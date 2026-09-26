extends SceneTree
## Run normally for native integration checks; append -- --capture for rendered PNG frames.

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
	for frame: int in range(6):
		await process_frame
	_check(demo.relationship != null, "demo owns a relationship component")
	_check(demo.relationship.profile == demo.PROFILE, "demo uses editable profile resource")
	_check(demo.relationship.get_points() == 320, "demo starts at 320 points")
	_check(demo.points_label.text == "320 / 1000 points", "initial points display")
	_check(demo.level_label.text == "Current level: Acquaintance", "initial level display")
	_check(demo.bounds_label.text == "Bounds: 0 to 1000", "minimum and maximum display")
	_check(demo.normalized_label.text == "Normalized relationship: 0.32", "normalized display")
	_check(demo.birthday_checkbox.button_pressed == false, "birthday multiplier starts off")
	_check(demo.coffee_button != null and demo.cake_button != null, "coffee and cake controls")
	_check(demo.trash_button != null and demo.unknown_button != null, "trash and unknown controls")

	# Dispatch one real mouse click through the viewport rather than invoking a callback.
	var coffee_position: Vector2 = demo.coffee_button.get_global_rect().get_center()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = coffee_position
	press.pressed = true
	root.push_input(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = coffee_position
	release.pressed = false
	root.push_input(release)
	await process_frame
	_check(demo.relationship.get_points() == 370, "native coffee action applies 50")
	_check(demo.last_gift_label.text == "Last gift: Coffee  ·  LOVE  ·  applied +50", "coffee result display")
	_check(demo.signal_label.text == "relationship_changed  320 → 370", "relationship signal display")

	demo.birthday_checkbox.button_pressed = true
	demo.cake_button.pressed.emit()
	_check(demo.relationship.get_points() == 410, "birthday cake applies doubled 40")
	_check(demo.level_label.text == "Current level: Friend", "400 boundary level display")
	_check(demo.last_gift_label.text == "Last gift: Cake  ·  LIKE  ·  applied +40", "birthday cake display")
	demo.trash_button.pressed.emit()
	_check(demo.relationship.get_points() == 330, "birthday trash applies doubled negative 80")
	_check(demo.last_gift_label.text == "Last gift: Trash  ·  HATE  ·  applied -80", "birthday trash display")
	demo.unknown_button.pressed.emit()
	_check(demo.relationship.get_points() == 330, "unknown action remains neutral")
	_check(demo.last_gift_label.text == "Last gift: Unknown  ·  NEUTRAL  ·  applied +0", "unknown result display")

	if "--capture" in OS.get_cmdline_user_args():
		if DisplayServer.get_name() == "headless":
			_check(false, "capture requires native rendering")
		else:
			DirAccess.make_dir_recursive_absolute("res://assets/screenshots")
			DirAccess.make_dir_recursive_absolute("res://assets/promo/frames")
			# Capture actual demo states, with the birthday control visibly changing the outcome.
			demo._reset_points()
			demo.birthday_checkbox.button_pressed = false
			var capture_actions: Array[Button] = [
				demo.coffee_button,
				demo.cake_button,
				demo.trash_button,
				demo.unknown_button,
				demo.coffee_button,
				demo.cake_button,
				demo.trash_button,
				demo.coffee_button,
				demo.cake_button,
				demo.unknown_button,
				demo.trash_button,
			]
			for frame: int in range(capture_actions.size()):
				await process_frame
				await RenderingServer.frame_post_draw
				var image: Image = root.get_texture().get_image()
				var path: String = "res://assets/promo/frames/%02d.png" % frame
				_check(image.save_png(path) == OK, "capture frame %d" % frame)
				if frame == 0:
					_check(image.save_png("res://assets/screenshots/demo-overview.png") == OK, "overview PNG")
				if frame == 4:
					demo.birthday_checkbox.button_pressed = true
				capture_actions[frame].pressed.emit()

	for control: Control in [demo.coffee_button, demo.cake_button, demo.trash_button, demo.unknown_button]:
		_check(control.get_global_rect().end.x <= root.size.x, "gift control fits viewport horizontally")
		_check(control.get_global_rect().end.y <= root.size.y, "gift control fits viewport vertically")
	_check(demo.last_gift_label.get_global_rect().end.y <= root.size.y, "result label fits viewport")
	print("DEMO: %d checks, %d failures" % [_checks, _failures])
	demo.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
