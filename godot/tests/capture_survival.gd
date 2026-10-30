extends SceneTree
var game
var output := "/private/tmp/razes-survival-captures"
func _initialize() -> void: call_deferred("run")
func shot(title: String) -> void:
	await create_timer(0.3).timeout
	game._woodland.show_conditions(game._human_actor.position,game._camera.position,Vector2(0.2,0.04),game.farm.snow_cover)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(title+".png"))
	# Change scene transforms outside the renderer callback.
	await process_frame
func timing(label: String) -> Dictionary:
	for i in 12:
		await process_frame
		await RenderingServer.frame_post_draw
	var started := Time.get_ticks_usec()
	for i in 60:
		await process_frame
		await RenderingServer.frame_post_draw
	var sample := {"ms":(Time.get_ticks_usec()-started)/60000.0, "draws":RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)}
	print("PERF %s: %.2f ms/frame; %d draw calls; viewport %s" % [label,sample.ms,sample.draws,root.size])
	await process_frame
	return sample
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	root.size=Vector2i(1280,800)
	game=load("res://game.tscn").instantiate();game.terrain_seed=42;game.weather=Weather.new(42)
	root.add_child(game);current_scene=game;game.set_speed(0);game.set_process(false);game.set_process_unhandled_input(false)
	game.day=100;game._day_time=game.seconds_per_day*0.5;game._start_day()
	game._woodland.visible=false
	var baseline: Dictionary = await timing("same scene without trees")
	game._woodland.visible=true
	var wooded: Dictionary = await timing("summer woodland")
	assert(wooded.draws>baseline.draws, "Performance sample must actually render the trees")
	await shot("woodland-overview")
	var cell: Vector2i=game.farm.woodland.keys()[game.farm.woodland.size()/2]
	game.human.position=Human.plot_centre(cell)
	game._show_person();game._focus_person()
	game._start_selection(cell,false)
	await shot("woodland-close")
	game._farm_hud.open_action_menu()
	await shot("chop-wheel")
	game._farm_hud.action_wheel.hide()
	game.human.position=game.human.home;game.farm.wood=350000
	game.human.build_shelter(game.farm);game.human.build_remaining=4
	game._show_person();game._focus_person()
	await shot("construction")
	game.human.build_remaining=0;game.human.build_reserved=0;game.farm.shelter=true
	game.human.fatigue=80;game.human.sleep(6);game.advance_time(game.seconds_per_day/24.0*0.1)
	game._show_person();game._zoom=4.0;game._place_camera(game._human_actor.position)
	await shot("shelter-sleeper")
	game.human.position += Vector2(10,0);game._show_person()
	await shot("shelter-exterior")
	game.human.position=game.human.home;game._show_person()
	game._open_camp_menu()
	await shot("camp-wheel")
	game._camp_menu.hide();game.human.wake_up()
	game.day=Calendar.DAYS_PER_SEASON*2+40;game._show_farm()
	game._zoom=18;game._place_camera(Vector3.ZERO)
	await shot("autumn")
	game.day=Calendar.DAYS_PER_SEASON*3+10;game.farm.snow_cover=1;game._start_day()
	game._day_time=game.seconds_per_day*0.9;game._show_date();game._show_person()
	await shot("winter-night")
	root.size=Vector2i(1000,700);game._open_sleep()
	await shot("minimum-sleep")
	game._sleep_window.hide();game.toggle(game._body)
	await shot("minimum-body")
	print("Captured survival to "+output)
	game.free();quit()
