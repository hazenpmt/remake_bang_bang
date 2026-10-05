extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	print("MAP_MODAL_STAGE_START")
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	host.size = Vector2(1017, 618)
	root.add_child(host)

	var behind := Button.new()
	behind.position = Vector2(900, 150)
	behind.size = Vector2(100, 80)
	host.add_child(behind)
	var behind_presses := [0]
	behind.pressed.connect(func() -> void: behind_presses[0] += 1)

	var selector := load(
		"res://scenes/lobby/pvp/test/ready_room/PvpMapSelector.tscn"
	).instantiate() as Control
	host.add_child(selector)
	selector.show_maps([{
		"map_key": "random",
		"display_name": "Bản đồ ngẫu nhiên",
		"thumbnail_asset_path": "res://assets/ui/pvp_ready_room/maps/random.jpg",
	}], "random", true)
	await process_frame
	await process_frame
	print("MAP_MODAL_STAGE_OPEN")
	if (
		selector.mouse_filter != Control.MOUSE_FILTER_STOP
		or (selector.get_node("Dim") as Control).mouse_filter
			!= Control.MOUSE_FILTER_STOP
		or (selector.get_node("Window") as Control).mouse_filter
			!= Control.MOUSE_FILTER_STOP
	):
		push_error("Map selector modal filters are not configured correctly")
		quit(1)
		return

	# Click a point occupied by the underlying button but covered by the modal.
	_send_mouse(Vector2(950, 185), true)
	_send_mouse(Vector2(950, 185), false)
	await process_frame
	if not selector.visible or behind_presses[0] != 0:
		push_error("Map modal leaked its covered-area click")
		quit(1)
		return
	print("MAP_MODAL_STAGE_BLOCKED")

	# Click the selector's own X. It closes only after consuming the press, so
	# the release cannot activate the button underneath.
	var close := selector.get_node("Window/Close") as TextureButton
	var close_point := close.get_global_rect().get_center()
	# Headless mode has no native GUI hit-test. Emit TextureButton's actual
	# button_down signal to verify its deferred-close path, while the structural
	# assertions above verify the modal STOP/PASS configuration.
	close.button_down.emit()
	await process_frame
	_send_mouse(close_point, false)
	await process_frame
	if selector.visible or behind_presses[0] != 0:
		push_error(
			"Map modal close state visible=%s behind=%d point=%s"
			% [selector.visible, behind_presses[0], close_point]
		)
		quit(1)
		return
	print("MAP_SELECTOR_MODAL_OK")
	quit()


func _send_mouse(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.global_position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	Input.parse_input_event(event)
