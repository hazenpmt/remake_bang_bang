class_name PvpBattleSettings
extends Control

signal closed
signal settings_changed(values: Dictionary)
signal surrender_requested

const TAB_NORMAL := preload("res://assets/ui/battle_settings/btn_pag_up.png")
const TAB_SELECTED := preload("res://assets/ui/battle_settings/btn_pag_down.png")
const CHECK_OFF := preload("res://assets/ui/battle_settings/checkbox_bk.png")
const CHECK_ON := preload("res://assets/ui/battle_settings/checkbox_checked.png")
const QUALITY_NORMAL := preload("res://assets/ui/battle_settings/btn_quality.png")
const QUALITY_SELECTED := preload("res://assets/ui/battle_settings/btn_quality_selected.png")
const SLIDER_TRACK := preload("res://assets/ui/battle_settings/slider_track_enable.png")
const SLIDER_TRACK_DISABLED := preload("res://assets/ui/battle_settings/slider_track_disable.png")
const SLIDER_THUMB := preload("res://assets/ui/battle_settings/slider_thumb.png")
const BATTLE_ROW_BACKGROUND := preload("res://assets/ui/battle_settings/battle_set_inner2.png")
const BATTLE_MODE_BACKGROUND := preload("res://assets/ui/battle_settings/battle_set_inner1.png")
const BATTLE_MODE_BUTTON_BACKGROUND := preload("res://assets/ui/battle_settings/battle_btn_bg.png")
const KEY_FRAME := preload("res://assets/ui/battle_settings/word_frame.png")
const WORD_BATTLE_SETTING := preload("res://assets/ui/battle_settings/word_battle_setting_t.png")
const WORD_KEYBOARD_SETTING := preload("res://assets/ui/battle_settings/key_board_set_t.png")
const WORD_OPEN_INTELLIGENT := preload("res://assets/ui/battle_settings/word_open_intelligent_t.png")
const WORD_COMMON_MODE := preload("res://assets/ui/battle_settings/word_set_common_t.png")
const WORD_INTELLIGENT_MODE := preload("res://assets/ui/battle_settings/word_all_intelligent_t.png")
const WORD_PICTURE_SETTING := preload("res://assets/ui/battle_settings/word_picture_setting_t.png")
const PICTURE_BACKGROUND := preload("res://assets/ui/battle_settings/picture_set_inner.png")
const PICTURE_QUALITY_LINE := preload("res://assets/ui/battle_settings/picture_set_inner2.png")
const WORD_EFFECT := preload("res://assets/ui/battle_settings/word_effect_t.png")
const WORD_MOUSE_EFFECT := preload("res://assets/ui/battle_settings/word_mouse_effect_t.png")
const WORD_FULLSCREEN := preload("res://assets/ui/battle_settings/word_fullScreen_t.png")
const WORD_SKILL_NAME := preload("res://assets/ui/battle_settings/word_skill_name_t.png")
const QUALITY_WORD_NORMAL := [
	preload("res://assets/ui/battle_settings/word_low2_t.png"),
	preload("res://assets/ui/battle_settings/word_mid2_t.png"),
	preload("res://assets/ui/battle_settings/word_height2_t.png"),
]
const QUALITY_WORD_SELECTED := [
	preload("res://assets/ui/battle_settings/word_low1_t.png"),
	preload("res://assets/ui/battle_settings/word_mid1_t.png"),
	preload("res://assets/ui/battle_settings/word_height1_t.png"),
]
const WORD_MUSIC := preload("res://assets/ui/battle_settings/word_music_t.png")
const WORD_MUSIC_VOLUME := preload("res://assets/ui/battle_settings/word_music_vol_t.png")
const WORD_SOUND := preload("res://assets/ui/battle_settings/word_sound_t.png")
const WORD_SOUND_VOLUME := preload("res://assets/ui/battle_settings/word_sound_vol_t.png")
const WORD_BUY_LIVE := preload("res://assets/ui/battle_settings/word_buy_live_t.png")
const WORD_REFUSE := preload("res://assets/ui/battle_settings/word_refuse_t.png")
const WORD_REFUSE_CORPS := preload("res://assets/ui/battle_settings/word_refuse_corps_t.png")
const SECOND_PASSWORD_BUTTON := preload("res://assets/ui/battle_settings/btn_set_sec_pwd_t.png")
const MOD_LABEL_NORMAL := preload("res://assets/ui/battle_settings/mod_xanh_1.png")
const MOD_LABEL_SELECTED := preload("res://assets/ui/battle_settings/mod_cam_1.png")
const TAB_LABELS_NORMAL := [
	MOD_LABEL_NORMAL,
	preload("res://assets/ui/battle_settings/word_battle_up_t.png"),
	preload("res://assets/ui/battle_settings/word_picture_up_t.png"),
	preload("res://assets/ui/battle_settings/word_audio_up_t.png"),
	preload("res://assets/ui/battle_settings/word_other_up_t.png"),
]
const TAB_LABELS_SELECTED := [
	MOD_LABEL_SELECTED,
	preload("res://assets/ui/battle_settings/word_battle_down_t.png"),
	preload("res://assets/ui/battle_settings/word_picture_down_t.png"),
	preload("res://assets/ui/battle_settings/word_audio_down_t.png"),
	preload("res://assets/ui/battle_settings/word_other_down_t.png"),
]

const TAB_NAMES := ["mod", "operation", "graphics", "audio", "other"]
const TAB_BUTTONS := ["TabMod", "TabOperation", "TabGraphics", "TabAudio", "TabOther"]

var _active_tab := "operation"
var _test_mode_enabled := false
var _values := {
	"mod_player_respawn": true,
	"mod_no_cooldown": true,
	"mod_invincible": false,
	"mod_bot_movement": false,
	"mod_time_reduction_seconds": 0.0,
	"auto_aim": true,
	"aim_mode": 0,
	"show_skill_names": true,
	"smart_fire": false,
	"smart_skill_r": false,
	"smart_skill_e": false,
	"smart_skill_space": false,
	"smart_skill_q": false,
	"quality": 1,
	"smooth": true,
	"effects": true,
	"music": true,
	"music_volume": 0.5,
	"sound": true,
	"sound_volume": 0.6,
	"buy_respawn": false,
	"block_stranger_invites": false,
	"block_guild_invites": false,
}
var _editing_values: Dictionary = {}
var _widgets: Dictionary = {}

@onready var _panel: Control = $Panel
@onready var _content: Control = $Panel/Content


func _ready() -> void:
	visible = false
	_editing_values = _values.duplicate(true)
	$Panel/Close.pressed.connect(close)
	$Panel/Ok.pressed.connect(_apply_and_close)
	$Panel/Reset.pressed.connect(_reset_defaults)
	$Panel/Surrender.pressed.connect(func() -> void: surrender_requested.emit())
	for index: int in TAB_BUTTONS.size():
		(_panel.get_node(TAB_BUTTONS[index]) as TextureButton).pressed.connect(
			_select_tab.bind(TAB_NAMES[index])
		)
	_select_tab(_active_tab)


func open() -> void:
	_editing_values = _values.duplicate(true)
	_rebuild_content()
	visible = true
	move_to_front()


func configure_test_mode(enabled: bool) -> void:
	var was_enabled := _test_mode_enabled
	_test_mode_enabled = enabled
	$Panel/TabMod.visible = enabled
	if enabled and not was_enabled:
		_set_default_mod_values(_values)
	if not enabled:
		_reset_mod_values(_values)
		if _active_tab == "mod":
			_select_tab("operation")
	if visible:
		_editing_values = _values.duplicate(true)
		_rebuild_content()


func is_test_mode_enabled() -> bool:
	return _test_mode_enabled


func get_active_tab() -> String:
	return _active_tab


func close() -> void:
	if not visible:
		return
	_editing_values = _values.duplicate(true)
	visible = false
	closed.emit()


func is_open() -> bool:
	return visible


func handle_pointer_event(event: InputEvent) -> bool:
	var mouse_event := event as InputEventMouseButton
	if (
		mouse_event == null
		or not mouse_event.pressed
		or mouse_event.button_index != MOUSE_BUTTON_LEFT
	):
		return false
	for index: int in TAB_BUTTONS.size():
		var tab_button := _panel.get_node(TAB_BUTTONS[index]) as TextureButton
		if not tab_button.visible:
			continue
		if tab_button.get_global_rect().has_point(mouse_event.position):
			_select_tab(TAB_NAMES[index])
			return true
	# Content controls are created dynamically, so they cannot rely on the
	# SubViewport GUI dispatch order. Route their real screen rectangles here,
	# before the battle map consumes the click.
	for widget_value: Variant in _widgets.values():
		var widget := widget_value as Control
		if (
			widget == null
			or not widget.visible
			or not widget.get_global_rect().has_point(mouse_event.position)
		):
			continue
		if widget is TextureButton:
			(widget as TextureButton).pressed.emit()
			return true
		if widget is LineEdit:
			(widget as LineEdit).grab_focus()
			return true
	if ($Panel/Close as TextureButton).get_global_rect().has_point(mouse_event.position):
		close()
		return true
	if ($Panel/Ok as TextureButton).get_global_rect().has_point(mouse_event.position):
		_apply_and_close()
		return true
	if (
		$Panel/Reset.visible
		and ($Panel/Reset as TextureButton).get_global_rect().has_point(
			mouse_event.position
		)
	):
		_reset_defaults()
		return true
	if ($Panel/Surrender as TextureButton).get_global_rect().has_point(mouse_event.position):
		surrender_requested.emit()
		return true
	return false


func get_values() -> Dictionary:
	return _values.duplicate(true)


func _select_tab(tab_name: String) -> void:
	if tab_name == "mod" and not _test_mode_enabled:
		return
	if _active_tab == "mod" and _widgets.has("mod_match_time"):
		_commit_mod_time(_widgets["mod_match_time"] as LineEdit)
	_active_tab = tab_name
	$Panel/Reset.visible = tab_name != "other"
	for index: int in TAB_BUTTONS.size():
		var button := _panel.get_node(TAB_BUTTONS[index]) as TextureButton
		var selected: bool = TAB_NAMES[index] == tab_name
		button.texture_normal = TAB_SELECTED if selected else TAB_NORMAL
		button.size = button.texture_normal.get_size()
		var label := button.get_node("Label") as TextureRect
		label.texture = TAB_LABELS_SELECTED[index] if selected else TAB_LABELS_NORMAL[index]
		label.size = label.texture.get_size()
		label.position = (button.size - label.size) * 0.5
	_rebuild_content()


func _reset_defaults() -> void:
	_editing_values = {
		"mod_player_respawn": true, "mod_no_cooldown": true,
		"mod_invincible": false, "mod_bot_movement": false,
		"mod_time_reduction_seconds": 0.0,
		"auto_aim": true, "aim_mode": 0,
		"show_skill_names": true, "smart_fire": false,
		"smart_skill_r": false, "smart_skill_e": false,
		"smart_skill_space": false, "smart_skill_q": false,
		"quality": 1, "smooth": true, "effects": true,
		"music": true, "music_volume": 0.5, "sound": true,
		"sound_volume": 0.6, "buy_respawn": false,
		"block_stranger_invites": false, "block_guild_invites": false,
	}
	_rebuild_content()


func _rebuild_content() -> void:
	for child: Node in _content.get_children():
		child.free()
	_widgets.clear()
	match _active_tab:
		"mod": _build_mod()
		"graphics": _build_graphics()
		"audio": _build_audio()
		"other": _build_other()
		_: _build_operation()


func _reset_mod_values(target_values: Dictionary) -> void:
	target_values["mod_player_respawn"] = false
	target_values["mod_no_cooldown"] = false
	target_values["mod_invincible"] = false
	target_values["mod_bot_movement"] = false
	target_values["mod_time_reduction_seconds"] = 0.0


func _set_default_mod_values(target_values: Dictionary) -> void:
	target_values["mod_player_respawn"] = true
	target_values["mod_no_cooldown"] = true
	target_values["mod_invincible"] = false
	target_values["mod_bot_movement"] = false
	target_values["mod_time_reduction_seconds"] = 0.0


func _build_mod() -> void:
	if not _test_mode_enabled:
		return
	_add_heading("NGƯỜI CHƠI", Vector2(28, 13), Vector2(170, 25))
	_add_heading("BOT", Vector2(305, 13), Vector2(120, 25))
	_add_label("Hồi sinh", Vector2(28, 51), Vector2(145, 25), 16)
	_add_label("Cooldown skill", Vector2(28, 91), Vector2(170, 25), 16)
	_add_label("Bất tử", Vector2(28, 131), Vector2(145, 25), 16)
	_add_label("Bot di chuyển", Vector2(278, 51), Vector2(170, 25), 16)
	_add_check("mod_player_respawn", Vector2(182, 50))
	_add_check("mod_no_cooldown", Vector2(182, 90))
	_add_check("mod_invincible", Vector2(182, 130))
	_add_check("mod_bot_movement", Vector2(443, 50))
	_add_label(
		"Giảm thời gian trận đấu đi",
		Vector2(28, 205),
		Vector2(245, 28),
		15
	)
	var time_input := LineEdit.new()
	time_input.name = "ModMatchTime"
	time_input.position = Vector2(300, 205)
	time_input.size = Vector2(94, 29)
	time_input.max_length = 5
	time_input.text = _format_mod_time(
		float(_editing_values["mod_time_reduction_seconds"])
	)
	time_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	time_input.add_theme_font_size_override("font_size", 16)
	time_input.text_submitted.connect(func(_text: String) -> void:
		_commit_mod_time(time_input)
	)
	time_input.focus_exited.connect(_commit_mod_time.bind(time_input))
	_content.add_child(time_input)
	_widgets["mod_match_time"] = time_input


func _commit_mod_time(input: LineEdit) -> void:
	var parts := input.text.strip_edges().split(":")
	var seconds := float(_editing_values.get("mod_time_reduction_seconds", 0.0))
	if parts.size() == 2 and String(parts[0]).is_valid_int() and String(parts[1]).is_valid_int():
		seconds = float(int(parts[0]) * 60 + clampi(int(parts[1]), 0, 59))
	elif input.text.strip_edges().is_valid_int():
		seconds = float(int(input.text.strip_edges()))
	_editing_values["mod_time_reduction_seconds"] = clampf(seconds, 0.0, 240.0)
	input.text = _format_mod_time(
		float(_editing_values["mod_time_reduction_seconds"])
	)


func _format_mod_time(seconds: float) -> String:
	var total := clampi(roundi(seconds), 0, 240)
	return "%d:%02d" % [total / 60, total % 60]


func _build_operation() -> void:
	_add_image(WORD_BATTLE_SETTING, Vector2(20, 9))
	_add_image(BATTLE_MODE_BACKGROUND, Vector2(40, 49))
	_add_image(BATTLE_MODE_BUTTON_BACKGROUND, Vector2(146, 60))
	_add_image(WORD_KEYBOARD_SETTING, Vector2(265, 112))
	_add_image(WORD_OPEN_INTELLIGENT, Vector2(336, 111))
	_add_image(BATTLE_ROW_BACKGROUND, Vector2(24, 134))
	_add_mode_button(0, Vector2(148, 61), WORD_COMMON_MODE)
	_add_mode_button(1, Vector2(296, 61), WORD_INTELLIGENT_MODE)
	var left_rows := [
		["Skill 1", "R", Vector2(258, 136)],
		["Skill 2", "E", Vector2(258, 160)],
		["Tuyệt Chiêu", "P. Cách", Vector2(258, 184)],
		["Skill Guild", "Q", Vector2(258, 209)],
		["Xạ kích", "Chuột trái", Vector2(120, 235)],
		["Tự động bắn", "Chuột phải", Vector2(120, 259)],
		["Thông tin C-", "G", Vector2(120, 283)],
		["Phun Sơn Xe", "F", Vector2(120, 307)],
	]
	var left_y := [137.0, 160.0, 185.0, 209.0, 232.0, 257.0, 280.0, 306.0]
	for index: int in left_rows.size():
		var row: Array = left_rows[index]
		_add_label(String(row[0]), Vector2(30, left_y[index]), Vector2(105, 22), 13)
		_add_key(String(row[1]), row[2])
	var right_rows := [
		["Công", "Z", Vector2(300, 234)],
		["Rút lui", "X", Vector2(300, 259)],
		["Tập hợp", "C", Vector2(300, 282)],
	]
	for index: int in right_rows.size():
		var row: Array = right_rows[index]
		_add_label(String(row[0]), Vector2(210, [232.0, 257.0, 280.0][index]), Vector2(90, 22), 13)
		_add_key(String(row[1]), row[2])
	for entry: Array in [
		["smart_skill_r", Vector2(364, 131)],
		["smart_skill_e", Vector2(364, 155)],
		["smart_skill_space", Vector2(364, 180)],
		["smart_skill_q", Vector2(364, 204)],
	]:
		_add_check(String(entry[0]), entry[1])


func _build_graphics() -> void:
	_add_image(WORD_PICTURE_SETTING, Vector2(20, 9))
	_add_image(PICTURE_BACKGROUND, Vector2(27, 53))
	_add_image(PICTURE_QUALITY_LINE, Vector2(86, 68))
	for index: int in 3:
		var button := TextureButton.new()
		button.position = Vector2([88.0, 260.0, 429.0][index], 70)
		button.size = QUALITY_NORMAL.get_size()
		button.ignore_texture_size = true
		button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		button.texture_normal = QUALITY_SELECTED if int(_editing_values["quality"]) == index else QUALITY_NORMAL
		button.pressed.connect(func() -> void:
			_editing_values["quality"] = index
			_rebuild_content()
		)
		_content.add_child(button)
		_add_image(
			QUALITY_WORD_SELECTED[index] if int(_editing_values["quality"]) == index else QUALITY_WORD_NORMAL[index],
			button.position + (button.size - QUALITY_WORD_NORMAL[index].get_size()) * 0.5
		)
	_add_image(WORD_MOUSE_EFFECT, Vector2(27, 175))
	_add_image(WORD_FULLSCREEN, Vector2(256, 178))
	_add_image(WORD_EFFECT, Vector2(27, 237))
	_add_image(WORD_SKILL_NAME, Vector2(27, 296))
	_add_check("smooth", Vector2(147, 169))
	_add_check("auto_aim", Vector2(345, 169))
	_add_check("effects", Vector2(147, 231))
	_add_check("show_skill_names", Vector2(147, 290))


func _build_audio() -> void:
	_add_image(WORD_MUSIC, Vector2(67, 83))
	_add_image(WORD_MUSIC_VOLUME, Vector2(67, 140))
	_add_image(WORD_SOUND, Vector2(67, 228))
	_add_image(WORD_SOUND_VOLUME, Vector2(67, 278))
	_add_check("music", Vector2(198, 80))
	_add_slider("music_volume", Vector2(177, 132))
	_add_check("sound", Vector2(198, 226))
	_add_slider("sound_volume", Vector2(177, 271))


func _build_other() -> void:
	_add_image(WORD_BUY_LIVE, Vector2(71, 99))
	_add_image(WORD_REFUSE, Vector2(71, 174))
	_add_image(WORD_REFUSE_CORPS, Vector2(71, 249))
	_add_image(SECOND_PASSWORD_BUTTON, Vector2(391, 0))
	_add_check("buy_respawn", Vector2(412, 103))
	_add_check("block_stranger_invites", Vector2(412, 178))
	_add_check("block_guild_invites", Vector2(412, 254))


func _add_heading(text_value: String, position_value: Vector2, size_value: Vector2) -> void:
	_add_label(text_value, position_value, size_value, 15, Color(0.75, 0.92, 1))


func _add_image(texture: Texture2D, position_value: Vector2) -> TextureRect:
	var image := TextureRect.new()
	image.texture = texture
	image.position = position_value
	image.size = texture.get_size()
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(image)
	return image


func _add_mode_button(mode: int, position_value: Vector2, icon: Texture2D) -> void:
	var button := TextureButton.new()
	button.position = position_value
	button.size = Vector2(150, 31)
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	button.texture_normal = (
		preload("res://assets/ui/battle_settings/btn_battle_long_down.png")
		if int(_editing_values.get("aim_mode", 0)) == mode
		else preload("res://assets/ui/battle_settings/btn_battle_long_up.png")
	)
	button.pressed.connect(func() -> void:
		_editing_values["aim_mode"] = mode
		_rebuild_content()
	)
	_content.add_child(button)
	var icon_node := TextureRect.new()
	icon_node.texture = icon
	icon_node.size = icon.get_size()
	icon_node.position = (button.size - icon_node.size) * 0.5
	icon_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon_node)


func _add_label(text_value: String, position_value: Vector2, size_value: Vector2, font_size := 16, color := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = position_value
	label.size = size_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.12, 0.25, 1))
	label.add_theme_constant_override("outline_size", 2)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_content.add_child(label)
	return label


func _add_key(text_value: String, position_value: Vector2) -> void:
	var key := TextureButton.new()
	key.texture_normal = KEY_FRAME
	key.position = position_value
	key.size = KEY_FRAME.get_size()
	key.ignore_texture_size = true
	key.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_content.add_child(key)
	var label := Label.new()
	label.text = text_value
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.94, 0.96, 0.98))
	label.add_theme_color_override("font_outline_color", Color(0.03, 0.12, 0.25))
	label.add_theme_constant_override("outline_size", 1)
	key.add_child(label)


func _add_check(key: String, position_value: Vector2, title: String = "", detail: String = "") -> void:
	if not title.is_empty():
		_add_label(title, Vector2(20, position_value.y - 7), Vector2(position_value.x - 40, 30), 16)
		if not detail.is_empty():
			_add_label(detail, Vector2(20, position_value.y + 18), Vector2(position_value.x - 25, 30), 11, Color(0.9, 0.95, 1))
	var checkbox := TextureButton.new()
	checkbox.position = position_value
	checkbox.size = Vector2(27, 27)
	checkbox.ignore_texture_size = true
	checkbox.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	checkbox.texture_normal = CHECK_ON if bool(_editing_values.get(key, false)) else CHECK_OFF
	checkbox.pressed.connect(func() -> void:
		_editing_values[key] = not bool(_editing_values.get(key, false))
		checkbox.texture_normal = CHECK_ON if bool(_editing_values[key]) else CHECK_OFF
	)
	_content.add_child(checkbox)
	_widgets[key] = checkbox


func _add_slider(key: String, position_value: Vector2) -> void:
	var disabled_track := TextureRect.new()
	disabled_track.texture = SLIDER_TRACK_DISABLED
	disabled_track.position = position_value
	disabled_track.size = SLIDER_TRACK_DISABLED.get_size()
	disabled_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(disabled_track)
	var track := TextureRect.new()
	track.texture = SLIDER_TRACK
	track.position = position_value
	track.size = SLIDER_TRACK.get_size()
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(track)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = float(_editing_values[key])
	slider.position = position_value
	slider.size = SLIDER_TRACK.get_size()
	slider.modulate.a = 0.0
	_content.add_child(slider)
	var thumb := TextureRect.new()
	thumb.texture = SLIDER_THUMB
	thumb.size = SLIDER_THUMB.get_size()
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(thumb)
	var update_thumb := func(value: float) -> void:
		thumb.position = position_value + Vector2(
			(SLIDER_TRACK.get_width() - SLIDER_THUMB.get_width()) * value,
			0.0
		)
	update_thumb.call(slider.value)
	slider.value_changed.connect(func(value: float) -> void:
		_editing_values[key] = value
		update_thumb.call(value)
	)


func _apply_and_close() -> void:
	if _active_tab == "mod" and _widgets.has("mod_match_time"):
		_commit_mod_time(_widgets["mod_match_time"] as LineEdit)
	_values = _editing_values.duplicate(true)
	settings_changed.emit(get_values())
	# The time field is a one-shot reduction. Reopening and pressing OK without
	# entering another value must never subtract the same amount twice.
	_values["mod_time_reduction_seconds"] = 0.0
	_editing_values["mod_time_reduction_seconds"] = 0.0
	close()
