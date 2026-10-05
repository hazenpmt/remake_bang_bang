extends SceneTree

const SETTINGS_SCENE := preload("res://scenes/battle/PvpBattleSettings.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var settings := SETTINGS_SCENE.instantiate() as PvpBattleSettings
	root.add_child(settings)
	await process_frame
	assert(not settings.visible)
	settings.open()
	assert(settings.visible)
	assert(settings.get_node("Panel/Background").texture.get_size() == Vector2(726, 510))
	assert(settings.get_node("Panel/Inner").texture.get_size() == Vector2(531, 365))
	assert(settings.get_node("Panel/FullScreenTitle") is TextureRect)
	assert(settings.get_node("Panel/FullScreenTitle").texture.get_size() == Vector2(74, 27))
	assert(settings.get_node("Panel/Close").texture_normal.get_size() == Vector2(24, 24))
	assert(
		settings.get_node("Panel/Surrender").texture_normal.resource_path
		== "res://assets/ui/battle_settings/btn_vote_enable.png"
	)
	assert(settings.get_node("Panel/Surrender").texture_normal.get_size() == Vector2(133, 40))
	assert(settings.get_node("Panel/Surrender").size == Vector2(133, 40))
	assert(not settings.get_node("Panel/TabMod").visible)
	assert(not settings.is_test_mode_enabled())
	assert(settings.get_node("Panel/TabOperation/Label") is TextureRect)
	assert(settings.get_node("Panel/TabGraphics/Label") is TextureRect)
	assert(settings.get_node("Panel/TabAudio/Label") is TextureRect)
	assert(settings.get_node("Panel/TabOther/Label") is TextureRect)
	var operation_position: Vector2 = settings.get_node("Panel/TabOperation").position
	_click(settings, settings.get_node("Panel/TabGraphics") as Control)
	assert(String(settings.get("_active_tab")) == "graphics")
	assert(settings.get_node("Panel/TabOperation").position == operation_position)
	assert(settings.get_node("Panel/Content").get_child_count() >= 9)
	_click(settings, settings.get_node("Panel/TabAudio") as Control)
	assert(String(settings.get("_active_tab")) == "audio")
	_click(settings, settings.get_node("Panel/TabOther") as Control)
	assert(String(settings.get("_active_tab")) == "other")
	assert(not settings.get_node("Panel/Reset").visible)
	_click(settings, settings.get_node("Panel/TabOperation") as Control)
	assert(String(settings.get("_active_tab")) == "operation")
	assert(settings.get_node("Panel/Reset").visible)
	var operation_textures := _content_texture_paths(settings.get_node("Panel/Content"))
	for required_path: String in [
		"res://assets/ui/battle_settings/word_battle_setting_t.png",
		"res://assets/ui/battle_settings/key_board_set_t.png",
		"res://assets/ui/battle_settings/word_open_intelligent_t.png",
		"res://assets/ui/battle_settings/word_set_common_t.png",
		"res://assets/ui/battle_settings/word_all_intelligent_t.png",
		"res://assets/ui/battle_settings/battle_set_inner2.png",
	]:
		assert(operation_textures.has(required_path))
	var before := bool(settings.get_values().get("music", false))
	settings.call("_select_tab", "audio")
	var checkbox: TextureButton = settings.get_node("Panel/Content").get_child(4)
	checkbox.emit_signal("pressed")
	# Editing is staged: closing without OK must discard it.
	assert(bool(settings.get_values().get("music", false)) == before)
	settings.close()
	settings.open()
	assert(bool(settings.get_values().get("music", false)) == before)
	settings.call("_select_tab", "audio")
	checkbox = settings.get_node("Panel/Content").get_child(4)
	checkbox.emit_signal("pressed")
	(settings.get_node("Panel/Ok") as TextureButton).emit_signal("pressed")
	assert(not settings.visible)
	assert(bool(settings.get_values().get("music", false)) != before)
	settings.configure_test_mode(true)
	settings.open()
	assert(settings.get_node("Panel/TabMod").visible)
	assert(settings.is_test_mode_enabled())
	_click(settings, settings.get_node("Panel/TabMod") as Control)
	assert(settings.get_active_tab() == "mod")
	assert(settings.get_node("Panel/TabMod/Label").texture.resource_path == "res://assets/ui/battle_settings/mod_cam_1.png")
	assert(settings.get_node("Panel/Content/ModMatchTime") is LineEdit)
	assert(bool(settings.get_values().get("mod_player_respawn", false)))
	assert(bool(settings.get_values().get("mod_no_cooldown", false)))
	var emitted_values: Array[Dictionary] = []
	settings.settings_changed.connect(func(values: Dictionary) -> void:
		emitted_values.append(values)
	)
	var time_input := settings.get_node("Panel/Content/ModMatchTime") as LineEdit
	time_input.text = "2:50"
	(settings.get_node("Panel/Ok") as TextureButton).emit_signal("pressed")
	assert(emitted_values.size() == 1)
	assert(is_equal_approx(
		float(emitted_values[0].get("mod_time_reduction_seconds", 0.0)),
		170.0
	))
	# A reduction is one-shot and must not be retained for the next OK.
	assert(is_equal_approx(
		float(settings.get_values().get("mod_time_reduction_seconds", -1.0)),
		0.0
	))
	settings.configure_test_mode(false)
	assert(not settings.get_node("Panel/TabMod").visible)
	assert(settings.get_active_tab() == "operation")
	assert(not bool(settings.get_values().get("mod_invincible", true)))
	var surrender_requested := [false]
	settings.surrender_requested.connect(func() -> void: surrender_requested[0] = true)
	(settings.get_node("Panel/Surrender") as TextureButton).emit_signal("pressed")
	assert(bool(surrender_requested[0]))
	settings.close()
	assert(not settings.visible)
	settings.queue_free()
	await process_frame
	print("BATTLE_SETTINGS_RUNTIME_SMOKE_OK")
	quit(0)


func _click(settings: PvpBattleSettings, control: Control) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = control.get_global_rect().get_center()
	assert(settings.handle_pointer_event(event))


func _content_texture_paths(root_node: Node) -> Array[String]:
	var result: Array[String] = []
	for child: Node in root_node.get_children():
		if child is TextureRect and (child as TextureRect).texture != null:
			result.append((child as TextureRect).texture.resource_path)
		elif child is TextureButton and (child as TextureButton).texture_normal != null:
			result.append((child as TextureButton).texture_normal.resource_path)
		result.append_array(_content_texture_paths(child))
	return result
