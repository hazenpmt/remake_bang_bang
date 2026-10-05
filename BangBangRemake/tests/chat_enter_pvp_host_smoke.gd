extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var token := OS.get_environment("CHAT_SMOKE_TOKEN")
	var body := OS.get_environment("CHAT_SMOKE_BODY")
	var api_base := OS.get_environment("CHAT_SMOKE_API_BASE")
	assert(not token.is_empty())
	assert(not body.is_empty())
	assert(not api_base.is_empty())

	var game_session := root.get_node("GameSession")
	game_session.set("api_base_url", api_base)
	game_session.set("token", token)
	game_session.set("admission_active", true)
	game_session.set("account", {"id": "chat-enter-pvp-smoke"})
	game_session.set("profile", {"display_name": "EnterBot"})
	game_session.set("lobby_data", {"display_name": "EnterBot"})

	var pvp := load(
		"res://scenes/lobby/pvp/hub/PvpRoomView.tscn"
	).instantiate() as Control
	root.add_child(pvp)
	var chat := load("res://scenes/lobby/LobbyChat.tscn").instantiate() as Control
	var bottom := Control.new()
	var right := Control.new()
	root.add_child(chat)
	root.add_child(bottom)
	root.add_child(right)
	await process_frame
	await process_frame
	pvp.call("bind_shared_controls", chat, bottom, right)
	pvp.call("open")
	await process_frame
	await process_frame

	var message := chat.get_node("Input/Message") as LineEdit
	message.text = body
	message.grab_focus()
	assert(message.has_focus())
	var enter := InputEventKey.new()
	enter.pressed = true
	enter.keycode = KEY_ENTER
	enter.physical_keycode = KEY_ENTER
	Input.parse_input_event(enter)

	var deadline := Time.get_ticks_msec() + 8000
	while not message.text.is_empty() and Time.get_ticks_msec() < deadline:
		await create_timer(0.05).timeout
	assert(message.text.is_empty())
	var result: Dictionary = await game_session.fetch_world_chat(0, 50)
	assert(result.get("ok", false))
	var found := false
	for value: Variant in result.get("messages", []):
		if value is Dictionary and str(value.get("body", "")) == body:
			found = true
			break
	assert(found)
	print("CHAT_ENTER_PVP_HOST_OK")
	quit()
