@tool
class_name RestaurantTable
extends Resource
## A table keeps its customer reverse link weakly to avoid a Resource reference cycle.
## assign_customer() and release() update both sides without emitting lifecycle signals.

@export var table_id: StringName = &""
@export_range(0, 64, 1, "or_greater") var capacity: int = 2

## Runtime-only ownership. The weak reverse link is not serialized into .tres files.
var assigned_customer: RestaurantCustomer:
	get:
		if _assigned_customer_ref == null:
			return null
		var object: Object = _assigned_customer_ref.get_ref()
		return object as RestaurantCustomer

var occupied: bool:
	get:
		return assigned_customer != null

var _assigned_customer_ref: WeakRef = null
var _manager_ref: WeakRef = null


func can_seat(party_size: int) -> bool:
	if party_size <= 0 or capacity <= 0 or occupied:
		return false
	return party_size <= capacity


func assign_customer(customer: RestaurantCustomer) -> bool:
	if customer == null or not can_seat(customer.party_size):
		return false
	if customer.assigned_table != null:
		return false
	if not customer._assign_table(self):
		return false
	_assigned_customer_ref = weakref(customer)
	return assigned_customer == customer and customer.assigned_table == self


func release() -> RestaurantCustomer:
	var customer: RestaurantCustomer = assigned_customer
	_assigned_customer_ref = null
	if customer != null:
		customer._clear_assigned_table(self)
	return customer


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
