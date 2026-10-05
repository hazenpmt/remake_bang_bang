extends Control

signal tab_changed(tab_key: StringName)
signal room_selected(room_id: StringName)
signal room_join_requested(room_id: StringName)
signal game_start_requested(room: Dictionary)

enum RoomTab {
	EVENT,
	SOLO,
	RANK,
	GUILD,
	TEST,
}

enum PlayerTab {
	GUILD,
	FRIENDS,
	ROOM,
}

const TAB_TEXTURES := [
	{
		"normal": preload("res://assets/ui/pvp_room/tabs/event_normal.png"),
		"selected": preload("res://assets/ui/pvp_room/tabs/event_selected.png"),
	},
	{
		"normal": preload("res://assets/ui/pvp_room/tabs/sotai_normal.png"),
		"selected": preload("res://assets/ui/pvp_room/tabs/sotai_selected.png"),
	},
	{
		"normal": preload("res://assets/ui/pvp_room/tabs/rank_normal.png"),
		"selected": preload("res://assets/ui/pvp_room/tabs/rank_selected.png"),
	},
	{
		"normal": preload("res://assets/ui/pvp_room/tabs/guild_normal.png"),
		"selected": preload("res://assets/ui/pvp_room/tabs/guild_selected.png"),
	},
	{
		"normal": preload("res://assets/ui/pvp_room/tabs/test_normal.png"),
		"selected": preload("res://assets/ui/pvp_room/tabs/test_selected.png"),
	},
]

const ROOM_ROW_NORMAL := preload("res://assets/ui/pvp_room/room_row.png")
const ROOM_ROW_OCCUPIED := preload("res://assets/ui/pvp_room/room_header.png")
const ROOM_ROW_SELECTED := preload("res://assets/ui/pvp_room/room_row_selected.png")
const ROOM_STATUS_WAITING := preload("res://assets/ui/pvp_room/status_wait.png")
const ROOM_STATUS_RUNNING := preload("res://assets/ui/pvp_room/status_running.png")
const ROOM_ACTION_JOIN := preload("res://assets/ui/pvp_room/join.png")
const ROOM_ACTION_WATCH := preload("res://assets/ui/pvp_room/watch.png")
const ROOM_BROWSER_FRAME := preload("res://assets/ui/pvp_room/frame.png")
const READY_ROOM_FRAME := preload("res://assets/ui/pvp_room/frame.png")
const CHAT_INPUT_HEAD := preload("res://assets/ui/chat/input_head.png")
const PLAYER_ITEM_TEXTURE := preload("res://assets/ui/pvp_room/player_item.png")
const PLAYER_TAB_NORMAL := preload(
	"res://assets/ui/pvp_room/player_tab_normal.png"
)
const PLAYER_TAB_SELECTED := preload(
	"res://assets/ui/pvp_room/player_tab_selected.png"
)
const PLAYER_AVATAR_MALE := preload("res://assets/ui/profile/avatar_male.png")
const PLAYER_AVATAR_FEMALE := preload("res://assets/ui/profile/avatar_female.png")
const PLAYER_ITEM_HEIGHT := 65.0
const VISIBLE_PLAYER_ITEMS := 7
const READY_ROOM_POLL_SECONDS := 1.0
const SOCIAL_REFRESH_SECONDS := 5.0
const TEST_ROOMS: Array[Dictionary] = [
	{
		"room_code": "1001",
		"tab_key": "test",
		"room_name": "PvP Bot Test - sandbox",
		"mode_key": "free",
		"map_key": "random",
		"map_name": "Bản đồ ngẫu nhiên",
		"map_thumbnail_asset_path": (
			"res://assets/ui/pvp_ready_room/maps/random.jpg"
		),
		"max_players": 5,
		"player_count": 0,
		"status": "waiting",
		"is_test": true,
	},
	{
		"room_code": "268435491",
		"tab_key": "test",
		"room_name": "PvP #20",
		"mode_key": "free",
		"map_key": "bo_sua_chay_nhanh",
		"max_players": 2,
		"player_count": 2,
		"status": "running",
		"is_test": true,
	},
]

@onready var _tab_buttons: Array[TextureButton] = [
	$Window/Tabs/Event,
	$Window/Tabs/Solo,
	$Window/Tabs/Rank,
	$Window/Tabs/Guild,
	$Window/Tabs/Test,
]
@onready var _room_rows: Array[TextureRect] = [
	$Window/RoomList/Rows/Row1,
	$Window/RoomList/Rows/Row2,
	$Window/RoomList/Rows/Row3,
	$Window/RoomList/Rows/Row4,
	$Window/RoomList/Rows/Row5,
	$Window/RoomList/Rows/Row6,
	$Window/RoomList/Rows/Row7,
	$Window/RoomList/Rows/Row8,
]
@onready var _room_hit_targets: Array[Control] = [
	$Window/RoomList/Rows/HitTargets/Room1,
	$Window/RoomList/Rows/HitTargets/Room2,
	$Window/RoomList/Rows/HitTargets/Room3,
	$Window/RoomList/Rows/HitTargets/Room4,
	$Window/RoomList/Rows/HitTargets/Room5,
	$Window/RoomList/Rows/HitTargets/Room6,
	$Window/RoomList/Rows/HitTargets/Room7,
	$Window/RoomList/Rows/HitTargets/Room8,
]

const TAB_KEYS: Array[StringName] = [
	&"event",
	&"solo",
	&"rank",
	&"guild",
	&"test",
]

@export_enum("EVENT", "SO TÀI", "X.HẠNG", "GIẢI GUILD", "TEST")
var initial_tab: int = RoomTab.SOLO

var _selected_tab: RoomTab = RoomTab.SOLO
var _selected_room_index := 0
var _room_ids: Array[StringName] = [&"", &"", &"", &"", &"", &"", &"", &""]
var _room_models: Array[Dictionary] = []
var _room_contents: Array[Control] = []
var _room_request_in_flight := false
var _in_ready_room := false
var _ready_room_poll_elapsed := 0.0
var _ready_room_poll_in_flight := false
var _current_ready_room: Dictionary = {}
var _local_test_search_generation := 0
var _local_test_match_started := false
var _completed_match_id_to_ignore := ""
var _shared_chat: Control
var _shared_bottom_bar: Control
var _shared_right_menu: Control
var _shared_chat_parent: Node
var _shared_bottom_bar_parent: Node
var _shared_right_menu_parent: Node
@onready var _match_flow: Control = $MatchFlow
var _shared_chat_index := -1
var _shared_bottom_bar_index := -1
var _shared_right_menu_index := -1
var _shared_chat_layout: Dictionary
var _shared_chat_history_layout: Dictionary
var _shared_chat_input_layout: Dictionary
var _shared_bottom_bar_layout: Dictionary
var _shared_right_menu_layout: Dictionary
var _shared_chat_warning_visible := true
var _shared_chat_input_visible := true
var _shared_attached := false
var _standalone_chat_active := false
var _room_chat_signals_bound := false
var _room_chat_expanded := false
var _room_chat_hovered := false
var _room_chat_placeholder := ""
var _room_chat_collapsed_head: AtlasTexture
var _blocked_bottom_buttons: Dictionary = {}
var _shared_modals: Array[Control] = []
var _shared_modal_parents: Array[Node] = []
var _shared_modal_indices: Array[int] = []
var _shared_modal_layouts: Array[Dictionary] = []
var _shared_modal_visibility: Array[bool] = []
var _modal_attached := false
var _map_modal_blocked_controls: Dictionary = {}
var _player_items: Array[TextureRect] = []
var _player_scroll_offset := 0
var _player_scroll_dragging := false
var _player_scroll_grab_offset := 0.0
var _selected_player_tab: PlayerTab = PlayerTab.GUILD
var _player_models: Array[Dictionary] = []
var _player_request_in_flight := false
var _social_refresh_elapsed := 0.0


func _ready() -> void:
	$Window/BtnClose.pressed.connect(close)
	$Window/Tabs/Event.pressed.connect(_open_event_tab)
	$Window/Tabs/Solo.pressed.connect(_open_solo_tab)
	$Window/Tabs/Rank.pressed.connect(_open_rank_tab)
	$Window/Tabs/Guild.pressed.connect(_open_guild_tab)
	$Window/Tabs/Test.pressed.connect(_open_test_tab)
	for room_index in _room_hit_targets.size():
		_room_hit_targets[room_index].gui_input.connect(
			_on_room_row_gui_input.bind(room_index)
		)
	_setup_room_contents()
	($Window/QuickJoin as BaseButton).pressed.connect(_on_quick_join_pressed)
	$Window/ReadyRoom.map_catalog_requested.connect(
		_on_ready_room_map_catalog_requested
	)
	$Window/ReadyRoom.map_change_requested.connect(
		_on_ready_room_map_change_requested
	)
	$Window/ReadyRoom.start_game_requested.connect(
		_on_ready_room_start_game_requested
	)
	$Window/ReadyRoom.cancel_matchmaking_requested.connect(
		_on_ready_room_cancel_matchmaking_requested
	)
	$Window/ReadyRoom.map_selector_modal_changed.connect(
		_set_map_selector_modal_blocked
	)
	_match_flow.connect("battle_ready", _on_match_flow_battle_ready)
	_match_flow.connect(
		"confirmation_expired",
		_on_match_flow_confirmation_expired
	)
	_set_map_selector_modal_blocked(false)
	for child in $Window/PlayerList/Items.get_children():
		if child is TextureRect:
			_player_items.append(child as TextureRect)
	($Window/PlayerList/GuildTab as TextureButton).pressed.connect(
		_select_player_tab.bind(PlayerTab.GUILD)
	)
	($Window/PlayerList/FriendTab as TextureButton).pressed.connect(
		_select_player_tab.bind(PlayerTab.FRIENDS)
	)
	($Window/PlayerList/RoomTab as TextureButton).pressed.connect(
		_select_player_tab.bind(PlayerTab.ROOM)
	)
	($Window/PlayerList/Up as TextureButton).pressed.connect(
		_scroll_players.bind(-1)
	)
	($Window/PlayerList/Down as TextureButton).pressed.connect(
		_scroll_players.bind(1)
	)
	($Window/PlayerList/Items as Control).gui_input.connect(
		_on_player_items_gui_input
	)
	($Window/PlayerList/ScrollTrack as Control).gui_input.connect(
		_on_player_scroll_track_gui_input
	)
	($Window/PlayerList/ScrollTrack/Thumb as Control).gui_input.connect(
		_on_player_scroll_thumb_gui_input
	)
	_set_player_scroll_offset(0)
	_apply_player_tab_selection()
	_hide_unused_player_items()
	_apply_room_selection()
	_open_initial_tab()
	call_deferred("_refresh_rooms")
	call_deferred("_refresh_social_players")
	$Window/Chat.visible = false
	$Window/Chat/Warning.visible = false
	var preview_history := $Window/Chat/History as Control
	preview_history.offset_top = 0.0
	preview_history.offset_bottom = 163.0
	var preview_input := $Window/Chat/Input as Control
	preview_input.offset_top = 162.0
	preview_input.offset_bottom = 205.0
	var previous_shared_chat := _shared_chat
	_shared_chat = $Window/Chat
	_set_room_chat_expanded(false)
	_shared_chat = previous_shared_chat
	for child in $Window/BottomDock.get_children():
		child.visible = false
	call_deferred("_show_standalone_preview_if_needed")


func _show_standalone_preview_if_needed() -> void:
	if _shared_chat != null or _shared_bottom_bar != null or _shared_right_menu != null:
		return
	$Window/Chat.visible = true
	for child in $Window/BottomDock.get_children():
		child.visible = child.name != &"Channel" and child.name != &"InputHint"
	_shared_chat = $Window/Chat
	_shared_bottom_bar = $Window/BottomDock
	_standalone_chat_active = true
	_bind_room_chat_signals(_shared_chat)
	_match_flow.call("bind_shared_chat", _shared_chat)
	_set_room_chat_expanded(false)


func _input(event: InputEvent) -> void:
	_handle_room_chat_global_click(event)
	if not _player_scroll_dragging:
		return
	if event is InputEventMouseMotion:
		var track := $Window/PlayerList/ScrollTrack as Control
		_set_player_scroll_from_thumb_position(
			track.get_local_mouse_position().y - _player_scroll_grab_offset
		)
		get_viewport().set_input_as_handled()
	elif (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and not event.pressed
	):
		_player_scroll_dragging = false
		get_viewport().set_input_as_handled()


func _set_map_selector_modal_blocked(blocked: bool) -> void:
	# The map selector is a modal sibling of the social/profile host. Disable
	# every underlying hit target explicitly as a second guard; this prevents a
	# click from reaching a profile/player button even if a child changes its
	# z-order while the selector is being opened or closed.
	var controls: Array[Control] = [
		$Window/PlayerList,
		$Window/RoomList,
		$Window/Tabs,
		$Window/QuickJoin,
		$Window/Chat,
		$Window/BottomDock,
		$ModalHost,
	]
	if blocked:
		for control in controls:
			if control == null or _map_modal_blocked_controls.has(control):
				continue
			_map_modal_blocked_controls[control] = control.mouse_filter
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return
	for control_value: Variant in _map_modal_blocked_controls.keys():
		var control := control_value as Control
		if is_instance_valid(control):
			control.mouse_filter = int(_map_modal_blocked_controls[control])
	_map_modal_blocked_controls.clear()


func _handle_room_chat_global_click(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if (
		mouse_event == null
		or not mouse_event.pressed
		or mouse_event.button_index != MOUSE_BUTTON_LEFT
		or not _room_chat_expanded
		or not _room_chat_is_active()
	):
		return
	var input_control := _shared_chat.get_node("Input") as Control
	if input_control.get_global_rect().has_point(mouse_event.position):
		return
	var message := _shared_chat.get_node("Input/Message") as LineEdit
	message.release_focus()
	_room_chat_hovered = false
	call_deferred("_collapse_room_chat_if_idle")


func _select_player_tab(tab: PlayerTab) -> void:
	if _selected_player_tab == tab and not _player_models.is_empty():
		return
	_selected_player_tab = tab
	_social_refresh_elapsed = 0.0
	_apply_player_tab_selection()
	_set_player_models([])
	call_deferred("_refresh_social_players")


func _apply_player_tab_selection() -> void:
	var buttons: Array[TextureButton] = [
		$Window/PlayerList/GuildTab,
		$Window/PlayerList/FriendTab,
		$Window/PlayerList/RoomTab,
	]
	for index in buttons.size():
		buttons[index].texture_normal = (
			PLAYER_TAB_SELECTED
			if index == _selected_player_tab
			else PLAYER_TAB_NORMAL
		)


func _player_tab_key() -> String:
	match _selected_player_tab:
		PlayerTab.FRIENDS:
			return "friends"
		PlayerTab.ROOM:
			return "room"
		_:
			return "guild"


func _refresh_social_players() -> void:
	if not visible or _player_request_in_flight:
		return
	_player_request_in_flight = true
	var requested_tab := _player_tab_key()
	var players: Array = []
	if GameSession.token.is_empty():
		players = _offline_social_players(requested_tab)
	else:
		var result: Dictionary = await GameSession.fetch_social_players(
			requested_tab
		)
		if result.get("ok", false):
			var value: Variant = result.get("players", [])
			players = value if value is Array else []
	_player_request_in_flight = false
	if not visible:
		return
	if requested_tab != _player_tab_key():
		call_deferred("_refresh_social_players")
		return
	_set_player_models(players)


func _offline_social_players(tab_key: String) -> Array:
	if tab_key == "friends":
		return []
	var data := GameSession.profile.duplicate(true)
	data.merge(GameSession.lobby_data, true)
	var account_id := str(GameSession.account.get("id", "0"))
	var tank_key := _optional_text(data.get("tank_key"), "gangtiexia03")
	var tank_name := _optional_text(data.get("tank_name"), "Iron Man")
	var player := {
		"account_id": account_id,
		"display_name": _optional_text(data.get("display_name"), "Beenn"),
		"gender": _optional_text(data.get("gender"), "male"),
		"level": int(data.get("level", 15)),
		"avatar_key": _optional_text(data.get("avatar_key"), ""),
		"guild_name": _optional_text(data.get("guild_name"), "Chưa có Guild"),
		"online": true,
		"is_self": true,
		"tank_key": tank_key,
		"tank_name": tank_name,
		"tank_level": int(data.get("tank_level", 1)),
	}
	return [player]


func _set_player_models(players: Array) -> void:
	_player_models.clear()
	for player_value: Variant in players:
		if player_value is Dictionary:
			_player_models.append((player_value as Dictionary).duplicate(true))
	if _selected_player_tab == PlayerTab.FRIENDS and _player_models.is_empty():
		_player_models.append({"add_friend": true})
	_render_player_models()
	_set_player_scroll_offset(0)


func _ensure_player_item_count(count: int) -> void:
	if _player_items.is_empty():
		return
	while _player_items.size() < count:
		var item := TextureRect.new()
		item.name = "Item%d" % (_player_items.size() + 1)
		item.texture = PLAYER_ITEM_TEXTURE
		item.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		item.stretch_mode = TextureRect.STRETCH_SCALE
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.size = Vector2(154.0, PLAYER_ITEM_HEIGHT)
		$Window/PlayerList/Items.add_child(item)
		_player_items.append(item)


func _hide_unused_player_items() -> void:
	for item in _player_items:
		item.visible = false


func _render_player_models() -> void:
	_ensure_player_item_count(_player_models.size())
	for item_index in _player_items.size():
		var item := _player_items[item_index]
		for child in item.get_children():
			child.free()
		var occupied := item_index < _player_models.size()
		item.visible = occupied
		item.position = Vector2(0.0, item_index * PLAYER_ITEM_HEIGHT)
		if occupied:
			_configure_player_item(item, _player_models[item_index])
	_update_player_scrollbar()


func _configure_player_item(item: TextureRect, player: Dictionary) -> void:
	if player.get("add_friend", false):
		var plus := _add_player_label(
			item,
			"+",
			Vector2(5.0, 3.0),
			Vector2(42.0, 48.0),
			30,
			Color(0.0, 0.35, 0.48, 1.0)
		)
		plus.name = "Plus"
		plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var add_button := _add_player_button(
			item,
			"THÊM BẠN",
			Vector2(48.0, 18.0),
			Vector2(98.0, 25.0)
		)
		add_button.name = "AddFriend"
		add_button.pressed.connect(_show_add_friend_browser)
		return

	var online := bool(player.get("online", false))
	var is_self := bool(player.get("is_self", false))
	var avatar := TextureRect.new()
	avatar.name = "Avatar"
	avatar.position = Vector2(4.0, 5.0)
	avatar.size = Vector2(42.0, 42.0)
	avatar.texture = (
		PLAYER_AVATAR_FEMALE
		if _optional_text(player.get("gender"), "male") == "female"
		else PLAYER_AVATAR_MALE
	)
	avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item.add_child(avatar)

	var display_name := _optional_text(player.get("display_name"), "Người chơi")
	var name_label := _add_player_label(
		item,
		display_name,
		Vector2(49.0, 2.0),
		Vector2(102.0, 18.0),
		12,
		Color(1.0, 0.92, 0.16, 1.0) if online else Color(0.72, 0.78, 0.8, 1.0)
	)
	name_label.name = "PlayerName"
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var guild_name := _optional_text(player.get("guild_name"), "")
	var detail := (
		guild_name
		if not guild_name.is_empty()
		else "Đang online"
		if online
		else "Đang offline"
	)
	var detail_label := _add_player_label(
		item,
		detail,
		Vector2(49.0, 20.0),
		Vector2(102.0, 16.0),
		10,
		Color(0.92, 1.0, 1.0, 1.0) if online else Color(0.58, 0.65, 0.68, 1.0)
	)
	detail_label.name = "Detail"
	detail_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var level_label := _add_player_label(
		item,
		"LV.%d" % int(player.get("level", 1)),
		Vector2(4.0, 46.0),
		Vector2(41.0, 16.0),
		11,
		Color(0.35, 1.0, 1.0, 1.0)
	)
	level_label.name = "Level"
	var view_button := _add_player_button(
		item,
		"XEM",
		Vector2(48.0, 39.0),
		Vector2(44.0, 21.0)
	)
	view_button.name = "View"
	view_button.pressed.connect(_open_social_player_profile.bind(player))
	if _in_ready_room and online and not is_self:
		var invite_button := _add_player_button(
			item,
			"MỜI",
			Vector2(96.0, 39.0),
			Vector2(52.0, 21.0)
		)
		invite_button.name = "Invite"
		invite_button.pressed.connect(
			_invite_social_player.bind(player, invite_button)
		)


func _add_player_label(
	parent: Control,
	text_value: String,
	position_value: Vector2,
	size_value: Vector2,
	font_size: int,
	color: Color
) -> Label:
	var label := Label.new()
	label.position = position_value
	label.size = size_value
	label.text = text_value
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.18, 0.28, 1.0))
	label.add_theme_constant_override("outline_size", 1)
	parent.add_child(label)
	return label


func _add_player_button(
	parent: Control,
	text_value: String,
	position_value: Vector2,
	size_value: Vector2
) -> Button:
	var button := Button.new()
	button.position = position_value
	button.size = size_value
	button.text = text_value
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", Color(0.0, 0.32, 0.48, 1.0))
	button.add_theme_color_override("font_hover_color", Color(0.0, 0.2, 0.34, 1.0))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.72, 0.96, 1.0, 1.0)
	normal.border_color = Color(0.0, 0.5, 0.64, 1.0)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(8)
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.9, 1.0, 1.0, 1.0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", hover)
	parent.add_child(button)
	return button


func _show_add_friend_browser() -> void:
	call_deferred("_select_player_tab", PlayerTab.ROOM)


func _open_social_player_profile(player: Dictionary) -> void:
	if _shared_modals.size() < 2:
		return
	var profile_modal := _shared_modals[1]
	var owned_tanks: Array = []
	var tank_key := _optional_text(player.get("tank_key"), "")
	if not tank_key.is_empty():
		owned_tanks.append({
			"tank_key": tank_key,
			"tank_name": _optional_text(player.get("tank_name"), "Tank"),
			"tank_level": int(player.get("tank_level", 1)),
			"is_primary": true,
		})
	var profile_data := {
		"display_name": _optional_text(player.get("display_name"), "Người chơi"),
		"gender": _optional_text(player.get("gender"), "male"),
		"level": int(player.get("level", 1)),
		"avatar_key": _optional_text(player.get("avatar_key"), ""),
		"guild_name": _optional_text(player.get("guild_name"), ""),
		"owned_tanks": owned_tanks,
	}
	profile_modal.call(
		"show_profile",
		profile_data,
		{"id": _optional_text(player.get("account_id"), "")}
	)


func _invite_social_player(player: Dictionary, button: Button) -> void:
	if not _in_ready_room or button.disabled:
		return
	button.disabled = true
	var result: Dictionary = await GameSession.invite_social_player_to_room(
		_optional_text(player.get("account_id"), "")
	)
	button.text = "ĐÃ MỜI" if result.get("ok", false) else "LỖI"
	if not result.get("ok", false):
		button.disabled = false


func _scroll_players(delta: int) -> void:
	_set_player_scroll_offset(_player_scroll_offset + delta)


func _set_player_scroll_offset(value: int) -> void:
	_player_scroll_offset = clampi(value, 0, _max_player_scroll_offset())
	for item_index in _player_items.size():
		_player_items[item_index].position.y = (
			item_index * PLAYER_ITEM_HEIGHT
			- _player_scroll_offset * PLAYER_ITEM_HEIGHT
		)
	_update_player_scrollbar()


func _max_player_scroll_offset() -> int:
	return maxi(0, _player_models.size() - VISIBLE_PLAYER_ITEMS)


func _update_player_scrollbar() -> void:
	var track := $Window/PlayerList/ScrollTrack as Control
	var thumb := $Window/PlayerList/ScrollTrack/Thumb as Control
	var max_offset := _max_player_scroll_offset()
	var travel := maxf(0.0, track.size.y - thumb.size.y)
	var ratio := 0.0
	if max_offset > 0:
		ratio = float(_player_scroll_offset) / float(max_offset)
	thumb.position = Vector2(-0.5, roundf(travel * ratio))
	($Window/PlayerList/Up as BaseButton).disabled = _player_scroll_offset <= 0
	($Window/PlayerList/Down as BaseButton).disabled = (
		_player_scroll_offset >= max_offset
	)


func _set_player_scroll_from_thumb_position(position_y: float) -> void:
	var track := $Window/PlayerList/ScrollTrack as Control
	var thumb := $Window/PlayerList/ScrollTrack/Thumb as Control
	var travel := maxf(0.0, track.size.y - thumb.size.y)
	var max_offset := _max_player_scroll_offset()
	if travel <= 0.0 or max_offset <= 0:
		_set_player_scroll_offset(0)
		return
	var ratio := clampf(position_y / travel, 0.0, 1.0)
	_set_player_scroll_offset(roundi(ratio * max_offset))


func _on_player_items_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_scroll_players(-1)
		($Window/PlayerList/Items as Control).accept_event()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_scroll_players(1)
		($Window/PlayerList/Items as Control).accept_event()


func _on_player_scroll_track_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_players(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_players(1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var thumb := $Window/PlayerList/ScrollTrack/Thumb as Control
			_set_player_scroll_from_thumb_position(
				event.position.y - thumb.size.y * 0.5
			)
		else:
			return
		($Window/PlayerList/ScrollTrack as Control).accept_event()


func _on_player_scroll_thumb_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return
	_player_scroll_dragging = event.pressed
	if event.pressed:
		var track := $Window/PlayerList/ScrollTrack as Control
		var thumb := $Window/PlayerList/ScrollTrack/Thumb as Control
		_player_scroll_grab_offset = (
			track.get_local_mouse_position().y - thumb.position.y
		)
	($Window/PlayerList/ScrollTrack/Thumb as Control).accept_event()


func bind_shared_controls(
	chat: Control,
	bottom_bar: Control,
	right_menu: Control
) -> void:
	if _standalone_chat_active:
		_standalone_chat_active = false
		_room_chat_signals_bound = false
	_shared_chat = chat
	_shared_bottom_bar = bottom_bar
	_shared_right_menu = right_menu
	_shared_chat_parent = chat.get_parent()
	_shared_bottom_bar_parent = bottom_bar.get_parent()
	_shared_right_menu_parent = right_menu.get_parent()
	_shared_chat_index = chat.get_index()
	_shared_bottom_bar_index = bottom_bar.get_index()
	_shared_right_menu_index = right_menu.get_index()
	_shared_chat_layout = _capture_layout(chat)
	_shared_chat_history_layout = _capture_layout(chat.get_node("History"))
	_shared_chat_input_layout = _capture_layout(chat.get_node("Input"))
	_shared_bottom_bar_layout = _capture_layout(bottom_bar)
	_shared_right_menu_layout = _capture_layout(right_menu)
	_shared_chat_warning_visible = chat.get_node("Warning").visible
	_shared_chat_input_visible = chat.get_node("Input").visible
	_bind_room_chat_signals(chat)
	_match_flow.call("bind_shared_chat", chat)


func _bind_room_chat_signals(chat: Control) -> void:
	if _room_chat_signals_bound:
		return
	var input_control := chat.get_node("Input") as Control
	var message := chat.get_node("Input/Message") as LineEdit
	input_control.gui_input.connect(_on_room_chat_input_gui_input)
	message.gui_input.connect(_on_room_chat_message_gui_input)
	# The shared LobbyChat is reparented into this view at runtime.  Keep a
	# submit path on the host as well, so Enter cannot be swallowed by the
	# room-view input pipeline after reparenting.
	message.text_submitted.connect(_on_room_chat_message_submitted)
	message.focus_entered.connect(_on_room_chat_focus_entered)
	message.focus_exited.connect(_on_room_chat_focus_exited)
	for tab_name in [
		"TabTotal",
		"TabRoom",
		"TabTeam",
		"TabGuild",
		"TabPrivate",
	]:
		(chat.get_node("History/%s" % tab_name) as BaseButton).pressed.connect(
			_on_room_chat_channel_changed,
			CONNECT_DEFERRED
		)
	_room_chat_signals_bound = true


func _on_room_chat_message_submitted(_text: String) -> void:
	if _shared_chat == null or not _room_chat_is_active():
		return
	if _shared_chat.has_method("submit_message"):
		_shared_chat.call_deferred("submit_message")
	elif _shared_chat.has_method("_send_current_message"):
		_shared_chat.call_deferred("_send_current_message")


func bind_modal_controls(
	tank_panel: Control,
	profile_modal: Control,
	purchase_modal: Control,
	military_rank_panel: Control,
	friend_panel: Control,
	inventory_panel: Control
) -> void:
	_shared_modals = [
		tank_panel,
		profile_modal,
		purchase_modal,
		military_rank_panel,
		friend_panel,
		inventory_panel,
	]
	_shared_modal_parents.clear()
	_shared_modal_indices.clear()
	_shared_modal_layouts.clear()
	_shared_modal_visibility.clear()
	for modal in _shared_modals:
		_shared_modal_parents.append(modal.get_parent())
		_shared_modal_indices.append(modal.get_index())
		_shared_modal_layouts.append(_capture_layout(modal))
		_shared_modal_visibility.append(modal.visible)


func _capture_layout(control: Control) -> Dictionary:
	return {
		"anchor_left": control.anchor_left,
		"anchor_top": control.anchor_top,
		"anchor_right": control.anchor_right,
		"anchor_bottom": control.anchor_bottom,
		"offset_left": control.offset_left,
		"offset_top": control.offset_top,
		"offset_right": control.offset_right,
		"offset_bottom": control.offset_bottom,
		"size_flags_horizontal": control.size_flags_horizontal,
		"size_flags_vertical": control.size_flags_vertical,
		"z_index": control.z_index,
	}


func _restore_layout(control: Control, layout: Dictionary) -> void:
	control.anchor_left = layout["anchor_left"]
	control.anchor_top = layout["anchor_top"]
	control.anchor_right = layout["anchor_right"]
	control.anchor_bottom = layout["anchor_bottom"]
	control.offset_left = layout["offset_left"]
	control.offset_top = layout["offset_top"]
	control.offset_right = layout["offset_right"]
	control.offset_bottom = layout["offset_bottom"]
	control.size_flags_horizontal = layout["size_flags_horizontal"]
	control.size_flags_vertical = layout["size_flags_vertical"]
	control.z_index = layout["z_index"]


func open() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _shared_right_menu != null:
		var mail := _shared_right_menu.get_node_or_null("Btn_Mail") as Control
		if mail != null:
			mail.visible = false
	_attach_shared_controls()
	_attach_modal_controls()
	$Window/BtnClose.grab_focus()
	_social_refresh_elapsed = 0.0
	call_deferred("_refresh_social_players")
	if not _in_ready_room:
		call_deferred("_refresh_rooms")


func close() -> void:
	if _match_flow.call("is_open"):
		return
	if _in_ready_room:
		call_deferred("_leave_ready_room")
		return
	_close_visible_modals()
	_detach_modal_controls()
	_detach_shared_controls()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _attach_modal_controls() -> void:
	if _modal_attached or _shared_modals.is_empty():
		return
	var host := $ModalHost
	for modal in _shared_modals:
		modal.reparent(host, false)
		modal.anchor_left = 0.0
		modal.anchor_top = 0.0
		modal.anchor_right = 1.0
		modal.anchor_bottom = 1.0
		modal.offset_left = 0.0
		modal.offset_top = 0.0
		modal.offset_right = 0.0
		modal.offset_bottom = 0.0
		modal.z_index = 10
	_modal_attached = true


func _close_visible_modals() -> void:
	for modal in _shared_modals:
		if not modal.visible:
			continue
		if modal.has_method("close"):
			modal.call("close")
		elif modal.has_method("hide_view"):
			modal.call("hide_view")
		else:
			modal.visible = false


func _detach_modal_controls() -> void:
	if not _modal_attached:
		return
	for index in _shared_modals.size():
		var modal := _shared_modals[index]
		modal.reparent(_shared_modal_parents[index], false)
		_shared_modal_parents[index].move_child(
			modal,
			clampi(
				_shared_modal_indices[index],
				0,
				_shared_modal_parents[index].get_child_count() - 1
			)
		)
		_restore_layout(modal, _shared_modal_layouts[index])
		modal.visible = _shared_modal_visibility[index]
	_modal_attached = false


func _attach_shared_controls() -> void:
	if _shared_attached:
		return
	if _shared_chat == null or _shared_bottom_bar == null or _shared_right_menu == null:
		return

	_shared_chat.reparent($Window/SharedChatHost, false)
	_shared_chat.anchor_left = 0.0
	_shared_chat.anchor_top = 0.0
	_shared_chat.anchor_right = 0.0
	_shared_chat.anchor_bottom = 0.0
	_shared_chat.offset_left = 0.0
	_shared_chat.offset_top = 0.0
	_shared_chat.offset_right = 464.0
	_shared_chat.offset_bottom = 221.0
	var history := _shared_chat.get_node("History") as Control
	history.offset_top = 0.0
	history.offset_bottom = 163.0
	var input_control := _shared_chat.get_node("Input") as Control
	input_control.offset_top = 162.0
	input_control.offset_bottom = 205.0
	_shared_chat.get_node("Warning").visible = false
	_shared_chat.get_node("Input").visible = true
	_shared_chat.visible = true
	_shared_chat.z_index = 20
	_set_room_chat_expanded(false)

	_shared_bottom_bar.reparent($Window/SharedBottomHost, false)
	_set_top_left_rect(_shared_bottom_bar, Vector2(194.0, 0.0), Vector2(760.0, 54.0))
	_shared_bottom_bar.visible = true
	_shared_bottom_bar.z_index = 2

	_shared_right_menu.reparent($Window/SharedBottomHost, false)
	_set_top_left_rect(_shared_right_menu, Vector2(832.0, 0.0), Vector2(150.0, 54.0))
	_shared_right_menu.visible = true
	_shared_right_menu.z_index = 3
	_shared_attached = true


func _set_top_left_rect(control: Control, position: Vector2, size: Vector2) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = position.x
	control.offset_top = position.y
	control.offset_right = position.x + size.x
	control.offset_bottom = position.y + size.y


func _detach_shared_controls() -> void:
	if not _shared_attached:
		if _standalone_chat_active:
			_set_room_chat_expanded(false)
		return
	_shared_attached = false
	_set_bottom_buttons_blocked(false)
	_set_room_chat_expanded(true)
	_room_chat_hovered = false
	_shared_chat.reparent(_shared_chat_parent, false)
	_shared_chat_parent.move_child(
		_shared_chat,
		clampi(_shared_chat_index, 0, _shared_chat_parent.get_child_count() - 1)
	)
	_restore_layout(_shared_chat, _shared_chat_layout)
	_restore_layout(_shared_chat.get_node("History"), _shared_chat_history_layout)
	_restore_layout(_shared_chat.get_node("Input"), _shared_chat_input_layout)
	_shared_chat.get_node("Warning").visible = _shared_chat_warning_visible
	_shared_chat.get_node("Input").visible = _shared_chat_input_visible
	_shared_chat.z_index = 20

	_shared_bottom_bar.reparent(_shared_bottom_bar_parent, false)
	_shared_bottom_bar_parent.move_child(
		_shared_bottom_bar,
		clampi(_shared_bottom_bar_index, 0, _shared_bottom_bar_parent.get_child_count() - 1)
	)
	_restore_layout(_shared_bottom_bar, _shared_bottom_bar_layout)

	_shared_right_menu.reparent(_shared_right_menu_parent, false)
	_shared_right_menu_parent.move_child(
		_shared_right_menu,
		clampi(_shared_right_menu_index, 0, _shared_right_menu_parent.get_child_count() - 1)
	)
	_restore_layout(_shared_right_menu, _shared_right_menu_layout)


func _process(delta: float) -> void:
	$Window/ReadyRoom.set_matchmaking_timer_paused(
		_in_ready_room and bool(_match_flow.call("is_open"))
	)
	if _in_ready_room and _has_live_room_session():
		_ready_room_poll_elapsed += delta
		if (
			_ready_room_poll_elapsed >= READY_ROOM_POLL_SECONDS
			and not _ready_room_poll_in_flight
		):
			_ready_room_poll_elapsed = 0.0
			_ready_room_poll_in_flight = true
			_poll_ready_room()
	if visible:
		_social_refresh_elapsed += delta
		if (
			_social_refresh_elapsed >= SOCIAL_REFRESH_SECONDS
			and not _player_request_in_flight
		):
			_social_refresh_elapsed = 0.0
			_refresh_social_players()
	if not _room_chat_is_active():
		return
	_update_room_chat_hover(get_viewport().get_mouse_position())


func _update_room_chat_hover(mouse_position: Vector2) -> void:
	var input_control := _shared_chat.get_node("Input") as Control
	var mouse_inside := input_control.get_global_rect().has_point(mouse_position)
	if mouse_inside:
		_room_chat_hovered = true
		if not _room_chat_expanded:
			_set_room_chat_expanded(true)
		return
	_room_chat_hovered = false
	_collapse_room_chat_if_idle()


func _on_room_chat_focus_entered() -> void:
	if _room_chat_is_active():
		_set_room_chat_expanded(true)


func _on_room_chat_focus_exited() -> void:
	_collapse_room_chat_if_idle()


func _on_room_chat_input_gui_input(event: InputEvent) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if mouse_event.position.x < 110.0:
		return
	_focus_room_chat_message()


func _on_room_chat_message_gui_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if (
		key_event != null
		and key_event.pressed
		and not key_event.echo
		and key_event.keycode in [KEY_ENTER, KEY_KP_ENTER]
	):
		var message := _shared_chat.get_node("Input/Message") as LineEdit
		message.accept_event()
		get_viewport().set_input_as_handled()
		_on_room_chat_message_submitted(message.text)
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	_focus_room_chat_message()


func _focus_room_chat_message() -> void:
	if not _room_chat_is_active():
		return
	_set_room_chat_expanded(true)
	var message := _shared_chat.get_node("Input/Message") as LineEdit
	if message.editable:
		message.grab_focus()


func _on_room_chat_channel_changed() -> void:
	if not _room_chat_is_active() or _room_chat_expanded:
		return
	var message := _shared_chat.get_node("Input/Message") as LineEdit
	if message.placeholder_text != "dưới lv 15...":
		_room_chat_placeholder = message.placeholder_text
	message.placeholder_text = "dưới lv 15..."


func _collapse_room_chat_if_idle() -> void:
	if not _room_chat_is_active() or _room_chat_hovered:
		return
	var message := _shared_chat.get_node("Input/Message") as LineEdit
	if message.has_focus():
		return
	_set_room_chat_expanded(false)


func _set_room_chat_expanded(expanded: bool) -> void:
	if _shared_chat == null:
		return
	var input_control := _shared_chat.get_node("Input") as Control
	var message := _shared_chat.get_node("Input/Message") as LineEdit
	var head := _shared_chat.get_node("Input/Head") as TextureRect
	var middle := _shared_chat.get_node("Input/Middle") as Control
	var tail := _shared_chat.get_node("Input/Tail") as Control
	var message_left := _shared_chat.get_node("Input/MessageInputLeft") as Control
	var message_middle := _shared_chat.get_node("Input/MessageInputMiddle") as Control
	var message_right := _shared_chat.get_node("Input/MessageInputRight") as Control
	var friend := _shared_chat.get_node("Input/Btn_Friend") as Control
	var send := _shared_chat.get_node("Input/Btn_Send") as Control
	var quick_chat := _shared_chat.get_node("Input/Btn_QuickChat") as Control

	_room_chat_expanded = expanded
	input_control.offset_right = 464.0 if expanded else 194.0
	input_control.z_index = 30 if expanded else 0
	_set_bottom_buttons_blocked(expanded and _room_chat_is_active())
	if expanded:
		head.texture = CHAT_INPUT_HEAD
		head.offset_left = 0.0
		head.offset_top = 0.0
		head.offset_right = 110.0
		head.offset_bottom = 43.0
		middle.visible = true
		middle.offset_left = 110.0
		middle.offset_right = 440.0
		tail.offset_left = 440.0
		tail.offset_right = 464.0
		message_left.offset_left = 115.0
		message_left.offset_right = 134.0
		message_middle.offset_left = 134.0
		message_middle.offset_right = 355.0
		message_right.offset_left = 355.0
		message_right.offset_right = 374.0
		message.offset_left = 124.0
		message.offset_right = 346.0
		message.mouse_filter = Control.MOUSE_FILTER_STOP
		if message.placeholder_text != "dưới lv 15...":
			_room_chat_placeholder = message.placeholder_text
		message.placeholder_text = _room_chat_placeholder
		tail.visible = true
		message_left.visible = true
		message_middle.visible = true
		message_right.visible = true
		friend.visible = true
		send.visible = true
		quick_chat.visible = true
	else:
		if message.placeholder_text != "dưới lv 15...":
			_room_chat_placeholder = message.placeholder_text
		head.texture = _get_room_chat_collapsed_head()
		head.offset_left = 6.0
		head.offset_top = 6.0
		head.offset_right = 104.0
		head.offset_bottom = 37.0
		middle.offset_left = 110.0
		middle.offset_right = 194.0
		middle.visible = false
		tail.visible = false
		message_left.visible = true
		message_left.offset_left = 110.0
		message_left.offset_right = 129.0
		message_middle.visible = true
		message_middle.offset_left = 129.0
		message_middle.offset_right = 175.0
		message_right.visible = true
		message_right.offset_left = 175.0
		message_right.offset_right = 194.0
		message.offset_left = 119.0
		message.offset_right = 185.0
		message.placeholder_text = "dưới lv 15..."
		message.mouse_filter = Control.MOUSE_FILTER_STOP
		friend.visible = false
		send.visible = false
		quick_chat.visible = false


func _room_chat_is_active() -> bool:
	return (
		_shared_chat != null
		and (_shared_attached or _standalone_chat_active)
		and (
			_standalone_chat_active
			or _shared_chat.get_parent() == $Window/SharedChatHost
		)
	)


func _get_room_chat_collapsed_head() -> AtlasTexture:
	if _room_chat_collapsed_head == null:
		_room_chat_collapsed_head = AtlasTexture.new()
		_room_chat_collapsed_head.atlas = CHAT_INPUT_HEAD
		_room_chat_collapsed_head.region = Rect2(6.0, 6.0, 98.0, 31.0)
	return _room_chat_collapsed_head


func _set_bottom_buttons_blocked(blocked: bool) -> void:
	if not blocked:
		for button_value: Variant in _blocked_bottom_buttons:
			var button := button_value as BaseButton
			if is_instance_valid(button):
				var original_state := _blocked_bottom_buttons[button] as Dictionary
				button.disabled = bool(original_state["disabled"])
				button.mouse_filter = int(original_state["mouse_filter"])
		_blocked_bottom_buttons.clear()
		return
	if _shared_chat == null:
		return
	var chat_input := _shared_chat.get_node("Input") as Control
	var chat_rect := chat_input.get_global_rect()
	var bottom_buttons: Array[BaseButton] = []
	_collect_base_buttons(_shared_bottom_bar, bottom_buttons)
	_collect_base_buttons(_shared_right_menu, bottom_buttons)
	for button in bottom_buttons:
		if not button.visible or not button.get_global_rect().intersects(chat_rect):
			continue
		if not _blocked_bottom_buttons.has(button):
			_blocked_bottom_buttons[button] = {
				"disabled": button.disabled,
				"mouse_filter": button.mouse_filter,
			}
		button.disabled = true
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _collect_base_buttons(node: Node, output: Array[BaseButton]) -> void:
	if node == null:
		return
	for child in node.get_children():
		if child is BaseButton:
			output.append(child as BaseButton)
		_collect_base_buttons(child, output)


func get_active_tab_key() -> StringName:
	return TAB_KEYS[_selected_tab]


func get_selected_room_id() -> StringName:
	if _selected_room_index < 0 or _selected_room_index >= _room_ids.size():
		return &""
	return _room_ids[_selected_room_index]


func _setup_room_contents() -> void:
	var rows := $Window/RoomList/Rows as Control
	_room_contents = [
		rows.get_node("Room1") as Control,
		rows.get_node("Room2") as Control,
	]
	var source := _room_contents[0]
	for room_index in range(2, _room_rows.size()):
		var content := source.duplicate() as Control
		content.name = "Room%d" % (room_index + 1)
		rows.add_child(content)
		_room_contents.append(content)
	for room_index in _room_contents.size():
		var content := _room_contents[room_index]
		content.offset_left = 0.0
		content.offset_top = room_index * 38.0
		content.offset_right = 781.0
		content.offset_bottom = room_index * 38.0 + 38.0
		var action := _room_action_button(content)
		if action != null:
			action.pressed.connect(_join_room_at_index.bind(room_index))


func _room_action_button(content: Control) -> TextureButton:
	for child in content.get_children():
		if child is TextureButton:
			return child as TextureButton
	return null


func _on_room_row_gui_input(event: InputEvent, room_index: int) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event == null:
		return
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return
	if room_index < 0 or room_index >= _room_ids.size():
		return
	if _room_ids[room_index] == &"":
		return

	_selected_room_index = room_index
	_apply_room_selection()
	room_selected.emit(_room_ids[room_index])
	if mouse_event.double_click:
		room_join_requested.emit(_room_ids[room_index])
		_join_room_at_index(room_index)


func _join_room_at_index(room_index: int) -> void:
	if _room_request_in_flight:
		return
	if room_index < 0 or room_index >= _room_models.size():
		return
	var room := _room_models[room_index]
	if not _room_can_enter(room):
		return
	_join_room(room)


func _room_can_enter(room: Dictionary) -> bool:
	var room_status := _optional_text(room.get("status"), "")
	return (
		int(room.get("max_players", 0)) == 5
		and int(room.get("player_count", 0)) < 5
		and room_status in ["waiting", "matching"]
	)


func _join_room(room: Dictionary) -> void:
	_room_request_in_flight = true
	if not _has_live_room_session():
		_room_request_in_flight = false
		_enter_ready_room(_make_local_ready_room(room))
		return
	var result: Dictionary = await GameSession.join_game_room(
		_optional_text(room.get("room_code"), "")
	)
	_room_request_in_flight = false
	if not result.get("ok", false):
		_report_room_error(result)
		return
	var joined_value: Variant = result.get("room", {})
	if joined_value is Dictionary:
		_enter_ready_room(joined_value)


func _on_quick_join_pressed() -> void:
	if _room_request_in_flight:
		return
	if not _has_live_room_session():
		for room in _room_models:
			if _room_can_enter(room):
				_enter_ready_room(_make_local_ready_room(room))
				return
		return
	_room_request_in_flight = true
	var result: Dictionary = await GameSession.quick_join_game_room(
		String(get_active_tab_key())
	)
	_room_request_in_flight = false
	if not result.get("ok", false):
		_report_room_error(result)
		return
	var joined_value: Variant = result.get("room", {})
	if joined_value is Dictionary:
		_enter_ready_room(joined_value)


func _has_live_room_session() -> bool:
	if get_tree().current_scene == self:
		return false
	return not GameSession.token.is_empty() and GameSession.admission_active


func _make_local_ready_room(room: Dictionary) -> Dictionary:
	var preview_room := room.duplicate(true)
	var profile: Dictionary = GameSession.profile.duplicate(true)
	profile.merge(GameSession.lobby_data, true)
	if profile.is_empty():
		profile = {
			"display_name": "Beenn",
			"gender": "male",
			"level": 15,
			"experience": 1548,
			"experience_max": 13000,
		}
	var tank: Dictionary = GameSession.lobby_data
	var account_id := _optional_text(GameSession.account.get("id"), "")
	profile["account_id"] = account_id if not account_id.is_empty() else "local-player"
	profile["tank_key"] = _optional_text(tank.get("tank_key"), "gangtiexia03")
	profile["tank_name"] = _optional_text(tank.get("tank_name"), "Iron Man")
	profile["tank_level"] = int(tank.get("tank_level", 1))
	profile["equipped_skin_key"] = _optional_text(
		tank.get("equipped_skin_key"), "gangtiexia03_default"
	)
	profile["slot"] = 1
	profile["is_captain"] = true
	preview_room["player_count"] = 1
	preview_room["members"] = [profile]
	return preview_room


func _enter_ready_room(room: Dictionary) -> void:
	_local_test_search_generation += 1
	_local_test_match_started = false
	_in_ready_room = true
	_ready_room_poll_elapsed = 0.0
	$Window/Frame.texture = READY_ROOM_FRAME
	$Window/ContentBackground.visible = false
	$Window/ContentSwirl.visible = false
	$Window/Title.visible = false
	$Window/Tabs.visible = false
	$Window/RoomList.visible = false
	$Window/Pager.visible = false
	$Window/QuickJoin.visible = false
	$Window/CreateTeam.visible = false
	$Window/FindTeam.visible = false
	$Window/PlayerList.visible = true
	$Window/ReadyRoom.visible = true
	_render_player_models()
	_update_ready_room(room)


func _update_ready_room(room: Dictionary) -> void:
	_current_ready_room = room.duplicate(true)
	$Window/ReadyRoom.set_room_data(room)
	_match_flow.call("apply_match", room.get("match", {}))


func return_to_previous_room_after_battle() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if not _in_ready_room or _current_ready_room.is_empty():
		return
	_local_test_search_generation += 1
	_local_test_match_started = false
	_ready_room_poll_elapsed = 0.0
	var previous_match_value: Variant = _current_ready_room.get("match", {})
	if previous_match_value is Dictionary:
		_completed_match_id_to_ignore = String(
			(previous_match_value as Dictionary).get("id", "")
		)
	if _completed_match_id_to_ignore.is_empty() and not _has_live_room_session():
		_completed_match_id_to_ignore = "local-test"
	var room := _current_ready_room.duplicate(true)
	room["status"] = "waiting"
	room.erase("match")
	room.erase("matchmaking")
	_update_ready_room(room)


func leave_room_after_battle() -> void:
	# Keep _selected_tab untouched so the room browser opens on the exact tab
	# that launched this match (TEST/RANK/SOLO/GUILD/EVENT).
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	await _leave_ready_room()


func refresh_current_player_tank(lobby_data: Dictionary) -> void:
	if not _in_ready_room or _current_ready_room.is_empty():
		return
	var members_value: Variant = _current_ready_room.get("members", [])
	if members_value is not Array:
		return
	var members: Array = members_value.duplicate(true)
	var account_id := _optional_text(GameSession.account.get("id"), "")
	var member_index := -1
	for index in members.size():
		if members[index] is not Dictionary:
			continue
		var member: Dictionary = members[index]
		if (
			not account_id.is_empty()
			and _optional_text(member.get("account_id"), "") == account_id
		):
			member_index = index
			break
	if member_index < 0 and GameSession.token.is_empty() and not members.is_empty():
		member_index = 0
	if member_index < 0:
		return

	var member: Dictionary = members[member_index]
	member["tank_key"] = String(
		lobby_data.get("tank_key", member.get("tank_key", "gangtiexia03"))
	)
	member["tank_name"] = String(
		lobby_data.get("tank_name", member.get("tank_name", "Iron Man"))
	)
	member["tank_level"] = int(
		lobby_data.get("tank_level", member.get("tank_level", 1))
	)
	member["equipped_skin_key"] = String(
		lobby_data.get(
			"equipped_skin_key",
			member.get("equipped_skin_key", "gangtiexia03_default")
		)
	)
	members[member_index] = member
	var updated_room := _current_ready_room.duplicate(true)
	updated_room["members"] = members
	_update_ready_room(updated_room)

	if _has_live_room_session() and not _ready_room_poll_in_flight:
		_ready_room_poll_elapsed = 0.0
		_ready_room_poll_in_flight = true
		_poll_ready_room()


func _on_ready_room_map_catalog_requested() -> void:
	if _room_request_in_flight:
		return
	# Map selection is a standalone modal. Close any previously opened social
	# profile/modal first so it cannot remain an interactive layer underneath.
	_close_visible_modals()
	if not _has_live_room_session():
		$Window/ReadyRoom.show_map_selector([
			{
				"map_key": "random",
				"display_name": "Bản đồ ngẫu nhiên",
				"thumbnail_asset_path": (
					"res://assets/ui/pvp_ready_room/maps/random.jpg"
				),
			},
		])
		return
	_room_request_in_flight = true
	var result: Dictionary = await GameSession.fetch_game_maps()
	_room_request_in_flight = false
	if not result.get("ok", false):
		_report_room_error(result)
		return
	var maps_value: Variant = result.get("maps", [])
	$Window/ReadyRoom.show_map_selector(
		maps_value if maps_value is Array else []
	)


func _on_ready_room_map_change_requested(map_key: String) -> void:
	if _room_request_in_flight:
		return
	if not _has_live_room_session():
		_current_ready_room["map_key"] = map_key
		_current_ready_room["map_name"] = "Bản đồ ngẫu nhiên"
		_current_ready_room["map_thumbnail_asset_path"] = (
			"res://assets/ui/pvp_ready_room/maps/random.jpg"
		)
		_update_ready_room(_current_ready_room)
		_start_local_test_match_after_search()
		return
	_room_request_in_flight = true
	var result: Dictionary = await GameSession.select_game_room_map(map_key)
	_room_request_in_flight = false
	if not result.get("ok", false):
		_report_room_error(result)
		return
	var room_value: Variant = result.get("room", {})
	if room_value is Dictionary:
		_update_ready_room(room_value)


func _on_ready_room_start_game_requested() -> void:
	if _room_request_in_flight:
		return
	if not _has_live_room_session():
		_current_ready_room["status"] = "matching"
		_current_ready_room["matchmaking"] = {
			"state": "searching",
			"elapsed_seconds": 0,
			"estimated_seconds": 30,
			"ally_count": int(_current_ready_room.get("player_count", 1)),
			"ally_needed": maxi(
				0,
				int(_current_ready_room.get("max_players", 5))
				- int(_current_ready_room.get("player_count", 1))
			),
			"enemy_count": 5,
			"enemy_needed": 0,
			"enemy_bot_count": 5,
		}
		_update_ready_room(_current_ready_room)
		_start_local_test_match_after_search()
		return
	_room_request_in_flight = true
	var result: Dictionary = await GameSession.start_game_room()
	_room_request_in_flight = false
	if not result.get("ok", false):
		_report_room_error(result)
		return
	var room_value: Variant = result.get("room", {})
	if room_value is Dictionary:
		_update_ready_room(room_value)


func _on_ready_room_cancel_matchmaking_requested() -> void:
	if _room_request_in_flight:
		return
	if not _has_live_room_session():
		_local_test_search_generation += 1
		_local_test_match_started = false
		_current_ready_room["status"] = "waiting"
		_current_ready_room.erase("matchmaking")
		_update_ready_room(_current_ready_room)
		return
	_room_request_in_flight = true
	var result: Dictionary = await GameSession.cancel_game_room_matchmaking()
	_room_request_in_flight = false
	if not result.get("ok", false):
		_report_room_error(result)
		return
	var room_value: Variant = result.get("room", {})
	if room_value is Dictionary:
		_update_ready_room(room_value)


func _leave_ready_room() -> void:
	_local_test_search_generation += 1
	_local_test_match_started = false
	_room_request_in_flight = true
	if _has_live_room_session():
		var result: Dictionary = await GameSession.leave_game_room()
		if not result.get("ok", false):
			_room_request_in_flight = false
			_report_room_error(result)
			return
	_room_request_in_flight = false
	_in_ready_room = false
	_show_room_browser_layout()
	await _refresh_rooms()


func _poll_ready_room() -> void:
	var result: Dictionary = await GameSession.fetch_current_game_room()
	_ready_room_poll_in_flight = false
	if not _in_ready_room or not result.get("ok", false):
		return
	var room_value: Variant = result.get("room", {})
	if not (room_value is Dictionary) or room_value.is_empty():
		_local_test_search_generation += 1
		_local_test_match_started = false
		_in_ready_room = false
		_show_room_browser_layout()
		await _refresh_rooms()
		return
	var returned_room: Dictionary = room_value
	var returned_match_value: Variant = returned_room.get("match", {})
	var returned_match_id := ""
	if returned_match_value is Dictionary:
		returned_match_id = String((returned_match_value as Dictionary).get("id", ""))
	if (
		not _completed_match_id_to_ignore.is_empty()
		and returned_match_id == _completed_match_id_to_ignore
	):
		returned_room = returned_room.duplicate(true)
		returned_room["status"] = "waiting"
		returned_room.erase("match")
		returned_room.erase("matchmaking")
	elif (
		not returned_match_id.is_empty()
		and returned_match_id != _completed_match_id_to_ignore
	):
		_completed_match_id_to_ignore = ""
	var previous_status := String(_current_ready_room.get("status", ""))
	_update_ready_room(returned_room)
	if (
		previous_status == "matching"
		and String(room_value.get("status", "")) == "running"
		and (
			room_value.get("match", {}) is not Dictionary
			or room_value.get("match", {}).is_empty()
		)
	):
		game_start_requested.emit(room_value)


func _start_local_test_match_after_search() -> void:
	if _local_test_match_started:
		return
	_local_test_search_generation += 1
	var search_generation := _local_test_search_generation
	await get_tree().create_timer(2.0).timeout
	if (
		search_generation != _local_test_search_generation
		or _local_test_match_started
		or not _in_ready_room
		or String(_current_ready_room.get("status", "")) != "matching"
		or _has_live_room_session()
	):
		return
	_local_test_match_started = true
	_match_flow.call("start_local_test", _current_ready_room)


func _on_match_flow_battle_ready(match_data: Dictionary) -> void:
	_local_test_match_started = true
	var payload := _current_ready_room.duplicate(true)
	payload["match"] = match_data
	game_start_requested.emit(payload)


func _on_match_flow_confirmation_expired() -> void:
	$Window/ReadyRoom.set_matchmaking_timer_paused(false)
	if (
		_in_ready_room
		and not _has_live_room_session()
		and String(_current_ready_room.get("status", "")) == "matching"
	):
		_local_test_match_started = false
		_start_local_test_match_after_search()


func _refresh_rooms() -> void:
	if _room_request_in_flight or _in_ready_room:
		return
	_room_request_in_flight = true
	var tab_key := String(get_active_tab_key())
	if not _has_live_room_session():
		_room_request_in_flight = false
		_set_room_models(TEST_ROOMS if tab_key == "test" else [])
		return
	var result: Dictionary = await GameSession.fetch_game_rooms(tab_key)
	_room_request_in_flight = false
	if tab_key != String(get_active_tab_key()):
		call_deferred("_refresh_rooms")
		return
	if not result.get("ok", false):
		_set_room_models(TEST_ROOMS if tab_key == "test" else [])
		_report_room_error(result)
		return
	var rooms_value: Variant = result.get("rooms", [])
	var rooms: Array = rooms_value if rooms_value is Array else []
	_set_room_models(rooms)


func _set_room_models(rooms: Array) -> void:
	_room_models.clear()
	for room_value in rooms:
		if room_value is Dictionary and _room_models.size() < _room_rows.size():
			_room_models.append(room_value)
	for room_index in _room_ids.size():
		_room_ids[room_index] = &""
		if room_index < _room_models.size():
			_room_ids[room_index] = StringName(
				String(_room_models[room_index].get("room_code", ""))
			)
	if _selected_room_index >= _room_models.size():
		_selected_room_index = 0
	_render_room_models()
	_apply_room_selection()


func _render_room_models() -> void:
	for room_index in _room_contents.size():
		var content := _room_contents[room_index]
		var occupied := room_index < _room_models.size()
		content.visible = occupied
		if not occupied:
			continue
		var room := _room_models[room_index]
		(content.get_node("Id") as Label).text = _optional_text(
			room.get("room_code"), ""
		)
		(content.get_node("Name") as Label).text = _optional_text(
			room.get("room_name"), ""
		)
		(content.get_node("Mode") as Label).text = _room_mode_text(
			_optional_text(room.get("mode_key"), "free")
		)
		var map_fallback := _room_map_text(
			_optional_text(room.get("map_key"), "random")
		)
		(content.get_node("Map") as Label).text = _optional_text(
			room.get("map_name"), map_fallback
		)
		(content.get_node("Count") as Label).text = "%d/%d" % [
			int(room.get("player_count", 0)),
			int(room.get("max_players", 5)),
		]
		var room_status := _optional_text(room.get("status"), "waiting")
		var waiting := room_status in ["waiting", "matching"]
		(content.get_node("Status") as TextureRect).texture = (
			ROOM_STATUS_WAITING if waiting else ROOM_STATUS_RUNNING
		)
		var action := _room_action_button(content)
		if action != null:
			action.texture_normal = ROOM_ACTION_JOIN if waiting else ROOM_ACTION_WATCH
			action.disabled = not _room_can_enter(room)
			action.visible = true


func _room_mode_text(mode_key: String) -> String:
	return "Tự do" if mode_key == "free" else mode_key


func _room_map_text(map_key: String) -> String:
	match map_key:
		"random":
			return "Bản đồ ngẫu nhiên"
		"bo_sua_chay_nhanh":
			return "Bò sữa chạy nhanh"
		_:
			return map_key.replace("_", " ")


func _optional_text(value: Variant, fallback: String = "") -> String:
	if value == null:
		return fallback
	var result := str(value).strip_edges()
	return fallback if result.is_empty() else result


func _report_room_error(result: Dictionary) -> void:
	var error_value: Variant = result.get("error", {})
	var error: Dictionary = error_value if error_value is Dictionary else {}
	push_warning(String(error.get("message", "Không thể xử lý phòng PvP.")))


func _apply_room_selection() -> void:
	for room_index in _room_rows.size():
		var row := _room_rows[room_index]
		var state := row.get_node("State") as TextureRect
		var selected := room_index == _selected_room_index
		var occupied := _room_ids[room_index] != &""
		row.texture = ROOM_ROW_NORMAL
		row.offset_left = 0.0
		row.offset_top = room_index * 38.0
		row.offset_right = 781.0
		row.offset_bottom = room_index * 38.0 + 38.0
		state.visible = occupied
		state.texture = (
			ROOM_ROW_SELECTED
			if selected
			else ROOM_ROW_OCCUPIED
			if occupied
			else null
		)


func _open_initial_tab() -> void:
	match initial_tab:
		RoomTab.EVENT:
			_open_event_tab()
		RoomTab.RANK:
			_open_rank_tab()
		RoomTab.GUILD:
			_open_guild_tab()
		RoomTab.TEST:
			_open_test_tab()
		_:
			_open_solo_tab()


func _open_event_tab() -> void:
	_apply_tab_selection(RoomTab.EVENT)
	_show_event_content()
	tab_changed.emit(&"event")


func _open_solo_tab() -> void:
	_apply_tab_selection(RoomTab.SOLO)
	_show_solo_content()
	tab_changed.emit(&"solo")


func _open_rank_tab() -> void:
	_apply_tab_selection(RoomTab.RANK)
	_show_rank_content()
	tab_changed.emit(&"rank")


func _open_guild_tab() -> void:
	_apply_tab_selection(RoomTab.GUILD)
	_show_guild_content()
	tab_changed.emit(&"guild")


func _open_test_tab() -> void:
	_apply_tab_selection(RoomTab.TEST)
	_show_test_content()
	tab_changed.emit(&"test")


func _apply_tab_selection(tab: RoomTab) -> void:
	_selected_tab = tab
	for tab_index in _tab_buttons.size():
		var selected := tab_index == _selected_tab
		_tab_buttons[tab_index].texture_normal = (
			TAB_TEXTURES[tab_index]["selected"]
			if selected
			else TAB_TEXTURES[tab_index]["normal"]
		)
	if is_node_ready() and not _in_ready_room:
		call_deferred("_refresh_rooms")


func _show_event_content() -> void:
	_show_room_browser_layout()


func _show_solo_content() -> void:
	_show_room_browser_layout()


func _show_rank_content() -> void:
	_show_room_browser_layout()


func _show_guild_content() -> void:
	_show_room_browser_layout()


func _show_test_content() -> void:
	# TEST intentionally starts with the same presentation as SOLO, while keeping
	# a separate entry point and tab key for its future gameplay/network logic.
	_show_room_browser_layout()


func _show_room_browser_layout() -> void:
	$Window/Frame.texture = ROOM_BROWSER_FRAME
	$Window/ContentBackground.visible = true
	$Window/ContentSwirl.visible = true
	$Window/Title.visible = true
	$Window/Tabs.visible = true
	$Window/ReadyRoom.visible = false
	$Window/RoomList.visible = true
	$Window/PlayerList.visible = true
	_render_player_models()
	$Window/Pager.visible = true
	$Window/QuickJoin.visible = true
	$Window/CreateTeam.visible = true
	$Window/FindTeam.visible = true
