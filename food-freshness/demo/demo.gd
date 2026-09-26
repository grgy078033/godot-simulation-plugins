extends Control
## External-day example: freshness instances report state; the caller owns the day.

const PROFILE: FreshnessProfile = preload("res://demo/freshness_profile.tres")
const ITEM_NAMES: Dictionary = {
	&"milk": "Milk",
	&"fish": "Fish",
	&"bread": "Bread",
}
const ITEM_CREATED_DAYS: Dictionary = {
	&"milk": 8,
	&"fish": 5,
	&"bread": 10,
}

var current_day: int = 10
var previous_day_button: Button
var next_day_button: Button
var day_label: Label
var last_change_label: Label
var instances: Dictionary = {}
var item_state_labels: Dictionary = {}
var item_age_labels: Dictionary = {}
var item_stale_labels: Dictionary = {}
var item_expired_labels: Dictionary = {}
var item_last_labels: Dictionary = {}


func _ready() -> void:
	_build_ui()
	_create_instances()
	_refresh_all()


func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 34)
	add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 11)
	margin.add_child(layout)

	_label(layout, "FOOD FRESHNESS & EXPIRATION", 15).modulate = Color("74dfc5")
	_label(layout, "Know what is fresh before you serve it.", 31)
	_label(layout, "A small Resource profile and per-item RefCounted instance for explicit day-based state.", 16).modulate = Color("a6b4ca")

	var day_row := HBoxContainer.new()
	day_row.add_theme_constant_override("separation", 18)
	day_row.custom_minimum_size.y = 72
	layout.add_child(day_row)
	var day_panel := _panel(day_row, Vector2(390, 0))
	var day_content := _panel_content(day_panel)
	var day_controls := HBoxContainer.new()
	day_controls.add_theme_constant_override("separation", 12)
	day_content.add_child(day_controls)
	previous_day_button = _day_button(day_controls, "− 1 day", -1)
	day_label = _label(day_controls, "", 27)
	day_label.custom_minimum_size.x = 145
	day_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	next_day_button = _day_button(day_controls, "+ 1 day", 1)
	var day_hint := _label(day_row, "The caller advances the day. Lookups do not emit signals; update_day() does.", 14)
	day_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	day_hint.modulate = Color("a6b4ca")

	_label(layout, "EDITABLE FOOD INSTANCES", 13).modulate = Color("a6b4ca")
	var items_row := HBoxContainer.new()
	items_row.add_theme_constant_override("separation", 14)
	items_row.custom_minimum_size.y = 254
	layout.add_child(items_row)
	for item_id: StringName in [&"milk", &"fish", &"bread"]:
		_make_item_card(items_row, item_id)

	var separator := HSeparator.new()
	layout.add_child(separator)
	last_change_label = _label(layout, "", 20)
	last_change_label.custom_minimum_size.y = 32
	_label(layout, "Milk starts at day 8 (fresh on day 10); Fish was created on day 5; Bread is created today.", 14).modulate = Color("a6b4ca")
	_label(layout, "RESOURCE PROFILE  /  PER-ITEM REFCOUNTED STATE  /  NO INVENTORY OR CLOCK", 12).modulate = Color("74dfc5")


func _create_instances() -> void:
	for item_id: StringName in [&"milk", &"fish", &"bread"]:
		var instance := FreshnessInstance.new()
		instance.setup(PROFILE, int(ITEM_CREATED_DAYS[item_id]))
		instance.freshness_changed.connect(_on_freshness_changed.bind(item_id))
		instances[item_id] = instance


func _make_item_card(parent: Node, item_id: StringName) -> void:
	var card := _panel(parent, Vector2(0, 0))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := _panel_content(card)
	var title := _label(content, String(ITEM_NAMES[item_id]).to_upper(), 22)
	title.modulate = Color("f0c987")
	var created_label := _label(content, "Created day: %d" % int(ITEM_CREATED_DAYS[item_id]), 15)
	created_label.modulate = Color("a6b4ca")
	var age_label := _label(content, "", 17)
	var state_label := _label(content, "", 25)
	var stale_label := _label(content, "", 15)
	var expired_label := _label(content, "", 15)
	var last_label := _label(content, "Last change: setup (silent)", 13)
	last_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	last_label.modulate = Color("a6b4ca")
	item_age_labels[item_id] = age_label
	item_state_labels[item_id] = state_label
	item_stale_labels[item_id] = stale_label
	item_expired_labels[item_id] = expired_label
	item_last_labels[item_id] = last_label


func _day_button(parent: Node, text: String, delta: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(112, 42)
	button.add_theme_font_size_override("font_size", 15)
	button.pressed.connect(_shift_day.bind(delta))
	parent.add_child(button)
	return button


func _shift_day(delta: int) -> void:
	current_day += delta
	for item_id: StringName in instances:
		var instance: FreshnessInstance = instances[item_id]
		instance.update_day(current_day)
	_refresh_all()


func _reset_demo_state() -> void:
	current_day = 10
	for item_id: StringName in instances:
		var instance: FreshnessInstance = instances[item_id]
		instance.setup(PROFILE, int(ITEM_CREATED_DAYS[item_id]))
		var item_last_label: Label = item_last_labels[item_id] as Label
		item_last_label.text = "Last change: setup (silent)"
	last_change_label.text = "Last change: setup is silent; move the day to observe transitions."
	_refresh_all()


func _on_freshness_changed(old_state: int, new_state: int, item_id: StringName) -> void:
	var change_text: String = "Last change: %s → %s" % [_state_name(old_state), _state_name(new_state)]
	var item_last_label: Label = item_last_labels[item_id] as Label
	item_last_label.text = change_text
	if last_change_label != null:
		last_change_label.text = "%s: %s" % [String(ITEM_NAMES[item_id]), change_text]
	_refresh_item(item_id)


func _refresh_all() -> void:
	if day_label == null:
		return
	day_label.text = "DAY %d" % current_day
	for item_id: StringName in instances:
		_refresh_item(item_id)
	if last_change_label.text.is_empty():
		last_change_label.text = "Last change: setup is silent; move the day to observe transitions."


func _refresh_item(item_id: StringName) -> void:
	var instance: FreshnessInstance = instances[item_id] as FreshnessInstance
	var state: int = instance.get_state(current_day)
	var age_label: Label = item_age_labels[item_id] as Label
	var state_label: Label = item_state_labels[item_id] as Label
	var stale_label: Label = item_stale_labels[item_id] as Label
	var expired_label: Label = item_expired_labels[item_id] as Label
	age_label.text = "Age: %d day%s" % [instance.get_age(current_day), "" if instance.get_age(current_day) == 1 else "s"]
	state_label.text = _state_name(state)
	state_label.modulate = _state_color(state)
	stale_label.text = "Until stale: %d day%s" % [instance.days_until_stale(current_day), "" if instance.days_until_stale(current_day) == 1 else "s"]
	expired_label.text = "Until expired: %d day%s" % [instance.days_until_expired(current_day), "" if instance.days_until_expired(current_day) == 1 else "s"]


func _state_name(state: int) -> String:
	match state:
		FreshnessInstance.FreshnessState.FRESH:
			return "FRESH"
		FreshnessInstance.FreshnessState.STALE:
			return "STALE"
		_:
			return "EXPIRED"


func _state_color(state: int) -> Color:
	match state:
		FreshnessInstance.FreshnessState.FRESH:
			return Color("74dfc5")
		FreshnessInstance.FreshnessState.STALE:
			return Color("f0c987")
		_:
			return Color("ee8f8f")


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
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)
	return column


func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label
