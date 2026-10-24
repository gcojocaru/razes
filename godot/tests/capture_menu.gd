extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var output := "/tmp/stefan-menu"
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	change_scene_to_file("res://main.tscn")
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("menu.png"))
	root.size = Vector2i(1000, 700)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("menu-minimum.png"))
	var play: Button = current_scene.get_node("Layout/Play")
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = play.get_global_rect().get_center()
		event.pressed = pressed
		root.push_input(event, true)
		await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join("game.png"))
	print("Captured menu, minimum menu and game to " + output)
	quit()
