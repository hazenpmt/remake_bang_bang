extends SceneTree

const CLIENT_SCRIPT := preload(
	"res://scripts/network/battle_realtime_client.gd"
)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var api_url := OS.get_environment("BATTLE_REALTIME_TEST_API_URL")
	assert(not api_url.is_empty(), "BATTLE_REALTIME_TEST_API_URL is required.")
	var client := CLIENT_SCRIPT.new()
	root.add_child(client)
	var ticket_requests := [0]
	var pushed_snapshots: Array[Dictionary] = []
	client.snapshot_received.connect(
		func(snapshot: Dictionary) -> void:
			pushed_snapshots.append(snapshot)
	)
	client.ticket_requested.connect(
		func() -> void:
			ticket_requests[0] = int(ticket_requests[0]) + 1
			client.provide_ticket(
				"godot-live-ticket-%d" % int(ticket_requests[0])
			)
	)
	client.start(api_url, "godot-live-device")
	var deadline := Time.get_ticks_msec() + 5000
	while not client.is_usable() and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(client.is_usable(), "Godot did not complete the realtime handshake.")
	# The fixture retires the first socket. A reconnect must request a fresh
	# one-use ticket instead of reusing the first credential.
	deadline = Time.get_ticks_msec() + 5000
	while int(ticket_requests[0]) < 2 and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(
		int(ticket_requests[0]) >= 2,
		"Godot did not request a fresh reconnect ticket."
	)
	while not client.is_usable() and Time.get_ticks_msec() < deadline:
		await process_frame
	assert(client.is_usable(), "Godot did not reconnect with the fresh ticket.")

	var snapshot: Dictionary = await client.request_snapshot()
	assert(bool(snapshot.get("ok", false)))
	assert(String(snapshot.get("snapshot", {}).get("match_id", "")) == "fixture-match")
	assert(int(snapshot.get("snapshot", {}).get("revision", 0)) == 12)

	var command: Dictionary = await client.submit_command(
		1,
		{"type": "move", "x": 1.0, "y": 0.0}
	)
	assert(bool(command.get("ok", false)))
	assert(int(command.get("accepted_sequence", 0)) == 1)
	assert(int(command.get("snapshot", {}).get("revision", 0)) == 13)
	deadline = Time.get_ticks_msec() + 3000
	while Time.get_ticks_msec() < deadline:
		var received_delta_state := false
		for pushed: Dictionary in pushed_snapshots:
			if int(pushed.get("revision", 0)) == 13:
				received_delta_state = true
				assert(
					float((pushed.get("entities", []) as Array)[0].get("x", 0))
					== 12.0
				)
				break
		if received_delta_state:
			break
		await process_frame
	assert(
		int(pushed_snapshots.back().get("revision", 0)) == 13,
		"Godot did not reconstruct the pushed delta snapshot."
	)

	client.close()
	client.queue_free()
	print("BATTLE_REALTIME_LIVE_SMOKE_OK")
	quit(0)
