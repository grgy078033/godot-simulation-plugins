extends SceneTree
## Native integration runner; append -- --capture for actual promotional PNG frames.

const DEMO_SCRIPT = preload("res://demo/demo.gd")

var _checks: int = 0
var _failures: int = 0
var _capture_enabled: bool = false


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1100, 700)
	_capture_enabled = "--capture" in OS.get_cmdline_user_args()
	var scene: PackedScene = load("res://demo/demo.tscn")
	var demo: DEMO_SCRIPT = scene.instantiate()
	root.add_child(demo)
	for frame: int in range(8):
		await process_frame
	_check(demo.manager != null, "demo owns a queue manager")
	_check(demo.manager.get_available_tables().size() == 2, "demo registers both editable tables")
	_check(demo.table_two.capacity == 2 and demo.table_four.capacity == 4, "demo table capacities")
	_check(demo.alice.party_size == 2 and demo.bob.party_size == 4 and demo.carol.party_size == 1, "demo customer party sizes")
	_check(demo.alice.get_state() == RestaurantCustomer.CustomerState.ARRIVING, "demo starts customers ARRIVING")
	_check(demo.queue_label.text == "Queue: —", "demo starts with empty FIFO queue")
	_check(not demo.add_alice_button.disabled and not demo.add_bob_button.disabled and not demo.add_carol_button.disabled, "arrival buttons start enabled")
	_check(demo.customer_status_label.get_global_rect().end.y <= root.size.y, "customer status fits viewport")
	_check(demo.event_log_label.get_global_rect().end.y <= root.size.y, "event log fits viewport")
	if _capture_enabled:
		await _capture_frame(demo, 0)

	await _click(demo.add_alice_button)
	_check(demo.alice.get_state() == RestaurantCustomer.CustomerState.SEATED, "Alice arrival seats immediately")
	_check(demo.alice.assigned_table == demo.table_two and demo.table_two.assigned_customer == demo.alice, "Alice gets smallest suitable table")
	_check(demo.queue_label.text == "Queue: —", "Alice does not remain queued")
	_check(demo.add_alice_button.disabled, "Alice button disables after add")
	if _capture_enabled:
		await _capture_frame(demo, 1)

	await _click(demo.add_bob_button)
	_check(demo.bob.get_state() == RestaurantCustomer.CustomerState.SEATED, "Bob arrival seats at four-seat table")
	_check(demo.bob.assigned_table == demo.table_four and demo.table_four.assigned_customer == demo.bob, "Bob gets four-seat table")
	if _capture_enabled:
		await _capture_frame(demo, 2)

	await _click(demo.add_carol_button)
	_check(demo.carol.get_state() == RestaurantCustomer.CustomerState.WAITING_FOR_TABLE, "Carol waits when tables are occupied")
	_check(demo.carol.assigned_table == null, "waiting Carol has no table")
	_check(demo.manager.get_waiting_customers().size() == 1 and demo.manager.get_waiting_customers()[0] == demo.carol, "Carol is FIFO queue head")
	_check(demo.queue_label.text.contains("Carol (1)"), "queue label shows Carol party")
	if _capture_enabled:
		await _capture_frame(demo, 3)

	# Five caller-owned steps demonstrate SEATED -> ORDERING -> WAITING_FOR_FOOD -> EATING -> PAYING -> LEAVING.
	await _click(demo.step_button)
	_check(demo.alice.get_state() == RestaurantCustomer.CustomerState.ORDERING and demo.bob.get_state() == RestaurantCustomer.CustomerState.ORDERING, "step enters ORDERING")
	if _capture_enabled:
		await _capture_frame(demo, 4)
	await _click(demo.step_button)
	_check(demo.alice.get_state() == RestaurantCustomer.CustomerState.WAITING_FOR_FOOD, "step enters WAITING_FOR_FOOD")
	if _capture_enabled:
		await _capture_frame(demo, 5)
	await _click(demo.step_button)
	_check(demo.alice.get_state() == RestaurantCustomer.CustomerState.EATING, "step enters EATING")
	if _capture_enabled:
		await _capture_frame(demo, 6)
	await _click(demo.step_button)
	_check(demo.alice.get_state() == RestaurantCustomer.CustomerState.PAYING, "step enters PAYING")
	if _capture_enabled:
		await _capture_frame(demo, 7)
	await _click(demo.step_button)
	_check(demo.alice.get_state() == RestaurantCustomer.CustomerState.LEAVING, "step enters LEAVING")
	_check(demo.bob.get_state() == RestaurantCustomer.CustomerState.LEAVING, "step advances Bob in parallel")
	if _capture_enabled:
		await _capture_frame(demo, 8)

	await _click(demo.complete_two_button)
	_check(demo.alice.get_state() == RestaurantCustomer.CustomerState.COMPLETED, "Table 2 completion sets Alice COMPLETED")
	_check(demo.alice.assigned_table == null, "Alice completion clears assigned table")
	_check(demo.carol.assigned_table == demo.table_two and demo.table_two.assigned_customer == demo.carol, "Table 2 completion immediately seats Carol")
	_check(demo.carol.get_state() == RestaurantCustomer.CustomerState.SEATED, "Carol transitions to SEATED after completion")
	if _capture_enabled:
		await _capture_frame(demo, 9)

	await _click(demo.complete_four_button)
	_check(demo.bob.get_state() == RestaurantCustomer.CustomerState.COMPLETED, "Table 4 completion sets Bob COMPLETED")
	_check(demo.table_four.assigned_customer == null, "Table 4 is released")
	if _capture_enabled:
		await _capture_frame(demo, 10)

	await _click(demo.complete_two_button)
	_check(demo.carol.get_state() == RestaurantCustomer.CustomerState.COMPLETED, "Table 2 completion sets Carol COMPLETED")
	_check(demo.manager.get_waiting_customers().is_empty(), "demo queue ends empty")
	_check(demo.table_two.assigned_customer == null and demo.table_four.assigned_customer == null, "all demo tables end available")
	for button: Button in [demo.add_alice_button, demo.add_bob_button, demo.add_carol_button, demo.step_button, demo.complete_two_button, demo.complete_four_button]:
		_check(button.get_global_rect().end.x <= root.size.x, "demo control fits viewport horizontally")
		_check(button.get_global_rect().end.y <= root.size.y, "demo control fits viewport vertically")
	_check(demo.event_log_label.text.contains("COMPLETED"), "demo exposes completion in signal log")
	print("DEMO: %d checks, %d failures" % [_checks, _failures])
	demo.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _click(button: Button) -> void:
	var position: Vector2 = button.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = position
	press.pressed = true
	root.push_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = position
	release.pressed = false
	root.push_input(release)
	await process_frame
	await process_frame


func _capture_frame(demo: DEMO_SCRIPT, index: int) -> void:
	if DisplayServer.get_name() == "headless":
		_check(false, "native capture requires a rendered display")
		return
	DirAccess.make_dir_recursive_absolute("res://assets/screenshots")
	DirAccess.make_dir_recursive_absolute("res://assets/promo/frames")
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_check(image.get_size() == Vector2i(1100, 700), "native frame has 1100x700 size")
	var frame_path: String = "res://assets/promo/frames/%02d.png" % index
	_check(image.save_png(frame_path) == OK, "native frame %d saves" % index)
	if index == 0:
		_check(image.save_png("res://assets/screenshots/demo-overview.png") == OK, "overview screenshot saves")
	if index == 8:
		_check(image.save_png("res://assets/screenshots/lifecycle-leaving.png") == OK, "lifecycle screenshot saves")


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
