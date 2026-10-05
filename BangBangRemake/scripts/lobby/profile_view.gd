extends Control

const AssetPathAliases := preload("res://scripts/data/asset_path_aliases.gd")

const MALE_CHARACTER := preload("res://assets/ui/profile/character_male_rgba.png")
const FEMALE_CHARACTER := preload("res://assets/ui/profile/character_female_rgba.png")
const CHARACTER_TEXTURES: Dictionary = {
	"default_male": MALE_CHARACTER,
	"default_female": FEMALE_CHARACTER,
}
const TAB_TOTAL := preload("res://assets/ui/profile/original/tab_total.png")
const TAB_TOTAL_SELECTED := preload(
	"res://assets/ui/profile/original/tab_total_selected.png"
)
const TAB_CLAN := preload("res://assets/ui/profile/original/tab_clan.png")
const TAB_CLAN_SELECTED := preload(
	"res://assets/ui/profile/original/tab_clan_selected.png"
)
const ALPHA_DISCARD_SHADER := preload("res://assets/shaders/alpha_discard.gdshader")
const LEVEL_FX_11_20 := \
	"res://assets/animations/profile_level_11_20_effect1_compact/timeline.json"
const LEVEL_FX_21_30 := \
	"res://assets/animations/profile_level_21_30_fx_compact/timeline.json"
const LEVEL_FX_31_35 := \
	"res://assets/animations/profile_level_31_35_fx_compact/timeline.json"
const LEVEL_FX_36_40 := \
	"res://assets/animations/profile_level_36_40_fx_compact/timeline.json"
const PanelTransitionHelper := preload("res://scripts/ui/panel_transition.gd")
const VISIBLE_TANK_ROWS := 3
const TAB_STEP := 76.0
const TAB_SELECTED_START_X := -8.0
const SCROLL_THUMB_TOP := 18.0
const SCROLL_THUMB_TRAVEL := 97.0
const TankSkinCatalog := preload("res://scripts/lobby/tank_skin_catalog.gd")
const TANK_TEXTURES: Dictionary = {
	"gangtiexia03": preload("res://assets/ui/tank/tank_ironman_reward.png"),
}

@onready var _level_badge: TextureRect = $Window/CharacterFrame/LevelBadge
@onready var _level_effect: SwfTimelinePlayer = \
	$Window/CharacterFrame/LevelEffect
@onready var _character_name: Label = $Window/CharacterFrame/Name
@onready var _character: TextureRect = $Window/CharacterFrame/Character
@onready var _character_id: Label = $Window/CharacterIdValue
@onready var _tab_selected: TextureRect = $Window/Tabs/Selected
@onready var _tank_count: Label = $Window/TankSection/TankCount
@onready var _preview_image: TextureRect = $Window/TankSection/TankPreview/TankImage
@onready var _preview_level: TextureRect = \
	$Window/TankSection/TankPreview/TankLevel
@onready var _preview_name: Label = $Window/TankSection/TankPreview/TankName
@onready var _scroll_thumb: TextureRect = $Window/TankSection/TankScroll/Thumb
@onready var _scroll_up: TextureButton = $Window/TankSection/TankScroll/Up
@onready var _scroll_down: TextureButton = $Window/TankSection/TankScroll/Down
@onready var _preview_score: Label = \
	$Window/TankSection/TankPreview/Stats/ScoreBackground/Value
@onready var _preview_wins: Label = \
	$Window/TankSection/TankPreview/Stats/WinBackground/Value
@onready var _preview_kills: Label = \
	$Window/TankSection/TankPreview/Stats/KillBackground/Value
@onready var _preview_assists: Label = \
	$Window/TankSection/TankPreview/Stats/AssistBackground/Value

var _tank_rows: Array[Control] = []
var _tank_row_animations: Array = []
var _tank_row_skin_frames: Array[TextureRect] = []
var _owned_tanks: Array = []
var _selected_tank_index := 0
var _tank_scroll_offset := 0
var _alpha_discard_material := ShaderMaterial.new()
var _preview_animation: SwfTimelinePlayer
var _panel_transition: Tween


func _ready() -> void:
	_alpha_discard_material.shader = ALPHA_DISCARD_SHADER
	_apply_alpha_discard($Window)
	_apply_text_emphasis($Window)
	$Window/BtnClose.pressed.connect(hide_view)
	_tank_rows = [
		$Window/TankSection/TankList/TankRow0,
		$Window/TankSection/TankList/TankRow1,
		$Window/TankSection/TankList/TankRow2,
	]
	_tank_row_animations.clear()
	_tank_row_skin_frames.clear()
	for index in _tank_rows.size():
		var existing_animation := _tank_rows[index].get_node_or_null(
			"TankAnimation"
		) as SwfTimelinePlayer
		_tank_row_animations.append(existing_animation)
		_tank_row_skin_frames.append(
			_tank_rows[index].get_node("SkinFrame") as TextureRect
		)
		var select_button := _tank_rows[index].get_node("Select") as Button
		select_button.pressed.connect(_select_tank.bind(index))
	_sync_tank_row_display_scale()
	_scroll_up.pressed.connect(_scroll_tanks.bind(-1))
	_scroll_down.pressed.connect(_scroll_tanks.bind(1))
	$Window/TankSection/TankList.gui_input.connect(_on_tank_list_gui_input)
	for index in 4:
		var tab := $Window/Tabs.get_node("Tab%d" % index) as TextureButton
		tab.pressed.connect(_select_tab.bind(index))
	if not GameSession.lobby_data_changed.is_connected(_on_lobby_data_changed):
		GameSession.lobby_data_changed.connect(_on_lobby_data_changed)
	_select_tab(0)


func _apply_alpha_discard(node: Node) -> void:
	if node == _level_badge or node == _level_effect:
		return
	if node is CanvasItem:
		if node.name not in [&"Window", &"FrameComposite"]:
			(node as CanvasItem).material = _alpha_discard_material
	for child in node.get_children():
		_apply_alpha_discard(child)


func _apply_text_emphasis(node: Node) -> void:
	if node is Label:
		var label := node as Label
		if label.get_theme_constant("outline_size") < 2:
			label.add_theme_constant_override("outline_size", 2)
	for child in node.get_children():
		_apply_text_emphasis(child)


func show_profile(data: Dictionary, account: Dictionary) -> void:
	var level := clampi(_safe_int(data.get("level", 1), 1), 0, 40)
	var gender := _safe_string(data.get("gender", "male"))
	var avatar_key := _safe_string(data.get("avatar_key", ""))
	_character_name.text = _safe_string(data.get("display_name", "Nhân vật"))
	_character.texture = CHARACTER_TEXTURES.get(
		avatar_key,
		FEMALE_CHARACTER if gender == "female" else MALE_CHARACTER
	) as Texture2D
	_refresh_level_badge(level)
	_character_id.text = _safe_string(account.get("id", "—"))
	_refresh_summary(data)

	var owned_tanks_value: Variant = data.get("owned_tanks", [])
	_owned_tanks = owned_tanks_value if owned_tanks_value is Array else []
	_tank_count.text = "Hiện có %d Tank" % _owned_tanks.size()

	_selected_tank_index = 0
	for index in _owned_tanks.size():
		var tank_value: Variant = _owned_tanks[index]
		if tank_value is Dictionary and bool(tank_value.get("is_primary", false)):
			_selected_tank_index = index
			break
	_tank_scroll_offset = clampi(
		_selected_tank_index - 1,
		0,
		_max_tank_scroll_offset()
	)
	_refresh_tank_rows()
	_refresh_selected_tank()
	move_to_front()
	_panel_transition = PanelTransitionHelper.play_open(
		self,
		$Window,
		_panel_transition
	)


func hide_view() -> void:
	_panel_transition = PanelTransitionHelper.play_close(
		self,
		$Window,
		_panel_transition
	)


func close() -> void:
	hide_view()


func _refresh_tank_rows() -> void:
	_sync_tank_row_display_scale()
	for row_index in _tank_rows.size():
		var row := _tank_rows[row_index]
		var tank_index := _tank_scroll_offset + row_index
		if tank_index >= _owned_tanks.size():
			_clear_tank_row_visual(row_index)
			row.visible = false
			continue
		var tank_value: Variant = _owned_tanks[tank_index]
		if not (tank_value is Dictionary):
			_clear_tank_row_visual(row_index)
			row.visible = false
			continue
		var tank: Dictionary = tank_value
		var skin_frame_texture := TankSkinCatalog.skin_frame_texture(
			"tankinfo",
			tank
		)
		_tank_row_skin_frames[row_index].texture = skin_frame_texture
		_tank_row_skin_frames[row_index].visible = skin_frame_texture != null
		var tank_key := _safe_string(tank.get("tank_key", ""))
		var equipped_skin_key := TankSkinCatalog.equipped_skin_key(tank)
		_set_tank_row_visual(
			row_index,
			tank,
			tank_key,
			equipped_skin_key
		)
		_set_tank_level_texture(
			row.get_node("Level") as TextureRect,
			_safe_int(tank.get("tank_level", 1), 1)
		)
		(row.get_node("Name") as Label).text = _safe_string(
			tank.get("tank_name", "Tank")
		)
		(row.get_node("Achievement") as Label).text = "Chiến tích: %d" % maxi(
			0,
			_safe_int(
				tank.get("achievement_score", tank.get("battle_score", 0)),
				0
			)
		)
		(row.get_node("Wins") as Label).text = "Thắng: %d" % maxi(
			0,
			_safe_int(tank.get("wins", tank.get("total_wins", 0)), 0)
		)
		(row.get_node("Background") as TextureRect).visible = (
			tank_index == _selected_tank_index
		)
		row.visible = true
	_refresh_scrollbar()


func _sync_tank_row_display_scale() -> void:
	if _tank_rows.is_empty():
		return
	var reference_icon := _tank_rows[0].get_node("Icon") as TextureRect
	var reference_scale := reference_icon.scale
	for index in range(1, _tank_rows.size()):
		var icon := _tank_rows[index].get_node("Icon") as TextureRect
		icon.scale = reference_scale


func _clear_tank_row_visual(row_index: int) -> void:
	_tank_row_skin_frames[row_index].texture = null
	_tank_row_skin_frames[row_index].visible = false
	var icon := _tank_rows[row_index].get_node("Icon") as TextureRect
	icon.visible = false
	var animation: SwfTimelinePlayer = _tank_row_animations[row_index]
	if animation != null:
		animation.stop()
		animation.visible = false


func _on_lobby_data_changed(data: Dictionary) -> void:
	if not visible:
		return
	var selected_key := ""
	if (
		not _owned_tanks.is_empty()
		and _selected_tank_index >= 0
		and _selected_tank_index < _owned_tanks.size()
		and _owned_tanks[_selected_tank_index] is Dictionary
	):
		selected_key = _safe_string(
			(_owned_tanks[_selected_tank_index] as Dictionary).get(
				"tank_key",
				""
			)
		)
	var merged := GameSession.profile.duplicate(true)
	merged.merge(data, true)
	var owned_value: Variant = merged.get("owned_tanks", [])
	_owned_tanks = owned_value if owned_value is Array else []
	_tank_count.text = "Hiện có %d Tank" % _owned_tanks.size()
	_selected_tank_index = 0
	for index in _owned_tanks.size():
		var tank_value: Variant = _owned_tanks[index]
		if tank_value is not Dictionary:
			continue
		var tank: Dictionary = tank_value
		if (
			not selected_key.is_empty()
			and _safe_string(tank.get("tank_key", "")) == selected_key
		):
			_selected_tank_index = index
			break
		if bool(tank.get("is_primary", false)):
			_selected_tank_index = index
	_tank_scroll_offset = clampi(
		_selected_tank_index - 1,
		0,
		_max_tank_scroll_offset()
	)
	_refresh_summary(merged)
	_refresh_tank_rows()
	_refresh_selected_tank()


func _set_tank_row_visual(
	row_index: int,
	tank: Dictionary,
	tank_key: String,
	skin_key: String
) -> void:
	var row := _tank_rows[row_index]
	var icon := row.get_node("Icon") as TextureRect
	var animation: SwfTimelinePlayer = _tank_row_animations[row_index]
	var animation_path := TankSkinCatalog.animation_path(skin_key)
	if animation_path.is_empty():
		if animation != null:
			animation.stop()
			animation.visible = false
		var texture := TankSkinCatalog.icon_for(skin_key)
		if texture == null:
			texture = TankSkinCatalog.texture_for(tank, tank_key, skin_key)
		if texture == null:
			texture = TANK_TEXTURES.get(tank_key) as Texture2D
		icon.texture = texture
		icon.visible = texture != null
		return

	icon.visible = false
	if animation == null:
		animation = SwfTimelinePlayer.new()
		animation.name = "TankAnimation"
		animation.timeline_path = animation_path
		row.add_child(animation)
		row.move_child(animation, icon.get_index() + 1)
		_tank_row_animations[row_index] = animation
	elif animation.timeline_path != animation_path:
		animation.load_timeline(animation_path)
	_fit_tank_row_animation(animation, icon)
	animation.visible = true
	animation.play()


func _fit_tank_row_animation(
	animation: SwfTimelinePlayer,
	icon: TextureRect
) -> void:
	var stage_size := animation.get_stage_size()
	var fit_scale := 1.0
	if stage_size.x > 0.0 and stage_size.y > 0.0:
		fit_scale = minf(
			icon.size.x / stage_size.x,
			icon.size.y / stage_size.y
		)
	animation.position = icon.get_transform() * (icon.size * 0.5)
	animation.scale = icon.scale * fit_scale
	animation.rotation = icon.rotation


func _select_tank(row_index: int) -> void:
	var tank_index := _tank_scroll_offset + row_index
	if tank_index < 0 or tank_index >= _owned_tanks.size():
		return
	_selected_tank_index = tank_index
	_refresh_tank_rows()
	_refresh_selected_tank()


func _scroll_tanks(delta: int) -> void:
	var next_offset := clampi(
		_tank_scroll_offset + delta,
		0,
		_max_tank_scroll_offset()
	)
	if next_offset == _tank_scroll_offset:
		return
	_tank_scroll_offset = next_offset
	_refresh_tank_rows()


func _on_tank_list_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll_tanks(-1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll_tanks(1)


func _max_tank_scroll_offset() -> int:
	return maxi(0, _owned_tanks.size() - VISIBLE_TANK_ROWS)


func _refresh_scrollbar() -> void:
	var max_offset := _max_tank_scroll_offset()
	var ratio := 0.0
	if max_offset > 0:
		ratio = float(_tank_scroll_offset) / float(max_offset)
	_scroll_thumb.position.y = SCROLL_THUMB_TOP + roundf(
		SCROLL_THUMB_TRAVEL * ratio
	)
	_scroll_up.disabled = _tank_scroll_offset <= 0
	_scroll_down.disabled = _tank_scroll_offset >= max_offset


func _refresh_selected_tank() -> void:
	if _owned_tanks.is_empty() or _selected_tank_index >= _owned_tanks.size():
		_preview_image.visible = false
		if _preview_animation != null:
			_preview_animation.stop()
			_preview_animation.visible = false
		_preview_level.texture = null
		_preview_name.text = "Chưa có Tank"
		_set_preview_stats({})
		return

	var tank_value: Variant = _owned_tanks[_selected_tank_index]
	if not (tank_value is Dictionary):
		return
	var tank: Dictionary = tank_value
	var tank_key := _safe_string(tank.get("tank_key", ""))
	var highest_skin_key := TankSkinCatalog.highest_owned_skin_key(tank)
	_refresh_preview_tank_visual(tank, tank_key, highest_skin_key)
	_set_tank_level_texture(
		_preview_level,
		_safe_int(tank.get("tank_level", 1), 1)
	)
	_preview_name.text = _safe_string(tank.get("tank_name", "Tank"))
	_set_preview_stats(tank)


func _refresh_preview_tank_visual(
	tank: Dictionary,
	tank_key: String,
	skin_key: String
) -> void:
	var animation_path := TankSkinCatalog.animation_path(skin_key)
	if not animation_path.is_empty():
		_preview_image.visible = false
		if _preview_animation == null:
			_preview_animation = SwfTimelinePlayer.new()
			_preview_animation.name = "TankAnimation"
			_preview_animation.position = (
				_preview_image.position + _preview_image.size * 0.5
			)
			_preview_animation.timeline_path = animation_path
			$Window/TankSection/TankPreview.add_child(_preview_animation)
		elif _preview_animation.timeline_path != animation_path:
			_preview_animation.load_timeline(animation_path)
		_preview_animation.visible = true
		_preview_animation.play()
		return

	if _preview_animation != null:
		_preview_animation.stop()
		_preview_animation.visible = false
	var texture := TankSkinCatalog.texture_for(tank, tank_key, skin_key)
	if texture == null:
		texture = TANK_TEXTURES.get(tank_key) as Texture2D
	_preview_image.texture = texture
	_preview_image.visible = texture != null


func _set_preview_stats(tank: Dictionary) -> void:
	_preview_score.text = str(maxi(
		0,
		_safe_int(
			tank.get("achievement_score", tank.get("battle_score", 0)),
			0
		)
	))
	_preview_wins.text = str(maxi(
		0,
		_safe_int(tank.get("wins", tank.get("total_wins", 0)), 0)
	))
	_preview_kills.text = str(maxi(0, _safe_int(tank.get("kills", 0), 0)))
	_preview_assists.text = str(maxi(0, _safe_int(tank.get("assists", 0), 0)))


func _refresh_summary(data: Dictionary) -> void:
	($Window/Summary/RankBackground/Value as Label).text = _safe_string(
		data.get("rank_name", "Đồng I")
	)
	($Window/Summary/WinBackground/Value as Label).text = str(maxi(
		0,
		_safe_int(data.get("total_wins", 0), 0)
	))
	($Window/Summary/EscapeBackground/Value as Label).text = "%d%%" % clampi(
		_safe_int(data.get("escape_rate", 0), 0),
		0,
		100
	)
	($Window/Summary/KillBackground/Value as Label).text = str(maxi(
		0,
		_safe_int(data.get("kill_badges", 0), 0)
	))
	($Window/Summary/AssistBackground/Value as Label).text = str(maxi(
		0,
		_safe_int(data.get("assist_badges", 0), 0)
	))
	($Window/Summary/AllRoundBackground/Value as Label).text = str(maxi(
		0,
		_safe_int(data.get("all_round_badges", 0), 0)
	))
	($Window/Summary/DemolishBackground/Value as Label).text = str(maxi(
		0,
		_safe_int(data.get("demolish_badges", 0), 0)
	))


func _select_tab(selected_index: int) -> void:
	_tab_selected.position.x = TAB_SELECTED_START_X + TAB_STEP * selected_index
	for index in 4:
		var tab := $Window/Tabs.get_node("Tab%d" % index) as TextureButton
		var text_texture := tab.get_node("Text") as TextureRect
		if index == 0:
			text_texture.texture = (
				TAB_TOTAL_SELECTED if selected_index == 0 else TAB_TOTAL
			)
		elif index == 3:
			text_texture.texture = (
				TAB_CLAN_SELECTED if selected_index == 3 else TAB_CLAN
			)


func _refresh_level_badge(level: int) -> void:
	_level_badge.texture = AssetPathAliases.load_texture(
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
		Vector2(0.88, 0.88)
		if is_level_11_to_20
		else Vector2.ONE
	)
	_level_effect.modulate.a = 1.0
	if _level_effect.timeline_path != effect_path:
		_level_effect.load_timeline(effect_path)
	_level_effect.visible = true
	_level_effect.play()


func _set_tank_level_texture(target: TextureRect, level: int) -> void:
	var safe_level := clampi(level, 1, 6)
	target.texture = AssetPathAliases.load_texture(
		"res://assets/ui/tank/tank_level_%d.png" % safe_level
	)


func _safe_string(value: Variant) -> String:
	if value == null:
		return ""
	return str(value)


func _safe_int(value: Variant, fallback: int) -> int:
	if value == null:
		return fallback
	if value is int or value is float:
		return int(value)
	var text := String(value).strip_edges()
	return int(text) if text.is_valid_int() else fallback
