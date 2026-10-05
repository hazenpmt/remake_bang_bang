extends RefCounted

const AssetPathAliases := preload("res://scripts/data/asset_path_aliases.gd")

## Exact head assets used by the PvP team cards.
##
## Files are copied byte-for-byte from rez/zh_CN/avatar/head.  The lookup is
## deliberately filename-based so adding another tank only requires adding
## its original logical-key file to the folder; no UI scene changes are
## needed.  A head SWF can be converted into the matching compact timeline
## folder under assets/animations/pvp_tank_heads/.

const HEAD_ROOT := "res://assets/ui/pvp_match_flow/tank_heads/"
const ANIMATION_ROOT := "res://assets/animations/pvp_tank_heads/"


static func texture_for(tank_key: String, skin_key: String) -> Texture2D:
	var candidates := _candidates(tank_key, skin_key)
	for candidate_value: Variant in candidates:
		var candidate := String(candidate_value).strip_edges()
		if candidate.is_empty():
			continue
		var path := AssetPathAliases.resolve(
			"%s%s.png" % [HEAD_ROOT, candidate]
		)
		if ResourceLoader.exists(path):
			return ResourceLoader.load(path, "Texture2D") as Texture2D
	return null


static func animation_path(tank_key: String, skin_key: String) -> String:
	var candidates := _candidates(tank_key, skin_key)
	for candidate_value: Variant in candidates:
		var candidate := String(candidate_value).strip_edges()
		if candidate.is_empty():
			continue
		var path := AssetPathAliases.resolve(
			"%s%s_compact/timeline.json" % [ANIMATION_ROOT, candidate]
		)
		if ResourceLoader.exists(path):
			return path
	return ""


static func _default_skin_key(tank_key: String) -> String:
	return "%s_default" % tank_key if not tank_key.is_empty() else ""


static func _candidates(tank_key: String, skin_key: String) -> Array:
	var normalized_skin := skin_key.strip_edges()
	var default_skin := _default_skin_key(tank_key)
	if not normalized_skin.is_empty() and normalized_skin != default_skin:
		# Never silently show a default head for an equipped non-default skin.
		# The caller will use its accurate full-tank fallback until that skin's
		# original head asset is added to this catalog.
		return [normalized_skin]
	return [default_skin, tank_key]
