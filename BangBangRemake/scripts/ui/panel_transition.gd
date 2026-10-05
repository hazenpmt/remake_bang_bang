class_name PanelTransition
extends RefCounted

const OPEN_DURATION := 0.18
const CLOSE_DURATION := 0.13
const OPEN_SCALE := Vector2(0.92, 0.92)
const CLOSE_SCALE := Vector2(0.95, 0.95)


static func play_open(
	panel: Control,
	content: Control,
	active_tween: Tween = null
) -> Tween:
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	panel.visible = true
	panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
	content.pivot_offset = content.size * 0.5
	content.scale = OPEN_SCALE

	var tween := panel.create_tween()
	tween.set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(
		panel,
		"modulate",
		Color.WHITE,
		OPEN_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		content,
		"scale",
		Vector2.ONE,
		OPEN_DURATION
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tween


static func play_close(
	panel: Control,
	content: Control,
	active_tween: Tween = null
) -> Tween:
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	if not panel.visible:
		return null
	content.pivot_offset = content.size * 0.5

	var tween := panel.create_tween()
	tween.set_parallel(true)
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(
		panel,
		"modulate",
		Color(1.0, 1.0, 1.0, 0.0),
		CLOSE_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(
		content,
		"scale",
		CLOSE_SCALE,
		CLOSE_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(
		_finish_close.bind(panel, content)
	)
	return tween


static func _finish_close(panel: Control, content: Control) -> void:
	if not is_instance_valid(panel) or not is_instance_valid(content):
		return
	panel.visible = false
	panel.modulate = Color.WHITE
	content.scale = Vector2.ONE
