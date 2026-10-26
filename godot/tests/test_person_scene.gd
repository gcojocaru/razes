extends SceneTree
## Real scene input, the shared clock, queued farming and the needs panel.

## The old five-plot seed store, which these checks' seed arithmetic was written for.
const OLD_STOCK := {"Barley": 10000, "Oats": 8000, "Millet": 1800, "Wheat": 7500, "Rye": 8000}

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

func until(game, condition: Callable, hours := 48.0, step := 0.05) -> bool:
	for i in ceili(hours / step):
		if condition.call():
			return true
		game.advance_time(game.seconds_per_day * step / 24.0)
	return condition.call()

func run() -> void:
	var field_scene = load("res://game.tscn").instantiate()
	field_scene.terrain_seed = 40
	root.add_child(field_scene)
	field_scene.set_speed(0)
	current_scene = field_scene
	await process_frame
	await process_frame
	var game = current_scene
	game.farm.stock = OLD_STOCK.duplicate()
	var person = game.get("human")
	check(person != null, "The game starts with one simulated person")
	if person == null:
		current_scene.free()
		quit(1)
		return
	# This suite isolates the existing body/UI arithmetic from randomized exposure weather.
	person.weather = null
	game.set_speed(0)
	check(game.find_child("HumanActor", true, false) != null and game.find_child("HumanHud", true, false) != null, "The person and their needs appear in the game")
	check(not game._human_hud._supplies.text.contains("Flour"), "The farmer has no initial flour supply")
	check(is_equal_approx(game._day_time / game.seconds_per_day * 24, 6.0), "The first farming day starts at 06:00")
	var cell := Vector2i(8, 8)
	game._start_selection(cell, false)
	key(KEY_F)
	check(game.farm.stage(cell) == "Grass" and person.queue.size() == 1, "F queues plowing without changing the field instantly")
	check(not game._farm_hud.buttons.Plow.visible and "queued" in game._farm_hud._detail_label.text.to_lower(), "Queued plots explain their pending work instead of offering duplicate actions")
	key(KEY_C)
	check(game._farm_hud.action_wheel.entries.is_empty() and "queued" in game._farm_hud.action_wheel.hub_detail.text.to_lower(), "The action wheel excludes already-queued work")
	key(KEY_ESCAPE)
	game.selected[Vector2i(9, 8)] = true
	game._show_farm()
	check("Plow 1" in game._farm_hud.buttons.Plow.tooltip_text, "A mixed selection previews only its unassigned plot")
	game.selected.erase(Vector2i(9, 8))
	game._show_farm()
	key(KEY_F)
	check(person.queue.size() == 1, "Repeated commands cannot duplicate work on a plot")
	var position: Vector2 = person.position
	var clock: float = game._day_time
	game._process(1.0)
	check(person.position == position and game._day_time == clock, "Pause stops the person and the calendar together")
	game.advance_time(game.seconds_per_day / 24.0)
	check(game.farm.stage(cell) == "Grass" and person.position.distance_to(position) > 10.0, "The farmer walks to the field and works before its stage changes")
	check(game._farm_hud._plot_label.text.begins_with("Plowing ") and game._farm_hud._detail_label.text.contains("h left"), "Selected plowing progress updates while work is running")
	var remaining: float = person.job.remaining
	key(KEY_BACKSPACE)
	check(game._farm_hud._plot_label.text.begins_with("Plowing ") and game._farm_hud.buttons.Plow.visible, "Cleared plowing keeps its visible progress and offers resuming")
	key(KEY_F)
	check(is_equal_approx(person.queue[0].remaining, remaining), "Requeued scene plowing resumes the saved remaining hours")
	check(until(game, func(): return game.farm.stage(cell) == "Plowed", 6.0), "Timed plowing eventually completes")
	key(KEY_C)
	key(KEY_RIGHT)
	key(KEY_ENTER)
	check(game.seed_crop() == "Oats" and game.farm.stage(cell) == "Plowed" and game.farm.stock.Oats == 6400, "The keyboard wheel reserves oat seed while sowing waits for the person")
	check(until(game, func(): return game.farm.stage(cell) == "Sown", 8.0), "The farmer collects seed and completes sowing")
	check(game.farm.crop(cell) == "Oats" and game.farm.record(game.day, "Oats").seed == 1600, "Timed sowing uses the shared Farm rules and records the seed once")
	game.farm.plots[cell].stage = "Ripe"
	game.farm.plots[cell].growth = 1.0
	game._show_farm()
	key(KEY_F)
	check(game.farm.stock.Oats == 6400, "Ordering harvest does not immediately fill the store")
	check(until(game, func(): return person.carried_crop == "Oats" and person.carried == 5600, 12.0, 1.0 / 600), "The harvest is visibly carried before it reaches the store")
	check(game.farm.stock.Oats == 6400, "Grain in the person's bag is not simultaneously in the store")
	check(until(game, func(): return person.carried == 0 and game.farm.stock.Oats == 12000, 1.0), "The grain enters the store on arrival at camp")
	key(KEY_H)
	check(game._focus().is_equal_approx(game._surface_point(person.position * game.METRES_TO_UNITS)), "H centres the camera on the person")
	var camp_focus: Vector3 = game._focus()
	Input.action_press("ui_left")
	game._process(0.01)
	Input.action_release("ui_left")
	check(game._focus().x < camp_focus.x, "Panning west from camp moves west instead of snapping back to the field")
	key(KEY_B)
	var body = game._body
	check(body.visible and not game._human_hud.visible and body._values["Weight"][0].text == "%.1f kg" % person.mass() and body._values["Basal"][0].text.contains("kcal a day"), "B opens the Body window with the farmer's weight and metabolism, in place of the Farmer panel")
	check(body._scroll.custom_minimum_size.y > 300.0, "The Body window opens with all its rows showing")
	var energy: String = body._values["Ready energy"][0].text
	game.advance_time(game.seconds_per_day / 24.0)
	check(body._values["Ready energy"][0].text != energy and body._values["Burning now"][0].text.begins_with("Idle"), "The Body window follows the farmer live")
	key(KEY_I)
	check(game._inventory.visible and not body.visible, "Inventory and Body share the left side, one at a time")
	key(KEY_I)
	game._human_hud._buttons.get_child(1).pressed.emit()
	check(body.visible, "The Farmer panel's Body button opens the Body window")
	key(KEY_B)
	check(not body.visible and game._human_hud.visible, "B closes the Body window and brings back the Farmer panel")
	key(KEY_G)
	key(KEY_ENTER)
	game._food_window.prepare.pressed.emit()
	game.advance_time(game.seconds_per_day / 48.0)
	check(game.farm.stock.Barley == 9700 and person.stomach_kcal > 1000.0, "Camp Eat and explicit preparation cook grain from the player's existing stock")
	key(KEY_R)
	check(game._sleep_window.visible and person.sleep_remaining == 0, "R opens explicit sleep configuration without starting it")
	game._sleep_window.start.pressed.emit()
	check(person.sleep_remaining == 8 and game._human_hud._wake_button.visible, "Chosen sleep offers Wake up immediately while paused")
	key(KEY_R)
	game._start_selection(Vector2i(9, 8), false)
	game.work("Plow")
	key(KEY_BACKSPACE)
	check(person.queue.is_empty() and person.job.is_empty(), "Backspace clears the work order")
	var old_day: int = game.day
	var stored: int = game.farm.stored()
	game.skip_days(1)
	check(game.day == old_day + 1 and game.farm.stored() == stored, "Debug day skips never automatically eat the player's grain")
	check(person.health > 0 and game._human_hud.title.text == person.name, "The farmer survives the test day after an explicitly requested meal")
	var stale := Vector2i(9, 8)
	game._day_time = game.seconds_per_day / 3.0
	person.wake_up()
	person.fatigue = 0
	game.farm.plots[stale] = {"stage": "Ripe", "crop": "Oats", "growth": 1.0, "fertility": 1.0, "wintered": true, "moisture": 0.0, "days": 0}
	game._start_selection(stale, false)
	game.work("Harvest")
	game.farm.plots[stale].stage = "Withered"
	game._show_farm()
	check(until(game, func(): return person.queue.is_empty() and person.job.is_empty(), 4.0), "A harvest invalidated by frost releases its job")
	check(game._farm_hud.buttons.Plow.visible and "queued" not in game._farm_hud._detail_label.text.to_lower(), "Releasing stale work refreshes field actions without selecting the plot again")
	person.position = person.home
	# A body 50 g above the limit of survival, with no ready energy or food.
	person.glycogen = 0.0
	person.stomach = 0.0
	person.stomach_kcal = 0.0
	person.fat = 2.0
	person.lean = Human.DEATH_BMI * Human.HEIGHT * Human.HEIGHT - 1.95
	var death_clock: float = game._day_time
	game.advance_time(game.seconds_per_day / 4.0)
	check(person.activity == "Dead" and game.get("_game_over") != null, "Zero health ends the game and creates the Game Over screen")
	if game.get("_game_over") != null:
		var game_over_title = game._game_over.find_child("GameOverTitle", true, false)
		check(game._game_over.visible and game_over_title != null and game_over_title.text == "Game Over", "Game Over is visibly displayed after health reaches zero")
	check(game._day_time > death_clock and game._day_time < death_clock + game.seconds_per_day / 8.0 and is_equal_approx(person.bmi(), Human.DEATH_BMI), "A long time skip stops the clock at death rather than consuming its remaining hours")
	clock = game._day_time
	old_day = game.day
	stored = game.farm.stored()
	game.set_speed(4)
	game._process(1.0)
	game.skip_days(1)
	key(KEY_SPACE)
	check(game.speed == 0 and game.day == old_day and game._day_time == clock and game.farm.stored() == stored, "Game Over blocks resume, further time skips and resource changes")
	key(KEY_F10)
	check(not game._sound_control.panel.visible, "Game Over cannot reopen a hidden sound panel or steal Restart's keyboard input")
	check(not game._sound_control.visible, "The underlying Sound button cannot receive Tab focus after Game Over")
	key(KEY_TAB)
	key(KEY_ENTER)
	await process_frame
	await process_frame
	check(current_scene.human.health == 100.0 and current_scene.human.activity != "Dead", "Enter restarts after death without requiring a mouse")
	if failures.is_empty():
		print("PASS: visible person, queued input, real walking/work/hauling, reservations, pause, focus/rest/cancel, shared skips and death UI")
	current_scene.free()
	await create_timer(0.2).timeout
	quit(0 if failures.is_empty() else 1)
