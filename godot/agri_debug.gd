extends PanelContainer
## Developer-only agriculture tools, toggled with F4 in debug builds: fill the
## store, skip time, and set the crop, stage, growth and soil of the selected plots.

var game: Node3D
var crop := OptionButton.new()
var stage := OptionButton.new()
var growth := HSlider.new()
var fertility := HSlider.new()
var info := Label.new()

func _init(owner_game: Node3D) -> void:
	game = owner_game
	name = "AgricultureDebug"
	visible = false
	# Bottom left, above the F3 panel, clear of the inventory.
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = 14
	offset_bottom = -110
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.05, 0.05, 0.85)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(10)
	add_theme_stylebox_override("panel", box)

	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 280
	add_child(column)
	var title := Label.new()
	title.text = "Agriculture debug (F4)"
	title.add_theme_color_override("font_color", Color(1, 0.75, 0.3))
	column.add_child(title)

	var fill := Button.new()
	fill.text = "Add 100 kg of each crop"
	fill.pressed.connect(func() -> void:
		for name in Farm.CROPS:
			game.farm.stock[name] += 100000
		game._show_farm())
	column.add_child(fill)
	var skips := HBoxContainer.new()
	for skip in [["+1 day", 1], ["+1 week", Calendar.DAYS_PER_WEEK], ["+1 month", Calendar.DAYS_PER_MONTH], ["Next season", 0]]:
		var button := Button.new()
		button.text = skip[0]
		button.pressed.connect(func() -> void:
			game.skip_days(skip[1] if skip[1] else Calendar.DAYS_PER_SEASON - game.day % Calendar.DAYS_PER_SEASON))
		skips.add_child(button)
	column.add_child(skips)

	column.add_child(HSeparator.new())
	crop.add_item("No crop")
	for name in Farm.CROPS:
		crop.add_item(name)
	_row(column, "Crop", crop)
	for name in Farm.STAGES:
		stage.add_item(name)
	_row(column, "Stage", stage)
	growth.max_value = 1.0
	growth.step = 0.01
	_row(column, "Growth", growth)
	fertility.min_value = Farm.MIN_FERTILITY
	fertility.max_value = 1.0
	fertility.step = 0.01
	fertility.value = 1.0
	_row(column, "Soil", fertility)
	var apply := Button.new()
	apply.text = "Apply to selected plots"
	apply.pressed.connect(apply_to_selected)
	column.add_child(apply)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	column.add_child(info)

func _row(column: VBoxContainer, text: String, control: Control) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = 60
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	column.add_child(row)

## Overwrites the selected plots with the chosen crop, stage, growth and soil.
## A standing crop needs a crop type, so "No crop" falls back to the first.
func apply_to_selected() -> void:
	var stage_name := stage.get_item_text(stage.selected)
	var crop_name := "" if crop.selected == 0 else crop.get_item_text(crop.selected)
	if stage_name in ["Sown", "Ripe"] and crop_name == "":
		crop_name = Farm.CROPS.keys()[0]
	for cell in game.selected:
		# Winter counts as lived through, so a winter crop set mid-growth keeps ripening.
		game.farm.plots[cell] = {"stage": stage_name, "crop": crop_name, "growth": 1.0 if stage_name == "Ripe" else growth.value, "fertility": fertility.value, "wintered": true, "moisture": 0.0, "days": 0}
	game._show_farm()

## Shows the first selected plot's raw state.
func refresh() -> void:
	var cells: Array = game.selected.keys()
	if cells.is_empty():
		info.text = "Select plots to edit them."
		return
	var cell: Vector2i = cells[0]
	info.text = "%d selected. %s: %s" % [cells.size(), cell, game.farm.plots.get(cell, "untouched grass")]
