extends Control
## Contextual action wheel. Native buttons use annular hit targets; the overlay
## consumes outside clicks so dismissing it cannot change the field selection.

signal activated(action: String, crop: String)

const TimeHud := preload("res://time_hud.gd")
const RADIUS := 182.0
const HUB := 82.0
const MARGIN := 12.0
const ICONS := {
	"Plow": preload("res://assets/actions/plow.svg"),
	"Harvest": preload("res://assets/actions/harvest.svg"),
	"Eat": preload("res://assets/actions/eat.svg"),
	"Sleep": preload("res://assets/actions/sleep.svg"),
	"Barley": preload("res://assets/actions/barley.svg"),
	"Oats": preload("res://assets/actions/oats.svg"),
	"Millet": preload("res://assets/actions/millet.svg"),
	"Wheat": preload("res://assets/actions/wheat.svg"),
	"Rye": preload("res://assets/actions/rye.svg"),
}

class Segment extends Button:
	var begin := 0.0
	var span := TAU

	func _has_point(point: Vector2) -> bool:
		var offset := point - Vector2.ONE * RADIUS
		return offset.length() >= HUB and offset.length() <= RADIUS and fposmod(offset.angle() - begin, TAU) <= span

var entries: Array[Dictionary] = []
var hub_detail := Label.new()
var _hub_title := Label.new()
var _hint := Label.new()
var _farm: Farm
var _cells: Array = []
var _day := 0
var _seed_crop := ""
var _origin := Vector2.ZERO
var _focused := 0
var _buttons: Array[Button] = []
var _font := TimeHud.serif_font()
var _title := "Fields"
var _detail := "Select land to work"

func _init() -> void:
	name = "ActionWheel"
	visible = false
	set_as_top_level(true)
	z_index = 20
	mouse_filter = Control.MOUSE_FILTER_STOP
	for label in [_hub_title, hub_detail, _hint]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size = Vector2(140, 58)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_override("font", _font)
		label.add_theme_font_size_override("font_size", 13)
		label.add_theme_color_override("font_color", TimeHud.PARCHMENT)
		add_child(label)
	hub_detail.max_lines_visible = 3
	hub_detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	hub_detail.mouse_filter = Control.MOUSE_FILTER_PASS
	_hub_title.add_theme_font_override("font", preload("res://assets/fonts/CormorantUnicase-Bold.ttf"))
	_hub_title.add_theme_font_size_override("font_size", 22)
	_hub_title.add_theme_color_override("font_color", TimeHud.GOLD)
	_hint.add_theme_stylebox_override("normal", TimeHud.box(TimeHud.INK, Color.TRANSPARENT, 5, 0, Vector2(8, 2)))
	_hint.text = "Arrows · Enter   /   Esc to close"
	_hint.add_theme_font_size_override("font_size", 12)

func _ready() -> void:
	get_viewport().size_changed.connect(func() -> void: size = get_viewport_rect().size)

func show_farm(farm: Farm, cells: Array, day: int, seed_crop: String, queued: Array = []) -> void:
	_farm = farm
	_cells = cells.filter(func(cell): return cell not in queued)
	_day = day
	_seed_crop = seed_crop
	var next: Array[Dictionary] = []
	for action in Farm.ACTIONS:
		var crops: Array = Farm.sowable(day) if action == "Sow" else [""]
		for crop: String in crops:
			var result := farm.preview(_cells, day, action, crop)
			if result.plots > 0:
				next.append({"action": action, "crop": crop, "plots": result.plots, "grain": result.grain})
	_title = "Fields"
	_detail = "Select land to work"
	if not cells.is_empty():
		_title = "%d plots" % cells.size()
		_detail = "Choose an action"
		if cells.size() == 1:
			var cell: Vector2i = cells[0]
			_title = farm.stage(cell)
			if _title == "Sown":
				_title = "%s %d%%" % [farm.crop(cell), floori(farm.growth(cell) * 100)]
			elif _title == "Ripe":
				_title = "Ripe " + farm.crop(cell).to_lower()
			if farm.terrain != null and farm.terrain.cell_reason(cell) != "":
				_title = farm.terrain.cell_reason(cell)
			_detail = "Soil %d%%" % roundi(farm.fertility(cell) * 100)
		if next.is_empty():
			var reasons := PackedStringArray()
			for cell: Vector2i in cells:
				var reason: String = "Work already queued" if cell in queued else farm.action(cell, day, seed_crop).reason
				if reason != "" and reason not in reasons:
					reasons.append(reason)
			_detail = "\n".join(reasons)
	var changed := next != entries
	entries = next
	if changed and visible:
		_build_buttons()
		_place_labels()
	_show_hub()
	queue_redraw()

func open_at(at: Vector2) -> void:
	position = Vector2.ZERO
	size = get_viewport_rect().size
	_origin = at.clamp(Vector2.ONE * (RADIUS + MARGIN), size - Vector2(RADIUS + MARGIN, RADIUS + MARGIN + 26))
	visible = true
	_build_buttons()
	_place_labels()
	queue_redraw()

func wheel_rect() -> Rect2:
	return Rect2(_origin - Vector2.ONE * RADIUS, Vector2.ONE * RADIUS * 2)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and visible and is_inside_tree():
		_origin = _origin.clamp(Vector2.ONE * (RADIUS + MARGIN), size - Vector2(RADIUS + MARGIN, RADIUS + MARGIN + 26))
		_place_labels()
		for button in _buttons:
			button.position = wheel_rect().position
		queue_redraw()

func _build_buttons() -> void:
	var previous := ""
	if not _buttons.is_empty() and _focused < _buttons.size():
		previous = _buttons[_focused].text
	for button in _buttons:
		remove_child(button)
		button.queue_free()
	_buttons.clear()
	_focused = 0
	for i in entries.size():
		var entry := entries[i]
		var button := Segment.new()
		button.begin = _angle(i) - PI / entries.size()
		button.span = TAU / entries.size()
		button.position = wheel_rect().position
		button.size = Vector2.ONE * RADIUS * 2
		button.text = _label(entry) + ": " + _effect(entry)
		button.tooltip_text = _tooltip(entry)
		for style in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			button.add_theme_stylebox_override(style, StyleBoxEmpty.new())
		for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color", "font_outline_color"]:
			button.add_theme_color_override(state, Color.TRANSPARENT)
		button.pressed.connect(_activate.bind(i))
		button.mouse_entered.connect(_focus_entry.bind(i))
		button.focus_entered.connect(_focus_entry.bind(i))
		add_child(button)
		_buttons.append(button)
		if button.text == previous or (previous == "" and _seed_crop != "" and entry.crop == _seed_crop):
			_focused = i
	if not _buttons.is_empty():
		_buttons[_focused].grab_focus()
	_show_hub()

func _place_labels() -> void:
	_hub_title.position = _origin + Vector2(-72, -51)
	_hub_title.size = Vector2(144, 55)
	hub_detail.position = _origin + Vector2(-70, 5)
	hub_detail.size = Vector2(140, 58)
	_hint.position = _origin + Vector2(-RADIUS, (RADIUS if not entries.is_empty() else HUB) + 2)
	_hint.size = Vector2(RADIUS * 2, 22)
	# Keep the keyboard hint inside the viewport even when the wheel hugs its bottom.
	_hint.position.y = minf(_hint.position.y, size.y - 24)

func _show_hub() -> void:
	_hub_title.text = _title
	hub_detail.text = _detail
	hub_detail.tooltip_text = _detail
	if visible and not entries.is_empty():
		_focused = mini(_focused, entries.size() - 1)
		hub_detail.text = _effect(entries[_focused])

func _focus_entry(index: int) -> void:
	_focused = index
	_show_hub()
	queue_redraw()

func _activate(index: int) -> void:
	var entry := entries[index]
	# Time and stock may have changed since the press began.
	if _farm.preview(_cells, _day, entry.action, entry.crop).plots == 0:
		show_farm(_farm, _cells, _day, _seed_crop)
		return
	hide()
	activated.emit(entry.action, entry.crop)

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey:
		return
	get_viewport().set_input_as_handled()
	if not event.pressed:
		return
	match event.physical_keycode:
		KEY_ESCAPE:
			hide()
		KEY_LEFT, KEY_UP, KEY_RIGHT, KEY_DOWN, KEY_TAB:
			if not _buttons.is_empty():
				var backwards: bool = event.physical_keycode in [KEY_LEFT, KEY_UP] or (event.physical_keycode == KEY_TAB and event.shift_pressed)
				_focused = posmod(_focused + (-1 if backwards else 1), _buttons.size())
				_buttons[_focused].grab_focus()
		KEY_ENTER, KEY_KP_ENTER:
			if not entries.is_empty() and not event.echo:
				_activate(_focused)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		accept_event()
		if not event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			hide()

func _angle(index: int) -> float:
	return -PI / 2 + index * TAU / entries.size()

func _label(entry: Dictionary) -> String:
	return "Sow " + entry.crop if entry.action == "Sow" else entry.action

func _effect(entry: Dictionary) -> String:
	return "%d plot%s" % [entry.plots, "s" if entry.plots != 1 else ""] + ("\n%s%s kg %s" % ["+" if entry.grain > 0 else "", Farm.kg(entry.grain), entry.crop.to_lower() + " seed" if entry.action == "Sow" else "grain"] if entry.grain != 0 else "\nPrepare for sowing")

func _tooltip(entry: Dictionary) -> String:
	return _label(entry) + ": " + _effect(entry) + "\nQueue this work for the farmer" + ("\nSown " + Farm.sowing_window(entry.crop) if entry.crop != "" else "")

func _summary(entry: Dictionary) -> String:
	return "%d plot%s" % [entry.plots, "s" if entry.plots != 1 else ""] + (" · %s%s kg" % ["+" if entry.grain > 0 else "", Farm.kg(entry.grain)] if entry.grain != 0 else "")

func _draw() -> void:
	draw_circle(_origin + Vector2(0, 5), (RADIUS if not entries.is_empty() else HUB) + 5, Color(0, 0, 0, 0.25))
	draw_circle(_origin, HUB, TimeHud.INK)
	for i in entries.size():
		var angle := _angle(i)
		var half := PI / entries.size()
		var gap := 0.012 if entries.size() > 1 else 0.0
		var from := angle - half + gap
		var to := angle + half - gap
		var color := Color(0.23, 0.22, 0.14, 0.98) if i == _focused else Color(0.10, 0.095, 0.075, 0.97)
		draw_arc(_origin, (RADIUS + HUB) / 2, from, to, 96, color, RADIUS - HUB, true)
		draw_arc(_origin, RADIUS, from, to, 96, TimeHud.GOLD, 1.5, true)
		if entries.size() > 1:
			for edge in [from, to]:
				var dir := Vector2.from_angle(edge)
				draw_line(_origin + dir * HUB, _origin + dir * RADIUS, TimeHud.GOLD.darkened(0.25), 1, true)
		var at := _origin + Vector2.from_angle(angle) * ((RADIUS + HUB) / 2)
		var icon: Texture2D = ICONS[entries[i].crop if entries[i].crop != "" else entries[i].action]
		draw_texture_rect(icon, Rect2(at + Vector2(-23, -46), Vector2(46, 46)), false)
		_text(at + Vector2(0, 20), _label(entries[i]), 17, TimeHud.PARCHMENT)
		_text(at + Vector2(0, 37), _summary(entries[i]), 12, TimeHud.GOLD)
	draw_arc(_origin, HUB, 0, TAU, 96, TimeHud.GOLD, 1.5, true)

func _text(at: Vector2, text: String, font_size: int, color: Color) -> void:
	var width := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(_font, at - Vector2(width / 2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
