extends SceneTree
## Focused contract runner:
## godot --headless --path . --script tests/test_core.gd

var _checks: int = 0
var _failures: int = 0
var _started: Array[StringName] = []
var _ended: Array[StringName] = []
var _signal_log: Array[String] = []
var _reentrant_log: Array[String] = []
var _reentrant_requested: bool = false
var _reentrant_scheduler: WorldEventScheduler = null


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var schedule: EventSchedule = _demo_schedule()
	_check(schedule.events.size() == 4, "demo schedule has four resources")
	_check(not schedule.is_event_active(&"shop_open", 7, 59), "day event inactive before start")
	_check(schedule.is_event_active(&"shop_open", 8, 0), "day event active at start")
	_check(schedule.is_event_active(&"shop_open", 17, 59), "day event active before end")
	_check(not schedule.is_event_active(&"shop_open", 18, 0), "day event inactive at end")
	_check(schedule.is_event_active(&"shop_open", 32, 0), "normalized 32:00 resolves to 08:00")
	_check(schedule.is_event_active(&"street_lights", 42, 0), "normalized overnight query at 18:00")
	_check(schedule.is_event_active(&"street_lights", -6, 0), "negative query clock normalizes to 18:00")
	_check(schedule.is_event_active(&"street_lights", 2, 0), "overnight event active after midnight")
	_check(not schedule.is_event_active(&"street_lights", 6, 0), "overnight event inactive at end")
	_check(schedule.is_event_active(&"ghost_spawn", 4, 59), "second overnight event active before end")
	_check(not schedule.is_event_active(&"ghost_spawn", 5, 0), "second overnight event inactive at end")
	_check(not schedule.is_event_active(&"missing", 10, 0), "unknown event is inactive")
	_check(not schedule.is_event_active(&"", 10, 0), "empty event ID is inactive")

	var empty_schedule: EventSchedule = EventSchedule.new()
	_check(not empty_schedule.is_event_active(&"missing", 10, 0), "empty schedule active query is false")
	_check(empty_schedule.get_active_events(10, 0).is_empty(), "empty schedule active list is empty")
	_check(empty_schedule.get_next_event(10, 0) == null, "empty schedule next event is null")
	_check(empty_schedule.minutes_until_event(&"missing", 10, 0) == -1, "empty schedule minutes query is -1")

	var active_at_22: Array[ScheduledEvent] = schedule.get_active_events(22, 0)
	_check(active_at_22.size() == 3, "concurrent events are returned")
	_check(active_at_22[0].event_id == &"street_lights" and active_at_22[1].event_id == &"tavern_music", "active events preserve inspector order")
	_check(active_at_22[2].event_id == &"ghost_spawn", "active event order includes later concurrent event")
	var independent_active: Array[ScheduledEvent] = schedule.get_active_events(22, 0)
	independent_active.clear()
	_check(independent_active.is_empty() and schedule.events.size() == 4, "active result array is independent")
	_check(schedule.events[0].event_id == &"shop_open", "queries do not reorder inspector data")

	var before_shop: ScheduledEvent = schedule.get_next_event(7, 59)
	_check(before_shop != null and before_shop.event_id == &"shop_open", "next event finds the next start")
	_check(schedule.minutes_until_event(&"shop_open", 7, 59) == 1, "minutes until next start")
	_check(schedule.minutes_until_event(&"shop_open", 8, 0) == 1440, "exact start is next day for minutes query")
	_check(schedule.minutes_until_event(&"street_lights", 18, 0) == 1440, "exact overnight start is 1440")
	_check(schedule.minutes_until_event(&"street_lights", 18, 30) == 1410, "active event counts to its next start")
	_check(schedule.minutes_until_event(&"missing", 12, 0) == -1, "unknown minutes query is -1")
	_check(schedule.minutes_until_event(&"", 12, 0) == -1, "empty minutes query is -1")
	var at_8_next: ScheduledEvent = schedule.get_next_event(8, 0)
	_check(at_8_next != null and at_8_next.event_id == &"street_lights", "next start is strictly after now")
	var exact_ghost_next: ScheduledEvent = schedule.get_next_event(22, 0)
	_check(exact_ghost_next != null and exact_ghost_next.event_id == &"shop_open", "exact event start skips to the next daily start")

	var tied_schedule: EventSchedule = EventSchedule.new()
	var tied_first: ScheduledEvent = _event(&"first_tie", 12, 0, 13, 0)
	var tied_second: ScheduledEvent = _event(&"second_tie", 12, 0, 13, 0)
	tied_schedule.events.assign([tied_first, tied_second])
	var tied_next: ScheduledEvent = tied_schedule.get_next_event(10, 0)
	_check(tied_next == tied_first, "same-time next event keeps input order")
	_check(tied_schedule.get_next_event(12, 0) == tied_first, "same-time exact start wraps without changing tie order")

	var unsorted_schedule: EventSchedule = EventSchedule.new()
	var unsorted_late: ScheduledEvent = _event(&"late", 12, 0, 13, 0)
	var unsorted_early: ScheduledEvent = _event(&"early", 8, 0, 9, 0)
	unsorted_schedule.events.assign([unsorted_late, unsorted_early])
	_check(unsorted_schedule.get_next_event(7, 0) == unsorted_early, "unsorted events choose the earliest upcoming start")
	var unsorted_active: Array[ScheduledEvent] = unsorted_schedule.get_active_events(12, 0)
	_check(unsorted_active.size() == 1 and unsorted_active[0] == unsorted_late, "unsorted active query still resolves the right event")
	_check(unsorted_schedule.events[0] == unsorted_late, "unsorted query preserves input order")

	var oracle_schedule: EventSchedule = EventSchedule.new()
	var oracle_lights: ScheduledEvent = _event(&"street_lights", 18, 0, 6, 0)
	var oracle_pulse: ScheduledEvent = _event(&"midday_pulse", 11, 37, 12, 23)
	var oracle_shop: ScheduledEvent = _event(&"shop_open", 8, 0, 18, 0)
	# Deliberately unsorted input; expected values below come from fixed local windows.
	oracle_schedule.events.assign([oracle_lights, oracle_pulse, oracle_shop])
	var oracle_windows: Array[Dictionary] = [
		{"id": &"street_lights", "start": 1080, "end": 360},
		{"id": &"midday_pulse", "start": 697, "end": 743},
		{"id": &"shop_open", "start": 480, "end": 1080},
	]
	var oracle_active_ok: bool = true
	var oracle_next_ok: bool = true
	var oracle_minutes_ok: bool = true
	for minute_of_day: int in range(1440):
		var query_hour: int = int(minute_of_day / 60.0)
		var query_minute: int = minute_of_day % 60
		var expected_active: Array[StringName] = []
		for window: Dictionary in oracle_windows:
			if _oracle_is_active(int(window["start"]), int(window["end"]), minute_of_day):
				expected_active.append(window["id"] as StringName)
		var actual_active: Array[StringName] = []
		for event: ScheduledEvent in oracle_schedule.get_active_events(query_hour, query_minute):
			actual_active.append(event.event_id)
		if actual_active != expected_active:
			oracle_active_ok = false

		var expected_next_index: int = _oracle_next_index(oracle_windows, minute_of_day)
		var actual_next: ScheduledEvent = oracle_schedule.get_next_event(query_hour, query_minute)
		if expected_next_index < 0:
			if actual_next != null:
				oracle_next_ok = false
		else:
			var expected_next_id: StringName = oracle_windows[expected_next_index]["id"] as StringName
			var expected_delta: int = _oracle_minutes_until(int(oracle_windows[expected_next_index]["start"]), minute_of_day)
			if actual_next == null or actual_next.event_id != expected_next_id:
				oracle_next_ok = false
			if oracle_schedule.minutes_until_event(expected_next_id, query_hour, query_minute) != expected_delta:
				oracle_minutes_ok = false
	_check(oracle_active_ok, "independent full-day oracle matches active IDs for all 1440 minutes")
	_check(oracle_next_ok, "independent full-day oracle matches next starts for all 1440 minutes")
	_check(oracle_minutes_ok, "independent full-day oracle matches minutes until start for all 1440 minutes")
	_check(not oracle_schedule.is_event_active(&"midday_pulse", 11, 36), "nonzero-minute event is inactive before its start")
	_check(oracle_schedule.is_event_active(&"midday_pulse", 11, 37), "nonzero-minute event is active at its start")
	_check(oracle_schedule.is_event_active(&"midday_pulse", 12, 22), "nonzero-minute event is active before its end")
	_check(not oracle_schedule.is_event_active(&"midday_pulse", 12, 23), "nonzero-minute event is inactive at its end")

	var edge_schedule: EventSchedule = EventSchedule.new()
	var invalid_clock: ScheduledEvent = _event(&"invalid", 24, 0, 2, 0)
	var empty_id: ScheduledEvent = _event(&"", 8, 0, 9, 0)
	var duplicate_first: ScheduledEvent = _event(&"duplicate", 8, 0, 10, 0)
	var duplicate_later: ScheduledEvent = _event(&"duplicate", 9, 0, 11, 0)
	var zero_duration: ScheduledEvent = _event(&"zero", 12, 0, 12, 0)
	edge_schedule.events.assign([null, invalid_clock, empty_id, duplicate_first, duplicate_later, zero_duration])
	var edge_active: Array[ScheduledEvent] = edge_schedule.get_active_events(9, 30)
	_check(edge_active.size() == 1 and edge_active[0] == duplicate_first, "null invalid and duplicate entries use first valid event")
	_check(edge_schedule.is_event_active(&"duplicate", 9, 30), "duplicate query resolves first valid entry")
	_check(edge_schedule.get_next_event(11, 0) == duplicate_first, "zero-duration event is excluded from upcoming starts")
	_check(edge_schedule.minutes_until_event(&"zero", 11, 0) == -1, "zero-duration minutes query is invalid")
	_check(edge_schedule.get_next_event(12, 0) == duplicate_first, "only valid nonzero event wraps daily")
	var only_zero: EventSchedule = EventSchedule.new()
	only_zero.events.assign([zero_duration])
	_check(only_zero.get_next_event(12, 0) == null, "schedule with only zero-duration event has no next event")

	var resource_path: String = "user://world_event_schedule_test.tres"
	_check(ResourceSaver.save(schedule, resource_path) == OK, "schedule Resource saves")
	var loaded_schedule: EventSchedule = load(resource_path) as EventSchedule
	_check(loaded_schedule != null, "schedule Resource loads")
	if loaded_schedule != null:
		_check(loaded_schedule.events.size() == 4, "serialized event array")
		_check(loaded_schedule.events[1].event_id == &"street_lights", "serialized event identity")
		_check(loaded_schedule.events[1].start_hour == 18 and loaded_schedule.events[1].end_hour == 6, "serialized overnight fields")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(resource_path))

	var scheduler := WorldEventScheduler.new()
	scheduler.schedule = schedule
	scheduler.event_started.connect(_on_event_started)
	scheduler.event_ended.connect(_on_event_ended)
	scheduler.update_time(7, 59)
	_check(_started.is_empty() and _ended.is_empty(), "inactive first update emits nothing")
	scheduler.update_time(8, 0)
	_check(_started == [&"shop_open"] and _ended.is_empty(), "first active update emits start")
	_check(scheduler.get_active_event_ids() == [&"shop_open"], "scheduler caches active IDs")
	var active_ids_copy: Array[StringName] = scheduler.get_active_event_ids()
	active_ids_copy.clear()
	_check(scheduler.get_active_event_ids() == [&"shop_open"], "scheduler active ID query is independent")
	var start_count: int = _started.size()
	var end_count: int = _ended.size()
	scheduler.update_time(8, 30)
	_check(_started.size() == start_count and _ended.size() == end_count, "repeated time in same window emits nothing")
	scheduler.update_time(18, 0)
	_check(_ended == [&"shop_open"] and _started == [&"shop_open", &"street_lights"], "end emits before new start")
	_check(_signal_log[1] == "ended:shop_open" and _signal_log[2] == "started:street_lights", "signal order is ended then started")
	scheduler.update_time(22, 0)
	_check(_started == [&"shop_open", &"street_lights", &"tavern_music", &"ghost_spawn"], "simultaneous distinct starts all emit")
	scheduler.update_time(23, 0)
	_check(_ended == [&"shop_open", &"tavern_music"], "ending active event emits once")
	var no_replay_started: int = _started.size()
	scheduler.update_time(23, 30)
	_check(_started.size() == no_replay_started, "same destination window does not replay")

	var jump_scheduler := WorldEventScheduler.new()
	jump_scheduler.schedule = schedule
	var jump_started: Array[StringName] = []
	var jump_ended: Array[StringName] = []
	jump_scheduler.event_started.connect(func(event_id: StringName) -> void: jump_started.append(event_id))
	jump_scheduler.event_ended.connect(func(event_id: StringName) -> void: jump_ended.append(event_id))
	jump_scheduler.update_time(8, 0)
	jump_started.clear()
	jump_scheduler.update_time(22, 0)
	_check(jump_started == [&"street_lights", &"tavern_music", &"ghost_spawn"], "time jump reconciles destination active set only")
	_check(jump_ended == [&"shop_open"], "time jump ends the old active set once")
	jump_started.clear()
	jump_ended.clear()
	jump_scheduler.update_time(8, 0)
	_check(jump_ended == [&"street_lights", &"tavern_music", &"ghost_spawn"] and jump_started == [&"shop_open"], "rewind reconciles destination without replay")

	var replacement_schedule: EventSchedule = EventSchedule.new()
	replacement_schedule.events.assign([_event(&"replacement", 0, 0, 23, 0)])
	scheduler.update_time(8, 0)
	var ended_before_replace: int = _ended.size()
	scheduler.schedule = replacement_schedule
	scheduler.update_time(8, 0)
	_check(_ended.size() == ended_before_replace + 1 and _ended[-1] == &"shop_open", "replaced schedule ends old active IDs on next update")
	_check(_started[-1] == &"replacement", "replaced schedule starts destination IDs")
	var ended_before_null: int = _ended.size()
	scheduler.schedule = null
	scheduler.update_time(8, 0)
	_check(_ended.size() == ended_before_null + 1 and _ended[-1] == &"replacement", "null schedule ends active IDs once")
	scheduler.update_time(8, 0)
	_check(_ended.size() == ended_before_null + 1, "repeated null schedule does not re-end IDs")

	_reentrant_scheduler = WorldEventScheduler.new()
	var reentrant_schedule: EventSchedule = EventSchedule.new()
	reentrant_schedule.events.assign([_event(&"reentrant_a", 8, 0, 10, 0), _event(&"reentrant_b", 10, 0, 12, 0)])
	_reentrant_scheduler.schedule = reentrant_schedule
	_reentrant_scheduler.event_started.connect(_on_reentrant_started)
	_reentrant_scheduler.event_ended.connect(_on_reentrant_ended)
	_reentrant_scheduler.update_time(8, 0)
	_check(_reentrant_log == ["started:reentrant_a", "ended:reentrant_a", "started:reentrant_b"], "reentrant update is deferred safely after signal batch")
	_check(_reentrant_scheduler.get_active_event_ids() == [&"reentrant_b"], "reentrant destination state is coherent")
	_reentrant_scheduler.free()
	scheduler.free()
	jump_scheduler.free()

	print("CORE: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _oracle_is_active(start: int, end: int, now: int) -> bool:
	if start == end:
		return false
	if start < end:
		return now >= start and now < end
	return now >= start or now < end


func _oracle_next_index(windows: Array[Dictionary], now: int) -> int:
	var best_index: int = -1
	var best_delta: int = 1441
	for index: int in range(windows.size()):
		var start: int = int(windows[index]["start"])
		var end: int = int(windows[index]["end"])
		if start == end:
			continue
		var delta: int = start - now
		if delta < 0:
			delta += 1440
		if delta == 0:
			delta = 1440
		if delta < best_delta:
			best_delta = delta
			best_index = index
	return best_index


func _oracle_minutes_until(start: int, now: int) -> int:
	var delta: int = start - now
	if delta < 0:
		delta += 1440
	return 1440 if delta == 0 else delta


func _demo_schedule() -> EventSchedule:
	var schedule: EventSchedule = EventSchedule.new()
	schedule.events.assign([
		_event(&"shop_open", 8, 0, 18, 0),
		_event(&"street_lights", 18, 0, 6, 0),
		_event(&"tavern_music", 20, 0, 23, 0),
		_event(&"ghost_spawn", 22, 0, 5, 0),
	])
	return schedule


func _event(event_id: StringName, start_hour: int, start_minute: int, end_hour: int, end_minute: int) -> ScheduledEvent:
	var event: ScheduledEvent = ScheduledEvent.new()
	event.event_id = event_id
	event.start_hour = start_hour
	event.start_minute = start_minute
	event.end_hour = end_hour
	event.end_minute = end_minute
	return event


func _on_event_started(event_id: StringName) -> void:
	_started.append(event_id)
	_signal_log.append("started:" + String(event_id))


func _on_event_ended(event_id: StringName) -> void:
	_ended.append(event_id)
	_signal_log.append("ended:" + String(event_id))


func _on_reentrant_started(event_id: StringName) -> void:
	_reentrant_log.append("started:" + String(event_id))
	if event_id == &"reentrant_a" and not _reentrant_requested:
		_reentrant_requested = true
		_reentrant_scheduler.update_time(10, 0)


func _on_reentrant_ended(event_id: StringName) -> void:
	_reentrant_log.append("ended:" + String(event_id))


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
