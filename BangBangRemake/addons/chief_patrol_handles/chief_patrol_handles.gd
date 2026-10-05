@tool
extends EditorPlugin

const CHIEF_SCRIPT_PATH := "res://scripts/battle/pvp_battle_chief.gd"
const LEFT_PROPERTY := &"patrol_left_x"
const RIGHT_PROPERTY := &"patrol_right_x"
const HANDLE_RADIUS := 7.0
const HANDLE_HIT_RADIUS := 13.0
const HANDLE_COLOR := Color(0.05, 0.95, 1.0, 0.98)
const ACTIVE_HANDLE_COLOR := Color(1.0, 0.82, 0.1, 1.0)
const HANDLE_OUTLINE_COLOR := Color(1.0, 1.0, 1.0, 0.95)

var _dragging_chief: Node2D
var _dragging_property: StringName = &""
var _drag_start_value := 0.0
var _last_signature := Vector3(INF, INF, INF)


func _enter_tree() -> void:
	var selection := get_editor_interface().get_selection()
	if not selection.selection_changed.is_connected(_on_selection_changed):
		selection.selection_changed.connect(_on_selection_changed)
	set_process(true)
	update_overlays()


func _exit_tree() -> void:
	var selection := get_editor_interface().get_selection()
	if selection.selection_changed.is_connected(_on_selection_changed):
		selection.selection_changed.disconnect(_on_selection_changed)
	_cancel_drag()


func _process(_delta: float) -> void:
	var chief := _selected_chief()
	var signature := Vector3(INF, INF, INF)
	if chief != null:
		signature = Vector3(
			float(chief.get_instance_id()),
			float(chief.get(LEFT_PROPERTY)),
			float(chief.get(RIGHT_PROPERTY))
		)
	if signature != _last_signature:
		_last_signature = signature
		update_overlays()


func _handles(object: Object) -> bool:
	var node := object as Node2D
	if node == null:
		return false
	var node_script := node.get_script() as Script
	return (
		node_script != null
		and node_script.resource_path == CHIEF_SCRIPT_PATH
	)


func _edit(_object: Object) -> void:
	update_overlays()


func _make_visible(_visible: bool) -> void:
	update_overlays()


func _forward_canvas_draw_over_viewport(viewport_control: Control) -> void:
	var chief := _selected_chief()
	if chief == null:
		return
	var handle_positions := _handle_screen_positions(chief)
	_draw_handle(viewport_control, handle_positions[0], LEFT_PROPERTY)
	_draw_handle(viewport_control, handle_positions[1], RIGHT_PROPERTY)


func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and key_event.keycode == KEY_ESCAPE and _dragging_chief != null:
			_cancel_drag()
			return true
	if event is InputEventMouseMotion and _dragging_chief != null:
		_update_drag((event as InputEventMouseMotion).position)
		return true
	if not event is InputEventMouseButton:
		return false
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index == MOUSE_BUTTON_RIGHT and mouse_event.pressed:
		if _dragging_chief != null:
			_cancel_drag()
			return true
		return false
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return false
	if mouse_event.pressed:
		var chief := _selected_chief()
		if chief == null:
			return false
		var handle_positions := _handle_screen_positions(chief)
		var hits_left := mouse_event.position.distance_to(handle_positions[0]) <= HANDLE_HIT_RADIUS
		var hits_right := mouse_event.position.distance_to(handle_positions[1]) <= HANDLE_HIT_RADIUS
		if not hits_left and not hits_right:
			return false
		var property := LEFT_PROPERTY
		if hits_right and not hits_left:
			property = RIGHT_PROPERTY
		elif hits_left and hits_right:
			# When both ends overlap, clicking the right half selects the right end.
			property = (
				LEFT_PROPERTY
				if mouse_event.position.x < handle_positions[0].x
				else RIGHT_PROPERTY
			)
		_begin_drag(chief, property)
		return true
	if _dragging_chief != null:
		_finish_drag()
		return true
	return false


func _selected_chief() -> Node2D:
	var selected_nodes := get_editor_interface().get_selection().get_selected_nodes()
	if selected_nodes.size() != 1:
		return null
	var node := selected_nodes[0] as Node2D
	if node == null:
		return null
	var node_script := node.get_script() as Script
	if node_script == null or node_script.resource_path != CHIEF_SCRIPT_PATH:
		return null
	return node


func _handle_screen_positions(chief: Node2D) -> PackedVector2Array:
	var canvas_transform := _editor_canvas_transform()
	var world_y := chief.global_position.y
	return PackedVector2Array([
		canvas_transform * Vector2(float(chief.get(LEFT_PROPERTY)), world_y),
		canvas_transform * Vector2(float(chief.get(RIGHT_PROPERTY)), world_y),
	])


func _editor_canvas_transform() -> Transform2D:
	var editor_viewport := get_editor_interface().get_editor_viewport_2d()
	if editor_viewport == null:
		return Transform2D.IDENTITY
	return editor_viewport.global_canvas_transform


func _draw_handle(
	viewport_control: Control,
	position: Vector2,
	property: StringName
) -> void:
	var fill_color := (
		ACTIVE_HANDLE_COLOR
		if _dragging_chief != null and _dragging_property == property
		else HANDLE_COLOR
	)
	viewport_control.draw_circle(position, HANDLE_RADIUS, fill_color)
	viewport_control.draw_arc(
		position,
		HANDLE_RADIUS,
		0.0,
		TAU,
		24,
		HANDLE_OUTLINE_COLOR,
		2.0,
		true
	)


func _begin_drag(chief: Node2D, property: StringName) -> void:
	_dragging_chief = chief
	_dragging_property = property
	_drag_start_value = float(chief.get(property))
	update_overlays()


func _update_drag(screen_position: Vector2) -> void:
	if not is_instance_valid(_dragging_chief):
		_cancel_drag()
		return
	var world_position := _editor_canvas_transform().affine_inverse() * screen_position
	var new_value := snappedf(world_position.x, 1.0)
	if _dragging_property == LEFT_PROPERTY:
		new_value = minf(new_value, float(_dragging_chief.get(RIGHT_PROPERTY)))
	else:
		new_value = maxf(new_value, float(_dragging_chief.get(LEFT_PROPERTY)))
	_dragging_chief.set(_dragging_property, new_value)
	_dragging_chief.queue_redraw()
	update_overlays()


func _finish_drag() -> void:
	if not is_instance_valid(_dragging_chief):
		_clear_drag()
		return
	var chief := _dragging_chief
	var property := _dragging_property
	var final_value := float(chief.get(property))
	var initial_value := _drag_start_value
	_clear_drag()
	if is_equal_approx(initial_value, final_value):
		update_overlays()
		return
	chief.set(property, initial_value)
	var undo_redo := get_undo_redo()
	undo_redo.create_action("Kéo điểm tuần tra Tù trưởng")
	undo_redo.add_do_property(chief, property, final_value)
	undo_redo.add_undo_property(chief, property, initial_value)
	undo_redo.commit_action()
	chief.queue_redraw()
	update_overlays()


func _cancel_drag() -> void:
	if is_instance_valid(_dragging_chief):
		_dragging_chief.set(_dragging_property, _drag_start_value)
		_dragging_chief.queue_redraw()
	_clear_drag()
	update_overlays()


func _clear_drag() -> void:
	_dragging_chief = null
	_dragging_property = &""
	_drag_start_value = 0.0


func _on_selection_changed() -> void:
	if _dragging_chief != null:
		_cancel_drag()
	_last_signature = Vector3(INF, INF, INF)
	update_overlays()
