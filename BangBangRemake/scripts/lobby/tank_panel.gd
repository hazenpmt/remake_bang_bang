extends Control

signal primary_tank_changed(lobby_data: Dictionary)
signal military_rank_requested

const ASSET_ROOT := "res://assets/ui/tank/"
const PanelTransitionHelper := preload("res://scripts/ui/panel_transition.gd")
const AssetPathAliases := preload("res://scripts/data/asset_path_aliases.gd")
const MAIN_SIZE := Vector2(1005.0, 608.0)
const UPGRADE_SIZE := Vector2(630.0, 519.0)
const SKIN_SIZE := Vector2(995.0, 570.0)

const TANK_PAGE_COUNT := 3
const TANK_CELL_COUNT := 13
const TANK_CELL_SELECT_TIMELINE := \
	"res://assets/animations/tank_cell_select_compact/timeline.json"
const TANK_CELL_SELECT_SCALE := 1.0
const TANK_CELL_POSITIONS := [
	Vector2(8.0, 108.0),
	Vector2(108.0, 108.0),
	Vector2(208.0, 108.0),
	Vector2(58.0, 190.0),
	Vector2(158.0, 190.0),
	Vector2(8.0, 272.0),
	Vector2(108.0, 272.0),
	Vector2(208.0, 272.0),
	Vector2(58.0, 354.0),
	Vector2(158.0, 354.0),
	Vector2(8.0, 436.0),
	Vector2(108.0, 436.0),
	Vector2(208.0, 436.0),
]

const TANK_KEYS := [
	"gangtiexia03",
	"page_1_slot_02",
	"page_1_slot_03",
	"page_1_slot_04",
	"page_1_slot_05",
	"page_1_slot_06",
	"page_1_slot_07",
	"page_1_slot_08",
	"page_1_slot_09",
	"page_1_slot_10",
	"page_1_slot_11",
	"page_1_slot_12",
	"page_1_slot_13",
	"page_2_slot_01",
	"page_2_slot_02",
	"page_2_slot_03",
	"page_2_slot_04",
	"page_2_slot_05",
	"page_2_slot_06",
	"page_2_slot_07",
	"page_2_slot_08",
	"page_2_slot_09",
	"page_2_slot_10",
	"page_2_slot_11",
	"page_2_slot_12",
	"page_2_slot_13",
	"page_3_slot_01",
	"page_3_slot_02",
	"page_3_slot_03",
	"page_3_slot_04",
	"page_3_slot_05",
	"page_3_slot_06",
	"page_3_slot_07",
	"page_3_slot_08",
	"page_3_slot_09",
	"page_3_slot_10",
	"page_3_slot_11",
	"page_3_slot_12",
	"page_3_slot_13",
]

const MAIN_TAB_ASSETS := [
	["main_tab_all.png", "main_tab_all_selected.png"],
	["main_tab_dps.png", "main_tab_dps_selected.png"],
	["main_tab_tank.png", "main_tab_tank_selected.png"],
	["main_tab_assist.png", "main_tab_assist_selected.png"],
]
const MAIN_TAB_ROLE_KEYS := ["all", "dps", "tanker", "support"]

const SKIN_TAB_ASSETS := [
	["skin_tab_all.png", "skin_tab_all_selected.png", "all"],
	["skin_tab_a.png", "skin_tab_a_selected.png", "A"],
	["skin_tab_s.png", "skin_tab_s_selected.png", "S"],
	["skin_tab_ss.png", "skin_tab_ss_selected.png", "SS"],
	["skin_tab_sss.png", "skin_tab_sss_selected.png", "SSS"],
]
const SKIN_TAB_BACKGROUND_ASSETS := [
	"skin_tab_background.png",
	"skin_tab_background_selected.png",
]

const SKIN_QUALITY_ASSETS := [
	["quality_a.png", "quality_a_selected.png"],
	["quality_s.png", "quality_s_selected.png"],
	["quality_ss.png", "quality_ss_selected.png"],
	["quality_sss.png", "quality_sss_selected.png"],
]

const SKIN_CARD_COUNT := 9
const SKIN_CARD_STEP := 235.0
const SKIN_CONTENT_PADDING := 6.0
const SKIN_SCROLL_ARROW_WIDTH := 19.0
const SKIN_SCROLL_STEP := 120.0
const SKIN_ATTRIBUTE_INACTIVE_COLOR := Color(0.58, 0.76, 0.84, 1.0)
const SKIN_ATTRIBUTE_ACTIVE_COLOR := Color(1.0, 0.82, 0.08, 1.0)
const SKIN_ATTRIBUTE_ACTIVE_OUTLINE := Color(0.0, 0.18, 0.34, 1.0)
const SKIN_ATTRIBUTE_INACTIVE_OUTLINE := Color(0.0, 0.14, 0.28, 1.0)
const TANK_CELL_UNOWNED_MATERIAL := preload(
	"res://shaders/tank_cell_unowned_color_match.tres"
)
const DAMAGE_TYPE_PHYSICAL_TEXTURE := preload(
	"res://assets/ui/tank/ico_tank_physics.png"
)
const DAMAGE_TYPE_ENERGY_TEXTURE := preload(
	"res://assets/ui/tank/ico_tank_energy.png"
)
const INFO_STAT_KEYS := [
	"hit_points",
	"basic_attack_damage",
	"penetration",
	"physical_armor",
	"energy_shield",
	"move_speed",
	"fire_rate",
	"attack_range",
]
const IRONMAN_LEVEL_1_BASE_STATS := {
	"hit_points": 2325,
	"basic_attack_damage": 238,
	"penetration": 30,
	"physical_armor": 150,
	"energy_shield": 150,
	"move_speed": 170,
	"fire_rate": 66,
	"attack_range": 480,
}
const SKIN_CARD_DATA := [
	["Iron Man", "", "gangtiexia03_default"],
	["Iron Man 2", "A", "gangtiexia04"],
	["Iron Man 3", "S", "gangtiexia05"],
	["MK-42", "SS", "gangtiexia_pf04"],
	["Bão Sa Mạc", "SS", "gangtiexia_pf01"],
	["Patriot", "SS", "gangtiexia_pf05"],
	["Dũng Sĩ Bình Minh", "SS", "gangtiexia_pf03"],
	["Chiến Cảnh Tương Lai", "SS", "gangtiexia_pf02"],
	["Hồng Liên (Iron Man)", "SSS", "gangtiexia_pf06"],
]

const TANK_LEVEL_ASSETS := [
	"tank_level_1.png",
	"tank_level_2.png",
	"tank_level_3.png",
	"tank_level_4.png",
	"tank_level_5.png",
	"tank_level_6.png",
]

const SKILL_ROUNDED_SHADER := preload("res://shaders/rounded_texture_mask.gdshader")
const TankSkinCatalog := preload("res://scripts/lobby/tank_skin_catalog.gd")
const IRONMAN_SKILL_TOOLTIP_DATA := preload(
	"res://scripts/data/ironman_skill_tooltip_data.gd"
)
const IRONMAN_SKILL_TOOLTIPS := IRONMAN_SKILL_TOOLTIP_DATA.SKILL_TOOLTIPS
const TANK_CELL_TEXTURES: Dictionary = {
	"gangtiexia03": preload("res://assets/ui/tank/tank_ironman_reward.png"),
}

var _built := false
var _main_view: Control
var _panel_transition: Tween
var _upgrade_overlay: Control
var _skin_overlay: Control
var _tank_name_label: Label
var _tank_level_label: TextureRect
var _upgrade_level_from: Label
var _upgrade_level_to: Label
var _upgrade_status: Label
var _main_info_text: Label
var _main_stats_labels: TextureRect
var _main_stats_values: Control
var _main_stats_base_values: Array[Label] = []
var _main_stats_bonus_values: Array[Label] = []
var _main_stats_additional_percent: Label
var _military_rank_button: TextureButton
var _main_radar: TextureRect
var _main_tank_image: TextureRect
var _skin_preview_image: TextureRect
var _skin_preview_frame: TextureRect
var _main_tank_animation: SwfTimelinePlayer
var _skin_preview_animation: SwfTimelinePlayer
var _damage_type_icon: TextureRect
var _damage_type_tooltip: PanelContainer
var _damage_type_tooltip_text: Label
var _info_description_assets: Control
var _main_tab_buttons: Array[TextureButton] = []
var _rent_tab: TextureButton
var _info_buttons: Array[TextureButton] = []
var _info_button_labels: Array[TextureRect] = []
var _skin_tab_buttons: Array[TextureButton] = []
var _skin_tab_labels: Array[TextureRect] = []
var _skin_quality_buttons: Array[TextureButton] = []
var _skin_cards: Array[Dictionary] = []
var _skin_empty_label: Label
var _skin_viewport: Control
var _skin_content: Control
var _skin_scrollbar: Control
var _skin_scroll_thumb: TextureRect
var _skin_scroll_value := 0.0
var _skin_scroll_max_value := 0.0
var _skin_scroll_dragging := false
var _skin_scroll_drag_offset := 0.0
var _skin_equip_busy := false
var _skin_attribute_total_attack: Label
var _skin_attribute_quality_nodes: Dictionary = {}
var _skin_attribute_other_nodes: Dictionary = {}
var _tank_cells: Array[Control] = []
var _tank_cell_backgrounds: Array[TextureRect] = []
var _tank_cell_images: Array[TextureRect] = []
var _tank_cell_skin_frames: Array[TextureRect] = []
var _tank_cell_animations: Array = []
var _tank_level_badges: Array[TextureRect] = []
var _tank_level_labels: Array[TextureRect] = []
var _primary_badges: Array[TextureRect] = []
var _tank_cell_selection_clip: Control
var _tank_cell_selection: SwfTimelinePlayer
var _page_buttons: Array[TextureButton] = []
var _page_number_labels: Array[Label] = []
var _page_next_button: TextureButton
var _selected_tank_cell := 0
var _selected_tank_global_index := 0
var _current_tank_page := 0
var _tank_level := 1
var _tank_name := "Iron Man"
var _primary_tank_key := ""
var _owned_tanks_by_key: Dictionary = {}
var _display_tank_keys: Array[String] = []
var _selected_main_role := "all"
var _preview_equipped_skin_key := "gangtiexia03_default"
var _set_primary_button: TextureButton
var _primary_selected_label: TextureRect
var _set_primary_busy := false
var _skill_icons: Array[TextureRect] = []
var _skill_tooltip: PanelContainer
var _skill_tooltip_text: RichTextLabel


func _ready() -> void:
	if has_node("MainView") and has_node("UpgradeOverlay") and has_node("SkinOverlay"):
		_bind_scene_nodes()
	else:
		_build()
	if not GameSession.lobby_data_changed.is_connected(_on_lobby_data_changed):
		GameSession.lobby_data_changed.connect(_on_lobby_data_changed)
	_setup_skill_tooltips()
	if get_tree().current_scene == self:
		call_deferred("_open_standalone_preview")
	else:
		visible = false


func _process(_delta: float) -> void:
	if (
		_skill_tooltip != null
		and _skill_tooltip.visible
		and _main_view != null
	):
		_update_skill_tooltip_position()
	if (
		_damage_type_tooltip != null
		and _damage_type_tooltip.visible
		and _main_view != null
	):
		_update_damage_type_tooltip_position()


func _bind_scene_nodes() -> void:
	_built = true
	_main_view = get_node("MainView") as Control
	_upgrade_overlay = get_node("UpgradeOverlay") as Control
	_skin_overlay = get_node("SkinOverlay") as Control
	_tank_name_label = _main_view.get_node("TankName") as Label
	_tank_level_label = _main_view.get_node("TankLevel") as TextureRect
	_upgrade_level_from = _upgrade_overlay.get_node("TankLevelUp/LevelFrom") as Label
	_upgrade_level_to = _upgrade_overlay.get_node("TankLevelUp/LevelTo") as Label
	_upgrade_status = _upgrade_overlay.get_node("TankLevelUp/Status") as Label
	_main_info_text = _main_view.get_node("InfoText") as Label
	_main_stats_labels = _main_view.get_node("InfoStatsLabels") as TextureRect
	_main_stats_values = _main_view.get_node("InfoStatsValues") as Control
	_main_stats_base_values.clear()
	_main_stats_bonus_values.clear()
	var base_values := _main_stats_values.get_node("BaseValues") as Control
	var bonus_values := _main_stats_values.get_node("BonusValues") as Control
	for stat_index in INFO_STAT_KEYS.size():
		_main_stats_base_values.append(
			base_values.get_node("Value%d" % stat_index) as Label
		)
		if stat_index < 5:
			_main_stats_bonus_values.append(
				bonus_values.get_node("Value%d" % stat_index) as Label
			)
	_main_stats_additional_percent = _main_stats_values.get_node(
		"AdditionalPercent"
	) as Label
	_military_rank_button = _main_stats_values.get_node(
		"BtnMilitaryRank"
	) as TextureButton
	_connect_if_needed(
		_military_rank_button.pressed,
		_on_military_rank_pressed
	)
	_main_radar = _main_view.get_node("Radar") as TextureRect
	_main_tank_image = _main_view.get_node("MainTankImage") as TextureRect
	_skin_preview_image = _main_view.get_node("SkinPreviewImage") as TextureRect
	_skin_preview_frame = _main_view.get_node("SkinPreviewFrame") as TextureRect
	_damage_type_icon = _main_view.get_node("DamageTypeIcon") as TextureRect
	_damage_type_tooltip = _main_view.get_node(
		"DamageTypeTooltip"
	) as PanelContainer
	_damage_type_tooltip_text = _damage_type_tooltip.get_node("Text") as Label
	_damage_type_tooltip.hide()
	_connect_if_needed(
		_damage_type_icon.mouse_entered,
		_show_damage_type_tooltip
	)
	_connect_if_needed(
		_damage_type_icon.mouse_exited,
		_hide_damage_type_tooltip
	)
	_info_description_assets = _main_view.get_node("InfoDescriptionAssets") as Control
	_rent_tab = _main_view.get_node("MainTabRent") as TextureButton
	_skin_empty_label = _skin_overlay.get_node("TankSkin/EmptyLabel") as Label
	_skin_viewport = _skin_overlay.get_node("TankSkin/SkinViewport") as Control
	# Scene để hở vùng clip nhằm nhìn/căn được cả chín preview trong editor.
	# Khi chạy game mới bật clip để danh sách chỉ hiện trong khung và cuộn ngang.
	_skin_viewport.clip_contents = true
	_skin_content = _skin_viewport.get_node("SkinContent") as Control
	_skin_scrollbar = _skin_overlay.get_node("TankSkin/SkinScroll") as Control
	_skin_scroll_thumb = _skin_scrollbar.get_node("Thumb") as TextureRect
	_connect_if_needed(
		(_skin_scrollbar.get_node("LeftButton") as TextureButton).pressed,
		_scroll_skin_by.bind(-SKIN_SCROLL_STEP)
	)
	_connect_if_needed(
		(_skin_scrollbar.get_node("RightButton") as TextureButton).pressed,
		_scroll_skin_by.bind(SKIN_SCROLL_STEP)
	)
	_connect_if_needed(
		(_skin_scrollbar.get_node("Interaction") as Control).gui_input,
		_on_skin_scroll_gui_input
	)
	_connect_if_needed(_skin_viewport.gui_input, _on_skin_viewport_gui_input)

	_main_tab_buttons.clear()
	for index in MAIN_TAB_ASSETS.size():
		var button := _main_view.get_node("MainTab%d" % index) as TextureButton
		_main_tab_buttons.append(button)
		_connect_if_needed(button.pressed, _on_main_tab_pressed.bind(index))
	_connect_if_needed(_rent_tab.pressed, _on_main_tab_pressed.bind(4))

	_tank_cells.clear()
	_tank_cell_backgrounds.clear()
	_tank_cell_images.clear()
	_tank_cell_skin_frames.clear()
	_tank_cell_animations.clear()
	_tank_level_badges.clear()
	_tank_level_labels.clear()
	_primary_badges.clear()
	for index in TANK_CELL_COUNT:
		var cell := _main_view.get_node("TankCell%02d" % (index + 1)) as Control
		_tank_cells.append(cell)
		_tank_cell_backgrounds.append(cell.get_node("OwnershipBackground") as TextureRect)
		_tank_cell_images.append(cell.get_node("TankImage") as TextureRect)
		_tank_cell_skin_frames.append(cell.get_node("SkinFrame") as TextureRect)
		_tank_cell_animations.append(
			cell.get_node_or_null("TankAnimation") as SwfTimelinePlayer
		)
		_tank_level_badges.append(cell.get_node("LevelBadge") as TextureRect)
		_tank_level_labels.append(cell.get_node("LevelNumber") as TextureRect)
		_primary_badges.append(cell.get_node("PrimaryBadge") as TextureRect)
		_connect_if_needed(cell.gui_input, _on_tank_cell_gui_input.bind(index))
	_sync_tank_cell_display_scale()
	_tank_cell_selection_clip = _main_view.get_node("TankCellSelectionClip") as Control
	_tank_cell_selection = _tank_cell_selection_clip.get_node("TankCellSelection") as SwfTimelinePlayer
	_select_tank_cell(_selected_tank_cell)

	_page_buttons.clear()
	_page_number_labels.clear()
	for index in TANK_PAGE_COUNT:
		var page_button := _main_view.get_node("PageButton%d" % index) as TextureButton
		_page_buttons.append(page_button)
		_page_number_labels.append(page_button.get_node("PageNumber") as Label)
		_connect_if_needed(page_button.pressed, _set_tank_page.bind(index))
	_page_next_button = _main_view.get_node("PageNext") as TextureButton
	_connect_if_needed(_page_next_button.pressed, _show_next_tank_page)

	_info_buttons.clear()
	_info_button_labels.clear()
	for index in 2:
		var button := _main_view.get_node("InfoTab%d" % index) as TextureButton
		_info_buttons.append(button)
		_info_button_labels.append(button.get_node("LabelTexture") as TextureRect)
		_connect_if_needed(button.pressed, _set_info_mode.bind(index))

	_skin_tab_buttons.clear()
	_skin_tab_labels.clear()
	for index in SKIN_TAB_ASSETS.size():
		var button := _skin_overlay.get_node("TankSkin/SkinTab%d" % index) as TextureButton
		_skin_tab_buttons.append(button)
		_skin_tab_labels.append(button.get_node("LabelTexture") as TextureRect)
		_connect_if_needed(button.pressed, _on_skin_tab_pressed.bind(index))

	_skin_quality_buttons.clear()
	for index in SKIN_QUALITY_ASSETS.size():
		var quality_button := _main_view.get_node("SkinQuality%d" % index) as TextureButton
		_skin_quality_buttons.append(quality_button)
		_connect_if_needed(quality_button.pressed, _open_skin_quality.bind(index))

	var attribute_panel := _skin_overlay.get_node(
		"TankSkin/SkinAttributePanel"
	) as Control
	_skin_attribute_total_attack = attribute_panel.get_node(
		"TotalAttackPercent"
	) as Label
	_skin_attribute_quality_nodes = {
		"quality_a": {
			"labels": [
				attribute_panel.get_node("QualityARequirement") as Label,
				attribute_panel.get_node("QualityABonus") as Label,
			],
			"status": attribute_panel.get_node("QualityAStatus") as TextureRect,
		},
		"quality_s": {
			"labels": [
				attribute_panel.get_node("QualitySRequirement") as Label,
				attribute_panel.get_node("QualitySBonus") as Label,
			],
			"status": attribute_panel.get_node("QualitySStatus") as TextureRect,
		},
		"quality_ss": {
			"labels": [
				attribute_panel.get_node("QualitySSRequirement") as Label,
				attribute_panel.get_node("QualitySSBonus") as Label,
			],
			"status": attribute_panel.get_node("QualitySSStatus") as TextureRect,
		},
		"quality_sss": {
			"labels": [
				attribute_panel.get_node("QualitySSSRequirement") as Label,
				attribute_panel.get_node("QualitySSSBonus") as Label,
			],
			"status": attribute_panel.get_node("QualitySSSStatus") as TextureRect,
		},
	}
	_skin_attribute_other_nodes = {
		"distinct_2": [
			attribute_panel.get_node("Other2Requirement") as Label,
			attribute_panel.get_node("Other2Bonus") as Label,
		],
		"distinct_3_sss": [
			attribute_panel.get_node("Other3Line1") as Label,
			attribute_panel.get_node("Other3Line2") as Label,
			attribute_panel.get_node("Other3Bonus") as Label,
		],
		"distinct_4": [
			attribute_panel.get_node("Other4Requirement") as Label,
			attribute_panel.get_node("Other4Bonus") as Label,
		],
	}

	_skin_cards.clear()
	for index in SKIN_CARD_COUNT:
		var card := _skin_content.get_node("SkinCard%d" % index) as Control
		var use_button := card.get_node("UseButton") as TextureButton
		_skin_cards.append({
			"node": card,
			"quality": String(SKIN_CARD_DATA[index][1]),
			"skin_key": String(SKIN_CARD_DATA[index][2]),
			"equipped": card.get_node("Equipped") as TextureRect,
			"use_button": use_button,
		})
		_connect_if_needed(
			use_button.pressed,
			_on_use_skin_pressed.bind(String(SKIN_CARD_DATA[index][2]))
		)

	_connect_if_needed((_main_view.get_node("BtnClose") as TextureButton).pressed, close)
	_connect_if_needed((_main_view.get_node("BtnLevelUp") as TextureButton).pressed, _open_upgrade)
	_connect_if_needed((_main_view.get_node("BtnSkin") as TextureButton).pressed, _open_skin)
	_set_primary_button = _main_view.get_node("BtnSetPrimary") as TextureButton
	_primary_selected_label = _main_view.get_node("PrimarySelectedLabel") as TextureRect
	_connect_if_needed(_set_primary_button.pressed, _on_set_primary_pressed)
	_connect_if_needed(
		(_upgrade_overlay.get_node("TankLevelUp/BtnClose") as TextureButton).pressed,
		_close_upgrade
	)
	_connect_if_needed(
		(_upgrade_overlay.get_node("TankLevelUp/BtnConfirm") as TextureButton).pressed,
		_on_upgrade_request
	)
	_connect_if_needed(
		(_skin_overlay.get_node("TankSkin/BtnClose") as TextureButton).pressed,
		_close_skin
	)
	_set_info_mode(0)
	_set_skin_quality(-1)
	_set_tank_page(0)


func _connect_if_needed(signal_value: Signal, callback: Callable) -> void:
	if not signal_value.is_connected(callback):
		signal_value.connect(callback)


func _open_standalone_preview() -> void:
	open()
	var arguments := OS.get_cmdline_user_args()
	if "--preview-upgrade" in arguments:
		_open_upgrade()
	elif "--preview-skin" in arguments:
		_open_skin()
	elif "--preview-sequence" in arguments:
		_run_preview_sequence()


func _run_preview_sequence() -> void:
	await get_tree().create_timer(1.0).timeout
	_open_upgrade()
	await get_tree().create_timer(1.0).timeout
	_close_upgrade()
	_open_skin()


func open() -> void:
	if not _built:
		_build()
	_refresh_server_tank()
	_main_view.visible = true
	_upgrade_overlay.visible = false
	_skin_overlay.visible = false
	_hide_damage_type_tooltip()
	move_to_front()
	_panel_transition = PanelTransitionHelper.play_open(
		self,
		_main_view,
		_panel_transition
	)


func close() -> void:
	_hide_damage_type_tooltip()
	_hide_skill_tooltip()
	_panel_transition = PanelTransitionHelper.play_close(
		self,
		_main_view,
		_panel_transition
	)


func is_open() -> bool:
	return visible


func _input(event: InputEvent) -> void:
	if not _skin_scroll_dragging or _skin_scrollbar == null:
		return
	if event is InputEventMouseMotion:
		_set_skin_scroll_from_thumb_position(
			_skin_scrollbar.get_local_mouse_position().x - _skin_scroll_drag_offset
		)
	elif (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and not event.pressed
	):
		_skin_scroll_dragging = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	if _upgrade_overlay.visible:
		_upgrade_overlay.visible = false
	elif _skin_overlay.visible:
		_skin_overlay.visible = false
	else:
		close()
	get_viewport().set_input_as_handled()


func _build() -> void:
	if _built:
		return
	_built = true

	var dim := ColorRect.new()
	dim.name = "DimBackground"
	dim.color = Color(0.0, 0.02, 0.05, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_build_main_view()
	_sync_tank_cell_display_scale()
	_build_upgrade_overlay()
	_build_skin_overlay()


func _build_main_view() -> void:
	_main_view = _centered_control(self, "MainView", MAIN_SIZE)
	var frame := _add_texture_rect(_main_view, "tank_frame.png", Vector2.ZERO, MAIN_SIZE)
	frame.name = "Frame"
	var title := _add_texture_rect(_main_view, "title_tank.png", Vector2(388.0, 0.0))
	title.name = "Title"
	var close_button := _add_texture_button(
		_main_view,
		"close.png",
		Vector2(935.0, 3.0),
		Vector2(46.0, 46.0),
		close
	)
	close_button.name = "BtnClose"

	for index in MAIN_TAB_ASSETS.size():
		var button := _add_texture_button(
			_main_view,
			MAIN_TAB_ASSETS[index][0],
			Vector2(20.0 + index * 75.0, 62.0),
			Vector2(72.0, 35.0),
			_on_main_tab_pressed.bind(index)
		)
		button.name = "MainTab%d" % index
		_main_tab_buttons.append(button)

	_rent_tab = _add_texture_button(
		_main_view,
		"tab_rent.png",
		Vector2(320.0, 62.0),
		Vector2(72.0, 35.0),
		_on_main_tab_pressed.bind(4)
	)
	_rent_tab.name = "MainTabRent"
	_set_main_tab(0)

	_build_tank_grid()
	_build_tank_center()
	_build_main_info()


func _build_tank_grid() -> void:
	for index in TANK_CELL_COUNT:
		var cell := Control.new()
		cell.name = "TankCell%02d" % (index + 1)
		cell.position = TANK_CELL_POSITIONS[index]
		cell.size = Vector2(104.0, 117.0)
		cell.clip_contents = false
		cell.mouse_filter = Control.MOUSE_FILTER_STOP
		cell.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_main_view.add_child(cell)
		_tank_cells.append(cell)
		_connect_if_needed(cell.gui_input, _on_tank_cell_gui_input.bind(index))

		var background := _add_texture_rect(
			cell,
			"tank_cell_owned.png" if index == 0 else "tank_cell_unowned.png",
			Vector2.ZERO,
			cell.size
		)
		background.name = "OwnershipBackground"
		background.material = null if index == 0 else TANK_CELL_UNOWNED_MATERIAL
		_tank_cell_backgrounds.append(background)
		var tank_image := TextureRect.new()
		tank_image.name = "TankImage"
		tank_image.position = Vector2.ZERO
		tank_image.size = Vector2(104.0, 117.0)
		tank_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tank_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tank_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tank_image.z_index = 1
		cell.add_child(tank_image)
		_tank_cell_images.append(tank_image)
		_tank_cell_animations.append(null)
		var skin_frame := TextureRect.new()
		skin_frame.name = "SkinFrame"
		skin_frame.position = Vector2(6.5, 6.5)
		skin_frame.size = Vector2(91.0, 104.0)
		skin_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		skin_frame.z_index = 0
		skin_frame.visible = false
		cell.add_child(skin_frame)
		_tank_cell_skin_frames.append(skin_frame)

		var level_badge := _add_texture_rect(
			cell,
			"tank_level_badge_owned.png" if index == 0 else "tank_level_badge_unowned.png",
			Vector2(31.5, 94.0),
			Vector2(41.0, 23.0)
		)
		level_badge.name = "LevelBadge"
		level_badge.z_index = 2
		_tank_level_badges.append(level_badge)
		var level_number := _add_texture_rect(
			cell,
			"battle_level_numbers.png",
			Vector2(48.0, 99.0),
			Vector2(8.0, 12.0)
		)
		level_number.texture = _digit_texture(1)
		level_number.name = "LevelNumber"
		level_number.z_index = 2
		_tank_level_labels.append(level_number)
		var primary_badge := _add_texture_rect(
			cell,
			"tank_primary_badge.png",
			Vector2(22.0, 0.0)
		)
		primary_badge.name = "PrimaryBadge"
		primary_badge.z_index = 3
		primary_badge.visible = index == 0
		_primary_badges.append(primary_badge)

	_tank_cell_selection_clip = Control.new()
	_tank_cell_selection_clip.name = "TankCellSelectionClip"
	_tank_cell_selection_clip.position = TANK_CELL_POSITIONS[0]
	_tank_cell_selection_clip.size = Vector2(104.0, 117.0)
	_tank_cell_selection_clip.clip_contents = true
	_tank_cell_selection_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_view.add_child(_tank_cell_selection_clip)

	_tank_cell_selection = SwfTimelinePlayer.new()
	_tank_cell_selection.name = "TankCellSelection"
	_tank_cell_selection.timeline_path = TANK_CELL_SELECT_TIMELINE
	_tank_cell_selection.scale = Vector2.ONE * TANK_CELL_SELECT_SCALE
	_tank_cell_selection.position = Vector2(52.0, 58.5)
	_tank_cell_selection.z_index = 0
	_tank_cell_selection_clip.add_child(_tank_cell_selection)
	_select_tank_cell(0)
	_build_tank_page_controls()


func _build_tank_page_controls() -> void:
	_page_buttons.clear()
	_page_number_labels.clear()
	var positions := [Vector2(112.0, 565.0), Vector2(144.0, 565.0), Vector2(176.0, 565.0)]
	for index in TANK_PAGE_COUNT:
		var button := _add_texture_button(
			_main_view,
			"pager_selected.png" if index == 0 else "pager_blue.png",
			positions[index],
			Vector2(24.0, 25.0),
			_set_tank_page.bind(index)
		)
		button.name = "PageButton%d" % index
		var number := _add_label(
			button,
			Vector2.ZERO,
			Vector2(24.0, 25.0),
			str(index + 1),
			12,
			Color.WHITE,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		number.name = "PageNumber"
		_page_buttons.append(button)
		_page_number_labels.append(number)
	_page_next_button = _add_texture_button(
		_main_view,
		"pager_next.png",
		Vector2(207.0, 563.0),
		Vector2(33.0, 29.0),
		_show_next_tank_page
	)
	_page_next_button.name = "PageNext"


func _build_tank_center() -> void:
	_tank_level_label = _add_texture_rect(
		_main_view,
		"tank_level_1.png",
		Vector2(462.5, 43.5)
	)
	_tank_level_label.name = "TankLevel"
	_add_texture_rect(_main_view, "tank_name_bg.png", Vector2(405.0, 82.0))
	_tank_name_label = _add_label(
		_main_view,
		Vector2(405.0, 82.0),
		Vector2(159.0, 32.0),
		"Iron Man",
		17,
		Color.WHITE,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_tank_name_label.name = "TankName"

	_add_texture_rect(
		_main_view,
		"tank_booth.png",
		Vector2(372.0, 218.0),
		Vector2(230.0, 166.0)
	)
	_add_texture_rect(
		_main_view,
		"tank_ironman_reward.png",
		Vector2(327.0, 111.0),
		Vector2(200.0, 200.0)
	)
	_set_primary_button = _add_texture_button(
		_main_view,
		"btn_set_primary.png",
		Vector2(455.0, 348.0),
		Vector2(64.0, 30.0),
		_on_set_primary_pressed
	)
	_set_primary_button.name = "BtnSetPrimary"
	_set_primary_button.visible = false
	_primary_selected_label = _add_texture_rect(
		_main_view,
		"label_primary_selected.png",
		Vector2(464.0, 354.0)
	)
	_primary_selected_label.name = "PrimarySelectedLabel"

	var progress_stage := _add_texture_rect(
		_main_view,
		"tank_progress_stage.png",
		Vector2(354.0, 392.0)
	)
	progress_stage.name = "ProgressStage"
	var skill_paths := [
		"skill_ironman_1.jpg",
		"skill_ironman_2.jpg",
		"skill_ironman_3.jpg",
	]
	var skill_material := ShaderMaterial.new()
	skill_material.shader = SKILL_ROUNDED_SHADER
	for index in skill_paths.size():
		_add_texture_rect(
			_main_view,
			"skill_slot.png",
			Vector2(389.0 + index * 64.0, 412.0),
			Vector2(58.0, 57.0)
		)
		var skill_icon := _add_texture_rect(
			_main_view,
			skill_paths[index],
			Vector2(393.0 + index * 64.0, 416.0),
			Vector2(50.0, 50.0)
		)
		skill_icon.name = "SkillIcon%d" % (index + 1)
		skill_icon.material = skill_material

	_add_label(
		_main_view,
		Vector2(377.0, 476.0),
		Vector2(225.0, 24.0),
		"Lv Tank đã có: LV.1",
		14,
		Color.WHITE,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	var level_up_button := _add_texture_button(
		_main_view,
		"btn_level_up.png",
		Vector2(418.0, 507.0),
		Vector2(133.0, 47.0),
		_open_upgrade
	)
	level_up_button.name = "BtnLevelUp"


func _build_main_info() -> void:
	var info_panel := _add_texture_rect(_main_view, "info_panel.png", Vector2(674.0, 103.0))
	info_panel.name = "InfoPanel"

	for index in 2:
		var button := _add_texture_button(
			_main_view,
			"tab_bg.png",
			Vector2(696.0 + index * 76.0, 64.0),
			Vector2(72.0, 35.0),
			_set_info_mode.bind(index)
		)
		var label := _add_texture_rect(
			button,
			"detail_desc.png" if index == 0 else "detail_stats.png",
			Vector2(6.0, 8.0),
			Vector2(60.0, 17.0)
		)
		button.name = "InfoTab%d" % index
		label.name = "LabelTexture"
		_info_buttons.append(button)
		_info_button_labels.append(label)

	_main_info_text = _add_label(
		_main_view,
		Vector2(696.0, 108.0),
		Vector2(250.0, 128.0),
		"",
		16,
		Color.WHITE,
		HORIZONTAL_ALIGNMENT_LEFT
	)
	_main_info_text.name = "InfoText"
	_main_info_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_main_info_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_main_info_text.add_theme_constant_override("line_spacing", 5)
	_main_stats_labels = _add_texture_rect(
		_main_view,
		"info_stats_labels.png",
		Vector2(696.0, 108.0)
	)
	_main_stats_labels.name = "InfoStatsLabels"
	_main_stats_labels.visible = false
	_main_radar = _add_texture_rect(
		_main_view,
		"radar_bg.png",
		Vector2(750.0, 218.0)
	)
	_main_radar.name = "Radar"
	_build_info_description_assets()

	var skin_cell_background := _add_texture_rect(
		_main_view,
		"skin_cell_bg.png",
		Vector2(744.0, 382.0)
	)
	skin_cell_background.name = "SkinCellBackground"
	_skin_preview_image = _add_texture_rect(
		_main_view,
		"tank_ironman_reward.png",
		Vector2(665.0, 318.0),
		Vector2(200.0, 200.0)
	)
	_skin_preview_image.name = "SkinPreviewImage"
	_skin_preview_image.z_index = 1
	_skin_preview_frame = TextureRect.new()
	_skin_preview_frame.name = "SkinPreviewFrame"
	_skin_preview_frame.position = Vector2(680.0, 427.5)
	_skin_preview_frame.size = Vector2(131.0, 108.0)
	_skin_preview_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skin_preview_frame.z_index = 0
	_skin_preview_frame.visible = false
	_main_view.add_child(_skin_preview_frame)
	var skin_button := _add_texture_button(
		_main_view,
		"btn_skin.png",
		Vector2(792.0, 500.0),
		Vector2(122.0, 43.0),
		_open_skin
	)
	skin_button.name = "BtnSkin"
	_build_skin_quality_buttons()
	_set_info_mode(0)
	_set_skin_quality(-1)


func _build_info_description_assets() -> void:
	_info_description_assets = Control.new()
	_info_description_assets.name = "InfoDescriptionAssets"
	_info_description_assets.position = Vector2.ZERO
	_info_description_assets.size = MAIN_SIZE
	_info_description_assets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_main_view.add_child(_info_description_assets)

	_add_texture_rect(
		_info_description_assets,
		"info_position_label.png",
		Vector2(688.0, 117.0)
	).name = "PositionLabel"
	_add_label(
		_info_description_assets,
		Vector2(769.0, 114.0),
		Vector2(180.0, 27.0),
		"Chiến sĩ đột tiến",
		15,
		Color.WHITE,
		HORIZONTAL_ALIGNMENT_LEFT
	).name = "PositionValue"
	_add_texture_rect(
		_info_description_assets,
		"info_divider.png",
		Vector2(690.0, 145.0)
	).name = "PositionDivider"

	_add_texture_rect(
		_info_description_assets,
		"info_difficulty_label.png",
		Vector2(688.0, 150.0)
	).name = "DifficultyLabel"
	_add_texture_rect(
		_info_description_assets,
		"difficulty_star_filled.png",
		Vector2(777.5, 139.0)
	).name = "DifficultyStar1"
	_add_texture_rect(
		_info_description_assets,
		"difficulty_star_empty.png",
		Vector2(802.5, 137.5)
	).name = "DifficultyStar2"
	_add_texture_rect(
		_info_description_assets,
		"difficulty_star_empty.png",
		Vector2(829.5, 137.5)
	).name = "DifficultyStar3"
	_add_texture_rect(
		_info_description_assets,
		"info_divider.png",
		Vector2(690.0, 179.0)
	).name = "DifficultyDivider"

	_add_texture_rect(
		_info_description_assets,
		"info_attribute_label.png",
		Vector2(798.0, 186.0)
	).name = "AttributeLabel"
	_add_texture_rect(
		_info_description_assets,
		"info_divider.png",
		Vector2(690.0, 209.0)
	).name = "AttributeDivider"

	var radar_labels := [
		["RadarDpsLabel", "radar_dps_label.png", Vector2(802.0, 207.0)],
		["RadarBurstLabel", "radar_burst_label.png", Vector2(889.0, 248.0)],
		["RadarMobilityLabel", "radar_mobility_label.png", Vector2(889.0, 316.0)],
		["RadarSupportLabel", "radar_support_label.png", Vector2(802.0, 361.0)],
		["RadarDefenseLabel", "radar_defense_label.png", Vector2(716.0, 316.0)],
		["RadarDurabilityLabel", "radar_durability_label.png", Vector2(716.0, 248.0)],
	]
	for label_data in radar_labels:
		_add_texture_rect(
			_info_description_assets,
			String(label_data[1]),
			label_data[2]
		).name = String(label_data[0])


func _build_skin_quality_buttons() -> void:
	_skin_quality_buttons.clear()
	var positions := [
		Vector2(859.0, 430.0),
		Vector2(925.0, 430.0),
		Vector2(859.0, 462.0),
		Vector2(925.0, 462.0),
	]
	for index in SKIN_QUALITY_ASSETS.size():
		var button := _add_texture_button(
			_main_view,
			String(SKIN_QUALITY_ASSETS[index][0]),
			positions[index],
			Vector2(66.0, 32.0),
			_open_skin_quality.bind(index)
		)
		button.name = "SkinQuality%d" % index
		_skin_quality_buttons.append(button)


func _build_upgrade_overlay() -> void:
	_upgrade_overlay = Control.new()
	_upgrade_overlay.name = "UpgradeOverlay"
	_upgrade_overlay.z_index = 10
	_upgrade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_upgrade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_upgrade_overlay.visible = false
	add_child(_upgrade_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.64)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_upgrade_overlay.add_child(dim)

	var popup := _centered_control(_upgrade_overlay, "TankLevelUp", UPGRADE_SIZE)
	_add_texture_rect(popup, "upgrade_bg.png", Vector2.ZERO)
	_add_texture_rect(popup, "upgrade_spiral.png", Vector2(15.0, 47.0))
	_add_texture_rect(popup, "upgrade_title.png", Vector2(275.0, 5.0))
	var close_button := _add_texture_button(
		popup,
		"close.png",
		Vector2(580.0, 6.0),
		Vector2(46.0, 46.0),
		_close_upgrade
	)
	close_button.name = "BtnClose"
	_add_texture_rect(popup, "upgrade_arrow.png", Vector2(216.0, 82.0))
	_add_texture_rect(
		popup,
		"tank_ironman_reward.png",
		Vector2(-30.0, 45.0),
		Vector2(200.0, 200.0)
	)

	_upgrade_level_from = _add_label(
		popup,
		Vector2(213.0, 48.0),
		Vector2(95.0, 30.0),
		"LV.1",
		18,
		Color(1.0, 0.88, 0.1),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_upgrade_level_from.name = "LevelFrom"
	_upgrade_level_to = _add_label(
		popup,
		Vector2(470.0, 48.0),
		Vector2(95.0, 30.0),
		"LV.2",
		18,
		Color(1.0, 0.88, 0.1),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_upgrade_level_to.name = "LevelTo"

	var stats := ["HP", "TC", "Giáp", "Khiên"]
	for index in stats.size():
		var y := 91.0 + index * 31.0
		_add_label(
			popup,
			Vector2(215.0, y),
			Vector2(72.0, 26.0),
			stats[index] + ":",
			15,
			Color.WHITE,
			HORIZONTAL_ALIGNMENT_RIGHT
		)
		_add_label(
			popup,
			Vector2(292.0, y),
			Vector2(70.0, 26.0),
			"—",
			15,
			Color.WHITE,
			HORIZONTAL_ALIGNMENT_CENTER
		)
		_add_label(
			popup,
			Vector2(490.0, y),
			Vector2(70.0, 26.0),
			"—",
			15,
			Color(0.9, 1.0, 0.9),
			HORIZONTAL_ALIGNMENT_CENTER
		)

	_add_texture_rect(popup, "upgrade_progress_title.png", Vector2(275.0, 235.0))
	_add_texture_rect(popup, "exp_bar.png", Vector2(43.0, 256.0), Vector2(543.0, 63.0))
	_add_label(
		popup,
		Vector2(270.0, 264.0),
		Vector2(90.0, 25.0),
		"0%",
		14,
		Color.WHITE,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_add_texture_rect(popup, "upgrade_items_title.png", Vector2(261.0, 332.0))

	for index in 2:
		var x := 218.0 + index * 104.0
		_add_texture_rect(popup, "item_box.png", Vector2(x, 356.0), Vector2(94.0, 87.0))
		_add_label(
			popup,
			Vector2(x, 401.0),
			Vector2(94.0, 25.0),
			"—",
			14,
			Color.WHITE,
			HORIZONTAL_ALIGNMENT_CENTER
		)

	_upgrade_status = _add_label(
		popup,
		Vector2(80.0, 442.0),
		Vector2(470.0, 28.0),
		"",
		13,
		Color(0.38, 0.38, 0.38),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_upgrade_status.name = "Status"
	var confirm_button := _add_texture_button(
		popup,
		"upgrade_lv_button.png",
		Vector2(255.0, 468.0),
		Vector2(120.0, 42.0),
		_on_upgrade_request
	)
	confirm_button.name = "BtnConfirm"


func _build_skin_overlay() -> void:
	_skin_overlay = Control.new()
	_skin_overlay.name = "SkinOverlay"
	_skin_overlay.z_index = 10
	_skin_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_skin_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_skin_overlay.visible = false
	add_child(_skin_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.64)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_skin_overlay.add_child(dim)

	var skin := _centered_control(_skin_overlay, "TankSkin", SKIN_SIZE)
	_add_texture_rect(skin, "skin_bg.png", Vector2.ZERO)
	_add_texture_rect(skin, "skin_attr_bg.png", Vector2(17.0, 61.0))
	_add_texture_rect(skin, "skin_title.png", Vector2(403.0, 0.0))
	var close_button := _add_texture_button(
		skin,
		"close.png",
		Vector2(944.0, 5.0),
		Vector2(46.0, 46.0),
		_close_skin
	)
	close_button.name = "BtnClose"

	_add_label(
		skin,
		Vector2(26.0, 85.0),
		Vector2(205.0, 310.0),
		"Có skin cấp A\nHP +2%\n\nCó skin cấp S\nTC +2%\n\nCó skin cấp SS\nHP +6%\n\nCó skin cấp SSS\nTC +6%",
		14,
		Color.WHITE,
		HORIZONTAL_ALIGNMENT_LEFT
	)

	for index in SKIN_TAB_ASSETS.size():
		var button := _add_texture_button(
			skin,
			SKIN_TAB_ASSETS[index][0],
			Vector2(260.0 + index * 84.0, 59.0),
			Vector2(78.0, 34.0),
			_on_skin_tab_pressed.bind(index)
		)
		button.name = "SkinTab%d" % index
		_skin_tab_buttons.append(button)

	_add_skin_card(
		skin,
		Vector2(270.0, 120.0),
		"tank_ironman_reward.png",
		"Iron Man",
		""
	)

	_skin_empty_label = _add_label(
		skin,
		Vector2(310.0, 270.0),
		Vector2(610.0, 40.0),
		"Không có skin thuộc cấp này trong bộ asset hiện có.",
		16,
		Color.WHITE,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_skin_empty_label.name = "EmptyLabel"
	_skin_empty_label.visible = false
	_set_skin_tab(0)


func _add_skin_card(
	parent: Control,
	position: Vector2,
	texture_path: String,
	display_name: String,
	quality: String
) -> void:
	var card := Control.new()
	card.name = "SkinCard%d" % _skin_cards.size()
	card.position = position
	card.size = Vector2(225.0, 390.0)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(card)

	_add_label(
		card,
		Vector2.ZERO,
		Vector2(225.0, 28.0),
		display_name,
		14,
		Color(1.0, 0.85, 0.1) if quality == "SSS" else Color.WHITE,
		HORIZONTAL_ALIGNMENT_CENTER
	)
	_add_texture_rect(card, "skin_booth.png", Vector2(-6.0, 172.0), Vector2(236.0, 127.0))
	_add_texture_rect(card, texture_path, Vector2(-23.0, 18.0))
	var quality_label := _add_label(
		card,
		Vector2(0.0, 292.0),
		Vector2(225.0, 28.0),
		"ĐÁNH GIÁ:  " + quality,
		13,
		Color(1.0, 0.84, 0.1) if quality == "SSS" else Color(0.3, 1.0, 0.3),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	quality_label.visible = not quality.is_empty()
	_skin_cards.append({"node": card, "quality": quality})


func _refresh_server_tank() -> void:
	_sync_tank_cell_display_scale()
	var data := GameSession.profile.duplicate()
	data.merge(GameSession.lobby_data, true)
	var has_server_data := not GameSession.profile.is_empty() or not GameSession.lobby_data.is_empty()
	var server_name := _safe_string(data.get("tank_name", "")).strip_edges()
	_tank_name = server_name if not server_name.is_empty() else "Iron Man"
	_tank_level = clampi(
		_safe_int(data.get("tank_level", 1), 1),
		1,
		TANK_LEVEL_ASSETS.size()
	)
	_tank_name_label.text = _tank_name
	_tank_level_label.texture = _texture(TANK_LEVEL_ASSETS[_tank_level - 1])
	_upgrade_level_from.text = "LV.%d" % _tank_level
	_upgrade_level_to.text = "LV.%d" % mini(_tank_level + 1, TANK_LEVEL_ASSETS.size())

	var owned_levels: Dictionary = {}
	_owned_tanks_by_key.clear()
	var owned_tanks: Variant = data.get("owned_tanks", [])
	if owned_tanks is Array:
		for owned_tank: Variant in owned_tanks:
			if owned_tank is Dictionary:
				var owned_key := _safe_string(owned_tank.get("tank_key", "")).strip_edges()
				if not owned_key.is_empty():
					owned_levels[owned_key] = maxi(
						1,
						_safe_int(owned_tank.get("tank_level", 1), 1)
					)
					_owned_tanks_by_key[owned_key] = owned_tank
	_primary_tank_key = _safe_string(data.get("tank_key", "")).strip_edges()
	if not _primary_tank_key.is_empty():
		owned_levels[_primary_tank_key] = _tank_level
		if not _owned_tanks_by_key.has(_primary_tank_key):
			var current_tank := data.duplicate(true)
			current_tank["tank_key"] = _primary_tank_key
			current_tank["tank_name"] = _tank_name
			current_tank["tank_level"] = _tank_level
			if _primary_tank_key == "gangtiexia03":
				current_tank["tank_role_key"] = _safe_string(
					data.get("tank_role_key", "dps")
				)
			_owned_tanks_by_key[_primary_tank_key] = current_tank
	elif not has_server_data:
		_primary_tank_key = "gangtiexia03"
		owned_levels["gangtiexia03"] = _tank_level
		_owned_tanks_by_key["gangtiexia03"] = _offline_preview_tank_data()

	_rebuild_display_tank_keys()
	for index in _tank_cell_backgrounds.size():
		var global_index := _current_tank_page * TANK_CELL_COUNT + index
		var tank_key := (
			_display_tank_keys[global_index]
			if global_index >= 0 and global_index < _display_tank_keys.size()
			else ""
		)
		_tank_cells[index].visible = not tank_key.is_empty()
		if tank_key.is_empty():
			_tank_cell_skin_frames[index].texture = null
			_tank_cell_skin_frames[index].visible = false
			continue
		var owned := owned_levels.has(tank_key)
		_tank_cell_backgrounds[index].texture = _texture(
			"tank_cell_owned.png" if owned else "tank_cell_unowned.png"
		)
		_tank_cell_backgrounds[index].material = (
			null if owned else TANK_CELL_UNOWNED_MATERIAL
		)
		_tank_level_badges[index].texture = _texture(
			"tank_level_badge_owned.png" if owned else "tank_level_badge_unowned.png"
		)
		var displayed_level := clampi(
			int(owned_levels[tank_key]) if owned else 1,
			0,
			9
		)
		_tank_level_labels[index].texture = _digit_texture(displayed_level)
		_primary_badges[index].visible = tank_key == _primary_tank_key
		var owned_tank_value: Variant = _owned_tanks_by_key.get(tank_key, {})
		var owned_tank: Dictionary = (
			owned_tank_value if owned_tank_value is Dictionary else {}
		)
		var equipped_skin_key := TankSkinCatalog.equipped_skin_key(owned_tank)
		var cell_frame_texture := TankSkinCatalog.skin_frame_texture(
			"tankcell",
			owned_tank
		)
		_tank_cell_skin_frames[index].texture = cell_frame_texture
		_tank_cell_skin_frames[index].visible = (
			owned and cell_frame_texture != null
		)
		_set_tank_cell_visual(
			index,
			owned_tank,
			tank_key,
			equipped_skin_key,
			owned
		)
	_update_primary_controls()
	_refresh_skin_quality_buttons()
	_refresh_selected_tank_skin_visuals()
	_refresh_damage_type_indicator()
	_refresh_skin_card_states()
	_refresh_skin_attributes()
	_refresh_tank_stats()


func _set_tank_page(page_index: int) -> void:
	_current_tank_page = clampi(page_index, 0, TANK_PAGE_COUNT - 1)
	for index in _page_buttons.size():
		_page_buttons[index].texture_normal = _texture(
			"pager_selected.png" if index == _current_tank_page else "pager_blue.png"
		)
		_page_number_labels[index].add_theme_color_override(
			"font_color",
			Color(0.04, 0.38, 0.68) if index == _current_tank_page else Color.WHITE
		)
	_refresh_server_tank()
	_sync_tank_cell_selection_for_page()


func _show_next_tank_page() -> void:
	_set_tank_page((_current_tank_page + 1) % TANK_PAGE_COUNT)


func _on_tank_cell_gui_input(event: InputEvent, index: int) -> void:
	if (
		event is InputEventMouseButton
		and event.button_index == MOUSE_BUTTON_LEFT
		and event.pressed
	):
		_select_tank_cell(index)
		accept_event()


func _select_tank_cell(index: int) -> void:
	if _tank_cells.is_empty() or _tank_cell_selection == null:
		return
	_selected_tank_cell = clampi(index, 0, _tank_cells.size() - 1)
	_selected_tank_global_index = (
		_current_tank_page * TANK_CELL_COUNT + _selected_tank_cell
	)
	_sync_tank_cell_selection_for_page()
	_update_primary_controls()
	_refresh_skin_quality_buttons()
	_refresh_selected_tank_skin_visuals()
	_refresh_damage_type_indicator()
	_refresh_skin_card_states()
	_refresh_skin_attributes()
	_refresh_tank_stats()


func _sync_tank_cell_selection_for_page() -> void:
	if _tank_cells.is_empty() or _tank_cell_selection == null:
		return
	var selected_page := _selected_tank_global_index / TANK_CELL_COUNT
	if selected_page != _current_tank_page:
		_tank_cell_selection.stop()
		_tank_cell_selection_clip.visible = false
		return
	_selected_tank_cell = _selected_tank_global_index % TANK_CELL_COUNT
	var cell := _tank_cells[_selected_tank_cell]
	_tank_cell_selection_clip.position = cell.position
	_tank_cell_selection_clip.visible = true
	_tank_cell_selection.position = cell.size * 0.5
	_tank_cell_selection.play()


func _rebuild_display_tank_keys() -> void:
	_display_tank_keys.clear()
	for tank_key_value: Variant in _owned_tanks_by_key.keys():
		var tank_key := String(tank_key_value)
		var tank_value: Variant = _owned_tanks_by_key[tank_key_value]
		var tank: Dictionary = tank_value if tank_value is Dictionary else {}
		if (
			_selected_main_role == "all"
			or _tank_role_key(tank, tank_key) == _selected_main_role
		):
			_display_tank_keys.append(tank_key)
	if _selected_main_role == "all":
		for tank_key_value: Variant in TANK_KEYS:
			var tank_key := String(tank_key_value)
			if tank_key not in _display_tank_keys:
				_display_tank_keys.append(tank_key)
	var visible_page_count := maxi(
		1,
		int(ceil(float(_display_tank_keys.size()) / float(TANK_CELL_COUNT)))
	)
	_selected_tank_global_index = clampi(
		_selected_tank_global_index,
		0,
		maxi(0, _display_tank_keys.size() - 1)
	)
	for index in _page_buttons.size():
		_page_buttons[index].visible = index < visible_page_count
	if _page_next_button != null:
		_page_next_button.visible = visible_page_count > 1


func _tank_role_key(tank_data: Dictionary, tank_key: String = "") -> String:
	var role := _safe_string(
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
	# The legacy Iron Man preview predates the role field. It is DPS.
	if tank_key == "gangtiexia03":
		return "dps"
	return ""


func _selected_tank_key() -> String:
	if (
		_selected_tank_global_index < 0
		or _selected_tank_global_index >= _display_tank_keys.size()
	):
		return ""
	return _display_tank_keys[_selected_tank_global_index]


func _update_primary_controls() -> void:
	if _set_primary_button == null or _primary_selected_label == null:
		return
	var selected_key := _selected_tank_key()
	var owned := _owned_tanks_by_key.has(selected_key)
	var is_primary := not selected_key.is_empty() and selected_key == _primary_tank_key
	_set_primary_button.visible = owned and not is_primary
	_set_primary_button.disabled = _set_primary_busy or not owned or is_primary
	_primary_selected_label.visible = is_primary


func _on_set_primary_pressed() -> void:
	if _set_primary_busy:
		return
	var selected_key := _selected_tank_key()
	if selected_key.is_empty() or not _owned_tanks_by_key.has(selected_key):
		return
	if selected_key == _primary_tank_key:
		return

	_set_primary_busy = true
	_update_primary_controls()
	var result := await GameSession.set_primary_tank(selected_key)
	_set_primary_busy = false
	if not result.get("ok", false):
		var error_value: Variant = result.get("error", {})
		var message := "Không thể đổi Tank chủ chiến."
		if error_value is Dictionary:
			message = String(error_value.get("message", message))
		push_warning(message)
		_update_primary_controls()
		return

	_refresh_server_tank()
	primary_tank_changed.emit(GameSession.lobby_data.duplicate(true))


func _on_main_tab_pressed(index: int) -> void:
	_set_main_tab(index)


func _set_main_tab(selected_index: int) -> void:
	for index in _main_tab_buttons.size():
		_main_tab_buttons[index].texture_normal = _texture(
			MAIN_TAB_ASSETS[index][1] if index == selected_index else MAIN_TAB_ASSETS[index][0]
		)
	_rent_tab.texture_normal = _texture(
		"tab_rent_selected.png" if selected_index == 4 else "tab_rent.png"
	)
	_selected_main_role = (
		MAIN_TAB_ROLE_KEYS[selected_index]
		if selected_index >= 0 and selected_index < MAIN_TAB_ROLE_KEYS.size()
		else "all"
	)
	if not _tank_cells.is_empty():
		_current_tank_page = 0
		_selected_tank_cell = 0
		_selected_tank_global_index = 0
		_refresh_server_tank()
		_select_tank_cell(0)


func _set_info_mode(index: int) -> void:
	for button_index in _info_buttons.size():
		var selected := button_index == index
		_info_buttons[button_index].texture_normal = _texture(
			"tab_bg_selected.png" if selected else "tab_bg.png"
		)
		_info_button_labels[button_index].texture = _texture(
			(
				"detail_desc_selected.png"
				if button_index == 0 and selected
				else "detail_stats_selected.png"
				if button_index == 1 and selected
				else "detail_desc.png"
				if button_index == 0
				else "detail_stats.png"
			)
		)

	if index == 0:
		_main_info_text.text = ""
		_main_info_text.visible = false
		_main_stats_labels.visible = false
		_main_stats_values.visible = false
		_info_description_assets.visible = true
		_main_radar.visible = true
	else:
		_main_info_text.text = ""
		_main_info_text.visible = false
		_main_stats_labels.visible = true
		_main_stats_values.visible = true
		_info_description_assets.visible = false
		_main_radar.visible = false


func _set_skin_quality(selected_index: int) -> void:
	for index in _skin_quality_buttons.size():
		_skin_quality_buttons[index].texture_normal = _texture(
			SKIN_QUALITY_ASSETS[index][1]
			if index == selected_index
			else SKIN_QUALITY_ASSETS[index][0]
		)


func _refresh_skin_quality_buttons() -> void:
	var selected_tank: Variant = _owned_tanks_by_key.get(_selected_tank_key(), {})
	var owned_qualities: Dictionary = {}
	if selected_tank is Dictionary:
		owned_qualities = TankSkinCatalog.owned_qualities(selected_tank)
	for index in _skin_quality_buttons.size():
		var quality := String(SKIN_TAB_ASSETS[index + 1][2])
		_skin_quality_buttons[index].texture_normal = _texture(
			SKIN_QUALITY_ASSETS[index][1]
			if owned_qualities.get(quality, false) == true
			else SKIN_QUALITY_ASSETS[index][0]
		)


func _refresh_selected_tank_skin_visuals() -> void:
	if (
		_main_tank_image == null
		or _skin_preview_image == null
		or _skin_preview_frame == null
	):
		return
	var tank_key := _selected_tank_key()
	var tank_value: Variant = _owned_tanks_by_key.get(tank_key, {})
	var tank_data: Dictionary = (
		tank_value if tank_value is Dictionary else {}
	)
	var equipped_key := TankSkinCatalog.equipped_skin_key(tank_data)
	var highest_owned_key := TankSkinCatalog.highest_owned_skin_key(tank_data)
	var preview_frame_texture := TankSkinCatalog.skin_frame_texture(
		"skinpreview",
		tank_data
	)
	_skin_preview_frame.texture = preview_frame_texture
	_skin_preview_frame.visible = preview_frame_texture != null
	_main_tank_animation = _set_tank_skin_visual(
		_main_tank_image,
		_main_tank_animation,
		tank_data,
		tank_key,
		equipped_key,
		"MainTankAnimation",
		false
	)
	_skin_preview_animation = _set_tank_skin_visual(
		_skin_preview_image,
		_skin_preview_animation,
		tank_data,
		tank_key,
		highest_owned_key,
		"SkinPreviewAnimation",
		true
	)


func _refresh_damage_type_indicator() -> void:
	if (
		_damage_type_icon == null
		or _damage_type_tooltip == null
		or _damage_type_tooltip_text == null
	):
		return
	var tank_value: Variant = _owned_tanks_by_key.get(
		_selected_tank_key(),
		{}
	)
	var tank: Dictionary = tank_value if tank_value is Dictionary else {}
	var damage_type := _safe_string(
		tank.get(
			"tank_damage_type",
			tank.get("damage_type", "physical")
		)
	).strip_edges().to_lower()
	var is_energy := damage_type == "energy"
	_damage_type_icon.texture = (
		DAMAGE_TYPE_ENERGY_TEXTURE
		if is_energy
		else DAMAGE_TYPE_PHYSICAL_TEXTURE
	)
	_damage_type_tooltip_text.text = (
		"Tank Năng Lượng: dùng\nđối kháng Tank Vật Lý"
		if is_energy
		else "Tank Vật Lý: thường dùng\nđối kháng Tank Năng lượng."
	)


func _show_damage_type_tooltip() -> void:
	if _damage_type_tooltip == null:
		return
	_damage_type_tooltip.show()
	_update_damage_type_tooltip_position()


func _hide_damage_type_tooltip() -> void:
	if _damage_type_tooltip != null:
		_damage_type_tooltip.hide()


func _update_damage_type_tooltip_position() -> void:
	if _damage_type_tooltip == null or _main_view == null:
		return
	var mouse_position := _main_view.get_local_mouse_position()
	var tooltip_size := _damage_type_tooltip.size
	var target := mouse_position + Vector2(14.0, 14.0)
	if target.x + tooltip_size.x > _main_view.size.x - 6.0:
		target.x = mouse_position.x - tooltip_size.x - 14.0
	if target.y + tooltip_size.y > _main_view.size.y - 6.0:
		target.y = mouse_position.y - tooltip_size.y - 14.0
	target.x = clampf(
		target.x,
		6.0,
		_main_view.size.x - tooltip_size.x - 6.0
	)
	target.y = clampf(
		target.y,
		6.0,
		_main_view.size.y - tooltip_size.y - 6.0
	)
	_damage_type_tooltip.position = target


func _set_tank_skin_visual(
	image: TextureRect,
	animation: SwfTimelinePlayer,
	tank_data: Dictionary,
	tank_key: String,
	skin_key: String,
	animation_name: String,
	prefer_icon: bool
) -> SwfTimelinePlayer:
	var animation_path := TankSkinCatalog.animation_path(skin_key)
	if not animation_path.is_empty():
		image.visible = false
		if animation == null:
			animation = SwfTimelinePlayer.new()
			animation.name = animation_name
			animation.timeline_path = animation_path
			_main_view.add_child(animation)
			_main_view.move_child(animation, image.get_index() + 1)
		elif animation.timeline_path != animation_path:
			animation.load_timeline(animation_path)
		animation.position = image.get_transform() * (image.size * 0.5)
		animation.scale = image.scale
		animation.rotation = image.rotation
		animation.z_index = image.z_index
		animation.visible = true
		animation.play()
		return animation

	if animation != null:
		animation.stop()
		animation.visible = false
	var texture: Texture2D = null
	if prefer_icon:
		texture = TankSkinCatalog.icon_for(skin_key)
	if texture == null:
		texture = TankSkinCatalog.texture_for(tank_data, tank_key, skin_key)
	image.texture = texture
	image.visible = texture != null
	return animation


func _sync_tank_cell_display_scale() -> void:
	if _tank_cell_images.is_empty():
		return
	var reference_scale := _tank_cell_images[0].scale
	for index in range(1, _tank_cell_images.size()):
		_tank_cell_images[index].scale = reference_scale


func _set_tank_cell_visual(
	index: int,
	tank_data: Dictionary,
	tank_key: String,
	skin_key: String,
	owned: bool
) -> void:
	var image := _tank_cell_images[index]
	var animation: SwfTimelinePlayer = _tank_cell_animations[index]
	var animation_path := (
		TankSkinCatalog.animation_path(skin_key)
		if owned
		else ""
	)
	if animation_path.is_empty():
		if animation != null:
			animation.stop()
			animation.visible = false
		var texture: Texture2D = (
			TankSkinCatalog.catalog_texture_for(
				tank_data,
				tank_key,
				skin_key
			)
			if owned
			else null
		)
		if texture == null and owned:
			texture = TANK_CELL_TEXTURES.get(tank_key) as Texture2D
		image.texture = texture
		image.visible = texture != null
		return

	image.visible = false
	if animation == null:
		animation = SwfTimelinePlayer.new()
		animation.name = "TankAnimation"
		animation.timeline_path = animation_path
		_tank_cells[index].add_child(animation)
		_tank_cells[index].move_child(animation, image.get_index() + 1)
		_tank_cell_animations[index] = animation
	elif animation.timeline_path != animation_path:
		animation.load_timeline(animation_path)
	_fit_tank_cell_animation(animation, image)
	animation.visible = true
	animation.play()


func _fit_tank_cell_animation(
	animation: SwfTimelinePlayer,
	image: TextureRect
) -> void:
	var stage_size := animation.get_stage_size()
	var fit_scale := 1.0
	if stage_size.x > 0.0 and stage_size.y > 0.0:
		fit_scale = minf(
			image.size.x / stage_size.x,
			image.size.y / stage_size.y
		)
	animation.position = image.get_transform() * (image.size * 0.5)
	animation.scale = image.scale * fit_scale
	animation.rotation = image.rotation
	animation.z_index = image.z_index


func _equipped_skin_quality(tank_data: Dictionary) -> String:
	var direct_quality := _normalized_skin_quality(
		tank_data.get("equipped_skin_quality", "")
	)
	if not direct_quality.is_empty():
		return direct_quality

	var equipped_skin_key := _safe_string(
		tank_data.get("equipped_skin_key", "")
	).strip_edges()
	var default_quality := ""
	var skins: Variant = tank_data.get("skins", [])
	if skins is not Array:
		return ""
	for skin_value: Variant in skins:
		if not skin_value is Dictionary:
			continue
		var skin: Dictionary = skin_value
		if skin.get("owned", false) != true:
			continue
		var quality := _normalized_skin_quality(skin.get("quality_key", ""))
		var skin_key := _safe_string(skin.get("skin_key", "")).strip_edges()
		var is_equipped: bool = (
			skin.get("is_equipped", skin.get("equipped", false)) == true
		)
		if is_equipped or (
			not equipped_skin_key.is_empty() and skin_key == equipped_skin_key
		):
			return quality
		if skin.get("is_default", false) == true:
			default_quality = quality
	return default_quality


func _equipped_skin_key(tank_data: Dictionary) -> String:
	var direct_key := _safe_string(
		tank_data.get("equipped_skin_key", "")
	).strip_edges()
	if not direct_key.is_empty():
		return direct_key

	var default_key := ""
	var skins: Variant = tank_data.get("skins", [])
	if skins is not Array:
		return ""
	for skin_value: Variant in skins:
		if skin_value is not Dictionary:
			continue
		var skin: Dictionary = skin_value
		if skin.get("owned", false) != true:
			continue
		var skin_key := _safe_string(skin.get("skin_key", "")).strip_edges()
		if skin.get("is_equipped", skin.get("equipped", false)) == true:
			return skin_key
		if skin.get("is_default", false) == true:
			default_key = skin_key
	return default_key


func _refresh_skin_card_states() -> void:
	if _skin_cards.is_empty():
		return
	var selected_tank_value: Variant = _owned_tanks_by_key.get(
		_selected_tank_key(),
		{}
	)
	var selected_tank: Dictionary = (
		selected_tank_value if selected_tank_value is Dictionary else {}
	)
	var owned_skins: Dictionary = {}
	var equipped_key := _equipped_skin_key(selected_tank)
	var skins: Variant = selected_tank.get("skins", [])
	if skins is Array:
		for skin_value: Variant in skins:
			if skin_value is not Dictionary:
				continue
			var skin: Dictionary = skin_value
			var skin_key := _safe_string(skin.get("skin_key", "")).strip_edges()
			if not skin_key.is_empty():
				owned_skins[skin_key] = skin.get("owned", false) == true

	# F6 xem riêng scene không có dữ liệu server: chỉ Skin mặc định được xem là đang dùng.
	if selected_tank.has("tank_key") and not selected_tank.has("skins"):
		owned_skins["gangtiexia03_default"] = true
		equipped_key = "gangtiexia03_default"

	for card_data in _skin_cards:
		var skin_key := String(card_data["skin_key"])
		var owned: bool = owned_skins.get(skin_key, false) == true
		var equipped := owned and skin_key == equipped_key
		var equipped_label := card_data["equipped"] as TextureRect
		var use_button := card_data["use_button"] as TextureButton
		equipped_label.visible = equipped
		use_button.visible = owned and not equipped
		use_button.disabled = _skin_equip_busy or not owned or equipped


func _refresh_skin_attributes() -> void:
	if _skin_attribute_total_attack == null:
		return
	var selected_tank_value: Variant = _owned_tanks_by_key.get(
		_selected_tank_key(),
		{}
	)
	var selected_tank: Dictionary = (
		selected_tank_value if selected_tank_value is Dictionary else {}
	)
	var bonus_value: Variant = selected_tank.get("skin_collection_bonus", {})
	var bonus: Dictionary = bonus_value if bonus_value is Dictionary else {}
	var attack_percent := _safe_int(
		bonus.get("total_tc_percent", bonus.get("attack_percent", 0)),
		0
	)
	_skin_attribute_total_attack.text = "TC+%d%%" % maxi(0, attack_percent)

	var requirements_by_key: Dictionary = {}
	var requirements: Variant = bonus.get("requirements", [])
	if requirements is Array:
		for requirement_value: Variant in requirements:
			if requirement_value is not Dictionary:
				continue
			var requirement: Dictionary = requirement_value
			var rule_key := _safe_string(
				requirement.get("rule_key", "")
			).strip_edges()
			if not rule_key.is_empty():
				requirements_by_key[rule_key] = requirement

	for rule_key: String in _skin_attribute_quality_nodes:
		var node_data: Dictionary = _skin_attribute_quality_nodes[rule_key]
		var requirement_value: Variant = requirements_by_key.get(rule_key, {})
		var completed: bool = (
			requirement_value is Dictionary
			and requirement_value.get("completed", false) == true
		)
		var color := (
			SKIN_ATTRIBUTE_ACTIVE_COLOR
			if completed
			else SKIN_ATTRIBUTE_INACTIVE_COLOR
		)
		var outline_color := (
			SKIN_ATTRIBUTE_ACTIVE_OUTLINE
			if completed
			else SKIN_ATTRIBUTE_INACTIVE_OUTLINE
		)
		for label_value: Variant in node_data["labels"]:
			var label := label_value as Label
			label.add_theme_color_override("font_color", color)
			label.add_theme_color_override("font_outline_color", outline_color)
			label.add_theme_constant_override("outline_size", 2)
		var status := node_data["status"] as TextureRect
		status.texture = _texture(
			"skin_attr_active.png" if completed else "skin_attr_inactive.png"
		)

	for rule_key: String in _skin_attribute_other_nodes:
		var requirement_value: Variant = requirements_by_key.get(rule_key, {})
		var completed: bool = (
			requirement_value is Dictionary
			and requirement_value.get("completed", false) == true
		)
		var color := (
			SKIN_ATTRIBUTE_ACTIVE_COLOR
			if completed
			else SKIN_ATTRIBUTE_INACTIVE_COLOR
		)
		var outline_color := (
			SKIN_ATTRIBUTE_ACTIVE_OUTLINE
			if completed
			else SKIN_ATTRIBUTE_INACTIVE_OUTLINE
		)
		var labels: Array = _skin_attribute_other_nodes[rule_key]
		for label in labels:
			var requirement_label := label as Label
			requirement_label.add_theme_color_override("font_color", color)
			requirement_label.add_theme_color_override(
				"font_outline_color",
				outline_color
			)
			requirement_label.add_theme_constant_override("outline_size", 2)


func _refresh_tank_stats() -> void:
	if (
		_main_stats_base_values.size() != INFO_STAT_KEYS.size()
		or _main_stats_bonus_values.size() != 5
	):
		return
	var selected_tank_value: Variant = _owned_tanks_by_key.get(
		_selected_tank_key(),
		{}
	)
	var selected_tank: Dictionary = (
		selected_tank_value if selected_tank_value is Dictionary else {}
	)
	var base_stats_value: Variant = selected_tank.get("base_stats", {})
	var base_stats: Dictionary = (
		base_stats_value if base_stats_value is Dictionary else {}
	)
	var bonuses_value: Variant = selected_tank.get("stat_bonuses", {})
	var bonuses: Dictionary = (
		bonuses_value if bonuses_value is Dictionary else {}
	)
	var use_level_one_fallback := (
		_selected_tank_key() == "gangtiexia03"
		and _safe_int(selected_tank.get("tank_level", _tank_level), 1) == 1
	)
	for stat_index in INFO_STAT_KEYS.size():
		var stat_key: String = INFO_STAT_KEYS[stat_index]
		var base_value: Variant = base_stats.get(
			stat_key,
			selected_tank.get("base_%s" % stat_key, null)
		)
		if (
			(base_value == null or not str(base_value).is_valid_int())
			and use_level_one_fallback
		):
			base_value = IRONMAN_LEVEL_1_BASE_STATS.get(stat_key, null)
		_main_stats_base_values[stat_index].text = (
			str(_safe_int(base_value, 0)) if base_value != null else "-"
		)
		var bonus_value := maxf(
			0.0,
			float(bonuses.get(stat_key, 0.0))
		)
		if stat_index < 5:
			_main_stats_bonus_values[stat_index].text = _format_stat_bonus(
				bonus_value
			)

	var collection_value: Variant = selected_tank.get(
		"skin_collection_bonus",
		{}
	)
	var collection: Dictionary = (
		collection_value if collection_value is Dictionary else {}
	)
	var hp_percent := maxi(
		0,
		_safe_int(collection.get("hit_points_percent", 0), 0)
	)
	var attack_percent := maxi(
		0,
		_safe_int(collection.get("attack_percent", 0), 0)
	)
	_main_stats_additional_percent.text = (
		"HP +%d%% Tấn Công +%d%%" % [hp_percent, attack_percent]
	)


func _format_stat_bonus(value: float) -> String:
	return "+%d" % _round_stat_bonus(value)


func _round_stat_bonus(value: float) -> int:
	var safe_value := maxf(0.0, value)
	var lower_value := floori(safe_value)
	return lower_value + 1 if safe_value - lower_value > 0.5 else lower_value


func _on_military_rank_pressed() -> void:
	military_rank_requested.emit()


func _setup_skill_tooltips() -> void:
	_skill_icons.clear()
	for index in IRONMAN_SKILL_TOOLTIPS.size():
		var icon := _main_view.get_node_or_null(
			"SkillIcon%d" % (index + 1)
		) as TextureRect
		if icon == null:
			continue
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		icon.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		_connect_if_needed(icon.mouse_entered, _show_skill_tooltip.bind(index))
		_connect_if_needed(icon.mouse_exited, _hide_skill_tooltip)
		_skill_icons.append(icon)

	_skill_tooltip = PanelContainer.new()
	_skill_tooltip.name = "SkillDescriptionTooltip"
	_skill_tooltip.position = Vector2.ZERO
	_skill_tooltip.size = Vector2(268.0, 400.0)
	_skill_tooltip.z_index = 120
	_skill_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tooltip_style := StyleBoxFlat.new()
	tooltip_style.bg_color = Color(0.015, 0.025, 0.035, 0.90)
	tooltip_style.border_color = Color(0.28, 0.34, 0.38, 0.95)
	tooltip_style.set_border_width_all(1)
	tooltip_style.set_corner_radius_all(5)
	tooltip_style.content_margin_left = 10.0
	tooltip_style.content_margin_top = 8.0
	tooltip_style.content_margin_right = 10.0
	tooltip_style.content_margin_bottom = 8.0
	_skill_tooltip.add_theme_stylebox_override("panel", tooltip_style)
	_main_view.add_child(_skill_tooltip)

	_skill_tooltip_text = RichTextLabel.new()
	_skill_tooltip_text.bbcode_enabled = true
	_skill_tooltip_text.fit_content = false
	_skill_tooltip_text.scroll_active = false
	_skill_tooltip_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_skill_tooltip_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_tooltip_text.add_theme_font_size_override("normal_font_size", 12)
	_skill_tooltip_text.add_theme_font_size_override("bold_font_size", 12)
	_skill_tooltip.add_child(_skill_tooltip_text)
	_skill_tooltip.hide()


func _show_skill_tooltip(index: int) -> void:
	if index < 0 or index >= IRONMAN_SKILL_TOOLTIPS.size():
		return
	var data: Dictionary = IRONMAN_SKILL_TOOLTIPS[index]
	_skill_tooltip.size = Vector2(268.0, float(data.get("height", 320.0)))
	_skill_tooltip_text.text = (
		"[font_size=15][b][color=#ffffff]%s[/color][/b][/font_size]\n"
		+ "[color=#63e65d]Thời gian CD %s[/color]\n\n"
		+ "[color=#ffffff][b][lb]Giới thiệu[rb][/b][/color]\n"
		+ "[color=#ffffff]Tính chất: [/color][color=#ff3cd8]Skill[/color]"
		+ "[color=#ffffff]     Loại ST: [/color][color=#ffad19]Vật Lý[/color]\n"
		+ "[color=#ffffff]VP Bay: [/color][color=#50e7ff]%s[/color]\n\n"
		+ "%s"
	) % [
		String(data.get("title", "")),
		String(data.get("cooldown", "")),
		"Có" if index == 0 else "Không",
		String(data.get("description", "")),
	]
	_skill_tooltip.show()
	_update_skill_tooltip_position()


func _hide_skill_tooltip() -> void:
	if _skill_tooltip != null:
		_skill_tooltip.hide()


func _update_skill_tooltip_position() -> void:
	var mouse_position := _main_view.get_local_mouse_position()
	var tooltip_size := _skill_tooltip.size
	var target := mouse_position + Vector2(14.0, 16.0)
	if target.x + tooltip_size.x > _main_view.size.x - 6.0:
		target.x = mouse_position.x - tooltip_size.x - 14.0
	if target.y + tooltip_size.y > _main_view.size.y - 6.0:
		target.y = mouse_position.y - tooltip_size.y - 14.0
	target.x = clampf(target.x, 6.0, _main_view.size.x - tooltip_size.x - 6.0)
	target.y = clampf(target.y, 6.0, _main_view.size.y - tooltip_size.y - 6.0)
	_skill_tooltip.position = target


func _on_use_skin_pressed(skin_key: String) -> void:
	if _skin_equip_busy:
		return
	var tank_key := _selected_tank_key()
	if tank_key.is_empty() or skin_key.is_empty():
		return
	var selected_tank_value: Variant = _owned_tanks_by_key.get(tank_key, {})
	if selected_tank_value is not Dictionary:
		return
	var selected_tank: Dictionary = selected_tank_value
	var can_use := false
	var skins: Variant = selected_tank.get("skins", [])
	if skins is Array:
		for skin_value: Variant in skins:
			if skin_value is Dictionary:
				var candidate: Dictionary = skin_value
				if (
					_safe_string(candidate.get("skin_key", "")).strip_edges() == skin_key
					and candidate.get("owned", false) == true
				):
					can_use = true
					break
	if not can_use:
		return

	if GameSession.token.is_empty():
		_preview_equipped_skin_key = skin_key
		selected_tank["equipped_skin_key"] = skin_key
		selected_tank["equipped_skin_quality"] = TankSkinCatalog.skin_quality(
			selected_tank,
			skin_key
		)
		selected_tank["skins"] = _preview_skin_catalog(skin_key)
		_owned_tanks_by_key[tank_key] = selected_tank
		_sync_preview_skin_to_game_session(tank_key, selected_tank)
		_refresh_server_tank()
		primary_tank_changed.emit(GameSession.lobby_data.duplicate(true))
		return

	_skin_equip_busy = true
	_refresh_skin_card_states()
	var result := await GameSession.equip_tank_skin(tank_key, skin_key)
	_skin_equip_busy = false
	if not result.get("ok", false):
		var error_value: Variant = result.get("error", {})
		var message := "Không thể sử dụng Skin này."
		if error_value is Dictionary:
			message = String(error_value.get("message", message))
		push_warning(message)
		_refresh_skin_card_states()
		return

	_refresh_server_tank()
	primary_tank_changed.emit(GameSession.lobby_data.duplicate(true))


func _sync_preview_skin_to_game_session(
	tank_key: String,
	tank_data: Dictionary
) -> void:
	var lobby := GameSession.lobby_data.duplicate(true)
	var synced_tank := tank_data.duplicate(true)
	synced_tank["is_primary"] = true
	var owned_tanks_value: Variant = lobby.get("owned_tanks", [])
	var owned_tanks: Array = (
		owned_tanks_value.duplicate(true)
		if owned_tanks_value is Array
		else []
	)
	var replaced := false
	for index in owned_tanks.size():
		if (
			owned_tanks[index] is Dictionary
			and String(owned_tanks[index].get("tank_key", "")) == tank_key
		):
			owned_tanks[index] = synced_tank
			replaced = true
			break
	if not replaced:
		owned_tanks.append(synced_tank)

	lobby["display_name"] = String(lobby.get("display_name", "Beenn"))
	lobby["gender"] = String(lobby.get("gender", "male"))
	lobby["level"] = int(lobby.get("level", 1))
	lobby["tank_key"] = tank_key
	lobby["tank_name"] = String(synced_tank.get("tank_name", _tank_name))
	lobby["tank_level"] = int(synced_tank.get("tank_level", _tank_level))
	lobby["tank_damage_type"] = String(
		synced_tank.get(
			"tank_damage_type",
			synced_tank.get("damage_type", "physical")
		)
	)
	lobby["equipped_skin_key"] = String(
		synced_tank.get("equipped_skin_key", "")
	)
	lobby["equipped_skin_quality"] = String(
		synced_tank.get("equipped_skin_quality", "")
	)
	lobby["owned_tanks"] = owned_tanks
	GameSession.apply_lobby_data(lobby)


func _on_lobby_data_changed(_data: Dictionary) -> void:
	if _built:
		_refresh_server_tank()


func _preview_skin_catalog(equipped_key: String) -> Array:
	var skins: Array = []
	for card_data in SKIN_CARD_DATA:
		var skin_key := String(card_data[2])
		skins.append({
			"skin_key": skin_key,
			"display_name": String(card_data[0]),
			"quality_key": String(card_data[1]),
			"is_default": skin_key == "gangtiexia03_default",
			"is_equipped": skin_key == equipped_key,
			"owned": true,
		})
	return skins


func _offline_preview_tank_data() -> Dictionary:
	var base_stats := IRONMAN_LEVEL_1_BASE_STATS.duplicate(true)
	var raw_skin_hit_points_bonus := (
		float(base_stats["hit_points"]) * 10.0 / 100.0
	)
	var raw_skin_attack_bonus := (
		float(base_stats["basic_attack_damage"]) * 10.0 / 100.0
	)
	var stat_bonuses := {
		"hit_points": _round_stat_bonus(raw_skin_hit_points_bonus),
		"basic_attack_damage": _round_stat_bonus(raw_skin_attack_bonus),
		"penetration": 0.0,
		"physical_armor": _round_stat_bonus(1.6),
		"energy_shield": 0.0,
		"move_speed": 0.0,
		"fire_rate": 0.0,
		"attack_range": 0.0,
	}
	var effective_stats := {}
	for stat_key: String in INFO_STAT_KEYS:
		effective_stats[stat_key] = (
			float(base_stats[stat_key])
			+ float(stat_bonuses.get(stat_key, 0.0))
		)
	return {
		"tank_key": "gangtiexia03",
		"tank_name": _tank_name,
		"tank_level": _tank_level,
		"tank_role_key": "dps",
		"tank_damage_type": "physical",
		"is_primary": true,
		"equipped_skin_key": _preview_equipped_skin_key,
		"skins": _preview_skin_catalog(_preview_equipped_skin_key),
		"base_stats": base_stats,
		"stat_bonus_sources": [
			{
				"source_key": "skin_collection",
				"hit_points": raw_skin_hit_points_bonus,
				"basic_attack_damage": raw_skin_attack_bonus,
				"penetration": 0.0,
				"physical_armor": 0.0,
				"energy_shield": 0.0,
			},
			{
				"source_key": "military_rank",
				"hit_points": 0.0,
				"basic_attack_damage": 0.0,
				"penetration": 0.0,
				"physical_armor": 1.6,
				"energy_shield": 0.0,
			},
		],
		"stat_bonuses": stat_bonuses,
		"effective_stats": effective_stats,
		"skin_collection_bonus": {
			"hit_points_percent": 10,
			"attack_percent": 10,
			"total_tc_percent": 10,
			"frame_tier": "orange",
			"owned_quality_count": 4,
			"owned_qualities": ["A", "S", "SS", "SSS"],
			"requirements": [
				{"rule_key": "quality_a", "completed": true},
				{"rule_key": "quality_s", "completed": true},
				{"rule_key": "quality_ss", "completed": true},
				{"rule_key": "quality_sss", "completed": true},
				{"rule_key": "distinct_2", "completed": true},
				{"rule_key": "distinct_3_sss", "completed": true},
				{"rule_key": "distinct_4", "completed": true},
			],
		},
	}


func _normalized_skin_quality(value: Variant) -> String:
	var quality := _safe_string(value).strip_edges().to_upper()
	return quality if quality in ["A", "S", "SS", "SSS"] else ""


func _open_upgrade() -> void:
	_upgrade_status.text = ""
	_upgrade_overlay.visible = true
	_upgrade_overlay.move_to_front()


func _close_upgrade() -> void:
	_upgrade_overlay.visible = false


func _on_upgrade_request() -> void:
	_upgrade_status.text = "Chưa có API nâng cấp Tank từ máy chủ; level chưa bị thay đổi."


func _open_skin(selected_tab: int = 0) -> void:
	_skin_overlay.visible = true
	_skin_overlay.move_to_front()
	_set_skin_tab(clampi(selected_tab, 0, SKIN_TAB_ASSETS.size() - 1))


func _open_skin_quality(quality_index: int) -> void:
	_open_skin(quality_index + 1)


func _close_skin() -> void:
	_skin_overlay.visible = false


func _on_skin_tab_pressed(index: int) -> void:
	_set_skin_tab(index)


func _set_skin_tab(selected_index: int) -> void:
	var selected_quality := String(SKIN_TAB_ASSETS[selected_index][2])
	for index in _skin_tab_buttons.size():
		var selected := index == selected_index
		_skin_tab_buttons[index].texture_normal = _texture(
			SKIN_TAB_BACKGROUND_ASSETS[1] if selected else SKIN_TAB_BACKGROUND_ASSETS[0]
		)
		_skin_tab_labels[index].texture = _texture(
			SKIN_TAB_ASSETS[index][1] if selected else SKIN_TAB_ASSETS[index][0]
		)

	var visible_count := 0
	for card_data in _skin_cards:
		var card := card_data["node"] as Control
		var card_quality := String(card_data["quality"])
		card.visible = selected_quality == "all" or card_quality == selected_quality
		if card.visible:
			card.position = Vector2(
				SKIN_CONTENT_PADDING + visible_count * SKIN_CARD_STEP,
				0.0
			)
			visible_count += 1
	_skin_empty_label.visible = visible_count == 0
	if _skin_content != null and _skin_viewport != null and _skin_scrollbar != null:
		var content_width := maxf(
			_skin_viewport.size.x,
			SKIN_CONTENT_PADDING * 2.0
			+ visible_count * SKIN_CARD_STEP
			- (SKIN_CARD_STEP - 225.0)
		)
		_skin_content.size.x = content_width
		_skin_scroll_max_value = maxf(
			0.0,
			content_width - _skin_viewport.size.x
		)
		_skin_scrollbar.visible = _skin_scroll_max_value > 0.0
		_set_skin_scroll_value(0.0)
	_refresh_skin_card_states()


func _on_skin_scroll_changed(value: float) -> void:
	_set_skin_scroll_value(value)


func _set_skin_scroll_value(value: float) -> void:
	_skin_scroll_value = clampf(value, 0.0, _skin_scroll_max_value)
	if _skin_content != null:
		_skin_content.position.x = -_skin_scroll_value
	_update_skin_scroll_thumb()


func _scroll_skin_by(amount: float) -> void:
	_set_skin_scroll_value(_skin_scroll_value + amount)


func _update_skin_scroll_thumb() -> void:
	if _skin_scrollbar == null or _skin_scroll_thumb == null or _skin_viewport == null:
		return
	var track_width := _skin_scrollbar.size.x - SKIN_SCROLL_ARROW_WIDTH * 2.0
	var content_width := maxf(_skin_content.size.x, _skin_viewport.size.x)
	var thumb_width := track_width
	if content_width > 0.0:
		thumb_width = clampf(
			track_width * _skin_viewport.size.x / content_width,
			40.0,
			track_width
		)
	var thumb_travel := maxf(0.0, track_width - thumb_width)
	var ratio := (
		_skin_scroll_value / _skin_scroll_max_value
		if _skin_scroll_max_value > 0.0
		else 0.0
	)
	# Texture gốc là thanh dọc 19×505; node xoay -90° để thành tay kéo ngang.
	_skin_scroll_thumb.position = Vector2(
		SKIN_SCROLL_ARROW_WIDTH + thumb_travel * ratio,
		19.0
	)
	_skin_scroll_thumb.size = Vector2(19.0, thumb_width)


func _set_skin_scroll_from_thumb_position(thumb_x: float) -> void:
	if _skin_scrollbar == null or _skin_scroll_thumb == null:
		return
	var track_width := _skin_scrollbar.size.x - SKIN_SCROLL_ARROW_WIDTH * 2.0
	var thumb_width := _skin_scroll_thumb.size.y
	var thumb_travel := maxf(0.0, track_width - thumb_width)
	if thumb_travel <= 0.0 or _skin_scroll_max_value <= 0.0:
		_set_skin_scroll_value(0.0)
		return
	var local_x := clampf(
		thumb_x - SKIN_SCROLL_ARROW_WIDTH,
		0.0,
		thumb_travel
	)
	_set_skin_scroll_value(local_x / thumb_travel * _skin_scroll_max_value)


func _on_skin_scroll_gui_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not event.pressed:
		_skin_scroll_dragging = false
		return
	# Interaction chỉ phủ phần ray giữa hai nút mũi tên, nên vị trí chuột
	# cần đổi về hệ tọa độ của SkinScroll trước khi so với tay kéo.
	var local_x: float = event.position.x + SKIN_SCROLL_ARROW_WIDTH
	var thumb_left := _skin_scroll_thumb.position.x
	var thumb_right := thumb_left + _skin_scroll_thumb.size.y
	if local_x >= thumb_left and local_x <= thumb_right:
		_skin_scroll_drag_offset = local_x - thumb_left
	else:
		_skin_scroll_drag_offset = _skin_scroll_thumb.size.y * 0.5
		_set_skin_scroll_from_thumb_position(
			local_x - _skin_scroll_drag_offset
		)
	_skin_scroll_dragging = true
	accept_event()


func _on_skin_viewport_gui_input(event: InputEvent) -> void:
	if event is not InputEventMouseButton or not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		_scroll_skin_by(-SKIN_SCROLL_STEP)
		accept_event()
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		_scroll_skin_by(SKIN_SCROLL_STEP)
		accept_event()


func _centered_control(parent: Control, node_name: String, node_size: Vector2) -> Control:
	var result := Control.new()
	result.name = node_name
	result.anchor_left = 0.5
	result.anchor_top = 0.5
	result.anchor_right = 0.5
	result.anchor_bottom = 0.5
	result.offset_left = -node_size.x * 0.5
	result.offset_top = -node_size.y * 0.5
	result.offset_right = node_size.x * 0.5
	result.offset_bottom = node_size.y * 0.5
	result.mouse_filter = Control.MOUSE_FILTER_STOP
	parent.add_child(result)
	return result


func _add_texture_rect(
	parent: Control,
	asset_name: String,
	position: Vector2,
	target_size: Vector2 = Vector2.ZERO,
	scale_to_rect: bool = false
) -> TextureRect:
	var result := TextureRect.new()
	var source_texture := _texture(asset_name)
	result.texture = source_texture
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.stretch_mode = (
		TextureRect.STRETCH_SCALE
		if scale_to_rect
		else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	)
	result.position = position
	result.size = source_texture.get_size() if target_size == Vector2.ZERO else target_size
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result


func _add_texture_button(
	parent: Control,
	asset_name: String,
	position: Vector2,
	target_size: Vector2,
	callback: Callable
) -> TextureButton:
	var result := TextureButton.new()
	result.texture_normal = _texture(asset_name)
	result.ignore_texture_size = true
	result.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	result.position = position
	result.size = target_size
	result.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	result.pressed.connect(callback)
	parent.add_child(result)
	return result


func _add_label(
	parent: Control,
	position: Vector2,
	target_size: Vector2,
	text_value: String,
	font_size: int,
	font_color: Color,
	alignment: HorizontalAlignment
) -> Label:
	var result := Label.new()
	result.position = position
	result.size = target_size
	result.text = text_value
	result.horizontal_alignment = alignment
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", font_color)
	result.add_theme_color_override("font_outline_color", Color(0.0, 0.25, 0.45, 1.0))
	result.add_theme_constant_override("outline_size", 2)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result


func _texture(asset_name: String) -> Texture2D:
	return AssetPathAliases.load_texture(ASSET_ROOT + asset_name)


func _digit_texture(digit: int) -> AtlasTexture:
	var result := AtlasTexture.new()
	result.atlas = _texture("battle_level_numbers.png")
	result.region = Rect2(clampi(digit, 0, 9) * 8.0, 0.0, 8.0, 12.0)
	return result


func _safe_string(value: Variant) -> String:
	if value == null:
		return ""
	return String(value)


func _safe_int(value: Variant, fallback: int) -> int:
	if value == null:
		return fallback
	if value is int or value is float:
		return int(value)
	var text := String(value).strip_edges()
	return int(text) if text.is_valid_int() else fallback
