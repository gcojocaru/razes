extends SceneTree
func _initialize() -> void:
	call_deferred("capture")
func capture() -> void:
	change_scene_to_file("res://game.tscn")
	await process_frame
	await process_frame
	current_scene.set_speed(0)
	var controls := current_scene.find_child("SoundControl", true, false)
	controls.button.pressed.emit()
	for weather in ["Rain", "Storm", "Snow"]:
		current_scene._weather_effects.show_weather(weather, true)
		current_scene._weather_audio.show_weather(weather, true)
		await create_timer(1).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/stefan-weather/" + weather + ".png")
	root.size = Vector2i(1000, 700)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/stefan-weather/minimum.png")
	current_scene.free()
	await create_timer(0.2).timeout
	quit()
