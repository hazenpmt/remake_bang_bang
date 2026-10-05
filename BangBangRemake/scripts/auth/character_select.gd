extends Control

const CHARACTER_ROSTER_SCENE := "res://scenes/auth/CharacterRoster.tscn"
const ACTIVE_FIRST_FRAME := 14
const ACTIVE_LAST_FRAME := 91
const RESERVED_CHARACTER_NAMES := [
	"admin",
	"administrator",
	"gm",
	"gamemaster",
	"mod",
	"moderator",
	"system",
	"hethong",
	"hệthống",
	"quantri",
	"quảntrị",
]

var selected_gender := "male"
var _display_name_pattern := RegEx.new()

@onready var name_input: LineEdit = %CharacterName
@onready var status_label: Label = %StatusLabel
@onready var male_button: TextureButton = %BtnMale
@onready var female_button: TextureButton = %BtnFemale
@onready var confirm_button: TextureButton = %BtnConfirm
@onready var male_character: SwfTimelinePlayer = %MaleCharacter
@onready var female_character: SwfTimelinePlayer = %FemaleCharacter
@onready var male_selection_glow: Panel = %MaleSelectionGlow
@onready var female_selection_glow: Panel = %FemaleSelectionGlow


func _ready() -> void:
	_display_name_pattern.compile("^[\\p{L}\\p{N}]+(?: [\\p{L}\\p{N}]+)*$")
	_set_character_selected(male_character)
	_set_character_idle(female_character)

	male_button.pressed.connect(_select_gender.bind("male"))
	female_button.pressed.connect(_select_gender.bind("female"))
	confirm_button.pressed.connect(_create_character)
	name_input.text_submitted.connect(func(_value: String) -> void: _create_character())
	name_input.grab_focus()


func _select_gender(gender: String) -> void:
	selected_gender = gender
	var male_selected := gender == "male"
	male_button.button_pressed = male_selected
	female_button.button_pressed = not male_selected
	male_selection_glow.visible = male_selected
	female_selection_glow.visible = not male_selected

	if male_selected:
		_set_character_selected(male_character)
		_set_character_idle(female_character)
	else:
		_set_character_idle(male_character)
		_set_character_selected(female_character)

	status_label.text = ""


func _set_character_selected(character: SwfTimelinePlayer) -> void:
	character.z_index = 2
	character.play_range(ACTIVE_FIRST_FRAME, ACTIVE_LAST_FRAME)


func _set_character_idle(character: SwfTimelinePlayer) -> void:
	character.pause()
	character.z_index = 1
	character.seek_frame(1)


func _create_character() -> void:
	if selected_gender.is_empty():
		_show_error("Bạn chưa chọn nhân vật nam hoặc nữ.")
		return

	var display_name := name_input.text.strip_edges()
	var validation_error := _validate_character_name(display_name)
	if not validation_error.is_empty():
		_show_error(validation_error)
		return

	_set_busy(true)
	status_label.text = "Đang tạo nhân vật..."
	status_label.modulate = Color.WHITE
	var result: Dictionary = await GameSession.create_character(
		display_name,
		selected_gender
	)
	if result.get("ok", false):
		get_tree().change_scene_to_file(CHARACTER_ROSTER_SCENE)
		return

	_set_busy(false)
	var error: Dictionary = result.get("error", {})
	_show_error(String(error.get("message", "Không thể tạo nhân vật.")))


func _validate_character_name(display_name: String) -> String:
	if display_name.length() < 3 or display_name.length() > 10:
		return "Tên nhân vật phải có từ 3 đến 10 ký tự."
	if _display_name_pattern.search(display_name) == null:
		return "Tên chỉ được gồm chữ, số và một khoảng trắng giữa các từ."
	if display_name.is_valid_int():
		return "Tên nhân vật không được chỉ gồm số."

	var compact_name := display_name.to_lower().replace(" ", "")
	var is_admin_name_exception := GameSession.is_admin() and compact_name == "admin"
	if compact_name in RESERVED_CHARACTER_NAMES and not is_admin_name_exception:
		return "Tên này được dành riêng cho hệ thống hoặc quản trị viên."
	return ""


func _set_busy(is_busy: bool) -> void:
	confirm_button.disabled = is_busy
	male_button.disabled = is_busy
	female_button.disabled = is_busy
	name_input.editable = not is_busy


func _show_error(message: String) -> void:
	status_label.text = message
	status_label.modulate = Color(1.0, 0.55, 0.55)
