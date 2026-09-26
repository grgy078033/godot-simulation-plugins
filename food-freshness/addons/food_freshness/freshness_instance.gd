class_name FreshnessInstance
extends RefCounted
## Per-item freshness state using a caller-owned day value.
## Pure lookups never mutate or emit; update_day() is the notification path.

enum FreshnessState {
	FRESH,
	STALE,
	EXPIRED,
}

signal freshness_changed(old_state: int, new_state: int)
signal expired()

var profile: FreshnessProfile = null
var created_day: int = 0

var _comparison_state: int = FreshnessState.EXPIRED


## Assign a profile and creation day. The initial comparison state is silent.
func setup(value: FreshnessProfile, day: int) -> void:
	profile = value
	created_day = day
	_comparison_state = get_state(day)


## Age never becomes negative when a caller queries before creation.
func get_age(current_day: int) -> int:
	return maxi(current_day - created_day, 0)


func get_state(current_day: int) -> int:
	if profile == null:
		return FreshnessState.EXPIRED
	var age: int = get_age(current_day)
	var fresh_days: int = _fresh_duration()
	var stale_end: int = fresh_days + _stale_duration()
	if age < fresh_days:
		return FreshnessState.FRESH
	if age < stale_end:
		return FreshnessState.STALE
	return FreshnessState.EXPIRED


func days_until_stale(current_day: int) -> int:
	if profile == null:
		return 0
	return maxi(_fresh_duration() - get_age(current_day), 0)


func days_until_expired(current_day: int) -> int:
	if profile == null:
		return 0
	return maxi(_fresh_duration() + _stale_duration() - get_age(current_day), 0)


func is_fresh(current_day: int) -> bool:
	return get_state(current_day) == FreshnessState.FRESH


func is_stale(current_day: int) -> bool:
	return get_state(current_day) == FreshnessState.STALE


func is_expired(current_day: int) -> bool:
	return get_state(current_day) == FreshnessState.EXPIRED


## Reconcile a caller-owned day. Signals fire only when the state changes.
func update_day(day: int) -> void:
	var new_state: int = get_state(day)
	var old_state: int = _comparison_state
	if old_state == new_state:
		return
	_comparison_state = new_state
	freshness_changed.emit(old_state, new_state)
	if new_state == FreshnessState.EXPIRED:
		expired.emit()


func _fresh_duration() -> int:
	return maxi(profile.fresh_duration, 0) if profile != null else 0


func _stale_duration() -> int:
	return maxi(profile.stale_duration, 0) if profile != null else 0
