extends SceneTree

const CALCULATOR := preload("res://scripts/data/battle_honor_calculator.gd")
const RESULT_SCENE := preload(
	"res://scenes/battle/PvpBattleResultSequence.tscn"
)
const SUMMARY_SCENE := preload(
	"res://scenes/battle/PvpBattleResultScreen.tscn"
)
const HONOR_SLOT_SCENE := preload(
	"res://scenes/battle/PvpBattleHonorSlot.tscn"
)
const HONOR_BADGE_SCENE := preload(
	"res://scenes/battle/PvpBattleHonorBadge.tscn"
)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var preview_slot := HONOR_SLOT_SCENE.instantiate() as Control
	assert((preview_slot.get_node("Content/Pedestal") as CanvasItem).modulate.a == 1.0)
	assert((preview_slot.get_node("Content/Avatar") as CanvasItem).modulate.a == 1.0)
	assert((preview_slot.get_node("Content/TankVisual") as CanvasItem).modulate.a == 1.0)
	assert((preview_slot.get_node("Honors/LayoutSingle") as Control).visible)
	var preview_avatar := preview_slot.get_node("Content/Avatar") as Control
	var preview_portrait := preview_avatar.get_node("Portrait") as TextureRect
	assert(not preview_avatar.clip_contents)
	assert(preview_portrait.size == Vector2(135.0, 119.0))
	assert(preview_portrait.position == Vector2(57.0, 0.0))
	assert(
		String(preview_portrait.texture.resource_path)
		== "res://assets/battle/result/avatar_heads/boy001.png"
	)
	preview_slot.free()
	var preview_badge := HONOR_BADGE_SCENE.instantiate() as Control
	assert((preview_badge.get_node("Visual") as CanvasItem).modulate.a == 1.0)
	assert((preview_badge.get_node("Visual/Icon") as CanvasItem).modulate.a == 1.0)
	assert((preview_badge.get_node("Visual/Label") as CanvasItem).modulate.a == 1.0)
	preview_badge.free()
	_assert_segment(_p3_players(), "label_p3", 3)
	_assert_segment(_p2_players(), "label_p2", 2)
	_assert_segment(_p1_players(), "label_p1", 1)
	var sequence := RESULT_SCENE.instantiate() as PvpBattleResultSequence
	root.add_child(sequence)
	await process_frame
	sequence.begin({
		"viewer_outcome": "win",
		"viewer_team_no": 1,
		"team_1_score": 25,
		"team_2_score": 17,
		"elapsed_seconds": 187.0,
	}, _p3_players(), "player")
	assert(sequence.visible)
	assert(sequence.is_sequence_active())
	sequence.call("_on_movie_frame_changed", 94)
	await process_frame
	assert(sequence.is_sequence_active())
	assert(sequence.get_node("HonorStage").visible)
	var slots := sequence.get_node("HonorStage/Center/Slots")
	assert(slots.get_child_count() == 3)
	assert(slots.get_child(0).has_node("Content/RotatingBase"))
	assert(slots.get_child(0).has_node("Honors"))
	var first_honors := slots.get_child(0).get_node("Honors") as Control
	assert((slots.get_child(0).get_node("Content/Pedestal") as CanvasItem).modulate.a == 0.0)
	assert(first_honors.has_node("LayoutSingle/Badge1/Visual/ImpactFlash"))
	assert(
		(first_honors.get_node("LayoutSingle/Badge1") as Control).position
		== Vector2(74.5, 0.0)
	)
	assert(
		(first_honors.get_node("LayoutDouble/Badge1") as Control).position
		== Vector2(24.5, 0.0)
	)
	assert(
		(first_honors.get_node("LayoutTriple/Badge2") as Control).position
		== Vector2(74.5, 0.0)
	)
	var portrait := slots.get_child(0).get_node(
		"Content/Avatar/Portrait"
	) as TextureRect
	assert(portrait.texture.get_size() == Vector2(135.0, 119.0))
	assert(
		String(portrait.texture.resource_path)
		== "res://assets/battle/result/avatar_heads/boy001.png"
	)
	var custom_avatar := sequence.call(
		"_honor_avatar_texture", {"avatar_key": "boy001", "gender": "male"}
	) as Texture2D
	assert(custom_avatar.get_size() == Vector2(135.0, 119.0))
	assert(
		String(custom_avatar.resource_path)
		== "res://assets/battle/result/avatar_heads/boy001.png"
	)
	var tank_name := slots.get_child(0).get_node("Content/TankName") as Label
	var tank_name_bg := slots.get_child(0).get_node(
		"Content/TankNameBackground"
	) as TextureRect
	assert(tank_name.position == tank_name_bg.position)
	assert(tank_name.size == tank_name_bg.size)
	assert(String(slots.get_child(0).get_meta("relation")) == "enemy")
	assert(String(slots.get_child(1).get_meta("relation")) == "ally")
	assert(String(slots.get_child(2).get_meta("relation")) == "self")
	var awards: Array = sequence.get_honor_result().get("awards", [])
	assert(String((awards[0] as Dictionary).get("type", "")) == "mvp")
	assert(String((awards[1] as Dictionary).get("type", "")) == "killer")
	assert(String((awards[2] as Dictionary).get("type", "")) == "assist")
	sequence.call("_complete_honors")
	await process_frame
	assert(not sequence.visible)
	sequence.queue_free()
	await process_frame

	# Run a second sequence without manually forcing any frame. This guards the
	# real outcome -> honors -> result signal path against hanging at the range end.
	var live_sequence := RESULT_SCENE.instantiate() as PvpBattleResultSequence
	root.add_child(live_sequence)
	await process_frame
	var live_finished := [false]
	live_sequence.honors_finished.connect(
		func(_result: Dictionary, _players: Array[Dictionary], _honors: Dictionary) -> void:
			live_finished[0] = true
	)
	Engine.time_scale = 8.0
	live_sequence.begin({
		"viewer_outcome": "win",
		"viewer_team_no": 1,
	}, _p3_players(), "player")
	var deadline_msec := Time.get_ticks_msec() + 4000
	while not bool(live_finished[0]) and Time.get_ticks_msec() < deadline_msec:
		await process_frame
	Engine.time_scale = 1.0
	if not bool(live_finished[0]):
		print("LIVE_TIMEOUT phase=%s frame=%d" % [
			String(live_sequence.get("_phase")),
			int(live_sequence.get_node("MovieCenter/Movie").get_current_frame()),
		])
	assert(bool(live_finished[0]))
	live_sequence.queue_free()
	await process_frame

	var summary := SUMMARY_SCENE.instantiate() as PvpBattleResultScreen
	var shared_chat_parent := Control.new()
	shared_chat_parent.name = "SharedChatParent"
	root.add_child(shared_chat_parent)
	var shared_chat := _make_shared_chat_mock()
	shared_chat_parent.add_child(shared_chat)
	root.add_child(summary)
	await process_frame
	summary.bind_shared_chat(shared_chat)
	summary.show_result({
		"viewer_outcome": "win",
		"winner_team_no": 1,
		"viewer_team_no": 1,
		"team_1_score": 25,
		"team_2_score": 17,
		"elapsed_seconds": 187.0,
	}, _ten_players(), CALCULATOR.calculate(_p3_players()), "player")
	assert(summary.visible)
	assert(not summary.has_node("Center/Window/Title"))
	assert(
		String(summary.get_node("Background").texture.resource_path)
		== "res://assets/ui/bg_sea.jpg"
	)
	var team_1 := summary.get_node("Center/Window/LeftPanel/Rows/Team1")
	var team_2 := summary.get_node("Center/Window/LeftPanel/Rows/Team2")
	assert(team_1.has_node("Slot1") and team_1.has_node("Slot5"))
	assert(team_2.has_node("Slot1") and team_2.has_node("Slot5"))
	assert(team_1.get_node("Slot1").has_node("KdaCell"))
	assert(team_2.get_node("Slot1").has_node("KdaCell"))
	assert(int(team_1.get_node("Slot1").get_meta("team_no")) == 1)
	assert(int(team_2.get_node("Slot1").get_meta("team_no")) == 2)
	assert((team_1.get_node("WinIcon") as TextureRect).visible)
	assert(not (team_2.get_node("WinIcon") as TextureRect).visible)
	assert(
		String((team_1.get_node("WinIcon") as TextureRect).texture.resource_path)
		== "res://assets/battle/result/win_icon_t.png"
	)
	assert((team_1.get_node("WinIcon") as TextureRect).texture.get_size() == Vector2(101, 102))
	assert(
		(team_1.get_node("Slot1/PlayerName") as Label).get_theme_color("font_color")
		== Color("69ff62")
	)
	assert(
		(team_1.get_node("Slot1/Kda") as Label).get_theme_color("font_color")
		== Color("ffe130")
	)
	assert(
		(team_2.get_node("Slot1/PlayerName") as Label).get_theme_color("font_color")
		== Color("ffffff")
	)
	assert(
		(team_2.get_node("Slot1/Kda") as Label).get_theme_color("font_color")
		== Color("ffffff")
	)
	assert(shared_chat.get_parent() == summary.get_node("Center/Window/ChatHost"))
	assert(shared_chat.get_node("Input").visible)
	assert(shared_chat.get_node("History").size == Vector2(464, 163))
	assert(shared_chat.get_node("Input").position == Vector2(0, 162))
	assert(shared_chat.get_node("Input").size == Vector2(464, 43))
	assert(summary.has_node("Center/Window/RightPanel/RewardSlot5"))
	assert(summary.has_node("Center/Window/RightPanel/TankArea/TankDisplayName"))
	assert(summary.has_node("Center/Window/Leave"))
	assert(summary.get_node("Center/Window").custom_minimum_size == Vector2(977, 618))
	assert(
		summary.get_node("Center/Window/Broad").texture.resource_path
		== "res://assets/battle/result/pvpBroad.png"
	)
	assert(summary.get_node("Center/Window/Broad").texture.get_size() == Vector2(977, 618))
	assert(summary.get_node("Center/Window/LeftPanel").position == Vector2(14, 41))
	assert(summary.get_node("Center/Window/ChatHost").position == Vector2(35, 401))
	assert(summary.get_node("Center/Window/RightPanel").position == Vector2(499, 4))
	assert(
		summary.get_node("Center/Window/ScoreHeader").texture.resource_path
		== "res://assets/battle/result/word_battlescore_2_t.png"
	)
	assert(summary.get_node("Center/Window/ScoreHeader").texture.get_size() == Vector2(52, 13))
	assert(summary.get_node("Center/Window/RightPanel/ExperienceHeader").texture.get_size() == Vector2(440, 48))
	assert(summary.get_node("Center/Window/RightPanel/CurrentLevelBadge/Base").size == Vector2(80, 40))
	assert(summary.get_node("Center/Window/RightPanel/NextLevelBadge/Base").size == Vector2(80, 40))
	assert(
		summary.get_node("Center/Window/RightPanel/CurrentLevelBadge/Base").texture.resource_path
		== "res://assets/ui/profile/level/level_15.png"
	)
	assert(
		summary.get_node("Center/Window/RightPanel/NextLevelBadge/Base").texture.resource_path
		== "res://assets/ui/profile/level/level_16.png"
	)
	assert(
		(summary.get_node("Center/Window/RightPanel/LevelPercent") as Label).text
		== "11.91%"
	)
	assert(
		(summary.get_node("Center/Window/RightPanel/LevelNumbers") as Label).text
		== "1548 / 13000"
	)
	assert(
		summary.get_node("Center/Window/RightPanel/CurrentLevelBadge").position
		== Vector2(2, 18)
	)
	assert(
		summary.get_node("Center/Window/RightPanel/NextLevelBadge").position
		== Vector2(394, 18)
	)
	assert(summary.get_node("Center/Window/RightPanel/LevelBarClip").size.x == 26.0)
	assert((team_1.get_node("Slot1/TankIcon") as TextureRect).size == Vector2(28, 28))
	assert(
		(team_1.get_node("Slot1/TankIcon") as TextureRect).texture.get_size()
		== Vector2(200, 200)
	)
	assert(
		String((team_1.get_node("Slot1/TankIcon") as TextureRect).texture.resource_path)
		== "res://assets/ui/tank/tank_ironman_reward.png"
	)
	assert(
		String((team_2.get_node("Slot1/TankIcon") as TextureRect).texture.resource_path)
		== "res://assets/battle/result_tanks/degula03.png"
	)
	var featured_honors := summary.get_node(
		"Center/Window/RightPanel/TankArea/FeaturedHonors"
	)
	assert(featured_honors.get_child_count() == 1)
	for honor_badge: Control in featured_honors.get_children():
		assert((honor_badge.get_child(0) as TextureRect).texture.get_size() == Vector2(55, 44))
		assert((honor_badge.get_child(1) as TextureRect).texture.get_size() == Vector2(42, 18))
	assert(
		(summary.get_node("Center/Window/RightPanel/TankArea/FeaturedName") as Label).text
		== "participant:2:1"
	)
	assert(
		(summary.get_node("Center/Window/RightPanel/TankArea/FeaturedTank") as TextureRect).texture.resource_path
		== "res://assets/battle/result_tanks/degula03.png"
	)
	assert(
		(summary.get_node("Center/Window/RightPanel/TankArea/FeaturedTank") as TextureRect).texture.get_size()
		== Vector2(200, 200)
	)
	assert(summary.has_node("Center/Window/RightPanel/TankArea/Owned"))
	assert(summary.has_node("Center/Window/RightPanel/TankArea/BuyTank"))
	assert(summary.has_node("Center/Window/RightPanel/TankArea/OtherRules"))
	assert(summary.has_node("Center/Window/ReturnCountdown"))
	assert(
		(summary.get_node("Center/Window/ReturnCountdown/Text") as Label).text
		== "10s"
	)
	assert(summary.get_node("Center/Window/RightPanel/AccountExpBackground").texture.get_size() == Vector2(416, 30))
	assert(
		summary.get_node("Center/Window/RightPanel/AccountExpBackground").z_index
		> summary.get_node("Center/Window/RightPanel/CoinSegments").z_index
	)
	assert(summary.get_node("Center/Window/RightPanel/TankArea").position == Vector2(14, 330))
	assert(summary.get_node("Center/Window/Exit").position == Vector2(715, 562))
	assert(summary.get_node("Center/Window/Leave").position == Vector2(584, 562))
	# Result actions must remain deferred until the release event has finished;
	# otherwise the same click can activate a lobby button revealed underneath.
	var exit_signal_count := [0]
	summary.exit_requested.connect(func() -> void:
		exit_signal_count[0] += 1
	)
	summary.call("_queue_exit_request")
	assert(summary.visible)
	assert(bool(summary.get("_action_queued")))
	assert(int(exit_signal_count[0]) == 0)
	await process_frame
	assert(int(exit_signal_count[0]) == 1)
	assert(bool(summary.get("_action_requested")))
	# A sparse match still retains all ten editable scene rows. Empty slots keep
	# their row graphics and simply have no runtime player text/icon.
	summary.show_result({
		"viewer_outcome": "lose",
		"winner_team_no": 2,
		"viewer_team_no": 1,
		"team_1_score": 0,
		"team_2_score": 1,
	}, [
		_player("player", 1, 1, 0, 1, 0),
		_player("participant:2:1", 2, 1, 1, 0, 0),
	], {}, "player")
	assert(not (team_1.get_node("WinIcon") as TextureRect).visible)
	assert((team_2.get_node("WinIcon") as TextureRect).visible)
	assert((team_1.get_node("Slot2/PlayerName") as Label).text.is_empty())
	assert((team_2.get_node("Slot5/Kda") as Label).text.is_empty())
	assert(team_1.get_node("Slot5/Separator").visible)
	assert(team_2.get_node("Slot5/KdaCell").visible)
	summary.reset()
	assert(not summary.visible)
	assert(shared_chat.get_parent() == shared_chat_parent)
	assert(shared_chat.get_node("Input").visible)
	summary.queue_free()
	shared_chat_parent.queue_free()
	await process_frame
	print("BATTLE_RESULT_SEQUENCE_SMOKE_OK")
	quit(0)


func _assert_segment(
	players: Array[Dictionary],
	expected_segment: String,
	expected_winners: int
) -> void:
	var result: Dictionary = CALCULATOR.calculate(players)
	assert(String(result.get("segment", "")) == expected_segment)
	assert((result.get("winners", []) as Array).size() == expected_winners)


func _p3_players() -> Array[Dictionary]:
	return [
		_player("player", 1, 1, 0, 2, 10),
		_player("participant:1:2", 1, 2, 8, 10, 0),
		_player("participant:2:1", 2, 1, 7, 0, 9),
	]


func _p2_players() -> Array[Dictionary]:
	return [
		_player("player", 1, 1, 1, 2, 9),
		_player("participant:2:1", 2, 1, 8, 0, 8),
	]


func _p1_players() -> Array[Dictionary]:
	return [
		_player("player", 1, 1, 9, 0, 10),
		_player("participant:2:1", 2, 1, 2, 3, 1),
	]


func _ten_players() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for team_no in [1, 2]:
		for slot_no in range(1, 6):
			var player := _player(
				"player" if team_no == 1 and slot_no == 1 else "participant:%d:%d" % [team_no, slot_no],
				team_no,
				slot_no,
				slot_no,
				1,
				6 - slot_no
			)
			if team_no == 2 and slot_no == 1:
				player["tank_key"] = "degula03"
			result.append(player)
	return result


func _player(
	combatant_key: String,
	team_no: int,
	slot_no: int,
	kills: int,
	deaths: int,
	assists: int
) -> Dictionary:
	return {
		"combatant_key": combatant_key,
		"display_name": combatant_key,
		"team_no": team_no,
		"slot_no": slot_no,
		"tank_key": "gangtiexia03",
		"kills": kills,
		"deaths": deaths,
		"assists": assists,
		"level": 15,
		"experience": 1548,
		"experience_max": 13000,
	}


func _make_shared_chat_mock() -> Control:
	var chat := Control.new()
	chat.name = "SharedChat"
	chat.size = Vector2(464, 256)
	var warning := TextureRect.new()
	warning.name = "Warning"
	warning.visible = true
	chat.add_child(warning)
	var history := Control.new()
	history.name = "History"
	history.position = Vector2(10, 20)
	history.size = Vector2(464, 163)
	chat.add_child(history)
	var input_control := Control.new()
	input_control.name = "Input"
	input_control.position = Vector2(0, 213)
	input_control.size = Vector2(464, 43)
	chat.add_child(input_control)
	return chat
