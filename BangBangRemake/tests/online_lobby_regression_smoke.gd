extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game_session := root.get_node("GameSession")
	game_session.set("account", {"id": "online-lobby-smoke"})
	game_session.set("profile", {
		"display_name": "Smoke",
		"gender": "male",
		"level": 15,
	})
	game_session.set("lobby_data", {
		"display_name": "Smoke",
		"gender": "male",
		"level": 15,
		"owned_tanks": [],
		"newcomer_tank_reward_claimed": true,
	})

	var roster := load(
		"res://scenes/auth/CharacterRoster.tscn"
	).instantiate() as Control
	root.add_child(roster)
	await process_frame
	var close_button := roster.get_node("Window/BtnClose") as TextureButton
	var level_base := roster.get_node("Window/Level/LevelBase") as TextureRect
	var level_effect := roster.get_node("Window/Level/LevelEffect") as Node2D
	assert(close_button.position == Vector2(728, 23))
	assert(close_button.size == Vector2(24, 24))
	assert(level_base.position == Vector2.ZERO)
	assert(level_base.size == Vector2(80, 40))
	assert(level_base.texture.get_size() == Vector2(80, 40))
	assert(level_effect.position == Vector2(40, 20))
	assert(level_effect.scale == Vector2.ONE)
	assert(level_effect.visible)

	var pvp_view := load(
		"res://scenes/lobby/pvp/hub/PvpRoomView.tscn"
	).instantiate() as Control
	root.add_child(pvp_view)
	await process_frame
	await process_frame
	pvp_view.call("_set_room_models", [{
		"room_code": "1001",
		"room_name": "Nullable room",
		"mode_key": "free",
		"map_key": "random",
		"map_name": null,
		"map_thumbnail_asset_path": null,
		"max_players": 5,
		"player_count": 1,
		"status": "waiting",
	}])
	assert((pvp_view.get_node(
		"Window/RoomList/Rows/Room1/Map"
	) as Label).text == "Bản đồ ngẫu nhiên")

	var ready_room := pvp_view.get_node("Window/ReadyRoom") as Control
	ready_room.call("set_room_data", {
		"room_code": "1001",
		"room_name": "Nullable room",
		"status": "waiting",
		"map_key": "random",
		"map_thumbnail_asset_path": null,
		"members": [{
			"display_name": "Smoke",
			"gender": "male",
			"level": 15,
			"tank_key": null,
			"tank_name": null,
			"equipped_skin_key": null,
			"is_captain": true,
		}],
	})
	assert((ready_room.get_node("RoomCode") as Label).text == "1001")
	assert((ready_room.get_node("Slots/Slot1/Member/TankName") as Label).text == "Tank")
	var map_selector := ready_room.get_node("MapSelector") as Control
	assert(map_selector.mouse_filter == Control.MOUSE_FILTER_STOP)
	assert((map_selector.get_node("Dim") as Control).mouse_filter == Control.MOUSE_FILTER_STOP)
	assert((map_selector.get_node("Window") as Control).mouse_filter == Control.MOUSE_FILTER_STOP)

	var admission_losses := [0]
	game_session.admission_lost.connect(func(_message: String) -> void:
		admission_losses[0] += 1
	)
	game_session.set("admission_active", true)
	game_session.call("_complete_request", 0, "/chat/messages", {
		"ok": false,
		"status": 409,
		"error": {
			"code": "ADMISSION_REQUIRED",
			"message": "Admission expired",
		},
	})
	game_session.call("_complete_request", 0, "/rooms", {
		"ok": false,
		"status": 409,
		"error": {"code": "ADMISSION_REQUIRED"},
	})
	assert(admission_losses[0] == 1)
	assert(not bool(game_session.get("admission_active")))

	print("ONLINE_LOBBY_REGRESSION_OK")
	quit()
