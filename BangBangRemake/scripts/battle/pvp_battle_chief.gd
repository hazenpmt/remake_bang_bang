@tool
extends Node2D

const FRAME_SIZE := Vector2(200.0, 200.0)
const FRAME_COUNT := 6
const DIRECTION_RIGHT := 2
const DIRECTION_LEFT := 6
const WALK_FRAME_SECONDS := 0.12
const MUZZLE_OFFSET := 24.0
const HP_FILL_WIDTH := 66.0
const FRIENDLY_COLOR := Color("35bfff")
const HOSTILE_COLOR := Color("ff2828")
const BLUE_HP := preload("res://assets/battle/hud/life_blue.png")
const RED_HP := preload("res://assets/battle/hud/life_red.png")

@export_range(1, 2, 1) var team_no := 1
@export var patrol_left_x := 168.0:
	set(value):
		patrol_left_x = value
		queue_redraw()
@export var patrol_right_x := 780.0:
	set(value):
		patrol_right_x = value
		queue_redraw()
@export_range(-1, 1, 2) var initial_direction := 1

@onready var _body: Sprite2D = $Body
@onready var _hp_fill_clip: Control = $Status/HpFillClip
@onready var _hp_fill: TextureRect = $Status/HpFillClip/Fill
@onready var _name_label: Label = $Status/Name

var _spawn_position := Vector2.ZERO
var _move_direction := 1
var _animation_frame := 0
var _animation_elapsed := 0.0
var _maximum_health := 1


func _ready() -> void:
	_spawn_position = global_position
	_move_direction = 1 if initial_direction >= 0 else -1
	if _body.material != null:
		_body.material = _body.material.duplicate()
	_apply_body_frame()
	set_viewer_team(team_no)
	set_health(_maximum_health, _maximum_health)
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var left_local := to_local(Vector2(patrol_left_x, global_position.y))
	var right_local := to_local(Vector2(patrol_right_x, global_position.y))
	var guide_color := Color(0.1, 0.9, 1.0, 0.9)
	var outline_color := Color(1.0, 1.0, 1.0, 0.98)
	draw_line(left_local, right_local, guide_color, 2.0)
	for handle_position: Vector2 in [left_local, right_local]:
		draw_circle(handle_position, 7.0, guide_color)
		draw_arc(
			handle_position,
			7.0,
			0.0,
			TAU,
			24,
			outline_color,
			2.0,
			true
		)


func reset_for_match(viewer_team_no: int) -> void:
	global_position = _spawn_position
	_move_direction = 1 if initial_direction >= 0 else -1
	_animation_frame = 0
	_animation_elapsed = 0.0
	visible = true
	_apply_body_frame()
	set_viewer_team(viewer_team_no)


func on_respawn() -> void:
	_move_direction = 1 if initial_direction >= 0 else -1
	_animation_frame = 0
	_animation_elapsed = 0.0
	_apply_body_frame()


func set_viewer_team(viewer_team_no: int) -> void:
	var friendly := team_no == viewer_team_no
	_hp_fill.texture = BLUE_HP if friendly else RED_HP
	_name_label.add_theme_color_override(
		"font_color",
		FRIENDLY_COLOR if friendly else HOSTILE_COLOR
	)
	if _body.material is ShaderMaterial:
		(_body.material as ShaderMaterial).set_shader_parameter(
			"friendly_to_viewer",
			friendly
		)


func set_health(current_value: int, maximum_value: int) -> void:
	_maximum_health = maxi(maximum_value, 1)
	var ratio := clampf(float(maxi(current_value, 0)) / float(_maximum_health), 0.0, 1.0)
	_hp_fill_clip.size.x = HP_FILL_WIDTH * ratio


func get_team_no() -> int:
	return team_no


func get_patrol_motion(delta: float, move_speed: float) -> Vector2:
	var left_x := minf(patrol_left_x, patrol_right_x)
	var right_x := maxf(patrol_left_x, patrol_right_x)
	if global_position.x >= right_x - 0.01:
		_move_direction = -1
	elif global_position.x <= left_x + 0.01:
		_move_direction = 1
	var next_x := clampf(
		global_position.x + float(_move_direction) * move_speed * delta,
		left_x,
		right_x
	)
	return Vector2(next_x - global_position.x, 0.0)


func apply_patrol_position(world_position: Vector2, delta: float) -> Vector2:
	var displacement := world_position - global_position
	global_position = world_position
	if displacement.length_squared() <= 0.0001:
		stop_movement()
		return Vector2.ZERO
	_animation_elapsed += delta
	while _animation_elapsed >= WALK_FRAME_SECONDS:
		_animation_elapsed -= WALK_FRAME_SECONDS
		_animation_frame = (_animation_frame + 1) % FRAME_COUNT
	_apply_body_frame()
	return displacement.normalized()


func reverse_patrol_direction() -> void:
	_move_direction *= -1
	_apply_body_frame()


func advance_patrol(delta: float, move_speed: float) -> Vector2:
	var motion := get_patrol_motion(delta, move_speed)
	return apply_patrol_position(global_position + motion, delta)


func stop_movement() -> void:
	_animation_frame = 0
	_animation_elapsed = 0.0
	_apply_body_frame()


func face_target(world_position: Vector2) -> void:
	var horizontal_delta := world_position.x - global_position.x
	if absf(horizontal_delta) > 0.01:
		_move_direction = 1 if horizontal_delta > 0.0 else -1
	_apply_body_frame()


func get_projectile_start(target_position: Vector2) -> Vector2:
	var direction := (target_position - global_position).normalized()
	if direction.is_zero_approx():
		direction = Vector2(float(_move_direction), 0.0)
	return global_position + direction * MUZZLE_OFFSET


func _apply_body_frame() -> void:
	if not is_instance_valid(_body):
		return
	var direction_row := DIRECTION_RIGHT if _move_direction >= 0 else DIRECTION_LEFT
	_body.region_rect = Rect2(
		float(_animation_frame) * FRAME_SIZE.x,
		float(direction_row) * FRAME_SIZE.y,
		FRAME_SIZE.x,
		FRAME_SIZE.y
	)
