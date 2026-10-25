extends SceneTree

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

## Presses `button` by Enter or Space while it has focus, or by a mouse click.
func activate(activation: String, button: Control) -> void:
	for pressed in [true, false]:
		if activation == "Mouse":
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = pressed
			click.position = button.get_global_rect().get_center()
			root.push_input(click, true)
		else:
			var key := InputEventKey.new()
			key.keycode = KEY_ENTER if activation == "Enter" else KEY_SPACE
			key.pressed = pressed
			Input.parse_input_event(key)
		await process_frame
	await process_frame
	await process_frame

func press(code: Key) -> void:
	var key := InputEventKey.new()
	key.keycode = code
	key.pressed = true
	Input.parse_input_event(key)
	await process_frame

## Queues typing `text`; the focused control receives it next frame.
func type(text: String) -> void:
	for character in text:
		var key := InputEventKey.new()
		key.unicode = character.unicode_at(0)
		key.pressed = true
		Input.parse_input_event(key)

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
		await activate(activation, play)
		var creation = menu.creation
		var layout: Control = menu.get_node("Layout")
		check(creation.visible and not layout.visible and creation.name_edit.has_focus(), "Play opens peasant creation with the name ready to type via " + activation)
		check(music.playing and current_scene == menu, "Creation keeps the menu and its music")
		if activation == "Enter":
			for dimensions in [Vector2i(1000, 700), Vector2i(1440, 900), Vector2i(1920, 1080)]:
				root.size = dimensions
				await process_frame
				await process_frame
				var card: Rect2 = creation.get_global_rect()
				check(menu.get_viewport_rect().encloses(card) and not card.intersects(menu.get_node("SoundControl").button.get_global_rect()), "Peasant creation fits beside the Sound button at %s" % dimensions)
			check(creation.peasant.name == "Ion" and creation._values.Height.text == "1.72 m" and creation._values.Weight.text == "65 kg" and creation._values["Body fat"].text == "15%" and creation._info.text.begins_with("BMI 22.0"), "Creation starts from the default 65 kg peasant with 15% body fat")
			type("Toader")
			# LineEdit reports text changes deferred, after the frame that inserts them.
			await process_frame
			await process_frame
			check(creation.peasant.name == "Toader" and "Toader" in creation.begin.tooltip_text, "Typing replaces the suggested name")
			creation.sliders.Height.value = 1.55
			check(creation.sliders.Weight.min_value == 45 and creation.sliders.Weight.max_value == 72 and creation.peasant.weight == 65, "Weight keeps to a BMI of 18.5 to 30 at the chosen height")
			creation.sliders.Weight.value = 100
			check(creation.peasant.weight == 72, "A weight beyond a BMI of 30 is refused")
			creation.sliders.Height.value = 1.85
			creation.sliders["Body fat"].value = 25
			check(creation.sliders.Weight.min_value == 64 and creation.peasant.height == 1.85 and creation.peasant.body_fat == 0.25 and creation._info.text.begins_with("BMI 21.0 · 54.0 kg lean, 18.0 kg fat"), "Height and body fat set the body, and the summary follows")
			var presets: Dictionary = creation.Terrain.PRESETS
			check(creation.lands.Hills.button_pressed and creation.land == presets.Hills and creation._values.Hills.text == "18 m" and creation._values.Ponds.text == "2" and not creation.sliders.Hills.editable and not creation.sliders.Ponds.editable, "Land starts on the Hills preset with its sliders locked")
			creation.lands.Steppe.button_pressed = true
			check(creation.land == presets.Steppe and creation._values.Hills.text == "7 m" and creation._values.Ponds.text == "1", "A preset sets the land's hills and ponds")
			creation.lands.Custom.button_pressed = true
			creation.sliders.Hills.value = 22
			creation.sliders.Ponds.value = 3
			check(creation.sliders.Hills.editable and creation.land == {"hills": 22.0, "ponds": 3} and creation._values.Hills.text == "22 m" and creation._values.Ponds.text == "3", "Custom unlocks the hills and ponds")
			creation.sliders.Hills.value = 99
			check(creation.land.hills == creation.sliders.Hills.max_value and creation.sliders.Hills.max_value <= creation.Terrain.MAX_HILLS, "Custom hills stop at the highest land the terrain tests cover")
			creation.sliders.Hills.value = 22
			await press(KEY_ESCAPE)
			check(not creation.visible and layout.visible and play.has_focus(), "Escape returns from creation to Play")
			await activate(activation, play)
			check(creation.visible and creation.peasant.name == "Toader" and creation.peasant.height == 1.85 and creation.lands.Custom.button_pressed and creation.land == {"hills": 22.0, "ponds": 3}, "Reopening keeps the peasant and land being made")
			creation.name_edit.text = "  "
			creation.name_edit.text_changed.emit(creation.name_edit.text)
			await press(KEY_ENTER)
			check(creation.begin.disabled and current_scene == menu, "A blank name cannot begin the game")
			# Typed with the Enter below in one frame, before LineEdit reports the change, so Begin must read the field itself.
			type("Toader")
		elif activation == "Space":
			creation.begin.grab_focus()
		else:
			await activate(activation, creation.looks.hair.Red)
			for look in [["skin", "Olive"], ["beard", "Beard"], ["clothes", "Woad blue"]]:
				creation.looks[look[0]][look[1]].button_pressed = true
			check(creation.peasant.hair == "Red" and creation.peasant.beard == "Beard" and creation._values.Hair.text == "Red", "Clicking a swatch chooses its look")
			await activate(activation, creation.lands.Lakeland)
			check(creation.land == creation.Terrain.PRESETS.Lakeland and creation._values.Ponds.text == "4", "Clicking a land preset chooses it")
		await activate(activation, creation.begin)
		check(current_scene.scene_file_path == "res://game.tscn", "Begin opens game via " + activation)
		check(not is_instance_valid(music), "Leaving the menu frees its music player")
		var farmer: Human = current_scene.human
		if activation == "Enter":
			current_scene._show_farm()
			current_scene._body.show_body(farmer)
			check(farmer.name == "Toader" and current_scene._human_hud.title.text == "Toader" and current_scene._human_actor.get_node("Name").text == "Toader", "The game's farmer, panel and label carry the chosen name")
			check(farmer.height == 1.85 and is_equal_approx(farmer.mass(), 72.0) and is_equal_approx(farmer.fat, 18.0) and absf(farmer.glycogen - 54.0 * Human.GLYCOGEN_PER_LEAN) < 5.0 and current_scene._body._values["Height"][0].text == "1.85 m" and current_scene._body._values["Weight"][1].text == "+0.00 kg since start", "The farmer starts in the chosen body, the start of their Body window")
			check(current_scene.terrain.hills == 22.0 and current_scene.terrain.ponds.size() == 3, "The field is made from the custom land")
		elif activation == "Space":
			check(farmer.name == "Ion" and is_equal_approx(farmer.mass(), 65.0) and current_scene.terrain.hills == 18.0 and current_scene.terrain.ponds.size() == 2, "A new creation screen offers the default peasant and land again")
		else:
			var actor: Node3D = current_scene._human_actor
			check(actor._hair[0].albedo_color == actor.HAIRS.Red * 1.6 and actor._hands.albedo_color == actor.SKINS.Olive and actor._clothes[0].albedo_color == actor._ratio(actor.CLOTHES["Woad blue"], actor.CLOTHES["Undyed linen"]) and actor._beard.visible, "The farmer wears the chosen looks")
			check(current_scene.terrain.hills == 11.0 and current_scene.terrain.ponds.size() == 4, "The field is made from the chosen preset")
			var first_seed: int = current_scene.terrain.seed
			reload_current_scene()
			await process_frame
			await process_frame
			check(current_scene.human.name == "Ion" and current_scene._human_actor._beard.visible and is_equal_approx(current_scene.human.mass(), 65.0), "Restart begins again with the same peasant")
			check(current_scene.terrain.hills == 11.0 and current_scene.terrain.ponds.size() == 4 and current_scene.terrain.seed != first_seed, "Restart keeps the land with a fresh field")
		check(current_scene.placing_camp and current_scene.speed == 0, "A new game first pauses to choose the camp's place")
		for cell in 256:
			if current_scene.terrain.cell_reason(Vector2i(cell % 16, cell / 16)) == "":
				var spot: Vector3 = current_scene.cell_center(Vector2i(cell % 16, cell / 16))
				current_scene._place_camera(spot)
				if current_scene.place_camp(current_scene._camera.unproject_position(spot)):
					break
		check(not current_scene.placing_camp and current_scene.human.position == current_scene.human.home and current_scene.speed == 1, "Clicking dry ground pitches camp with the peasant and resumes time")
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
		print("PASS: title, Romanian glyph, version, focus, three layouts, Enter, Space and mouse Play into peasant creation (name, body limits, looks, land presets and Custom, Escape, blank names) and Begin into the game as that peasant on that land, both kept on Restart; looping menu music stops on start, grid field with cell picking, calendar with pause, speeds, debug day length, seasonal weather with particles, sun path, day and night lighting")
	current_scene.free()
	# Let the audio server release stopped playback before the test process exits.
	await create_timer(0.2).timeout
	quit(0 if failures.is_empty() else 1)
