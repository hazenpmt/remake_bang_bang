extends Control

const WORLD_CHANNEL := &"world"
const WORLD_PLACEHOLDER := "Nhập nội dung chat bằng trả lời nhanh"
const VISIBLE_MESSAGE_COUNT := 5
const SCROLL_THUMB_HEIGHT := 18.0
const MAX_LOCAL_MESSAGES := 100

@onready var _history_text: RichTextLabel = $History/Messages
@onready var _history: Control = $History
@onready var _message_input: LineEdit = $Input/Message
@onready var _channel_label: Label = $Input/ChannelLabel
@onready var _poll_timer: Timer = $PollTimer
@onready var _scroll_track: TextureRect = $History/ScrollTrack
@onready var _scroll_thumb: TextureRect = $History/ScrollTrack/Thumb

var _tab_buttons: Array[TextureButton] = []
var _messages: Array[Dictionary] = []
var _active_channel: StringName = WORLD_CHANNEL
var _last_message_id := 0
var _chat_server_started_at := ""
var _scroll_offset := 0
var _poll_in_flight := false
var _send_in_flight := false
var _scroll_thumb_dragging := false
var _scroll_thumb_grab_offset := 0.0


func _ready() -> void:
	_tab_buttons.assign([
		$History/TabTotal,
		$History/TabRoom,
		$History/TabTeam,
		$History/TabGuild,
		$History/TabPrivate,
	])
	for index in _tab_buttons.size():
		_tab_buttons[index].pressed.connect(_select_tab.bind(index))

	$History/Btn_Up.pressed.connect(_scroll_up)
	$History/Btn_Down.pressed.connect(_scroll_down)
	$History/Btn_Clear.pressed.connect(_clear_local_history)
	_history.gui_input.connect(_on_history_gui_input)
	_scroll_track.gui_input.connect(_on_scroll_track_gui_input)
	_scroll_thumb.gui_input.connect(_on_scroll_thumb_gui_input)
	_scroll_thumb.mouse_default_cursor_shape = Control.CURSOR_VSIZE
	$Input/Btn_Channel.pressed.connect(_select_tab.bind(0))
	$Input/Btn_Friend.pressed.connect(_select_tab.bind(4))
	$Input/Btn_Send.pressed.connect(_send_current_message)
	$Input/Btn_QuickChat.pressed.connect(_focus_message_input)
	_message_input.gui_input.connect(_on_message_gui_input)
	_message_input.text_submitted.connect(_on_message_submitted)
	_poll_timer.timeout.connect(_poll_world_messages)

	_select_tab(0)
	_poll_world_messages()


func _unhandled_key_input(event: InputEvent) -> void:
	# The shared room chat can be reparented/collapsed while the same key event
	# is travelling through the room view. Keep Enter as a guaranteed submit
	# path and consume it so the room view cannot treat it as a shortcut.
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	var is_enter := (
		key_event.keycode in [KEY_ENTER, KEY_KP_ENTER]
		or key_event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]
	)
	if (
		not key_event.pressed
		or key_event.echo
		or not is_enter
		or not _message_input.has_focus()
		or not _message_input.editable
	):
		return
	get_viewport().set_input_as_handled()
	_send_current_message()


func _input(event: InputEvent) -> void:
	# LineEdit consumes Enter before _unhandled_key_input. Catch it at the
	# LobbyChat node first so the shared PVP chat cannot swallow the submit.
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	var is_enter := (
		key_event.keycode in [KEY_ENTER, KEY_KP_ENTER]
		or key_event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]
	)
	if (
		not key_event.pressed
		or key_event.echo
		or not is_enter
		or not _message_input.has_focus()
		or not _message_input.editable
	):
		return
	get_viewport().set_input_as_handled()
	_send_current_message()


func _on_message_gui_input(event: InputEvent) -> void:
	# Handle Enter at the LineEdit itself.  This runs before the shared PVP
	# host/global input handlers and is reliable even when the LineEdit has
	# already consumed the native text_submitted signal.
	if not (event is InputEventKey):
		return
	var key_event := event as InputEventKey
	var is_enter := (
		key_event.keycode in [KEY_ENTER, KEY_KP_ENTER]
		or key_event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]
	)
	if (
		not key_event.pressed
		or key_event.echo
		or not is_enter
		or not _message_input.editable
	):
		return
	_message_input.accept_event()
	_send_current_message()


func set_full_input_layout() -> void:
	# Restore the original 464px LobbyChat input after a host (such as the
	# room browser) has collapsed the same shared control to its short form.
	var input_control := $Input as Control
	input_control.offset_right = 464.0
	input_control.z_index = 0
	$Input/Head.texture = load("res://assets/ui/chat/input_head.png") as Texture2D
	_set_chat_rect($Input/Head as Control, 0.0, 0.0, 110.0, 43.0)
	_set_chat_rect($Input/Middle as Control, 110.0, 0.0, 440.0, 43.0)
	_set_chat_rect($Input/Tail as Control, 440.0, 0.0, 464.0, 43.0)
	_set_chat_rect($Input/MessageInputLeft as Control, 115.0, 6.0, 134.0, 37.0)
	_set_chat_rect($Input/MessageInputMiddle as Control, 134.0, 6.0, 355.0, 37.0)
	_set_chat_rect($Input/MessageInputRight as Control, 355.0, 6.0, 374.0, 37.0)
	_set_chat_rect($Input/Message as Control, 124.0, 7.0, 346.0, 37.0)
	$Input/Middle.visible = true
	$Input/Tail.visible = true
	$Input/MessageInputLeft.visible = true
	$Input/MessageInputMiddle.visible = true
	$Input/MessageInputRight.visible = true
	$Input/Btn_Friend.visible = true
	$Input/Btn_Send.visible = true
	$Input/Btn_QuickChat.visible = true
	_message_input.mouse_filter = Control.MOUSE_FILTER_STOP
	if _active_channel == WORLD_CHANNEL:
		_message_input.editable = true
		_message_input.placeholder_text = WORLD_PLACEHOLDER


func _set_chat_rect(
	control: Control,
	left: float,
	top: float,
	right: float,
	bottom: float
) -> void:
	control.offset_left = left
	control.offset_top = top
	control.offset_right = right
	control.offset_bottom = bottom


func _select_tab(index: int) -> void:
	if index < 0 or index >= _tab_buttons.size():
		return
	for tab_index in _tab_buttons.size():
		_tab_buttons[tab_index].button_pressed = tab_index == index

	match index:
		0:
			_active_channel = WORLD_CHANNEL
			_channel_label.text = "Thế Giới"
			_message_input.editable = true
			_message_input.placeholder_text = WORLD_PLACEHOLDER
			_render_messages()
			_poll_world_messages()
		1:
			_show_unavailable_channel(&"room", "Room", "Kênh Room sẽ mở khi bạn tham gia phòng đấu.")
		2:
			_show_unavailable_channel(&"team", "Team", "Kênh Team sẽ mở khi hệ thống đội được hoàn thiện.")
		3:
			_show_unavailable_channel(&"guild", "Guild", "Kênh Guild sẽ mở khi hệ thống quân đoàn được hoàn thiện.")
		4:
			_show_unavailable_channel(
				&"private",
				"Chat riêng",
				"Chat riêng sẽ mở khi giao diện chọn người nhận được hoàn thiện."
			)


func _show_unavailable_channel(channel: StringName, label: String, notice: String) -> void:
	_active_channel = channel
	_channel_label.text = label
	_message_input.editable = false
	_message_input.placeholder_text = notice
	_history_text.text = "[color=#c7d1da]%s[/color]" % _escape_bbcode(notice)


func _poll_world_messages() -> void:
	if _active_channel != WORLD_CHANNEL or _poll_in_flight:
		return
	_poll_in_flight = true
	var result := await GameSession.fetch_world_chat(_last_message_id, 50)
	_poll_in_flight = false
	if not result.get("ok", false):
		_show_request_error(result)
		return
	var server_started_at := _optional_text(result.get("server_started_at"), "")
	if (
		not server_started_at.is_empty()
		and not _chat_server_started_at.is_empty()
		and server_started_at != _chat_server_started_at
	):
		# A restarted backend owns a new world-chat session. Drop only the
		# client-side view; the server keeps old rows for moderation/audit.
		_messages.clear()
		_last_message_id = 0
		_scroll_offset = 0
	_chat_server_started_at = server_started_at
	_message_input.placeholder_text = WORLD_PLACEHOLDER

	var received: Variant = result.get("messages", [])
	if received is Array:
		if received.is_empty() and _messages.is_empty():
			_render_messages()
		else:
			_append_messages(received)


func _append_messages(received: Array) -> void:
	var added := false
	for value: Variant in received:
		if not (value is Dictionary):
			continue
		var message: Dictionary = value
		var message_id := int(message.get("id", 0))
		if message_id <= _last_message_id:
			continue
		_last_message_id = message_id
		_messages.append(message)
		added = true

	if not added:
		return
	while _messages.size() > MAX_LOCAL_MESSAGES:
		_messages.pop_front()
	if _scroll_offset == 0:
		_render_messages()
	else:
		_scroll_offset = mini(
			_scroll_offset + received.size(),
			maxi(0, _messages.size() - VISIBLE_MESSAGE_COUNT)
		)
		_render_messages()


func _send_current_message() -> void:
	if _active_channel != WORLD_CHANNEL or _send_in_flight:
		return
	var message := _message_input.text.strip_edges()
	if message.is_empty():
		_message_input.grab_focus()
		return

	_send_in_flight = true
	_message_input.editable = false
	if not GameSession.admission_active:
		var admission_ready := await _ensure_chat_admission()
		if not admission_ready:
			_send_in_flight = false
			_message_input.editable = true
			_message_input.grab_focus()
			return
	var result := await GameSession.send_world_chat(message)
	if not result.get("ok", false):
		var error_value: Variant = result.get("error", {})
		var error: Dictionary = error_value if error_value is Dictionary else {}
		var error_code := _optional_text(error.get("code"), "")
		if error_code in ["ADMISSION_REQUIRED", "ADMISSION_EXPIRED"]:
			# A backend restart can expire only the admission lease. Rejoin the
			# online queue and retry once; the auth token is never replaced.
			if await _ensure_chat_admission():
				result = await GameSession.send_world_chat(message)
	_send_in_flight = false
	_message_input.editable = true
	if not result.get("ok", false):
		_show_request_error(result)
		_message_input.grab_focus()
		return

	_message_input.placeholder_text = WORLD_PLACEHOLDER
	_message_input.clear()
	var sent: Variant = result.get("message", {})
	if sent is Dictionary:
		_append_messages([sent])
	_scroll_to_end()
	_message_input.grab_focus()


func _ensure_chat_admission() -> bool:
	var admission := await GameSession.join_admission()
	if not admission.get("ok", false):
		_show_request_error(admission)
		return false
	var admission_value: Variant = admission.get("admission", {})
	var admission_data: Dictionary = (
		admission_value if admission_value is Dictionary else {}
	)
	var state := _optional_text(admission_data.get("state"), "")
	if state != "admitted":
		_show_request_error({
			"error": {
				"message": "Máy chủ đang đầy, vui lòng vào lại hàng chờ online."
			}
		})
		return false
	GameSession.start_presence_heartbeat(
		float(admission_data.get("heartbeat_interval_seconds", 20))
	)
	return true


func _on_message_submitted(_text: String) -> void:
	submit_message()


func submit_message() -> void:
	# Public host entry point used after LobbyChat is reparented into PVP.
	# Keep one guarded send path so the native LineEdit signal and the PVP
	# host cannot create duplicate requests.
	_send_current_message()


func _show_request_error(result: Dictionary) -> void:
	var error_value: Variant = result.get("error", {})
	var error: Dictionary = error_value if error_value is Dictionary else {}
	var message := _optional_text(
		error.get("message"), "Không thể sử dụng chat lúc này."
	)
	_message_input.placeholder_text = message
	if _active_channel == WORLD_CHANNEL and _messages.is_empty():
		_history_text.text = (
			"[color=#ffcc66][Thế Giới] %s[/color]" % _escape_bbcode(message)
		)


func _scroll_up() -> void:
	_scroll_offset = mini(
		_scroll_offset + 1,
		maxi(0, _messages.size() - VISIBLE_MESSAGE_COUNT)
	)
	_render_messages()


func _scroll_down() -> void:
	_scroll_offset = maxi(0, _scroll_offset - 1)
	_render_messages()


func _scroll_to_end() -> void:
	_scroll_offset = 0
	_render_messages()


func _on_history_gui_input(event: InputEvent) -> void:
	if _handle_scroll_wheel(event):
		_history.accept_event()


func _on_scroll_track_gui_input(event: InputEvent) -> void:
	if _handle_scroll_wheel(event):
		_scroll_track.accept_event()
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	_set_scroll_from_thumb_position(mouse_event.position.y - _scroll_thumb.size.y * 0.5)
	_scroll_track.accept_event()


func _handle_scroll_wheel(event: InputEvent) -> bool:
	if not (event is InputEventMouseButton):
		return false
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed:
		return false
	match mouse_event.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			_scroll_up()
			return true
		MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_down()
			return true
	return false


func _on_scroll_thumb_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return
		_scroll_thumb_dragging = mouse_event.pressed
		if mouse_event.pressed:
			_scroll_thumb_grab_offset = (
				_scroll_track.get_local_mouse_position().y - _scroll_thumb.position.y
			)
		_scroll_thumb.accept_event()
	elif event is InputEventMouseMotion and _scroll_thumb_dragging:
		_set_scroll_from_thumb_position(
			_scroll_track.get_local_mouse_position().y - _scroll_thumb_grab_offset
		)
		_scroll_thumb.accept_event()


func _set_scroll_from_thumb_position(position_y: float) -> void:
	var max_offset := maxi(0, _messages.size() - VISIBLE_MESSAGE_COUNT)
	var travel := maxf(0.0, _scroll_track.size.y - _scroll_thumb.size.y)
	if max_offset == 0 or travel <= 0.0:
		_scroll_to_end()
		return
	var ratio_from_top := clampf(position_y / travel, 0.0, 1.0)
	_scroll_offset = clampi(
		roundi((1.0 - ratio_from_top) * float(max_offset)),
		0,
		max_offset
	)
	_render_messages()


func _update_scrollbar() -> void:
	var track_height := _scroll_track.size.y
	if track_height <= 0.0:
		return
	var max_offset := maxi(0, _messages.size() - VISIBLE_MESSAGE_COUNT)
	var thumb_height := minf(SCROLL_THUMB_HEIGHT, track_height)
	_scroll_thumb.size = Vector2(19.0, thumb_height)
	var travel := maxf(0.0, track_height - thumb_height)
	var ratio_from_top := 1.0
	if max_offset > 0:
		ratio_from_top = 1.0 - float(_scroll_offset) / float(max_offset)
	_scroll_thumb.position = Vector2(0.0, roundf(travel * ratio_from_top))


func _clear_local_history() -> void:
	_messages.clear()
	_scroll_offset = 0
	_render_messages()


func _focus_message_input() -> void:
	if _message_input.editable:
		_message_input.grab_focus()


func _render_messages() -> void:
	if _active_channel != WORLD_CHANNEL:
		return
	if _messages.is_empty():
		_history_text.text = "[color=#aebbc5][Thế Giới] Chưa có tin nhắn.[/color]"
		_update_scrollbar()
		return

	var end_index := maxi(0, _messages.size() - _scroll_offset)
	var start_index := maxi(0, end_index - VISIBLE_MESSAGE_COUNT)
	var lines := PackedStringArray()
	var own_name := _optional_text(GameSession.profile.get("display_name"), "")
	if own_name.is_empty():
		own_name = _optional_text(GameSession.lobby_data.get("display_name"), "")

	for index in range(start_index, end_index):
		var message := _messages[index]
		var sender := _optional_text(message.get("sender_name"), "Người chơi")
		var body := _optional_text(message.get("body"), "")
		body = _truncate_chat_text(body, 30)
		sender = _truncate_chat_text(sender, 14)
		var sender_color := "#ffd84a" if sender == own_name else "#62ff75"
		lines.append(
			"[color=#e7e9eb][Thế Giới][/color][color=%s]%s[/color]: %s"
			% [sender_color, _escape_bbcode(sender), _escape_bbcode(body)]
		)
	_history_text.text = "\n".join(lines)
	_update_scrollbar()


func _truncate_chat_text(value: String, max_characters: int) -> String:
	var compact := value.replace("\r", " ").replace("\n", " ").strip_edges()
	if compact.length() <= max_characters:
		return compact
	return compact.left(maxi(1, max_characters - 1)).strip_edges() + "…"


func _escape_bbcode(value: String) -> String:
	var escaped := ""
	for character in value:
		match character:
			"[":
				escaped += "[lb]"
			"]":
				escaped += "[rb]"
			_:
				escaped += character
	return escaped


func _optional_text(value: Variant, fallback: String = "") -> String:
	if value == null:
		return fallback
	var result := str(value).strip_edges()
	return fallback if result.is_empty() else result
