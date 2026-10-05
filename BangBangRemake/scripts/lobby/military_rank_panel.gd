extends Control

const AssetPathAliases := preload("res://scripts/data/asset_path_aliases.gd")

const ASSET_ROOT := "res://assets/ui/military_rank/"
const WINDOW_FRAME_SCENE := preload(
	"res://scenes/lobby/military_rank/MilitaryRankOverview.tscn"
)
const RANK_LEVEL_POPUP_SCENE := preload(
	"res://scenes/lobby/military_rank/MilitaryRankLevelPopup.tscn"
)
const PanelTransitionHelper := preload("res://scripts/ui/panel_transition.gd")
const RANKS := [
	[1, 0, "Binh nhì"],
	[2, 5, "Hạ Sĩ"],
	[3, 10, "Trung Sĩ"],
	[4, 15, "Thượng Sĩ"],
	[5, 20, "Chuẩn Úy"],
	[6, 25, "Thiếu Úy"],
	[7, 30, "Trung Úy"],
	[8, 35, "Thượng Úy"],
	[9, 40, "Đại Úy"],
	[10, 45, "Thiếu Tá"],
	[11, 50, "Thiếu Tá Cấp 2"],
	[12, 55, "Thiếu Tá Cấp 3"],
	[13, 60, "Trung Tá"],
	[14, 65, "Trung Tá Cấp 2"],
	[15, 70, "Trung Tá Cấp 3"],
	[16, 75, "Thượng Tá"],
	[17, 85, "Thượng Tá Cấp 2"],
	[18, 95, "Thượng Tá Cấp 3"],
	[19, 105, "Đại Tá"],
	[20, 115, "Đại Tá Cấp 2"],
	[21, 125, "Đại Tá Cấp 3"],
	[22, 135, "Chuẩn Tướng"],
	[23, 150, "Chuẩn Tướng Cấp 2"],
	[24, 165, "Chuẩn Tướng Cấp 3"],
	[25, 180, "Thiếu Tướng"],
	[26, 195, "Thiếu Tướng Cấp 2"],
	[27, 210, "Thiếu Tướng Cấp 3"],
	[28, 225, "Trung Tướng"],
	[29, 245, "Trung Tướng Cấp 2"],
	[30, 265, "Trung Tướng Cấp 3"],
	[31, 285, "Thượng Tướng"],
	[32, 305, "Thượng Tướng Cấp 2"],
	[33, 325, "Thượng Tướng Cấp 3"],
	[34, 345, "Đại Tướng Cấp 1"],
	[35, 370, "Đại Tướng Cấp 2"],
	[36, 395, "Đại Tướng Cấp 3"],
	[37, 420, "Nguyên Soái Cấp 1"],
	[38, 450, "Nguyên Soái Cấp 2"],
	[39, 480, "Nguyên Soái Cấp 3"],
	[40, 510, "Đại Nguyên Soái"],
]
const RANKS_PER_PAGE := 8
const ATTRIBUTE_FRAME_ACTIVE := [
	"img_mr_attr_item_m_lbk.png",
	"img_mr_attr_item_m_lbk.png",
	"img_mr_attr_item_m_lbk.png",
	"img_mr_attr_item_m_lbk.png",
	"img_mr_attr_item_b_lbk.png",
]
const ATTRIBUTE_FRAME_INACTIVE := [
	"img_mr_attr_item_m_bk.png",
	"img_mr_attr_item_m_bk.png",
	"img_mr_attr_item_m_bk.png",
	"img_mr_attr_item_m_bk.png",
	"img_mr_attr_item_b_bk.png",
]
const ATTRIBUTE_ICON_ACTIVE := [
	"attrIcon/img_phy_arm_active.png",
	"attrIcon/img_eng_arm_active.png",
	"attrIcon/img_ctsis_arm_active.png",
	"attrIcon/img_hpmax_active.png",
	"attrIcon/img_atk_active.png",
]
const ATTRIBUTE_ICON_INACTIVE := [
	"attrIcon/img_phy_arm_no_active.png",
	"attrIcon/img_eng_arm_no_active.png",
	"attrIcon/img_ctsis_arm_un_active.png",
	"attrIcon/img_hpmax_no_active.png",
	"attrIcon/img_atk_un_active.png",
]

var _window: Control
var _overview: Control
var _rank_list: Control
var _current_icon: TextureRect
var _next_icon: TextureRect
var _current_name: Label
var _next_name: Label
var _progress: Range
var _progress_text: Label
var _summary_text: RichTextLabel
var _activation_requirement: Label
var _attribute_frames: Array[TextureRect] = []
var _attribute_icons: Array[TextureRect] = []
var _attribute_labels: Array[Label] = []
var _special_rank_icon: TextureRect
var _special_rank_text: Label
var _cooldown_text: Label
var _rank_cards: Array[Dictionary] = []
var _page_buttons: Array[TextureButton] = []
var _page_prev_button: TextureButton
var _page_next_button: TextureButton
var _page := 0
var _stars := 0
var _owned_tank_count := 0
var _current_rank_index := 0
var _rank_progress_stars := 0
var _rank_progress_required := 5
var _stars_per_attribute := 1
var _attribute_unlock_count := 0
var _military_bonuses: Dictionary = {}
var _cooldown_reduction_percent := 0.0
var _panel_transition: Tween


func _ready() -> void:
	_build()
	if get_tree().current_scene == self:
		call_deferred("open")
	else:
		visible = false


func open() -> void:
	_refresh_account_rank()
	_show_overview()
	move_to_front()
	_panel_transition = PanelTransitionHelper.play_open(
		self,
		_window,
		_panel_transition
	)


func close() -> void:
	_panel_transition = PanelTransitionHelper.play_close(
		self,
		_window,
		_panel_transition
	)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.015, 0.04, 0.76)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)

	_window = WINDOW_FRAME_SCENE.instantiate() as Control
	_window.name = "Window"
	_window.set_anchors_preset(Control.PRESET_CENTER)
	_window.position = Vector2(-500.0, -290.0)
	_window.size = Vector2(1000.0, 580.0)
	add_child(_window)

	var close_button := _window.get_node("Header/CloseButton") as TextureButton
	close_button.pressed.connect(close)

	_bind_overview_scene()
	_bind_rank_popup_scene()


func _bind_overview_scene() -> void:
	_overview = _window.get_node("Overview") as Control
	_current_icon = _overview.get_node("CurrentIcon") as TextureRect
	_next_icon = _overview.get_node("NextIcon") as TextureRect
	_current_name = _overview.get_node("CurrentName") as Label
	_next_name = _overview.get_node("NextName") as Label
	_progress = _overview.get_node("Progress") as Range
	_progress_text = _overview.get_node("ProgressText") as Label
	_summary_text = _overview.get_node("SummaryText") as RichTextLabel
	_activation_requirement = _overview.get_node(
		"ActivationRequirement"
	) as Label
	_attribute_frames.assign([
		_overview.get_node("PhysicalArmorFrame") as TextureRect,
		_overview.get_node("EnergyArmorFrame") as TextureRect,
		_overview.get_node("PierceFrame") as TextureRect,
		_overview.get_node("HitPointsFrame") as TextureRect,
		_overview.get_node("AttackFrame") as TextureRect,
	])
	_attribute_icons.assign([
		_overview.get_node("PhysicalArmorIcon") as TextureRect,
		_overview.get_node("EnergyArmorIcon") as TextureRect,
		_overview.get_node("PierceIcon") as TextureRect,
		_overview.get_node("HitPointsIcon") as TextureRect,
		_overview.get_node("AttackIcon") as TextureRect,
	])
	_attribute_labels.assign([
		_overview.get_node("PhysicalArmorLabel") as Label,
		_overview.get_node("EnergyArmorLabel") as Label,
		_overview.get_node("PierceLabel") as Label,
		_overview.get_node("HitPointsLabel") as Label,
		_overview.get_node("AttackLabel") as Label,
	])
	_special_rank_icon = _overview.get_node("SpecialRankIcon") as TextureRect
	_special_rank_text = _overview.get_node("SpecialRankText") as Label
	_cooldown_text = _overview.get_node("CooldownText") as Label
	var list_button := _overview.get_node("WatchRankListButton") as TextureButton
	list_button.pressed.connect(_show_rank_list)
	list_button.mouse_entered.connect(
		_set_control_hover.bind(list_button, true)
	)
	list_button.mouse_exited.connect(
		_set_control_hover.bind(list_button, false)
	)


func _bind_rank_popup_scene() -> void:
	_rank_list = RANK_LEVEL_POPUP_SCENE.instantiate() as Control
	_rank_list.name = "RankLevelPopup"
	_rank_list.position = Vector2(50.0, 25.0)
	_rank_list.size = Vector2(900.0, 530.0)
	_rank_list.z_index = 50
	_window.add_child(_rank_list)
	var popup_close := _rank_list.get_node("CloseButton") as TextureButton
	popup_close.pressed.connect(_show_overview)

	_rank_cards.clear()
	for index in RANKS_PER_PAGE:
		var card := _rank_list.get_node("Cards/Card%d" % index) as Control
		_rank_cards.append({
			"panel": card,
			"icon": card.get_node("Icon") as TextureRect,
			"locked_overlay": card.get_node("LockedOverlay") as TextureRect,
			"requirement": card.get_node("Requirement") as Label,
			"name": card.get_node("Name") as Label,
		})

	_page_buttons.clear()
	for page_index in 5:
		var page_button := _rank_list.get_node(
			"PageButton%d" % page_index
		) as TextureButton
		page_button.pressed.connect(_set_page.bind(page_index))
		_page_buttons.append(page_button)
	_page_prev_button = _rank_list.get_node("PrevButton") as TextureButton
	_page_next_button = _rank_list.get_node("NextButton") as TextureButton
	_page_prev_button.pressed.connect(_show_previous_rank_page)
	_page_next_button.pressed.connect(_show_next_rank_page)
	_rank_list.visible = false


func _build_overview() -> void:
	_overview = Control.new()
	_overview.name = "Overview"
	_overview.position = Vector2(18.0, 50.0)
	_overview.size = Vector2(964.0, 520.0)
	_window.add_child(_overview)

	var left_background := TextureRect.new()
	left_background.texture = _asset_texture("img_mr_attr_list_bk.png")
	left_background.position = Vector2.ZERO
	left_background.size = Vector2(626.0, 520.0)
	left_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	left_background.stretch_mode = TextureRect.STRETCH_SCALE
	left_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overview.add_child(left_background)

	var right_background := TextureRect.new()
	right_background.texture = _asset_texture("img_mr_attr_bk.png")
	right_background.position = Vector2(626.0, 0.0)
	right_background.size = Vector2(338.0, 520.0)
	right_background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	right_background.stretch_mode = TextureRect.STRETCH_SCALE
	right_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overview.add_child(right_background)

	_current_icon = _rank_icon()
	_current_icon.position = Vector2(34.0, 8.0)
	_current_icon.size = Vector2(90.0, 96.0)
	_overview.add_child(_current_icon)
	_next_icon = _rank_icon()
	_next_icon.position = Vector2(500.0, 8.0)
	_next_icon.size = Vector2(90.0, 96.0)
	_overview.add_child(_next_icon)

	_current_name = _label("", 15, Color(1.0, 0.88, 0.08))
	_current_name.position = Vector2(10.0, 100.0)
	_current_name.size = Vector2(138.0, 28.0)
	_current_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overview.add_child(_current_name)
	_next_name = _label("", 15, Color.WHITE)
	_next_name.position = Vector2(476.0, 100.0)
	_next_name.size = Vector2(138.0, 28.0)
	_next_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overview.add_child(_next_name)

	var current_caption := _label("Chung", 14, Color(0.64, 0.91, 1.0))
	current_caption.position = Vector2(158.0, 19.0)
	current_caption.size = Vector2(100.0, 24.0)
	_overview.add_child(current_caption)
	var next_caption := _label("Lv sau", 14, Color(0.64, 0.91, 1.0))
	next_caption.position = Vector2(372.0, 19.0)
	next_caption.size = Vector2(90.0, 24.0)
	next_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_overview.add_child(next_caption)

	_progress = ProgressBar.new()
	_progress.position = Vector2(158.0, 46.0)
	_progress.size = Vector2(304.0, 23.0)
	(_progress as ProgressBar).show_percentage = false
	_progress.add_theme_stylebox_override(
		"background",
		_style_box(Color(0.0, 0.10, 0.20), Color(0.08, 0.65, 0.90), 2, 6)
	)
	_progress.add_theme_stylebox_override(
		"fill",
		_style_box(Color(0.20, 0.82, 1.0), Color(0.75, 0.96, 1.0), 1, 5)
	)
	_overview.add_child(_progress)

	_progress_text = _label("", 15, Color.WHITE)
	_progress_text.position = _progress.position
	_progress_text.size = _progress.size
	_progress_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_progress_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overview.add_child(_progress_text)

	var list_button := TextureButton.new()
	list_button.texture_normal = _asset_texture("btn_watch_mr_list_t.png")
	list_button.position = Vector2(266.0, 82.0)
	list_button.size = Vector2(90.0, 32.0)
	list_button.ignore_texture_size = true
	list_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	list_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	list_button.pressed.connect(_show_rank_list)
	_overview.add_child(list_button)

	var attribute_nodes := [
		["img_phy_arm_active.png", Vector2(24.0, 168.0), "Giáp Vật Lý +0.0"],
		["img_ctsis_arm_active.png", Vector2(228.0, 218.0), "Xuyên Thấu +0.0"],
		["img_eng_arm_active.png", Vector2(100.0, 294.0), "Khiên Năng Lượng +0.0"],
		["img_hpmax_active.png", Vector2(326.0, 350.0), "HP +0"],
		["img_atk_active.png", Vector2(500.0, 266.0), "TC +0.0"],
	]
	for node_data: Array in attribute_nodes:
		var attribute_icon := TextureRect.new()
		attribute_icon.texture = _asset_texture(
			"attrIcon/" + String(node_data[0])
		)
		attribute_icon.position = node_data[1]
		attribute_icon.size = Vector2(78.0, 84.0)
		attribute_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		attribute_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		attribute_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overview.add_child(attribute_icon)
		var attribute_label := _label(String(node_data[2]), 12, Color.WHITE)
		attribute_label.position = Vector2(
			attribute_icon.position.x - 31.0,
			attribute_icon.position.y + 77.0
		)
		attribute_label.size = Vector2(140.0, 25.0)
		attribute_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_overview.add_child(attribute_label)

	var activation_requirement := _label(
		"ĐK kích hoạt skill kế tiếp:  ★ x4",
		14,
		Color.WHITE
	)
	activation_requirement.position = Vector2(205.0, 478.0)
	activation_requirement.size = Vector2(330.0, 30.0)
	activation_requirement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overview.add_child(activation_requirement)

	var summary_title := _label("Thuộc Tính Quân Hàm", 18, Color(0.72, 0.94, 1.0))
	summary_title.position = Vector2(637.0, 23.0)
	summary_title.size = Vector2(316.0, 32.0)
	summary_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overview.add_child(summary_title)

	_summary_text = RichTextLabel.new()
	_summary_text.bbcode_enabled = true
	_summary_text.fit_content = false
	_summary_text.scroll_active = false
	_summary_text.position = Vector2(651.0, 66.0)
	_summary_text.size = Vector2(286.0, 168.0)
	_summary_text.add_theme_font_size_override("normal_font_size", 16)
	_summary_text.add_theme_font_size_override("bold_font_size", 16)
	_overview.add_child(_summary_text)

	var description_panel := Panel.new()
	description_panel.position = Vector2(646.0, 235.0)
	description_panel.size = Vector2(298.0, 86.0)
	description_panel.clip_contents = true
	description_panel.add_theme_stylebox_override(
		"panel",
		_style_box(Color(0.01, 0.11, 0.22, 0.72), Color(0.04, 0.25, 0.40), 1, 1)
	)
	_overview.add_child(description_panel)
	var description := _label(
		"Giới thiệu:\nCứ mỗi tăng 1 cấp Tank sẽ nhận được 1 Ngôi Sao,\n"
		+ "tích lũy đạt số lượng nhất định sẽ tăng Quân Hàm.",
		12,
		Color.WHITE
	)
	description.position = Vector2(8.0, 7.0)
	description.size = Vector2(274.0, 72.0)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.clip_text = true
	description_panel.add_child(description)

	var special_rank_icon := _rank_icon()
	special_rank_icon.texture = _rank_texture(10)
	special_rank_icon.position = Vector2(656.0, 360.0)
	special_rank_icon.size = Vector2(78.0, 84.0)
	_overview.add_child(special_rank_icon)
	var activate_label := _label("Kích hoạt", 16, Color(1.0, 0.88, 0.08))
	activate_label.position = Vector2(740.0, 370.0)
	activate_label.size = Vector2(100.0, 25.0)
	activate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overview.add_child(activate_label)
	var cooldown_icon := TextureRect.new()
	cooldown_icon.texture = _asset_texture(
		"attrIcon/img_common_cool_no_active.png"
	)
	cooldown_icon.position = Vector2(860.0, 377.0)
	cooldown_icon.size = Vector2(58.0, 64.0)
	cooldown_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cooldown_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	cooldown_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overview.add_child(cooldown_icon)
	var rank_special_text := _label(
		"Quân hàm Thiếu Tá kích hoạt thuộc tính",
		11,
		Color.WHITE
	)
	rank_special_text.position = Vector2(632.0, 446.0)
	rank_special_text.size = Vector2(190.0, 42.0)
	rank_special_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rank_special_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_overview.add_child(rank_special_text)
	var cooldown_text := _label("CD Skill -0.5%", 12, Color.WHITE)
	cooldown_text.position = Vector2(830.0, 447.0)
	cooldown_text.size = Vector2(120.0, 24.0)
	cooldown_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overview.add_child(cooldown_text)


func _build_rank_list() -> void:
	_rank_list = Control.new()
	_rank_list.name = "RankList"
	_rank_list.position = Vector2(18.0, 50.0)
	_rank_list.size = Vector2(964.0, 520.0)
	_window.add_child(_rank_list)

	var background := Panel.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.add_theme_stylebox_override(
		"panel",
		_style_box(Color(0.015, 0.22, 0.39, 0.99), Color(0.08, 0.56, 0.86), 2, 8)
	)
	_rank_list.add_child(background)

	var list_title := _label("Cấp Quân Hàm", 20, Color.WHITE)
	list_title.position = Vector2(0.0, 6.0)
	list_title.size = Vector2(964.0, 30.0)
	list_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_rank_list.add_child(list_title)

	var back_button := Button.new()
	back_button.text = "‹ Quay lại"
	back_button.position = Vector2(14.0, 6.0)
	back_button.size = Vector2(106.0, 30.0)
	back_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_button.add_theme_font_size_override("font_size", 15)
	back_button.pressed.connect(_show_overview)
	_rank_list.add_child(back_button)

	for index in RANKS_PER_PAGE:
		var card := Panel.new()
		var column := index % 4
		var row := index / 4
		card.position = Vector2(12.0 + column * 238.0, 42.0 + row * 205.0)
		card.size = Vector2(226.0, 192.0)
		_rank_list.add_child(card)

		var icon := _rank_icon()
		icon.position = Vector2(61.0, 16.0)
		icon.size = Vector2(104.0, 112.0)
		card.add_child(icon)

		var requirement := _label("", 16, Color(1.0, 0.90, 0.0))
		requirement.position = Vector2(4.0, 77.0)
		requirement.size = Vector2(218.0, 32.0)
		requirement.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		requirement.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		requirement.add_theme_color_override("font_outline_color", Color(0.0, 0.05, 0.08))
		requirement.add_theme_constant_override("outline_size", 3)
		card.add_child(requirement)

		var name_label := _label("", 17, Color.WHITE)
		name_label.position = Vector2(5.0, 151.0)
		name_label.size = Vector2(216.0, 34.0)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		card.add_child(name_label)

		_rank_cards.append({
			"panel": card,
			"icon": icon,
			"requirement": requirement,
			"name": name_label,
		})

	for page_index in 5:
		var page_button := Button.new()
		page_button.text = str(page_index + 1)
		page_button.position = Vector2(370.0 + page_index * 48.0, 470.0)
		page_button.size = Vector2(38.0, 34.0)
		page_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		page_button.add_theme_font_size_override("font_size", 17)
		page_button.pressed.connect(_set_page.bind(page_index))
		_rank_list.add_child(page_button)
		_page_buttons.append(page_button)


func _refresh_account_rank() -> void:
	var lobby: Dictionary = GameSession.lobby_data
	var owned_value: Variant = lobby.get("owned_tanks", [])
	var owned_tanks: Array = owned_value if owned_value is Array else []
	_owned_tank_count = owned_tanks.size()
	_stars = 0
	for tank_value: Variant in owned_tanks:
		if tank_value is Dictionary:
			_stars += maxi(1, int(tank_value.get("tank_level", 1)))

	var server_rank_value: Variant = lobby.get("military_rank", {})
	var server_rank: Dictionary = (
		server_rank_value if server_rank_value is Dictionary else {}
	)
	if server_rank_value is Dictionary:
		_stars = maxi(0, int(server_rank.get("stars", _stars)))
		_owned_tank_count = maxi(
			0,
			int(server_rank.get("owned_tank_count", _owned_tank_count))
		)

	if GameSession.profile.is_empty() and lobby.is_empty():
		_stars = 1
		_owned_tank_count = 1

	var state := _rank_state_for_stars(_stars)
	_current_rank_index = int(state["rank_index"])
	_rank_progress_stars = int(state["progress_stars"])
	_rank_progress_required = int(state["progress_required"])
	_stars_per_attribute = int(state["stars_per_attribute"])
	_attribute_unlock_count = int(state["attribute_unlock_count"])
	_military_bonuses = state["bonuses"] as Dictionary
	_cooldown_reduction_percent = float(
		state["cooldown_reduction_percent"]
	)

	if not server_rank.is_empty():
		_current_rank_index = clampi(
			int(server_rank.get("current_index", _current_rank_index)),
			0,
			RANKS.size() - 1
		)
		_rank_progress_stars = maxi(
			0,
			int(server_rank.get("progress_stars", _rank_progress_stars))
		)
		_rank_progress_required = maxi(
			0,
			int(server_rank.get("progress_required", _rank_progress_required))
		)
		_stars_per_attribute = maxi(
			1,
			int(server_rank.get(
				"stars_per_attribute",
				_stars_per_attribute
			))
		)
		_attribute_unlock_count = clampi(
			int(server_rank.get(
				"attribute_unlock_count",
				_attribute_unlock_count
			)),
			0,
			5
		)
		var server_bonuses_value: Variant = server_rank.get("bonuses", {})
		if (
			server_bonuses_value is Dictionary
			and not (server_bonuses_value as Dictionary).is_empty()
		):
			_military_bonuses = server_bonuses_value
		_cooldown_reduction_percent = maxf(
			0.0,
			float(server_rank.get(
				"cooldown_reduction_percent",
				_cooldown_reduction_percent
			))
		)

	var current: Array = RANKS[_current_rank_index]
	var next: Array = current
	if _current_rank_index + 1 < RANKS.size():
		next = RANKS[_current_rank_index + 1]

	_current_icon.texture = _rank_texture(int(current[0]))
	_current_name.text = String(current[2])
	_next_icon.texture = _rank_texture(int(next[0]))
	_next_name.text = (
		String(next[2])
		if _current_rank_index + 1 < RANKS.size()
		else "Đã tối đa"
	)

	if _current_rank_index + 1 < RANKS.size():
		_progress.max_value = maxf(1.0, float(_rank_progress_required))
		_progress.value = clampf(
			float(_rank_progress_stars),
			0.0,
			float(_rank_progress_required)
		)
		_progress_text.text = "%d/%d" % [
			_rank_progress_stars,
			_rank_progress_required,
		]
	else:
		_progress.max_value = 1.0
		_progress.value = 1.0
		_progress_text.text = "TỐI ĐA"

	var physical_armor := float(_military_bonuses.get("physical_armor", 0.0))
	var energy_shield := float(_military_bonuses.get("energy_shield", 0.0))
	var penetration := float(_military_bonuses.get("penetration", 0.0))
	var hit_points := float(_military_bonuses.get("hit_points", 0.0))
	var attack := float(_military_bonuses.get("basic_attack_damage", 0.0))
	var displayed_physical_armor := _round_stat_bonus(physical_armor)
	var displayed_energy_shield := _round_stat_bonus(energy_shield)
	var displayed_penetration := _round_stat_bonus(penetration)
	var displayed_hit_points := _round_stat_bonus(hit_points)
	var displayed_attack := _round_stat_bonus(attack)
	var cooldown_text_value := (
		"-%.1f%%" % _cooldown_reduction_percent
		if _cooldown_reduction_percent > 0.0
		else "0.0%"
	)
	_summary_text.text = (
		"[table=2]"
		+ "[cell][right][color=#ffffff][b]Giáp Vật Lý:[/b][/color][/right][/cell]"
		+ "[cell][left]   [color=#ffe20b][b]+%d[/b][/color][/left][/cell]" % displayed_physical_armor
		+ "[cell][right][color=#ffffff][b]Giáp Năng Lượng:[/b][/color][/right][/cell]"
		+ "[cell][left]   [color=#ffe20b][b]+%d[/b][/color][/left][/cell]" % displayed_energy_shield
		+ "[cell][right][color=#ffffff][b]Xuyên:[/b][/color][/right][/cell]"
		+ "[cell][left]   [color=#ffe20b][b]+%d[/b][/color][/left][/cell]" % displayed_penetration
		+ "[cell][right][color=#ffffff][b]HP:[/b][/color][/right][/cell]"
		+ "[cell][left]   [color=#ffe20b][b]+%d[/b][/color][/left][/cell]" % displayed_hit_points
		+ "[cell][right][color=#ffffff][b]TC:[/b][/color][/right][/cell]"
		+ "[cell][left]   [color=#ffe20b][b]+%d[/b][/color][/left][/cell]" % displayed_attack
		+ "[cell][right][color=#ffffff][b]CD Skill:[/b][/color][/right][/cell]"
		+ "[cell][left]   [color=#ffe20b][b]%s[/b][/color][/left][/cell]" % cooldown_text_value
		+ "[/table]"
	)
	_refresh_attribute_unlocks(_current_rank_index)
	_refresh_cooldown_milestone()
	_refresh_rank_cards()


func _round_stat_bonus(value: float) -> int:
	var safe_value := maxf(0.0, value)
	var lower_value := floori(safe_value)
	return lower_value + 1 if safe_value - lower_value > 0.5 else lower_value


func _show_overview() -> void:
	_overview.visible = true
	_rank_list.visible = false


func _show_rank_list() -> void:
	_page = clampi(_rank_index_for_stars(_stars) / RANKS_PER_PAGE, 0, 4)
	_refresh_rank_cards()
	_overview.visible = true
	_rank_list.visible = true
	_rank_list.move_to_front()


func _set_page(page_index: int) -> void:
	_page = clampi(page_index, 0, 4)
	_refresh_rank_cards()


func _show_previous_rank_page() -> void:
	_set_page(_page - 1)


func _show_next_rank_page() -> void:
	_set_page(_page + 1)


func _refresh_rank_cards() -> void:
	for card_index in RANKS_PER_PAGE:
		var rank_index := _page * RANKS_PER_PAGE + card_index
		var card: Dictionary = _rank_cards[card_index]
		var icon := card["icon"] as TextureRect
		var locked_overlay := card["locked_overlay"] as TextureRect
		var requirement := card["requirement"] as Label
		var name_label := card["name"] as Label
		var rank: Array = RANKS[rank_index]
		var unlocked := rank_index <= _current_rank_index

		icon.texture = _rank_texture(int(rank[0]))
		icon.modulate = Color.WHITE
		locked_overlay.visible = not unlocked
		name_label.text = String(rank[2])
		name_label.modulate = Color.WHITE if unlocked else Color(0.60, 0.64, 0.66)
		requirement.text = "" if unlocked else "Sao đạt %d sẽ mở" % int(rank[1])

	for index in _page_buttons.size():
		var button := _page_buttons[index]
		button.disabled = index == _page
		button.modulate = Color.WHITE
	_page_prev_button.visible = _page > 0
	_page_next_button.visible = _page < 4


func _refresh_attribute_unlocks(current_rank_index: int) -> void:
	var is_maximum_rank := current_rank_index + 1 >= RANKS.size()
	var unlocked_count := 5 if is_maximum_rank else _attribute_unlock_count
	var remainder := _rank_progress_stars % _stars_per_attribute
	var stars_until_next_attribute := (
		_stars_per_attribute
		if remainder == 0
		else _stars_per_attribute - remainder
	)
	_activation_requirement.text = (
		"Đã kích hoạt toàn bộ thuộc tính Quân Hàm"
		if is_maximum_rank
		else "ĐK kích hoạt skill kế tiếp:  ★ x%d" % stars_until_next_attribute
	)

	for attribute_index in _attribute_icons.size():
		var unlocked := attribute_index < unlocked_count
		_attribute_frames[attribute_index].texture = _asset_texture(
			(
				ATTRIBUTE_FRAME_ACTIVE[attribute_index]
				if unlocked
				else ATTRIBUTE_FRAME_INACTIVE[attribute_index]
			)
		)
		_attribute_icons[attribute_index].texture = _asset_texture(
			(
				ATTRIBUTE_ICON_ACTIVE[attribute_index]
				if unlocked
				else ATTRIBUTE_ICON_INACTIVE[attribute_index]
			)
		)
		if attribute_index < _attribute_labels.size():
			var label := _attribute_labels[attribute_index]
			if attribute_index == 0:
				label.text = "Giáp Vật Lý +1.6"
			elif attribute_index == 1:
				label.text = "Khiên Năng Lượng +1.6"
			elif attribute_index == 2:
				label.text = "Xuyên Thấu +1.6"
			elif attribute_index == 3:
				label.text = "HP +24"
			else:
				label.text = "TC +1.6"


func _refresh_cooldown_milestone() -> void:
	var current_rank_id := _current_rank_index + 1
	var milestone_rank_id := 4
	while milestone_rank_id <= current_rank_id:
		milestone_rank_id += 4
	if milestone_rank_id > RANKS.size():
		_special_rank_icon.texture = _rank_texture(RANKS.size())
		_special_rank_text.text = "Đã kích hoạt toàn bộ mốc giảm CD Skill"
		_cooldown_text.text = "Tổng -%.1f%%" % _cooldown_reduction_percent
		return
	var milestone: Array = RANKS[milestone_rank_id - 1]
	_special_rank_icon.texture = _rank_texture(milestone_rank_id)
	_special_rank_text.text = (
		"Quân hàm %s kích hoạt thuộc tính" % String(milestone[2])
	)
	_cooldown_text.text = "CD Skill -0.5%"


func _set_control_hover(control: CanvasItem, hovered: bool) -> void:
	control.modulate = Color(1.45, 1.45, 1.45, 1.0) if hovered else Color.WHITE


func _rank_index_for_stars(stars: int) -> int:
	return int(_rank_state_for_stars(stars)["rank_index"])


func _rank_state_for_stars(stars: int) -> Dictionary:
	var rank_index := 0
	var progress_stars := maxi(stars, 0)
	while rank_index + 1 < RANKS.size():
		var required := int(RANKS[rank_index + 1][1])
		if progress_stars < required:
			break
		progress_stars = progress_stars - required + 1
		rank_index += 1
	var progress_required := (
		int(RANKS[rank_index + 1][1])
		if rank_index + 1 < RANKS.size()
		else 0
	)
	var stars_per_attribute := rank_index + 1
	var unlocked_count := (
		5
		if rank_index + 1 >= RANKS.size()
		else mini(
			4,
			floori(float(progress_stars) / float(stars_per_attribute))
		)
	)
	var completed_ranks := rank_index
	var bonuses := {
		"physical_armor": (
			completed_ranks + (1 if unlocked_count >= 1 else 0)
		) * 1.6,
		"energy_shield": (
			completed_ranks + (1 if unlocked_count >= 2 else 0)
		) * 1.6,
		"penetration": (
			completed_ranks + (1 if unlocked_count >= 3 else 0)
		) * 1.6,
		"hit_points": (
			completed_ranks + (1 if unlocked_count >= 4 else 0)
		) * 24.0,
		"basic_attack_damage": (
			completed_ranks + (1 if unlocked_count >= 5 else 0)
		) * 1.6,
	}
	return {
		"rank_index": rank_index,
		"progress_stars": progress_stars,
		"progress_required": progress_required,
		"stars_per_attribute": stars_per_attribute,
		"attribute_unlock_count": unlocked_count,
		"bonuses": bonuses,
		"cooldown_reduction_percent": floori(
			float(rank_index + 1) / 4.0
		) * 0.5,
	}


func _rank_texture(rank_id: int) -> Texture2D:
	var actual_id := mini(rank_id, 33)
	return _asset_texture("rank/Junxian%02d.png" % actual_id)


func _asset_texture(relative_path: String) -> Texture2D:
	return AssetPathAliases.load_texture(ASSET_ROOT + relative_path)


func _rank_icon() -> TextureRect:
	var icon := TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _label(text_value: String, size_value: int, color: Color) -> Label:
	var result := Label.new()
	result.text = text_value
	result.add_theme_font_size_override("font_size", size_value)
	result.add_theme_color_override("font_color", color)
	result.add_theme_color_override("font_outline_color", Color(0.0, 0.10, 0.18))
	result.add_theme_constant_override("outline_size", 2)
	return result


func _style_box(
	background: Color,
	border: Color,
	border_width: int,
	radius: int
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	return style
