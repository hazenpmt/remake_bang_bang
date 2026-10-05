extends Control

const TANK_SKIN_CATALOG = preload("res://scripts/lobby/tank_skin_catalog.gd")
const PURPLE_FRAME := preload(
	"res://assets/battle/hud/team_state/purple.png"
)
const ORANGE_FRAME := preload(
	"res://assets/battle/hud/team_state/orange.png"
)
const BLUE_HP_BAR := preload(
	"res://assets/battle/hud/team_state/player_blue_hp_bar.png"
)
const RED_HP_BAR := preload(
	"res://assets/battle/hud/team_state/player_red_hp_bar.png"
)
const HP_BAR_WIDTH := 56.0
const CHAT_BUBBLE_MAX_CHARACTERS := 64
const CHAT_BUBBLE_LINE_COUNT := 2

@onready var _tank_icon: TextureRect = $TankIcon
@onready var _skin_frame: TextureRect = $SkinFrame
@onready var _display_name: Label = $DisplayName
@onready var _hp_clip: Control = $HpClip
@onready var _hp_fill: TextureRect = $HpClip/Fill
@onready var _cooldown_background: TextureRect = $CooldownBackground
@onready var _cooldown_ready: TextureRect = $CooldownReady
@onready var _cooldown_value: Label = $CooldownValue
@onready var _chat_bubble: Control = $ChatBubble
@onready var _chat_message: Label = $ChatBubble/Message

var _shows_private_cooldown := false
var _chat_bubble_generation := 0


func configure(
	participant: Dictionary,
	is_friendly: bool,
	show_private_cooldown: bool,
	icon_texture: Texture2D,
	bubble_opens_right: bool = true
) -> void:
	_shows_private_cooldown = show_private_cooldown
	_tank_icon.texture = icon_texture
	_display_name.text = String(
		participant.get("display_name", participant.get("tank_name", ""))
	).strip_edges()
	_hp_fill.texture = BLUE_HP_BAR if is_friendly else RED_HP_BAR
	var frame_tier := TANK_SKIN_CATALOG.skin_frame_tier(participant)
	_skin_frame.visible = frame_tier in ["purple", "orange"]
	if frame_tier == "purple":
		_skin_frame.texture = PURPLE_FRAME
	elif frame_tier == "orange":
		_skin_frame.texture = ORANGE_FRAME
	_chat_bubble_generation += 1
	_chat_bubble.visible = false
	_chat_bubble.position.x = 64.0 if bubble_opens_right else -166.0
	set_health(1, 1)
	set_space_cooldown(0.0)


func set_health(current_value: int, maximum_value: int) -> void:
	var safe_maximum := maxi(maximum_value, 1)
	var ratio := clampf(float(current_value) / float(safe_maximum), 0.0, 1.0)
	_hp_clip.size.x = HP_BAR_WIDTH * ratio


func set_space_cooldown(seconds_remaining: float) -> void:
	if not _shows_private_cooldown:
		_cooldown_background.visible = false
		_cooldown_ready.visible = false
		_cooldown_value.visible = false
		return
	var is_ready := seconds_remaining <= 0.0
	_cooldown_background.visible = true
	_cooldown_ready.visible = is_ready
	_cooldown_value.visible = not is_ready
	if not is_ready:
		_cooldown_value.text = str(maxi(ceili(seconds_remaining), 1))


func show_chat_bubble(message: String, duration_seconds: float = 4.0) -> void:
	_chat_bubble_generation += 1
	var generation := _chat_bubble_generation
	_chat_message.text = _format_chat_bubble_text(message)
	_chat_bubble.visible = not _chat_message.text.is_empty()
	if not _chat_bubble.visible:
		return
	await get_tree().create_timer(maxf(duration_seconds, 0.1)).timeout
	if generation == _chat_bubble_generation and is_instance_valid(_chat_bubble):
		_chat_bubble.visible = false


func fit_chat_message_prefix(message: String) -> String:
	return String(_layout_chat_bubble_text(message).get("accepted", ""))


func can_fit_chat_message(message: String) -> bool:
	return bool(_layout_chat_bubble_text(message).get("complete", false))


func _format_chat_bubble_text(message: String) -> String:
	return String(_layout_chat_bubble_text(message).get("wrapped", ""))


func _layout_chat_bubble_text(message: String) -> Dictionary:
	var safe_message := message.replace("\r", " ").replace("\n", " ").left(
		CHAT_BUBBLE_MAX_CHARACTERS
	)
	var font := _chat_message.get_theme_font("font")
	var font_size := _chat_message.get_theme_font_size("font_size")
	var maximum_width := maxf(_chat_message.size.x, 1.0)
	var lines: Array[String] = [""]
	var accepted := ""
	for index in range(safe_message.length()):
		var character := safe_message.substr(index, 1)
		var candidate := lines[-1] + character
		if font.get_string_size(
			candidate,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size
		).x <= maximum_width:
			lines[-1] = candidate
			accepted += character
			continue
		if lines.size() >= CHAT_BUBBLE_LINE_COUNT:
			break
		lines.append(character)
		accepted += character
	return {
		"accepted": accepted,
		"wrapped": "\n".join(lines),
		"complete": accepted.length() == safe_message.length(),
	}
