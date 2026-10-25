extends SceneTree
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/stefan-weather")
	var audio := root.get_node("Audio")
	var original: Dictionary = audio.levels.duplicate()
	var was_muted: bool = audio.muted
	audio.set_level("Weather", 5)
	check(audio.levels.Weather == 1.0, "Volume clamps above maximum")
	audio.set_level("Weather", -1)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Weather")), "Zero volume silences bus")
	audio.set_level("Weather", 0.42)
	audio.set_muted(true)
	check(audio.levels.Weather == 0.42 and AudioServer.is_bus_mute(0), "Mute preserves mix")
	check(audio.save_settings("/tmp/stefan-weather/test-sound.cfg") == OK, "Settings save")
	audio.set_muted(false)
	audio.set_level("Weather", 0.9)
	audio.load_settings("/tmp/stefan-weather/test-sound.cfg")
	check(audio.muted and audio.levels.Weather == 0.42, "Settings restore")
	var malformed := ConfigFile.new()
	malformed.set_value("volume", "Weather", "bad")
	malformed.set_value("volume", "Music", 8)
	malformed.set_value("volume", "Master", NAN)
	malformed.set_value("volume", "muted", "bad")
	malformed.save("/tmp/stefan-weather/bad-sound.cfg")
	audio.load_settings("/tmp/stefan-weather/bad-sound.cfg")
	check(audio.levels.Weather == 0.42 and audio.levels.Music == 1.0 and is_finite(audio.levels.Master) and not audio.muted, "Invalid settings stay safe")
	audio.levels = original.duplicate()
	audio.set_muted(was_muted)
	var sound = load("res://weather_audio.gd").new()
	root.add_child(sound)
	check(sound.layers.size() == 5, "Five independent ambience layers")
	for layer in sound.layers:
		check(layer.playing and layer.stream.get_length() > 2, "Bundled layers play")
	sound.show_weather("Storm", true)
	sound.lightning()
	check(sound.pending_thunder >= 0.8, "Thunder waits for lightning distance")
	sound._process(2.4)
	check(sound.thunder.playing, "Delayed thunder plays")
	sound.lightning()
	sound.show_weather("Snow", true)
	check(sound.pending_thunder < 0 and not sound.thunder.playing, "Leaving storm cancels thunder")
	check(sound._mix[1] > 0 and sound._mix[2] == 0, "Snow has winter wind without rain")
	var instance: int = sound.layers[0].get_instance_id()
	sound.show_weather("Snow")
	check(sound.layers[0].get_instance_id() == instance and sound.layers[0].playing, "Repeated days keep running layers")
	sound.show_weather("Rain")
	for i in 100:
		sound._process(0.1)
	check(sound._mix[2] > 0.5 and sound.wind_strength > 0, "Rain fades in and wind varies")
	sound.free()
	for scene in ["res://main.tscn", "res://game.tscn"]:
		change_scene_to_file(scene)
		await process_frame
		await process_frame
		var controls := current_scene.find_child("SoundControl", true, false)
		check(controls != null, "Sound controls exist in " + scene)
		check(controls.button.get_global_rect().position.x > 0, "Sound button is inside viewport")
		controls.button.pressed.emit()
		check(controls.panel.visible and controls.mute.has_focus(), "Panel opens with keyboard focus")
		controls.sliders.Weather.value = 37
		check(is_equal_approx(audio.levels.Weather, 0.37), "Slider controls weather bus")
		if scene.ends_with("game.tscn"):
			current_scene.set_speed(0)
			var before: Vector3 = current_scene._camera.position
			Input.action_press("ui_right")
			current_scene._process(0.2)
			Input.action_release("ui_right")
			check(current_scene._camera.position == before, "Volume arrows do not pan camera")
		root.size = Vector2i(1000, 700)
		await process_frame
		check(Rect2(Vector2.ZERO, controls.size).encloses(controls.panel.get_global_rect()), "Panel fits minimum window")
		controls._close()
		var toggle_key := InputEventKey.new()
		toggle_key.physical_keycode = KEY_F10
		toggle_key.pressed = true
		root.push_input(toggle_key, true)
		check(controls.panel.visible, "F10 opens sound panel")
		var escape := InputEventKey.new()
		escape.physical_keycode = KEY_ESCAPE
		escape.keycode = KEY_ESCAPE
		escape.pressed = true
		root.push_input(escape, true)
		check(not controls.panel.visible, "Escape closes sound panel")
		check(not controls.panel.visible and controls.button.has_focus(), "Close restores button focus")
		if scene.ends_with("main.tscn"):
			check(current_scene.get_node("MenuMusic").bus == "Music", "Menu uses music bus")
	audio.levels = original.duplicate()
	audio.set_muted(was_muted)
	current_scene.free()
	await create_timer(0.2).timeout
	if failures.is_empty():
		print("PASS: sound preferences, validation, layers, transitions, thunder and menu/game controls")
	quit(0 if failures.is_empty() else 1)
