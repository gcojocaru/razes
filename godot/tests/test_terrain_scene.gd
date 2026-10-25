extends SceneTree
## Picking and gameplay follow the same playable hills and water surface.

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://game.tscn").instantiate()
	game.terrain_seed = 42
	root.add_child(game)
	current_scene = game
	await process_frame
	await process_frame
	game.set_speed(0)
	check(game.farm.terrain == game.terrain and game.human.terrain == game.terrain, "Farm actions and movement share the rendered terrain")
	var land: Array[Vector2i] = []
	var water: Array[Vector2i] = []
	for x in 16:
		for z in 16:
			var cell := Vector2i(x, z)
			if game.terrain.cell_reason(cell) == "":
				land.append(cell)
			elif game.terrain.cell_reason(cell) == "Water":
				water.append(cell)
	check(land.size() > 100 and water.size() > 0, "The playing field contains usable land and water")
	if land.is_empty() or water.is_empty():
		game.free()
		quit(1)
		return
	var tested := 0
	for cell in land + water:
		if tested % 7 == 0:
			var world: Vector3 = game.cell_center(cell)
			var surface: float = maxf(game.terrain.height_at(Vector2(world.x, world.z)), -0.3)
			check(is_equal_approx(world.y, surface), "Plot centres follow the visible hill or water surface")
			game._zoom = 8.0
			game._place_camera(world)
			for turn in [0.0, PI * 0.5, PI]:
				game.rotate_camera(turn)
				var picked: Vector2i = game.cell_at_screen(game._camera.unproject_position(world))
				check(picked == cell, "Picking finds %s at %s after camera rotation; got %s" % [cell, world, picked])
		tested += 1
	var pond: Vector2 = game.terrain.ponds[0].center
	game._place_camera(game._surface_point(pond))
	game._start_camp_placement()
	var before: Vector2 = game.terrain.camp
	check(not game.place_camp(game._camera.unproject_position(game._surface_point(pond))) and game.terrain.camp == before and game.placing_camp, "A camp cannot move into a pond and the old camp stays")
	game.placing_camp = false
	var spot: Vector3 = game.cell_center(land[0])
	game._zoom = 8.0
	game._place_camera(spot)
	game._start_camp_placement()
	check(game.placing_camp and game.place_camp(game._camera.unproject_position(spot)), "Move places the camp on clicked dry ground")
	check(not game.placing_camp and game.human.home == game.terrain.camp / game.METRES_TO_UNITS and Vector2(game._camp.position.x, game._camp.position.z).is_equal_approx(Vector2(spot.x, spot.z)), "The camp moves to the centre of the clicked plot")
	check(game.terrain.cell_reason(land[0]) == "Camp" and game.farm.action(land[0], game.day).reason == "Camp", "The camp's plot cannot be farmed")
	var hill: Vector2i = land.filter(func(cell: Vector2i) -> bool: return cell != land[0] and game.cell_center(cell).y > 0.5)[0]
	var at: Vector3 = game.cell_center(hill)
	game.human.position = Vector2(at.x, at.z) / game.METRES_TO_UNITS
	game._show_person()
	check(is_equal_approx(game._human_actor.position.y, at.y), "The farmer's feet follow the actual hillside surface")
	game._focus_person()
	check(game._focus().is_equal_approx(at), "Focus finds the person at their ground height")
	# The dummy renderer discards MultiMesh transforms; the GPU run checks roots.
	if DisplayServer.get_name() != "headless":
		var stalks: MultiMesh = game.get_node("Crops").multimesh
		var grounded := true
		for index in range(0, stalks.instance_count, 37):
			var base: Vector3 = stalks.get_instance_transform(index).origin
			grounded = grounded and absf(base.y - game.terrain.height_at(Vector2(base.x, base.z))) < 0.001
		check(grounded, "Crop roots follow individual hillside positions rather than the cell centre")
	for focus in [Vector3(-18, 0, -18), Vector3(18, 0, 18), Vector3(-18, 0, 18), Vector3(18, 0, -18)]:
		for zoom in [2.0, 8.0, 40.0]:
			for turn in 8:
				game._camera.rotation.y = turn * PI / 4.0
				game._zoom = zoom
				game._place_camera(focus)
				var eye: Vector3 = game._camera.position
				check(eye.y > game.terrain.height_at(Vector2(eye.x, eye.z)) + 0.3, "The camera remains above hills at pan limits, headings and zooms")
	game.human.position = game.human.home
	game._start_selection(water[0], false)
	game.work("Plow")
	check(game.human.queue.is_empty() and game.farm.plots.is_empty(), "A water selection cannot queue farming or create a plot")
	check("Water" in game._farm_hud._plot_label.text and "Water" in game._farm_hud._detail_label.text, "A selected water plot identifies why it cannot be farmed")
	game._farm_hud.open_action_menu()
	check(game._farm_hud.action_wheel.entries.is_empty(), "Water offers no farm work in the action wheel")
	game._farm_hud.action_wheel.hide()
	game._start_selection(hill, false)
	game.work("Plow")
	check(game.human.queue.size() == 1, "The player can queue work on an elevated dry plot")
	game._zoom = 6.0
	var camp: Vector3 = game._surface_point(game.terrain.camp)
	game._place_camera(camp)
	check(game._camp_at(game._camera.unproject_position(camp)), "The camp remains clickable on its compact dry clearing")
	var camp_view = load("res://game.tscn").instantiate()
	camp_view.terrain_seed = 5
	root.add_child(camp_view)
	await process_frame
	await process_frame
	camp_view.set_speed(0)
	camp_view._zoom = 2.0
	for focus in [Vector3(-18, 0, -2), Vector3(-16, 0, 2), Vector3(-15, 0, -2)]:
		for turn in 16:
			camp_view._camera.rotation.y = turn * PI / 8.0
			camp_view._place_camera(focus)
			var eye: Vector3 = camp_view._camera.position
			check(eye.y > camp_view.terrain.height_at(Vector2(eye.x, eye.z)) + 0.3, "Close zoom stays above the steep camp clearing edge at %s, heading %d" % [focus, turn])
	camp_view.free()
	game.free()
	await create_timer(0.2).timeout
	if failures.is_empty():
		print("PASS: playable hills/ponds, shared terrain, elevated/shore picking, farmer/crop grounding, camera clearance, water refusal and hill orders")
	quit(0 if failures.is_empty() else 1)
