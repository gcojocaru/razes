extends "res://hud_window.gd"
## Peasant creation, opened by Play over the menu. The first page makes the peasant:
## a name, the body the needs simulation runs on (height, weight and body fat) with
## what it means for food and work, and looks, beside a preview the player turns by
## dragging or with the buttons under it. Next chooses the land, a preset or Custom
## hills and ponds. Begin starts the game as this peasant on that land.

const HumanActor := preload("res://human_actor.gd")
const Terrain := preload("res://terrain.gd")
const SERIF_BOLD := preload("res://assets/fonts/CormorantUnicase-Bold.ttf")
## Weight is kept between full health (BMI 18.5) and obese (30) at the chosen height.
const BMIS := Vector2(18.5, 30.0)
## Each land's description; the presets' hills and ponds are Terrain.PRESETS.
const LANDS := {
	"Steppe": "Low, open land with one pond: the most farmland",
	"Hills": "Rolling hills with two ponds; some slopes are too steep to farm",
	"Lakeland": "Gentle hills between four ponds; the farmer walks around the water",
	"Custom": "Choose how high the hills rise and how many ponds lie in the field",
}
## Old Romanian and Moldovan men's names for the Random name button.
const NAMES := ["Ion", "Vasile", "Gheorghe", "Dumitru", "Nicolae", "Constantin", "Toader", "Ștefan", "Ilie", "Petru", "Andrei", "Savu", "Lupu", "Pătru", "Ghiță", "Stan", "Simion", "Ursu", "Neculai", "Costache", "Iordache", "Zaharia", "Gavril", "Matei", "Sandu", "Oprea", "Grigore", "Nistor", "Tudor", "Florea", "Mitru", "Ioniță", "Chirilă", "Arsenie"]
## Radians the preview turns per pixel dragged, and per second a turn button is held.
const DRAG_TURN := 0.01
const TURN_SPEED := 2.0

var name_edit := LineEdit.new()
var next := Button.new()
var begin := Button.new()
## "Height", "Weight", "Body fat", "Hills" and "Ponds".
var sliders := {}
## Each look ("skin") -> option -> its button.
var looks := {}
## What Begin starts the game with; Human.create() and HumanActor.dress() read it.
var peasant := {}
## Each of LANDS -> its button.
var lands := {}
## The land Begin starts the game on: {"hills": metres, "ponds"}.
var land := {}
var _land_group := ButtonGroup.new()
var _values := {}
var _info := _label("")
var _land_note := _label("", MUTED, 14)
var _character := VBoxContainer.new()
var _land_page := VBoxContainer.new()
var _back := Button.new()
var _person := Human.new()
var _actor := HumanActor.new(1.0)
## The preview's render and where it is shown.
var _view := SubViewport.new()
var _frame := TextureRect.new()
var _turn := 0.6
## -1 while the left turn button is held, 1 for the right, else 0.
var _turning := 0.0

func _init() -> void:
	super("Your peasant", "Escape", 0, 0)
	name = "Creation"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_theme_stylebox_override("panel", TimeHud.box(Color(TimeHud.INK, 1.0), Color(0, 0, 0, 0), 0, 0, Vector2(28, 20)))
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 32)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(main)
	main.add_child(_preview())
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 16)
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	form.custom_minimum_size.x = 520
	main.add_child(form)
	form.add_child(_character)
	form.add_child(_land_page)
	_land_page.add_theme_constant_override("separation", 16)
	name_edit.text = _person.name
	name_edit.max_length = 24
	name_edit.placeholder_text = "Name your peasant"
	name_edit.select_all_on_focus = true
	# A refused Next or Begin leaves the name ready to fix.
	name_edit.keep_editing_on_text_submit = true
	name_edit.add_theme_font_override("font", _serif)
	name_edit.add_theme_font_size_override("font_size", 18)
	name_edit.text_changed.connect(func(_text: String) -> void: _changed())
	name_edit.text_submitted.connect(func(_text: String) -> void: _submit_name())
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	name_row.add_child(name_edit)
	var random_name := Button.new()
	random_name.name = "RandomName"
	random_name.text = "Random name"
	_choice_style(random_name, 15)
	random_name.tooltip_text = "An old Romanian or Moldovan name"
	random_name.pressed.connect(_random_name)
	name_row.add_child(random_name)
	_field(_grid(_section(_character, "Name")), "Name", name_row)
	var section := _section(_character, "Body")
	_slider(section, "Height", 1.55, 1.85, 0.01, _person.height, "Taller bodies have a lower BMI at the same weight")
	_slider(section, "Weight", 40.0, 110.0, 1.0, _person.mass(), "From full health at a BMI of 18.5 to 30 at this height")
	_slider(section, "Body fat", 8.0, 30.0, 1.0, _person.fat / _person.mass() * 100.0, "The rest is lean mass: muscle, organs and bone")
	section.add_child(_info)
	var about := _label("Lean mass raises the metabolism and holds more ready energy; fat lasts longer without food; every kilogram makes walking and work dearer.", MUTED, 13)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(about)
	section = _section(_character, "Looks")
	var grid := _grid(section)
	# Hair and facial hair come back with their models; everyone wears the same clothes.
	_choices(grid, "skin", HumanActor.SKINS)
	var random_look := Button.new()
	random_look.name = "RandomLook"
	random_look.text = "Random skin"
	_choice_style(random_look, 15)
	random_look.tooltip_text = "Chooses a skin tone at random"
	random_look.pressed.connect(_random_looks)
	section.add_child(random_look)
	section = _section(_land_page, "Land")
	grid = _grid(section)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	_field(grid, "Preset", row)
	for option in LANDS:
		var button := Button.new()
		button.text = option
		button.toggle_mode = true
		button.button_group = _land_group
		_choice_style(button, 16)
		button.custom_minimum_size = Vector2(124, 40)
		button.toggled.connect(func(on: bool) -> void:
			if on:
				_changed())
		row.add_child(button)
		lands[option] = button
	lands.Hills.set_pressed_no_signal(true)
	_slider(section, "Hills", 0.0, Terrain.MAX_HILLS, 1.0, 18.0, "How many metres the field's hills rise; Custom sets it")
	_slider(section, "Ponds", 0.0, 4.0, 1.0, 2.0, "How many ponds lie in the field; Custom sets it")
	_land_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	section.add_child(_land_note)
	_footer()
	_changed()

## Back, Next and Begin at the foot of the screen; each page shows its own.
func _footer() -> void:
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_back.text = "Back"
	_choice_style(_back, 18)
	_back.custom_minimum_size = Vector2(160, 52)
	_back.pressed.connect(_show_page.bind(false))
	next.text = "Next: Land"
	_choice_style(next, 22)
	next.custom_minimum_size = Vector2(220, 52)
	next.pressed.connect(_show_page.bind(true))
	begin.text = "Begin"
	_choice_style(begin, 22)
	begin.custom_minimum_size = Vector2(220, 52)
	begin.pressed.connect(_begin)
	footer.add_child(_back)
	footer.add_child(spacer)
	footer.add_child(next)
	footer.add_child(begin)
	header.get_parent().add_child(footer)

## Shows the character page or the land page with its own buttons.
func _show_page(land_page: bool) -> void:
	_character.visible = not land_page
	_land_page.visible = land_page
	_back.visible = land_page
	next.visible = not land_page
	begin.visible = land_page
	if not land_page:
		name_edit.grab_focus()

## Enter in the name goes on to the land once the name is set, and begins from there.
func _submit_name() -> void:
	# LineEdit reports typing a frame late, so read the name now.
	_changed()
	if _land_page.visible:
		_begin()
	elif not next.disabled:
		_show_page(true)

## Shows the screen on the character page with the name ready to type over.
func open() -> void:
	show()
	_show_page(false)

## The peasant on a patch of bare earth, turned by dragging or the buttons below.
func _preview() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	var stage := Control.new()
	stage.name = "Preview"
	stage.custom_minimum_size = Vector2(280, 480)
	stage.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(stage)
	# Shown as a texture rather than in a SubViewportContainer, which renders at the layout's size and stretches it
	# when the window scales the layout up; _process sizes the render to the screen pixels it covers.
	_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(_frame)
	var view := _view
	view.own_world_3d = true
	view.transparent_bg = true
	view.msaa_3d = Viewport.MSAA_4X
	_frame.add_child(view)
	_frame.texture = view.get_texture()
	# Over the view, so the drag reaches it before the viewport does.
	var drag := Control.new()
	drag.name = "Turn"
	drag.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drag.mouse_default_cursor_shape = Control.CURSOR_DRAG
	drag.tooltip_text = "Drag to turn the peasant"
	drag.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_turn_by(event.relative.x * DRAG_TURN))
	stage.add_child(drag)
	var turns := HBoxContainer.new()
	turns.alignment = BoxContainer.ALIGNMENT_CENTER
	turns.add_theme_constant_override("separation", 12)
	column.add_child(turns)
	for turn in [["TurnLeft", -1.0], ["TurnRight", 1.0]]:
		var button := _turn_button(turn[1])
		button.name = turn[0]
		button.tooltip_text = "Hold to turn the peasant " + ("left" if turn[1] < 0 else "right")
		turns.add_child(button)
	_person.position = Vector2.ZERO
	_actor.get_node("Locator").hide()
	_actor.get_node("Name").hide()
	view.add_child(_actor)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.55
	disc.bottom_radius = 0.55
	disc.height = 0.02
	disc.radial_segments = 24
	var earth := MeshInstance3D.new()
	earth.mesh = disc
	earth.material_override = StandardMaterial3D.new()
	earth.material_override.albedo_color = Color("5a4d39")
	earth.position.y = -0.01
	view.add_child(earth)
	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(Basis(), Vector3(-1.2, 2.5, 2.0)).looking_at(Vector3(0, 0.9, 0))
	sun.light_color = Color(1.0, 0.95, 0.86)
	# The lights and ambient add up to about white on the linen: this renderer clips anything brighter flat.
	sun.light_energy = 0.65
	sun.shadow_enabled = true
	sun.shadow_blur = 2.0
	view.add_child(sun)
	# A cool fill from the other side, and a rim from behind to lift the figure off the dark panel.
	for light in [[Vector3(2.0, 1.2, 1.5), Color(0.75, 0.82, 1.0), 0.2], [Vector3(0.8, 2.2, -2.5), Color(1.0, 0.92, 0.8), 0.45]]:
		var lamp := DirectionalLight3D.new()
		lamp.transform = Transform3D(Basis(), light[0]).looking_at(Vector3(0, 0.9, 0))
		lamp.light_color = light[1]
		lamp.light_energy = light[2]
		view.add_child(lamp)
	var camera := Camera3D.new()
	camera.fov = 30.0
	camera.transform = Transform3D(Basis(), Vector3(0, 1.3, 4.4)).looking_at(Vector3(0, 0.9, 0))
	camera.environment = Environment.new()
	camera.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	camera.environment.ambient_light_color = Color(0.52, 0.48, 0.43)
	camera.environment.ambient_light_energy = 0.45
	view.add_child(camera)
	return column

func _turn_by(radians: float) -> void:
	_turn += radians

## An arrow icon that turns the peasant in `direction` (-1 left, 1 right) for as long as it is held.
func _turn_button(direction: float) -> Button:
	var button := Button.new()
	button.custom_minimum_size = Vector2(64, 48)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_choice_style(button, 15)
	button.draw.connect(func() -> void:
		var centre := button.size / 2
		var tip := centre + Vector2(10 * direction, 0)
		var back := -8 * direction
		button.draw_colored_polygon(PackedVector2Array([tip, centre + Vector2(back, -10), centre + Vector2(back, 10)]), TimeHud.PARCHMENT))
	button.button_down.connect(func() -> void: _turning = direction)
	button.button_up.connect(func() -> void: _turning = 0.0)
	return button

func _random_name() -> void:
	name_edit.text = NAMES.pick_random()
	_changed()

## Picks one option of each look at random; the buttons' toggles update `peasant`.
func _random_looks() -> void:
	for key in looks:
		looks[key][looks[key].keys().pick_random()].button_pressed = true

## A gold-ruled card with a title; returns the column to fill.
func _section(parent: Control, title: String) -> VBoxContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", TimeHud.box(Color(TimeHud.GOLD, 0.06), Color(TimeHud.GOLD, 0.3), 8, 1, Vector2(18, 12)))
	parent.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	card.add_child(column)
	column.add_child(_label(title, TimeHud.GOLD, 22, SERIF_BOLD))
	return column

func _grid(parent: Control) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 10)
	parent.add_child(grid)
	return grid

## A titled control and, after it, a label saying what it is set to, which it returns.
func _field(grid: GridContainer, title: String, control: Control) -> Label:
	var label := _label(title, TimeHud.PARCHMENT, 15)
	label.custom_minimum_size.x = 80
	grid.add_child(label)
	control.custom_minimum_size.x = 260
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(control)
	_values[title] = _label("", MUTED, 15)
	_values[title].custom_minimum_size.x = 110
	grid.add_child(_values[title])
	return _values[title]

## A slider with its title and setting above it, full width, in `parent`.
func _slider(parent: Control, title: String, low: float, high: float, step: float, value: float, tooltip: String) -> void:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	parent.add_child(column)
	var head := HBoxContainer.new()
	var label := _label(title, TimeHud.PARCHMENT, 16)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(label)
	_values[title] = _label("", MUTED, 16)
	head.add_child(_values[title])
	column.add_child(head)
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = value
	slider.tooltip_text = tooltip + " (arrow keys adjust)"
	slider.value_changed.connect(func(_value: float) -> void: _changed())
	sliders[title] = slider
	column.add_child(slider)

## Exclusive choices for look `key`, the first chosen: colour swatches from a
## Dictionary of colours, or words from an Array.
func _choices(grid: GridContainer, key: String, options: Variant) -> void:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	row.add_theme_constant_override("v_separation", 8)
	var chosen := _field(grid, key.capitalize(), row)
	var group := ButtonGroup.new()
	looks[key] = {}
	for option in options:
		var button := Button.new()
		button.toggle_mode = true
		button.button_group = group
		button.tooltip_text = option
		if options is Dictionary:
			_swatch(button, options[option])
		else:
			button.text = option
			_choice_style(button, 16)
			button.custom_minimum_size = Vector2(0, 40)
		button.toggled.connect(func(on: bool) -> void:
			if on:
				peasant[key] = option
				chosen.text = option if options is Dictionary else ""
				_changed())
		row.add_child(button)
		looks[key][option] = button
	var first: String = looks[key].keys()[0]
	looks[key][first].set_pressed_no_signal(true)
	peasant[key] = first
	chosen.text = first if options is Dictionary else ""

## A round swatch of `color`, ringed in parchment when chosen.
func _swatch(button: Button, color: Color) -> void:
	button.custom_minimum_size = Vector2(34, 34)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var rings := {"normal": [TimeHud.GOLD.darkened(0.4), 1], "hover": [TimeHud.GOLD, 2], "pressed": [TimeHud.PARCHMENT, 3], "hover_pressed": [TimeHud.PARCHMENT, 3]}
	for state in rings:
		button.add_theme_stylebox_override(state, TimeHud.box(color, rings[state][0], 17, rings[state][1], Vector2.ZERO))
	var focus := TimeHud.box(Color(0, 0, 0, 0), TimeHud.GOLD.lightened(0.3), 20, 2, Vector2.ZERO)
	focus.set_expand_margin_all(4)
	button.add_theme_stylebox_override("focus", focus)

## Gives a text button the house look at `size`, with room to click.
func _choice_style(button: Button, size: int) -> void:
	TimeHud.style_button(button, _serif)
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_stylebox_override("normal", TimeHud.box(Color(0, 0, 0, 0), TimeHud.GOLD.darkened(0.4), 8, 1, Vector2(14, 6)))
	button.add_theme_stylebox_override("hover", TimeHud.box(Color(TimeHud.GOLD, 0.15), TimeHud.GOLD, 8, 1, Vector2(14, 6)))
	button.add_theme_stylebox_override("pressed", TimeHud.box(TimeHud.GOLD, TimeHud.GOLD, 8, 1, Vector2(14, 6)))
	button.add_theme_stylebox_override("hover_pressed", TimeHud.box(TimeHud.GOLD.lightened(0.15), TimeHud.GOLD, 8, 1, Vector2(14, 6)))
	button.add_theme_stylebox_override("disabled", TimeHud.box(Color(0, 0, 0, 0), TimeHud.GOLD.darkened(0.65), 8, 1, Vector2(14, 6)))

## Reads every choice into `peasant` and shows the body it makes.
func _changed() -> void:
	var tall: float = sliders.Height.value
	sliders.Weight.min_value = ceilf(BMIS.x * tall * tall)
	sliders.Weight.max_value = floorf(BMIS.y * tall * tall)
	peasant.name = name_edit.text.strip_edges()
	peasant.height = tall
	peasant.weight = sliders.Weight.value
	peasant.body_fat = sliders["Body fat"].value / 100.0
	_values.Height.text = "%.2f m" % tall
	_values.Weight.text = "%d kg" % peasant.weight
	_values["Body fat"].text = "%d%%" % sliders["Body fat"].value
	_person.create(peasant)
	_actor.dress(peasant)
	_info.text = "BMI %.1f · %.1f kg lean, %.1f kg fat\nBasal %d kcal a day · ready energy %d kcal\nHoeing burns %d kcal an hour" % [_person.bmi(), _person.lean, _person.fat, roundi(_person.basal() * 24.0), roundi(_person.glycogen), roundi(_person.burn("Plow"))]
	# A preset shows its hills and ponds; only Custom moves them.
	var preset: String = _land_group.get_pressed_button().text
	_land_note.text = LANDS[preset]
	for title in ["Hills", "Ponds"]:
		sliders[title].editable = preset == "Custom"
		sliders[title].modulate.a = 1.0 if preset == "Custom" else 0.45
		if preset != "Custom":
			sliders[title].set_value_no_signal(Terrain.PRESETS[preset][title.to_lower()])
	land = {"hills": sliders.Hills.value, "ponds": int(sliders.Ponds.value)}
	_values.Hills.text = "%d m" % land.hills
	_values.Ponds.text = str(land.ponds)
	begin.disabled = peasant.name == ""
	next.disabled = begin.disabled
	begin.tooltip_text = "Name your peasant first" if begin.disabled else "Start farming as %s (Enter in the name field)" % peasant.name
	next.tooltip_text = "Name your peasant first" if next.disabled else "Choose the land for %s" % peasant.name

func _begin() -> void:
	# LineEdit reports typing a frame late, so read the name now.
	_changed()
	if begin.disabled:
		return
	Human.peasant = peasant.duplicate()
	preload("res://game.gd").choose_camp = true
	Terrain.land = land.duplicate()
	var error := get_tree().change_scene_to_file("res://game.tscn")
	if error != OK:
		push_error("Could not open the game scene: " + error_string(error))

func _process(delta: float) -> void:
	if visible:
		var pixels := Vector2i((_frame.size * (get_viewport().get_final_transform() * _frame.get_global_transform_with_canvas()).get_scale()).ceil())
		if _view.size != pixels:
			_view.size = pixels
		_turn += _turning * TURN_SPEED * delta
		_person.facing = Vector2(sin(_turn), cos(_turn))
		_actor.show_person(_person, delta)

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide()
