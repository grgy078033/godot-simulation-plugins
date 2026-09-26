extends SceneTree
## Run normally for headless integration; append -- --capture for native PNGs.

const DEMO_SCRIPT = preload("res://demo/demo.gd")
var _checks: int = 0
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1100, 700)
	var scene: PackedScene = load("res://demo/demo.tscn")
	var demo: DEMO_SCRIPT = scene.instantiate()
	root.add_child(demo)
	# Nested Containers settle their deferred minimum-size/layout notifications.
	for frame: int in range(4):
		await process_frame
	_check(demo.cards.size() == 3, "three NPC cards")
	_check(demo.clock_label.text == "08:00", "initial time")
	_check(demo.cards[0].location_label.text == "Location: Restaurant", "Alice 08:00")
	_check(demo.cards[1].activity_label.text == "Activity: Sleeping", "Bob 08:00")
	_check(demo.cards[2].location_label.text == "Location: Park", "Carol 08:00")
	_check(demo.cards[0].next_label.text == "Park at 17:00", "Alice next")
	_check(demo.cards[0].countdown_label.text == "Walking / in 540 min", "Alice countdown")
	# Dispatch mouse input through the viewport, not directly into the clock.
	var position: Vector2 = demo.next_button.get_global_rect().get_center()
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
	_check(demo.clock_label.text == "09:00", "native mouse input +1 Hour")
	_check(demo.cards[1].location_label.text == "Location: Shop", "Bob boundary updates")
	demo.previous_button.pressed.emit()
	_check(demo.clock_label.text == "08:00", "-1 Hour connection")
	for step: int in range(16):
		demo.next_button.pressed.emit()
	_check(demo.clock_label.text == "00:00", "forward midnight")
	_check(demo.cards[1].activity_label.text == "Activity: Sleeping", "Bob midnight")
	demo.previous_button.pressed.emit()
	_check(demo.clock_label.text == "23:00", "backward midnight")
	_check(demo.cards[0].activity_label.text == "Activity: Sleeping", "Alice 23:00")
	_check(demo.cards[0].countdown_label.text == "Breakfast / in 480 min", "overnight countdown")
	for card: Control in demo.cards:
		_check(card.get_global_rect().end.x <= root.size.x, "card fits viewport horizontally")
		_check(card.get_global_rect().end.y <= root.size.y, "card fits viewport vertically")
	if "--capture" in OS.get_cmdline_user_args():
		if DisplayServer.get_name() == "headless":
			_check(false, "capture requires native rendering")
		else:
			DirAccess.make_dir_recursive_absolute("res://assets/screenshots")
			DirAccess.make_dir_recursive_absolute("res://assets/promo/frames")
			# Rewind to 08:00, then advance with the actual connected UI button.
			for step: int in range(15):
				demo.previous_button.pressed.emit()
			for frame: int in range(16):
				await process_frame
				await RenderingServer.frame_post_draw
				var image: Image = root.get_texture().get_image()
				var path: String = "res://assets/promo/frames/%02d.png" % frame
				_check(image.save_png(path) == OK, "capture frame %d" % frame)
				if frame == 0:
					_check(image.save_png("res://assets/screenshots/demo-overview.png") == OK, "overview PNG")
				if frame < 15:
					demo.next_button.pressed.emit()
	print("DEMO: %d checks, %d failures" % [_checks, _failures])
	demo.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
