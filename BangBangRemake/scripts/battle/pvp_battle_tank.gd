extends Node2D

const SUPPORTED_TANK_KEY := "gangtiexia03"
const BODY_FRAME_SIZE := Vector2(150.0, 150.0)
const BODY_DIRECTION_UP := 0
const BODY_DIRECTION_LEFT := 6
const BODY_DIRECTION_RIGHT := 2
const BODY_DIRECTION_DOWN := 4
const BODY_ANIMATION_FRAME := 0
const CANNON_SOURCE_ANGLE := -PI / 2.0
const DIRECTION_ANGLE_STEP := PI / 4.0
const TURN_FINISH_EPSILON := PI / 720.0
const MOVE_FRAME_SECONDS := 0.12
const MUZZLE_DISTANCE := 48.0
const MUZZLE_FRAME_SIZE := Vector2(114.0, 150.0)
const MUZZLE_FRAME_COUNT := 5
const MUZZLE_FRAME_SECONDS := 0.035
const CANNON_RECOIL_FRAME_SECONDS := 1.0 / 24.0
const CANNON_RECOIL_OFFSETS := [
	0.0,
	0.0,
	0.0,
	20.0,
	20.0,
	16.0,
	12.0,
	8.0,
	4.0,
	0.0,
]
const WORLD_HP_GREEN_PATH := "res://assets/battle/hud/life_green.png"
const WORLD_HP_RED_PATH := "res://assets/battle/hud/life_red.png"
const WORLD_HP_FILL_WIDTH := 66.0
const WORLD_HP_PER_SEGMENT := 500
const WORLD_HP_DIVIDER_COLOR := Color(0.02, 0.12, 0.03, 0.88)
const LOW_HEALTH_WARNING_RATIO := 0.25
const TANK_HURT_WARNING_RATIO := 0.35
const FRIENDLY_NAME_COLOR := Color("28ff28")
const HOSTILE_NAME_COLOR := Color("ff2020")

@export_range(360.0, 1440.0, 15.0) var turn_max_speed_degrees := 1080.0
@export_range(2000.0, 20000.0, 100.0) var turn_acceleration_degrees := 12000.0
@export_range(0.0, 10.0, 0.5) var direction_hysteresis_degrees := 5.0

@onready var _body: Sprite2D = $Body
@onready var _cannon: Sprite2D = $Cannon
@onready var _muzzle_flash: Sprite2D = $MuzzleFlash
@onready var _self_mark: SwfTimelinePlayer = $SelfMark
@onready var _world_hp_fill_clip: Control = \
	$PlayerStatus/HpFillClip
@onready var _world_hp_fill: TextureRect = \
	$PlayerStatus/HpFillClip/Fill
@onready var _world_hp_dividers: Control = \
	$PlayerStatus/HpFillClip/Dividers
@onready var _world_low_health_warning: SwfTimelinePlayer = \
	$LowHealthWarning
@onready var _world_tank_hurt: SwfTimelinePlayer = $TankHurt
var _world_hp_red: Texture2D
var _world_hp_green: Texture2D
@onready var _world_name: Label = $PlayerStatus/Name
@onready var _world_vip: Label = $PlayerStatus/VipPlaceholder

var _body_direction := BODY_DIRECTION_RIGHT
var _target_body_direction := BODY_DIRECTION_RIGHT
var _last_turn_step := -1
var _active_opposite_turn_step := 0
var _last_opposite_start_direction := -1
var _last_opposite_target_direction := -1
var _last_opposite_turn_step := 0
var _body_angle := 0.0
var _turn_velocity := 0.0
var _animation_frame := BODY_ANIMATION_FRAME
var _animation_elapsed := 0.0
var _cannon_world_angle := 0.0
var _muzzle_frame := 0
var _muzzle_elapsed := 0.0
var _cannon_recoil_frame := 0
var _cannon_recoil_elapsed := 0.0
var _cannon_recoil_active := false
var _world_hp_divider_segment_count := -1


func configure(tank_key: String, _skin_key: String, team_no: int) -> void:
	_world_hp_green = load(WORLD_HP_GREEN_PATH) as Texture2D
	_world_hp_red = load(WORLD_HP_RED_PATH) as Texture2D
	var resolved_tank_key := tank_key.strip_edges()
	if resolved_tank_key.is_empty():
		resolved_tank_key = SUPPORTED_TANK_KEY
	visible = resolved_tank_key == SUPPORTED_TANK_KEY
	if not visible:
		push_warning(
			"Battle Tank source is not mapped yet: %s" % resolved_tank_key
		)
		return
	var faces_right: bool = team_no != 2
	var body_direction: int = BODY_DIRECTION_RIGHT
	if not faces_right:
		body_direction = BODY_DIRECTION_LEFT
	_body_direction = body_direction
	_target_body_direction = body_direction
	_last_turn_step = -1
	_active_opposite_turn_step = 0
	_last_opposite_start_direction = -1
	_last_opposite_target_direction = -1
	_last_opposite_turn_step = 0
	_body_angle = _body_direction_angle(body_direction)
	_turn_velocity = 0.0
	_animation_frame = BODY_ANIMATION_FRAME
	_animation_elapsed = 0.0
	_body.rotation = 0.0
	_muzzle_flash.visible = false
	_muzzle_frame = 0
	_muzzle_elapsed = 0.0
	_cannon_recoil_frame = 0
	_cannon_recoil_elapsed = 0.0
	_cannon_recoil_active = false
	_cannon.position = Vector2.ZERO
	_self_mark.pause()
	_self_mark.seek_frame(1)
	_self_mark.visible = false
	_world_name.text = "Người chơi"
	_world_vip.text = ""
	_world_vip.visible = false
	_world_tank_hurt.pause()
	_world_tank_hurt.seek_frame(1)
	_world_tank_hurt.visible = false
	set_body_frame(_body_direction, _animation_frame)
	set_cannon_angle(_body_direction_angle(_body_direction))


func set_local_controlled(enabled: bool) -> void:
	_self_mark.visible = enabled
	if enabled:
		set_hostile(false)
		_self_mark.loop = true
		_self_mark.play_range(1, _self_mark.get_frame_count())
	else:
		_self_mark.pause()
		_self_mark.seek_frame(1)


func set_hostile(hostile: bool) -> void:
	if hostile:
		if _world_hp_red != null:
			_world_hp_fill.texture = _world_hp_red
		_world_name.add_theme_color_override(
			"font_color",
			HOSTILE_NAME_COLOR
		)
	else:
		if _world_hp_green != null:
			_world_hp_fill.texture = _world_hp_green
		_world_name.add_theme_color_override(
			"font_color",
			FRIENDLY_NAME_COLOR
		)


func set_player_identity(
	display_name: String,
	vip_level: int = 0
) -> void:
	var resolved_name := display_name.strip_edges()
	if resolved_name.is_empty():
		resolved_name = "Người chơi"
	_world_name.text = resolved_name
	if vip_level > 0:
		_world_vip.visible = true
		_world_vip.text = "V%d" % vip_level
	else:
		_world_vip.visible = false
		_world_vip.text = ""


func set_health(current_value: int, maximum_value: int) -> void:
	var safe_maximum := maxi(maximum_value, 1)
	var safe_current := clampi(current_value, 0, safe_maximum)
	_update_world_hp_dividers(safe_maximum)
	var ratio := clampf(
		float(safe_current)
		/ float(safe_maximum),
		0.0,
		1.0
	)
	_world_hp_fill_clip.size = Vector2(
		WORLD_HP_FILL_WIDTH * ratio,
		_world_hp_fill_clip.size.y
	)
	# Keep the original ui/life_warn.swf border continuously visible for every
	# tank at <= 25%; it is hidden only after recovering above the threshold.
	var should_show_low_health_warning := (
		safe_current > 0 and ratio <= LOW_HEALTH_WARNING_RATIO
	)
	if should_show_low_health_warning:
		if not _world_low_health_warning.visible:
			_world_low_health_warning.seek_frame(1)
	_world_low_health_warning.pause()
	_world_low_health_warning.visible = should_show_low_health_warning
	# Original event/tank_hurt.swf: the smoke/damage shell begins at <=35% HP
	# and clears only after recovering above that threshold (including revive).
	var should_show_tank_hurt := (
		safe_current > 0 and ratio <= TANK_HURT_WARNING_RATIO
	)
	var was_tank_hurt_visible := _world_tank_hurt.visible
	_world_tank_hurt.visible = should_show_tank_hurt
	if should_show_tank_hurt:
		if not was_tank_hurt_visible:
			_world_tank_hurt.seek_frame(1)
			_world_tank_hurt.play_range(1, _world_tank_hurt.get_frame_count())
	else:
		_world_tank_hurt.pause()
		_world_tank_hurt.seek_frame(1)


func _update_world_hp_dividers(maximum_health: int) -> void:
	if not is_instance_valid(_world_hp_dividers):
		return
	# Do not cap the logical segment count: tougher tanks always have more
	# health divisions.  Repeated sub-pixel positions are skipped below because
	# the original bar is only 66 pixels wide.
	var segment_count := maxi(
		ceili(float(maximum_health) / float(WORLD_HP_PER_SEGMENT)),
		1
	)
	if segment_count == _world_hp_divider_segment_count:
		return
	_world_hp_divider_segment_count = segment_count
	for child: Node in _world_hp_dividers.get_children():
		child.queue_free()
	var last_divider_x := -1
	for divider_index in range(1, segment_count):
		var divider_x := roundi(
			WORLD_HP_FILL_WIDTH
			* float(divider_index)
			/ float(segment_count)
		)
		if divider_x == last_divider_x:
			continue
		last_divider_x = divider_x
		var divider := ColorRect.new()
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		divider.color = WORLD_HP_DIVIDER_COLOR
		divider.position = Vector2(divider_x, 0.0)
		# The divider starts at the fill's upper boundary, matching the
		# original bar and extends well past its midpoint.
		divider.size = Vector2(1.0, 6.0)
		_world_hp_dividers.add_child(divider)


func update_movement(
	movement_direction: Vector2,
	delta: float,
	force_turn_target: bool = false,
	hold_body_direction: bool = false,
	requested_facing_direction: Variant = null
) -> Vector2:
	_update_cannon_recoil(delta)
	_update_muzzle_flash(delta)
	var facing_direction: Vector2 = movement_direction
	if requested_facing_direction is Vector2:
		facing_direction = requested_facing_direction
	var has_facing_input := not facing_direction.is_zero_approx()
	if hold_body_direction:
		# Opposing keys pause the body without discarding the last committed
		# target. Releasing one of them can therefore resume toward the remaining
		# direction instead of inventing a new route.
		_turn_velocity = 0.0
		_animation_frame = BODY_ANIMATION_FRAME
		_animation_elapsed = 0.0
		set_body_frame(_body_direction, _animation_frame)
		return Vector2.ZERO
	if not has_facing_input:
		# Releasing movement stops displacement, not the committed body turn.
		# A quick tap must continue to its selected direction like the source game.
		_advance_body_turn(delta)
		_animation_frame = BODY_ANIMATION_FRAME
		_animation_elapsed = 0.0
		set_body_frame(_body_direction, _animation_frame)
		return Vector2.ZERO
	var requested_direction := _direction_index_from_vector(
		facing_direction
	)
	if (
		requested_direction != _target_body_direction
		or force_turn_target
	):
		if requested_direction != _target_body_direction:
			_set_turn_target(requested_direction)
	_advance_body_turn(delta)
	var is_moving := not movement_direction.is_zero_approx()
	if not is_moving:
		_animation_frame = BODY_ANIMATION_FRAME
		_animation_elapsed = 0.0
		set_body_frame(_body_direction, _animation_frame)
		return Vector2.ZERO
	_animation_elapsed = _animation_elapsed + delta
	if _animation_elapsed >= MOVE_FRAME_SECONDS:
		_animation_elapsed = fmod(_animation_elapsed, MOVE_FRAME_SECONDS)
		_animation_frame = 1 - _animation_frame
	set_body_frame(_body_direction, _animation_frame)
	return movement_direction.normalized()


func _freeze_body_turn() -> void:
	_target_body_direction = _body_direction
	_body_angle = _body_direction_angle(_body_direction)
	_turn_velocity = 0.0
	_clear_opposite_route_memory()


func aim_cannon_at(world_position: Vector2) -> void:
	var aim_direction := world_position - global_position
	if aim_direction.is_zero_approx():
		return
	set_cannon_angle(aim_direction.angle())


func fire() -> Dictionary:
	var shot_direction := Vector2.RIGHT.rotated(_cannon_world_angle)
	var shot_position := (
		global_position
		+ _cannon.position
		+ shot_direction * MUZZLE_DISTANCE
	)
	_start_cannon_recoil()
	_start_muzzle_flash()
	return {
		"position": shot_position,
		"direction": shot_direction,
	}


func _start_cannon_recoil() -> void:
	_cannon_recoil_frame = 0
	_cannon_recoil_elapsed = 0.0
	_cannon_recoil_active = true
	_apply_cannon_recoil_frame()


func _update_cannon_recoil(delta: float) -> void:
	if not _cannon_recoil_active:
		return
	_cannon_recoil_elapsed = _cannon_recoil_elapsed + delta
	while _cannon_recoil_elapsed >= CANNON_RECOIL_FRAME_SECONDS:
		_cannon_recoil_elapsed = (
			_cannon_recoil_elapsed
			- CANNON_RECOIL_FRAME_SECONDS
		)
		_cannon_recoil_frame = _cannon_recoil_frame + 1
		if _cannon_recoil_frame >= CANNON_RECOIL_OFFSETS.size():
			_cannon_recoil_active = false
			_cannon_recoil_frame = 0
			_cannon.position = Vector2.ZERO
			_update_muzzle_transform()
			return
		_apply_cannon_recoil_frame()


func _apply_cannon_recoil_frame() -> void:
	var recoil_offset: float = CANNON_RECOIL_OFFSETS[
		_cannon_recoil_frame
	]
	var shot_direction := Vector2.RIGHT.rotated(_cannon_world_angle)
	_cannon.position = -shot_direction * recoil_offset
	_update_muzzle_transform()


func _start_muzzle_flash() -> void:
	_muzzle_frame = 0
	_muzzle_elapsed = 0.0
	_muzzle_flash.visible = true
	_apply_muzzle_frame()
	_update_muzzle_transform()


func _update_muzzle_flash(delta: float) -> void:
	if not _muzzle_flash.visible:
		return
	_muzzle_elapsed = _muzzle_elapsed + delta
	while _muzzle_elapsed >= MUZZLE_FRAME_SECONDS:
		_muzzle_elapsed = _muzzle_elapsed - MUZZLE_FRAME_SECONDS
		_muzzle_frame = _muzzle_frame + 1
		if _muzzle_frame >= MUZZLE_FRAME_COUNT:
			_muzzle_flash.visible = false
			return
		_apply_muzzle_frame()


func _apply_muzzle_frame() -> void:
	_muzzle_flash.region_rect = Rect2(
		float(_muzzle_frame) * MUZZLE_FRAME_SIZE.x,
		0.0,
		MUZZLE_FRAME_SIZE.x,
		MUZZLE_FRAME_SIZE.y
	)


func _update_muzzle_transform() -> void:
	var muzzle_direction := Vector2.RIGHT.rotated(_cannon_world_angle)
	_muzzle_flash.position = (
		_cannon.position
		+ muzzle_direction * MUZZLE_DISTANCE
	)
	_muzzle_flash.rotation = _cannon_world_angle - CANNON_SOURCE_ANGLE


func _set_turn_target(requested_direction: int) -> void:
	var safe_direction := posmod(requested_direction, 8)
	if _can_reverse_active_opposite_turn(safe_direction):
		_reverse_active_opposite_turn(safe_direction)
		return
	var current_direction := _body_direction
	_active_opposite_turn_step = 0
	if posmod(safe_direction - current_direction, 8) == 4:
		_active_opposite_turn_step = _choose_opposite_turn_step(
			current_direction,
			safe_direction
		)
		_last_opposite_start_direction = current_direction
		_last_opposite_target_direction = safe_direction
		_last_opposite_turn_step = _active_opposite_turn_step
	else:
		_clear_opposite_route_memory()
	_target_body_direction = safe_direction


func _can_reverse_active_opposite_turn(
	requested_direction: int
) -> bool:
	return (
		_active_opposite_turn_step != 0
		and _target_body_direction
			== _last_opposite_target_direction
		and requested_direction
			== _last_opposite_start_direction
	)


func _reverse_active_opposite_turn(
	requested_direction: int
) -> void:
	var previous_start := _last_opposite_start_direction
	_last_opposite_start_direction = (
		_last_opposite_target_direction
	)
	_last_opposite_target_direction = previous_start
	_active_opposite_turn_step = -_last_opposite_turn_step
	_last_opposite_turn_step = _active_opposite_turn_step
	_turn_velocity = -_turn_velocity
	_target_body_direction = posmod(requested_direction, 8)


func _is_body_turn_finished() -> bool:
	if _body_direction != _target_body_direction:
		return false
	var target_angle := _body_direction_angle(_target_body_direction)
	var angular_error := wrapf(target_angle - _body_angle, -PI, PI)
	return (
		absf(angular_error) <= TURN_FINISH_EPSILON
		and is_zero_approx(_turn_velocity)
	)


func _advance_body_turn(delta: float) -> void:
	var target_angle := _body_direction_angle(_target_body_direction)
	var angular_error := _signed_turn_error(target_angle)
	if absf(angular_error) <= TURN_FINISH_EPSILON:
		_body_angle = target_angle
		_turn_velocity = 0.0
		_update_rendered_body_direction()
		return
	var acceleration := deg_to_rad(turn_acceleration_degrees)
	var max_speed := deg_to_rad(turn_max_speed_degrees)
	var braking_speed := sqrt(
		maxf(2.0 * acceleration * absf(angular_error), 0.0)
	)
	var desired_velocity := (
		signf(angular_error)
		* minf(max_speed, braking_speed)
	)
	_turn_velocity = move_toward(
		_turn_velocity,
		desired_velocity,
		acceleration * delta
	)
	var angle_step := _turn_velocity * delta
	if (
		signf(angle_step) == signf(angular_error)
		and absf(angle_step) >= absf(angular_error)
	):
		_body_angle = target_angle
		_turn_velocity = 0.0
	else:
		_body_angle = fposmod(_body_angle + angle_step, TAU)
	if not is_zero_approx(_turn_velocity):
		_last_turn_step = 1 if _turn_velocity > 0.0 else -1
	_update_rendered_body_direction()


func _signed_turn_error(target_angle: float) -> float:
	var angular_error := wrapf(target_angle - _body_angle, -PI, PI)
	if is_equal_approx(absf(angular_error), PI):
		var opposite_step := _active_opposite_turn_step
		if opposite_step == 0:
			opposite_step = _last_turn_step
		if opposite_step == 0:
			opposite_step = -1
		return float(opposite_step) * PI
	return angular_error


func _update_rendered_body_direction() -> void:
	var rendered_angle := _body_direction_angle(_body_direction)
	var rendered_error := wrapf(
		_body_angle - rendered_angle,
		-PI,
		PI
	)
	var switch_threshold := (
		DIRECTION_ANGLE_STEP * 0.5
		+ deg_to_rad(direction_hysteresis_degrees)
	)
	if absf(rendered_error) < switch_threshold:
		return
	var direction_step := 1 if rendered_error > 0.0 else -1
	_body_direction = posmod(_body_direction + direction_step, 8)
	set_body_frame(_body_direction, _animation_frame)


func _choose_opposite_turn_step(
	current_direction: int,
	requested_direction: int
) -> int:
	if (
		current_direction == _last_opposite_target_direction
		and requested_direction == _last_opposite_start_direction
		and _last_opposite_turn_step != 0
	):
		return -_last_opposite_turn_step
	if (
		current_direction == BODY_DIRECTION_UP
		and requested_direction == BODY_DIRECTION_DOWN
	):
		return 1
	if (
		current_direction == BODY_DIRECTION_DOWN
		and requested_direction == BODY_DIRECTION_UP
	):
		return -1
	return -1


func _clear_opposite_route_memory() -> void:
	_active_opposite_turn_step = 0
	_last_opposite_start_direction = -1
	_last_opposite_target_direction = -1
	_last_opposite_turn_step = 0


func set_body_frame(direction_index: int, animation_frame: int) -> void:
	var safe_direction := posmod(direction_index, 8)
	var safe_frame := clampi(animation_frame, 0, 1)
	_body.region_rect = Rect2(
		float(safe_frame) * BODY_FRAME_SIZE.x,
		float(safe_direction) * BODY_FRAME_SIZE.y,
		BODY_FRAME_SIZE.x,
		BODY_FRAME_SIZE.y
	)


func set_cannon_angle(world_angle: float) -> void:
	_cannon_world_angle = world_angle
	_cannon.rotation = world_angle - CANNON_SOURCE_ANGLE
	if _cannon_recoil_active:
		_apply_cannon_recoil_frame()
	else:
		_update_muzzle_transform()


func _direction_index_from_vector(direction: Vector2) -> int:
	if direction.is_zero_approx():
		return _body_direction
	var direction_octant := roundi(
		direction.angle() / DIRECTION_ANGLE_STEP
	)
	return posmod(
		direction_octant + BODY_DIRECTION_RIGHT,
		8
	)


func _body_direction_angle(direction_index: int) -> float:
	return fposmod(
		float(direction_index - BODY_DIRECTION_RIGHT) * PI / 4.0,
		TAU
	)
