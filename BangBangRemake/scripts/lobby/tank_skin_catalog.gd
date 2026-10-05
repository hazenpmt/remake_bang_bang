extends RefCounted

const AssetPathAliases := preload("res://scripts/data/asset_path_aliases.gd")

const QUALITY_RANK: Dictionary = {
	"A": 1,
	"S": 2,
	"SS": 3,
	"SSS": 4,
}

const TANK_TEXTURES: Dictionary = {
	"gangtiexia03": preload("res://assets/ui/tank/tank_ironman_reward.png"),
}

const SKIN_TEXTURES: Dictionary = {
	"gangtiexia03_default": preload(
		"res://assets/ui/tank/tank_ironman_reward.png"
	),
	"gangtiexia04": preload("res://assets/ui/tank/skin_ironman_2.png"),
	"gangtiexia05": preload("res://assets/ui/tank/skin_ironman_3.png"),
	"gangtiexia_pf04": preload("res://assets/ui/tank/skin_mk42.png"),
	"gangtiexia_pf01": preload("res://assets/ui/tank/skin_bao_sa_mac.png"),
	"gangtiexia_pf05": preload(
		"res://assets/animations/ironman_patriot_compact/shapes/2.png"
	),
	"gangtiexia_pf03": preload(
		"res://assets/ui/tank/skin_dung_si_binh_minh.png"
	),
	"gangtiexia_pf02": preload(
		"res://assets/ui/tank/skin_chien_canh_tuong_lai.png"
	),
	"gangtiexia_pf06": preload(
		"res://assets/animations/ironman_hong_lien_compact/shapes/2.png"
	),
}

const SKIN_ICON_TEXTURES: Dictionary = {
	"gangtiexia_pf01": preload(
		"res://assets/ui/tank/skin_icons/gangtiexia_pf01.png"
	),
	"gangtiexia_pf02": preload(
		"res://assets/ui/tank/skin_icons/gangtiexia_pf02.png"
	),
	"gangtiexia_pf03": preload(
		"res://assets/ui/tank/skin_icons/gangtiexia_pf03.png"
	),
	"gangtiexia_pf04": preload(
		"res://assets/ui/tank/skin_icons/gangtiexia_pf04.png"
	),
	"gangtiexia_pf05": preload(
		"res://assets/ui/tank/skin_icons/gangtiexia_pf05.png"
	),
}

const SKIN_ANIMATIONS: Dictionary = {
	"gangtiexia_pf05": (
		"res://assets/animations/ironman_patriot_compact/timeline.json"
	),
	"gangtiexia_pf06": (
		"res://assets/animations/ironman_hong_lien_compact/timeline.json"
	),
}

const SKIN_FRAME_TEXTURES: Dictionary = {
	"skinpreview": {
		"purple": preload("res://assets/ui/skinframe/skinpreview/purple.png"),
		"orange": preload("res://assets/ui/skinframe/skinpreview/orange.png"),
	},
	"tankcell": {
		"purple": preload("res://assets/ui/skinframe/tankcell/purple.png"),
		"orange": preload("res://assets/ui/skinframe/tankcell/orange.png"),
	},
	"tankinfo": {
		"purple": preload("res://assets/ui/skinframe/tankinfo/purple.png"),
		"orange": preload("res://assets/ui/skinframe/tankinfo/orange.png"),
	},
	"tankselect": {
		"purple": preload("res://assets/ui/skinframe/tankselect/purple.png"),
		"orange": preload("res://assets/ui/skinframe/tankselect/orange.png"),
	},
	"tanklist": {
		"purple": preload("res://assets/ui/skinframe/tanklist/purple.png"),
		"orange": preload("res://assets/ui/skinframe/tanklist/orange.png"),
	},
}


static func normalized_quality(value: Variant) -> String:
	var quality := String(value if value != null else "").strip_edges().to_upper()
	return quality if QUALITY_RANK.has(quality) else ""


static func owned_qualities(tank_data: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var skins: Variant = tank_data.get("skins", [])
	if skins is not Array:
		return result
	for skin_value: Variant in skins:
		if skin_value is not Dictionary:
			continue
		var skin: Dictionary = skin_value
		if skin.get("owned", false) != true:
			continue
		var quality := normalized_quality(skin.get("quality_key", ""))
		if not quality.is_empty():
			result[quality] = true
	return result


static func equipped_skin_key(tank_data: Dictionary) -> String:
	var direct_key := String(
		tank_data.get("equipped_skin_key", "")
	).strip_edges()
	if not direct_key.is_empty():
		return direct_key

	var default_key := ""
	var skins: Variant = tank_data.get("skins", [])
	if skins is not Array:
		return default_key
	for skin_value: Variant in skins:
		if skin_value is not Dictionary:
			continue
		var skin: Dictionary = skin_value
		if skin.get("owned", false) != true:
			continue
		var skin_key := String(skin.get("skin_key", "")).strip_edges()
		if skin.get("is_equipped", skin.get("equipped", false)) == true:
			return skin_key
		if skin.get("is_default", false) == true:
			default_key = skin_key
	return default_key


static func highest_owned_skin_key(tank_data: Dictionary) -> String:
	var best_key := ""
	var best_rank := -1
	var skins: Variant = tank_data.get("skins", [])
	if skins is not Array:
		return equipped_skin_key(tank_data)
	for skin_value: Variant in skins:
		if skin_value is not Dictionary:
			continue
		var skin: Dictionary = skin_value
		if skin.get("owned", false) != true:
			continue
		var skin_key := String(skin.get("skin_key", "")).strip_edges()
		if skin_key.is_empty():
			continue
		var rank := int(QUALITY_RANK.get(
			normalized_quality(skin.get("quality_key", "")),
			0
		))
		if rank > best_rank:
			best_rank = rank
			best_key = skin_key
	return best_key if not best_key.is_empty() else equipped_skin_key(tank_data)


static func skin_quality(tank_data: Dictionary, skin_key: String) -> String:
	var skins: Variant = tank_data.get("skins", [])
	if skins is not Array:
		return ""
	for skin_value: Variant in skins:
		if skin_value is not Dictionary:
			continue
		var skin: Dictionary = skin_value
		if String(skin.get("skin_key", "")).strip_edges() == skin_key:
			return normalized_quality(skin.get("quality_key", ""))
	return ""


static func skin_frame_tier(tank_data: Dictionary) -> String:
	var direct_tier := String(
		tank_data.get("skin_frame_tier", "")
	).strip_edges().to_lower()
	if direct_tier in ["purple", "orange"]:
		return direct_tier
	var collection_value: Variant = tank_data.get("skin_collection_bonus", {})
	if collection_value is Dictionary:
		var collection: Dictionary = collection_value
		var collection_tier := String(
			collection.get("frame_tier", "")
		).strip_edges().to_lower()
		if collection_tier in ["purple", "orange"]:
			return collection_tier
	return ""


static func skin_frame_texture(
	frame_group: String,
	tank_data: Dictionary
) -> Texture2D:
	var group_value: Variant = SKIN_FRAME_TEXTURES.get(frame_group, {})
	if group_value is not Dictionary:
		return null
	var tier := skin_frame_tier(tank_data)
	if tier.is_empty():
		return null
	return (group_value as Dictionary).get(tier) as Texture2D


static func find_owned_tank(data: Dictionary, tank_key: String) -> Dictionary:
	var owned_tanks: Variant = data.get("owned_tanks", [])
	if owned_tanks is not Array:
		return {}
	var primary_fallback: Dictionary = {}
	for tank_value: Variant in owned_tanks:
		if tank_value is not Dictionary:
			continue
		var tank: Dictionary = tank_value
		if bool(tank.get("is_primary", false)):
			primary_fallback = tank
		if String(tank.get("tank_key", "")).strip_edges() == tank_key:
			return tank
	return primary_fallback


static func texture_for(
	tank_data: Dictionary,
	tank_key: String,
	skin_key: String
) -> Texture2D:
	var skin_asset_path := _skin_preview_asset_path(tank_data, skin_key)
	var skin_asset_texture := _load_texture_path(skin_asset_path)
	if skin_asset_texture != null:
		return skin_asset_texture
	var known_skin := SKIN_TEXTURES.get(skin_key) as Texture2D
	if known_skin != null:
		return known_skin
	var tank_asset_texture := _load_texture_path(
		String(tank_data.get("tank_preview_asset_key", ""))
	)
	if tank_asset_texture != null:
		return tank_asset_texture
	return TANK_TEXTURES.get(tank_key) as Texture2D


static func animation_path(skin_key: String) -> String:
	return String(SKIN_ANIMATIONS.get(skin_key, ""))


static func catalog_texture_for(
	tank_data: Dictionary,
	tank_key: String,
	skin_key: String
) -> Texture2D:
	var skin_icon := icon_for(skin_key)
	if skin_icon != null:
		return skin_icon
	return texture_for(tank_data, tank_key, skin_key)


static func icon_for(skin_key: String) -> Texture2D:
	return SKIN_ICON_TEXTURES.get(skin_key) as Texture2D


static func _skin_preview_asset_path(
	tank_data: Dictionary,
	skin_key: String
) -> String:
	if skin_key.is_empty():
		return ""
	var skins: Variant = tank_data.get("skins", [])
	if skins is not Array:
		return ""
	for skin_value: Variant in skins:
		if skin_value is not Dictionary:
			continue
		var skin: Dictionary = skin_value
		if String(skin.get("skin_key", "")).strip_edges() == skin_key:
			return String(skin.get("preview_asset_key", "")).strip_edges()
	return ""


static func _load_texture_path(asset_path: String) -> Texture2D:
	var resolved_path := AssetPathAliases.resolve(asset_path)
	if (
		not asset_path.begins_with("res://")
		or not ResourceLoader.exists(resolved_path)
	):
		return null
	return ResourceLoader.load(resolved_path, "Texture2D") as Texture2D
