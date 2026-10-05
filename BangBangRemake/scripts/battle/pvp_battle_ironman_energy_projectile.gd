extends Node2D

## The Hạt Năng Lượng projectile has the original 6-frame PNG source.

signal advanced(start: Vector2, finish: Vector2)
signal range_ended(position_value: Vector2)

const FLIGHT_SECONDS := 0.8
const FRAME_RATE := 24.0

@onready var _sprite: Sprite2D = $Sprite

var _direction := Vector2.RIGHT
var _remaining_distance := 0.0
var _speed := 0.0
var _frame_elapsed := 0.0


func configure(
	start: Vector2,
	direction: Vector2,
	maximum_distance: float
) -> void:
	global_position = start
	_direction = direction.normalized() if not direction.is_zero_approx() else Vector2.RIGHT
	_remaining_distance = maxf(maximum_distance, 0.0)
	_speed = _remaining_distance / FLIGHT_SECONDS
	rotation = _direction.angle() + PI * 0.5


func _process(delta: float) -> void:
	if _remaining_distance <= 0.0:
		range_ended.emit(global_position)
		queue_free()
		return
	var travel := minf(_speed * delta, _remaining_distance)
	var start := global_position
	var finish := start + _direction * travel
	global_position = finish
	_remaining_distance -= travel
	_frame_elapsed += delta
	_sprite.frame = int(_frame_elapsed * FRAME_RATE) % maxi(_sprite.hframes, 1)
	advanced.emit(start, finish)
	if is_queued_for_deletion():
		return
	if _remaining_distance <= 0.0:
		range_ended.emit(global_position)
		queue_free()
