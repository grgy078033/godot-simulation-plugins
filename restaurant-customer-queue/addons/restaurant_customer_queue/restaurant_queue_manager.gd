class_name RestaurantQueueManager
extends Node
## Owns one runtime registration of customers and tables.
## Caller-owned lifecycle transitions remain available through RestaurantCustomer.set_state().

var _customers: Array[RestaurantCustomer] = []
var _tables: Array[RestaurantTable] = []
var _queue: CustomerQueue = CustomerQueue.new()
var _in_mutation: bool = false


func add_customer(customer: RestaurantCustomer) -> bool:
	if _in_mutation or not _is_valid_customer(customer):
		return false
	if _has_registered_customer(customer) or customer.assigned_table != null:
		return false
	if customer._is_terminal() or customer.get_state() == RestaurantCustomer.CustomerState.COMPLETED:
		return false
	if not customer._claim_manager(self):
		return false
	if not _queue.enqueue(customer):
		customer._release_manager(self)
		return false
	_in_mutation = true
	_customers.append(customer)
	# Registration is an arrival handoff: the manager owns QUEUING onward.
	customer.set_state(RestaurantCustomer.CustomerState.QUEUING)
	_try_assign_tables_internal()
	_in_mutation = false
	return true


func add_table(table: RestaurantTable) -> bool:
	if _in_mutation or not _is_valid_table(table):
		return false
	if _has_registered_table(table) or table.occupied:
		return false
	if not table._claim_manager(self):
		return false
	_in_mutation = true
	_tables.append(table)
	_try_assign_tables_internal()
	_in_mutation = false
	return true


func try_assign_tables() -> void:
	if _in_mutation:
		return
	_in_mutation = true
	_try_assign_tables_internal()
	_in_mutation = false


func complete_customer(customer: RestaurantCustomer) -> bool:
	if _in_mutation or customer == null or not _has_registered_customer_instance(customer):
		return false
	if customer._is_terminal() or customer.get_state() == RestaurantCustomer.CustomerState.COMPLETED:
		return false
	var table: RestaurantTable = customer.assigned_table
	if table != null:
		# A manager may release only its own table/customer ownership pair.
		if not _has_registered_table_instance(table) or table.assigned_customer != customer:
			return false
	_in_mutation = true
	if table != null:
		var released: RestaurantCustomer = table.release()
		if released != customer or customer.assigned_table != null:
			_in_mutation = false
			return false
	_queue.remove_customer(customer)
	customer._mark_completed()
	customer.set_state(RestaurantCustomer.CustomerState.COMPLETED)
	_remove_registered_customer(customer)
	# The destination state is settled before the next lifecycle signal can observe it.
	_try_assign_tables_internal()
	_in_mutation = false
	return true


func get_waiting_customers() -> Array[RestaurantCustomer]:
	return _queue._snapshot()


func get_available_tables() -> Array[RestaurantTable]:
	var available: Array[RestaurantTable] = []
	for table: RestaurantTable in _tables:
		if table != null and table.capacity > 0 and not table.occupied:
			available.append(table)
	return available


func _try_assign_tables_internal() -> void:
	while _queue.get_queue_size() > 0:
		var customer: RestaurantCustomer = _queue.get_next_customer()
		if customer == null:
			break
		if customer.get_state() == RestaurantCustomer.CustomerState.COMPLETED or customer._is_terminal():
			_queue.dequeue()
			_remove_registered_customer(customer)
			continue
		if customer.assigned_table != null:
			break
		var table: RestaurantTable = _find_smallest_suitable_table(customer)
		if table == null:
			break
		if not table.assign_customer(customer):
			break
		var seated: RestaurantCustomer = _queue.dequeue()
		if seated != customer:
			# This should be unreachable, but never leave one half of an assignment.
			table.release()
			break
		# assign_customer established both links before this signal is emitted.
		customer.set_state(RestaurantCustomer.CustomerState.SEATED)
	for waiting: RestaurantCustomer in _queue._snapshot():
		if waiting.get_state() == RestaurantCustomer.CustomerState.QUEUING:
			waiting.set_state(RestaurantCustomer.CustomerState.WAITING_FOR_TABLE)


func _remove_registered_customer(customer: RestaurantCustomer) -> void:
	var index: int = _customers.find(customer)
	if index >= 0:
		_customers.remove_at(index)
	customer._release_manager(self)


func _find_smallest_suitable_table(customer: RestaurantCustomer) -> RestaurantTable:
	var best: RestaurantTable = null
	for table: RestaurantTable in _tables:
		if table == null or table.capacity <= 0 or table.occupied:
			continue
		if not table.can_seat(customer.party_size):
			continue
		if best == null or table.capacity < best.capacity:
			best = table
	return best


func _is_valid_customer(customer: RestaurantCustomer) -> bool:
	return customer != null and customer.party_size > 0


func _is_valid_table(table: RestaurantTable) -> bool:
	return table != null and table.capacity > 0


func _has_registered_customer(customer: RestaurantCustomer) -> bool:
	if _has_registered_customer_instance(customer):
		return true
	if customer == null or customer.customer_id == &"":
		return false
	for existing: RestaurantCustomer in _customers:
		if existing.customer_id == customer.customer_id:
			return true
	return false


func _has_registered_customer_instance(customer: RestaurantCustomer) -> bool:
	for existing: RestaurantCustomer in _customers:
		if existing == customer:
			return true
	return false


func _has_registered_table(table: RestaurantTable) -> bool:
	if _has_registered_table_instance(table):
		return true
	if table == null or table.table_id == &"":
		return false
	for existing: RestaurantTable in _tables:
		if existing.table_id == table.table_id:
			return true
	return false


func _has_registered_table_instance(table: RestaurantTable) -> bool:
	for existing: RestaurantTable in _tables:
		if existing == table:
			return true
	return false
