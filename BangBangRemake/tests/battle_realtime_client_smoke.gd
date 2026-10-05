extends SceneTree

const CLIENT_SCRIPT := preload(
	"res://scripts/network/battle_realtime_client.gd"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var client := CLIENT_SCRIPT.new()
	root.add_child(client)
	client.set("_api_base_url", "http://127.0.0.1:8080/api")
	assert(client.call("_websocket_url") == "ws://127.0.0.1:8080/api/realtime/battle")
	client.set("_api_base_url", "https://game.example/api")
	assert(client.call("_websocket_url") == "wss://game.example/api/realtime/battle")
	client.set("_explicit_websocket_url", "wss://battle-2.example/api/realtime/battle")
	assert(client.call("_websocket_url") == "wss://battle-2.example/api/realtime/battle")
	client.set("_explicit_websocket_url", "")

	var pushed: Array[Dictionary] = []
	client.snapshot_received.connect(
		func(snapshot: Dictionary) -> void:
			pushed.append(snapshot)
	)
	client.call("_handle_message", JSON.stringify({
		"type": "hello",
		"transport_version": 3,
		"protocol_version": 2,
	}))
	client.call("_handle_message", JSON.stringify({
		"type": "snapshot",
		"snapshot_serial": 1,
		"snapshot": {
			"protocol_version": 2,
			"match_id": "15",
			"state_epoch": 3,
			"revision": 8,
			"entities": [{
				"team_no": 1,
				"slot_no": 1,
				"hit_points": 100,
			}],
			"world_entities": [{
				"entity_key": "building:46",
				"hit_points": 500,
			}],
		},
	}))
	assert(pushed.size() == 1)
	assert(int(pushed[0].get("revision", -1)) == 8)
	client.call("_handle_message", JSON.stringify({
		"type": "snapshot_delta",
		"base_snapshot_serial": 1,
		"snapshot_serial": 2,
		"match_id": "15",
		"state_epoch": 3,
		"base_revision": 8,
		"revision": 9,
		"delta": {
			"set": {"revision": 9},
			"unset": [],
			"entities": [{
				"team_no": 1,
				"slot_no": 1,
				"set": {"hit_points": 91},
				"unset": [],
			}],
			"world_entities": [{
				"entity_key": "building:46",
				"set": {"hit_points": 470},
				"unset": [],
			}],
		},
	}))
	assert(pushed.size() == 2)
	assert(int(pushed[1].get("revision", -1)) == 9)
	assert(int((pushed[1].get("entities", []) as Array)[0].get("hit_points")) == 91)
	assert(
		int((pushed[1].get("world_entities", []) as Array)[0].get("hit_points"))
		== 470
	)
	assert(not bool(client.call("_accept_snapshot_delta", {
		"base_snapshot_serial": 99,
		"snapshot_serial": 100,
	})))

	var pending: Dictionary = client.get("_pending")
	pending[7] = null
	client.call("_handle_message", JSON.stringify({
		"type": "command_result",
		"request_id": 7,
		"ok": true,
		"accepted_sequence": 3,
	}))
	pending = client.get("_pending")
	assert(bool((pending[7] as Dictionary).get("ok", false)))
	assert(int((pending[7] as Dictionary).get("accepted_sequence", 0)) == 3)

	pending[8] = null
	client.call("_handle_message", JSON.stringify({
		"type": "error",
		"request_id": 8,
		"ok": false,
		"status": 409,
		"error": {"code": "BATTLE_SEQUENCE_GAP", "expected_sequence": 4},
	}))
	pending = client.get("_pending")
	assert(not bool((pending[8] as Dictionary).get("ok", true)))
	assert(int((pending[8] as Dictionary).get("status", 0)) == 409)

	client.close()
	client.queue_free()
	print("BATTLE_REALTIME_CLIENT_SMOKE_OK")
	quit(0)
