extends Control
## A tiny external-controls example: the component does not own a clock, inventory or calendar.

const PROFILE: RelationshipProfile = preload("res://demo/alice_profile.tres")

var relationship: RelationshipComponent
var birthday_checkbox: CheckButton
var coffee_button: Button
var cake_button: Button
var trash_button: Button
var unknown_button: Button
var points_label: Label
var level_label: Label
var bounds_label: Label
var normalized_label: Label
var last_gift_label: Label
var signal_label: Label

var _last_item: StringName = &""
var _last_reaction: int = GiftPreference.Reaction.NEUTRAL
var _last_delta: int = 0


func _ready() -> void:
	relationship = RelationshipComponent.new()
	relationship.profile = PROFILE
	relationship.relationship_changed.connect(_on_relationship_changed)
	relationship.gift_given.connect(_on_gift_given)
	add_child(relationship)
	# This value is deliberately assigned after the profile, and is not reset by _ready.
	relationship.set_points(320)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 36)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)
	_label(layout, "NPC RELATIONSHIP & GIFTING", 15).modulate = Color("74dfc5")
	_label(layout, "Give every gift a clear relationship consequence.", 32)
	_label(layout, "A small Resource profile and Node component for points, reactions and levels.", 17).modulate = Color("a6b4ca")

	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 36)
	status_row.custom_minimum_size.y = 132
	layout.add_child(status_row)
	var status_column := VBoxContainer.new()
	status_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(status_column)
	_label(status_column, "ALICE  /  NPC ID: alice", 13).modulate = Color("a6b4ca")
	points_label = _label(status_column, "", 42)
	level_label = _label(status_column, "", 22)
	bounds_label = _label(status_column, "", 14)
	bounds_label.modulate = Color("a6b4ca")
	normalized_label = _label(status_column, "", 14)
	normalized_label.modulate = Color("74dfc5")

	var control_column := VBoxContainer.new()
	control_column.custom_minimum_size.x = 350
	status_row.add_child(control_column)
	birthday_checkbox = CheckButton.new()
	birthday_checkbox.text = "Birthday multiplier  ×2"
	birthday_checkbox.tooltip_text = "Passes multiplier 2.0 to give_gift; no calendar is included."
	birthday_checkbox.add_theme_font_size_override("font_size", 18)
	control_column.add_child(birthday_checkbox)
	_label(control_column, "The caller supplies the multiplier.", 14).modulate = Color("a6b4ca")
	var reset_button := Button.new()
	reset_button.text = "Reset Alice to 320"
	reset_button.custom_minimum_size = Vector2(0, 42)
	reset_button.pressed.connect(_reset_points)
	control_column.add_child(reset_button)

	_label(layout, "GIFT ACTIONS", 13).modulate = Color("a6b4ca")
	var gift_row := HBoxContainer.new()
	gift_row.add_theme_constant_override("separation", 12)
	gift_row.custom_minimum_size.y = 76
	layout.add_child(gift_row)
	coffee_button = _gift_button(gift_row, "Coffee\nLOVE  +50", &"coffee")
	cake_button = _gift_button(gift_row, "Cake\nLIKE  +20", &"cake")
	trash_button = _gift_button(gift_row, "Trash\nHATE  −40", &"trash")
	unknown_button = _gift_button(gift_row, "Unknown\nNEUTRAL  +0", &"unknown")

	var separator := HSeparator.new()
	layout.add_child(separator)
	last_gift_label = _label(layout, "Last gift: none", 23)
	signal_label = _label(layout, "", 14)
	signal_label.modulate = Color("a6b4ca")
	_label(layout, "Try 320 → 400 to cross from Acquaintance to Friend. Birthday doubles only the chosen gift.", 15).modulate = Color("a6b4ca")
	_label(layout, "RESOURCE PROFILES  /  NODE COMPONENT  /  NO INVENTORY OR CALENDAR", 12).modulate = Color("74dfc5")
	_refresh_state()


func _gift_button(parent: Node, text: String, item_id: StringName) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 72)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(_give_gift.bind(item_id))
	parent.add_child(button)
	return button


func _give_gift(item_id: StringName) -> void:
	var multiplier: float = 2.0 if birthday_checkbox.button_pressed else 1.0
	relationship.give_gift(item_id, multiplier)


func _reset_points() -> void:
	relationship.set_points(320)
	_last_item = &""
	_last_delta = 0
	last_gift_label.text = "Last gift: none (Alice reset to 320)"
	signal_label.text = "Caller-owned point state; no automatic progression."
	_refresh_state()


func _on_relationship_changed(old_value: int, new_value: int) -> void:
	if signal_label != null:
		signal_label.text = "relationship_changed  %d → %d" % [old_value, new_value]
	_refresh_state()


func _on_gift_given(item_id: StringName, reaction: int, relationship_change: int) -> void:
	_last_item = item_id
	_last_reaction = reaction
	_last_delta = relationship_change
	last_gift_label.text = "Last gift: %s  ·  %s  ·  applied %+d" % [String(item_id).capitalize(), _reaction_name(reaction), relationship_change]
	_refresh_state()


func _refresh_state() -> void:
	if relationship == null or points_label == null:
		return
	var active_profile: RelationshipProfile = relationship.profile
	var level: RelationshipLevel = relationship.get_relationship_level()
	var level_text: String = level.display_name if level != null else "No level"
	points_label.text = "%d / %d points" % [relationship.get_points(), active_profile.maximum_points]
	level_label.text = "Current level: " + level_text
	bounds_label.text = "Bounds: %d to %d" % [active_profile.minimum_points, active_profile.maximum_points]
	normalized_label.text = "Normalized relationship: %.2f" % relationship.get_normalized_relationship()


func _reaction_name(reaction: int) -> String:
	match reaction:
		GiftPreference.Reaction.LOVE:
			return "LOVE"
		GiftPreference.Reaction.LIKE:
			return "LIKE"
		GiftPreference.Reaction.DISLIKE:
			return "DISLIKE"
		GiftPreference.Reaction.HATE:
			return "HATE"
		_:
			return "NEUTRAL"


func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label
