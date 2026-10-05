@tool
extends Node2D

const MAP_LAYOUT_PATH := \
	"res://assets/battle/maps/Maya Tiên tri(Tính điểm)/data1_c.godot.json"

# stage1.jpg is 2160x1413. The battle uses a 1920x1080 SubViewport, which
# would otherwise clip the lower/right map area in Godot's 2D editor.
const EDITOR_MAP_VIEWPORT_SIZE := Vector2i(2160, 1413)

const MAP_BUILDING_COLLISION_OVERRIDE_PATH := \
	"res://assets/battle/maps/Maya Tiên tri(Tính điểm)/data1_c.building_collision_overrides.json"

const NPC_TEXTURES := {
	1008: preload(
		"res://assets/battle/buildings/npc/fixbox001.png"
	),
	1009: preload(
		"res://assets/battle/buildings/npc/fixbox002.png"
	),
	1102: preload(
		"res://assets/battle/buildings/npc/cannon1_base.png"
	),
	1103: preload(
		"res://assets/battle/buildings/npc/cannon2_base.png"
	),
	1105: preload(
		"res://assets/battle/buildings/npc/missile2_base.png"
	),
	1106: preload(
		"res://assets/battle/buildings/npc/missile2_base.png"
	),
	2003: preload(
		"res://assets/battle/buildings/npc/box001.png"
	),
	2004: preload(
		"res://assets/battle/buildings/npc/box002.png"
	),
	2006: preload(
		"res://assets/battle/buildings/npc/box004.png"
	),
	2008: preload(
		"res://assets/battle/buildings/npc/earthbags002.png"
	),
	2009: preload(
		"res://assets/battle/buildings/npc/abatis001.png"
	),
	2010: preload(
		"res://assets/battle/buildings/npc/abatis002.png"
	),
	2011: preload(
		"res://assets/battle/buildings/npc/roadblock001.png"
	),
	5031: preload(
		"res://assets/battle/buildings/npc/iron006.png"
	),
}

const NPC_OVERLAY_TEXTURES := {
	1102: preload(
		"res://assets/battle/buildings/npc/cannon1_gun.png"
	),
	1103: preload(
		"res://assets/battle/buildings/npc/cannon2_gun.png"
	),
	1105: preload(
		"res://assets/battle/buildings/npc/missile1_gun.png"
	),
	1106: preload(
		"res://assets/battle/buildings/npc/missile2_gun.png"
	),
}

const NPC_NAMES := {
	1008: "Hộp sửa chữa đội 1",
	1009: "Hộp sửa chữa đội 2",
	1102: "Pháo đài đội 1",
	1103: "Pháo đài đội 2",
	1105: "Pháo tên lửa đội 1",
	1106: "Pháo tên lửa đội 2",
	2003: "Thùng gỗ",
	2004: "Thùng gỗ bọc sắt",
	2006: "Chồng thùng gỗ",
	2008: "Bao cát",
	2009: "Hàng rào dọc",
	2010: "Hàng rào ngang",
	2011: "Chướng ngại",
	5031: "Khối sắt",
}

@export_category("Xem trước map trong Editor")
@export var show_npc_visuals := true
@export var show_static_collision := true
@export var show_npc_collision := true
@export var show_team_spawns := true
@export var show_player_tank_collision := true
@export var show_gameplay_points := true
@export var show_labels := true
@export_range(0.05, 0.8, 0.05) var collision_opacity := 0.2

@export_category("Chinh va cham keo tha")
# Tick this once from the EditorMapPreview Inspector. It creates real,
# persistent CollisionShape2D children under TerrainCollision from the source
# map rectangles; they can then be selected, dragged and resized in Godot 2D.
@export var create_drag_edit_static_colliders := false:
	set(value):
		if not value:
			return
		if Engine.is_editor_hint():
			# Also refresh the full-size edit canvas for an already-open scene.
			# Existing shapes are left untouched by the creation routine below.
			call_deferred("_expand_editor_viewport_to_full_map")
			call_deferred("_create_drag_edit_static_colliders")

var _layout: Dictionary = {}
var _building_collision_overrides: Dictionary = {}
var _load_error := ""


func _ready() -> void:
	if not Engine.is_editor_hint():
		visible = false
		return
	_expand_editor_viewport_to_full_map()
	_load_layout()
	set_process(true)
	queue_redraw()


func _expand_editor_viewport_to_full_map() -> void:
	# get_viewport() points at the Godot editor viewport while this @tool
	# script is being drawn, not necessarily at this map's SubViewport. Walk
	# the known scene branch instead so we alter WorldViewport itself.
	var world := get_parent()
	var map_viewport := world.get_parent() as SubViewport if world != null else null
	if map_viewport == null:
		return
	# A stretching SubViewportContainer owns the child viewport size and clips
	# this 2160x1413 source image at the 1920x1080 battle target. Disable that
	# editor-only stretch first, then expose the complete map canvas.
	var viewport_container := map_viewport.get_parent() as SubViewportContainer
	if viewport_container != null:
		viewport_container.stretch = false
	map_viewport.size = EDITOR_MAP_VIEWPORT_SIZE


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		queue_redraw()


func _load_layout() -> void:
	_layout.clear()
	_load_error = ""
	var file := FileAccess.open(MAP_LAYOUT_PATH, FileAccess.READ)
	if file == null:
		_load_error = "Không mở được %s" % MAP_LAYOUT_PATH
		return
	var parsed_value: Variant = JSON.parse_string(file.get_as_text())
	if parsed_value is not Dictionary:
		_load_error = "JSON map không hợp lệ."
		return
	_layout = parsed_value
	_load_building_collision_overrides()


func _load_building_collision_overrides() -> void:
	# @tool scripts can retain an old inspector instance while Godot hot-reloads
	# this script. That old instance has the newly added field as Nil once, so
	# replace it instead of calling Dictionary.clear() on it.
	_building_collision_overrides = {}
	var file := FileAccess.open(MAP_BUILDING_COLLISION_OVERRIDE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed_value: Variant = JSON.parse_string(file.get_as_text())
	if parsed_value is not Dictionary:
		return
	var document: Dictionary = parsed_value
	var overrides_value: Variant = document.get("buildings", {})
	if overrides_value is Dictionary:
		_building_collision_overrides = (overrides_value as Dictionary).duplicate(true)


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	if _layout.is_empty():
		_draw_load_error()
		return
	var has_authored_objects := _has_authored_map_objects()
	if show_npc_visuals and not has_authored_objects:
		_draw_npc_visuals()
	if show_static_collision:
		_draw_static_collision()
	if show_npc_collision and not has_authored_objects:
		_draw_npc_collision()
	if show_team_spawns:
		_draw_team_spawns()
	if show_player_tank_collision:
		_draw_player_tank_collision()
	if show_gameplay_points:
		_draw_gameplay_points()


func _has_authored_map_objects() -> bool:
	var world := get_parent()
	if world == null:
		return false
	var editor_objects := world.get_node_or_null("EditorMapObjects")
	if editor_objects == null:
		return false
	for child: Node in editor_objects.get_children():
		if child.has_method("get_world_collision_rectangles"):
			return true
	return false


func _draw_load_error() -> void:
	var message := _load_error
	if message.is_empty():
		message = "Chưa có dữ liệu map."
	draw_string(
		ThemeDB.fallback_font,
		Vector2(40.0, 60.0),
		message,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		20,
		Color(1.0, 0.2, 0.2, 1.0)
	)


func _draw_npc_visuals() -> void:
	var placements_value: Variant = _layout.get("npc_placements", [])
	if placements_value is not Array:
		return
	for placement_value: Variant in placements_value:
		if placement_value is not Dictionary:
			continue
		var placement: Dictionary = placement_value
		var template_id := int(placement.get("template_id", 0))
		var unique_id := int(placement.get("unique_id", 0))
		var center := Vector2(
			float(placement.get("x", 0.0)),
			float(placement.get("y", 0.0))
		)
		var texture_value: Variant = NPC_TEXTURES.get(template_id)
		var texture := texture_value as Texture2D
		if texture != null:
			draw_texture(texture, center - texture.get_size() * 0.5)
		else:
			draw_circle(center, 18.0, Color(1.0, 0.0, 1.0, 0.9))
		var overlay_value: Variant = NPC_OVERLAY_TEXTURES.get(template_id)
		var overlay_texture := overlay_value as Texture2D
		if overlay_texture != null:
			draw_texture(
				overlay_texture,
				center - overlay_texture.get_size() * 0.5
			)
		if show_labels:
			var npc_name := String(
				NPC_NAMES.get(template_id, "NPC chưa nhận diện")
			)
			_draw_label(
				center + Vector2(-54.0, 56.0),
				"%s  #%d / mẫu %d" % [
					npc_name,
					unique_id,
					template_id,
				],
				Color(1.0, 1.0, 0.35, 1.0)
			)


func _draw_static_collision() -> void:
	var scene_rectangles := _scene_static_collision_rectangles()
	if not scene_rectangles.is_empty():
		# The labels map the visual red guide to the exact draggable child name
		# under TerrainCollision. They are editor-only and never enter gameplay.
		_draw_collision_rectangles(scene_rectangles, true)
		return
	var rectangles_value: Variant = _layout.get(
		"static_collision_rectangles",
		[]
	)
	if rectangles_value is not Array:
		return
	var rectangles: Array[Rect2] = []
	for rectangle_value: Variant in rectangles_value:
		if rectangle_value is not Dictionary:
			continue
		rectangles.append(_rect_from_dictionary(rectangle_value))
	_draw_collision_rectangles(rectangles)


func _draw_collision_rectangles(
	rectangles: Array[Rect2],
	show_drag_ids := false
) -> void:
	var fill_color := Color(1.0, 0.05, 0.05, collision_opacity)
	var border_color := Color(1.0, 0.1, 0.1, 0.95)
	for index in rectangles.size():
		var rectangle: Rect2 = rectangles[index]
		draw_rect(rectangle, fill_color, true)
		draw_rect(rectangle, border_color, false, 2.0)
		if show_drag_ids:
			_draw_label(
				rectangle.position + Vector2(4.0, 16.0),
				"D%02d" % index,
				Color(1.0, 0.82, 0.15, 1.0)
			)


func _scene_static_collision_rectangles() -> Array[Rect2]:
	var terrain_collision := _terrain_collision()
	var rectangles: Array[Rect2] = []
	if terrain_collision == null:
		return rectangles
	for child: Node in terrain_collision.get_children():
		var collision_shape := child as CollisionShape2D
		if collision_shape == null:
			continue
		var rectangle_shape := collision_shape.shape as RectangleShape2D
		if rectangle_shape == null:
			continue
		var size := rectangle_shape.size * collision_shape.scale.abs()
		if size.x <= 0.0 or size.y <= 0.0:
			continue
		rectangles.append(Rect2(collision_shape.position - size * 0.5, size))
	return rectangles


func _create_drag_edit_static_colliders() -> void:
	if not Engine.is_editor_hint():
		return
	if _layout.is_empty():
		_load_layout()
	var terrain_collision := _terrain_collision()
	if terrain_collision == null:
		push_warning("TerrainCollision node is missing.")
		return
	if not _scene_static_collision_rectangles().is_empty():
		push_warning("Editable static collision shapes already exist.")
		return
	var rectangles_value: Variant = _layout.get(
		"static_collision_rectangles",
		[]
	)
	if rectangles_value is not Array:
		return
	var scene_root := get_tree().edited_scene_root
	if scene_root == null:
		return
	var index := 0
	for rectangle_value: Variant in rectangles_value:
		if rectangle_value is not Dictionary:
			continue
		var rectangle := _rect_from_dictionary(rectangle_value as Dictionary)
		if rectangle.size.x <= 0.0 or rectangle.size.y <= 0.0:
			continue
		var shape := RectangleShape2D.new()
		shape.size = rectangle.size
		var collision_shape := CollisionShape2D.new()
		collision_shape.name = "DragCollision_%02d" % index
		collision_shape.position = rectangle.get_center()
		collision_shape.shape = shape
		terrain_collision.add_child(collision_shape)
		collision_shape.owner = scene_root
		index += 1
	queue_redraw()


func _terrain_collision() -> StaticBody2D:
	var world := get_parent()
	return world.get_node_or_null("TerrainCollision") as StaticBody2D


func _draw_npc_collision() -> void:
	var occupancy_value: Variant = _layout.get("npc_occupancy", [])
	if occupancy_value is not Array:
		return
	var fill_color := Color(1.0, 0.55, 0.0, collision_opacity)
	var border_color := Color(1.0, 0.7, 0.05, 0.95)
	for occupancy_entry_value: Variant in occupancy_value:
		if occupancy_entry_value is not Dictionary:
			continue
		var occupancy_entry: Dictionary = occupancy_entry_value
		var building_id := int(occupancy_entry.get("unique_id", 0))
		var rectangles_value: Variant = occupancy_entry.get("rectangles", [])
		# The Inspector may retain this exported tool node across a script reload.
		# Read through Variant first: the just-added Dictionary member is Nil on
		# that one old node instance until Godot recreates it.
		var override_value: Variant = null
		var override_container: Variant = _building_collision_overrides
		if override_container is Dictionary:
			var overrides: Dictionary = override_container
			override_value = overrides.get(str(building_id), null)
		if override_value is Array and not (override_value as Array).is_empty():
			rectangles_value = override_value
		if rectangles_value is not Array:
			continue
		for rectangle_value: Variant in rectangles_value:
			if rectangle_value is not Dictionary:
				continue
			var rectangle := _rect_from_dictionary(rectangle_value)
			draw_rect(rectangle, fill_color, true)
			draw_rect(rectangle, border_color, false, 1.5)


func _draw_team_spawns() -> void:
	var spawns_value: Variant = _layout.get("team_spawns", [])
	if spawns_value is not Array:
		return
	for spawn_value: Variant in spawns_value:
		if spawn_value is not Dictionary:
			continue
		var spawn: Dictionary = spawn_value
		var team_no := int(spawn.get("team", 0))
		var slot_no := int(spawn.get("slot", 0))
		var center := Vector2(
			float(spawn.get("x", 0.0)),
			float(spawn.get("y", 0.0))
		)
		var color := (
			Color(0.1, 0.65, 1.0, 1.0)
			if team_no == 1
			else Color(1.0, 0.2, 0.25, 1.0)
		)
		draw_circle(
			center,
			14.0,
			Color(color.r, color.g, color.b, 0.35)
		)
		draw_arc(center, 14.0, 0.0, TAU, 24, color, 3.0)
		if show_labels:
			_draw_label(
				center + Vector2(17.0, 5.0),
				"Đội %d - vị trí %d" % [team_no, slot_no],
				color
			)


func _draw_player_tank_collision() -> void:
	var world := get_parent()
	var tank_anchor := world.get_node_or_null("PlayerTankAnchor") as Node2D
	if tank_anchor == null:
		return
	var center := tank_anchor.position
	# These are the exact logical radii used in pvp_battle_map.gd.
	# Combat targeting and terrain movement now share the 36px body radius.
	var target_radius := 36.0
	var movement_radius := 36.0
	var movement_center := center + Vector2(0.0, 12.0)
	var target_rect := Rect2(
		center - Vector2.ONE * target_radius,
		Vector2.ONE * target_radius * 2.0
	)
	draw_rect(target_rect, Color(1.0, 0.55, 0.0, 0.18), true)
	draw_rect(target_rect, Color(1.0, 0.7, 0.05, 0.98), false, 2.0)
	draw_arc(
		center,
		target_radius,
		0.0,
		TAU,
		40,
		Color(1.0, 0.7, 0.05, 0.98),
		1.5
	)
	var movement_rect := Rect2(
		movement_center - Vector2.ONE * movement_radius,
		Vector2.ONE * movement_radius * 2.0
	)
	draw_rect(movement_rect, Color(0.15, 1.0, 0.4, 0.25), true)
	draw_rect(movement_rect, Color(0.15, 1.0, 0.4, 1.0), false, 1.5)
	draw_arc(
		movement_center,
		movement_radius,
		0.0,
		TAU,
		40,
		Color(0.15, 1.0, 0.4, 1.0),
		1.5
	)
	_draw_cross(center, 5.0, Color.WHITE)
	if show_labels:
		_draw_label(
			center + Vector2(42.0, -22.0),
			"Tank hit 36 / move 36 (+12Y)",
			Color(1.0, 0.9, 0.25, 1.0)
		)


func _draw_gameplay_points() -> void:
	var anchors_value: Variant = _layout.get("team_anchors", [])
	if anchors_value is Array:
		for anchor_value: Variant in anchors_value:
			if anchor_value is not Dictionary:
				continue
			var anchor: Dictionary = anchor_value
			var center := Vector2(
				float(anchor.get("x", 0.0)),
				float(anchor.get("y", 0.0))
			)
			var team_no := int(anchor.get("team", 0))
			var color := (
				Color(0.0, 0.9, 1.0, 1.0)
				if team_no == 1
				else Color(1.0, 0.3, 0.5, 1.0)
			)
			_draw_cross(center, 18.0, color)
			if show_labels:
				_draw_label(
					center + Vector2(20.0, -8.0),
					"Mốc đội %d" % team_no,
					color
				)
	var points_value: Variant = _layout.get("special_points", [])
	if points_value is not Array:
		return
	for point_value: Variant in points_value:
		if point_value is not Dictionary:
			continue
		var point: Dictionary = point_value
		var center := Vector2(
			float(point.get("x", 0.0)),
			float(point.get("y", 0.0))
		)
		_draw_cross(center, 20.0, Color(0.8, 0.25, 1.0, 1.0))
		if show_labels:
			_draw_label(
				center + Vector2(22.0, -8.0),
				"Điểm gameplay loại %d" % int(point.get("type", 0)),
				Color(0.9, 0.4, 1.0, 1.0)
			)


func _draw_cross(center: Vector2, radius: float, color: Color) -> void:
	draw_line(
		center - Vector2(radius, 0.0),
		center + Vector2(radius, 0.0),
		color,
		3.0
	)
	draw_line(
		center - Vector2(0.0, radius),
		center + Vector2(0.0, radius),
		color,
		3.0
	)
	draw_circle(center, 5.0, color)


func _draw_label(
	position_value: Vector2,
	text_value: String,
	color: Color
) -> void:
	draw_string(
		ThemeDB.fallback_font,
		position_value + Vector2(1.0, 1.0),
		text_value,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		13,
		Color(0.0, 0.0, 0.0, 0.95)
	)
	draw_string(
		ThemeDB.fallback_font,
		position_value,
		text_value,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1.0,
		13,
		color
	)


func _rect_from_dictionary(value: Dictionary) -> Rect2:
	return Rect2(
		float(value.get("x", 0.0)),
		float(value.get("y", 0.0)),
		float(value.get("width", 0.0)),
		float(value.get("height", 0.0))
	)
