extends Control

signal requested
signal cancellation_requested
signal hover_changed(hovered: bool, anchor_global_rect: Rect2)

const COMPLETE_FIRST_FRAME := 1
const COMPLETE_LAST_FRAME := 13
const READY_FIRST_FRAME := 14
const READY_LAST_FRAME := 35
const COOLDOWN_FIRST_FRAME := 1
const COOLDOWN_LAST_FRAME := 60
const COOLDOWN_SOURCE_SECONDS := 60.0 / 24.0

@export_range(0.0, 60.0, 0.5) var cooldown_seconds := 5.0

@onready var _ready_effect: SwfTimelinePlayer = $ReadyEffect
@onready var _cooldown_effect: SwfTimelinePlayer = $CooldownEffect
@onready var _selected_effect: SwfTimelinePlayer = $SelectedEffect
@onready var _cooldown_label: Label = $CooldownLabel

var _cooldown_remaining := 0.0
var _channel_remaining := 0.0
var _channel_active := false
var _completion_playing := false
var _pointer_pressed := false
var _pointer_hovered := false
var _rest_position := Vector2.ZERO
var _targeting_active := false


func _ready() -> void:
	_rest_position = position
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)
	_ready_effect.frame_changed.connect(_on_ready_frame_changed)
	_selected_effect.pause()
	_selected_effect.visible = false
	reset_ready()


func activate() -> bool:
	if _cooldown_remaining > 0.0 or _completion_playing or _channel_active:
		return false
	if cooldown_seconds <= 0.0:
		reset_ready()
		return true
	_cooldown_remaining = cooldown_seconds
	_ready_effect.pause()
	_ready_effect.visible = false
	_cooldown_effect.visible = true
	_cooldown_effect.loop = false
	_cooldown_effect.playback_speed = (
		COOLDOWN_SOURCE_SECONDS / _cooldown_remaining
	)
	_cooldown_effect.play_range(
		COOLDOWN_FIRST_FRAME,
		COOLDOWN_LAST_FRAME
	)
	_cooldown_label.visible = true
	_update_cooldown_label()
	set_process(true)
	return true


func begin_channel_countdown(duration: float) -> bool:
	if not is_ready():
		return false
	_channel_active = true
	_channel_remaining = maxf(duration, 0.1)
	_targeting_active = false
	_set_selected_effect_visible(false)
	_ready_effect.pause()
	_ready_effect.visible = false
	_cooldown_effect.pause()
	_cooldown_effect.visible = false
	_cooldown_label.visible = true
	_update_remaining_label(_channel_remaining)
	set_process(false)
	_refresh_interaction_visual()
	return true


func update_channel_countdown(value: float) -> void:
	if not _channel_active:
		return
	_channel_remaining = maxf(value, 0.0)
	_update_remaining_label(_channel_remaining)


func finish_channel_and_start_cooldown() -> bool:
	if not _channel_active:
		return false
	_channel_active = false
	_channel_remaining = 0.0
	return activate()


func cancel_channel_countdown() -> void:
	if not _channel_active:
		return
	_channel_active = false
	_channel_remaining = 0.0
	reset_ready()


func set_cooldown_seconds(value: float) -> void:
	cooldown_seconds = maxf(value, 0.0)


func is_ready() -> bool:
	return (
		_cooldown_remaining <= 0.0
		and not _completion_playing
		and not _channel_active
	)


func get_remaining_seconds() -> float:
	if _channel_active:
		return _channel_remaining
	return _cooldown_remaining


func sync_cooldown_remaining(value: float) -> void:
	# Online PvP cooldowns are server-owned. This updates only the HUD/runtime
	# countdown; it never makes a client command authoritative.
	if _channel_active:
		return
	var remaining := maxf(value, 0.0)
	if remaining <= 0.0:
		if _cooldown_remaining > 0.0 or _completion_playing:
			reset_ready()
		return
	var was_cooling := _cooldown_remaining > 0.0 and _cooldown_effect.visible
	_cooldown_remaining = remaining
	_completion_playing = false
	_targeting_active = false
	_set_selected_effect_visible(false)
	_ready_effect.pause()
	_ready_effect.visible = false
	_cooldown_effect.visible = true
	_cooldown_effect.loop = false
	_cooldown_effect.playback_speed = (
		COOLDOWN_SOURCE_SECONDS / maxf(_cooldown_remaining, 0.1)
	)
	if not was_cooling:
		_cooldown_effect.play_range(COOLDOWN_FIRST_FRAME, COOLDOWN_LAST_FRAME)
	_cooldown_label.visible = true
	_update_cooldown_label()
	set_process(true)
	_refresh_interaction_visual()


func set_targeting_active(value: bool) -> void:
	_targeting_active = value
	_set_selected_effect_visible(value)
	_refresh_interaction_visual()


func reset_ready() -> void:
	_cooldown_remaining = 0.0
	_channel_remaining = 0.0
	_channel_active = false
	_completion_playing = false
	_cooldown_effect.pause()
	_cooldown_effect.visible = false
	_cooldown_label.visible = false
	_set_selected_effect_visible(false)
	_ready_effect.visible = true
	_ready_effect.loop = true
	_ready_effect.play_range(READY_FIRST_FRAME, READY_LAST_FRAME)
	set_process(false)
	_refresh_interaction_visual()


func _process(delta: float) -> void:
	if _cooldown_remaining <= 0.0:
		set_process(false)
		return
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)
	_update_cooldown_label()
	if _cooldown_remaining <= 0.0:
		_finish_cooldown()


func _finish_cooldown() -> void:
	_cooldown_effect.pause()
	_cooldown_effect.visible = false
	_cooldown_label.visible = false
	_completion_playing = true
	_ready_effect.visible = true
	_ready_effect.loop = false
	_ready_effect.play_range(
		COMPLETE_FIRST_FRAME,
		COMPLETE_LAST_FRAME
	)
	set_process(false)


func _update_cooldown_label() -> void:
	_update_remaining_label(_cooldown_remaining)


func _update_remaining_label(value: float) -> void:
	var displayed_value := maxf(ceilf(value * 10.0) / 10.0, 0.1)
	_cooldown_label.text = "%.1f" % displayed_value


func _set_selected_effect_visible(value: bool) -> void:
	if not is_instance_valid(_selected_effect):
		return
	_selected_effect.visible = value
	if value:
		_selected_effect.loop = true
		_selected_effect.play_range(1, _selected_effect.get_frame_count())
	else:
		_selected_effect.pause()


func _on_ready_frame_changed(frame_number: int) -> void:
	if not _completion_playing or frame_number < COMPLETE_LAST_FRAME:
		return
	_completion_playing = false
	_ready_effect.loop = true
	_ready_effect.play_range(READY_FIRST_FRAME, READY_LAST_FRAME)
	_refresh_interaction_visual()


func _on_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		if (
			mouse_event.button_index == MOUSE_BUTTON_RIGHT
			and mouse_event.pressed
		):
			cancellation_requested.emit()
		accept_event()
		return
	if mouse_event.pressed:
		_pointer_pressed = true
		_refresh_interaction_visual()
		# Emit on the press itself.  The former release-only behavior could be
		# missed when the viewport receives the release first, making HUD clicks
		# look inert even though the hotkeys still worked.
		requested.emit()
		accept_event()
		return
	_pointer_pressed = false
	_refresh_interaction_visual()
	accept_event()


func _on_mouse_entered() -> void:
	_pointer_hovered = true
	_refresh_interaction_visual()
	hover_changed.emit(true, get_global_rect())


func _on_mouse_exited() -> void:
	_pointer_hovered = false
	_refresh_interaction_visual()
	hover_changed.emit(false, get_global_rect())


func _refresh_interaction_visual() -> void:
	if not is_inside_tree():
		return
	position = _rest_position + (Vector2(0, 1) if _pointer_pressed else Vector2.ZERO)
	if _targeting_active:
		self_modulate = Color.WHITE
	elif is_ready() and _pointer_hovered:
		self_modulate = Color(1.12, 1.12, 1.12, 1.0)
	else:
		self_modulate = Color.WHITE
