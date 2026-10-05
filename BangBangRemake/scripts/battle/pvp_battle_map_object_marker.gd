@tool
class_name PvpBattleMapObjectMarker
extends Node2D

const BUILDING_CATALOG := preload(
	"res://scripts/data/battle_building_catalog.gd"
)

@export_category("Vat the / cong trinh tren map")
@export var unique_id := 0:
	set(value):
		unique_id = value
		_update_editor_display()
@export var template_id := 0:
	set(value):
		template_id = value
		_update_editor_display()
@export_range(0, 2, 1) var team_no := 0:
	set(value):
		team_no = value
		_update_editor_display()

## ID vat goc dung de ke thua actions khi nhan ban node. Voi vat goc, gia tri
## nay trung unique_id. Khi Ctrl+D de them vat cung loai, chi doi unique_id.
@export var source_unique_id := 0

## Hitbox cuc bo tinh tu tam node. Khi keo node, hitbox nay di cung vat.
@export var collision_rectangles: Array[Rect2] = []:
	set(value):
		collision_rectangles = value
		_update_editor_display()

@export_category("Hien thi trong Editor")
@export var show_collision := true:
	set(value):
		show_collision = value
		_update_editor_display()
@export var show_label := true:
	set(value):
		show_label = value
		_update_editor_display()


func _ready() -> void:
	if not Engine.is_editor_hint():
		visible = false
		set_process(false)
		return
	_refresh_sprite_textures()
	queue_redraw()


func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var template := BUILDING_CATALOG.get_template(template_id)
	if show_collision:
		for rectangle: Rect2 in collision_rectangles:
			draw_rect(rectangle, Color(1.0, 0.55, 0.0, 0.18), true)
			draw_rect(rectangle, Color(1.0, 0.72, 0.05, 0.95), false, 1.5)
	if show_label:
		var display_name := String(template.get("display_name", "Unknown map object"))
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-54.0, _selection_rect().end.y + 16.0),
			"%s  #%d / mau %d" % [display_name, unique_id, template_id],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			14,
			Color(1.0, 1.0, 0.35, 1.0)
		)

func _selection_rect() -> Rect2:
	var template := BUILDING_CATALOG.get_template(template_id)
	var size := Vector2(
		float(template.get("image_width", template.get("width", 72.0))),
		float(template.get("image_height", template.get("height", 72.0)))
	)
	if size.x <= 0.0 or size.y <= 0.0:
		size = Vector2(72.0, 72.0)
	var result := Rect2(-size * 0.5, size)
	for rectangle: Rect2 in collision_rectangles:
		result = result.merge(rectangle)
	return result


func get_world_collision_rectangles() -> Array[Rect2]:
	var rectangles: Array[Rect2] = []
	for local_rectangle: Rect2 in collision_rectangles:
		rectangles.append(Rect2(position + local_rectangle.position, local_rectangle.size))
	return rectangles


func _update_editor_display() -> void:
	if is_inside_tree():
		_refresh_sprite_textures()
		queue_redraw()


func _refresh_sprite_textures() -> void:
	if not Engine.is_editor_hint():
		return
	var template := BUILDING_CATALOG.get_template(template_id)
	var visual_state := BUILDING_CATALOG.get_visual_state(template, 0)
	_set_sprite_texture(
		get_node_or_null("Base") as Sprite2D,
		String(visual_state.get("base", ""))
	)
	_set_sprite_texture(
		get_node_or_null("Overlay") as Sprite2D,
		String(visual_state.get("overlay", ""))
	)


func _set_sprite_texture(sprite: Sprite2D, file_name: String) -> void:
	if sprite == null:
		return
	var asset_path := BUILDING_CATALOG.asset_path(file_name)
	sprite.texture = (
		load(asset_path) as Texture2D
		if not asset_path.is_empty()
		else null
	)
	sprite.visible = sprite.texture != null
