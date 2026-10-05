extends Control

signal camera_intro_finished
signal settings_requested
signal skill_command_requested(command: Dictionary)
signal local_skill_result_applied(result: Dictionary)
signal battle_finished(result: Dictionary)
signal result_exit_requested
signal result_summary_requested(
	result: Dictionary,
	players: Array[Dictionary],
	honors: Dictionary
)

const PROJECTILE_SCENE := preload(
	"res://scenes/battle/PvpBattleProjectile.tscn"
)
const TURRET_PROJECTILE_SCENE := preload(
	"res://scenes/battle/PvpBattleTurretProjectile.tscn"
)
const CHIEF_PROJECTILE_SCENE := preload(
	"res://scenes/battle/PvpBattleChiefProjectile.tscn"
)
const IRONMAN_ENERGY_PROJECTILE_SCENE := preload(
	"res://scenes/battle/PvpBattleIronmanEnergyProjectile.tscn"
)
const BATTLE_TANK_SCENE := preload(
	"res://scenes/battle/PvpBattleTank.tscn"
)
const BATTLE_BUILDING_SCENE := preload(
	"res://scenes/battle/PvpBattleBuilding.tscn"
)
const FOOTPOINT_SCENE := preload(
	"res://scenes/battle/PvpBattleFootpoint.tscn"
)
const TEAM_STATE_CARD_SCENE := preload(
	"res://scenes/battle/PvpBattleTeamStateCard.tscn"
)
const BUILDING_CATALOG := preload(
	"res://scripts/data/battle_building_catalog.gd"
)
const CHIEF_CATALOG := preload(
	"res://scripts/data/battle_chief_catalog.gd"
)
const GAMEPLAY_RULE_CATALOG := preload(
	"res://scripts/data/battle_gameplay_rule_catalog.gd"
)
const ProfileProgression := preload("res://scripts/data/profile_progression.gd")
const SKILL_TARGETING_SCRIPT := preload(
	"res://scripts/battle/pvp_battle_skill_targeting.gd"
)
const SKILL_TOOLTIP_SCRIPT := preload(
	"res://scripts/battle/pvp_battle_skill_tooltip.gd"
)
const IRONMAN_SKILL_TOOLTIP_DATA := preload(
	"res://scripts/data/ironman_skill_tooltip_data.gd"
)
const BATTLE_INPUT_STATE := preload(
	"res://scripts/battle/pvp_battle_input_state.gd"
)
const DAMAGE_NUMBER_SCRIPT := preload(
	"res://scripts/battle/pvp_battle_damage_number.gd"
)
const MAX_RANGE_INDICATOR_SCRIPT := preload(
	"res://scripts/battle/pvp_battle_max_range_indicator.gd"
)
const MAP_DISPLAY_NAME := "Maya Tiên tri [Tính Điểm]"
const MAP_CENTER := Vector2(1080.0, 706.5)
const MAP_SIZE := Vector2(2160.0, 1413.0)
const MAP_LAYOUT_PATH := \
	"res://assets/battle/maps/Maya Tiên tri(Tính điểm)/data1_c.godot.json"
const MAP_BUILDING_COLLISION_OVERRIDE_PATH := \
	"res://assets/battle/maps/Maya Tiên tri(Tính điểm)/data1_c.building_collision_overrides.json"
# The old 12px movement footprint only blocked the tank's centre while the
# opaque Iron Man body spans roughly 109x79px, so the sprite visibly sank deep
# into walls. Use the existing 36px combat-body radius for terrain movement.
const TANK_COLLISION_RADIUS := 36.0
const COLLISION_MOVE_STEP := 12.0
const TANK_COLLISION_CENTER_OFFSET := Vector2(0.0, 12.0)
const MOVEMENT_SLIDE_ITERATIONS := 4
const MOVEMENT_SWEEP_BINARY_STEPS := 10
const IRONMAN_BASE_MOVE_SPEED := 170.0
const IRONMAN_BASE_HIT_POINTS := 2325
const IRONMAN_BASE_BASIC_ATTACK_DAMAGE := 238.0
const IRONMAN_BASE_PENETRATION := 30.0
const IRONMAN_BASE_PHYSICAL_ARMOR := 150.0
const IRONMAN_BASE_ENERGY_SHIELD := 150.0
const IRONMAN_TANK_KEY := "gangtiexia03"
const IRONMAN_BASE_FIRE_RATE := 66.0
const IRONMAN_BASE_ATTACK_RANGE := 480.0
const IRONMAN_BASE_CRITICAL_CHANCE_PERCENT := 5.0
const IRONMAN_BASE_CRITICAL_DAMAGE_PERCENT := 150.0
const DAMAGE_TYPE_PHYSICAL := "physical"
const DAMAGE_TYPE_ENERGY := "energy"
const FOOTPOINT_TRIGGER_BUILDING_IDS := [46, 47]
const FOOTPOINT_SPAWN_POINTS := {
	46: Vector2(1296.0, 480.0),
	47: Vector2(864.0, 936.0),
}
# The source Maya route network bounds the neutral creature's centre lane by
# these exact corner coordinates. The two spawn holes sit immediately outside
# opposite corners and become passable when crates #46/#47 are destroyed.
const FOOTPOINT_ROAM_RECT := Rect2(876.0, 492.0, 408.0, 432.0)
const FOOTPOINT_HIT_POINTS := 80
const FOOTPOINT_MOVE_SPEED := 217.0
const FOOTPOINT_ATTACK := 360.0
const FOOTPOINT_PENETRATION := 150.0
const FOOTPOINT_ARMOR := 300.0
const FOOTPOINT_ALERT_RANGE := 480.0
const FOOTPOINT_HIT_RADIUS := 36.0
const FOOTPOINT_CONTACT_RADIUS := 72.0
const FOOTPOINT_EXPLOSION_RADIUS := 144.0
# Effect 20101 stores iBurstHarm=500. Attribute-damage values in this XML are
# percentages, so skill 201 applies five times AINpcLevel 168's attack value.
const FOOTPOINT_EXPLOSION_DAMAGE := FOOTPOINT_ATTACK * 5.0
const FOOTPOINT_RESPAWN_SECONDS := 5.0
const FOOTPOINT_BIRTH_SECONDS := 15.0 / 24.0
# The original client exposes armour and penetration as integer point stats.
# 1000 is the defence scale: at 1,000 effective defence, incoming damage is
# halved.  It is not bonus damage/defence and it is kept explicit so the
# authoritative battle server can apply exactly the same conversion.
const DEFENCE_REDUCTION_SCALE := 1000.0
const ASSIST_CONTRIBUTION_SECONDS := 6.0
const RESPAWN_SECONDS := 10.0
# The original protect_time.swf timeline is slowed to 1.5 seconds on respawn;
# the gameplay invulnerability uses the exact same window.
const RESPAWN_PROTECTION_SECONDS := 1.5
const RESPAWN_PROTECTION_PLAYBACK_SPEED := (16.0 / 20.0) / RESPAWN_PROTECTION_SECONDS
const IRONMAN_SKILL_RANGE := 600.0
const IRONMAN_SKILL_AREA_RADIUS := 144.0
const IRONMAN_R_SELECT_WIDTH := 96.0
# iSelectRange=144 in the original XML is the E impact radius.  The original
# select circle therefore spans its full diameter (288), not 144 pixels.
const IRONMAN_E_SELECT_DIAMETER := IRONMAN_SKILL_AREA_RADIUS * 2.0
const IRONMAN_TIA_RANGE := 600.0
const IRONMAN_TIA_HALF_WIDTH := 24.0
const IRONMAN_TIA_SELECT_WIDTH := 48.0
const IRONMAN_TARGET_RADIUS := 36.0
const IRONMAN_R_DAMAGE_RATIO := 2.67
const IRONMAN_E_DAMAGE_RATIO := 0.75
# Tooltip/XML behaviour: E can damage structures, but loses 50% of that
# damage before normal armour/penetration mitigation is applied.
const IRONMAN_E_STRUCTURE_DAMAGE_MULTIPLIER := 0.5
const IRONMAN_TIA_DAMAGE_RATIO := 1.25
const IRONMAN_E_TICK_SECONDS := 0.5
const IRONMAN_E_FIELD_SECONDS := 3.0
const IRONMAN_TIA_TICK_SECONDS := 0.2
const IRONMAN_TIA_SECONDS := 4.0
const IRONMAN_TIA_CANCEL_DELAY_SECONDS := 1.0
const IRONMAN_TIA_HIT_SHAKE_SECONDS := 0.18
const IRONMAN_TIA_HIT_SHAKE_DEGREES := 0.65
const IRONMAN_TIA_HIT_SHAKE_OFFSET := 1.2
const IRONMAN_TIA_HIT_SHAKE_HERTZ := 20.0
# Skill XML does not expose turning speed. This deliberately conservative
# value keeps Space visibly slower than normal cannon aiming.
# XML 363301 does not expose a turn-speed parameter. This is deliberately
# conservative so the Space beam does not snap around the cursor.
const IRONMAN_TIA_TURN_SPEED_DEGREES := 20.0
const IRONMAN_R_SLOW_SECONDS := 2.5
const IRONMAN_R_SLOW_TICK_SECONDS := 0.5
const IRONMAN_R_SLOW_START := 0.75
const IRONMAN_R_SLOW_RECOVERY := 0.05
const IRONMAN_E_SLOW_SECONDS := 1.0
const IRONMAN_E_SLOW_VALUE := 0.5
const IRONMAN_E_STUN_SECONDS := 1.0
const TEST_BOT_HIT_POINTS := 50000
const TEST_BOTS_STATIONARY := true
const IRONMAN_SHIELD_RATIO := 0.3
const IRONMAN_SHIELD_BREAK_DAMAGE_RATIO := 2.36
const IRONMAN_SHIELD_BREAK_RADIUS := 300.0
const IRONMAN_SHIELD_RECHARGE_SECONDS := 15.0
const IRONMAN_SKILL_IDS := [363401, 363201, 363301]
const EFFECT_SKILL_GANGTIE01 := \
	"res://assets/animations/skill_gangtie01_compact/timeline.json"
const EFFECT_BLOW_GANGTIE01 := \
	"res://assets/animations/blow_gangtie01_compact/timeline.json"
const EFFECT_BUFF_GANGTIE01 := \
	"res://assets/animations/buff_gangtie01_compact/timeline.json"
const EFFECT_BUFF_GANGTIE02 := \
	"res://assets/animations/buff_gangtie02_compact/timeline.json"
const EFFECT_BUFF_GANGTIE03 := \
	"res://assets/animations/buff_gangtie03_compact/timeline.json"
const EFFECT_SI_GANGTIE01 := \
	"res://assets/animations/si_gangtie01_compact/timeline.json"
const EFFECT_SI_GANGTIE02 := \
	"res://assets/animations/si_gangtie02_compact/timeline.json"
const EFFECT_SLOW01 := \
	"res://assets/animations/slow01_compact/timeline.json"
const EFFECT_STUN_SLOW := \
	"res://assets/animations/stun_slow_compact/timeline.json"
const EFFECT_IRONMAN_DEATH := \
	"res://assets/animations/ironman_death_compact/timeline.json"
const EFFECT_IRONMAN_DEATH_BLOW := \
	"res://assets/animations/ironman_death_blow_compact/timeline.json"
const EFFECT_RESPAWN_PROTECTION := \
	"res://assets/animations/battle_respawn_protect_compact/timeline.json"
const EFFECT_RESPAWN_FACE := \
	"res://assets/animations/face_relive_t_compact/timeline.json"
const EFFECT_SCORE_GAIN := \
	"res://assets/animations/pvp_score_tip_compact/timeline.json"
const EFFECT_CHIEF_DEATH := \
	"res://assets/animations/chief_oil_death_compact/timeline.json"
const EFFECT_NORMAL_BULLET_BLOW := \
	"res://assets/animations/normal_bullet_blow_compact/timeline.json"
const EFFECT_NORMAL_BULLET_WALL_BLOW := \
	"res://assets/animations/normal_bullet_blow02_compact/timeline.json"
# The source SWF stage is 115x115. Its compact shapes are already centred
# around (0, 0), while the converted stage offset is (-57.5, -57.5); cancel
# only that stage offset so the blue flash centre matches the shell contact.
const NORMAL_BULLET_WALL_STAGE_CENTER := Vector2(57.5, 57.5)
const PING_INTERVAL_SECONDS := 2.0
const AUTHORITATIVE_PROTOCOL_VERSION := 2
const AUTHORITATIVE_SNAPSHOT_INTERVAL_SECONDS := 0.1
const AUTHORITATIVE_MOVE_INTERVAL_SECONDS := 0.1
const AUTHORITATIVE_BEAM_AIM_INTERVAL_SECONDS := 0.1
# Two channel reads happen per poll. 1.25s keeps the combined request rate
# below the server's 120 reads/minute account limit with room for transitions.
const BATTLE_CHAT_POLL_INTERVAL_SECONDS := 1.25
# The parent match flow already refreshes the match twice per second. This
# independent two-second presence check keeps the combined endpoint traffic
# below its 180 reads/minute limit.
const BATTLE_PRESENCE_POLL_INTERVAL_SECONDS := 2.0
const BATTLE_CHAT_BUBBLE_SECONDS := 4.0
const BATTLE_CHAT_MAX_VISIBLE_MESSAGES := 5
const BATTLE_CHAT_MAX_CHARACTERS := 64
const MINIMAP_SIZE := Vector2(200.0, 131.0)
const MINIMAP_TANK_MARKER_SIZE := Vector2(28.0, 28.0)
const MINIMAP_TANK_HEAD_SIZE := Vector2(25.0, 25.0)
const MINIMAP_SELF_FRAME := preload(
	"res://assets/battle/hud/minimap/tank_micro_green_bg.png"
)
const MINIMAP_FRIEND_FRAME := preload(
	"res://assets/battle/hud/minimap/tank_micro_blue_bg.png"
)
const MINIMAP_ENEMY_FRAME := preload(
	"res://assets/battle/hud/minimap/tank_micro_red_bg.png"
)
const SCORE_LEFT_BLUE := preload("res://assets/battle/hud/alive/left_blue.png")
const SCORE_LEFT_RED := preload("res://assets/battle/hud/alive/left_red.png")
const SCORE_RIGHT_BLUE := preload("res://assets/battle/hud/alive/right_blue.png")
const SCORE_RIGHT_RED := preload("res://assets/battle/hud/alive/right_red.png")
const IRONMAN_MICRO_HEAD := preload(
	"res://assets/battle/hud/minimap/gangtiexia_small.png"
)
const PING_TEXT_COLOR := Color(0.2, 1.0, 0.2)
const DAMAGE_NUMBER_OFFSET_Y := -72.0
const HEAL_NUMBER_OFFSET_Y := -92.0
const DAMAGE_NUMBER_LANE_OFFSETS := [-36.0, 36.0, 0.0]

@export_range(0.0, 3.0, 0.05) var center_hold_seconds := 0.35
@export_range(0.1, 5.0, 0.05) var camera_travel_seconds := 1.6
@export_range(0.5, 60.0, 0.5) var skill_test_cooldown_seconds := 5.0
@export var use_local_skill_fallback := true

@onready var _viewport_container: SubViewportContainer = $ViewportContainer
@onready var _world_viewport: SubViewport = $ViewportContainer/WorldViewport
@onready var _world: Node2D = $ViewportContainer/WorldViewport/World
@onready var _camera: Camera2D = $ViewportContainer/WorldViewport/World/Camera
@onready var _spawns: Node2D = $ViewportContainer/WorldViewport/World/Spawns
@onready var _terrain_collision: StaticBody2D = \
	$ViewportContainer/WorldViewport/World/TerrainCollision
@onready var _player_anchor: CharacterBody2D = \
	$ViewportContainer/WorldViewport/World/PlayerTankAnchor
@onready var _player_tank: Node2D = \
	$ViewportContainer/WorldViewport/World/PlayerTankAnchor/PlayerTank
@onready var _participant_tanks: Node2D = \
	$ViewportContainer/WorldViewport/World/ParticipantTanks
@onready var _chiefs: Node2D = \
	$ViewportContainer/WorldViewport/World/Chiefs
@onready var _map_buildings: Node2D = \
	$ViewportContainer/WorldViewport/World/MapBuildings
@onready var _neutral_footpoints: Node2D = \
	$ViewportContainer/WorldViewport/World/NeutralFootpoints
@onready var _editor_map_objects: Node2D = \
	$ViewportContainer/WorldViewport/World/EditorMapObjects
@onready var _projectiles: Node2D = \
	$ViewportContainer/WorldViewport/World/Projectiles
@onready var _skill_effects: Node2D = \
	$ViewportContainer/WorldViewport/World/SkillEffects
@onready var _footpoint_effect_preview: Node2D = \
	$ViewportContainer/WorldViewport/World/FootpointEffectPreview
@onready var _footpoint_birth_template: SwfTimelinePlayer = \
	$ViewportContainer/WorldViewport/World/FootpointEffectPreview/XuatHien
@onready var _footpoint_blow_template: SwfTimelinePlayer = \
	$ViewportContainer/WorldViewport/World/FootpointEffectPreview/No
@onready var _footpoint_death_template: SwfTimelinePlayer = \
	$ViewportContainer/WorldViewport/World/FootpointEffectPreview/XacChet
@onready var _damage_numbers: Node2D = \
	$ViewportContainer/WorldViewport/World/DamageNumbers
@onready var _map_name_label: Label = $BattleHud/MapName
@onready var _battle_hud: Control = $BattleHud
@onready var _score_rule_hud: Control = $BattleHud/ScoreRuleHud
@onready var _score_left_side: TextureRect = $BattleHud/ScoreRuleHud/LeftSide
@onready var _score_right_side: TextureRect = $BattleHud/ScoreRuleHud/RightSide
@onready var _score_left_label: Label = $BattleHud/ScoreRuleHud/LeftScore
@onready var _score_right_label: Label = $BattleHud/ScoreRuleHud/RightScore
@onready var _score_limit_label: Label = $BattleHud/ScoreRuleHud/ScoreLimit
@onready var _score_timer_label: Label = $BattleHud/ScoreRuleHud/Timer
@onready var _score_left_gain_effect: SwfTimelinePlayer = \
	$BattleHud/ScoreRuleHud/LeftScore/ScoreGainEffect
@onready var _score_right_gain_effect: SwfTimelinePlayer = \
	$BattleHud/ScoreRuleHud/RightScore/ScoreGainEffect
@onready var _minimap_marker: TextureRect = \
	$BattleHud/Minimap/PlayerMarker
@onready var _minimap_tank_markers: Control = \
	$BattleHud/Minimap/TankMarkers
@onready var _team_state_left: Control = $BattleHud/TeamStateLeft
@onready var _team_state_right: Control = $BattleHud/TeamStateRight
@onready var _hp_fill_clip: Control = \
	$BattleHud/BottomStatus/Health/HpFillClip
@onready var _hp_value: RichTextLabel = \
	$BattleHud/BottomStatus/Health/HpValue
@onready var _ping_label: Label = $BattleHud/TopRight/Ping
@onready var _settings_button: TextureButton = \
	$BattleHud/TopRight/Settings
@onready var _settings_panel: PvpBattleSettings = \
	$BattleHud/SettingsPanel
@onready var _skill_1: Control = $BattleHud/BottomStatus/Skill1
@onready var _skill_2: Control = $BattleHud/BottomStatus/Skill2
@onready var _skill_3: Control = $BattleHud/BottomStatus/Skill3
@onready var _shield_buff_icon: TextureRect = \
	$BattleHud/BottomStatus/ShieldBuffIcon
@onready var _kda_label: Label = $BattleHud/TopRight/Kda
@onready var _battle_chat_history: RichTextLabel = $BattleHud/ChatHistory
@onready var _battle_chat: Control = $BattleHud/BattleChat
@onready var _battle_chat_channel_button: Button = \
	$BattleHud/BattleChat/ChannelButton
@onready var _battle_chat_channel_label: Label = \
	$BattleHud/BattleChat/Channel
@onready var _battle_chat_input: LineEdit = $BattleHud/BattleChat/Input
@onready var _ping_request: HTTPRequest = $PingRequest
@onready var _respawn_overlay: Control = $BattleHud/RespawnOverlay
@onready var _respawn_count_label: Label = \
	$BattleHud/RespawnOverlay/Countdown
@onready var _respawn_free_label: Label = \
	$BattleHud/RespawnOverlay/FreeCount
@onready var _respawn_now_button: TextureButton = \
	$BattleHud/RespawnOverlay/RespawnNow
@onready var _battle_result_sequence: PvpBattleResultSequence = \
	$BattleResultSequence

var _match_data: Dictionary = {}
var _camera_tween: Tween
var _intro_generation := 0
var _control_enabled := false
var _camera_following := false
var _tank_move_speed := IRONMAN_BASE_MOVE_SPEED
var _max_hit_points := IRONMAN_BASE_HIT_POINTS
var _current_hit_points := IRONMAN_BASE_HIT_POINTS
var _tank_basic_attack_damage := IRONMAN_BASE_BASIC_ATTACK_DAMAGE
var _tank_penetration := IRONMAN_BASE_PENETRATION
var _tank_physical_armor := IRONMAN_BASE_PHYSICAL_ARMOR
var _tank_energy_shield := IRONMAN_BASE_ENERGY_SHIELD
var _tank_fire_rate := IRONMAN_BASE_FIRE_RATE
var _tank_attack_range := IRONMAN_BASE_ATTACK_RANGE
var _tank_critical_chance_percent := IRONMAN_BASE_CRITICAL_CHANCE_PERCENT
var _tank_critical_damage_percent := IRONMAN_BASE_CRITICAL_DAMAGE_PERCENT
var _tank_damage_type := DAMAGE_TYPE_PHYSICAL
var _auto_fire_enabled := false
var _shot_cooldown_remaining := 0.0
var _ping_elapsed := PING_INTERVAL_SECONDS
var _ping_started_msec := 0
var _ping_in_flight := false
var _movement_input_state := BATTLE_INPUT_STATE.new()
var _static_collision_rectangles: Array[Rect2] = []
var _map_layout: Dictionary = {}
var _viewer_team_no := 1
var _battle_rules: Dictionary = {}
var _battle_rules_started := false
var _battle_finished := false
var _battle_winner_team_no := 0
var _team_scores := {1: 0, 2: 0}
var _building_collision_overrides: Dictionary = {}
var _building_collision_rectangles: Dictionary = {}
var _initial_building_collision_rectangles: Dictionary = {}
var _map_building_instances: Dictionary = {}
var _footpoint_spawners: Dictionary = {}
var _footpoint_generation := 0
var _skill_cooldown_seconds: Array[float] = [
	5.0,
	5.0,
	5.0,
]
var _skill_targeting: PvpBattleSkillTargeting
var _skill_tooltip
var _combatants: Dictionary = {}
var _strike_fields: Array[Dictionary] = []
var _skill_channel: Dictionary = {}
var _hovered_skill_index := -1
var _ironman_shield_points := 0
var _ironman_shield_recharge_remaining := 0.0
var _ironman_shield_effect: Node2D
var _damage_number_sequences: Dictionary = {}
var _battle_elapsed_seconds := 0.0
var _remaining_free_respawns := 1
var _test_mod_player_respawn := false
var _test_mod_no_cooldown := false
var _test_mod_invincible := false
var _test_mod_bot_movement := false
var _respawn_button_tween: Tween
var _team_state_cards: Dictionary = {}
var _team_state_cards_by_account: Dictionary = {}
var _team_state_cards_by_name: Dictionary = {}
var _minimap_markers: Dictionary = {}
var _battle_chat_channel := "battle"
var _battle_chat_entries: Array[String] = []
var _battle_chat_last_ids := {"team": 0, "battle": 0}
var _battle_chat_poll_elapsed := BATTLE_CHAT_POLL_INTERVAL_SECONDS
var _battle_presence_poll_elapsed := BATTLE_PRESENCE_POLL_INTERVAL_SECONDS
var _battle_chat_poll_in_flight := false
var _battle_presence_poll_in_flight := false
var _battle_chat_send_in_flight := false
var _battle_chat_generation := 0
var _battle_presence_by_account: Dictionary = {}
var _battle_join_announced: Dictionary = {}
var _battle_player_names: Dictionary = {}
var _battle_player_teams: Dictionary = {}
var _battle_viewer_account_id := ""
var _battle_seen_active_phase := false
var _battle_match_end_announced := false
var _battle_chat_last_valid_input := ""
var _battle_chat_input_guard := false
var _last_battle_result: Dictionary = {}
var _server_authoritative_battle := false
var _authoritative_ready := false
var _authoritative_generation := 0
var _authoritative_revision := -1
var _authoritative_state_epoch := -1
var _authoritative_sequence := 0
var _authoritative_snapshot_elapsed := 0.0
var _authoritative_move_elapsed := 0.0
var _authoritative_beam_aim_elapsed := 0.0
var _authoritative_snapshot_in_flight := false
var _authoritative_command_in_flight := false
var _authoritative_command_queue: Array[Dictionary] = []
var _authoritative_last_move := Vector2(999.0, 999.0)
var _authoritative_sync_error_shown := false


func _ready() -> void:
	# EditorMapPreview temporarily disables stretching to expose the full map
	# canvas. Restore the normal stretch-driven game viewport before battle
	# rendering and camera logic begin.
	_viewport_container.stretch = true
	# EditorMapObjects is the saved authoring layer. Runtime reads its data, but
	# only the real PvpBattleBuilding instances below may be rendered in battle.
	_editor_map_objects.visible = false
	_footpoint_effect_preview.visible = false
	_minimap_marker.visible = false
	_load_map_layout()
	_build_terrain_collision()
	_spawn_map_buildings()
	if not GameSession.battle_realtime_snapshot_received.is_connected(
		_on_battle_realtime_snapshot_received
	):
		GameSession.battle_realtime_snapshot_received.connect(
			_on_battle_realtime_snapshot_received
		)
	_ping_request.request_completed.connect(_on_ping_request_completed)
	_settings_button.pressed.connect(_on_settings_pressed)
	_settings_panel.surrender_requested.connect(_on_settings_surrender_requested)
	_settings_panel.settings_changed.connect(_on_battle_settings_changed)
	_battle_chat_channel_button.pressed.connect(_toggle_battle_chat_channel)
	_battle_chat_input.text_changed.connect(
		_on_battle_chat_input_text_changed
	)
	_respawn_now_button.pressed.connect(_on_respawn_now_pressed)
	_respawn_now_button.mouse_entered.connect(
		_on_respawn_now_button_hovered.bind(true)
	)
	_respawn_now_button.mouse_exited.connect(
		_on_respawn_now_button_hovered.bind(false)
	)
	_respawn_now_button.button_down.connect(_on_respawn_now_button_down)
	_battle_result_sequence.honors_finished.connect(
		_on_result_honors_finished
	)
	_skill_1.connect("requested", _on_skill_slot_requested.bind(0))
	_skill_2.connect("requested", _on_skill_slot_requested.bind(1))
	_skill_3.connect("requested", _on_skill_slot_requested.bind(2))
	_skill_1.connect("cancellation_requested", _cancel_skill_targeting)
	_skill_2.connect("cancellation_requested", _cancel_skill_targeting)
	_skill_3.connect("cancellation_requested", _cancel_skill_targeting)
	_skill_1.connect("hover_changed", _on_skill_slot_hover_changed.bind(0))
	_skill_2.connect("hover_changed", _on_skill_slot_hover_changed.bind(1))
	_skill_3.connect("hover_changed", _on_skill_slot_hover_changed.bind(2))
	_skill_targeting = SKILL_TARGETING_SCRIPT.new()
	_world.add_child(_skill_targeting)
	_skill_tooltip = SKILL_TOOLTIP_SCRIPT.new()
	_battle_hud.add_child(_skill_tooltip)
	_shield_buff_icon.visible = false
	_respawn_overlay.visible = false
	_reset_battle_chat()
	_reset_battle_rules()
	_map_name_label.text = MAP_DISPLAY_NAME
	_reset_skills()
	_update_health_hud()
	_update_kda_hud()
	_update_minimap_marker()


func _input(event: InputEvent) -> void:
	if _settings_panel.is_open():
		if _settings_panel.handle_pointer_event(event):
			get_viewport().set_input_as_handled()
			return
		var settings_key_event := event as InputEventKey
		if (
			settings_key_event != null
			and settings_key_event.pressed
			and not settings_key_event.echo
			and settings_key_event.keycode == KEY_ESCAPE
		):
			_settings_panel.close()
			get_viewport().set_input_as_handled()
		return
	var settings_mouse_event := event as InputEventMouseButton
	if (
		settings_mouse_event != null
		and settings_mouse_event.pressed
		and settings_mouse_event.button_index == MOUSE_BUTTON_LEFT
		and _settings_button.get_global_rect().has_point(
			settings_mouse_event.position
		)
	):
		_on_settings_pressed()
		get_viewport().set_input_as_handled()
		return
	var chat_key_event := event as InputEventKey
	if chat_key_event != null and not chat_key_event.echo:
		var chat_keycode := chat_key_event.physical_keycode
		if chat_keycode == 0:
			chat_keycode = chat_key_event.keycode
		if (
			chat_key_event.pressed
			and chat_keycode in [KEY_ENTER, KEY_KP_ENTER]
		):
			_handle_battle_chat_enter()
			get_viewport().set_input_as_handled()
			return
		if _battle_chat.visible:
			if chat_key_event.pressed and chat_keycode == KEY_ESCAPE:
				_close_battle_chat()
				get_viewport().set_input_as_handled()
			elif chat_key_event.pressed and chat_keycode == KEY_TAB:
				_toggle_battle_chat_channel()
				get_viewport().set_input_as_handled()
			# Let LineEdit consume normal typing, but never pass those same keys to
			# movement or skills while the chat field owns focus.
			return
	# Enter/chat remains live throughout the result movie. Every battle action
	# below this point is frozen once a winner has been decided.
	if _battle_finished:
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null:
		if (
			_battle_chat.visible
			and mouse_event.pressed
			and mouse_event.button_index == MOUSE_BUTTON_LEFT
			and _battle_chat_channel_button.get_global_rect().has_point(
				mouse_event.position
			)
		):
			_toggle_battle_chat_channel()
			get_viewport().set_input_as_handled()
			return
		if (
			_battle_chat.visible
			and _battle_chat.get_global_rect().has_point(mouse_event.position)
		):
			return
		if _respawn_overlay.visible:
			if (
				mouse_event.pressed
				and mouse_event.button_index == MOUSE_BUTTON_LEFT
				and _respawn_now_button.visible
				and not _respawn_now_button.disabled
				and _respawn_now_button.get_global_rect().has_point(
					mouse_event.position
				)
			):
				_on_respawn_now_pressed()
			get_viewport().set_input_as_handled()
			return
		# Handle the three HUD slots at the map level as well as in their own
		# Control script.  SubViewport input ordering is platform-dependent, so
		# this is the authoritative route for both direct-click casting and hover.
		var skill_index := _skill_index_at_hud_position(mouse_event.position)
		if skill_index >= 0:
			if mouse_event.pressed:
				if mouse_event.button_index == MOUSE_BUTTON_LEFT:
					_on_skill_slot_requested(skill_index)
				elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
					_cancel_skill_targeting()
			get_viewport().set_input_as_handled()
			return
		if _is_pointer_over_interactive_battle_hud(mouse_event.position):
			return
		_handle_fire_mouse_button(mouse_event)
		return
	var key_event := event as InputEventKey
	if key_event == null or key_event.echo:
		return
	var keycode := key_event.physical_keycode
	if keycode == 0:
		keycode = key_event.keycode
	if keycode == KEY_W:
		_set_movement_key(KEY_W, key_event.pressed)
	elif keycode == KEY_S:
		_set_movement_key(KEY_S, key_event.pressed)
	elif keycode == KEY_A:
		_set_movement_key(KEY_A, key_event.pressed)
	elif keycode == KEY_D:
		_set_movement_key(KEY_D, key_event.pressed)
	elif keycode == KEY_R and key_event.pressed:
		_try_select_skill(0)
	elif keycode == KEY_E and key_event.pressed:
		_try_select_skill(1)
	elif keycode == KEY_SPACE and key_event.pressed:
		if not _skill_channel.is_empty():
			_try_cancel_tia_tan_ra()
		else:
			_try_select_skill(2)


func _process(delta: float) -> void:
	if not visible:
		return
	if _server_authoritative_battle:
		_process_authoritative_network(delta)
	_process_battle_rules(delta)
	_process_battle_chat(delta)
	if _battle_finished:
		return
	_process_respawn_runtime(delta)
	_process_neutral_footpoint_ai(delta)
	# World-owned skill instances have their own lifetime. They must never pause
	# just because the caster dies, loses input control, or waits to respawn.
	# Future persistent areas/projectiles should be advanced from this branch.
	_process_persistent_world_skill_runtime(delta)
	_update_battle_roster_ui()
	_update_skill_hud_hover()
	_ping_elapsed = _ping_elapsed + delta
	if _ping_elapsed >= PING_INTERVAL_SECONDS and not _ping_in_flight:
		_request_real_ping()
	if not _control_enabled:
		# Player input is disabled during death/respawn, but the battle world must
		# keep running: turrets can still defend against living enemies and bots
		# can continue their own AI. Do not start either during loading/camera
		# intro, where control is also deliberately disabled.
		var player_combatant: Dictionary = _combatants.get("player", {})
		if bool(player_combatant.get("dead", false)):
			_process_bot_ai(delta)
			_process_chief_ai(delta)
			_process_turret_ai(delta)
		return
	# A player-owned channel/cooldown belongs to battle time, not to the input
	# overlay. Opening chat or Settings blocks new controls, but must not freeze
	# an already-running Space channel or its transition into cooldown.
	_process_player_bound_skill_runtime(delta)
	if _battle_chat.visible:
		_process_bot_ai(delta)
		_process_chief_ai(delta)
		_process_turret_ai(delta)
		return
	if _settings_panel.is_open():
		_player_anchor.velocity = Vector2.ZERO
		_process_bot_ai(delta)
		_process_chief_ai(delta)
		_process_turret_ai(delta)
		return
	if _skill_targeting.is_active():
		_skill_targeting.update_target(
			_player_anchor.global_position,
			_world_mouse_position()
		)
	if _skill_channel.is_empty():
		_update_cannon_aim()
	else:
		_player_tank.call(
			"aim_cannon_at",
			_player_anchor.global_position
			+ _skill_channel.get("direction", Vector2.RIGHT)
		)
	_update_auto_fire(delta)
	_process_bot_ai(delta)
	_process_chief_ai(delta)
	_process_turret_ai(delta)


func _reset_battle_rules() -> void:
	if _battle_rules.is_empty():
		_battle_rules = GAMEPLAY_RULE_CATALOG.resolve(_map_layout)
	_battle_rules_started = false
	_battle_finished = false
	_battle_winner_team_no = 0
	_team_scores = {1: 0, 2: 0}
	_battle_elapsed_seconds = 0.0
	_last_battle_result = {}
	if is_instance_valid(_world):
		_world.process_mode = Node.PROCESS_MODE_INHERIT
	if is_instance_valid(_battle_result_sequence):
		_battle_result_sequence.reset()
	_battle_chat.z_index = 0
	_battle_chat_history.z_index = 0
	_reset_score_gain_effect(_score_left_gain_effect)
	_reset_score_gain_effect(_score_right_gain_effect)
	_update_score_rule_hud()


func _process_battle_rules(delta: float) -> void:
	if _server_authoritative_battle:
		_update_score_rule_hud()
		return
	if not _battle_rules_started or _battle_finished:
		_update_score_rule_hud()
		return
	_battle_elapsed_seconds = minf(
		_battle_elapsed_seconds + delta,
		float(_battle_rules.get("duration_seconds", 240.0))
	)
	_update_score_rule_hud()
	if _battle_elapsed_seconds < float(
		_battle_rules.get("duration_seconds", 240.0)
	):
		return
	var team_1_score := int(_team_scores.get(1, 0))
	var team_2_score := int(_team_scores.get(2, 0))
	var winner_team_no := 0
	if team_1_score > team_2_score:
		winner_team_no = 1
	elif team_2_score > team_1_score:
		winner_team_no = 2
	_finish_battle(winner_team_no, "time_limit")


func _add_team_score(team_no: int, points: int, reason: String) -> void:
	if _server_authoritative_battle:
		return
	if (
		not _battle_rules_started
		or _battle_finished
		or team_no not in [1, 2]
		or points <= 0
	):
		return
	_team_scores[team_no] = int(_team_scores.get(team_no, 0)) + points
	_update_score_rule_hud()
	if points == 1:
		_play_score_gain_effect(team_no)
	if int(_team_scores[team_no]) >= int(
		_battle_rules.get("score_limit", 25)
	):
		_finish_battle(team_no, reason)


func _play_score_gain_effect(team_no: int) -> void:
	var effect := (
		_score_left_gain_effect
		if team_no == 1
		else _score_right_gain_effect
	)
	if not is_instance_valid(effect):
		return
	effect.visible = true
	effect.play_range(1, effect.get_frame_count())


func _reset_score_gain_effect(effect: SwfTimelinePlayer) -> void:
	if not is_instance_valid(effect):
		return
	if effect.timeline_path != EFFECT_SCORE_GAIN:
		effect.load_timeline(EFFECT_SCORE_GAIN)
	effect.stop()
	effect.visible = true


func _finish_battle(winner_team_no: int, reason: String) -> void:
	if _battle_finished:
		return
	_battle_finished = true
	_battle_rules_started = false
	_battle_winner_team_no = winner_team_no
	_control_enabled = false
	_clear_movement_keys()
	_reset_firing()
	_cancel_skill_targeting()
	_finish_tia_tan_ra(false)
	_respawn_overlay.visible = false
	# Freeze the complete battle simulation (tanks, AI, bullets and world-owned
	# skills) in one place. Battle chat lives in BattleHud, outside this world.
	_world.process_mode = Node.PROCESS_MODE_DISABLED
	_battle_chat.z_index = 120
	_battle_chat_history.z_index = 120
	var viewer_outcome := "draw"
	if winner_team_no > 0:
		viewer_outcome = "win" if winner_team_no == _viewer_team_no else "lose"
	var result := {
		"mode": String(_battle_rules.get("mode", "")),
		"reason": reason,
		"winner_team_no": winner_team_no,
		"viewer_team_no": _viewer_team_no,
		"viewer_outcome": viewer_outcome,
		"team_1_score": int(_team_scores.get(1, 0)),
		"team_2_score": int(_team_scores.get(2, 0)),
		"elapsed_seconds": _battle_elapsed_seconds,
	}
	var result_players := _build_result_players()
	result["players"] = result_players
	_battle_result_sequence.begin(result, result_players, "player")
	result["honors"] = _battle_result_sequence.get_honor_result()
	_last_battle_result = result.duplicate(true)
	battle_finished.emit(result)


func _on_result_honors_finished(
	result: Dictionary,
	players: Array[Dictionary],
	honors: Dictionary
) -> void:
	result_summary_requested.emit(result, players, honors)


func _build_result_players() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var viewer: Dictionary = _viewer_participant()
	var viewer_team := int(viewer.get("team_no", _viewer_team_no))
	var viewer_slot := int(viewer.get("slot_no", 1))
	for participant_value: Variant in _match_data.get("participants", []):
		if participant_value is not Dictionary:
			continue
		var participant: Dictionary = participant_value
		var team_no := int(participant.get("team_no", 0))
		var slot_no := int(participant.get("slot_no", 0))
		if team_no not in [1, 2] or slot_no < 1 or slot_no > 5:
			continue
		var combatant_key := (
			"player"
			if team_no == viewer_team and slot_no == viewer_slot
			else "participant:%d:%d" % [team_no, slot_no]
		)
		var combatant: Dictionary = _combatants.get(combatant_key, {})
		var kills := int(combatant.get("kills", 0))
		var deaths := int(combatant.get("deaths", 0))
		var assists := int(combatant.get("assists", 0))
		var progression := participant.duplicate(true)
		if combatant_key == "player":
			progression.merge(GameSession.profile, true)
			progression.merge(GameSession.lobby_data, true)
		var level := clampi(int(
			combatant.get("level_after", progression.get("level", 1))
		), 1, 40)
		var experience := maxi(int(
			combatant.get("experience_after", progression.get("experience", 0))
		), 0)
		var result_player := {
			"combatant_key": combatant_key,
			"account_id": String(participant.get("account_id", "")),
			"display_name": _participant_display_name(participant, slot_no),
			"team_no": team_no,
			"slot_no": slot_no,
			"tank_key": String(participant.get("tank_key", "gangtiexia03")),
			"equipped_skin_key": String(
				participant.get("equipped_skin_key", "gangtiexia03_default")
			),
			"tank_preview_asset_key": String(
				participant.get("tank_preview_asset_key", "")
			),
			"equipped_skin_preview_asset_key": String(
				participant.get("equipped_skin_preview_asset_key", "")
			),
			"tank_micro_asset_key": String(
				participant.get("tank_micro_asset_key", "")
			),
			"skins": (
				participant.get("skins", []).duplicate(true)
				if participant.get("skins", []) is Array
				else []
			),
			"skin_frame_tier": String(participant.get("skin_frame_tier", "")),
			"tank_display_name": String(
				participant.get(
					"tank_display_name",
					participant.get("tank_name", participant.get("tank_key", "Tank"))
				)
			),
			"gender": String(participant.get("gender", "male")),
			"avatar_key": String(participant.get("avatar_key", "")),
			"is_bot": bool(participant.get("is_bot", false)),
			"kills": kills,
			"deaths": deaths,
			"assists": assists,
			"level": level,
			"experience": experience,
			"experience_max": int(progression.get(
				"experience_max",
				ProfileProgression.experience_max_for_level(level)
			)),
			"mvp_score": float(kills * 5 + assists * 3 - deaths * 2),
		}
		for reward_key in [
			"experience_reward",
			"silver_reward",
			"level_after",
			"experience_after",
			"silver_after",
		]:
			if combatant.has(reward_key):
				result_player[reward_key] = combatant[reward_key]
		result.append(result_player)
	if not result.is_empty():
		return result
	# Editor/offline previews may not have a participant payload. Preserve a
	# useful deterministic result table from the registered tank combatants.
	for combatant_key_value: Variant in _combatants.keys():
		var combatant_key := String(combatant_key_value)
		var combatant: Dictionary = _combatants[combatant_key]
		if (
			bool(combatant.get("is_chief", false))
			or bool(combatant.get("is_map_object", false))
			or bool(combatant.get("is_neutral_footpoint", false))
		):
			continue
		var team_no := int(combatant.get("team_no", 0))
		var slot_no := 1
		if combatant_key.begins_with("participant:"):
			var key_parts := combatant_key.split(":")
			if key_parts.size() >= 3:
				slot_no = int(key_parts[2])
		var kills := int(combatant.get("kills", 0))
		var deaths := int(combatant.get("deaths", 0))
		var assists := int(combatant.get("assists", 0))
		result.append({
			"combatant_key": combatant_key,
			"display_name": "Người chơi %d-%d" % [team_no, slot_no],
			"team_no": team_no,
			"slot_no": slot_no,
			"tank_key": "gangtiexia03",
			"kills": kills,
			"deaths": deaths,
			"assists": assists,
			"level": 1,
			"experience": 0,
			"experience_max": ProfileProgression.experience_max_for_level(1),
			"mvp_score": float(kills * 5 + assists * 3 - deaths * 2),
		})
	return result


func get_last_battle_result() -> Dictionary:
	return _last_battle_result.duplicate(true)


func _update_score_rule_hud() -> void:
	if not is_instance_valid(_score_rule_hud):
		return
	var is_score_race := String(
		_battle_rules.get("mode", "")
	) == GAMEPLAY_RULE_CATALOG.MODE_SCORE_RACE
	_score_rule_hud.visible = is_score_race
	if not is_score_race:
		return
	var viewer_is_left := _viewer_team_no == 1
	_score_left_side.texture = SCORE_LEFT_BLUE if viewer_is_left else SCORE_LEFT_RED
	_score_right_side.texture = SCORE_RIGHT_RED if viewer_is_left else SCORE_RIGHT_BLUE
	_score_left_label.text = str(int(_team_scores.get(1, 0)))
	_score_right_label.text = str(int(_team_scores.get(2, 0)))
	_score_limit_label.text = str(int(_battle_rules.get("score_limit", 25)))
	var duration := float(_battle_rules.get("duration_seconds", 240.0))
	var remaining_seconds := maxi(ceili(duration - _battle_elapsed_seconds), 0)
	_score_timer_label.text = "%d:%02d" % [
		floori(float(remaining_seconds) / 60.0),
		remaining_seconds % 60,
	]


func get_battle_rule_state() -> Dictionary:
	return {
		"rules": _battle_rules.duplicate(true),
		"started": _battle_rules_started,
		"finished": _battle_finished,
		"winner_team_no": _battle_winner_team_no,
		"team_scores": _team_scores.duplicate(true),
		"elapsed_seconds": _battle_elapsed_seconds,
	}


func _physics_process(delta: float) -> void:
	if not visible or not _control_enabled or _battle_chat.visible:
		_player_anchor.velocity = Vector2.ZERO
		return
	var target_direction := (
		Vector2.ZERO if not _skill_channel.is_empty() else _movement_input()
	)
	var hold_body_direction := (
		target_direction.is_zero_approx()
		and _has_opposing_movement_keys()
	)
	var previous_position := _player_anchor.position
	_player_anchor.velocity = (
		target_direction * _effective_player_move_speed()
	)
	# CharacterBody2D performs a swept move against the original terrain and
	# live building StaticBody2D shapes. move_and_slide removes only the
	# velocity component pointing into a wall: it never invents a detour.
	_player_anchor.move_and_slide()
	var clamped_position := _clamp_tank_center(_player_anchor.position)
	if not clamped_position.is_equal_approx(_player_anchor.position):
		_player_anchor.position = clamped_position
	var actual_displacement := _player_anchor.position - previous_position
	var actual_direction := Vector2.ZERO
	if actual_displacement.length_squared() > 0.0001:
		actual_direction = actual_displacement.normalized()
	var is_wall_sliding := (
		not target_direction.is_zero_approx()
		and not actual_direction.is_zero_approx()
		and actual_direction.dot(target_direction) < 0.999
	)
	# Khi xe còn dịch chuyển (kể cả đang trượt tường), thân phải theo hướng
	# dịch chuyển thật. Chỉ dùng hướng phím khi bị chặn đứng hoàn toàn; nếu
	# không còn phím nào thì dùng Vector2.ZERO: không chốt hướng mới từ dịch
	# chuyển hiệu chỉnh va chạm, còn tank tự hoàn tất hướng đã chốt trước đó.
	var actual_input_progress := actual_direction.dot(target_direction)
	var body_facing_direction := (
		Vector2.ZERO
		if target_direction.is_zero_approx()
		else (
			actual_direction
			if (
				not actual_direction.is_zero_approx()
				and actual_input_progress > 0.1
			)
			else target_direction
		)
	)
	_player_tank.call(
		"update_movement",
		actual_direction,
		delta,
		is_wall_sliding,
		hold_body_direction,
		body_facing_direction
	)
	_update_minimap_marker()
	if _camera_following:
		_camera.position = _player_anchor.position


func prepare(match_data: Dictionary) -> void:
	_cancel_camera_intro()
	_clear_movement_keys()
	_reset_firing()
	_clear_skill_runtime()
	_clear_projectiles()
	_clear_damage_numbers()
	_clear_participant_tanks()
	_clear_neutral_footpoints()
	_clear_battle_roster_ui()
	_combatants.clear()
	_reset_map_buildings()
	_battle_elapsed_seconds = 0.0
	_remaining_free_respawns = 1
	_control_enabled = false
	_camera_following = false
	_match_data = match_data.duplicate(true)
	_reset_authoritative_network()
	_server_authoritative_battle = (
		not bool(_match_data.get("is_test", false))
		and String(_match_data.get("id", "")) != "local-test"
	)
	_reset_test_mod_runtime()
	_settings_panel.configure_test_mode(_is_test_mod_authorized())
	_reset_battle_chat()
	var viewer := _viewer_participant()
	var viewer_team := int(
		viewer.get(
			"team_no",
			_match_data.get("viewer_team_no", 1)
		)
	)
	_viewer_team_no = viewer_team
	_reset_battle_rules()
	_set_map_object_viewer_team(_viewer_team_no)
	_reset_chiefs(_viewer_team_no)
	var viewer_slot := clampi(int(viewer.get("slot_no", 1)), 1, 5)
	var spawn := _spawns.get_node_or_null(
		"Team%dSlot%d" % [clampi(viewer_team, 1, 2), viewer_slot]
	) as Marker2D
	_player_anchor.position = spawn.position if spawn != null else MAP_CENTER
	var tank_key := String(viewer.get("tank_key", "gangtiexia03"))
	var skin_key := String(
		viewer.get("equipped_skin_key", "gangtiexia03_default")
	)
	var tank_data := _viewer_tank_data(viewer)
	var player_stats := _resolved_combat_stats(tank_data, viewer)
	_tank_move_speed = float(player_stats["move_speed"])
	_max_hit_points = int(player_stats["hit_points"])
	_current_hit_points = _max_hit_points
	_tank_basic_attack_damage = float(player_stats["basic_attack_damage"])
	_tank_penetration = float(player_stats["penetration"])
	_tank_physical_armor = float(player_stats["physical_armor"])
	_tank_energy_shield = float(player_stats["energy_shield"])
	_tank_fire_rate = float(player_stats["fire_rate"])
	_tank_attack_range = float(player_stats["attack_range"])
	_tank_critical_chance_percent = float(player_stats["critical_chance_percent"])
	_tank_critical_damage_percent = float(player_stats["critical_damage_percent"])
	_tank_damage_type = String(player_stats["damage_type"])
	_player_tank.call("configure", tank_key, skin_key, viewer_team)
	_player_tank.call("set_local_controlled", true)
	_player_tank.call(
		"set_player_identity",
		_viewer_display_name(viewer),
		0
	)
	_register_combatant(
		"player",
		_player_tank,
		viewer_team,
		player_stats,
		true
	)
	if tank_key == IRONMAN_TANK_KEY:
		_activate_ironman_shield()
	else:
		_clear_ironman_shield()
	_spawn_participant_tanks(viewer)
	_build_battle_roster_ui(viewer, tank_data)
	_seed_battle_join_messages()
	_register_chief_combatants()
	_register_map_building_combatants()
	_reset_skills(tank_data)
	_update_health_hud()
	_update_kda_hud()
	_update_respawn_hud()
	_update_minimap_marker()
	_camera.position = MAP_CENTER
	_camera.enabled = true
	visible = false


func reveal() -> void:
	_cancel_camera_intro()
	_control_enabled = false
	_camera_following = false
	visible = true
	_battle_rules_started = true
	if _server_authoritative_battle:
		_begin_authoritative_sync()
	_update_score_rule_hud()
	_camera.position = MAP_CENTER
	_ping_elapsed = PING_INTERVAL_SECONDS
	_request_real_ping()
	var generation := _intro_generation
	if center_hold_seconds > 0.0:
		await get_tree().create_timer(center_hold_seconds).timeout
	if generation != _intro_generation or not visible:
		return
	_camera_tween = create_tween()
	_camera_tween.set_trans(Tween.TRANS_CUBIC)
	_camera_tween.set_ease(Tween.EASE_IN_OUT)
	_camera_tween.tween_property(
		_camera,
		"position",
		_player_anchor.position,
		camera_travel_seconds
	)
	_camera_tween.tween_callback(
		_on_camera_intro_completed.bind(generation)
	)


func _on_camera_intro_completed(generation: int) -> void:
	if generation == _intro_generation and visible:
		_camera_following = true
		_control_enabled = (
			_authoritative_ready if _server_authoritative_battle else true
		)
		_camera.position = _player_anchor.position
		camera_intro_finished.emit()


func reset() -> void:
	_reset_authoritative_network()
	_cancel_camera_intro()
	_clear_movement_keys()
	_reset_firing()
	_clear_skill_runtime()
	_clear_projectiles()
	_clear_damage_numbers()
	_clear_participant_tanks()
	_clear_neutral_footpoints()
	_clear_battle_roster_ui()
	_reset_chiefs(_viewer_team_no)
	_combatants.clear()
	_battle_elapsed_seconds = 0.0
	_remaining_free_respawns = 1
	_control_enabled = false
	_camera_following = false
	_settings_panel.configure_test_mode(false)
	_reset_test_mod_runtime()
	_reset_battle_chat()
	_reset_battle_rules()
	_player_tank.call("set_local_controlled", false)
	_reset_skills()
	_update_kda_hud()
	_update_respawn_hud()
	_match_data.clear()
	_camera.position = MAP_CENTER
	_ping_elapsed = PING_INTERVAL_SECONDS
	visible = false


func _reset_authoritative_network() -> void:
	GameSession.close_battle_realtime()
	_authoritative_generation += 1
	_server_authoritative_battle = false
	_authoritative_ready = false
	_authoritative_revision = -1
	_authoritative_state_epoch = -1
	_authoritative_sequence = 0
	_authoritative_snapshot_elapsed = 0.0
	_authoritative_move_elapsed = 0.0
	_authoritative_beam_aim_elapsed = 0.0
	_authoritative_snapshot_in_flight = false
	_authoritative_command_in_flight = false
	_authoritative_command_queue.clear()
	_authoritative_last_move = Vector2(999.0, 999.0)
	_authoritative_sync_error_shown = false


func _begin_authoritative_sync() -> void:
	if not _server_authoritative_battle:
		return
	_authoritative_ready = false
	_control_enabled = false
	GameSession.open_battle_realtime()
	_authoritative_snapshot_elapsed = AUTHORITATIVE_SNAPSHOT_INTERVAL_SECONDS
	_poll_authoritative_snapshot()


func _process_authoritative_network(delta: float) -> void:
	if not _server_authoritative_battle or _battle_finished:
		return
	_authoritative_snapshot_elapsed += delta
	if (
		not GameSession.is_battle_realtime_ready()
		and
		_authoritative_snapshot_elapsed
		>= AUTHORITATIVE_SNAPSHOT_INTERVAL_SECONDS
		and not _authoritative_snapshot_in_flight
	):
		_authoritative_snapshot_elapsed = 0.0
		_poll_authoritative_snapshot()
	if not _authoritative_ready:
		return
	_authoritative_move_elapsed += delta
	if _authoritative_move_elapsed >= AUTHORITATIVE_MOVE_INTERVAL_SECONDS:
		_authoritative_move_elapsed = 0.0
		var desired_move := Vector2.ZERO
		if (
			_control_enabled
			and not _battle_chat.visible
			and not _settings_panel.is_open()
			and _skill_channel.is_empty()
		):
			desired_move = _movement_input()
		if (
			not desired_move.is_equal_approx(_authoritative_last_move)
			or not desired_move.is_zero_approx()
		):
			_authoritative_last_move = desired_move
			_enqueue_authoritative_command({
				"type": "move",
				"x": desired_move.x,
				"y": desired_move.y,
			})
	_authoritative_beam_aim_elapsed += delta
	if (
		not _skill_channel.is_empty()
		and _authoritative_beam_aim_elapsed
		>= AUTHORITATIVE_BEAM_AIM_INTERVAL_SECONDS
	):
		_authoritative_beam_aim_elapsed = 0.0
		var target := _world_mouse_position()
		_enqueue_authoritative_command({
			"type": "skill_aim",
			"target_x": target.x,
			"target_y": target.y,
		})


func _on_battle_realtime_snapshot_received(snapshot: Dictionary) -> void:
	if not _server_authoritative_battle or _battle_finished:
		return
	_apply_authoritative_snapshot(snapshot)


func _poll_authoritative_snapshot() -> void:
	if (
		not _server_authoritative_battle
		or _authoritative_snapshot_in_flight
	):
		return
	_authoritative_snapshot_in_flight = true
	var generation := _authoritative_generation
	var result: Dictionary = await GameSession.fetch_game_match_battle_snapshot()
	if generation != _authoritative_generation:
		return
	_authoritative_snapshot_in_flight = false
	if not bool(result.get("ok", false)):
		_handle_authoritative_sync_failure(result)
		return
	var snapshot_value: Variant = result.get("snapshot", {})
	if snapshot_value is Dictionary:
		_apply_authoritative_snapshot(snapshot_value)


func _enqueue_authoritative_command(command: Dictionary) -> void:
	if (
		not _server_authoritative_battle
		or not _authoritative_ready
		or _battle_finished
	):
		return
	var command_type := String(command.get("type", ""))
	if command_type in ["move", "skill_aim"]:
		for index in range(_authoritative_command_queue.size() - 1, -1, -1):
			if String(
				_authoritative_command_queue[index].get("type", "")
			) == command_type:
				_authoritative_command_queue[index] = command.duplicate(true)
				return
	if _authoritative_command_queue.size() >= 32:
		# Drop only stale continuous-input commands. Discrete attacks/skills must
		# preserve their exact order and sequence.
		for index in _authoritative_command_queue.size():
			if String(
				_authoritative_command_queue[index].get("type", "")
			) in ["move", "skill_aim"]:
				_authoritative_command_queue.remove_at(index)
				break
	_authoritative_command_queue.append(command.duplicate(true))
	_drain_authoritative_commands()


func _drain_authoritative_commands() -> void:
	if _authoritative_command_in_flight:
		return
	_authoritative_command_in_flight = true
	var generation := _authoritative_generation
	while (
		generation == _authoritative_generation
		and _server_authoritative_battle
		and not _authoritative_command_queue.is_empty()
	):
		var command: Dictionary = _authoritative_command_queue[0].duplicate(true)
		var sequence := _authoritative_sequence + 1
		var result: Dictionary = await GameSession.submit_game_match_battle_command(
			sequence,
			command
		)
		if generation != _authoritative_generation:
			return
		var accepted := false
		if bool(result.get("ok", false)):
			accepted = true
			_apply_authoritative_command_response(result)
		else:
			var error_value: Variant = result.get("error", {})
			var error_code := (
				String(error_value.get("code", ""))
				if error_value is Dictionary
				else ""
			)
			if error_code in ["NETWORK_TIMEOUT", "NETWORK_UNAVAILABLE"]:
				# The server may have committed before the HTTP response was lost.
				# Reconnect first, then retry the exact same sequence/payload only if
				# the snapshot proves it was not processed.
				var recovery: Dictionary = (
					await GameSession.fetch_game_match_battle_snapshot()
				)
				if generation != _authoritative_generation:
					return
				if bool(recovery.get("ok", false)):
					var recovery_snapshot: Variant = recovery.get("snapshot", {})
					if recovery_snapshot is Dictionary:
						_apply_authoritative_snapshot(recovery_snapshot)
					if _authoritative_sequence >= sequence:
						accepted = true
					else:
						result = (
							await GameSession.submit_game_match_battle_command(
								sequence,
								command
							)
						)
						if generation != _authoritative_generation:
							return
						accepted = bool(result.get("ok", false))
						if accepted:
							_apply_authoritative_command_response(result)
				else:
					_handle_authoritative_sync_failure(recovery)
			if not accepted:
				if error_code == "BATTLE_SEQUENCE_GAP" and error_value is Dictionary:
					_authoritative_sequence = maxi(
						0,
						int(error_value.get("expected_sequence", 1)) - 1
					)
				_rollback_predicted_authoritative_command(command)
				_poll_authoritative_snapshot()
		_authoritative_command_queue.pop_front()
	_authoritative_command_in_flight = false


func _apply_authoritative_command_response(result: Dictionary) -> void:
	var snapshot_value: Variant = result.get("snapshot", {})
	if snapshot_value is Dictionary:
		_apply_authoritative_snapshot(snapshot_value)
	_authoritative_sequence = maxi(
		_authoritative_sequence,
		int(result.get("accepted_sequence", _authoritative_sequence))
	)


func _rollback_predicted_authoritative_command(command: Dictionary) -> void:
	var command_type := String(command.get("type", ""))
	if command_type == "skill":
		_clear_skill_runtime()
		_reset_skills(_viewer_tank_data(_viewer_participant()))
	elif command_type == "basic_attack":
		_shot_cooldown_remaining = 0.0


func _handle_authoritative_sync_failure(result: Dictionary) -> void:
	_authoritative_ready = false
	_control_enabled = false
	_clear_movement_keys()
	_reset_firing()
	if _authoritative_sync_error_shown:
		return
	_authoritative_sync_error_shown = true
	var error_value: Variant = result.get("error", {})
	var message := (
		String(error_value.get("message", "Mất đồng bộ với máy chủ trận đấu."))
		if error_value is Dictionary
		else "Mất đồng bộ với máy chủ trận đấu."
	)
	push_warning("Authoritative battle sync: %s" % message)


func _apply_authoritative_snapshot(snapshot: Dictionary) -> void:
	if int(snapshot.get("protocol_version", 0)) != AUTHORITATIVE_PROTOCOL_VERSION:
		_handle_authoritative_sync_failure({
			"error": {"message": "Phiên bản protocol trận đấu không tương thích."}
		})
		return
	if String(snapshot.get("match_id", "")) != String(_match_data.get("id", "")):
		_handle_authoritative_sync_failure({
			"error": {"message": "Snapshot không thuộc trận hiện tại."}
		})
		return
	var state_epoch := int(snapshot.get("state_epoch", 0))
	if state_epoch < _authoritative_state_epoch:
		return
	if state_epoch > _authoritative_state_epoch:
		# A new fenced match worker may have recovered the last durable checkpoint.
		# Accept its lower revision and rewind only continuous input sequences; all
		# discrete actions were checkpointed before the old worker acknowledged them.
		_authoritative_state_epoch = state_epoch
		_authoritative_revision = -1
		_authoritative_sequence = maxi(
			0,
			int(snapshot.get("last_processed_sequence", 0))
		)
	else:
		_authoritative_sequence = maxi(
			_authoritative_sequence,
			int(snapshot.get("last_processed_sequence", 0))
		)
	var revision := int(snapshot.get("revision", -1))
	if revision < _authoritative_revision:
		return
	_authoritative_revision = revision
	_authoritative_ready = true
	_authoritative_sync_error_shown = false
	_team_scores = {
		1: int(snapshot.get("team_1_score", 0)),
		2: int(snapshot.get("team_2_score", 0)),
	}
	_battle_elapsed_seconds = maxf(
		float(snapshot.get("elapsed_ms", 0)) / 1000.0,
		0.0
	)
	var viewer_team := int(snapshot.get("viewer_team_no", _viewer_team_no))
	var viewer_slot := int(snapshot.get("viewer_slot_no", 1))
	var entities_value: Variant = snapshot.get("entities", [])
	var world_entities_value: Variant = snapshot.get("world_entities")
	if entities_value is not Array or world_entities_value is not Array:
		_handle_authoritative_sync_failure({
			"error": {"message": "Snapshot trận đấu thiếu danh sách thực thể."}
		})
		return
	if not _authoritative_world_snapshot_is_complete(world_entities_value):
		_handle_authoritative_sync_failure({
			"error": {"message": "Snapshot world entity thiếu, trùng hoặc không thuộc map."}
		})
		return
	for entity_value: Variant in entities_value:
		if entity_value is not Dictionary:
			continue
		var entity: Dictionary = entity_value
		var team_no := int(entity.get("team_no", 0))
		var slot_no := int(entity.get("slot_no", 0))
		var combatant_key := (
			"player"
			if team_no == viewer_team and slot_no == viewer_slot
			else "participant:%d:%d" % [team_no, slot_no]
		)
		_apply_authoritative_entity(combatant_key, entity)
	_apply_authoritative_world_snapshot(world_entities_value)
	_update_score_rule_hud()
	_update_health_hud()
	_update_kda_hud()
	_update_respawn_hud()
	_update_battle_roster_ui()
	_update_minimap_marker()
	var player: Dictionary = _combatants.get("player", {})
	_control_enabled = (
		_camera_following
		and not bool(player.get("dead", false))
		and not _battle_finished
	)
	var result_value: Variant = snapshot.get("result")
	if result_value is Dictionary and not _battle_finished:
		_finish_battle(
			int(result_value.get("winner_team_no", 0)),
			String(result_value.get("finish_reason", "server_result"))
		)


func _authoritative_world_snapshot_is_complete(world_entities: Array) -> bool:
	var expected: Dictionary = {}
	for building_id_value: Variant in _map_building_instances.keys():
		expected["building:%d" % int(building_id_value)] = "building"
	for team_no in [1, 2]:
		expected["chief:%d" % team_no] = "chief"
	for building_id in FOOTPOINT_TRIGGER_BUILDING_IDS:
		expected["footpoint:%d" % building_id] = "footpoint"
	if world_entities.size() != expected.size():
		return false
	var seen: Dictionary = {}
	for entity_value: Variant in world_entities:
		if entity_value is not Dictionary:
			return false
		var entity: Dictionary = entity_value
		var entity_key := String(entity.get("entity_key", ""))
		var entity_type := String(entity.get("entity_type", ""))
		if (
			not expected.has(entity_key)
			or String(expected[entity_key]) != entity_type
			or seen.has(entity_key)
		):
			return false
		seen[entity_key] = true
	return seen.size() == expected.size()


func _apply_authoritative_entity(
	combatant_key: String,
	entity: Dictionary
) -> void:
	if not _combatants.has(combatant_key):
		return
	var combatant: Dictionary = _combatants[combatant_key]
	var tank := combatant.get("tank") as Node2D
	var server_position := Vector2(
		float(entity.get("position_x", 0.0)),
		float(entity.get("position_y", 0.0))
	)
	if combatant_key == "player":
		var correction_distance := _player_anchor.position.distance_to(server_position)
		_player_anchor.position = (
			server_position
			if correction_distance > 96.0
			else _player_anchor.position.lerp(server_position, 0.35)
		)
	elif is_instance_valid(tank):
		tank.global_position = tank.global_position.lerp(server_position, 0.5)
	var was_dead := bool(combatant.get("dead", false))
	var dead := bool(entity.get("dead", false))
	combatant["hit_points"] = int(entity.get("hit_points", 0))
	combatant["maximum_health"] = maxi(
		int(entity.get("maximum_hit_points", 1)),
		1
	)
	combatant["dead"] = dead
	combatant["respawn_remaining"] = (
		float(entity.get("respawn_remaining_ms", 0)) / 1000.0
	)
	combatant["respawn_invulnerability_remaining"] = (
		float(entity.get("invulnerable_remaining_ms", 0)) / 1000.0
	)
	combatant["kills"] = int(entity.get("kills", 0))
	combatant["deaths"] = int(entity.get("deaths", 0))
	combatant["assists"] = int(entity.get("assists", 0))
	combatant["battle_kit_key"] = String(entity.get("battle_kit_key", ""))
	for reward_key in [
		"experience_reward",
		"silver_reward",
		"level_after",
		"experience_after",
		"silver_after",
	]:
		if entity.has(reward_key):
			combatant[reward_key] = int(entity[reward_key])
	_combatants[combatant_key] = combatant
	if dead and not was_dead:
		_play_combatant_death_effect(combatant_key)
	elif was_dead and not dead and bool(combatant.get("is_chief", false)):
		if is_instance_valid(tank) and tank.has_method("on_respawn"):
			tank.call("on_respawn")
	if is_instance_valid(tank):
		tank.visible = not dead
		tank.call(
			"set_health",
			int(combatant["hit_points"]),
			int(combatant["maximum_health"])
		)
	if combatant_key != "player":
		return
	_current_hit_points = int(combatant["hit_points"])
	_max_hit_points = int(combatant["maximum_health"])
	_remaining_free_respawns = int(
		entity.get("free_respawns_remaining", 0)
	)
	_shot_cooldown_remaining = (
		float(entity.get("basic_attack_cooldown_ms", 0)) / 1000.0
	)
	var cooldowns_value: Variant = entity.get("skill_cooldowns_ms", {})
	if cooldowns_value is Dictionary:
		var skill_slots: Array[Control] = [_skill_1, _skill_2, _skill_3]
		for slot_index in skill_slots.size():
			if slot_index == 2 and not _skill_channel.is_empty():
				continue
			skill_slots[slot_index].call(
				"sync_cooldown_remaining",
				float(cooldowns_value.get(str(slot_index + 1), 0)) / 1000.0
			)
	var previous_shield_points := _ironman_shield_points
	var shield_points := int(entity.get("shield_points", 0))
	if shield_points <= 0:
		if previous_shield_points > 0:
			# The server owns the retaliation damage. This call only plays the
			# original shield-break timeline because _deal_damage is authority-locked.
			_break_ironman_shield()
		else:
			_clear_ironman_shield()
	else:
		if not is_instance_valid(_ironman_shield_effect):
			_activate_ironman_shield()
		_ironman_shield_points = shield_points


func _apply_authoritative_world_snapshot(world_entities: Array) -> void:
	var attack_visuals: Array[Dictionary] = []
	for entity_value: Variant in world_entities:
		if entity_value is not Dictionary:
			continue
		var entity: Dictionary = entity_value
		var entity_type := String(entity.get("entity_type", ""))
		match entity_type:
			"building":
				_apply_authoritative_building_entity(entity, attack_visuals)
			"chief":
				_apply_authoritative_chief_entity(entity, attack_visuals)
			"footpoint":
				_apply_authoritative_footpoint_entity(entity)
			_:
				_handle_authoritative_sync_failure({
					"error": {"message": "Snapshot có loại world entity không hỗ trợ."}
				})
				return
	for visual: Dictionary in attack_visuals:
		_play_authoritative_world_attack(visual)


func _apply_authoritative_building_entity(
	entity: Dictionary,
	attack_visuals: Array[Dictionary]
) -> void:
	var entity_key := String(entity.get("entity_key", ""))
	if not entity_key.begins_with("building:"):
		return
	var building_id := int(entity_key.trim_prefix("building:"))
	var building := _map_building_instances.get(building_id) as Node2D
	if not is_instance_valid(building) or not _combatants.has(entity_key):
		return
	var combatant: Dictionary = _combatants[entity_key]
	var was_dead := bool(combatant.get("dead", false))
	var dead := bool(entity.get("dead", false))
	var hit_points := int(entity.get("hit_points", 0))
	building.call("set_authoritative_health", hit_points)
	combatant["hit_points"] = hit_points
	combatant["maximum_health"] = maxi(
		int(entity.get("maximum_hit_points", 1)),
		1
	)
	combatant["dead"] = dead
	var previous_serial := int(combatant.get("world_attack_serial", 0))
	var attack_serial := int(entity.get("attack_serial", 0))
	combatant["world_attack_serial"] = attack_serial
	_combatants[entity_key] = combatant
	if dead:
		_building_collision_rectangles.erase(building_id)
		if not was_dead:
			_on_map_building_destroyed(building_id)
	else:
		building.visible = true
	if attack_serial > previous_serial and not dead:
		attack_visuals.append({
			"source_key": entity_key,
			"target_key": String(entity.get("last_target_key", "")),
			"kind": "turret",
		})


func _apply_authoritative_chief_entity(
	entity: Dictionary,
	attack_visuals: Array[Dictionary]
) -> void:
	var entity_key := String(entity.get("entity_key", ""))
	if not _combatants.has(entity_key):
		return
	var combatant: Dictionary = _combatants[entity_key]
	var previous_serial := int(combatant.get("world_attack_serial", 0))
	var attack_serial := int(entity.get("attack_serial", 0))
	_apply_authoritative_entity(entity_key, entity)
	combatant = _combatants[entity_key]
	combatant["world_attack_serial"] = attack_serial
	combatant["respawn_remaining"] = (
		float(entity.get("respawn_remaining_ms", 0)) / 1000.0
	)
	_combatants[entity_key] = combatant
	if attack_serial > previous_serial and not bool(entity.get("dead", false)):
		attack_visuals.append({
			"source_key": entity_key,
			"target_key": String(entity.get("last_target_key", "")),
			"kind": "chief",
		})


func _apply_authoritative_footpoint_entity(entity: Dictionary) -> void:
	var entity_key := String(entity.get("entity_key", ""))
	if not bool(entity.get("activated", false)):
		_remove_authoritative_footpoint(entity_key, false)
		return
	if bool(entity.get("dead", false)):
		_remove_authoritative_footpoint(entity_key, true)
		return
	if not _combatants.has(entity_key):
		_spawn_authoritative_footpoint(entity)
	if not _combatants.has(entity_key):
		return
	var combatant: Dictionary = _combatants[entity_key]
	var footpoint := combatant.get("tank") as Node2D
	if not is_instance_valid(footpoint):
		_combatants.erase(entity_key)
		return
	var server_position := Vector2(
		float(entity.get("position_x", 0.0)),
		float(entity.get("position_y", 0.0))
	)
	var motion := server_position - footpoint.global_position
	footpoint.global_position = (
		server_position
		if motion.length() > 96.0
		else footpoint.global_position.lerp(server_position, 0.5)
	)
	footpoint.call(
		"update_movement",
		Vector2.ZERO if motion.is_zero_approx() else motion.normalized(),
		AUTHORITATIVE_SNAPSHOT_INTERVAL_SECONDS
	)
	var hit_points := int(entity.get("hit_points", 0))
	var maximum_hit_points := maxi(
		int(entity.get("maximum_hit_points", FOOTPOINT_HIT_POINTS)),
		1
	)
	footpoint.call("set_health", hit_points, maximum_hit_points)
	combatant["hit_points"] = hit_points
	combatant["maximum_health"] = maximum_hit_points
	combatant["dead"] = false
	_combatants[entity_key] = combatant


func _spawn_authoritative_footpoint(entity: Dictionary) -> void:
	if _neutral_footpoints == null:
		return
	var entity_key := String(entity.get("entity_key", ""))
	var building_id := int(entity.get("spawner_building_id", 0))
	if entity_key.is_empty() or building_id <= 0:
		return
	var footpoint := FOOTPOINT_SCENE.instantiate() as Node2D
	if footpoint == null:
		return
	footpoint.name = "AuthoritativeFootpoint%d" % building_id
	footpoint.position = Vector2(
		float(entity.get("position_x", 0.0)),
		float(entity.get("position_y", 0.0))
	)
	_neutral_footpoints.add_child(footpoint)
	footpoint.call("configure", building_id)
	_combatants[entity_key] = {
		"tank": footpoint,
		"team_no": 0,
		"spawn_position": footpoint.global_position,
		"hit_points": int(entity.get("hit_points", FOOTPOINT_HIT_POINTS)),
		"maximum_health": maxi(
			int(entity.get("maximum_hit_points", FOOTPOINT_HIT_POINTS)),
			1
		),
		"basic_attack_damage": FOOTPOINT_ATTACK,
		"penetration": FOOTPOINT_PENETRATION,
		"physical_armor": FOOTPOINT_ARMOR,
		"energy_shield": FOOTPOINT_ARMOR,
		"move_speed": FOOTPOINT_MOVE_SPEED,
		"attack_range": FOOTPOINT_ALERT_RANGE,
		"hit_radius": FOOTPOINT_HIT_RADIUS,
		"is_player": false,
		"is_bot": false,
		"is_map_object": false,
		"is_structure": false,
		"is_chief": false,
		"is_neutral_footpoint": true,
		"footpoint_spawner_id": building_id,
		"dead": false,
		"damage_contributors": {},
	}
	_footpoint_spawners[building_id] = {
		"enabled": true,
		"spawn_position": Vector2(
			float(entity.get("position_x", 0.0)),
			float(entity.get("position_y", 0.0))
		),
		"active_key": entity_key,
		"respawn_remaining": 0.0,
		"birth_remaining": (
			float(entity.get("active_remaining_ms", 0)) / 1000.0
		),
	}
	var birth_effect := _play_footpoint_template_effect(
		_footpoint_birth_template,
		footpoint.global_position
	)
	birth_effect.z_as_relative = false
	birth_effect.z_index = 8


func _remove_authoritative_footpoint(
	entity_key: String,
	play_death_effect: bool
) -> void:
	if not _combatants.has(entity_key):
		return
	var combatant: Dictionary = _combatants[entity_key]
	var footpoint := combatant.get("tank") as Node2D
	var position_value := (
		footpoint.global_position
		if is_instance_valid(footpoint)
		else Vector2.ZERO
	)
	if play_death_effect:
		var blow_effect := _play_footpoint_template_effect(
			_footpoint_blow_template,
			position_value
		)
		blow_effect.z_as_relative = false
		blow_effect.z_index = 8
		var death_effect := _play_footpoint_template_effect(
			_footpoint_death_template,
			position_value
		)
		death_effect.z_as_relative = false
		death_effect.z_index = 9
	if is_instance_valid(footpoint):
		footpoint.queue_free()
	var building_id := int(combatant.get("footpoint_spawner_id", 0))
	if _footpoint_spawners.has(building_id):
		var spawner: Dictionary = _footpoint_spawners[building_id]
		spawner["active_key"] = ""
		_footpoint_spawners[building_id] = spawner
	_combatants.erase(entity_key)


func _local_key_from_authoritative_entity_key(entity_key: String) -> String:
	if not entity_key.begins_with("participant:"):
		return entity_key
	var parts := entity_key.split(":")
	if parts.size() != 3:
		return entity_key
	var team_no := int(parts[1])
	var slot_no := int(parts[2])
	var viewer := _viewer_participant()
	if (
		team_no == int(viewer.get("team_no", _viewer_team_no))
		and slot_no == int(viewer.get("slot_no", 1))
	):
		return "player"
	return entity_key


func _play_authoritative_world_attack(visual: Dictionary) -> void:
	var source_key := String(visual.get("source_key", ""))
	var target_key := _local_key_from_authoritative_entity_key(
		String(visual.get("target_key", ""))
	)
	if (
		not _combatants.has(source_key)
		or not _combatants.has(target_key)
	):
		return
	var source: Dictionary = _combatants[source_key]
	match String(visual.get("kind", "")):
		"turret":
			_fire_turret(source_key, target_key, source)
		"chief":
			_fire_chief(source_key, target_key, source)


func _cancel_camera_intro() -> void:
	_intro_generation = _intro_generation + 1
	if _camera_tween != null and _camera_tween.is_valid():
		_camera_tween.kill()
	_camera_tween = null


func _movement_input() -> Vector2:
	return _movement_input_state.movement_input()


func _set_movement_key(keycode: int, pressed: bool) -> void:
	_movement_input_state.set_key(keycode, pressed)


func _has_opposing_movement_keys() -> bool:
	return _movement_input_state.has_opposing_keys()


func _load_map_layout() -> void:
	_static_collision_rectangles.clear()
	_map_layout.clear()
	_load_building_collision_overrides()
	var file := FileAccess.open(MAP_LAYOUT_PATH, FileAccess.READ)
	if file == null:
		push_warning("Không mở được dữ liệu map: %s" % MAP_LAYOUT_PATH)
		return
	var parsed_value: Variant = JSON.parse_string(file.get_as_text())
	if parsed_value is not Dictionary:
		push_warning("Dữ liệu map không phải Dictionary: %s" % MAP_LAYOUT_PATH)
		return
	var layout: Dictionary = parsed_value
	_map_layout = layout.duplicate(true)
	_battle_rules = GAMEPLAY_RULE_CATALOG.resolve(_map_layout)
	_validate_map_size(layout)
	_apply_original_spawns(layout)
	var rectangles_value: Variant = layout.get(
		"static_collision_rectangles",
		[]
	)
	if rectangles_value is not Array:
		push_warning("Map không có danh sách static_collision_rectangles hợp lệ.")
		return
	for rectangle_value: Variant in rectangles_value:
		if rectangle_value is not Dictionary:
			continue
		var rectangle: Dictionary = rectangle_value
		var collision_rectangle := Rect2(
			float(rectangle.get("x", 0.0)),
			float(rectangle.get("y", 0.0)),
			float(rectangle.get("width", 0.0)),
			float(rectangle.get("height", 0.0))
		)
		if collision_rectangle.size.x <= 0.0:
			continue
		if collision_rectangle.size.y <= 0.0:
			continue
		_static_collision_rectangles.append(collision_rectangle)
	var scene_collision_rectangles := _scene_terrain_collision_rectangles()
	if not scene_collision_rectangles.is_empty():
		# Once the designer has generated/saved drag-editable CollisionShape2D
		# nodes in PvpBattleMap.tscn, those shapes become the single source for
		# tank movement and every projectile terrain test.
		_static_collision_rectangles = scene_collision_rectangles


func _validate_map_size(layout: Dictionary) -> void:
	var header_value: Variant = layout.get("header", {})
	if header_value is not Dictionary:
		return
	var header: Dictionary = header_value
	var layout_size := Vector2(
		float(header.get("width", 0.0)),
		float(header.get("height", 0.0))
	)
	if not layout_size.is_equal_approx(MAP_SIZE):
		push_warning(
			"Kích thước dữ liệu map %s khác MAP_SIZE %s."
			% [layout_size, MAP_SIZE]
		)


func _apply_original_spawns(layout: Dictionary) -> void:
	var spawns_value: Variant = layout.get("team_spawns", [])
	if spawns_value is not Array:
		return
	for spawn_value: Variant in spawns_value:
		if spawn_value is not Dictionary:
			continue
		var spawn_data: Dictionary = spawn_value
		var team_no := int(spawn_data.get("team", 0))
		var slot_no := int(spawn_data.get("slot", 0))
		if team_no < 1 or team_no > 2:
			continue
		if slot_no < 1 or slot_no > 5:
			continue
		var marker := _spawns.get_node_or_null(
			"Team%dSlot%d" % [team_no, slot_no]
		) as Marker2D
		if marker == null:
			continue
		marker.position = Vector2(
			float(spawn_data.get("x", marker.position.x)),
			float(spawn_data.get("y", marker.position.y))
		)


func _build_terrain_collision() -> void:
	if not _scene_terrain_collision_rectangles().is_empty():
		# Persistent editor-authored CollisionShape2D nodes already provide the
		# collision body; never replace them with temporary JSON-generated nodes.
		return
	for child: Node in _terrain_collision.get_children():
		child.queue_free()
	for collision_rectangle: Rect2 in _static_collision_rectangles:
		var shape := RectangleShape2D.new()
		shape.size = collision_rectangle.size
		var collision_shape := CollisionShape2D.new()
		collision_shape.position = (
			collision_rectangle.position
			+ collision_rectangle.size * 0.5
		)
		collision_shape.shape = shape
		_terrain_collision.add_child(collision_shape)


func _scene_terrain_collision_rectangles() -> Array[Rect2]:
	var rectangles: Array[Rect2] = []
	if _terrain_collision == null:
		return rectangles
	for child: Node in _terrain_collision.get_children():
		var collision_shape := child as CollisionShape2D
		if collision_shape == null:
			continue
		var rectangle_shape := collision_shape.shape as RectangleShape2D
		if rectangle_shape == null:
			continue
		var size := rectangle_shape.size * collision_shape.scale.abs()
		if size.x <= 0.0 or size.y <= 0.0:
			continue
		rectangles.append(Rect2(collision_shape.position - size * 0.5, size))
	return rectangles


func _spawn_map_buildings() -> void:
	_clear_map_buildings()
	if _map_layout.is_empty() or _map_buildings == null:
		return
	var occupancy_by_id := _map_npc_occupancy_by_id(_map_layout)
	var placements_value: Variant = _map_layout.get("npc_placements", [])
	var authored_data := _authored_map_object_data()
	if not authored_data.is_empty():
		placements_value = authored_data.get("placements", [])
		occupancy_by_id = authored_data.get("occupancy_by_id", {})
	if placements_value is not Array:
		return
	for placement_value: Variant in placements_value:
		if placement_value is not Dictionary:
			continue
		var placement: Dictionary = placement_value
		var building_id := int(placement.get("unique_id", 0))
		var template_id := int(placement.get("template_id", 0))
		if building_id <= 0:
			continue
		var template := BUILDING_CATALOG.get_template(template_id)
		if template.is_empty():
			push_warning(
				"Chua co dinh nghia cong trinh mau %d (id dat %d)."
				% [template_id, building_id]
			)
			continue
		var rectangles: Array[Rect2] = occupancy_by_id.get(building_id, [])
		var building := BATTLE_BUILDING_SCENE.instantiate() as Node2D
		if building == null:
			continue
		_map_buildings.add_child(building)
		building.call("configure", placement, template, rectangles)
		building.call("set_viewer_team", _viewer_team_no)
		building.connect("destroyed", _on_map_building_destroyed)
		_map_building_instances[building_id] = building
		_building_collision_rectangles[building_id] = rectangles
		_initial_building_collision_rectangles[building_id] = rectangles.duplicate()


func _clear_map_buildings() -> void:
	_building_collision_rectangles.clear()
	_initial_building_collision_rectangles.clear()
	_map_building_instances.clear()
	if _map_buildings == null:
		return
	for building: Node in _map_buildings.get_children():
		_map_buildings.remove_child(building)
		building.queue_free()


func _reset_map_buildings() -> void:
	for building_value: Variant in _map_building_instances.values():
		var building := building_value as Node2D
		if not is_instance_valid(building):
			continue
		building.call("reset_for_match")
		building.call("set_viewer_team", _viewer_team_no)
		var building_id := int(building.call("get_building_id"))
		var rectangles_value: Variant = _initial_building_collision_rectangles.get(
			building_id,
			[]
		)
		_building_collision_rectangles[building_id] = (
			(rectangles_value as Array).duplicate()
			if rectangles_value is Array
			else []
		)


func _authored_map_object_data() -> Dictionary:
	if _editor_map_objects == null or _editor_map_objects.get_child_count() <= 0:
		return {}
	var source_by_id: Dictionary = {}
	var source_placements_value: Variant = _map_layout.get("npc_placements", [])
	if source_placements_value is Array:
		for source_value: Variant in source_placements_value:
			if source_value is not Dictionary:
				continue
			var source: Dictionary = source_value
			source_by_id[int(source.get("unique_id", 0))] = source
	var placements: Array[Dictionary] = []
	var occupancy_by_id: Dictionary = {}
	var used_ids: Dictionary = {}
	for child: Node in _editor_map_objects.get_children():
		if not child.has_method("get_world_collision_rectangles"):
			continue
		var building_id := int(child.get("unique_id"))
		var template_id := int(child.get("template_id"))
		if building_id <= 0 or template_id <= 0:
			push_warning("Bo qua map object co unique_id/template_id khong hop le: %s" % child.name)
			continue
		if used_ids.has(building_id):
			push_warning("Bo qua map object trung unique_id %d: %s" % [building_id, child.name])
			continue
		used_ids[building_id] = true
		var source_id := int(child.get("source_unique_id"))
		if source_id <= 0:
			source_id = building_id
		var placement: Dictionary = {}
		var source_value: Variant = source_by_id.get(source_id, {})
		if source_value is Dictionary:
			placement = (source_value as Dictionary).duplicate(true)
		placement["unique_id"] = building_id
		placement["template_id"] = template_id
		placement["camp"] = int(child.get("team_no"))
		placement["x"] = (child as Node2D).position.x
		placement["y"] = (child as Node2D).position.y
		placements.append(placement)
		var rectangles_value: Variant = child.call("get_world_collision_rectangles")
		occupancy_by_id[building_id] = (
			(rectangles_value as Array).duplicate()
			if rectangles_value is Array
			else []
		)
	return {
		"placements": placements,
		"occupancy_by_id": occupancy_by_id,
	}


func _set_map_object_viewer_team(viewer_team_no: int) -> void:
	for building_value: Variant in _map_building_instances.values():
		var building := building_value as Node2D
		if is_instance_valid(building):
			building.call("set_viewer_team", viewer_team_no)


func _register_map_building_combatants() -> void:
	for building_value: Variant in _map_building_instances.values():
		var building := building_value as Node2D
		if not is_instance_valid(building):
			continue
		var building_id := int(building.call("get_building_id"))
		var template_id := int(building.call("get_template_id"))
		var template := BUILDING_CATALOG.get_template(template_id)
		if building_id <= 0 or template.is_empty():
			continue
		var maximum_health := maxi(int(building.call("get_maximum_hit_points")), 1)
		var is_structure := bool(building.call("is_structure"))
		_combatants["building:%d" % building_id] = {
			"tank": building,
			"team_no": int(building.call("get_team_no")),
			"hit_points": maximum_health,
			"maximum_health": maximum_health,
			"basic_attack_damage": float(template.get("physical_attack", 0)),
			"penetration": 0.0,
			"physical_armor": float(template.get("armor", 0)),
			"energy_shield": float(template.get("armor", 0)),
			"move_speed": 0.0,
			"fire_rate": 0.0,
			"attack_range": float(template.get("alert_range", 0)),
			"attack_interval_seconds": maxf(
				float(template.get("attack_interval_ms", 1000)) / 1000.0,
				0.05
			),
			"turret_shot_cooldown": 0.0,
			"can_attack": bool(template.get("can_attack", false)),
			"building_kind": String(template.get("kind", "")),
			"critical_chance_percent": 0.0,
			"critical_damage_percent": 100.0,
			"damage_type": DAMAGE_TYPE_PHYSICAL,
			"is_player": false,
			"is_bot": false,
			"is_map_object": true,
			"is_structure": is_structure,
			"hit_rectangles": _building_collision_rectangles.get(
				building_id,
				[]
			),
			"dead": false,
			"damage_contributors": {},
		}


func _map_npc_occupancy_by_id(layout: Dictionary) -> Dictionary:
	var occupancy_by_id: Dictionary = {}
	var occupancy_value: Variant = layout.get("npc_occupancy", [])
	if occupancy_value is not Array:
		return occupancy_by_id
	for occupancy_entry_value: Variant in occupancy_value:
		if occupancy_entry_value is not Dictionary:
			continue
		var occupancy_entry: Dictionary = occupancy_entry_value
		var building_id := int(occupancy_entry.get("unique_id", 0))
		if building_id <= 0:
			continue
		var rectangles: Array[Rect2] = []
		var rectangles_value: Variant = occupancy_entry.get("rectangles", [])
		if rectangles_value is Array:
			for rectangle_value: Variant in rectangles_value:
				if rectangle_value is not Dictionary:
					continue
				var rectangle_data: Dictionary = rectangle_value
				var rectangle := Rect2(
					float(rectangle_data.get("x", 0.0)),
					float(rectangle_data.get("y", 0.0)),
					float(rectangle_data.get("width", 0.0)),
					float(rectangle_data.get("height", 0.0))
				)
				if rectangle.size.x > 0.0 and rectangle.size.y > 0.0:
					rectangles.append(rectangle)
		var override_value: Variant = null
		var override_container: Variant = _building_collision_overrides
		if override_container is Dictionary:
			var overrides: Dictionary = override_container
			override_value = overrides.get(str(building_id), null)
		if override_value is Array:
			var override_rectangles := _rectangles_from_override(override_value)
			if not override_rectangles.is_empty():
				rectangles = override_rectangles
		occupancy_by_id[building_id] = rectangles
	return occupancy_by_id


func _load_building_collision_overrides() -> void:
	_building_collision_overrides = {}
	var file := FileAccess.open(MAP_BUILDING_COLLISION_OVERRIDE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed_value: Variant = JSON.parse_string(file.get_as_text())
	if parsed_value is not Dictionary:
		push_warning("Building collision override JSON is invalid.")
		return
	var document: Dictionary = parsed_value
	var overrides_value: Variant = document.get("buildings", {})
	if overrides_value is Dictionary:
		_building_collision_overrides = (overrides_value as Dictionary).duplicate(true)


func _rectangles_from_override(value: Array) -> Array[Rect2]:
	var rectangles: Array[Rect2] = []
	for rectangle_value: Variant in value:
		if rectangle_value is not Dictionary:
			continue
		var rectangle_data: Dictionary = rectangle_value
		var rectangle := Rect2(
			float(rectangle_data.get("x", 0.0)),
			float(rectangle_data.get("y", 0.0)),
			float(rectangle_data.get("width", 0.0)),
			float(rectangle_data.get("height", 0.0))
		)
		if rectangle.size.x > 0.0 and rectangle.size.y > 0.0:
			rectangles.append(rectangle)
	return rectangles


func _on_map_building_destroyed(building_id: int) -> void:
	_building_collision_rectangles.erase(building_id)
	var building := _map_building_instances.get(building_id) as Node2D
	if not is_instance_valid(building):
		return
	if (
		not _server_authoritative_battle
		and
		building_id in FOOTPOINT_TRIGGER_BUILDING_IDS
		and int(building.call("get_template_id")) == 2006
	):
		_activate_footpoint_spawner(building_id, building.global_position)
	if not bool(building.call("should_hide_when_destroyed")):
		return
	var destruction_timeline := String(
		building.call("get_destruction_timeline_path")
	)
	if not destruction_timeline.is_empty():
		_play_timeline_effect(destruction_timeline, building.global_position)
	# Source break4 is only the final debris sprite. The source destruction
	# SWF plays at this position; hide the static node so debris cannot remain
	# forever and no further shot can show damage after it has broken.
	building.visible = false


func _activate_footpoint_spawner(
	building_id: int,
	spawn_position: Vector2
) -> void:
	if _footpoint_spawners.has(building_id):
		return
	_footpoint_spawners[building_id] = {
		"enabled": true,
		"spawn_position": FOOTPOINT_SPAWN_POINTS.get(
			building_id,
			spawn_position
		),
		"active_key": "",
		"respawn_remaining": 0.0,
		"birth_remaining": 0.0,
	}
	_spawn_footpoint(building_id)


func _spawn_footpoint(building_id: int) -> void:
	if not _footpoint_spawners.has(building_id) or _neutral_footpoints == null:
		return
	var spawner: Dictionary = _footpoint_spawners[building_id]
	if not String(spawner.get("active_key", "")).is_empty():
		return
	var footpoint := FOOTPOINT_SCENE.instantiate() as Node2D
	if footpoint == null:
		return
	_footpoint_generation += 1
	var combatant_key := "footpoint:%d:%d" % [
		building_id,
		_footpoint_generation,
	]
	footpoint.name = "FootpointFromCrate%d" % building_id
	footpoint.position = spawner.get(
		"spawn_position",
		FOOTPOINT_SPAWN_POINTS.get(building_id, MAP_CENTER)
	)
	_neutral_footpoints.add_child(footpoint)
	footpoint.call("configure", building_id)
	_combatants[combatant_key] = {
		"tank": footpoint,
		"team_no": 0,
		"spawn_position": footpoint.global_position,
		"hit_points": FOOTPOINT_HIT_POINTS,
		"maximum_health": FOOTPOINT_HIT_POINTS,
		"basic_attack_damage": FOOTPOINT_ATTACK,
		"penetration": FOOTPOINT_PENETRATION,
		"physical_armor": FOOTPOINT_ARMOR,
		"energy_shield": FOOTPOINT_ARMOR,
		"move_speed": FOOTPOINT_MOVE_SPEED,
		"attack_range": FOOTPOINT_ALERT_RANGE,
		"critical_chance_percent": 0.0,
		"critical_damage_percent": 100.0,
		"damage_type": DAMAGE_TYPE_PHYSICAL,
		"hit_radius": FOOTPOINT_HIT_RADIUS,
		"is_player": false,
		"is_bot": false,
		"is_map_object": false,
		"is_structure": false,
		"is_chief": false,
		"is_neutral_footpoint": true,
		"footpoint_spawner_id": building_id,
		"dead": false,
		"damage_contributors": {},
		"slow_remaining": 0.0,
		"slow_value": 0.0,
		"slow_tick_remaining": 0.0,
		"slow_recovery": 0.0,
		"e_slow_remaining": 0.0,
		"stun_remaining": 0.0,
	}
	spawner["active_key"] = combatant_key
	spawner["respawn_remaining"] = 0.0
	spawner["birth_remaining"] = FOOTPOINT_BIRTH_SECONDS
	_footpoint_spawners[building_id] = spawner
	var birth_effect := _play_footpoint_template_effect(
		_footpoint_birth_template,
		footpoint.global_position
	)
	birth_effect.z_as_relative = false
	birth_effect.z_index = 8


func _process_neutral_footpoint_ai(delta: float) -> void:
	if _server_authoritative_battle:
		return
	for building_id_value: Variant in _footpoint_spawners.keys():
		var building_id := int(building_id_value)
		var spawner: Dictionary = _footpoint_spawners[building_id]
		var combatant_key := String(spawner.get("active_key", ""))
		if combatant_key.is_empty():
			var respawn_remaining := maxf(
				float(spawner.get("respawn_remaining", 0.0)) - delta,
				0.0
			)
			spawner["respawn_remaining"] = respawn_remaining
			_footpoint_spawners[building_id] = spawner
			if respawn_remaining <= 0.0:
				_spawn_footpoint(building_id)
			continue
		if not _combatants.has(combatant_key):
			spawner["active_key"] = ""
			spawner["respawn_remaining"] = FOOTPOINT_RESPAWN_SECONDS
			_footpoint_spawners[building_id] = spawner
			continue
		var combatant: Dictionary = _combatants[combatant_key]
		var footpoint := combatant.get("tank") as Node2D
		if not is_instance_valid(footpoint) or bool(combatant.get("dead", false)):
			continue
		var birth_remaining := maxf(
			float(spawner.get("birth_remaining", 0.0)) - delta,
			0.0
		)
		spawner["birth_remaining"] = birth_remaining
		_footpoint_spawners[building_id] = spawner
		if birth_remaining > 0.0:
			footpoint.call("update_movement", Vector2.ZERO, delta)
			continue
		var target_key := _nearest_player_tank_for_footpoint(
			footpoint.global_position
		)
		var movement_direction := Vector2.ZERO
		if float(combatant.get("stun_remaining", 0.0)) <= 0.0:
			if target_key.is_empty():
				movement_direction = footpoint.call(
					"get_wander_direction",
					FOOTPOINT_ROAM_RECT,
					delta
				)
			else:
				var to_target := (
					_combatant_position(target_key)
					- footpoint.global_position
				)
				if not to_target.is_zero_approx():
					movement_direction = to_target.normalized()
		var move_speed := FOOTPOINT_MOVE_SPEED * (
			1.0 - clampf(float(combatant.get("slow_value", 0.0)), 0.0, 1.0)
		)
		# The XML hit radius is centred on the Footpoint sprite itself. The shared
		# tank slide helper expects the player's +12Y body-centre offset, so feed
		# it an inverse-shifted proxy anchor. Clamp the source hole position into
		# the roam rectangle first: hole #47 begins 12px inside the lower static
		# wall and otherwise the generic safe-fraction solver cannot escape an
		# already-overlapping start.
		footpoint.global_position = Vector2(
			clampf(
				footpoint.global_position.x,
				FOOTPOINT_ROAM_RECT.position.x,
				FOOTPOINT_ROAM_RECT.end.x
			),
			clampf(
				footpoint.global_position.y,
				FOOTPOINT_ROAM_RECT.position.y,
				FOOTPOINT_ROAM_RECT.end.y
			)
		)
		var previous_position := footpoint.global_position
		var moved_position := _move_player_motion_with_slide(
			previous_position - TANK_COLLISION_CENTER_OFFSET,
			movement_direction * move_speed * delta
		) + TANK_COLLISION_CENTER_OFFSET
		footpoint.global_position = Vector2(
			clampf(moved_position.x, FOOTPOINT_ROAM_RECT.position.x, FOOTPOINT_ROAM_RECT.end.x),
			clampf(moved_position.y, FOOTPOINT_ROAM_RECT.position.y, FOOTPOINT_ROAM_RECT.end.y)
		)
		var actual_motion := footpoint.global_position - previous_position
		footpoint.call(
			"update_movement",
			Vector2.ZERO if actual_motion.is_zero_approx() else actual_motion.normalized(),
			delta
		)
		var touched_key := _first_player_tank_touching_footpoint(
			footpoint.global_position
		)
		if not touched_key.is_empty():
			_detonate_footpoint(combatant_key)


func _nearest_player_tank_for_footpoint(source_position: Vector2) -> String:
	var nearest_key := ""
	var nearest_distance := INF
	for target_key_value: Variant in _combatants.keys():
		var target_key := String(target_key_value)
		var target: Dictionary = _combatants[target_key]
		if not _is_live_team_tank(target):
			continue
		var distance := source_position.distance_to(_combatant_position(target_key))
		if distance <= FOOTPOINT_ALERT_RANGE and distance < nearest_distance:
			nearest_key = target_key
			nearest_distance = distance
	return nearest_key


func _first_player_tank_touching_footpoint(source_position: Vector2) -> String:
	for target_key_value: Variant in _combatants.keys():
		var target_key := String(target_key_value)
		var target: Dictionary = _combatants[target_key]
		if not _is_live_team_tank(target):
			continue
		if (
			source_position.distance_to(_combatant_position(target_key))
			<= FOOTPOINT_CONTACT_RADIUS
		):
			return target_key
	return ""


func _is_live_team_tank(combatant: Dictionary) -> bool:
	var team_no := int(combatant.get("team_no", 0))
	return (
		(team_no == 1 or team_no == 2)
		and not bool(combatant.get("dead", false))
		and not bool(combatant.get("is_map_object", false))
		and not bool(combatant.get("is_chief", false))
		and not bool(combatant.get("is_neutral_footpoint", false))
	)


func _detonate_footpoint(combatant_key: String) -> void:
	if not _combatants.has(combatant_key):
		return
	var source_position := _combatant_position(combatant_key)
	var targets: Array[String] = []
	for target_key_value: Variant in _combatants.keys():
		var target_key := String(target_key_value)
		var target: Dictionary = _combatants[target_key]
		if (
			_is_live_team_tank(target)
			and source_position.distance_to(_combatant_position(target_key))
			<= FOOTPOINT_EXPLOSION_RADIUS
		):
			targets.append(target_key)
	for target_key: String in targets:
		_deal_damage(
			combatant_key,
			target_key,
			FOOTPOINT_EXPLOSION_DAMAGE,
			DAMAGE_TYPE_PHYSICAL
		)
	_handle_neutral_footpoint_death(combatant_key)


func _handle_neutral_footpoint_death(combatant_key: String) -> void:
	if not _combatants.has(combatant_key):
		return
	var combatant: Dictionary = _combatants[combatant_key]
	var death_position := _combatant_position(combatant_key)
	var footpoint := combatant.get("tank") as Node2D
	var building_id := int(combatant.get("footpoint_spawner_id", 0))
	var blow_effect := _play_footpoint_template_effect(
		_footpoint_blow_template,
		death_position
	)
	blow_effect.z_as_relative = false
	blow_effect.z_index = 8
	var death_effect := _play_footpoint_template_effect(
		_footpoint_death_template,
		death_position
	)
	death_effect.z_as_relative = false
	death_effect.z_index = 9
	if is_instance_valid(footpoint):
		footpoint.visible = false
		footpoint.queue_free()
	_combatants.erase(combatant_key)
	if _footpoint_spawners.has(building_id):
		var spawner: Dictionary = _footpoint_spawners[building_id]
		spawner["active_key"] = ""
		spawner["birth_remaining"] = 0.0
		spawner["respawn_remaining"] = FOOTPOINT_RESPAWN_SECONDS
		_footpoint_spawners[building_id] = spawner


func _clear_neutral_footpoints() -> void:
	for spawner_value: Variant in _footpoint_spawners.values():
		if spawner_value is not Dictionary:
			continue
		var combatant_key := String(
			(spawner_value as Dictionary).get("active_key", "")
		)
		if not combatant_key.is_empty():
			_combatants.erase(combatant_key)
	_footpoint_spawners.clear()
	_footpoint_generation = 0
	if _neutral_footpoints == null:
		return
	for footpoint: Node in _neutral_footpoints.get_children():
		_neutral_footpoints.remove_child(footpoint)
		footpoint.queue_free()


func _move_player_with_collision(
	current_position: Vector2,
	motion: Vector2
) -> Vector2:
	if motion.length_squared() <= 0.0001:
		return _clamp_tank_center(current_position)
	# Kept only for bot motion and deterministic tests. The player uses the
	# CharacterBody2D above. This helper may slide along an existing tangent,
	# but it never searches for or persists an automatically chosen route.
	return _move_player_motion_with_slide(current_position, motion)


func _move_player_motion_with_slide(
	current_position: Vector2,
	motion: Vector2
) -> Vector2:
	var result := _clamp_tank_center(current_position)
	var step_count := maxi(
		int(ceil(motion.length() / COLLISION_MOVE_STEP)),
		1
	)
	var step_motion := motion / float(step_count)
	for _step_index in range(step_count):
		result = _move_player_slide_step(result, step_motion)
	return result


func _move_player_slide_step(
	current_position: Vector2,
	motion: Vector2
) -> Vector2:
	var result := _clamp_tank_center(current_position)
	var remaining := motion
	for _iteration in range(MOVEMENT_SLIDE_ITERATIONS):
		if remaining.length_squared() <= 0.0001:
			break
		var candidate := _clamp_tank_center(result + remaining)
		var candidate_motion := candidate - result
		if candidate_motion.length_squared() <= 0.0001:
			break
		if _tank_can_occupy(candidate):
			result = candidate
			break
		var safe_fraction := _movement_safe_fraction(
			result,
			candidate_motion
		)
		if safe_fraction > 0.0:
			result = _clamp_tank_center(
				result + candidate_motion * safe_fraction
			)
		var leftover := candidate_motion * (1.0 - safe_fraction)
		if leftover.length_squared() <= 0.0001:
			break
		var probe_distance := minf(leftover.length(), 1.0)
		var blocked_probe := _clamp_tank_center(
			result + leftover.normalized() * probe_distance
		)
		var collision_normals := _movement_collision_normals(
			blocked_probe,
			leftover
		)
		if collision_normals.is_empty():
			collision_normals = _movement_collision_normals(
				candidate,
				leftover
			)
		if collision_normals.is_empty():
			break
		var slide_motion := leftover
		for normal: Vector2 in collision_normals:
			var inward_speed := slide_motion.dot(normal)
			if inward_speed < 0.0:
				slide_motion -= normal * inward_speed
		if slide_motion.length_squared() <= 0.0001:
			break
		remaining = slide_motion
	return result


func _movement_safe_fraction(start: Vector2, motion: Vector2) -> float:
	if motion.length_squared() <= 0.0001:
		return 0.0
	if _tank_can_occupy(_clamp_tank_center(start + motion)):
		return 1.0
	var safe_fraction := 0.0
	var blocked_fraction := 1.0
	for _iteration in range(MOVEMENT_SWEEP_BINARY_STEPS):
		var middle := (safe_fraction + blocked_fraction) * 0.5
		var candidate := _clamp_tank_center(start + motion * middle)
		if _tank_can_occupy(candidate):
			safe_fraction = middle
		else:
			blocked_fraction = middle
	return safe_fraction


func _movement_collision_normals(
	anchor_position: Vector2,
	incoming_motion: Vector2
) -> Array[Vector2]:
	var normals: Array[Vector2] = []
	var collision_center := (
		anchor_position + TANK_COLLISION_CENTER_OFFSET
	)
	for collision_rectangle: Rect2 in _static_collision_rectangles:
		_append_movement_collision_normal(
			normals,
			collision_center,
			incoming_motion,
			collision_rectangle
		)
	for rectangles_value: Variant in _building_collision_rectangles.values():
		if rectangles_value is not Array:
			continue
		for rectangle_value: Variant in rectangles_value:
			if rectangle_value is not Rect2:
				continue
			_append_movement_collision_normal(
				normals,
				collision_center,
				incoming_motion,
				rectangle_value as Rect2
			)
	return normals


func _append_movement_collision_normal(
	normals: Array[Vector2],
	collision_center: Vector2,
	incoming_motion: Vector2,
	rectangle: Rect2
) -> void:
	if not _circle_intersects_rectangle(
		collision_center,
		TANK_COLLISION_RADIUS,
		rectangle
	):
		return
	var rectangle_end := rectangle.end
	var nearest_point := Vector2(
		clampf(collision_center.x, rectangle.position.x, rectangle_end.x),
		clampf(collision_center.y, rectangle.position.y, rectangle_end.y)
	)
	var normal := collision_center - nearest_point
	if normal.length_squared() > 0.0001:
		normal = normal.normalized()
	else:
		normal = _rectangle_inside_normal(
			collision_center,
			incoming_motion,
			rectangle
		)
	for existing_normal: Vector2 in normals:
		if existing_normal.dot(normal) > 0.999:
			return
	normals.append(normal)


func _rectangle_inside_normal(
	center: Vector2,
	incoming_motion: Vector2,
	rectangle: Rect2
) -> Vector2:
	var distances := [
		center.x - rectangle.position.x,
		rectangle.end.x - center.x,
		center.y - rectangle.position.y,
		rectangle.end.y - center.y,
	]
	var normals := [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]
	var best_index := 0
	for index in range(1, distances.size()):
		if float(distances[index]) < float(distances[best_index]):
			best_index = index
	var result: Vector2 = normals[best_index]
	if not incoming_motion.is_zero_approx() and result.dot(incoming_motion) > 0.0:
		result = -result
	return result


func _clamp_tank_center(position_value: Vector2) -> Vector2:
	var minimum_anchor := (
		Vector2.ONE * TANK_COLLISION_RADIUS
		- TANK_COLLISION_CENTER_OFFSET
	)
	var maximum_anchor := (
		MAP_SIZE
		- Vector2.ONE * TANK_COLLISION_RADIUS
		- TANK_COLLISION_CENTER_OFFSET
	)
	return Vector2(
		clampf(
			position_value.x,
			minimum_anchor.x,
			maximum_anchor.x
		),
		clampf(
			position_value.y,
			minimum_anchor.y,
			maximum_anchor.y
		)
	)


func _tank_can_occupy(anchor_center: Vector2) -> bool:
	var collision_center := (
		anchor_center + TANK_COLLISION_CENTER_OFFSET
	)
	for collision_rectangle: Rect2 in _static_collision_rectangles:
		if _circle_intersects_rectangle(
			collision_center,
			TANK_COLLISION_RADIUS,
			collision_rectangle
		):
			return false
	for rectangles_value: Variant in _building_collision_rectangles.values():
		if rectangles_value is not Array:
			continue
		for building_rectangle_value: Variant in rectangles_value:
			if building_rectangle_value is not Rect2:
				continue
			if _circle_intersects_rectangle(
				collision_center,
				TANK_COLLISION_RADIUS,
				building_rectangle_value as Rect2
			):
				return false
	return true


func _circle_intersects_rectangle(
	center: Vector2,
	radius: float,
	rectangle: Rect2
) -> bool:
	var rectangle_end := rectangle.position + rectangle.size
	var nearest_point := Vector2(
		clampf(center.x, rectangle.position.x, rectangle_end.x),
		clampf(center.y, rectangle.position.y, rectangle_end.y)
	)
	return center.distance_squared_to(nearest_point) < radius * radius


func _clear_movement_keys() -> void:
	_movement_input_state.clear()
	if is_instance_valid(_player_anchor):
		_player_anchor.velocity = Vector2.ZERO


func _handle_fire_mouse_button(mouse_event: InputEventMouseButton) -> void:
	if not mouse_event.pressed or not visible or not _control_enabled:
		return
	if _skill_targeting.is_active():
		if mouse_event.button_index == MOUSE_BUTTON_LEFT:
			# Do not confirm the previous frame's mouse position.  Direction skills
			# otherwise could accept a fast click after the cursor had crossed 600.
			_skill_targeting.update_target(
				_player_anchor.global_position,
				_world_mouse_position()
			)
			var cast: Dictionary = _skill_targeting.confirm()
			if not cast.is_empty():
				_commit_skill_cast(cast)
		elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
			_cancel_skill_targeting()
		return
	if not _skill_channel.is_empty():
		return
	if mouse_event.button_index == MOUSE_BUTTON_LEFT:
		_try_shoot()
	elif mouse_event.button_index == MOUSE_BUTTON_RIGHT:
		_auto_fire_enabled = not _auto_fire_enabled
		if _auto_fire_enabled:
			_try_shoot()


func _is_pointer_over_interactive_battle_hud(
	pointer_position: Vector2
) -> bool:
	for control: Control in [
		_skill_1,
		_skill_2,
		_skill_3,
		_settings_button,
		_battle_chat,
	]:
		if (
			is_instance_valid(control)
			and control.visible
			and control.get_global_rect().has_point(pointer_position)
		):
			return true
	return false


func _skill_index_at_hud_position(pointer_position: Vector2) -> int:
	var skill_slots: Array[Control] = [_skill_1, _skill_2, _skill_3]
	for skill_index in skill_slots.size():
		var skill_slot := skill_slots[skill_index]
		if (
			is_instance_valid(skill_slot)
			and skill_slot.visible
			and skill_slot.get_global_rect().has_point(pointer_position)
		):
			return skill_index
	return -1


func _update_skill_hud_hover() -> void:
	if _skill_tooltip == null:
		return
	var pointer_position := get_viewport().get_mouse_position()
	var hovered_skill := _skill_index_at_hud_position(pointer_position)
	if (
		is_instance_valid(_shield_buff_icon)
		and _shield_buff_icon.visible
		and _shield_buff_icon.get_global_rect().has_point(pointer_position)
	):
		hovered_skill = 3
	if hovered_skill == _hovered_skill_index:
		return
	_hovered_skill_index = hovered_skill
	if hovered_skill < 0:
		_skill_tooltip.hide_tooltip()
		return
	if hovered_skill == 3:
		_skill_tooltip.show_for(
			_ironman_shield_tooltip_data(),
			_shield_buff_icon.get_global_rect()
		)
	else:
		var skill_slot := _skill_slot_for(hovered_skill)
		if skill_slot == null:
			return
		_skill_tooltip.show_for(
			_ironman_skill_tooltip_data(hovered_skill),
			skill_slot.get_global_rect()
		)


func _update_auto_fire(delta: float) -> void:
	_shot_cooldown_remaining = maxf(
		_shot_cooldown_remaining - delta,
		0.0
	)
	if (
		_auto_fire_enabled
		and _skill_targeting.is_active() == false
		and _skill_channel.is_empty()
		and _shot_cooldown_remaining <= 0.0
	):
		_try_shoot()


func _try_shoot() -> void:
	if _shot_cooldown_remaining > 0.0:
		return
	_shoot_once()
	_shot_cooldown_remaining = 60.0 / maxf(_tank_fire_rate, 1.0)


func _shoot_once() -> void:
	if not visible or not _control_enabled:
		return
	if _server_authoritative_battle:
		if not _authoritative_ready:
			return
		var authoritative_target := _world_mouse_position()
		_enqueue_authoritative_command({
			"type": "basic_attack",
			"target_x": authoritative_target.x,
			"target_y": authoritative_target.y,
		})
	_update_cannon_aim()
	var shot_value: Variant = _player_tank.call("fire")
	if shot_value is not Dictionary:
		return
	var shot_data: Dictionary = shot_value
	var position_value: Variant = shot_data.get("position", Vector2.ZERO)
	var direction_value: Variant = shot_data.get("direction", Vector2.ZERO)
	if position_value is not Vector2 or direction_value is not Vector2:
		return
	var projectile := PROJECTILE_SCENE.instantiate() as Node2D
	if projectile == null:
		return
	_projectiles.add_child(projectile)
	projectile.call(
		"configure",
		position_value,
		direction_value,
		_tank_attack_range
	)
	projectile.connect(
		"advanced",
		_on_basic_projectile_advanced.bind(projectile)
	)
	projectile.connect("impact_started", _on_basic_projectile_impact)
	projectile.connect(
		"terrain_impact_started",
		_on_basic_projectile_wall_impact
	)


func _on_basic_projectile_advanced(
	start: Vector2,
	finish: Vector2,
	projectile: Node2D
) -> void:
	if not is_instance_valid(projectile):
		return
	var terrain_fraction := _first_terrain_hit_fraction(start, finish)
	var impact_key := _first_enemy_hit_on_segment(start, finish, true)
	var impact_fraction := INF
	if not impact_key.is_empty():
		impact_fraction = clampf(
			_combatant_hit_fraction(start, finish, impact_key),
			0.0,
			1.0
		)
	if terrain_fraction < impact_fraction:
		projectile.global_position = start.lerp(finish, terrain_fraction)
		projectile.call("impact", true)
		return
	if is_inf(impact_fraction):
		return
	projectile.global_position = start.lerp(finish, impact_fraction)
	projectile.call("impact")
	_deal_damage("player", impact_key, _tank_basic_attack_damage)


func _on_basic_projectile_impact(impact_position: Vector2) -> void:
	# Player and bot Iron Man basic shots share the same original impact timeline
	# as NPC turret shells, replacing the old custom bullet_gangtie02 animation.
	_play_normal_bullet_impact(impact_position)


func _on_basic_projectile_wall_impact(impact_position: Vector2) -> void:
	# `normal_bullet_blow02.swf` is the original blue impact used when a normal
	# shell is stopped by terrain; it has no combat target and causes no damage.
	_play_wall_bullet_impact(impact_position)


func _reset_firing() -> void:
	_auto_fire_enabled = false
	_shot_cooldown_remaining = 0.0


func _clear_projectiles() -> void:
	if _projectiles == null:
		return
	for projectile in _projectiles.get_children():
		projectile.queue_free()


func _spawn_participant_tanks(viewer: Dictionary) -> void:
	var viewer_team := int(viewer.get("team_no", 0))
	var viewer_slot := int(viewer.get("slot_no", 0))
	for participant_value: Variant in _match_data.get("participants", []):
		if participant_value is not Dictionary:
			continue
		var participant: Dictionary = participant_value
		var team_no := int(participant.get("team_no", 0))
		var slot_no := int(participant.get("slot_no", 0))
		if team_no == viewer_team and slot_no == viewer_slot:
			continue
		if team_no < 1 or team_no > 2 or slot_no < 1 or slot_no > 5:
			continue
		var spawn := _spawns.get_node_or_null(
			"Team%dSlot%d" % [team_no, slot_no]
		) as Marker2D
		if spawn == null:
			continue
		var tank := BATTLE_TANK_SCENE.instantiate() as Node2D
		if tank == null:
			continue
		tank.name = "ParticipantTankTeam%dSlot%d" % [
			team_no,
			slot_no,
		]
		tank.position = spawn.position
		_participant_tanks.add_child(tank)
		var tank_key := String(
			participant.get("tank_key", "gangtiexia03")
		).strip_edges()
		if tank_key.is_empty():
			tank_key = "gangtiexia03"
		var skin_key := String(
			participant.get(
				"equipped_skin_key",
				"gangtiexia03_default"
			)
		).strip_edges()
		if skin_key.is_empty():
			skin_key = "gangtiexia03_default"
		tank.call("configure", tank_key, skin_key, team_no)
		tank.call("set_local_controlled", false)
		tank.call("set_hostile", team_no != viewer_team)
		tank.call(
			"set_player_identity",
			_participant_display_name(participant, slot_no),
			int(participant.get("vip_level", 0))
		)
		var combat_stats := _resolved_combat_stats(participant)
		if bool(participant.get("is_bot", false)):
			# The sandbox keeps the requested 50k HP target while every other
			# property still comes from the same tank stat record.
			combat_stats["hit_points"] = TEST_BOT_HIT_POINTS
		var maximum_health := int(combat_stats["hit_points"])
		tank.call("set_health", maximum_health, maximum_health)
		_register_combatant(
			"participant:%d:%d" % [team_no, slot_no],
			tank,
			team_no,
			combat_stats,
			false,
			bool(participant.get("is_bot", false))
		)


func _clear_participant_tanks() -> void:
	if _participant_tanks == null:
		return
	for tank: Node in _participant_tanks.get_children():
		_participant_tanks.remove_child(tank)
		tank.queue_free()


func _reset_chiefs(viewer_team_no: int) -> void:
	if _chiefs == null:
		return
	for chief_node: Node in _chiefs.get_children():
		if chief_node.has_method("reset_for_match"):
			chief_node.call("reset_for_match", viewer_team_no)


func _register_chief_combatants() -> void:
	if _chiefs == null:
		return
	for chief_node: Node in _chiefs.get_children():
		var chief := chief_node as Node2D
		if chief == null or not chief.has_method("get_team_no"):
			continue
		var team_no := int(chief.call("get_team_no"))
		if team_no < 1 or team_no > 2:
			continue
		var combatant_key := "chief:%d" % team_no
		_register_combatant(
			combatant_key,
			chief,
			team_no,
			CHIEF_CATALOG.combat_stats(),
			false,
			false
		)
		var combatant: Dictionary = _combatants[combatant_key]
		combatant["is_chief"] = true
		combatant["respawn_seconds"] = CHIEF_CATALOG.RESPAWN_SECONDS
		combatant["hit_radius"] = CHIEF_CATALOG.HIT_RADIUS
		combatant["alert_range"] = CHIEF_CATALOG.ALERT_RANGE
		combatant["attack_interval_seconds"] = (
			CHIEF_CATALOG.ATTACK_INTERVAL_SECONDS
		)
		combatant["burst_shots"] = CHIEF_CATALOG.BURST_SHOTS
		combatant["burst_break_seconds"] = (
			CHIEF_CATALOG.BURST_BREAK_SECONDS
		)
		combatant["chief_shot_cooldown"] = 0.0
		combatant["chief_burst_remaining"] = 0
		combatant["chief_burst_break_remaining"] = 0.0
		_combatants[combatant_key] = combatant
		chief.call(
			"set_health",
			CHIEF_CATALOG.MAXIMUM_HEALTH,
			CHIEF_CATALOG.MAXIMUM_HEALTH
		)


func _resolved_combat_stats(
	primary: Dictionary,
	fallback: Dictionary = {}
) -> Dictionary:
	# Lobby values are already effective values: base tank stat + skin
	# collection + military rank + any saved stat-bonus sources.  Prefer that
	# full snapshot over a participant's visual-only match record.
	var source := fallback.duplicate(true)
	source.merge(primary, true)
	var effective_value: Variant = primary.get("effective_stats", {})
	if effective_value is Dictionary:
		source.merge(effective_value, true)
	var damage_type := String(
		source.get(
			"damage_type",
			source.get("tank_damage_type", DAMAGE_TYPE_PHYSICAL)
		)
	).to_lower()
	if damage_type != DAMAGE_TYPE_ENERGY:
		damage_type = DAMAGE_TYPE_PHYSICAL
	var collection_bonus: Dictionary = {}
	var collection_value: Variant = source.get("skin_collection_bonus", {})
	if collection_value is Dictionary:
		collection_bonus = collection_value
	var revive_speed_percent := maxf(
		float(
			source.get(
				"revive_speed_percent",
				collection_bonus.get("revive_speed_percent", 0.0)
			)
		),
		0.0
	)
	var revive_duration_seconds := maxf(
		float(
			source.get(
				"revive_duration_seconds",
				collection_bonus.get("revive_duration_seconds", 0.0)
			)
		),
		0.0
	)
	return {
		"hit_points": maxi(
			int(source.get("hit_points", IRONMAN_BASE_HIT_POINTS)),
			1
		),
		"basic_attack_damage": maxf(
			float(source.get("basic_attack_damage", IRONMAN_BASE_BASIC_ATTACK_DAMAGE)),
			0.0
		),
		"penetration": maxf(
			float(source.get("penetration", IRONMAN_BASE_PENETRATION)),
			0.0
		),
		"physical_armor": maxf(
			float(source.get("physical_armor", IRONMAN_BASE_PHYSICAL_ARMOR)),
			0.0
		),
		"energy_shield": maxf(
			float(source.get("energy_shield", IRONMAN_BASE_ENERGY_SHIELD)),
			0.0
		),
		"move_speed": maxf(
			float(source.get("move_speed", IRONMAN_BASE_MOVE_SPEED)),
			0.0
		),
		"fire_rate": maxf(
			float(source.get("fire_rate", IRONMAN_BASE_FIRE_RATE)),
			1.0
		),
		"attack_range": maxf(
			float(source.get("attack_range", IRONMAN_BASE_ATTACK_RANGE)),
			1.0
		),
		"critical_chance_percent": clampf(
			float(
				source.get(
					"critical_chance_percent",
					IRONMAN_BASE_CRITICAL_CHANCE_PERCENT
				)
			),
			0.0,
			100.0
		),
		"critical_damage_percent": maxf(
			float(
				source.get(
					"critical_damage_percent",
					IRONMAN_BASE_CRITICAL_DAMAGE_PERCENT
				)
			),
			100.0
		),
		"damage_type": damage_type,
		"revive_speed_percent": revive_speed_percent,
		"revive_duration_seconds": revive_duration_seconds,
	}


func _participant_display_name(
	participant: Dictionary,
	slot_no: int
) -> String:
	var display_name := String(
		participant.get("display_name", "")
	).strip_edges()
	if not display_name.is_empty():
		return display_name
	if bool(participant.get("is_bot", false)):
		return "BOT %d" % slot_no
	return "Người chơi"


func _on_skill_slot_requested(skill_index: int) -> void:
	if skill_index == 2 and not _skill_channel.is_empty():
		_try_cancel_tia_tan_ra()
		return
	_try_select_skill(skill_index)


func _on_skill_slot_hover_changed(
	hovered: bool,
	anchor_global_rect: Rect2,
	skill_index: int
) -> void:
	if _skill_tooltip == null:
		return
	if hovered:
		_skill_tooltip.show_for(
			_ironman_skill_tooltip_data(skill_index),
			anchor_global_rect
		)
	else:
		_skill_tooltip.hide_tooltip()


func _ironman_skill_tooltip_data(skill_index: int) -> Dictionary:
	if skill_index < 0 or skill_index >= IRONMAN_SKILL_TOOLTIP_DATA.SKILL_TOOLTIPS.size():
		return {}
	var source: Dictionary = IRONMAN_SKILL_TOOLTIP_DATA.SKILL_TOOLTIPS[skill_index]
	var projectile_value := "Có" if skill_index == 0 else "Không"
	var projectile_color := "#50e7ff" if skill_index == 0 else "#9aa8ab"
	var header := (
		"[b][lb]Giới thiệu[rb][/b]\n"
		+ "Tính chất: [color=#ff3cd8][b]Skill[/b][/color]"
		+ "     Loại ST: [color=#ffad19][b]Vật Lý[/b][/color]\n"
		+ "VP Bay: [color=%s][b]%s[/b][/color]\n\n"
	) % [projectile_color, projectile_value]
	return {
		"title": String(source.get("title", "")),
		"cooldown": "Thời gian CD %s" % String(source.get("cooldown", "")),
		"height": float(source.get("height", 320.0)),
		"bbcode": header + String(source.get("description", "")),
	}


func _ironman_shield_tooltip_data() -> Dictionary:
	var source: Dictionary = IRONMAN_SKILL_TOOLTIP_DATA.SHIELD_TOOLTIP
	return {
		"title": String(source.get("title", "Khiên Thép")),
		"height": float(source.get("height", 108.0)),
		"show_metadata": false,
		"title_font_size": int(source.get("title_font_size", 14)),
		"body_font_size": int(source.get("body_font_size", 12)),
		"bbcode": String(source.get("description", "")),
	}


func _try_select_skill(skill_index: int) -> void:
	if not visible or not _control_enabled or not _skill_channel.is_empty():
		return
	var skill_slot := _skill_slot_for(skill_index)
	if skill_slot == null or not bool(skill_slot.call("is_ready")):
		return
	if _skill_targeting.is_active():
		_cancel_skill_targeting()
	var targeting_mode := (
		PvpBattleSkillTargeting.MODE_POINT
		if skill_index == 1
		else PvpBattleSkillTargeting.MODE_DIRECTION
	)
	var selection_size := _ironman_skill_selection_size(skill_index)
	skill_slot.call("set_targeting_active", true)
	_skill_targeting.begin(
		skill_index,
		targeting_mode,
		IRONMAN_SKILL_RANGE,
		selection_size
	)
	# Update immediately, rather than waiting for the next frame, so a direct
	# click on a HUD icon always opens the targeting preview at once.
	_skill_targeting.update_target(
		_player_anchor.global_position,
		_world_mouse_position()
	)


func _cancel_skill_targeting() -> void:
	if _skill_targeting == null or not _skill_targeting.is_active():
		return
	var skill_slot := _skill_slot_for(_skill_targeting.active_skill_index())
	if skill_slot != null:
		skill_slot.call("set_targeting_active", false)
	_skill_targeting.cancel()


func _ironman_skill_selection_size(skill_index: int) -> float:
	match skill_index:
		0:
			return IRONMAN_R_SELECT_WIDTH
		1:
			return IRONMAN_E_SELECT_DIAMETER
		2:
			return IRONMAN_TIA_SELECT_WIDTH
	return 0.0


func _commit_skill_cast(cast: Dictionary) -> void:
	if _server_authoritative_battle and not _authoritative_ready:
		return
	var skill_index := int(cast.get("skill_index", -1))
	var cast_origin: Vector2 = cast.get("origin", Vector2.ZERO)
	var cast_target: Vector2 = cast.get("target", cast_origin)
	# E is an area cast and cannot select beyond 600. R and Space are direction
	# casts: their target was already clamped to the 600 endpoint by targeting.
	if (
		skill_index == 1
		and cast_origin.distance_to(cast_target) > IRONMAN_SKILL_RANGE
	):
		return
	var skill_slot := _skill_slot_for(skill_index)
	if skill_slot == null:
		return
	skill_slot.call("set_targeting_active", false)
	skill_slot.call(
		"set_cooldown_seconds",
		_effective_skill_cooldown(skill_index)
	)
	var activation_succeeded := (
		bool(
			skill_slot.call(
				"begin_channel_countdown",
				IRONMAN_TIA_SECONDS
			)
		)
		if skill_index == 2
		else bool(skill_slot.call("activate"))
	)
	if not activation_succeeded:
		return
	if _is_test_mod_authorized() and _test_mod_no_cooldown and skill_index != 2:
		skill_slot.call("reset_ready")
	var command := cast.duplicate(true)
	command["skill_id"] = IRONMAN_SKILL_IDS[skill_index]
	command["target_position"] = cast.get("target", Vector2.ZERO)
	command["requested_at_msec"] = Time.get_ticks_msec()
	skill_command_requested.emit(command)
	if _server_authoritative_battle:
		var authoritative_target: Vector2 = command.get(
			"target_position",
			cast.get("target", _player_anchor.global_position)
		)
		_enqueue_authoritative_command({
			"type": "skill",
			"slot": skill_index + 1,
			"target_x": authoritative_target.x,
			"target_y": authoritative_target.y,
		})
		# Keep original projectile/effect timelines as prediction only. Shared HP,
		# damage, status and scores are reconciled exclusively from server snapshot.
		_apply_local_skill_command(command)
	elif use_local_skill_fallback:
		_apply_local_skill_command(command)


func _apply_local_skill_command(command: Dictionary) -> void:
	var skill_index := int(command.get("skill_index", -1))
	match skill_index:
		0:
			_cast_hat_nang_luong(command)
		1:
			_cast_dan_khong_kich(command)
		2:
			_cast_tia_tan_ra(command)
		_:
			return
	local_skill_result_applied.emit({
		"skill_id": command.get("skill_id", 0),
		"source": "local_fallback",
	})


func _skill_slot_for(skill_index: int) -> Control:
	match skill_index:
		0:
			return _skill_1
		1:
			return _skill_2
		2:
			return _skill_3
	return null


func _cast_hat_nang_luong(cast: Dictionary) -> void:
	var projectile := IRONMAN_ENERGY_PROJECTILE_SCENE.instantiate() as Node2D
	if projectile == null:
		return
	var direction: Vector2 = cast.get("direction", Vector2.RIGHT)
	_projectiles.add_child(projectile)
	projectile.call(
		"configure",
		cast.get("origin", _player_anchor.global_position),
		direction,
		IRONMAN_SKILL_RANGE
	)
	projectile.connect(
		"advanced",
		_on_energy_projectile_advanced.bind(projectile)
	)
	projectile.connect("range_ended", _on_energy_projectile_range_ended)


func _cast_dan_khong_kich(cast: Dictionary) -> void:
	var target: Vector2 = cast.get("target", _player_anchor.global_position)
	_play_timeline_effect(EFFECT_SKILL_GANGTIE01, target)
	_play_timeline_effect(EFFECT_SI_GANGTIE01, target)
	var field_effect := _play_timeline_effect(
		EFFECT_SI_GANGTIE02,
		target,
		0.0,
		true
	)
	var range_effect := MAX_RANGE_INDICATOR_SCRIPT.new()
	range_effect.position = target
	range_effect.radius = IRONMAN_SKILL_AREA_RADIUS
	range_effect.target_is_valid = true
	range_effect.z_index = 0
	_skill_effects.add_child(range_effect)
	_strike_fields.append({
		"position": target,
		"remaining": IRONMAN_E_FIELD_SECONDS,
		"tick_remaining": IRONMAN_E_TICK_SECONDS,
		"effect": field_effect,
		"range_effect": range_effect,
	})


func _cast_tia_tan_ra(cast: Dictionary) -> void:
	var direction: Vector2 = cast.get("direction", Vector2.RIGHT)
	# Skill 363301 grants the passive shield immediately when its channel starts.
	if _ironman_shield_points <= 0:
		_activate_ironman_shield()
	var beam_effect := _play_timeline_effect(
		EFFECT_BUFF_GANGTIE01,
		_player_anchor.global_position,
		0.0,
		true
	)
	beam_effect.rotation = direction.angle() + PI * 0.5
	_skill_channel = {
		"direction": direction,
		"remaining": IRONMAN_TIA_SECONDS,
		"elapsed": 0.0,
		"tick_remaining": IRONMAN_TIA_TICK_SECONDS,
		"hit_shake_remaining": 0.0,
		"hit_shake_elapsed": 0.0,
		"effect": beam_effect,
	}
	_clear_movement_keys()
	_reset_firing()


func _try_cancel_tia_tan_ra() -> void:
	if _skill_channel.is_empty():
		return
	if float(_skill_channel.get("elapsed", 0.0)) < IRONMAN_TIA_CANCEL_DELAY_SECONDS:
		return
	if _server_authoritative_battle:
		_enqueue_authoritative_command({"type": "skill_cancel"})
	_finish_tia_tan_ra()


func _finish_tia_tan_ra(start_cooldown := true) -> void:
	var channel_was_active := not _skill_channel.is_empty()
	var effect: Variant = _skill_channel.get("effect")
	if is_instance_valid(effect):
		effect.queue_free()
	_skill_channel.clear()
	if not channel_was_active:
		return
	if start_cooldown:
		_skill_3.call(
			"set_cooldown_seconds",
			_effective_skill_cooldown(2)
		)
		_skill_3.call("finish_channel_and_start_cooldown")
		if _is_test_mod_authorized() and _test_mod_no_cooldown:
			_skill_3.call("reset_ready")
	else:
		_skill_3.call("cancel_channel_countdown")


func _process_persistent_world_skill_runtime(delta: float) -> void:
	_process_status_effects(delta)
	_process_dan_khong_kich_fields(delta)


func _process_player_bound_skill_runtime(delta: float) -> void:
	_process_ironman_shield(delta)
	_process_tia_tan_ra(delta)


func _process_dan_khong_kich_fields(delta: float) -> void:
	for field_index in range(_strike_fields.size() - 1, -1, -1):
		var field: Dictionary = _strike_fields[field_index]
		field["remaining"] = float(field.get("remaining", 0.0)) - delta
		field["tick_remaining"] = (
			float(field.get("tick_remaining", 0.0)) - delta
		)
		while (
			float(field.get("tick_remaining", 0.0)) <= 0.0
			and float(field.get("remaining", 0.0)) >= 0.0
		):
			_apply_dan_khong_kich_tick(field)
			field["tick_remaining"] = (
				float(field.get("tick_remaining", 0.0))
				+ IRONMAN_E_TICK_SECONDS
			)
		if float(field.get("remaining", 0.0)) <= 0.0:
			for effect_key in ["effect", "range_effect"]:
				var effect: Variant = field.get(effect_key)
				if is_instance_valid(effect):
					effect.queue_free()
			_strike_fields.remove_at(field_index)
		else:
			_strike_fields[field_index] = field


func _apply_dan_khong_kich_tick(field: Dictionary) -> void:
	var target: Vector2 = field.get("position", Vector2.ZERO)
	for combatant_key in _enemy_keys_in_radius(
		target,
		IRONMAN_SKILL_AREA_RADIUS,
		true
	):
		var combatant: Dictionary = _combatants.get(combatant_key, {})
		var e_damage_multiplier := (
			IRONMAN_E_STRUCTURE_DAMAGE_MULTIPLIER
			if bool(combatant.get("is_structure", false))
			else 1.0
		)
		_deal_damage(
			"player",
			combatant_key,
			_tank_basic_attack_damage
			* IRONMAN_E_DAMAGE_RATIO
			* e_damage_multiplier
		)
		if bool(combatant.get("is_map_object", false)):
			continue
		_apply_slow(
			combatant_key,
			IRONMAN_E_SLOW_VALUE,
			IRONMAN_E_SLOW_SECONDS
		)
		_apply_e_slow_marker(combatant_key)


func _process_tia_tan_ra(delta: float) -> void:
	if _skill_channel.is_empty():
		return
	_update_tia_tan_ra_direction(delta)
	_skill_channel["remaining"] = (
		float(_skill_channel.get("remaining", 0.0)) - delta
	)
	_skill_3.call(
		"update_channel_countdown",
		maxf(float(_skill_channel.get("remaining", 0.0)), 0.0)
	)
	_skill_channel["elapsed"] = (
		float(_skill_channel.get("elapsed", 0.0)) + delta
	)
	_skill_channel["tick_remaining"] = (
		float(_skill_channel.get("tick_remaining", 0.0)) - delta
	)
	var effect := _skill_channel.get("effect") as Node2D
	if is_instance_valid(effect):
		effect.global_position = _player_anchor.global_position
	while (
		float(_skill_channel.get("tick_remaining", 0.0)) <= 0.0
		and float(_skill_channel.get("remaining", 0.0)) >= 0.0
	):
		_apply_tia_tan_ra_tick()
		_skill_channel["tick_remaining"] = (
			float(_skill_channel.get("tick_remaining", 0.0))
			+ IRONMAN_TIA_TICK_SECONDS
		)
	_update_tia_hit_shake(delta)
	if float(_skill_channel.get("remaining", 0.0)) <= 0.0:
		_finish_tia_tan_ra()


func _update_tia_tan_ra_direction(delta: float) -> void:
	var current_direction: Vector2 = _skill_channel.get(
		"direction",
		Vector2.RIGHT
	)
	var mouse_offset := _world_mouse_position() - _player_anchor.global_position
	if mouse_offset.length_squared() <= 0.001:
		return
	var desired_angle := mouse_offset.angle()
	var current_angle := current_direction.angle()
	var angle_delta := wrapf(desired_angle - current_angle, -PI, PI)
	var maximum_turn := deg_to_rad(IRONMAN_TIA_TURN_SPEED_DEGREES) * delta
	var new_angle := current_angle + clampf(
		angle_delta,
		-maximum_turn,
		maximum_turn
	)
	var new_direction := Vector2.from_angle(new_angle)
	_skill_channel["direction"] = new_direction
	var effect := _skill_channel.get("effect") as Node2D
	if is_instance_valid(effect):
		effect.rotation = new_angle + PI * 0.5


func _update_tia_hit_shake(delta: float) -> void:
	var effect := _skill_channel.get("effect") as Node2D
	if not is_instance_valid(effect):
		return
	var direction: Vector2 = _skill_channel.get("direction", Vector2.RIGHT)
	var base_position := _player_anchor.global_position
	var base_rotation := direction.angle() + PI * 0.5
	var remaining := maxf(
		float(_skill_channel.get("hit_shake_remaining", 0.0)) - delta,
		0.0
	)
	_skill_channel["hit_shake_remaining"] = remaining
	if remaining <= 0.0:
		_skill_channel["hit_shake_elapsed"] = 0.0
		effect.global_position = base_position
		effect.rotation = base_rotation
		return
	var shake_elapsed := (
		float(_skill_channel.get("hit_shake_elapsed", 0.0)) + delta
	)
	_skill_channel["hit_shake_elapsed"] = shake_elapsed
	var wave := sin(shake_elapsed * TAU * IRONMAN_TIA_HIT_SHAKE_HERTZ)
	var fade := minf(remaining / 0.06, 1.0)
	var shake_value := wave * fade
	effect.global_position = (
		base_position
		+ direction.orthogonal()
		* IRONMAN_TIA_HIT_SHAKE_OFFSET
		* shake_value
	)
	effect.rotation = (
		base_rotation
		+ deg_to_rad(IRONMAN_TIA_HIT_SHAKE_DEGREES)
		* shake_value
	)


func _apply_tia_tan_ra_tick() -> void:
	var direction: Vector2 = _skill_channel.get("direction", Vector2.RIGHT)
	var start := _player_anchor.global_position
	var finish := start + direction * IRONMAN_TIA_RANGE
	var dealt_damage := 0
	for combatant_key in _enemy_keys_in_line(
		start,
		finish,
		IRONMAN_TIA_HALF_WIDTH
	):
		var tick_damage := _deal_damage(
			"player",
			combatant_key,
			_tank_basic_attack_damage * IRONMAN_TIA_DAMAGE_RATIO
		)
		dealt_damage += tick_damage
	if dealt_damage > 0:
		_skill_channel["hit_shake_remaining"] = IRONMAN_TIA_HIT_SHAKE_SECONDS
		_skill_channel["hit_shake_elapsed"] = 0.0
		_heal_player(roundi(float(dealt_damage) * 0.25))


func _on_energy_projectile_advanced(
	start: Vector2,
	finish: Vector2,
	projectile: Node2D
) -> void:
	if not is_instance_valid(projectile):
		return
	var impact_fraction := _first_terrain_hit_fraction(start, finish)
	var impact_key := _first_enemy_hit_on_segment(start, finish)
	if not impact_key.is_empty():
		var enemy_position := _combatant_position(impact_key)
		var tank_fraction := _segment_fraction(start, finish, enemy_position)
		if tank_fraction < impact_fraction:
			impact_fraction = tank_fraction
	if is_inf(impact_fraction):
		return
	var impact_position := start.lerp(finish, impact_fraction)
	projectile.queue_free()
	_resolve_hat_nang_luong_impact(impact_position)


func _on_energy_projectile_range_ended(position_value: Vector2) -> void:
	_resolve_hat_nang_luong_impact(position_value)


func _resolve_hat_nang_luong_impact(impact_position: Vector2) -> void:
	_play_timeline_effect(EFFECT_BLOW_GANGTIE01, impact_position)
	for combatant_key in _enemy_keys_in_radius(
		impact_position,
		IRONMAN_SKILL_AREA_RADIUS
	):
		if _consume_e_slow_marker(combatant_key):
			_apply_stun(combatant_key, IRONMAN_E_STUN_SECONDS)
		_deal_damage(
			"player",
			combatant_key,
			_tank_basic_attack_damage * IRONMAN_R_DAMAGE_RATIO
		)
		_apply_r_slow(combatant_key)


func _register_combatant(
	combatant_key: String,
	tank: Node2D,
	team_no: int,
	stats: Dictionary,
	is_player: bool,
	is_bot := false
) -> void:
	var maximum_health := maxi(int(stats.get("hit_points", 1)), 1)
	_combatants[combatant_key] = {
		"tank": tank,
		"team_no": team_no,
		"spawn_position": tank.global_position,
		"hit_points": maximum_health,
		"maximum_health": maximum_health,
		"basic_attack_damage": float(
			stats.get("basic_attack_damage", IRONMAN_BASE_BASIC_ATTACK_DAMAGE)
		),
		"penetration": float(stats.get("penetration", IRONMAN_BASE_PENETRATION)),
		"physical_armor": float(
			stats.get("physical_armor", IRONMAN_BASE_PHYSICAL_ARMOR)
		),
		"energy_shield": float(
			stats.get("energy_shield", IRONMAN_BASE_ENERGY_SHIELD)
		),
		"move_speed": float(stats.get("move_speed", IRONMAN_BASE_MOVE_SPEED)),
		"fire_rate": float(stats.get("fire_rate", IRONMAN_BASE_FIRE_RATE)),
		"attack_range": float(
			stats.get("attack_range", IRONMAN_BASE_ATTACK_RANGE)
		),
		"critical_chance_percent": float(
			stats.get(
				"critical_chance_percent",
				IRONMAN_BASE_CRITICAL_CHANCE_PERCENT
			)
		),
		"critical_damage_percent": float(
			stats.get(
				"critical_damage_percent",
				IRONMAN_BASE_CRITICAL_DAMAGE_PERCENT
			)
		),
		"damage_type": String(stats.get("damage_type", DAMAGE_TYPE_PHYSICAL)),
		"is_player": is_player,
		"is_bot": is_bot,
		"bot_shot_cooldown": 0.0,
		"dead": false,
		"respawn_remaining": 0.0,
		"respawn_invulnerability_remaining": 0.0,
		"kills": 0,
		"deaths": 0,
		"assists": 0,
		"damage_contributors": {},
		"slow_remaining": 0.0,
		"slow_value": 0.0,
		"slow_tick_remaining": 0.0,
		"slow_recovery": 0.0,
		"e_slow_remaining": 0.0,
		"stun_remaining": 0.0,
		"revive_speed_percent": float(
			stats.get("revive_speed_percent", 0.0)
		),
		"revive_duration_seconds": float(
			stats.get("revive_duration_seconds", 0.0)
		),
		"revive_speed_remaining": 0.0,
	}


func _enemy_keys_in_radius(
	center: Vector2,
	radius: float,
	include_structures := false
) -> Array[String]:
	var keys: Array[String] = []
	var player_combatant: Dictionary = _combatants.get("player", {})
	var player_team := int(player_combatant.get("team_no", 0))
	for combatant_key_variant in _combatants.keys():
		var combatant_key := String(combatant_key_variant)
		var combatant: Dictionary = _combatants[combatant_key]
		if (
			bool(combatant.get("dead", false))
			or (
				bool(combatant.get("is_map_object", false))
				and (
					not include_structures
					or not bool(combatant.get("is_structure", false))
				)
			)
			or int(combatant.get("team_no", 0)) == player_team
		):
			continue
		if _combatant_position(combatant_key).distance_to(center) <= radius:
			keys.append(combatant_key)
	return keys


func _enemy_keys_in_line(
	start: Vector2,
	finish: Vector2,
	half_width: float
) -> Array[String]:
	var keys: Array[String] = []
	var player_combatant: Dictionary = _combatants.get("player", {})
	var player_team := int(player_combatant.get("team_no", 0))
	for combatant_key_variant in _combatants.keys():
		var combatant_key := String(combatant_key_variant)
		var combatant: Dictionary = _combatants[combatant_key]
		if (
			bool(combatant.get("dead", false))
			or bool(combatant.get("is_map_object", false))
			or int(combatant.get("team_no", 0)) == player_team
		):
			continue
		var position_value := _combatant_position(combatant_key)
		var fraction := _segment_fraction(start, finish, position_value)
		if fraction <= 0.0 or fraction > 1.0:
			continue
		var closest_point := start.lerp(finish, fraction)
		if position_value.distance_to(closest_point) <= half_width + IRONMAN_TARGET_RADIUS:
			keys.append(combatant_key)
	return keys


func _first_enemy_hit_on_segment(
	start: Vector2,
	finish: Vector2,
	include_map_objects := false
) -> String:
	var player_combatant: Dictionary = _combatants.get("player", {})
	return _first_enemy_hit_on_segment_for_team(
		start,
		finish,
		int(player_combatant.get("team_no", 0)),
		include_map_objects
	)


func _first_enemy_hit_on_segment_for_team(
	start: Vector2,
	finish: Vector2,
	shooter_team: int,
	include_map_objects := false
) -> String:
	var first_key := ""
	var first_fraction := INF
	for combatant_key_variant in _combatants.keys():
		var combatant_key := String(combatant_key_variant)
		var combatant: Dictionary = _combatants[combatant_key]
		if (
			bool(combatant.get("dead", false))
			or (
				bool(combatant.get("is_map_object", false))
				and not include_map_objects
			)
			or int(combatant.get("team_no", 0)) == shooter_team
		):
			continue
		var fraction := _combatant_hit_fraction(
			start,
			finish,
			combatant_key
		)
		if fraction < 0.0 or fraction > 1.0:
			continue
		if fraction < first_fraction:
			first_fraction = fraction
			first_key = combatant_key
	return first_key


func _combatant_hit_fraction(
	start: Vector2,
	finish: Vector2,
	combatant_key: String
) -> float:
	var combatant: Dictionary = _combatants.get(combatant_key, {})
	if bool(combatant.get("is_map_object", false)):
		var hit_rectangles_value: Variant = combatant.get("hit_rectangles", [])
		if hit_rectangles_value is Array:
			return _first_rectangle_hit_fraction(
				start,
				finish,
				hit_rectangles_value
			)
		return -1.0
	var position_value := _combatant_position(combatant_key)
	var fraction := _segment_fraction(start, finish, position_value)
	if fraction < 0.0 or fraction > 1.0:
		return -1.0
	var closest_point := start.lerp(finish, fraction)
	var hit_radius := maxf(
		float(combatant.get("hit_radius", IRONMAN_TARGET_RADIUS)),
		1.0
	)
	return (
		fraction
		if position_value.distance_to(closest_point) <= hit_radius
		else -1.0
	)


func _first_rectangle_hit_fraction(
	start: Vector2,
	finish: Vector2,
	rectangles: Array
) -> float:
	var first_fraction := INF
	for rectangle_value: Variant in rectangles:
		if rectangle_value is not Rect2:
			continue
		var rectangle := rectangle_value as Rect2
		if rectangle.has_point(start):
			return 0.0
		var rectangle_end := rectangle.end
		var corners := [
			rectangle.position,
			Vector2(rectangle_end.x, rectangle.position.y),
			rectangle_end,
			Vector2(rectangle.position.x, rectangle_end.y),
		]
		for corner_index in corners.size():
			var hit: Variant = Geometry2D.segment_intersects_segment(
				start,
				finish,
				corners[corner_index],
				corners[(corner_index + 1) % corners.size()]
			)
			if hit is Vector2:
				first_fraction = minf(
					first_fraction,
					_segment_fraction(start, finish, hit)
				)
	return -1.0 if is_inf(first_fraction) else first_fraction


func _process_bot_ai(delta: float) -> void:
	if _server_authoritative_battle:
		return
	for combatant_key_variant in _combatants.keys():
		var combatant_key := String(combatant_key_variant)
		var combatant: Dictionary = _combatants[combatant_key]
		if (
			not bool(combatant.get("is_bot", false))
			or bool(combatant.get("dead", false))
		):
			continue
		var tank := combatant.get("tank") as Node2D
		if not is_instance_valid(tank):
			continue
		# In the explicit TEST sandbox this single option owns both halves of the
		# requested behaviour: unchecked bots remain idle and do not attack;
		# checked bots may move, aim and fire normally.
		if _is_test_mod_authorized() and not _test_mod_bot_movement:
			tank.call("update_movement", Vector2.ZERO, delta)
			continue
		var target_key := _nearest_enemy_key_for(combatant_key)
		if target_key.is_empty():
			tank.call("update_movement", Vector2.ZERO, delta)
			continue
		var target_position := _combatant_position(target_key)
		var to_target := target_position - tank.global_position
		var distance_to_target := to_target.length()
		if float(combatant.get("stun_remaining", 0.0)) > 0.0:
			tank.call("update_movement", Vector2.ZERO, delta)
			continue
		tank.call("aim_cannon_at", target_position)
		var movement_direction := Vector2.ZERO
		var attack_range := maxf(
			float(combatant.get("attack_range", IRONMAN_BASE_ATTACK_RANGE)),
			1.0
		)
		var allow_test_bot_movement := (
			_is_test_mod_authorized() and _test_mod_bot_movement
		)
		if (
			(not TEST_BOTS_STATIONARY or allow_test_bot_movement)
			and distance_to_target > attack_range * 0.8
		):
			movement_direction = to_target.normalized()
			var move_speed := maxf(
				float(combatant.get("move_speed", IRONMAN_BASE_MOVE_SPEED)),
				0.0
			) * (
				1.0 - clampf(float(combatant.get("slow_value", 0.0)), 0.0, 1.0)
			)
			if float(combatant.get("revive_speed_remaining", 0.0)) > 0.0:
				move_speed *= 1.0 + maxf(
					float(combatant.get("revive_speed_percent", 0.0)),
					0.0
				) / 100.0
			var previous_position := tank.position
			tank.position = _move_player_with_collision(
				previous_position,
				movement_direction * move_speed * delta
			)
			var displacement := tank.position - previous_position
			if not displacement.is_zero_approx():
				movement_direction = displacement.normalized()
		tank.call("update_movement", movement_direction, delta)
		var shot_cooldown := maxf(
			float(combatant.get("bot_shot_cooldown", 0.0)) - delta,
			0.0
		)
		combatant["bot_shot_cooldown"] = shot_cooldown
		if distance_to_target <= attack_range and shot_cooldown <= 0.0:
			_shoot_bot(combatant_key, target_key, combatant)
			combatant["bot_shot_cooldown"] = 60.0 / maxf(
				float(combatant.get("fire_rate", IRONMAN_BASE_FIRE_RATE)),
				1.0
			)
		_combatants[combatant_key] = combatant


func _process_chief_ai(delta: float) -> void:
	if _server_authoritative_battle:
		return
	for combatant_key_value: Variant in _combatants.keys():
		var combatant_key := String(combatant_key_value)
		var combatant: Dictionary = _combatants[combatant_key]
		if (
			not bool(combatant.get("is_chief", false))
			or bool(combatant.get("dead", false))
		):
			continue
		var chief := combatant.get("tank") as Node2D
		if not is_instance_valid(chief):
			continue
		var cooldown := maxf(
			float(combatant.get("chief_shot_cooldown", 0.0)) - delta,
			0.0
		)
		var burst_break := maxf(
			float(combatant.get("chief_burst_break_remaining", 0.0)) - delta,
			0.0
		)
		combatant["chief_shot_cooldown"] = cooldown
		combatant["chief_burst_break_remaining"] = burst_break
		if float(combatant.get("stun_remaining", 0.0)) > 0.0:
			chief.call("stop_movement")
			_combatants[combatant_key] = combatant
			continue
		var target_key := _nearest_enemy_tank_in_range(
			combatant_key,
			maxf(float(combatant.get("attack_range", 0.0)), 0.0)
		)
		var burst_remaining := int(
			combatant.get("chief_burst_remaining", 0)
		)
		if burst_remaining <= 0 and cooldown <= 0.0 and not target_key.is_empty():
			burst_remaining = maxi(
				int(combatant.get("burst_shots", CHIEF_CATALOG.BURST_SHOTS)),
				1
			)
			burst_break = 0.0
		if burst_remaining > 0:
			if target_key.is_empty():
				burst_remaining = 0
				burst_break = 0.0
			else:
				var target_position := _combatant_position(target_key)
				chief.call("stop_movement")
				chief.call("face_target", target_position)
				if burst_break <= 0.0:
					_fire_chief(combatant_key, target_key, combatant)
					burst_remaining -= 1
					if burst_remaining > 0:
						burst_break = maxf(
							float(
								combatant.get(
									"burst_break_seconds",
									CHIEF_CATALOG.BURST_BREAK_SECONDS
								)
							),
							0.01
						)
					else:
						cooldown = maxf(
							float(
								combatant.get(
									"attack_interval_seconds",
									CHIEF_CATALOG.ATTACK_INTERVAL_SECONDS
								)
							),
							0.05
						)
		else:
			var slow_multiplier := 1.0 - clampf(
				float(combatant.get("slow_value", 0.0)),
				0.0,
				1.0
			)
			var patrol_motion: Vector2 = chief.call(
				"get_patrol_motion",
				delta,
				maxf(float(combatant.get("move_speed", 0.0)), 0.0)
				* slow_multiplier
			)
			var patrol_start := chief.global_position
			var patrol_end := _move_player_motion_with_slide(
				patrol_start,
				patrol_motion
			)
			chief.call("apply_patrol_position", patrol_end, delta)
			var actual_motion := patrol_end - patrol_start
			if (
				patrol_motion.length_squared() > 0.0001
				and actual_motion.dot(patrol_motion.normalized())
				< patrol_motion.length() - 0.05
			):
				chief.call("reverse_patrol_direction")
		combatant["chief_shot_cooldown"] = cooldown
		combatant["chief_burst_remaining"] = burst_remaining
		combatant["chief_burst_break_remaining"] = burst_break
		_combatants[combatant_key] = combatant


func _fire_chief(
	combatant_key: String,
	target_key: String,
	combatant: Dictionary
) -> void:
	if not _combatants.has(target_key):
		return
	var target: Dictionary = _combatants[target_key]
	if bool(target.get("dead", false)):
		return
	var chief := combatant.get("tank") as Node2D
	if not is_instance_valid(chief):
		return
	var target_position := _combatant_position(target_key)
	var start_position: Vector2 = chief.call(
		"get_projectile_start",
		target_position
	)
	var direction := (target_position - start_position).normalized()
	if direction.is_zero_approx():
		return
	var projectile := CHIEF_PROJECTILE_SCENE.instantiate() as Node2D
	if projectile == null:
		return
	_projectiles.add_child(projectile)
	projectile.call(
		"configure",
		start_position,
		direction,
		maxf(float(combatant.get("attack_range", CHIEF_CATALOG.ATTACK_RANGE)), 1.0),
		CHIEF_CATALOG.PROJECTILE_SPEED
	)
	projectile.connect(
		"advanced",
		_on_chief_projectile_advanced.bind(projectile, combatant_key)
	)
	projectile.connect(
		"expired",
		_on_chief_projectile_expired.bind(projectile)
	)


func _on_chief_projectile_advanced(
	start: Vector2,
	finish: Vector2,
	projectile: Node2D,
	shooter_key: String
) -> void:
	if not is_instance_valid(projectile) or not _combatants.has(shooter_key):
		return
	var shooter: Dictionary = _combatants[shooter_key]
	var terrain_fraction := _first_terrain_hit_fraction(start, finish)
	var impact_key := _first_enemy_hit_on_segment_for_team(
		start,
		finish,
		int(shooter.get("team_no", 0)),
		false
	)
	var impact_fraction := INF
	if not impact_key.is_empty():
		impact_fraction = clampf(
			_combatant_hit_fraction(start, finish, impact_key),
			0.0,
			1.0
		)
	if terrain_fraction < impact_fraction:
		projectile.global_position = start.lerp(finish, terrain_fraction)
		projectile.call("impact")
		_play_normal_bullet_impact(projectile.global_position)
		return
	if is_inf(impact_fraction):
		return
	projectile.global_position = start.lerp(finish, impact_fraction)
	projectile.call("impact")
	_play_normal_bullet_impact(projectile.global_position)
	_deal_damage(
		shooter_key,
		impact_key,
		float(shooter.get("basic_attack_damage", CHIEF_CATALOG.BASIC_ATTACK_DAMAGE)),
		DAMAGE_TYPE_PHYSICAL
	)


func _on_chief_projectile_expired(
	impact_position: Vector2,
	projectile: Node2D
) -> void:
	if not is_instance_valid(projectile):
		return
	_play_normal_bullet_impact(impact_position)


func _process_turret_ai(delta: float) -> void:
	if _server_authoritative_battle:
		return
	for combatant_key_value: Variant in _combatants.keys():
		var combatant_key := String(combatant_key_value)
		var combatant: Dictionary = _combatants[combatant_key]
		if (
			not bool(combatant.get("is_map_object", false))
			or not bool(combatant.get("is_structure", false))
			or not bool(combatant.get("can_attack", false))
			or bool(combatant.get("dead", false))
		):
			continue
		var turret := combatant.get("tank") as Node2D
		if not is_instance_valid(turret):
			continue
		var cooldown := maxf(
			float(combatant.get("turret_shot_cooldown", 0.0)) - delta,
			0.0
		)
		combatant["turret_shot_cooldown"] = cooldown
		var target_key := _nearest_enemy_tank_in_range(
			combatant_key,
			maxf(float(combatant.get("attack_range", 0.0)), 0.0)
		)
		if not target_key.is_empty():
			turret.call("aim_gun_at", _combatant_position(target_key))
			if cooldown <= 0.0:
				_fire_turret(combatant_key, target_key, combatant)
				combatant["turret_shot_cooldown"] = maxf(
					float(combatant.get("attack_interval_seconds", 1.0)),
					0.05
				)
		_combatants[combatant_key] = combatant


func _nearest_enemy_tank_in_range(
	combatant_key: String,
	attack_range: float
) -> String:
	if not _combatants.has(combatant_key) or attack_range <= 0.0:
		return ""
	var source: Dictionary = _combatants[combatant_key]
	var source_team := int(source.get("team_no", 0))
	var source_position := _combatant_position(combatant_key)
	var nearest_key := ""
	var nearest_distance := INF
	for target_key_value: Variant in _combatants.keys():
		var target_key := String(target_key_value)
		var target: Dictionary = _combatants[target_key]
		if (
			target_key == combatant_key
			or bool(target.get("dead", false))
			or bool(target.get("is_map_object", false))
			or int(target.get("team_no", 0)) == source_team
		):
			continue
		var distance_to_target := source_position.distance_to(
			_combatant_position(target_key)
		)
		if distance_to_target <= attack_range and distance_to_target < nearest_distance:
			nearest_distance = distance_to_target
			nearest_key = target_key
	return nearest_key


func _fire_turret(
	combatant_key: String,
	target_key: String,
	combatant: Dictionary
) -> void:
	if not _combatants.has(target_key):
		return
	var target: Dictionary = _combatants[target_key]
	if bool(target.get("dead", false)):
		return
	var turret := combatant.get("tank") as Node2D
	if not is_instance_valid(turret):
		return
	var target_position := _combatant_position(target_key)
	var muzzle_position: Vector2 = turret.call(
		"get_turret_muzzle_position",
		target_position
	)
	var shot_direction := (target_position - muzzle_position).normalized()
	if shot_direction.is_zero_approx():
		return
	turret.call("play_turret_shot", target_position)
	var projectile := TURRET_PROJECTILE_SCENE.instantiate() as Node2D
	if projectile == null:
		return
	_projectiles.add_child(projectile)
	projectile.call(
		"configure",
		muzzle_position,
		shot_direction,
		maxf(float(combatant.get("attack_range", 0.0)), 1.0),
		String(combatant.get("building_kind", ""))
		== BUILDING_CATALOG.KIND_MISSILE,
		int(combatant.get("team_no", 0)) == _viewer_team_no
	)
	projectile.connect(
		"advanced",
		_on_turret_projectile_advanced.bind(projectile, combatant_key)
	)
	projectile.connect(
		"expired",
		_on_turret_projectile_expired.bind(projectile)
	)


func _on_turret_projectile_advanced(
	start: Vector2,
	finish: Vector2,
	projectile: Node2D,
	shooter_key: String
) -> void:
	if not is_instance_valid(projectile) or not _combatants.has(shooter_key):
		return
	var shooter: Dictionary = _combatants[shooter_key]
	var terrain_fraction := _first_terrain_hit_fraction(start, finish)
	var impact_key := _first_enemy_hit_on_segment_for_team(
		start,
		finish,
		int(shooter.get("team_no", 0)),
		false
	)
	var impact_fraction := INF
	if not impact_key.is_empty():
		impact_fraction = clampf(
			_combatant_hit_fraction(start, finish, impact_key),
			0.0,
			1.0
		)
	if terrain_fraction < impact_fraction:
		projectile.global_position = start.lerp(finish, terrain_fraction)
		projectile.call("impact")
		# Blue `normal_bullet_blow02` is only for a tank's regular shell hitting
		# terrain. Turret structures stop here too, but retain their own regular
		# shell impact instead of borrowing the tank-only blue effect.
		_play_normal_bullet_impact(projectile.global_position)
		return
	if is_inf(impact_fraction):
		return
	projectile.global_position = start.lerp(finish, impact_fraction)
	projectile.call("impact")
	_play_normal_bullet_impact(projectile.global_position)
	_deal_damage(
		shooter_key,
		impact_key,
		float(shooter.get("basic_attack_damage", 0.0)),
		DAMAGE_TYPE_PHYSICAL
	)


func _on_turret_projectile_expired(
	impact_position: Vector2,
	projectile: Node2D
) -> void:
	if not is_instance_valid(projectile):
		return
	# A shot which misses a tank reaches ground at its range endpoint. It still
	# plays the original impact but has no target and therefore deals no damage.
	_play_normal_bullet_impact(impact_position)


func _play_normal_bullet_impact(impact_position: Vector2) -> void:
	# BulletExhibit id 1 links the original normal shell to this exact source
	# impact timeline, so the end-of-flight effect is not a synthetic image.
	var impact_effect := _play_timeline_effect(
		EFFECT_NORMAL_BULLET_BLOW,
		impact_position
	)
	# Map foreground is z=10. The impact must be visible at the hit point while
	# remaining below HUD z=20, not hidden behind foliage/props.
	impact_effect.z_as_relative = false
	impact_effect.z_index = 11


func _play_wall_bullet_impact(impact_position: Vector2) -> void:
	var impact_effect := _play_timeline_effect(
		EFFECT_NORMAL_BULLET_WALL_BLOW,
		impact_position,
		0.0,
		false,
		null,
		NORMAL_BULLET_WALL_STAGE_CENTER
	)
	# Map foreground is z=10 and HUD is z=20. Keep the blue wall flash at the
	# actual obstacle contact point without allowing it to cover HUD controls.
	impact_effect.z_as_relative = false
	impact_effect.z_index = 11


func _nearest_enemy_key_for(combatant_key: String) -> String:
	if not _combatants.has(combatant_key):
		return ""
	var source: Dictionary = _combatants[combatant_key]
	var source_team := int(source.get("team_no", 0))
	var source_position := _combatant_position(combatant_key)
	var nearest_key := ""
	var nearest_distance := INF
	for target_key_variant in _combatants.keys():
		var target_key := String(target_key_variant)
		var target: Dictionary = _combatants[target_key]
		if (
			target_key == combatant_key
			or bool(target.get("dead", false))
			or bool(target.get("is_map_object", false))
			or int(target.get("team_no", 0)) == source_team
		):
			continue
		var distance_to_target := source_position.distance_to(
			_combatant_position(target_key)
		)
		if distance_to_target < nearest_distance:
			nearest_distance = distance_to_target
			nearest_key = target_key
	return nearest_key


func _shoot_bot(
	combatant_key: String,
	_target_key: String,
	combatant: Dictionary
) -> void:
	var tank := combatant.get("tank") as Node2D
	if not is_instance_valid(tank):
		return
	var shot_value: Variant = tank.call("fire")
	if shot_value is not Dictionary:
		return
	var shot_data: Dictionary = shot_value
	var position_value: Variant = shot_data.get("position", Vector2.ZERO)
	var direction_value: Variant = shot_data.get("direction", Vector2.ZERO)
	if position_value is not Vector2 or direction_value is not Vector2:
		return
	var projectile := PROJECTILE_SCENE.instantiate() as Node2D
	if projectile == null:
		return
	_projectiles.add_child(projectile)
	projectile.call(
		"configure",
		position_value,
		direction_value,
		maxf(
			float(combatant.get("attack_range", IRONMAN_BASE_ATTACK_RANGE)),
			1.0
		)
	)
	projectile.connect(
		"advanced",
		_on_bot_projectile_advanced.bind(projectile, combatant_key)
	)
	projectile.connect("impact_started", _on_basic_projectile_impact)
	projectile.connect(
		"terrain_impact_started",
		_on_basic_projectile_wall_impact
	)


func _on_bot_projectile_advanced(
	start: Vector2,
	finish: Vector2,
	projectile: Node2D,
	shooter_key: String
) -> void:
	if not is_instance_valid(projectile) or not _combatants.has(shooter_key):
		return
	var shooter: Dictionary = _combatants[shooter_key]
	var terrain_fraction := _first_terrain_hit_fraction(start, finish)
	var impact_key := _first_enemy_hit_on_segment_for_team(
		start,
		finish,
		int(shooter.get("team_no", 0)),
		true
	)
	var impact_fraction := INF
	if not impact_key.is_empty():
		impact_fraction = clampf(
			_combatant_hit_fraction(start, finish, impact_key),
			0.0,
		1.0
		)
	if terrain_fraction < impact_fraction:
		projectile.global_position = start.lerp(finish, terrain_fraction)
		projectile.call("impact", true)
		return
	if is_inf(impact_fraction):
		return
	projectile.global_position = start.lerp(finish, impact_fraction)
	projectile.call("impact")
	_deal_damage(
		shooter_key,
		impact_key,
		float(shooter.get("basic_attack_damage", IRONMAN_BASE_BASIC_ATTACK_DAMAGE))
	)


func _combatant_position(combatant_key: String) -> Vector2:
	var combatant: Dictionary = _combatants.get(combatant_key, {})
	var tank := combatant.get("tank") as Node2D
	return tank.global_position if is_instance_valid(tank) else Vector2.ZERO


func _deal_damage(
	attacker_key: String,
	target_key: String,
	raw_damage: float,
	damage_type := ""
) -> int:
	if _server_authoritative_battle:
		return 0
	if raw_damage <= 0.0 or not _combatants.has(target_key):
		return 0
	if (
		target_key == "player"
		and _is_test_mod_authorized()
		and _test_mod_invincible
	):
		return 0
	var attacker: Dictionary = _combatants.get(attacker_key, {})
	var target: Dictionary = _combatants[target_key]
	if bool(target.get("dead", false)) or float(
		target.get("respawn_invulnerability_remaining", 0.0)
	) > 0.0:
		return 0
	var resolved_damage_type := damage_type.to_lower()
	if resolved_damage_type.is_empty():
		resolved_damage_type = String(
			attacker.get("damage_type", DAMAGE_TYPE_PHYSICAL)
		).to_lower()
	if resolved_damage_type != DAMAGE_TYPE_ENERGY:
		resolved_damage_type = DAMAGE_TYPE_PHYSICAL
	var critical := false
	var adjusted_damage := raw_damage
	var critical_chance := clampf(
		float(
			attacker.get(
				"critical_chance_percent",
				IRONMAN_BASE_CRITICAL_CHANCE_PERCENT
			)
		),
		0.0,
		100.0
	)
	if critical_chance > 0.0 and randf() * 100.0 < critical_chance:
		critical = true
		adjusted_damage *= maxf(
			float(
				attacker.get(
					"critical_damage_percent",
					IRONMAN_BASE_CRITICAL_DAMAGE_PERCENT
				)
			) / 100.0,
			1.0
		)
	var defence := float(
		target.get(
			"energy_shield" if resolved_damage_type == DAMAGE_TYPE_ENERGY else "physical_armor",
			IRONMAN_BASE_ENERGY_SHIELD if resolved_damage_type == DAMAGE_TYPE_ENERGY else IRONMAN_BASE_PHYSICAL_ARMOR
		)
	)
	# Xuyên only pierces physical armour. Energy damage is reduced by KHIÊN NL.
	defence = maxf(
		defence - maxf(float(attacker.get("penetration", 0.0)), 0.0),
		0.0
	)
	var mitigated_damage := adjusted_damage * (
		DEFENCE_REDUCTION_SCALE / (DEFENCE_REDUCTION_SCALE + defence)
	)
	# Tia Tan Rã grants its documented 50% reduction against energy damage
	# during the channel. Physical hits still use normal armour mitigation.
	if (
		resolved_damage_type == DAMAGE_TYPE_ENERGY
		and target_key == "player"
		and not _skill_channel.is_empty()
	):
		mitigated_damage *= 0.5
	_record_damage_contribution(attacker_key, target_key)
	return _apply_damage(
		target_key,
		mitigated_damage,
		critical,
		attacker_key
	)


func _apply_damage(
	combatant_key: String,
	damage: float,
	critical: bool = false,
	attacker_key := ""
) -> int:
	if not _combatants.has(combatant_key):
		return 0
	# Keep the sandbox invincibility guard at the final shared damage entry too,
	# so future damage sources cannot bypass the higher-level _deal_damage path.
	if (
		combatant_key == "player"
		and _is_test_mod_authorized()
		and _test_mod_invincible
	):
		return 0
	var combatant: Dictionary = _combatants[combatant_key]
	if bool(combatant.get("dead", false)):
		return 0
	var previous_health := int(combatant.get("hit_points", 0))
	var actual_damage := mini(maxi(roundi(damage), 0), previous_health)
	if bool(combatant.get("is_player", false)) and _ironman_shield_points > 0:
		var absorbed_damage := mini(_ironman_shield_points, actual_damage)
		_ironman_shield_points -= absorbed_damage
		actual_damage -= absorbed_damage
		if _ironman_shield_points <= 0:
			_break_ironman_shield()
	if actual_damage <= 0:
		return 0
	if bool(combatant.get("is_map_object", false)):
		var building := combatant.get("tank") as Node2D
		if not is_instance_valid(building):
			return 0
		actual_damage = int(building.call("apply_damage", actual_damage))
		if actual_damage <= 0:
			return 0
		var building_health := int(building.call("get_hit_points"))
		combatant["hit_points"] = building_health
		combatant["dead"] = building_health <= 0
		_combatants[combatant_key] = combatant
		_spawn_damage_number(combatant_key, actual_damage, critical)
		return actual_damage
	var current_health := previous_health - actual_damage
	combatant["hit_points"] = current_health
	if current_health <= 0:
		combatant["dead"] = true
	_combatants[combatant_key] = combatant
	var tank := combatant.get("tank") as Node2D
	if bool(combatant.get("is_player", false)):
		_current_hit_points = current_health
		_update_health_hud()
	elif is_instance_valid(tank):
		tank.call(
			"set_health",
			current_health,
			int(combatant.get("maximum_health", 1))
		)
	if current_health <= 0:
		if bool(combatant.get("is_neutral_footpoint", false)):
			_spawn_damage_number(combatant_key, actual_damage, critical)
			_handle_neutral_footpoint_death(combatant_key)
			return actual_damage
		_play_combatant_death_effect(combatant_key)
		if is_instance_valid(tank):
			tank.visible = false
		if bool(combatant.get("is_player", false)):
			_control_enabled = false
			_reset_firing()
			_finish_tia_tan_ra(false)
		_register_combatant_death(attacker_key, combatant_key)
		if not _battle_finished:
			_begin_respawn(combatant_key)
	_spawn_damage_number(combatant_key, actual_damage, critical)
	return actual_damage


func _record_damage_contribution(
	attacker_key: String,
	target_key: String
) -> void:
	if (
		attacker_key == target_key
		or not _combatants.has(attacker_key)
		or not _combatants.has(target_key)
	):
		return
	var attacker: Dictionary = _combatants[attacker_key]
	var target: Dictionary = _combatants[target_key]
	if bool(attacker.get("is_map_object", false)) or bool(target.get("is_map_object", false)):
		return
	if bool(target.get("is_chief", false)):
		return
	if int(attacker.get("team_no", 0)) == int(target.get("team_no", 0)):
		return
	var contributors: Dictionary = target.get("damage_contributors", {})
	contributors[attacker_key] = _battle_elapsed_seconds
	target["damage_contributors"] = contributors
	_combatants[target_key] = target


func _register_combatant_death(
	killer_key: String,
	victim_key: String
) -> void:
	if not _combatants.has(victim_key):
		return
	var victim: Dictionary = _combatants[victim_key]
	var victim_is_chief := bool(victim.get("is_chief", false))
	var killer_is_enemy := false
	if (
		not killer_key.is_empty()
		and killer_key != victim_key
		and _combatants.has(killer_key)
	):
		killer_is_enemy = int(
			(_combatants[killer_key] as Dictionary).get("team_no", 0)
		) != int(victim.get("team_no", 0))
	if killer_is_enemy:
		_award_score_for_combatant_death(killer_key, victim_key)
	# Chiefs are score-bearing monsters, not tanks. Their deaths must never
	# enter tank K/D/A statistics or grant contributor assists.
	if victim_is_chief:
		victim["damage_contributors"] = {}
		_combatants[victim_key] = victim
		_update_kda_hud()
		return
	victim["deaths"] = int(victim.get("deaths", 0)) + 1
	if (
		not killer_key.is_empty()
		and killer_key != victim_key
		and _combatants.has(killer_key)
	):
		var killer: Dictionary = _combatants[killer_key]
		if killer_is_enemy:
			killer["kills"] = int(killer.get("kills", 0)) + 1
			_combatants[killer_key] = killer
	if killer_is_enemy:
		var contributors: Dictionary = victim.get("damage_contributors", {})
		for contributor_key_value: Variant in contributors.keys():
			var contributor_key := String(contributor_key_value)
			if contributor_key == killer_key or not _combatants.has(contributor_key):
				continue
			if _battle_elapsed_seconds - float(contributors[contributor_key]) > ASSIST_CONTRIBUTION_SECONDS:
				continue
			var contributor: Dictionary = _combatants[contributor_key]
			if int(contributor.get("team_no", 0)) != int(
				_combatants[killer_key].get("team_no", 0)
			):
				continue
			contributor["assists"] = int(contributor.get("assists", 0)) + 1
			_combatants[contributor_key] = contributor
	victim["damage_contributors"] = {}
	_combatants[victim_key] = victim
	_update_kda_hud()


func _award_score_for_combatant_death(
	killer_key: String,
	victim_key: String
) -> void:
	if not _combatants.has(killer_key) or not _combatants.has(victim_key):
		return
	var killer: Dictionary = _combatants[killer_key]
	var victim: Dictionary = _combatants[victim_key]
	if (
		bool(victim.get("is_map_object", false))
		or bool(victim.get("is_neutral_footpoint", false))
	):
		return
	var killer_team := int(killer.get("team_no", 0))
	var victim_team := int(victim.get("team_no", 0))
	if killer_team not in [1, 2] or victim_team not in [1, 2]:
		return
	if killer_team == victim_team:
		return
	var is_chief := bool(victim.get("is_chief", false))
	var rule_key := "chief_kill_points" if is_chief else "tank_kill_points"
	var reason := "chief_kill" if is_chief else "tank_kill"
	_add_team_score(killer_team, int(_battle_rules.get(rule_key, 1)), reason)


func _begin_respawn(combatant_key: String) -> void:
	if not _combatants.has(combatant_key):
		return
	if (
		combatant_key == "player"
		and _is_test_mod_authorized()
		and _test_mod_player_respawn
	):
		# Respawn synchronously so RespawnOverlay never becomes visible for even
		# one frame when the TEST option is active.
		_respawn_combatant(combatant_key)
		return
	var combatant: Dictionary = _combatants[combatant_key]
	combatant["respawn_remaining"] = maxf(
		float(combatant.get("respawn_seconds", RESPAWN_SECONDS)),
		0.0
	)
	combatant["respawn_invulnerability_remaining"] = 0.0
	_combatants[combatant_key] = combatant
	_update_respawn_hud()


func _process_respawn_runtime(delta: float) -> void:
	if _server_authoritative_battle:
		_update_respawn_hud()
		return
	for combatant_key_value: Variant in _combatants.keys():
		var combatant_key := String(combatant_key_value)
		var combatant: Dictionary = _combatants[combatant_key]
		if bool(combatant.get("is_map_object", false)):
			continue
		if bool(combatant.get("dead", false)):
			combatant["respawn_remaining"] = maxf(
				float(combatant.get("respawn_remaining", 0.0)) - delta,
				0.0
			)
			_combatants[combatant_key] = combatant
			if float(combatant["respawn_remaining"]) <= 0.0:
				_respawn_combatant(combatant_key)
			continue
		var revive_speed_remaining := maxf(
			float(combatant.get("revive_speed_remaining", 0.0)) - delta,
			0.0
		)
		combatant["revive_speed_remaining"] = revive_speed_remaining
		var immunity_remaining := float(
			combatant.get("respawn_invulnerability_remaining", 0.0)
		)
		if immunity_remaining <= 0.0:
			_combatants[combatant_key] = combatant
			continue
		immunity_remaining = maxf(immunity_remaining - delta, 0.0)
		combatant["respawn_invulnerability_remaining"] = immunity_remaining
		if immunity_remaining <= 0.0:
			var protection_effect: Variant = combatant.get("respawn_protection_effect")
			if is_instance_valid(protection_effect):
				protection_effect.queue_free()
			combatant.erase("respawn_protection_effect")
		_combatants[combatant_key] = combatant
	_update_respawn_hud()


func _respawn_combatant(combatant_key: String) -> void:
	if not _combatants.has(combatant_key):
		return
	var combatant: Dictionary = _combatants[combatant_key]
	var tank := combatant.get("tank") as Node2D
	if not is_instance_valid(tank):
		return
	var spawn_position: Vector2 = combatant.get("spawn_position", tank.global_position)
	if bool(combatant.get("is_player", false)):
		_player_anchor.global_position = spawn_position
	else:
		tank.global_position = spawn_position
	var maximum_health := maxi(int(combatant.get("maximum_health", 1)), 1)
	var is_chief := bool(combatant.get("is_chief", false))
	combatant["hit_points"] = maximum_health
	combatant["dead"] = false
	combatant["respawn_remaining"] = 0.0
	combatant["respawn_invulnerability_remaining"] = (
		0.0 if is_chief else RESPAWN_PROTECTION_SECONDS
	)
	combatant["bot_shot_cooldown"] = 0.0
	combatant["slow_remaining"] = 0.0
	combatant["slow_value"] = 0.0
	combatant["slow_tick_remaining"] = 0.0
	combatant["slow_recovery"] = 0.0
	combatant["e_slow_remaining"] = 0.0
	combatant["stun_remaining"] = 0.0
	combatant["chief_shot_cooldown"] = 0.0
	combatant["chief_burst_remaining"] = 0
	combatant["chief_burst_break_remaining"] = 0.0
	combatant["revive_speed_remaining"] = maxf(
		float(combatant.get("revive_duration_seconds", 0.0)),
		0.0
	)
	tank.visible = true
	if is_chief and tank.has_method("on_respawn"):
		tank.call("on_respawn")
	tank.call("set_health", maximum_health, maximum_health)
	if is_chief:
		var stale_protection: Variant = combatant.get("respawn_protection_effect")
		if is_instance_valid(stale_protection):
			stale_protection.queue_free()
		combatant.erase("respawn_protection_effect")
		_combatants[combatant_key] = combatant
		_update_minimap_marker()
		_update_respawn_hud()
		return
	var protection_effect := _play_timeline_effect(
		EFFECT_RESPAWN_PROTECTION,
		Vector2.ZERO,
		0.0,
		true,
		tank
	)
	protection_effect.z_index = 18
	protection_effect.playback_speed = RESPAWN_PROTECTION_PLAYBACK_SPEED
	combatant["respawn_protection_effect"] = protection_effect
	# Exact 40-frame source face/face_relive_t.swf. Its own timeline already
	# contains the speech bubble position above the revived unit.
	var relive_face := _play_timeline_effect(
		EFFECT_RESPAWN_FACE,
		Vector2.ZERO,
		0.0,
		false,
		tank
	)
	relive_face.z_index = 19
	_combatants[combatant_key] = combatant
	if bool(combatant.get("is_player", false)):
		_current_hit_points = maximum_health
		_control_enabled = true
		_camera_following = true
		_activate_ironman_shield()
		_update_health_hud()
	_update_minimap_marker()
	_update_respawn_hud()


func _on_respawn_now_pressed() -> void:
	if _remaining_free_respawns <= 0 or not _combatants.has("player"):
		return
	var player: Dictionary = _combatants["player"]
	if not bool(player.get("dead", false)):
		return
	if _server_authoritative_battle:
		_enqueue_authoritative_command({"type": "respawn"})
		return
	_remaining_free_respawns -= 1
	_respawn_combatant("player")


func _on_respawn_now_button_hovered(is_hovered: bool) -> void:
	if _respawn_now_button.disabled:
		return
	_animate_respawn_now_button(
		Vector2(1.08, 1.08) if is_hovered else Vector2.ONE,
		Color(1.25, 1.2, 0.72, 1.0) if is_hovered else Color.WHITE,
		0.1
	)


func _on_respawn_now_button_down() -> void:
	if _respawn_now_button.disabled:
		return
	_animate_respawn_now_button(
		Vector2(0.94, 0.94),
		Color(1.35, 1.28, 0.75, 1.0),
		0.05
	)


func _animate_respawn_now_button(
	target_scale: Vector2,
	target_color: Color,
	duration: float
) -> void:
	if _respawn_button_tween != null and _respawn_button_tween.is_valid():
		_respawn_button_tween.kill()
	_respawn_button_tween = create_tween()
	_respawn_button_tween.set_trans(Tween.TRANS_QUAD)
	_respawn_button_tween.set_ease(Tween.EASE_OUT)
	_respawn_button_tween.tween_property(
		_respawn_now_button,
		"scale",
		target_scale,
		duration
	)
	_respawn_button_tween.parallel().tween_property(
		_respawn_now_button,
		"self_modulate",
		target_color,
		duration
	)


func _update_respawn_hud() -> void:
	if not is_instance_valid(_respawn_overlay):
		return
	var player: Dictionary = _combatants.get("player", {})
	var is_dead := bool(player.get("dead", false))
	_respawn_overlay.visible = is_dead
	if not is_dead:
		_respawn_now_button.scale = Vector2.ONE
		_respawn_now_button.self_modulate = Color.WHITE
		return
	var remaining := maxf(float(player.get("respawn_remaining", 0.0)), 0.0)
	_respawn_count_label.text = "Còn %d s hồi sinh" % ceili(remaining)
	_respawn_free_label.text = "Lượt hồi sinh miễn phí còn lại: %d" % _remaining_free_respawns
	_respawn_now_button.disabled = _remaining_free_respawns <= 0
	# Keep the original button visible at zero free revives. It remains inert
	# until a later paid/VIP revive flow is implemented.
	_respawn_now_button.visible = true


func _update_kda_hud() -> void:
	if not is_instance_valid(_kda_label):
		return
	var player: Dictionary = _combatants.get("player", {})
	_kda_label.text = "K/D/A  %d/%d/%d" % [
		int(player.get("kills", 0)),
		int(player.get("deaths", 0)),
		int(player.get("assists", 0)),
	]


func _play_combatant_death_effect(combatant_key: String) -> void:
	var death_position := _combatant_position(combatant_key)
	var combatant: Dictionary = _combatants.get(combatant_key, {})
	if bool(combatant.get("is_chief", false)):
		_play_timeline_effect(EFFECT_CHIEF_DEATH, death_position)
		return
	_play_timeline_effect(EFFECT_IRONMAN_DEATH_BLOW, death_position)
	_play_timeline_effect(EFFECT_IRONMAN_DEATH, death_position)


func _spawn_damage_number(
	combatant_key: String,
	damage: int,
	critical: bool
) -> void:
	if damage <= 0 or _damage_numbers == null:
		return
	var tank_position := _combatant_position(combatant_key)
	var sequence := int(_damage_number_sequences.get(combatant_key, 0))
	_damage_number_sequences[combatant_key] = sequence + 1
	var lane_offset := float(
		DAMAGE_NUMBER_LANE_OFFSETS[
			sequence % DAMAGE_NUMBER_LANE_OFFSETS.size()
		]
	)
	var popup := DAMAGE_NUMBER_SCRIPT.new() as Node2D
	if popup == null:
		return
	popup.z_index = 50
	popup.global_position = (
		tank_position
		+ Vector2(lane_offset, DAMAGE_NUMBER_OFFSET_Y)
	)
	_damage_numbers.add_child(popup)
	popup.call("show_damage", damage, critical)


func _clear_damage_numbers() -> void:
	_damage_number_sequences.clear()
	if _damage_numbers == null:
		return
	for popup: Node in _damage_numbers.get_children():
		_damage_numbers.remove_child(popup)
		popup.queue_free()


func _spawn_heal_number(healing: int) -> void:
	if healing <= 0 or _damage_numbers == null:
		return
	var sequence_key := "heal:player"
	var sequence := int(_damage_number_sequences.get(sequence_key, 0))
	_damage_number_sequences[sequence_key] = sequence + 1
	var lane_offset := float(
		DAMAGE_NUMBER_LANE_OFFSETS[
			sequence % DAMAGE_NUMBER_LANE_OFFSETS.size()
		]
	)
	var popup := DAMAGE_NUMBER_SCRIPT.new() as Node2D
	if popup == null:
		return
	popup.z_index = 50
	popup.global_position = (
		_player_anchor.global_position
		+ Vector2(lane_offset, HEAL_NUMBER_OFFSET_Y)
	)
	_damage_numbers.add_child(popup)
	popup.call("show_heal", healing)


func _heal_player(amount: int) -> void:
	if _server_authoritative_battle:
		return
	if amount <= 0 or not _combatants.has("player"):
		return
	var combatant: Dictionary = _combatants["player"]
	var previous_health := int(combatant.get("hit_points", 0))
	var current_health := mini(
		previous_health + amount,
		int(combatant.get("maximum_health", 1))
	)
	combatant["hit_points"] = current_health
	_combatants["player"] = combatant
	_current_hit_points = current_health
	_update_health_hud()
	_spawn_heal_number(current_health - previous_health)


func _activate_ironman_shield() -> void:
	if _max_hit_points <= 0:
		return
	_ironman_shield_points = maxi(roundi(float(_max_hit_points) * IRONMAN_SHIELD_RATIO), 1)
	_ironman_shield_recharge_remaining = 0.0
	if is_instance_valid(_ironman_shield_effect):
		_ironman_shield_effect.queue_free()
	_ironman_shield_effect = _play_timeline_effect(
		EFFECT_BUFF_GANGTIE02,
		Vector2.ZERO,
		0.0,
		true,
		_player_anchor
	)
	_ironman_shield_effect.z_index = 2
	_shield_buff_icon.visible = true


func _break_ironman_shield() -> void:
	_ironman_shield_points = 0
	_ironman_shield_recharge_remaining = IRONMAN_SHIELD_RECHARGE_SECONDS
	if is_instance_valid(_ironman_shield_effect):
		_ironman_shield_effect.queue_free()
	_ironman_shield_effect = null
	_shield_buff_icon.visible = false
	_play_timeline_effect(
		EFFECT_BUFF_GANGTIE03,
		_player_anchor.global_position
	)
	for combatant_key in _enemy_keys_in_radius(
		_player_anchor.global_position,
		IRONMAN_SHIELD_BREAK_RADIUS
	):
		_deal_damage(
			"player",
			combatant_key,
			_tank_basic_attack_damage * IRONMAN_SHIELD_BREAK_DAMAGE_RATIO
		)


func _process_ironman_shield(delta: float) -> void:
	if _server_authoritative_battle:
		return
	if _ironman_shield_points > 0 or _ironman_shield_recharge_remaining <= 0.0:
		return
	_ironman_shield_recharge_remaining = maxf(
		_ironman_shield_recharge_remaining - delta,
		0.0
	)
	if _ironman_shield_recharge_remaining <= 0.0:
		_activate_ironman_shield()


func _clear_ironman_shield() -> void:
	_ironman_shield_points = 0
	_ironman_shield_recharge_remaining = 0.0
	if is_instance_valid(_ironman_shield_effect):
		_ironman_shield_effect.queue_free()
	_ironman_shield_effect = null
	if _shield_buff_icon != null:
		_shield_buff_icon.visible = false


func _apply_r_slow(combatant_key: String) -> void:
	_apply_slow(
		combatant_key,
		IRONMAN_R_SLOW_START,
		IRONMAN_R_SLOW_SECONDS,
		IRONMAN_R_SLOW_TICK_SECONDS,
		IRONMAN_R_SLOW_RECOVERY
	)


func _apply_e_slow_marker(combatant_key: String) -> void:
	if not _combatants.has(combatant_key):
		return
	var combatant: Dictionary = _combatants[combatant_key]
	combatant["e_slow_remaining"] = IRONMAN_E_SLOW_SECONDS
	_combatants[combatant_key] = combatant


func _consume_e_slow_marker(combatant_key: String) -> bool:
	if not _combatants.has(combatant_key):
		return false
	var combatant: Dictionary = _combatants[combatant_key]
	if float(combatant.get("e_slow_remaining", 0.0)) <= 0.0:
		return false
	combatant["e_slow_remaining"] = 0.0
	_combatants[combatant_key] = combatant
	return true


func _apply_slow(
	combatant_key: String,
	slow_value: float,
	duration: float,
	recovery_tick := 0.0,
	recovery_value := 0.0
) -> void:
	if not _combatants.has(combatant_key):
		return
	var combatant: Dictionary = _combatants[combatant_key]
	combatant["slow_remaining"] = duration
	combatant["slow_value"] = clampf(slow_value, 0.0, 1.0)
	combatant["slow_tick_remaining"] = recovery_tick
	combatant["slow_recovery"] = recovery_value
	var old_effect: Variant = combatant.get("slow_effect")
	if is_instance_valid(old_effect):
		old_effect.queue_free()
	var tank := combatant.get("tank") as Node2D
	if is_instance_valid(tank):
		combatant["slow_effect"] = _play_timeline_effect(
			EFFECT_SLOW01,
			Vector2.ZERO,
			0.0,
			true,
			tank
		)
	_combatants[combatant_key] = combatant


func _apply_stun(combatant_key: String, duration: float) -> void:
	if not _combatants.has(combatant_key):
		return
	var combatant: Dictionary = _combatants[combatant_key]
	combatant["stun_remaining"] = maxf(
		float(combatant.get("stun_remaining", 0.0)),
		duration
	)
	var old_effect: Variant = combatant.get("stun_effect")
	if is_instance_valid(old_effect):
		old_effect.queue_free()
	var tank := combatant.get("tank") as Node2D
	if is_instance_valid(tank):
		# Buff 363203 (Iron Man E stun) points to the original slow.swf,
		# distinct from the E field's slow01.swf.
		combatant["stun_effect"] = _play_timeline_effect(
			EFFECT_STUN_SLOW,
			Vector2.ZERO,
			0.0,
			true,
			tank
		)
	_combatants[combatant_key] = combatant


func _process_status_effects(delta: float) -> void:
	for combatant_key_variant in _combatants.keys():
		var combatant_key := String(combatant_key_variant)
		var combatant: Dictionary = _combatants[combatant_key]
		if bool(combatant.get("is_map_object", false)):
			continue
		var e_slow_remaining := float(
			combatant.get("e_slow_remaining", 0.0)
		)
		if e_slow_remaining > 0.0:
			combatant["e_slow_remaining"] = maxf(
				e_slow_remaining - delta,
				0.0
			)
		var stun_remaining := float(combatant.get("stun_remaining", 0.0))
		if stun_remaining > 0.0:
			stun_remaining -= delta
			combatant["stun_remaining"] = stun_remaining
			if stun_remaining <= 0.0:
				var stun_effect: Variant = combatant.get("stun_effect")
				if is_instance_valid(stun_effect):
					stun_effect.queue_free()
				combatant.erase("stun_effect")
		var remaining := float(combatant.get("slow_remaining", 0.0))
		if remaining > 0.0:
			remaining -= delta
			combatant["slow_remaining"] = remaining
			var tick_seconds := float(combatant.get("slow_tick_remaining", 0.0))
			if tick_seconds > 0.0:
				tick_seconds -= delta
				while tick_seconds <= 0.0 and remaining > 0.0:
					combatant["slow_value"] = maxf(
						float(combatant.get("slow_value", 0.0))
						- float(combatant.get("slow_recovery", 0.0)),
						0.0
					)
					tick_seconds += IRONMAN_R_SLOW_TICK_SECONDS
				combatant["slow_tick_remaining"] = tick_seconds
			if remaining <= 0.0:
				combatant["slow_value"] = 0.0
				var effect: Variant = combatant.get("slow_effect")
				if is_instance_valid(effect):
					effect.queue_free()
				combatant.erase("slow_effect")
		_combatants[combatant_key] = combatant


func _effective_player_move_speed() -> float:
	var combatant: Dictionary = _combatants.get("player", {})
	var slow_value := clampf(float(combatant.get("slow_value", 0.0)), 0.0, 1.0)
	var revive_multiplier := 1.0
	if float(combatant.get("revive_speed_remaining", 0.0)) > 0.0:
		revive_multiplier += maxf(
			float(combatant.get("revive_speed_percent", 0.0)),
			0.0
		) / 100.0
	return _tank_move_speed * revive_multiplier * (1.0 - slow_value)


func _segment_fraction(
	start: Vector2,
	finish: Vector2,
	point: Vector2
) -> float:
	var segment := finish - start
	var length_squared := segment.length_squared()
	if length_squared <= 0.0001:
		return -1.0
	return (point - start).dot(segment) / length_squared


func _first_terrain_hit_fraction(start: Vector2, finish: Vector2) -> float:
	var result := INF
	for collision_rectangle: Rect2 in _static_collision_rectangles:
		if collision_rectangle.has_point(start):
			return 0.0
		var rectangle_end := collision_rectangle.end
		var corners := [
			collision_rectangle.position,
			Vector2(rectangle_end.x, collision_rectangle.position.y),
			rectangle_end,
			Vector2(collision_rectangle.position.x, rectangle_end.y),
		]
		for corner_index in corners.size():
			var hit: Variant = Geometry2D.segment_intersects_segment(
				start,
				finish,
				corners[corner_index],
				corners[(corner_index + 1) % corners.size()]
			)
			if hit is Vector2:
				result = minf(result, _segment_fraction(start, finish, hit))
	return result


func _play_timeline_effect(
	timeline_path: String,
	position_value: Vector2,
	lifetime := 0.0,
	loop := false,
	parent: Node2D = null,
	content_position_adjust := Vector2.ZERO
) -> Node2D:
	var effect := SwfTimelinePlayer.new()
	effect.timeline_path = timeline_path
	effect.autoplay = true
	effect.loop = loop
	effect.content_position_adjust = content_position_adjust
	effect.position = position_value
	effect.z_index = 1
	var effect_parent := parent if parent != null else _skill_effects
	effect_parent.add_child(effect)
	if lifetime > 0.0:
		get_tree().create_timer(lifetime).timeout.connect(
			_queue_effect_if_valid.bind(effect)
		)
	elif not loop:
		effect.frame_changed.connect(_on_one_shot_effect_frame.bind(effect))
	return effect


func _play_footpoint_template_effect(
	template: SwfTimelinePlayer,
	position_value: Vector2
) -> Node2D:
	var effect := _play_timeline_effect(
		template.timeline_path,
		position_value,
		0.0,
		false,
		null,
		template.content_position_adjust
	)
	effect.scale = template.scale
	effect.rotation = template.rotation
	return effect


func _on_one_shot_effect_frame(
	frame_number: int,
	effect: SwfTimelinePlayer
) -> void:
	if frame_number < effect.get_frame_count():
		return
	get_tree().create_timer(1.0 / 24.0).timeout.connect(
		_queue_effect_if_valid.bind(effect)
	)


func _queue_effect_if_valid(effect: Variant) -> void:
	if is_instance_valid(effect):
		effect.queue_free()


func _clear_skill_runtime() -> void:
	if _skill_targeting != null:
		_cancel_skill_targeting()
	_clear_ironman_shield()
	for combatant_value in _combatants.values():
		if combatant_value is not Dictionary:
			continue
		var combatant: Dictionary = combatant_value
		var slow_effect: Variant = combatant.get("slow_effect")
		if is_instance_valid(slow_effect):
			slow_effect.queue_free()
		var stun_effect: Variant = combatant.get("stun_effect")
		if is_instance_valid(stun_effect):
			stun_effect.queue_free()
		var respawn_protection_effect: Variant = combatant.get(
			"respawn_protection_effect"
		)
		if is_instance_valid(respawn_protection_effect):
			respawn_protection_effect.queue_free()
	_strike_fields.clear()
	_finish_tia_tan_ra(false)
	if _skill_effects != null:
		for effect: Node in _skill_effects.get_children():
			effect.queue_free()


func _reset_skills(tank_data: Dictionary = {}) -> void:
	# XML base CD: R Hạt Năng Lượng 6s, E Đạn Không Kích 8s,
	# Space Tia Tan Rã 20s.  The server may later send a reduced value.
	_skill_cooldown_seconds = [6.0, 8.0, 20.0]
	var skills_value: Variant = tank_data.get("skills", [])
	if skills_value is Array:
		for skill_value: Variant in skills_value:
			if skill_value is not Dictionary:
				continue
			var skill: Dictionary = skill_value
			var slot_index := int(skill.get("slot_index", 0)) - 1
			if slot_index < 0 or slot_index >= _skill_cooldown_seconds.size():
				continue
			var cooldown_seconds := float(skill.get("cooldown_ms", 0.0)) / 1000.0
			if cooldown_seconds > 0.0:
				_skill_cooldown_seconds[slot_index] = maxf(
					cooldown_seconds,
					0.5
				)
	var skill_slots: Array[Control] = [_skill_1, _skill_2, _skill_3]
	for skill_index in skill_slots.size():
		var skill_slot := skill_slots[skill_index]
		skill_slot.call(
			"set_cooldown_seconds",
			_effective_skill_cooldown(skill_index)
		)
		skill_slot.call("reset_ready")


func _update_cannon_aim() -> void:
	_player_tank.call("aim_cannon_at", _world_mouse_position())


func _world_mouse_position() -> Vector2:
	var container_size := _viewport_container.size
	if container_size.x <= 0.0 or container_size.y <= 0.0:
		return _player_anchor.global_position
	var viewport_size := Vector2(_world_viewport.size)
	var local_mouse := _viewport_container.get_local_mouse_position()
	var viewport_mouse := Vector2(
		local_mouse.x * viewport_size.x / container_size.x,
		local_mouse.y * viewport_size.y / container_size.y
	)
	return (
		_camera.get_screen_center_position()
		+ viewport_mouse
		- viewport_size * 0.5
	)


func set_player_health(current_value: int, maximum_value: int) -> void:
	_max_hit_points = maxi(maximum_value, 1)
	_current_hit_points = clampi(current_value, 0, _max_hit_points)
	if _combatants.has("player"):
		var combatant: Dictionary = _combatants["player"]
		combatant["hit_points"] = _current_hit_points
		combatant["maximum_health"] = _max_hit_points
		_combatants["player"] = combatant
	_update_health_hud()


func _update_health_hud() -> void:
	if _hp_fill_clip == null or _hp_value == null:
		return
	var ratio := clampf(
		float(_current_hit_points) / float(_max_hit_points),
		0.0,
		1.0
	)
	_hp_fill_clip.size = Vector2(66.0 * ratio, _hp_fill_clip.size.y)
	_hp_value.text = (
		"[center][color=#d8ff00]%d[/color]"
		+ "[color=#ff6b23]/%d[/color][/center]"
	) % [_current_hit_points, _max_hit_points]
	_player_tank.call(
		"set_health",
		_current_hit_points,
		_max_hit_points
	)


func _update_minimap_marker() -> void:
	_update_minimap_tank_markers()


func _build_battle_roster_ui(
	viewer: Dictionary,
	viewer_tank_data: Dictionary
) -> void:
	_clear_battle_roster_ui()
	var viewer_team := int(viewer.get("team_no", _viewer_team_no))
	var viewer_slot := int(viewer.get("slot_no", 0))
	for participant_value: Variant in _match_data.get("participants", []):
		if participant_value is not Dictionary:
			continue
		var participant: Dictionary = participant_value
		var team_no := int(participant.get("team_no", 0))
		var slot_no := int(participant.get("slot_no", 0))
		if team_no < 1 or team_no > 2 or slot_no < 1 or slot_no > 5:
			continue
		var combatant_key := "participant:%d:%d" % [team_no, slot_no]
		var is_viewer := team_no == viewer_team and slot_no == viewer_slot
		if is_viewer:
			combatant_key = "player"
		var card_data := participant.duplicate(true)
		if is_viewer:
			var merged_viewer_data := viewer_tank_data.duplicate(true)
			merged_viewer_data.merge(card_data, true)
			card_data = merged_viewer_data
		card_data["display_name"] = (
			_viewer_display_name(viewer)
			if is_viewer
			else _participant_display_name(participant, slot_no)
		)
		var icon_texture: Texture2D = IRONMAN_MICRO_HEAD
		var card_parent := _team_state_left if team_no == 1 else _team_state_right
		var card := card_parent.get_node_or_null("Slot%d" % slot_no) as Control
		if card == null:
			# Authored slots are the normal path. This fallback keeps future modes
			# with a larger roster functional without changing the five-card scene.
			card = TEAM_STATE_CARD_SCENE.instantiate() as Control
			card.name = "RuntimeSlot%d" % slot_no
			card.position = Vector2(0.0, float(slot_no - 1) * 72.0)
			card_parent.add_child(card)
		card.visible = true
		card.call(
			"configure",
			card_data,
			team_no == _viewer_team_no,
			team_no == _viewer_team_no,
			icon_texture,
			team_no == 1
		)
		_team_state_cards[combatant_key] = card
		var participant_account_id := String(
			participant.get("account_id", "")
		).strip_edges()
		if not participant_account_id.is_empty():
			_team_state_cards_by_account[participant_account_id] = card
		var participant_name := String(
			card_data.get("display_name", "")
		).strip_edges()
		if not participant_name.is_empty():
			_team_state_cards_by_name[participant_name] = card
		var marker := _create_minimap_tank_marker(
			is_viewer,
			team_no == _viewer_team_no
		)
		_minimap_tank_markers.add_child(marker)
		_minimap_markers[combatant_key] = marker
	_update_battle_roster_ui()


func _create_minimap_tank_marker(
	is_viewer: bool,
	is_friendly: bool
) -> Control:
	var marker := Control.new()
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.size = MINIMAP_TANK_MARKER_SIZE
	var frame := TextureRect.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.size = MINIMAP_TANK_MARKER_SIZE
	frame.texture = (
		MINIMAP_SELF_FRAME
		if is_viewer
		else (MINIMAP_FRIEND_FRAME if is_friendly else MINIMAP_ENEMY_FRAME)
	)
	marker.add_child(frame)
	var head := TextureRect.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.position = (MINIMAP_TANK_MARKER_SIZE - MINIMAP_TANK_HEAD_SIZE) * 0.5
	head.size = MINIMAP_TANK_HEAD_SIZE
	head.texture = IRONMAN_MICRO_HEAD
	marker.add_child(head)
	return marker


func _update_battle_roster_ui() -> void:
	for combatant_key_value: Variant in _team_state_cards.keys():
		var combatant_key := String(combatant_key_value)
		var card := _team_state_cards.get(combatant_key) as Control
		if not is_instance_valid(card) or not _combatants.has(combatant_key):
			continue
		var combatant: Dictionary = _combatants[combatant_key]
		card.call(
			"set_health",
			int(combatant.get("hit_points", 0)),
			int(combatant.get("maximum_health", 1))
		)
		var cooldown_remaining := float(
			combatant.get("space_cooldown_remaining", 0.0)
		)
		if combatant_key == "player" and _skill_3.has_method(
			"get_remaining_seconds"
		):
			cooldown_remaining = float(
				_skill_3.call("get_remaining_seconds")
			)
		card.call("set_space_cooldown", cooldown_remaining)
	_update_minimap_tank_markers()


func _update_minimap_tank_markers() -> void:
	for combatant_key_value: Variant in _minimap_markers.keys():
		var combatant_key := String(combatant_key_value)
		var marker := _minimap_markers.get(combatant_key) as Control
		if not is_instance_valid(marker) or not _combatants.has(combatant_key):
			continue
		var combatant: Dictionary = _combatants[combatant_key]
		var tank := combatant.get("tank") as Node2D
		marker.visible = (
			not bool(combatant.get("dead", false))
			and is_instance_valid(tank)
			and tank.visible
		)
		if not marker.visible:
			continue
		var normalized_position := Vector2(
			_combatant_position(combatant_key).x / MAP_SIZE.x,
			_combatant_position(combatant_key).y / MAP_SIZE.y
		)
		var marker_half := MINIMAP_TANK_MARKER_SIZE * 0.5
		var marker_center := normalized_position * MINIMAP_SIZE
		marker.position = Vector2(
			clampf(
				marker_center.x,
				marker_half.x,
				MINIMAP_SIZE.x - marker_half.x
			),
			clampf(
				marker_center.y,
				marker_half.y,
				MINIMAP_SIZE.y - marker_half.y
			)
		) - marker_half


func _clear_battle_roster_ui() -> void:
	# The ten cards are authored scene nodes so they remain visible/editable in
	# the 2D Editor. Runtime only configures and hides them; it never replaces
	# their parent position/scale selected by the user.
	for card_parent: Control in [_team_state_left, _team_state_right]:
		for child: Node in card_parent.get_children():
			var card := child as Control
			if card != null:
				card.visible = false
	for marker_value: Variant in _minimap_markers.values():
		if is_instance_valid(marker_value):
			(marker_value as Node).queue_free()
	_team_state_cards.clear()
	_team_state_cards_by_account.clear()
	_team_state_cards_by_name.clear()
	_minimap_markers.clear()


func _reset_battle_chat() -> void:
	_battle_chat_generation += 1
	_battle_chat_entries.clear()
	_battle_chat_last_ids = {"team": 0, "battle": 0}
	_battle_chat_poll_elapsed = BATTLE_CHAT_POLL_INTERVAL_SECONDS
	_battle_presence_poll_elapsed = BATTLE_PRESENCE_POLL_INTERVAL_SECONDS
	_battle_chat_poll_in_flight = false
	_battle_presence_poll_in_flight = false
	_battle_chat_send_in_flight = false
	_battle_presence_by_account.clear()
	_battle_join_announced.clear()
	_battle_player_names.clear()
	_battle_player_teams.clear()
	_battle_viewer_account_id = ""
	_battle_seen_active_phase = false
	_battle_match_end_announced = false
	_battle_chat_last_valid_input = ""
	_battle_chat_channel = "battle"
	if not is_node_ready():
		return
	_battle_chat.visible = false
	_battle_chat_history.clear()
	_battle_chat_input.clear()
	_battle_chat_input.editable = true
	_battle_chat_input.placeholder_text = "Nhập nội dung chat"
	_battle_chat_input.release_focus()
	_update_battle_chat_channel_label()


func _on_battle_chat_input_text_changed(new_text: String) -> void:
	if _battle_chat_input_guard:
		return
	var accepted := _fit_battle_chat_message_prefix(new_text)
	_battle_chat_last_valid_input = accepted
	if accepted == new_text:
		return
	# The source bubble owns exactly two visual rows. Reject the first character
	# that would no longer fit instead of letting LineEdit scroll hidden text.
	_battle_chat_input_guard = true
	_battle_chat_input.text = accepted
	_battle_chat_input.caret_column = accepted.length()
	_battle_chat_input_guard = false


func _fit_battle_chat_message_prefix(message: String) -> String:
	var safe_message := message.left(BATTLE_CHAT_MAX_CHARACTERS)
	for card_parent: Control in [_team_state_left, _team_state_right]:
		for child: Node in card_parent.get_children():
			if child.has_method("fit_chat_message_prefix"):
				return String(child.call("fit_chat_message_prefix", safe_message))
	return safe_message


func _seed_battle_join_messages() -> void:
	var viewer := _viewer_participant()
	_battle_viewer_account_id = String(
		viewer.get("account_id", GameSession.account.get("id", ""))
	).strip_edges()
	var humans: Array[Dictionary] = []
	for participant_value: Variant in _match_data.get("participants", []):
		if participant_value is not Dictionary:
			continue
		var participant: Dictionary = participant_value
		if bool(participant.get("is_bot", false)):
			continue
		humans.append(participant)
	humans.sort_custom(_battle_join_before)
	for participant: Dictionary in humans:
		var account_id := String(participant.get("account_id", "")).strip_edges()
		if account_id.is_empty():
			continue
		var name := String(participant.get("display_name", "")).strip_edges()
		if name.is_empty():
			name = "Người chơi"
		_battle_player_names[account_id] = name
		_battle_player_teams[account_id] = int(participant.get("team_no", 0))
		_battle_presence_by_account[account_id] = bool(
			participant.get("connected", true)
		)
		_battle_join_announced[account_id] = true
		_append_battle_system_message(
			name,
			"đã tham gia vào chiến trường.",
			account_id
		)


func _battle_join_before(left: Dictionary, right: Dictionary) -> bool:
	var left_joined := String(left.get("battle_joined_at", ""))
	var right_joined := String(right.get("battle_joined_at", ""))
	if left_joined != right_joined:
		if left_joined.is_empty():
			return false
		if right_joined.is_empty():
			return true
		return left_joined < right_joined
	var left_order := int(left.get("team_no", 0)) * 10 + int(
		left.get("slot_no", 0)
	)
	var right_order := int(right.get("team_no", 0)) * 10 + int(
		right.get("slot_no", 0)
	)
	return left_order < right_order


func _process_battle_chat(delta: float) -> void:
	if (
		_match_data.is_empty()
		or String(_match_data.get("id", "")).is_empty()
		or _is_local_battle_preview()
	):
		return
	_battle_chat_poll_elapsed += delta
	if (
		_battle_chat_poll_elapsed >= BATTLE_CHAT_POLL_INTERVAL_SECONDS
		and not _battle_chat_poll_in_flight
	):
		_battle_chat_poll_elapsed = 0.0
		_poll_battle_chat()
	_battle_presence_poll_elapsed += delta
	if (
		_battle_presence_poll_elapsed >= BATTLE_PRESENCE_POLL_INTERVAL_SECONDS
		and not _battle_presence_poll_in_flight
	):
		_battle_presence_poll_elapsed = 0.0
		_poll_battle_presence()


func _poll_battle_chat() -> void:
	if _battle_chat_poll_in_flight or _match_data.is_empty():
		return
	_battle_chat_poll_in_flight = true
	var generation := _battle_chat_generation
	var combined: Array[Dictionary] = []
	for channel: String in ["team", "battle"]:
		var result: Dictionary = await GameSession.fetch_game_match_chat(
			channel,
			int(_battle_chat_last_ids.get(channel, 0)),
			50
		)
		if generation != _battle_chat_generation:
			return
		if not result.get("ok", false):
			continue
		var received: Variant = result.get("messages", [])
		if received is not Array:
			continue
		for value: Variant in received:
			if value is not Dictionary:
				continue
			var message: Dictionary = value.duplicate(true)
			message["channel"] = channel
			combined.append(message)
	combined.sort_custom(_battle_message_before)
	for message: Dictionary in combined:
		_append_battle_chat_message(
			String(message.get("channel", "battle")),
			message
		)
	if generation == _battle_chat_generation:
		_battle_chat_poll_in_flight = false


func _battle_message_before(left: Dictionary, right: Dictionary) -> bool:
	var left_created := String(left.get("created_at", ""))
	var right_created := String(right.get("created_at", ""))
	if left_created != right_created:
		return left_created < right_created
	return int(left.get("id", 0)) < int(right.get("id", 0))


func _poll_battle_presence() -> void:
	if _battle_presence_poll_in_flight or _match_data.is_empty():
		return
	_battle_presence_poll_in_flight = true
	var generation := _battle_chat_generation
	var result: Dictionary = await GameSession.fetch_current_game_match()
	if generation != _battle_chat_generation:
		return
	_battle_presence_poll_in_flight = false
	if not result.get("ok", false):
		return
	var match_value: Variant = result.get("match", {})
	if match_value is not Dictionary:
		return
	var refreshed_match: Dictionary = match_value
	if String(refreshed_match.get("id", "")) != String(
		_match_data.get("id", "")
	):
		return
	var refreshed_phase := String(refreshed_match.get("phase", ""))
	if refreshed_phase == "active":
		_battle_seen_active_phase = true
	elif _battle_seen_active_phase and not _battle_match_end_announced:
		_battle_match_end_announced = true
		for account_value: Variant in _battle_presence_by_account.keys():
			var account_id := String(account_value)
			if not bool(_battle_presence_by_account.get(account_id, false)):
				continue
			_append_battle_system_message(
				String(_battle_player_names.get(account_id, "Người chơi")),
				"rời chiến trường.",
				account_id
			)
			_battle_presence_by_account[account_id] = false
		return
	var seen_accounts: Dictionary = {}
	for participant_value: Variant in refreshed_match.get("participants", []):
		if participant_value is not Dictionary:
			continue
		var participant: Dictionary = participant_value
		if bool(participant.get("is_bot", false)):
			continue
		var account_id := String(participant.get("account_id", "")).strip_edges()
		if account_id.is_empty():
			continue
		seen_accounts[account_id] = true
		var name := String(participant.get("display_name", "")).strip_edges()
		if name.is_empty():
			name = String(_battle_player_names.get(account_id, "Người chơi"))
		_battle_player_names[account_id] = name
		_battle_player_teams[account_id] = int(participant.get("team_no", 0))
		var connected := bool(participant.get("connected", true))
		var had_state := _battle_presence_by_account.has(account_id)
		var was_connected := bool(
			_battle_presence_by_account.get(account_id, connected)
		)
		if had_state and was_connected and not connected:
			_append_battle_system_message(
				name,
				"rời chiến trường.",
				account_id
			)
		elif connected and not _battle_join_announced.has(account_id):
			_battle_join_announced[account_id] = true
			_append_battle_system_message(
				name,
				"đã tham gia vào chiến trường.",
				account_id
			)
		_battle_presence_by_account[account_id] = connected
	for account_value: Variant in _battle_presence_by_account.keys():
		var account_id := String(account_value)
		if seen_accounts.has(account_id):
			continue
		if bool(_battle_presence_by_account.get(account_id, false)):
			_append_battle_system_message(
				String(_battle_player_names.get(account_id, "Người chơi")),
				"rời chiến trường.",
				account_id
			)
		_battle_presence_by_account[account_id] = false


func _handle_battle_chat_enter() -> void:
	if _match_data.is_empty() or not visible:
		return
	if not _battle_chat.visible:
		_open_battle_chat()
		return
	var message := _battle_chat_input.text.strip_edges()
	if message.is_empty():
		_close_battle_chat()
		return
	var channel := _battle_chat_channel
	_battle_chat_input.clear()
	_battle_chat_last_valid_input = ""
	_close_battle_chat()
	_send_battle_chat(message, channel)


func _open_battle_chat() -> void:
	_clear_movement_keys()
	_reset_firing()
	_cancel_skill_targeting()
	_battle_chat.visible = true
	_battle_chat_input.editable = not _battle_chat_send_in_flight
	_battle_chat_input.placeholder_text = "Nhập nội dung chat"
	_battle_chat_input.grab_focus()


func _close_battle_chat() -> void:
	_battle_chat.visible = false
	_battle_chat_input.release_focus()


func _toggle_battle_chat_channel() -> void:
	_battle_chat_channel = "team" if _battle_chat_channel == "battle" else "battle"
	_update_battle_chat_channel_label()
	if _battle_chat.visible:
		_battle_chat_input.grab_focus()


func _update_battle_chat_channel_label() -> void:
	_battle_chat_channel_label.text = (
		"Chiến trường" if _battle_chat_channel == "battle" else "Phe ta"
	)


func _send_battle_chat(message: String, channel: String) -> void:
	message = message.strip_edges().left(BATTLE_CHAT_MAX_CHARACTERS)
	if _battle_chat_send_in_flight or message.is_empty():
		return
	if _is_local_battle_preview():
		var viewer := _viewer_participant()
		var next_id := int(_battle_chat_last_ids.get(channel, 0)) + 1
		_append_battle_chat_message(channel, {
			"id": next_id,
			"sender_account_id": String(
				viewer.get("account_id", "local-player")
			),
			"sender_name": _viewer_display_name(viewer),
			"body": message,
			"created_at": Time.get_datetime_string_from_system(true),
		})
		return
	_battle_chat_send_in_flight = true
	var generation := _battle_chat_generation
	var result: Dictionary = await GameSession.send_game_match_chat(
		message,
		channel
	)
	if generation != _battle_chat_generation:
		return
	_battle_chat_send_in_flight = false
	if not result.get("ok", false):
		var error_value: Variant = result.get("error", {})
		_battle_chat_input.placeholder_text = (
			String(error_value.get("message", "Không thể gửi chat lúc này."))
			if error_value is Dictionary
			else "Không thể gửi chat lúc này."
		)
		_open_battle_chat()
		return
	var sent: Variant = result.get("message", {})
	if sent is Dictionary:
		var sent_message: Dictionary = sent.duplicate(true)
		if String(sent_message.get("sender_account_id", "")).is_empty():
			sent_message["sender_account_id"] = String(
				GameSession.account.get("id", "")
			)
		_append_battle_chat_message(channel, sent_message)


func _append_battle_chat_message(
	channel: String,
	message: Dictionary
) -> void:
	var safe_channel := "battle" if channel == "battle" else "team"
	var sender_account_id := String(
		message.get("sender_account_id", "")
	).strip_edges()
	var sender_team := int(_battle_player_teams.get(sender_account_id, 0))
	# Team chat and battle chat share one visual history, but remain two
	# independent streams. Never render a known enemy from the private stream;
	# enemies are visible only when their message came from battle chat.
	if (
		safe_channel == "team"
		and sender_team > 0
		and sender_team != _viewer_team_no
	):
		return
	var message_id := int(message.get("id", 0))
	if message_id <= int(_battle_chat_last_ids.get(safe_channel, 0)):
		return
	_battle_chat_last_ids[safe_channel] = message_id
	var sender_name := String(message.get("sender_name", "Người chơi")).strip_edges()
	if sender_name.is_empty():
		sender_name = "Người chơi"
	var body := String(message.get("body", "")).strip_edges()
	if body.is_empty():
		return
	var prefix := "Chiến trường" if safe_channel == "battle" else "Phe ta"
	var prefix_color := "#cfefff" if safe_channel == "battle" else "#72f09a"
	var sender_color := _battle_player_name_color(sender_account_id)
	_append_battle_log_line(
		"[color=%s][%s][/color] [color=%s][u]%s[/u][/color]: %s"
		% [
			prefix_color,
			prefix,
			sender_color,
			_battle_chat_escape(sender_name),
			_battle_chat_escape(body),
		]
	)
	_show_battle_chat_bubble(message, body)


func _append_battle_system_message(
	player_name: String,
	action: String,
	account_id: String = ""
) -> void:
	var player_color := _battle_player_name_color(account_id)
	_append_battle_log_line(
		"[color=#cfefff][Chiến trường][/color] "
		+ "[color=%s][u]%s[/u][/color] %s"
		% [
			player_color,
			_battle_chat_escape(player_name),
			_battle_chat_escape(action),
		]
	)


func _battle_player_name_color(account_id: String) -> String:
	var safe_account_id := account_id.strip_edges()
	if (
		not safe_account_id.is_empty()
		and safe_account_id == _battle_viewer_account_id
	):
		return "#55ff55"
	var player_team := int(_battle_player_teams.get(safe_account_id, 0))
	if player_team > 0 and player_team == _viewer_team_no:
		return "#55aaff"
	if player_team > 0:
		return "#ff5555"
	return "#ffffff"


func _append_battle_log_line(bbcode_line: String) -> void:
	_battle_chat_entries.append(bbcode_line)
	while _battle_chat_entries.size() > BATTLE_CHAT_MAX_VISIBLE_MESSAGES:
		_battle_chat_entries.pop_front()
	_battle_chat_history.text = "\n".join(_battle_chat_entries)


func _battle_chat_escape(value: String) -> String:
	# Full-width brackets keep user text literal inside RichTextLabel BBCode.
	return value.replace("[", "［").replace("]", "］")


func _show_battle_chat_bubble(message: Dictionary, body: String) -> void:
	var account_id := String(message.get("sender_account_id", "")).strip_edges()
	var sender_name := String(message.get("sender_name", "")).strip_edges()
	var card := _team_state_cards_by_account.get(account_id, null) as Control
	if card == null:
		card = _team_state_cards_by_name.get(sender_name, null) as Control
	if is_instance_valid(card) and card.has_method("show_chat_bubble"):
		card.call("show_chat_bubble", body, BATTLE_CHAT_BUBBLE_SECONDS)


func _is_local_battle_preview() -> bool:
	return String(_match_data.get("id", "")) == "local-test"


func _viewer_tank_data(viewer: Dictionary) -> Dictionary:
	var tank_key := String(viewer.get("tank_key", "gangtiexia03"))
	var owned_tanks: Variant = GameSession.lobby_data.get("owned_tanks", [])
	if owned_tanks is Array:
		for tank_value: Variant in owned_tanks:
			if (
				tank_value is Dictionary
				and String(tank_value.get("tank_key", "")) == tank_key
			):
				return tank_value
	if String(GameSession.lobby_data.get("tank_key", "")) == tank_key:
		return GameSession.lobby_data
	return viewer


func _request_real_ping() -> void:
	if _ping_in_flight:
		return
	_ping_elapsed = 0.0
	_ping_in_flight = true
	_ping_started_msec = Time.get_ticks_msec()
	var request_error := _ping_request.request(_health_url())
	if request_error != OK:
		_ping_in_flight = false
		_set_ping_unavailable()


func _health_url() -> String:
	var server_url := String(
		ProjectSettings.get_setting(
			"network/api_base_url",
			"http://127.0.0.1:8080/api"
		)
	).trim_suffix("/")
	if server_url.ends_with("/api"):
		server_url = server_url.substr(0, server_url.length() - 4)
	return server_url + "/health"


func _on_ping_request_completed(
	result: int,
	response_code: int,
	_headers: PackedStringArray,
	_body: PackedByteArray
) -> void:
	_ping_in_flight = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_set_ping_unavailable()
		return
	var latency_ms := maxi(
		Time.get_ticks_msec() - _ping_started_msec,
		0
	)
	_ping_label.text = "%d ms" % latency_ms
	_ping_label.add_theme_color_override("font_color", PING_TEXT_COLOR)


func _set_ping_unavailable() -> void:
	_ping_label.text = "-- ms"
	_ping_label.add_theme_color_override(
		"font_color",
		PING_TEXT_COLOR
	)


func _on_settings_pressed() -> void:
	if _battle_finished:
		return
	_clear_movement_keys()
	_reset_firing()
	_cancel_skill_targeting()
	_settings_panel.configure_test_mode(_is_test_mod_authorized())
	_settings_panel.open()
	settings_requested.emit()


func _is_test_mod_authorized() -> bool:
	# Do not trust a visible button or a client-supplied is_test flag alone.
	# Mods are confined to the explicit local sandbox match created by TEST.
	return (
		bool(_match_data.get("is_test", false))
		and String(_match_data.get("id", "")) == "local-test"
	)


func _reset_test_mod_runtime() -> void:
	_test_mod_player_respawn = false
	_test_mod_no_cooldown = false
	_test_mod_invincible = false
	_test_mod_bot_movement = false


func _on_battle_settings_changed(values: Dictionary) -> void:
	if not _is_test_mod_authorized():
		_reset_test_mod_runtime()
		return
	_test_mod_player_respawn = bool(values.get("mod_player_respawn", false))
	_test_mod_no_cooldown = bool(values.get("mod_no_cooldown", false))
	_test_mod_invincible = bool(values.get("mod_invincible", false))
	_test_mod_bot_movement = bool(values.get("mod_bot_movement", false))
	var reduction_seconds := clampf(
		float(values.get("mod_time_reduction_seconds", 0.0)),
		0.0,
		240.0
	)
	if reduction_seconds > 0.0 and not _battle_finished:
		var duration := maxf(
			float(_battle_rules.get("duration_seconds", 240.0)),
			_battle_elapsed_seconds
		)
		var remaining := maxf(duration - _battle_elapsed_seconds, 0.0)
		# Preserve at least one second. This prevents negative timers and lets the
		# normal battle-rule loop own the eventual time-limit finish sequence.
		var safe_reduction := minf(reduction_seconds, maxf(remaining - 1.0, 0.0))
		_battle_rules["duration_seconds"] = maxf(
			duration - safe_reduction,
			_battle_elapsed_seconds + 1.0
		)
	_apply_test_mod_skill_cooldowns()
	if _test_mod_player_respawn:
		var player: Dictionary = _combatants.get("player", {})
		if bool(player.get("dead", false)):
			_respawn_combatant("player")
	_update_score_rule_hud()


func _effective_skill_cooldown(skill_index: int) -> float:
	if _is_test_mod_authorized() and _test_mod_no_cooldown:
		return 0.0
	if skill_index < 0 or skill_index >= _skill_cooldown_seconds.size():
		return 0.5
	return _skill_cooldown_seconds[skill_index]


func _apply_test_mod_skill_cooldowns() -> void:
	var skill_slots: Array[Control] = [_skill_1, _skill_2, _skill_3]
	for skill_index: int in skill_slots.size():
		skill_slots[skill_index].call(
			"set_cooldown_seconds",
			_effective_skill_cooldown(skill_index)
		)
		if _test_mod_no_cooldown:
			skill_slots[skill_index].call("reset_ready")


func _on_settings_surrender_requested() -> void:
	if _battle_finished:
		return
	_settings_panel.close()
	if _server_authoritative_battle:
		_enqueue_authoritative_command({"type": "surrender"})
		return
	_finish_battle(2 if _viewer_team_no == 1 else 1, "surrender")


func _viewer_participant() -> Dictionary:
	var account_id := String(GameSession.account.get("id", ""))
	var viewer_team := int(_match_data.get("viewer_team_no", 1))
	var team_fallback: Dictionary = {}
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
			team_fallback.is_empty()
			and int(participant.get("team_no", 0)) == viewer_team
			and not bool(participant.get("is_bot", false))
		):
			team_fallback = participant
	return team_fallback


func _viewer_display_name(viewer: Dictionary) -> String:
	var display_name := String(viewer.get("display_name", "")).strip_edges()
	if display_name.is_empty():
		display_name = String(
			GameSession.profile.get("display_name", "")
		).strip_edges()
	if display_name.is_empty():
		display_name = String(
			GameSession.lobby_data.get("display_name", "")
		).strip_edges()
	if display_name.is_empty():
		display_name = "Người chơi"
	return display_name
