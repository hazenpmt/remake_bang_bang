extends Node

const ROOM_SCENE := preload(
	"res://scenes/lobby/pvp/hub/PvpRoomView.tscn"
)


func _ready() -> void:
	call_deferred("_run")


func _run() -> void:
	var room_view := ROOM_SCENE.instantiate() as Control
	add_child(room_view)
	await get_tree().process_frame
	await get_tree().process_frame
	var before_room := {
		"id": "same-room-before-battle",
		"room_code": "268435491",
		"name": "PvP #20",
		"status": "running",
		"max_players": 5,
		"player_count": 1,
		"members": [{
			"account_id": "local-player",
			"display_name": "Beenn",
			"team_no": 1,
			"slot": 1,
			"tank_key": "gangtiexia03",
		}],
		"match": {
			"id": "local-test",
			"phase": "battle",
		},
	}
	room_view.call("_enter_ready_room", before_room)
	var match_flow := room_view.get_node("MatchFlow") as Control
	match_flow.visible = true
	match_flow.mouse_filter = Control.MOUSE_FILTER_STOP
	match_flow.call("_on_battle_result_exit_requested")
	var restored: Dictionary = room_view.get("_current_ready_room")
	assert(bool(room_view.get("_in_ready_room")))
	assert(String(restored.get("id", "")) == "same-room-before-battle")
	assert(String(restored.get("room_code", "")) == "268435491")
	assert(String(restored.get("status", "")) == "waiting")
	assert(not restored.has("match"))
	assert(not restored.has("matchmaking"))
	assert(room_view.get_node("Window/ReadyRoom").visible)
	assert(not match_flow.visible)
	room_view.queue_free()
	await get_tree().process_frame
	print("PVP_RESULT_RETURN_ROOM_SMOKE_OK")
	get_tree().quit(0)
