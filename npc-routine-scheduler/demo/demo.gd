extends Control

const NPC_CARD: PackedScene = preload("res://demo/npc_demo.tscn")
const CARD_SCRIPT = preload("res://demo/npc_demo.gd")
const ROUTINES: Array[NPCSchedule] = [
	preload("res://demo/alice.tres"),
	preload("res://demo/bob.tres"),
	preload("res://demo/carol.tres"),
]

var total_minutes: int = 480
var clock_label: Label
var previous_button: Button
var next_button: Button
var cards: Array[CARD_SCRIPT] = []


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	margin.add_child(layout)
	_label(layout, "NPC ROUTINE SCHEDULER", 15).modulate = Color("74dfc5")
	_label(layout, "A daily rhythm for every NPC.", 34)
	_label(layout, "Your clock. Your world. One lightweight scheduler.", 18).modulate = Color("a6b4ca")
	var time_row := HBoxContainer.new()
	time_row.add_theme_constant_override("separation", 24)
	time_row.custom_minimum_size.y = 96
	layout.add_child(time_row)
	var clock_box := VBoxContainer.new()
	clock_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	time_row.add_child(clock_box)
	_label(clock_box, "CURRENT GAME TIME", 13).modulate = Color("a6b4ca")
	clock_label = _label(clock_box, "08:00", 44)
	previous_button = _button(time_row, "-1 Hour", -60)
	next_button = _button(time_row, "+1 Hour", 60)
	var card_row := HBoxContainer.new()
	card_row.add_theme_constant_override("separation", 18)
	card_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(card_row)
	var names: Array[String] = ["Alice", "Bob", "Carol"]
	var accents: Array[Color] = [Color("74dfc5"), Color("f0c987"), Color("b6acfa")]
	for index: int in range(3):
		var card: CARD_SCRIPT = NPC_CARD.instantiate()
		card.npc_name = names[index]
		card.routine = ROUTINES[index]
		card.accent = accents[index]
		card_row.add_child(card)
		cards.append(card)
	_label(layout, "Try crossing midnight. Routines wrap automatically; your clock stays in control.", 16).modulate = Color("a6b4ca")
	_label(layout, "DAILY ROUTINES  /  INSPECTOR RESOURCES  /  NO DEPENDENCIES", 12).modulate = Color("74dfc5")
	_refresh()


func _shift_time(delta_minutes: int) -> void:
	total_minutes = posmod(total_minutes + delta_minutes, 1440)
	_refresh()


func _refresh() -> void:
	var hour: int = int(total_minutes / 60.0)
	var minute: int = total_minutes % 60
	clock_label.text = "%02d:%02d" % [hour, minute]
	for card: CARD_SCRIPT in cards:
		card.update_time(hour, minute)


func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label


func _button(parent: Node, text: String, delta_minutes: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(138, 52)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(_shift_time.bind(delta_minutes))
	parent.add_child(button)
	return button
