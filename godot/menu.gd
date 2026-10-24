extends Control

func _ready() -> void:
	$Version.text = "v" + str(ProjectSettings.get_setting("application/config/version"))
	$Layout/Play.pressed.connect(_play)
	$Layout/Play.grab_focus()

func _play() -> void:
	var error := get_tree().change_scene_to_file("res://game.tscn")
	if error != OK:
		push_error("Could not open the game scene: " + error_string(error))
