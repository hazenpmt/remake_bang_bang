extends RefCounted

## Data-driven Shop catalog.
## Edit res://shop_content/catalog.json or drop packages into
## res://shop_content/packages/<package>/manifest.json. No scene/code edit needed.

const AssetPathAliases := preload("res://scripts/data/asset_path_aliases.gd")
const ContentDelivery := preload("res://scripts/network/content_delivery.gd")

const CATEGORY_KEYS: Array[StringName] = [
	&"recommend", &"tank", &"skin", &"fashion",
	&"decoration", &"vip", &"material", &"assistant",
]
const CATEGORY_LABELS: Array[String] = [
	"ĐỀ CỬ", "TANK", "SKIN", "THỜI TRANG",
	"TRANG TRÍ", "VIP", "NGUYÊN LIỆU", "TRỢ THỦ",
]
const ALLOWED_ITEM_TYPES: Array[StringName] = [
	&"tank", &"tank_skin", &"avatar_fashion", &"profile_decoration",
	&"vip_pass", &"material", &"assistant", &"consumable", &"bundle",
]
const ALLOWED_CURRENCIES: Array[StringName] = [
	&"xu", &"locked_xu", &"silver",
]
const DEFAULT_CONTENT_ROOT := "res://shop_content"

static var _loaded := false
static var _items_by_id: Dictionary = {}
static var _offers: Array[Dictionary] = []
static var _shelves_by_id: Dictionary = {}
static var _errors: PackedStringArray = []
static var _texture_cache: Dictionary = {}


static func reload() -> void:
	_reset_catalog()
	var root := _find_content_root()
	_load_document(root.path_join("catalog.json"), root)
	_load_packages(root.path_join("packages"))
	_validate_references()
	if not _errors.is_empty():
		for message in _errors:
			push_warning("Shop catalog: %s" % message)
	else:
		print(
			"Shop catalog loaded: %d items, %d offers, %d shelves" % [
				_items_by_id.size(), _offers.size(), _shelves_by_id.size()
			]
		)


static func apply_server_catalog(document: Variant) -> bool:
	_reset_catalog()
	if not document is Dictionary:
		_errors.append("Máy chủ trả về catalog không hợp lệ")
		return false
	_load_document_value(document as Dictionary, DEFAULT_CONTENT_ROOT, "server")
	_validate_references()
	if not _errors.is_empty():
		for message in _errors:
			push_warning("Shop server catalog: %s" % message)
		return false
	return true


static func apply_purchase(purchase: Dictionary) -> void:
	_ensure_loaded()
	var item_id := String(purchase.get("item_id", ""))
	if _items_by_id.has(item_id):
		var item := _items_by_id[item_id] as Dictionary
		item["owned"] = true
		var grant: Dictionary = purchase.get("grant", {})
		item["owned_quantity"] = maxi(
			1, int(grant.get("balance_after", item.get("owned_quantity", 1)))
		)
	var offer_id := String(purchase.get("offer_id", ""))
	var quantity := maxi(1, int(purchase.get("quantity", 1)))
	for offer in _offers:
		if String(offer.get("offer_id", "")) != offer_id:
			continue
		var purchased := int(offer.get("purchased_quantity", 0)) + quantity
		offer["purchased_quantity"] = purchased
		if offer.get("purchase_limit") != null:
			offer["remaining_limit"] = maxi(
				0, int(offer.get("purchase_limit", 0)) - purchased
			)
		break


static func _reset_catalog() -> void:
	_loaded = true
	_items_by_id.clear()
	_offers.clear()
	_shelves_by_id.clear()
	_errors.clear()
	_texture_cache.clear()


static func items(shelf_id: StringName) -> Array:
	_ensure_loaded()
	var result: Array = []
	var now := int(Time.get_unix_time_from_system())
	for offer in _offers:
		var shelf_ids: Array = offer.get("shelf_ids", []) as Array
		if not shelf_ids.has(String(shelf_id)):
			continue
		if not _offer_is_active(offer, now):
			continue
		var item_id := String(offer.get("item_id", ""))
		if not _items_by_id.has(item_id):
			continue
		var merged: Dictionary = (
			_items_by_id[item_id] as Dictionary
		).duplicate(true)
		var item_source_root := String(
			merged.get("_source_root", DEFAULT_CONTENT_ROOT)
		)
		merged.merge(offer, true)
		merged["_source_root"] = item_source_root
		merged["id"] = String(offer.get("offer_id", item_id))
		merged["desc"] = String(merged.get("description", ""))
		var badges: Array = merged.get("badges", []) as Array
		if not badges.is_empty():
			merged["badge"] = String(badges[0]).to_lower()
		merged["try"] = bool(merged.get("preview_enabled", false))
		_resolve_visual_paths(merged)
		result.append(merged)
	result.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("sort_priority", 0)) > int(
			right.get("sort_priority", 0)
		)
	)
	return result


static func is_large(shelf_id: StringName) -> bool:
	_ensure_loaded()
	var shelf: Dictionary = _shelves_by_id.get(String(shelf_id), {})
	return String(shelf.get("layout", "small")) == "large"


static func validation_errors() -> PackedStringArray:
	_ensure_loaded()
	return _errors.duplicate()


static func content_root() -> String:
	return _find_content_root()


static func load_texture(asset_path: String) -> Texture2D:
	if asset_path.is_empty():
		return null
	if asset_path.begins_with("content://"):
		asset_path = ContentDelivery.resolve_uri(asset_path)
		if asset_path.is_empty():
			return null
	if _texture_cache.has(asset_path):
		return _texture_cache[asset_path] as Texture2D
	var texture: Texture2D
	if asset_path.begins_with("res://"):
		texture = AssetPathAliases.load_texture(asset_path)
	elif asset_path.begins_with("user://"):
		texture = _load_external_texture(
			ProjectSettings.globalize_path(asset_path)
		)
	else:
		texture = _load_external_texture(asset_path)
	_texture_cache[asset_path] = texture
	return texture


static func _ensure_loaded() -> void:
	if not _loaded:
		reload()


static func _find_content_root() -> String:
	var environment_root := OS.get_environment("BANGBANG_SHOP_CONTENT_DIR")
	if not environment_root.is_empty() and FileAccess.file_exists(
		environment_root.path_join("catalog.json")
	):
		return environment_root
	if not OS.has_feature("editor"):
		var beside_executable := OS.get_executable_path().get_base_dir().path_join(
			"shop_content"
		)
		if FileAccess.file_exists(beside_executable.path_join("catalog.json")):
			return beside_executable
	var user_root := ProjectSettings.globalize_path("user://shop_content")
	if FileAccess.file_exists(user_root.path_join("catalog.json")):
		return user_root
	return DEFAULT_CONTENT_ROOT


static func _load_packages(packages_root: String) -> void:
	var directory := DirAccess.open(packages_root)
	if directory == null:
		return
	var package_names := directory.get_directories()
	package_names.sort()
	for package_name in package_names:
		var package_root := packages_root.path_join(package_name)
		var manifest_path := package_root.path_join("manifest.json")
		if FileAccess.file_exists(manifest_path):
			_load_document(manifest_path, package_root)


static func _load_document(path: String, source_root: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		_errors.append("Không đọc được %s" % path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		_errors.append("JSON không hợp lệ: %s" % path)
		return
	_load_document_value(parsed as Dictionary, source_root, path)


static func _load_document_value(
	document: Dictionary,
	source_root: String,
	source_label: String
) -> void:
	for raw_shelf in document.get("shelves", []):
		if not raw_shelf is Dictionary:
			continue
		var shelf := (raw_shelf as Dictionary).duplicate(true)
		var shelf_id := String(shelf.get("shelf_id", "")).strip_edges()
		if shelf_id.is_empty():
			_errors.append("Shelf thiếu shelf_id trong %s" % source_label)
			continue
		_shelves_by_id[shelf_id] = shelf
	for raw_item in document.get("items", []):
		if not raw_item is Dictionary:
			continue
		var item := (raw_item as Dictionary).duplicate(true)
		var item_id := String(item.get("item_id", "")).strip_edges()
		if item_id.is_empty():
			_errors.append("Item thiếu item_id trong %s" % source_label)
			continue
		if _items_by_id.has(item_id):
			_errors.append("item_id bị trùng: %s" % item_id)
			continue
		item["_source_root"] = source_root
		_items_by_id[item_id] = item
	for raw_offer in document.get("offers", []):
		if not raw_offer is Dictionary:
			continue
		var offer := (raw_offer as Dictionary).duplicate(true)
		offer["_source_root"] = source_root
		_offers.append(offer)


static func _validate_references() -> void:
	var seen_offer_ids := {}
	for item_id in _items_by_id:
		var item := _items_by_id[item_id] as Dictionary
		var item_type := StringName(item.get("item_type", ""))
		if item_type not in ALLOWED_ITEM_TYPES:
			_errors.append("item_type không hợp lệ: %s (%s)" % [item_id, item_type])
	for offer in _offers:
		var offer_id := String(offer.get("offer_id", "")).strip_edges()
		if offer_id.is_empty():
			_errors.append("Offer thiếu offer_id")
			continue
		if seen_offer_ids.has(offer_id):
			_errors.append("offer_id bị trùng: %s" % offer_id)
		seen_offer_ids[offer_id] = true
		var item_id := String(offer.get("item_id", ""))
		if not _items_by_id.has(item_id):
			_errors.append("%s tham chiếu item_id không tồn tại: %s" % [offer_id, item_id])
		var currency := StringName(offer.get("currency", ""))
		if currency not in ALLOWED_CURRENCIES:
			_errors.append("Tiền tệ không hợp lệ ở %s: %s" % [offer_id, currency])
		for shelf_id in offer.get("shelf_ids", []):
			if not _shelves_by_id.has(String(shelf_id)):
				_errors.append("%s tham chiếu shelf không tồn tại: %s" % [offer_id, shelf_id])


static func _offer_is_active(offer: Dictionary, now: int) -> bool:
	if not bool(offer.get("enabled", true)):
		return false
	var start_at := _optional_text(offer.get("start_at"))
	var end_at := _optional_text(offer.get("end_at"))
	if not start_at.is_empty():
		var start_unix := int(Time.get_unix_time_from_datetime_string(start_at))
		if start_unix > now:
			return false
	if not end_at.is_empty():
		var end_unix := int(Time.get_unix_time_from_datetime_string(end_at))
		if end_unix <= now:
			return false
	return true


static func _optional_text(value: Variant) -> String:
	if value == null:
		return ""
	return str(value).strip_edges()


static func _resolve_visual_paths(record: Dictionary) -> void:
	var source_root := String(record.get("_source_root", DEFAULT_CONTENT_ROOT))
	var image_path := _resolve_asset_path(String(record.get("image", "")), source_root)
	if image_path.begins_with("content://"):
		var cached_path := ContentDelivery.resolve_uri(image_path)
		if cached_path.is_empty():
			image_path = _resolve_asset_path(
				String(record.get("fallback_image", "")), source_root
			)
		else:
			image_path = cached_path
	record["image"] = image_path
	var resolved_skills: Array[String] = []
	for skill_path in record.get("skills", []):
		resolved_skills.append(_resolve_asset_path(String(skill_path), source_root))
	record["skills"] = resolved_skills


static func _resolve_asset_path(asset_path: String, source_root: String) -> String:
	if asset_path.is_empty() or asset_path.begins_with("res://") or asset_path.begins_with("user://") or asset_path.begins_with("content://") or asset_path.is_absolute_path():
		return asset_path
	var combined := source_root.path_join(asset_path).simplify_path()
	if combined.begins_with("res://") or combined.begins_with("user://"):
		return combined
	return combined


static func _load_external_texture(path: String) -> Texture2D:
	var image := Image.new()
	if image.load(path) != OK:
		push_warning("Shop catalog: không đọc được ảnh %s" % path)
		return null
	return ImageTexture.create_from_image(image)
