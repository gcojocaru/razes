extends SceneTree
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message); push_error(message)
func key(code: Key) -> void:
	var e := InputEventKey.new();e.physical_keycode=code;e.keycode=code;e.pressed=true
	root.push_input(e,true)
func choose(game, action: String) -> void:
	key(KEY_G)
	var index: int = game._camp_menu.entries.map(func(e):return e.action).find(action)
	for i in index: key(KEY_TAB)
	key(KEY_ENTER)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://game.tscn").instantiate()
	game.terrain_seed=42;root.add_child(game);current_scene=game;game.set_speed(0)
	await process_frame;await process_frame
	var cell: Vector2i=game.farm.woodland.keys()[0]
	game._start_selection(cell,false);key(KEY_C)
	check(game._farm_hud.action_wheel.entries[0].action=="Chop", "Woodland offers Chop through the actual field wheel")
	key(KEY_ENTER)
	check(game.human.queue.size()==1 and game.farm.wood_piles.is_empty(), "Keyboard chopping queues physical work, not instant wood")
	game.advance_time(game.seconds_per_day/24.0)
	key(KEY_BACKSPACE)
	check(game.farm.woodland[cell]<6 and game.farm.woodland[cell]>4.9, "Clear jobs preserves partial chopping through scene input")
	var paused: float=game.farm.woodland[cell];var wood: int=game.farm.wood
	game._process(1)
	check(game.farm.woodland[cell]==paused and game.farm.wood==wood, "Pause freezes woodland work and fuel")
	game.farm.wood=350000
	game.human.position=game.human.home
	game.human.fatigue=0
	choose(game,"Build")
	check(game.human.build_reserved==300000 and game.farm.wood==50000, "Camp wheel construction reserves deposited logs")
	key(KEY_BACKSPACE)
	check(game.human.build_reserved==0 and game.farm.wood==350000, "Scene cancellation refunds unfinished construction")
	choose(game,"Build")
	game.human.build_remaining=0.01
	game.advance_time(game.seconds_per_day/24.0*0.02)
	check(game.farm.shelter and game._camp.get_node("Shelter").visible, "Completing construction reveals the timber hut")
	choose(game,"Move")
	check(not game.placing_camp and game._camp_menu.visible, "Completed shelter explains why Move is unavailable")
	key(KEY_ESCAPE)
	var heated: bool=game.farm.heating_enabled
	choose(game,"Heat")
	check(game.farm.heating_enabled != heated, "Camp keyboard toggle changes heating")
	game.human.exposure.wetness=0.8
	choose(game,"Recover")
	check(game.human.recovering, "Recover is an explicit camp command")
	key(KEY_R)
	check(not game.human.recovering, "R stops recovery without discarding field orders")
	game.farm.wood=0
	game._open_food()
	check(game._food_window.prepare.disabled and game._food_window._reason.text.contains("wood"), "Food UI blocks a meal that lacks cooking fuel")
	key(KEY_ESCAPE)
	root.size=Vector2i(1000,700)
	key(KEY_G)
	await process_frame;await process_frame
	check(Rect2(Vector2.ZERO,root.get_visible_rect().size).encloses(game._camp_menu.wheel_rect()), "Camp controls fit the minimum viewport")
	key(KEY_ESCAPE)
	game.human.exposure.health=0
	game.advance_time(1)
	check(game._game_over.visible and game.speed==0 and not game._camp_menu.visible, "Exposure death uses the Game Over input barrier")
	load("res://game.gd").choose_camp=true
	key(KEY_ENTER)
	await process_frame;await process_frame
	check(current_scene.farm.wood==48000 and not current_scene.farm.shelter and current_scene.human.exposure.health==100 and current_scene.farm.woodland.size()>0, "Restart resets woodland, wood, shelter and exposure")
	current_scene.free()
	if failures.is_empty(): print("PASS: woodland/camp keyboard actions, partial work, pause, construction/cancel/fixed home, heating, recovery, food fuel, viewport and death/Restart")
	quit(0 if failures.is_empty() else 1)
