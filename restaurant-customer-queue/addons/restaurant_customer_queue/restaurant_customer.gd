@tool
class_name RestaurantCustomer
extends Resource
## Inspector-friendly customer data with explicit, caller-owned lifecycle state.
## Runtime table ownership is intentionally not exported so Resources never serialize cycles.

signal state_changed(old_state: int, new_state: int)

enum CustomerState {
	ARRIVING,
	QUEUING,
	WAITING_FOR_TABLE,
	SEATED,
	ORDERING,
	WAITING_FOR_FOOD,
	EATING,
	PAYING,
	LEAVING,
	COMPLETED,
}

@export var customer_id: StringName = &""
@export_range(0, 64, 1, "or_greater") var party_size: int = 1
@export_enum("ARRIVING", "QUEUING", "WAITING_FOR_TABLE", "SEATED", "ORDERING", "WAITING_FOR_FOOD", "EATING", "PAYING", "LEAVING", "COMPLETED") var state: int = CustomerState.ARRIVING:
	get:
		return _state
	set(value):
		set_state(value)
@export var waiting_time: float = 0.0

## Runtime-only strong link. RestaurantTable keeps the reverse link weakly.
var assigned_table: RestaurantTable = null
var _state: int = CustomerState.ARRIVING
var _manager_ref: WeakRef = null
var _terminal: bool = false


func set_state(new_state: int) -> void:
	if new_state < CustomerState.ARRIVING or new_state > CustomerState.COMPLETED:
		return
	if _state == new_state:
		return
	var old_state: int = _state
	_state = new_state
	state_changed.emit(old_state, _state)


func get_state() -> int:
	return _state


func _assign_table(table: RestaurantTable) -> bool:
	if table == null or assigned_table != null:
		return false
	assigned_table = table
	return true


func _clear_assigned_table(table: RestaurantTable) -> bool:
	if assigned_table != table:
		return false
	assigned_table = null
	return true


func _mark_completed() -> void:
	_terminal = true


func _is_terminal() -> bool:
	return _terminal


func _claim_manager(manager: RestaurantQueueManager) -> bool:
	if manager == null:
		return false
	var current_manager: RestaurantQueueManager = _get_manager()
	if current_manager != null and current_manager != manager:
		return false
	_manager_ref = weakref(manager)
	return true


func _release_manager(manager: RestaurantQueueManager) -> void:
	if _get_manager() == manager:
		_manager_ref = null


func _get_manager() -> RestaurantQueueManager:
	if _manager_ref == null:
		return null
	var object: Object = _manager_ref.get_ref()
	return object as RestaurantQueueManager
