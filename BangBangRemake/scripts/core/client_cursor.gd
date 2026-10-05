extends Node


const GAME_CURSOR_PATH := "res://assets/ui/game_cursor_32x32.png"
const GAME_CURSOR_HOTSPOT := Vector2(3.0, 2.0)
const GAME_CURSOR_SHAPES := [
	Input.CURSOR_ARROW,
	Input.CURSOR_IBEAM,
	Input.CURSOR_POINTING_HAND,
	Input.CURSOR_CROSS,
	Input.CURSOR_WAIT,
	Input.CURSOR_BUSY,
	Input.CURSOR_DRAG,
	Input.CURSOR_CAN_DROP,
	Input.CURSOR_FORBIDDEN,
	Input.CURSOR_VSIZE,
	Input.CURSOR_HSIZE,
	Input.CURSOR_BDIAGSIZE,
	Input.CURSOR_FDIAGSIZE,
	Input.CURSOR_MOVE,
	Input.CURSOR_VSPLIT,
	Input.CURSOR_HSPLIT,
	Input.CURSOR_HELP,
]


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var game_cursor := load(GAME_CURSOR_PATH) as Texture2D
	if game_cursor != null:
		for cursor_shape in GAME_CURSOR_SHAPES:
			Input.set_custom_mouse_cursor(
				game_cursor,
				cursor_shape,
				GAME_CURSOR_HOTSPOT
			)
	else:
		push_warning("Không tải được ảnh con trỏ client: %s" % GAME_CURSOR_PATH)
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	get_tree().node_added.connect(_on_node_added)
	_apply_arrow_cursor(get_tree().root)


func _exit_tree() -> void:
	if DisplayServer.get_name() != "headless":
		for cursor_shape in GAME_CURSOR_SHAPES:
			Input.set_custom_mouse_cursor(null, cursor_shape)


func _on_node_added(node: Node) -> void:
	_apply_arrow_cursor_to_control(node)


func _apply_arrow_cursor(node: Node) -> void:
	_apply_arrow_cursor_to_control(node)
	for child in node.get_children():
		_apply_arrow_cursor(child)


func _apply_arrow_cursor_to_control(node: Node) -> void:
	if (
		node is Control
		and node.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND
	):
		node.mouse_default_cursor_shape = Control.CURSOR_ARROW
