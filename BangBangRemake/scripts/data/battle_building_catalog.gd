extends RefCounted

const AssetPathAliases := preload("res://scripts/data/asset_path_aliases.gd")

## Shared, source-of-truth definitions for map objects.
##
## A map must only store which template is placed where. Balance values and
## original visual state files live here so a change is applied consistently to
## every map that uses the same template. All cannon and missile turrets are
## structures in the current mode; crates, fences, sandbags and repair boxes
## remain destructible map objects.

const ASSET_ROOT := "res://assets/battle/buildings/npc/"

const KIND_REPAIR_BOX := "repair_box"
const KIND_CANNON := "cannon"
const KIND_MISSILE := "missile"
const KIND_DESTRUCTIBLE := "destructible"

const DAMAGE_STATE_NORMAL := 0
const DAMAGE_STATE_LIGHT := 1
const DAMAGE_STATE_MEDIUM := 2
const DAMAGE_STATE_HEAVY := 3
const DAMAGE_STATE_DESTROYED := 4

# Values below are transcribed from rez/zh_CN/xml/NpcTemplate_table.xml.
# They are not derived from a screenshot or guessed visual values.
const TEMPLATES: Dictionary = {
	1008: {
		"display_name": "Repair box - team 1",
		"kind": KIND_REPAIR_BOX,
		"width": 72,
		"height": 72,
		"image_width": 120,
		"image_height": 120,
		"hit_points": 3000,
		"physical_attack": 125,
		"energy_attack": 125,
		"armor": 0,
		"alert_range": 144,
		"attack_interval_ms": 1000,
		"can_attack": false,
		"friendly_visual_template_id": 1009,
		"enemy_visual_template_id": 1008,
		"hits_to_destroy": 20,
		"hits_per_damage_state": 5,
		"hide_after_destroy": true,
		"opposite_template_id": 1009,
		"destruction_swf": "destroy_npc01.swf",
		"visual_states": [
			{"base": "fixbox001.png"},
			{"base": "fixbox001_break1.png"},
			{"base": "fixbox001_break2.png"},
			{"base": "fixbox001_break3.png"},
			{"base": "fixbox001_break4.png"},
		],
	},
	1009: {
		"display_name": "Repair box - team 2",
		"kind": KIND_REPAIR_BOX,
		"width": 72,
		"height": 72,
		"image_width": 120,
		"image_height": 120,
		"hit_points": 3000,
		"physical_attack": 125,
		"energy_attack": 125,
		"armor": 0,
		"alert_range": 144,
		"attack_interval_ms": 1000,
		"can_attack": false,
		"friendly_visual_template_id": 1009,
		"enemy_visual_template_id": 1008,
		"hits_to_destroy": 20,
		"hits_per_damage_state": 5,
		"hide_after_destroy": true,
		"opposite_template_id": 1008,
		"destruction_swf": "destroy_npc01.swf",
		# XML itself points the first broken slot to break2; preserve that source.
		"visual_states": [
			{"base": "fixbox002.png"},
			{"base": "fixbox002_break2.png"},
			{"base": "fixbox002_break2.png"},
			{"base": "fixbox002_break3.png"},
			{"base": "fixbox002_break4.png"},
		],
	},
	1102: {
		"display_name": "Cannon turret - team 1",
		"kind": KIND_CANNON,
		"width": 72,
		"height": 72,
		"image_width": 120,
		"image_height": 120,
		"hit_points": 3600,
		"physical_attack": 300,
		"energy_attack": 300,
		"armor": 50,
		"alert_range": 480,
		"attack_interval_ms": 1000,
		"muzzle_offset_pixels": 52.0,
		"can_attack": true,
		"is_structure": true,
		"friendly_visual_template_id": 1103,
		"enemy_visual_template_id": 1102,
		"opposite_template_id": 1103,
		"destruction_swf": "destroy_paota.swf",
		"visual_states": [
			{"base": "cannon1_base.png", "overlay": "cannon1_gun.png"},
			{"base": "cannon1_break1_base.png", "overlay": "cannon1_break1_gun.png"},
			{"base": "cannon1_break2_base.png", "overlay": "cannon1_break2_gun.png"},
			{"base": "cannon1_break3_base.png", "overlay": "cannon1_break3_gun.png"},
			{"base": "cannon1_break4.png"},
		],
	},
	1103: {
		"display_name": "Cannon turret - team 2",
		"kind": KIND_CANNON,
		"width": 72,
		"height": 72,
		"image_width": 120,
		"image_height": 120,
		"hit_points": 3600,
		"physical_attack": 300,
		"energy_attack": 300,
		"armor": 50,
		"alert_range": 480,
		"attack_interval_ms": 1000,
		"muzzle_offset_pixels": 52.0,
		"can_attack": true,
		"is_structure": true,
		"friendly_visual_template_id": 1103,
		"enemy_visual_template_id": 1102,
		"opposite_template_id": 1102,
		"destruction_swf": "destroy_paota.swf",
		"visual_states": [
			{"base": "cannon2_base.png", "overlay": "cannon2_gun.png"},
			{"base": "cannon2_break1_base.png", "overlay": "cannon2_break1_gun.png"},
			{"base": "cannon2_break2_base.png", "overlay": "cannon2_break2_gun.png"},
			{"base": "cannon2_break3_base.png", "overlay": "cannon2_break3_gun.png"},
			{"base": "cannon2_break4.png"},
		],
	},
	1105: {
		"display_name": "Missile turret - team 1",
		"kind": KIND_MISSILE,
		"width": 96,
		"height": 96,
		"image_width": 144,
		"image_height": 144,
		"hit_points": 9600,
		"physical_attack": 600,
		"energy_attack": 600,
		"armor": 50,
		"alert_range": 480,
		"attack_interval_ms": 1250,
		"muzzle_offset_pixels": 59.0,
		"anti_stealth_range": 300,
		"can_attack": true,
		"is_structure": true,
		"damage_received_multiplier": 1.0,
		"friendly_visual_template_id": 1106,
		"enemy_visual_template_id": 1105,
		"opposite_template_id": 1106,
		"destruction_swf": "destroy_paota.swf",
		"visual_states": [
			{"base": "missile1_base.png", "overlay": "missile1_gun.png"},
			{"base": "missile1_break1_base.png", "overlay": "missile1_break1_gun.png"},
			{"base": "missile1_break2_base.png", "overlay": "missile1_break2_gun.png"},
			{"base": "missile1_break3_base.png", "overlay": "missile1_break3_gun.png"},
			{"base": "missile1_break4.png"},
		],
	},
	1106: {
		"display_name": "Missile turret - team 2",
		"kind": KIND_MISSILE,
		"width": 96,
		"height": 96,
		"image_width": 144,
		"image_height": 144,
		"hit_points": 9600,
		"physical_attack": 600,
		"energy_attack": 600,
		"armor": 50,
		"alert_range": 480,
		"attack_interval_ms": 1250,
		"muzzle_offset_pixels": 59.0,
		"anti_stealth_range": 300,
		"can_attack": true,
		"is_structure": true,
		"damage_received_multiplier": 1.0,
		"friendly_visual_template_id": 1106,
		"enemy_visual_template_id": 1105,
		"opposite_template_id": 1105,
		"destruction_swf": "destroy_paota.swf",
		"visual_states": [
			{"base": "missile2_base.png", "overlay": "missile2_gun.png"},
			{"base": "missile2_break1_base.png", "overlay": "missile2_break1_gun.png"},
			{"base": "missile2_break2_base.png", "overlay": "missile2_break2_gun.png"},
			{"base": "missile2_break3_base.png", "overlay": "missile2_break3_gun.png"},
			{"base": "missile2_break4.png"},
		],
	},
	5031: {
		"display_name": "Iron block",
		"kind": KIND_DESTRUCTIBLE,
		"width": 72,
		"height": 72,
		"image_width": 120,
		"image_height": 120,
		"hit_points": 400,
		"physical_attack": 100,
		"energy_attack": 100,
		"armor": 0,
		"alert_range": 0,
		"attack_interval_ms": 1000,
		"can_attack": false,
		"hits_to_destroy": 3,
		"hits_per_damage_state": 1,
		"hide_after_destroy": true,
		"destruction_swf": "",
		"visual_states": [
			{"base": "iron006.png"},
			{"base": "iron006.png"},
			{"base": "iron006.png"},
			{"base": "iron006.png"},
			{"base": "iron006.png"},
		],
	},
}


static func _destructible(
	display_name: String,
	width: int,
	height: int,
	hit_points: int,
	file_stem: String,
	destruction_swf: String,
	destroyed_file := ""
) -> Dictionary:
	if destroyed_file.is_empty():
		destroyed_file = "%s_break4.png" % file_stem
	return {
		"display_name": display_name,
		"kind": KIND_DESTRUCTIBLE,
		"width": width,
		"height": height,
		"image_width": width + 48,
		"image_height": height + 48,
		"hit_points": hit_points,
		"physical_attack": 100,
		"energy_attack": 100,
		"armor": 0,
		"alert_range": 0,
		"attack_interval_ms": 1000,
		"can_attack": false,
		"is_structure": false,
		"hits_to_destroy": 3,
		"hits_per_damage_state": 1,
		"hide_after_destroy": true,
		"destruction_swf": destruction_swf,
		"visual_states": [
			{"base": "%s.png" % file_stem},
			{"base": "%s_break1.png" % file_stem},
			{"base": "%s_break2.png" % file_stem},
			{"base": "%s_break3.png" % file_stem},
			{"base": destroyed_file},
		],
	}


static func get_template(template_id: int) -> Dictionary:
	if TEMPLATES.has(template_id):
		var template_value: Variant = TEMPLATES[template_id]
		if template_value is Dictionary:
			return (template_value as Dictionary).duplicate(true)
	match template_id:
		2003:
			# The XML supplies the four original damage assets. Gameplay keeps this
			# map prop on a three-basic-shot progression; that progression is stored
			# explicitly rather than inflating the source XML HP.
			return _destructible(
				"Wood crate",
				72,
				72,
				100,
				"box001",
				"destroy_npc01.swf",
				""
			)
		2004:
			return _destructible("Reinforced wood crate", 72, 72, 200, "box002", "destroy_npc01.swf")
		2006:
			return _destructible("Stacked wood crates", 144, 144, 300, "box004", "destroy_npc01.swf")
		2008:
			return _destructible("Sandbags", 72, 72, 300, "earthbags002", "destroy_npc05.swf", "box003_break4.png")
		2009:
			return _destructible("Wire mesh vertical", 48, 72, 200, "abatis001", "destroy_npc05.swf")
		2010:
			return _destructible("Wire mesh horizontal", 72, 48, 200, "abatis002", "destroy_npc05.swf")
		2011:
			return _destructible("Road block", 72, 72, 200, "roadblock001", "destroy_npc05.swf")
		_:
			return {}


static func get_visual_state(template: Dictionary, damage_state: int) -> Dictionary:
	var states_value: Variant = template.get("visual_states", [])
	if states_value is not Array or (states_value as Array).is_empty():
		return {}
	var states: Array = states_value
	var state_index := clampi(damage_state, 0, states.size() - 1)
	var state_value: Variant = states[state_index]
	if state_value is not Dictionary:
		return {}
	return (state_value as Dictionary).duplicate(true)


static func get_relation_visual_template(
	template: Dictionary,
	is_friendly_to_viewer: bool
) -> Dictionary:
	var relation_key := (
		"friendly_visual_template_id"
		if is_friendly_to_viewer
		else "enemy_visual_template_id"
	)
	var template_id := int(template.get(relation_key, 0))
	if template_id <= 0:
		return template.duplicate(true)
	var relation_template := get_template(template_id)
	return relation_template if not relation_template.is_empty() else template.duplicate(true)


static func destruction_timeline_path(template: Dictionary) -> String:
	match String(template.get("destruction_swf", "")):
		"destroy_npc01.swf":
			return "res://assets/animations/map_destroy_npc01_compact/timeline.json"
		"destroy_npc05.swf":
			return "res://assets/animations/map_destroy_npc05_compact/timeline.json"
		"destroy_paota.swf":
			return "res://assets/animations/map_destroy_paota_compact/timeline.json"
		_:
			return ""


static func asset_path(file_name: String) -> String:
	if file_name.is_empty():
		return ""
	return AssetPathAliases.resolve(ASSET_ROOT + file_name)
