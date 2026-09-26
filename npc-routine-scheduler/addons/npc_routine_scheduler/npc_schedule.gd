@tool
class_name NPCSchedule
extends Resource
## A repeating 24-hour schedule. Queries never reorder or copy entry resources.
## Null/invalid entries are ignored; the first entry wins duplicate start times.

@export var entries: Array[ScheduleEntry] = []


func get_entry_at(hour: int, minute: int) -> ScheduleEntry:
	var now: int = posmod(hour * 60 + minute, 1440)
	var previous: ScheduleEntry = null
	var last: ScheduleEntry = null
	for entry: ScheduleEntry in entries:
		if not _is_valid_entry(entry):
			continue
		var start: int = entry.get_total_minutes()
		if last == null or start > last.get_total_minutes():
			last = entry
		if start <= now and (previous == null or start > previous.get_total_minutes()):
			previous = entry
	return previous if previous != null else last


func get_next_entry(hour: int, minute: int) -> ScheduleEntry:
	var now: int = posmod(hour * 60 + minute, 1440)
	var upcoming: ScheduleEntry = null
	var first: ScheduleEntry = null
	for entry: ScheduleEntry in entries:
		if not _is_valid_entry(entry):
			continue
		var start: int = entry.get_total_minutes()
		if first == null or start < first.get_total_minutes():
			first = entry
		if start > now and (upcoming == null or start < upcoming.get_total_minutes()):
			upcoming = entry
	return upcoming if upcoming != null else first


func minutes_until_next_entry(hour: int, minute: int) -> int:
	var upcoming: ScheduleEntry = get_next_entry(hour, minute)
	if upcoming == null:
		return -1
	var now: int = posmod(hour * 60 + minute, 1440)
	var difference: int = posmod(upcoming.get_total_minutes() - now, 1440)
	return 1440 if difference == 0 else difference


func _is_valid_entry(entry: ScheduleEntry) -> bool:
	return entry != null and entry.hour >= 0 and entry.hour < 24 \
		and entry.minute >= 0 and entry.minute < 60
