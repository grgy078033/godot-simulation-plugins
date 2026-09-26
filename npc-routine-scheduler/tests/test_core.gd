extends SceneTree
## Dependency-free runner: godot --headless --path . --script tests/test_core.gd

var _checks: int = 0
var _failures: int = 0
var _events: Array[ScheduleEntry] = []


func _initialize() -> void:
	var schedule := NPCSchedule.new()
	var breakfast := _entry(7, 0, &"Home")
	var work := _entry(8, 0, &"Work")
	var park := _entry(17, 0, &"Park")
	var sleep := _entry(23, 0, &"Home")
	schedule.entries.assign([breakfast, work, park, sleep])
	_check(schedule.get_entry_at(8, 0) == work, "08:00 exact boundary")
	_check(schedule.get_entry_at(15, 0) == work, "15:00 between entries")
	_check(schedule.get_entry_at(17, 0) == park, "17:00 exact boundary")
	_check(schedule.get_entry_at(23, 59) == sleep, "23:59")
	_check(schedule.get_entry_at(2, 0) == sleep, "02:00 overnight")
	_check(schedule.get_entry_at(6, 59) == sleep, "06:59 overnight")
	_check(schedule.get_entry_at(0, 0) == sleep, "00:00 overnight")
	schedule.entries.assign([park, sleep, breakfast, work])
	var original: Array[ScheduleEntry] = schedule.entries.duplicate()
	_check(schedule.get_entry_at(15, 0) == work, "unsorted current")
	_check(schedule.get_next_entry(15, 0) == park, "unsorted next")
	_check(schedule.get_next_entry(23, 30) == breakfast, "next wraps")
	_check(schedule.minutes_until_next_entry(23, 30) == 450, "450-minute wrap")
	_check(schedule.entries == original, "queries preserve Inspector order")
	schedule.entries.assign([work, park, sleep])
	_check(schedule.get_next_entry(15, 0) == park, "next 17:00")
	_check(schedule.get_next_entry(23, 30) == work, "next 08:00 tomorrow")
	_check(schedule.get_next_entry(17, 0) == sleep, "next strictly after now")
	_check(schedule.minutes_until_next_entry(15, 30) == 90, "90 minutes")
	_check(schedule.minutes_until_next_entry(23, 30) == 510, "510 minutes")
	_check(schedule.get_entry_at(32, 0) == work, "overflow query wraps")
	_check(schedule.get_entry_at(0, -1) == sleep, "negative query wraps")
	var scheduler := NPCScheduler.new()
	scheduler.schedule = schedule
	scheduler.schedule_changed.connect(_on_changed)
	_check(scheduler.get_current_entry() == null, "initial current null")
	_check(scheduler.get_next_entry() == null, "initial next null")
	scheduler.update_time(8, 0)
	scheduler.update_time(9, 0)
	scheduler.update_time(10, 0)
	_check(_events.size() == 1 and _events[0] == work, "signal once per resource")
	_check(scheduler.get_current_entry() == work, "cached current")
	_check(scheduler.get_next_entry() == park, "scheduler next")
	scheduler.update_time(17, 0)
	_check(_events.size() == 2 and _events[1] == park, "transition signal")
	scheduler.update_time(8, 0)
	_check(_events.size() == 3, "rewind signal")
	scheduler.update_time(23, 59)
	scheduler.update_time(0, 0)
	_check(_events.size() == 4, "no duplicate at midnight")
	scheduler.schedule = null
	scheduler.update_time(1, 0)
	scheduler.update_time(2, 0)
	_check(_events.size() == 5 and _events[4] == null, "clearing emits null once")
	_check(scheduler.get_next_entry() == null, "no schedule next")
	scheduler.free()
	schedule.entries.clear()
	_check(schedule.get_entry_at(12, 0) == null, "empty current")
	_check(schedule.get_next_entry(12, 0) == null, "empty next")
	_check(schedule.minutes_until_next_entry(12, 0) == -1, "empty minutes sentinel")
	schedule.entries.assign([work])
	_check(schedule.get_entry_at(0, 0) == work, "single entry current")
	_check(schedule.get_next_entry(8, 0) == work, "single entry next tomorrow")
	_check(schedule.minutes_until_next_entry(8, 0) == 1440, "single exact = full day")
	_check(schedule.minutes_until_next_entry(7, 59) == 1, "single minute before")
	var duplicate := _entry(8, 0, &"Ignored")
	var invalid := _entry(24, 0, &"Invalid")
	schedule.entries.assign([null, work, duplicate, invalid])
	_check(schedule.get_entry_at(8, 0) == work, "first duplicate wins current")
	_check(schedule.get_next_entry(0, 0) == work, "first duplicate wins next")
	schedule.entries.assign([null, invalid])
	_check(schedule.get_entry_at(0, 0) == null, "invalid-only current")
	_check(schedule.get_next_entry(0, 0) == null, "invalid-only next")
	_check(schedule.minutes_until_next_entry(0, 0) == -1, "invalid-only minutes")
	var half_hour := _entry(7, 30, &"Cafe")
	var invalid_minute := _entry(7, 60, &"Invalid")
	schedule.entries.assign([work, invalid_minute, half_hour])
	_check(schedule.get_entry_at(7, 29) == work, "nonzero minute overnight")
	_check(schedule.get_entry_at(7, 30) == half_hour, "nonzero minute boundary")
	_check(schedule.minutes_until_next_entry(7, 29) == 1, "nonzero minute next")
	var same_location := _entry(9, 0, &"Work")
	schedule.entries.assign([work, same_location])
	_events.clear()
	scheduler = NPCScheduler.new()
	scheduler.schedule = schedule
	scheduler.schedule_changed.connect(_on_changed)
	scheduler.update_time(8, 0)
	scheduler.update_time(9, 0)
	_check(_events.size() == 2, "different resources with same fields emit")
	var replacement := NPCSchedule.new()
	replacement.entries.assign([half_hour])
	scheduler.schedule = replacement
	scheduler.update_time(9, 0)
	_check(scheduler.get_current_entry() == half_hour, "schedule replacement refresh")
	replacement.entries.clear()
	scheduler.update_time(9, 0)
	_check(scheduler.get_current_entry() == null, "entry edits refresh")
	_check(_events.size() == 4 and _events[3] == null, "empty edit emits null")
	scheduler.free()
	# Full-day invariant against an independent ordered timeline.
	schedule.entries.assign([park, sleep, breakfast, work])
	for now: int in range(1440):
		var expected: ScheduleEntry = sleep
		var expected_next: ScheduleEntry = breakfast
		if now >= 420 and now < 480:
			expected = breakfast
			expected_next = work
		elif now >= 480 and now < 1020:
			expected = work
			expected_next = park
		elif now >= 1020 and now < 1380:
			expected = park
			expected_next = sleep
		_check(schedule.get_entry_at(0, now) == expected, "full-day current %d" % now)
		_check(schedule.get_next_entry(0, now) == expected_next, "full-day next %d" % now)
		var distance: int = posmod(expected_next.get_total_minutes() - now, 1440)
		_check(schedule.minutes_until_next_entry(0, now) == distance, "full-day distance %d" % now)
	print("CORE: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _entry(hour: int, minute: int, location: StringName) -> ScheduleEntry:
	var entry := ScheduleEntry.new()
	entry.hour = hour
	entry.minute = minute
	entry.location_id = location
	return entry


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)


func _on_changed(entry: ScheduleEntry) -> void:
	_events.append(entry)
