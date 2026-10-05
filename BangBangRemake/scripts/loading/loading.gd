extends Control

const LOBBY_SCENE := "res://scenes/lobby/MainLobby.tscn"
const QUEUE_SCENE := "res://scenes/auth/AdmissionQueue.tscn"

@onready var loading_bar: SwfTimelinePlayer = %LoadingBar
@onready var percent_label: Label = %PercentLabel
@onready var status_label: Label = %StatusLabel
@onready var retry_button: Button = %RetryButton

var api_ready := false
var scene_ready := false
var load_failed := false
var loaded_scene: PackedScene


func _ready() -> void:
	retry_button.pressed.connect(_restart_loading)
	_restart_loading()


func _process(_delta: float) -> void:
	if load_failed or scene_ready:
		return

	var progress: Array = []
	var status := ResourceLoader.load_threaded_get_status(LOBBY_SCENE, progress)
	var scene_progress := 0.0
	if not progress.is_empty():
		scene_progress = float(progress[0])
	_set_progress(20.0 + scene_progress * 80.0)

	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			loaded_scene = ResourceLoader.load_threaded_get(LOBBY_SCENE)
			scene_ready = true
			_try_enter_lobby()
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_show_failure("Không thể tải tài nguyên sảnh.")


func _restart_loading() -> void:
	retry_button.visible = false
	load_failed = false
	api_ready = false
	scene_ready = false
	loaded_scene = null
	status_label.text = "Đang đồng bộ dữ liệu người chơi..."
	status_label.modulate = Color.WHITE
	_set_progress(0.0)

	var error := ResourceLoader.load_threaded_request(LOBBY_SCENE)
	if error != OK:
		_show_failure("Không thể bắt đầu tải tài nguyên sảnh.")
		return
	_load_player_data()


func _load_player_data() -> void:
	var result: Dictionary = await GameSession.fetch_lobby()
	if not result.get("ok", false):
		var error: Dictionary = result.get("error", {})
		if String(error.get("code", "")) == "ADMISSION_REQUIRED":
			get_tree().change_scene_to_file(QUEUE_SCENE)
			return
		_show_failure(String(error.get("message", "Không tải được dữ liệu người chơi.")))
		return
	api_ready = true
	status_label.text = "Đang khởi tạo sảnh chính..."
	_try_enter_lobby()


func _try_enter_lobby() -> void:
	if not api_ready or not scene_ready or loaded_scene == null:
		return
	_set_progress(100.0)
	status_label.text = "Hoàn tất"
	await get_tree().create_timer(0.15).timeout
	get_tree().change_scene_to_packed(loaded_scene)


func _set_progress(value: float) -> void:
	var progress := clampf(value, 0.0, 100.0)
	var frame_count := loading_bar.get_frame_count()
	if frame_count > 0:
		loading_bar.seek_frame(clampi(
			roundi(progress * float(frame_count - 1) / 100.0) + 1,
			1,
			frame_count
		))
	percent_label.text = "%d%%" % roundi(progress)


func _show_failure(message: String) -> void:
	load_failed = true
	status_label.text = message
	status_label.modulate = Color(1.0, 0.55, 0.55)
	retry_button.visible = true
