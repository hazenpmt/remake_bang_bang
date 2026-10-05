extends Control

signal shop_action_requested(action: StringName, offer: Dictionary)

const ShopCatalog := preload("res://scripts/data/shop_catalog.gd")
const ContentDelivery := preload("res://scripts/network/content_delivery.gd")
const CardScene := preload("res://scenes/lobby/shop/ShopProductCard.tscn")
const TAB_NORMAL := preload("res://assets/ui/shop/controls/shop_navItem.png")
const TAB_SELECTED := preload("res://assets/ui/shop/controls/shop_navItemSelected.png")
const SUB_NORMAL: Array[Texture2D] = [
	preload("res://assets/ui/shop/controls/shop_subnavItem_left.png"),
	preload("res://assets/ui/shop/controls/shop_subnavItem_center.png"),
	preload("res://assets/ui/shop/controls/shop_subnavItem_right.png"),
]
const SUB_SELECTED: Array[Texture2D] = [
	preload("res://assets/ui/shop/controls/shop_subnavItemSelected_left.png"),
	preload("res://assets/ui/shop/controls/shop_subnavItemSelected_center.png"),
	preload("res://assets/ui/shop/controls/shop_subnavItemSelected_right.png"),
]
const PAGE_NORMAL := preload("res://assets/ui/tank/pager_blue.png")
const PAGE_SELECTED := preload("res://assets/ui/tank/pager_selected.png")
const PAGE_DEFAULT_COLOR := Color("fbf8f8")
const PAGE_SELECTED_COLOR := Color("126df6")
const LEVEL_FX_11_20 := \
	"res://assets/animations/profile_level_11_20_effect1_compact/timeline.json"
const LEVEL_FX_21_30 := \
	"res://assets/animations/profile_level_21_30_fx_compact/timeline.json"
const LEVEL_FX_31_35 := \
	"res://assets/animations/profile_level_31_35_fx_compact/timeline.json"
const LEVEL_FX_36_40 := \
	"res://assets/animations/profile_level_36_40_fx_compact/timeline.json"
const PanelTransitionHelper := preload("res://scripts/ui/panel_transition.gd")

@onready var _window: Control = $Window
@onready var _tabs: Array[TextureButton] = [
	$Window/Content/Tabs/Recommend, $Window/Content/Tabs/Tank,
	$Window/Content/Tabs/Skin, $Window/Content/Tabs/Fashion,
	$Window/Content/Tabs/Decoration, $Window/Content/Tabs/Vip,
	$Window/Content/Tabs/Material, $Window/Content/Tabs/Assistant,
]
@onready var _subtabs: Array[TextureButton] = [
	$Window/Content/SubTabs/All,
	$Window/Content/SubTabs/Sale,
	$Window/Content/SubTabs/LockedXu,
]
@onready var _cards: Control = $Window/Content/Cards
@onready var _pages: Array[TextureButton] = [
	$Window/Pagination/Page1, $Window/Pagination/Page2,
	$Window/Pagination/Page3, $Window/Pagination/Page4,
	$Window/Pagination/Page5, $Window/Pagination/Page6,
]
@onready var _level_effect: SwfTimelinePlayer = $Window/Avatar/LevelEffect

var _category_index := 0
var _filter_index := 0
var _page := 1
var _panel_transition: Tween


func _ready() -> void:
	$Window/Close.pressed.connect(close)
	$Window/Pack.pressed.connect(_open_bag)
	$Window/Pagination/Prev.pressed.connect(_change_page.bind(-1))
	$Window/Pagination/Next.pressed.connect(_change_page.bind(1))
	for index in _tabs.size():
		_tabs[index].pressed.connect(_select_category.bind(index))
	for index in _subtabs.size():
		_subtabs[index].pressed.connect(_select_filter.bind(index))
	for index in _pages.size():
		_prepare_page_button(_pages[index], index + 1)
	if not GameSession.lobby_data_changed.is_connected(
		_on_lobby_data_changed
	):
		GameSession.lobby_data_changed.connect(_on_lobby_data_changed)
	_refresh_profile()
	_refresh()


func open() -> void:
	# Online sessions never trust local price/ownership data. The local catalog
	# is only a preview/offline authoring source; PostgreSQL is authoritative.
	if not GameSession.token.is_empty() and GameSession.admission_active:
		var result := await GameSession.fetch_shop_catalog()
		if not result.get("ok", false):
			_emit_result_error(result)
			return
		var content_task_id := GameSession.begin_interactive_task(
			"Đang đồng bộ nội dung Shop..."
		)
		var content_result := await ContentDelivery.sync_catalog_assets(
			result.get("catalog", {}), GameSession.api_base_url
		)
		GameSession.finish_interactive_task(content_task_id, content_result)
		if not content_result.get("ok", false):
			var content_error: Dictionary = content_result.get("error", {})
			push_warning(
				"Shop content delivery: %s" % String(
					content_error.get("message", "Không tải được asset động.")
				)
			)
		if not ShopCatalog.apply_server_catalog(result.get("catalog", {})):
			shop_action_requested.emit(&"error", {
				"message": "Dữ liệu Shop từ máy chủ không hợp lệ."
			})
			return
	else:
		# Editor/test preview still supports external packages without a server.
		ShopCatalog.reload()
	_category_index = clampi(
		_category_index, 0, ShopCatalog.CATEGORY_KEYS.size() - 1
	)
	_page = 1
	_refresh_profile()
	_refresh()
	_panel_transition = PanelTransitionHelper.play_open(
		self, _window, _panel_transition
	)


func apply_server_purchase(purchase: Dictionary) -> void:
	ShopCatalog.apply_purchase(purchase)
	_refresh_profile()
	_refresh_cards()
	_refresh_pagination()


func _emit_result_error(result: Dictionary) -> void:
	var error: Dictionary = result.get("error", {})
	shop_action_requested.emit(&"error", {
		"status": int(result.get("status", 0)),
		"message": String(error.get("message", "Không tải được Shop.")),
	})


func close() -> void:
	_panel_transition = PanelTransitionHelper.play_close(
		self, _window, _panel_transition
	)


func _select_category(index: int) -> void:
	_category_index = clampi(index, 0, ShopCatalog.CATEGORY_KEYS.size() - 1)
	_page = 1
	_refresh()


func _select_filter(index: int) -> void:
	_filter_index = clampi(index, 0, 2)
	_page = 1
	_refresh()


func _change_page(delta: int) -> void:
	var count := _page_count()
	var next_page := _page + delta
	if next_page < 1:
		next_page = count
	elif next_page > count:
		next_page = 1
	_set_page(next_page)


func _set_page(next_page: int) -> void:
	_page = clampi(next_page, 1, _page_count())
	_refresh_cards()
	_refresh_pagination()


func _refresh() -> void:
	_refresh_tabs()
	_refresh_subtabs()
	_refresh_cards()
	_refresh_pagination()


func _refresh_tabs() -> void:
	for index in _tabs.size():
		_tabs[index].texture_normal = (
			TAB_SELECTED if index == _category_index else TAB_NORMAL
		)


func _refresh_subtabs() -> void:
	for index in _subtabs.size():
		_subtabs[index].texture_normal = (
			SUB_SELECTED[index] if index == _filter_index else SUB_NORMAL[index]
		)


func _refresh_cards() -> void:
	for child in _cards.get_children():
		child.queue_free()
	var category: StringName = ShopCatalog.CATEGORY_KEYS[_category_index]
	var items := _filtered_items(category)
	var per_page := 3 if ShopCatalog.is_large(category) else 6
	var start := (_page - 1) * per_page
	for slot in per_page:
		var item_index := start + slot
		if item_index >= items.size():
			break
		var card := CardScene.instantiate() as Control
		if card == null:
			continue
		card.position = (
			Vector2(slot * 250, 0)
			if per_page == 3
			else Vector2((slot % 3) * 250, (slot / 3) * 190)
		)
		_cards.add_child(card)
		card.call("setup", items[item_index], category)
		card.connect("action_requested", _on_card_action)


func _refresh_pagination() -> void:
	var count := _page_count()
	_page = clampi(_page, 1, count)
	_ensure_page_buttons(count)
	var visible_count := count
	# PageNumListFrame + PageNumProxy in the Flash client use a 616 px host,
	# 28 px per page and 30 px at both ends, then center that list.
	var list_width := float(visible_count * 28 + 60)
	var list_x := floorf((616.0 - list_width) * 0.5)
	$Window/Pagination/Prev.position = Vector2(list_x, 0.0)
	$Window/Pagination/Next.position = Vector2(
		list_x + list_width - 33.0,
		0.0
	)
	for index in _pages.size():
		var page := _pages[index]
		page.visible = index < visible_count
		page.position = Vector2(list_x + 32.0 + index * 28.0, 2.0)
		var selected := index + 1 == _page
		page.texture_normal = PAGE_SELECTED if selected else PAGE_NORMAL
		var label := page.get_node("Text") as Label
		label.text = str(index + 1)
		label.add_theme_color_override(
			"font_color",
			PAGE_SELECTED_COLOR if selected else PAGE_DEFAULT_COLOR
		)
	$Window/Pagination/Prev.disabled = false
	$Window/Pagination/Next.disabled = false


func _ensure_page_buttons(count: int) -> void:
	while _pages.size() < count:
		var page_number := _pages.size() + 1
		var page := TextureButton.new()
		page.name = "Page%d" % page_number
		page.size = Vector2(24, 24)
		page.ignore_texture_size = true
		page.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		var label := Label.new()
		label.name = "Text"
		label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.add_theme_font_size_override("font_size", 12)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		page.add_child(label)
		$Window/Pagination.add_child(page)
		_pages.append(page)
		_prepare_page_button(page, page_number)


func _prepare_page_button(page: TextureButton, page_number: int) -> void:
	page.ignore_texture_size = true
	page.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	page.size = Vector2(24, 24)
	if not page.pressed.is_connected(_set_page.bind(page_number)):
		page.pressed.connect(_set_page.bind(page_number))


func _page_count() -> int:
	var category: StringName = ShopCatalog.CATEGORY_KEYS[_category_index]
	var per_page := 3 if ShopCatalog.is_large(category) else 6
	return maxi(1, ceili(float(_filtered_items(category).size()) / float(per_page)))


func _filtered_items(category: StringName) -> Array:
	var result := ShopCatalog.items(category)
	if _filter_index == 1:
		result = result.filter(func(item: Dictionary) -> bool:
			var badges: Array = item.get("badges", []) as Array
			return (
				badges.has("sale")
				or int(item.get("original_price", 0))
					> int(item.get("price", 0))
			)
		)
	elif _filter_index == 2:
		result = result.filter(func(item: Dictionary) -> bool:
			return StringName(item.get("currency", "")) == &"locked_xu"
		)
	return result


func _refresh_profile() -> void:
	var data := GameSession.profile.duplicate()
	data.merge(GameSession.lobby_data, true)
	var is_preview := data.is_empty()
	$Window/Avatar/Character.texture = (
		load("res://assets/ui/profile/character_female_rgba.png")
		if String(data.get("gender", "male")) == "female"
		else load("res://assets/ui/profile/character_male_rgba.png")
	)
	$Window/Avatar/Name.text = String(data.get("display_name", "Beenn"))
	var level := clampi(int(data.get("level", 15 if is_preview else 1)), 1, 40)
	_refresh_level_badge(level)
	$Window/Currencies/Xu/Value.text = _format_number(int(data.get("xu", 10997 if is_preview else 0)))
	$Window/Currencies/LockedXu/Value.text = _format_number(int(data.get("locked_xu", 23670 if is_preview else 0)))
	$Window/Currencies/Silver/Value.text = _format_number(int(data.get("silver", 5144770 if is_preview else 0)))


func _refresh_level_badge(level: int) -> void:
	$Window/Avatar/Level.texture = load(
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
		_level_effect.stop()
		_level_effect.visible = false
		return
	_level_effect.scale = (
		Vector2(0.616, 0.616)
		if level <= 20
		else Vector2(0.7, 0.7)
	)
	_level_effect.modulate = Color.WHITE
	if _level_effect.timeline_path != effect_path:
		_level_effect.load_timeline(effect_path)
	_level_effect.visible = true
	_level_effect.play()


func _on_card_action(action: StringName, offer: Dictionary) -> void:
	shop_action_requested.emit(action, offer)


func _open_bag() -> void:
	shop_action_requested.emit(&"open_bag", {})


func _on_lobby_data_changed(_data: Dictionary) -> void:
	_refresh_profile()


func _format_number(value: int) -> String:
	var source := str(maxi(0, value))
	var result := ""
	while source.length() > 3:
		result = "," + source.right(3) + result
		source = source.left(source.length() - 3)
	return source + result
