class_name BattleGameplayRuleCatalog
extends RefCounted

const MODE_SCORE_RACE := "score_race"

# Maps declare only a gameplay_mode plus optional per-map overrides. Maps that
# share a mode therefore reuse the same scoring and finish semantics.
const RULES_BY_MODE := {
	MODE_SCORE_RACE: {
		"duration_seconds": 240.0,
		"score_limit": 25,
		"tank_kill_points": 1,
		"chief_kill_points": 1,
	},
}


static func resolve(map_layout: Dictionary) -> Dictionary:
	var mode := String(
		map_layout.get("gameplay_mode", MODE_SCORE_RACE)
	).strip_edges()
	if not RULES_BY_MODE.has(mode):
		push_warning("Gameplay mode không được hỗ trợ: %s" % mode)
		mode = MODE_SCORE_RACE
	var rules: Dictionary = RULES_BY_MODE[mode].duplicate(true)
	var overrides_value: Variant = map_layout.get("gameplay_rules", {})
	if overrides_value is Dictionary:
		rules.merge(overrides_value, true)
	rules["mode"] = mode
	rules["duration_seconds"] = maxf(
		float(rules.get("duration_seconds", 240.0)),
		1.0
	)
	rules["score_limit"] = maxi(int(rules.get("score_limit", 25)), 1)
	rules["tank_kill_points"] = maxi(
		int(rules.get("tank_kill_points", 1)),
		0
	)
	rules["chief_kill_points"] = maxi(
		int(rules.get("chief_kill_points", 1)),
		0
	)
	return rules
