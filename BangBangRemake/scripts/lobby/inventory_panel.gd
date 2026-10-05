extends Control

const AssetPathAliases := preload("res://scripts/data/asset_path_aliases.gd")

signal tab_changed(tab_index: int)
signal inventory_action_requested(action: StringName)

const TAB_NORMAL := preload(
	"res://assets/ui/inventory/tabs/shop_navItem_s.png"
)
const TAB_SELECTED := preload(
	"res://assets/ui/inventory/tabs/shop_navItem_s_Selected.png"
)
const EMPTY_SLOT := preload(
	"res://assets/ui/inventory/tankbarn/BagItem_BK.png"
)
const SPRAY_CELL := preload(
	"res://assets/ui/inventory/tankbarn/paintword_cell_bk.png"
)
const SPRAY_CELL_SELECTED := preload(
	"res://assets/ui/inventory/tankbarn/paintword_cell_selected.png"
)
const SPRAY_SELECTED_TICK := preload(
	"res://assets/ui/inventory/public/tick.png"
)
const ACHIEVEMENT_FILTER_SELECTED := preload(
	"res://assets/ui/inventory/public/button_2_green.png"
)
const HoverPressTextureButtonScript := preload(
	"res://scripts/ui/HoverPressTextureButton.gd"
)
const LEVEL_FX_11_20 := \
	"res://assets/animations/profile_level_11_20_effect1_compact/timeline.json"
const LEVEL_FX_21_30 := \
	"res://assets/animations/profile_level_21_30_fx_compact/timeline.json"
const LEVEL_FX_31_35 := \
	"res://assets/animations/profile_level_31_35_fx_compact/timeline.json"
const LEVEL_FX_36_40 := \
	"res://assets/animations/profile_level_36_40_fx_compact/timeline.json"
const ProfileProgression := preload("res://scripts/data/profile_progression.gd")
const ShopCatalog := preload("res://scripts/data/shop_catalog.gd")
const PanelTransitionHelper := preload("res://scripts/ui/panel_transition.gd")

const SPRAY_TEXTURES: Array[Texture2D] = [
	preload("res://assets/ui/inventory/preview/spray01.png"),
	preload("res://assets/ui/inventory/preview/spray02.png"),
	preload("res://assets/ui/inventory/preview/spray03.png"),
	preload("res://assets/ui/inventory/preview/spray04.png"),
	preload("res://assets/ui/inventory/preview/spray05_t.png"),
	preload("res://assets/ui/inventory/preview/spray06.png"),
	preload("res://assets/ui/inventory/preview/spray07_t.png"),
	preload("res://assets/ui/inventory/preview/spray08_t.png"),
	preload("res://assets/ui/inventory/preview/spray09.png"),
	preload("res://assets/ui/inventory/preview/spray10_t.png"),
]

@onready var _tab_buttons: Array[TextureButton] = [
	$Window/TabBar/TabItems,
	$Window/TabBar/TabMaterials,
	$Window/TabBar/TabFashion,
	$Window/TabBar/TabDecoration,
	$Window/TabBar/TabAchievements,
	$Window/TabBar/TabSpray,
]
@onready var _views: Array[Control] = [
	$Window/ContentFrame/Viewport/ItemsView,
	$Window/ContentFrame/Viewport/MaterialsView,
	$Window/ContentFrame/Viewport/FashionView,
	$Window/ContentFrame/Viewport/DecorationView,
	$Window/ContentFrame/Viewport/AchievementsView,
	$Window/ContentFrame/Viewport/SprayView,
]
@onready var _items_grid: Control = \
	$Window/ContentFrame/Viewport/ItemsView/ItemGrid
@onready var _materials_grid: Control = \
	$Window/ContentFrame/Viewport/MaterialsView/ItemGrid
@onready var _spray_grid: Control = \
	$Window/ContentFrame/Viewport/SprayView/SprayGrid
@onready var _profile_name: Label = $Window/ProfileName
@onready var _level_base: TextureRect = $Window/Level/Base
@onready var _level_effect: SwfTimelinePlayer = $Window/Level/Effect
@onready var _exp_bar: TextureProgressBar = $Window/ExpBar
@onready var _exp_value: Label = $Window/ExpValue
@onready var _guild_value: Label = $Window/GuildValue
@onready var _wins_value: Label = $Window/WinsValue
@onready var _run_value: Label = $Window/RunValue
@onready var _daily_value: Label = $Window/DailyValue
@onready var _xu_value: Label = \
	$Window/ContentFrame/Viewport/ItemsView/XuValue
@onready var _locked_xu_value: Label = \
	$Window/ContentFrame/Viewport/ItemsView/LockedXuValue
@onready var _silver_value: Label = \
	$Window/ContentFrame/Viewport/ItemsView/SilverValue
@onready var _material_xu_value: Label = \
	$Window/ContentFrame/Viewport/MaterialsView/XuValue
@onready var _material_locked_xu_value: Label = \
	$Window/ContentFrame/Viewport/MaterialsView/LockedXuValue
@onready var _material_silver_value: Label = \
	$Window/ContentFrame/Viewport/MaterialsView/SilverValue
@onready var _expand_storage: LinkButton = \
	$Window/ContentFrame/Viewport/ItemsView/ExpandStorage
@onready var _page_controls: Control = \
	$Window/ContentFrame/Viewport/ItemsView/PageControls
@onready var _page_label: Label = \
	$Window/ContentFrame/Viewport/ItemsView/PageControls/Page
@onready var _page_prev: TextureButton = \
	$Window/ContentFrame/Viewport/ItemsView/PageControls/Prev
@onready var _page_next: TextureButton = \
	$Window/ContentFrame/Viewport/ItemsView/PageControls/Next
@onready var _material_page_label: Label = \
	$Window/ContentFrame/Viewport/MaterialsView/PageControls/Page
@onready var _fashion_page_label: Label = \
	$Window/ContentFrame/Viewport/FashionView/PageControls/Page
@onready var _decoration_page_label: Label = \
	$Window/ContentFrame/Viewport/DecorationView/PageControls/Page
@onready var _spray_page_label: Label = \
	$Window/ContentFrame/Viewport/SprayView/PageControls/Page
@onready var _spray_preview: TextureRect = \
	$Window/ContentFrame/Viewport/SprayView/Preview/Spray
@onready var _notification: Control = $Notification

var _selected_tab := 0
var _selected_spray := 0
var _item_page := 1
var _item_page_count := 1
var _storage_expanded := false
var _material_page := 1
var _material_page_count := 3
var _fashion_page := 1
var _fashion_page_count := 1
var _decoration_page := 1
var _decoration_page_count := 1
var _spray_page := 1
var _spray_page_count := 1
var _achievement_filter := 0
var _panel_transition: Tween
var _server_general_items: Array[Dictionary] = []
var _server_material_items: Array[Dictionary] = []


func _ready() -> void:
	$Window/CloseButton.pressed.connect(close)
	if not GameSession.lobby_data_changed.is_connected(
		_on_lobby_data_changed
	):
		GameSession.lobby_data_changed.connect(_on_lobby_data_changed)
	for index in _tab_buttons.size():
		_tab_buttons[index].pressed.connect(_select_tab.bind(index))
	_expand_storage.pressed.connect(_on_expand_storage_pressed)
	_page_prev.pressed.connect(_change_item_page.bind(-1))
	_page_next.pressed.connect(_change_item_page.bind(1))
	$Window/ContentFrame/Viewport/MaterialsView/PageControls/First.pressed.connect(
		_set_material_page.bind(1)
	)
	$Window/ContentFrame/Viewport/MaterialsView/PageControls/Prev.pressed.connect(
		_change_material_page.bind(-1)
	)
	$Window/ContentFrame/Viewport/MaterialsView/PageControls/Next.pressed.connect(
		_change_material_page.bind(1)
	)
	$Window/ContentFrame/Viewport/MaterialsView/PageControls/Last.pressed.connect(
		_set_material_page.bind(_material_page_count)
	)
	$Window/ContentFrame/Viewport/FashionView/PageControls/First.pressed.connect(
		_set_fashion_page.bind(1)
	)
	$Window/ContentFrame/Viewport/FashionView/PageControls/Prev.pressed.connect(
		_change_fashion_page.bind(-1)
	)
	$Window/ContentFrame/Viewport/FashionView/PageControls/Next.pressed.connect(
		_change_fashion_page.bind(1)
	)
	$Window/ContentFrame/Viewport/FashionView/PageControls/Last.pressed.connect(
		_go_fashion_last_page
	)
	$Window/ContentFrame/Viewport/DecorationView/PageControls/First.pressed.connect(
		_set_decoration_page.bind(1)
	)
	$Window/ContentFrame/Viewport/DecorationView/PageControls/Prev.pressed.connect(
		_change_decoration_page.bind(-1)
	)
	$Window/ContentFrame/Viewport/DecorationView/PageControls/Next.pressed.connect(
		_change_decoration_page.bind(1)
	)
	$Window/ContentFrame/Viewport/DecorationView/PageControls/Last.pressed.connect(
		_go_decoration_last_page
	)
	$Window/ContentFrame/Viewport/ItemsView/Sort.pressed.connect(
		_emit_inventory_action.bind(&"sort")
	)
	$Window/ContentFrame/Viewport/ItemsView/Sell.pressed.connect(
		_emit_inventory_action.bind(&"sell")
	)
	$Window/ContentFrame/Viewport/ItemsView/OpenAll.pressed.connect(
		_emit_inventory_action.bind(&"open_all")
	)
	$Window/ContentFrame/Viewport/ItemsView/GoShop.pressed.connect(
		_emit_inventory_action.bind(&"go_shop")
	)
	$Window/ContentFrame/Viewport/MaterialsView/Sort.pressed.connect(
		_emit_inventory_action.bind(&"sort_materials")
	)
	$Window/ContentFrame/Viewport/MaterialsView/Sell.pressed.connect(
		_emit_inventory_action.bind(&"sell_materials")
	)
	$Window/ContentFrame/Viewport/DecorationView/Cancel.pressed.connect(
		_emit_inventory_action.bind(&"cancel_decoration")
	)
	$Window/ContentFrame/Viewport/AchievementsView/FilterAll.pressed.connect(
		_set_achievement_filter.bind(0)
	)
	$Window/ContentFrame/Viewport/AchievementsView/FilterCompleted.pressed.connect(
		_set_achievement_filter.bind(1)
	)
	$Window/ContentFrame/Viewport/AchievementsView/FilterUnfinished.pressed.connect(
		_set_achievement_filter.bind(2)
	)
	$Window/ContentFrame/Viewport/SprayView/PageControls/First.pressed.connect(
		_set_spray_page.bind(1)
	)
	$Window/ContentFrame/Viewport/SprayView/PageControls/Prev.pressed.connect(
		_change_spray_page.bind(-1)
	)
	$Window/ContentFrame/Viewport/SprayView/PageControls/Next.pressed.connect(
		_change_spray_page.bind(1)
	)
	$Window/ContentFrame/Viewport/SprayView/PageControls/Last.pressed.connect(
		_go_spray_last_page
	)
	$Window/ContentFrame/Viewport/SprayView/Select.pressed.connect(
		_emit_inventory_action.bind(&"select_spray")
	)
	_notification.confirmed.connect(_on_notification_confirmed)
	_build_item_grid(_items_grid)
	_build_item_grid(_materials_grid)
	_build_spray_grid()
	_refresh_profile_preview()
	_refresh_item_pager()
	_refresh_material_pager()
	_set_achievement_filter(0)
	_refresh_spray_pager()
	_select_tab(0)


func open() -> void:
	_refresh_profile_preview()
	move_to_front()
	_panel_transition = PanelTransitionHelper.play_open(
		self,
		$Window,
		_panel_transition
	)
	if not GameSession.token.is_empty() and GameSession.admission_active:
		var result := await GameSession.fetch_inventory()
		if not result.get("ok", false):
			var error: Dictionary = result.get("error", {})
			_notification.call(
				"show_message",
				String(error.get("message", "Không tải được Kho.")),
				false,
				&"inventory_error"
			)
			return
		_apply_server_inventory(result.get("inventory", {}))


func close() -> void:
	if _notification.call("is_open"):
		_notification.call("close")
	_panel_transition = PanelTransitionHelper.play_close(
		self,
		$Window,
		_panel_transition
	)


func get_selected_tab() -> int:
	return _selected_tab


func is_storage_expanded() -> bool:
	return _storage_expanded


func get_item_page() -> int:
	return _item_page


func get_item_page_count() -> int:
	return _item_page_count


func get_material_page() -> int:
	return _material_page


func get_material_page_count() -> int:
	return _material_page_count


func get_fashion_page() -> int:
	return _fashion_page


func get_fashion_page_count() -> int:
	return _fashion_page_count


func get_decoration_page() -> int:
	return _decoration_page


func get_decoration_page_count() -> int:
	return _decoration_page_count


func get_spray_page() -> int:
	return _spray_page


func get_spray_page_count() -> int:
	return _spray_page_count


func get_achievement_filter() -> int:
	return _achievement_filter


func get_notification() -> Control:
	return _notification


func _select_tab(index: int) -> void:
	_selected_tab = clampi(index, 0, _views.size() - 1)
	for tab_index in _tab_buttons.size():
		_tab_buttons[tab_index].texture_normal = (
			TAB_SELECTED if tab_index == _selected_tab else TAB_NORMAL
		)
		_views[tab_index].visible = tab_index == _selected_tab
	tab_changed.emit(_selected_tab)


func _on_expand_storage_pressed() -> void:
	if not GameSession.token.is_empty():
		_notification.call(
			"show_message",
			"Mở rộng kho phải được máy chủ xác thực và hiện chưa mở.",
			false,
			&"server_feature_pending"
		)
		return
	_notification.call(
		"show_message",
		"Tốn 10 xu để mở thêm ô đạo cụ",
		true,
		&"expand_storage"
	)


func _on_notification_confirmed(context: Variant) -> void:
	if context != &"expand_storage" or _storage_expanded:
		return
	_storage_expanded = true
	_item_page_count = 2
	_item_page = 1
	_refresh_item_pager()


func _refresh_item_pager() -> void:
	var online_inventory := not GameSession.token.is_empty()
	_expand_storage.visible = not online_inventory and not _storage_expanded
	_page_controls.visible = (
		_item_page_count > 1 if online_inventory else _storage_expanded
	)
	_page_label.text = "%d/%d" % [_item_page, _item_page_count]


func _change_item_page(direction: int) -> void:
	if not _storage_expanded or _item_page_count <= 1:
		return
	_item_page = wrapi(
		_item_page - 1 + direction,
		0,
		_item_page_count
	) + 1
	_refresh_item_pager()
	_populate_server_grid(_items_grid, _server_general_items, _item_page)


func _refresh_material_pager() -> void:
	_material_page_label.text = "%d/%d" % [
		_material_page,
		_material_page_count,
	]


func _change_material_page(direction: int) -> void:
	_material_page = wrapi(
		_material_page - 1 + direction,
		0,
		_material_page_count
	) + 1
	_refresh_material_pager()
	_populate_server_grid(
		_materials_grid, _server_material_items, _material_page
	)


func _set_material_page(page: int) -> void:
	_material_page = clampi(page, 1, _material_page_count)
	_refresh_material_pager()
	_populate_server_grid(
		_materials_grid, _server_material_items, _material_page
	)


func _refresh_fashion_pager() -> void:
	_fashion_page_label.text = "%d/%d" % [
		_fashion_page,
		_fashion_page_count,
	]


func _change_fashion_page(direction: int) -> void:
	_fashion_page = wrapi(
		_fashion_page - 1 + direction,
		0,
		_fashion_page_count
	) + 1
	_refresh_fashion_pager()


func _set_fashion_page(page: int) -> void:
	_fashion_page = clampi(page, 1, _fashion_page_count)
	_refresh_fashion_pager()


func _go_fashion_last_page() -> void:
	_set_fashion_page(_fashion_page_count)


func _refresh_decoration_pager() -> void:
	_decoration_page_label.text = "%d/%d" % [
		_decoration_page,
		_decoration_page_count,
	]


func _change_decoration_page(direction: int) -> void:
	_decoration_page = wrapi(
		_decoration_page - 1 + direction,
		0,
		_decoration_page_count
	) + 1
	_refresh_decoration_pager()


func _set_decoration_page(page: int) -> void:
	_decoration_page = clampi(page, 1, _decoration_page_count)
	_refresh_decoration_pager()


func _go_decoration_last_page() -> void:
	_set_decoration_page(_decoration_page_count)


func _refresh_spray_pager() -> void:
	_spray_page_count = maxi(
		1,
		ceili(float(SPRAY_TEXTURES.size()) / 10.0)
	)
	_spray_page = clampi(_spray_page, 1, _spray_page_count)
	_spray_page_label.text = "%d/%d" % [
		_spray_page,
		_spray_page_count,
	]


func _change_spray_page(direction: int) -> void:
	_spray_page = wrapi(
		_spray_page - 1 + direction,
		0,
		_spray_page_count
	) + 1
	_rebuild_spray_grid()
	_refresh_spray_pager()


func _set_spray_page(page: int) -> void:
	_spray_page = clampi(page, 1, _spray_page_count)
	_rebuild_spray_grid()
	_refresh_spray_pager()


func _go_spray_last_page() -> void:
	_set_spray_page(_spray_page_count)


func _set_achievement_filter(filter_index: int) -> void:
	_achievement_filter = clampi(filter_index, 0, 2)
	var achievements_view := \
		$Window/ContentFrame/Viewport/AchievementsView
	var filter_buttons: Array[TextureButton] = [
		achievements_view.get_node("FilterAll") as TextureButton,
		achievements_view.get_node("FilterCompleted") as TextureButton,
		achievements_view.get_node("FilterUnfinished") as TextureButton,
	]
	for index in filter_buttons.size():
		filter_buttons[index].texture_normal = (
			ACHIEVEMENT_FILTER_SELECTED
			if index == _achievement_filter
			else null
		)
	for row_index in range(1, 5):
		var row := achievements_view.get_node(
			"Row%d" % row_index
		) as Control
		row.visible = _achievement_filter != 1


func _refresh_collection_pagers(data: Dictionary) -> void:
	var fashion_count := _collection_item_count(
		data,
		["fashion_items", "owned_fashions", "fashions", "fashion_count"]
	)
	var decoration_count := _collection_item_count(
		data,
		[
			"decoration_items",
			"owned_decorations",
			"decorations",
			"decoration_count",
		]
	)
	_fashion_page_count = maxi(1, ceili(float(fashion_count) / 3.0))
	_decoration_page_count = maxi(1, ceili(float(decoration_count) / 3.0))
	_fashion_page = clampi(_fashion_page, 1, _fashion_page_count)
	_decoration_page = clampi(
		_decoration_page,
		1,
		_decoration_page_count
	)
	_refresh_fashion_pager()
	_refresh_decoration_pager()


func _collection_item_count(data: Dictionary, keys: Array) -> int:
	for key_value: Variant in keys:
		var value: Variant = data.get(str(key_value))
		if value is Array or value is Dictionary:
			return value.size()
		if value is int or value is float:
			return maxi(0, int(value))
	return 0


func _emit_inventory_action(action: StringName) -> void:
	inventory_action_requested.emit(action)


func _build_item_grid(grid: Control) -> void:
	if grid.get_child_count() > 0:
		return
	for row in 5:
		for column in 9:
			var slot := TextureRect.new()
			slot.name = "Slot%d" % (row * 9 + column)
			slot.texture = EMPTY_SLOT
			slot.position = Vector2(column * 59, row * 59)
			slot.size = Vector2(55, 55)
			slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			slot.stretch_mode = TextureRect.STRETCH_KEEP
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			grid.add_child(slot)


func _apply_server_inventory(value: Variant) -> void:
	if not value is Dictionary:
		return
	_server_general_items.clear()
	_server_material_items.clear()
	for raw_item in (value as Dictionary).get("items", []):
		if not raw_item is Dictionary:
			continue
		var item := (raw_item as Dictionary).duplicate(true)
		var item_type := StringName(item.get("item_type", ""))
		if item_type == &"material":
			_server_material_items.append(item)
		elif item_type in [&"consumable", &"bundle", &"vip_pass"]:
			_server_general_items.append(item)
	_item_page_count = maxi(
		1, ceili(float(_server_general_items.size()) / 45.0)
	)
	_material_page_count = maxi(
		1, ceili(float(_server_material_items.size()) / 45.0)
	)
	_item_page = clampi(_item_page, 1, _item_page_count)
	_material_page = clampi(_material_page, 1, _material_page_count)
	_refresh_item_pager()
	_refresh_material_pager()
	_populate_server_grid(_items_grid, _server_general_items, _item_page)
	_populate_server_grid(
		_materials_grid, _server_material_items, _material_page
	)
	_refresh_profile_preview()


func _populate_server_grid(
	grid: Control,
	items: Array[Dictionary],
	page: int
) -> void:
	for slot_index in mini(45, grid.get_child_count()):
		var slot := grid.get_child(slot_index) as TextureRect
		for child in slot.get_children():
			child.queue_free()
		slot.tooltip_text = ""
	var start := (maxi(1, page) - 1) * 45
	for slot_index in 45:
		var item_index := start + slot_index
		if item_index >= items.size() or slot_index >= grid.get_child_count():
			break
		var item := items[item_index]
		var slot := grid.get_child(slot_index) as TextureRect
		slot.tooltip_text = String(item.get("name", "Vật phẩm"))
		var texture := ShopCatalog.load_texture(String(item.get("image", "")))
		if texture != null:
			var icon := TextureRect.new()
			icon.texture = texture
			icon.position = Vector2(4, 4)
			icon.size = Vector2(47, 47)
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(icon)
		var quantity := maxi(0, int(item.get("owned_quantity", 0)))
		if quantity > 1:
			var quantity_label := Label.new()
			quantity_label.position = Vector2(3, 31)
			quantity_label.size = Vector2(48, 21)
			quantity_label.text = "x%s" % _format_number(quantity)
			quantity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			quantity_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
			quantity_label.add_theme_font_size_override("font_size", 12)
			quantity_label.add_theme_color_override("font_color", Color.WHITE)
			quantity_label.add_theme_color_override(
				"font_outline_color", Color(0, 0, 0, 0.9)
			)
			quantity_label.add_theme_constant_override("outline_size", 2)
			quantity_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(quantity_label)


func _build_spray_grid() -> void:
	_refresh_spray_pager()
	_rebuild_spray_grid()


func _rebuild_spray_grid() -> void:
	for child in _spray_grid.get_children():
		child.queue_free()
	var first_index := (_spray_page - 1) * 10
	var last_index := mini(first_index + 10, SPRAY_TEXTURES.size())
	for index in range(first_index, last_index):
		var visible_index := index - first_index
		var cell := TextureButton.new()
		cell.set_script(HoverPressTextureButtonScript)
		cell.texture_normal = (
			SPRAY_CELL_SELECTED if index == _selected_spray else SPRAY_CELL
		)
		cell.position = Vector2(
			(visible_index % 5) * 89,
			(visible_index / 5) * 89
		)
		cell.size = Vector2(78, 78)
		cell.ignore_texture_size = true
		cell.stretch_mode = TextureButton.STRETCH_KEEP
		cell.clip_contents = true
		cell.pressed.connect(_select_spray.bind(index))

		var spray := TextureRect.new()
		spray.texture = SPRAY_TEXTURES[index]
		spray.position = Vector2(-1, -1)
		spray.size = SPRAY_TEXTURES[index].get_size()
		spray.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spray.stretch_mode = TextureRect.STRETCH_KEEP
		spray.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(spray)

		var selected_tick := TextureRect.new()
		selected_tick.name = "SelectedTick"
		selected_tick.texture = SPRAY_SELECTED_TICK
		selected_tick.position = Vector2(43, 43)
		selected_tick.size = SPRAY_SELECTED_TICK.get_size()
		selected_tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
		selected_tick.visible = index == _selected_spray
		cell.add_child(selected_tick)
		_spray_grid.add_child(cell)


func _select_spray(index: int) -> void:
	_selected_spray = index
	_spray_preview.texture = SPRAY_TEXTURES[_selected_spray]
	var first_index := (_spray_page - 1) * 10
	for cell_index in _spray_grid.get_child_count():
		var cell := _spray_grid.get_child(cell_index) as TextureButton
		var source_index := first_index + cell_index
		cell.texture_normal = (
			SPRAY_CELL_SELECTED
			if source_index == _selected_spray
			else SPRAY_CELL
		)
		(cell.get_node("SelectedTick") as TextureRect).visible = (
			source_index == _selected_spray
		)


func _refresh_profile_preview() -> void:
	if not is_node_ready():
		return
	var data := GameSession.profile.duplicate()
	data.merge(GameSession.lobby_data, true)
	if GameSession.token.is_empty() and GameSession.lobby_data.is_empty():
		data.merge(ProfileProgression.OFFLINE_PREVIEW, true)
	_profile_name.text = String(data.get("display_name", "Nhân vật"))

	var level := clampi(_safe_int(data.get("level", 1), 1), 0, 40)
	var experience := maxi(0, _safe_int(data.get("experience", 0), 0))
	var experience_max := maxi(
		0,
		_safe_int(
			data.get(
				"experience_max",
				ProfileProgression.experience_max_for_level(level)
			),
			ProfileProgression.experience_max_for_level(level)
		)
	)
	var exp_ratio := 0.0
	if experience_max > 0:
		exp_ratio = clampf(
			float(experience) / float(experience_max),
			0.0,
			1.0
		)
	_exp_bar.value = exp_ratio * 100.0
	_exp_value.text = "%d/%d" % [experience, experience_max]
	_refresh_level_badge(level)

	var guild_name := String(data.get("guild_name", "")).strip_edges()
	_guild_value.text = (
		guild_name if not guild_name.is_empty() else "Chưa gia nhập"
	)
	_wins_value.text = str(maxi(
		0,
		_safe_int(data.get("total_wins", data.get("wins", 0)), 0)
	))
	_run_value.text = "%d%%" % clampi(
		_safe_int(data.get("escape_rate", data.get("run_percent", 0)), 0),
		0,
		100
	)
	_daily_value.text = str(maxi(
		0,
		_safe_int(
			data.get(
				"daily_team_help",
				data.get("daily_team_requests", 0)
			),
			0
		)
	))
	var xu_text := "Xu: %s" % _format_number(
		maxi(0, _safe_int(data.get("xu", 0), 0))
	)
	var locked_xu_text := "Xu khóa: %s" % _format_number(
		maxi(0, _safe_int(data.get("locked_xu", 0), 0))
	)
	var silver_text := "Bạc: %s" % _format_number(
		maxi(0, _safe_int(data.get("silver", 0), 0))
	)
	_xu_value.text = xu_text
	_locked_xu_value.text = locked_xu_text
	_silver_value.text = silver_text
	_material_xu_value.text = xu_text
	_material_locked_xu_value.text = locked_xu_text
	_material_silver_value.text = silver_text
	_refresh_collection_pagers(data)


func _on_lobby_data_changed(_data: Dictionary) -> void:
	_refresh_profile_preview()


func _refresh_level_badge(level: int) -> void:
	_level_base.texture = AssetPathAliases.load_texture(
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

	var is_level_11_to_20 := level >= 11 and level <= 20
	_level_effect.scale = (
		Vector2(0.88, 0.88) if is_level_11_to_20 else Vector2.ONE
	)
	_level_effect.modulate = Color.WHITE
	if _level_effect.timeline_path != effect_path:
		_level_effect.load_timeline(effect_path)
	_level_effect.visible = true
	_level_effect.play()


func _safe_int(value: Variant, fallback: int) -> int:
	if value == null:
		return fallback
	if value is int:
		return value
	if value is float:
		return roundi(value)
	var text := str(value).strip_edges()
	if not text.is_valid_int():
		return fallback
	return int(text)


func _format_number(value: int) -> String:
	var digits := str(maxi(0, value))
	var formatted := ""
	while digits.length() > 3:
		formatted = "," + digits.right(3) + formatted
		digits = digits.left(digits.length() - 3)
	return digits + formatted
