extends PanelContainer
## Top-centre time panel: season emblem, date, week pips, weather, year progress and speed buttons.

signal speed_selected(speed: int)

const SPEEDS := [0, 1, 2, 4]
const SPEED_LABELS := ["❚❚", "▶", "▶▶", "▶▶▶"]
const SEASON_COLORS := [Color(0.56, 0.78, 0.38), Color(0.96, 0.77, 0.3), Color(0.86, 0.45, 0.2), Color(0.76, 0.88, 0.98)]
const GOLD := Color(0.85, 0.71, 0.43)
const PARCHMENT := Color(0.94, 0.84, 0.63)
const INK := Color(0.09, 0.07, 0.05, 0.9)

var _day := 0
var _season_label := Label.new()
var _detail_label := Label.new()
var _icon := Control.new()
var _pips := Control.new()
var _year_bar := Control.new()
var _buttons: Array[Button] = []
var _condition := "Clear"
var _weather_icon := Control.new()
var _temperature_label := Label.new()
var _condition_label := Label.new()

func _init() -> void:
	name = "TimeHud"
	anchor_left = 0.5
	anchor_right = 0.5
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	offset_top = 14
	add_theme_stylebox_override("panel", box(INK, GOLD, 10, 2, Vector2(18, 10)))

	var serif := serif_font()

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	add_child(column)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	column.add_child(row)

	_icon.custom_minimum_size = Vector2(44, 44)
	_icon.draw.connect(_draw_icon)
	row.add_child(_icon)

	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", -4)
	text.custom_minimum_size.x = 210
	_season_label.add_theme_font_override("font", preload("res://assets/fonts/CormorantUnicase-Bold.ttf"))
	_season_label.add_theme_font_size_override("font_size", 30)
	_season_label.add_theme_color_override("font_color", GOLD)
	_detail_label.add_theme_font_override("font", serif)
	_detail_label.add_theme_font_size_override("font_size", 15)
	_detail_label.add_theme_color_override("font_color", PARCHMENT)
	text.add_child(_season_label)
	text.add_child(_detail_label)
	row.add_child(text)

	_pips.custom_minimum_size = Vector2(7 * 16, 44)
	_pips.draw.connect(_draw_pips)
	row.add_child(_pips)

	row.add_child(VSeparator.new())
	_weather_icon.custom_minimum_size = Vector2(40, 44)
	_weather_icon.draw.connect(_draw_weather)
	row.add_child(_weather_icon)
	var weather_text := VBoxContainer.new()
	weather_text.add_theme_constant_override("separation", -2)
	weather_text.custom_minimum_size.x = 64
	weather_text.alignment = BoxContainer.ALIGNMENT_CENTER
	_temperature_label.add_theme_font_override("font", serif)
	_temperature_label.add_theme_font_size_override("font_size", 22)
	_temperature_label.add_theme_color_override("font_color", PARCHMENT)
	_condition_label.add_theme_font_override("font", serif)
	_condition_label.add_theme_font_size_override("font_size", 13)
	_condition_label.add_theme_color_override("font_color", GOLD)
	weather_text.add_child(_temperature_label)
	weather_text.add_child(_condition_label)
	row.add_child(weather_text)

	row.add_child(VSeparator.new())
	var group := ButtonGroup.new()
	for i in SPEEDS.size():
		var button := Button.new()
		button.text = SPEED_LABELS[i]
		button.tooltip_text = "Pause (Space)" if i == 0 else "Speed %d× (key %d)" % [SPEEDS[i], i]
		button.toggle_mode = true
		button.button_group = group
		# Keyboard focus would let Space press a button instead of toggling pause.
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(44, 34)
		style_button(button, serif)
		button.pressed.connect(func() -> void: speed_selected.emit(SPEEDS[i]))
		_buttons.append(button)
		row.add_child(button)

	_year_bar.custom_minimum_size = Vector2(0, 8)
	_year_bar.tooltip_text = "Year progress"
	_year_bar.draw.connect(_draw_year_bar)
	column.add_child(_year_bar)

func show_time(day: int, speed: int, weather: Dictionary) -> void:
	_day = day
	_condition = weather.condition
	_temperature_label.text = "%d°C" % weather.temperature
	_condition_label.text = weather.condition
	var d := Calendar.date(day)
	_season_label.text = Calendar.SEASONS[d.season]
	_detail_label.text = "Month %d  ·  Week %d  ·  Year %d" % [d.month, d.week, d.year]
	for i in _buttons.size():
		_buttons[i].set_pressed_no_signal(SPEEDS[i] == speed)
	_icon.queue_redraw()
	_pips.queue_redraw()
	_year_bar.queue_redraw()
	_weather_icon.queue_redraw()

func _draw_weather() -> void:
	var c := _weather_icon.size / 2.0
	var sun := Color(0.96, 0.77, 0.3)
	var cloud := Color(0.8, 0.8, 0.78) if _condition == "Cloudy" else Color(0.55, 0.57, 0.6)
	if _condition == "Clear":
		for i in 8:
			var dir := Vector2.from_angle(i * TAU / 8)
			_weather_icon.draw_line(c + dir * 10, c + dir * 15, sun, 2, true)
		_weather_icon.draw_circle(c, 7, sun)
		return
	if _condition == "Cloudy":
		_weather_icon.draw_circle(c + Vector2(7, -6), 6, sun)
	var top := c + Vector2(0, -4)
	for blob in [[Vector2(-8, 3), 6.0], [Vector2(0, -1), 8.0], [Vector2(8, 3), 6.0]]:
		_weather_icon.draw_circle(top + blob[0], blob[1], cloud)
	_weather_icon.draw_rect(Rect2(top + Vector2(-8, 3), Vector2(16, 6)), cloud)
	match _condition:
		"Rain", "Storm":
			for x in [-7, 0, 7]:
				_weather_icon.draw_line(c + Vector2(x, 9), c + Vector2(x - 3, 16), Color(0.55, 0.75, 0.95), 2, true)
			if _condition == "Storm":
				_weather_icon.draw_polyline(PackedVector2Array([c + Vector2(2, 6), c + Vector2(-2, 12), c + Vector2(3, 12), c + Vector2(-1, 19)]), sun, 2, true)
		"Snow":
			for x in [-7, 0, 7]:
				_weather_icon.draw_circle(c + Vector2(x, 12 + absf(x) * 0.4), 2, Color(0.92, 0.95, 1))

func _draw_icon() -> void:
	var season: int = Calendar.date(_day).season
	var color: Color = SEASON_COLORS[season]
	var c := _icon.size / 2.0
	_icon.draw_circle(c, 21, INK.lightened(0.08))
	_icon.draw_arc(c, 21, 0, TAU, 40, GOLD, 1.5, true)
	match season:
		0: # Spring: a sprout.
			_icon.draw_line(c + Vector2(0, 12), c + Vector2(0, -2), color, 2.5, true)
			_icon.draw_colored_polygon(_leaf(c + Vector2(0, -2), Vector2(-11, -8)), color)
			_icon.draw_colored_polygon(_leaf(c + Vector2(0, 2), Vector2(10, -6)), color)
		1: # Summer: a sun.
			for i in 8:
				var dir := Vector2.from_angle(i * TAU / 8)
				_icon.draw_line(c + dir * 10, c + dir * 16, color, 2.5, true)
			_icon.draw_circle(c, 8, color)
		2: # Autumn: a falling leaf.
			_icon.draw_colored_polygon(_leaf(c + Vector2(-8, 9), Vector2(16, -18)), color)
			_icon.draw_line(c + Vector2(-11, 12), c + Vector2(-6, 7), color, 2, true)
		3: # Winter: a snowflake.
			for i in 3:
				var dir := Vector2.from_angle(i * PI / 3 + PI / 2) * 14
				_icon.draw_line(c - dir, c + dir, color, 2.5, true)
			_icon.draw_circle(c, 3, color)

func _leaf(base: Vector2, reach: Vector2) -> PackedVector2Array:
	var side := reach.orthogonal().normalized() * reach.length() * 0.3
	return PackedVector2Array([base, base + reach * 0.5 + side, base + reach, base + reach * 0.5 - side])

func _draw_pips() -> void:
	var today: int = Calendar.date(_day).day
	for i in 7:
		var c := Vector2(8 + i * 16, _pips.size.y / 2.0)
		if i + 1 == today:
			_pips.draw_circle(c, 6, GOLD.lightened(0.2))
		elif i + 1 < today:
			_pips.draw_circle(c, 4, GOLD.darkened(0.2))
		else:
			_pips.draw_arc(c, 4, 0, TAU, 16, GOLD.darkened(0.45), 1.5, true)

func _draw_year_bar() -> void:
	var width := _year_bar.size.x
	var height := _year_bar.size.y
	var progress := float(_day % Calendar.DAYS_PER_YEAR) / Calendar.DAYS_PER_YEAR
	for s in 4:
		var rect := Rect2(width * s / 4.0 + 1, 2, width / 4.0 - 2, height - 4)
		_year_bar.draw_rect(rect, Color(SEASON_COLORS[s], 0.25))
		var filled := clampf(progress * width - rect.position.x, 0, rect.size.x)
		_year_bar.draw_rect(Rect2(rect.position, Vector2(filled, rect.size.y)), SEASON_COLORS[s])
	var x := progress * width
	_year_bar.draw_rect(Rect2(x - 1.5, 0, 3, height), PARCHMENT)

## Serif HUD text font, shared with the farm panel and ledger.
static func serif_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Georgia", "Noto Serif", "DejaVu Serif"])
	return font

## Gold-outlined HUD button look, shared with the farm panel.
static func style_button(button: Button, font: Font) -> void:
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", PARCHMENT)
	button.add_theme_color_override("font_pressed_color", INK)
	button.add_theme_color_override("font_hover_pressed_color", INK)
	button.add_theme_color_override("font_disabled_color", PARCHMENT.darkened(0.5))
	button.add_theme_stylebox_override("normal", box(Color(0, 0, 0, 0), GOLD.darkened(0.4), 6, 1, Vector2(6, 4)))
	button.add_theme_stylebox_override("hover", box(Color(GOLD, 0.15), GOLD, 6, 1, Vector2(6, 4)))
	button.add_theme_stylebox_override("pressed", box(GOLD, GOLD, 6, 1, Vector2(6, 4)))
	button.add_theme_stylebox_override("hover_pressed", box(GOLD.lightened(0.15), GOLD, 6, 1, Vector2(6, 4)))
	button.add_theme_stylebox_override("disabled", box(Color(0, 0, 0, 0), GOLD.darkened(0.65), 6, 1, Vector2(6, 4)))

static func box(fill: Color, border: Color, radius: int, border_width: int, padding: Vector2) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(radius)
	box.content_margin_left = padding.x
	box.content_margin_right = padding.x
	box.content_margin_top = padding.y
	box.content_margin_bottom = padding.y
	return box
