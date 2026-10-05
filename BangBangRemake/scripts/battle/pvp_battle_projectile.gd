extends Node2D

signal advanced(start: Vector2, finish: Vector2)
signal impact_started(position: Vector2)
signal terrain_impact_started(position: Vector2)

const BULLET_FRAME_SIZE := Vector2(82.0, 129.0)
const BULLET_FRAME_COUNT := 4
const BULLET_FRAME_SECONDS := 0.06
const BULLET_SOURCE_ANGLE := -PI / 2.0

@export_range(100.0, 2000.0, 10.0) var projectile_speed := 720.0

@onready var _bullet_sprite: Sprite2D = $BulletSprite

var _direction := Vector2.RIGHT
var _maximum_distance := 480.0
var _traveled_distance := 0.0
var _animation_elapsed := 0.0
var _animation_frame := 0
var _impact_active := false


func configure(
	start_position: Vector2,
	direction: Vector2,
	maximum_distance: float
) -> void:
	global_position = start_position
	_direction = direction.normalized()
	if _direction.is_zero_approx():
		_direction = Vector2.RIGHT
	_maximum_distance = maxf(maximum_distance, 1.0)
	_traveled_distance = 0.0
	_animation_elapsed = 0.0
	_animation_frame = 0
	_impact_active = false
	rotation = _direction.angle() - BULLET_SOURCE_ANGLE
	_bullet_sprite.visible = true
	_apply_bullet_frame()


func _process(delta: float) -> void:
	if _impact_active:
		return
	var remaining_distance := maxf(
		_maximum_distance - _traveled_distance,
		0.0
	)
	var travel_distance := minf(
		projectile_speed * delta,
		remaining_distance
	)
	var start_position := global_position
	var next_position := start_position + _direction * travel_distance
	var collision := _find_collision(start_position, next_position)
	var segment_finish := next_position
	if not collision.is_empty():
		var hit_position: Variant = collision.get(
			"position",
			start_position
		)
		if hit_position is Vector2:
			segment_finish = hit_position
	advanced.emit(start_position, segment_finish)
	if _impact_active:
		return
	if not collision.is_empty():
		global_position = segment_finish
		impact(true)
		return
	global_position = next_position
	_traveled_distance = _traveled_distance + travel_distance
	_animation_elapsed = _animation_elapsed + delta
	while _animation_elapsed >= BULLET_FRAME_SECONDS:
		_animation_elapsed = _animation_elapsed - BULLET_FRAME_SECONDS
		_animation_frame = (_animation_frame + 1) % BULLET_FRAME_COUNT
		_apply_bullet_frame()
	if _traveled_distance >= _maximum_distance:
		impact()


func impact(hit_terrain := false) -> void:
	if _impact_active:
		return
	_impact_active = true
	_bullet_sprite.visible = false
	# PvpBattleMap chooses the exact source timeline: normal_bullet_blow for a
	# tank/range impact, and normal_bullet_blow02 for a terrain/wall impact.
	if hit_terrain:
		terrain_impact_started.emit(global_position)
	else:
		impact_started.emit(global_position)
	queue_free()


func _find_collision(
	from_position: Vector2,
	to_position: Vector2
) -> Dictionary:
	if from_position.is_equal_approx(to_position):
		return {}
	var query := PhysicsRayQueryParameters2D.create(
		from_position,
		to_position
	)
	query.collide_with_areas = true
	query.collide_with_bodies = true
	return get_world_2d().direct_space_state.intersect_ray(query)


func _apply_bullet_frame() -> void:
	_bullet_sprite.region_rect = Rect2(
		float(_animation_frame) * BULLET_FRAME_SIZE.x,
		0.0,
		BULLET_FRAME_SIZE.x,
		BULLET_FRAME_SIZE.y
	)
