extends SceneTree
## Camp context input, inventory selection and the explicit selected-grain meal.

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

func click(at: Vector2, button := MOUSE_BUTTON_LEFT) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = button
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
	var selected := Vector2i(0, 8)
	game._start_selection(selected, false)
	var camp: Vector3 = game._surface_point(game.human.home * game.METRES_TO_UNITS)
	var stock: Dictionary = game.farm.stock.duplicate()
	await click(game._camera.unproject_position(camp))
	check(game.get("_camp_menu") != null, "Clicking camp opens a camp context menu")
	if game.get("_camp_menu") == null:
		current_scene.free()
		quit(1)
		return
	check(game._camp_menu.visible and game.selected.keys() == [selected], "Camp interaction preserves the field selection")
	check(game._camp_menu.has_method("wheel_rect"), "Camp actions use the shared annular action wheel")
	if not game._camp_menu.has_method("wheel_rect"):
		current_scene.free()
		quit(1)
		return
	check(game._camp_menu.entries.map(func(entry): return entry.action) == ["Eat", "Sleep", "Move"], "Camp has Eat, Sleep and Move wheel segments")
	for action in ["Eat", "Sleep"]:
		check(game._camp_menu.ICONS[action].get_size() == Vector2(64, 64), action + " has a matching wheel icon")
	key(KEY_ENTER)
	await process_frame
	check(game._food_window.visible and not game._sleep_window.visible, "The first camp wheel opening focuses Eat for keyboard activation")
	key(KEY_ESCAPE)
	key(KEY_G)
	await click(game._camp_menu._origin + Vector2(0, -132))
	await process_frame
	var food = game._food_window
	check(food.visible and not game._camp_menu.visible and not game.human.eating_requested and game.farm.stock == stock, "Choosing Eat opens inventory selection without spending grain or starting a meal")
	check(food.grain_buttons.size() == Farm.CROPS.keys().reduce(func(bags: int, crop: String) -> int: return bags + game.farm.bags(crop).size(), 0), "The food window shows each starting grain bag")
	food.quantity.value = 375
	for grain in [["Barley", "1327.5", "354"], ["Oats", "1458.75", "389"], ["Millet", "1417.5", "378"], ["Wheat", "1226.25", "327"], ["Rye", "1267.5", "338"]]:
		var bag = food.grain_buttons.filter(func(button): return button.crop == grain[0])[0]
		await click(bag.get_global_rect().get_center())
		check(food._preview.text.contains("Meal: " + grain[1] + " kcal") and bag.tooltip_text.contains(grain[2] + " kcal / 100 g"), "Selecting %s immediately updates the exact portion calories and bag nutrition" % grain[0])
	key(KEY_ESCAPE)
	check(not food.visible and game.farm.stock == stock, "Closing food preparation consumes nothing")
	await click(game._camera.unproject_position(camp), MOUSE_BUTTON_RIGHT)
	check(game._camp_menu.visible and game.selected.keys() == [selected], "Right-clicking camp opens its wheel without changing field selection")
	await click(game._camp_menu._origin)
	check(not game._camp_menu.visible and not food.visible and not game._sleep_window.visible and game.selected.keys() == [selected], "The wheel hub cannot activate either action or click through to land")
	key(KEY_G)
	check(game._camp_menu.visible and not food.visible, "G opens the same camp menu rather than directly eating")
	await click(Vector2(root.get_visible_rect().size.x - 20, root.get_visible_rect().size.y / 2))
	check(not game._camp_menu.visible and game.selected.keys() == [selected], "Outside dismissal cannot select land or issue work")
	root.content_scale_size = Vector2i(1920, 1080)
	await process_frame
	await process_frame
	game._camp_menu.open_at(root.get_visible_rect().size - Vector2(5, 5))
	root.content_scale_size = Vector2i(1440, 900)
	await process_frame
	await process_frame
	check(root.get_visible_rect().encloses(game._camp_menu.wheel_rect()), "Camp wheel remains reachable after shrinking the window")
	key(KEY_ESCAPE)
	key(KEY_G)
	key(KEY_ENTER)
	await process_frame
	var oats = food.grain_buttons.filter(func(button): return button.crop == "Oats")[0]
	await click(oats.get_global_rect().get_center())
	check(food.selected_crop == "Oats", "An inventory bag selects that grain for porridge")
	food.quantity.get_line_edit().text = "450"
	food.quantity.get_line_edit().text_changed.emit("450")
	await process_frame
	check(food.prepare.disabled and food._reason.text.contains("room for 375 g"), "A portion bigger than the stomach explains its room instead of preparing")
	food.quantity.get_line_edit().text = "360"
	food.quantity.get_line_edit().text_changed.emit("360")
	await process_frame
	check(food._preview.text.contains("1400.4 kcal") and not food.prepare.disabled, "Typing a portion updates its recipe before confirmation")
	await click(food.prepare.get_global_rect().get_center())
	check(not food.visible and game.human.eating_requested and game.human.meal_crop == "Oats" and game.human.meal_grams == 360, "Prepare commits the typed quantity and the chosen grain")
	check(game.farm.stock.Oats == Farm.STARTING_STOCK.Oats - 360 and game.farm.stock.Barley == Farm.STARTING_STOCK.Barley, "Exactly 360 g of oats is reserved without substituting barley")
	key(KEY_G)
	key(KEY_ENTER)
	await process_frame
	check(food.prepare.disabled, "A pending meal cannot be confirmed twice")
	key(KEY_ESCAPE)
	game.advance_time(game.seconds_per_day / 24.0 * 0.25)
	check(game.human.eating_requested and game.human.stomach_kcal == 0.0, "Cooking takes time before the porridge reaches the stomach")
	game.advance_time(game.seconds_per_day / 24.0 * 0.5)
	check(not game.human.eating_requested and is_equal_approx(game.human.stomach_kcal, 1400.4 - 0.15 * game.human.digestion()), "360 g reaches the stomach as 1400.4 kcal after 36 game minutes, then digests")
	key(KEY_G)
	key(KEY_ENTER)
	await process_frame
	game.farm.stock.Oats = 100
	game._show_farm()
	check(food.quantity.value == 360 and food.prepare.disabled, "Stock changes invalidate the requested amount without silently shrinking the meal")
	await click(food.prepare.get_global_rect().get_center())
	check(game.farm.stock.Oats == 100 and not game.human.eating_requested, "An unavailable portion cannot consume resources")
	food.quantity.get_line_edit().text = "20"
	food.quantity.get_line_edit().text_changed.emit("20")
	await process_frame
	check(not food.prepare.disabled and food._preview.text.contains("77.8 kcal"), "Typing a smaller portion that fits the stomach immediately enables preparation")
	for crop in Farm.CROPS:
		game.farm.stock[crop] = 0
	game._show_farm()
	check(food.prepare.disabled and food.grain_buttons.is_empty(), "An empty inventory offers no phantom food")
	game.human.lean = 20.0
	game.advance_time(game.seconds_per_day / 1440.0)
	key(KEY_G)
	check(game._game_over.visible and not food.visible and not game._camp_menu.visible, "Game Over closes and blocks both new camp controls")
	key(KEY_TAB)
	key(KEY_ENTER)
	await process_frame
	await process_frame
	check(current_scene.human.health == 100.0 and not current_scene._food_window.visible, "Hidden food controls cannot steal keyboard Restart")
	if failures.is_empty():
		print("PASS: camp context input, inventory grain selection, typed portions, exact reservation, proportional porridge, stale stock, dismissal and Game Over")
	current_scene.free()
	await create_timer(0.2).timeout
	quit(0 if failures.is_empty() else 1)
