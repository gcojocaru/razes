extends SceneTree
## Seeded playable hills and ponds share their surface with rendering and routes.

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

## Plots counted by reason ("" is usable), and whether camp has a route to every usable plot.
func survey(terrain) -> Dictionary:
	var plots := {"": 0, "Water": 0, "Too steep": 0, "Unreachable": 0, "Camp": 0, "routed": true}
	for x in 16:
		for z in 16:
			var reason: String = terrain.cell_reason(Vector2i(x, z))
			plots[reason] += 1
			if reason == "":
				plots.routed = plots.routed and not terrain.path(terrain.CAMP, Vector2(x - 7.5, z - 7.5) * 2.0).is_empty()
	return plots

func dry_route(terrain, route: PackedVector2Array) -> bool:
	if route.is_empty():
		return false
	for index in range(1, route.size()):
		var steps := maxi(1, ceili(route[index - 1].distance_to(route[index]) / 0.1))
		for step in steps + 1:
			var point := route[index - 1].lerp(route[index], float(step) / steps)
			if not terrain._walkable(point):
				return false
			for offset in [Vector2.ZERO, Vector2(0.25, 0), Vector2(-0.25, 0), Vector2(0, 0.25), Vector2(0, -0.25)]:
				if terrain.height_at(point + offset) <= terrain.WATER_LEVEL:
					return false
	return true

func reconnectable_route(terrain, route: PackedVector2Array, checked: Dictionary) -> bool:
	for index in range(1, route.size()):
		var from := route[index - 1]
		var to := route[index]
		var edge := Vector4(from.x, from.y, to.x, to.y)
		if from.x > to.x or (from.x == to.x and from.y > to.y):
			edge = Vector4(to.x, to.y, from.x, from.y)
		if checked.has(edge):
			continue
		checked[edge] = true
		if terrain.path(from.lerp(to, 0.5), terrain.CAMP).is_empty():
			return false
	return not route.is_empty()

func run() -> void:
	var Terrain = load("res://terrain.gd")
	var first = Terrain.new(37)
	var repeat = Terrain.new(37)
	var other = Terrain.new(38)
	var edge_case = Terrain.new(0)
	check(dry_route(edge_case, edge_case.path(edge_case.CAMP, Vector2(-15, -15))), "Routes validate the walkability between graph vertices")
	check(reconnectable_route(edge_case, edge_case.path(Vector2(11, -15), edge_case.CAMP), {}), "A farmer between waypoints can request a return to camp")
	if not failures.is_empty():
		quit(1)
		return
	var different := false
	for x in range(-60, 61, 6):
		for z in range(-60, 61, 6):
			var point := Vector2(x + 0.23, z + 0.71)
			check(first.height_at(point) == repeat.height_at(point), "The same seed repeats every sampled height")
			different = different or not is_equal_approx(first.height_at(point), other.height_at(point))
	check(different and first.ponds == repeat.ponds, "Seeds repeat their ponds and vary the landscape")
	for terrain_seed in 30:
		var terrain = Terrain.new(terrain_seed)
		check(terrain.hills == 18.0 and terrain.ponds.size() == 2, "Seed %d makes the Hills preset's land by default" % terrain_seed)
		for pond in terrain.ponds:
			check(absf(pond.center.x) < 11.0 and absf(pond.center.y) < 11.0 and terrain.height_at(pond.center) < terrain.WATER_LEVEL, "Seed %d keeps real pond basins inside the playing field" % terrain_seed)
		check(terrain.height_at(terrain.CAMP) > terrain.WATER_LEVEL, "Seed %d leaves the default camp dry" % terrain_seed)
		var farmable := 0
		var water := 0
		var low := INF
		var high := -INF
		var hill_farming := false
		var all_reachable := true
		var safe := true
		var reconnectable := true
		var checked_edges := {}
		for x in 16:
			for z in 16:
				var cell := Vector2i(x, z)
				var point := Vector2(x - 7.5, z - 7.5) * 2.0
				var reason: String = terrain.cell_reason(cell)
				if reason == "Water":
					water += 1
				if not reason.is_empty():
					continue
				farmable += 1
				var height: float = terrain.height_at(point)
				low = minf(low, height)
				high = maxf(high, height)
				hill_farming = hill_farming or absf(terrain.height_at(point + Vector2.ONE) - terrain.height_at(point - Vector2.ONE)) > 0.12
				var route: PackedVector2Array = terrain.path(terrain.CAMP, point)
				all_reachable = all_reachable and not route.is_empty() and route[0] == terrain.CAMP and route[-1] == point
				safe = safe and dry_route(terrain, route)
				reconnectable = reconnectable and reconnectable_route(terrain, route, checked_edges)
				var home_route: PackedVector2Array = terrain.path(point, terrain.CAMP)
				safe = safe and dry_route(terrain, home_route)
				reconnectable = reconnectable and reconnectable_route(terrain, home_route, checked_edges)
		check(farmable >= 90 and water >= 8, "Seed %d leaves substantial usable farmland and several water plots (%d dry, %d water)" % [terrain_seed, farmable, water])
		check(high - low > 1.0 and hill_farming, "Seed %d has visible playable hills that can be farmed" % terrain_seed)
		check(all_reachable and safe, "Seed %d connects every farmable plot to camp without crossing or clipping water" % terrain_seed)
		check(reconnectable, "Seed %d permits a return home from every outward and homeward route midpoint" % terrain_seed)
		var first_pond: Dictionary = terrain.ponds[0]
		check(terrain.path(terrain.CAMP, first_pond.center).is_empty(), "Water destinations cannot be walked to")
		var across := Vector2(first_pond.radii.x + 4.0, 0)
		var detour: PackedVector2Array = terrain.path(first_pond.center - across, first_pond.center + across)
		check(detour.size() > 2 and dry_route(terrain, detour), "Seed %d walks across a pond on a dry detour with no corner cutting (%s)" % [terrain_seed, detour])
		if not detour.is_empty():
			var between := detour[0].lerp(detour[1], 0.37)
			var resumed: PackedVector2Array = terrain.path(between, terrain.CAMP)
			check(not resumed.is_empty() and resumed[0] == between and resumed[-1] == terrain.CAMP and dry_route(terrain, resumed), "A route can start between navigation points")
		check(terrain.path(terrain.CAMP, terrain.CAMP) == PackedVector2Array([terrain.CAMP]), "A stationary route keeps its exact endpoint")
	# Seed 48's camp stands on high ground; a clearing dug down to zero walled it off from every plot.
	var hilltop = Terrain.new(48)
	check(hilltop.height_at(hilltop.CAMP) > 1.7 and survey(hilltop).Unreachable == 0, "A camp on high ground reaches the whole field")
	var custom := {"Flat": {"hills": 0.0, "ponds": 0}, "Highest": {"hills": Terrain.MAX_HILLS, "ponds": 4}}
	for terrain_seed in 10:
		var usable := {}
		for land in ["Steppe", "Hills", "Lakeland", "Flat", "Highest"]:
			var chosen: Dictionary = Terrain.PRESETS.get(land, custom.get(land))
			var terrain = Terrain.new(terrain_seed, chosen)
			var plots := survey(terrain)
			usable[land] = plots[""]
			check(terrain.hills == chosen.hills and terrain.ponds.size() == chosen.ponds, "Seed %d makes %s land" % [terrain_seed, land])
			check(plots.Unreachable == 0 and plots.routed and plots[""] >= {"Steppe": 220, "Hills": 170, "Lakeland": 130, "Flat": 256, "Highest": 70}[land], "Seed %d %s land leaves its farmland reachable (%s)" % [terrain_seed, land, plots])
		check(usable.Steppe > usable.Hills and usable.Hills > usable.Lakeland, "Seed %d: Steppe has the most farmland and Lakeland the least (%s)" % [terrain_seed, usable])
	var mesh: ArrayMesh = first.create_mesh()
	check(mesh.get_surface_count() == 1, "Terrain forms one continuous surface")
	var bounds := mesh.get_aabb()
	check(is_equal_approx(bounds.position.x, -128.0) and is_equal_approx(bounds.position.z, -128.0) and is_equal_approx(bounds.size.x, 256.0) and is_equal_approx(bounds.size.z, 256.0), "The landscape covers the full surrounding area")
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	check(vertices.size() == 257 * 257 and normals.size() == vertices.size(), "The surface has one-unit geometry and slope normals")
	var aligned := true
	for index in vertices.size():
		var vertex := vertices[index]
		aligned = aligned and is_equal_approx(vertex.y, first.height_at(Vector2(vertex.x, vertex.z))) and normals[index].y > 0.0
	for index in range(0, indices.size(), 153):
		var a := vertices[indices[index]]
		var b := vertices[indices[index + 1]]
		var c := vertices[indices[index + 2]]
		var point := a * 0.17 + b * 0.31 + c * 0.52
		aligned = aligned and absf(first.height_at(Vector2(point.x, point.z)) - point.y) < 0.00002
	check(aligned, "The sampler matches both rendered triangle interiors and vertices")
	var picked := true
	for x in range(-16, 17, 2):
		for z in range(-16, 17, 2):
			var point := Vector2(x + 0.23, z + 0.61)
			var height: float = maxf(first.WATER_LEVEL, first.height_at(point))
			var expected := Vector3(point.x, height, point.y)
			for offset in [Vector3(0, 20, 0), Vector3(8, 24, 6), Vector3(-9, 24, 3)]:
				var hit = first.ray_hit(expected + offset, -offset.normalized())
				picked = picked and hit != null and hit.distance_to(expected) < 0.001
	check(picked, "Vertical and oblique rays pick the visible terrain or water surface accurately")
	var vertex_picking := true
	for point in [Vector2(-15, -15), Vector2(-9, -9), Vector2(1, 1), Vector2(15, 15)]:
		var target := Vector3(point.x, maxf(first.WATER_LEVEL, first.height_at(point)), point.y)
		for turn in 8:
			var direction := Vector3(0.4, -0.819, 0.4).rotated(Vector3.UP, turn * PI / 4.0).normalized()
			var hit = first.ray_hit(target - direction * 8.0, direction)
			vertex_picking = vertex_picking and hit != null and hit.distance_to(target) < 0.001
	check(vertex_picking, "Rotated oblique rays pick lattice vertices and edges without precision misses")
	check(first.ray_hit(Vector3(0, 20, 0), Vector3.UP) == null and first.ray_hit(Vector3(0, 20, 0), Vector3.ZERO) == null, "Rays pointing away or with no direction miss")
	check(first.path(first.CAMP, Vector2(-30, 0)).is_empty(), "Walking stays inside the playable navigation area")
	var moved = Terrain.new(3, {"hills": 0.0, "ponds": 0})
	check(not moved.set_camp(Vector2(-30, 0)) and moved.camp == moved.CAMP, "A camp cannot move off the playable area")
	check(moved.set_camp(Vector2(10.4, 9.6)) and moved.camp == Vector2(10, 10) and survey(moved).Unreachable == 0, "A moved camp snaps to the lattice and reaches the flat field")
	check(moved.set_camp(Vector2(11, 11)) and moved.cell_reason(Vector2i(13, 13)) == "Camp" and moved.cell_reason(Vector2i(12, 12)) == "" and survey(moved).Camp == 1, "Only the plot under the camp is closed to farming")
	if failures.is_empty():
		print("PASS: 30 seeded landscapes, in-field ponds and farmable hills, camps on high ground, camp moves, three presets and custom extremes, validated walking edges and route resumption, exact rendered heights and terrain/water picking")
	quit(0 if failures.is_empty() else 1)
