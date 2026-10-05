extends Control

const AssetPathAliases := preload("res://scripts/data/asset_path_aliases.gd")

signal profile_requested(player: Dictionary)

enum Section {
	MENTOR,
	FRIENDS,
	BLOCKED,
	SEARCH,
}

const MALE_AVATAR := preload("res://assets/ui/profile/avatar_male.png")
const FEMALE_AVATAR := preload("res://assets/ui/profile/avatar_female.png")
const TREE_OPEN := preload("res://assets/ui/friend_original/tree_open.png")
const TREE_CLOSED := preload("res://assets/ui/friend_original/tree_closed.png")
const STATUS_MALE_ONLINE := preload(
	"res://assets/ui/friend_original/status_male_online.png"
)
const STATUS_FEMALE_ONLINE := preload(
	"res://assets/ui/friend_original/status_female_online.png"
)
const STATUS_OFFLINE := preload(
	"res://assets/ui/friend_original/status_offline.png"
)
const ROW_FILL := preload("res://assets/ui/friend_original/list_fill.png")
const ROW_BUTTON_BLUE := preload(
	"res://assets/ui/friend_original/row_button_blue.png"
)
const ROW_BUTTON_GREEN := preload(
	"res://assets/ui/tank/skin_use_button_bg.png"
)
const ROW_BUTTON_DISABLED := preload(
	"res://assets/ui/friend_original/row_button_disabled.png"
)
const LEVEL_FX_11_20 := \
	"res://assets/animations/profile_level_11_20_effect1_compact/timeline.json"
const LEVEL_FX_21_30 := \
	"res://assets/animations/profile_level_21_30_fx_compact/timeline.json"
const LEVEL_FX_31_35 := \
	"res://assets/animations/profile_level_31_35_fx_compact/timeline.json"
const LEVEL_FX_36_40 := \
	"res://assets/animations/profile_level_36_40_fx_compact/timeline.json"
const PanelTransitionHelper := preload("res://scripts/ui/panel_transition.gd")
const ProfileProgression := preload("res://scripts/data/profile_progression.gd")

@onready var _owner_avatar: TextureRect = $Window/OwnerCard/Avatar
@onready var _owner_level: TextureRect = $Window/OwnerCard/Level/Base
@onready var _owner_level_effect: SwfTimelinePlayer = \
	$Window/OwnerCard/Level/Effect
@onready var _owner_name: Label = $Window/OwnerCard/Name
@onready var _window: Control = $Window
@onready var _drag_handle: Control = $Window/DragHandle
@onready var _search: LineEdit = $Window/Search
@onready var _mentor_button: Button = $Window/MentorButton
@onready var _friends_button: Button = $Window/FriendsButton
@onready var _blocked_button: Button = $Window/BlockedButton
@onready var _section_selection: TextureRect = $Window/SectionSelection
@onready var _section_status: Label = $Window/SectionStatus
@onready var _friend_counts: HBoxContainer = $Window/FriendCounts
@onready var _friend_count_value: Label = \
	$Window/FriendCounts/FriendsValue
@onready var _invite_count_value: Label = \
	$Window/FriendCounts/InvitesValue
@onready var _scroll: ScrollContainer = $Window/Scroll
@onready var _rows: VBoxContainer = $Window/Scroll/Rows
@onready var _scroll_track: TextureRect = $Window/CustomScrollBar/Track
@onready var _scroll_thumb: TextureRect = $Window/CustomScrollBar/Thumb
@onready var _scroll_up_button: TextureButton = $Window/CustomScrollBar/Up
@onready var _scroll_down_button: TextureButton = \
	$Window/CustomScrollBar/Down
@onready var _player_menu: Control = $Window/PlayerMenu
@onready var _menu_player_name: Label = $Window/PlayerMenu/PlayerName
@onready var _menu_guild: Label = $Window/PlayerMenu/Guild
@onready var _menu_team: Label = $Window/PlayerMenu/Team
@onready var _menu_add_friend: Button = $Window/PlayerMenu/AddFriend
@onready var _menu_private_chat: Button = $Window/PlayerMenu/PrivateChat
@onready var _menu_copy_name: Button = $Window/PlayerMenu/CopyName
@onready var _menu_block: Button = $Window/PlayerMenu/Block
@onready var _menu_invite_guild: Button = $Window/PlayerMenu/InviteGuild
@onready var _menu_remove_friend: Button = $Window/PlayerMenu/RemoveFriend
@onready var _menu_observe: Button = $Window/PlayerMenu/Observe
@onready var _add_friend_dismiss: Button = $AddFriendDismissArea
@onready var _add_friend_modal: Control = $AddFriendModal
@onready var _add_friend_prompt: Label = $AddFriendModal/Prompt
@onready var _add_friend_input: LineEdit = $AddFriendModal/NameInput

var _section := Section.FRIENDS
var _request_serial := 0
var _active_player: Dictionary = {}
var _active_row_kind := ""
var _panel_transition: Tween
var _selected_row_background: ColorRect
var _scroll_thumb_dragging := false
var _scroll_thumb_grab_offset := 0.0
var _window_dragging := false
var _window_drag_offset := Vector2.ZERO

const SCROLL_STEP := 28
const SCROLL_TRACK_TOP := 19.0
const SCROLL_TRACK_HEIGHT := 280.0
const SCROLL_THUMB_MIN_HEIGHT := 38.0


func _ready() -> void:
	$DismissArea.pressed.connect(close)
	$Window/BtnClose.pressed.connect(close)
	_drag_handle.gui_input.connect(_on_window_drag_handle_gui_input)
	_mentor_button.pressed.connect(_select_section.bind(Section.MENTOR))
	_friends_button.pressed.connect(_select_section.bind(Section.FRIENDS))
	_blocked_button.pressed.connect(_select_section.bind(Section.BLOCKED))
	$Window/AddFriendButton.pressed.connect(_open_add_friend_modal)
	$Window/BlockedListButton.pressed.connect(
		_select_section.bind(Section.BLOCKED)
	)
	_search.text_submitted.connect(_search_player)
	_menu_add_friend.pressed.connect(_menu_add_friend_pressed)
	_menu_private_chat.pressed.connect(_menu_private_chat_pressed)
	_menu_copy_name.pressed.connect(_menu_copy_name_pressed)
	_menu_block.pressed.connect(_menu_block_pressed)
	_menu_remove_friend.pressed.connect(_menu_remove_friend_pressed)
	$Window/PlayerMenu/View.pressed.connect(_menu_view_pressed)
	_scroll_up_button.pressed.connect(_scroll_rows.bind(-1))
	_scroll_down_button.pressed.connect(_scroll_rows.bind(1))
	_scroll_track.gui_input.connect(_on_scroll_track_gui_input)
	_scroll_thumb.gui_input.connect(_on_scroll_thumb_gui_input)
	_scroll.get_v_scroll_bar().value_changed.connect(
		_on_internal_scroll_value_changed
	)
	_add_friend_dismiss.pressed.connect(_close_add_friend_modal)
	$AddFriendModal/BtnClose.pressed.connect(_close_add_friend_modal)
	$AddFriendModal/Confirm.pressed.connect(_submit_add_friend)
	_add_friend_input.text_submitted.connect(_submit_add_friend)
	_update_section_buttons()
	call_deferred("_sync_custom_scrollbar")


func open() -> void:
	_refresh_owner_card()
	_select_section(Section.FRIENDS)
	move_to_front()
	_panel_transition = PanelTransitionHelper.play_open(
		self,
		$Window,
		_panel_transition
	)


func close() -> void:
	_request_serial += 1
	_window_dragging = false
	_close_add_friend_modal()
	_hide_player_menu()
	_panel_transition = PanelTransitionHelper.play_close(
		self,
		$Window,
		_panel_transition
	)


func _refresh_owner_card() -> void:
	var data := GameSession.profile.duplicate()
	data.merge(GameSession.lobby_data, true)
	if GameSession.token.is_empty() and GameSession.lobby_data.is_empty():
		data.merge(ProfileProgression.OFFLINE_PREVIEW, true)
	var gender := String(data.get("gender", "male"))
	_owner_avatar.texture = (
		FEMALE_AVATAR if gender == "female" else MALE_AVATAR
	)
	_refresh_owner_level(clampi(int(data.get("level", 1)), 0, 40))
	_owner_name.text = String(data.get("display_name", "Beenn"))


func _refresh_owner_level(level: int) -> void:
	_owner_level.texture = AssetPathAliases.load_texture(
		"res://assets/ui/profile/level/level_%d.png" % level
	)

	var effect_path := ""
	if level >= 36:
		effect_path = LEVEL_FX_36_40
	elif level >= 31:
		effect_path = LEVEL_FX_31_35
	elif level >= 21:
		effect_path = LEVEL_FX_21_30
	elif level >= 11:
		effect_path = LEVEL_FX_11_20

	if effect_path.is_empty():
		_owner_level_effect.stop()
		_owner_level_effect.visible = false
		return

	var is_level_11_to_20 := level >= 11 and level <= 20
	_owner_level_effect.scale = (
		Vector2(0.44, 0.44)
		if is_level_11_to_20
		else Vector2(0.5, 0.5)
	)
	_owner_level_effect.modulate.a = 1.0
	if _owner_level_effect.timeline_path != effect_path:
		_owner_level_effect.load_timeline(effect_path)
	_owner_level_effect.visible = true
	_owner_level_effect.play()


func _select_section(section: Section) -> void:
	_close_add_friend_modal()
	_hide_player_menu()
	_section = section
	_update_section_buttons()
	_refresh()


func _update_section_buttons() -> void:
	var selected_section := _section
	if selected_section == Section.SEARCH:
		selected_section = Section.FRIENDS
	var buttons: Array[Button] = [
		_mentor_button,
		_friends_button,
		_blocked_button,
	]
	var disclosures: Array[TextureRect] = [
		$Window/MentorButton/Disclosure,
		$Window/FriendsButton/Disclosure,
		$Window/BlockedButton/Disclosure,
	]
	for index in buttons.size():
		var selected := index == selected_section
		buttons[index].add_theme_color_override(
			"font_color",
			Color(1, 1, 1, 1)
			if selected
			else Color(0.13, 0.25, 0.3, 1)
		)
		disclosures[index].texture = TREE_OPEN if selected else TREE_CLOSED
		disclosures[index].position = (
			Vector2(5.0, 10.0) if selected else Vector2(7.0, 8.0)
		)
	_section_selection.position.y = 180.0 + float(selected_section) * 30.0


func _set_status(message: String) -> void:
	_friend_counts.visible = false
	_section_status.visible = true
	_section_status.text = message


func _set_friend_counts(friend_count: int, invite_count: int) -> void:
	_section_status.visible = false
	_friend_counts.visible = true
	_friend_count_value.text = str(friend_count)
	_invite_count_value.text = str(invite_count)


func _open_player_search() -> void:
	_section = Section.SEARCH
	_update_section_buttons()
	_search.grab_focus()
	if _search.text.strip_edges().is_empty():
		_clear_rows()
		_set_status("Nhập tên người chơi rồi nhấn Enter.")
	else:
		_refresh()


func _open_add_friend_modal() -> void:
	_hide_player_menu()
	_add_friend_prompt.text = "Nhập tên người chơi"
	_add_friend_input.clear()
	_add_friend_dismiss.visible = true
	_add_friend_modal.visible = true
	_add_friend_input.call_deferred("grab_focus")


func _close_add_friend_modal() -> void:
	_add_friend_modal.visible = false
	_add_friend_dismiss.visible = false
	_add_friend_input.release_focus()


func _submit_add_friend(_submitted_text: String = "") -> void:
	var player_name := _add_friend_input.text.strip_edges()
	if player_name.is_empty():
		_add_friend_prompt.text = "Vui lòng nhập tên người chơi"
		_add_friend_input.grab_focus()
		return
	_close_add_friend_modal()
	_search.text = player_name
	_search_player(player_name)


func _search_player(_submitted_text: String = "") -> void:
	_section = Section.SEARCH
	_update_section_buttons()
	_refresh()


func _refresh() -> void:
	_request_serial += 1
	var request_serial := _request_serial
	_clear_rows()

	if _section == Section.MENTOR:
		_set_status("Sư Đồ")
		_add_empty_row("Chưa có quan hệ Sư Đồ.")
		return

	if _section == Section.SEARCH and _search.text.strip_edges().is_empty():
		_set_status("Tìm người chơi")
		_add_empty_row("Nhập tên người chơi rồi nhấn Enter.")
		return

	if GameSession.token.is_empty() or not GameSession.admission_active:
		_show_offline_preview()
		return

	_set_status("Đang tải danh sách...")
	if _section == Section.FRIENDS:
		var requests_result: Dictionary = await GameSession.fetch_friends(
			"requests"
		)
		if not _request_is_current(request_serial):
			return
		var friends_result: Dictionary = await GameSession.fetch_friends(
			"friends"
		)
		if not _request_is_current(request_serial):
			return
		if not _result_ok(requests_result) or not _result_ok(friends_result):
			_show_request_error(
				requests_result
				if not _result_ok(requests_result)
				else friends_result
			)
			return
		var request_players := _result_players(requests_result)
		var friend_players := _result_players(friends_result)
		_set_friend_counts(friend_players.size(), request_players.size())
		for player_value: Variant in request_players:
			if player_value is Dictionary:
				_add_player_row(player_value, "request")
		for player_value: Variant in friend_players:
			if player_value is Dictionary:
				_add_player_row(player_value, "friend")
		if request_players.is_empty() and friend_players.is_empty():
			_add_empty_row("Chưa có bạn bè. Bấm KẾT BẠN để tìm người chơi.")
	elif _section == Section.BLOCKED:
		var blocked_result: Dictionary = await GameSession.fetch_friends(
			"blocked"
		)
		if not _request_is_current(request_serial):
			return
		if not _result_ok(blocked_result):
			_show_request_error(blocked_result)
			return
		var blocked_players := _result_players(blocked_result)
		_set_status("Sổ đen: %d" % blocked_players.size())
		for player_value: Variant in blocked_players:
			if player_value is Dictionary:
				_add_player_row(player_value, "blocked")
		if blocked_players.is_empty():
			_add_empty_row("Danh sách chặn đang trống.")
	else:
		var search_result: Dictionary = await GameSession.fetch_friends(
			"search",
			_search.text.strip_edges()
		)
		if not _request_is_current(request_serial):
			return
		if not _result_ok(search_result):
			_show_request_error(search_result)
			return
		var found_players := _result_players(search_result)
		_set_status("Kết quả tìm kiếm: %d" % found_players.size())
		for player_value: Variant in found_players:
			if player_value is Dictionary:
				_add_player_row(player_value, "search")
		if found_players.is_empty():
			_add_empty_row("Không tìm thấy người chơi phù hợp.")


func _show_offline_preview() -> void:
	match _section:
		Section.FRIENDS:
			var preview_players: Array[Dictionary] = [
				{
					"account_id": "offline-preview-1",
					"display_name": "Wind→Rosé",
					"gender": "female",
					"level": 32,
					"online": true,
					"guild_name": "League",
					"team_name": "Revied",
					"relationship_status": "accepted",
				},
				{
					"account_id": "offline-preview-2",
					"display_name": "Fatzxje♥",
					"gender": "male",
					"level": 29,
					"online": true,
					"guild_name": "Kim Cương II",
					"relationship_status": "accepted",
				},
				{
					"account_id": "offline-preview-3",
					"display_name": "MRKHOA",
					"gender": "male",
					"level": 25,
					"online": true,
					"relationship_status": "accepted",
				},
				{
					"account_id": "offline-preview-4",
					"display_name": "Anpan",
					"gender": "female",
					"level": 27,
					"online": true,
					"guild_name": "League",
					"relationship_status": "accepted",
				},
				{
					"account_id": "offline-preview-5",
					"display_name": "JohnnyP",
					"gender": "male",
					"level": 24,
					"online": true,
					"team_name": "Revied",
					"relationship_status": "accepted",
				},
				{
					"account_id": "offline-preview-6",
					"display_name": "Neoro",
					"gender": "male",
					"level": 21,
					"online": true,
					"relationship_status": "accepted",
				},
				{
					"account_id": "offline-preview-7",
					"display_name": "Lisa",
					"gender": "female",
					"level": 19,
					"online": true,
					"guild_name": "Rabbit",
					"relationship_status": "accepted",
				},
				{
					"account_id": "offline-preview-8",
					"display_name": "BOYKA.MAFIA",
					"gender": "male",
					"level": 18,
					"online": true,
					"relationship_status": "accepted",
				},
			]
			_set_friend_counts(8, 0)
			for player: Dictionary in preview_players:
				_add_player_row(player, "friend")
		Section.BLOCKED:
			_set_status("Sổ đen: 0")
			_add_empty_row("Danh sách chặn đang trống.")
		Section.SEARCH:
			_set_status("Chưa kết nối máy chủ")
			_add_empty_row("Đăng nhập để tìm và kết bạn với người chơi.")


func _request_is_current(request_serial: int) -> bool:
	return visible and request_serial == _request_serial


func _result_ok(result: Dictionary) -> bool:
	return bool(result.get("ok", false))


func _result_players(result: Dictionary) -> Array:
	var players_value: Variant = result.get("players", [])
	return players_value if players_value is Array else []


func _show_request_error(result: Dictionary) -> void:
	_set_status("Không tải được danh sách")
	_add_empty_row(
		String(result.get("message", "Kết nối máy chủ thất bại."))
	)


func _clear_rows() -> void:
	_hide_player_menu()
	_scroll.scroll_vertical = 0
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	call_deferred("_sync_custom_scrollbar")


func _add_empty_row(message: String) -> void:
	var label := Label.new()
	label.custom_minimum_size = Vector2(248.0, 70.0)
	label.add_theme_color_override(
		"font_color",
		Color(0.05, 0.35, 0.5, 1)
	)
	label.add_theme_font_size_override("font_size", 13)
	label.text = message
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rows.add_child(label)
	call_deferred("_sync_custom_scrollbar")


func _add_player_row(player: Dictionary, row_kind: String) -> void:
	var row := Control.new()
	row.name = "PlayerRow"
	row.custom_minimum_size = Vector2(248.0, 28.0)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	_rows.add_child(row)

	var selection := ColorRect.new()
	selection.name = "Selection"
	selection.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	selection.color = Color(0.02, 0.43, 0.67, 1)
	selection.mouse_filter = Control.MOUSE_FILTER_IGNORE
	selection.visible = false
	row.add_child(selection)

	var status_icon := TextureRect.new()
	status_icon.name = "Status"
	status_icon.position = Vector2(5.0, 2.0)
	status_icon.size = Vector2(16.0, 23.0)
	status_icon.texture = _player_status_texture(player)
	status_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	status_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	status_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(status_icon)

	var name_label := Label.new()
	name_label.name = "PlayerName"
	name_label.position = Vector2(27.0, 1.0)
	name_label.size = Vector2(215.0, 26.0)
	name_label.add_theme_color_override(
		"font_color",
		Color(0.02, 0.25, 0.38, 1)
	)
	name_label.add_theme_color_override(
		"font_outline_color",
		Color(1, 1, 1, 0.85)
	)
	name_label.add_theme_constant_override("outline_size", 1)
	name_label.add_theme_font_size_override("font_size", 15)
	name_label.text = String(player.get("display_name", "Người chơi"))
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_label)

	var click_target := Button.new()
	click_target.name = "ClickTarget"
	click_target.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	click_target.focus_mode = Control.FOCUS_NONE
	click_target.flat = true
	click_target.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	click_target.pressed.connect(
		_show_player_menu.bind(row, selection, player, row_kind)
	)
	row.add_child(click_target)
	call_deferred("_sync_custom_scrollbar")


func _show_player_menu(
	row: Control,
	selection: ColorRect,
	player: Dictionary,
	row_kind: String
) -> void:
	_hide_player_menu()
	_active_player = player.duplicate()
	_active_row_kind = row_kind
	_selected_row_background = selection
	selection.visible = true

	var display_name := String(player.get("display_name", "Người chơi"))
	var guild_name := String(player.get("guild_name", "")).strip_edges()
	var team_name := String(player.get("team_name", "")).strip_edges()
	_menu_player_name.text = display_name
	_menu_guild.text = "Guild: %s" % (
		guild_name if not guild_name.is_empty() else "Không có"
	)
	_menu_team.text = "Team: %s" % (
		team_name if not team_name.is_empty() else "Không có"
	)

	var relationship := String(player.get("relationship_status", ""))
	var incoming := bool(player.get("incoming_request", false))
	var outgoing := bool(player.get("outgoing_request", false))
	_menu_add_friend.text = "Thêm bạn bè"
	_menu_add_friend.disabled = (
		row_kind == "friend"
		or row_kind == "blocked"
		or relationship == "accepted"
		or outgoing
	)
	if row_kind == "request":
		_menu_add_friend.text = "Đồng ý" if incoming else "Đã gửi lời mời"
		_menu_add_friend.disabled = not incoming

	_menu_private_chat.disabled = false
	_menu_copy_name.disabled = false
	_menu_block.text = (
		"Bỏ chặn" if row_kind == "blocked" else "Thêm vào sổ đen"
	)
	_menu_block.disabled = bool(player.get("blocked_me", false))
	_menu_invite_guild.disabled = true
	_menu_observe.disabled = true
	_menu_remove_friend.text = (
		"Từ chối"
		if row_kind == "request" and incoming
		else "Hủy lời mời"
		if row_kind == "request"
		else "Xóa"
	)
	_menu_remove_friend.disabled = row_kind not in ["friend", "request"]

	var row_y: float = row.global_position.y - $Window.global_position.y
	_player_menu.position = Vector2(
		230.0,
		clampf(row_y - 8.0, 180.0, 300.0)
	)
	_player_menu.visible = true


func _scroll_rows(direction: int) -> void:
	var scroll_bar := _scroll.get_v_scroll_bar()
	var maximum := maxf(0.0, scroll_bar.max_value - scroll_bar.page)
	_scroll.scroll_vertical = clampi(
		_scroll.scroll_vertical + direction * SCROLL_STEP,
		0,
		int(ceil(maximum))
	)
	_sync_custom_scrollbar()


func _on_internal_scroll_value_changed(_value: float) -> void:
	_sync_custom_scrollbar()


func _sync_custom_scrollbar() -> void:
	if not is_instance_valid(_scroll):
		return
	var scroll_bar := _scroll.get_v_scroll_bar()
	var maximum := maxf(0.0, scroll_bar.max_value - scroll_bar.page)
	var content_height := maxf(scroll_bar.max_value, scroll_bar.page)
	var visible_ratio := (
		1.0
		if content_height <= 0.0
		else clampf(scroll_bar.page / content_height, 0.0, 1.0)
	)
	var thumb_height := clampf(
		SCROLL_TRACK_HEIGHT * visible_ratio,
		SCROLL_THUMB_MIN_HEIGHT,
		SCROLL_TRACK_HEIGHT
	)
	var travel := SCROLL_TRACK_HEIGHT - thumb_height
	var progress := (
		0.0
		if maximum <= 0.0
		else clampf(scroll_bar.value / maximum, 0.0, 1.0)
	)
	_scroll_thumb.position.y = SCROLL_TRACK_TOP + travel * progress
	_scroll_thumb.size.y = thumb_height
	_scroll_up_button.disabled = maximum <= 0.0
	_scroll_down_button.disabled = maximum <= 0.0
	_scroll_thumb.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
		if maximum <= 0.0
		else Control.MOUSE_FILTER_STOP
	)


func _on_scroll_track_gui_input(event: InputEvent) -> void:
	var mouse_button := event as InputEventMouseButton
	if (
		mouse_button == null
		or not mouse_button.pressed
		or mouse_button.button_index != MOUSE_BUTTON_LEFT
	):
		return
	var scroll_bar := _scroll.get_v_scroll_bar()
	var maximum := maxf(0.0, scroll_bar.max_value - scroll_bar.page)
	if maximum <= 0.0:
		return
	var thumb_height := _scroll_thumb.size.y
	var travel := SCROLL_TRACK_HEIGHT - thumb_height
	if travel <= 0.0:
		return
	var local_y := clampf(
		mouse_button.position.y - thumb_height * 0.5,
		0.0,
		travel
	)
	scroll_bar.value = maximum * local_y / travel
	_sync_custom_scrollbar()
	accept_event()


func _on_scroll_thumb_gui_input(event: InputEvent) -> void:
	var mouse_button := event as InputEventMouseButton
	if mouse_button != null and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		_scroll_thumb_dragging = mouse_button.pressed
		if mouse_button.pressed:
			_scroll_thumb_grab_offset = mouse_button.position.y
			accept_event()
		return

	var mouse_motion := event as InputEventMouseMotion
	if mouse_motion == null or not _scroll_thumb_dragging:
		return
	var scroll_bar := _scroll.get_v_scroll_bar()
	var maximum := maxf(0.0, scroll_bar.max_value - scroll_bar.page)
	var travel := SCROLL_TRACK_HEIGHT - _scroll_thumb.size.y
	if maximum <= 0.0 or travel <= 0.0:
		return
	var track_local_y := _scroll_track.get_local_mouse_position().y
	var thumb_top := clampf(
		track_local_y - _scroll_thumb_grab_offset,
		0.0,
		travel
	)
	scroll_bar.value = maximum * thumb_top / travel
	_sync_custom_scrollbar()
	accept_event()


func _hide_player_menu() -> void:
	_player_menu.visible = false
	if is_instance_valid(_selected_row_background):
		_selected_row_background.visible = false
	_selected_row_background = null
	_active_player.clear()
	_active_row_kind = ""


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if _window_dragging:
		var drag_button := event as InputEventMouseButton
		if (
			drag_button != null
			and drag_button.button_index == MOUSE_BUTTON_LEFT
			and not drag_button.pressed
		):
			_window_dragging = false
			get_viewport().set_input_as_handled()
			return
		var drag_motion := event as InputEventMouseMotion
		if drag_motion != null:
			_move_window_drag(drag_motion.global_position)
			get_viewport().set_input_as_handled()
			return
	if not _player_menu.visible:
		return
	var mouse_event := event as InputEventMouseButton
	if (
		mouse_event == null
		or not mouse_event.pressed
		or mouse_event.button_index != MOUSE_BUTTON_LEFT
	):
		return
	if not _player_menu.get_global_rect().has_point(mouse_event.position):
		_hide_player_menu()


func _on_window_drag_handle_gui_input(event: InputEvent) -> void:
	var mouse_button := event as InputEventMouseButton
	if (
		mouse_button == null
		or mouse_button.button_index != MOUSE_BUTTON_LEFT
	):
		return
	_window_dragging = mouse_button.pressed
	if _window_dragging:
		_window_drag_offset = (
			mouse_button.global_position - _window.global_position
		)
		_hide_player_menu()
	_drag_handle.accept_event()


func _move_window_drag(pointer_position: Vector2) -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var maximum := Vector2(
		maxf(0.0, viewport_size.x - _window.size.x),
		maxf(0.0, viewport_size.y - _window.size.y)
	)
	var target := pointer_position - _window_drag_offset
	_window.global_position = Vector2(
		clampf(target.x, 0.0, maximum.x),
		clampf(target.y, 0.0, maximum.y)
	)


func _unhandled_key_input(event: InputEvent) -> void:
	if (
		visible
		and _add_friend_modal.visible
		and event.is_action_pressed("ui_cancel")
	):
		_close_add_friend_modal()
		get_viewport().set_input_as_handled()


func _menu_add_friend_pressed() -> void:
	if _active_player.is_empty():
		return
	var player := _active_player.duplicate()
	var incoming := bool(player.get("incoming_request", false))
	var row_kind := _active_row_kind
	_hide_player_menu()
	if row_kind == "request" and incoming:
		_accept_friend(player)
	else:
		_send_friend_request(player)


func _menu_private_chat_pressed() -> void:
	if _active_player.is_empty():
		return
	var display_name := String(
		_active_player.get("display_name", "người chơi")
	)
	_hide_player_menu()
	_set_status(
		"Chat riêng với %s chưa mở vì máy chủ chưa có kênh riêng."
		% display_name
	)


func _menu_copy_name_pressed() -> void:
	if _active_player.is_empty():
		return
	var display_name := String(_active_player.get("display_name", ""))
	DisplayServer.clipboard_set(display_name)
	_hide_player_menu()
	_set_status("Đã copy tên: %s" % display_name)


func _menu_block_pressed() -> void:
	if _active_player.is_empty():
		return
	var player := _active_player.duplicate()
	var was_blocked := _active_row_kind == "blocked"
	_hide_player_menu()
	if was_blocked:
		_unblock_player(player)
	else:
		_block_player(player)


func _menu_remove_friend_pressed() -> void:
	if _active_player.is_empty():
		return
	var player := _active_player.duplicate()
	var row_kind := _active_row_kind
	_hide_player_menu()
	if row_kind == "request":
		_decline_friend(player)
	else:
		_remove_friend(player)


func _menu_view_pressed() -> void:
	if _active_player.is_empty():
		return
	var player := _active_player.duplicate()
	_hide_player_menu()
	_open_player_profile(player)


func _player_status_texture(player: Dictionary) -> Texture2D:
	return (
		STATUS_FEMALE_ONLINE
		if String(player.get("gender", "male")) == "female"
		else STATUS_MALE_ONLINE
	)


func _add_row_button(
	parent: HBoxContainer,
	text: String,
	callback: Callable,
	kind: String = "blue"
) -> TextureButton:
	var button := TextureButton.new()
	button.custom_minimum_size = Vector2(58.0, 25.0)
	button.focus_mode = Control.FOCUS_NONE
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_SCALE
	button.texture_normal = (
		ROW_BUTTON_GREEN if kind == "green" else ROW_BUTTON_BLUE
	)
	button.texture_hover = button.texture_normal
	button.texture_pressed = button.texture_normal
	button.texture_disabled = ROW_BUTTON_DISABLED

	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	label.add_theme_color_override(
		"font_outline_color",
		Color(0, 0.25, 0.38, 1)
	)
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_font_size_override("font_size", 9)
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	button.add_child(label)

	if callback.is_valid():
		button.pressed.connect(callback)
	else:
		button.disabled = true
	parent.add_child(button)
	return button


func _add_search_actions(
	actions: HBoxContainer,
	player: Dictionary
) -> void:
	if bool(player.get("blocked_by_me", false)):
		_add_row_button(actions, "BỎ CHẶN", _unblock_player.bind(player))
		return
	if bool(player.get("blocked_me", false)):
		_add_row_button(actions, "KHÔNG THỂ", Callable())
		return
	var relationship := String(player.get("relationship_status", ""))
	if relationship == "accepted":
		_add_row_button(actions, "BẠN BÈ", Callable())
	elif bool(player.get("incoming_request", false)):
		_add_row_button(
			actions,
			"ĐỒNG Ý",
			_accept_friend.bind(player),
			"green"
		)
	elif bool(player.get("outgoing_request", false)):
		_add_row_button(actions, "ĐÃ GỬI", Callable())
	else:
		_add_row_button(
			actions,
			"KẾT BẠN",
			_send_friend_request.bind(player),
			"green"
		)
	_add_row_button(actions, "CHẶN", _block_player.bind(player))


func _open_player_profile(player: Dictionary) -> void:
	var profile_data := player.duplicate()
	var owned_tanks: Array = []
	var tank_key := String(player.get("tank_key", ""))
	if not tank_key.is_empty():
		owned_tanks.append({
			"tank_key": tank_key,
			"display_name": String(player.get("tank_name", tank_key)),
			"level": maxi(1, int(player.get("tank_level", 1))),
			"is_primary": true,
		})
	profile_data["owned_tanks"] = owned_tanks
	profile_requested.emit(profile_data)


func _send_friend_request(player: Dictionary) -> void:
	_set_status("Đang xử lý...")
	var result: Dictionary = await GameSession.send_friend_request(
		String(player.get("account_id", ""))
	)
	_complete_social_action(result)


func _accept_friend(player: Dictionary) -> void:
	_set_status("Đang xử lý...")
	var result: Dictionary = await GameSession.accept_friend_request(
		String(player.get("account_id", ""))
	)
	_complete_social_action(result)


func _decline_friend(player: Dictionary) -> void:
	_set_status("Đang xử lý...")
	var result: Dictionary = await GameSession.decline_friend_request(
		String(player.get("account_id", ""))
	)
	_complete_social_action(result)


func _remove_friend(player: Dictionary) -> void:
	_set_status("Đang xử lý...")
	var result: Dictionary = await GameSession.remove_friend(
		String(player.get("account_id", ""))
	)
	_complete_social_action(result)


func _block_player(player: Dictionary) -> void:
	_set_status("Đang xử lý...")
	var result: Dictionary = await GameSession.block_player(
		String(player.get("account_id", ""))
	)
	_complete_social_action(result)


func _unblock_player(player: Dictionary) -> void:
	_set_status("Đang xử lý...")
	var result: Dictionary = await GameSession.unblock_player(
		String(player.get("account_id", ""))
	)
	_complete_social_action(result)


func _complete_social_action(result: Dictionary) -> void:
	if not visible:
		return
	if not bool(result.get("ok", false)):
		_set_status(String(
			result.get("message", "Thao tác thất bại.")
		))
		return
	call_deferred("_refresh")
