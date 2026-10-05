extends Control

const AssetPathAliases := preload("res://scripts/data/asset_path_aliases.gd")

signal map_chosen(map_key: String)

const MAP_CARD := preload("res://assets/ui/pvp_ready_room/map_card.png")
const MAP_CARD_SELECTED := preload(
	"res://assets/ui/pvp_ready_room/map_card_selected.png"
)
const MAPS_PER_PAGE := 3
const MAP_ASSET_ROOT := "res://assets/ui/pvp_ready_room/maps/"

@onready var _cards: Array[TextureButton] = [
	$Window/Cards/Card1,
	$Window/Cards/Card2,
	$Window/Cards/Card3,
]

var _maps: Array[Dictionary] = []
var _page := 0
var _selected_map_key := ""
var _editable := false


func _ready() -> void:
	# This layer is modal: closing it must consume the same click so the
	# underlying room's XEM button cannot receive it after the popup disappears.
	$Window/Close.gui_input.connect(_on_close_gui_input)
	$Window/Close.button_down.connect(_queue_close_selector)
	$Window/Close.pressed.connect(_queue_close_selector)
	$Window/Previous.pressed.connect(_change_page.bind(-1))
	$Window/Next.pressed.connect(_change_page.bind(1))
	$Window/Confirm.pressed.connect(_confirm_selection)
	for card_index in _cards.size():
		_cards[card_index].pressed.connect(_select_card.bind(card_index))
	mouse_filter = Control.MOUSE_FILTER_STOP
	$Dim.mouse_filter = Control.MOUSE_FILTER_STOP
	# The window itself must stop input, not pass empty areas to the room/profile
	# controls behind it. Child buttons still receive their own GUI events.
	$Window.mouse_filter = Control.MOUSE_FILTER_STOP
	$Window/Close.mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false


func _on_close_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			get_viewport().set_input_as_handled()
			if mouse_event.pressed:
				_queue_close_selector()


func _queue_close_selector() -> void:
	get_viewport().set_input_as_handled()
	call_deferred("_close_selector")


func _close_selector() -> void:
	if not visible:
		return
	visible = false
	get_viewport().set_input_as_handled()


func show_maps(
	maps: Array,
	selected_map_key: String,
	editable: bool
) -> void:
	_maps.clear()
	for map_value in maps:
		if map_value is Dictionary:
			_maps.append(map_value)
	_selected_map_key = selected_map_key
	_editable = editable
	_page = 0
	for map_index in _maps.size():
		if String(_maps[map_index].get("map_key", "")) == selected_map_key:
			_page = floori(float(map_index) / float(MAPS_PER_PAGE))
			break
	_refresh_cards()
	visible = true
	move_to_front()
	mouse_filter = Control.MOUSE_FILTER_STOP
	$Dim.mouse_filter = Control.MOUSE_FILTER_STOP
	$Window.mouse_filter = Control.MOUSE_FILTER_STOP


func _change_page(delta: int) -> void:
	_page = clampi(_page + delta, 0, _max_page())
	_refresh_cards()


func _max_page() -> int:
	return maxi(0, ceili(float(_maps.size()) / float(MAPS_PER_PAGE)) - 1)


func _select_card(card_index: int) -> void:
	if not _editable:
		return
	var map_index := _page * MAPS_PER_PAGE + card_index
	if map_index < 0 or map_index >= _maps.size():
		return
	_selected_map_key = String(_maps[map_index].get("map_key", ""))
	_refresh_cards()


func _confirm_selection() -> void:
	if not _editable or _selected_map_key.is_empty():
		return
	visible = false
	map_chosen.emit(_selected_map_key)


func _refresh_cards() -> void:
	for card_index in _cards.size():
		var card := _cards[card_index]
		var map_index := _page * MAPS_PER_PAGE + card_index
		var occupied := map_index < _maps.size()
		card.visible = occupied
		if not occupied:
			continue
		var map_data := _maps[map_index]
		var map_key := String(map_data.get("map_key", ""))
		card.texture_normal = (
			MAP_CARD_SELECTED if map_key == _selected_map_key else MAP_CARD
		)
		(card.get_node("Name") as Label).text = String(
			map_data.get("display_name", map_key)
		)
		(card.get_node("Thumbnail") as TextureRect).texture = _load_map_texture(
			String(map_data.get("thumbnail_asset_path", ""))
		)
	$Window/Previous.disabled = _page <= 0
	$Window/Next.disabled = _page >= _max_page()
	$Window/Confirm.visible = _editable and not _maps.is_empty()


func _load_map_texture(asset_path: String) -> Texture2D:
	if not asset_path.begins_with(MAP_ASSET_ROOT):
		return null
	var resolved_path := AssetPathAliases.resolve(asset_path)
	if not ResourceLoader.exists(resolved_path):
		return null
	return ResourceLoader.load(resolved_path, "Texture2D") as Texture2D
