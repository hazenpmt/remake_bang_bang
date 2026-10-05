extends Control

const LOGIN_SCENE := "res://scenes/auth/Login.tscn"
const LOADING_SCENE := "res://scenes/loading/Loading.tscn"

@onready var position_label: Label = %PositionLabel
@onready var waiting_label: Label = %WaitingLabel
@onready var online_label: Label = %OnlineLabel
@onready var status_label: RichTextLabel = %StatusLabel
@onready var retry_button: Button = %RetryButton
@onready var cancel_button: Button = %CancelButton
@onready var poll_timer: Timer = %PollTimer
@onready var estimate_timer: Timer = %EstimateTimer

var _request_in_flight := false
var _estimated_wait_seconds := 0


func _ready() -> void:
	retry_button.pressed.connect(_join_queue)
	cancel_button.pressed.connect(_cancel_queue)
	poll_timer.timeout.connect(_poll_queue)
	estimate_timer.timeout.connect(_tick_estimated_wait)
	_join_queue()


func _join_queue() -> void:
	if _request_in_flight:
		return
	_set_requesting(true, "Đang kiểm tra sức chứa máy chủ...")
	var result: Dictionary = await GameSession.join_admission()
	_set_requesting(false, "")
	_handle_result(result)


func _poll_queue() -> void:
	if _request_in_flight:
		return
	_request_in_flight = true
	var result: Dictionary = await GameSession.get_admission_status()
	_request_in_flight = false
	_handle_result(result)


func _handle_result(result: Dictionary) -> void:
	if not result.get("ok", false):
		var error: Dictionary = result.get("error", {})
		_show_error(String(error.get("message", "Không kiểm tra được hàng chờ.")))
		return

	var admission: Dictionary = result.get("admission", {})
	var state := String(admission.get("state", "not_queued"))
	if state == "admitted":
		poll_timer.stop()
		estimate_timer.stop()
		_set_status_text("Đã có chỗ. Đang vào game...")
		position_label.text = ""
		waiting_label.text = ""
		GameSession.start_presence_heartbeat(
			float(admission.get("heartbeat_interval_seconds", 20))
		)
		get_tree().change_scene_to_file(LOADING_SCENE)
		return

	if state == "not_queued":
		estimate_timer.stop()
		_join_queue()
		return

	var position := int(admission.get("position", 0))
	var total_waiting := int(admission.get("total_waiting", 0))
	var online := int(admission.get("online", 0))
	var capacity := int(admission.get("capacity", 0))
	var countdown_active := bool(admission.get("disconnect_countdown_active", false))
	position_label.text = "STT: %d/%d" % [position, total_waiting]
	waiting_label.text = "Đang chờ: %d người" % total_waiting
	online_label.text = "Máy chủ: %d/%d người online" % [online, capacity]
	status_label.modulate = Color.WHITE
	if countdown_active:
		_estimated_wait_seconds = int(
			admission.get("disconnect_countdown_seconds", 0)
		)
		_render_disconnect_countdown()
		estimate_timer.start()
	else:
		_estimated_wait_seconds = 0
		estimate_timer.stop()
		_set_status_text("Máy chủ đang đầy. Đang chờ người chơi rời game...")
	retry_button.visible = false
	var poll_seconds := maxf(1.0, float(admission.get("poll_after_ms", 3000)) / 1000.0)
	poll_timer.start(poll_seconds)


func _format_wait_time(total_seconds: int) -> String:
	var safe_seconds := maxi(0, total_seconds)
	var minutes := safe_seconds / 60
	var seconds := safe_seconds % 60
	return "%02d:%02d" % [minutes, seconds]


func _tick_estimated_wait() -> void:
	_estimated_wait_seconds = maxi(0, _estimated_wait_seconds - 1)
	_render_disconnect_countdown()


func _render_disconnect_countdown() -> void:
	status_label.text = (
		"[center][color=#D1D5DA]Phát hiện người chơi mất kết nối. "
		+ "Giải phóng suất sau: [color=#D5A85E]%s[/color].[/color][/center]"
		% _format_wait_time(_estimated_wait_seconds)
	)


func _set_status_text(message: String) -> void:
	status_label.text = "[center]%s[/center]" % message


func _cancel_queue() -> void:
	poll_timer.stop()
	estimate_timer.stop()
	cancel_button.disabled = true
	_set_status_text("Đang rời hàng chờ...")
	await GameSession.logout()
	get_tree().change_scene_to_file(LOGIN_SCENE)


func _set_requesting(is_requesting: bool, message: String) -> void:
	_request_in_flight = is_requesting
	retry_button.disabled = is_requesting
	cancel_button.disabled = is_requesting
	if not message.is_empty():
		estimate_timer.stop()
		_set_status_text(message)
		status_label.modulate = Color.WHITE


func _show_error(message: String) -> void:
	poll_timer.stop()
	estimate_timer.stop()
	_set_status_text(message)
	status_label.modulate = Color(1.0, 0.55, 0.55)
	retry_button.visible = true
	retry_button.disabled = false
	cancel_button.disabled = false
