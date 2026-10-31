extends Control

const SaveGame := preload("res://save_game.gd")

var creation := preload("res://creation.gd").new()

func _ready() -> void:
	# The project's window size is in points, but Godot takes it as pixels: a Retina screen would show it at half size.
	var window := get_window()
	var screen := window.current_screen
	var fits := Vector2(DisplayServer.screen_get_usable_rect(screen).size) / Vector2(window.get_size_with_decorations())
	var scale := minf(DisplayServer.screen_get_scale(screen), minf(fits.x, fits.y))
	if scale > 1.0 and window.mode == Window.MODE_WINDOWED:
		window.size = Vector2i(Vector2(window.size) * scale)
		window.move_to_center()
	add_child(preload("res://sound_control.gd").new())
	# Full screen over the menu, so it sits above the Sound button.
	add_child(creation)
	$MenuMusic.bus = "Music"
	$Version.text = "v" + str(ProjectSettings.get_setting("application/config/version"))
	var saved := SaveGame.read()
	if not saved.is_empty():
		# Continue takes Play's place and focus; Play moves down a row.
		var resume: Button = $Layout/Play.duplicate()
		resume.name = "Continue"
		resume.text = "Continue"
		var date := Calendar.date(saved.game.day)
		resume.tooltip_text = "Resume %s's farm: %s of year %d" % [saved.human.name, Calendar.SEASONS[date.season].to_lower(), date.year]
		resume.pressed.connect(func() -> void:
			preload("res://game.gd").continue_save = saved
			var error := get_tree().change_scene_to_file("res://game.tscn")
			if error != OK:
				push_error("Could not open the game scene: " + error_string(error)))
		$Layout.add_child(resume)
		$Layout.move_child(resume, $Layout/Play.get_index())
		$Layout/Play.position.y += 80
	$Layout/Play.pressed.connect(creation.open)
	# Peasant creation takes the title's place until it closes.
	creation.visibility_changed.connect(func() -> void:
		$Layout.visible = not creation.visible
		if not creation.visible:
			$Layout/Play.grab_focus())
	var first: Button = $Layout.get_node_or_null("Continue")
	(first if first != null else $Layout/Play).grab_focus()
