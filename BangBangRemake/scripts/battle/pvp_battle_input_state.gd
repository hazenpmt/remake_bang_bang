extends RefCounted

var _up_pressed := false
var _down_pressed := false
var _left_pressed := false
var _right_pressed := false


func movement_input() -> Vector2:
	var horizontal := _resolved_axis(
		_left_pressed,
		_right_pressed
	)
	var vertical := _resolved_axis(
		_up_pressed,
		_down_pressed
	)
	return Vector2(horizontal, vertical).normalized()


func set_key(keycode: int, pressed: bool) -> void:
	if keycode == KEY_W:
		_up_pressed = pressed
	elif keycode == KEY_S:
		_down_pressed = pressed
	elif keycode == KEY_A:
		_left_pressed = pressed
	elif keycode == KEY_D:
		_right_pressed = pressed


func has_opposing_keys() -> bool:
	return (
		(_left_pressed and _right_pressed)
		or (_up_pressed and _down_pressed)
	)


func clear() -> void:
	_up_pressed = false
	_down_pressed = false
	_left_pressed = false
	_right_pressed = false


func _resolved_axis(
	negative_pressed: bool,
	positive_pressed: bool
) -> float:
	if negative_pressed == positive_pressed:
		return 0.0
	return -1.0 if negative_pressed else 1.0
