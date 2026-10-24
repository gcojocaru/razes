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
		await create_timer(0.2).timeout
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
		check(current_scene._focus().is_equal_approx(looked_at), "Rotating orbits the field without moving the view centre")
	if failures.is_empty():
		print("PASS: title, Romanian glyph, version, focus, three layouts, Enter, Space and mouse Play, looping menu music stops on start, grid field with cell picking")
	quit(0 if failures.is_empty() else 1)
