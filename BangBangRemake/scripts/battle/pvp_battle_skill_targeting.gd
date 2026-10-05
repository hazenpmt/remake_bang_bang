class_name PvpBattleSkillTargeting
extends Node2D

## Original targeting SWFs used by Iron Man.  These are compact display-list
## timelines converted from rez/zh_CN/swf/ui/select, not recreated artwork.

const TIMELINE_PLAYER := preload(
	"res://scripts/animation/swf_timeline_player.gd"
)
const SELECT_ARROW := \
	"res://assets/animations/select_arrow_compact/timeline.json"
const SELECT_CIRCLE := \
	"res://assets/animations/select_circle_compact/timeline.json"
const MAX_RANGE_INDICATOR := preload(
	"res://scripts/battle/pvp_battle_max_range_indicator.gd"
)

const MODE_POINT := "point"
const MODE_DIRECTION := "direction"

# Measurements below are the authored, post-transform dimensions of the
# original select_arrow/select_circle SWFs.  The original battle client scales
# those instances at runtime from the skill XML; it does not edit the artwork.
const POINT_CIRCLE_NATIVE_DIAMETER := 75.47
const DIRECTION_ARROW_NATIVE_WIDTH := 47.94
const DIRECTION_ARROW_NATIVE_TIP_DISTANCE := 165.45

var _active := false
var _skill_index := -1
var _mode := MODE_POINT
var _maximum_range := 0.0
var _selection_size := 0.0
var _origin := Vector2.ZERO
var _target := Vector2.ZERO
var _valid_target := false
var _has_target := false
var _last_direction := Vector2.RIGHT

var _point_circle: Node2D
# Kept untyped because the fallback is a small purpose-built Node2D with
# `radius` and `target_is_valid` properties, not a generic timeline player.
var _range_circle
var _arrow: Node2D


func _ready() -> void:
	z_index = 8
	_point_circle = _make_indicator(SELECT_CIRCLE)
	_range_circle = MAX_RANGE_INDICATOR.new()
	add_child(_range_circle)
	_range_circle.z_index = -1
	_arrow = _make_indicator(SELECT_ARROW)
	hide()


func begin(
	skill_index: int,
	mode: String,
	maximum_range: float,
	selection_size: float
) -> void:
	_skill_index = skill_index
	_mode = mode
	_maximum_range = maxf(maximum_range, 0.0)
	_selection_size = maxf(selection_size, 0.0)
	_active = true
	_valid_target = false
	_has_target = false
	show()
	_refresh_visibility()


func update_target(origin: Vector2, candidate: Vector2) -> void:
	if not _active:
		return
	_origin = origin
	_target = candidate
	_has_target = true
	var offset := candidate - origin
	if offset.length_squared() > 0.001:
		_last_direction = offset.normalized()
	# The original directional skills accept a mouse direction even after the
	# cursor crosses the range ring.  R and Space therefore fire toward the
	# cursor at their authored 600 range.  Only point-targeted E is rejected
	# outside the ring.
	_valid_target = (
		_mode == MODE_DIRECTION
		or offset.length() <= _maximum_range
	)
	_refresh_visibility()
	_apply_preview()


func is_active() -> bool:
	return _active


func active_skill_index() -> int:
	return _skill_index


func cancel() -> void:
	_active = false
	_skill_index = -1
	_valid_target = false
	_has_target = false
	_refresh_visibility()
	hide()


func confirm() -> Dictionary:
	if not _active or not _valid_target:
		return {}
	var confirmed_target := _target
	if _mode == MODE_DIRECTION:
		# Keep the network command bounded to the real skill range while still
		# accepting a cursor positioned beyond it.
		confirmed_target = _origin + _last_direction * _maximum_range
	var cast := {
		"skill_index": _skill_index,
		"origin": _origin,
		"target": confirmed_target,
		"direction": _last_direction,
	}
	cancel()
	return cast


func _make_indicator(timeline_path: String) -> Node2D:
	var indicator := TIMELINE_PLAYER.new() as Node2D
	indicator.timeline_path = timeline_path
	indicator.autoplay = false
	indicator.loop = false
	indicator.visible = false
	add_child(indicator)
	return indicator


func _refresh_visibility() -> void:
	if _point_circle == null:
		return
	_point_circle.visible = _active and _mode == MODE_POINT
	# The original client keeps the maximum-range ring on while targeting.
	# It is a visual boundary, not merely an out-of-range warning.
	_range_circle.visible = _active
	_arrow.visible = _active and _mode == MODE_DIRECTION


func _apply_preview() -> void:
	var preview_modulate := Color.WHITE if _valid_target else Color(1, 1, 1, 0.35)
	_range_circle.position = _origin
	_range_circle.radius = _maximum_range
	_range_circle.target_is_valid = _valid_target
	if _mode == MODE_POINT:
		_point_circle.position = _target
		var point_scale := _selection_size / POINT_CIRCLE_NATIVE_DIAMETER
		_point_circle.scale = Vector2.ONE * point_scale
		_point_circle.modulate = preview_modulate
		return

	# select_arrow is authored vertically. The XML SRangeParam/iWidth controls
	# its width while iRange controls the distance from the tank to its arrow tip.
	# This is the same original SWF for R and Space; only those XML dimensions
	# differ (96 wide for R, 48 wide for Space).
	var rotation_value := _last_direction.angle() + PI * 0.5
	_arrow.position = _origin
	_arrow.rotation = rotation_value
	_arrow.scale = Vector2(
		_selection_size / DIRECTION_ARROW_NATIVE_WIDTH,
		_maximum_range / DIRECTION_ARROW_NATIVE_TIP_DISTANCE
	)
	_arrow.modulate = preview_modulate
