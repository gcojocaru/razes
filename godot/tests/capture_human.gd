extends SceneTree
## Real renderer proof of one farmer's work, hauling and camp routine.

var output := "/tmp/stefan-human"

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	change_scene_to_file("res://game.tscn")
	await process_frame
	await process_frame
	var game = current_scene
	game.set_speed(0)
	game.weather = Weather.new(7)
	game.day = 35
	game._start_day()
	await save("field")
	game._focus_person()
	game._zoom = 2.1
	game._focus_person()
	await save("camp")
	game._open_camp_menu()
	await save("camp-menu")
	game._camp_menu._focus_entry(1)
	await save("camp-sleep-wheel")
	root.size = Vector2i(1000, 700)
	game._camp_menu.open_at(root.get_visible_rect().size - Vector2.ONE * 8)
	await save("camp-wheel-minimum")
	root.size = Vector2i(1280, 800)
	game._open_food()
	game._food_window._choose_grain("Oats")
	game._food_window.quantity.value = 375
	await save("food-preparation")
	root.size = Vector2i(1000, 700)
	await save("food-minimum")
	root.size = Vector2i(1280, 800)
	game._food_window.hide()
	game.human.fatigue = 80
	game._open_sleep()
	game._sleep_window.hours.value = 2
	await save("sleep-preparation")
	root.size = Vector2i(1000, 700)
	await save("sleep-minimum")
	root.size = Vector2i(1280, 800)
	game.human.calories = 30
	game.human.health = 1
	game._sleep_window.hours.value = 8
	await save("sleep-warning")
	game.human.calories = 2000
	game.human.health = 100
	game._sleep_window.hide()
	game.human.fatigue = 0
	var cell := Vector2i(0, 8)
	game._start_selection(cell, false)
	game.work("Plow")
	game.advance_time(game.seconds_per_day / 24.0 / 600.0)
	game._focus_person()
	await save("walking")
	game.advance_time(game.seconds_per_day / 24.0 * 0.1)
	game._focus_person()
	await save("plowing")
	game.advance_time(game.seconds_per_day / 24.0 * 3.0)
	game.choose_crop("Oats")
	game.advance_time(game.seconds_per_day / 24.0 * 0.1)
	game._focus_person()
	await save("sowing")
	game.advance_time(game.seconds_per_day / 24.0)
	game.farm.plots[cell].stage = "Ripe"
	game.farm.plots[cell].growth = 1.0
	game._show_farm()
	game.work("Harvest")
	game.advance_time(game.seconds_per_day / 24.0 * 0.5)
	game._focus_person()
	await save("harvesting")
	for i in 12000:
		if game.human.carried_crop == "Oats" and game.human.carried > 0:
			break
		game.advance_time(game.seconds_per_day / 24.0 / 600.0)
	game._focus_person()
	await save("carrying")
	game.advance_time(game.seconds_per_day / 24.0)
	game.human.cancel(game.farm)
	game.human.position = game.human.home
	game.human.calories = 700
	game.human.eat(game.farm, "Barley", 300)
	game.advance_time(game.seconds_per_day / 24.0 * 0.1)
	game._focus_person()
	await save("cooking")
	game.advance_time(game.seconds_per_day / 24.0 * 0.5)
	game._day_time = game.seconds_per_day * 22.0 / 24.0
	game.human.fatigue = 80
	game.human.sleep(8)
	game.advance_time(game.seconds_per_day / 24.0 * 0.1)
	game._focus_person()
	await save("sleeping")
	root.size = Vector2i(1000, 700)
	game._zoom = 8
	game._focus_person()
	await save("minimum")
	game.toggle(game._inventory)
	await save("inventory-minimum")
	game.toggle(game._inventory)
	game.human.wake_up()
	game.human.calories = -90
	game.human.health = 1
	game.advance_time(game.seconds_per_day / 24.0)
	game._focus_person()
	await save("dead")
	print("Captured the human farming loop to " + output)
	quit()

func save(label: String) -> void:
	current_scene._show_farm()
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))
