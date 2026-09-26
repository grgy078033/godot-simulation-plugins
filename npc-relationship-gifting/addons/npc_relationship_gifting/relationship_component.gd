class_name RelationshipComponent
extends Node
## Lightweight point state and gift resolution for one relationship profile.
## Assigning profile preserves the current points and clamps only when its bounds require it.

signal relationship_changed(old_value: int, new_value: int)
signal gift_given(item_id: StringName, reaction: int, relationship_change: int)

const MAX_SAFE_SCALED_POINTS: float = 9.0e18

@export var profile: RelationshipProfile:
	get:
		return _profile
	set(value):
		_profile = value
		_clamp_existing_points()

var points: int:
	get:
		return _points
	set(value):
		set_points(value)

var _profile: RelationshipProfile = null
var _points: int = 0


func add_points(amount: int) -> void:
	_set_points(_points + amount)


func remove_points(amount: int) -> void:
	_set_points(_points - amount)


func set_points(value: int) -> void:
	_set_points(value)


func get_points() -> int:
	return _points


func get_normalized_relationship() -> float:
	var minimum: int = _get_minimum_points()
	var maximum: int = _get_effective_maximum_points()
	var width: int = maximum - minimum
	if width <= 0:
		return 0.0
	return clamp(float(_points - minimum) / float(width), 0.0, 1.0)


func get_relationship_level() -> RelationshipLevel:
	if _profile == null:
		return null
	var selected: RelationshipLevel = null
	for level: RelationshipLevel in _profile.levels:
		if level == null or level.minimum_points > _points:
			continue
		if selected == null or level.minimum_points > selected.minimum_points:
			selected = level
	return selected


## Invalid multipliers emit no gift signal; nonfinite scaled values are rejected and
## finite oversized values saturate to the corresponding profile bound.
func give_gift(item_id: StringName, multiplier: float = 1.0) -> GiftResult:
	var preference: GiftPreference = _find_preference(item_id)
	var reaction: int = GiftPreference.Reaction.NEUTRAL
	var base_points: int = 0
	if preference != null:
		reaction = preference.reaction
		base_points = preference.relationship_change
	var result := GiftResult.new(reaction, base_points, 0)
	if not is_finite(multiplier) or multiplier < 0.0:
		return result
	var scaled_value: float = float(base_points) * multiplier
	if not is_finite(scaled_value):
		return result
	var old_points: int = _points
	var target_points: int
	if scaled_value >= MAX_SAFE_SCALED_POINTS:
		target_points = _get_effective_maximum_points()
	elif scaled_value <= -MAX_SAFE_SCALED_POINTS:
		target_points = _get_minimum_points()
	else:
		var scaled_points: int = int(round(scaled_value))
		target_points = _clamp_points(old_points + scaled_points)
	var applied_delta: int = target_points - old_points
	result.final_points = applied_delta
	# Compute and retain the result before relationship_changed callbacks can re-enter.
	_set_points(target_points)
	gift_given.emit(item_id, reaction, applied_delta)
	return result


func _find_preference(item_id: StringName) -> GiftPreference:
	if _profile == null:
		return null
	for preference: GiftPreference in _profile.gift_preferences:
		if preference != null and preference.item_id == item_id:
			return preference
	return null


func _get_minimum_points() -> int:
	return _profile.minimum_points if _profile != null else 0


func _get_effective_maximum_points() -> int:
	if _profile == null:
		return 0
	return maxi(_profile.maximum_points, _profile.minimum_points)


func _clamp_existing_points() -> void:
	_set_points(_points)


func _clamp_points(value: int) -> int:
	return clampi(value, _get_minimum_points(), _get_effective_maximum_points())


func _set_points(value: int) -> void:
	var clamped: int = _clamp_points(value)
	if clamped == _points:
		return
	var old_value: int = _points
	_points = clamped
	relationship_changed.emit(old_value, _points)
