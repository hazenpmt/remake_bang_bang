class_name PvpBattleSkillTooltip
extends Panel

## Battle tooltip styled after the original Tank panel: hierarchy, coloured
## stat keywords and both passive/active text are rendered as BBCode.
## It deliberately ignores input so it cannot steal a click from the skill HUD.

const TOOLTIP_WIDTH := 252.0
const CONTENT_MARGIN := 10.0

var _title_label: Label
var _cooldown_label: Label
var _body_label: RichTextLabel
var _show_generation := 0
var _active_anchor_rect := Rect2()
var _active_body_top := 62.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 100
	visible = false
	var background := StyleBoxFlat.new()
	background.bg_color = Color("091116ef")
	background.border_color = Color("60727a")
	background.set_border_width_all(1)
	background.corner_radius_top_left = 5
	background.corner_radius_top_right = 5
	background.corner_radius_bottom_left = 5
	background.corner_radius_bottom_right = 5
	add_theme_stylebox_override("panel", background)

	_title_label = Label.new()
	_title_label.position = Vector2(CONTENT_MARGIN, 7.0)
	_title_label.size = Vector2(TOOLTIP_WIDTH - CONTENT_MARGIN * 2.0, 21.0)
	_title_label.add_theme_font_size_override("font_size", 16)
	_title_label.add_theme_color_override("font_color", Color.WHITE)
	_title_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_title_label.add_theme_constant_override("outline_size", 2)
	add_child(_title_label)

	_cooldown_label = Label.new()
	_cooldown_label.position = Vector2(CONTENT_MARGIN, 28.0)
	_cooldown_label.size = Vector2(TOOLTIP_WIDTH - CONTENT_MARGIN * 2.0, 17.0)
	_cooldown_label.add_theme_font_size_override("font_size", 14)
	_cooldown_label.add_theme_color_override("font_color", Color("22c85a"))
	add_child(_cooldown_label)

	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = true
	_body_label.scroll_active = false
	_body_label.fit_content = false
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.position = Vector2(CONTENT_MARGIN, 47.0)
	_body_label.add_theme_font_size_override("normal_font_size", 14)
	_body_label.add_theme_font_size_override("bold_font_size", 14)
	_body_label.add_theme_color_override("default_color", Color("eef2f1"))
	_body_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_body_label.add_theme_constant_override("outline_size", 1)
	_body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body_label)


func show_for(data: Dictionary, anchor_global_rect: Rect2) -> void:
	if _title_label == null:
		return
	_show_generation += 1
	var generation := _show_generation
	_active_anchor_rect = anchor_global_rect
	_title_label.text = String(data.get("title", ""))
	_title_label.add_theme_font_size_override(
		"font_size",
		int(data.get("title_font_size", 16))
	)
	var body_font_size := int(data.get("body_font_size", 14))
	_body_label.add_theme_font_size_override("normal_font_size", body_font_size)
	_body_label.add_theme_font_size_override("bold_font_size", body_font_size)
	var show_metadata := bool(data.get("show_metadata", true))
	_cooldown_label.visible = show_metadata
	_cooldown_label.text = String(data.get("cooldown", ""))
	_active_body_top = 47.0 if show_metadata else 31.0
	_body_label.position = Vector2(CONTENT_MARGIN, _active_body_top)
	var fallback_height := float(data.get("height", 280.0))
	custom_minimum_size = Vector2.ZERO
	size = Vector2(TOOLTIP_WIDTH, fallback_height)
	_body_label.size = Vector2(
		TOOLTIP_WIDTH - CONTENT_MARGIN * 2.0,
		maxf(fallback_height - _active_body_top - CONTENT_MARGIN, 1.0)
	)
	_body_label.text = String(data.get("bbcode", ""))
	_position_at_active_anchor()
	visible = true
	# RichTextLabel finalises BBCode wrapping after the current layout pass.
	# Measure on deferred call so each box becomes exactly as tall as its text.
	_fit_content_after_layout.call_deferred(generation, fallback_height)


func _fit_content_after_layout(generation: int, fallback_height: float) -> void:
	if generation != _show_generation or not visible:
		return
	var rendered_body_height := ceilf(_body_label.get_content_height())
	var tooltip_height := fallback_height
	if rendered_body_height > 0.0:
		tooltip_height = _active_body_top + rendered_body_height + CONTENT_MARGIN
	size = Vector2(TOOLTIP_WIDTH, tooltip_height)
	custom_minimum_size = size
	_body_label.size = Vector2(
		TOOLTIP_WIDTH - CONTENT_MARGIN * 2.0,
		maxf(rendered_body_height, 1.0)
	)
	_position_at_active_anchor()


func _position_at_active_anchor() -> void:
	var viewport_size := get_viewport_rect().size
	var desired_x := _active_anchor_rect.get_center().x - size.x * 0.5
	var desired_y := _active_anchor_rect.position.y - size.y - 10.0
	position = Vector2(
		clampf(desired_x, 8.0, maxf(8.0, viewport_size.x - size.x - 8.0)),
		maxf(8.0, desired_y)
	)


func hide_tooltip() -> void:
	_show_generation += 1
	visible = false
