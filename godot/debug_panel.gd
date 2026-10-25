extends PanelContainer
## Developer-only tuning panel, toggled with F3 in debug builds.

signal day_length_changed(seconds: float)

var day_length := SpinBox.new()

func _init(seconds_per_day: float) -> void:
	name = "DebugPanel"
	visible = false
	anchor_top = 1.0
	anchor_bottom = 1.0
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	offset_left = 14
	offset_bottom = -14
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.05, 0.05, 0.05, 0.85)
	box.set_corner_radius_all(6)
	box.set_content_margin_all(10)
	add_theme_stylebox_override("panel", box)

	var column := VBoxContainer.new()
	add_child(column)
	var title := Label.new()
	title.text = "Debug (F3)"
	title.add_theme_color_override("font_color", Color(1, 0.75, 0.3))
	column.add_child(title)
	var row := HBoxContainer.new()
	column.add_child(row)
	var label := Label.new()
	label.text = "Day length"
	row.add_child(label)
	day_length.min_value = 0.05
	day_length.max_value = 600
	day_length.step = 0.05
	day_length.suffix = "s"
	day_length.value = seconds_per_day
	day_length.custom_minimum_size.x = 110
	day_length.value_changed.connect(day_length_changed.emit)
	row.add_child(day_length)
