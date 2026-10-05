class_name BattleHonorCalculator
extends RefCounted

## The result movie has three layouts: one, two, or three distinct honorees.
## Awards are selected across both teams.  A stable team/slot key resolves exact
## ties so every client reaches the same result.

const HONOR_ASSIST := "assist"
const HONOR_KILLER := "killer"
const HONOR_MVP := "mvp"


static func calculate(players: Array[Dictionary]) -> Dictionary:
	var eligible: Array[Dictionary] = []
	for player: Dictionary in players:
		if bool(player.get("is_chief", false)) or bool(
			player.get("is_neutral", false)
		):
			continue
		var entry := player.duplicate(true)
		entry["kills"] = maxi(int(entry.get("kills", 0)), 0)
		entry["deaths"] = maxi(int(entry.get("deaths", 0)), 0)
		entry["assists"] = maxi(int(entry.get("assists", 0)), 0)
		# Kills carry the most weight, assists reward team contribution, and each
		# death costs points.  No team/win bonus is used: either side may be MVP.
		entry["mvp_score"] = (
			float(entry["kills"]) * 5.0
			+ float(entry["assists"]) * 3.0
			- float(entry["deaths"]) * 2.0
		)
		eligible.append(entry)
	if eligible.is_empty():
		return {
			"awards": [],
			"winners": [],
			"segment": "label_p1",
			"segment_range": Vector2i(502, 646),
		}

	# The original result ceremony reveals recipients from left to right in this
	# fixed order. Keeping the award order here also makes grouped winners stable.
	var awards: Array[Dictionary] = []
	awards.append(_award(HONOR_MVP, _best(eligible, HONOR_MVP)))
	awards.append(_award(HONOR_KILLER, _best(eligible, HONOR_KILLER)))
	awards.append(_award(HONOR_ASSIST, _best(eligible, HONOR_ASSIST)))

	var winner_by_key: Dictionary = {}
	var ordered_keys: Array[String] = []
	for award: Dictionary in awards:
		var player: Dictionary = award["player"]
		var key := String(player.get("combatant_key", ""))
		if key.is_empty():
			key = "%d:%d:%s" % [
				int(player.get("team_no", 0)),
				int(player.get("slot_no", 0)),
				String(player.get("display_name", "")),
			]
		if not winner_by_key.has(key):
			var winner := player.duplicate(true)
			winner["honors"] = []
			winner_by_key[key] = winner
			ordered_keys.append(key)
		var winner: Dictionary = winner_by_key[key]
		var honors: Array = winner.get("honors", [])
		honors.append(String(award["type"]))
		winner["honors"] = honors
		winner_by_key[key] = winner

	var winners: Array[Dictionary] = []
	for key: String in ordered_keys:
		winners.append(winner_by_key[key])
	var segment := "label_p%d" % clampi(winners.size(), 1, 3)
	var segment_ranges := {
		"label_p3": Vector2i(190, 349),
		"label_p2": Vector2i(350, 501),
		"label_p1": Vector2i(502, 646),
	}
	return {
		"awards": awards,
		"winners": winners,
		"segment": segment,
		"segment_range": segment_ranges[segment],
	}


static func _award(honor_type: String, player: Dictionary) -> Dictionary:
	return {"type": honor_type, "player": player.duplicate(true)}


static func _best(players: Array[Dictionary], honor_type: String) -> Dictionary:
	var best := players[0]
	for index in range(1, players.size()):
		var candidate := players[index]
		if _is_better(candidate, best, honor_type):
			best = candidate
	return best


static func _is_better(
	candidate: Dictionary,
	current: Dictionary,
	honor_type: String
) -> bool:
	var fields: Array[String]
	match honor_type:
		HONOR_ASSIST:
			fields = ["assists", "kills"]
		HONOR_KILLER:
			fields = ["kills", "assists"]
		_:
			fields = ["mvp_score", "kills", "assists"]
	for field: String in fields:
		var candidate_value := float(candidate.get(field, 0.0))
		var current_value := float(current.get(field, 0.0))
		if not is_equal_approx(candidate_value, current_value):
			return candidate_value > current_value
	var candidate_deaths := int(candidate.get("deaths", 0))
	var current_deaths := int(current.get("deaths", 0))
	if candidate_deaths != current_deaths:
		return candidate_deaths < current_deaths
	var candidate_order := int(candidate.get("team_no", 0)) * 10 + int(
		candidate.get("slot_no", 0)
	)
	var current_order := int(current.get("team_no", 0)) * 10 + int(
		current.get("slot_no", 0)
	)
	return candidate_order < current_order
