extends SceneTree
## Real renderer views of repeatable landscapes, rotations, farming and snow.

var output := "/tmp/stefan-terrain"
var game

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	var Terrain = load("res://terrain.gd")
	for view in [["Hills", 42], ["Hills", 7381], ["Hills", 90125], ["Steppe", 42], ["Lakeland", 42], ["Custom", 42]]:
		Terrain.land = Terrain.PRESETS.get(view[0], {"hills": Terrain.MAX_HILLS, "ponds": 4})
		game = load("res://game.tscn").instantiate()
		game.terrain_seed = view[1]
		root.add_child(game)
		game.set_speed(0)
		game._day_time = game.seconds_per_day * 0.5
		game.today = {"temperature": 12, "condition": "Clear"}
		game._weather_effects.show_weather("Clear", true)
		game._show_date()
		await shot("%s-%d" % [view[0].to_lower(), view[1]])
		if view == ["Hills", 42]:
			game.farm.stock.Barley = 100000
			for x in range(5, 9):
				for y in range(6, 10):
					var cell := Vector2i(x, y)
					if game.terrain.cell_reason(cell) != "":
						continue
					game.farm.act(cell, 0)
					if x > 5:
						game.farm.act(cell, 0, "Barley")
						game.farm.plots[cell].growth = 0.65
						if y == 6:
							game.farm.plots[cell].stage = "Ripe"
			game._start_selection(Vector2i(6, 7), false)
			game._select_to(Vector2i(8, 9))
			await shot("farming")
			var pond: Dictionary = game.terrain.ponds[0]
			var wet := Vector2i(floori(pond.center.x / 2.0 + 8), floori(pond.center.y / 2.0 + 8))
			game._start_selection(wet, false)
			await shot("water-selection")
			game._start_selection(Vector2i(7, 7), false)
			game._zoom = 6.0
			game._place_camera(game.cell_center(Vector2i(7, 7)))
			await shot("farming-close")
			game._zoom = 36.0
			game._place_camera(Vector3.ZERO)
			game.selected.clear()
			game._show_farm()
			game.rotate_camera(PI)
			await shot("rotated")
			game.human.order(game.farm, [Vector2i(15, 15)], game.day, "Plow")
			game.advance_time(game.seconds_per_day * 0.01 / 24.0)
			game._focus_person()
			await shot("walking-hill")
			game.human.cancel(game.farm)
			game.advance_time(game.seconds_per_day * 0.2 / 24.0)
			game._focus_person()
			await shot("camp")
			game._zoom = 40.0
			game._place_camera(Vector3.ZERO)
			game._weather_effects.show_weather("Snow", true)
			game.today = {"temperature": -4, "condition": "Snow"}
			game._show_date()
			game._field.set_shader_parameter("snow", 1.0)
			await shot("snow")
			root.size = Vector2i(1000, 700)
			await shot("minimum")
			root.size = Vector2i(1280, 800)
		game.free()
		await process_frame
	print("Captured procedural terrain to " + output)
	quit()

func shot(label: String) -> void:
	print("Capturing " + label)
	await create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))
