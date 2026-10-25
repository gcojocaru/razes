extends SceneTree
## Real terrain routes are shared by field work, carried grain and camp forecasts.

const DAY := 9
const SCALE := 0.2
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var farm = Farm.new()
	var person = Human.new()
	if not farm.get_property_list().any(func(property: Dictionary) -> bool: return property.name == "terrain") or not person.get_property_list().any(func(property: Dictionary) -> bool: return property.name == "terrain"):
		check(false, "Farm and Human accept the same optional playable terrain")
		quit(1)
		return
	var terrain = load("res://terrain.gd").new(37)
	farm.terrain = terrain
	person.terrain = terrain
	var wet := Vector2i(-1, -1)
	var hill := wet
	var detour := wet
	for x in 16:
		for y in 16:
			var cell := Vector2i(x, y)
			var point := Vector2(cell) * 2.0 - Vector2.ONE * 15.0
			if terrain.cell_reason(cell) == "Water" and terrain.height_at(point) < terrain.WATER_LEVEL:
				wet = cell
			elif terrain.cell_reason(cell) == "":
				if absf(terrain.height_at(point)) > 0.2:
					hill = cell
				for step in range(1, 100):
					if terrain.height_at((person.home * SCALE).lerp(point, step / 100.0)) < terrain.WATER_LEVEL:
						detour = cell
						break
	check(wet.x >= 0 and hill.x >= 0 and detour.x >= 0, "The real seeded field offers water, farmable hills and a route around a pond")
	if not failures.is_empty():
		quit(1)
		return
	var stock: Dictionary = farm.stock.duplicate()
	check(not farm.act(wet, DAY) and farm.preview([wet], DAY, "Plow").plots == 0 and person.order(farm, [wet], DAY, "Plow") == 0 and farm.stock == stock and farm.plots.is_empty(), "Water refuses direct work, previews and queued work without changing plots or stock")
	var stale_farm = Farm.new()
	stale_farm.act(wet, DAY)
	stale_farm.terrain = terrain
	check(stale_farm.preview([wet], DAY, "Sow", "Barley").plots == 0 and person.order(stale_farm, [wet], DAY, "Sow", "Barley") == 0 and stale_farm.stock == stock, "A submerged sowing plot cannot reserve or spend seed, including through previews")
	check(person.order(farm, [hill], DAY, "Plow") == 1, "A gentle hill accepts ordinary field work")
	person.advance(farm, DAY, 6, 3.2)
	check(farm.stage(hill) == "Plowed", "The farmer reaches and finishes work on a gentle hill")
	person.cancel(farm)
	person.advance(farm, DAY, 9.2, 0.2)
	test_pond_route(terrain, detour)
	test_sleep_route(terrain, detour)
	test_sleep_during_return()
	test_unreachable(terrain, wet)
	test_stale_route(terrain, wet)
	if failures.is_empty():
		print("PASS: farmable hills, water refusal and previews, routed work and seed return, sleep forecasts and subdivision, unreachable commands")
	quit(0 if failures.is_empty() else 1)

func test_pond_route(terrain, cell: Vector2i) -> void:
	var farm = Farm.new()
	farm.terrain = terrain
	farm.act(cell, DAY)
	var person = Human.new()
	person.terrain = terrain
	check(person.order(farm, [cell], DAY, "Sow", "Barley") == 1 and farm.stock.Barley == 8000, "A job beyond the pond reserves exactly its seed")
	var destination := Vector2(cell) * 10.0 - Vector2.ONE * 75.0
	var distance := 0.0
	var dry := true
	for step in 4000:
		var before: Vector2 = person.position
		person.advance(farm, DAY, 6 + step * 0.00005, 0.00005)
		distance += before.distance_to(person.position)
		dry = dry and terrain.height_at(person.position * SCALE) > terrain.WATER_LEVEL
		if person.position == destination:
			break
	check(person.position == destination and distance > person.home.distance_to(destination) + 1.0 and dry and person.carried == 2000, "Travel to work takes a longer dry route around the pond while carrying reserved seed")
	person.cancel(farm)
	check(farm.stock.Barley == 8000 and person.carried == 2000 and person.reserved_seed() == 0, "Cancelling away from camp keeps carried seed out of available stock")
	for step in 4000:
		person.advance(farm, DAY, 7 + step * 0.00005, 0.00005)
		dry = dry and terrain.height_at(person.position * SCALE) > terrain.WATER_LEVEL
		if person.position == person.home:
			break
	check(dry and person.position == person.home and farm.stock.Barley == 10000 and person.carried == 0, "Cancellation returns around the pond and refunds carried seed exactly once at camp")

func test_sleep_route(terrain, cell: Vector2i) -> void:
	var one = Human.new()
	var frames = Human.new()
	for person in [one, frames]:
		person.terrain = terrain
		person.position = Vector2(cell) * 10.0 - Vector2.ONE * 75.0
		person.fatigue = 80.0
	var preview: Dictionary = one.sleep_prediction(2.0)
	check(not preview.is_empty() and preview.hours > 2.0 + one.position.distance_to(one.home) / (Human.WALK_SPEED * 0.8), "The sleep forecast includes the longer walk around the pond")
	one.sleep(2.0)
	frames.sleep(2.0)
	one.advance(Farm.new(), DAY, 6, preview.hours)
	for step in 400:
		frames.advance(Farm.new(), DAY, 6 + step * preview.hours / 400.0, preview.hours / 400.0)
	check(one.position == one.home and one.sleep_remaining == 0 and is_equal_approx(one.fatigue, preview.fatigue) and is_equal_approx(one.glycogen, preview.glycogen) and is_equal_approx(one.mass(), preview.mass), "Actual routed travel and sleep match the needs and duration forecast")
	check(frames.position == one.position and is_equal_approx(frames.sleep_remaining, one.sleep_remaining) and is_equal_approx(frames.fatigue, one.fatigue) and is_equal_approx(frames.glycogen, one.glycogen) and is_equal_approx(frames.mass(), one.mass()), "Pond routes and sleeping preserve needs across frame subdivisions")

func test_unreachable(terrain, wet: Vector2i) -> void:
	var person = Human.new()
	person.terrain = terrain
	var wet_center := Vector2(wet) * 2.0 - Vector2.ONE * 15.0
	for x in range(-4, 5):
		for y in range(-4, 5):
			var point := wet_center + Vector2(x, y) * 0.25
			if terrain.height_at(point) < terrain.WATER_LEVEL:
				person.position = point / SCALE
	check(person.position != person.home, "The unreachable-camp fixture starts in an actual pond")
	var farm = Farm.new()
	farm.terrain = terrain
	var stock: Dictionary = farm.stock.duplicate()
	check(not person.sleep(2) and person.sleep_prediction(2).is_empty() and not person.eat(farm, "Barley", 300) and farm.stock == stock, "An unreachable camp refuses sleep and meals without hanging or reserving food")
	person.cancel(farm)
	person.advance(farm, DAY, 6, 0.1)
	check(is_equal_approx(person.advanced_hours, 0.1) and person.position != person.home, "An unreachable return consumes idle time without teleporting or stalling the simulation")
	var interrupted = Human.new()
	interrupted.terrain = terrain
	interrupted.eat(farm, "Barley", 300)
	interrupted.position = person.position
	interrupted.advance(farm, DAY, 6, 0.1)
	check(not interrupted.eating_requested and interrupted.meal_grams == 0 and farm.stock == stock and interrupted.position != interrupted.home, "A meal whose camp route became unavailable refunds its unprepared grain")

func test_sleep_during_return() -> void:
	var terrain = load("res://terrain.gd").new(0)
	var one = Human.new()
	var frames = Human.new()
	for person in [one, frames]:
		person.terrain = terrain
		person.position = Vector2(1, 9) * 10.0 - Vector2.ONE * 75.0
		person.cancel(Farm.new())
		person.advance(Farm.new(), DAY, 6, 0.0041)
	var preview: Dictionary = one.sleep_prediction(2.0)
	one.sleep(2.0)
	frames.sleep(2.0)
	one.advance(Farm.new(), DAY, 6, preview.hours)
	for step in 400:
		frames.advance(Farm.new(), DAY, 6 + step * preview.hours / 400.0, preview.hours / 400.0)
	check(one.position == one.home and one.sleep_remaining == 0 and is_equal_approx(one.fatigue, preview.fatigue) and is_equal_approx(one.glycogen, preview.glycogen) and is_equal_approx(one.mass(), preview.mass), "Sleep requested during a return home finishes at its forecast duration with the predicted needs")
	check(frames.position == one.position and is_equal_approx(frames.sleep_remaining, one.sleep_remaining) and is_equal_approx(frames.fatigue, one.fatigue) and is_equal_approx(frames.glycogen, one.glycogen) and is_equal_approx(frames.mass(), one.mass()), "An interrupted return route keeps the sleep duration and needs independent of frame subdivisions")

func test_stale_route(terrain, wet: Vector2i) -> void:
	var farm = Farm.new()
	farm.act(wet, DAY)
	var person = Human.new()
	person.order(farm, [wet], DAY, "Sow", "Barley")
	farm.terrain = terrain
	person.terrain = terrain
	person.advance(farm, DAY, 6, 0.1)
	check(person.queue.is_empty() and person.job.is_empty() and person.carried == 0 and farm.stock.Barley == 10000 and farm.stage(wet) == "Plowed", "An unreachable stale sowing job is dropped and all reserved and carried seed is refunded once")
