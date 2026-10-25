extends SceneTree
## GPU-rendered proof of the contextual wheel, including the minimum window.

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var args := OS.get_cmdline_user_args()
	var output: String = args[0] if not args.is_empty() else "/tmp/stefan-wheel"
	DirAccess.make_dir_recursive_absolute(output)
	change_scene_to_file("res://game.tscn")
	await process_frame
	await process_frame
	var game = current_scene
	game.set_speed(0)
	var cell := Vector2i(8, 8)
	game._start_selection(cell, false)
	var wheel = game._farm_hud.action_wheel
	for state in ["grass", "plowed", "growing", "ripe", "mixed", "autumn", "summer", "winter", "edge"]:
		game.day = 0
		game.farm = Farm.new()
		game.selected = {cell: true}
		if state != "grass":
			game.farm.act(cell, 0)
		if state in ["growing", "ripe", "mixed"]:
			game.farm.act(cell, 0, "Barley")
			game.farm.plots[cell].growth = 0.42
		if state in ["ripe", "mixed"]:
			game.farm.plots[cell].stage = "Ripe"
		if state == "mixed":
			game.selected[cell + Vector2i(1, 0)] = true
			game.selected[cell + Vector2i(2, 0)] = true
			game.farm.act(cell + Vector2i(1, 0), 0)
		if state == "autumn":
			game.day = Calendar.DAYS_PER_SEASON * 2
		if state == "summer":
			game.day = Calendar.DAYS_PER_MONTH * 2
		if state == "winter":
			game.day = Calendar.DAYS_PER_SEASON * 3
		if state == "edge":
			root.size = Vector2i(1000, 700)
			await process_frame
		game.today = game.weather.on(game.day)
		game._show_date()
		game._show_farm()
		wheel.open_at(game._camera.unproject_position(game.cell_center(cell)) if state != "edge" else root.get_visible_rect().end)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(output.path_join(state + ".png"))
		wheel.hide()
	print("Captured field action wheels to " + output)
	quit()
