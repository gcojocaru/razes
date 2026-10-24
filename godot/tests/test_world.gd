extends SceneTree

var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if not ResourceLoader.exists("res://scripts/village_world.gd"):
		check(false, "VillageWorld must implement the coordinate and stable entity contract")
		quit(1)
		return
	var world_script = load("res://scripts/village_world.gd")
	if world_script == null or not world_script.can_instantiate():
		check(false, "VillageWorld must parse and instantiate")
		quit(1)
		return
	var rules = load("res://scripts/village_rules.gd")
	var world = world_script.new()
	var state: Dictionary = rules.new_game()
	world.set_state(state)
	root.add_child(world)
	await process_frame
	for width in [Vector2i.ONE, Vector2i(2, 2), Vector2i(3, 3), Vector2i(2, 1), Vector2i(1, 2)]:
		for tile in [Vector2i(-16, -16), Vector2i(-1, 0), Vector2i.ZERO, Vector2i(7, 9), Vector2i(31, 31)]:
			var point: Vector3 = world_script.grid_to_world(Vector2(tile), width)
			check(world_script.world_to_grid(point, width) == tile, "Every footprint round-trips across positive/negative coordinates")
	check(world_script.grid_to_world(Vector2.ZERO) == Vector3(-15, 0, -15), "Starter tile zero keeps the fixed origin")
	check(world_script.grid_to_world(Vector2(6, 6), Vector2i(3, 3)) == Vector3(-1, 0, -1), "House root is the native footprint centre")
	check(world_script.world_to_grid(Vector3(-16.01, 0, -15)) == Vector2i(-1, 0), "Ground edge selection uses floor, including negative tiles")
	var house = world.get_node("Entities/house")
	var worker = world.get_node("Entities/worker-ion")
	check(absf(worker.position.x - house.position.x) > 3.25 or absf(worker.position.z - house.position.z) > 3.25, "Resting Ion stands clear of the house geometry and raised veranda")
	var house_model = house.get_child(0)
	var surface_count: int = world.get_node("Surfaces").get_child_count()
	check(surface_count == state["layout"]["farmland"].size(), "Every farmland cell is rendered")
	var first_surface = world.get_node("Surfaces").get_child(0) if surface_count > 0 else null
	world.set_selection({"kind": "hotspot", "id": "house"})
	var changed := state.duplicate(true)
	changed["money"] = int(changed.get("money", 0)) + 1
	world.set_state(changed)
	check(world.get_node("Entities/house") == house, "HUD/resource updates retain house identity")
	check(house.get_child(0) == house_model, "HUD/resource updates retain actual model identity")
	check(world.get_node("Entities/worker-ion") == worker, "HUD/resource updates retain Ion identity")
	check(world.get_node("Surfaces").get_child_count() == surface_count and surface_count > 0 and world.get_node("Surfaces").get_child(0) == first_surface, "HUD/resource updates retain all surface roots")
	for turn in range(4):
		world.rotate_map(1)
		check(house.position == Vector3(-1, 0, -1), "Map rotations preserve world coordinates")
		for tile in [Vector2i(-16, 31), Vector2i(0, 0), Vector2i(12, 4)]:
			var point: Vector3 = world_script.grid_to_world(Vector2(tile))
			var screen: Vector2 = world.camera.unproject_position(point)
			var projected: Variant = world._ground_point(screen)
			check(projected != null and projected.distance_to(point) < 0.002, "Camera rays agree with ground coordinates in every rotation")
	world.zoom_camera(1000)
	check(world.camera.size <= 120, "Zoom out remains bounded across all parcels")
	world.zoom_camera(0.00001)
	check(world.camera.size >= 14, "Zoom in remains bounded")
	world._pan_target(Vector3(10000, 0, -10000))
	check(absf(world.camera_target.x) <= 48 and absf(world.camera_target.z) <= 48, "Panning stays inside the complete map")
	world.reset_camera()
	check(world.camera_target == Vector3.ZERO, "Home returns to the starting parcel")
	var before: Vector3 = house.position
	changed["layout"]["ownedParcels"].append({"x": 1, "y": 0})
	world.set_state(changed)
	check(house.position == before and world.get_node("Entities/house") == house, "Purchasing land never recentres/recreates existing structures")
	changed["buildings"].append({"id": "well", "level": 3, "condition": 72.0, "completedSeason": 0, "legacyAssignment": false, "debugPlaced": true})
	changed["layout"]["buildings"].append({"id": "well", "position": {"x": 12, "y": 0}, "facing": 0})
	for facing in range(4):
		changed["layout"]["buildings"][0]["facing"] = facing
		world.set_state(changed)
		world.set_tool("well", facing, true)
		world._preview_tile = Vector2i(12, 0)
		world._update_preview()
		var committed = world.get_node("Entities/building-well")
		check(world._preview.position == committed.position and world._preview.rotation == committed.rotation, "Ghost and actual building share transforms for every facing")
		check(world._model_bounds(world._preview.get_child(0)) == world._model_bounds(committed.get_child(0)), "Ghost preserves actual level, condition and model bounds")
	world.set_tool("scenery:barn", 1)
	world._preview_tile = Vector2i(12, 0)
	world._update_preview()
	check(world._preview.position == world_script.grid_to_world(Vector2(12, 0), rules.footprint("scenery:barn", 1)), "Ghost uses the committed footprint centre")
	check(is_equal_approx(world._preview.rotation.y, -PI / 2), "Ghost uses the committed facing")
	check(world._preview.find_children("*", "CollisionObject3D", true, false).is_empty(), "Ghost never intercepts selection rays")
	var picked: Array[Vector2i] = []
	world.parcel_selected.connect(func(parcel: Vector2i): picked.append(parcel))
	world.set_tool("")
	for tile in [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(16, 0), Vector2i(0, 16)]:
		# The east parcel was purchased earlier, so it should not emit locked land selection.
		world._select_at(world.camera.unproject_position(world_script.grid_to_world(Vector2(tile))))
	check(picked == [Vector2i(-1, 0), Vector2i(0, -1), Vector2i(0, 1)], "Ground hit testing floors negative parcel indices and respects current ownership")
	var old_count := picked.size()
	world._select_at(world.camera.unproject_position(world_script.grid_to_world(Vector2(-17, 0))))
	check(picked.size() == old_count, "Terrain outside the finite map cannot be selected for purchase")
	var attempts: Array = []
	world.placement_requested.connect(func(kind: String, tile: Vector2i, facing: int): attempts.append([kind, tile, facing]))
	world.set_tool("fence", 3)
	var screen: Vector2 = world.camera.unproject_position(world_script.grid_to_world(Vector2(1, 1)))
	world._place_at(screen)
	world._place_at(screen)
	check(attempts.size() == 1 and attempts[0] == ["fence", Vector2i(1, 1), 3], "Painting deduplicates cells and emits the current facing")
	world.set_selection({"kind": "hotspot", "id": "house"})
	world.set_selection({"kind": "hotspot", "id": "field"})
	check(world.get_node("Selection").position == Vector3.ZERO, "Field highlights do not inherit the previous building offset")
	await physics_frame
	world._select_at(world.camera.unproject_position(house.position + Vector3(0, 2.2, 0)))
	check(world._selection == {"kind": "hotspot", "id": "house"}, "A camera ray selects the actual house collider")
	world._select_at(world.camera.unproject_position(worker.position + Vector3(0, 1.2, 0)))
	check(world._selection == {"kind": "worker", "id": "ion"}, "A camera ray can select Ion without the house blocking him")
	world.free()
	print("World: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
