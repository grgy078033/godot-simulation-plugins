@tool
class_name EventSchedule
extends Resource
## A repeating daily collection of half-open event windows.
## Invalid entries and duplicate IDs are ignored after the first valid entry.

const DAY_MINUTES: int = 1440

@export var events: Array[ScheduledEvent] = []


## Returns whether the first valid event with event_id is active at the query time.
func is_event_active(event_id: StringName, hour: int, minute: int) -> bool:
	if String(event_id).is_empty():
		return false
	var event: ScheduledEvent = _find_first_valid_event(event_id)
	if event == null:
		return false
	return _is_active(event, _normalize_clock(hour, minute))


## Returns a new array of active event Resources in inspector order.
func get_active_events(hour: int, minute: int) -> Array[ScheduledEvent]:
	var active: Array[ScheduledEvent] = []
	var seen: Dictionary = {}
	var now: int = _normalize_clock(hour, minute)
	for event: ScheduledEvent in events:
		if not _is_valid_event(event) or seen.has(event.event_id):
			continue
		seen[event.event_id] = true
		if _is_active(event, now):
			active.append(event)
	return active


## Returns the event whose valid start is next strictly after the query time.
## The same-minute start is treated as the next day's start (1440 minutes away).
func get_next_event(hour: int, minute: int) -> ScheduledEvent:
	var now: int = _normalize_clock(hour, minute)
	var next_event: ScheduledEvent = null
	var next_delta: int = DAY_MINUTES + 1
	for event: ScheduledEvent in _get_valid_events():
		var start: int = _event_start(event)
		if start == _event_end(event):
			continue
		var delta: int = posmod(start - now, DAY_MINUTES)
		if delta == 0:
			delta = DAY_MINUTES
		if delta < next_delta:
			next_delta = delta
			next_event = event
	return next_event


## Returns minutes until the named event's next valid start, even while it is active.
## Exact start returns 1440; unknown, empty or invalid IDs return -1.
func minutes_until_event(event_id: StringName, hour: int, minute: int) -> int:
	if String(event_id).is_empty():
		return -1
	var event: ScheduledEvent = _find_first_valid_event(event_id)
	if event == null or _event_start(event) == _event_end(event):
		return -1
	var now: int = _normalize_clock(hour, minute)
	var difference: int = posmod(_event_start(event) - now, DAY_MINUTES)
	return DAY_MINUTES if difference == 0 else difference


func _get_valid_events() -> Array[ScheduledEvent]:
	var valid: Array[ScheduledEvent] = []
	var seen: Dictionary = {}
	for event: ScheduledEvent in events:
		if not _is_valid_event(event) or seen.has(event.event_id):
			continue
		seen[event.event_id] = true
		valid.append(event)
	return valid


func _find_first_valid_event(event_id: StringName) -> ScheduledEvent:
	for event: ScheduledEvent in events:
		if _is_valid_event(event) and event.event_id == event_id:
			return event
	return null


func _is_valid_event(event: ScheduledEvent) -> bool:
	if event == null or String(event.event_id).is_empty():
		return false
	return _is_valid_clock(event.start_hour, event.start_minute) and _is_valid_clock(event.end_hour, event.end_minute)


func _is_valid_clock(hour: int, minute: int) -> bool:
	return hour >= 0 and hour < 24 and minute >= 0 and minute < 60


func _normalize_clock(hour: int, minute: int) -> int:
	return posmod(hour * 60 + minute, DAY_MINUTES)


func _event_start(event: ScheduledEvent) -> int:
	return event.start_hour * 60 + event.start_minute


func _event_end(event: ScheduledEvent) -> int:
	return event.end_hour * 60 + event.end_minute


func _is_active(event: ScheduledEvent, now: int) -> bool:
	var start: int = _event_start(event)
	var end: int = _event_end(event)
	if start == end:
		return false
	if start < end:
		return now >= start and now < end
	return now >= start or now < end
