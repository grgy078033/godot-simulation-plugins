class_name WorldEventScheduler
extends Node
## Applies an EventSchedule only when the caller forwards a clock update.
## It reconciles the destination active-ID set and never replays skipped times.

const DAY_MINUTES: int = 1440

signal event_started(event_id: StringName)
signal event_ended(event_id: StringName)

@export var schedule: EventSchedule:
	get:
		return _schedule
	set(value):
		_schedule = value

var _schedule: EventSchedule = null
var _active_event_ids: Array[StringName] = []
var _emitting_signals: bool = false
var _has_pending_update: bool = false
var _pending_minute: int = 0


## Reconciles active IDs at a caller-supplied clock time normalized to one day.
## The first update emits event_started for every active destination event.
## During a callback, the latest update is deferred until the current signal batch ends.
func update_time(hour: int, minute: int) -> void:
	var normalized: int = _normalize_clock(hour, minute)
	if _emitting_signals:
		_pending_minute = normalized
		_has_pending_update = true
		return
	_apply_update(normalized)
	_drain_pending_updates()


## Returns a fresh array of event IDs active after the latest update.
func get_active_event_ids() -> Array[StringName]:
	var copy: Array[StringName] = []
	for event_id: StringName in _active_event_ids:
		copy.append(event_id)
	return copy


func _apply_update(normalized: int) -> void:
	var previous: Array[StringName] = _active_event_ids
	var destination: Array[StringName] = _collect_active_event_ids(normalized)
	var previous_set: Dictionary = {}
	var destination_set: Dictionary = {}
	for event_id: StringName in previous:
		previous_set[event_id] = true
	for event_id: StringName in destination:
		destination_set[event_id] = true

	var ended: Array[StringName] = []
	for event_id: StringName in previous:
		if not destination_set.has(event_id):
			ended.append(event_id)
	var started: Array[StringName] = []
	for event_id: StringName in destination:
		if not previous_set.has(event_id):
			started.append(event_id)

	# Publish the full destination before callbacks can re-enter the scheduler.
	_active_event_ids = destination
	if ended.is_empty() and started.is_empty():
		return

	_emitting_signals = true
	for event_id: StringName in ended:
		event_ended.emit(event_id)
	for event_id: StringName in started:
		event_started.emit(event_id)
	_emitting_signals = false


func _collect_active_event_ids(normalized: int) -> Array[StringName]:
	var active_ids: Array[StringName] = []
	if _schedule == null:
		return active_ids
	var active_events: Array[ScheduledEvent] = _schedule.get_active_events(normalized / 60, normalized % 60)
	for event: ScheduledEvent in active_events:
		active_ids.append(event.event_id)
	return active_ids


func _drain_pending_updates() -> void:
	while _has_pending_update and not _emitting_signals:
		var pending: int = _pending_minute
		_has_pending_update = false
		_apply_update(pending)


func _normalize_clock(hour: int, minute: int) -> int:
	return posmod(hour * 60 + minute, DAY_MINUTES)
