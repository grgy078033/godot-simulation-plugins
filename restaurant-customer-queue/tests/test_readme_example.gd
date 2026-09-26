extends SceneTree
## Executes the README's included-Resource manager example.

const ALICE_CONFIG: RestaurantCustomer = preload("res://demo/alice.tres")
const TABLE_TWO_CONFIG: RestaurantTable = preload("res://demo/table_two.tres")

var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	var manager := RestaurantQueueManager.new()
	root.add_child(manager)
	var alice: RestaurantCustomer = ALICE_CONFIG.duplicate(true) as RestaurantCustomer
	var table_two: RestaurantTable = TABLE_TWO_CONFIG.duplicate(true) as RestaurantTable
	alice.state_changed.connect(_on_alice_state_changed.bind(alice))
	_check(manager.add_table(table_two), "README table registration")
	_check(manager.add_customer(alice), "README customer registration")
	var waiting: Array[RestaurantCustomer] = manager.get_waiting_customers()
	var available: Array[RestaurantTable] = manager.get_available_tables()
	_check(waiting.size() == 0, "README waiting query")
	_check(available.size() == 0, "README available query")
	manager.try_assign_tables()
	_check(alice.assigned_table == table_two, "README duplicate Resource assignment")
	_check(alice.get_state() == RestaurantCustomer.CustomerState.SEATED, "README example reaches SEATED")
	manager.free()
	print("README: %d checks, %d failures" % [_checks, _failures])
	quit(0 if _failures == 0 else 1)


func _on_alice_state_changed(old_state: int, new_state: int, alice: RestaurantCustomer) -> void:
	_check(old_state >= RestaurantCustomer.CustomerState.ARRIVING, "README callback old state")
	_check(new_state >= RestaurantCustomer.CustomerState.ARRIVING, "README callback new state")
	if new_state == RestaurantCustomer.CustomerState.SEATED:
		_check(alice.assigned_table != null, "README callback sees assigned table")


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
