extends TextureButton

@export var hover_brightness := 1.25
@export var pressed_brightness := 0.82
@export var pressed_offset := 1.0

var _rest_position := Vector2.ZERO
var _color_tween: Tween


func _ready() -> void:
	_rest_position = position
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)


func _on_mouse_entered() -> void:
	if disabled:
		return
	_tween_color(Color(hover_brightness, hover_brightness, hover_brightness))


func _on_mouse_exited() -> void:
	if disabled:
		return
	if not button_pressed:
		position = _rest_position
	_tween_color(Color.WHITE)


func _on_button_down() -> void:
	if disabled:
		return
	position = _rest_position + Vector2(0.0, pressed_offset)
	_tween_color(
		Color(pressed_brightness, pressed_brightness, pressed_brightness)
	)


func _on_button_up() -> void:
	position = _rest_position
	if disabled:
		return
	if is_hovered():
		_tween_color(
			Color(hover_brightness, hover_brightness, hover_brightness)
		)
	else:
		_tween_color(Color.WHITE)


func _tween_color(target: Color) -> void:
	if _color_tween != null and _color_tween.is_valid():
		_color_tween.kill()
	_color_tween = create_tween()
	_color_tween.tween_property(self, "self_modulate", target, 0.08)
