extends SceneTree
## The creation screen's random buttons and the turn buttons, checked without the menu.

var failures := 0

func check(passed: bool, message: String) -> void:
	if not passed:
		failures += 1
		push_error("FAIL: " + message)

func _initialize() -> void:
	change_scene_to_file("res://main.tscn")
	await process_frame
	await process_frame
	var creation = current_scene.creation
	creation.open()
	var names: Array = creation.NAMES
	var seen := {}
	for i in 40:
		creation._random_name()
		seen[creation.name_edit.text] = true
		check(creation.name_edit.text in names and creation.peasant.name == creation.name_edit.text, "Random name is one of the list")
	check(seen.size() > 1, "Random name varies")
	for i in 20:
		creation._random_looks()
		for key in creation.looks:
			check(creation.peasant[key] in creation.looks[key].keys(), "Random %s is one of its options" % key)
	check(creation.looks.keys() == ["skin"] + creation.HumanActor.HAIR.keys() + ["hair_colour"] + creation.HumanActor.CLOTHES.keys(), "The looks offer a skin tone, hair, a beard, hair colour and each kind of clothes")
	var before: float = creation._turn
	creation.find_child("TurnRight", true, false).button_down.emit()
	creation._process(0.5)
	check(is_equal_approx(creation._turn - before, creation.TURN_SPEED * 0.5), "Holding the right turn button turns for as long as it is held")
	creation.find_child("TurnRight", true, false).button_up.emit()
	before = creation._turn
	creation._process(0.5)
	check(creation._turn == before, "Releasing the turn button stops the turn")
	creation.find_child("TurnLeft", true, false).button_down.emit()
	creation._process(0.25)
	check(is_equal_approx(creation._turn - before, -creation.TURN_SPEED * 0.25), "The left turn button turns left")
	creation.find_child("TurnLeft", true, false).button_up.emit()
	# Twice the layout's 1440 x 900, as a full-screen Retina window gives.
	root.size = Vector2i(2880, 1800)
	creation._process(0.0)
	check(creation._view.size == Vector2i((creation._frame.size * 2).ceil()), "In a window twice the layout's size, the preview renders at the pixels it covers instead of stretching")
	quit(1 if failures > 0 else 0)
