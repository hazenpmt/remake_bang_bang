extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var network_ux := root.get_node("NetworkUx")
	var game_session := root.get_node("GameSession")
	assert(network_ux.active_request_count() == 0)
	assert(not network_ux.is_blocking_input())
	game_session.interactive_request_started.emit(9001, "Đang kiểm tra...")
	await process_frame
	assert(network_ux.active_request_count() == 1)
	assert(network_ux.is_blocking_input())
	assert(not network_ux.is_loading_visible())
	await create_timer(0.35).timeout
	assert(network_ux.is_loading_visible())
	game_session.interactive_request_finished.emit(9001)
	await process_frame
	assert(network_ux.active_request_count() == 0)
	assert(not network_ux.is_blocking_input())
	assert(not network_ux.is_loading_visible())

	var timeout_result: Dictionary = game_session.call(
		"_connection_error", HTTPRequest.RESULT_TIMEOUT
	)
	assert(timeout_result.error.code == "NETWORK_TIMEOUT")
	game_session.interactive_request_failed.emit(9001, timeout_result)
	await process_frame
	var notification := network_ux.get_node("Notification") as Control
	assert(notification.visible)
	notification.call("confirm")
	assert(not notification.visible)
	game_session.session_expired.emit("Phiên đăng nhập đã hết hạn.")
	await process_frame
	assert(network_ux.is_session_dialog_open())
	assert(notification.visible)
	notification.call("confirm")
	assert(not network_ux.is_session_dialog_open())
	assert(not notification.visible)
	print("NETWORK_REQUEST_OVERLAY_OK")
	quit()
