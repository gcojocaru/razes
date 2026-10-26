extends Control

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
	$Layout/Play.pressed.connect(creation.open)
	# Peasant creation takes the title's place until it closes.
	creation.visibility_changed.connect(func() -> void:
		$Layout.visible = not creation.visible
		if not creation.visible:
			$Layout/Play.grab_focus())
	$Layout/Play.grab_focus()
