extends SceneTree

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	check(ResourceLoader.exists("res://main.tscn"), "Main menu scene must exist")
	if not failures.is_empty():
		quit(1)
		return
	for activation in ["Enter", "Space", "Mouse"]:
		change_scene_to_file("res://main.tscn")
		await process_frame
		await process_frame
		var menu: Control = current_scene
		var title: Label = menu.get_node("Layout/Title")
		var play: Button = menu.get_node("Layout/Play")
		var version: Label = menu.get_node("Version")
		var music: AudioStreamPlayer = menu.get_node_or_null("MenuMusic")
		check(music != null, "Menu music player exists")
		if music == null:
			quit(1)
			return
		check(music.stream is AudioStreamMP3, "Menu uses bundled MP3 audio")
		check(music.stream.loop, "Menu music loops")
		check(music.playing, "Menu music starts automatically")
		check(music.volume_db == -14.0, "Menu music plays at a modest volume")
		music.seek(music.stream.get_length() - 0.05)
		# Wait on the real clock: a slow first frame can run a game-time timer out before the audio loops.
		var deadline := Time.get_ticks_msec() + 1000
		while music.get_playback_position() > 1.0 and Time.get_ticks_msec() < deadline:
			await process_frame
		check(music.playing and music.get_playback_position() < 1.0, "Music continues across its loop boundary")
		check(title.text == "ȘTEFAN", "Title preserves Romanian spelling")
		check(title.get_theme_font("font").has_char(0x218), "Title font contains Romanian Ș")
		check(version.text == "v" + str(ProjectSettings.get_setting("application/config/version")), "Version comes from project settings")
		check(play.has_focus(), "Play has initial keyboard focus")
		check(play.has_theme_stylebox_override("focus"), "Play has a visible focus style")
		for dimensions in [Vector2i(1000, 700), Vector2i(1440, 900), Vector2i(1920, 1080)]:
			root.size = dimensions
			await process_frame
			await process_frame
			var viewport := menu.get_viewport_rect()
			for control in [title, play, version]:
				check(viewport.encloses(control.get_global_rect()), "Control stays visible at %s: %s" % [dimensions, control.name])
			check(title.get_global_rect().end.y <= play.get_global_rect().position.y, "Title does not overlap Play")
		if activation != "Mouse":
			var key := InputEventKey.new()
			key.keycode = KEY_ENTER if activation == "Enter" else KEY_SPACE
			key.pressed = true
			Input.parse_input_event(key)
			await process_frame
			key = InputEventKey.new()
			key.keycode = KEY_ENTER if activation == "Enter" else KEY_SPACE
			key.pressed = false
			Input.parse_input_event(key)
		else:
			for pressed in [true, false]:
				var click := InputEventMouseButton.new()
				click.button_index = MOUSE_BUTTON_LEFT
				click.pressed = pressed
				click.position = play.get_global_rect().get_center()
				root.push_input(click, true)
				await process_frame
		await process_frame
		await process_frame
		check(current_scene.scene_file_path == "res://game.tscn", "Play opens game via " + activation)
		check(not is_instance_valid(music), "Leaving the menu frees its music player")
		check(current_scene.has_node("Field"), "Game shows the grid field")
		check(current_scene.cell_at_world(Vector3(-15.9, 0, -15.9)) == Vector2i(0, 0), "Field corner is cell 0,0")
		check(current_scene.cell_at_world(current_scene.cell_center(Vector2i(5, 9))) == Vector2i(5, 9), "Cell centre maps back to its cell")
		check(current_scene.cell_at_world(Vector3(40, 0, 0)) == Vector2i(-1, -1), "Points off the field have no cell")
		var centre: Vector2 = root.get_visible_rect().get_center()
		check(current_scene.cell_at_screen(centre) != Vector2i(-1, -1), "Screen centre looks at the field")
		var looked_at: Vector3 = current_scene._focus()
		current_scene.rotate_camera(PI / 2)
		var pinch := InputEventMagnifyGesture.new()
		pinch.factor = 1.5
		var before: float = current_scene._zoom
		current_scene._unhandled_input(pinch)
		check(current_scene._zoom < before, "Trackpad pinch zooms in")
		check(Calendar.DAYS_PER_YEAR == 336, "Year is 4 seasons x 3 months x 4 weeks x 7 days")
		check(Calendar.date(0) == {"year": 1, "season": 0, "month": 1, "week": 1, "day": 1}, "Time starts on the first day of spring")
		check(Calendar.date(335) == {"year": 1, "season": 3, "month": 3, "week": 4, "day": 7}, "Last day of the year is in winter")
		check(Calendar.date(336).year == 2 and Calendar.date(336).season == 0, "Year rolls over into spring")
		check(Calendar.date(28).month == 2 and Calendar.date(84).season == 1, "Months and seasons roll over")
		var start_day: int = current_scene.day
		# Calendar acceleration is tested separately from starvation and Game Over.
		current_scene.human.calories = 100000
		current_scene.advance_time(current_scene.seconds_per_day * 3)
		check(current_scene.day == start_day + 3, "Game time advances whole days")
		check(current_scene.find_child("TimeHud", true, false) != null, "Game shows the time panel")
		var space := InputEventKey.new()
		space.physical_keycode = KEY_SPACE
		space.pressed = true
		current_scene._unhandled_input(space)
		check(current_scene.speed == 0, "Space pauses time")
		current_scene._unhandled_input(space)
		check(current_scene.speed == 1, "Space resumes the previous speed")
		current_scene.set_speed(4)
		start_day = current_scene.day
		current_scene._process(current_scene.seconds_per_day)
		check(current_scene.day == start_day + 4, "Fastest speed runs four days per normal day")
		var debug: PanelContainer = current_scene.find_child("DebugPanel", true, false)
		check(debug != null and not debug.visible, "Debug panel exists but starts hidden")
		var f3 := InputEventKey.new()
		f3.physical_keycode = KEY_F3
		f3.pressed = true
		current_scene._unhandled_input(f3)
		check(debug.visible, "F3 shows the debug panel")
		debug.day_length.value = 0.5
		check(is_equal_approx(current_scene.seconds_per_day, 0.5), "Debug panel sets the day length")
		var weather := Weather.new(7)
		check(weather.on(50) == Weather.new(7).on(50), "Same seed and day give the same weather")
		var season_temperature := [0.0, 0.0, 0.0, 0.0]
		var seen := {}
		var snow_when_warm := false
		for weather_day in Calendar.DAYS_PER_YEAR * 3:
			var forecast: Dictionary = weather.on(weather_day)
			season_temperature[Calendar.date(weather_day).season] += forecast.temperature
			seen[forecast.condition] = true
			snow_when_warm = snow_when_warm or (forecast.condition == "Snow" and forecast.temperature > 1)
		check(season_temperature[1] > season_temperature[0] and season_temperature[0] > season_temperature[3], "Summer is warmest and winter coldest")
		check(seen.size() == Weather.CONDITIONS.size(), "Every weather condition happens within three years")
		check(not snow_when_warm, "Snow only falls at 1°C or colder")
		check(current_scene.today == current_scene.weather.on(current_scene.day), "Game shows the weather for today")
		var effects: Node3D = current_scene.find_child("WeatherEffects", true, false)
		effects.show_weather("Storm", true)
		check(effects.rain.emitting and not effects.snow.emitting, "Storms rain")
		effects.show_weather("Snow", true)
		check(effects.snow.emitting and not effects.rain.emitting, "Snow days snow")
		effects.show_weather("Clear", true)
		check(not effects.snow.emitting and not effects.rain.emitting, "Clear days have no particles")
		var first_flash := INF
		for storm in 20:
			effects.show_weather("Clear", true)
			effects.show_weather("Storm")
			first_flash = minf(first_flash, effects._next_flash)
		check(first_flash > effects.BLEND_SECONDS * 2, "The first lightning waits until the ground has turned wet")
		var noon := Calendar.sun(0, 12.0)
		check(is_zero_approx(Calendar.sun(0, 6.0).y) and absf(rad_to_deg(asin(noon.y)) - 43.0) < 0.01 and noon.z > 0.7 and Calendar.sun(0, 7.0).x > 0.9, "The equinox sun rises at 06:00 in the east and stands 43° up in the south at noon")
		var daylight := func(on: int) -> float:
			var hours := 0.0
			for minute in 24 * 60:
				hours += float(Calendar.sun(on, minute / 60.0).y > 0.0) / 60.0
			return hours
		check(absf(daylight.call(Calendar.DAYS_PER_SEASON) - 15.7) < 0.1 and absf(daylight.call(Calendar.DAYS_PER_SEASON * 3) - 8.3) < 0.1, "Days last 15.7 hours at midsummer and 8.3 at midwinter, as at Chișinău")
		effects.show_weather("Clear", true)
		await process_frame
		effects.show_time(0, 12.0)
		var lit: Array = [effects._sun.light_energy, effects._environment.background_color.v, effects._fire.light_energy]
		check(effects._sun.basis.z.is_equal_approx(noon), "At noon the light comes from the sun")
		effects.show_time(0, 0.0)
		check(effects._sun.basis.z.is_equal_approx(-Calendar.sun(0, 0.0)) and effects._sun.light_energy < lit[0] * 0.5 and effects._environment.background_color.v < lit[1] * 0.3 and effects._fire.light_energy > lit[2] * 3.0, "At midnight a dimmer moon opposite the sun lights the field, the sky darkens and the camp fire brightens")
		var hud = current_scene._time_hud
		hud.show_time(0, 0, {"temperature": 10, "condition": "Clear"}, 0.0)
		var night: bool = hud._night
		hud.show_time(0, 0, {"temperature": 10, "condition": "Clear"}, 12.0)
		check(night and not hud._night, "The time panel shows a moon at night and the sun by day")
		check(current_scene._focus().is_equal_approx(looked_at), "Rotating orbits the field without moving the view centre")
	if failures.is_empty():
		print("PASS: title, Romanian glyph, version, focus, three layouts, Enter, Space and mouse Play, looping menu music stops on start, grid field with cell picking, calendar with pause, speeds, debug day length, seasonal weather with particles, sun path, day and night lighting")
	current_scene.free()
	# Let the audio server release stopped playback before the test process exits.
	await create_timer(0.2).timeout
	quit(0 if failures.is_empty() else 1)
