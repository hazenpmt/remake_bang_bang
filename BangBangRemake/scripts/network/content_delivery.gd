extends RefCounted

## Runtime content cache for immutable Shop images.
## Existing res:// assets remain the built-in base/fallback content.

const CACHE_ROOT := "user://content_cache"
const MAX_IMAGE_BYTES := 16 * 1024 * 1024
const CONTENT_PREFIX := "content://"

static var _resolved_paths: Dictionary = {}


static func sync_catalog_assets(catalog: Dictionary, api_base_url: String) -> Dictionary:
	var required_ids := _catalog_asset_ids(catalog)
	if required_ids.is_empty():
		return {"ok": true, "downloaded": 0, "cached": 0}
	var manifest_result := await _request_bytes(
		api_base_url.trim_suffix("/") + "/content/manifest"
	)
	if not manifest_result.get("ok", false):
		return manifest_result
	var parsed: Variant = JSON.parse_string(
		(manifest_result.get("body", PackedByteArray()) as PackedByteArray).get_string_from_utf8()
	)
	if not parsed is Dictionary or not (parsed as Dictionary).get("ok", false):
		return _error("CONTENT_MANIFEST_INVALID", "Danh sách nội dung từ máy chủ không hợp lệ.")
	var manifest_value: Variant = (parsed as Dictionary).get("manifest", {})
	if not manifest_value is Dictionary:
		return _error("CONTENT_MANIFEST_INVALID", "Danh sách nội dung từ máy chủ không hợp lệ.")
	var assets_by_id: Dictionary = {}
	for value in (manifest_value as Dictionary).get("assets", []):
		if value is Dictionary:
			var asset := value as Dictionary
			assets_by_id[String(asset.get("asset_id", ""))] = asset

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CACHE_ROOT))
	var downloaded := 0
	var cached := 0
	for asset_id in required_ids:
		if not assets_by_id.has(asset_id):
			return _error(
				"CONTENT_ASSET_MISSING",
				"Máy chủ chưa phát hành asset %s." % asset_id
			)
		var asset := assets_by_id[asset_id] as Dictionary
		var validation := _validate_manifest_asset(asset)
		if not validation.get("ok", false):
			return validation
		var cache_path := _cache_path(asset)
		if FileAccess.file_exists(cache_path) and (
			FileAccess.get_sha256(cache_path) == String(asset.get("sha256", ""))
		):
			_resolved_paths[asset_id] = cache_path
			cached += 1
			continue
		var asset_url := _absolute_content_url(
			String(asset.get("url", "")), api_base_url
		)
		var download := await _request_bytes(asset_url)
		if not download.get("ok", false):
			return download
		var body := download.get("body", PackedByteArray()) as PackedByteArray
		if body.size() != int(asset.get("byte_size", 0)):
			return _error("CONTENT_SIZE_MISMATCH", "Dung lượng asset tải về không khớp manifest.")
		if _sha256_bytes(body) != String(asset.get("sha256", "")):
			return _error("CONTENT_HASH_MISMATCH", "Asset tải về không vượt qua kiểm tra SHA-256.")
		var file := FileAccess.open(cache_path, FileAccess.WRITE)
		if file == null:
			return _error("CONTENT_CACHE_WRITE_FAILED", "Không ghi được asset vào cache của game.")
		file.store_buffer(body)
		file.close()
		_resolved_paths[asset_id] = cache_path
		downloaded += 1
	return {"ok": true, "downloaded": downloaded, "cached": cached}


static func resolve_uri(uri: String) -> String:
	if not uri.begins_with(CONTENT_PREFIX):
		return uri
	var asset_id := uri.trim_prefix(CONTENT_PREFIX)
	return String(_resolved_paths.get(asset_id, ""))


static func _catalog_asset_ids(catalog: Dictionary) -> PackedStringArray:
	var ids := PackedStringArray()
	var seen := {}
	for value in catalog.get("items", []):
		if not value is Dictionary:
			continue
		var item := value as Dictionary
		var paths: Array = [item.get("image", "")]
		paths.append_array(item.get("skills", []))
		for path_value in paths:
			var path := String(path_value)
			if path.begins_with(CONTENT_PREFIX):
				var asset_id := path.trim_prefix(CONTENT_PREFIX)
				if not seen.has(asset_id):
					seen[asset_id] = true
					ids.append(asset_id)
	ids.sort()
	return ids


static func _validate_manifest_asset(asset: Dictionary) -> Dictionary:
	var asset_id := String(asset.get("asset_id", ""))
	var sha256 := String(asset.get("sha256", ""))
	var media_type := String(asset.get("media_type", ""))
	var byte_size := int(asset.get("byte_size", 0))
	if not _valid_asset_id(asset_id):
		return _error("CONTENT_MANIFEST_INVALID", "asset_id trong manifest không hợp lệ.")
	if sha256.length() != 64 or not sha256.is_valid_hex_number(false):
		return _error("CONTENT_MANIFEST_INVALID", "SHA-256 trong manifest không hợp lệ.")
	if media_type not in ["image/png", "image/jpeg", "image/webp"]:
		return _error("CONTENT_MANIFEST_INVALID", "Định dạng ảnh trong manifest không được hỗ trợ.")
	if byte_size <= 0 or byte_size > MAX_IMAGE_BYTES:
		return _error("CONTENT_MANIFEST_INVALID", "Dung lượng asset trong manifest không an toàn.")
	if String(asset.get("url", "")).is_empty():
		return _error("CONTENT_MANIFEST_INVALID", "Asset trong manifest thiếu URL.")
	return {"ok": true}


static func _cache_path(asset: Dictionary) -> String:
	var extension := ".png"
	match String(asset.get("media_type", "")):
		"image/jpeg": extension = ".jpg"
		"image/webp": extension = ".webp"
	return CACHE_ROOT.path_join(String(asset.get("sha256", "")) + extension)


static func _absolute_content_url(url: String, api_base_url: String) -> String:
	if url.begins_with("https://") or url.begins_with("http://"):
		return url
	var base := api_base_url.trim_suffix("/")
	if base.ends_with("/api"):
		base = base.trim_suffix("/api")
	return base + (url if url.begins_with("/") else "/" + url)


static func _request_bytes(url: String) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return _error("CONTENT_REQUEST_FAILED", "Game chưa sẵn sàng để tải nội dung.")
	var request := HTTPRequest.new()
	request.timeout = 20.0
	tree.root.add_child(request)
	var start_error := request.request(url)
	if start_error != OK:
		request.queue_free()
		return _error("CONTENT_REQUEST_FAILED", "Không bắt đầu được yêu cầu tải nội dung.")
	var response: Array = await request.request_completed
	request.queue_free()
	if int(response[0]) != HTTPRequest.RESULT_SUCCESS:
		return _error("CONTENT_REQUEST_FAILED", "Không kết nối được máy chủ nội dung.")
	var status := int(response[1])
	if status < 200 or status >= 300:
		return _error("CONTENT_HTTP_ERROR", "Máy chủ nội dung trả lỗi HTTP %d." % status)
	return {"ok": true, "status": status, "body": response[3] as PackedByteArray}


static func _sha256_bytes(body: PackedByteArray) -> String:
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	context.update(body)
	return context.finish().hex_encode()


static func _valid_asset_id(value: String) -> bool:
	if value.is_empty() or value.length() > 64:
		return false
	for code in value.to_ascii_buffer():
		if not (
			(code >= 97 and code <= 122)
			or (code >= 48 and code <= 57)
			or code == 95
		):
			return false
	return true


static func _error(code: String, message: String) -> Dictionary:
	return {"ok": false, "error": {"code": code, "message": message}}
