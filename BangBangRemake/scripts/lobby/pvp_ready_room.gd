extends Control

signal map_catalog_requested
signal map_change_requested(map_key: String)
signal map_selector_modal_changed(active: bool)
signal start_game_requested
signal cancel_matchmaking_requested

const AVATAR_MALE := preload("res://assets/ui/profile/avatar_male.png")
const AVATAR_FEMALE := preload("res://assets/ui/profile/avatar_female.png")
const DEFAULT_MAP := preload("res://assets/ui/pvp_ready_room/maps/random.jpg")
const LEVEL_FX_11_20 := \
	"res://assets/animations/profile_level_11_20_effect1_compact/timeline.json"
const LEVEL_FX_21_30 := \
	"res://assets/animations/profile_level_21_30_fx_compact/timeline.json"
const LEVEL_FX_31_35 := \
	"res://assets/animations/profile_level_31_35_fx_compact/timeline.json"
const LEVEL_FX_36_40 := \
	"res://assets/animations/profile_level_36_40_fx_compact/timeline.json"
const MAP_ASSET_ROOT := "res://assets/ui/pvp_ready_room/maps/"
const TankSkinCatalog := preload("res://scripts/lobby/tank_skin_catalog.gd")
const AssetPathAliases := preload("res://scripts/data/asset_path_aliases.gd")

const AVATAR_TEXTURES: Dictionary = {
	"default_male": AVATAR_MALE,
	"default_female": AVATAR_FEMALE,
}
const TANK_TEXTURES: Dictionary = {
	"gangtiexia03": preload("res://assets/ui/tank/tank_ironman_reward.png"),
}
@onready var _room_code: Label = $RoomCode
@onready var _room_title: Label = $RoomTitle
@onready var _start_background: TextureRect = $StartControls/Background
@onready var _map_button: TextureButton = $StartControls/MapButton
@onready var _start_button: TextureButton = $StartControls/StartGame
@onready var _start_effect: CanvasItem = $StartControls/StartGameEffect
@onready var _matchmaking_panel: Control = $StartControls/Matchmaking
@onready var _matchmaking_elapsed: Label = $StartControls/Matchmaking/Elapsed
@onready var _matchmaking_estimated: Label = \
	$StartControls/Matchmaking/Estimated
@onready var _matchmaking_cancel: TextureButton = \
	$StartControls/Matchmaking/Cancel
@onready var _map_selector: Control = $MapSelector
@onready var _slots: Array[Control] = [
	$Slots/Slot1,
	$Slots/Slot2,
	$Slots/Slot3,
	$Slots/Slot4,
	$Slots/Slot5,
]

var _room_data: Dictionary = {}
var _current_player_is_captain := false
var _matching_elapsed_seconds := 0.0
var _matching_estimated_seconds := 30
var _matching := false
var _matching_timer_paused := false


func _ready() -> void:
	_map_button.pressed.connect(_on_map_button_pressed)
	_start_button.pressed.connect(_on_start_button_pressed)
	_matchmaking_cancel.pressed.connect(_on_matchmaking_cancel_pressed)
	_map_selector.map_chosen.connect(_on_map_chosen)
	_map_selector.visibility_changed.connect(_on_map_selector_visibility_changed)
	_on_map_selector_visibility_changed()


func _on_map_button_pressed() -> void:
	map_catalog_requested.emit()


func _on_start_button_pressed() -> void:
	start_game_requested.emit()


func _on_matchmaking_cancel_pressed() -> void:
	cancel_matchmaking_requested.emit()


func _on_map_chosen(map_key: String) -> void:
	_on_map_selector_visibility_changed()
	map_change_requested.emit(map_key)


func _on_map_selector_visibility_changed() -> void:
	# While the selector is visible this full ready-room surface is the modal
	# hit target. When it closes, restore pass-through so the player list and
	# shared lobby controls work normally again.
	mouse_filter = (
		Control.MOUSE_FILTER_STOP
		if _map_selector.visible
		else Control.MOUSE_FILTER_IGNORE
	)
	map_selector_modal_changed.emit(_map_selector.visible)


func _process(delta: float) -> void:
	if not _matching or _matching_timer_paused:
		return
	_matching_elapsed_seconds += delta
	_update_matchmaking_timer()


func set_matchmaking_timer_paused(paused: bool) -> void:
	_matching_timer_paused = paused and _matching


func set_room_data(room: Dictionary) -> void:
	_room_data = room.duplicate(true)
	_room_code.text = _optional_text(room.get("room_code"), "")
	_room_title.text = _optional_text(room.get("room_name"), "Phòng PvP")
	var members_value: Variant = room.get("members", [])
	var members: Array = members_value if members_value is Array else []
	for slot_index in _slots.size():
		var member: Dictionary = {}
		if slot_index < members.size() and members[slot_index] is Dictionary:
			member = members[slot_index]
		_update_slot(_slots[slot_index], member, slot_index)
	_current_player_is_captain = _is_current_player_captain(members)
	var room_status := _optional_text(room.get("status"), "waiting")
	var is_waiting := room_status == "waiting"
	_matching = room_status == "matching"
	if not _matching:
		_matching_timer_paused = false
	var can_start := (
		_current_player_is_captain
		and is_waiting
	)
	_start_background.visible = is_waiting
	_map_button.visible = is_waiting
	_start_button.visible = can_start
	_start_effect.visible = can_start
	_matchmaking_panel.visible = _matching
	_matchmaking_cancel.visible = _matching and _current_player_is_captain
	if _matching and not _matching_timer_paused:
		var matchmaking_value: Variant = room.get("matchmaking", {})
		var matchmaking: Dictionary = (
			matchmaking_value if matchmaking_value is Dictionary else {}
		)
		_matching_elapsed_seconds = maxf(
			0.0,
			float(matchmaking.get("elapsed_seconds", 0))
		)
		_matching_estimated_seconds = maxi(
			1,
			int(matchmaking.get("estimated_seconds", 30))
		)
		_update_matchmaking_timer()
	_set_current_map_texture(
		_optional_text(room.get("map_thumbnail_asset_path"), "")
	)


func show_map_selector(maps: Array) -> void:
	_map_selector.show_maps(
		maps,
		_optional_text(_room_data.get("map_key"), "random"),
		_current_player_is_captain
	)


func _update_slot(slot: Control, member: Dictionary, slot_index: int) -> void:
	var waiting := slot.get_node("Waiting") as Control
	var content := slot.get_node("Member") as Control
	var occupied := not member.is_empty()
	waiting.visible = not occupied
	content.visible = occupied
	if not occupied:
		return

	var display_name := _optional_text(member.get("display_name"), "Người chơi")
	var gender := _optional_text(member.get("gender"), "male")
	var avatar_key := _optional_text(member.get("avatar_key"), "")
	var level := clampi(int(member.get("level", 1)), 0, 40)
	var tank_level := clampi(int(member.get("tank_level", 1)), 1, 6)
	var tank_key := _optional_text(member.get("tank_key"), "")
	var tank_name := _optional_text(member.get("tank_name"), "Tank")
	var equipped_skin_key := _optional_text(member.get("equipped_skin_key"), "")
	var is_captain := bool(member.get("is_captain", slot_index == 0))

	(content.get_node("Avatar") as TextureRect).texture = AVATAR_TEXTURES.get(
		avatar_key,
		AVATAR_FEMALE if gender == "female" else AVATAR_MALE
	) as Texture2D
	(content.get_node("Name") as Label).text = display_name
	_set_player_level(content, level)
	_set_tank_visual(
		content,
		tank_key,
		equipped_skin_key
	)
	(content.get_node("TankName") as Label).text = tank_name
	(content.get_node("TankLevel") as TextureRect).texture = \
		AssetPathAliases.load_texture(
		"res://assets/ui/tank/tank_level_%d.png" % tank_level
	)
	(content.get_node("CaptainTitle") as Control).visible = is_captain


func _optional_text(value: Variant, fallback: String = "") -> String:
	if value == null:
		return fallback
	var result := str(value).strip_edges()
	return fallback if result.is_empty() else result


func _set_player_level(content: Control, level: int) -> void:
	(content.get_node("Level") as TextureRect).texture = \
		AssetPathAliases.load_texture(
		"res://assets/ui/profile/level/level_%d.png" % level
	)
	var effect := content.get_node("LevelEffect") as SwfTimelinePlayer
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
		effect.stop()
		effect.visible = false
		return
	var is_level_11_to_20 := level >= 11 and level <= 20
	effect.scale = (
		Vector2(0.44, 0.44)
		if is_level_11_to_20
		else Vector2(0.5, 0.5)
	)
	effect.modulate.a = 1.0
	if effect.timeline_path != effect_path:
		effect.load_timeline(effect_path)
	effect.visible = true
	effect.play()


func _tank_texture(tank_key: String, equipped_skin_key: String) -> Texture2D:
	var texture := TankSkinCatalog.texture_for(
		{},
		tank_key,
		equipped_skin_key
	)
	if texture != null:
		return texture
	return TANK_TEXTURES.get(tank_key) as Texture2D


func _set_tank_visual(
	content: Control,
	tank_key: String,
	equipped_skin_key: String
) -> void:
	var tank_image := content.get_node("Tank") as TextureRect
	var animation := content.get_node_or_null("TankAnimation") as SwfTimelinePlayer
	var animation_path := TankSkinCatalog.animation_path(equipped_skin_key)
	if animation_path.is_empty():
		if animation != null:
			animation.stop()
			animation.visible = false
		tank_image.texture = _tank_texture(tank_key, equipped_skin_key)
		tank_image.visible = tank_image.texture != null
		return
	tank_image.visible = false
	if animation == null:
		animation = SwfTimelinePlayer.new()
		animation.name = "TankAnimation"
		animation.position = Vector2(79.0, 192.0)
		animation.scale = Vector2(0.7, 0.7)
		animation.timeline_path = animation_path
		content.add_child(animation)
	elif animation.timeline_path != animation_path:
		animation.load_timeline(animation_path)
	animation.visible = true
	animation.play()


func _is_current_player_captain(members: Array) -> bool:
	var account_id := String(GameSession.account.get("id", ""))
	for member_value in members:
		if not (member_value is Dictionary):
			continue
		var member: Dictionary = member_value
		if (
			not account_id.is_empty()
			and String(member.get("account_id", "")) == account_id
		):
			return bool(member.get("is_captain", false))
	if GameSession.token.is_empty() and not members.is_empty():
		var first_member: Dictionary = members[0]
		return bool(first_member.get("is_captain", false))
	return false


func _set_current_map_texture(asset_path: String) -> void:
	var texture: Texture2D = null
	var resolved_path := AssetPathAliases.resolve(asset_path)
	if (
		asset_path.begins_with(MAP_ASSET_ROOT)
		and ResourceLoader.exists(resolved_path)
	):
		texture = ResourceLoader.load(resolved_path, "Texture2D") as Texture2D
	_map_button.texture_normal = texture if texture != null else DEFAULT_MAP


func _update_matchmaking_timer() -> void:
	_matchmaking_elapsed.text = _format_duration(
		floori(_matching_elapsed_seconds)
	)
	_matchmaking_estimated.text = "Dự kiến: %s" % _format_duration(
		_matching_estimated_seconds
	)


func _format_duration(total_seconds: int) -> String:
	var safe_seconds := maxi(0, total_seconds)
	return "%02d:%02d" % [
		safe_seconds / 60,
		safe_seconds % 60,
	]
