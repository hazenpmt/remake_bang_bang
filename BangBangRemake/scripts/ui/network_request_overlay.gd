extends CanvasLayer

const LOGIN_SCENE := "res://scenes/auth/Login.tscn"
const SHOW_DELAY_SECONDS := 0.3

@onready var _blocker: Control = $Blocker
@onready var _dim: ColorRect = $Blocker/Dim
@onready var _content: Control = $Blocker/Content
@onready var _loading_bar: SwfTimelinePlayer = \
	$Blocker/Content/LoadingBarSpace/LoadingBar
@onready var _status: Label = $Blocker/Content/Status
@onready var _notification: Control = $Notification

var _active_requests: Dictionary = {}
var _visibility_generation := 0
var _session_dialog_open := false
var _last_critical_error := ""
var _last_critical_error_at := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_blocker.visible = false
	_dim.visible = false
	_content.visible = false
	GameSession.interactive_request_started.connect(_on_request_started)
	GameSession.interactive_request_finished.connect(_on_request_finished)
	GameSession.interactive_request_failed.connect(_on_request_failed)
	GameSession.session_expired.connect(_on_session_expired)
	_notification.confirmed.connect(_on_notification_confirmed)
	_notification.cancelled.connect(_on_notification_cancelled)


func _on_request_started(request_id: int, message: String) -> void:
	var was_empty := _active_requests.is_empty()
	_active_requests[request_id] = message
	_status.text = message
	# Block duplicate pointer input immediately. The visible loading art is
	# delayed so fast requests do not flash on screen.
	_blocker.visible = true
	if not was_empty:
		return
	_visibility_generation += 1
	_show_after_delay(_visibility_generation)


func _show_after_delay(generation: int) -> void:
	await get_tree().create_timer(
		SHOW_DELAY_SECONDS, true, false, true
	).timeout
	if generation != _visibility_generation or _active_requests.is_empty():
		return
	_dim.visible = true
	_content.visible = true
	_loading_bar.play()


func _on_request_finished(request_id: int) -> void:
	_active_requests.erase(request_id)
	if not _active_requests.is_empty():
		var remaining_ids := _active_requests.keys()
		_status.text = String(_active_requests[remaining_ids.back()])
		return
	_hide_loading()


func _hide_loading() -> void:
	_visibility_generation += 1
	_loading_bar.stop()
	_content.visible = false
	_dim.visible = false
	_blocker.visible = false


func _on_request_failed(_request_id: int, result: Dictionary) -> void:
	var status := int(result.get("status", 0))
	if status == 401:
		return
	# Validation/business errors stay in their feature panel. Only connection,
	# timeout, invalid response and server failures need a global modal.
	if status > 0 and status < 500:
		return
	var error: Dictionary = result.get("error", {})
	var message := String(error.get(
		"message", "Không thể hoàn tất yêu cầu với máy chủ."
	))
	var now := Time.get_ticks_msec()
	if message == _last_critical_error and now - _last_critical_error_at < 1000:
		return
	_last_critical_error = message
	_last_critical_error_at = now
	_notification.call("show_message", message, false, &"network_error")


func _on_session_expired(message: String) -> void:
	_hide_loading()
	_session_dialog_open = true
	_notification.call(
		"show_message",
		message + "\nVui lòng đăng nhập lại.",
		false,
		&"session_expired"
	)


func _on_notification_confirmed(context: Variant) -> void:
	if StringName(context) != &"session_expired":
		return
	_session_dialog_open = false
	if get_tree().current_scene == null:
		return
	if get_tree().current_scene.scene_file_path == LOGIN_SCENE:
		return
	get_tree().change_scene_to_file(LOGIN_SCENE)


func _on_notification_cancelled(context: Variant) -> void:
	if StringName(context) == &"session_expired":
		_on_notification_confirmed(context)


func active_request_count() -> int:
	return _active_requests.size()


func is_blocking_input() -> bool:
	return _blocker.visible


func is_loading_visible() -> bool:
	return _content.visible


func is_session_dialog_open() -> bool:
	return _session_dialog_open
