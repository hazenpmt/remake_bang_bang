extends Node2D

signal destroyed(building_id: int)

const BUILDING_CATALOG := preload("res://scripts/data/battle_building_catalog.gd")

@onready var _base: Sprite2D = $Base
@onready var _overlay: Sprite2D = $Overlay
@onready var _structure_health: Control = $StructureHealth
@onready var _structure_health_fill: TextureRect = $StructureHealth/FillClip/Fill
@onready var _collision: StaticBody2D = $Collision

var _building_id := 0
var _template_id := 0
var _template: Dictionary = {}
var _visual_template: Dictionary = {}
var _team_no := 0
var _viewer_team_no := 1
var _current_hit_points := 1
var _maximum_hit_points := 1
var _damage_state := BUILDING_CATALOG.DAMAGE_STATE_NORMAL
var _damage_hit_count := 0
var _destroyed := false
var _gun_recoil_tween: Tween


func configure(
	placement: Dictionary,
	template: Dictionary,
	collision_rectangles: Array[Rect2]
) -> void:
	_building_id = int(placement.get("unique_id", 0))
	_template_id = int(placement.get("template_id", 0))
	_template = template.duplicate(true)
	_visual_template = _template.duplicate(true)
	_team_no = int(placement.get("camp", 0))
	position = Vector2(
		float(placement.get("x", 0.0)),
		float(placement.get("y", 0.0))
	)
	_maximum_hit_points = maxi(int(_template.get("hit_points", 1)), 1)
	_current_hit_points = _maximum_hit_points
	_damage_hit_count = 0
	name = "Building_%d_Template_%d" % [_building_id, _template_id]
	set_meta("building_id", _building_id)
	set_meta("template_id", _template_id)
	set_meta("team_no", _team_no)
	_build_collision(collision_rectangles)
	_refresh_visual_template()
	_refresh_structure_health()


func get_building_id() -> int:
	return _building_id


func get_template_id() -> int:
	return _template_id


func get_team_no() -> int:
	return _team_no


func get_hit_points() -> int:
	return _current_hit_points


func get_maximum_hit_points() -> int:
	return _maximum_hit_points


func is_structure() -> bool:
	return bool(_template.get("is_structure", false))


func aim_gun_at(world_target: Vector2) -> void:
	if _destroyed or _overlay.texture == null:
		return
	var direction := world_target - global_position
	if direction.is_zero_approx():
		return
	# The source gun sprites face upward. Rotate only the separate original gun
	# layer, keeping the source base sprite stationary.
	_overlay.rotation = direction.angle() + PI * 0.5


func play_turret_shot(world_target: Vector2) -> void:
	aim_gun_at(world_target)
	if _overlay.texture == null:
		return
	if _gun_recoil_tween != null and _gun_recoil_tween.is_valid():
		_gun_recoil_tween.kill()
	var recoil_direction := (world_target - global_position).normalized()
	_overlay.position = -recoil_direction * 4.0
	_gun_recoil_tween = create_tween()
	_gun_recoil_tween.tween_property(_overlay, "position", Vector2.ZERO, 0.10)


func get_turret_muzzle_position(world_target: Vector2) -> Vector2:
	var direction := world_target - global_position
	if direction.is_zero_approx():
		return global_position
	# These offsets are measured from the centres to the muzzles in the original
	# unscaled gun PNG layers (cannon 120px, missile 144px).
	return global_position + direction.normalized() * float(
		_template.get("muzzle_offset_pixels", 0.0)
	)


func set_viewer_team(viewer_team_no: int) -> void:
	_viewer_team_no = viewer_team_no
	_refresh_visual_template()
	_refresh_structure_health()


func is_destroyed() -> bool:
	return _destroyed


func should_hide_when_destroyed() -> bool:
	return bool(_template.get("hide_after_destroy", false))


func get_destruction_timeline_path() -> String:
	return BUILDING_CATALOG.destruction_timeline_path(_template)


func apply_damage(damage: int) -> int:
	if _destroyed or damage <= 0:
		return 0
	var hits_to_destroy := maxi(int(_template.get("hits_to_destroy", 0)), 0)
	if hits_to_destroy > 0:
		return _apply_hit_progress_damage(hits_to_destroy)
	var received_multiplier := maxf(
		float(_template.get("damage_received_multiplier", 1.0)),
		0.0
	)
	var scaled_damage := maxi(roundi(float(damage) * received_multiplier), 1)
	var actual_damage := mini(scaled_damage, _current_hit_points)
	_current_hit_points -= actual_damage
	if _current_hit_points <= 0:
		_destroyed = true
		_collision.process_mode = Node.PROCESS_MODE_DISABLED
	_update_visual_from_health()
	_refresh_structure_health()
	if _destroyed:
		destroyed.emit(_building_id)
	return actual_damage


func _apply_hit_progress_damage(hits_to_destroy: int) -> int:
	var previous_hit_points := _current_hit_points
	_damage_hit_count = mini(_damage_hit_count + 1, hits_to_destroy)
	var remaining_hits := maxi(hits_to_destroy - _damage_hit_count, 0)
	_current_hit_points = roundi(
		float(_maximum_hit_points)
		* float(remaining_hits)
		/ float(hits_to_destroy)
	)
	var actual_damage := maxi(previous_hit_points - _current_hit_points, 1)
	if _current_hit_points <= 0:
		_destroyed = true
		_collision.process_mode = Node.PROCESS_MODE_DISABLED
		_update_visual_from_health()
		_refresh_structure_health()
		destroyed.emit(_building_id)
		return actual_damage
	var hits_per_damage_state := maxi(
		int(_template.get("hits_per_damage_state", 1)),
		1
	)
	var next_state := clampi(
		floori(float(_damage_hit_count) / float(hits_per_damage_state)),
		BUILDING_CATALOG.DAMAGE_STATE_NORMAL,
		BUILDING_CATALOG.DAMAGE_STATE_HEAVY
	)
	_set_damage_state(next_state)
	_refresh_structure_health()
	return actual_damage


func set_authoritative_health(current_hit_points: int) -> void:
	_current_hit_points = clampi(current_hit_points, 0, _maximum_hit_points)
	_destroyed = _current_hit_points <= 0
	_collision.process_mode = (
		Node.PROCESS_MODE_DISABLED
		if _destroyed
		else Node.PROCESS_MODE_INHERIT
	)
	_update_visual_from_health()
	_refresh_structure_health()


func reset_for_match() -> void:
	_current_hit_points = _maximum_hit_points
	_damage_hit_count = 0
	_destroyed = false
	visible = true
	if _gun_recoil_tween != null and _gun_recoil_tween.is_valid():
		_gun_recoil_tween.kill()
	_overlay.position = Vector2.ZERO
	_overlay.rotation = 0.0
	_collision.process_mode = Node.PROCESS_MODE_INHERIT
	_damage_state = BUILDING_CATALOG.DAMAGE_STATE_NORMAL
	_refresh_visual_template()
	_refresh_structure_health()


func _update_visual_from_health() -> void:
	# XML provides the original normal, three damaged and destroyed files but
	# does not include their numeric HP thresholds. Until an authoritative
	# source supplies them, use four equal health bands while every visual itself
	# remains byte-for-byte from the original client.
	var next_state := BUILDING_CATALOG.DAMAGE_STATE_NORMAL
	var health_ratio := float(_current_hit_points) / float(_maximum_hit_points)
	if health_ratio <= 0.0:
		next_state = BUILDING_CATALOG.DAMAGE_STATE_DESTROYED
	elif health_ratio <= 0.25:
		next_state = BUILDING_CATALOG.DAMAGE_STATE_HEAVY
	elif health_ratio <= 0.5:
		next_state = BUILDING_CATALOG.DAMAGE_STATE_MEDIUM
	elif health_ratio <= 0.75:
		next_state = BUILDING_CATALOG.DAMAGE_STATE_LIGHT
	_set_damage_state(next_state)


func _set_damage_state(next_state: int) -> void:
	_damage_state = next_state
	var visual_state := BUILDING_CATALOG.get_visual_state(
		_visual_template,
		_damage_state
	)
	_base.texture = _load_texture(String(visual_state.get("base", "")))
	_overlay.texture = _load_texture(String(visual_state.get("overlay", "")))
	_overlay.visible = _overlay.texture != null
	if not _overlay.visible:
		_overlay.position = Vector2.ZERO
		_overlay.rotation = 0.0


func _refresh_visual_template() -> void:
	_visual_template = BUILDING_CATALOG.get_relation_visual_template(
		_template,
		_team_no == _viewer_team_no
	)
	_set_damage_state(_damage_state)


func _refresh_structure_health() -> void:
	if not is_instance_valid(_structure_health):
		return
	_structure_health.visible = is_structure() and not _destroyed
	if not _structure_health.visible:
		return
	var health_ratio := clampf(
		float(_current_hit_points) / float(_maximum_hit_points),
		0.0,
		1.0
	)
	_structure_health_fill.size.x = 66.0 * health_ratio
	var fill_file := (
		"life_blue.png"
		if _team_no == _viewer_team_no
		else "life_red.png"
	)
	_structure_health_fill.texture = _load_hud_texture(fill_file)


func _load_texture(file_name: String) -> Texture2D:
	var asset_path := BUILDING_CATALOG.asset_path(file_name)
	if asset_path.is_empty():
		return null
	return load(asset_path) as Texture2D


func _load_hud_texture(file_name: String) -> Texture2D:
	return load("res://assets/battle/hud/" + file_name) as Texture2D


func _build_collision(collision_rectangles: Array[Rect2]) -> void:
	for child: Node in _collision.get_children():
		child.queue_free()
	for rectangle: Rect2 in collision_rectangles:
		if rectangle.size.x <= 0.0 or rectangle.size.y <= 0.0:
			continue
		var shape := RectangleShape2D.new()
		shape.size = rectangle.size
		var collision_shape := CollisionShape2D.new()
		collision_shape.position = rectangle.get_center() - global_position
		collision_shape.shape = shape
		_collision.add_child(collision_shape)
