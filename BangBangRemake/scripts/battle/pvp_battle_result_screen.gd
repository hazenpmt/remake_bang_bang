class_name PvpBattleResultScreen
extends Control

signal exit_requested
signal leave_requested

const TankSkinCatalog := preload("res://scripts/lobby/tank_skin_catalog.gd")
const ProfileProgression := preload("res://scripts/data/profile_progression.gd")
const AssetPathAliases := preload("res://scripts/data/asset_path_aliases.gd")
const LEVEL_FX_11_20 := "res://assets/animations/profile_level_11_20_effect1_compact/timeline.json"
const LEVEL_FX_21_30 := "res://assets/animations/profile_level_21_30_fx_compact/timeline.json"
const LEVEL_FX_31_35 := "res://assets/animations/profile_level_31_35_fx_compact/timeline.json"
const LEVEL_FX_36_40 := "res://assets/animations/profile_level_36_40_fx_compact/timeline.json"
const IRONMAN_RESULT_TEXTURE := preload(
	"res://assets/ui/tank/tank_ironman_reward.png"
)
const HONOR_TEXTURES := {
	"mvp": preload("res://assets/battle/result/honnor_kda.png"),
	"killer": preload("res://assets/battle/result/honnor_killer.png"),
	"assist": preload("res://assets/battle/result/honner_assist.png"),
}
const HONOR_LABEL_TEXTURES := {
	"mvp": preload("res://assets/battle/result/honnor_label_kda_t.png"),
	"killer": preload("res://assets/battle/result/honnor_label_killer_t.png"),
	"assist": preload("res://assets/battle/result/honnor_label_assist_t.png"),
}

@onready var _score: Label = $Center/Window/Score
@onready var _rows: Control = $Center/Window/LeftPanel/Rows
@onready var _team_1_rows: Control = $Center/Window/LeftPanel/Rows/Team1
@onready var _team_2_rows: Control = $Center/Window/LeftPanel/Rows/Team2
@onready var _team_1_win: TextureRect = $Center/Window/LeftPanel/Rows/Team1/WinIcon
@onready var _team_2_win: TextureRect = $Center/Window/LeftPanel/Rows/Team2/WinIcon
@onready var _chat_host: Control = $Center/Window/ChatHost
@onready var _featured_tank: TextureRect = \
	$Center/Window/RightPanel/TankArea/FeaturedTank
@onready var _tank_display_name: Label = \
	$Center/Window/RightPanel/TankArea/TankDisplayName
@onready var _featured_name: Label = \
	$Center/Window/RightPanel/TankArea/FeaturedName
@onready var _featured_stats: Label = \
	$Center/Window/RightPanel/TankArea/FeaturedStats
@onready var _featured_honors: HBoxContainer = \
	$Center/Window/RightPanel/TankArea/FeaturedHonors
@onready var _experience_base: Label = \
	$Center/Window/RightPanel/ExperienceBaseText
@onready var _experience_fashion: Label = \
	$Center/Window/RightPanel/ExperienceFashionText
@onready var _experience_vip: Label = \
	$Center/Window/RightPanel/ExperienceVipText
@onready var _coin_total: Label = $Center/Window/RightPanel/CoinTotal
@onready var _coin_base: Label = $Center/Window/RightPanel/CoinBaseText
@onready var _coin_fashion: Label = $Center/Window/RightPanel/CoinFashionText
@onready var _coin_vip: Label = $Center/Window/RightPanel/CoinVipText
@onready var _current_level_base: TextureRect = \
	$Center/Window/RightPanel/CurrentLevelBadge/Base
@onready var _current_level_effect: SwfTimelinePlayer = \
	$Center/Window/RightPanel/CurrentLevelBadge/Effect
@onready var _next_level_base: TextureRect = \
	$Center/Window/RightPanel/NextLevelBadge/Base
@onready var _next_level_effect: SwfTimelinePlayer = \
	$Center/Window/RightPanel/NextLevelBadge/Effect
@onready var _level_percent: Label = $Center/Window/RightPanel/LevelPercent
@onready var _level_numbers: Label = $Center/Window/RightPanel/LevelNumbers
@onready var _level_bar_clip: Control = $Center/Window/RightPanel/LevelBarClip
@onready var _owned_button: TextureRect = \
	$Center/Window/RightPanel/TankArea/Owned
@onready var _buy_tank_button: TextureRect = \
	$Center/Window/RightPanel/TankArea/BuyTank
@onready var _other_rules_button: TextureRect = \
	$Center/Window/RightPanel/TankArea/OtherRules
@onready var _return_countdown: Label = \
	$Center/Window/ReturnCountdown/Text
@onready var _exit_button: TextureButton = $Center/Window/Exit
@onready var _leave_button: TextureButton = $Center/Window/Leave

var _result: Dictionary = {}
var _players: Array[Dictionary] = []
var _honors: Dictionary = {}
var _viewer_combatant_key := "player"
var _shared_chat: Control
var _chat_original_parent: Node
var _chat_original_index := -1
var _chat_original_layout: Dictionary = {}
var _chat_history_layout: Dictionary = {}
var _chat_input_layout: Dictionary = {}
var _chat_original_visible := true
var _chat_warning_visible := true
var _chat_input_visible := true
var _chat_attached := false
var _auto_return_deadline_msec := 0
var _auto_return_active := false
var _action_requested := false
var _action_queued := false
var _exit_visual_state := -1
var _leave_visual_state := -1


func _ready() -> void:
	visible = false
	$Center/Window/Exit.pressed.connect(_queue_exit_request)
	$Center/Window/Leave.pressed.connect(_queue_leave_request)


func _input(event: InputEvent) -> void:
	if (
		not visible
		or _action_requested
		or event is not InputEventMouseButton
		or event.button_index != MOUSE_BUTTON_LEFT
		or event.pressed
	):
		return
	if $Center/Window/Exit.get_global_rect().has_point(event.position):
		get_viewport().set_input_as_handled()
		_queue_exit_request()
		return
	if $Center/Window/Leave.get_global_rect().has_point(event.position):
		get_viewport().set_input_as_handled()
		_queue_leave_request()


func _process(_delta: float) -> void:
	if not visible:
		return
	_sync_result_button_visuals()
	if not _auto_return_active:
		return
	var remaining_msec := _auto_return_deadline_msec - Time.get_ticks_msec()
	var remaining_seconds := maxi(ceili(float(remaining_msec) / 1000.0), 0)
	_return_countdown.text = "%ds" % remaining_seconds
	if remaining_msec <= 0:
		_request_exit()


func show_result(
	result: Dictionary,
	players: Array[Dictionary],
	honors: Dictionary,
	viewer_combatant_key := "player"
) -> void:
	_result = result.duplicate(true)
	_players = players.duplicate(true)
	_honors = honors.duplicate(true)
	_viewer_combatant_key = viewer_combatant_key
	_populate()
	_attach_shared_chat()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_action_requested = false
	_action_queued = false
	_reset_result_button_visuals()
	_auto_return_deadline_msec = Time.get_ticks_msec() + 10000
	_auto_return_active = true
	_return_countdown.text = "10s"


func reset() -> void:
	_auto_return_active = false
	_action_requested = false
	_action_queued = false
	_reset_result_button_visuals()
	_detach_shared_chat()
	visible = false
	_clear_player_slots()
	_clear_container(_featured_honors)
	_current_level_effect.stop()
	_current_level_effect.visible = false
	_next_level_effect.stop()
	_next_level_effect.visible = false


func _sync_result_button_visuals() -> void:
	var mouse_position := get_viewport().get_mouse_position()
	var left_held := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	_exit_visual_state = _sync_result_button_visual(
		_exit_button,
		_exit_visual_state,
		mouse_position,
		left_held
	)
	_leave_visual_state = _sync_result_button_visual(
		_leave_button,
		_leave_visual_state,
		mouse_position,
		left_held
	)


func _sync_result_button_visual(
	button: TextureButton,
	previous_state: int,
	mouse_position: Vector2,
	left_held: bool
) -> int:
	var hovered := button.get_global_rect().has_point(mouse_position)
	var next_state := 2 if hovered and left_held else (1 if hovered else 0)
	if next_state == previous_state:
		return previous_state
	var target_color := Color.WHITE
	if next_state == 2:
		target_color = Color(0.8, 0.8, 0.8, 1.0)
	elif next_state == 1:
		target_color = Color(1.3, 1.3, 1.3, 1.0)
	button.call("_glow", target_color)
	return next_state


func _reset_result_button_visuals() -> void:
	_exit_visual_state = -1
	_leave_visual_state = -1
	if is_instance_valid(_exit_button):
		_exit_button.modulate = Color.WHITE
	if is_instance_valid(_leave_button):
		_leave_button.modulate = Color.WHITE


func bind_shared_chat(chat: Control) -> void:
	if _chat_attached:
		_detach_shared_chat()
	_shared_chat = chat


func _populate() -> void:
	_score.text = "%d  -  %d     %s" % [
		int(_result.get("team_1_score", 0)),
		int(_result.get("team_2_score", 0)),
		_format_time(float(_result.get("elapsed_seconds", 0.0))),
	]
	_populate_rows()
	var winner_team_no := int(_result.get("winner_team_no", 0))
	if winner_team_no == 0:
		var team_1_score := int(_result.get("team_1_score", 0))
		var team_2_score := int(_result.get("team_2_score", 0))
		if team_1_score != team_2_score:
			winner_team_no = 1 if team_1_score > team_2_score else 2
	_team_1_win.visible = winner_team_no == 1
	_team_2_win.visible = winner_team_no == 2
	_populate_featured_player()


func _populate_rows() -> void:
	_clear_player_slots()
	var ordered := _players.duplicate(true)
	ordered.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_order := int(left.get("team_no", 0)) * 10 + int(
			left.get("slot_no", 0)
		)
		var right_order := int(right.get("team_no", 0)) * 10 + int(
			right.get("slot_no", 0)
		)
		return left_order < right_order
	)
	var team_indices := {1: 0, 2: 0}
	for player: Dictionary in ordered:
		var team_no := clampi(int(player.get("team_no", 1)), 1, 2)
		var team_index := int(team_indices[team_no])
		if team_index >= 5:
			continue
		team_indices[team_no] = team_index + 1
		var target := _team_1_rows if team_no == 1 else _team_2_rows
		var row := target.get_node("Slot%d" % (team_index + 1)) as Control
		row.set_meta("team_no", team_no)
		row.set_meta("combatant_key", String(player.get("combatant_key", "")))
		var tank_icon := row.get_node("TankIcon") as TextureRect
		# The source result table scales the equipped 200x200 tank/skin art
		# into this small slot.  Minimap micro sprites are not used here.
		tank_icon.texture = _tank_texture(player)
		tank_icon.visible = true
		var name := row.get_node("PlayerName") as Label
		name.text = String(player.get("display_name", "Người chơi"))
		name.add_theme_color_override("font_color", _player_name_color(player))
		var team_text_color := _team_text_color(team_no)
		var kda := row.get_node("Kda") as Label
		kda.text = "%d/%d/%d" % [
			int(player.get("kills", 0)),
			int(player.get("deaths", 0)),
			int(player.get("assists", 0)),
		]
		kda.add_theme_color_override("font_color", team_text_color)
		var score := row.get_node("Score") as Label
		score.text = str(_performance(player))
		score.add_theme_color_override("font_color", team_text_color)


func _populate_featured_player() -> void:
	var featured := _mvp_player()
	if featured.is_empty() and not _players.is_empty():
		featured = _players[0]
	var viewer := _viewer_player()
	if viewer.is_empty():
		viewer = featured
	var tank_texture := _tank_texture(featured)
	_featured_tank.texture = tank_texture
	_featured_tank.size = tank_texture.get_size()
	_featured_tank.position = Vector2(
		(216.0 - tank_texture.get_width()) * 0.5,
		(200.0 - tank_texture.get_height()) * 0.5
	)
	_featured_name.text = String(featured.get("display_name", "Người chơi"))
	_tank_display_name.text = String(
		featured.get(
			"tank_display_name",
			featured.get("tank_name", featured.get("tank_key", "Tank"))
		)
	)
	# The source tank card contains the tank name, honors and player name only.
	# KDA and score belong exclusively to the player table on the left.
	_featured_stats.text = ""
	_featured_stats.visible = false
	var experience_reward := _result_experience(viewer)
	var silver_reward := (
		maxi(int(viewer.get("silver_reward", 0)), 0)
		if viewer.has("silver_reward")
		else maxi(_performance(viewer), 0)
	)
	_experience_base.text = "Cơ sở +%d" % experience_reward
	_experience_fashion.text = "Thời trang +0"
	_experience_vip.text = "VIP +0"
	_coin_base.text = "Cơ sở +%d" % silver_reward
	_coin_fashion.text = "Thời trang +0"
	_coin_vip.text = "VIP +0"
	_coin_total.text = str(silver_reward)
	var progression := _viewer_progression(viewer)
	var level := clampi(int(progression.get("level", 1)), 1, 40)
	var next_level := mini(level + 1, 40)
	var experience_value := maxi(int(progression.get("experience", 0)), 0)
	var experience_max := int(progression.get(
		"experience_max",
		ProfileProgression.experience_max_for_level(level)
	))
	var experience_ratio := 1.0 if experience_max <= 0 else clampf(
		float(experience_value) / float(experience_max), 0.0, 1.0
	)
	_set_level_badge(_current_level_base, _current_level_effect, level)
	_set_level_badge(_next_level_base, _next_level_effect, next_level)
	_level_percent.text = "MAX" if experience_max <= 0 else "%.2f%%" % (
		experience_ratio * 100.0
	)
	_level_numbers.text = "" if experience_max <= 0 else "%d / %d" % [
		experience_value,
		experience_max,
	]
	_level_bar_clip.size.x = roundf(221.0 * experience_ratio)
	_clear_container(_featured_honors)
	for winner_value: Variant in _honors.get("winners", []):
		if winner_value is not Dictionary:
			continue
		var winner: Dictionary = winner_value
		if String(winner.get("combatant_key", "")) != String(
			featured.get("combatant_key", "")
		):
			continue
		for honor_value: Variant in winner.get("honors", []):
			var honor := String(honor_value)
			if not HONOR_TEXTURES.has(honor):
				continue
			_featured_honors.add_child(_make_honor_badge(honor))
	var featured_tank_key := String(featured.get("tank_key", ""))
	# A viewer can only enter battle with a tank already present in their
	# owned roster.  Keep the session check for server payloads, while local
	# previews also show the source client's owned-state button correctly.
	var viewer_owns_featured_tank := _viewer_owns_tank(featured_tank_key)
	_owned_button.visible = viewer_owns_featured_tank
	_buy_tank_button.visible = not viewer_owns_featured_tank
	_other_rules_button.visible = true


func _queue_exit_request() -> void:
	if (
		not visible
		or not _auto_return_active
		or _action_requested
		or _action_queued
	):
		return
	# Keep the result screen above the lobby until the release event has fully
	# finished. Hiding it inside BaseButton.pressed lets the same release click
	# reach a Shop/Bag button underneath after the ready room is restored.
	_action_queued = true
	call_deferred("_request_exit")


func _queue_leave_request() -> void:
	if not visible or _action_requested or _action_queued:
		return
	_action_queued = true
	call_deferred("_request_leave")


func _request_exit() -> void:
	_action_queued = false
	if not visible or not _auto_return_active or _action_requested:
		return
	_action_requested = true
	_auto_return_active = false
	exit_requested.emit()


func _request_leave() -> void:
	_action_queued = false
	if not visible or _action_requested:
		return
	_action_requested = true
	_auto_return_active = false
	leave_requested.emit()


func _mvp_player() -> Dictionary:
	for winner_value: Variant in _honors.get("winners", []):
		if winner_value is not Dictionary:
			continue
		var winner: Dictionary = winner_value
		var winner_honors: Variant = winner.get("honors", [])
		if winner_honors is Array:
			var winner_honor_list: Array = winner_honors
			if "mvp" in winner_honor_list:
				return _player_from_award(winner)
	for award_value: Variant in _honors.get("awards", []):
		if award_value is not Dictionary:
			continue
		var award: Dictionary = award_value
		if String(award.get("type", "")) != "mvp":
			continue
		var award_player: Variant = award.get("player", {})
		if award_player is Dictionary:
			var award_player_data: Dictionary = award_player
			return _player_from_award(award_player_data)
	return {}


func _viewer_player() -> Dictionary:
	for player: Dictionary in _players:
		if String(player.get("combatant_key", "")) == _viewer_combatant_key:
			return player
	return {}


func _player_from_award(award_player: Dictionary) -> Dictionary:
	var combatant_key := String(award_player.get("combatant_key", ""))
	for player: Dictionary in _players:
		if String(player.get("combatant_key", "")) == combatant_key:
			return player
	return award_player


func _make_honor_badge(honor: String) -> Control:
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(55.0, 64.0)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = HONOR_TEXTURES[honor]
	icon.position = Vector2.ZERO
	icon.size = icon.texture.get_size()
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(icon)
	var label := TextureRect.new()
	label.texture = HONOR_LABEL_TEXTURES[honor]
	label.position = Vector2(6.5, 45.0)
	label.size = label.texture.get_size()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_child(label)
	return badge


func _tank_texture(player: Dictionary) -> Texture2D:
	var tank_key := String(player.get("tank_key", "gangtiexia03"))
	# Missing skin data means the base tank, not Iron Man's default skin. Using
	# a global skin fallback here made every incomplete opponent payload render
	# as Iron Man even when its authoritative tank_key was different.
	var skin_key := String(player.get("equipped_skin_key", ""))
	for key in ["equipped_skin_preview_asset_key", "tank_preview_asset_key"]:
		var asset_path := String(player.get(key, "")).strip_edges()
		var resolved_path := AssetPathAliases.resolve(asset_path)
		if asset_path.begins_with("res://") and ResourceLoader.exists(resolved_path):
			var direct_texture := ResourceLoader.load(
				resolved_path,
				"Texture2D"
			) as Texture2D
			if direct_texture != null:
				return direct_texture
	for original_key in [skin_key, tank_key]:
		var original_texture := _result_tank_texture(String(original_key))
		if original_texture != null:
			return original_texture
	var texture := TankSkinCatalog.texture_for(player, tank_key, skin_key)
	return texture if texture != null else IRONMAN_RESULT_TEXTURE


func _result_tank_texture(value: String) -> Texture2D:
	var asset_name := value.strip_edges().to_lower().get_file().get_basename()
	if asset_name.ends_with("_default"):
		asset_name = asset_name.trim_suffix("_default")
	if asset_name.is_empty():
		return null
	var asset_path := "res://assets/battle/result_tanks/%s.png" % asset_name
	return AssetPathAliases.load_texture(asset_path)


func _viewer_owns_tank(tank_key: String) -> bool:
	if tank_key.is_empty():
		return false
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return false
	for source_value: Variant in [session.get("lobby_data"), session.get("profile")]:
		if source_value is not Dictionary:
			continue
		if String((source_value as Dictionary).get("tank_key", "")) == tank_key:
			return true
		var owned_tanks: Variant = (source_value as Dictionary).get("owned_tanks", [])
		if owned_tanks is not Array:
			continue
		for tank_value: Variant in owned_tanks:
			if (
				tank_value is Dictionary
				and String(tank_value.get("tank_key", "")) == tank_key
				and bool(tank_value.get("owned", true))
			):
				return true
	return false


func _viewer_progression(featured: Dictionary) -> Dictionary:
	var progression := featured.duplicate(true)
	if featured.has("level_after") and featured.has("experience_after"):
		# The battle settlement snapshot is newer than the lobby cache that was
		# loaded before entering the match, so it must win on the result screen.
		progression["level"] = int(featured["level_after"])
		progression["experience"] = int(featured["experience_after"])
		progression["experience_max"] = ProfileProgression.experience_max_for_level(
			int(featured["level_after"])
		)
		return progression
	var session := get_node_or_null("/root/GameSession")
	if session == null:
		return progression
	var profile_value: Variant = session.get("profile")
	var lobby_value: Variant = session.get("lobby_data")
	for source_value: Variant in [profile_value, lobby_value]:
		if source_value is not Dictionary:
			continue
		var source: Dictionary = source_value
		for key in ["level", "experience", "experience_max"]:
			if source.has(key):
				progression[key] = source[key]
	return progression


func _set_level_badge(
	base: TextureRect,
	effect: SwfTimelinePlayer,
	level: int
) -> void:
	base.texture = AssetPathAliases.load_texture(
		"res://assets/ui/profile/level/level_%d.png" % level
	)
	var effect_path := _level_effect_path(level)
	if effect_path.is_empty():
		effect.stop()
		effect.visible = false
		return
	# The result header displays the 80x40 level badge at native size, twice
	# the lobby's 40x20 slot, so its original timeline effect scales with it.
	effect.scale = Vector2(0.88, 0.88) if level <= 20 else Vector2.ONE
	effect.modulate.a = 1.0
	if effect.timeline_path != effect_path:
		effect.load_timeline(effect_path)
	effect.visible = true
	effect.play()


func _level_effect_path(level: int) -> String:
	if level >= 36:
		return LEVEL_FX_36_40
	if level >= 31:
		return LEVEL_FX_31_35
	if level >= 21:
		return LEVEL_FX_21_30
	if level >= 11:
		return LEVEL_FX_11_20
	return ""


func _attach_shared_chat() -> void:
	if _chat_attached or not is_instance_valid(_shared_chat):
		return
	var history := _shared_chat.get_node_or_null("History") as Control
	var input_control := _shared_chat.get_node_or_null("Input") as Control
	var warning := _shared_chat.get_node_or_null("Warning") as CanvasItem
	if history == null or input_control == null:
		return
	_chat_original_parent = _shared_chat.get_parent()
	if _chat_original_parent == null:
		return
	_chat_original_index = _shared_chat.get_index()
	_chat_original_layout = _capture_layout(_shared_chat)
	_chat_history_layout = _capture_layout(history)
	_chat_input_layout = _capture_layout(input_control)
	_chat_original_visible = _shared_chat.visible
	_chat_input_visible = input_control.visible
	_chat_warning_visible = warning.visible if warning != null else false
	_shared_chat.reparent(_chat_host, false)
	_set_rect(_shared_chat, Vector2.ZERO, Vector2(464.0, 205.0))
	_set_rect(history, Vector2.ZERO, Vector2(464.0, 163.0))
	_set_rect(input_control, Vector2(0.0, 162.0), Vector2(464.0, 43.0))
	input_control.visible = true
	# PvpRoomView normally keeps this shared control collapsed.  The result
	# screen has its own full-width input area, so restore the complete input
	# visuals and hit targets without replacing LobbyChat's send/poll logic.
	if _shared_chat.has_method("set_full_input_layout"):
		_shared_chat.call("set_full_input_layout")
	if warning != null:
		warning.visible = false
	_shared_chat.visible = true
	_shared_chat.z_index = 20
	_chat_attached = true


func _detach_shared_chat() -> void:
	if not _chat_attached:
		return
	_chat_attached = false
	if not is_instance_valid(_shared_chat) or not is_instance_valid(_chat_original_parent):
		return
	_shared_chat.reparent(_chat_original_parent, false)
	_chat_original_parent.move_child(
		_shared_chat,
		clampi(_chat_original_index, 0, _chat_original_parent.get_child_count() - 1)
	)
	_restore_layout(_shared_chat, _chat_original_layout)
	var history := _shared_chat.get_node_or_null("History") as Control
	var input_control := _shared_chat.get_node_or_null("Input") as Control
	var warning := _shared_chat.get_node_or_null("Warning") as CanvasItem
	if history != null:
		_restore_layout(history, _chat_history_layout)
	if input_control != null:
		_restore_layout(input_control, _chat_input_layout)
		input_control.visible = _chat_input_visible
	if warning != null:
		warning.visible = _chat_warning_visible
	_shared_chat.visible = _chat_original_visible


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
		"z_index": control.z_index,
	}


func _restore_layout(control: Control, layout: Dictionary) -> void:
	if layout.is_empty():
		return
	control.anchor_left = float(layout["anchor_left"])
	control.anchor_top = float(layout["anchor_top"])
	control.anchor_right = float(layout["anchor_right"])
	control.anchor_bottom = float(layout["anchor_bottom"])
	control.offset_left = float(layout["offset_left"])
	control.offset_top = float(layout["offset_top"])
	control.offset_right = float(layout["offset_right"])
	control.offset_bottom = float(layout["offset_bottom"])
	control.z_index = int(layout["z_index"])


func _set_rect(control: Control, position_value: Vector2, size_value: Vector2) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 0.0
	control.anchor_bottom = 0.0
	control.offset_left = position_value.x
	control.offset_top = position_value.y
	control.offset_right = position_value.x + size_value.x
	control.offset_bottom = position_value.y + size_value.y


func _player_name_color(player: Dictionary) -> Color:
	if String(player.get("combatant_key", "")) == _viewer_combatant_key:
		return Color("69ff62")
	return _team_text_color(int(player.get("team_no", 0)))


func _team_text_color(team_no: int) -> Color:
	return Color("ffe130") if team_no == 1 else Color("ffffff")


func _clear_player_slots() -> void:
	for team_no in [1, 2]:
		var team := _team_1_rows if team_no == 1 else _team_2_rows
		for slot_no in range(1, 6):
			var row := team.get_node("Slot%d" % slot_no) as Control
			row.remove_meta("combatant_key")
			row.set_meta("team_no", team_no)
			(row.get_node("TankIcon") as TextureRect).visible = false
			(row.get_node("PlayerName") as Label).text = ""
			(row.get_node("Kda") as Label).text = ""
			(row.get_node("Score") as Label).text = ""
	_team_1_win.visible = false
	_team_2_win.visible = false


func _performance(player: Dictionary) -> int:
	return int(round(
		float(player.get("kills", 0)) * 5.0
		+ float(player.get("assists", 0)) * 3.0
		- float(player.get("deaths", 0)) * 2.0
	))


func _result_experience(player: Dictionary) -> int:
	if player.has("experience_reward"):
		return maxi(int(player.get("experience_reward", 0)), 0)
	if _result.has("experience_reward"):
		return maxi(int(_result.get("experience_reward", 0)), 0)
	var value := 50 + int(player.get("kills", 0)) * 10
	value += int(player.get("assists", 0)) * 5
	if String(_result.get("viewer_outcome", "")) == "win":
		value += 25
	return maxi(value, 0)


func _format_time(seconds: float) -> String:
	var total := maxi(roundi(seconds), 0)
	return "%d:%02d" % [total / 60, total % 60]


func _clear_container(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
