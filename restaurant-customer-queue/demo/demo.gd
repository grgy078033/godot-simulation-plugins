extends Control
## External-controls example: the manager owns FIFO/table assignment; the caller owns lifecycle steps.

const ALICE: RestaurantCustomer = preload("res://demo/alice.tres")
const BOB: RestaurantCustomer = preload("res://demo/bob.tres")
const CAROL: RestaurantCustomer = preload("res://demo/carol.tres")
const TABLE_TWO: RestaurantTable = preload("res://demo/table_two.tres")
const TABLE_FOUR: RestaurantTable = preload("res://demo/table_four.tres")

var manager: RestaurantQueueManager
var alice: RestaurantCustomer
var bob: RestaurantCustomer
var carol: RestaurantCustomer
var table_two: RestaurantTable
var table_four: RestaurantTable

var add_alice_button: Button
var add_bob_button: Button
var add_carol_button: Button
var step_button: Button
var complete_two_button: Button
var complete_four_button: Button
var queue_label: Label
var table_two_label: Label
var table_four_label: Label
var customer_status_label: Label
var event_log_label: Label
var hint_label: Label

var _added: Array[RestaurantCustomer] = []
var _event_log: Array[String] = []


func _ready() -> void:
	# Duplicate editable .tres values so this demo run owns its runtime state.
	alice = ALICE.duplicate(true) as RestaurantCustomer
	bob = BOB.duplicate(true) as RestaurantCustomer
	carol = CAROL.duplicate(true) as RestaurantCustomer
	table_two = TABLE_TWO.duplicate(true) as RestaurantTable
	table_four = TABLE_FOUR.duplicate(true) as RestaurantTable
	manager = RestaurantQueueManager.new()
	add_child(manager)
	for customer: RestaurantCustomer in [alice, bob, carol]:
		customer.state_changed.connect(_on_customer_state_changed.bind(customer))
	# Register in reverse capacity order to make smallest-suitable selection visible.
	manager.add_table(table_four)
	manager.add_table(table_two)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 6)
	margin.add_child(layout)
	_label(layout, "RESTAURANT CUSTOMER QUEUE", 15).modulate = Color("74dfc5")
	_label(layout, "Strict FIFO seating for small restaurant simulations.", 28)
	_label(layout, "Two editable table Resources · one Node manager · caller-owned customer lifecycle", 15).modulate = Color("a6b4ca")

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 22)
	top_row.custom_minimum_size.y = 100
	layout.add_child(top_row)
	var queue_column := VBoxContainer.new()
	queue_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(queue_column)
	_label(queue_column, "FIFO WAITING QUEUE", 12).modulate = Color("a6b4ca")
	queue_label = _label(queue_column, "Queue: —", 22)
	var queue_note := _label(queue_column, "Head-of-line blocking: no party is skipped.", 13)
	queue_note.modulate = Color("a6b4ca")
	var table_column := VBoxContainer.new()
	table_column.custom_minimum_size.x = 520
	top_row.add_child(table_column)
	_label(table_column, "REGISTERED TABLES", 12).modulate = Color("a6b4ca")
	table_two_label = _label(table_column, "", 18)
	table_four_label = _label(table_column, "", 18)

	_label(layout, "ARRIVALS", 12).modulate = Color("a6b4ca")
	var arrival_row := HBoxContainer.new()
	arrival_row.add_theme_constant_override("separation", 10)
	arrival_row.custom_minimum_size.y = 48
	layout.add_child(arrival_row)
	add_alice_button = _action_button(arrival_row, "Add Alice  ·  party 2", _add_alice)
	add_bob_button = _action_button(arrival_row, "Add Bob  ·  party 4", _add_bob)
	add_carol_button = _action_button(arrival_row, "Add Carol  ·  party 1", _add_carol)

	_label(layout, "CUSTOMER STATES", 12).modulate = Color("a6b4ca")
	customer_status_label = _label(layout, "", 16)
	customer_status_label.custom_minimum_size.y = 54

	var controls_row := HBoxContainer.new()
	controls_row.add_theme_constant_override("separation", 10)
	controls_row.custom_minimum_size.y = 48
	layout.add_child(controls_row)
	step_button = _action_button(controls_row, "Step seated lifecycle", _step_lifecycle)
	complete_two_button = _action_button(controls_row, "Complete Table 2", _complete_table_two)
	complete_four_button = _action_button(controls_row, "Complete Table 4", _complete_table_four)

	var separator := HSeparator.new()
	layout.add_child(separator)
	hint_label = _label(layout, "", 14)
	hint_label.modulate = Color("74dfc5")
	event_log_label = _label(layout, "State signal log: —", 13)
	event_log_label.modulate = Color("a6b4ca")
	event_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_log_label.custom_minimum_size.y = 100
	_label(layout, "RESOURCE CONFIGURATION  /  NODE MANAGER  /  NO MENU, MONEY OR MOVEMENT", 12).modulate = Color("74dfc5")
	_refresh_state()


func _action_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 16)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button


func _add_alice() -> void:
	_add_customer(alice, add_alice_button)


func _add_bob() -> void:
	_add_customer(bob, add_bob_button)


func _add_carol() -> void:
	_add_customer(carol, add_carol_button)


func _add_customer(customer: RestaurantCustomer, button: Button) -> void:
	if manager.add_customer(customer):
		_added.append(customer)
		button.disabled = true
		_hint("Arrival accepted. The manager assigns the first suitable table in FIFO order.")
		_refresh_state()


func _step_lifecycle() -> void:
	var changed: bool = false
	for customer: RestaurantCustomer in _added:
		if customer.get_state() == RestaurantCustomer.CustomerState.SEATED:
			customer.set_state(RestaurantCustomer.CustomerState.ORDERING)
			changed = true
		elif customer.get_state() == RestaurantCustomer.CustomerState.ORDERING:
			customer.set_state(RestaurantCustomer.CustomerState.WAITING_FOR_FOOD)
			changed = true
		elif customer.get_state() == RestaurantCustomer.CustomerState.WAITING_FOR_FOOD:
			customer.set_state(RestaurantCustomer.CustomerState.EATING)
			changed = true
		elif customer.get_state() == RestaurantCustomer.CustomerState.EATING:
			customer.set_state(RestaurantCustomer.CustomerState.PAYING)
			changed = true
		elif customer.get_state() == RestaurantCustomer.CustomerState.PAYING:
			customer.set_state(RestaurantCustomer.CustomerState.LEAVING)
			changed = true
	if changed:
		_hint("Lifecycle is caller-owned. Complete the table after LEAVING to seat the next party.")
	else:
		_hint("Add a customer or complete a seated table; waiting parties remain FIFO.")
	_refresh_state()


func _complete_table_two() -> void:
	_complete_table(table_two)


func _complete_table_four() -> void:
	_complete_table(table_four)


func _complete_table(table: RestaurantTable) -> void:
	var customer: RestaurantCustomer = table.assigned_customer
	if customer == null:
		_hint("That table is already available.")
		return
	if manager.complete_customer(customer):
		_hint("%s completed; the manager immediately attempted the next queued party." % _display_name(customer))
	_refresh_state()


func _on_customer_state_changed(old_state: int, new_state: int, customer: RestaurantCustomer) -> void:
	_event_log.push_front("%s: %s → %s" % [_display_name(customer), _state_name(old_state), _state_name(new_state)])
	if _event_log.size() > 7:
		_event_log.pop_back()
	_refresh_state()


func _refresh_state() -> void:
	if manager == null or queue_label == null:
		return
	var waiting: Array[RestaurantCustomer] = manager.get_waiting_customers()
	var queue_parts: Array[String] = []
	for customer: RestaurantCustomer in waiting:
		queue_parts.append("%s (%d)" % [_display_name(customer), customer.party_size])
	queue_label.text = "Queue: " + ("  →  ".join(queue_parts) if not queue_parts.is_empty() else "—")
	table_two_label.text = _table_text(table_two)
	table_four_label.text = _table_text(table_four)
	var status_parts: Array[String] = []
	for customer: RestaurantCustomer in [alice, bob, carol]:
		var table_text: String = "table %s" % String(customer.assigned_table.table_id) if customer.assigned_table != null else "no table"
		status_parts.append("%s ×%d  ·  %s  ·  %s" % [_display_name(customer), customer.party_size, _state_name(customer.get_state()), table_text])
	customer_status_label.text = "\n".join(status_parts)
	complete_two_button.disabled = table_two.assigned_customer == null
	complete_four_button.disabled = table_four.assigned_customer == null
	complete_two_button.text = "Complete %s @ Table 2" % _display_name(table_two.assigned_customer) if table_two.assigned_customer != null else "Complete Table 2"
	complete_four_button.text = "Complete %s @ Table 4" % _display_name(table_four.assigned_customer) if table_four.assigned_customer != null else "Complete Table 4"
	event_log_label.text = "State signal log:\n" + ("\n".join(_event_log) if not _event_log.is_empty() else "—")


func _table_text(table: RestaurantTable) -> String:
	if table.assigned_customer == null:
		return "Table %d  ·  capacity %d  ·  AVAILABLE" % [table.capacity, table.capacity]
	return "Table %d  ·  capacity %d  ·  %s ×%d  ·  OCCUPIED" % [table.capacity, table.capacity, _display_name(table.assigned_customer), table.assigned_customer.party_size]


func _display_name(customer: RestaurantCustomer) -> String:
	if customer == null:
		return "—"
	return String(customer.customer_id).capitalize()


func _state_name(state: int) -> String:
	match state:
		RestaurantCustomer.CustomerState.ARRIVING:
			return "ARRIVING"
		RestaurantCustomer.CustomerState.QUEUING:
			return "QUEUING"
		RestaurantCustomer.CustomerState.WAITING_FOR_TABLE:
			return "WAITING_FOR_TABLE"
		RestaurantCustomer.CustomerState.SEATED:
			return "SEATED"
		RestaurantCustomer.CustomerState.ORDERING:
			return "ORDERING"
		RestaurantCustomer.CustomerState.WAITING_FOR_FOOD:
			return "WAITING_FOR_FOOD"
		RestaurantCustomer.CustomerState.EATING:
			return "EATING"
		RestaurantCustomer.CustomerState.PAYING:
			return "PAYING"
		RestaurantCustomer.CustomerState.LEAVING:
			return "LEAVING"
		RestaurantCustomer.CustomerState.COMPLETED:
			return "COMPLETED"
		_:
			return "UNKNOWN"


func _hint(text: String) -> void:
	if hint_label != null:
		hint_label.text = text


func _label(parent: Node, text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label
