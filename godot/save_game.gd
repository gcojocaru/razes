extends RefCounted
## One autosave slot. Terrain and weather rebuild from their seeds, so a save holds
## only seeds and the plain fields of the game, farm, farmer and exposure. Older
## schemas are rejected, not migrated: the game is unreleased.

const VERSION := 1
const Terrain := preload("res://terrain.gd")
const Exposure := preload("res://exposure.gd")
const Actor := preload("res://human_actor.gd")
const GAME := {"day": TYPE_INT, "_day_time": TYPE_FLOAT, "seconds_per_day": TYPE_FLOAT, "terrain_seed": TYPE_INT, "weather_seed": TYPE_INT, "_seed_choice": TYPE_STRING}
const EXPOSURE := ["wetness", "core", "health"]
const CELLS := ["plots", "woodland", "wood_piles", "regrowth", "plowing"]

## Test runs use their own SceneTree script and must never touch the player's save.
static var path := "user://save.dat" if Engine.get_main_loop() != null and Engine.get_main_loop().get_script() == null else ""

static func save(game: Node) -> Error:
	if path == "":
		return ERR_UNAVAILABLE
	var data := {"version": VERSION, "land": Terrain.land, "peasant": Human.peasant, "camp": game.terrain.camp, "game": {}, "farm": {}, "human": {}, "exposure": {}}
	for property in GAME: data.game[property] = game.get(property)
	for property in Farm.SAVED: data.farm[property] = game.farm.get(property)
	for property in Human.SAVED: data.human[property] = game.human.get(property)
	for property in EXPOSURE: data.exposure[property] = game.human.exposure.get(property)
	# Write beside the slot and rename over it, so a failed write keeps the last good save.
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		push_warning("Could not save the game: " + error_string(FileAccess.get_open_error()))
		return FileAccess.get_open_error()
	file.store_var(data)
	var error := file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(temporary, path)
	if error != OK:
		push_warning("Could not save the game: " + error_string(error))
	return error

## The saved game, or {} when there is none. An unreadable save is kept as `.bad`.
static func read() -> Dictionary:
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	var data: Variant = file.get_var() if file != null else null
	if file != null:
		file.close()
	if data is Dictionary and _valid(data):
		return data
	push_warning("The saved game could not be read; kept as " + path + ".bad")
	DirAccess.rename_absolute(path, path + ".bad")
	return {}

static func delete() -> void:
	if path != "" and FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)

## Copies a read save into a game whose terrain and scene are already built.
static func apply(data: Dictionary, game: Node) -> void:
	for property in Farm.SAVED: game.farm.set(property, data.farm[property])
	for property in Human.SAVED:
		# Typed arrays must be assigned, not replaced, to keep their element type.
		if property == "queue": game.human.queue.assign(data.human.queue)
		else: game.human.set(property, data.human[property])
	for property in EXPOSURE: game.human.exposure.set(property, data.exposure[property])
	for property in GAME: game.set(property, data.game[property])

static func _valid(data: Dictionary) -> bool:
	if data.get("version") != VERSION or not _shaped(data, {"land": TYPE_DICTIONARY, "peasant": TYPE_DICTIONARY, "camp": TYPE_VECTOR2, "game": TYPE_DICTIONARY, "farm": TYPE_DICTIONARY, "human": TYPE_DICTIONARY, "exposure": TYPE_DICTIONARY}):
		return false
	var land: Dictionary = data.land
	if not _shaped(land, {"hills": TYPE_FLOAT, "ponds": TYPE_INT}) or land.hills < 0.0 or land.hills > Terrain.MAX_HILLS or land.ponds < 1 or land.ponds > 4:
		return false
	var peasant: Dictionary = data.peasant
	if not peasant.is_empty():
		if not peasant.get("name") is String or peasant.get("skin") not in Actor.SKINS or peasant.get("hair_colour", Actor.HAIR_COLOURS.keys()[0]) not in Actor.HAIR_COLOURS:
			return false
		for key in ["height", "weight", "body_fat"]:
			if not (peasant.get(key) is float or peasant.get(key) is int) or not peasant[key] > 0.0:
				return false
	var game: Dictionary = data.game
	if not _shaped(game, GAME) or game.day < 0 or game.seconds_per_day <= 0.0 or game._day_time < 0.0 or game._day_time >= game.seconds_per_day:
		return false
	var farm := Farm.new()
	var human := Human.new()
	var exposure := Exposure.new()
	for template in [[farm, Farm.SAVED, data.farm], [human, Human.SAVED, data.human], [exposure, EXPOSURE, data.exposure]]:
		for property: String in template[1]:
			if not template[2].has(property) or typeof(template[2][property]) != typeof(template[0].get(property)):
				return false
	# shortcut: plot, job and queue entries are not field-checked; upgrade if saves become shareable.
	for collection in CELLS:
		for cell: Variant in data.farm[collection]:
			if not cell is Vector2i or cell.x < 0 or cell.y < 0 or cell.x >= 16 or cell.y >= 16:
				return false
	for grams: Variant in data.farm.stock.values() + data.farm.wood_piles.values() + [data.farm.wood, data.farm.water, data.human.skin, data.human.carried, data.human.meal_grams, data.human.build_reserved, data.human.meal_fuel, data.human.meal_water]:
		if not grams is int or grams < 0:
			return false
	return true

static func _shaped(data: Dictionary, types: Dictionary) -> bool:
	for key in types:
		if not data.has(key) or typeof(data[key]) != types[key]:
			return false
	return true
