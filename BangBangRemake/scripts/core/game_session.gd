extends Node

signal lobby_data_changed(data: Dictionary)

signal admission_lost(message: String)

signal interactive_request_started(request_id: int, message: String)
signal interactive_request_finished(request_id: int)
signal interactive_request_failed(request_id: int, result: Dictionary)
signal session_expired(message: String)
signal battle_realtime_snapshot_received(snapshot: Dictionary)
signal battle_realtime_state_changed(connected: bool)

const SESSION_FILE := "user://auth_session.json"
const DEVICE_ID_FILE := "user://device_id.txt"
const BATTLE_REALTIME_CLIENT := preload(
	"res://scripts/network/battle_realtime_client.gd"
)

var token := ""
var device_id := ""
var account: Dictionary = {}
var profile: Dictionary = {}
var lobby_data: Dictionary = {}
var game_room: Dictionary = {}
var shop_catalog: Dictionary = {}
var inventory: Dictionary = {}
var admission_active := false
var api_base_url := ""

var _heartbeat_timer: Timer
var _heartbeat_in_flight := false
var _close_requested := false
var _next_request_id := 1
var _session_expiry_emitted := false
var _admission_loss_emitted := false
var _battle_realtime: Node
var _battle_realtime_generation := 0
var _battle_ticket_in_flight := false


func is_admin() -> bool:
	return String(account.get("role", "player")) == "admin"


func _ready() -> void:
	get_tree().auto_accept_quit = false
	api_base_url = String(
		ProjectSettings.get_setting("network/api_base_url", "http://127.0.0.1:8080/api")
	).trim_suffix("/")
	if (
		api_base_url.begins_with("http://")
		and not api_base_url.begins_with("http://127.0.0.1")
		and not api_base_url.begins_with("http://localhost")
	):
		push_error("Máy chủ online phải dùng HTTPS để bảo vệ mật khẩu và token.")
	_heartbeat_timer = Timer.new()
	_heartbeat_timer.one_shot = false
	_heartbeat_timer.wait_time = 20.0
	_heartbeat_timer.timeout.connect(_send_presence_heartbeat)
	add_child(_heartbeat_timer)
	_battle_realtime = BATTLE_REALTIME_CLIENT.new()
	_battle_realtime.snapshot_received.connect(
		func(snapshot: Dictionary) -> void:
			battle_realtime_snapshot_received.emit(snapshot)
	)
	_battle_realtime.state_changed.connect(
		func(connected: bool) -> void:
			battle_realtime_state_changed.emit(connected)
	)
	_battle_realtime.ticket_requested.connect(_refresh_battle_realtime_ticket)
	add_child(_battle_realtime)
	_load_or_create_device_id()
	_discard_saved_session_file()


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST or _close_requested:
		return
	_close_requested = true
	call_deferred("_leave_admission_and_quit")


func _leave_admission_and_quit() -> void:
	await leave_admission(1.5)
	get_tree().quit()


func register_account(username: String, password: String) -> Dictionary:
	var result := await _request_json(
		HTTPClient.METHOD_POST,
		"/auth/register",
		{"username": username, "password": password}
	)
	if result.get("ok", false):
		_apply_auth_response(result)
	return result


func login_account(username: String, password: String) -> Dictionary:
	var result := await _request_json(
		HTTPClient.METHOD_POST,
		"/auth/login",
		{"username": username, "password": password}
	)
	if result.get("ok", false):
		_apply_auth_response(result)
	return result


func validate_saved_session() -> Dictionary:
	if token.is_empty():
		return {
			"ok": false,
			"error": {"message": "Chưa có phiên đăng nhập đã lưu."},
		}

	var result := await _request_json(HTTPClient.METHOD_GET, "/auth/session")
	if result.get("ok", false):
		_apply_auth_response(result, false)
	else:
		clear_session()
	return result


func create_character(display_name: String, gender: String) -> Dictionary:
	var result := await _request_json(
		HTTPClient.METHOD_POST,
		"/characters",
		{"display_name": display_name, "gender": gender}
	)
	if result.get("ok", false):
		_apply_auth_response(result, false)
	return result


func fetch_lobby() -> Dictionary:
	var result := await _request_json(HTTPClient.METHOD_GET, "/lobby")
	if result.get("ok", false):
		apply_lobby_data(result.get("lobby", {}))
	return result


func fetch_shop_catalog() -> Dictionary:
	var result := await _request_action(
		HTTPClient.METHOD_GET,
		"/shop/catalog",
		{},
		"Đang tải Shop..."
	)
	if result.get("ok", false):
		var value: Variant = result.get("catalog", {})
		shop_catalog = value if value is Dictionary else {}
		_apply_economy_balances(shop_catalog.get("balances", {}))
	return result


func begin_interactive_task(message: String) -> int:
	var request_id := _next_request_id
	_next_request_id += 1
	interactive_request_started.emit(request_id, message)
	return request_id


func finish_interactive_task(request_id: int, result: Dictionary = {"ok": true}) -> void:
	interactive_request_finished.emit(request_id)
	if not result.get("ok", false):
		interactive_request_failed.emit(request_id, result)


func fetch_inventory() -> Dictionary:
	var result := await _request_action(
		HTTPClient.METHOD_GET,
		"/inventory",
		{},
		"Đang tải kho..."
	)
	if result.get("ok", false):
		var value: Variant = result.get("inventory", {})
		inventory = value if value is Dictionary else {}
		_apply_economy_balances(inventory.get("balances", {}))
	return result


func purchase_shop_offer(
	offer_id: String,
	quantity: int,
	idempotency_key: String
) -> Dictionary:
	var result := await _request_action(
		HTTPClient.METHOD_POST,
		"/shop/purchases",
		{"offer_id": offer_id, "quantity": quantity},
		"Đang xác nhận giao dịch...",
		10.0,
		PackedStringArray(["Idempotency-Key: %s" % idempotency_key])
	)
	if result.get("ok", false):
		var purchase: Dictionary = result.get("purchase", {})
		_apply_economy_balances(purchase.get("balances", {}))
	return result


func _apply_economy_balances(value: Variant) -> void:
	if not value is Dictionary:
		return
	var balances := value as Dictionary
	for currency in [&"xu", &"locked_xu", &"silver"]:
		if balances.has(currency):
			lobby_data[currency] = maxi(0, int(balances[currency]))
	notify_lobby_data_changed()


func set_primary_tank(tank_key: String) -> Dictionary:
	var result := await _request_action(
		HTTPClient.METHOD_POST,
		"/tanks/primary",
		{"tank_key": tank_key},
		"Đang đổi Tank chính..."
	)
	if result.get("ok", false):
		var lobby_value: Variant = result.get("lobby", {})
		apply_lobby_data(lobby_value)
	return result


func equip_tank_skin(tank_key: String, skin_key: String) -> Dictionary:
	var result := await _request_action(
		HTTPClient.METHOD_POST,
		"/tanks/skin/equip",
		{"tank_key": tank_key, "skin_key": skin_key},
		"Đang trang bị Skin..."
	)
	if result.get("ok", false):
		var lobby_value: Variant = result.get("lobby", {})
		apply_lobby_data(lobby_value)
	return result


func claim_newcomer_tank() -> Dictionary:
	var result := await _request_action(
		HTTPClient.METHOD_POST,
		"/rewards/newcomer-tank/claim",
		{},
		"Đang nhận phần thưởng..."
	)
	if result.get("ok", false):
		var lobby_value: Variant = result.get("lobby", {})
		apply_lobby_data(lobby_value)
	return result


func apply_lobby_data(value: Variant) -> void:
	lobby_data = value if value is Dictionary else {}
	lobby_data_changed.emit(lobby_data)


func notify_lobby_data_changed() -> void:
	lobby_data_changed.emit(lobby_data)


func fetch_world_chat(after_id: int = 0, limit: int = 50) -> Dictionary:
	var safe_after_id := maxi(0, after_id)
	var safe_limit := clampi(limit, 1, 50)
	return await _request_json(
		HTTPClient.METHOD_GET,
		"/chat/messages?after_id=%d&limit=%d" % [safe_after_id, safe_limit]
	)


func send_world_chat(message: String) -> Dictionary:
	return await _request_json(
		HTTPClient.METHOD_POST,
		"/chat/messages",
		{"message": message}
	)


func fetch_social_players(tab_key: String) -> Dictionary:
	var safe_tab := tab_key if tab_key in ["guild", "friends", "room"] else "guild"
	return await _request_json(
		HTTPClient.METHOD_GET,
		"/social/players?tab=%s" % safe_tab
	)


func invite_social_player_to_room(account_id: String) -> Dictionary:
	return await _request_action(
		HTTPClient.METHOD_POST,
		"/social/room-invitations",
		{"account_id": account_id},
		"Đang gửi lời mời..."
	)


func fetch_friends(view_key: String = "friends", search: String = "") -> Dictionary:
	var safe_view := (
		view_key
		if view_key in ["friends", "blocked", "requests", "search"]
		else "friends"
	)
	var path := "/friends?view=%s" % safe_view
	if safe_view == "search":
		path += "&q=%s" % search.strip_edges().uri_encode()
	return await _request_action(
		HTTPClient.METHOD_GET, path, {}, "Đang tải danh sách người chơi..."
	)


func send_friend_request(account_id: String) -> Dictionary:
	return await _request_action(
		HTTPClient.METHOD_POST,
		"/friends/requests",
		{"account_id": account_id},
		"Đang gửi lời mời kết bạn..."
	)


func accept_friend_request(account_id: String) -> Dictionary:
	return await _request_action(
		HTTPClient.METHOD_POST,
		"/friends/requests/accept",
		{"account_id": account_id},
		"Đang chấp nhận lời mời..."
	)


func decline_friend_request(account_id: String) -> Dictionary:
	return await _request_action(
		HTTPClient.METHOD_POST,
		"/friends/requests/decline",
		{"account_id": account_id},
		"Đang từ chối lời mời..."
	)


func remove_friend(account_id: String) -> Dictionary:
	return await _request_action(
		HTTPClient.METHOD_POST,
		"/friends/remove",
		{"account_id": account_id},
		"Đang xóa bạn..."
	)


func block_player(account_id: String) -> Dictionary:
	return await _request_action(
		HTTPClient.METHOD_POST,
		"/friends/block",
		{"account_id": account_id},
		"Đang chặn người chơi..."
	)


func unblock_player(account_id: String) -> Dictionary:
	return await _request_action(
		HTTPClient.METHOD_POST,
		"/friends/unblock",
		{"account_id": account_id},
		"Đang bỏ chặn..."
	)


func fetch_game_match_team_chat(after_id: int = 0, limit: int = 50) -> Dictionary:
	var safe_after_id := maxi(0, after_id)
	var safe_limit := clampi(limit, 1, 50)
	return await _request_json(
		HTTPClient.METHOD_GET,
		"/rooms/match/chat?after_id=%d&limit=%d" % [safe_after_id, safe_limit]
	)


func send_game_match_team_chat(message: String) -> Dictionary:
	return await _request_json(
		HTTPClient.METHOD_POST,
		"/rooms/match/chat",
		{"message": message}
	)


func fetch_game_match_chat(
	channel: String,
	after_id: int = 0,
	limit: int = 50
) -> Dictionary:
	var safe_channel := "battle" if channel == "battle" else "team"
	var safe_after_id := maxi(0, after_id)
	var safe_limit := clampi(limit, 1, 50)
	return await _request_json(
		HTTPClient.METHOD_GET,
		"/rooms/match/chat?channel=%s&after_id=%d&limit=%d"
		% [safe_channel, safe_after_id, safe_limit]
	)


func send_game_match_chat(message: String, channel: String) -> Dictionary:
	var safe_channel := "battle" if channel == "battle" else "team"
	return await _request_json(
		HTTPClient.METHOD_POST,
		"/rooms/match/chat",
		{"message": message, "channel": safe_channel}
	)


func fetch_game_rooms(tab_key: String) -> Dictionary:
	return await _request_json(
		HTTPClient.METHOD_GET,
		"/rooms?tab=%s" % tab_key
	)


func fetch_current_game_room() -> Dictionary:
	var result := await _request_json(HTTPClient.METHOD_GET, "/rooms/current")
	if result.get("ok", false):
		var room_value: Variant = result.get("room", {})
		game_room = room_value if room_value is Dictionary else {}
	return result


func fetch_game_maps() -> Dictionary:
	return await _request_json(HTTPClient.METHOD_GET, "/rooms/maps")


func create_game_room(
	tab_key: String,
	room_name: String,
	mode_key: String = "free",
	map_key: String = "random"
) -> Dictionary:
	var result := await _request_action(
		HTTPClient.METHOD_POST,
		"/rooms/create",
		{
			"tab_key": tab_key,
			"room_name": room_name,
			"mode_key": mode_key,
			"map_key": map_key,
		},
		"Đang tạo phòng..."
	)
	_apply_game_room_result(result)
	return result


func join_game_room(room_code: String) -> Dictionary:
	var result := await _request_action(
		HTTPClient.METHOD_POST,
		"/rooms/join",
		{"room_code": room_code},
		"Đang vào phòng..."
	)
	_apply_game_room_result(result)
	return result


func quick_join_game_room(tab_key: String) -> Dictionary:
	var result := await _request_action(
		HTTPClient.METHOD_POST,
		"/rooms/quick-join",
		{"tab_key": tab_key},
		"Đang tìm phòng phù hợp..."
	)
	_apply_game_room_result(result)
	return result


func select_game_room_map(map_key: String) -> Dictionary:
	var result := await _request_action(
		HTTPClient.METHOD_POST,
		"/rooms/map",
		{"map_key": map_key},
		"Đang đổi bản đồ..."
	)
	_apply_game_room_result(result)
	return result


func start_game_room() -> Dictionary:
	var result := await _request_action(
		HTTPClient.METHOD_POST, "/rooms/start", {}, "Đang bắt đầu ghép trận..."
	)
	_apply_game_room_result(result)
	return result


func cancel_game_room_matchmaking() -> Dictionary:
	var result := await _request_action(
		HTTPClient.METHOD_POST,
		"/rooms/cancel-matchmaking",
		{},
		"Đang hủy ghép trận..."
	)
	_apply_game_room_result(result)
	return result


func fetch_current_game_match() -> Dictionary:
	return await _request_json(HTTPClient.METHOD_GET, "/rooms/match")


func confirm_game_match() -> Dictionary:
	return await _request_action(
		HTTPClient.METHOD_POST, "/rooms/match/confirm", {}, "Đang xác nhận trận..."
	)


func select_game_match_tank(tank_key: String) -> Dictionary:
	return await _request_action(
		HTTPClient.METHOD_POST,
		"/rooms/match/tank",
		{"tank_key": tank_key},
		"Đang chọn Tank..."
	)


func equip_game_match_skin(tank_key: String, skin_key: String) -> Dictionary:
	var result := await _request_action(
		HTTPClient.METHOD_POST,
		"/rooms/match/skin",
		{"tank_key": tank_key, "skin_key": skin_key},
		"Đang trang bị Skin..."
	)
	if result.get("ok", false):
		# The match snapshot is already atomically updated by the server. Refresh
		# lobby data separately so all lobby/PvP visuals use the saved skin now.
		await fetch_lobby()
	return result


func deploy_game_match_tank() -> Dictionary:
	return await _request_action(
		HTTPClient.METHOD_POST, "/rooms/match/deploy", {}, "Đang xuất trận..."
	)


func report_game_match_load(progress: int) -> Dictionary:
	return await _request_json(
		HTTPClient.METHOD_POST,
		"/rooms/match/load",
		{"progress": clampi(progress, 0, 100)}
	)


func fetch_game_match_battle_snapshot() -> Dictionary:
	if is_battle_realtime_ready():
		var realtime_result: Dictionary = await _battle_realtime.request_snapshot()
		if bool(realtime_result.get("ok", false)):
			return realtime_result
		var realtime_error: Dictionary = realtime_result.get("error", {})
		if String(realtime_error.get("code", "")) not in [
			"NETWORK_TIMEOUT", "NETWORK_UNAVAILABLE"
		]:
			return realtime_result
	return await _request_json(
		HTTPClient.METHOD_GET,
		"/rooms/match/battle",
		{},
		3.0
	)


func submit_game_match_battle_command(
	sequence: int,
	command: Dictionary
) -> Dictionary:
	if is_battle_realtime_ready():
		var realtime_result: Dictionary = await _battle_realtime.submit_command(
			sequence,
			command
		)
		if bool(realtime_result.get("ok", false)):
			return realtime_result
		var realtime_error: Dictionary = realtime_result.get("error", {})
		if String(realtime_error.get("code", "")) not in [
			"NETWORK_TIMEOUT", "NETWORK_UNAVAILABLE"
		]:
			return realtime_result
	return await _request_json(
		HTTPClient.METHOD_POST,
		"/rooms/match/battle/commands",
		{
			"sequence": sequence,
			"command": command,
		},
		3.0
	)


func open_battle_realtime() -> void:
	if _battle_realtime == null or token.is_empty():
		return
	if _battle_realtime.is_desired():
		return
	_battle_realtime_generation += 1
	_battle_realtime.start(api_base_url, device_id)


func _refresh_battle_realtime_ticket() -> void:
	if _battle_ticket_in_flight or token.is_empty() or _battle_realtime == null:
		return
	_battle_ticket_in_flight = true
	var generation := _battle_realtime_generation
	var result := await _request_json(
		HTTPClient.METHOD_POST,
		"/rooms/match/battle/realtime-ticket",
		{},
		3.0
	)
	_battle_ticket_in_flight = false
	if generation != _battle_realtime_generation or _battle_realtime == null:
		return
	if not bool(result.get("ok", false)):
		_battle_realtime.ticket_request_failed()
		return
	var url_value: Variant = result.get("websocket_url", "")
	var websocket_url := String(url_value) if url_value is String else ""
	_battle_realtime.provide_ticket(
		String(result.get("ticket", "")),
		websocket_url
	)


func close_battle_realtime() -> void:
	_battle_realtime_generation += 1
	_battle_ticket_in_flight = false
	if _battle_realtime != null:
		_battle_realtime.close()


func is_battle_realtime_ready() -> bool:
	return _battle_realtime != null and _battle_realtime.is_usable()


func leave_game_room() -> Dictionary:
	var result := await _request_action(
		HTTPClient.METHOD_POST, "/rooms/leave", {}, "Đang rời phòng..."
	)
	if result.get("ok", false):
		game_room.clear()
	return result


func _apply_game_room_result(result: Dictionary) -> void:
	if not result.get("ok", false):
		return
	var room_value: Variant = result.get("room", {})
	game_room = room_value if room_value is Dictionary else {}


func join_admission() -> Dictionary:
	return await _request_json(HTTPClient.METHOD_POST, "/admission/join")


func get_admission_status() -> Dictionary:
	return await _request_json(HTTPClient.METHOD_GET, "/admission/status")


func start_presence_heartbeat(interval_seconds: float = 20.0) -> void:
	admission_active = true
	_admission_loss_emitted = false
	_heartbeat_timer.wait_time = maxf(5.0, interval_seconds)
	_heartbeat_timer.start()


func leave_admission(request_timeout_seconds: float = 10.0) -> void:
	if not token.is_empty():
		await _request_json(
			HTTPClient.METHOD_POST,
			"/admission/leave",
			{},
			request_timeout_seconds
		)
	_stop_presence_heartbeat()


func logout() -> void:
	if not token.is_empty():
		await _request_json(HTTPClient.METHOD_POST, "/auth/logout")
	clear_session()


func clear_session() -> void:
	_stop_presence_heartbeat()
	close_battle_realtime()
	token = ""
	account.clear()
	profile.clear()
	apply_lobby_data({})
	game_room.clear()
	shop_catalog.clear()
	inventory.clear()
	_discard_saved_session_file()


func _send_presence_heartbeat() -> void:
	if not admission_active or _heartbeat_in_flight or token.is_empty():
		return
	_heartbeat_in_flight = true
	var result := await _request_json(HTTPClient.METHOD_POST, "/admission/heartbeat")
	_heartbeat_in_flight = false
	if result.get("ok", false):
		return
	if int(result.get("status", 0)) == 0:
		return
	if _admission_loss_emitted:
		return
	_admission_loss_emitted = true
	_stop_presence_heartbeat()
	var error_value: Variant = result.get("error", {})
	var error: Dictionary = error_value if error_value is Dictionary else {}
	admission_lost.emit(str(error.get("message", "Suất online đã hết hạn.")))


func _stop_presence_heartbeat() -> void:
	admission_active = false
	_heartbeat_in_flight = false
	if _heartbeat_timer != null:
		_heartbeat_timer.stop()


func _request_json(
	method: HTTPClient.Method,
	path: String,
	body: Dictionary = {},
	request_timeout_seconds: float = 10.0,
	interactive := false,
	loading_message := "Đang kết nối máy chủ...",
	extra_headers := PackedStringArray()
) -> Dictionary:
	var request_id := 0
	if interactive:
		request_id = _next_request_id
		_next_request_id += 1
		interactive_request_started.emit(request_id, loading_message)
	var request := HTTPRequest.new()
	request.timeout = request_timeout_seconds
	add_child(request)

	var headers := PackedStringArray(["Content-Type: application/json"])
	if not device_id.is_empty():
		headers.append("X-Device-Id: %s" % device_id)
	if not token.is_empty():
		headers.append("Authorization: Bearer %s" % token)
	for header in extra_headers:
		if header.contains("\r") or header.contains("\n"):
			continue
		headers.append(header)

	var request_body := ""
	if method != HTTPClient.METHOD_GET:
		request_body = JSON.stringify(body)

	var start_error := request.request(
		api_base_url + path,
		headers,
		method,
		request_body
	)
	if start_error != OK:
		request.queue_free()
		return _complete_request(
			request_id, path, _connection_error(HTTPRequest.RESULT_CANT_CONNECT)
		)

	var response: Array = await request.request_completed
	request.queue_free()

	var transport_result: int = response[0]
	var response_code: int = response[1]
	var response_body: PackedByteArray = response[3]
	if transport_result != HTTPRequest.RESULT_SUCCESS:
		return _complete_request(
			request_id, path, _connection_error(transport_result)
		)

	var parsed: Variant = JSON.parse_string(response_body.get_string_from_utf8())
	if not (parsed is Dictionary):
		return _complete_request(request_id, path, {
			"ok": false,
			"status": response_code,
			"error": {
				"code": "INVALID_SERVER_RESPONSE",
				"message": "Máy chủ trả về dữ liệu không hợp lệ.",
			},
		})

	var result: Dictionary = parsed
	result["status"] = response_code
	return _complete_request(request_id, path, result)


func _complete_request(
	request_id: int,
	path: String,
	result: Dictionary
) -> Dictionary:
	_handle_session_expiry(path, result)
	_handle_admission_expiry(path, result)
	if request_id > 0:
		interactive_request_finished.emit(request_id)
		if not result.get("ok", false):
			interactive_request_failed.emit(request_id, result)
	return result


func _handle_admission_expiry(path: String, result: Dictionary) -> void:
	if (
		int(result.get("status", 0)) != 409
		or path.begins_with("/admission/")
		or path == "/chat/messages"
		or _admission_loss_emitted
	):
		return
	var error_value: Variant = result.get("error", {})
	var error: Dictionary = error_value if error_value is Dictionary else {}
	var code := str(error.get("code", ""))
	if code not in ["ADMISSION_REQUIRED", "ADMISSION_EXPIRED"]:
		return
	_admission_loss_emitted = true
	_stop_presence_heartbeat()
	admission_lost.emit(str(error.get("message", "Suất online đã hết hạn.")))


func _handle_session_expiry(path: String, result: Dictionary) -> void:
	if (
		int(result.get("status", 0)) != 401
		or token.is_empty()
		or path.begins_with("/auth/")
		or _session_expiry_emitted
	):
		return
	_session_expiry_emitted = true
	var error: Dictionary = result.get("error", {})
	var message := String(
		error.get("message", "Phiên đăng nhập đã hết hạn.")
	)
	clear_session()
	session_expired.emit(message)


func _connection_error(transport_result: int) -> Dictionary:
	var timed_out := transport_result == HTTPRequest.RESULT_TIMEOUT
	return {
		"ok": false,
		"status": 0,
		"error": {
			"code": "NETWORK_TIMEOUT" if timed_out else "NETWORK_UNAVAILABLE",
			"message": (
				"Yêu cầu quá thời gian chờ. Vui lòng kiểm tra mạng và thử lại."
				if timed_out
				else "Không kết nối được máy chủ. Vui lòng kiểm tra mạng và thử lại."
			),
		},
	}


func _request_action(
	method: HTTPClient.Method,
	path: String,
	body: Dictionary = {},
	loading_message := "Đang xử lý...",
	request_timeout_seconds := 10.0,
	extra_headers := PackedStringArray()
) -> Dictionary:
	return await _request_json(
		method,
		path,
		body,
		request_timeout_seconds,
		true,
		loading_message,
		extra_headers
	)


func _apply_auth_response(result: Dictionary, _save_token_to_disk := true) -> void:
	_session_expiry_emitted = false
	if result.has("token"):
		token = String(result["token"])
	var account_value: Variant = result.get("account", {})
	var profile_value: Variant = result.get("profile", {})
	account = account_value if account_value is Dictionary else {}
	profile = profile_value if profile_value is Dictionary else {}


func _discard_saved_session_file() -> void:
	if FileAccess.file_exists(SESSION_FILE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SESSION_FILE))


func _load_or_create_device_id() -> void:
	if FileAccess.file_exists(DEVICE_ID_FILE):
		var existing := FileAccess.open(DEVICE_ID_FILE, FileAccess.READ)
		if existing != null:
			var candidate := existing.get_as_text().strip_edges()
			if candidate.length() >= 32 and candidate.length() <= 128:
				device_id = candidate
				return

	device_id = Crypto.new().generate_random_bytes(32).hex_encode()
	var file := FileAccess.open(DEVICE_ID_FILE, FileAccess.WRITE)
	if file == null:
		push_error("Không thể lưu mã cài đặt của máy.")
		device_id = ""
		return
	file.store_string(device_id)
