@tool
class_name FreshnessProfile
extends Resource
## Inspector-friendly day durations shared by freshness instances.

@export_range(0, 36500, 1, "or_greater") var fresh_duration: int = 3
@export_range(0, 36500, 1, "or_greater") var stale_duration: int = 2
