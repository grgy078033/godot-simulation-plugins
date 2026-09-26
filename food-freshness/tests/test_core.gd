extends SceneTree
## Focused dependency-free freshness contract runner.
## godot --headless --path . --script tests/test_core.gd

var _checks: int = 0
var _failures: int = 0
var _state_events: Array[Vector2i] = []
var _expired_events: int = 0


func _initialize() -> void:
	_run()


func _run() -> void:
	var profile := _profile()
	var instance := FreshnessInstance.new()
	instance.setup(profile, 10)
	instance.freshness_changed.connect(_on_freshness_changed)
	instance.expired.connect(_on_expired)
	_check(instance.profile == profile, "setup stores the profile")
	_check(instance.created_day == 10, "setup stores the creation day")

	# The independent day model is age=max(day-created, 0), with [fresh, stale) bands.
	_check(instance.get_age(10) == 0, "created day has age zero")
	_check(instance.get_age(8) == 0, "before creation clamps age to zero")
	_check(instance.get_state(10) == FreshnessInstance.FreshnessState.FRESH, "age zero is fresh")
	_check(instance.get_state(11) == FreshnessInstance.FreshnessState.FRESH, "age one is fresh")
	_check(instance.get_state(12) == FreshnessInstance.FreshnessState.FRESH, "age two is fresh")
	_check(instance.get_state(13) == FreshnessInstance.FreshnessState.STALE, "age three is stale")
	_check(instance.get_state(14) == FreshnessInstance.FreshnessState.STALE, "age four is stale")
	_check(instance.get_state(15) == FreshnessInstance.FreshnessState.EXPIRED, "age five is expired")
	_check(instance.is_fresh(10) and not instance.is_stale(10) and not instance.is_expired(10), "fresh predicates")
	_check(instance.is_stale(13) and not instance.is_fresh(13) and not instance.is_expired(13), "stale predicates")
	_check(instance.is_expired(15) and not instance.is_fresh(15) and not instance.is_stale(15), "expired predicates")
	_check(instance.days_until_stale(10) == 3, "fresh countdown starts at three")
	_check(instance.days_until_stale(12) == 1, "stale countdown at age two")
	_check(instance.days_until_stale(13) == 0, "stale countdown clamps at boundary")
	_check(instance.days_until_expired(10) == 5, "expiration countdown starts at five")
	_check(instance.days_until_expired(13) == 2, "expiration countdown at stale start")
	_check(instance.days_until_expired(14) == 1, "expiration countdown before boundary")
	_check(instance.days_until_expired(15) == 0, "expiration countdown clamps at zero")

	# Pure queries, including predicates, never alter the comparison state or emit.
	_check(_state_events.is_empty() and _expired_events == 0, "pure lookups emit no signals")
	instance.get_age(999)
	instance.get_state(999)
	instance.days_until_stale(999)
	instance.days_until_expired(999)
	instance.is_fresh(999)
	instance.is_stale(999)
	instance.is_expired(999)
	_check(_state_events.is_empty() and _expired_events == 0, "repeated pure queries remain silent")

	# Transitions, repeated updates, jumps and permitted rewinds.
	instance.update_day(11)
	_check(_state_events.is_empty(), "same-state update is silent")
	instance.update_day(13)
	_check(_state_events == [Vector2i(FreshnessInstance.FreshnessState.FRESH, FreshnessInstance.FreshnessState.STALE)], "fresh to stale signal args")
	instance.update_day(14)
	_check(_state_events.size() == 1, "repeated stale update is silent")
	instance.update_day(15)
	_check(_state_events.size() == 2, "stale to expired emits once")
	_check(_state_events[1] == Vector2i(FreshnessInstance.FreshnessState.STALE, FreshnessInstance.FreshnessState.EXPIRED), "expired transition args")
	_check(_expired_events == 1, "expired emits only on entry")
	instance.update_day(16)
	_check(_state_events.size() == 2 and _expired_events == 1, "repeated expired update is silent")
	instance.update_day(14)
	_check(_state_events.size() == 3, "rewind emits reverse transition")
	_check(_state_events[2] == Vector2i(FreshnessInstance.FreshnessState.EXPIRED, FreshnessInstance.FreshnessState.STALE), "rewind signal args")
	instance.update_day(15)
	_check(_state_events.size() == 4 and _expired_events == 2, "later expiry emits again")
	_check(_state_events[3] == Vector2i(FreshnessInstance.FreshnessState.STALE, FreshnessInstance.FreshnessState.EXPIRED), "later expiry args")

	# Setup initializes the comparison state silently even when reusing an instance.
	_state_events.clear()
	_expired_events = 0
	instance.setup(profile, 100)
	_check(_state_events.is_empty() and _expired_events == 0, "setup is silent")
	_check(instance.get_state(100) == FreshnessInstance.FreshnessState.FRESH, "setup reset state at new creation day")
	instance.update_day(105)
	_check(_state_events == [Vector2i(FreshnessInstance.FreshnessState.FRESH, FreshnessInstance.FreshnessState.EXPIRED)], "reused instance compares from new setup")
	_check(_expired_events == 1, "reused instance expiration signal")

	# Two instances can share a profile Resource but own identity and comparison state.
	var first := FreshnessInstance.new()
	var second := FreshnessInstance.new()
	first.setup(profile, 10)
	second.setup(profile, 10)
	first.update_day(13)
	_check(first.is_stale(13) and second.is_fresh(10), "shared profile instances keep independent state")
	_check(first.created_day == second.created_day, "shared profile does not merge item identity")
	profile.fresh_duration = 1
	_check(first.get_state(10) == FreshnessInstance.FreshnessState.FRESH, "shared profile edits are visible to lookup")
	_check(second.get_state(11) == FreshnessInstance.FreshnessState.STALE, "shared profile edit is visible to both instances")
	first.setup(profile, 10)
	second.setup(profile, 10)
	_check(first.get_state(11) == FreshnessInstance.FreshnessState.STALE, "normalized shared profile state")

	# Durations are normalized independently to zero; zero fresh means stale can start at age zero.
	var zero_profile := FreshnessProfile.new()
	zero_profile.fresh_duration = 0
	zero_profile.stale_duration = 0
	var zero_instance := FreshnessInstance.new()
	zero_instance.setup(zero_profile, 10)
	_check(zero_instance.get_state(10) == FreshnessInstance.FreshnessState.EXPIRED, "zero durations expire at creation")
	_check(zero_instance.days_until_stale(10) == 0 and zero_instance.days_until_expired(10) == 0, "zero duration countdowns are zero")
	var negative_profile := FreshnessProfile.new()
	negative_profile.fresh_duration = -1
	negative_profile.stale_duration = 2
	var negative_instance := FreshnessInstance.new()
	negative_instance.setup(negative_profile, 10)
	_check(negative_instance.get_state(10) == FreshnessInstance.FreshnessState.STALE, "negative fresh duration normalizes to zero")
	_check(negative_instance.get_state(12) == FreshnessInstance.FreshnessState.EXPIRED, "normalized stale duration boundary")
	_check(negative_instance.days_until_stale(10) == 0 and negative_instance.days_until_expired(10) == 2, "negative duration countdown normalization")

	# Missing profiles are a safe expired baseline with no crash and no positive countdown.
	var missing := FreshnessInstance.new()
	missing.setup(null, 10)
	_check(missing.profile == null, "missing profile remains null")
	_check(missing.get_age(8) == 0 and missing.get_state(10) == FreshnessInstance.FreshnessState.EXPIRED, "missing profile safe state")
	_check(missing.days_until_stale(10) == 0 and missing.days_until_expired(10) == 0, "missing profile zero countdowns")
	var missing_state_events: Array[Vector2i] = []
	missing.freshness_changed.connect(func(old_state: int, new_state: int) -> void: missing_state_events.append(Vector2i(old_state, new_state)))
	missing.update_day(100)
	_check(missing_state_events.is_empty(), "missing profile update remains silent")

	# Resource serialization preserves the editable profile contract.
	var save_profile := _profile()
	var save_path: String = "user://freshness_profile_test.tres"
	var save_error: Error = ResourceSaver.save(save_profile, save_path)
	_check(save_error == OK, "freshness profile saves")
	var loaded_profile: FreshnessProfile = load(save_path) as FreshnessProfile
	_check(loaded_profile != null, "freshness profile loads")
	if loaded_profile != null:
		_check(loaded_profile.fresh_duration == 3 and loaded_profile.stale_duration == 2, "serialized duration values")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))

	print("CORE: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _profile() -> FreshnessProfile:
	var value := FreshnessProfile.new()
	value.fresh_duration = 3
	value.stale_duration = 2
	return value


func _on_freshness_changed(old_state: int, new_state: int) -> void:
	_state_events.append(Vector2i(old_state, new_state))


func _on_expired() -> void:
	_expired_events += 1


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
