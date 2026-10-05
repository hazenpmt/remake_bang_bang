extends Control

const AssetPathAliases := preload("res://scripts/data/asset_path_aliases.gd")

signal battle_ready(match_data: Dictionary)
signal confirmation_expired

const MATCH_FOUND_BG := preload(
	"res://assets/ui/pvp_match_flow/match_found_bg.png"
)
const AVATAR_FRAME := preload(
	"res://assets/ui/pvp_match_flow/avatar_frame.png"
)
const AVATAR_CONFIRMED := preload(
	"res://assets/ui/pvp_match_flow/avatar_confirmed.png"
)
const CONFIRM_BUTTON := preload(
	"res://assets/ui/pvp_match_flow/confirm_button.png"
)
const CONFIRMED_BUTTON := preload(
	"res://assets/ui/pvp_match_flow/confirmed_button.png"
)
const DEPLOY_BUTTON := preload(
	"res://assets/ui/pvp_match_flow/tank_select/deploy_bg.png"
)
const DEPLOY_TEXT := preload(
	"res://assets/ui/pvp_match_flow/tank_select/deploy_text.png"
)
const DEPLOYED_TEXT := preload(
	"res://assets/ui/pvp_match_flow/tank_select/deployed_text.png"
)
const DEPLOYED_BUTTON := preload(
	"res://assets/ui/pvp_match_flow/deployed_button.png"
)
const TANK_SLOT_SELECTED := preload(
	"res://assets/ui/pvp_match_flow/tank_select/tank_selected_bg.png"
)
const TANK_SLOT_NORMAL := preload(
	"res://assets/ui/pvp_match_flow/tank_select/tank_unselected_bg.png"
)
const TEAM_SELF_SELECTED := preload(
	"res://assets/ui/pvp_match_flow/tank_select/self_selected_bg.png"
)
const TEAM_GRID := preload(
	"res://assets/ui/pvp_match_flow/tank_select/tank_grid_bg.png"
)
const TEAM_GRID_COVER := preload(
	"res://assets/ui/pvp_match_flow/tank_select/tank_grid_cover.png"
)
const TEAM_SELF := preload(
	"res://assets/ui/pvp_match_flow/tank_select/self_bg.png"
)
const TEAM_ALLY := preload(
	"res://assets/ui/pvp_match_flow/tank_select/ally_bg.png"
)
const TEAM_ENEMY := preload(
	"res://assets/ui/pvp_match_flow/tank_select/enemy_bg.png"
)
const TAB_ALL_NORMAL := preload(
	"res://assets/ui/pvp_match_flow/tank_select/tab_all_normal.png"
)
const TAB_ALL_SELECTED := preload(
	"res://assets/ui/pvp_match_flow/tank_select/tab_all_selected.png"
)
const TAB_DPS_NORMAL := preload(
	"res://assets/ui/pvp_match_flow/tank_select/tab_dps_normal.png"
)
const TAB_DPS_SELECTED := preload(
	"res://assets/ui/pvp_match_flow/tank_select/tab_dps_selected.png"
)
const TAB_TANKER_NORMAL := preload(
	"res://assets/ui/pvp_match_flow/tank_select/tab_tanker_normal.png"
)
const TAB_TANKER_SELECTED := preload(
	"res://assets/ui/pvp_match_flow/tank_select/tab_tanker_selected.png"
)
const TAB_SUPPORT_NORMAL := preload(
	"res://assets/ui/pvp_match_flow/tank_select/tab_support_normal.png"
)
const TAB_SUPPORT_SELECTED := preload(
	"res://assets/ui/pvp_match_flow/tank_select/tab_support_selected.png"
)
const BTN_SKIN := preload("res://assets/ui/tank/btn_skin.png")
const MATCH_SKIN_BG := preload("res://assets/ui/tank/skin_bg.png")
const MATCH_SKIN_TITLE := preload("res://assets/ui/tank/skin_title.png")
const MATCH_SKIN_CLOSE := preload("res://assets/ui/tank/close.png")
const MATCH_SKIN_BOOTH := preload("res://assets/ui/tank/skin_booth.png")
const MATCH_SKIN_EQUIPPED := preload("res://assets/ui/tank/skin_equipped.png")
const MATCH_SKIN_USE_BG := preload("res://assets/ui/tank/skin_use_button_bg.png")
const MATCH_SKIN_USE_TEXT := preload("res://assets/ui/tank/skin_use_text.png")
const MATCH_SKIN_RATING_TITLE := preload("res://assets/ui/tank/skin_rating_title.png")
const MATCH_SKIN_RATING_A := preload("res://assets/ui/tank/skin_rating_a.png")
const MATCH_SKIN_RATING_S := preload("res://assets/ui/tank/skin_rating_s.png")
const MATCH_SKIN_RATING_SS := preload("res://assets/ui/tank/skin_rating_ss.png")
const MATCH_SKIN_RATING_SSS := preload("res://assets/ui/tank/skin_rating_sss.png")
const MATCH_SKIN_TAB_BG := preload("res://assets/ui/tank/skin_tab_background.png")
const MATCH_SKIN_TAB_BG_SELECTED := preload(
	"res://assets/ui/tank/skin_tab_background_selected.png"
)
const MATCH_SKIN_TAB_ALL := preload("res://assets/ui/tank/skin_tab_all.png")
const MATCH_SKIN_TAB_ALL_SELECTED := preload(
	"res://assets/ui/tank/skin_tab_all_selected.png"
)
const MATCH_SKIN_TAB_A := preload("res://assets/ui/tank/skin_tab_a.png")
const MATCH_SKIN_TAB_A_SELECTED := preload(
	"res://assets/ui/tank/skin_tab_a_selected.png"
)
const MATCH_SKIN_TAB_S := preload("res://assets/ui/tank/skin_tab_s.png")
const MATCH_SKIN_TAB_S_SELECTED := preload(
	"res://assets/ui/tank/skin_tab_s_selected.png"
)
const MATCH_SKIN_TAB_SS := preload("res://assets/ui/tank/skin_tab_ss.png")
const MATCH_SKIN_TAB_SS_SELECTED := preload(
	"res://assets/ui/tank/skin_tab_ss_selected.png"
)
const MATCH_SKIN_TAB_SSS := preload("res://assets/ui/tank/skin_tab_sss.png")
const MATCH_SKIN_TAB_SSS_SELECTED := preload(
	"res://assets/ui/tank/skin_tab_sss_selected.png"
)
const MATCH_SKIN_SCROLL_LEFT := preload("res://assets/ui/chat/scrollbar_up.png")
const MATCH_SKIN_SCROLL_RIGHT := preload("res://assets/ui/chat/scrollbar_down.png")
const MATCH_SKIN_SCROLL_TRACK := preload("res://assets/ui/chat/scrollbar_track.png")
const MATCH_SKIN_SCROLL_THUMB := preload("res://assets/ui/tank/skin_scroll_thumb.png")
const MATCH_SCROLL_UP := preload("res://assets/ui/chat/scrollbar_up.png")
const MATCH_SCROLL_DOWN := preload("res://assets/ui/chat/scrollbar_down.png")
const MATCH_SCROLL_TRACK := preload("res://assets/ui/chat/scrollbar_track.png")
const MATCH_SCROLL_THUMB := preload("res://assets/ui/tank/skin_scroll_thumb.png")
const TEAM_CHAT_COMPACT_BG := preload(
	"res://assets/ui/pvp_match_flow/tank_select/pvp_chat_compact.png"
)
const TEAM_CHAT_EXPANDED_BG := preload(
	"res://assets/ui/pvp_match_flow/tank_select/pvp_chat_expanded.png"
)
const TANK_INTRO_BACKGROUND := preload(
	"res://assets/battle/hud/respawn/relive_bg_pve.png"
)
const BATTLE_LOADING_BG := preload(
	"res://assets/ui/pvp_match_flow/battle_loading_bg.png"
)
const LOADING_HEXAGON := preload(
	"res://assets/ui/pvp_match_flow/loading_hexagon.png"
)
const LOADING_HEXAGON_LIGHT := preload(
	"res://assets/ui/pvp_match_flow/loading_hexagon_light.png"
)
const LOADING_VS := preload(
	"res://assets/ui/pvp_match_flow/loading_vs.png"
)
const LOADING_BAR := preload(
	"res://assets/ui/pvp_match_flow/loading_bar.png"
)
const LOADING_BAR_BG := preload(
	"res://assets/ui/pvp_match_flow/loading_bar_bg.png"
)
const LOADING_CHAT_BUBBLE_TOP := preload(
	"res://assets/ui/pvp_match_flow/chat/talk/talkbktop.png"
)
const LOADING_CHAT_BUBBLE_MIDDLE := preload(
	"res://assets/ui/pvp_match_flow/chat/talk/talkbkmiddle.png"
)
const LOADING_CHAT_BUBBLE_BOTTOM := preload(
	"res://assets/ui/pvp_match_flow/chat/talk/talkbkbottom.png"
)
const DEFAULT_BATTLE_MAP_THUMBNAIL := preload(
	"res://assets/battle/maps/Maya Tiên tri(Tính điểm)/stage1_small.jpg"
)
const AVATAR_MALE := preload("res://assets/ui/profile/avatar_male.png")
const AVATAR_FEMALE := preload("res://assets/ui/profile/avatar_female.png")
const SEA_BACKGROUND := preload("res://assets/ui/bg_sea.jpg")
const TankSkinCatalog := preload("res://scripts/lobby/tank_skin_catalog.gd")
const PvpTankHeadCatalog := preload(
	"res://scripts/lobby/pvp_tank_head_catalog.gd"
)
const TRANSITION_TIMELINE := (
	"res://assets/animations/pvp_battle_transition_compact/timeline.json"
)
const CONFIRM_EFFECT_TIMELINE := (
	"res://assets/animations/pvp_confirm_button_effect_compact/timeline.json"
)
const DEPLOY_EFFECT_TIMELINE := (
	"res://assets/animations/pvp_deploy_button_effect_compact/timeline.json"
)

const POLL_INTERVAL := 0.5
const TEAM_CHAT_POLL_INTERVAL := 1.0
const LOADING_CHAT_POLL_INTERVAL := 1.5
const LOADING_CHAT_BUBBLE_SECONDS := 4.0
const LOCAL_BOT_CONFIRM_STEP := 0.35
const LOCAL_PREPARATION_SECONDS := 5.0
const TRANSITION_MAP_REVEAL_FRAME := 25
const DESIGN_SIZE := Vector2(1920.0, 1080.0)
const TEAM_CHAT_COMPACT_SIZE := Vector2(557.0, 79.0)
const TEAM_CHAT_EXPANDED_SIZE := Vector2(557.0, 129.0)
const TEAM_CHAT_BOTTOM := 601.0
const TEAM_CHAT_MAX_LOCAL_MESSAGES := 100
const TEAM_VISUAL_CLIP_POSITION := Vector2(5.0, 5.0)
const TEAM_VISUAL_CLIP_SIZE := Vector2(168.0, 88.0)
const TEAM_CARD_SIZE := Vector2(178.0, 98.0)
const IRONMAN_PREVIEW_SKINS := [
	["gangtiexia03_default", "Iron Man", ""],
	["gangtiexia04", "Iron Man 2", "A"],
	["gangtiexia05", "Iron Man 3", "S"],
	["gangtiexia_pf04", "MK-42", "SS"],
	["gangtiexia_pf01", "Bão Sa Mạc", "SS"],
	["gangtiexia_pf05", "Patriot", "SS"],
	["gangtiexia_pf03", "Dũng Sĩ Bình Minh", "SS"],
	["gangtiexia_pf02", "Chiến Cảnh Tương Lai", "SS"],
	["gangtiexia_pf06", "Hồng Liên (Iron Man)", "SSS"],
]

var _match_data: Dictionary = {}
var _phase := ""
var _poll_elapsed := 0.0
var _request_in_flight := false
var _poll_in_flight := false
var _local_preview := false
var _local_elapsed := 0.0
var _local_preparation_elapsed := 0.0
var _local_preparation_started := false
var _intro_dismissed := false
var _reported_load_steps: Dictionary = {}
var _battle_emitted := false

var _match_found: Control
var _match_counter: Label
var _match_countdown: Label
var _confirm_button: TextureButton
var _confirm_effect: SwfTimelinePlayer
var _avatar_images: Array[TextureRect] = []
var _avatar_glows: Array[TextureRect] = []
var _avatar_questions: Array[Label] = []

var _tank_select: Control
var _tank_intro: Label
var _tank_phase_status: Label
var _tank_grid: GridContainer
var _tank_scroll: ScrollContainer
var _tank_scrollbar: Control
var _tank_scrollbar_track: TextureRect
var _tank_scrollbar_thumb: TextureRect
var _tank_scrollbar_dragging := false
var _tank_scrollbar_drag_offset := 0.0
var _deploy_button: TextureButton
var _deploy_state_text: TextureRect
var _deploy_effect: SwfTimelinePlayer
var _tank_role_value: Label
var _team_left: VBoxContainer
var _team_right: VBoxContainer
var _selected_tank_key := ""
var _selected_tank_role := "all"
var _selected_skin_key := ""
var _selection_display_elapsed := 0.0
var _tank_buttons: Dictionary = {}
var _skin_buttons: Dictionary = {}
var _tank_role_buttons: Dictionary = {}
var _tank_choice_visual_position := Vector2(10.5, 5.0)
var _tank_choice_visual_size := Vector2(200.0, 200.0)
var _tank_choice_visual_scale := Vector2(0.375, 0.375)
var _tank_choice_button_position := Vector2.ZERO
var _tank_choice_button_size := Vector2(96.0, 96.0)
var _tank_choice_level_position := Vector2(9.0, -1.0)
var _tank_choice_level_size := Vector2(86.0, 21.0)
var _tank_choice_level_scale := Vector2.ONE
var _tank_choice_level_rotation := 0.0
var _tank_choice_level_pivot := Vector2.ZERO
var _tank_choice_skin_frame_position := Vector2.ZERO
var _tank_choice_skin_frame_size := Vector2(96.0, 96.0)
var _tank_choice_skin_frame_scale := Vector2.ONE
var _tank_choice_skin_frame_rotation := 0.0
var _tank_choice_skin_frame_pivot := Vector2.ZERO
var _team_visual_position := Vector2.ZERO
var _team_visual_size := Vector2(200.0, 200.0)
var _team_visual_scale := Vector2.ONE
var _team_visual_rotation := 0.0
var _team_visual_pivot := Vector2(100.0, 100.0)
var _team_skin_frame_position := Vector2(4.5, 3.0)
var _team_skin_frame_size := Vector2(169.0, 92.0)
var _team_skin_frame_scale := Vector2.ONE
var _team_skin_frame_rotation := 0.0
var _team_skin_frame_pivot := Vector2.ZERO
var _team_column_signatures: Dictionary = {}

var _match_skin_overlay: Control
var _match_skin_panel: Control
var _match_skin_viewport: Control
var _match_skin_content: Control
var _match_skin_empty_label: Label
var _match_skin_scrollbar: Control
var _match_skin_scroll_thumb: TextureRect
var _match_skin_quality_buttons: Dictionary = {}
var _match_skin_use_buttons: Array[TextureButton] = []
var _match_skin_quality := "all"
var _match_skin_scroll_value := 0.0
var _match_skin_scroll_max := 0.0
var _match_skin_scroll_dragging := false
var _match_skin_scroll_drag_offset := 0.0
var _match_skin_render_signature := ""

var _team_chat: Control
var _team_chat_background: TextureRect
var _team_chat_history: RichTextLabel
var _team_chat_input: LineEdit
var _team_chat_send: TextureButton
var _team_chat_scroll_track: TextureRect
var _team_chat_scroll_up: TextureButton
var _team_chat_scroll_down: TextureButton
var _team_chat_messages: Array[Dictionary] = []
var _team_chat_last_id := 0
var _team_chat_scroll_offset := 0
var _team_chat_poll_elapsed := 0.0
var _team_chat_poll_in_flight := false
var _team_chat_send_in_flight := false
var _team_chat_expanded := false
var _team_chat_hovered := false
var _team_chat_pinned_open := false

var _battle_loading: Control
var _loading_left: Control
var _loading_right: Control
var _loading_left_card_positions: Array[Vector2] = []
var _loading_right_card_positions: Array[Vector2] = []
var _loading_clock: SwfTimelinePlayer
var _loading_cards: Array[Control] = []
var _loading_map_name: Label
var _loading_map_preview: TextureRect
var _battle_map: Control
var _battle_map_prepared := false
var _battle_map_revealed := false
var _battle_result_screen: PvpBattleResultScreen
var _loading_chat: Control
var _loading_chat_channel_label: Label
var _loading_chat_input: LineEdit
var _loading_chat_channel_button: Button
var _loading_chat_send_button: Button
var _loading_chat_quick_button: Button
var _loading_chat_quick_panel: Panel
var _loading_chat_quick_close: Button
var _loading_chat_channel := "team"
var _loading_chat_last_ids := {"team": 0, "battle": 0}
var _loading_chat_poll_elapsed := LOADING_CHAT_POLL_INTERVAL
var _loading_chat_poll_in_flight := false
var _loading_chat_send_in_flight := false
var _loading_card_by_account: Dictionary = {}
var _loading_card_by_name: Dictionary = {}
var _loading_bubble_payloads: Dictionary = {}

var _transition_layer: Control
var _transition_player: SwfTimelinePlayer
var _transition_finished := false


func _ready() -> void:
	set_process(true)
	_bind_scene_nodes()
	if not GameSession.lobby_data_changed.is_connected(_on_lobby_data_changed):
		GameSession.lobby_data_changed.connect(_on_lobby_data_changed)
	if get_tree().current_scene == self:
		call_deferred("_start_standalone_offline_preview")


func _bind_scene_nodes() -> void:
	_match_found = $MatchFound
	_match_counter = $MatchFound/Window/Counter
	_match_countdown = $MatchFound/Window/Countdown
	_confirm_button = $MatchFound/Window/Confirm
	_confirm_effect = $MatchFound/Window/ConfirmEffect
	for index in 10:
		var slot := $MatchFound/Window/AvatarSlots.get_node(
			"Slot%02d" % (index + 1)
		)
		_avatar_images.append(slot.get_node("Avatar") as TextureRect)
		_avatar_glows.append(slot.get_node("Glow") as TextureRect)
		_avatar_questions.append(slot.get_node("Question") as Label)
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_enable_button_hover(_confirm_button)

	_tank_select = $TankSelect
	_tank_intro = $TankSelect/Intro
	_tank_phase_status = $TankSelect/Panel/Center/PhaseStatus
	_team_left = $TankSelect/Panel/TeamLeft
	_team_right = $TankSelect/Panel/TeamRight
	var team_visual_preview := (
		$TankSelect/Panel/TeamLeft/EditorPreviewSlot01/TeamVisualClip/TeamVisualCoordinates/TeamVisualRoot
		as Control
	)
	_team_visual_position = team_visual_preview.position
	_team_visual_size = team_visual_preview.size
	_team_visual_scale = team_visual_preview.scale
	_team_visual_rotation = team_visual_preview.rotation
	_team_visual_pivot = team_visual_preview.pivot_offset
	var team_skin_frame_preview := (
		$TankSelect/Panel/TeamLeft/EditorPreviewSlot01/SkinFrame
		as TextureRect
	)
	_team_skin_frame_position = team_skin_frame_preview.position
	_team_skin_frame_size = team_skin_frame_preview.size
	_team_skin_frame_scale = team_skin_frame_preview.scale
	_team_skin_frame_rotation = team_skin_frame_preview.rotation
	_team_skin_frame_pivot = team_skin_frame_preview.pivot_offset
	_tank_scroll = $TankSelect/Panel/Center/TankScroll
	_tank_grid = $TankSelect/Panel/Center/TankScroll/TankGrid
	_tank_scrollbar = $TankSelect/Panel/Center/TankScrollBar
	_tank_scrollbar_track = $TankSelect/Panel/Center/TankScrollBar/Track
	_tank_scrollbar_thumb = $TankSelect/Panel/Center/TankScrollBar/Thumb
	var tank_visual_preview := get_node(
		"TankSelect/Panel/Center/TankScroll/TankGrid/"
		+ "EditorPreviewCell01/EditorPreviewTank01/TankVisual"
	) as TextureRect
	var tank_button_preview := tank_visual_preview.get_parent() as TextureButton
	_tank_choice_visual_position = tank_visual_preview.position
	_tank_choice_visual_size = tank_visual_preview.size
	_tank_choice_visual_scale = tank_visual_preview.scale
	_tank_choice_button_position = tank_button_preview.position
	_tank_choice_button_size = tank_button_preview.size
	var tank_level_preview := tank_button_preview.get_node("Level") as TextureRect
	_tank_choice_level_position = tank_level_preview.position
	_tank_choice_level_size = tank_level_preview.size
	_tank_choice_level_scale = tank_level_preview.scale
	_tank_choice_level_rotation = tank_level_preview.rotation
	_tank_choice_level_pivot = tank_level_preview.pivot_offset
	var tank_skin_frame_preview := (
		tank_button_preview.get_node("SkinFrame")
		as TextureRect
	)
	_tank_choice_skin_frame_position = tank_skin_frame_preview.position
	_tank_choice_skin_frame_size = tank_skin_frame_preview.size
	_tank_choice_skin_frame_scale = tank_skin_frame_preview.scale
	_tank_choice_skin_frame_rotation = tank_skin_frame_preview.rotation
	_tank_choice_skin_frame_pivot = tank_skin_frame_preview.pivot_offset
	_clear_editor_preview_tank_slots()
	_deploy_button = $TankSelect/Panel/Center/Deploy
	_deploy_state_text = $TankSelect/Panel/Center/Deploy/StateText
	_deploy_effect = $TankSelect/Panel/Center/DeployEffect
	_deploy_effect.timeline_path = DEPLOY_EFFECT_TIMELINE
	_tank_role_value = $TankSelect/Panel/Center/RoleBox/Value
	_deploy_button.pressed.connect(_on_deploy_pressed)
	_enable_button_hover(_deploy_button)
	_tank_role_buttons = {
		"all": $TankSelect/Panel/Center/RoleTabs/All,
		"dps": $TankSelect/Panel/Center/RoleTabs/Dps,
		"tanker": $TankSelect/Panel/Center/RoleTabs/Tanker,
		"support": $TankSelect/Panel/Center/RoleTabs/Support,
		"skin": $TankSelect/Panel/Center/RoleTabs/Skin,
	}
	for role_key: String in _tank_role_buttons:
		var role_button := _tank_role_buttons[role_key] as TextureButton
		role_button.pressed.connect(_on_tank_role_pressed.bind(role_key))
		_enable_button_hover(role_button)
	_build_match_skin_overlay()
	_refresh_tank_role_buttons()
	_style_tank_vertical_scrollbar()
	_bind_team_chat()

	_battle_loading = $BattleLoading
	_loading_left = $BattleLoading/AllyCards
	_loading_right = $BattleLoading/EnemyCards
	_capture_loading_card_layouts()
	_loading_clock = $BattleLoading/Clock
	_loading_map_name = $BattleLoading/MapName
	_loading_map_preview = $BattleLoading/MapPreviewFrame/Thumbnail
	_battle_map = $BattleMap
	if _battle_map.has_signal("result_summary_requested"):
		_battle_map.connect(
			"result_summary_requested",
			_on_battle_result_summary_requested
		)
	_battle_result_screen = get_node_or_null("BattleResultScreen") as PvpBattleResultScreen
	if _battle_result_screen != null:
		_battle_result_screen.exit_requested.connect(
			_on_battle_result_exit_requested
		)
		_battle_result_screen.leave_requested.connect(
			_on_battle_result_leave_requested
		)
	else:
		push_error("PvpMatchFlow: BattleResultScreen failed to load.")
	_bind_loading_chat()

	_transition_layer = $Transition
	_transition_player = $Transition/OriginalBattleDoor
	_transition_player.frame_changed.connect(_on_transition_frame_changed)
	_transition_layer.resized.connect(_center_transition_player)
	call_deferred("_center_transition_player")


func bind_shared_chat(chat: Control) -> void:
	if _battle_result_screen == null:
		_battle_result_screen = get_node_or_null("BattleResultScreen") as PvpBattleResultScreen
	if _battle_result_screen != null:
		_battle_result_screen.bind_shared_chat(chat)


func _bind_loading_chat() -> void:
	_loading_chat = $BattleLoading/LoadingChat
	_loading_chat_channel_label = $BattleLoading/LoadingChat/Channel
	_loading_chat_input = $BattleLoading/LoadingChat/Input
	_loading_chat_channel_button = $BattleLoading/LoadingChat/ChannelButton
	_loading_chat_send_button = $BattleLoading/LoadingChat/SendButton
	_loading_chat_quick_button = $BattleLoading/LoadingChat/QuickButton
	_loading_chat_quick_panel = $BattleLoading/LoadingChat/QuickPanel
	_loading_chat_quick_close = $BattleLoading/LoadingChat/QuickPanel/Close
	_loading_chat_channel_button.pressed.connect(_toggle_loading_chat_channel)
	_loading_chat_send_button.pressed.connect(_send_loading_chat)
	_loading_chat_quick_button.pressed.connect(_toggle_loading_quick_chat)
	_loading_chat_quick_close.pressed.connect(_hide_loading_quick_chat)
	_loading_chat_input.text_submitted.connect(_on_loading_chat_submitted)
	for child in $BattleLoading/LoadingChat/QuickPanel/Options.get_children():
		var option := child as Button
		if option != null:
			option.pressed.connect(_on_loading_quick_chat_selected.bind(option.text))
	_set_loading_chat_channel("team")


func _set_loading_chat_channel(channel: String) -> void:
	_loading_chat_channel = "battle" if channel == "battle" else "team"
	if _loading_chat_channel_label != null:
		_loading_chat_channel_label.text = (
			"Chiến trường" if _loading_chat_channel == "battle" else "Phe ta"
		)
	if _loading_chat_quick_panel != null:
		_loading_chat_quick_panel.visible = false


func _toggle_loading_chat_channel() -> void:
	_set_loading_chat_channel(
		"battle" if _loading_chat_channel == "team" else "team"
	)
	_loading_chat_input.grab_focus()


func _toggle_loading_quick_chat() -> void:
	if not _loading_chat_is_active():
		return
	_loading_chat_quick_panel.visible = not _loading_chat_quick_panel.visible


func _hide_loading_quick_chat() -> void:
	if _loading_chat_quick_panel != null:
		_loading_chat_quick_panel.visible = false


func _on_loading_chat_submitted(_text: String) -> void:
	_send_loading_chat()


func _on_loading_quick_chat_selected(message: String) -> void:
	_loading_chat_input.text = message
	_hide_loading_quick_chat()
	_send_loading_chat()


func _loading_chat_is_active() -> bool:
	return _phase == "loading" or _phase == "transition"


func _reset_loading_chat() -> void:
	_loading_chat_last_ids = {"team": 0, "battle": 0}
	_loading_chat_poll_elapsed = LOADING_CHAT_POLL_INTERVAL
	_loading_chat_poll_in_flight = false
	_loading_chat_send_in_flight = false
	_loading_bubble_payloads.clear()
	if _loading_chat_input != null:
		_loading_chat_input.clear()
		_loading_chat_input.editable = true
		_loading_chat_input.placeholder_text = "Nhập nội dung chat"
		_loading_chat_input.release_focus()
	_set_loading_chat_channel("team")


func _poll_loading_chat() -> void:
	if _loading_chat_poll_in_flight or not _loading_chat_is_active():
		return
	_loading_chat_poll_in_flight = true
	for channel in ["team", "battle"]:
		var result: Dictionary = await GameSession.fetch_game_match_chat(
			channel,
			int(_loading_chat_last_ids.get(channel, 0)),
			50
		)
		if not result.get("ok", false):
			continue
		var received: Variant = result.get("messages", [])
		if received is Array:
			_append_loading_chat_messages(channel, received)
	_loading_chat_poll_in_flight = false


func _send_loading_chat() -> void:
	if _loading_chat_send_in_flight or not _loading_chat_is_active():
		return
	var message := _loading_chat_input.text.strip_edges()
	if message.is_empty():
		_loading_chat_input.grab_focus()
		return
	var channel := _loading_chat_channel
	if _local_preview:
		var viewer := _viewer_participant()
		var next_id := int(_loading_chat_last_ids.get(channel, 0)) + 1
		_append_loading_chat_messages(channel, [{
			"id": next_id,
			"sender_account_id": String(viewer.get("account_id", "local-player")),
			"sender_name": String(viewer.get("display_name", "Bạn")),
			"body": message,
		}])
		_loading_chat_input.clear()
		return
	_loading_chat_send_in_flight = true
	_loading_chat_input.editable = false
	var result: Dictionary = await GameSession.send_game_match_chat(message, channel)
	_loading_chat_send_in_flight = false
	_loading_chat_input.editable = true
	if not result.get("ok", false):
		var error_value: Variant = result.get("error", {})
		_loading_chat_input.placeholder_text = (
			String(error_value.get("message", "Không thể gửi chat lúc này."))
			if error_value is Dictionary
			else "Không thể gửi chat lúc này."
		)
		_loading_chat_input.grab_focus()
		return
	_loading_chat_input.clear()
	var sent: Variant = result.get("message", {})
	if sent is Dictionary:
		_append_loading_chat_messages(channel, [sent])


func _append_loading_chat_messages(channel: String, received: Array) -> void:
	var last_id := int(_loading_chat_last_ids.get(channel, 0))
	for value in received:
		if value is not Dictionary:
			continue
		var message: Dictionary = value
		var message_id := int(String(message.get("id", "0")))
		if message_id <= last_id:
			continue
		last_id = message_id
		_show_loading_chat_bubble(message)
	_loading_chat_last_ids[channel] = last_id


func _show_loading_chat_bubble(message: Dictionary) -> void:
	var account_id := String(message.get("sender_account_id", ""))
	var sender_name := String(message.get("sender_name", ""))
	var key := account_id if not account_id.is_empty() else sender_name
	if key.is_empty():
		return
	_loading_bubble_payloads[key] = {
		"body": String(message.get("body", "")),
		"account_id": account_id,
		"sender_name": sender_name,
		"expires_at": Time.get_ticks_msec() + int(LOADING_CHAT_BUBBLE_SECONDS * 1000.0),
	}
	_restore_loading_chat_bubbles()


func _restore_loading_chat_bubbles() -> void:
	var now := Time.get_ticks_msec()
	for key_variant in _loading_bubble_payloads.keys():
		var key := String(key_variant)
		var payload: Dictionary = _loading_bubble_payloads.get(key, {})
		if now >= int(payload.get("expires_at", 0)):
			_loading_bubble_payloads.erase(key)
			continue
		var card := _loading_card_by_account.get(
			String(payload.get("account_id", "")),
			null
		) as Control
		if card == null:
			card = _loading_card_by_name.get(
				String(payload.get("sender_name", "")),
				null
			) as Control
		if card != null:
			_attach_loading_chat_bubble(card, String(payload.get("body", "")))


func _attach_loading_chat_bubble(card: Control, message: String) -> void:
	var previous := card.get_node_or_null("ChatBubble") as Control
	if previous != null:
		previous.queue_free()
	var bubble := Control.new()
	bubble.name = "ChatBubble"
	bubble.position = Vector2(35.0, -54.0)
	bubble.size = Vector2(166.0, 52.0)
	bubble.z_index = 10
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(bubble)
	for part_data in [
		[LOADING_CHAT_BUBBLE_TOP, Vector2(0.0, 0.0)],
		[LOADING_CHAT_BUBBLE_MIDDLE, Vector2(0.0, 27.0)],
		[LOADING_CHAT_BUBBLE_MIDDLE, Vector2(0.0, 35.0)],
		[LOADING_CHAT_BUBBLE_BOTTOM, Vector2(0.0, 43.0)],
	]:
		var part := TextureRect.new()
		part.texture = part_data[0] as Texture2D
		part.position = part_data[1] as Vector2
		part.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		part.stretch_mode = TextureRect.STRETCH_KEEP
		part.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bubble.add_child(part)
	var text := _label(Vector2(10.0, 7.0), Vector2(146.0, 34.0), 12)
	text.text = message.left(48)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_color_override("font_color", Color(0.08, 0.08, 0.08, 1.0))
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.add_child(text)


func _clear_editor_preview_tank_slots() -> void:
	for child in _tank_grid.get_children():
		if child.name.begins_with("EditorPreviewCell"):
			child.free()


func _style_tank_vertical_scrollbar() -> void:
	if _tank_scroll == null:
		return
	var custom_up := $TankSelect/Panel/Center/TankScrollBar/Up as TextureButton
	var custom_down := $TankSelect/Panel/Center/TankScrollBar/Down as TextureButton
	custom_up.pressed.connect(_scroll_tank_by.bind(-96))
	custom_down.pressed.connect(_scroll_tank_by.bind(96))
	_tank_scrollbar_track.gui_input.connect(_on_tank_scrollbar_track_input)
	_tank_scrollbar_thumb.gui_input.connect(_on_tank_scrollbar_thumb_input)
	var scrollbar := _tank_scroll.get_v_scroll_bar()
	scrollbar.modulate = Color(1.0, 1.0, 1.0, 0.0)
	scrollbar.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _scroll_tank_by(amount: int) -> void:
	if _tank_scroll == null:
		return
	var bar := _tank_scroll.get_v_scroll_bar()
	var maximum := maxi(0, int(bar.max_value - bar.page))
	_tank_scroll.scroll_vertical = clampi(
		_tank_scroll.scroll_vertical + amount,
		0,
		maximum
	)


func _sync_tank_scrollbar() -> void:
	if _tank_scroll == null or _tank_scrollbar_thumb == null:
		return
	var bar := _tank_scroll.get_v_scroll_bar()
	var maximum := maxf(0.0, bar.max_value - bar.page)
	var travel := maxf(
		0.0,
		_tank_scrollbar_track.size.y - _tank_scrollbar_thumb.size.y
	)
	var ratio := (
		float(_tank_scroll.scroll_vertical) / maximum
		if maximum > 0.0
		else 0.0
	)
	_tank_scrollbar_thumb.position.y = (
		_tank_scrollbar_track.position.y + travel * ratio
	)


func _on_tank_scrollbar_track_input(event: InputEvent) -> void:
	if (
		event is not InputEventMouseButton
		or not event.pressed
		or event.button_index != MOUSE_BUTTON_LEFT
	):
		return
	var local_y: float = (event as InputEventMouseButton).position.y
	var travel := maxf(
		1.0,
		_tank_scrollbar_track.size.y - _tank_scrollbar_thumb.size.y
	)
	var ratio := clampf(
		(local_y - _tank_scrollbar_thumb.size.y * 0.5) / travel,
		0.0,
		1.0
	)
	var bar := _tank_scroll.get_v_scroll_bar()
	_tank_scroll.scroll_vertical = int(
		roundf(ratio * maxf(0.0, bar.max_value - bar.page))
	)
	get_viewport().set_input_as_handled()


func _on_tank_scrollbar_thumb_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_tank_scrollbar_dragging = true
			_tank_scrollbar_drag_offset = event.position.y
		else:
			_tank_scrollbar_dragging = false
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _tank_scrollbar_dragging:
		var travel := maxf(
			1.0,
			_tank_scrollbar_track.size.y - _tank_scrollbar_thumb.size.y
		)
		var thumb_y := clampf(
			_tank_scrollbar_thumb.position.y
			+ event.relative.y,
			_tank_scrollbar_track.position.y,
			_tank_scrollbar_track.position.y + travel
		)
		var ratio := (
			thumb_y - _tank_scrollbar_track.position.y
		) / travel
		var bar := _tank_scroll.get_v_scroll_bar()
		_tank_scroll.scroll_vertical = int(
			roundf(ratio * maxf(0.0, bar.max_value - bar.page))
		)
		get_viewport().set_input_as_handled()


func _bind_team_chat() -> void:
	_team_chat = $TankSelect/Panel/Center/Chat
	_team_chat_background = $TankSelect/Panel/Center/Chat/Background
	_team_chat_history = $TankSelect/Panel/Center/Chat/History
	_team_chat_input = $TankSelect/Panel/Center/Chat/Input
	_team_chat_send = $TankSelect/Panel/Center/Chat/Send
	_team_chat_scroll_track = $TankSelect/Panel/Center/Chat/ScrollTrack
	_team_chat_scroll_up = $TankSelect/Panel/Center/Chat/ScrollUp
	_team_chat_scroll_down = $TankSelect/Panel/Center/Chat/ScrollDown
	_team_chat_scroll_track.texture = MATCH_SCROLL_TRACK
	_team_chat_scroll_up.texture_normal = MATCH_SCROLL_UP
	_team_chat_scroll_down.texture_normal = MATCH_SCROLL_DOWN
	_team_chat_input.focus_entered.connect(_on_team_chat_input_focus_entered)
	_team_chat_input.text_changed.connect(_on_team_chat_input_changed)
	_team_chat_input.text_submitted.connect(_on_team_chat_input_submitted)
	_team_chat_send.pressed.connect(_send_team_chat)
	_team_chat_scroll_up.pressed.connect(_scroll_team_chat_up)
	_team_chat_scroll_down.pressed.connect(_scroll_team_chat_down)
	_team_chat_history.gui_input.connect(_on_team_chat_history_input)
	_enable_button_hover(_team_chat_send)
	_enable_button_hover(_team_chat_scroll_up)
	_enable_button_hover(_team_chat_scroll_down)
	_set_team_chat_expanded(false)
	_render_team_chat()


func _set_team_chat_expanded(expanded: bool) -> void:
	if _team_chat == null:
		return
	_team_chat_expanded = expanded
	var target_size := (
		TEAM_CHAT_EXPANDED_SIZE if expanded else TEAM_CHAT_COMPACT_SIZE
	)
	_team_chat.position = Vector2(
		_team_chat.position.x,
		TEAM_CHAT_BOTTOM - target_size.y
	)
	_team_chat.size = target_size
	_team_chat_background.texture = (
		TEAM_CHAT_EXPANDED_BG if expanded else TEAM_CHAT_COMPACT_BG
	)
	_team_chat_background.size = target_size
	_team_chat_history.position = Vector2(9.0, 8.0)
	_team_chat_history.size = Vector2(519.0, target_size.y - 47.0)
	_team_chat_scroll_up.position = Vector2(528.0, 7.0)
	_team_chat_scroll_up.size = Vector2(20.0, 20.0)
	_team_chat_scroll_down.position = Vector2(
		528.0,
		_team_chat_history.position.y + _team_chat_history.size.y - 20.0
	)
	_team_chat_scroll_down.size = Vector2(20.0, 20.0)
	var track_top := 27.0
	var track_bottom := _team_chat_scroll_down.position.y
	_team_chat_scroll_track.position = Vector2(528.0, track_top)
	_team_chat_scroll_track.size = Vector2(
		20.0,
		maxf(0.0, track_bottom - track_top)
	)
	_team_chat_scroll_track.visible = (
		expanded and _team_chat_scroll_track.size.y > 0.0
	)
	_team_chat_input.position = Vector2(9.0, target_size.y - 30.0)
	_team_chat_input.size = Vector2(465.0, 23.0)
	_team_chat_send.position = Vector2(478.0, target_size.y - 31.0)
	_team_chat_send.size = Vector2(71.0, 29.0)
	_team_chat_scroll_offset = mini(
		_team_chat_scroll_offset,
		maxi(0, _team_chat_messages.size() - _team_chat_visible_count())
	)
	_render_team_chat()


func _on_team_chat_mouse_entered() -> void:
	_team_chat_hovered = true
	_set_team_chat_expanded(true)


func _on_team_chat_mouse_exited() -> void:
	_team_chat_hovered = false
	if not _team_chat_pinned_open:
		_set_team_chat_expanded(false)


func _update_team_chat_hover(mouse_position: Vector2) -> void:
	if _team_chat == null or not _team_chat.visible:
		return
	var hovered := _team_chat.get_global_rect().has_point(mouse_position)
	if hovered == _team_chat_hovered:
		return
	_team_chat_hovered = hovered
	if hovered:
		_set_team_chat_expanded(true)
	elif not _team_chat_pinned_open:
		_set_team_chat_expanded(false)


func _handle_team_chat_pointer_input(event: InputEvent) -> bool:
	if (
		not visible
		or _phase != "selecting"
		or _team_chat == null
		or event is not InputEventMouseButton
		or not event.pressed
	):
		return false
	if not _team_chat.get_global_rect().has_point(event.position):
		return false
	_team_chat_hovered = true
	if not _team_chat_expanded:
		_set_team_chat_expanded(true)
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_scroll_team_chat_up()
		return true
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_scroll_team_chat_down()
		return true
	if event.button_index != MOUSE_BUTTON_LEFT:
		return false
	if _team_chat_input.get_global_rect().has_point(event.position):
		_team_chat_pinned_open = true
		_team_chat_input.grab_focus()
		return false
	if _team_chat_send.get_global_rect().has_point(event.position):
		_send_team_chat()
		return true
	if _team_chat_scroll_up.get_global_rect().has_point(event.position):
		_scroll_team_chat_up()
		return true
	if _team_chat_scroll_down.get_global_rect().has_point(event.position):
		_scroll_team_chat_down()
		return true
	return false


func _on_team_chat_input_focus_entered() -> void:
	_team_chat_pinned_open = true
	_set_team_chat_expanded(true)


func _on_team_chat_input_changed(_new_text: String) -> void:
	if _team_chat_input.has_focus():
		_team_chat_pinned_open = true
		_set_team_chat_expanded(true)


func _on_team_chat_input_submitted(_text: String) -> void:
	_send_team_chat()


func _on_team_chat_history_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_scroll_team_chat_up()
		_team_chat_history.accept_event()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_scroll_team_chat_down()
		_team_chat_history.accept_event()


func _scroll_team_chat_up() -> void:
	_team_chat_scroll_offset = mini(
		_team_chat_scroll_offset + 1,
		maxi(0, _team_chat_messages.size() - _team_chat_visible_count())
	)
	_render_team_chat()


func _scroll_team_chat_down() -> void:
	_team_chat_scroll_offset = maxi(0, _team_chat_scroll_offset - 1)
	_render_team_chat()


func _team_chat_visible_count() -> int:
	return 3 if _team_chat_expanded else 1


func _reset_team_chat() -> void:
	_team_chat_messages.clear()
	_team_chat_last_id = 0
	_team_chat_scroll_offset = 0
	_team_chat_poll_elapsed = TEAM_CHAT_POLL_INTERVAL
	_team_chat_poll_in_flight = false
	_team_chat_send_in_flight = false
	_team_chat_hovered = false
	_team_chat_pinned_open = false
	_team_chat_input.release_focus()
	_team_chat_input.editable = true
	_team_chat_input.clear()
	_team_chat_input.placeholder_text = "Nhập nội dung chat"
	_set_team_chat_expanded(false)


func _poll_team_chat() -> void:
	if (
		_local_preview
		or _phase != "selecting"
		or _team_chat_poll_in_flight
	):
		return
	_team_chat_poll_in_flight = true
	var result: Dictionary = await GameSession.fetch_game_match_team_chat(
		_team_chat_last_id,
		50
	)
	_team_chat_poll_in_flight = false
	if not result.get("ok", false):
		_show_team_chat_error(result)
		return
	var received: Variant = result.get("messages", [])
	if received is Array:
		_append_team_chat_messages(received)


func _send_team_chat() -> void:
	if _team_chat_send_in_flight or _phase != "selecting":
		return
	var message := _team_chat_input.text.strip_edges()
	if message.is_empty():
		_team_chat_input.grab_focus()
		return
	_team_chat_pinned_open = true
	_set_team_chat_expanded(true)
	if _local_preview:
		_append_team_chat_messages([{
			"id": _team_chat_last_id + 1,
			"sender_name": _team_chat_own_name(),
			"body": message,
		}])
		_team_chat_input.clear()
		_team_chat_scroll_offset = 0
		_render_team_chat()
		_team_chat_input.grab_focus()
		return
	_team_chat_send_in_flight = true
	_team_chat_input.editable = false
	var result: Dictionary = await GameSession.send_game_match_team_chat(message)
	_team_chat_send_in_flight = false
	_team_chat_input.editable = true
	if not result.get("ok", false):
		_show_team_chat_error(result)
		_team_chat_input.grab_focus()
		return
	_team_chat_input.clear()
	var sent: Variant = result.get("message", {})
	if sent is Dictionary:
		_append_team_chat_messages([sent])
	_team_chat_scroll_offset = 0
	_render_team_chat()
	_team_chat_input.grab_focus()


func _append_team_chat_messages(received: Array) -> void:
	var added_count := 0
	for value: Variant in received:
		if value is not Dictionary:
			continue
		var message: Dictionary = value
		var message_id := int(String(message.get("id", "0")))
		if message_id <= _team_chat_last_id:
			continue
		_team_chat_last_id = message_id
		_team_chat_messages.append(message.duplicate(true))
		added_count += 1
	if added_count == 0:
		_render_team_chat()
		return
	while _team_chat_messages.size() > TEAM_CHAT_MAX_LOCAL_MESSAGES:
		_team_chat_messages.pop_front()
	if _team_chat_scroll_offset > 0:
		_team_chat_scroll_offset = mini(
			_team_chat_scroll_offset + added_count,
			maxi(0, _team_chat_messages.size() - _team_chat_visible_count())
		)
	_render_team_chat()


func _render_team_chat() -> void:
	if _team_chat_history == null:
		return
	if _team_chat_messages.is_empty():
		_team_chat_history.text = (
			"[color=#d6e9ee][Phe ta][/color] "
			+ "Chọn Tank phù hợp với đội hình."
		)
		_update_team_chat_scroll_buttons()
		return
	var visible_count := _team_chat_visible_count()
	var end_index := maxi(0, _team_chat_messages.size() - _team_chat_scroll_offset)
	var start_index := maxi(0, end_index - visible_count)
	var lines := PackedStringArray()
	var own_name := _team_chat_own_name()
	for index in range(start_index, end_index):
		var message := _team_chat_messages[index]
		var sender := String(message.get("sender_name", "Người chơi"))
		var body := String(message.get("body", ""))
		var sender_color := "#ffd84a" if sender == own_name else "#62ff75"
		lines.append(
			"[color=#d6e9ee][Phe ta][/color] "
			+ "[color=%s]%s[/color]: %s"
			% [
				sender_color,
				_escape_team_chat_bbcode(sender),
				_escape_team_chat_bbcode(body),
			]
		)
	_team_chat_history.text = "\n".join(lines)
	_update_team_chat_scroll_buttons()


func _update_team_chat_scroll_buttons() -> void:
	var maximum := maxi(
		0,
		_team_chat_messages.size() - _team_chat_visible_count()
	)
	_team_chat_scroll_up.disabled = _team_chat_scroll_offset >= maximum
	_team_chat_scroll_down.disabled = _team_chat_scroll_offset <= 0


func _show_team_chat_error(result: Dictionary) -> void:
	var error_value: Variant = result.get("error", {})
	var message := (
		String(error_value.get("message", "Không thể sử dụng chat đội lúc này."))
		if error_value is Dictionary
		else "Không thể sử dụng chat đội lúc này."
	)
	_team_chat_input.placeholder_text = message


func _team_chat_own_name() -> String:
	var own_name := String(GameSession.profile.get("display_name", ""))
	if own_name.is_empty():
		own_name = String(GameSession.lobby_data.get("display_name", ""))
	if own_name.is_empty():
		own_name = "Bạn"
	return own_name


func _escape_team_chat_bbcode(value: String) -> String:
	return value.replace("[", "[lb]").replace("]", "[rb]")


func _build_match_skin_overlay() -> void:
	# The gallery is embedded in the existing large Tank-selection rectangle.
	_match_skin_overlay = $TankSelect/Panel/Center/SkinGallery
	_match_skin_panel = _match_skin_overlay
	_match_skin_viewport = $TankSelect/Panel/Center/SkinGallery/SkinViewport
	_match_skin_content = (
		$TankSelect/Panel/Center/SkinGallery/SkinViewport/SkinContent
	)
	_match_skin_empty_label = (
		$TankSelect/Panel/Center/SkinGallery/SkinViewport/SkinContent/EmptyLabel
	)
	_match_skin_scrollbar = $TankSelect/Panel/Center/SkinGallery/SkinScroll
	_match_skin_scroll_thumb = (
		$TankSelect/Panel/Center/SkinGallery/SkinScroll/Thumb
	)
	_match_skin_viewport.gui_input.connect(_on_match_skin_viewport_gui_input)
	(
		$TankSelect/Panel/Center/SkinGallery/SkinScroll/Interaction
		as Control
	).gui_input.connect(_on_match_skin_scroll_gui_input)
	var scene_tab_data := [
		["all", MATCH_SKIN_TAB_ALL, MATCH_SKIN_TAB_ALL_SELECTED, "All"],
		["A", MATCH_SKIN_TAB_A, MATCH_SKIN_TAB_A_SELECTED, "A"],
		["S", MATCH_SKIN_TAB_S, MATCH_SKIN_TAB_S_SELECTED, "S"],
		["SS", MATCH_SKIN_TAB_SS, MATCH_SKIN_TAB_SS_SELECTED, "SS"],
		["SSS", MATCH_SKIN_TAB_SSS, MATCH_SKIN_TAB_SSS_SELECTED, "SSS"],
	]
	for scene_entry: Array in scene_tab_data:
		var scene_quality_key := String(scene_entry[0])
		var scene_tab_button := (
			$TankSelect/Panel/Center/SkinGallery/Tabs.get_node(
				String(scene_entry[3])
			) as TextureButton
		)
		scene_tab_button.pressed.connect(
			_on_match_skin_quality_pressed.bind(scene_quality_key)
		)
		_enable_button_hover(scene_tab_button)
		_match_skin_quality_buttons[scene_quality_key] = {
			"button": scene_tab_button,
			"normal": scene_entry[1],
			"selected": scene_entry[2],
		}
	var scene_left_button := (
		$TankSelect/Panel/Center/SkinGallery/SkinScroll/Left as TextureButton
	)
	var scene_right_button := (
		$TankSelect/Panel/Center/SkinGallery/SkinScroll/Right as TextureButton
	)
	scene_left_button.pressed.connect(_scroll_match_skin_by.bind(-120.0))
	scene_right_button.pressed.connect(_scroll_match_skin_by.bind(120.0))
	_enable_button_hover(scene_left_button)
	_enable_button_hover(scene_right_button)
	_match_skin_overlay.visible = false
	_match_skin_empty_label.text = "Không có Skin thuộc bậc này."
	_match_skin_empty_label.visible = false


func _open_match_skin_overlay() -> void:
	if _selected_tank_key.is_empty():
		_select_default_tank()
	if not _match_skin_overlay.visible:
		_match_skin_quality = "all"
		_match_skin_scroll_value = 0.0
	_tank_scroll.visible = false
	_tank_scrollbar.visible = false
	_match_skin_overlay.visible = true
	_refresh_match_skin_overlay()


func _close_match_skin_overlay() -> void:
	if _match_skin_overlay != null:
		_match_skin_overlay.visible = false
	if _tank_scroll != null:
		_tank_scroll.visible = true
	if _tank_scrollbar != null:
		_tank_scrollbar.visible = true


func _on_match_skin_quality_pressed(quality_key: String) -> void:
	_match_skin_quality = quality_key
	_match_skin_scroll_value = 0.0
	_refresh_match_skin_overlay()


func _refresh_match_skin_overlay() -> void:
	if _match_skin_overlay == null or not _match_skin_overlay.visible:
		return
	var tank := _owned_tank_by_key(_selected_tank_key)
	var render_signature := _match_skin_signature(tank)
	if render_signature == _match_skin_render_signature:
		_refresh_match_skin_quality_buttons()
		return
	_match_skin_render_signature = render_signature
	_match_skin_use_buttons.clear()
	for child in _match_skin_content.get_children():
		if child != _match_skin_empty_label:
			child.free()
	var visible_count := 0
	if not tank.is_empty():
		var skins: Variant = tank.get("skins", [])
		if skins is Array:
			for skin_value: Variant in skins:
				if skin_value is not Dictionary:
					continue
				var skin: Dictionary = skin_value
				if skin.get("owned", false) != true:
					continue
				var skin_key := String(skin.get("skin_key", "")).strip_edges()
				var quality := TankSkinCatalog.skin_quality(tank, skin_key)
				if (
					skin_key.is_empty()
					or (_match_skin_quality != "all" and quality != _match_skin_quality)
				):
					continue
				_add_match_skin_card(tank, skin, visible_count)
				visible_count += 1
	_match_skin_empty_label.visible = visible_count == 0
	_match_skin_content.size = Vector2(
		maxf(_match_skin_viewport.size.x, 6.0 + visible_count * 225.0),
		_match_skin_viewport.size.y
	)
	_match_skin_scroll_max = maxf(
		0.0,
		_match_skin_content.size.x - _match_skin_viewport.size.x
	)
	_match_skin_scrollbar.visible = _match_skin_scroll_max > 0.0
	_set_match_skin_scroll_value(_match_skin_scroll_value)
	_refresh_match_skin_quality_buttons()


func _add_match_skin_card(
	tank: Dictionary,
	skin: Dictionary,
	index: int
) -> void:
	var skin_key := String(skin.get("skin_key", "")).strip_edges()
	var card := Control.new()
	card.position = Vector2(6.0 + index * 225.0, 0.0)
	card.size = Vector2(215.0, 245.0)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	_match_skin_content.add_child(card)
	var title := _label(Vector2.ZERO, Vector2(215.0, 24.0), 13)
	title.text = String(skin.get("display_name", skin.get("skin_name", skin_key)))
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.1))
	card.add_child(title)
	var booth := TextureRect.new()
	booth.texture = MATCH_SKIN_BOOTH
	booth.position = Vector2(-11.0, 112.0)
	booth.size = Vector2(236.0, 127.0)
	booth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(booth)
	var preview := TextureRect.new()
	preview.texture = TankSkinCatalog.texture_for(tank, _selected_tank_key, skin_key)
	preview.position = Vector2(7.5, 22.0)
	preview.size = Vector2(200.0, 200.0)
	preview.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(preview)
	_attach_tank_animation(card, preview, skin_key)
	var quality := TankSkinCatalog.skin_quality(tank, skin_key)
	var rating := Control.new()
	rating.position = Vector2(72.0, 190.0)
	rating.size = Vector2(80.0, 25.0)
	rating.visible = not quality.is_empty()
	rating.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(rating)
	var rating_title := TextureRect.new()
	rating_title.texture = MATCH_SKIN_RATING_TITLE
	rating_title.size = Vector2(47.0, 25.0)
	rating_title.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	rating_title.stretch_mode = TextureRect.STRETCH_KEEP
	rating_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rating.add_child(rating_title)
	var rating_grade_texture := _match_skin_rating_texture(quality)
	if rating_grade_texture != null:
		var rating_grade := TextureRect.new()
		rating_grade.texture = rating_grade_texture
		rating_grade.position = Vector2(52.0, 1.0)
		rating_grade.size = rating_grade_texture.get_size()
		rating_grade.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		rating_grade.stretch_mode = TextureRect.STRETCH_KEEP
		rating_grade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rating.add_child(rating_grade)
	var equipped := TankSkinCatalog.equipped_skin_key(tank) == skin_key
	var equipped_label := TextureRect.new()
	equipped_label.texture = MATCH_SKIN_EQUIPPED
	equipped_label.position = Vector2(75.0, 223.0)
	equipped_label.size = Vector2(65.0, 19.0)
	equipped_label.visible = equipped
	equipped_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(equipped_label)
	var use_button := TextureButton.new()
	use_button.texture_normal = MATCH_SKIN_USE_BG
	use_button.texture_hover = MATCH_SKIN_USE_BG
	use_button.position = Vector2(74.5, 218.0)
	use_button.size = Vector2(66.0, 29.0)
	use_button.visible = not equipped
	use_button.set_meta("skin_key", skin_key)
	use_button.pressed.connect(_on_match_skin_use_pressed.bind(skin_key))
	_enable_button_hover(use_button)
	card.add_child(use_button)
	_match_skin_use_buttons.append(use_button)
	var use_text := TextureRect.new()
	use_text.texture = MATCH_SKIN_USE_TEXT
	use_text.position = Vector2(15.5, 5.0)
	use_text.size = Vector2(35.0, 19.0)
	use_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	use_button.add_child(use_text)


func _match_skin_signature(tank: Dictionary) -> String:
	var parts: Array[String] = [
		_selected_tank_key,
		_match_skin_quality,
		TankSkinCatalog.equipped_skin_key(tank),
	]
	var skins: Variant = tank.get("skins", [])
	if skins is Array:
		for skin_value: Variant in skins:
			if skin_value is not Dictionary:
				continue
			var skin: Dictionary = skin_value
			if skin.get("owned", false) != true:
				continue
			parts.append(
				"%s:%s:%s:%s" % [
					String(skin.get("skin_key", "")),
					String(skin.get("quality_key", "")),
					String(skin.get("display_name", skin.get("skin_name", ""))),
					String(skin.get("preview_asset_key", "")),
				]
			)
	return "|".join(parts)


func _match_skin_rating_texture(quality: String) -> Texture2D:
	match quality:
		"A":
			return MATCH_SKIN_RATING_A
		"S":
			return MATCH_SKIN_RATING_S
		"SS":
			return MATCH_SKIN_RATING_SS
		"SSS":
			return MATCH_SKIN_RATING_SSS
	return null


func _on_match_skin_use_pressed(skin_key: String) -> void:
	_on_skin_pressed(skin_key)


func _refresh_match_skin_quality_buttons() -> void:
	for quality_key: String in _match_skin_quality_buttons:
		var data: Dictionary = _match_skin_quality_buttons[quality_key]
		var button := data.get("button") as TextureButton
		var icon := button.get_node("Icon") as TextureRect
		var selected := quality_key == _match_skin_quality
		button.texture_normal = (
			MATCH_SKIN_TAB_BG_SELECTED if selected else MATCH_SKIN_TAB_BG
		)
		icon.texture = data.get("selected" if selected else "normal") as Texture2D


func _set_match_skin_scroll_value(value: float) -> void:
	_match_skin_scroll_value = clampf(value, 0.0, _match_skin_scroll_max)
	_match_skin_content.position.x = -_match_skin_scroll_value
	if _match_skin_scroll_thumb == null or _match_skin_scrollbar == null:
		return
	var arrow_width := 20.0
	var track_width := _match_skin_scrollbar.size.x - arrow_width * 2.0
	var content_width := maxf(
		_match_skin_content.size.x,
		_match_skin_viewport.size.x
	)
	var thumb_width := clampf(
		track_width * _match_skin_viewport.size.x / content_width,
		40.0,
		track_width
	)
	var travel := maxf(0.0, track_width - thumb_width)
	var ratio := (
		_match_skin_scroll_value / _match_skin_scroll_max
		if _match_skin_scroll_max > 0.0
		else 0.0
	)
	_match_skin_scroll_thumb.position = Vector2(
		arrow_width + travel * ratio,
		19.0
	)
	# Ảnh nguồn là thanh dọc 19×505; node xoay -90° như TankPanel.
	_match_skin_scroll_thumb.size = Vector2(19.0, thumb_width)


func _set_match_skin_scroll_from_thumb_position(thumb_x: float) -> void:
	if _match_skin_scrollbar == null or _match_skin_scroll_thumb == null:
		return
	var arrow_width := 20.0
	var track_width := _match_skin_scrollbar.size.x - arrow_width * 2.0
	var thumb_width := _match_skin_scroll_thumb.size.y
	var travel := maxf(0.0, track_width - thumb_width)
	if travel <= 0.0 or _match_skin_scroll_max <= 0.0:
		_set_match_skin_scroll_value(0.0)
		return
	var local_x := clampf(thumb_x - arrow_width, 0.0, travel)
	_set_match_skin_scroll_value(local_x / travel * _match_skin_scroll_max)


func _on_match_skin_scroll_gui_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not event.pressed:
		_match_skin_scroll_dragging = false
		return
	_begin_match_skin_scroll_drag(event.position.x + 20.0)
	accept_event()


func _begin_match_skin_scroll_drag(local_x: float) -> void:
	var thumb_left := _match_skin_scroll_thumb.position.x
	var thumb_right := thumb_left + _match_skin_scroll_thumb.size.y
	if local_x >= thumb_left and local_x <= thumb_right:
		_match_skin_scroll_drag_offset = local_x - thumb_left
	else:
		_match_skin_scroll_drag_offset = _match_skin_scroll_thumb.size.y * 0.5
		_set_match_skin_scroll_from_thumb_position(
			local_x - _match_skin_scroll_drag_offset
		)
	_match_skin_scroll_dragging = true


func _scroll_match_skin_by(amount: float) -> void:
	_set_match_skin_scroll_value(_match_skin_scroll_value + amount)


func _on_match_skin_viewport_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_match_skin_by(-120.0)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_match_skin_by(120.0)
			accept_event()


func _start_standalone_offline_preview() -> void:
	var profile: Dictionary = GameSession.profile.duplicate(true)
	if profile.is_empty():
		profile = {
			"display_name": "Beenn",
			"gender": "male",
			"level": 1,
		}
	var lobby: Dictionary = GameSession.lobby_data
	profile["tank_key"] = String(
		lobby.get("tank_key", "gangtiexia03")
	)
	profile["tank_name"] = String(lobby.get("tank_name", "Iron Man"))
	profile["tank_level"] = int(lobby.get("tank_level", 1))
	profile["tank_role_key"] = String(lobby.get("tank_role_key", "dps"))
	profile["equipped_skin_key"] = String(
		lobby.get("equipped_skin_key", "gangtiexia03_default")
	)
	if String(profile["tank_key"]) == "gangtiexia03":
		profile["skins"] = _preview_ironman_skins(
			String(profile["equipped_skin_key"])
		)
	profile["slot"] = 1
	profile["is_captain"] = true
	start_local_test({
		"room_code": "1001",
		"room_name": "PvP Bot Test - sandbox",
		"map_key": "random",
		"map_name": "Bản đồ ngẫu nhiên",
		"map_thumbnail_asset_path": (
			"res://assets/battle/maps/Maya Tiên tri(Tính điểm)/stage1_small.jpg"
		),
		"members": [profile],
	})


func _preview_ironman_skins(equipped_skin_key: String) -> Array:
	var skins: Array = []
	for entry: Array in IRONMAN_PREVIEW_SKINS:
		var skin_key := String(entry[0])
		skins.append({
			"skin_key": skin_key,
			"display_name": String(entry[1]),
			"quality_key": String(entry[2]),
			"is_default": skin_key == "gangtiexia03_default",
			"is_equipped": skin_key == equipped_skin_key,
			"owned": true,
		})
	return skins


func _add_local_preview_skin_data(member: Dictionary) -> void:
	var tank_key := String(member.get("tank_key", "gangtiexia03"))
	var equipped_skin_key := String(
		member.get("equipped_skin_key", "gangtiexia03_default")
	)
	var owned := TankSkinCatalog.find_owned_tank(
		GameSession.lobby_data,
		tank_key
	)
	if equipped_skin_key.is_empty() and not owned.is_empty():
		equipped_skin_key = TankSkinCatalog.equipped_skin_key(owned)
	if tank_key == "gangtiexia03":
		member["skins"] = _preview_ironman_skins(equipped_skin_key)
		member["skin_frame_tier"] = "orange"
	elif not owned.is_empty():
		member["skins"] = owned.get("skins", []).duplicate(true)
		member["skin_frame_tier"] = TankSkinCatalog.skin_frame_tier(owned)
	member["equipped_skin_key"] = equipped_skin_key


func apply_match(match_value: Variant) -> void:
	if match_value is not Dictionary or match_value.is_empty():
		# Room polling may briefly return a snapshot without `match` while the
		# authoritative match endpoint is moving from selecting to loading.
		# Never tear down an active flow from that transient room snapshot.
		return
	_local_preview = false
	_apply_match_data(match_value)


func start_local_test(room: Dictionary) -> void:
	_local_preview = true
	_local_elapsed = 0.0
	_local_preparation_elapsed = 0.0
	_local_preparation_started = false
	_request_in_flight = false
	var members_value: Variant = room.get("members", [])
	var members: Array = members_value if members_value is Array else []
	var participants: Array = []
	for index in members.size():
		var member_value: Variant = members[index]
		if member_value is not Dictionary or index >= 5:
			continue
		var member: Dictionary = member_value.duplicate(true)
		_add_local_preview_skin_data(member)
		member["team_no"] = 1
		member["slot_no"] = index + 1
		member["is_bot"] = false
		member["confirmed"] = false
		member["deployed"] = false
		member["load_progress"] = 0
		member["load_ready"] = false
		participants.append(member)
	for index in 5:
		participants.append({
			"team_no": 2,
			"slot_no": index + 1,
			"is_bot": true,
			"display_name": "BOT %d" % (index + 1),
			"gender": "female" if index % 2 == 1 else "male",
			"avatar_key": (
				"default_female" if index % 2 == 1 else "default_male"
			),
			# TankUpTemplate 10000001, level 1: explicit XML values so
			# local-test bots are reliable damage targets rather than fallbacks.
			"tank_level": 1,
			"hit_points": 2325,
			"basic_attack_damage": 238.0,
			"penetration": 30.0,
			"physical_armor": 150.0,
			"energy_shield": 150.0,
			"move_speed": 170.0,
			"fire_rate": 66.6667,
			"attack_range": 480.0,
			"critical_chance_percent": 5.0,
			"critical_damage_percent": 150.0,
			"damage_type": "physical",
			"confirmed": false,
			"deployed": false,
			"load_progress": 0,
			"load_ready": false,
		})
	_apply_match_data({
		"id": "local-test",
		"phase": "confirming",
		"is_test": true,
		"map_key": room.get("map_key", "random"),
		"map_name": room.get("map_name", "Bản đồ ngẫu nhiên"),
		"map_thumbnail_asset_path": room.get(
			"map_thumbnail_asset_path",
			"res://assets/battle/maps/Maya Tiên tri(Tính điểm)/stage1_small.jpg"
		),
		"confirmation_seconds_remaining": 30,
		"selection_intro_seconds_remaining": 3,
		"viewer_team_no": 1,
		"participants": participants,
	})


func hide_flow() -> void:
	visible = false
	if _match_skin_overlay != null:
		_match_skin_overlay.visible = false
	if _team_chat_input != null:
		_team_chat_input.release_focus()
		_team_chat_pinned_open = false
		_team_chat_hovered = false
		_set_team_chat_expanded(false)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_phase = ""
	_match_data.clear()
	_team_column_signatures.clear()
	_reported_load_steps.clear()
	_reset_battle_map()
	_transition_finished = false
	_battle_emitted = false
	if _transition_player != null:
		_transition_player.stop()


func is_open() -> bool:
	return visible


func _process(delta: float) -> void:
	if not visible:
		return
	if _phase == "selecting":
		_selection_display_elapsed += delta
		_sync_tank_scrollbar()
		_update_team_chat_hover(get_viewport().get_mouse_position())
		_team_chat_poll_elapsed += delta
		if (
			not _local_preview
			and _team_chat_poll_elapsed >= TEAM_CHAT_POLL_INTERVAL
			and not _team_chat_poll_in_flight
		):
			_team_chat_poll_elapsed = 0.0
			_poll_team_chat()
	if _loading_chat_is_active():
		_loading_chat_poll_elapsed += delta
		if (
			not _local_preview
			and _loading_chat_poll_elapsed >= LOADING_CHAT_POLL_INTERVAL
			and not _loading_chat_poll_in_flight
		):
			_loading_chat_poll_elapsed = 0.0
			_poll_loading_chat()
		_restore_loading_chat_bubbles()
	if _local_preview:
		_advance_local_preview(delta)
		return
	_poll_elapsed += delta
	if (
		_poll_elapsed >= POLL_INTERVAL
		and not _request_in_flight
		and not _poll_in_flight
	):
		_poll_elapsed = 0.0
		_poll_match()


func _input(event: InputEvent) -> void:
	if _match_skin_scroll_dragging and _match_skin_scrollbar != null:
		if event is InputEventMouseMotion:
			_set_match_skin_scroll_from_thumb_position(
				_match_skin_scrollbar.get_local_mouse_position().x
				- _match_skin_scroll_drag_offset
			)
			get_viewport().set_input_as_handled()
			return
		if (
			event is InputEventMouseButton
			and event.button_index == MOUSE_BUTTON_LEFT
			and not event.pressed
		):
			_match_skin_scroll_dragging = false
			get_viewport().set_input_as_handled()
			return
	if _handle_match_skin_input(event):
		get_viewport().set_input_as_handled()
		return
	if _handle_team_chat_pointer_input(event):
		get_viewport().set_input_as_handled()
		return
	if (
		visible
		and _phase == "selecting"
		and _team_chat_expanded
		and event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and not _team_chat.get_global_rect().has_point(event.position)
	):
		_team_chat_pinned_open = false
		_team_chat_hovered = false
		_team_chat_input.release_focus()
		_set_team_chat_expanded(false)
	if (
		visible
		and _phase == "confirming"
		and event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
		and not _confirm_button.disabled
		and _confirm_button.get_global_rect().has_point(event.position)
	):
		_on_confirm_pressed()
		get_viewport().set_input_as_handled()
		return
	if (
		visible
		and _phase == "selecting"
		and _tank_intro.visible
		and event is InputEventMouseButton
		and event.pressed
		and _tank_intro.get_global_rect().has_point(event.position)
	):
		_intro_dismissed = true
		_tank_intro.visible = false
		# Keep processing this same click. The intro banner overlaps the
		# controls visually, but it must not swallow a click on Skin or Deploy.
	if (
		visible
		and _phase == "selecting"
		and event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		for role_key: String in _tank_role_buttons:
			var role_button := _tank_role_buttons[role_key] as TextureButton
			if (
				not role_button.disabled
				and role_button.get_global_rect().has_point(event.position)
			):
				_on_tank_role_pressed(role_key)
				get_viewport().set_input_as_handled()
				return
		if (
			not _deploy_button.disabled
			and _deploy_button.get_global_rect().has_point(event.position)
		):
			_on_deploy_pressed()
			get_viewport().set_input_as_handled()
			return


func _handle_match_skin_input(event: InputEvent) -> bool:
	if (
		not visible
		or _phase != "selecting"
		or _match_skin_overlay == null
		or not _match_skin_overlay.visible
		or event is not InputEventMouseButton
		or not event.pressed
	):
		return false
	if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		if not _match_skin_overlay.get_global_rect().has_point(event.position):
			return false
		_scroll_match_skin_by(
			-120.0
			if event.button_index == MOUSE_BUTTON_WHEEL_UP
			else 120.0
		)
		return true
	if event.button_index != MOUSE_BUTTON_LEFT:
		return false
	for quality_key: String in _match_skin_quality_buttons:
		var quality_data: Dictionary = _match_skin_quality_buttons[quality_key]
		var quality_button := quality_data.get("button") as TextureButton
		if (
			quality_button != null
			and not quality_button.disabled
			and quality_button.get_global_rect().has_point(event.position)
		):
			_on_match_skin_quality_pressed(quality_key)
			return true
	if _match_skin_viewport.get_global_rect().has_point(event.position):
		for use_button: TextureButton in _match_skin_use_buttons:
			if (
				is_instance_valid(use_button)
				and use_button.visible
				and not use_button.disabled
				and use_button.get_global_rect().has_point(event.position)
			):
				_on_match_skin_use_pressed(
					String(use_button.get_meta("skin_key", ""))
				)
				return true
	var left_button := _match_skin_scrollbar.get_node("Left") as TextureButton
	if left_button.get_global_rect().has_point(event.position):
		_scroll_match_skin_by(-120.0)
		return true
	var right_button := _match_skin_scrollbar.get_node("Right") as TextureButton
	if right_button.get_global_rect().has_point(event.position):
		_scroll_match_skin_by(120.0)
		return true
	var interaction := _match_skin_scrollbar.get_node("Interaction") as Control
	if interaction.get_global_rect().has_point(event.position):
		_begin_match_skin_scroll_drag(
			_match_skin_scrollbar.get_local_mouse_position().x
		)
		return true
	return false


func _apply_match_data(match_value: Dictionary) -> void:
	_match_data = match_value.duplicate(true)
	var next_phase := String(_match_data.get("phase", ""))
	if next_phase == "cancelled":
		var confirmation_was_open := _phase == "confirming"
		hide_flow()
		if confirmation_was_open:
			confirmation_expired.emit()
		return
	visible = not next_phase.is_empty()
	mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if visible
		else Control.MOUSE_FILTER_IGNORE
	)
	if next_phase != _phase:
		_phase = next_phase
		_on_phase_changed()
	match _phase:
		"confirming":
			_refresh_match_found()
		"selecting":
			_refresh_tank_select()
		"loading":
			_refresh_battle_loading()
			_report_real_loading_progress()
		"transition":
			_refresh_battle_loading()
			_start_transition()
		"active":
			_complete_flow()


func _on_phase_changed() -> void:
	if _match_skin_overlay != null:
		_match_skin_overlay.visible = false
	if _phase != "selecting" and _team_chat_input != null:
		_team_chat_input.release_focus()
		_team_chat_pinned_open = false
		_team_chat_hovered = false
		_set_team_chat_expanded(false)
	_match_found.visible = _phase == "confirming"
	_tank_select.visible = _phase == "selecting"
	_battle_loading.visible = _phase in ["loading", "transition"]
	if _phase == "loading" and is_instance_valid(_loading_clock):
		_loading_clock.play_range(1, _loading_clock.get_frame_count())
	_transition_layer.visible = _phase in ["transition", "active"]
	if _phase not in ["loading", "transition", "active"]:
		_reset_battle_map()
	if _phase == "selecting":
		_intro_dismissed = false
		_selected_tank_key = ""
		_selected_tank_role = "all"
		_selected_skin_key = ""
		_selection_display_elapsed = 0.0
		_team_column_signatures.clear()
		_reset_team_chat()
		_refresh_tank_role_buttons()
		_select_default_tank()
	if _phase == "loading":
		_reported_load_steps.clear()
		_transition_finished = false
		_reset_loading_chat()
		_prepare_battle_map()
	if _phase not in ["transition", "active"] and _transition_player != null:
		_transition_player.stop()


func _build_match_found() -> void:
	_match_found = Control.new()
	_match_found.name = "MatchFound"
	_match_found.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_match_found)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.0, 0.03, 0.08, 0.4)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_match_found.add_child(shade)

	var window := TextureRect.new()
	window.name = "Window"
	window.texture = MATCH_FOUND_BG
	window.position = DESIGN_SIZE * 0.5 - Vector2(233.5, 172.5)
	window.size = Vector2(467.0, 345.0)
	window.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	window.stretch_mode = TextureRect.STRETCH_KEEP
	_match_found.add_child(window)

	_match_counter = _label(Vector2(34.0, 64.0), Vector2(180.0, 24.0), 16)
	_match_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	window.add_child(_match_counter)
	_match_countdown = _label(Vector2(250.0, 64.0), Vector2(180.0, 24.0), 16)
	_match_countdown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	window.add_child(_match_countdown)

	for team_index in 2:
		for slot_index in 5:
			var flat_index := team_index * 5 + slot_index
			var slot := Control.new()
			slot.position = Vector2(
				48.0 + slot_index * 77.0,
				105.0 + team_index * 76.0
			)
			slot.size = Vector2(62.0, 62.0)
			window.add_child(slot)

			var frame := TextureRect.new()
			frame.texture = AVATAR_FRAME
			frame.size = Vector2(62.0, 62.0)
			frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			frame.stretch_mode = TextureRect.STRETCH_KEEP
			frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(frame)

			var avatar := TextureRect.new()
			avatar.position = Vector2(7.0, 7.0)
			avatar.size = Vector2(48.0, 48.0)
			avatar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			avatar.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(avatar)
			_avatar_images.append(avatar)

			var glow := TextureRect.new()
			glow.texture = AVATAR_CONFIRMED
			glow.position = Vector2(-6.0, -6.0)
			glow.size = Vector2(74.0, 74.0)
			glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			glow.stretch_mode = TextureRect.STRETCH_KEEP
			glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(glow)
			_avatar_glows.append(glow)

			var question := _label(Vector2.ZERO, Vector2(62.0, 62.0), 28)
			question.text = "?"
			question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			slot.add_child(question)
			_avatar_questions.append(question)

	_confirm_effect = SwfTimelinePlayer.new()
	_confirm_effect.name = "OriginalConfirmEffect"
	_confirm_effect.timeline_path = CONFIRM_EFFECT_TIMELINE
	_confirm_effect.position = Vector2(233.0, 286.5)
	window.add_child(_confirm_effect)
	_confirm_button = TextureButton.new()
	_confirm_button.position = Vector2(179.0, 266.0)
	_confirm_button.size = Vector2(108.0, 41.0)
	_confirm_button.texture_normal = CONFIRM_BUTTON
	_confirm_button.ignore_texture_size = true
	_confirm_button.stretch_mode = TextureButton.STRETCH_KEEP
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_enable_button_hover(_confirm_button)
	window.add_child(_confirm_button)
	_match_found.visible = false


func _refresh_match_found() -> void:
	var participants := _participants_by_slots()
	var confirmed_count := 0
	var required_count := 0
	for index in 10:
		var participant: Dictionary = participants[index]
		var has_participant := not participant.is_empty()
		var confirmed := bool(participant.get("confirmed", false))
		if has_participant:
			required_count += 1
			if confirmed:
				confirmed_count += 1
		_avatar_images[index].texture = _avatar_texture(participant)
		_avatar_images[index].visible = true
		_avatar_images[index].modulate = (
			Color.WHITE if confirmed else Color(0.28, 0.28, 0.28, 1.0)
		)
		_avatar_glows[index].visible = confirmed
		_avatar_questions[index].visible = not has_participant
	_match_counter.text = "%d/%d đã sắp xếp" % [confirmed_count, required_count]
	_match_countdown.text = "Đếm ngược %d giây" % int(
		_match_data.get("confirmation_seconds_remaining", 30)
	)
	var viewer := _viewer_participant()
	var viewer_confirmed := bool(viewer.get("confirmed", false))
	_confirm_button.texture_normal = (
		CONFIRMED_BUTTON if viewer_confirmed else CONFIRM_BUTTON
	)
	_confirm_button.texture_disabled = (
		CONFIRMED_BUTTON if viewer_confirmed else CONFIRM_BUTTON
	)
	_confirm_button.disabled = viewer_confirmed or _request_in_flight
	_confirm_effect.visible = not viewer_confirmed
	if _confirm_effect.visible:
		_confirm_effect.play()
	else:
		_confirm_effect.stop()
	if _confirm_button.disabled:
		_confirm_button.self_modulate = Color.WHITE


func _build_tank_select() -> void:
	_tank_select = Control.new()
	_tank_select.name = "TankSelect"
	_tank_select.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_tank_select)
	var blocker := ColorRect.new()
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.color = Color(0.0, 0.0, 0.0, 0.0)
	blocker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tank_select.add_child(blocker)

	var background := TextureRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.texture = SEA_BACKGROUND
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tank_select.add_child(background)

	var panel := Panel.new()
	panel.position = Vector2(460.0, 228.0)
	panel.size = Vector2(1000.0, 610.0)
	panel.add_theme_stylebox_override("panel", _blue_panel_style())
	_tank_select.add_child(panel)

	var ally_title := _label(Vector2(0.0, 4.0), Vector2(200.0, 32.0), 22)
	ally_title.text = "Ta"
	ally_title.add_theme_color_override("font_color", Color(0.78, 0.95, 1.0))
	panel.add_child(ally_title)
	var enemy_title := _label(Vector2(800.0, 4.0), Vector2(200.0, 32.0), 22)
	enemy_title.text = "Địch"
	enemy_title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.88))
	panel.add_child(enemy_title)

	_team_left = VBoxContainer.new()
	_team_left.position = Vector2(10.0, 42.0)
	_team_left.size = Vector2(190.0, 520.0)
	_team_left.add_theme_constant_override("separation", 6)
	panel.add_child(_team_left)
	_team_right = VBoxContainer.new()
	_team_right.position = Vector2(800.0, 42.0)
	_team_right.size = Vector2(190.0, 520.0)
	_team_right.add_theme_constant_override("separation", 6)
	panel.add_child(_team_right)

	var center := Panel.new()
	center.position = Vector2(210.0, 42.0)
	center.size = Vector2(580.0, 520.0)
	center.add_theme_stylebox_override("panel", _inner_panel_style())
	panel.add_child(center)
	var title := _label(Vector2(0.0, 5.0), Vector2(580.0, 38.0), 24)
	title.text = "Chọn Tank xuất chiến"
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 0.1))
	center.add_child(title)

	_tank_grid = GridContainer.new()
	_tank_grid.columns = 4
	_tank_grid.position = Vector2(30.0, 54.0)
	_tank_grid.size = Vector2(520.0, 330.0)
	_tank_grid.add_theme_constant_override("h_separation", 8)
	_tank_grid.add_theme_constant_override("v_separation", 8)
	center.add_child(_tank_grid)

	_deploy_button = TextureButton.new()
	_deploy_button.position = Vector2(254.0, 405.0)
	_deploy_button.size = Vector2(72.0, 35.0)
	_deploy_button.texture_normal = DEPLOY_BUTTON
	_deploy_button.texture_disabled = DEPLOY_BUTTON
	_deploy_button.ignore_texture_size = true
	_deploy_button.stretch_mode = TextureButton.STRETCH_KEEP
	_deploy_button.pressed.connect(_on_deploy_pressed)
	_enable_button_hover(_deploy_button)
	center.add_child(_deploy_button)

	var hint := _label(Vector2(25.0, 452.0), Vector2(530.0, 45.0), 15)
	hint.text = "Chọn Tank bạn sở hữu. Đội TEST chỉ chờ người chơi thật xuất chiến."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(hint)

	var intro_size := Vector2(TANK_INTRO_BACKGROUND.get_size())
	_tank_intro = _label(
		Vector2(
			(DESIGN_SIZE.x - intro_size.x) * 0.5,
			506.5
		),
		intro_size,
		40
	)
	_tank_intro.text = "Chọn Tank xuất chiến"
	_tank_intro.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var intro_style := StyleBoxTexture.new()
	intro_style.texture = TANK_INTRO_BACKGROUND
	_tank_intro.add_theme_stylebox_override("normal", intro_style)
	_tank_intro.add_theme_color_override("font_color", Color(1.0, 0.93, 0.0))
	_tank_intro.add_theme_color_override("font_shadow_color", Color(0.0, 0.2, 0.5, 1.0))
	_tank_intro.add_theme_constant_override("shadow_offset_x", 3)
	_tank_intro.add_theme_constant_override("shadow_offset_y", 3)
	_tank_intro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tank_select.add_child(_tank_intro)
	_tank_select.visible = false


func _refresh_tank_select() -> void:
	var viewer_team := int(_match_data.get("viewer_team_no", 1))
	var enemy_team := 2 if viewer_team == 1 else 1
	_refresh_team_column(_team_left, viewer_team, false)
	_refresh_team_column(_team_right, enemy_team, true)
	_refresh_owned_tanks()
	var viewer := _viewer_participant()
	var deployed := bool(viewer.get("deployed", false))
	_deploy_button.texture_normal = DEPLOY_BUTTON
	_deploy_button.texture_disabled = (
		DEPLOYED_BUTTON if deployed else DEPLOY_BUTTON
	)
	_deploy_state_text.texture = DEPLOYED_TEXT if deployed else DEPLOY_TEXT
	_deploy_button.disabled = deployed or _request_in_flight
	if _deploy_effect != null:
		_deploy_effect.visible = not deployed
	if _deploy_button.disabled:
		_deploy_button.self_modulate = Color.WHITE
	_refresh_selected_tank_role_label()
	var required_count := 0
	var deployed_count := 0
	for participant in _team_participants(viewer_team):
		if participant.is_empty() or bool(participant.get("is_bot", false)):
			continue
		required_count += 1
		if bool(participant.get("deployed", false)):
			deployed_count += 1
	required_count = maxi(1, required_count)
	var match_required := int(
		_match_data.get("required_count", 0)
	)
	var match_deployed := int(
		_match_data.get("deployed_count", 0)
	)
	var all_match_deployed := (
		_all_local("deployed")
		if _local_preview
		else match_required > 0 and match_deployed >= match_required
	)
	if all_match_deployed:
		var preparation_seconds := maxi(
			0,
			int(_match_data.get("preparation_seconds_remaining", 5))
		)
		_tank_phase_status.text = "%d  Đang chuẩn bị vào  %d" % [
			preparation_seconds,
			preparation_seconds,
		]
	else:
		var selection_seconds := maxi(
			0,
			30 - int(_selection_display_elapsed)
		)
		_tank_phase_status.text = "%d  Bên ta chọn %d tank (%d/%d)" % [
			selection_seconds,
			required_count,
			deployed_count,
			required_count,
		]
	var intro_remaining := int(
		_match_data.get("selection_intro_seconds_remaining", 0)
	)
	_tank_intro.visible = not _intro_dismissed and intro_remaining > 0
	_refresh_match_skin_overlay()


func _refresh_team_column(
	column: VBoxContainer,
	team_no: int,
	is_enemy: bool
) -> void:
	var slots := _team_participants(team_no)
	var signature := _team_column_signature(slots, team_no, is_enemy)
	var column_id := column.get_instance_id()
	if String(_team_column_signatures.get(column_id, "")) == signature:
		return
	_team_column_signatures[column_id] = signature
	for child in column.get_children():
		child.queue_free()
	for index in 5:
		var participant: Dictionary = slots[index]
		var is_viewer := (
			not participant.is_empty()
			and _participant_is_viewer(participant)
		)
		var card := TextureRect.new()
		card.custom_minimum_size = TEAM_CARD_SIZE
		card.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		card.stretch_mode = TextureRect.STRETCH_KEEP
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.clip_contents = true
		card.texture = TEAM_SELF_SELECTED if is_viewer else TEAM_GRID
		column.add_child(card)
		if participant.is_empty():
			var question := _label(Vector2.ZERO, TEAM_CARD_SIZE, 15)
			question.text = "???"
			question.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			card.add_child(question)
		else:
			var visual_clip := Control.new()
			visual_clip.name = "TeamVisualClip"
			visual_clip.position = TEAM_VISUAL_CLIP_POSITION
			visual_clip.size = TEAM_VISUAL_CLIP_SIZE
			visual_clip.clip_contents = true
			visual_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(visual_clip)
			var visual_coordinates := Control.new()
			visual_coordinates.name = "TeamVisualCoordinates"
			visual_coordinates.position = -TEAM_VISUAL_CLIP_POSITION
			visual_coordinates.size = TEAM_CARD_SIZE
			visual_coordinates.mouse_filter = Control.MOUSE_FILTER_IGNORE
			visual_clip.add_child(visual_coordinates)
			var visual_root := Control.new()
			visual_root.name = "TeamVisualRoot"
			visual_root.position = _team_visual_position
			visual_root.size = _team_visual_size
			visual_root.scale = _team_visual_scale
			visual_root.rotation = _team_visual_rotation
			visual_root.pivot_offset = _team_visual_pivot
			visual_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
			visual_root.z_index = 4
			visual_coordinates.add_child(visual_root)
			var tank := TextureRect.new()
			tank.position = Vector2.ZERO
			tank.size = _team_visual_size
			tank.texture = _tank_texture(participant)
			tank.expand_mode = TextureRect.EXPAND_KEEP_SIZE
			tank.stretch_mode = TextureRect.STRETCH_KEEP
			tank.flip_h = not is_enemy
			tank.mouse_filter = Control.MOUSE_FILTER_IGNORE
			visual_root.add_child(tank)
			_attach_tank_animation(
				visual_root,
				tank,
				String(participant.get("equipped_skin_key", "")),
				not is_enemy
			)
			var name := _label(
				Vector2(5.0, 73.0),
				Vector2(168.0, 23.0),
				12
			)
			name.text = (
				String(participant.get("display_name", ""))
				if bool(participant.get("deployed", false))
				or is_viewer
				else "???"
			)
			name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			name.add_theme_color_override(
				"font_color",
				Color(1.0, 0.94, 0.18)
				if not is_enemy
				else Color(1.0, 0.72, 0.96)
			)
			name.add_theme_color_override(
				"font_outline_color",
				Color(0.0, 0.04, 0.09, 1.0)
			)
			name.add_theme_color_override(
				"font_shadow_color",
				Color(0.0, 0.0, 0.0, 0.9)
			)
			name.add_theme_constant_override("outline_size", 3)
			name.add_theme_constant_override("shadow_offset_x", 1)
			name.add_theme_constant_override("shadow_offset_y", 1)
			name.z_index = 4
			card.add_child(name)
		if bool(participant.get("deployed", false)):
			var deployed_cover := TextureRect.new()
			deployed_cover.position = Vector2(1.5, 1.5)
			deployed_cover.size = Vector2(175.0, 95.0)
			deployed_cover.texture = TEAM_GRID_COVER
			deployed_cover.expand_mode = TextureRect.EXPAND_KEEP_SIZE
			deployed_cover.stretch_mode = TextureRect.STRETCH_KEEP
			deployed_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
			card.add_child(deployed_cover)
		var frame := TextureRect.new()
		frame.position = Vector2.ZERO
		frame.size = TEAM_CARD_SIZE
		frame.texture = (
			TEAM_SELF
			if is_viewer
			else TEAM_ENEMY
			if is_enemy
			else TEAM_ALLY
		)
		frame.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		frame.stretch_mode = TextureRect.STRETCH_KEEP
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(frame)
		var skin_frame_texture := TankSkinCatalog.skin_frame_texture(
			"tankselect",
			{"skin_frame_tier": _participant_skin_frame_tier(participant)}
		)
		if skin_frame_texture != null:
			var skin_frame := TextureRect.new()
			skin_frame.name = "SkinFrame"
			skin_frame.position = _team_skin_frame_position
			skin_frame.size = _team_skin_frame_size
			skin_frame.scale = _team_skin_frame_scale
			skin_frame.rotation = _team_skin_frame_rotation
			skin_frame.pivot_offset = _team_skin_frame_pivot
			skin_frame.texture = skin_frame_texture
			skin_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
			skin_frame.z_index = 3
			card.add_child(skin_frame)


func _team_column_signature(
	slots: Array,
	team_no: int,
	is_enemy: bool
) -> String:
	var parts: Array[String] = [str(team_no), str(is_enemy)]
	for participant_value: Variant in slots:
		if participant_value is not Dictionary or participant_value.is_empty():
			parts.append("empty")
			continue
		var participant: Dictionary = participant_value
		parts.append(
			"%s:%s:%s:%s:%s:%s:%s:%s" % [
				String(participant.get("account_id", "")),
				String(participant.get("display_name", "")),
				String(participant.get("tank_key", "")),
				String(participant.get("equipped_skin_key", "")),
				String(participant.get("tank_preview_asset_key", "")),
				String(participant.get("equipped_skin_preview_asset_key", "")),
				str(bool(participant.get("deployed", false))),
				_participant_skin_frame_tier(participant),
			]
		)
	return "|".join(parts)


func _refresh_owned_tanks() -> void:
	if _selected_tank_role == "skin":
		_clear_tank_buttons()
		_open_match_skin_overlay()
		return
	_close_match_skin_overlay()
	_clear_skin_buttons()
	var tanks := _owned_tank_list()
	var existing_keys: Dictionary = {}
	for tank_value: Variant in tanks:
		if tank_value is not Dictionary:
			continue
		var tank: Dictionary = tank_value
		var tank_key := String(tank.get("tank_key", ""))
		if tank_key.is_empty():
			continue
		existing_keys[tank_key] = true
		if not _tank_buttons.has(tank_key):
			_create_tank_button(tank)
		var button := _tank_buttons[tank_key] as TextureButton
		_set_tank_button_skin_frame(button, tank)
		var role_key := _tank_role_key(tank)
		button.get_parent().visible = (
			_selected_tank_role == "all"
			or role_key == _selected_tank_role
		)
		button.disabled = _viewer_has_deployed() or _request_in_flight
	for tank_key: Variant in _tank_buttons.keys():
		if not existing_keys.has(tank_key):
			var old_button := _tank_buttons[tank_key] as TextureButton
			old_button.get_parent().queue_free()
			_tank_buttons.erase(tank_key)
	_update_tank_button_selection()


func _refresh_owned_skins() -> void:
	_clear_tank_buttons()
	var tank := _owned_tank_by_key(_selected_tank_key)
	if tank.is_empty():
		return
	var equipped_skin_key := TankSkinCatalog.equipped_skin_key(tank)
	if _selected_skin_key.is_empty():
		_selected_skin_key = equipped_skin_key
	var skin_values: Variant = tank.get("skins", [])
	var existing_keys: Dictionary = {}
	if skin_values is Array:
		for skin_value: Variant in skin_values:
			if skin_value is not Dictionary:
				continue
			var skin: Dictionary = skin_value
			if skin.get("owned", false) != true:
				continue
			var skin_key := String(skin.get("skin_key", "")).strip_edges()
			if skin_key.is_empty():
				continue
			existing_keys[skin_key] = true
			if not _skin_buttons.has(skin_key):
				_create_skin_button(tank, skin)
			var button := _skin_buttons[skin_key] as TextureButton
			button.get_parent().visible = true
			button.disabled = _request_in_flight
	for skin_key: Variant in _skin_buttons.keys():
		if not existing_keys.has(skin_key):
			var old_button := _skin_buttons[skin_key] as TextureButton
			old_button.get_parent().queue_free()
			_skin_buttons.erase(skin_key)
	_update_skin_button_selection()


func _clear_tank_buttons() -> void:
	for button_value: Variant in _tank_buttons.values():
		var button := button_value as TextureButton
		if button != null:
			button.get_parent().free()
	_tank_buttons.clear()


func _clear_skin_buttons() -> void:
	for button_value: Variant in _skin_buttons.values():
		var button := button_value as TextureButton
		if button != null:
			button.get_parent().free()
	_skin_buttons.clear()


func _create_tank_button(tank: Dictionary) -> void:
	var tank_key := String(tank.get("tank_key", ""))
	var cell := Control.new()
	cell.custom_minimum_size = Vector2(96.0, 96.0)
	_tank_grid.add_child(cell)
	var button := TextureButton.new()
	button.position = _tank_choice_button_position
	button.size = _tank_choice_button_size
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP
	button.texture_normal = TANK_SLOT_NORMAL
	button.texture_hover = TANK_SLOT_SELECTED
	button.texture_pressed = TANK_SLOT_SELECTED
	button.tooltip_text = String(tank.get("tank_name", tank_key))
	button.pressed.connect(_on_tank_pressed.bind(tank_key))
	_enable_button_hover(button)
	var tank_image := TextureRect.new()
	tank_image.name = "TankImage"
	tank_image.position = _tank_choice_visual_position
	tank_image.size = _tank_choice_visual_size
	tank_image.scale = _tank_choice_visual_scale
	tank_image.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	tank_image.stretch_mode = TextureRect.STRETCH_KEEP
	tank_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tank_image.z_index = 1
	button.add_child(tank_image)
	var skin_frame := TextureRect.new()
	skin_frame.name = "SkinFrame"
	skin_frame.position = _tank_choice_skin_frame_position
	skin_frame.size = _tank_choice_skin_frame_size
	skin_frame.scale = _tank_choice_skin_frame_scale
	skin_frame.rotation = _tank_choice_skin_frame_rotation
	skin_frame.pivot_offset = _tank_choice_skin_frame_pivot
	skin_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(skin_frame)
	var level := TextureRect.new()
	level.name = "Level"
	level.position = _tank_choice_level_position
	level.size = _tank_choice_level_size
	level.scale = _tank_choice_level_scale
	level.rotation = _tank_choice_level_rotation
	level.pivot_offset = _tank_choice_level_pivot
	level.z_index = 2
	level.texture = _tank_level_texture(int(tank.get("tank_level", 1)))
	level.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	level.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	level.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(level)
	cell.add_child(button)
	_tank_buttons[tank_key] = button
	_set_tank_button_skin_frame(button, tank)
	_set_tank_button_visual(button, tank)


func _create_skin_button(tank: Dictionary, skin: Dictionary) -> void:
	var skin_key := String(skin.get("skin_key", "")).strip_edges()
	var cell := Control.new()
	cell.custom_minimum_size = Vector2(96.0, 96.0)
	_tank_grid.add_child(cell)
	var button := TextureButton.new()
	button.position = _tank_choice_button_position
	button.size = _tank_choice_button_size
	button.ignore_texture_size = true
	button.stretch_mode = TextureButton.STRETCH_KEEP
	button.texture_normal = TANK_SLOT_NORMAL
	button.texture_hover = TANK_SLOT_SELECTED
	button.texture_pressed = TANK_SLOT_SELECTED
	button.tooltip_text = String(skin.get("skin_name", skin_key))
	button.pressed.connect(_on_skin_pressed.bind(skin_key))
	_enable_button_hover(button)
	var tank_image := TextureRect.new()
	tank_image.name = "TankImage"
	tank_image.position = _tank_choice_visual_position
	tank_image.size = _tank_choice_visual_size
	tank_image.scale = _tank_choice_visual_scale
	tank_image.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	tank_image.stretch_mode = TextureRect.STRETCH_KEEP
	tank_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(tank_image)
	var visual_data := tank.duplicate(true)
	visual_data["equipped_skin_key"] = skin_key
	cell.add_child(button)
	_skin_buttons[skin_key] = button
	_set_tank_button_visual(button, visual_data)


func _update_tank_button_selection() -> void:
	for key: Variant in _tank_buttons:
		var button := _tank_buttons[key] as TextureButton
		var selected := String(key) == _selected_tank_key
		button.texture_normal = (
			TANK_SLOT_SELECTED if selected else TANK_SLOT_NORMAL
		)
		button.modulate = Color.WHITE


func _update_skin_button_selection() -> void:
	for key: Variant in _skin_buttons:
		var button := _skin_buttons[key] as TextureButton
		var selected := String(key) == _selected_skin_key
		button.texture_normal = (
			TANK_SLOT_SELECTED if selected else TANK_SLOT_NORMAL
		)
		button.modulate = Color.WHITE


func _select_default_tank() -> void:
	var viewer := _viewer_participant()
	_selected_tank_key = String(viewer.get("tank_key", ""))
	if _selected_tank_key.is_empty():
		_selected_tank_key = String(
			GameSession.lobby_data.get("tank_key", "")
		)
	if _selected_tank_key.is_empty():
		var tanks := _owned_tank_list()
		if not tanks.is_empty():
			var first_tank: Variant = tanks[0]
			if first_tank is Dictionary:
				_selected_tank_key = String(first_tank.get("tank_key", ""))
	var selected_tank := _owned_tank_by_key(_selected_tank_key)
	_selected_skin_key = TankSkinCatalog.equipped_skin_key(selected_tank)
	if not _selected_tank_key.is_empty() and not _local_preview:
		_submit_tank_selection(_selected_tank_key)


func _build_battle_loading() -> void:
	_battle_loading = Control.new()
	_battle_loading.name = "BattleLoading"
	_battle_loading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_battle_loading)
	var blocker := ColorRect.new()
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.color = Color(0.0, 0.0, 0.0, 0.0)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_battle_loading.add_child(blocker)

	var background := TextureRect.new()
	background.texture = BATTLE_LOADING_BG
	background.position = Vector2(160.0, 156.5)
	background.size = Vector2(1600.0, 767.0)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_battle_loading.add_child(background)

	var versus := TextureRect.new()
	versus.texture = LOADING_VS
	versus.position = Vector2(923.0, 500.0)
	versus.size = Vector2(74.0, 63.0)
	versus.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	versus.stretch_mode = TextureRect.STRETCH_KEEP
	versus.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_battle_loading.add_child(versus)

	_loading_map_name = _label(Vector2(760.0, 410.0), Vector2(400.0, 52.0), 22)
	_loading_map_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_loading_map_name.add_theme_color_override("font_color", Color.WHITE)
	_battle_loading.add_child(_loading_map_name)

	_loading_left = Control.new()
	_loading_left.position = Vector2(360.0, 215.0)
	_loading_left.size = Vector2(460.0, 650.0)
	_battle_loading.add_child(_loading_left)
	_loading_right = Control.new()
	_loading_right.position = Vector2(1100.0, 215.0)
	_loading_right.size = Vector2(460.0, 650.0)
	_battle_loading.add_child(_loading_right)
	_battle_loading.visible = false


func _refresh_battle_loading() -> void:
	for child in _loading_left.get_children():
		child.queue_free()
	for child in _loading_right.get_children():
		child.queue_free()
	_loading_cards.clear()
	_loading_card_by_account.clear()
	_loading_card_by_name.clear()
	_loading_map_name.text = String(
		_match_data.get("map_name", _match_data.get("map_key", ""))
	)
	var map_thumbnail_path := String(
		_match_data.get("map_thumbnail_asset_path", "")
	)
	var resolved_thumbnail_path := AssetPathAliases.resolve(map_thumbnail_path)
	var map_thumbnail: Texture2D = DEFAULT_BATTLE_MAP_THUMBNAIL
	if not map_thumbnail_path.is_empty() and ResourceLoader.exists(
		resolved_thumbnail_path
	):
		var loaded_thumbnail := ResourceLoader.load(
			resolved_thumbnail_path,
			"Texture2D"
		) as Texture2D
		if loaded_thumbnail != null:
			map_thumbnail = loaded_thumbnail
	_loading_map_preview.texture = map_thumbnail

	var viewer_team := int(_match_data.get("viewer_team_no", 1))
	var enemy_team := 2 if viewer_team == 1 else 1
	var enemy := _team_participant_list(enemy_team)
	var allies := _team_participant_list(viewer_team)
	# Cả trận 1v1 lẫn 5v5 đều bắt đầu tại ô số 1 của bố cục năm ô.
	for index in allies.size():
		_create_loading_card(_loading_left, allies[index], index, true)
	for index in enemy.size():
		_create_loading_card(_loading_right, enemy[index], index, false)
	_restore_loading_chat_bubbles()


func _create_loading_card(
	parent: Control,
	participant: Dictionary,
	index: int,
	is_ally: bool
) -> void:
	var card := Control.new()
	card.position = _loading_card_position(index, is_ally)
	card.size = Vector2(235.0, 190.0)
	parent.add_child(card)
	_loading_cards.append(card)
	var account_id := String(participant.get("account_id", ""))
	if not account_id.is_empty():
		_loading_card_by_account[account_id] = card
	var display_name := String(participant.get("display_name", ""))
	if not display_name.is_empty():
		_loading_card_by_name[display_name] = card

	var frame := TextureRect.new()
	frame.texture = (
		LOADING_HEXAGON_LIGHT
		if bool(participant.get("load_ready", false))
		else LOADING_HEXAGON
	)
	frame.size = Vector2(235.0, 190.0)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(frame)

	var tank := TextureRect.new()
	var head_texture := _tank_head_texture(participant)
	if head_texture != null:
		tank.position = Vector2(28.0, 28.0)
		tank.size = Vector2(178.0, 98.0)
		tank.texture = head_texture
		tank.expand_mode = TextureRect.EXPAND_KEEP_SIZE
		tank.stretch_mode = TextureRect.STRETCH_KEEP
		tank.flip_h = is_ally
	else:
		tank.position = Vector2(40.0, 26.0)
		tank.size = Vector2(155.0, 105.0)
		tank.texture = _tank_texture(participant)
		tank.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tank.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tank.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(tank)
	if not _attach_tank_head_animation(
		card,
		tank,
		participant,
		is_ally
	) and head_texture == null:
		_attach_tank_animation(
			card,
			tank,
			String(participant.get("equipped_skin_key", "")),
			is_ally
		)

	var name := _label(Vector2(28.0, 123.0), Vector2(180.0, 24.0), 14)
	name.text = String(participant.get("display_name", ""))
	name.add_theme_color_override(
		"font_color",
		Color(0.9, 0.9, 1.0) if is_ally else Color(1.0, 0.65, 0.8)
	)
	card.add_child(name)

	var bar_bg := TextureRect.new()
	bar_bg.texture = LOADING_BAR_BG
	bar_bg.position = Vector2(51.0, 151.0)
	bar_bg.size = Vector2(132.0, 16.0)
	bar_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar_bg.stretch_mode = TextureRect.STRETCH_KEEP
	card.add_child(bar_bg)

	var bar_clip := Control.new()
	bar_clip.position = Vector2(52.0, 152.0)
	bar_clip.size = Vector2(
		130.0 * float(participant.get("load_progress", 0)) / 100.0,
		14.0
	)
	bar_clip.clip_contents = true
	card.add_child(bar_clip)
	var bar := TextureRect.new()
	bar.texture = LOADING_BAR
	bar.size = Vector2(130.0, 14.0)
	bar.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bar.stretch_mode = TextureRect.STRETCH_KEEP
	bar_clip.add_child(bar)

	var progress := _label(Vector2(51.0, 146.0), Vector2(132.0, 24.0), 12)
	progress.text = "%d%%" % int(participant.get("load_progress", 0))
	card.add_child(progress)


func _capture_loading_card_layouts() -> void:
	_loading_left_card_positions = _editor_loading_card_positions(_loading_left)
	_loading_right_card_positions = _editor_loading_card_positions(_loading_right)


func _editor_loading_card_positions(parent: Control) -> Array[Vector2]:
	var positions: Array[Vector2] = []
	for child in parent.get_children():
		if child is Control and child.name.begins_with("EditorPreviewCard"):
			positions.append((child as Control).position)
	return positions


func _loading_card_position(index: int, is_ally: bool) -> Vector2:
	var positions := (
		_loading_left_card_positions
		if is_ally
		else _loading_right_card_positions
	)
	if index >= 0 and index < positions.size():
		return positions[index]
	# Fallback for a participant beyond the five authored scene slots.
	return Vector2(0.0, float(index) * 105.0)


func _build_transition() -> void:
	_transition_layer = Control.new()
	_transition_layer.name = "Transition"
	_transition_layer.z_index = 100
	_transition_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_transition_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_transition_layer)
	_transition_player = SwfTimelinePlayer.new()
	_transition_player.name = "OriginalBattleDoor"
	_transition_player.timeline_path = TRANSITION_TIMELINE
	_transition_player.autoplay = false
	_transition_player.loop = false
	_transition_player.frame_changed.connect(_on_transition_frame_changed)
	_transition_layer.add_child(_transition_player)
	_center_transition_player()
	_transition_layer.visible = false


func _center_transition_player() -> void:
	if _transition_layer == null or _transition_player == null:
		return
	_transition_player.position = _transition_layer.size * 0.5
	var stage_size := _transition_player.get_stage_size()
	if stage_size.x <= 0.0 or stage_size.y <= 0.0:
		stage_size = DESIGN_SIZE
	if _transition_layer.size.x <= 0.0 or _transition_layer.size.y <= 0.0:
		_transition_player.scale = Vector2.ONE
		return
	var cover_scale := maxf(
		_transition_layer.size.x / stage_size.x,
		_transition_layer.size.y / stage_size.y
	)
	_transition_player.scale = Vector2.ONE * cover_scale


func _start_transition() -> void:
	_prepare_battle_map()
	_center_transition_player()
	_transition_layer.visible = true
	if _transition_finished:
		return
	if (
		_transition_player.get_current_frame()
		>= TRANSITION_MAP_REVEAL_FRAME
	):
		_reveal_battle_map()
	if _transition_player.get_current_frame() <= 1:
		_transition_player.play()


func _on_transition_frame_changed(frame_number: int) -> void:
	if _transition_finished:
		return
	if frame_number >= TRANSITION_MAP_REVEAL_FRAME:
		_reveal_battle_map()
	if frame_number < _transition_player.get_frame_count():
		return
	_transition_finished = true
	_transition_player.stop()
	_transition_player.seek_frame(_transition_player.get_frame_count())
	if _phase == "active":
		_complete_flow()


func _prepare_battle_map() -> void:
	if _battle_map == null or _battle_map_prepared:
		return
	_battle_map_prepared = true
	_battle_map_revealed = false
	_battle_map.call("prepare", _match_data)


func _reveal_battle_map() -> void:
	if _battle_map == null or _battle_map_revealed:
		return
	_prepare_battle_map()
	_battle_map_revealed = true
	_battle_loading.visible = false
	_battle_map.call("reveal")


func _reset_battle_map() -> void:
	_battle_map_prepared = false
	_battle_map_revealed = false
	if _battle_map != null:
		_battle_map.call("reset")
	if _battle_result_screen != null:
		_battle_result_screen.reset()


func _on_battle_result_summary_requested(
	result: Dictionary,
	players: Array[Dictionary],
	honors: Dictionary
) -> void:
	# The source client removes the battlefield before opening the result module.
	# Hiding this sibling reveals the already-loaded lobby starfield underneath.
	_battle_map.visible = false
	# The transition layer sits above the result screen and otherwise consumes
	# pointer input even after its animation has finished.
	_transition_layer.visible = false
	_battle_result_screen.show_result(result, players, honors, "player")


func _on_battle_result_exit_requested() -> void:
	# Restore the exact ready-room UI and its shared chat before releasing the
	# per-match overlay. Do not leave the room or fall back to the room browser.
	_battle_result_screen.reset()
	_queue_lobby_refresh_after_online_battle()
	var room_view := get_parent()
	if room_view != null and room_view.has_method("return_to_previous_room_after_battle"):
		room_view.call("return_to_previous_room_after_battle")
	hide_flow()


func _on_battle_result_leave_requested() -> void:
	# THOÁT is distinct from VỀ: release the result UI/chat, close the match
	# overlay, then leave the ready room. PvpRoomView keeps its selected tab.
	_battle_result_screen.reset()
	_queue_lobby_refresh_after_online_battle()
	var room_view := get_parent()
	hide_flow()
	if room_view != null and room_view.has_method("leave_room_after_battle"):
		room_view.call("leave_room_after_battle")


func _queue_lobby_refresh_after_online_battle() -> void:
	if (
		bool(_match_data.get("is_test", false))
		or String(_match_data.get("id", "")) in ["", "local-test"]
	):
		return
	call_deferred("_refresh_lobby_after_online_battle")


func _refresh_lobby_after_online_battle() -> void:
	# The settlement transaction may have changed level/EXP/Bạc. Reload the
	# authoritative lobby once so every header/panel drops its pre-match cache.
	await GameSession.fetch_lobby()


func _complete_flow() -> void:
	if not _transition_finished:
		_start_transition()
		return
	if _battle_emitted:
		return
	_battle_emitted = true
	battle_ready.emit(_match_data)


func _poll_match() -> void:
	_poll_in_flight = true
	var result: Dictionary = await GameSession.fetch_current_game_match()
	_poll_in_flight = false
	if not result.get("ok", false):
		var error_value: Variant = result.get("error", {})
		var error_code := (
			String(error_value.get("code", ""))
			if error_value is Dictionary
			else ""
		)
		if error_code in ["MATCH_NOT_FOUND", "MATCH_CONFIRM_CLOSED"]:
			var confirmation_was_open := _phase == "confirming"
			hide_flow()
			if error_code == "MATCH_CONFIRM_CLOSED" and confirmation_was_open:
				confirmation_expired.emit()
		return
	var match_value: Variant = result.get("match", {})
	if match_value is Dictionary:
		_apply_match_data(match_value)


func _on_confirm_pressed() -> void:
	if _request_in_flight:
		return
	if _local_preview:
		var participants: Array = _match_data.get("participants", [])
		for participant_value: Variant in participants:
			if (
				participant_value is Dictionary
				and not bool(participant_value.get("is_bot", false))
			):
				var participant: Dictionary = participant_value
				participant["confirmed"] = true
				break
		_refresh_match_found()
		return
	_request_in_flight = true
	var result: Dictionary = await GameSession.confirm_game_match()
	_request_in_flight = false
	_apply_result_match(result)


func _on_tank_pressed(tank_key: String) -> void:
	if _request_in_flight or _viewer_has_deployed():
		return
	_selected_tank_key = tank_key
	_selected_skin_key = TankSkinCatalog.equipped_skin_key(
		_owned_tank_by_key(tank_key)
	)
	_update_tank_button_selection()
	_refresh_selected_tank_role_label()
	if _local_preview:
		_set_local_viewer_tank(tank_key)
		return
	_submit_tank_selection(tank_key)


func _on_skin_pressed(skin_key: String) -> void:
	if (
		_request_in_flight
		or _selected_tank_key.is_empty()
		or skin_key.is_empty()
	):
		return
	var tank := _owned_tank_by_key(_selected_tank_key)
	if tank.is_empty():
		return
	_selected_skin_key = skin_key
	_update_skin_button_selection()
	if _local_preview:
		_set_local_viewer_skin(_selected_tank_key, skin_key)
		return
	_submit_skin_selection(_selected_tank_key, skin_key)


func _on_tank_role_pressed(role_key: String) -> void:
	_selected_tank_role = role_key
	_refresh_tank_role_buttons()
	_refresh_owned_tanks()
	if _tank_scroll != null:
		_tank_scroll.scroll_vertical = 0


func _refresh_tank_role_buttons() -> void:
	if _tank_role_buttons.is_empty():
		return
	var normal_textures := {
		"all": TAB_ALL_NORMAL,
		"dps": TAB_DPS_NORMAL,
		"tanker": TAB_TANKER_NORMAL,
		"support": TAB_SUPPORT_NORMAL,
		"skin": BTN_SKIN,
	}
	var selected_textures := {
		"all": TAB_ALL_SELECTED,
		"dps": TAB_DPS_SELECTED,
		"tanker": TAB_TANKER_SELECTED,
		"support": TAB_SUPPORT_SELECTED,
		"skin": BTN_SKIN,
	}
	for role_key: String in _tank_role_buttons:
		var button := _tank_role_buttons[role_key] as TextureButton
		button.texture_normal = (
			selected_textures[role_key]
			if role_key == _selected_tank_role
			else normal_textures[role_key]
		)


func _submit_tank_selection(tank_key: String) -> void:
	if _request_in_flight or tank_key.is_empty():
		return
	_request_in_flight = true
	var result: Dictionary = await GameSession.select_game_match_tank(tank_key)
	_request_in_flight = false
	_apply_result_match(result)


func _submit_skin_selection(tank_key: String, skin_key: String) -> void:
	if _request_in_flight:
		return
	_request_in_flight = true
	var equip_result: Dictionary = await GameSession.equip_game_match_skin(
		tank_key,
		skin_key
	)
	if not bool(equip_result.get("ok", false)):
		_request_in_flight = false
		_selected_skin_key = TankSkinCatalog.equipped_skin_key(
			_owned_tank_by_key(tank_key)
		)
		_refresh_match_skin_overlay()
		return
	_request_in_flight = false
	if bool(equip_result.get("ok", false)):
		var match_value: Variant = equip_result.get("match", {})
		if match_value is Dictionary:
			_apply_match_data(match_value)
		_refresh_match_skin_overlay()
	else:
		_refresh_tank_select()


func _on_deploy_pressed() -> void:
	if _request_in_flight:
		return
	if _local_preview:
		var viewer := _local_viewer_participant()
		viewer["deployed"] = true
		for participant_value: Variant in _match_data.get("participants", []):
			if participant_value is Dictionary and bool(
				participant_value.get("is_bot", false)
			):
				var participant: Dictionary = participant_value
				participant["deployed"] = true
		_refresh_tank_select()
		return
	_request_in_flight = true
	var result: Dictionary = await GameSession.deploy_game_match_tank()
	_request_in_flight = false
	_apply_result_match(result)


func _report_real_loading_progress() -> void:
	if _request_in_flight or _local_preview:
		return
	var progress := 10
	if ResourceLoader.exists(TRANSITION_TIMELINE):
		progress = 35
	var map_path := String(_match_data.get("map_thumbnail_asset_path", ""))
	var resolved_map_path := AssetPathAliases.resolve(map_path)
	if map_path.is_empty() or ResourceLoader.exists(resolved_map_path):
		progress = 65
	var viewer := _viewer_participant()
	if _tank_texture(viewer) != null:
		progress = 90
	if not _reported_load_steps.has(progress):
		_reported_load_steps[progress] = true
		_submit_load_progress(progress)
	elif progress == 90 and not _reported_load_steps.has(100):
		_reported_load_steps[100] = true
		_submit_load_progress(100)


func _submit_load_progress(progress: int) -> void:
	if _request_in_flight:
		return
	_request_in_flight = true
	var result: Dictionary = await GameSession.report_game_match_load(progress)
	_request_in_flight = false
	_apply_result_match(result)


func _apply_result_match(result: Dictionary) -> void:
	if not result.get("ok", false):
		return
	var match_value: Variant = result.get("match", {})
	if match_value is Dictionary:
		_apply_match_data(match_value)


func _advance_local_preview(delta: float) -> void:
	_local_elapsed += delta
	match _phase:
		"confirming":
			var participants: Array = _match_data.get("participants", [])
			for participant_value: Variant in participants:
				if participant_value is not Dictionary:
					continue
				var participant: Dictionary = participant_value
				if (
					bool(participant.get("is_bot", false))
					and not bool(participant.get("confirmed", false))
					and _local_elapsed >= (
						float(participant.get("slot_no", 1))
						* LOCAL_BOT_CONFIRM_STEP
					)
				):
					participant["confirmed"] = true
			_match_data["confirmation_seconds_remaining"] = maxi(
				0,
				30 - int(_local_elapsed)
			)
			_refresh_match_found()
			if _all_local("confirmed"):
				_set_local_phase("selecting")
			elif int(
				_match_data.get("confirmation_seconds_remaining", 0)
			) <= 0:
				hide_flow()
				confirmation_expired.emit()
		"selecting":
			_match_data["selection_intro_seconds_remaining"] = maxi(
				0,
				3 - int(_local_elapsed)
			)
			if _all_local("deployed"):
				if not _local_preparation_started:
					_local_preparation_started = true
					_local_preparation_elapsed = 0.0
				else:
					_local_preparation_elapsed += delta
				_match_data["preparation_seconds_remaining"] = maxi(
					0,
					ceili(
						LOCAL_PREPARATION_SECONDS
						- _local_preparation_elapsed
					)
				)
			else:
				_local_preparation_started = false
				_local_preparation_elapsed = 0.0
				_match_data["preparation_seconds_remaining"] = 0
			_refresh_tank_select()
			if (
				_local_preparation_started
				and _local_preparation_elapsed
				>= LOCAL_PREPARATION_SECONDS
			):
				_set_local_phase("loading")
		"loading":
			var next_progress := mini(100, int(_local_elapsed * 45.0))
			for participant_value: Variant in _match_data.get("participants", []):
				if participant_value is Dictionary:
					var participant: Dictionary = participant_value
					participant["load_progress"] = next_progress
					participant["load_ready"] = next_progress >= 100
			_refresh_battle_loading()
			if next_progress >= 100:
				_set_local_phase("transition")
		"transition":
			if _transition_finished:
				_set_local_phase("active")


func _set_local_phase(next_phase: String) -> void:
	_local_elapsed = 0.0
	if next_phase == "selecting":
		_local_preparation_elapsed = 0.0
		_local_preparation_started = false
	elif _phase == "selecting":
		_local_preparation_elapsed = 0.0
		_local_preparation_started = false
	_match_data["phase"] = next_phase
	if next_phase == "selecting":
		for participant_value: Variant in _match_data.get("participants", []):
			if participant_value is Dictionary and bool(
				participant_value.get("is_bot", false)
			):
				var participant: Dictionary = participant_value
				participant["tank_key"] = "gangtiexia03"
				participant["tank_name"] = "Iron Man"
				participant["equipped_skin_key"] = "gangtiexia03_default"
				participant["deployed"] = true
	_apply_match_data(_match_data)


func _all_local(field: String) -> bool:
	var participants: Array = _match_data.get("participants", [])
	if participants.is_empty():
		return false
	for participant_value: Variant in participants:
		if (
			participant_value is not Dictionary
			or not bool(participant_value.get(field, false))
		):
			return false
	return true


func _set_local_viewer_tank(tank_key: String) -> void:
	var viewer := _local_viewer_participant()
	var owned := TankSkinCatalog.find_owned_tank(
		GameSession.lobby_data,
		tank_key
	)
	viewer["tank_key"] = tank_key
	viewer["tank_name"] = owned.get("tank_name", tank_key)
	viewer["tank_level"] = owned.get("tank_level", 1)
	viewer["equipped_skin_key"] = TankSkinCatalog.equipped_skin_key(owned)
	if tank_key == "gangtiexia03":
		if String(viewer["equipped_skin_key"]).is_empty():
			viewer["equipped_skin_key"] = "gangtiexia03_default"
		viewer["skins"] = _preview_ironman_skins(
			String(viewer["equipped_skin_key"])
		)
		viewer["skin_frame_tier"] = (
			TankSkinCatalog.skin_frame_tier(owned)
			if not owned.is_empty()
			else "orange"
		)
	elif not owned.is_empty():
		viewer["skins"] = owned.get("skins", []).duplicate(true)
		viewer["skin_frame_tier"] = TankSkinCatalog.skin_frame_tier(owned)
	_selected_skin_key = String(viewer.get("equipped_skin_key", ""))
	viewer["deployed"] = false
	_refresh_tank_select()


func _set_local_viewer_skin(tank_key: String, skin_key: String) -> void:
	var owned_tanks: Variant = GameSession.lobby_data.get("owned_tanks", [])
	if owned_tanks is Array:
		for tank_value: Variant in owned_tanks:
			if tank_value is not Dictionary:
				continue
			var tank: Dictionary = tank_value
			if String(tank.get("tank_key", "")) != tank_key:
				continue
			tank["equipped_skin_key"] = skin_key
			var skins: Variant = tank.get("skins", [])
			if skins is Array:
				for skin_value: Variant in skins:
					if skin_value is Dictionary:
						var skin: Dictionary = skin_value
						skin["is_equipped"] = (
							String(skin.get("skin_key", "")) == skin_key
						)
			break
		GameSession.lobby_data["owned_tanks"] = owned_tanks
		GameSession.notify_lobby_data_changed()
	var viewer := _local_viewer_participant()
	viewer["equipped_skin_key"] = skin_key
	var viewer_skins: Variant = viewer.get("skins", [])
	if viewer_skins is Array:
		for skin_value: Variant in viewer_skins:
			if skin_value is Dictionary:
				var skin: Dictionary = skin_value
				skin["is_equipped"] = (
					String(skin.get("skin_key", "")) == skin_key
				)
	_refresh_tank_select()
	_refresh_match_skin_overlay()


func _local_viewer_participant() -> Dictionary:
	for participant_value: Variant in _match_data.get("participants", []):
		if (
			participant_value is Dictionary
			and int(participant_value.get("team_no", 0)) == 1
			and not bool(participant_value.get("is_bot", false))
		):
			return participant_value
	return {}


func _viewer_participant() -> Dictionary:
	var account_id := String(GameSession.account.get("id", ""))
	var viewer_team := int(_match_data.get("viewer_team_no", 0))
	for participant_value: Variant in _match_data.get("participants", []):
		if participant_value is not Dictionary:
			continue
		var participant: Dictionary = participant_value
		if (
			not account_id.is_empty()
			and String(participant.get("account_id", "")) == account_id
		):
			return participant
		if (
			account_id.is_empty()
			and viewer_team > 0
			and int(participant.get("team_no", 0)) == viewer_team
			and not bool(participant.get("is_bot", false))
		):
			return participant
	return _local_viewer_participant()


func _participants_by_slots() -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	slots.resize(10)
	for index in 10:
		slots[index] = {}
	for participant_value: Variant in _match_data.get("participants", []):
		if participant_value is not Dictionary:
			continue
		var participant: Dictionary = participant_value
		var team_no := int(participant.get("team_no", 0))
		var slot_no := int(participant.get("slot_no", 0))
		if team_no in [1, 2] and slot_no >= 1 and slot_no <= 5:
			slots[(team_no - 1) * 5 + slot_no - 1] = participant
	return slots


func _team_participants(team_no: int) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	slots.resize(5)
	for index in 5:
		slots[index] = {}
	for participant_value: Variant in _match_data.get("participants", []):
		if participant_value is not Dictionary:
			continue
		var participant: Dictionary = participant_value
		if int(participant.get("team_no", 0)) != team_no:
			continue
		var slot_no := int(participant.get("slot_no", 0))
		if slot_no >= 1 and slot_no <= 5:
			slots[slot_no - 1] = participant
	return slots


func _team_participant_list(team_no: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for participant in _team_participants(team_no):
		if not participant.is_empty():
			result.append(participant)
	return result


func _participant_is_viewer(participant: Dictionary) -> bool:
	if participant.is_empty():
		return false
	var viewer := _viewer_participant()
	if viewer.is_empty():
		return false
	var participant_account := String(participant.get("account_id", ""))
	var viewer_account := String(viewer.get("account_id", ""))
	if not participant_account.is_empty() and not viewer_account.is_empty():
		return participant_account == viewer_account
	return (
		int(participant.get("team_no", 0))
		== int(viewer.get("team_no", 0))
		and int(participant.get("slot_no", 0))
		== int(viewer.get("slot_no", 0))
	)


func _avatar_texture(participant: Dictionary) -> Texture2D:
	return (
		AVATAR_FEMALE
		if String(participant.get("gender", "")) == "female"
		else AVATAR_MALE
	)


func _tank_texture(participant: Dictionary) -> Texture2D:
	var tank_key := String(participant.get("tank_key", ""))
	var skin_key := String(participant.get("equipped_skin_key", ""))
	var tank_data := TankSkinCatalog.find_owned_tank(
		GameSession.lobby_data,
		tank_key
	)
	if tank_data.is_empty():
		tank_data = participant
	return TankSkinCatalog.texture_for(tank_data, tank_key, skin_key)


func _participant_skin_frame_tier(participant: Dictionary) -> String:
	var direct_tier := TankSkinCatalog.skin_frame_tier(participant)
	if not direct_tier.is_empty():
		return direct_tier
	if not _participant_is_viewer(participant):
		return ""
	var owned := _owned_tank_by_key(
		String(participant.get("tank_key", ""))
	)
	return TankSkinCatalog.skin_frame_tier(owned)


func _set_tank_button_skin_frame(
	button: TextureButton,
	tank: Dictionary
) -> void:
	var skin_frame := button.get_node_or_null("SkinFrame") as TextureRect
	if skin_frame == null:
		return
	var texture := TankSkinCatalog.skin_frame_texture("tanklist", tank)
	skin_frame.texture = texture
	skin_frame.visible = texture != null


func _on_lobby_data_changed(_data: Dictionary) -> void:
	_team_column_signatures.clear()
	if _phase == "selecting":
		_refresh_tank_select()


func _tank_level_texture(level: int) -> Texture2D:
	return AssetPathAliases.load_texture(
		"res://assets/ui/tank/tank_level_%d.png" % clampi(level, 1, 6)
	)


func _tank_head_texture(participant: Dictionary) -> Texture2D:
	return PvpTankHeadCatalog.texture_for(
		String(participant.get("tank_key", "")),
		String(participant.get("equipped_skin_key", ""))
	)


func _owned_tank_list() -> Array:
	if _local_preview:
		var local_viewer := _viewer_participant()
		if not local_viewer.is_empty():
			return [local_viewer]
	var tanks_value: Variant = GameSession.lobby_data.get("owned_tanks", [])
	if tanks_value is Array and not tanks_value.is_empty():
		return tanks_value
	var viewer := _viewer_participant()
	if viewer.is_empty():
		return []
	return [viewer]


func _owned_tank_by_key(tank_key: String) -> Dictionary:
	for tank_value: Variant in _owned_tank_list():
		if tank_value is not Dictionary:
			continue
		var tank: Dictionary = tank_value
		if String(tank.get("tank_key", "")) == tank_key:
			return tank
	return {}


func _viewer_has_deployed() -> bool:
	return bool(_viewer_participant().get("deployed", false))


func _tank_role_key(tank_data: Dictionary) -> String:
	var role := String(
		tank_data.get(
			"tank_role_key",
			tank_data.get(
				"role_key",
				tank_data.get("tank_role", tank_data.get("role", ""))
			)
		)
	).strip_edges().to_lower()
	match role:
		"attack", "attacker", "damage", "damage_dealer":
			return "dps"
		"tank", "panzer", "defender", "defense":
			return "tanker"
		"assist", "healer", "healing", "helper":
			return "support"
		"dps", "tanker", "support":
			return role
	if String(tank_data.get("tank_key", "")) == "gangtiexia03":
		return "dps"
	return ""


func _refresh_selected_tank_role_label() -> void:
	if _tank_role_value == null:
		return
	var role_key := _tank_role_key(
		_owned_tank_by_key(_selected_tank_key)
	)
	match role_key:
		"tanker":
			_tank_role_value.text = "TANK"
		"support":
			_tank_role_value.text = "HỖ TRỢ"
		_:
			_tank_role_value.text = "DPS"


func _set_tank_button_visual(
	button: TextureButton,
	tank_data: Dictionary
) -> void:
	var old_animation := button.get_node_or_null("TankAnimation")
	if old_animation != null:
		old_animation.queue_free()
	var image := button.get_node("TankImage") as TextureRect
	var skin_key := TankSkinCatalog.equipped_skin_key(tank_data)
	var animation_path := TankSkinCatalog.animation_path(skin_key)
	if animation_path.is_empty():
		image.visible = true
		image.texture = _tank_texture(tank_data)
		return
	image.visible = false
	var animation := SwfTimelinePlayer.new()
	animation.name = "TankAnimation"
	animation.timeline_path = animation_path
	animation.position = (
		_tank_choice_visual_position
		+ _tank_choice_visual_size * _tank_choice_visual_scale * 0.5
	)
	button.add_child(animation)
	animation.scale = _tank_choice_visual_scale
	animation.play()


func _attach_tank_animation(
	parent: Control,
	image: TextureRect,
	skin_key: String,
	flip_h := false
) -> void:
	var animation_path := TankSkinCatalog.animation_path(skin_key)
	if animation_path.is_empty():
		return
	image.visible = false
	var animation := SwfTimelinePlayer.new()
	animation.name = "TankAnimation"
	animation.timeline_path = animation_path
	animation.position = image.position + image.size * 0.5
	parent.add_child(animation)
	var stage_size := animation.get_stage_size()
	if stage_size.x > 0.0 and stage_size.y > 0.0:
		var fit := minf(
			image.size.x / stage_size.x,
			image.size.y / stage_size.y
		)
		animation.scale = Vector2(
			-fit if flip_h else fit,
			fit
		)
	animation.play()


func _attach_tank_head_animation(
	parent: Control,
	image: TextureRect,
	participant: Dictionary,
	flip_h: bool
) -> bool:
	var animation_path := PvpTankHeadCatalog.animation_path(
		String(participant.get("tank_key", "")),
		String(participant.get("equipped_skin_key", ""))
	)
	if animation_path.is_empty():
		return false
	image.visible = false
	var animation := SwfTimelinePlayer.new()
	animation.name = "TankHeadAnimation"
	animation.timeline_path = animation_path
	animation.position = image.position + image.size * 0.5
	parent.add_child(animation)
	var stage_size := animation.get_stage_size()
	if stage_size.x > 0.0 and stage_size.y > 0.0:
		# This is display placement only; the original head SWF is untouched.
		var fit := minf(image.size.x / stage_size.x, image.size.y / stage_size.y)
		animation.scale = Vector2(-fit if flip_h else fit, fit)
	else:
		animation.scale = Vector2(-1.0 if flip_h else 1.0, 1.0)
	animation.play()
	return true


func _label(position: Vector2, size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.position = position
	label.size = size
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.18, 0.35, 1.0))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _enable_button_hover(button: TextureButton) -> void:
	button.mouse_entered.connect(_on_button_hover.bind(button, true))
	button.mouse_exited.connect(_on_button_hover.bind(button, false))
	button.button_down.connect(_on_button_down.bind(button))
	button.button_up.connect(_on_button_up.bind(button))


func _on_button_hover(button: TextureButton, entered: bool) -> void:
	if button.disabled:
		return
	_tween_button_color(
		button,
		Color(1.25, 1.25, 1.25, 1.0) if entered else Color.WHITE
	)


func _on_button_down(button: TextureButton) -> void:
	if not button.disabled:
		_tween_button_color(button, Color(0.78, 0.78, 0.78, 1.0))


func _on_button_up(button: TextureButton) -> void:
	if button.disabled:
		return
	_tween_button_color(
		button,
		Color(1.25, 1.25, 1.25, 1.0)
		if button.is_hovered()
		else Color.WHITE
	)


func _tween_button_color(button: TextureButton, color: Color) -> void:
	var tween := button.create_tween()
	tween.tween_property(button, "self_modulate", color, 0.1)


func _blue_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.62, 0.84, 0.96)
	style.border_color = Color(0.88, 0.97, 1.0)
	style.set_border_width_all(4)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0.0, 0.12, 0.2, 0.7)
	style.shadow_size = 8
	return style


func _inner_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.35, 0.58, 0.82)
	style.border_color = Color(0.55, 0.95, 1.0)
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	return style


func _team_card_style(is_enemy: bool, occupied: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = (
		Color(0.0, 0.56, 0.72, 0.94)
		if occupied
		else Color(0.0, 0.42, 0.58, 0.72)
	)
	style.border_color = (
		Color(1.0, 0.32, 0.4)
		if is_enemy
		else Color(0.42, 1.0, 0.5)
	)
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	return style
