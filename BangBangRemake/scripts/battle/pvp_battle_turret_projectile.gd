extends Node2D

signal advanced(start: Vector2, finish: Vector2)
signal expired(position: Vector2)

const SOURCE_UP_ANGLE := -PI * 0.5
# Match PvpBattleTank exactly: both player tanks and NPC turrets use the
# original tank/fire/fire.png sheet, rather than the different bullet/fire.png
# file that happens to share the same filename.
const MUZZLE_FRAME_SIZE := Vector2(114.0, 150.0)
const MUZZLE_FRAME_COUNT := 5
const MUZZLE_FRAME_SECONDS := 0.035
const TAIL_FRAME_SIZE := Vector2(29.0, 65.0)
const TAIL_FRAME_COUNT := 4
const TAIL_FRAME_SECONDS := 0.05

const CANNON_BULLET := preload("res://assets/battle/projectiles/putong.png")
const MISSILE_BULLET := preload("res://assets/battle/projectiles/daodan.png")
const BLUE_TAIL := preload("res://assets/battle/projectiles/putong_blue.png")
const RED_TAIL := preload("res://assets/battle/projectiles/putong_red.png")

@export_range(100.0, 2000.0, 10.0) var projectile_speed := 720.0

@onready var _bullet_sprite: Sprite2D = $BulletSprite
@onready var _tail_sprite: Sprite2D = $TailSprite
@onready var _muzzle_flash: Sprite2D = $MuzzleFlash

var _direction := Vector2.RIGHT
var _maximum_distance := 480.0
var _traveled_distance := 0.0
var _tail_elapsed := 0.0
var _tail_frame := 0
var _muzzle_elapsed := 0.0
var _muzzle_frame := 0
var _impact_active := false


func configure(
	start_position: Vector2,
	direction: Vector2,
	maximum_distance: float,
	is_missile: bool,
	is_friendly_to_viewer: bool
) -> void:
	global_position = start_position
	_direction = direction.normalized()
	if _direction.is_zero_approx():
		_direction = Vector2.RIGHT
	_maximum_distance = maxf(maximum_distance, 1.0)
	_traveled_distance = 0.0
	_tail_elapsed = 0.0
	_tail_frame = 0
	_muzzle_elapsed = 0.0
	_muzzle_frame = 0
	_impact_active = false
	rotation = _direction.angle() - SOURCE_UP_ANGLE
	_bullet_sprite.texture = MISSILE_BULLET if is_missile else CANNON_BULLET
	_tail_sprite.texture = BLUE_TAIL if is_friendly_to_viewer else RED_TAIL
	_tail_sprite.position = Vector2(0.0, 58.0 if is_missile else 42.0)
	_tail_sprite.visible = true
	_bullet_sprite.visible = true
	_muzzle_flash.global_position = start_position
	_muzzle_flash.global_rotation = rotation
	_muzzle_flash.visible = true
	_apply_tail_frame()
	_apply_muzzle_frame()


func _process(delta: float) -> void:
	_update_muzzle_flash(delta)
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
	_update_tail(delta)
	if _traveled_distance >= _maximum_distance:
		_impact_active = true
		_bullet_sprite.visible = false
		_tail_sprite.visible = false
		expired.emit(global_position)
		queue_free()


func impact() -> void:
	if _impact_active:
		return
	_impact_active = true
	_bullet_sprite.visible = false
	_tail_sprite.visible = false
	queue_free()


func _update_tail(delta: float) -> void:
	_tail_elapsed += delta
	while _tail_elapsed >= TAIL_FRAME_SECONDS:
		_tail_elapsed -= TAIL_FRAME_SECONDS
		_tail_frame = (_tail_frame + 1) % TAIL_FRAME_COUNT
		_apply_tail_frame()


func _update_muzzle_flash(delta: float) -> void:
	if not _muzzle_flash.visible:
		return
	_muzzle_elapsed += delta
	while _muzzle_elapsed >= MUZZLE_FRAME_SECONDS:
		_muzzle_elapsed -= MUZZLE_FRAME_SECONDS
		_muzzle_frame += 1
		if _muzzle_frame >= MUZZLE_FRAME_COUNT:
			_muzzle_flash.visible = false
			return
		_apply_muzzle_frame()


func _apply_tail_frame() -> void:
	_tail_sprite.region_rect = Rect2(
		float(_tail_frame) * TAIL_FRAME_SIZE.x,
		0.0,
		TAIL_FRAME_SIZE.x,
		TAIL_FRAME_SIZE.y
	)


func _apply_muzzle_frame() -> void:
	_muzzle_flash.region_rect = Rect2(
		float(_muzzle_frame) * MUZZLE_FRAME_SIZE.x,
		0.0,
		MUZZLE_FRAME_SIZE.x,
		MUZZLE_FRAME_SIZE.y
	)
