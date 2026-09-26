class_name NPCScheduler
extends Node
## Call update_time from your own clock. No autoload or EditorPlugin required.

signal schedule_changed(entry: ScheduleEntry)

@export var schedule: NPCSchedule

var current_entry: ScheduleEntry = null
var _hour: int = 0
var _minute: int = 0
var _has_time: bool = false


func update_time(hour: int, minute: int) -> void:
	_hour = hour
	_minute = minute
	_has_time = true
	var resolved: ScheduleEntry = schedule.get_entry_at(hour, minute) if schedule != null else null
	if resolved != current_entry:
		current_entry = resolved
		schedule_changed.emit(current_entry)


func get_current_entry() -> ScheduleEntry:
	return current_entry


func get_next_entry() -> ScheduleEntry:
	if schedule == null or not _has_time:
		return null
	return schedule.get_next_entry(_hour, _minute)
