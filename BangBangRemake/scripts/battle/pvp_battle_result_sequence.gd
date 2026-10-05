class_name PvpBattleResultSequence
extends Control

signal honors_finished(
	result: Dictionary,
	players: Array[Dictionary],
	honors: Dictionary
)

const RESULT_TIMELINE := \
	"res://assets/animations/battle_result_mv_t_compact/timeline.json"
const TankSkinCatalog := preload("res://scripts/lobby/tank_skin_catalog.gd")
const AssetPathAliases := preload("res://scripts/data/asset_path_aliases.gd")
const HONOR_SLOT_SCENE := preload(
	"res://scenes/battle/PvpBattleHonorSlot.tscn"
)
const IRONMAN_RESULT_TEXTURE := preload(
	"res://assets/ui/tank/tank_ironman_reward.png"
)
const AVATAR_MALE := preload(
	"res://assets/battle/result/avatar_heads/boy001.png"
)
const AVATAR_FEMALE := preload(
	"res://assets/ui/profile/character_female_rgba.png"
)
const PEDESTAL_TEXTURES := {
	"enemy": preload(
		"res://assets/animations/battle_result_mv_t_compact/shapes/2.png"
	),
	"ally": preload(
		"res://assets/animations/battle_result_mv_t_compact/shapes/4.png"
	),
	"self": preload(
		"res://assets/animations/battle_result_mv_t_compact/shapes/6.png"
	),
}
const CHARACTER_NAME_BACKGROUNDS := {
	"enemy": preload(
		"res://assets/animations/battle_result_mv_t_compact/shapes/20.png"
	),
	"ally": preload(
		"res://assets/animations/battle_result_mv_t_compact/shapes/22.png"
	),
	"self": preload(
		"res://assets/animations/battle_result_mv_t_compact/shapes/24.png"
	),
}
const TANK_NAME_BACKGROUNDS := {
	"enemy": preload(
		"res://assets/animations/battle_result_mv_t_compact/shapes/10.png"
	),
	"ally": preload(
		"res://assets/animations/battle_result_mv_t_compact/shapes/12.png"
	),
	"self": preload(
		"res://assets/animations/battle_result_mv_t_compact/shapes/14.png"
	),
}
const MEDAL_FLASH_TEXTURE := preload(
	"res://assets/animations/battle_result_mv_t_compact/shapes/40.png"
)
const PEDESTAL_ROTATION_TEXTURE := preload(
	"res://assets/animations/battle_result_mv_t_compact/shapes/28.png"
)
const HONOR_TEXTURES := {
	"mvp": preload(
		"res://assets/animations/battle_result_mv_t_compact/shapes/33.png"
	),
	"killer": preload(
		"res://assets/animations/battle_result_mv_t_compact/shapes/36.png"
	),
	"assist": preload(
		"res://assets/animations/battle_result_mv_t_compact/shapes/37.png"
	),
}
const MEDAL_SPARK_TEXTURES := [
	preload("res://assets/animations/battle_result_mv_t_compact/shapes/43.png"),
	preload("res://assets/animations/battle_result_mv_t_compact/shapes/45.png"),
	preload("res://assets/animations/battle_result_mv_t_compact/shapes/47.png"),
	preload("res://assets/animations/battle_result_mv_t_compact/shapes/49.png"),
	preload("res://assets/animations/battle_result_mv_t_compact/shapes/51.png"),
	preload("res://assets/animations/battle_result_mv_t_compact/shapes/53.png"),
]
const HONOR_LABEL_TEXTURES := {
	"mvp": preload("res://assets/battle/result/honnor_label_kda_t.png"),
	"killer": preload("res://assets/battle/result/honnor_label_killer_t.png"),
	"assist": preload("res://assets/battle/result/honnor_label_assist_t.png"),
}
const SLOT_SIZE := Vector2(249.0, 492.0)
const PEDESTAL_SIZE := Vector2(249.0, 406.0)
const CHARACTER_NAME_COLOR := Color("fffa7f")
const CHARACTER_NAME_GLOW := Color("eb3801")
const OUTCOME_SECONDS := 94.0 / 24.0
const SOURCE_FPS := 24.0
# Exact main-timeline calls from battle_result_mv_t.swf. The nested character
# movie is 61 frames and the medal movie is 35 frames.
const CHARACTER_START_FRAMES := {
	1: [18],
	2: [18, 25],
	3: [18, 25, 32],
}
const MEDAL_START_FRAMES := {
	1: [72, 82, 92],
	2: [80, 90, 100],
	3: [88, 98, 108],
}
const SEGMENT_END_FRAMES := {1: 144, 2: 152, 3: 160}
const POST_MEDAL_HOLD_FRAMES := 36
const MEDAL_ICON_KEYFRAMES := [
	[3.1802979, 2.5, 183.55, 0.0],
	[3.1721497, 2.45, 182.9, 10.0 / 256.0],
	[3.1490479, 2.5, 180.9, 37.0 / 256.0],
	[3.1154175, 2.45, 178.0, 76.0 / 256.0],
	[3.0785828, 2.5, 174.85, 119.0 / 256.0],
	[3.0468445, 2.55, 172.05, 156.0 / 256.0],
	[2.857483, 2.5, 155.8, 165.0 / 256.0],
	[2.5989532, 2.55, 133.5, 178.0 / 256.0],
	[2.2881622, 2.5, 106.7, 193.0 / 256.0],
	[1.9473724, 2.5, 77.25, 210.0 / 256.0],
	[1.6021271, 2.5, 47.5, 227.0 / 256.0],
	[1.2784119, 2.45, 19.6, 242.0 / 256.0],
	[0.9998779, 2.5, -4.45, 1.0],
	[1.1998291, 2.5, -4.45, 1.0],
	[0.9998779, 2.5, -4.45, 1.0],
]
const MEDAL_FLASH_KEYFRAMES := [
	[0.27676392, 0.18208313, -40.5, -27.35, 97.0 / 256.0],
	[0.39427185, 0.25941467, -58.1, -38.95, 97.0 / 256.0],
	[0.51179504, 0.33673096, -75.75, -50.6, 97.0 / 256.0],
	[0.629303, 0.4140625, -93.35, -62.05, 97.0 / 256.0],
	[0.69262695, 0.45573425, -102.85, -68.3, 81.0 / 256.0],
	[0.7559662, 0.497406, -112.3, -74.55, 65.0 / 256.0],
	[0.81929016, 0.53907776, -121.8, -80.8, 49.0 / 256.0],
	[0.88261414, 0.58073425, -131.3, -87.05, 32.0 / 256.0],
	[0.9459686, 0.622406, -140.7, -93.25, 16.0 / 256.0],
	[1.0092773, 0.66407776, -150.3, -99.65, 0.0],
]

@onready var _movie: SwfTimelinePlayer = $MovieCenter/Movie
@onready var _honor_stage: Control = $HonorStage
@onready var _honor_slots: HBoxContainer = $HonorStage/Center/Slots
@onready var _bg_down_sound: AudioStreamPlayer = $BackgroundDownSound
@onready var _medal_down_sound: AudioStreamPlayer = $MedalDownSound

var _phase := "idle"
var _result: Dictionary = {}
var _players: Array[Dictionary] = []
var _honor_result: Dictionary = {}
var _viewer_combatant_key := "player"
var _sequence_token := 0


func _ready() -> void:
	visible = false
	_movie.timeline_path = RESULT_TIMELINE
	_movie.loop = false
	_movie.autoplay = false
	_movie.frame_changed.connect(_on_movie_frame_changed)


func begin(
	result: Dictionary,
	players: Array[Dictionary],
	viewer_combatant_key := "player"
) -> void:
	_sequence_token += 1
	_result = result.duplicate(true)
	_players = players.duplicate(true)
	_viewer_combatant_key = viewer_combatant_key
	_honor_result = BattleHonorCalculator.calculate(_players)
	_clear_container(_honor_slots)
	visible = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_honor_stage.visible = false
	_movie.visible = true
	_phase = "outcome"
	var outcome := String(_result.get("viewer_outcome", "draw"))
	if outcome == "lose":
		_movie.play_range(95, 189)
	else:
		_movie.play_range(1, 94)
	_wait_for_outcome_end(_sequence_token)


func reset() -> void:
	_sequence_token += 1
	_phase = "idle"
	_movie.stop()
	_movie.visible = false
	_honor_stage.visible = false
	_clear_container(_honor_slots)
	visible = false


func get_honor_result() -> Dictionary:
	return _honor_result.duplicate(true)


func is_sequence_active() -> bool:
	return visible and _phase in ["outcome", "honors"]


func _on_movie_frame_changed(frame_number: int) -> void:
	if _phase == "outcome" and frame_number in [94, 189]:
		_phase = "between"
		call_deferred("_play_honors")


func _wait_for_outcome_end(token: int) -> void:
	# The source player normally reports its last frame. The independent timer
	# guarantees progress even if a low-FPS frame skips that exact signal.
	await get_tree().create_timer(OUTCOME_SECONDS + 0.08).timeout
	if token == _sequence_token and _phase == "outcome":
		_phase = "between"
		_play_honors()


func _play_honors() -> void:
	var token := _sequence_token
	_phase = "honors"
	_movie.stop()
	_movie.visible = false
	_build_honor_slots()
	_honor_stage.visible = true
	await get_tree().process_frame
	var slots := _honor_slots.get_children()
	var recipient_count := clampi(slots.size(), 1, 3)
	var elapsed_frames := 0
	for index: int in range(slots.size()):
		if token != _sequence_token:
			return
		var start_frame := int(CHARACTER_START_FRAMES[recipient_count][index])
		await _wait_source_frames(start_frame - elapsed_frames)
		elapsed_frames = start_frame
		_animate_character_slot(slots[index] as Control, token)
	var badges := _ordered_badges()
	for index: int in range(badges.size()):
		if token != _sequence_token:
			return
		var start_frame := int(MEDAL_START_FRAMES[recipient_count][index])
		await _wait_source_frames(start_frame - elapsed_frames)
		elapsed_frames = start_frame
		_animate_medal(badges[index], token)
	if token != _sequence_token:
		return
	await _wait_source_frames(
		int(SEGMENT_END_FRAMES[recipient_count]) - elapsed_frames
		+ POST_MEDAL_HOLD_FRAMES
	)
	if token == _sequence_token:
		_complete_honors()


func _animate_character_slot(slot: Control, token: int) -> void:
	_bg_down_sound.play()
	var content := slot.get_node("Content") as Control
	var pedestal := content.get_node("Pedestal") as Control
	var pedestal_aura := content.get_node("PedestalAura") as Control
	var rotating_base := content.get_node("RotatingBase") as Node2D
	var avatar := content.get_node("Avatar") as Control
	var player_name_bg := content.get_node("PlayerNameBackground") as Control
	var player_name := content.get_node("PlayerName") as Control
	var tank_visual := content.get_node("TankVisual") as Control
	var tank_name_bg := content.get_node("TankNameBackground") as Control
	var tank_name := content.get_node("TankName") as Control

	# Frames 2-9 of Timeline_1: a thin vertical beam widens into the full
	# pedestal. Its pivot stays fixed, so the base never spins or wanders.
	pedestal.pivot_offset = PEDESTAL_SIZE * 0.5
	pedestal.scale = Vector2(0.03, 1.0)
	pedestal.modulate.a = 0.0
	var pedestal_tween := pedestal.create_tween()
	pedestal_tween.set_parallel(true)
	pedestal_tween.tween_property(
		pedestal, "scale:x", 1.0, 8.0 / SOURCE_FPS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pedestal_tween.tween_property(
		pedestal, "modulate:a", 1.0, 5.0 / SOURCE_FPS
	)
	await pedestal_tween.finished
	if token != _sequence_token:
		return
	_start_rotating_base(rotating_base)
	pedestal_aura.pivot_offset = PEDESTAL_SIZE * 0.5
	pedestal_aura.scale = Vector2(0.92, 0.97)
	pedestal_aura.modulate.a = 0.72
	var aura_tween := pedestal_aura.create_tween()
	aura_tween.set_parallel(true)
	aura_tween.tween_property(
		pedestal_aura, "scale", Vector2(1.08, 1.04), 10.0 / SOURCE_FPS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	aura_tween.tween_property(
		pedestal_aura, "modulate:a", 0.0, 10.0 / SOURCE_FPS
	)

	# Runtime Flash inserted the portrait, name and tank into these canvases.
	# Reveal them in the same order requested by those nested placeholders.
	await _reveal_control(
		avatar,
		avatar.position + Vector2(0.0, -38.0),
		avatar.position,
		7.0 / SOURCE_FPS,
		Tween.TRANS_BACK
	)
	if token != _sequence_token:
		return
	player_name_bg.modulate.a = 0.0
	var name_bg_tween := player_name_bg.create_tween()
	name_bg_tween.tween_property(
		player_name_bg, "modulate:a", 1.0, 4.0 / SOURCE_FPS
	)
	await _reveal_control(
		player_name,
		player_name.position,
		player_name.position,
		5.0 / SOURCE_FPS
	)
	if token != _sequence_token:
		return
	var tank_tween := tank_visual.create_tween()
	tank_visual.position = Vector2(0.0, 46.0)
	tank_visual.pivot_offset = SLOT_SIZE * 0.5
	tank_visual.scale = Vector2(0.76, 0.76)
	tank_visual.modulate.a = 0.0
	tank_name_bg.modulate.a = 0.0
	tank_name.modulate.a = 0.0
	tank_tween.set_parallel(true)
	tank_tween.tween_property(
		tank_visual,
		"position",
		Vector2.ZERO,
		10.0 / SOURCE_FPS
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tank_tween.tween_property(
		tank_visual,
		"scale",
		Vector2.ONE,
		10.0 / SOURCE_FPS
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tank_tween.tween_property(
		tank_visual,
		"modulate:a",
		1.0,
		7.0 / SOURCE_FPS
	)
	tank_tween.tween_property(
		tank_name_bg,
		"modulate:a",
		1.0,
		8.0 / SOURCE_FPS
	)
	tank_tween.tween_property(
		tank_name,
		"modulate:a",
		1.0,
		8.0 / SOURCE_FPS
	)
	await tank_tween.finished


func _animate_medal(badge: Control, token: int) -> void:
	var visual := badge.get_node("Visual") as Control
	var icon := visual.get_node("Icon") as Control
	var label_texture := visual.get_node("Label") as Control
	var flash := visual.get_node("ImpactFlash") as Control
	var spark := visual.get_node("Spark") as TextureRect
	var source_origin := Vector2(50.0, 28.0)
	visual.modulate = Color.WHITE
	icon.pivot_offset = icon.size * 0.5
	icon.rotation = 0.0
	label_texture.modulate.a = 0.0
	flash.modulate.a = 0.0
	spark.visible = false
	for frame_index: int in range(1, 36):
		if token != _sequence_token:
			return
		var icon_frame_index := mini(frame_index, MEDAL_ICON_KEYFRAMES.size()) - 1
		var icon_frame: Array = MEDAL_ICON_KEYFRAMES[icon_frame_index]
		var icon_scale := float(icon_frame[0])
		icon.scale = Vector2(icon_scale, icon_scale)
		icon.position = (
			source_origin
			+ Vector2(float(icon_frame[1]), float(icon_frame[2]))
			- icon.pivot_offset
		)
		icon.modulate.a = float(icon_frame[3])
		if frame_index == 9:
			_medal_down_sound.play()
		if frame_index == 16:
			_shake_honor_stage()
		_apply_source_medal_flash(flash, source_origin, frame_index)
		_apply_source_medal_spark(spark, source_origin, frame_index)
		label_texture.modulate.a = 1.0 if frame_index >= 24 else 0.0
		await _wait_source_frames(1)


func _apply_source_medal_flash(
	flash: Control,
	source_origin: Vector2,
	frame_index: int
) -> void:
	if frame_index < 13 or frame_index > 22:
		flash.modulate.a = 0.0
		return
	var frame: Array = MEDAL_FLASH_KEYFRAMES[frame_index - 13]
	flash.position = source_origin + Vector2(float(frame[2]), float(frame[3]))
	flash.scale = Vector2(float(frame[0]), float(frame[1]))
	flash.modulate.a = float(frame[4])


func _apply_source_medal_spark(
	spark: TextureRect,
	source_origin: Vector2,
	frame_index: int
) -> void:
	if frame_index < 14 or frame_index > 23:
		spark.visible = false
		return
	var texture_index := mini(int((frame_index - 14) / 2), 5)
	spark.texture = MEDAL_SPARK_TEXTURES[texture_index]
	spark.position = source_origin + Vector2(-159.0, -107.95)
	spark.visible = true


func _start_rotating_base(base: Node2D) -> void:
	base.modulate.a = 1.0
	var source_rotation := base.get_node("SourceRotation") as Sprite2D
	var rotation_tween := source_rotation.create_tween().set_loops()
	rotation_tween.tween_property(
		source_rotation,
		"rotation",
		source_rotation.rotation + TAU,
		100.0 / SOURCE_FPS
	).set_trans(Tween.TRANS_LINEAR)


func _ordered_badges() -> Array[Control]:
	var result: Array[Control] = []
	for award_value: Variant in _honor_result.get("awards", []):
		if not award_value is Dictionary:
			continue
		var award := award_value as Dictionary
		var player := award.get("player", {}) as Dictionary
		var combatant_key := String(player.get("combatant_key", ""))
		var honor_type := String(award.get("type", ""))
		for slot_value: Variant in _honor_slots.get_children():
			var slot := slot_value as Control
			if String(slot.get_meta("combatant_key", "")) != combatant_key:
				continue
			var honors := slot.get_node("Honors") as Control
			for layout_value: Variant in honors.get_children():
				var layout := layout_value as Control
				if not layout.visible:
					continue
				for badge_value: Variant in layout.get_children():
					var badge := badge_value as Control
					if String(badge.get_meta("honor_type", "")) == honor_type:
						result.append(badge)
						break
			break
	return result


func _wait_source_frames(frame_count: int) -> void:
	if frame_count > 0:
		await get_tree().create_timer(float(frame_count) / SOURCE_FPS).timeout


func _shake_honor_stage() -> void:
	var start := _honor_stage.position
	var tween := _honor_stage.create_tween()
	tween.tween_property(
		_honor_stage, "position", start + Vector2(4.0, -2.0), 0.035
	)
	tween.tween_property(
		_honor_stage, "position", start + Vector2(-3.0, 2.0), 0.035
	)
	tween.tween_property(_honor_stage, "position", start, 0.045)


func _reveal_control(
	control: Control,
	start_position: Vector2,
	end_position: Vector2,
	duration: float,
	transition := Tween.TRANS_QUAD
) -> void:
	control.position = start_position
	control.modulate.a = 0.0
	var tween := control.create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		control,
		"position",
		end_position,
		duration
	).set_trans(transition).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "modulate:a", 1.0, duration)
	await tween.finished


func _complete_honors() -> void:
	if _phase not in ["honors", "between"]:
		return
	_phase = "done"
	visible = false
	honors_finished.emit(
		_result.duplicate(true),
		_players.duplicate(true),
		_honor_result.duplicate(true)
	)


func _build_honor_slots() -> void:
	_clear_container(_honor_slots)
	var winners: Array = _honor_result.get("winners", [])
	for winner_value: Variant in winners:
		if winner_value is Dictionary:
			_honor_slots.add_child(_make_honor_slot(winner_value))


func _make_honor_slot(winner: Dictionary) -> Control:
	var slot := HONOR_SLOT_SCENE.instantiate() as Control
	var relation := _winner_relation(winner)
	slot.set_meta("relation", relation)
	slot.set_meta("combatant_key", String(winner.get("combatant_key", "")))

	var honor_values: Array[String] = []
	for honor_value: Variant in winner.get("honors", []):
		var honor := String(honor_value)
		if HONOR_TEXTURES.has(honor):
			honor_values.append(honor)

	var content := slot.get_node("Content") as Control
	if honor_values.size() >= 3:
		var triple_offset := slot.get_node(
			"LayoutGuides/TripleContentOffset"
		) as Marker2D
		content.position += triple_offset.position

	(content.get_node("Pedestal") as TextureRect).texture = (
		PEDESTAL_TEXTURES[relation]
	)
	(content.get_node("PedestalAura") as TextureRect).texture = (
		PEDESTAL_TEXTURES[relation]
	)
	(content.get_node("PlayerNameBackground") as TextureRect).texture = (
		CHARACTER_NAME_BACKGROUNDS[relation]
	)
	(content.get_node("TankNameBackground") as TextureRect).texture = (
		TANK_NAME_BACKGROUNDS[relation]
	)

	var avatar := content.get_node("Avatar") as Control
	var portrait := avatar.get_node("Portrait") as TextureRect
	portrait.texture = _honor_avatar_texture(winner)
	portrait.size = portrait.texture.get_size()
	portrait.position = Vector2(
		(avatar.size.x - portrait.size.x) * 0.5,
		0.0
	)
	var player_name := content.get_node("PlayerName") as Label
	player_name.text = String(winner.get("display_name", "Người chơi"))

	var tank_image := content.get_node("TankVisual/TankImage") as TextureRect
	tank_image.texture = _tank_texture(winner)
	tank_image.size = tank_image.texture.get_size()
	var tank_name := content.get_node("TankName") as Label
	tank_name.text = String(
		winner.get(
			"tank_display_name",
			winner.get("tank_key", "Tank")
		)
	)

	_configure_honor_layout(slot, honor_values)
	_prepare_honor_slot_for_runtime(slot)
	return slot


func _prepare_honor_slot_for_runtime(slot: Control) -> void:
	# Scene defaults remain fully visible so its layout can be edited directly
	# in Godot. The runtime sequence hides each layer only after instantiation,
	# while HonorStage is still hidden, then reveals it through the source timing.
	var content := slot.get_node("Content") as Control
	(content.get_node("Pedestal") as CanvasItem).modulate.a = 0.0
	(content.get_node("PedestalAura") as CanvasItem).modulate.a = 0.0
	(content.get_node("RotatingBase") as CanvasItem).modulate.a = 0.0
	(content.get_node("Avatar") as CanvasItem).modulate.a = 0.0
	(content.get_node("PlayerNameBackground") as CanvasItem).modulate.a = 0.0
	(content.get_node("PlayerName") as CanvasItem).modulate.a = 0.0
	(content.get_node("TankVisual") as CanvasItem).modulate.a = 0.0
	(content.get_node("TankNameBackground") as CanvasItem).modulate.a = 0.0
	(content.get_node("TankName") as CanvasItem).modulate.a = 0.0
	var honors := slot.get_node("Honors") as Control
	for layout_value: Variant in honors.get_children():
		var layout := layout_value as Control
		if not layout.visible:
			continue
		for badge_value: Variant in layout.get_children():
			var badge := badge_value as Control
			var visual := badge.get_node("Visual") as Control
			visual.modulate.a = 0.0
			(visual.get_node("ImpactFlash") as CanvasItem).modulate.a = 0.0
			(visual.get_node("Spark") as CanvasItem).visible = false
			(visual.get_node("Icon") as CanvasItem).modulate.a = 0.0
			(visual.get_node("Label") as CanvasItem).modulate.a = 0.0


func _configure_honor_layout(
	slot: Control,
	honor_values: Array[String]
) -> void:
	var honors := slot.get_node("Honors") as Control
	for layout_value: Variant in honors.get_children():
		(layout_value as Control).visible = false
	var count := clampi(honor_values.size(), 1, 3)
	var layout_name := (
		"LayoutSingle"
		if count == 1
		else ("LayoutDouble" if count == 2 else "LayoutTriple")
	)
	var layout := honors.get_node(layout_name) as Control
	layout.visible = true
	var display_honors := honor_values.duplicate()
	if (
		count == 2
		and display_honors.has("killer")
		and display_honors.has("mvp")
	):
		display_honors = ["killer", "mvp"]
	for badge_index: int in layout.get_child_count():
		var badge := layout.get_child(badge_index) as Control
		badge.visible = badge_index < display_honors.size()
		if not badge.visible:
			continue
		var honor := String(display_honors[badge_index])
		badge.set_meta("honor_type", honor)
		var icon := badge.get_node("Visual/Icon") as TextureRect
		icon.texture = HONOR_TEXTURES[honor]
		icon.size = icon.texture.get_size()
		var label_texture := badge.get_node("Visual/Label") as TextureRect
		label_texture.texture = HONOR_LABEL_TEXTURES[honor]
		label_texture.size = label_texture.texture.get_size()


func _honor_avatar_texture(winner: Dictionary) -> Texture2D:
	var avatar_key := String(winner.get("avatar_key", "")).strip_edges()
	avatar_key = avatar_key.get_file().get_basename()
	var gender := String(winner.get("gender", "male")).to_lower()
	var candidates: Array[String] = []
	if not avatar_key.is_empty():
		candidates.append(avatar_key)
	candidates.append("female" if gender == "female" else "male")
	for candidate: String in candidates:
		var path := AssetPathAliases.resolve(
			"res://assets/battle/result/avatar_heads/%s.png" % candidate
		)
		if ResourceLoader.exists(path):
			return ResourceLoader.load(path, "Texture2D") as Texture2D
	return AVATAR_FEMALE if gender == "female" else AVATAR_MALE


func _make_honor_slot_legacy(winner: Dictionary) -> Control:
	var relation := _winner_relation(winner)
	var honor_values: Array[String] = []
	for honor_value: Variant in winner.get("honors", []):
		var honor_key := String(honor_value)
		if HONOR_TEXTURES.has(honor_key):
			honor_values.append(honor_key)
	var content_shift := 42.0 if honor_values.size() >= 3 else 0.0
	var slot := Control.new()
	slot.custom_minimum_size = SLOT_SIZE
	slot.set_meta("relation", relation)
	slot.set_meta("combatant_key", String(winner.get("combatant_key", "")))

	var pedestal := TextureRect.new()
	pedestal.name = "Pedestal"
	pedestal.texture = PEDESTAL_TEXTURES[relation]
	pedestal.position = Vector2(0.0, content_shift)
	pedestal.size = PEDESTAL_SIZE
	pedestal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pedestal.modulate.a = 0.0
	slot.add_child(pedestal)
	var pedestal_aura := TextureRect.new()
	pedestal_aura.name = "PedestalAura"
	pedestal_aura.texture = PEDESTAL_TEXTURES[relation]
	pedestal_aura.position = Vector2(0.0, content_shift)
	pedestal_aura.size = PEDESTAL_SIZE
	pedestal_aura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pedestal_aura.modulate.a = 0.0
	slot.add_child(pedestal_aura)
	# The SWF places shape 28 inside the coloured pedestal with blendMode 9
	# (subtract), then rotates that child for exactly 100 source frames. Keeping
	# the non-uniform scale on the parent makes the base stay horizontal while
	# only its internal light pattern revolves.
	var rotating_base := Node2D.new()
	rotating_base.name = "RotatingBase"
	rotating_base.position = Vector2(124.5, 334.9 + content_shift)
	rotating_base.scale = Vector2(2.259262, 1.0)
	rotating_base.modulate.a = 0.0
	var source_rotation := Sprite2D.new()
	source_rotation.name = "SourceRotation"
	source_rotation.texture = PEDESTAL_ROTATION_TEXTURE
	source_rotation.centered = true
	var subtract_shader := Shader.new()
	subtract_shader.code = (
		"shader_type canvas_item;\n"
		+ "render_mode unshaded, blend_sub;\n"
	)
	var subtract_material := ShaderMaterial.new()
	subtract_material.shader = subtract_shader
	source_rotation.material = subtract_material
	rotating_base.add_child(source_rotation)
	slot.add_child(rotating_base)

	var honor_row := Control.new()
	honor_row.name = "Honors"
	honor_row.position = Vector2.ZERO
	honor_row.size = Vector2(SLOT_SIZE.x, 150.0)
	honor_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for honor_index: int in honor_values.size():
		var honor := honor_values[honor_index]
		var badge := Control.new()
		badge.position = _honor_badge_position(
			honor_values,
			honor,
			honor_index
		)
		badge.size = Vector2(100.0, 100.0)
		badge.set_meta("honor_type", honor)
		var visual := Control.new()
		visual.name = "Visual"
		visual.size = Vector2(100.0, 100.0)
		visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
		visual.modulate.a = 0.0
		var flash := _native_texture_rect(MEDAL_FLASH_TEXTURE)
		flash.name = "ImpactFlash"
		var flash_material := CanvasItemMaterial.new()
		flash_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		flash.material = flash_material
		flash.modulate.a = 0.0
		visual.add_child(flash)
		var spark := TextureRect.new()
		spark.name = "Spark"
		spark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		spark.size = Vector2(322.0, 202.0)
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		spark.visible = false
		visual.add_child(spark)
		var icon := _native_texture_rect(HONOR_TEXTURES[honor])
		icon.name = "Icon"
		icon.modulate.a = 0.0
		visual.add_child(icon)
		var label_texture := _native_texture_rect(HONOR_LABEL_TEXTURES[honor])
		label_texture.name = "Label"
		label_texture.position = Vector2(
			(100.0 - label_texture.size.x) * 0.5,
			71.75
		)
		label_texture.modulate.a = 0.0
		visual.add_child(label_texture)
		badge.add_child(visual)
		honor_row.add_child(badge)
	slot.add_child(honor_row)

	var avatar_texture := (
		AVATAR_FEMALE
		if String(winner.get("gender", "male")) == "female"
		else AVATAR_MALE
	)
	var avatar := Control.new()
	avatar.name = "Avatar"
	avatar.position = Vector2(0.0, 96.0 + content_shift)
	avatar.size = Vector2(SLOT_SIZE.x, 126.0)
	avatar.clip_contents = true
	avatar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	avatar.modulate.a = 0.0
	var portrait := _native_texture_rect(avatar_texture)
	portrait.name = "Portrait"
	portrait.position = Vector2(
		(SLOT_SIZE.x - avatar_texture.get_width()) * 0.5,
		0.0
	)
	avatar.add_child(portrait)
	slot.add_child(avatar)
	var player_name_bg := _native_texture_rect(
		CHARACTER_NAME_BACKGROUNDS[relation]
	)
	player_name_bg.name = "PlayerNameBackground"
	player_name_bg.position = Vector2(
		(SLOT_SIZE.x - player_name_bg.size.x) * 0.5,
		210.0 + content_shift
	)
	player_name_bg.modulate.a = 0.0
	slot.add_child(player_name_bg)

	var player_name := _result_label(
		String(winner.get("display_name", "Người chơi")),
		18,
		CHARACTER_NAME_COLOR
	)
	player_name.add_theme_color_override(
		"font_outline_color",
		CHARACTER_NAME_GLOW
	)
	player_name.name = "PlayerName"
	player_name.position = Vector2(8.0, 211.0 + content_shift)
	player_name.size = Vector2(SLOT_SIZE.x - 16.0, 26.0)
	player_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	player_name.modulate.a = 0.0
	slot.add_child(player_name)

	var tank_texture := _tank_texture(winner)
	var tank_visual := Control.new()
	tank_visual.name = "TankVisual"
	tank_visual.position = Vector2.ZERO
	tank_visual.size = SLOT_SIZE
	tank_visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tank_visual.modulate.a = 0.0
	var tank := _native_texture_rect(tank_texture)
	tank.name = "TankImage"
	var tank_size := tank_texture.get_size()
	tank.position = Vector2(
		(SLOT_SIZE.x - tank_size.x) * 0.5,
		194.0 + content_shift + (200.0 - tank_size.y) * 0.5
	)
	tank_visual.add_child(tank)
	slot.add_child(tank_visual)
	var tank_name_bg := _native_texture_rect(TANK_NAME_BACKGROUNDS[relation])
	tank_name_bg.name = "TankNameBackground"
	tank_name_bg.position = Vector2(
		(SLOT_SIZE.x - tank_name_bg.size.x) * 0.5,
		404.0 + content_shift
	)
	tank_name_bg.modulate.a = 0.0
	slot.add_child(tank_name_bg)

	var tank_name := _result_label(
		String(
			winner.get(
				"tank_display_name",
				winner.get("tank_key", "Tank")
			)
		),
		14,
		Color.WHITE
	)
	tank_name.name = "TankName"
	tank_name.position = tank_name_bg.position
	tank_name.size = tank_name_bg.size
	tank_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tank_name.modulate.a = 0.0
	slot.add_child(tank_name)
	return slot


func _honor_badge_position(
	honors: Array,
	honor: String,
	index: int
) -> Vector2:
	match honors.size():
		1:
			return Vector2(74.5, 0.0)
		2:
			if honors.has("killer") and honors.has("mvp"):
				return Vector2(24.5 if honor == "killer" else 124.5, 0.0)
			return Vector2(24.5 + float(index) * 100.0, 0.0)
		_:
			match honor:
				"killer":
					return Vector2(74.5, 0.0)
				"assist":
					return Vector2(9.5, 48.0)
				_:
					return Vector2(139.5, 48.0)


func _winner_relation(winner: Dictionary) -> String:
	if String(winner.get("combatant_key", "")) == _viewer_combatant_key:
		return "self"
	if int(winner.get("team_no", 0)) == int(
		_result.get("viewer_team_no", 0)
	):
		return "ally"
	return "enemy"


func _relation_color(relation: String) -> Color:
	match relation:
		"self":
			return Color("61f05b")
		"ally":
			return Color("58cfff")
		_:
			return Color("ff625c")


func _tank_texture(winner: Dictionary) -> Texture2D:
	var tank_key := String(winner.get("tank_key", "gangtiexia03"))
	var skin_key := String(
		winner.get("equipped_skin_key", "gangtiexia03_default")
	)
	var texture := TankSkinCatalog.texture_for(winner, tank_key, skin_key)
	return texture if texture != null else IRONMAN_RESULT_TEXTURE


func _native_texture_rect(texture: Texture2D) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.size = texture.get_size()
	rect.custom_minimum_size = texture.get_size()
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


func _result_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.05, 0.08))
	label.add_theme_constant_override("outline_size", 3)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _clear_container(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()
