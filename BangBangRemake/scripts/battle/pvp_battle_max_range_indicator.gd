class_name PvpBattleMaxRangeIndicator
extends Node2D

## The original `max_circle.png` is referenced by the client manifest but is
## no longer present in any local archive or cache.  This is a code-drawn
## fallback for that one missing range-boundary asset only; the actual aim
## arrow and target circle still use the converted original SWFs.

var radius := 0.0:
	set(value):
		radius = maxf(value, 0.0)
		if is_inside_tree():
			queue_redraw()

var target_is_valid := true:
	set(value):
		target_is_valid = value
		if is_inside_tree():
			queue_redraw()


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	if radius <= 0.0:
		return
	var alpha := 0.82 if target_is_valid else 0.34
	var core_color := Color(0.00, 0.86, 0.96, alpha)
	var glow_color := Color(0.22, 0.94, 1.00, alpha * 0.42)
	var outline_color := Color(0.00, 0.42, 0.57, alpha * 0.80)
	# Fine cyan ring and inner shadow match the thin outer range indicator in
	# the original reference without putting a newly-made bitmap in the repo.
	draw_arc(Vector2.ZERO, radius + 1.0, 0.0, TAU, 256, glow_color, 4.0, true)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 256, core_color, 1.5, true)
	draw_arc(Vector2.ZERO, radius - 3.0, 0.0, TAU, 256, outline_color, 1.0, true)
	# The four reinforced sections make the circle legible against bright maps,
	# as in the game capture, while keeping its measurement exact (radius=600).
	for angle in [0.0, PI * 0.5, PI, PI * 1.5]:
		draw_arc(
			Vector2.ZERO,
			radius,
			angle - 0.115,
			angle + 0.115,
			16,
			Color(0.28, 0.98, 1.00, alpha),
			3.0,
			true
		)
