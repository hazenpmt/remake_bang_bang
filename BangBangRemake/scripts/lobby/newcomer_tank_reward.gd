extends Control

signal reward_claimed(lobby_data: Dictionary)

const INTRO_FIRST_FRAME := 1
const INTRO_LAST_FRAME := 97
const IDLE_FIRST_FRAME := 80
const IDLE_LAST_FRAME := 97
const SKILL_REVEAL_FRAMES := [61, 64, 67]

@onready var _animation: SwfTimelinePlayer = $Stage/Animation
@onready var _tank_name: Label = $Stage/TankName
@onready var _ok_button: Button = $Stage/BtnOk
@onready var _skill_icons: Array[TextureRect] = [
	$Stage/Skill1,
	$Stage/Skill2,
	$Stage/Skill3,
]

var _intro_finished := false
var _claiming := false


func _ready() -> void:
	visible = false
	_animation.frame_changed.connect(_on_animation_frame_changed)
	_ok_button.pressed.connect(_on_ok_pressed)


func show_reward(reward_data: Dictionary) -> void:
	_tank_name.text = String(reward_data.get("tank_name", "Iron Man"))
	_intro_finished = false
	_claiming = false
	_ok_button.disabled = false
	_sync_skill_icons(0)
	visible = true
	_animation.play_range(INTRO_FIRST_FRAME, INTRO_LAST_FRAME)


func _on_animation_frame_changed(frame_number: int) -> void:
	_sync_skill_icons(frame_number)
	if _intro_finished or frame_number < INTRO_LAST_FRAME:
		return
	_intro_finished = true
	call_deferred("_start_idle_loop")


func _sync_skill_icons(frame_number: int) -> void:
	for index in _skill_icons.size():
		_skill_icons[index].visible = frame_number >= SKILL_REVEAL_FRAMES[index]


func _start_idle_loop() -> void:
	if visible:
		_animation.play_range(IDLE_FIRST_FRAME, IDLE_LAST_FRAME)


func _on_ok_pressed() -> void:
	if _claiming:
		return
	_claiming = true
	_ok_button.disabled = true
	var game_session := get_node_or_null("/root/GameSession")
	if game_session == null:
		_claiming = false
		_ok_button.disabled = false
		push_warning("Không tìm thấy phiên kết nối máy chủ.")
		return
	var result: Dictionary = await game_session.call("claim_newcomer_tank")
	if not result.get("ok", false):
		_claiming = false
		_ok_button.disabled = false
		var error_value: Variant = result.get("error", {})
		var message := "Không thể xác nhận quà Tank tân thủ."
		if error_value is Dictionary:
			message = String(error_value.get("message", message))
		push_warning(message)
		return

	_animation.pause()
	visible = false
	_claiming = false
	var lobby_value: Variant = game_session.get("lobby_data")
	var lobby_data: Dictionary = (
		lobby_value.duplicate(true)
		if lobby_value is Dictionary
		else {}
	)
	reward_claimed.emit(lobby_data)
