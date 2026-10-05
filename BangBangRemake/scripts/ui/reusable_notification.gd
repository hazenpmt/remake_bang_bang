extends Control

signal confirmed(context: Variant)
signal cancelled(context: Variant)

@onready var _message: Label = $Dialog/Message
@onready var _confirm_button: TextureButton = $Dialog/Confirm
@onready var _cancel_button: TextureButton = $Dialog/Cancel

var _context: Variant = null


func _ready() -> void:
	_confirm_button.pressed.connect(_on_confirm_pressed)
	_cancel_button.pressed.connect(_on_cancel_pressed)
	set_process_input(false)


func show_message(
	message: String,
	show_cancel := false,
	context: Variant = null
) -> void:
	_message.text = message
	_cancel_button.visible = show_cancel
	_context = context
	visible = true
	set_process_input(true)
	move_to_front()


func close() -> void:
	visible = false
	set_process_input(false)


func is_open() -> bool:
	return visible


func get_message() -> String:
	return _message.text


func confirm() -> void:
	_on_confirm_pressed()


func cancel() -> void:
	_on_cancel_pressed()


func _on_confirm_pressed() -> void:
	if not visible:
		return
	var current_context: Variant = _context
	close()
	confirmed.emit(current_context)


func _on_cancel_pressed() -> void:
	if not visible:
		return
	var current_context: Variant = _context
	close()
	cancelled.emit(current_context)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		cancel()
		get_viewport().set_input_as_handled()
