class_name CustomerQueue
extends RefCounted
## Strict FIFO storage. It never prioritizes by party size or waiting time.

var _customers: Array[RestaurantCustomer] = []


func enqueue(customer: RestaurantCustomer) -> bool:
	if customer == null or customer.party_size <= 0:
		return false
	if _contains_identity(customer):
		return false
	_customers.append(customer)
	return true


func dequeue() -> RestaurantCustomer:
	if _customers.is_empty():
		return null
	return _customers.pop_front()


func remove_customer(customer: RestaurantCustomer) -> bool:
	if customer == null:
		return false
	var index: int = _customers.find(customer)
	if index < 0:
		return false
	_customers.remove_at(index)
	return true


func get_next_customer() -> RestaurantCustomer:
	if _customers.is_empty():
		return null
	return _customers[0]


func get_queue_size() -> int:
	return _customers.size()


func _snapshot() -> Array[RestaurantCustomer]:
	return _customers.duplicate()


func _contains_identity(customer: RestaurantCustomer) -> bool:
	for existing: RestaurantCustomer in _customers:
		if existing == customer:
			return true
		if existing.customer_id != &"" and customer.customer_id != &"" and existing.customer_id == customer.customer_id:
			return true
	return false
