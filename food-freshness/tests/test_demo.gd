extends SceneTree
## Native integration checks; append -- --capture for rendered PNG frames.

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
	for _frame: int in range(8):
		await process_frame

	_check(demo.instances.size() == 3, "demo owns three independent freshness instances")
	_check(demo.instances[&"milk"].profile == demo.PROFILE, "demo uses editable profile Resource")
	_check(demo.day_label.text == "DAY 10", "demo starts at day ten")
	_check(demo.item_age_labels[&"milk"].text == "Age: 2 days", "initial Milk age")
	_check(demo.item_state_labels[&"milk"].text == "FRESH", "initial Milk state")
	_check(demo.item_stale_labels[&"milk"].text == "Until stale: 1 day", "initial Milk stale countdown")
	_check(demo.item_expired_labels[&"milk"].text == "Until expired: 3 days", "initial Milk expiration countdown")
	_check(demo.item_age_labels[&"fish"].text == "Age: 5 days", "initial Fish age")
	_check(demo.item_state_labels[&"fish"].text == "EXPIRED", "initial Fish expired state")
	_check(demo.item_age_labels[&"bread"].text == "Age: 0 days", "initial Bread age")
	_check(demo.item_state_labels[&"bread"].text == "FRESH", "initial Bread state")
	_check(demo.last_change_label.text.contains("setup is silent"), "initial setup is silent in UI")
	_check(demo.previous_day_button != null and demo.next_day_button != null, "day controls exist")

	# Dispatch one real mouse click through the viewport rather than invoking a callback.
	_click(demo.next_day_button)
	await process_frame
	_check(demo.day_label.text == "DAY 11", "native next-day action advances caller day")
	_check(demo.item_age_labels[&"milk"].text == "Age: 3 days", "native action updates Milk age")
	_check(demo.item_state_labels[&"milk"].text == "STALE", "native action crosses stale boundary")
	_check(demo.item_stale_labels[&"milk"].text == "Until stale: 0 days", "native stale countdown clamps")
	_check(demo.item_state_labels[&"fish"].text == "EXPIRED", "expired Fish remains expired")

	demo.next_day_button.pressed.emit()
	_check(demo.day_label.text == "DAY 12", "second day action")
	demo.next_day_button.pressed.emit()
	_check(demo.day_label.text == "DAY 13", "third day action")
	_check(demo.item_last_labels[&"milk"].text == "Last change: STALE → EXPIRED", "Milk expiration log")
	_check(demo.item_state_labels[&"milk"].text == "EXPIRED", "Milk enters expired on day thirteen")
	demo.next_day_button.pressed.emit()
	demo.next_day_button.pressed.emit()
	_check(demo.day_label.text == "DAY 15", "later expiration day is reachable")
	_check(demo.item_state_labels[&"milk"].text == "EXPIRED", "repeated expired state remains expired")
	demo.previous_day_button.pressed.emit()
	demo.previous_day_button.pressed.emit()
	demo.previous_day_button.pressed.emit()
	_check(demo.day_label.text == "DAY 12", "rewind control works")
	_check(demo.item_state_labels[&"milk"].text == "STALE", "rewind restores stale state")
	_check(demo.item_last_labels[&"milk"].text == "Last change: EXPIRED → STALE", "rewind transition log")

	if "--capture" in OS.get_cmdline_user_args():
		if DisplayServer.get_name() == "headless":
			_check(false, "capture requires native rendering")
		else:
			DirAccess.make_dir_recursive_absolute("res://assets/screenshots")
			DirAccess.make_dir_recursive_absolute("res://assets/promo/frames")
			demo._reset_demo_state()
			var capture_actions: Array[Button] = [
				demo.next_day_button,
				demo.next_day_button,
				demo.next_day_button,
				demo.next_day_button,
				demo.next_day_button,
				demo.previous_day_button,
				demo.previous_day_button,
				demo.next_day_button,
				demo.next_day_button,
				demo.next_day_button,
				demo.next_day_button,
			]
			for frame: int in range(capture_actions.size()):
				await process_frame
				await RenderingServer.frame_post_draw
				var image: Image = root.get_texture().get_image()
				var path: String = "res://assets/promo/frames/%02d.png" % frame
				_check(image.save_png(path) == OK, "capture frame %d" % frame)
				if frame == 0:
					_check(image.save_png("res://assets/screenshots/demo-overview.png") == OK, "overview PNG")
				capture_actions[frame].pressed.emit()

	for item_id: StringName in demo.item_state_labels:
		var state_label: Label = demo.item_state_labels[item_id] as Label
		_check(state_label.get_global_rect().end.x <= root.size.x, "item card fits viewport horizontally")
		_check(state_label.get_global_rect().end.y <= root.size.y, "item card fits viewport vertically")
	_check(demo.last_change_label.get_global_rect().end.y <= root.size.y, "transition label fits viewport")
	print("DEMO: %d checks, %d failures" % [_checks, _failures])
	demo.queue_free()
	await process_frame
	quit(0 if _failures == 0 else 1)


func _click(control: Control) -> void:
	var position: Vector2 = control.get_global_rect().get_center()
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


func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures += 1
		push_error(description)
