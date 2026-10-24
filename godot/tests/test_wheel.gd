extends SceneTree
## Contextual menu rules, live availability, keyboard input and viewport fit.

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

func click_at(at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = at
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func run() -> void:
	var script = load("res://action_wheel.gd")
	if script == null:
		check(false, "The contextual wheel exists")
		quit(1)
		return
	var wheel = script.new()
	root.add_child(wheel)
	for icon in ["Plow", "Harvest"] + Farm.CROPS.keys():
		var texture = wheel.ICONS[icon]
		check(texture is Texture2D and texture.get_size() == Vector2(64, 64), icon + " has a scalable, consistently sized icon")
	var activations: Array = []
	wheel.activated.connect(func(action: String, crop: String) -> void: activations.append([action, crop]))
	var farm := Farm.new()
	var cell := Vector2i.ZERO
	wheel.show_farm(farm, [cell], 0, "Barley")
	check(wheel.entries.size() == 1 and wheel.entries[0].action == "Plow", "Grass offers Plow, not crop choices")
	wheel.open_at(Vector2(400, 350))
	await process_frame
	check(wheel.hub_detail.get_rect().end.y <= wheel._origin.y + wheel.HUB, "Hub labels fit on the very first opening")
	wheel.hide()
	farm.act(cell, 0)
	wheel.show_farm(farm, [cell], 0, "Barley")
	check(wheel.entries.map(func(e: Dictionary): return e.crop) == ["Barley", "Oats"], "Plowed land offers only crops sowable now")
	check(wheel.entries[0].plots == 1 and wheel.entries[0].grain == -Farm.CROPS.Barley.seed, "Sowing describes its actual seed cost")
	wheel.open_at(Vector2.ZERO)
	check(wheel.wheel_rect().position.x >= 0 and wheel.wheel_rect().position.y >= 0, "The wheel fits at the top-left edge")
	wheel.open_at(root.get_visible_rect().size)
	check(root.get_visible_rect().encloses(wheel.wheel_rect()), "The wheel fits at the bottom-right edge")
	check(wheel._hint.get_rect().position.y >= wheel.wheel_rect().end.y, "The hint does not overlap the wheel at the bottom edge")
	key(KEY_RIGHT)
	key(KEY_ENTER)
	check(not wheel.visible, "Keyboard activation dismisses the wheel")
	check(activations == [["Sow", "Oats"]], "Arrows and Enter activate the focused crop")
	wheel.open_at(Vector2(400, 350))
	farm.stock.Barley = 0
	farm.stock.Oats = 0
	await click_at(wheel._origin + Vector2(0, -132))
	check(activations.size() == 1 and wheel.visible and wheel.entries.is_empty(), "A mouse activation rechecks seed stock before emitting work")
	await click_at(Vector2(5, 5))
	check(not wheel.visible, "An outside mouse click dismisses the wheel")
	wheel.show_farm(farm, [cell], 0, "Barley")
	check(wheel.entries.is_empty() and "seed" in wheel.hub_detail.text.to_lower(), "No seed gives an explanation, not an unusable action")
	wheel.show_farm(farm, [cell], Calendar.DAYS_PER_SEASON * 3, "")
	check(wheel.entries.is_empty() and "sowing" in wheel.hub_detail.text.to_lower(), "Winter plowed land explains the next sowing window")
	farm.stock.Barley = Farm.STARTING_STOCK.Barley
	farm.act(cell, 0, "Barley")
	wheel.show_farm(farm, [cell], 0, "Barley")
	check(wheel.entries.is_empty() and "ripe" in wheel.hub_detail.text.to_lower(), "Growing crops show their status without Harvest")
	farm.plots[cell].stage = "Ripe"
	var plowed := Vector2i(1, 0)
	farm.act(plowed, 0)
	wheel.show_farm(farm, [cell, plowed, Vector2i(2, 0)], 0, "Barley")
	check(wheel.entries.map(func(e: Dictionary): return e.action) == ["Plow", "Sow", "Harvest"], "Mixed selection offers all applicable actions with seed available")
	check(wheel.entries[-1].grain == Farm.CROPS.Barley.grain, "Harvest displays the correct yield")
	wheel.open_at(Vector2(400, 350))
	wheel.show_farm(farm, [Vector2i(2, 0)], Calendar.DAYS_PER_SEASON * 3, "")
	check(wheel.visible and wheel.entries.is_empty() and "frozen" in wheel.hub_detail.text.to_lower(), "An open wheel refreshes when its action becomes unavailable")
	key(KEY_ESCAPE)
	check(not wheel.visible, "Escape dismisses a status-only wheel")
	wheel.show_farm(farm, [], 0, "Barley")
	check(wheel.entries.is_empty(), "An empty selection offers no work")
	for stage in ["Stubble", "Withered"]:
		farm.plots[cell].stage = stage
		wheel.show_farm(farm, [cell], 0, "Barley")
		check(wheel.entries.size() == 1 and wheel.entries[0].action == "Plow", stage + " offers Plow")
	wheel.show_farm(farm, [plowed], Calendar.DAYS_PER_SEASON * 2, "Wheat")
	check(wheel.entries.map(func(e: Dictionary): return e.crop) == ["Wheat", "Rye"], "Autumn offers the two winter crops")
	var growing := Vector2i(4, 0)
	farm.plots[growing] = farm.plots[cell].duplicate()
	farm.plots[growing].stage = "Sown"
	farm.plots[growing].crop = "Barley"
	wheel.show_farm(farm, [cell, plowed, growing], Calendar.DAYS_PER_SEASON * 3, "")
	wheel.open_at(Vector2(400, 350))
	await process_frame
	check(wheel.hub_detail.get_rect().end.y <= wheel._origin.y + wheel.HUB, "Several unavailable reasons stay within the hub")
	wheel.queue_free()
	await process_frame
	if failures.is_empty():
		print("PASS: contextual wheel states, seed costs, mixed selection, live refresh, keyboard and viewport fit")
	quit(0 if failures.is_empty() else 1)
