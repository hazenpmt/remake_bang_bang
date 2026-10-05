extends Control

const AssetPathAliases := preload("res://scripts/data/asset_path_aliases.gd")

const LOGIN_SCENE := "res://scenes/auth/Login.tscn"
const CHARACTER_CREATE_SCENE := "res://scenes/auth/CharacterSelect.tscn"
const QUEUE_SCENE := "res://scenes/auth/AdmissionQueue.tscn"
const MALE_CHARACTER := preload("res://assets/ui/profile/character_male_rgba.png")
const FEMALE_CHARACTER := preload("res://assets/ui/profile/character_female_rgba.png")
const LEVEL_FX_11_20 := "res://assets/animations/profile_level_11_20_effect1_compact/timeline.json"
const LEVEL_FX_21_30 := "res://assets/animations/profile_level_21_30_fx_compact/timeline.json"
const LEVEL_FX_31_35 := "res://assets/animations/profile_level_31_35_fx_compact/timeline.json"
const LEVEL_FX_36_40 := "res://assets/animations/profile_level_36_40_fx_compact/timeline.json"

@onready var _character: TextureRect = %Character
@onready var _character_name: Label = %CharacterName
@onready var _level_base: TextureRect = %LevelBase
@onready var _level_effect: SwfTimelinePlayer = %LevelEffect
@onready var _enter_button: TextureButton = %BtnEnter
@onready var _close_button: TextureButton = %BtnClose


func _ready() -> void:
	if GameSession.profile.is_empty():
		get_tree().call_deferred("change_scene_to_file", CHARACTER_CREATE_SCENE)
		return

	_enter_button.pressed.connect(_enter_game)
	_close_button.pressed.connect(_return_to_login)
	_refresh_character()


func _refresh_character() -> void:
	var gender := String(GameSession.profile.get("gender", "male"))
	var level := clampi(int(GameSession.profile.get("level", 1)), 0, 40)
	_character.texture = FEMALE_CHARACTER if gender == "female" else MALE_CHARACTER
	_character_name.text = String(GameSession.profile.get("display_name", "Nhân vật"))
	_refresh_level_badge(level)


func _refresh_level_badge(level: int) -> void:
	_level_base.texture = AssetPathAliases.load_texture(
		"res://assets/ui/profile/level/level_%d.png" % level
	)

	var effect_path := ""
	if level >= 36:
		effect_path = LEVEL_FX_36_40
	elif level >= 31:
		effect_path = LEVEL_FX_31_35
	elif level >= 21:
		effect_path = LEVEL_FX_21_30
	elif level >= 11:
		effect_path = LEVEL_FX_11_20

	if effect_path.is_empty():
		_level_effect.stop()
		_level_effect.visible = false
		return

	# Badge images and effect timelines share the original 80x40 stage.
	_level_effect.scale = Vector2.ONE
	_level_effect.modulate.a = 1.0
	if _level_effect.timeline_path != effect_path:
		_level_effect.load_timeline(effect_path)
	_level_effect.visible = true
	_level_effect.play()


func _enter_game() -> void:
	_enter_button.disabled = true
	get_tree().change_scene_to_file(QUEUE_SCENE)


func _return_to_login() -> void:
	_enter_button.disabled = true
	_close_button.disabled = true
	await GameSession.logout()
	get_tree().change_scene_to_file(LOGIN_SCENE)
