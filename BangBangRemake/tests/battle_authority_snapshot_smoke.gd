extends Node

const MAP_SCENE := preload("res://scenes/battle/PvpBattleMap.tscn")


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var map := MAP_SCENE.instantiate()
	add_child(map)
	await get_tree().process_frame
	var participants: Array[Dictionary] = []
	for team_no in [1, 2]:
		for slot_no in range(1, 6):
			participants.append({
				"account_id": "authority-%d-%d" % [team_no, slot_no],
				"display_name": "Authority %d-%d" % [team_no, slot_no],
				"team_no": team_no,
				"slot_no": slot_no,
				"tank_key": "gangtiexia03",
				"equipped_skin_key": "gangtiexia03_default",
				"is_bot": false,
			})
	var match_id := "authority-snapshot-smoke"
	map.call("prepare", {
		"id": match_id,
		"is_test": false,
		"viewer_team_no": 1,
		"participants": participants,
	})
	assert(bool(map.get("_server_authoritative_battle")))
	assert(not bool(map.get("_authoritative_ready")))
	map.set("_camera_following", true)
	map.call("_apply_authoritative_snapshot", _snapshot(map, match_id, 7, 4, 777))
	assert(bool(map.get("_authoritative_ready")))
	assert(int(map.get("_authoritative_revision")) == 7)
	assert(int(map.get("_authoritative_sequence")) == 4)
	assert(int(map.get("_current_hit_points")) == 777)
	assert(int((map.get("_team_scores") as Dictionary)[1]) == 9)
	assert(int((map.get("_team_scores") as Dictionary)[2]) == 6)
	assert(bool(map.get("_control_enabled")))
	assert((map.get("_player_anchor") as CharacterBody2D).position == Vector2(500, 500))
	var result_players: Array = map.call("_build_result_players")
	var viewer_result: Dictionary = result_players[0]
	assert(int(viewer_result.get("experience_reward", 0)) == 110)
	assert(int(viewer_result.get("silver_reward", 0)) == 17)
	assert(int(viewer_result.get("level", 0)) == 2)
	assert(int(viewer_result.get("experience", 0)) == 10)
	var player_before: Dictionary = (map.get("_combatants") as Dictionary)["player"]
	var hp_before := int(player_before.get("hit_points", 0))
	assert(int(map.call("_deal_damage", "participant:2:1", "player", 999999.0)) == 0)
	var player_after: Dictionary = (map.get("_combatants") as Dictionary)["player"]
	assert(int(player_after.get("hit_points", 0)) == hp_before)

	# An older poll must never roll back a newer command response.
	map.call("_apply_authoritative_snapshot", _snapshot(map, match_id, 6, 3, 1))
	assert(int(map.get("_authoritative_revision")) == 7)
	assert(int(map.get("_current_hit_points")) == 777)
	assert(int(map.get("_authoritative_sequence")) == 4)

	# Continuous input is coalesced while a command is in flight; discrete input
	# keeps its order. This test deliberately prevents the HTTP worker from running.
	map.set("_authoritative_command_in_flight", true)
	map.call("_enqueue_authoritative_command", {"type": "move", "x": 1.0, "y": 0.0})
	map.call("_enqueue_authoritative_command", {"type": "move", "x": 0.0, "y": 1.0})
	map.call("_enqueue_authoritative_command", {
		"type": "basic_attack", "target_x": 700.0, "target_y": 500.0,
	})
	var queue: Array = map.get("_authoritative_command_queue")
	assert(queue.size() == 2)
	assert(float((queue[0] as Dictionary).get("x", -1.0)) == 0.0)
	assert(float((queue[0] as Dictionary).get("y", -1.0)) == 1.0)
	assert(String((queue[1] as Dictionary).get("type", "")) == "basic_attack")
	map.set("_authoritative_command_in_flight", false)
	queue.clear()

	# Missing world state must fail closed. Keeping stale local NPC/building state
	# would otherwise reopen client authority after a partial server response.
	var incomplete := _snapshot(map, match_id, 8, 5, 600)
	(incomplete["world_entities"] as Array).pop_back()
	map.call("_apply_authoritative_snapshot", incomplete)
	assert(not bool(map.get("_authoritative_ready")))
	assert(not bool(map.get("_control_enabled")))
	map.call("_apply_authoritative_snapshot", _snapshot(map, match_id, 9, 5, 600))
	assert(bool(map.get("_authoritative_ready")))

	# A newly fenced worker may resume from the previous 500 ms checkpoint. Its
	# larger epoch authorizes a lower revision/continuous-input sequence.
	map.call("_apply_authoritative_snapshot", _snapshot(
		map, match_id, 1, 2, 550, 2
	))
	assert(int(map.get("_authoritative_state_epoch")) == 2)
	assert(int(map.get("_authoritative_revision")) == 1)
	assert(int(map.get("_authoritative_sequence")) == 2)
	assert(int(map.get("_current_hit_points")) == 550)

	# A mismatched snapshot locks controls and cannot silently fall back to local
	# combat, which is essential when reconnecting to a real online match.
	map.call("_apply_authoritative_snapshot", _snapshot(map, "wrong-match", 10, 6, 600))
	assert(not bool(map.get("_authoritative_ready")))
	assert(not bool(map.get("_control_enabled")))
	assert(bool(map.get("_server_authoritative_battle")))

	map.call("reset")
	map.call("prepare", {
		"id": "local-test",
		"is_test": true,
		"viewer_team_no": 1,
		"participants": participants,
	})
	assert(not bool(map.get("_server_authoritative_battle")))
	map.queue_free()
	await get_tree().process_frame
	print("BATTLE_AUTHORITY_SNAPSHOT_SMOKE_OK")
	get_tree().quit(0)


func _snapshot(
	map: Control,
	match_id: String,
	revision: int,
	sequence: int,
	viewer_hp: int,
	state_epoch: int = 1
) -> Dictionary:
	var entities: Array[Dictionary] = []
	for team_no in [1, 2]:
		for slot_no in range(1, 6):
			var is_viewer: bool = int(team_no) == 1 and slot_no == 1
			entities.append({
				"team_no": team_no,
				"slot_no": slot_no,
				"position_x": 500.0 + float(slot_no * 20),
				"position_y": 500.0 + float((team_no - 1) * 200),
				"hit_points": viewer_hp if is_viewer else 1000,
				"maximum_hit_points": 1000,
				"shield_points": 50 if is_viewer else 0,
				"dead": false,
				"respawn_remaining_ms": 0,
				"invulnerable_remaining_ms": 0,
				"basic_attack_cooldown_ms": 250 if is_viewer else 0,
				"skill_cooldowns_ms": {"1": 1000, "2": 2000, "3": 3000},
				"kills": 2 if is_viewer else 0,
				"deaths": 1 if is_viewer else 0,
				"assists": 3 if is_viewer else 0,
				"free_respawns_remaining": 1,
			})
			if is_viewer:
				entities[-1]["experience_reward"] = 110
				entities[-1]["silver_reward"] = 17
				entities[-1]["level_after"] = 2
				entities[-1]["experience_after"] = 10
				entities[-1]["silver_after"] = 5000017
	# Keep the viewer far enough from its scene spawn to exercise hard correction.
	entities[0]["position_x"] = 500.0
	entities[0]["position_y"] = 500.0
	var world_entities: Array[Dictionary] = []
	var building_instances: Dictionary = map.get("_map_building_instances")
	for building_id_value: Variant in building_instances.keys():
		var building_id := int(building_id_value)
		var building := building_instances[building_id] as Node2D
		assert(is_instance_valid(building))
		world_entities.append({
			"entity_key": "building:%d" % building_id,
			"entity_type": "building",
			"template_id": int(building.call("get_template_id")),
			"team_no": int(building.call("get_team_no")),
			"position_x": building.global_position.x,
			"position_y": building.global_position.y,
			"hit_points": int(building.call("get_maximum_hit_points")),
			"maximum_hit_points": int(building.call("get_maximum_hit_points")),
			"dead": false,
			"activated": true,
			"attack_serial": 0,
			"last_target_key": null,
		})
	for team_no in [1, 2]:
		world_entities.append({
			"entity_key": "chief:%d" % team_no,
			"entity_type": "chief",
			"team_no": team_no,
			"position_x": 400.0 if team_no == 1 else 1800.0,
			"position_y": 1142.5 if team_no == 1 else 252.0,
			"hit_points": 1494,
			"maximum_hit_points": 1494,
			"dead": false,
			"activated": true,
			"respawn_remaining_ms": 0,
			"attack_serial": 0,
			"last_target_key": null,
		})
	for building_id in [46, 47]:
		world_entities.append({
			"entity_key": "footpoint:%d" % building_id,
			"entity_type": "footpoint",
			"spawner_building_id": building_id,
			"team_no": 0,
			"position_x": 1296.0 if building_id == 46 else 864.0,
			"position_y": 480.0 if building_id == 46 else 936.0,
			"hit_points": 0,
			"maximum_hit_points": 80,
			"dead": true,
			"activated": false,
			"active_remaining_ms": 0,
			"respawn_remaining_ms": 0,
			"attack_serial": 0,
			"last_target_key": null,
		})
	return {
		"protocol_version": 2,
		"state_epoch": state_epoch,
		"match_id": match_id,
		"phase": "active",
		"revision": revision,
		"elapsed_ms": 12345,
		"team_1_score": 9,
		"team_2_score": 6,
		"viewer_team_no": 1,
		"viewer_slot_no": 1,
		"last_processed_sequence": sequence,
		"entities": entities,
		"world_entities": world_entities,
		"result": null,
	}
