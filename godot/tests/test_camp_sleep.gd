extends SceneTree
## Actual camp input, typed sleep forecasts, deadlines, waking and death isolation.

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	root.push_input(event, true)

func click(at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func run() -> void:
	var field_scene = load("res://game.tscn").instantiate()
	field_scene.terrain_seed = 40
	root.add_child(field_scene)
	field_scene.set_speed(0)
	current_scene = field_scene
	await process_frame
	await process_frame
	var game = current_scene
	game.set_speed(0)
	game._focus_person()
	var person = game.human
	person.fatigue = 80
	game._show_person()
	var cell := Vector2i(8, 8)
	game._start_selection(cell, false)
	var camp: Vector3 = game._surface_point(person.home * game.METRES_TO_UNITS)
	await click(game._camera.unproject_position(camp))
	check(game._camp_menu.has_method("wheel_rect"), "Camp offers Sleep in the shared action wheel")
	if not game._camp_menu.has_method("wheel_rect"):
		current_scene.free()
		quit(1)
		return
	await click(game._camp_menu._origin + Vector2(0, 132))
	var window = game._sleep_window
	check(window.visible and person.sleep_remaining == 0 and person.glycogen == 1989.0, "Sleep opens a duration preview without starting or changing needs")
	window.hours.get_line_edit().text = "2"
	window.hours.get_line_edit().text_changed.emit("2")
	await process_frame
	check(window._preview.text.contains("45%") and window._preview.text.contains("1859 kcal") and window._preview.text.contains("65.0 kg"), "Typing two hours immediately predicts restedness, remaining energy and weight")
	var focus: Vector3 = game._focus()
	await click(Vector2(1000, 600))
	check(game.selected.keys() == [cell] and game._focus() == focus, "Sleep configuration cannot click through to select land or move the camera")
	key(KEY_ESCAPE)
	check(not window.visible and person.sleep_remaining == 0 and person.fatigue == 80, "Closing sleep configuration spends no time and earns no recovery")
	key(KEY_G)
	key(KEY_DOWN)
	key(KEY_ENTER)
	check(window.visible and not game._food_window.visible, "Camp keyboard navigation activates Sleep instead of always choosing Eat")
	window.hours.get_line_edit().text = "25"
	window.hours.get_line_edit().text_changed.emit("25")
	await process_frame
	check(window.start.disabled, "Out-of-range typed hours cannot start sleep")
	window.hours.get_line_edit().text = "2"
	window.hours.get_line_edit().text_changed.emit("2")
	await process_frame
	check(not window.start.disabled, "Correcting the typed duration immediately enables Sleep")
	game.work("Plow")
	await click(window.start.get_global_rect().get_center())
	check(not window.visible and person.sleep_remaining == 2 and game._human_hud._wake_button.visible, "Confirming sleep latches the exact hours and offers Wake up while paused")
	var clock: float = game._day_time
	game._process(1)
	check(person.fatigue == 80 and person.sleep_remaining == 2 and game._day_time == clock, "Pause freezes the sleep clock and recovery")
	game.advance_time(game.seconds_per_day / 24.0)
	check(person.activity == "Sleeping" and is_equal_approx(person.sleep_remaining, 1) and is_equal_approx(person.fatigue, 67.5) and is_equal_approx(person.glycogen, 1989.0 - person.basal()), "One hour earns exactly its predicted sleep recovery")
	game._open_food()
	check(game._food_window.prepare.disabled, "Food preparation cannot spend grain during a pending sleep")
	key(KEY_ESCAPE)
	await click(game._human_hud._wake_button.get_global_rect().get_center())
	check(person.sleep_remaining == 0 and not game._human_hud._wake_button.visible, "Wake up ends sleep early without discarding field work")
	game.advance_time(game.seconds_per_day / 24.0 * 0.1)
	check(person.activity != "Sleeping" and (not person.job.is_empty() or not person.queue.is_empty()), "Preserved farming resumes after waking")
	person.cancel(game.farm)
	person.position = person.home
	person.eat(game.farm, "Barley", 300)
	key(KEY_R)
	check(window.visible and window.start.disabled, "A pending meal must finish before Sleep can be confirmed")
	key(KEY_ESCAPE)
	game.advance_time(game.seconds_per_day / 48.0)
	# A body 50 g above the limit of survival, with no ready energy or food.
	person.glycogen = 0.0
	person.stomach = 0.0
	person.stomach_kcal = 0.0
	person.fat = 2.0
	person.lean = Human.DEATH_BMI * Human.HEIGHT * Human.HEIGHT - 1.95
	person.fatigue = 80
	key(KEY_R)
	window.hours.value = 8
	check(window._preview.text.contains("0%") and window._reason.text.contains("survive"), "The preview exposes starvation death instead of promising a full night's recovery")
	await click(window.start.get_global_rect().get_center())
	game.advance_time(game.seconds_per_day / 3.0)
	check(person.activity == "Dead" and game._game_over.visible and not window.visible, "Death during chosen sleep closes the window and ends the game")
	key(KEY_R)
	key(KEY_G)
	check(not window.visible and not game._camp_menu.visible, "Game Over blocks reopening Sleep and the camp menu")
	key(KEY_TAB)
	key(KEY_ENTER)
	await process_frame
	await process_frame
	check(current_scene.human.health == 100 and current_scene.human.sleep_remaining == 0, "Hidden sleep controls cannot steal Restart")
	if failures.is_empty():
		print("PASS: camp Sleep, keyboard choice, live forecasts, typed duration, pause, early waking, work preservation, meal conflicts and death/Restart")
	current_scene.free()
	await create_timer(0.2).timeout
	quit(0 if failures.is_empty() else 1)
