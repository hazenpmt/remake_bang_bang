extends Node2D

const GLYPHS := "0123456789-+"
const NORMAL_GLYPH_SIZE := Vector2i(13, 20)
const HEAL_GLYPH_SIZE := Vector2i(13, 21)
const CRITICAL_GLYPH_SIZE := Vector2i(26, 33)
const CRITICAL_PREFIX_WIDTH := 31
const NORMAL_TEXTURE_PATH := "res://assets/battle/numbers/num_harm.png"
const HEAL_TEXTURE_PATH := "res://assets/battle/numbers/num_cure.png"
const CRITICAL_TEXTURE_PATH := "res://assets/battle/numbers/num_crit.png"
const CRITICAL_PREFIX_TEXTURE_PATH := (
	"res://assets/battle/numbers/prefix_crit.png"
)
const RISE_DISTANCE := 22.0
const DISPLAY_SECONDS := 0.55
const FADE_DELAY_SECONDS := 0.12
const FADE_SECONDS := DISPLAY_SECONDS - FADE_DELAY_SECONDS
var _normal_texture: Texture2D
var _heal_texture: Texture2D
var _critical_texture: Texture2D
var _critical_prefix_texture: Texture2D


func _ready() -> void:
	_normal_texture = load(NORMAL_TEXTURE_PATH) as Texture2D
	_heal_texture = load(HEAL_TEXTURE_PATH) as Texture2D
	_critical_texture = load(CRITICAL_TEXTURE_PATH) as Texture2D
	_critical_prefix_texture = load(CRITICAL_PREFIX_TEXTURE_PATH) as Texture2D


func show_damage(value: int, critical: bool = false) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var text := str(maxi(value, 0))
	if (
		_normal_texture == null
		or _critical_texture == null
		or _critical_prefix_texture == null
	):
		queue_free()
		return
	var glyph_size := (
		CRITICAL_GLYPH_SIZE if critical else NORMAL_GLYPH_SIZE
	)
	var atlas: Texture2D = (
		_critical_texture if critical else _normal_texture
	)
	var total_width := glyph_size.x * text.length()
	if critical:
		total_width += CRITICAL_PREFIX_WIDTH
	var cursor := -float(total_width) * 0.5
	if critical:
		var prefix := Sprite2D.new()
		prefix.centered = false
		prefix.texture = _critical_prefix_texture
		prefix.position = Vector2(
			cursor,
			float(glyph_size.y - _critical_prefix_texture.get_height())
		)
		add_child(prefix)
		cursor += CRITICAL_PREFIX_WIDTH
	for character_index in text.length():
		var character := text.substr(character_index, 1)
		var glyph_index := GLYPHS.find(character)
		if glyph_index < 0:
			continue
		var glyph_texture := AtlasTexture.new()
		glyph_texture.atlas = atlas
		glyph_texture.region = Rect2(
			glyph_index * glyph_size.x,
			0,
			glyph_size.x,
			glyph_size.y
		)
		var glyph := Sprite2D.new()
		glyph.centered = false
		glyph.texture = glyph_texture
		glyph.position = Vector2(cursor, 0.0)
		add_child(glyph)
		cursor += glyph_size.x
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(
		self,
		"position",
		position + Vector2(0.0, -RISE_DISTANCE),
		DISPLAY_SECONDS
	)
	tween.tween_property(
		self,
		"modulate",
		Color(1.0, 1.0, 1.0, 0.0),
		FADE_SECONDS
	).set_delay(FADE_DELAY_SECONDS)
	tween.finished.connect(queue_free)


func show_heal(value: int) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if _heal_texture == null:
		queue_free()
		return
	var text := "+%d" % maxi(value, 0)
	var total_width := HEAL_GLYPH_SIZE.x * text.length()
	var cursor := -float(total_width) * 0.5
	for character_index in text.length():
		var character := text.substr(character_index, 1)
		var glyph_index := GLYPHS.find(character)
		if glyph_index < 0:
			continue
		var glyph_texture := AtlasTexture.new()
		glyph_texture.atlas = _heal_texture
		glyph_texture.region = Rect2(
			glyph_index * HEAL_GLYPH_SIZE.x,
			0,
			HEAL_GLYPH_SIZE.x,
			HEAL_GLYPH_SIZE.y
		)
		var glyph := Sprite2D.new()
		glyph.centered = false
		glyph.texture = glyph_texture
		glyph.position = Vector2(cursor, 0.0)
		add_child(glyph)
		cursor += HEAL_GLYPH_SIZE.x
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(
		self,
		"position",
		position + Vector2(0.0, -RISE_DISTANCE),
		DISPLAY_SECONDS
	)
	tween.tween_property(
		self,
		"modulate",
		Color(1.0, 1.0, 1.0, 0.0),
		FADE_SECONDS
	).set_delay(FADE_DELAY_SECONDS)
	tween.finished.connect(queue_free)
