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
		check(current_scene.get_child_count() == 0, "Game scene is empty, with no menu controls")
		check(RenderingServer.get_default_clear_color() == Color.BLACK, "Empty game background is black")
	if failures.is_empty():
		print("PASS: title, Romanian glyph, version, focus, three layouts, Enter, Space and mouse Play, empty black game")
	quit(0 if failures.is_empty() else 1)
