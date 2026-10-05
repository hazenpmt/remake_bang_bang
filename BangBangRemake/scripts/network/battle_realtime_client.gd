extends Node

signal snapshot_received(snapshot: Dictionary)
signal state_changed(connected: bool)
signal ticket_requested()

const TRANSPORT_VERSION := 3
const BATTLE_PROTOCOL_VERSION := 2
const REQUEST_TIMEOUT_SECONDS := 3.0
const RECONNECT_MAX_SECONDS := 5.0

var _peer: WebSocketPeer
var _desired := false
var _usable := false
var _hello_valid := false
var _api_base_url := ""
var _ticket := ""
var _device_id := ""
var _explicit_websocket_url := ""
var _ticket_request_pending := false
var _next_request_id := 1
var _pending: Dictionary = {}
var _reconnect_attempt := 0
var _reconnect_at_ms := 0
var _stream_snapshot: Dictionary = {}
var _stream_serial := 0


func start(api_base_url: String, device_id: String) -> void:
	var unchanged := (
		_desired
		and _api_base_url == api_base_url
		and _device_id == device_id
	)
	_desired = true
	_api_base_url = api_base_url
	_device_id = device_id
	if unchanged and _peer != null and (
		_peer.get_ready_state() != WebSocketPeer.STATE_CLOSED
	):
		return
	_disconnect_peer(false)
	_request_ticket()


func provide_ticket(ticket: String, websocket_url: String = "") -> void:
	_ticket_request_pending = false
	if not _desired or ticket.is_empty():
		return
	_ticket = ticket
	_explicit_websocket_url = websocket_url
	_reconnect_at_ms = 0
	_connect_peer()


func ticket_request_failed() -> void:
	_ticket_request_pending = false
	if _desired:
		_schedule_reconnect()


func close() -> void:
	_desired = false
	_reconnect_at_ms = 0
	_reconnect_attempt = 0
	_disconnect_peer(true)
	_ticket = ""
	_explicit_websocket_url = ""
	_ticket_request_pending = false


func is_usable() -> bool:
	return _usable and _peer != null and (
		_peer.get_ready_state() == WebSocketPeer.STATE_OPEN
	)


func is_desired() -> bool:
	return _desired


func request_snapshot() -> Dictionary:
	return await _request({"type": "snapshot_request"})


func submit_command(sequence: int, command: Dictionary) -> Dictionary:
	return await _request({
		"type": "command",
		"sequence": sequence,
		"command": command.duplicate(true),
	})


func _process(_delta: float) -> void:
	if _peer == null:
		if (
			_desired
			and _reconnect_at_ms > 0
			and Time.get_ticks_msec() >= _reconnect_at_ms
		):
			_reconnect_at_ms = 0
			_request_ticket()
		return
	_peer.poll()
	var state := _peer.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		while _peer.get_available_packet_count() > 0:
			var packet := _peer.get_packet()
			if not _peer.was_string_packet():
				_peer.close(1003, "Text JSON messages are required.")
				return
			_handle_message(packet.get_string_from_utf8())
	elif state == WebSocketPeer.STATE_CLOSED:
		_disconnect_peer(false)
		_schedule_reconnect()


func _connect_peer() -> void:
	if not _desired or _ticket.is_empty():
		return
	_peer = WebSocketPeer.new()
	_peer.inbound_buffer_size = 512 * 1024
	_peer.outbound_buffer_size = 64 * 1024
	_peer.max_queued_packets = 128
	_peer.heartbeat_interval = 10.0
	var headers := PackedStringArray(["X-Battle-Ticket: %s" % _ticket])
	if not _device_id.is_empty():
		headers.append("X-Device-Id: %s" % _device_id)
	_peer.handshake_headers = headers
	var error := _peer.connect_to_url(_websocket_url())
	if error != OK:
		_disconnect_peer(false)
		_schedule_reconnect()


func _websocket_url() -> String:
	if not _explicit_websocket_url.is_empty():
		return _explicit_websocket_url
	var result := _api_base_url + "/realtime/battle"
	if result.begins_with("https://"):
		return "wss://" + result.trim_prefix("https://")
	if result.begins_with("http://"):
		return "ws://" + result.trim_prefix("http://")
	return result


func _disconnect_peer(graceful: bool) -> void:
	var was_usable := _usable
	_usable = false
	_hello_valid = false
	_stream_snapshot.clear()
	_stream_serial = 0
	_fail_pending(_network_error("Kết nối trận realtime đã bị ngắt."))
	if _peer != null and graceful and (
		_peer.get_ready_state() == WebSocketPeer.STATE_OPEN
	):
		_peer.close(1000, "Battle client closed.")
	_peer = null
	_ticket = ""
	_explicit_websocket_url = ""
	if was_usable:
		state_changed.emit(false)


func _request_ticket() -> void:
	if not _desired or _ticket_request_pending:
		return
	_ticket_request_pending = true
	ticket_requested.emit()


func _schedule_reconnect() -> void:
	if not _desired:
		return
	var delay_seconds := minf(
		RECONNECT_MAX_SECONDS,
		0.5 * pow(2.0, float(_reconnect_attempt))
	)
	_reconnect_attempt = mini(_reconnect_attempt + 1, 8)
	_reconnect_at_ms = Time.get_ticks_msec() + int(delay_seconds * 1000.0)


func _handle_message(text: String) -> void:
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return
	var message: Dictionary = parsed
	var message_type := String(message.get("type", ""))
	if message_type == "hello":
		_hello_valid = (
			int(message.get("transport_version", 0)) == TRANSPORT_VERSION
			and int(message.get("protocol_version", 0)) == BATTLE_PROTOCOL_VERSION
		)
		if not _hello_valid:
			_peer.close(1002, "Unsupported battle protocol.")
		return
	if message_type == "snapshot":
		var pushed: Variant = message.get("snapshot", {})
		var snapshot_serial := int(message.get("snapshot_serial", 0))
		if not _hello_valid:
			return
		if (
			not pushed is Dictionary
			or snapshot_serial <= _stream_serial
			or int((pushed as Dictionary).get("protocol_version", 0))
			!= BATTLE_PROTOCOL_VERSION
			or String((pushed as Dictionary).get("match_id", "")).is_empty()
		):
			_reject_stream("Invalid full battle snapshot.")
			return
		_stream_snapshot = (pushed as Dictionary).duplicate(true)
		_stream_serial = snapshot_serial
		if not _usable:
			_usable = true
			_reconnect_attempt = 0
			_reconnect_at_ms = 0
			state_changed.emit(true)
		snapshot_received.emit(_stream_snapshot.duplicate(true))
		return
	if message_type == "snapshot_delta":
		if not _accept_snapshot_delta(message):
			_reject_stream("Battle snapshot baseline mismatch.")
		return
	if message_type == "pong":
		return
	var request_id := int(message.get("request_id", 0))
	if request_id <= 0 or not _pending.has(request_id):
		return
	if message_type in ["command_result", "snapshot_result"]:
		_pending[request_id] = message.duplicate(true)
	elif message_type == "error":
		_pending[request_id] = {
			"ok": false,
			"status": int(message.get("status", 0)),
			"error": message.get("error", {}).duplicate(true),
		}


func _accept_snapshot_delta(message: Dictionary) -> bool:
	if not _hello_valid or _stream_snapshot.is_empty() or _stream_serial <= 0:
		return false
	var base_serial := int(message.get("base_snapshot_serial", 0))
	var snapshot_serial := int(message.get("snapshot_serial", 0))
	if base_serial != _stream_serial or snapshot_serial != base_serial + 1:
		return false
	if (
		String(message.get("match_id", ""))
		!= String(_stream_snapshot.get("match_id", ""))
		or int(message.get("state_epoch", 0))
		!= int(_stream_snapshot.get("state_epoch", 0))
		or int(message.get("base_revision", -1))
		!= int(_stream_snapshot.get("revision", -2))
	):
		return false
	var raw_delta: Variant = message.get("delta", {})
	if not raw_delta is Dictionary:
		return false
	var reconstructed := _apply_snapshot_delta(
		_stream_snapshot,
		raw_delta as Dictionary
	)
	if reconstructed.is_empty():
		return false
	if (
		String(reconstructed.get("match_id", ""))
		!= String(message.get("match_id", ""))
		or int(reconstructed.get("state_epoch", 0))
		!= int(message.get("state_epoch", 0))
		or int(reconstructed.get("revision", -1))
		!= int(message.get("revision", -2))
	):
		return false
	_stream_snapshot = reconstructed
	_stream_serial = snapshot_serial
	snapshot_received.emit(_stream_snapshot.duplicate(true))
	return true


func _apply_snapshot_delta(previous: Dictionary, delta: Dictionary) -> Dictionary:
	var raw_set: Variant = delta.get("set", {})
	var raw_unset: Variant = delta.get("unset", [])
	var entity_patches: Variant = delta.get("entities", [])
	var world_patches: Variant = delta.get("world_entities", [])
	if (
		not raw_set is Dictionary
		or not raw_unset is Array
		or not entity_patches is Array
		or not world_patches is Array
	):
		return {}
	var result := previous.duplicate(true)
	for raw_key: Variant in (raw_set as Dictionary).keys():
		var key := String(raw_key)
		if key in ["entities", "world_entities"]:
			return {}
		result[key] = (raw_set as Dictionary)[raw_key]
	for raw_key: Variant in raw_unset as Array:
		if not raw_key is String:
			return {}
		var key := String(raw_key)
		if key in ["entities", "world_entities"]:
			return {}
		result.erase(key)
	if not _patch_snapshot_rows(
		result,
		"entities",
		entity_patches as Array,
		["team_no", "slot_no"]
	):
		return {}
	if not _patch_snapshot_rows(
		result,
		"world_entities",
		world_patches as Array,
		["entity_key"]
	):
		return {}
	return result


func _patch_snapshot_rows(
	snapshot: Dictionary,
	field: String,
	patches: Array,
	key_fields: Array[String]
) -> bool:
	var raw_rows: Variant = snapshot.get(field, [])
	if not raw_rows is Array:
		return false
	var rows: Array = (raw_rows as Array).duplicate(true)
	var index_by_key: Dictionary = {}
	for index in range(rows.size()):
		if not rows[index] is Dictionary:
			return false
		var row_key := _snapshot_row_key(rows[index] as Dictionary, key_fields)
		if row_key.is_empty() or index_by_key.has(row_key):
			return false
		index_by_key[row_key] = index
	for raw_patch: Variant in patches:
		if not raw_patch is Dictionary:
			return false
		var patch: Dictionary = raw_patch
		var row_key := _snapshot_row_key(patch, key_fields)
		var raw_patch_set: Variant = patch.get("set", {})
		var raw_patch_unset: Variant = patch.get("unset", [])
		if (
			row_key.is_empty()
			or not index_by_key.has(row_key)
			or not raw_patch_set is Dictionary
			or not raw_patch_unset is Array
		):
			return false
		var row_index := int(index_by_key[row_key])
		var row: Dictionary = (rows[row_index] as Dictionary).duplicate(true)
		for raw_key: Variant in (raw_patch_set as Dictionary).keys():
			var key := String(raw_key)
			if key in key_fields:
				return false
			row[key] = (raw_patch_set as Dictionary)[raw_key]
		for raw_key: Variant in raw_patch_unset as Array:
			if not raw_key is String:
				return false
			var key := String(raw_key)
			if key in key_fields:
				return false
			row.erase(key)
		rows[row_index] = row
	snapshot[field] = rows
	return true


func _snapshot_row_key(row: Dictionary, key_fields: Array[String]) -> String:
	var parts: Array[String] = []
	for field: String in key_fields:
		if not row.has(field):
			return ""
		parts.append(str(row[field]))
	return ":".join(parts)


func _reject_stream(reason: String) -> void:
	var was_usable := _usable
	_usable = false
	_hello_valid = false
	_stream_snapshot.clear()
	_stream_serial = 0
	_fail_pending(_network_error("Dữ liệu trận realtime bị lệch, đang đồng bộ lại."))
	if _peer != null and _peer.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_peer.close(1002, reason)
	if was_usable:
		state_changed.emit(false)


func _request(message: Dictionary) -> Dictionary:
	if not is_usable():
		return _network_error("Kết nối trận realtime chưa sẵn sàng.")
	var request_id := _next_request_id
	_next_request_id += 1
	if _next_request_id >= 9007199254740991:
		_next_request_id = 1
	message["request_id"] = request_id
	_pending[request_id] = null
	var send_error := _peer.send_text(JSON.stringify(message))
	if send_error != OK:
		_pending.erase(request_id)
		return _network_error("Không gửi được lệnh trận realtime.")
	var deadline_ms := Time.get_ticks_msec() + int(REQUEST_TIMEOUT_SECONDS * 1000.0)
	while _pending.has(request_id) and _pending[request_id] == null:
		if Time.get_ticks_msec() >= deadline_ms:
			_pending.erase(request_id)
			return {
				"ok": false,
				"status": 0,
				"error": {
					"code": "NETWORK_TIMEOUT",
					"message": "Lệnh trận realtime quá thời gian chờ.",
				},
			}
		await get_tree().process_frame
	if not _pending.has(request_id):
		return _network_error("Kết nối trận realtime đã bị ngắt.")
	var result: Dictionary = _pending[request_id]
	_pending.erase(request_id)
	return result


func _fail_pending(result: Dictionary) -> void:
	for request_id: Variant in _pending.keys():
		_pending[request_id] = result.duplicate(true)


func _network_error(message: String) -> Dictionary:
	return {
		"ok": false,
		"status": 0,
		"error": {"code": "NETWORK_UNAVAILABLE", "message": message},
	}
