extends SceneTree

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var hud = load("res://farm_hud.gd").new()
	root.add_child(hud)
	root.add_child(hud.action_wheel)
	await process_frame
	var cell := Vector2i(8, 8)
	var other := Vector2i(9, 8)
	for action in ["Plow", "Chop"]:
		var farm := Farm.new()
		farm.heating_enabled = false
		if action == "Chop":
			farm.woodland[cell] = 6.0
			farm.woodland[other] = 6.0
		var person := Human.new()
		person.home = Human.plot_centre(cell)
		person.position = person.home
		person.order(farm, [cell, other], 0, action)
		check(person.advance(farm, 0, 6, 1), "%s progress requests a live field-panel refresh" % action)
		var remaining := 2.0 if action == "Plow" else 5.0
		person.cancel(farm)
		person.cancel(farm)
		hud.show_farm(farm, [cell], 0, "Barley")
		var detail: String = hud._plot_label.text + " · " + hud._detail_label.text
		check(detail.contains("33%" if action == "Plow" else "16%") and detail.contains("h left"), "%s remains visible after clearing jobs: %s" % [action, detail])
		person.order(farm, [other, cell], 0, action)
		check(is_equal_approx(person.queue[0].remaining, 3.0 if action == "Plow" else 6.0), "An unstarted %s plot keeps its full duration" % action)
		check(is_equal_approx(person.queue[1].remaining, remaining), "Reordering %s keeps only the work left on that plot" % action)
		person.cancel(farm)
		var copy := farm.copy_state()
		var worker := Human.new()
		worker.home = Human.plot_centre(cell)
		worker.position = worker.home
		worker.order(copy, [cell], 0, action)
		worker.advance(copy, 0, 7, remaining - 0.1)
		check(copy.stage(cell) == "Grass" and copy.wood_piles.is_empty(), "%s produces no output before the remaining work is done" % action)
		worker.advance(copy, 0, 7 + remaining - 0.1, 0.1)
		check(copy.stage(cell) == "Plowed" if action == "Plow" else not copy.woodland.has(cell) and copy.ground_wood() == 240000, "Resumed %s completes after only the remaining hours" % action)
		hud.show_farm(farm, [cell], 0, "Barley")
		check(hud._plot_label.text + " · " + hud._detail_label.text == detail, "Completing %s in a forecast copy cannot change live progress" % action)
		hud.show_farm(copy, [cell], 0, "Barley")
		check(not hud._detail_label.text.contains("h left"), "Completed %s no longer displays unfinished work" % action)
		if action == "Plow":
			copy.act(cell, 0, "Barley")
			copy.plots[cell].stage = "Withered"
			worker.order(copy, [cell], 0, "Plow")
			check(not worker.queue.is_empty() and is_equal_approx(worker.queue[0].remaining, 3.0), "A later plowing starts fresh after the earlier plowing completed")
			farm.regrowth[cell] = 0
			farm.grow({"condition": "Clear", "temperature": 15}, 672)
			farm.act(cell, 672)
			person.order(farm, [cell], 672, "Haul wood")
			person.advance(farm, 672, 6, 0.5)
			person.order(farm, [cell], 672, "Plow")
			check(not person.queue.is_empty() and is_equal_approx(person.queue[0].remaining, 3.0), "Regrown woodland discards earlier partial plowing when the land is cleared again")
	hud.action_wheel.free()
	hud.free()
	await process_frame
	if failures.is_empty():
		print("PASS: interrupted plowing/chopping progress, per-plot resume, live HUD refresh, completion and isolated forecasts")
	quit(0 if failures.is_empty() else 1)
