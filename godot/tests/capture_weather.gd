extends SceneTree
## Real renderer proof of weather and the day: dawn to night, the camp fire, and
## night weather.

var output := "/tmp/stefan-weather"
var game

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		output = args[0]
	DirAccess.make_dir_recursive_absolute(output)
	change_scene_to_file("res://game.tscn")
	await process_frame
	await process_frame
	game = current_scene
	game.set_speed(0)
	# Spring month 2: sunrise 04:56, sunset 19:04.
	game.day = 35
	for hour in [5.0, 5.5, 12.0, 18.5, 19.3, 20.2, 22.0]:
		await shot("Clear", hour, "Clear-%05.2f" % hour)
	game._zoom = 6.0
	game._focus_person()
	await shot("Clear", 22.0, "camp-night")
	game._zoom = 24.0
	game._focus_person()
	for weather in ["Rain", "Storm", "Snow"]:
		await shot(weather, 22.0, weather + "-night")
	game.find_child("SoundControl", true, false).button.pressed.emit()
	root.size = Vector2i(1000, 700)
	await shot("Snow", 22.0, "minimum")
	print("Captured weather and the day to " + output)
	current_scene.free()
	await create_timer(0.2).timeout
	quit()

## Saves the view in `weather` at `hour`, with the time panel showing the same.
func shot(weather: String, hour: float, label: String) -> void:
	game._weather_effects.show_weather(weather, true)
	game._weather_audio.show_weather(weather, true)
	game.today = {"temperature": 12, "condition": weather}
	game._day_time = game.seconds_per_day * hour / 24.0
	game._show_date()
	await create_timer(1).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label + ".png"))
