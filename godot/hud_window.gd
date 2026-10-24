extends PanelContainer
## Shared look of the HUD's windows (ledger, inventory, wiki): a gold-framed panel
## with a title, a close button and a scrolling body of striped rows.

const TimeHud := preload("res://time_hud.gd")
const MUTED := Color(0.94, 0.84, 0.63, 0.6)

## Rows go here; subclasses rebuild them when shown.
var body := VBoxContainer.new()
## Title on the left, close on the right; subclasses may add buttons between.
var header := HBoxContainer.new()
var _serif := TimeHud.serif_font()
var _scroll := ScrollContainer.new()
var _max_height := 0.0

func _init(title: String, key: String, width: float, max_height: float) -> void:
	name = title
	visible = false
	_max_height = max_height
	add_theme_stylebox_override("panel", TimeHud.box(TimeHud.INK, TimeHud.GOLD, 10, 2, Vector2(16, 12)))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	header.add_theme_constant_override("separation", 6)
	column.add_child(header)
	var label := _label(title, TimeHud.GOLD, 26, preload("res://assets/fonts/CormorantUnicase-Bold.ttf"))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	var close := Button.new()
	close.text = "×"
	close.tooltip_text = "Close (%s)" % key
	close.focus_mode = Control.FOCUS_NONE
	TimeHud.style_button(close, _serif)
	close.pressed.connect(hide)
	header.add_child(close)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size = Vector2(width, 0)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 0)
	_scroll.add_child(body)
	column.add_child(_scroll)

## Adds a button to the header, before the close button.
func _header_button(button: Button) -> void:
	button.focus_mode = Control.FOCUS_NONE
	TimeHud.style_button(button, _serif)
	header.add_child(button)
	header.move_child(button, header.get_child_count() - 2)

## Empties the body before a rebuild.
func _clear() -> void:
	for child in body.get_children():
		child.free()

## Sizes the scroll area to the rows, up to the window's maximum height.
func _fit() -> void:
	_scroll.custom_minimum_size.y = minf(body.get_combined_minimum_size().y, _max_height)

func _label(text: String, color := TimeHud.PARCHMENT, size := 14, font: Font = null) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font if font else _serif)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

## One striped table row of cells: each a String, Color (a swatch) or Control,
## sized by `widths`; `tooltip` explains the row on hover.
func _row(cells: Array, widths: Array, striped: bool, color := TimeHud.PARCHMENT, tooltip := "") -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", TimeHud.box(Color(TimeHud.GOLD, 0.08 if striped else 0.0), Color(0, 0, 0, 0), 4, 0, Vector2(6, 3)))
	panel.tooltip_text = tooltip
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	panel.add_child(row)
	for i in cells.size():
		var cell: Control
		if cells[i] is Color:
			cell = ColorRect.new()
			cell.color = cells[i]
			cell.custom_minimum_size = Vector2(12, 12)
			cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		elif cells[i] is Control:
			cell = cells[i]
		else:
			cell = _label(str(cells[i]), color)
		cell.custom_minimum_size.x = widths[i]
		cell.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(cell)
	body.add_child(panel)

## A thin bar filled to `share` (0–1) in `color`.
func _bar(share: float, color: Color, width: float) -> Control:
	var track := ColorRect.new()
	track.color = Color(TimeHud.GOLD, 0.15)
	track.custom_minimum_size = Vector2(width, 8)
	track.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var fill := ColorRect.new()
	fill.color = color
	fill.size = Vector2(width * clampf(share, 0.0, 1.0), 8)
	track.add_child(fill)
	return track
