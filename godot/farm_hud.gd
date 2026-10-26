extends PanelContainer
## Bottom-centre farm panel: selected plots and illustrated action buttons.
## Plot counts and grain costs/yields stay in tooltips.
## The action wheel offers work for the selected land, including individual crops.

signal action_pressed(action: String)
signal crop_chosen(crop: String)
signal ledger_pressed
signal inventory_pressed
signal wiki_pressed

const TimeHud := preload("res://time_hud.gd")
const ICONS := {
	"Actions": preload("res://assets/actions/actions.svg"),
	"Ledger": preload("res://assets/actions/ledger.svg"),
	"Inventory": preload("res://assets/actions/inventory.svg"),
	"Wiki": preload("res://assets/actions/wiki.svg"),
}
const NOTES := {
	"Grass": "Plow it into a field",
	"Plowed": "Ready to sow",
	"Ripe": "Harvest before the frost",
	"Stubble": "Plow it again to sow",
	"Withered": "Frost killed this crop",
}

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

	var text := VBoxContainer.new()
	text.alignment = BoxContainer.ALIGNMENT_CENTER
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
	_detail_label.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_child(text)

	for action in Farm.ACTIONS:
		buttons[action] = _button(serif, action, "Key F queues every ready action", action_wheel.ICONS.Barley if action == "Sow" else action_wheel.ICONS[action])
		buttons[action].pressed.connect(action_pressed.emit.bind(action))
		row.add_child(buttons[action])
		if action == "Sow":
			action_button = _button(serif, "Actions", "Actions for the selected land (key C, or right-click a plot)", ICONS.Actions)
			action_button.pressed.connect(open_action_menu)
			row.add_child(action_button)
	row.add_child(VSeparator.new())
	for window in [["Ledger", "Plantings and yearly results (key L)", ledger_pressed], ["Inventory", "Grain in store by crop (key I)", inventory_pressed], ["Wiki", "How the game works (key F1)", wiki_pressed]]:
		var button := _button(serif, window[0], window[0] + " — " + window[1], ICONS[window[0]])
		var opened: Signal = window[2]
		button.pressed.connect(opened.emit)
		row.add_child(button)

	action_wheel.activated.connect(func(action: String, crop: String) -> void:
		if action == "Sow":
			crop_chosen.emit(crop)
		else:
			action_pressed.emit(action))

func _button(font: Font, label: String, tooltip: String, icon: Texture2D) -> Button:
	var button := Button.new()
	button.name = label + "Button"
	button.accessibility_name = label
	button.tooltip_text = tooltip
	button.icon = icon
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.add_theme_constant_override("icon_max_width", 36)
	# Keyboard focus would let Space press the button instead of toggling pause.
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = Vector2(52, 52)
	TimeHud.style_button(button, font)
	button.add_theme_stylebox_override("pressed", TimeHud.box(TimeHud.GOLD.darkened(0.65), TimeHud.PARCHMENT, 6, 1, Vector2(6, 4)))
	return button

## Shows what the selected plots allow on this day, sowing `seed_crop`.
func show_farm(farm: Farm, cells: Array, day: int, seed_crop: String, queued: Array = []) -> void:
	var available := cells.filter(func(cell): return cell not in queued)
	var sowable := 0
	for action in buttons:
		var result := farm.preview(available, day, action, seed_crop)
		if action == "Sow":
			sowable = result.plots
		var verb: String = "Sow " + seed_crop if action == "Sow" else action
		buttons[action].visible = result.plots > 0
		buttons[action].accessibility_name = verb
		buttons[action].tooltip_text = "%s %d" % [verb, result.plots] + ("" if result.grain == 0 else "  %s%s kg" % ["+" if result.grain > 0 else "", Farm.kg(result.grain)]) + "\nQueues work for the farmer; F queues every ready action"
		if result.wood > 0:
			buttons[action].tooltip_text = "%s %d plots · %s kg wood to haul\nF queues every ready action" % [action, result.plots, Farm.kg(result.wood)]
	action_button.visible = not cells.is_empty()
	action_wheel.show_farm(farm, cells, day, seed_crop, queued)
	if seed_crop != "":
		buttons.Sow.icon = action_wheel.ICONS[seed_crop]
		buttons.Sow.tooltip_text += "\n" + _facts(seed_crop)
	_detail_label.tooltip_text = ""
	if cells.is_empty():
		_plot_label.text = "Fields"
		_detail_label.text = "Click or drag over plots; Shift adds"
		return
	var reasons := {}
	var ready_to_sow := 0
	var soil := 0.0
	for cell in cells:
		soil += farm.fertility(cell)
		if cell in queued:
			reasons["Work already queued"] = reasons.get("Work already queued", 0) + 1
			continue
		var next := farm.action(cell, day, seed_crop)
		if next.reason != "":
			_detail_label.tooltip_text = next.reason
			var reason: String = "Not enough %s seed" % seed_crop.to_lower() if " kg" in next.reason else next.reason
			reasons[reason] = reasons.get(reason, 0) + 1
		elif next.name == "Sow":
			ready_to_sow += 1
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
		if farm.terrain != null and farm.terrain.cell_reason(cell) != "":
			_plot_label.text = farm.terrain.cell_reason(cell)
		if farm.woodland.has(cell):
			_plot_label.text = "Woodland · %d%% cut" % floori((1.0 - farm.woodland[cell] / Farm.CHOP_HOURS) * 100)
			notes.append("%s h left · 240 kg wood" % String.num(farm.woodland[cell], 1))
		elif farm.wood_piles.has(cell):
			_plot_label.text = "Wood pile"
			notes.append("%s kg waiting for hauling" % Farm.kg(farm.wood_piles[cell]))
		elif farm.plowing.has(cell):
			_plot_label.text = "Plowing %d%%" % floori((1.0 - farm.plowing[cell] / Farm.PLOW_HOURS) * 100)
			notes.append("%s h left" % String.num(farm.plowing[cell], 1))
			if reasons: notes.append(reasons.keys()[0])
		else:
			notes.append(reasons.keys()[0] if reasons else NOTES[stage])
		if stage in ["Sown", "Ripe"]:
			_detail_label.tooltip_text = ("Expected harvest: about %s kg" if stage == "Sown" else "Harvest: %s kg") % Farm.kg(farm.harvest_yield(cell))
	else:
		_plot_label.text = "%d plots" % cells.size()
		for reason in reasons:
			notes.append(reason if reasons[reason] == 1 else "%s ×%d" % [reason, reasons[reason]])
	notes.append("soil %d%%" % roundi(soil / cells.size() * 100))
	_detail_label.text = "  ·  ".join(notes)
	_detail_label.tooltip_text += "\nArea: %d m² (%d m² per plot)" % [cells.size() * Farm.PLOT_AREA_M2, Farm.PLOT_AREA_M2]

## One line on what a crop needs and gives.
func _facts(crop: String) -> String:
	var kind: Dictionary = Farm.CROPS[crop]
	return "%s: sown %s, needs about %d warm days%s, dies at %d°C, %s kg seed per %d m² plot for about %s kg" % [crop, Farm.sowing_window(crop), kind.ripe, " and a winter" if kind.winter else "", kind.frost, Farm.kg(kind.seed), Farm.PLOT_AREA_M2, Farm.kg(kind.grain)]

## Opens contextual actions at the pointer, or above the farm panel for C/the button.
func open_action_menu(at := Vector2(-1, -1)) -> void:
	if at == Vector2(-1, -1):
		at = Vector2(get_viewport_rect().size.x / 2, get_global_rect().position.y - action_wheel.RADIUS - 28)
	action_wheel.open_at(at)
