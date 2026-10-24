extends RefCounted

const Rules = preload("res://scripts/village_rules.gd")
const MAX_BYTES := 1000000
var path: String

func _init(save_path: String = "user://household-v1.json") -> void:
	path = save_path

func load_game() -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"state": {}, "error": "", "exists": false, "recovered": false}
	var primary := _read(path)
	if primary.error.is_empty():
		return {"state": primary.state, "error": "", "exists": true, "recovered": false}
	var recovery := _read(path + ".recovery")
	if recovery.error.is_empty():
		return {"state": recovery.state, "error": "The household save could not be read. A previous valid household is available to restore.", "exists": true, "recovered": true}
	return {"state": {}, "error": primary.error, "exists": true, "recovered": false}

func save_game(state: Dictionary) -> String:
	return _write(state, true)

func start_fresh(state: Dictionary) -> String:
	var problem: String = Rules.validate(state)
	if not problem.is_empty():
		return problem
	if FileAccess.file_exists(path):
		var archive := path + ".preserved-%s-%s" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()]
		if DirAccess.copy_absolute(_absolute(path), _absolute(archive)) != OK:
			return "The previous household could not be preserved. Your original save has not been replaced."
	return _write(state, false)

func restore_recovery() -> String:
	var recovery := _read(path + ".recovery")
	if not recovery.error.is_empty():
		return recovery.error
	return start_fresh(recovery.state)

func _read(filename: String) -> Dictionary:
	var file := FileAccess.open(filename, FileAccess.READ)
	if file == null:
		return {"state": {}, "error": "The household save could not be opened. Retry or start a fresh household."}
	if file.get_length() > MAX_BYTES:
		return {"state": {}, "error": "This household save is too large to read safely."}
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK or not json.data is Dictionary:
		return {"state": {}, "error": "The household save is damaged or incomplete. Retry, restore a recovery copy, or start fresh."}
	var state: Dictionary = Rules.canonical_state(json.data)
	var problem: String = Rules.validate(state)
	return {"state": state if problem.is_empty() else {}, "error": problem}

func _write(state: Dictionary, preserve_previous: bool) -> String:
	var problem: String = Rules.validate(state)
	if not problem.is_empty():
		return problem
	var text := JSON.stringify(state)
	if text.to_utf8_buffer().size() > MAX_BYTES:
		return "The household is too large to save safely."
	var directory := _absolute(path).get_base_dir()
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		return "The save directory could not be created. Your run can continue without saving."
	if preserve_previous and FileAccess.file_exists(path):
		problem = _read(path).error
		if not problem.is_empty():
			return "The existing save needs recovery before it can be replaced."
	var temporary := path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return "The household could not be written. Your previous save is intact."
	file.store_string(text)
	file.flush()
	var write_error := file.get_error()
	file.close()
	if write_error != OK:
		DirAccess.remove_absolute(_absolute(temporary))
		return "Writing the household failed. Your previous save is intact."
	if preserve_previous and FileAccess.file_exists(path):
		var backup := path + ".recovery"
		if DirAccess.copy_absolute(_absolute(path), _absolute(backup + ".tmp")) != OK:
			return "The recovery copy could not be written. Your previous save is intact."
		if DirAccess.rename_absolute(_absolute(backup + ".tmp"), _absolute(backup)) != OK:
			return "The recovery copy could not be preserved. Your previous save is intact."
	if DirAccess.rename_absolute(_absolute(temporary), _absolute(path)) != OK:
		return "The new household could not replace the saved file. Your previous save is intact."
	return ""

func _absolute(filename: String) -> String:
	return ProjectSettings.globalize_path(filename)
