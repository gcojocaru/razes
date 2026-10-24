extends PanelContainer
## Bottom-centre farm panel: the grain stock, the selected plots and a button for
## each action some of them allow now, with its plot count and kg of grain spent or gained.
## The action wheel offers work for the selected land, including individual crops.

signal action_pressed(action: String)
signal crop_chosen(crop: String)
signal ledger_pressed
signal inventory_pressed
signal wiki_pressed

const TimeHud := preload("res://time_hud.gd")
const NOTES := {
	"Grass": "Plow it into a field",
	"Plowed": "Ready to sow",
	"Ripe": "Harvest before the frost",
	"Stubble": "Plow it again to sow",
	"Withered": "Frost killed this crop",
}

var grain_label := Label.new()
## Action name -> its button.
var buttons := {}
var action_button: Button
var action_wheel := preload("res://action_wheel.gd").new()
var _plot_label := Label.new()
var _detail_label := Label.new()

func _init() -> void:
	name = "FarmHud"
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_bottom = -14
	add_theme_stylebox_override("panel", TimeHud.box(TimeHud.INK, TimeHud.GOLD, 10, 2, Vector2(18, 10)))

	var serif := TimeHud.serif_font()

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	add_child(row)
	grain_label.add_theme_font_override("font", serif)
	grain_label.add_theme_font_size_override("font_size", 20)
	grain_label.add_theme_color_override("font_color", TimeHud.PARCHMENT)
	grain_label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(grain_label)
	row.add_child(VSeparator.new())

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", -4)
	text.custom_minimum_size.x = 240
	_plot_label.add_theme_font_override("font", preload("res://assets/fonts/CormorantUnicase-Bold.ttf"))
	_plot_label.add_theme_font_size_override("font_size", 22)
	_plot_label.add_theme_color_override("font_color", TimeHud.GOLD)
	_detail_label.add_theme_font_override("font", serif)
	_detail_label.add_theme_font_size_override("font_size", 13)
	_detail_label.add_theme_color_override("font_color", TimeHud.PARCHMENT)
	text.add_child(_plot_label)
	text.add_child(_detail_label)
	row.add_child(text)

	for action in Farm.ACTIONS:
		buttons[action] = _button(serif, "Key F does every ready action")
		buttons[action].pressed.connect(action_pressed.emit.bind(action))
		row.add_child(buttons[action])
		if action == "Sow":
			action_button = _button(serif, "Actions for the selected land (key C, or right-click a plot)")
			action_button.text = "Actions"
			action_button.pressed.connect(open_action_menu)
			row.add_child(action_button)
	row.add_child(VSeparator.new())
	for window in [["Ledger", "Plantings and yearly results (key L)", ledger_pressed], ["Inventory", "Grain in store by crop (key I)", inventory_pressed], ["Wiki", "How the game works (key F1)", wiki_pressed]]:
		var button := _button(serif, window[1])
		button.text = window[0]
		var opened: Signal = window[2]
		button.pressed.connect(opened.emit)
		row.add_child(button)

	action_wheel.activated.connect(func(action: String, crop: String) -> void:
		if action == "Sow":
			crop_chosen.emit(crop)
		else:
			action_pressed.emit(action))

func _button(font: Font, tooltip: String) -> Button:
	var button := Button.new()
	button.tooltip_text = tooltip
	# Keyboard focus would let Space press the button instead of toggling pause.
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(0, 34)
	TimeHud.style_button(button, font)
	return button

## Shows the stock and what the selected plots allow on this day, sowing `seed_crop`.
func show_farm(farm: Farm, cells: Array, day: int, seed_crop: String) -> void:
	grain_label.text = "Grain  %d kg" % farm.stored()
	grain_label.tooltip_text = "Grain in store, each crop's own seed (key I):\n" + "\n".join(Farm.CROPS.keys().map(func(crop: String) -> String: return "%s %d kg" % [crop, farm.stock[crop]]))
	var sowable := 0
	for action in buttons:
		var result := farm.preview(cells, day, action, seed_crop)
		if action == "Sow":
			sowable = result.plots
		var verb: String = "Sow " + seed_crop if action == "Sow" else action
		buttons[action].visible = result.plots > 0
		buttons[action].text = "%s %d" % [verb, result.plots] + ("" if result.grain == 0 else "  %+d kg" % result.grain)
	action_button.visible = not cells.is_empty()
	action_wheel.show_farm(farm, cells, day, seed_crop)
	if seed_crop != "":
		buttons.Sow.tooltip_text = _facts(seed_crop) + " (key F)"
	if cells.is_empty():
		_plot_label.text = "Fields"
		_detail_label.text = "Click or drag over plots; Shift adds"
		return
	var reasons := {}
	var ready_to_sow := 0
	var soil := 0.0
	for cell in cells:
		var next := farm.action(cell, day, seed_crop)
		if next.reason != "":
			reasons[next.reason] = reasons.get(next.reason, 0) + 1
		elif next.name == "Sow":
			ready_to_sow += 1
		soil += farm.fertility(cell)
	if sowable < ready_to_sow:
		reasons["Seed for %d of %d" % [sowable, ready_to_sow]] = 1
	var notes := PackedStringArray()
	if cells.size() == 1:
		var cell: Vector2i = cells[0]
		var stage := farm.stage(cell)
		match stage:
			"Sown":
				_plot_label.text = "%s  %d%%" % [farm.crop(cell), floori(farm.growth(cell) * 100)]
				if Farm.CROPS[farm.crop(cell)].winter and not farm.plots[cell].wintered:
					reasons = {"Must live through winter": 1}
			"Ripe":
				_plot_label.text = "Ripe " + farm.crop(cell).to_lower()
			_:
				_plot_label.text = stage
		notes.append(reasons.keys()[0] if reasons else NOTES[stage])
		if stage in ["Sown", "Ripe"]:
			notes.append(("about %d kg" if stage == "Sown" else "%d kg") % farm.harvest_yield(cell))
	else:
		_plot_label.text = "%d plots" % cells.size()
		for reason in reasons:
			notes.append(reason if reasons[reason] == 1 else "%s ×%d" % [reason, reasons[reason]])
	notes.append("soil %d%%" % roundi(soil / cells.size() * 100))
	_detail_label.text = "  ·  ".join(notes)

## One line on what a crop needs and gives.
func _facts(crop: String) -> String:
	var kind: Dictionary = Farm.CROPS[crop]
	return "%s: sown %s, needs about %d warm days%s, dies at %d°C, %d kg seed a plot for about %d kg" % [crop, Farm.sowing_window(crop), kind.ripe, " and a winter" if kind.winter else "", kind.frost, kind.seed, kind.grain]

## Opens contextual actions at the pointer, or above the farm panel for C/the button.
func open_action_menu(at := Vector2(-1, -1)) -> void:
	if at == Vector2(-1, -1):
		at = Vector2(get_viewport_rect().size.x / 2, get_global_rect().position.y - action_wheel.RADIUS - 28)
	action_wheel.open_at(at)
