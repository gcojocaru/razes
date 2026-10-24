extends SceneTree
## Crop and land rules, deterministic seasons and years, and the game screen wiring.

const SPRING := 35
const SUMMER := Calendar.DAYS_PER_MONTH * 3 + 10
const AUTUMN := Calendar.DAYS_PER_SEASON * 2 + 10
const WINTER := Calendar.DAYS_PER_SEASON * 3 + 10
const WARM := {"temperature": 20, "condition": "Rain"}

var failures: Array[String] = []

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

## Plows and sows `name` on sow_day, then grows with weather until it ripens or
## dies. Returns [final stage, day it ended].
func season(weather: Weather, name: String, sow_day: int) -> Array:
	var farm := Farm.new()
	farm.work([Vector2i.ZERO, Vector2i.ZERO], sow_day, "", name)
	var day := sow_day
	while farm.stage(Vector2i.ZERO) == "Sown":
		day += 1
		farm.grow(weather.on(day), day)
	return [farm.stage(Vector2i.ZERO), day]

## The middle of a crop's sowing months.
func mid_window(name: String) -> int:
	var months: Array = Farm.CROPS[name].sow
	return (months[0] + months[-1] + 1) * Calendar.DAYS_PER_MONTH / 2

## Grain gathered each year from one plot cropped with `name` in the years
## `pattern` marks true (repeating), sowing early in its window and harvesting when ripe.
func yields(name: String, pattern: Array, years: int) -> Array:
	var farm := Farm.new()
	farm.stock[name] = 9999
	var weather := Weather.new(7)
	var sow_at: int = Farm.CROPS[name].sow[0] * Calendar.DAYS_PER_MONTH + 10
	for day in Calendar.DAYS_PER_YEAR * years:
		farm.grow(weather.on(day), day)
		if day % Calendar.DAYS_PER_YEAR == sow_at and pattern[day / Calendar.DAYS_PER_YEAR % pattern.size()]:
			farm.work([Vector2i.ZERO, Vector2i.ZERO], day, "", name)
		if farm.stage(Vector2i.ZERO) == "Ripe":
			farm.act(Vector2i.ZERO, day)
	return range(1, years + 1).map(func(year: int) -> int: return farm.totals(year).gathered)

func click(position: Vector2, pressed: bool, shift := false) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.shift_pressed = shift
	event.position = position
	root.push_input(event, true)
	await process_frame

func press(button: Button) -> void:
	await click(button.get_global_rect().get_center(), true)
	await click(button.get_global_rect().get_center(), false)

## A right-button press at `from`, dragged through `path`, released at `to`.
func right_click(from: Vector2, to: Vector2, path := []) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_RIGHT
	event.pressed = true
	event.position = from
	root.push_input(event, true)
	await process_frame
	for point in path:
		var motion := InputEventMouseMotion.new()
		motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
		motion.position = point
		root.push_input(motion, true)
		await process_frame
	event = event.duplicate()
	event.pressed = false
	event.position = to
	root.push_input(event, true)
	await process_frame

func key(code: Key, shift := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	event.shift_pressed = shift
	current_scene._unhandled_input(event)

func texts(node: Node) -> Array:
	return node.find_children("*", "Label", true, false).map(func(label: Label) -> String: return label.text)

func run() -> void:
	var farm := Farm.new()
	var cell := Vector2i(3, 4)
	var barley: Dictionary = Farm.CROPS.Barley
	check(farm.stage(cell) == "Grass" and farm.fertility(cell) == 1.0 and farm.stock == Farm.STARTING_STOCK, "Plots start as fertile grass, with seed of each crop in store")
	check(Farm.sowable(SPRING) == ["Barley", "Oats"] and Farm.sowable(SUMMER) == ["Millet"] and Farm.sowable(AUTUMN) == ["Wheat", "Rye"] and Farm.sowable(WINTER).is_empty(), "Each crop has its own sowing months")
	check(not farm.act(cell, WINTER) and farm.plots.is_empty(), "Frozen winter ground cannot be plowed")
	check(farm.act(cell, SUMMER) and farm.stage(cell) == "Plowed", "Grass can be plowed outside winter")
	check(not farm.act(cell, SUMMER, "Barley") and farm.stock == Farm.STARTING_STOCK, "Sowing a crop outside its months changes nothing")
	check(farm.action(cell, SUMMER, "Barley").reason == "Barley is sown in Spring months 1–2", "Unavailable sowing says when that crop is sown")
	check(farm.action(cell, WINTER).reason == "Next sowing: Spring month 1 (Barley, Oats)", "Winter says when sowing opens next")
	check(farm.act(cell, SPRING, "Barley") and farm.stage(cell) == "Sown" and farm.crop(cell) == "Barley", "Sowing in its months plants the crop")
	check(farm.stock.Barley == Farm.STARTING_STOCK.Barley - barley.seed and farm.stock.Oats == Farm.STARTING_STOCK.Oats and farm.record(SPRING, "Barley").sown == 1, "Sowing uses that crop's own seed and is recorded")
	check(not farm.act(cell, SPRING) and farm.stage(cell) == "Sown", "Unripe crops cannot be harvested")

	check(Farm.daily_growth("Barley", {"temperature": barley.base, "condition": "Rain"}) == 0.0, "Crops do not grow at their base temperature")
	check(Farm.daily_growth("Barley", {"temperature": 20, "condition": "Snow"}) == 0.0, "Crops do not grow on snow days")
	check(Farm.daily_growth("Millet", {"temperature": 9, "condition": "Cloudy"}) == 0.0 and Farm.daily_growth("Barley", {"temperature": 9, "condition": "Cloudy"}) > 0.0, "Millet needs more warmth than barley")
	var rain_over_sun := func(name: String) -> float:
		return Farm.daily_growth(name, {"temperature": 20, "condition": "Rain"}) / Farm.daily_growth(name, {"temperature": 20, "condition": "Clear"})
	check(rain_over_sun.call("Oats") > rain_over_sun.call("Barley") and rain_over_sun.call("Barley") > rain_over_sun.call("Millet"), "Oats gain most from rain and millet least")

	var weather := Weather.new(7)
	var day := SPRING
	while farm.stage(cell) == "Sown":
		day += 1
		farm.grow(weather.on(day), day)
	check(farm.stage(cell) == "Ripe" and Calendar.date(day).season == 1, "Spring barley ripens in summer")
	check(farm.act(cell, day) and farm.stage(cell) == "Stubble", "Harvest leaves stubble")
	check(farm.stock.Barley == Farm.STARTING_STOCK.Barley - barley.seed + barley.grain, "Harvest on fertile soil adds the full yield to that crop's store")
	check(farm.record(day, "Barley").harvested == 1 and farm.totals(1).gathered == barley.grain, "The year records the harvest")
	check(is_equal_approx(farm.fertility(cell), 1.0 - barley.wear), "Harvest wears the soil")
	check(farm.action(cell, SPRING + Calendar.DAYS_PER_YEAR).name == "Plow", "Stubble must be plowed again before sowing")

	for i in ceili(barley.wear / Farm.YEARLY_REST * Calendar.DAYS_PER_YEAR):
		farm.grow({"temperature": 0, "condition": "Snow"}, day)
	check(is_equal_approx(farm.fertility(cell), 1.0), "Rest restores worn soil")
	check(farm.stage(cell) == "Stubble", "Grass does not return on cold days")
	for i in Farm.WILD_AT - 1:
		farm.grow(WARM, day)
	check(farm.stage(cell) == "Stubble", "Grass needs many warm days to return")
	farm.grow(WARM, day)
	check(farm.stage(cell) == "Grass", "Untended stubble goes back to grass")
	farm.act(cell, SPRING)
	for i in Farm.WILD_AT * 3:
		farm.grow(WARM, SPRING)
	check(farm.stage(cell) == "Plowed", "Plowed land stays plowed")

	farm.act(cell, SPRING, "Barley")
	farm.plots[cell].stage = "Ripe"
	farm.grow({"temperature": barley.frost + 1, "condition": "Snow"}, SPRING)
	check(farm.stage(cell) == "Ripe", "A crop survives frost above its limit")
	farm.grow({"temperature": barley.frost, "condition": "Snow"}, SPRING)
	check(farm.stage(cell) == "Withered" and farm.record(SPRING, "Barley").frost == 1, "Frost at a crop's limit kills it and is recorded")
	check(farm.action(cell, SPRING).name == "Plow", "Dead crops are plowed under")

	var wheat := Vector2i(9, 9)
	farm.work([wheat, wheat], AUTUMN, "", "Wheat")
	for i in 200:
		farm.grow(WARM, AUTUMN)
	check(farm.stage(wheat) == "Sown" and farm.growth(wheat) == Farm.BEFORE_WINTER, "Winter wheat waits for winter before ripening")
	farm.grow({"temperature": 0, "condition": "Cloudy"}, WINTER)
	for i in 200:
		farm.grow(WARM, SPRING + Calendar.DAYS_PER_YEAR)
	check(farm.stage(wheat) == "Ripe", "After a winter, wheat ripens")

	var field: Array = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0)]
	farm.stock.Barley = barley.seed * 2 + 1
	check(farm.preview(field, SPRING, "Sow", "Barley").plots == 0, "Sowing grass does nothing")
	check(farm.work(field, SPRING, "Plow") == 4 and farm.stage(field[3]) == "Plowed", "Work plows every selected plot")
	var forecast := farm.preview(field, SPRING, "", "Barley")
	check(forecast == {"plots": 2, "grain": -barley.seed * 2} and farm.stage(field[0]) == "Plowed", "Preview forecasts sowing as far as grain lasts, changing nothing")
	check(farm.work(field, SPRING, "", "Barley") == forecast.plots and farm.stock.Barley == 1, "Work matches its preview")
	check(farm.stage(field[1]) == "Sown" and farm.stage(field[2]) == "Plowed", "Sowing stops in order when that crop's seed runs out")
	check(farm.action(field[2], SPRING, "Barley").reason == "Needs 2 barley seed" and farm.action(field[2], SPRING, "Oats").reason == "", "Each crop needs its own seed")

	var ripe_day := {}
	for name in Farm.CROPS:
		var outcomes := range(50).map(func(seed: int) -> Array: return season(Weather.new(seed), name, mid_window(name)))
		var ripe := outcomes.filter(func(outcome: Array) -> bool: return outcome[0] == "Ripe")
		ripe_day[name] = ripe.map(func(outcome: Array) -> int: return outcome[1]).reduce(func(a: int, b: int) -> int: return a + b) / ripe.size()
		if name == "Wheat":
			check(ripe.size() >= 35 and ripe.size() < 50, "Wheat sown mid-autumn usually ripens but hard winters can kill it")
		else:
			check(ripe.size() == 50, "%s sown mid-window ripens in all 50 weather seeds" % name)
	check(ripe_day.Barley < ripe_day.Oats and ripe_day.Oats < ripe_day.Millet, "Spring crops ripen barley first, then oats, then late-sown millet")
	check(ripe_day.Rye < ripe_day.Wheat and Calendar.date(ripe_day.Rye).year == 2, "Autumn rye ripens the next summer, before wheat")
	var every_year := yields("Barley", [true], 9)
	var rested := yields("Barley", [true, true, false], 9)
	check(every_year[-1] < every_year[0] / 2.0, "Cropping barley every year halves its yield within nine years")
	check(rested.slice(-3) == rested.slice(0, 3), "Resting one year in three keeps barley's yield")

	change_scene_to_file("res://game.tscn")
	await process_frame
	await process_frame
	var game: Node3D = current_scene
	# A script error would stop this coroutine before quit() and hang the run.
	if game == null or game.find_child("FarmHud", true, false) == null:
		check(false, "The game screen loads")
		quit(1)
		return
	var hud: PanelContainer = game.find_child("FarmHud", true, false)
	var ledger: PanelContainer = game.find_child("Ledger", true, false)
	var debug: PanelContainer = game.find_child("AgricultureDebug", true, false)
	game.set_speed(0)
	var start_total := Farm.new().stored()
	check(hud.grain_label.text == "Grain  %d" % start_total and "Millet %d" % Farm.STARTING_STOCK.Millet in hud.grain_label.tooltip_text, "Farm panel shows grain in store, by crop on hover")
	check(hud.buttons.values().all(func(button: Button) -> bool: return not button.visible), "No action shows before plots are selected")
	var start: Vector2i = game.cell_at_screen(root.get_visible_rect().get_center())
	var end := start + Vector2i(2, 1)
	await click(game._camera.unproject_position(game.cell_center(start)), true)
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = game._camera.unproject_position(game.cell_center(end))
	root.push_input(motion, true)
	await process_frame
	await click(motion.position, false)
	check(game.selected.size() == 6 and game.selected.has(start) and game.selected.has(end), "Dragging selects a rectangle of plots")
	check(game._crops.get_pixelv(end).b == 1.0, "The field texture marks selected plots")
	check(hud.buttons.Plow.visible and hud.buttons.Plow.text == "Plow 6" and not hud.buttons.Sow.visible, "The panel offers to plow all six")
	key(KEY_F)
	check(game.selected.keys().all(func(plot: Vector2i) -> bool: return game.farm.stage(plot) == "Plowed"), "F works every selected plot")
	var extra := start + Vector2i(0, -2)
	await click(game._camera.unproject_position(game.cell_center(extra)), true, true)
	await click(game._camera.unproject_position(game.cell_center(extra)), false, true)
	check(game.selected.size() == 7 and game.selected.has(extra), "Shift-click adds a plot to the selection")
	var seeded: int = mini(6, Farm.STARTING_STOCK.Barley / barley.seed)
	check(hud.buttons.Sow.text == "Sow Barley %d  %+d grain" % [seeded, -barley.seed * seeded] and hud.buttons.Plow.text == "Plow 1", "Mixed selections offer each action with its crop, count and grain")
	check(seeded == 6 or "Seed for %d of 6" % seeded in hud._detail_label.text, "The panel says when seed runs short")
	check(hud.crop_button.visible and "Barley" in hud.buttons.Sow.tooltip_text, "The Sow button explains its crop, beside a crop menu button")
	key(KEY_C)
	var menu: PopupMenu = hud.crop_menu
	var oats: int = Farm.CROPS.keys().find("Oats")
	var winter_wheat: int = Farm.CROPS.keys().find("Wheat")
	check(menu.visible and menu.is_item_checked(0) and not menu.is_item_disabled(oats) and menu.is_item_disabled(winter_wheat), "C opens the crop menu: current crop checked, out-of-season crops disabled")
	var oats_sown: int = mini(6, Farm.STARTING_STOCK.Oats / Farm.CROPS.Oats.seed)
	check(menu.get_item_text(oats) == "Oats (%d)  ·  sow %d, %+d grain" % [Farm.STARTING_STOCK.Oats, oats_sown, -Farm.CROPS.Oats.seed * oats_sown] and menu.get_item_text(winter_wheat) == "Wheat (%d)  ·  Autumn months 1–2" % Farm.STARTING_STOCK.Wheat, "Menu items show the store and what they would sow, or when the crop is sown")
	menu.set_focused_item(oats)
	for pressed in [true, false]:
		var enter := InputEventKey.new()
		enter.keycode = KEY_ENTER
		enter.physical_keycode = KEY_ENTER
		enter.pressed = pressed
		Input.parse_input_event(enter)
		await process_frame
	check(not menu.visible and game.farm.stage(start) == "Sown" and game.farm.crop(start) == "Oats" and game.farm.stage(extra) == "Grass", "Choosing a crop from the keyboard sows it on the selected plowed plots only")
	check(game.seed_crop() == "Oats", "The chosen crop is remembered")
	var packed := roundi(game._crops.get_pixelv(start).r * 255)
	check(packed % 8 == Farm.STAGES.find("Sown") and packed / 8 == Farm.CROPS.keys().find("Oats") + 1, "The field texture carries each plot's stage and crop")
	check(hud.grain_label.text == "Grain  %d" % (start_total - Farm.CROPS.Oats.seed * oats_sown), "The store updates after sowing")
	await click(game._camera.unproject_position(game.cell_center(extra)), true)
	await click(game._camera.unproject_position(game.cell_center(extra)), false)
	check(game.selected.keys() == [extra], "A plain click replaces the selection")
	var start_screen: Vector2 = game._camera.unproject_position(game.cell_center(start))
	await right_click(start_screen + Vector2(40, 0), start_screen)
	check(not menu.visible and game.selected.keys() == [extra], "A right-drag rotates the view without opening the menu")
	await right_click(start_screen, start_screen + Vector2(2, 0), [start_screen + Vector2(80, 0), start_screen + Vector2(2, 0)])
	check(not menu.visible and game.selected.keys() == [extra], "A right-drag that comes back to where it began does not open the menu")
	await right_click(start_screen, start_screen)
	check(menu.visible and game.selected.keys() == [start], "Right-clicking a plot selects it and opens the crop menu")
	menu.hide()
	game._place_camera(game.cell_center(Vector2i(12, 3)))
	key(KEY_ENTER)
	check(game.selected.keys() == [Vector2i(12, 3)], "Enter selects the plot at the centre of the view")
	game._place_camera(game.cell_center(Vector2i(13, 3)))
	key(KEY_ENTER, true)
	check(game.selected.keys() == [Vector2i(12, 3), Vector2i(13, 3)], "Shift+Enter adds the centre plot")

	check(not ledger.visible, "The ledger starts hidden")
	key(KEY_L)
	check(ledger.visible and "Oats" in texts(ledger.body) and "%d growing" % oats_sown in texts(ledger.body), "L shows what is growing by crop")
	for tab in ["Years", "Crops"]:
		var button: Button = ledger.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text == tab)[0]
		await press(button)
	check("Autumn months 1–2" in texts(ledger.body) and "Wheat" in texts(ledger.body), "The Crops tab lists each crop's sowing months")
	ledger.tab = "Years"
	ledger.show_ledger(game.farm, game.day)
	check("1 now" in texts(ledger.body), "The Years tab lists this year")

	check(debug != null and not debug.visible, "The agriculture debug window starts hidden")
	key(KEY_F4)
	check(debug.visible, "F4 shows the agriculture debug window")
	debug.crop.select(Farm.CROPS.keys().find("Rye") + 1)
	debug.stage.select(Farm.STAGES.find("Ripe"))
	debug.apply_to_selected()
	check(game.farm.stage(Vector2i(12, 3)) == "Ripe" and game.farm.crop(Vector2i(13, 3)) == "Rye", "The debug window sets the selected plots")
	var fill: Button = debug.find_children("*", "Button", true, false).filter(func(b: Button) -> bool: return b.text.begins_with("Add 50"))[0]
	fill.pressed.emit()
	check(game.farm.stock.Rye == Farm.STARTING_STOCK.Rye + 50 and hud.grain_label.text == "Grain  %d" % game.farm.stored(), "The debug window fills the store")

	var inventory: PanelContainer = game.find_child("Inventory", true, false)
	check(not inventory.visible, "The inventory starts hidden")
	key(KEY_I)
	var stored := texts(inventory.body)
	check(inventory.visible and str(game.farm.stock.Oats) in stored and "%d plots" % (game.farm.stock.Barley / barley.seed) in stored, "I shows each crop's store and the plots it can sow")
	check("−%d sown" % (Farm.CROPS.Oats.seed * oats_sown) in stored and "—" in stored and str(game.farm.stored()) in stored, "The inventory shows this year's sowing, a dash for none, and the total")

	var Wiki := preload("res://wiki.gd")
	var bb: String = Wiki.to_bbcode("<head><title>Hidden</title></head><h2>Crops</h2>\n<p>Sow <b>barley</b> [early]&amp;<kbd>F</kbd></p><ul>\n<li>one</li> <li>two</li></ul><table><tr><th>A</th><th>B</th></tr><tr><td>1</td><td><i>2</i></td></tr></table>")
	check("Hidden" not in bb and "[ul]one\ntwo[/ul]" in bb and "[b]barley[/b] [lb]early[rb]&" in bb, "The wiki converter keeps text, lists and bold, escapes brackets and drops the head")
	check("[table=2][cell][color=%s]A[/color][/cell]" % Wiki.GOLD_HEX in bb and "[cell][i]2[/i][/cell][/table]" in bb, "Wiki tables become BBCode tables with gold headers")
	var page := FileAccess.get_file_as_string(Wiki.PAGE)
	for name in Farm.CROPS:
		var kind: Dictionary = Farm.CROPS[name]
		check(Farm.sowing_window(name) in page and "%d°C" % kind.frost in page and "%d → %d" % [kind.seed, kind.grain] in page, "The wiki's %s row matches the game" % name)
	var wiki: PanelContainer = game.find_child("Wiki", true, false)
	key(KEY_F1)
	var shown: String = wiki.text.get_parsed_text()
	check(wiki.visible and "Barley" in shown and "Plow grass" in shown and "<" not in shown and "[" not in shown, "F1 shows the wiki as formatted text, with no tags left over")
	game.weather = Weather.new(7)
	game.day = SUMMER
	game.skip_days(1)
	check(game.day == SUMMER + 1 and game.farm.growth(start) > 0.0, "Skipping a day grows sown crops")
	if failures.is_empty():
		print("PASS: five crops with own months, warmth, rain, frost and winter needs; plow, sow, harvest, stubble, plowed land kept, regrowing grass, soil wear and rest, year records, previews; 50-seed ripening per crop and 9-year rotation; selection, F/C/Enter keys, crop picker, ledger tabs, inventory, wiki page and window, agriculture debug and field texture")
	current_scene.free()
	# Let the audio server release stopped playback before the test process exits.
	await create_timer(0.2).timeout
	quit(0 if failures.is_empty() else 1)
