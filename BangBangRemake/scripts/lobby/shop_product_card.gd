extends Control

signal action_requested(action: StringName, offer: Dictionary)

const SMALL_FRAME := preload("res://assets/ui/shop/controls/goodsCard.png")
const LARGE_FRAME := preload("res://assets/ui/shop/controls/bigGoodsCard.png")
const BUY_SMALL := preload("res://assets/ui/shop/controls/button_buy_s_t.png")
const GIFT_SMALL := preload("res://assets/ui/shop/controls/button_present_s_t.png")
const BUY_LARGE := preload("res://assets/ui/shop/controls/button_buy_t.png")
const GIFT_LARGE := preload("res://assets/ui/shop/controls/button_present_t.png")
const CLAIM_TANK := preload("res://assets/ui/shop/controls/btn_get_tank_t.png")
const TRY_BUTTON := preload("res://assets/ui/shop/controls/button_view3_t.png")
const BADGE_HOT := preload("res://assets/ui/shop/controls/sign_hot_t.png")
const BADGE_SALE := preload("res://assets/ui/shop/controls/sign_discount_t.png")
const BADGE_NEW := preload("res://assets/ui/shop/controls/sign_new_rb_t.png")
const COIN_XU := preload("res://assets/ui/currency/icon_xu.png")
const COIN_LOCKED := preload("res://assets/ui/currency/icon_xu_locked.png")
const COIN_SILVER := preload("res://assets/ui/currency/icon_silver.png")
const HoverPressButton := preload("res://scripts/ui/HoverPressTextureButton.gd")
const ShopCatalog := preload("res://scripts/data/shop_catalog.gd")

var offer: Dictionary = {}
var category: StringName = &"recommend"
var large := false


func setup(next_offer: Dictionary, next_category: StringName) -> void:
	offer = next_offer.duplicate(true)
	category = next_category
	large = category in [&"tank", &"skin", &"fashion", &"decoration"]
	custom_minimum_size = Vector2(250, 380 if large else 190)
	size = custom_minimum_size
	_build()


func _build() -> void:
	for child in get_children():
		child.queue_free()
	# Flash component is 250x190/380; the unmodified frame deliberately bleeds
	# two pixels on every edge (254x194/384).
	_add_texture(LARGE_FRAME if large else SMALL_FRAME, Vector2(-2, -2))
	_add_label(
		String(offer.get("name", "Vật phẩm")),
		Vector2(10 if large else 16, 13),
		Vector2(230 if large else 219, 24),
		Color.WHITE,
		14,
		HORIZONTAL_ALIGNMENT_CENTER,
		true
	)
	if large:
		_build_large()
	else:
		_build_small()
	_add_badges()


func _build_small() -> void:
	_add_offer_image(Vector2(15, 61), Vector2(100, 100))
	_add_wrapped_text(
		String(offer.get("desc", "")), Vector2(124, 59),
		Vector2(116, 41), Color("#975557"), 12
	)
	_add_price(Vector2(134, 102))
	var blocked_message := _purchase_block_message()
	if not blocked_message.is_empty():
		_add_label(
			blocked_message, Vector2(120, 133), Vector2(118, 28),
			Color("#f48045"), 14, HORIZONTAL_ALIGNMENT_CENTER, true
		)
	else:
		_add_action_button(BUY_SMALL, Vector2(123, 133), &"buy")
	if blocked_message.is_empty() and bool(offer.get("giftable", true)):
		_add_action_button(GIFT_SMALL, Vector2(184, 133), &"gift")


func _build_large() -> void:
	_add_offer_image(Vector2(27, 40), Vector2(200, 200))
	if category == &"tank":
		var skills: Array = offer.get("skills", []) as Array
		for index in mini(3, skills.size()):
			var texture := ShopCatalog.load_texture(String(skills[index]))
			_add_texture(texture, Vector2(44 + index * 56, 248), Vector2(50, 50))
		_add_price(Vector2(81, 302))
		var blocked_message := _purchase_block_message()
		if not blocked_message.is_empty():
			_add_label(blocked_message, Vector2(5, 336), Vector2(110, 28), Color("#f48045"), 16, HORIZONTAL_ALIGNMENT_CENTER, true)
		else:
			_add_action_button(BUY_LARGE, Vector2(24, 336), &"buy")
		if blocked_message.is_empty() and bool(offer.get("giftable", true)):
			_add_action_button(GIFT_LARGE, Vector2(95, 336), &"gift")
	elif category == &"skin":
		_add_label("Hãy nhận Tank", Vector2(65, 250), Vector2(124, 20), Color("#169ed5"), 13, HORIZONTAL_ALIGNMENT_CENTER, true)
		var max_progress := maxi(1, int(offer.get("progress_max", 150)))
		var progress := clampi(int(offer.get("progress", 0)), 0, max_progress)
		var bar := ProgressBar.new()
		bar.position = Vector2(53, 274)
		bar.size = Vector2(150, 17)
		bar.max_value = max_progress
		bar.value = progress
		bar.show_percentage = false
		add_child(bar)
		_add_label("%d/%d" % [progress, max_progress], Vector2(53, 271), Vector2(150, 22), Color.WHITE, 12, HORIZONTAL_ALIGNMENT_CENTER, true)
		var blocked_message := _purchase_block_message()
		if blocked_message.is_empty():
			_add_action_button(CLAIM_TANK, Vector2(80, 336), &"claim")
		else:
			_add_label(blocked_message, Vector2(65, 336), Vector2(124, 28), Color("#f48045"), 16, HORIZONTAL_ALIGNMENT_CENTER, true)
	else:
		var description := String(offer.get("desc", ""))
		if not description.is_empty():
			_add_label(description, Vector2(20, 276), Vector2(214, 22), Color("#f05f50"), 12, HORIZONTAL_ALIGNMENT_CENTER, true)
		_add_price(Vector2(81, 302))
		var blocked_message := _purchase_block_message()
		if blocked_message.is_empty():
			_add_action_button(BUY_LARGE, Vector2(24, 336), &"buy")
		else:
			_add_label(blocked_message, Vector2(5, 336), Vector2(110, 28), Color("#f48045"), 16, HORIZONTAL_ALIGNMENT_CENTER, true)
		if blocked_message.is_empty() and bool(offer.get("giftable", true)):
			_add_action_button(GIFT_LARGE, Vector2(125, 336), &"gift")
		if bool(offer.get("try", false)):
			_add_action_button(TRY_BUTTON, Vector2(184, 8), &"try")


func _purchase_block_message() -> String:
	var remaining: Variant = offer.get("remaining_limit")
	if remaining != null and int(remaining) <= 0:
		return "Đã hết lượt"
	var item_type := StringName(offer.get("item_type", ""))
	if (
		bool(offer.get("owned", false))
		and item_type in [
			&"tank", &"tank_skin", &"avatar_fashion",
			&"profile_decoration", &"assistant",
		]
	):
		return "Đã có"
	return ""


func _add_offer_image(at: Vector2, box_size: Vector2) -> void:
	var texture := ShopCatalog.load_texture(
		String(offer.get("image", ""))
	)
	if texture == null:
		return
	var image := TextureRect.new()
	image.texture = texture
	var native_size := texture.get_size()
	if native_size.x <= box_size.x and native_size.y <= box_size.y:
		var centered_position := at + (box_size - native_size) * 0.5
		image.position = Vector2(
			floor(centered_position.x), floor(centered_position.y)
		)
		image.size = native_size
		image.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	else:
		image.position = at
		image.size = box_size
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(image)


func _add_price(at: Vector2) -> void:
	var currency := StringName(offer.get("currency", "xu"))
	var coin := COIN_XU
	if currency == &"locked_xu":
		coin = COIN_LOCKED
	elif currency == &"silver":
		coin = COIN_SILVER
	_add_texture(coin, at)
	_add_label(
		_format_number(int(offer.get("price", 0))), at + Vector2(26, 1),
		Vector2(80, 24), Color("#8c4800"), 14,
		HORIZONTAL_ALIGNMENT_LEFT, true
	)


func _add_badges() -> void:
	var badge := String(offer.get("badge", ""))
	if badge == "hot":
		_add_texture(BADGE_HOT, Vector2(2, 2))
	elif badge == "sale":
		_add_texture(BADGE_SALE, Vector2(2, 2))
	elif badge == "new":
		_add_texture(BADGE_NEW, Vector2(194, 320 if large else 130))


func _add_action_button(texture: Texture2D, at: Vector2, action: StringName) -> void:
	var button := TextureButton.new()
	button.texture_normal = texture
	button.ignore_texture_size = false
	button.position = at
	button.set_script(HoverPressButton)
	button.pressed.connect(_emit_action.bind(action))
	add_child(button)


func _emit_action(action: StringName) -> void:
	action_requested.emit(action, offer.duplicate(true))


func _add_texture(texture: Texture2D, at: Vector2, forced_size := Vector2.ZERO) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.position = at
	if forced_size != Vector2.ZERO:
		var native_size := texture.get_size()
		rect.position = at + Vector2(
			floor((forced_size.x - native_size.x) * 0.5),
			floor((forced_size.y - native_size.y) * 0.5)
		)
		rect.size = native_size
		rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	else:
		rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rect)
	return rect


func _add_label(
	text_value: String,
	at: Vector2,
	box_size: Vector2,
	color: Color,
	font_size: int,
	alignment: HorizontalAlignment,
	bold: bool
) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.size = box_size
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	if bold:
		label.add_theme_constant_override("outline_size", 1)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.24))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label


func _add_wrapped_text(
	text_value: String,
	at: Vector2,
	box_size: Vector2,
	color: Color,
	font_size: int
) -> RichTextLabel:
	var text_block := RichTextLabel.new()
	text_block.bbcode_enabled = false
	text_block.fit_content = false
	text_block.scroll_active = false
	text_block.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_block.add_theme_color_override("default_color", color)
	text_block.add_theme_font_size_override("normal_font_size", font_size)
	add_child(text_block)
	# Set the rect after entering the tree so theme minimum-size calculation
	# cannot grow the text block beyond the original Flash bounds.
	text_block.position = at
	text_block.size = box_size
	text_block.text = text_value
	return text_block


func _format_number(value: int) -> String:
	var source := str(maxi(0, value))
	var result := ""
	while source.length() > 3:
		result = "," + source.right(3) + result
		source = source.left(source.length() - 3)
	return source + result
