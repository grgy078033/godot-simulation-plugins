extends SceneTree
## Focused core contract runner:
## godot --headless --path . --script tests/test_core.gd

var _checks: int = 0
var _failures: int = 0
var _state_pairs: Array[Vector2i] = []
var _state_customers: Array[StringName] = []
var _reentrant_manager: RestaurantQueueManager = null
var _reentrant_checks: int = 0


func _initialize() -> void:
	_test_customer_and_table_contracts()
	_test_fifo_queue()
	_test_manager_assignment_and_completion()
	_test_manager_edge_cases()
	_test_manager_ownership_and_release()
	_test_resource_serialization()
	print("CORE: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _test_customer_and_table_contracts() -> void:
	var customer := _customer(&"table_guest", 2)
	customer.state_changed.connect(_on_state_changed.bind(customer))
	_check(customer.get_state() == RestaurantCustomer.CustomerState.ARRIVING, "customer starts ARRIVING")
	customer.set_state(RestaurantCustomer.CustomerState.QUEUING)
	customer.set_state(RestaurantCustomer.CustomerState.QUEUING)
	customer.set_state(-1)
	customer.set_state(999)
	_check(_state_pairs == [Vector2i(RestaurantCustomer.CustomerState.ARRIVING, RestaurantCustomer.CustomerState.QUEUING)], "same and invalid states suppress state signal")
	_check(customer.assigned_table == null, "customer starts without a table")

	var table := _table(&"two", 2)
	_check(table.can_seat(1), "two-seat table accepts one")
	_check(table.can_seat(2), "two-seat table accepts two")
	_check(not table.can_seat(3), "two-seat table rejects three")
	_check(not table.can_seat(0), "table rejects zero party")
	_check(not table.can_seat(-1), "table rejects negative party")
	_check(table.assign_customer(customer), "table assigns matching customer")
	_check(table.occupied, "assigned table is occupied")
	_check(table.assigned_customer == customer, "table reverse link points to customer")
	_check(customer.assigned_table == table, "customer forward link points to table")
	_check(not table.assign_customer(customer), "double table assignment is rejected")
	var other := _customer(&"other", 1)
	_check(not table.assign_customer(other), "occupied table rejects another customer")
	_check(not table.can_seat(1), "occupied table cannot seat")
	var released: RestaurantCustomer = table.release()
	_check(released == customer, "release returns assigned customer")
	_check(not table.occupied and table.assigned_customer == null, "release clears table reverse link")
	_check(customer.assigned_table == null, "release clears customer forward link")
	_check(table.release() == null, "empty release is safe")

	var invalid_table := _table(&"invalid", 0)
	_check(not invalid_table.can_seat(1), "zero-capacity table rejects seating")
	_check(not invalid_table.assign_customer(other), "zero-capacity assignment rejects")


func _test_fifo_queue() -> void:
	var queue := CustomerQueue.new()
	var alice := _customer(&"a", 2)
	var bob := _customer(&"b", 4)
	var carol := _customer(&"c", 1)
	_check(queue.dequeue() == null, "empty dequeue returns null")
	_check(queue.enqueue(alice), "enqueue A")
	_check(queue.enqueue(bob), "enqueue B")
	_check(queue.enqueue(carol), "enqueue C")
	_check(queue.get_queue_size() == 3, "queue size ABC")
	_check(queue.get_next_customer() == alice, "peek returns A")
	_check(queue.dequeue() == alice, "dequeue returns A")
	_check(queue.dequeue() == bob, "dequeue returns B")
	_check(queue.dequeue() == carol, "dequeue returns C")
	_check(queue.dequeue() == null and queue.get_queue_size() == 0, "queue drains to empty")
	_check(not queue.enqueue(null), "null enqueue rejects")
	var invalid := _customer(&"invalid", 0)
	_check(not queue.enqueue(invalid), "invalid party enqueue rejects")
	_check(queue.enqueue(alice), "re-enqueue after dequeue")
	_check(not queue.enqueue(alice), "duplicate instance enqueue rejects")
	var duplicate_id := _customer(&"a", 9)
	_check(not queue.enqueue(duplicate_id), "duplicate nonempty ID enqueue rejects")
	_check(queue.remove_customer(alice), "remove queued customer")
	_check(not queue.remove_customer(alice), "remove missing customer rejects")


func _test_manager_assignment_and_completion() -> void:
	var manager := RestaurantQueueManager.new()
	var table_four := _table(&"four", 4)
	var table_two := _table(&"two", 2)
	_check(manager.add_table(table_four), "register four-seat table first")
	_check(manager.add_table(table_two), "register two-seat table second")
	var alice := _customer(&"alice", 2)
	var bob := _customer(&"bob", 4)
	var carol := _customer(&"carol", 1)
	var alice_states: Array[Vector2i] = []
	alice.state_changed.connect(_record_pairs.bind(alice_states))
	_check(manager.add_customer(alice), "add Alice")
	_check(alice.assigned_table == table_two and table_two.assigned_customer == alice, "party two chooses smallest table before four")
	_check(alice.get_state() == RestaurantCustomer.CustomerState.SEATED, "Alice routes to SEATED")
	_check(alice_states == [Vector2i(RestaurantCustomer.CustomerState.ARRIVING, RestaurantCustomer.CustomerState.QUEUING), Vector2i(RestaurantCustomer.CustomerState.QUEUING, RestaurantCustomer.CustomerState.SEATED)], "Alice signal sequence")
	_check(manager.add_customer(bob), "add Bob")
	_check(bob.assigned_table == table_four and table_four.assigned_customer == bob, "party four chooses four-seat table")
	_check(manager.add_customer(carol), "add Carol")
	_check(carol.assigned_table == null and carol.get_state() == RestaurantCustomer.CustomerState.WAITING_FOR_TABLE, "no table routes to waiting")
	_check(manager.get_waiting_customers().size() == 1 and manager.get_waiting_customers()[0] == carol, "waiting queue contains Carol")
	_check(manager.get_available_tables().is_empty(), "both tables occupied")

	# Caller, not the manager, advances service lifecycle.
	var lifecycle_before: int = alice.get_state()
	alice.set_state(RestaurantCustomer.CustomerState.ORDERING)
	_check(alice.get_state() == RestaurantCustomer.CustomerState.ORDERING and lifecycle_before == RestaurantCustomer.CustomerState.SEATED, "caller controls service lifecycle")
	alice.set_state(RestaurantCustomer.CustomerState.WAITING_FOR_FOOD)
	alice.set_state(RestaurantCustomer.CustomerState.EATING)
	alice.set_state(RestaurantCustomer.CustomerState.PAYING)
	alice.set_state(RestaurantCustomer.CustomerState.LEAVING)
	_check(manager.complete_customer(alice), "complete Alice")
	_check(alice.get_state() == RestaurantCustomer.CustomerState.COMPLETED, "completion sets COMPLETED")
	_check(alice.assigned_table == null and table_two.assigned_customer == carol and table_two.occupied, "completion releases Alice before seating next party")
	_check(carol.assigned_table == table_two and table_two.assigned_customer == carol, "completion immediately seats next FIFO party")
	_check(carol.get_state() == RestaurantCustomer.CustomerState.SEATED, "next party routes to SEATED")
	_check(not manager.complete_customer(alice), "double completion is rejected")
	_check(not manager.add_customer(alice), "completed customer cannot be resurrected")
	_check(manager.get_waiting_customers().is_empty(), "queue empty after immediate seating")

	_check(manager.complete_customer(carol), "complete Carol")
	_check(manager.complete_customer(bob), "complete Bob")
	_check(manager.get_available_tables().size() == 2, "completed tables become available")
	manager.free()


func _test_manager_edge_cases() -> void:
	var manager := RestaurantQueueManager.new()
	var two := _table(&"two", 2)
	_check(manager.add_table(two), "edge manager adds two-seat table")
	_check(not manager.add_table(two), "duplicate table instance rejects")
	var duplicate_table_id := _table(&"two", 4)
	_check(not manager.add_table(duplicate_table_id), "duplicate nonempty table ID rejects")
	var invalid_table := _table(&"bad", 0)
	_check(not manager.add_table(invalid_table), "invalid table registration rejects")
	_check(not manager.add_table(null), "null table registration rejects")

	var head_large := _customer(&"large", 4)
	var tail_small := _customer(&"small", 1)
	_check(manager.add_customer(head_large), "large head registers")
	_check(manager.add_customer(tail_small), "small tail registers")
	_check(head_large.assigned_table == null and tail_small.assigned_table == null, "no suitable table leaves both queued")
	_check(manager.get_waiting_customers()[0] == head_large, "large party remains queue head")
	manager.try_assign_tables()
	_check(tail_small.assigned_table == null, "strict head-of-line blocking does not skip small tail")
	var four := _table(&"four", 4)
	_check(manager.add_table(four), "adding suitable table seats blocked head")
	_check(head_large.assigned_table == four and tail_small.assigned_table == two, "after head seats, tail uses freed suitable table only when available")
	_check(manager.complete_customer(head_large), "complete large head")
	_check(manager.complete_customer(tail_small), "complete small tail")

	var invalid_customer := _customer(&"zero", 0)
	_check(not manager.add_customer(invalid_customer), "zero party customer rejected")
	var negative_customer := _customer(&"negative", -2)
	_check(not manager.add_customer(negative_customer), "negative party customer rejected")
	_check(not manager.add_customer(null), "null customer registration rejects")
	var id_one := _customer(&"same", 1)
	var id_two := _customer(&"same", 2)
	_check(manager.add_customer(id_one), "first duplicate-ID customer registers")
	_check(not manager.add_customer(id_two), "duplicate customer ID rejects")
	_check(not manager.add_customer(id_one), "duplicate customer instance rejects")
	_check(manager.complete_customer(id_one), "complete registered duplicate-ID test customer")

	# Reentrant calls from a state callback are rejected while links are already consistent.
	var reentrant := RestaurantQueueManager.new()
	var re_table := _table(&"re", 2)
	_reentrant_manager = reentrant
	var re_customer := _customer(&"reentrant", 2)
	re_customer.state_changed.connect(_on_reentrant_state.bind(re_customer))
	_check(reentrant.add_table(re_table), "reentrant table registers")
	_check(reentrant.add_customer(re_customer), "reentrant customer registers")
	_check(_reentrant_checks >= 2, "reentrant state callback observed transitions")
	_check(re_customer.assigned_table == re_table and re_table.assigned_customer == re_customer, "reentrant callback sees consistent links")
	_reentrant_manager = null

	# A different manager cannot take ownership of an already assigned customer/table.
	var other_manager := RestaurantQueueManager.new()
	_check(not other_manager.add_table(re_table), "second manager cannot register occupied table")
	_check(not other_manager.add_customer(re_customer), "second manager cannot register assigned customer")
	_check(not other_manager.complete_customer(re_customer), "wrong manager cannot release customer")
	_check(reentrant.complete_customer(re_customer), "owning manager releases customer")
	_check(not manager.complete_customer(re_customer), "unrelated manager cannot complete customer")
	other_manager.free()
	reentrant.free()
	manager.free()


func _test_manager_ownership_and_release() -> void:
	var owner := RestaurantQueueManager.new()
	var rival := RestaurantQueueManager.new()
	var shared_customer := _customer(&"shared_queued", 4)
	_check(owner.add_customer(shared_customer), "owner registers shared queued customer")
	_check(shared_customer.get_state() == RestaurantCustomer.CustomerState.WAITING_FOR_TABLE, "shared customer waits without a table")
	_check(not rival.add_customer(shared_customer), "second manager rejects same queued customer")
	var shared_empty_table := _table(&"shared_empty", 2)
	_check(owner.add_table(shared_empty_table), "owner registers unsuitable empty table")
	_check(not shared_empty_table.occupied, "unsuitable registered table remains empty")
	_check(not rival.add_table(shared_empty_table), "second manager rejects same empty table")
	_check(not rival.complete_customer(shared_customer), "foreign manager cannot complete queued customer")
	_check(owner.complete_customer(shared_customer), "owner can complete queued customer")
	_check(shared_customer.get_state() == RestaurantCustomer.CustomerState.COMPLETED, "queued completion becomes terminal")
	_check(not rival.add_customer(shared_customer), "completed customer cannot resurrect after ownership release")
	owner.free()
	_check(rival.add_table(shared_empty_table), "freed manager ownership allows empty table reuse")
	rival.free()

	var first_owner := RestaurantQueueManager.new()
	var freed_customer := _customer(&"freed_customer", 1)
	_check(first_owner.add_customer(freed_customer), "first owner registers waiting customer")
	first_owner.free()
	var second_owner := RestaurantQueueManager.new()
	var freed_table := _table(&"freed_table", 1)
	_check(second_owner.add_customer(freed_customer), "new manager claims customer after old manager is freed")
	_check(second_owner.add_table(freed_table), "new manager seats customer after old manager is freed")
	_check(freed_customer.assigned_table == freed_table, "freed-manager customer has new owner assignment")
	_check(second_owner.complete_customer(freed_customer), "new manager completes reassigned customer")
	second_owner.free()

	var completed_weak: WeakRef = _complete_and_drop_customer()
	_check(completed_weak.get_ref() == null, "completed customer is released from manager references")


func _complete_and_drop_customer() -> WeakRef:
	var manager := RestaurantQueueManager.new()
	var table := _table(&"weak_table", 1)
	var customer: RestaurantCustomer = _customer(&"weak_customer", 1)
	manager.add_table(table)
	manager.add_customer(customer)
	manager.complete_customer(customer)
	var weak_customer: WeakRef = weakref(customer)
	customer = null
	table = null
	manager.free()
	return weak_customer


func _test_resource_serialization() -> void:
	var customer := _customer(&"saved_guest", 3)
	var table := _table(&"saved_table", 4)
	var customer_path: String = "user://restaurant_customer_queue_customer.tres"
	var table_path: String = "user://restaurant_customer_queue_table.tres"
	_check(ResourceSaver.save(customer, customer_path) == OK, "customer resource saves")
	_check(ResourceSaver.save(table, table_path) == OK, "table resource saves")
	var loaded_customer: RestaurantCustomer = load(customer_path) as RestaurantCustomer
	var loaded_table: RestaurantTable = load(table_path) as RestaurantTable
	_check(loaded_customer != null and loaded_customer.customer_id == &"saved_guest" and loaded_customer.party_size == 3, "customer resource loads editable fields")
	_check(loaded_table != null and loaded_table.table_id == &"saved_table" and loaded_table.capacity == 4, "table resource loads editable fields")
	if loaded_customer != null and loaded_table != null:
		_check(loaded_customer.assigned_table == null and loaded_table.assigned_customer == null, "runtime ownership links are not serialized")
		_check(loaded_table.assign_customer(loaded_customer), "loaded resources can own runtime assignment")
		_check(loaded_customer.assigned_table == loaded_table and loaded_table.assigned_customer == loaded_customer, "loaded runtime links stay two-way")
		loaded_table.release()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(customer_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(table_path))


func _customer(customer_id: StringName, party_size: int) -> RestaurantCustomer:
	var customer := RestaurantCustomer.new()
	customer.customer_id = customer_id
	customer.party_size = party_size
	return customer


func _table(table_id: StringName, capacity: int) -> RestaurantTable:
	var table := RestaurantTable.new()
	table.table_id = table_id
	table.capacity = capacity
	return table


func _on_state_changed(old_state: int, new_state: int, customer: RestaurantCustomer) -> void:
	_state_pairs.append(Vector2i(old_state, new_state))
	_state_customers.append(customer.customer_id)


func _record_pairs(old_state: int, new_state: int, pairs: Array[Vector2i]) -> void:
	pairs.append(Vector2i(old_state, new_state))


func _on_reentrant_state(old_state: int, _new_state: int, customer: RestaurantCustomer) -> void:
	_reentrant_checks += 1
	if _reentrant_manager != null:
		_reentrant_manager.try_assign_tables()
		_check(not _reentrant_manager.complete_customer(customer), "guard rejects reentrant completion")
	_check(customer.assigned_table == null or customer.assigned_table.assigned_customer == customer, "callback sees forward/reverse assignment invariant")
	_check(old_state >= RestaurantCustomer.CustomerState.ARRIVING and old_state <= RestaurantCustomer.CustomerState.COMPLETED, "callback receives valid old state")


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
