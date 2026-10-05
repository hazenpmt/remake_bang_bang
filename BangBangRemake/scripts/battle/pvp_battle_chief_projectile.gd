extends Node2D

signal advanced(start: Vector2, finish: Vector2)
signal expired(position: Vector2)

const SOURCE_UP_ANGLE := -PI * 0.5

@export_range(10.0, 2000.0, 10.0) var projectile_speed := 240.0

var _direction := Vector2.RIGHT
var _maximum_distance := 480.0
var _traveled_distance := 0.0
var _impact_active := false


func configure(
	start_position: Vector2,
	direction: Vector2,
	maximum_distance: float,
	speed: float
) -> void:
	global_position = start_position
	_direction = direction.normalized()
	if _direction.is_zero_approx():
		_direction = Vector2.RIGHT
	_maximum_distance = maxf(maximum_distance, 1.0)
	projectile_speed = maxf(speed, 1.0)
	_traveled_distance = 0.0
	_impact_active = false
	rotation = _direction.angle() - SOURCE_UP_ANGLE


func _process(delta: float) -> void:
	if _impact_active:
		return
	var remaining_distance := maxf(_maximum_distance - _traveled_distance, 0.0)
	var travel_distance := minf(projectile_speed * delta, remaining_distance)
	var start_position := global_position
	var finish_position := start_position + _direction * travel_distance
	advanced.emit(start_position, finish_position)
	if _impact_active:
		return
	global_position = finish_position
	_traveled_distance += travel_distance
	if _traveled_distance >= _maximum_distance:
		_impact_active = true
		expired.emit(global_position)
		queue_free()


func impact() -> void:
	if _impact_active:
		return
	_impact_active = true
	queue_free()
