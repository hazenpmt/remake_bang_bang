extends Node

const MAP_SCENE := preload("res://scenes/battle/PvpBattleMap.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var map := MAP_SCENE.instantiate()
	add_child(map)
	await get_tree().process_frame
	var participants: Array[Dictionary] = []
	for team_no in [1, 2]:
		for slot_no in range(1, 6):
			participants.append({
				"account_id": "test-%d-%d" % [team_no, slot_no],
				"display_name": "Test %d-%d" % [team_no, slot_no],
				"team_no": team_no,
				"slot_no": slot_no,
				"tank_key": "gangtiexia03",
				"equipped_skin_key": "gangtiexia03_default",
				"is_bot": not (team_no == 1 and slot_no == 1),
			})
	map.call("prepare", {
		"id": "local-result-smoke",
		"is_test": true,
		"viewer_team_no": 1,
		"participants": participants,
	})
	var rules: Dictionary = map.get("_battle_rules")
	assert(is_equal_approx(float(rules.get("duration_seconds", 0.0)), 240.0))
	map.visible = true
	var settings_button := map.get_node("BattleHud/TopRight/Settings") as TextureButton
	var settings_panel := map.get_node("BattleHud/SettingsPanel") as PvpBattleSettings
	assert(not settings_panel.is_open())
	# A forged is_test flag is insufficient: only the explicit local sandbox ID
	# may expose or apply battle mods.
	assert(not settings_panel.get_node("Panel/TabMod").visible)
	assert(not bool(map.get("_test_mod_no_cooldown")))
	var settings_click := InputEventMouseButton.new()
	settings_click.button_index = MOUSE_BUTTON_LEFT
	settings_click.pressed = true
	settings_click.position = settings_button.get_global_rect().get_center()
	map.call("_input", settings_click)
	assert(settings_panel.is_open())
	for tab_name: String in ["TabGraphics", "TabAudio", "TabOther", "TabOperation"]:
		var tab := settings_panel.get_node("Panel/" + tab_name) as Control
		var tab_click := InputEventMouseButton.new()
		tab_click.button_index = MOUSE_BUTTON_LEFT
		tab_click.pressed = true
		tab_click.position = tab.get_global_rect().get_center()
		map.call("_input", tab_click)
	var active_tab: String = String(settings_panel.get("_active_tab"))
	assert(active_tab == "operation")
	# Space is already channeling when Settings opens. Battle time must keep
	# advancing it into cooldown instead of freezing until the panel closes.
	var skill_3 := map.get_node("BattleHud/BottomStatus/Skill3") as Control
	assert(bool(skill_3.call("begin_channel_countdown", 0.25)))
	map.set("_skill_channel", {
		"direction": Vector2.RIGHT,
		"remaining": 0.25,
		"elapsed": 0.0,
		"tick_remaining": 10.0,
	})
	map.set("_control_enabled", true)
	map.call("_process", 0.3)
	assert((map.get("_skill_channel") as Dictionary).is_empty())
	var cooldown_before := float(skill_3.call("get_remaining_seconds"))
	assert(cooldown_before > 0.0)
	skill_3.call("_process", 0.1)
	assert(float(skill_3.call("get_remaining_seconds")) < cooldown_before)
	settings_panel.close()
	map.call("_finish_battle", 1, "smoke")
	var result: Dictionary = map.call("get_last_battle_result")
	assert(String(result.get("viewer_outcome", "")) == "win")
	assert((result.get("players", []) as Array).size() == 10)
	assert((map.get_node("ViewportContainer/WorldViewport/World") as Node).process_mode == Node.PROCESS_MODE_DISABLED)
	assert(map.get_node("BattleResultSequence").visible)
	map.call("_handle_battle_chat_enter")
	assert(map.get_node("BattleHud/BattleChat").visible)
	map.call("reset")
	assert((map.get_node("ViewportContainer/WorldViewport/World") as Node).process_mode == Node.PROCESS_MODE_INHERIT)
	assert(not map.get_node("BattleResultSequence").visible)
	map.call("prepare", {
		"id": "local-test",
		"is_test": true,
		"viewer_team_no": 1,
		"participants": participants,
	})
	assert(settings_panel.get_node("Panel/TabMod").visible)
	# Merely opening/configuring TEST does not apply any Mod option.
	assert(not bool(map.get("_test_mod_no_cooldown")))
	var test_rules: Dictionary = map.get("_battle_rules")
	assert(is_equal_approx(float(test_rules.get("duration_seconds", 0.0)), 240.0))
	map.set("_battle_elapsed_seconds", 55.0)
	settings_panel.open()
	var mod_tab := settings_panel.get_node("Panel/TabMod") as Control
	_click_map_control(map, mod_tab)
	assert(settings_panel.get_active_tab() == "mod")
	var widgets: Dictionary = settings_panel.get("_widgets")
	# Use the same PvpBattleMap._input route as a real click. Runtime values must
	# remain unchanged until the final OK click.
	_click_map_control(map, widgets["mod_invincible"] as Control)
	_click_map_control(map, widgets["mod_bot_movement"] as Control)
	var pending: Dictionary = settings_panel.get("_editing_values")
	assert(bool(pending.get("mod_invincible", false)))
	assert(bool(pending.get("mod_bot_movement", false)))
	assert(not bool(map.get("_test_mod_invincible")))
	assert(not bool(map.get("_test_mod_bot_movement")))
	var reduction_input := settings_panel.get_node(
		"Panel/Content/ModMatchTime"
	) as LineEdit
	reduction_input.text = "2:50"
	_click_map_control(map, settings_panel.get_node("Panel/Ok") as Control)
	assert(not settings_panel.is_open())
	assert(bool(map.get("_test_mod_player_respawn")))
	assert(bool(map.get("_test_mod_no_cooldown")))
	assert(bool(map.get("_test_mod_invincible")))
	assert(bool(map.get("_test_mod_bot_movement")))
	# 3:05 remaining minus 2:50 leaves exactly 0:15.
	test_rules = map.get("_battle_rules")
	assert(is_equal_approx(float(test_rules.get("duration_seconds", 0.0)), 70.0))
	assert(is_equal_approx(
		float(test_rules.get("duration_seconds", 0.0))
		- float(map.get("_battle_elapsed_seconds")),
		15.0
	))
	# Pressing OK again without another reduction must not subtract twice.
	settings_panel.open()
	settings_panel.call("_apply_and_close")
	test_rules = map.get("_battle_rules")
	assert(is_equal_approx(float(test_rules.get("duration_seconds", 0.0)), 70.0))
	# Invincibility covers the final shared damage entry.
	var player_before: Dictionary = (map.get("_combatants") as Dictionary)["player"]
	var hp_before := int(player_before.get("hit_points", 0))
	assert(int(map.call("_apply_damage", "player", 999999.0)) == 0)
	var player_after: Dictionary = (map.get("_combatants") as Dictionary)["player"]
	assert(int(player_after.get("hit_points", 0)) == hp_before)
	map.call("reset")
	assert(not settings_panel.get_node("Panel/TabMod").visible)
	map.queue_free()
	await get_tree().process_frame
	print("BATTLE_FINISH_FREEZE_SMOKE_OK")
	get_tree().quit(0)


func _click_map_control(map: Node, control: Control) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = control.get_global_rect().get_center()
	map.call("_input", click)
