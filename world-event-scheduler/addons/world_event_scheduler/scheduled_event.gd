@tool
class_name ScheduledEvent
extends Resource
## Inspector-friendly start/end window for one repeating world event.
## The interval is [start, end); equal start/end is intentionally inactive.

@export var event_id: StringName = &""
@export_range(0, 23, 1) var start_hour: int = 0
@export_range(0, 59, 1) var start_minute: int = 0
@export_range(0, 23, 1) var end_hour: int = 0
@export_range(0, 59, 1) var end_minute: int = 0
