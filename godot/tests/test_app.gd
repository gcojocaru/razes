extends SceneTree

const Main = preload("res://scripts/main.gd")
const Store = preload("res://scripts/save_store.gd")
const Rules = preload("res://scripts/village_rules.gd")
var checks := 0
var failures := 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var path := "/tmp/razes-app-check-%s.json" % Time.get_ticks_usec()
	var game = Main.new()
	game.store = Store.new(path)
	root.add_child(game)
	await process_frame
	check(game.find_child("EndWeek", true, false) is Button, "Playable interface offers a keyboard-focusable weekly review button")
	check(game._resources.get_parent().get_parent().size.y < 115, "Resource header must stay compact and leave the village visible")
	game.show_panel("debug")
	check(game.find_child("DebugResources", true, false) is Button, "Existing developer resource control remains reachable")
	check(game.find_child("DebugPlace_barn", true, false) is Button, "Every building can be inspected through the developer builder")
	check(game.perform("assign", {"task": "buildWoodshed"}), "Weekly builder can reserve an unbuilt plot")
	check(game.perform("assign", {"task": "rest"}), "Changing assignment leaves a cancelable reserved plot")
	game.show_panel("places")
	var plan_button = game.find_child("Visit_woodshed", true, false)
	check(plan_button is Button, "Canceled worker plans remain reachable through Places")
	game.select_place({"kind": "building", "id": "woodshed"})
	var cancel_plan = game.find_child("CancelPlan_woodshed", true, false)
	check(cancel_plan is Button, "An unbuilt reservation offers cancellation")
	if cancel_plan is Button:
		cancel_plan.pressed.emit()
	check(game.state.layout.buildings.is_empty(), "Canceling the reserved plot releases its occupied cells")
	check(game.perform("assign", {"task": "paid"}), "UI accepts a valid assignment")
	check(game.perform("end_week"), "UI resolves the weekly action")
	check(game.state.get("money") == 13 and game.state.get("food") == 17, "UI uses authoritative wage and consumption rules")
	check(game.perform("continue"), "UI continues into the next week")
	check(game.state.get("week") == 1, "Continue advances the calendar")
	var loaded: Dictionary = game.store.load_game()
	check(loaded.error.is_empty() and loaded.state == game.state, "Successful UI actions persist the complete state")
	var before: Dictionary = game.state.duplicate(true)
	check(not game.perform("buy_land", {"position": {"x": 1, "y": 0}}), "UI rejects unaffordable land")
	check(game.state == before, "Rejected UI action preserves money and land")
	game.queue_free()
	await process_frame
	var recovery_store = Store.new(path)
	check(recovery_store.start_fresh(Rules.new_game()).is_empty(), "Recovery fixture has a valid primary")
	check(recovery_store.save_game(Rules.new_game()).is_empty(), "Recovery fixture preserves a valid backup")
	var broken := FileAccess.open(path, FileAccess.WRITE)
	broken.store_string("corrupt primary")
	broken.close()
	var recovering = Main.new()
	recovering.store = recovery_store
	root.add_child(recovering)
	await process_frame
	await process_frame
	check(recovering.needs_recovery and recovering._recovery.visible, "Corrupt primary presents recovery actions")
	recovering._recovery.get_ok_button().pressed.emit()
	await process_frame
	check(recovering._fresh.visible, "Fresh start is explicitly confirmed")
	recovering._fresh.get_cancel_button().pressed.emit()
	await process_frame
	await process_frame
	check(recovering._recovery.visible, "Canceling fresh start returns to recovery controls")
	recovering._recovery.hide()
	check(not recovering._week_button.disabled, "A dismissed recovery dialog keeps a reachable recovery command")
	recovering._week_button.pressed.emit()
	await process_frame
	check(recovering._recovery.visible, "The persistent command reopens recovery without restarting")
	recovering.queue_free()
	await process_frame
	for suffix in ["", ".recovery", ".tmp", ".recovery.tmp"]:
		DirAccess.remove_absolute(path + suffix)
	for entry in DirAccess.open("/tmp").get_files():
		if entry.begins_with(path.get_file() + ".preserved-"):
			DirAccess.remove_absolute("/tmp/" + entry)
	print("App: %d/%d checks passed" % [checks - failures, checks])
	quit(0 if failures == 0 else 1)
