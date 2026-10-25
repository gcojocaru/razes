extends Control

var creation := preload("res://creation.gd").new()

func _ready() -> void:
	add_child(creation)
	add_child(preload("res://sound_control.gd").new())
	$MenuMusic.bus = "Music"
	$Version.text = "v" + str(ProjectSettings.get_setting("application/config/version"))
	$Layout/Play.pressed.connect(creation.open)
	# Peasant creation takes the title's place until it closes.
	creation.visibility_changed.connect(func() -> void:
		$Layout.visible = not creation.visible
		if not creation.visible:
			$Layout/Play.grab_focus())
	$Layout/Play.grab_focus()
