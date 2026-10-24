extends SceneTree

const Store = preload("res://scripts/save_store.gd")
const Rules = preload("res://scripts/village_rules.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var path := "/tmp/razes-save-check-%s.json" % Time.get_ticks_usec()
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("This is a corrupt development save.")
	file.close()
	var store = Store.new(path)
	var result: Dictionary = store.load_game()
	check(result.exists, "An unreadable household must not be treated as a missing save")
	check(not result.error.is_empty(), "Corrupt saves must show a recovery explanation")
	check(FileAccess.get_file_as_string(path) == "This is a corrupt development save.", "Loading must preserve corrupt original bytes")
	var state: Dictionary = Rules.new_game()
	check(not store.save_game(state).is_empty(), "Normal saves must not replace corrupt originals")
	check(store.start_fresh(state).is_empty(), "Explicit fresh start preserves the old bytes and writes a valid state")
	result = store.load_game()
	check(result.error.is_empty() and result.state == state, "Save round trip preserves the complete household")
	state.money = 40
	state = Rules.act(state, "buy_land", {"position": {"x": -1, "y": 0}}).state
	check(store.save_game(state).is_empty(), "Expanded land can be saved")
	check(store.load_game().state == state, "Ownership survives save round trip")
	var original: String = FileAccess.get_file_as_string(path)
	var invalid := state.duplicate(true)
	invalid.layout.ownedParcels.append({"x": 1, "y": 1})
	check(not store.save_game(invalid).is_empty(), "Invalid disconnected ownership cannot be saved")
	check(FileAccess.get_file_as_string(path) == original, "Rejected saves leave primary bytes intact")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("broken primary")
	file.close()
	result = store.load_game()
	check(result.recovered and result.state.money == 12, "Corrupt primary offers the previous valid household")
	check(store.restore_recovery().is_empty(), "Explicit recovery restores the valid household")
	check(store.load_game().error.is_empty(), "Restored primary is valid")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string("x".repeat(1000001))
	file.close()
	DirAccess.remove_absolute(path + ".recovery")
	check(not store.load_game().error.is_empty(), "Oversized saves are rejected before parsing")
	var directory := DirAccess.open("/tmp")
	for entry in directory.get_files():
		if entry.begins_with(path.get_file()):
			DirAccess.remove_absolute("/tmp/" + entry)
	print("Saves: %d/%d checks passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)
