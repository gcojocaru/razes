extends Node
## Shared buses and preferences, independent of gameplay saves.

const SETTINGS := "user://sound.cfg"
var levels := {"Master": 0.8, "Weather": 0.75, "Music": 0.7}
var muted := false

func _ready() -> void:
	for bus in ["Weather", "Music"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	load_settings()

func set_level(bus: String, value: float) -> void:
	if not levels.has(bus) or not is_finite(value):
		return
	levels[bus] = clampf(value, 0.0, 1.0)
	apply()

func set_muted(value: bool) -> void:
	muted = value
	apply()

func apply() -> void:
	for bus in levels:
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear_to_db(maxf(levels[bus], 0.0001)))
		AudioServer.set_bus_mute(AudioServer.get_bus_index(bus), levels[bus] == 0.0 or (bus == "Master" and muted))

func load_settings(path := SETTINGS) -> void:
	var config := ConfigFile.new()
	var error := config.load(path)
	if error != OK and error != ERR_FILE_NOT_FOUND:
		push_warning("Could not read sound settings: " + error_string(error))
	for bus in levels:
		var value: Variant = config.get_value("volume", bus, levels[bus])
		if (value is float or value is int) and is_finite(float(value)):
			levels[bus] = clampf(float(value), 0.0, 1.0)
	var mute_value: Variant = config.get_value("volume", "muted", false)
	muted = mute_value if mute_value is bool else false
	apply()

func save_settings(path := SETTINGS) -> Error:
	var config := ConfigFile.new()
	for bus in levels:
		config.set_value("volume", bus, levels[bus])
	config.set_value("volume", "muted", muted)
	var error := config.save(path)
	if error != OK:
		push_warning("Could not save sound settings: " + error_string(error))
	return error
