extends SceneTree

const Main = preload("res://scripts/main.gd")
const Rules = preload("res://scripts/village_rules.gd")
const Store = preload("res://scripts/save_store.gd")
var output := "/tmp/razes-godot-render"

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	call_deferred("run")

func capture(name: String) -> void:
	for frame in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(output.path_join(name + ".png"))
	if result != OK:
		push_error("Could not write rendered screenshot")
		quit(1)

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Renderer capture requires a graphical display, not --headless")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output)
	root.size = Vector2i(1440, 900)
	var game = Main.new()
	game.store = Store.new("/tmp/razes-render-ephemeral.json")
	root.add_child(game)
	game.world.set_process_unhandled_input(false)
	await capture("starter")
	var state: Dictionary = Rules.new_game()
	var placements := {
		"woodshed": Vector2i(2, 8), "cellar": Vector2i(10, 6), "well": Vector2i(9, 10),
		"barn": Vector2i(2, 4), "granary": Vector2i(6, 2), "workshop": Vector2i(10, 2),
		"bakery": Vector2i(12, 11), "smithy": Vector2i(2, 12), "stable": Vector2i(11, 14),
		"storehouse": Vector2i(13, 2), "apiary": Vector2i(8, 14)
	}
	for id in placements:
		var tile: Vector2i = placements[id]
		var result: Dictionary = Rules.act(state, "place_building", {"id": id, "position": {"x": tile.x, "y": tile.y}, "facing": 0, "instant": true})
		if not result.error.is_empty():
			push_error("Render fixture: " + result.error)
			quit(1)
			return
		state = result.state
	state.money = 100
	game.state = state
	game._refresh()
	await capture("village-summer")
	game.world.rotate_map(2)
	game.state = Rules.act(state, "preview_season", {"season": 3}).state
	game._refresh()
	await capture("village-winter-rear")
	game.world.rotate_map(2)
	game.state = Rules.act(state, "buy_land", {"position": {"x": -1, "y": 0}}).state
	game._refresh()
	game.show_panel("land")
	game.world.zoom_camera(2.0)
	await capture("expanded-land")
	game._close_panel()
	game.world.reset_camera()
	game.begin_placement("well")
	game.world._preview_tile = Vector2i(13, 6)
	game.world._update_preview()
	await capture("valid-placement")
	game.world._preview_tile = Vector2i(8, 8)
	game.world._update_preview()
	if Rules.placement_problem(game.state, "well", Vector2i(8, 8)).is_empty():
		push_error("The blocked placement fixture must overlap reserved house ground")
		quit(1)
		return
	await capture("blocked-placement")
	game.queue_free()
	await process_frame
	print("Rendered 6 actual Godot viewport captures to " + output)
	quit(0)
