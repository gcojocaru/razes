extends SceneTree
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func _initialize() -> void:
	var farm = Farm.new()
	if not farm.has_method("generate_woodland"):
		check(false, "New games generate seeded usable woodland")
		quit(1)
		return
	for preset in load("res://terrain.gd").PRESETS.values():
		for seed in range(6):
			farm = Farm.new()
			farm.terrain = load("res://terrain.gd").new(seed, preset)
			farm.generate_woodland(seed)
			var again = Farm.new()
			again.terrain = farm.terrain
			again.generate_woodland(seed)
			var clear := 0
			for x in 16:
				for y in 16:
					var cell := Vector2i(x, y)
					if farm.terrain.cell_reason(cell) == "" and not farm.woodland.has(cell): clear += 1
			check(clear >= 16 and farm.woodland.size() > 8 and farm.woodland == again.woodland, "Seeded grove leaves clear usable land reproducibly")
			for cell in farm.woodland:
				check(farm.terrain.cell_reason(cell) == "", "Trees stay on usable ground")
	farm = Farm.new()
	farm.heating_enabled = false
	var cell := Vector2i(8, 8)
	farm.woodland[cell] = 6.0
	var before: Dictionary = farm.woodland.duplicate(true)
	var preview: Dictionary = farm.preview([cell], 0, "Chop")
	check(preview.plots == 1 and preview.wood == 240000 and farm.woodland == before and farm.wood_piles.is_empty(), "Chop preview reports ground yield without changing live woodland")
	var other := Vector2i(9,8)
	farm.wood_piles[other]=15000
	check(farm.preview([cell,other],0).wood==255000, "A mixed clearing/hauling preview counts both wood amounts")
	farm.wood_piles.erase(other)
	var person = Human.new()
	person.home = Human.plot_centre(cell)
	person.position = person.home
	check(person.order(farm, [cell, cell], 0, "Chop") == 1, "Duplicate chopping orders are refused")
	person.advance(farm, 0, 6, 1)
	person.cancel(farm)
	check(is_equal_approx(farm.woodland[cell], 5.0), "Cancelling preserves one hour of chopping")
	person.order(farm, [cell], 0, "Chop")
	person.advance(farm, 0, 7, 5.3)
	check(not farm.woodland.has(cell) and farm.wood == 288000 and farm.wood_piles.is_empty(), "All 240kg is hauled in capacity-limited trips, deposited exactly once: %s / %s / %s" % [farm.wood, person.carried, farm.wood_piles])
	farm.woodland[cell] = 6.0
	person.fatigue = 0
	person.position = Human.plot_centre(Vector2i(9, 8))
	person.order(farm, [cell], 0, "Chop")
	person.advance(farm, 0, 12.1, 6.01)
	person.cancel(farm)
	var accounted: int = farm.wood + person.carried + int(farm.wood_piles.get(cell, 0))
	check(accounted == 528000 and person.carried <= 15000, "Cancelling a haul loses and duplicates no wood: %s" % accounted)
	farm = Farm.new();farm.heating_enabled=false;farm.woodland[cell]=6.0
	person=Human.new();person.position=Human.plot_centre(cell)
	person.order(farm,[cell],0,"Chop")
	person.advance(farm,0,6,6.011)
	check(person.carried==15000 and farm.wood==48000 and farm.wood_piles[cell]==225000, "Wood leaves the ground in one 15kg load and is unavailable while walking home")
	person.cancel(farm);person.advance(farm,0,12.011,0.1)
	check(person.carried==0 and farm.wood==63000 and farm.wood_piles[cell]==225000, "Cancelled hauling deposits only the carried load and leaves the rest at the plot")
	person.order(farm,[cell],0,"Haul wood");person.advance(farm,0,12.111,2.0)
	check(farm.wood==288000 and farm.wood_piles.is_empty() and person.carried==0, "Resumed hauling makes all remaining trips without inventing or losing wood")
	farm = Farm.new()
	farm.wood_piles[cell] = 15000
	check(farm.action(cell, 0).name == "Haul wood" and farm.preview([cell], 0, "Plow").plots == 0, "Ground piles block cultivation and offer hauling")
	farm.wood_piles.clear()
	farm.regrowth[cell] = 0
	for day in range(1, 673): farm.grow({"condition":"Clear", "temperature":15}, day)
	check(farm.woodland.has(cell), "Unused cleared grass regrows over two 336-day years")
	farm.woodland.clear()
	farm.regrowth[cell] = 0
	farm.act(cell, 0)
	for day in range(1, 674): farm.grow({"condition":"Clear", "temperature":15}, day)
	check(not farm.woodland.has(cell), "Cultivated plots do not regrow woodland")
	if failures.is_empty(): print("PASS: woodland generation, previews, chop progress, hauling conservation, piles and regrowth")
	quit(0 if failures.is_empty() else 1)
