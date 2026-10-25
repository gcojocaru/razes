extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func click(control: Control) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = control.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame

func save(output: String, file: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(file))

func capture() -> void:
	var output := "/tmp/stefan-menu"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	change_scene_to_file("res://main.tscn")
	await save(output, "menu.png")
	root.size = Vector2i(1000, 700)
	await save(output, "menu-minimum.png")
	var creation = current_scene.creation
	await click(current_scene.get_node("Layout/Play"))
	await save(output, "creation-minimum.png")
	root.size = Vector2i(1280, 800)
	await save(output, "creation.png")
	creation.name_edit.text = "Toader"
	creation.sliders.Height.value = 1.85
	creation.sliders.Weight.value = 90
	creation.sliders["Body fat"].value = 24
	for look in [["skin", "Olive"], ["hair", "Red"], ["beard", "Beard"], ["clothes", "Woad blue"]]:
		creation.looks[look[0]][look[1]].button_pressed = true
	# Face the camera for the close look at the beard.
	creation._turn = 0.0
	await save(output, "creation-custom.png")
	await click(creation.begin)
	await save(output, "game.png")
	current_scene._focus_person()
	current_scene._zoom = 2.1
	current_scene._focus_person()
	await save(output, "game-peasant.png")
	print("Captured menu, creation, customised creation and game to " + output)
	quit()
