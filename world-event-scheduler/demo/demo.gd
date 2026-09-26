extends Control
## External-clock example: the scheduler reconciles event IDs and owns no world spawners.

const EVENT_SCHEDULE: EventSchedule = preload("res://demo/event_schedule.tres")
const EVENT_NAMES: Dictionary = {
	&"shop_open": "Shop Open",
	&"street_lights": "Street Lights",
	&"tavern_music": "Tavern Music",
	&"ghost_spawn": "Ghost Spawn",
}

var scheduler: WorldEventScheduler
var previous_button: Button
var next_button: Button
var clock_label: Label
var active_label: Label
var next_event_label: Label
var transition_label: Label
var signal_hint_label: Label
var event_status_labels: Dictionary = {}

var _hour: int = 19
var _minute: int = 0
var _transition_log: Array[String] = []


func _ready() -> void:
	_build_ui()
	scheduler = WorldEventScheduler.new()
	scheduler.schedule = EVENT_SCHEDULE
	scheduler.event_started.connect(_on_event_started)
	scheduler.event_ended.connect(_on_event_ended)
	add_child(scheduler)
	scheduler.update_time(_hour, _minute)
	_refresh_state()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 34)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	_label(layout, "WORLD EVENT SCHEDULER", 15).modulate = Color("74dfc5")
	_label(layout, "Let your clock decide when the world changes.", 31)
	_label(layout, "A small Resource schedule and Node reconciler for explicit event windows and signals.", 16).modulate = Color("a6b4ca")

	var main_row := HBoxContainer.new()
	main_row.add_theme_constant_override("separation", 16)
	main_row.custom_minimum_size.y = 278
	layout.add_child(main_row)

	var clock_panel := _panel(main_row, Vector2(365, 0))
	var clock_column := _panel_content(clock_panel)
	_label(clock_column, "CALLER CLOCK", 13).modulate = Color("a6b4ca")
	clock_label = _label(clock_column, "", 46)
	_label(clock_column, "Forward any hour/minute values; queries normalize across midnight.", 13).modulate = Color("a6b4ca")
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	controls.custom_minimum_size.y = 48
	clock_column.add_child(controls)
	previous_button = _clock_button(controls, "− 1 hour", -1)
	next_button = _clock_button(controls, "+ 1 hour", 1)
	next_event_label = _label(clock_column, "", 19)
	next_event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	active_label = _label(clock_column, "", 19)
	active_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	signal_hint_label = _label(clock_column, "", 13)
	signal_hint_label.modulate = Color("a6b4ca")

	var events_panel := _panel(main_row, Vector2(0, 0))
	events_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var events_column := _panel_content(events_panel)
	_label(events_column, "EDITABLE EVENT WINDOWS", 13).modulate = Color("a6b4ca")
	for event: ScheduledEvent in EVENT_SCHEDULE.events:
		if event == null:
			continue
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.custom_minimum_size.y = 40
		events_column.add_child(row)
		var name_label := _label(row, EVENT_NAMES.get(event.event_id, String(event.event_id)), 18)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var window_label := _label(row, "%02d:%02d – %02d:%02d" % [event.start_hour, event.start_minute, event.end_hour, event.end_minute], 16)
		window_label.modulate = Color("a6b4ca")
		var state_label := _label(row, "", 16)
		state_label.custom_minimum_size.x = 96
		state_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		event_status_labels[event.event_id] = state_label
	_label(events_column, "Half-open windows [start, end); overnight windows are supported.", 13).modulate = Color("a6b4ca")

	var separator := HSeparator.new()
	layout.add_child(separator)
	_label(layout, "TRANSITION LOG", 13).modulate = Color("a6b4ca")
	transition_label = _label(layout, "", 21)
	transition_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	transition_label.custom_minimum_size.y = 64
	_label(layout, "The example labels are only state display: no shop, lights, music or spawner is created.", 14).modulate = Color("a6b4ca")
	_label(layout, "RESOURCE SCHEDULE  /  NODE SIGNALS  /  NO AUTOLOAD OR PER-FRAME PROCESSING", 12).modulate = Color("74dfc5")


func _clock_button(parent: Node, text: String, delta_hours: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(145, 46)
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(_shift_hour.bind(delta_hours))
	parent.add_child(button)
	return button


func _shift_hour(delta_hours: int) -> void:
	var total: int = posmod(_hour * 60 + _minute + delta_hours * 60, 1440)
	_hour = int(total / 60.0)
	_minute = total % 60
	scheduler.update_time(_hour, _minute)
	_refresh_state()


func _on_event_started(event_id: StringName) -> void:
	_transition_log.push_front("START  " + _event_name(event_id))
	_trim_transition_log()
	if signal_hint_label != null:
		signal_hint_label.text = "event_started(%s)" % String(event_id)
	_refresh_state()


func _on_event_ended(event_id: StringName) -> void:
	_transition_log.push_front("END    " + _event_name(event_id))
	_trim_transition_log()
	if signal_hint_label != null:
		signal_hint_label.text = "event_ended(%s)" % String(event_id)
	_refresh_state()


func _trim_transition_log() -> void:
	while _transition_log.size() > 3:
		_transition_log.pop_back()


func _refresh_state() -> void:
	if scheduler == null or clock_label == null:
		return
	clock_label.text = "%02d:%02d" % [_hour, _minute]
	var active_events: Array[ScheduledEvent] = EVENT_SCHEDULE.get_active_events(_hour, _minute)
	var active_names: Array[String] = []
	for event: ScheduledEvent in active_events:
		active_names.append(_event_name(event.event_id))
	active_label.text = "Active now: " + (", ".join(active_names) if not active_names.is_empty() else "none")

	var upcoming: ScheduledEvent = EVENT_SCHEDULE.get_next_event(_hour, _minute)
	if upcoming == null:
		next_event_label.text = "Next start: none"
	else:
		var minutes: int = EVENT_SCHEDULE.minutes_until_event(upcoming.event_id, _hour, _minute)
		next_event_label.text = "Next start: %s at %02d:%02d  (%d min)" % [_event_name(upcoming.event_id), upcoming.start_hour, upcoming.start_minute, minutes]

	for event_id: StringName in event_status_labels:
		var state_label: Label = event_status_labels[event_id]
		if scheduler.get_active_event_ids().has(event_id):
			state_label.text = "ACTIVE"
			state_label.modulate = Color("74dfc5")
		else:
			state_label.text = "idle"
			state_label.modulate = Color("70809a")
	transition_label.text = "  ·  ".join(_transition_log) if not _transition_log.is_empty() else "No transitions yet."


func _event_name(event_id: StringName) -> String:
	return String(EVENT_NAMES.get(event_id, String(event_id)))


func _panel(parent: Node, minimum_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum_size
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101b2c")
	style.border_color = Color("26364f")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel


func _panel_content(panel: PanelContainer) -> VBoxContainer:
	var margin := MarginContainer.new()
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 18)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 9)
	margin.add_child(column)
	return column


func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label
