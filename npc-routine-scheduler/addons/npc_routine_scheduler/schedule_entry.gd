@tool
class_name ScheduleEntry
extends Resource
## One daily routine, starting at a clock time and lasting until the next entry.

@export_range(0, 23) var hour: int = 8
@export_range(0, 59) var minute: int = 0
@export var location_id: StringName = &""
@export var activity: StringName = &""


func get_total_minutes() -> int:
	return hour * 60 + minute
