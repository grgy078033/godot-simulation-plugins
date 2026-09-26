extends PanelContainer
## Demo presentation only; the addon has no UI dependency.

@export var npc_name: String = "NPC"
@export var routine: NPCSchedule
@export var accent: Color = Color("74dfc5")

@onready var scheduler: NPCScheduler = $NPCScheduler
var location_label: Label
var activity_label: Label
var next_label: Label
var countdown_label: Label


func _ready() -> void:
	scheduler.schedule = routine
	scheduler.schedule_changed.connect(_on_schedule_changed)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("142033")
	panel.border_color = accent
	panel.border_width_top = 3
	panel.set_corner_radius_all(12)
	panel.content_margin_left = 24
	panel.content_margin_right = 24
	panel.content_margin_top = 24
	panel.content_margin_bottom = 24
	add_theme_stylebox_override("panel", panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	var title: Label = _label(box, npc_name, 28)
	title.modulate = accent
	_label(box, "CURRENT ROUTINE", 13).modulate = Color("a6b4ca")
	location_label = _label(box, "Location: --", 21)
	activity_label = _label(box, "Activity: --", 18)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	_label(box, "UP NEXT", 13).modulate = Color("a6b4ca")
	next_label = _label(box, "--", 18)
	countdown_label = _label(box, "--", 15)
	countdown_label.modulate = Color("a6b4ca")


func update_time(hour: int, minute: int) -> void:
	scheduler.update_time(hour, minute)
	var upcoming: ScheduleEntry = scheduler.get_next_entry()
	if upcoming == null:
		next_label.text = "No upcoming routine"
		countdown_label.text = "--"
		return
	next_label.text = "%s at %02d:%02d" % [upcoming.location_id, upcoming.hour, upcoming.minute]
	var remaining: int = routine.minutes_until_next_entry(hour, minute)
	countdown_label.text = "%s / in %d min" % [upcoming.activity, remaining]


func _on_schedule_changed(entry: ScheduleEntry) -> void:
	location_label.text = "Location: %s" % entry.location_id if entry != null else "Location: --"
	activity_label.text = "Activity: %s" % entry.activity if entry != null else "Activity: --"


func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label
