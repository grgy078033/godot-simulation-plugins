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
	_check(demo.scheduler != null, "demo owns a scheduler node")
	_check(demo.scheduler.schedule == demo.EVENT_SCHEDULE, "demo uses editable schedule resource")
	_check(demo.clock_label.text == "19:00", "demo starts at 19:00")
	_check(demo.active_label.text == "Active now: Street Lights", "initial overnight event is active")
	_check(demo.next_event_label.text == "Next start: Tavern Music at 20:00  (60 min)", "initial next start display")
	_check(demo.event_status_labels[&"street_lights"].text == "ACTIVE", "initial active row display")
	_check(demo.event_status_labels[&"shop_open"].text == "idle", "initial idle row display")
	_check(demo.previous_button != null and demo.next_button != null, "clock controls exist")
	_check(demo.transition_label.text.contains("START  Street Lights"), "initial signal appears in transition log")

	# Dispatch a real mouse click through the viewport rather than invoking a callback.
	_click(demo.next_button)
	await process_frame
	_check(demo.clock_label.text == "20:00", "native next-hour action advances the clock")
	_check(demo.active_label.text == "Active now: Street Lights, Tavern Music", "native action activates concurrent event")
	_check(demo.event_status_labels[&"tavern_music"].text == "ACTIVE", "new event row becomes active")
	_check(demo.signal_hint_label.text == "event_started(tavern_music)", "start signal display")

	demo.next_button.pressed.emit()
	_check(demo.clock_label.text == "21:00", "second clock action advances")
	demo.next_button.pressed.emit()
	_check(demo.clock_label.text == "22:00", "third clock action reaches ghost window")
	_check(demo.active_label.text == "Active now: Street Lights, Tavern Music, Ghost Spawn", "three concurrent events display")
	_check(demo.event_status_labels[&"ghost_spawn"].text == "ACTIVE", "ghost row becomes active")
	demo.next_button.pressed.emit()
	_check(demo.clock_label.text == "23:00", "event end boundary is reachable")
	_check(demo.active_label.text == "Active now: Street Lights, Ghost Spawn", "tavern ends at its half-open boundary")
	_check(demo.event_status_labels[&"tavern_music"].text == "idle", "ended event row returns idle")

	demo.previous_button.pressed.emit()
	_check(demo.clock_label.text == "22:00", "previous-hour action rewinds")
	_check(demo.active_label.text == "Active now: Street Lights, Tavern Music, Ghost Spawn", "rewind reconciles destination")

	if "--capture" in OS.get_cmdline_user_args():
		if DisplayServer.get_name() == "headless":
			_check(false, "capture requires native rendering")
		else:
			DirAccess.make_dir_recursive_absolute("res://assets/screenshots")
			DirAccess.make_dir_recursive_absolute("res://assets/promo/frames")
			# Reset to the demo's advertised 19:00 state before capturing actual frames.
			demo._hour = 19
			demo._minute = 0
			demo._transition_log.clear()
			demo.scheduler.update_time(19, 0)
			# Present the initial destination transition without showing reset cleanup events.
			demo._transition_log = ["START  Street Lights"]
			demo.signal_hint_label.text = "Initial clock update"
			demo._refresh_state()
			var capture_actions: Array[Button] = [
				demo.next_button,
				demo.next_button,
				demo.next_button,
				demo.next_button,
				demo.previous_button,
				demo.next_button,
				demo.next_button,
				demo.next_button,
				demo.previous_button,
				demo.previous_button,
				demo.next_button,
			]
			for frame: int in range(capture_actions.size()):
				await process_frame
				await RenderingServer.frame_post_draw
				var image: Image = root.get_texture().get_image()
				var path: String = "res://assets/promo/frames/%02d.png" % frame
				_check(image.save_png(path) == OK, "capture frame %d" % frame)
				if frame == 0:
					_check(image.save_png("res://assets/screenshots/demo-overview.png") == OK, "overview PNG")
				if frame == 3:
					_check(image.save_png("res://assets/screenshots/late-night.png") == OK, "late-night PNG")
				capture_actions[frame].pressed.emit()

	for event_id: StringName in demo.event_status_labels:
		var state_label: Label = demo.event_status_labels[event_id]
		_check(state_label.get_global_rect().end.x <= root.size.x, "event row fits viewport horizontally")
		_check(state_label.get_global_rect().end.y <= root.size.y, "event row fits viewport vertically")
	_check(demo.transition_label.get_global_rect().end.y <= root.size.y, "transition log fits viewport")
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
