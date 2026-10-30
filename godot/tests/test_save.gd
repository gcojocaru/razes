extends SceneTree

const SaveGame := preload("res://save_game.gd")
const Terrain := preload("res://terrain.gd")
const DIR := "/tmp/stefan-save"

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func field(seed_value: int) -> Node:
	var game = load("res://game.tscn").instantiate()
	game.terrain_seed = seed_value
	root.add_child(game)
	game.set_speed(0)
	return game

## Names every saved field whose value differs between the two games.
func differences(a: Node, b: Node) -> Array:
	var different := []
	for property in Farm.SAVED:
		if var_to_str(a.farm.get(property)) != var_to_str(b.farm.get(property)): different.append("farm." + property)
	for property in Human.SAVED:
		if var_to_str(a.human.get(property)) != var_to_str(b.human.get(property)): different.append("human." + property)
	for property in SaveGame.EXPOSURE + ["day", "_day_time", "snow_cover", "weather_seed", "terrain_seed"]:
		var owner: Object = a.human.exposure if property in SaveGame.EXPOSURE else a
		var other: Object = b.human.exposure if property in SaveGame.EXPOSURE else b
		if var_to_str(owner.get(property)) != var_to_str(other.get(property)): different.append(property)
	return different

func advance(game: Node, hours: float) -> void:
	for step in int(hours):
		game.advance_time(game.seconds_per_day / 24.0)

func run() -> void:
	check(SaveGame.path == "", "Test runs never default to the player's save slot")
	DirAccess.make_dir_recursive_absolute(DIR)
	SaveGame.path = DIR + "/save.dat"
	for leftover in ["", ".bad", ".tmp"]:
		DirAccess.remove_absolute(SaveGame.path + leftover)
	check(SaveGame.read().is_empty(), "No save reads as nothing")

	Human.peasant = {"name": "Toader", "height": 1.8, "weight": 72.0, "body_fat": 0.25, "skin": "Olive", "hair_colour": "Black"}
	Terrain.land = Terrain.PRESETS.Lakeland.duplicate()
	var original := field(40)
	await process_frame
	var ordered := 0
	for x in 16:
		for y in 16:
			if ordered < 3 and original.human.order(original.farm, [Vector2i(x, y)], original.day, "Plow") > 0:
				ordered += 1
	var chopped: int = original.human.order(original.farm, [original.farm.woodland.keys()[0]], original.day, "Chop")
	check(ordered == 3 and chopped == 1, "The farmer takes plowing and chopping orders")
	check(original.human.eat(original.farm, "Barley", 300), "A meal is reserved")
	advance(original, 5)
	check(not original.human.queue.is_empty() or not original.human.job.is_empty(), "Work is still under way when saving")
	check(SaveGame.save(original) == OK and FileAccess.file_exists(SaveGame.path) and not FileAccess.file_exists(SaveGame.path + ".tmp"), "Saving writes the slot without leaving a temporary file")
	var data := SaveGame.read()
	check(not data.is_empty(), "A fresh save reads back")

	# Another peasant and land must not leak into the resumed game.
	Human.peasant = {}
	Terrain.land = Terrain.PRESETS.Hills.duplicate()
	# Loaded at run time: the game script needs autoloads that exist only once the tree runs.
	var game_script: GDScript = load("res://game.gd")
	game_script.continue_save = data
	var resumed := field(99)
	await process_frame
	check(game_script.continue_save.is_empty(), "Continue is used once, so Restart begins a fresh game")
	check(resumed.speed == 0, "A continued game starts paused")
	check(resumed.terrain.camp == original.terrain.camp and resumed.terrain_seed == original.terrain_seed and resumed.terrain.ponds.size() == 4, "The camp, terrain seed and land are restored")
	check(Human.peasant.get("name") == "Toader" and resumed.human.name == "Toader", "The peasant is restored for the scene and for Restart")
	var different := differences(original, resumed)
	check(different.is_empty(), "Every saved field matches after loading: %s" % [different])
	advance(original, 48)
	advance(resumed, 48)
	different = differences(original, resumed)
	check(different.is_empty(), "Both games stay identical for 48 game hours: %s" % [different])
	check(original.day >= 2, "The comparison crossed dawns")
	check(SaveGame.read().get("game", {}).get("day") == original.day, "Each dawn autosaves")

	for corruption in ["garbage", "truncated", "version", "type", "cell", "skin", "ponds", "time"]:
		var bad := data.duplicate(true)
		match corruption:
			"version": bad.version = SaveGame.VERSION + 1
			"type": bad.farm.wood = "lots"
			"cell": bad.farm.plots[Vector2i(99, 0)] = {}
			"skin": bad.peasant.skin = "Blue"
			"ponds": bad.land.ponds = 9
			"time": bad.game._day_time = bad.game.seconds_per_day
		var file := FileAccess.open(SaveGame.path, FileAccess.WRITE)
		if corruption == "garbage":
			file.store_string("not a save")
		elif corruption == "truncated":
			var bytes := var_to_bytes(data)
			file.store_32(bytes.size())
			file.store_buffer(bytes.slice(0, bytes.size() / 2))
		else:
			file.store_var(bad)
		file.close()
		check(SaveGame.read().is_empty() and not FileAccess.file_exists(SaveGame.path) and FileAccess.file_exists(SaveGame.path + ".bad"), "A %s save is rejected and kept aside as .bad" % corruption)
		DirAccess.remove_absolute(SaveGame.path + ".bad")

	# The menu offers Continue only for a readable save.
	change_scene_to_file("res://main.tscn")
	await process_frame
	await process_frame
	check(current_scene.get_node_or_null("Layout/Continue") == null and current_scene.get_node("Layout/Play").has_focus(), "Without a save the menu offers Play only")
	SaveGame.save(original)
	change_scene_to_file("res://main.tscn")
	await process_frame
	await process_frame
	var resume: Button = current_scene.get_node_or_null("Layout/Continue")
	var play: Button = current_scene.get_node("Layout/Play")
	check(resume != null and resume.has_focus() and resume.get_global_rect().end.y <= play.get_global_rect().position.y, "With a save, Continue sits above Play with focus")
	if resume != null:
		resume.pressed.emit()
		await process_frame
		await process_frame
		check(current_scene.has_method("advance_time") and current_scene.day == original.day and current_scene.speed == 0 and current_scene.human.name == "Toader", "Continue opens the saved day, paused")
		current_scene.human._die()
		current_scene._end_game()
		check(not FileAccess.file_exists(SaveGame.path), "Death deletes the save, so Continue never opens a dead peasant")

	original.free()
	resumed.free()
	await process_frame
	if failures.is_empty():
		print("PASS: save slot isolation, atomic write, full restore of farm, farmer, exposure, land, peasant and camp, 48-hour determinism after loading, dawn autosave, rejection of corrupt saves, menu Continue and deletion at death")
	quit(0 if failures.is_empty() else 1)
