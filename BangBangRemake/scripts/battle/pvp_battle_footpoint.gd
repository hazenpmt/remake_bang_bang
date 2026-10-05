extends Node2D

const BODY_FRAME_SIZE := Vector2(150.0, 150.0)
const BODY_FRAME_COUNT := 6
const BODY_DIRECTION_RIGHT := 2
const DIRECTION_ANGLE_STEP := PI / 4.0
const MOVE_FRAME_SECONDS := 0.08
const WORLD_HP_FILL_WIDTH := 66.0
const WANDER_PADDING := 36.0
const WANDER_RESELECT_SECONDS := 2.0

@onready var _body: Sprite2D = $Body
@onready var _cannon: Sprite2D = $Cannon
@onready var _health_fill_clip: Control = $NeutralHealth/FillClip

var _direction_index := BODY_DIRECTION_RIGHT
var _animation_frame := 0
var _animation_elapsed := 0.0
var _wander_target := Vector2.ZERO
var _wander_remaining := 0.0
var _random := RandomNumberGenerator.new()


func configure(spawner_id: int) -> void:
	_random.seed = 0xF00D0000 + spawner_id
	_direction_index = BODY_DIRECTION_RIGHT if spawner_id == 47 else 6
	_animation_frame = 0
	_animation_elapsed = 0.0
	_wander_remaining = 0.0
	_set_body_frame()
	_cannon.rotation = _direction_angle(_direction_index) + PI / 2.0
	set_health(80, 80)


func set_health(current_value: int, maximum_value: int) -> void:
	var safe_maximum := maxi(maximum_value, 1)
	var ratio := clampf(float(current_value) / float(safe_maximum), 0.0, 1.0)
	_health_fill_clip.size.x = WORLD_HP_FILL_WIDTH * ratio


func get_wander_direction(roam_rect: Rect2, delta: float) -> Vector2:
	_wander_remaining = maxf(_wander_remaining - delta, 0.0)
	if (
		_wander_remaining <= 0.0
		or global_position.distance_to(_wander_target) <= 18.0
	):
		var inner := roam_rect.grow(-WANDER_PADDING)
		_wander_target = Vector2(
			_random.randf_range(inner.position.x, inner.end.x),
			_random.randf_range(inner.position.y, inner.end.y)
		)
		_wander_remaining = WANDER_RESELECT_SECONDS
	var direction := _wander_target - global_position
	return Vector2.ZERO if direction.is_zero_approx() else direction.normalized()


func update_movement(movement_direction: Vector2, delta: float) -> void:
	if movement_direction.is_zero_approx():
		_animation_frame = 0
		_animation_elapsed = 0.0
		_set_body_frame()
		return
	_direction_index = _direction_index_from_vector(movement_direction)
	_animation_elapsed += delta
	if _animation_elapsed >= MOVE_FRAME_SECONDS:
		_animation_elapsed = fmod(_animation_elapsed, MOVE_FRAME_SECONDS)
		_animation_frame = (_animation_frame + 1) % BODY_FRAME_COUNT
	_set_body_frame()
	# Component 1503 is the original Footpoint head. It follows the creature's
	# travel direction; this monster has no separate ranged-fire animation.
	_cannon.rotation = movement_direction.angle() + PI / 2.0


func _set_body_frame() -> void:
	_body.region_rect = Rect2(
		float(_animation_frame) * BODY_FRAME_SIZE.x,
		float(_direction_index) * BODY_FRAME_SIZE.y,
		BODY_FRAME_SIZE.x,
		BODY_FRAME_SIZE.y
	)


func _direction_index_from_vector(direction: Vector2) -> int:
	var octant := roundi(direction.angle() / DIRECTION_ANGLE_STEP)
	return posmod(octant + BODY_DIRECTION_RIGHT, 8)


func _direction_angle(direction_index: int) -> float:
	return float(posmod(direction_index - BODY_DIRECTION_RIGHT, 8)) * DIRECTION_ANGLE_STEP
