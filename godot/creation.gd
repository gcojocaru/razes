extends "res://hud_window.gd"
## Peasant creation, opened by Play over the menu: a name, the body the needs
## simulation runs on (height, weight and body fat) with what it means for food and
## work, and looks, beside a turning preview. Begin starts the game as this peasant.

const HumanActor := preload("res://human_actor.gd")
## Weight is kept between full health (BMI 18.5) and obese (30) at the chosen height.
const BMIS := Vector2(18.5, 30.0)

var name_edit := LineEdit.new()
var begin := Button.new()
## "Height", "Weight" and "Body fat".
var sliders := {}
## Each look ("skin", "hair", "beard", "clothes") -> option -> its button.
var looks := {}
## What Begin starts the game with; Human.create() and HumanActor.dress() read it.
var peasant := {}
var _values := {}
var _info := _label("")
var _person := Human.new()
var _actor := HumanActor.new(1.0)
var _turn := 0.6

func _init() -> void:
	super("Your peasant", "Escape", 800, 700)
	name = "Creation"
	anchor_left = 0.5
	anchor_top = 0.5
	anchor_right = 0.5
	anchor_bottom = 0.5
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	body.minimum_size_changed.connect(_fit)
	var main := HBoxContainer.new()
	main.add_theme_constant_override("separation", 24)
	body.add_child(main)
	main.add_child(_preview())
	var form := VBoxContainer.new()
	form.add_theme_constant_override("separation", 10)
	main.add_child(form)
	name_edit.text = _person.name
	name_edit.max_length = 24
	name_edit.placeholder_text = "Name your peasant"
	name_edit.select_all_on_focus = true
	# A refused Begin leaves the name ready to fix.
	name_edit.keep_editing_on_text_submit = true
	name_edit.add_theme_font_override("font", _serif)
	name_edit.add_theme_font_size_override("font_size", 18)
	name_edit.text_changed.connect(func(_text: String) -> void: _changed())
	name_edit.text_submitted.connect(func(_text: String) -> void: _begin())
	_field(_grid(form), "Name", name_edit)
	form.add_child(_label("Body", TimeHud.GOLD, 20, preload("res://assets/fonts/CormorantUnicase-Bold.ttf")))
	var grid := _grid(form)
	_slider(grid, "Height", 1.55, 1.85, 0.01, _person.height, "Taller bodies have a lower BMI at the same weight")
	_slider(grid, "Weight", 40.0, 110.0, 1.0, _person.mass(), "From full health at a BMI of 18.5 to 30 at this height")
	_slider(grid, "Body fat", 8.0, 30.0, 1.0, _person.fat / _person.mass() * 100.0, "The rest is lean mass: muscle, organs and bone")
	form.add_child(_info)
	var about := _label("Lean mass raises the metabolism and holds more ready energy; fat lasts longer without food; every kilogram makes walking and work dearer.", MUTED, 13)
	about.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	about.custom_minimum_size.x = 500
	form.add_child(about)
	form.add_child(_label("Looks", TimeHud.GOLD, 20, preload("res://assets/fonts/CormorantUnicase-Bold.ttf")))
	grid = _grid(form)
	_choices(grid, "skin", HumanActor.SKINS)
	_choices(grid, "hair", HumanActor.HAIRS)
	_choices(grid, "beard", HumanActor.BEARDS)
	_choices(grid, "clothes", HumanActor.CLOTHES)
	begin.text = "Begin"
	TimeHud.style_button(begin, _serif)
	begin.add_theme_font_size_override("font_size", 18)
	begin.custom_minimum_size = Vector2(160, 40)
	begin.size_flags_horizontal = Control.SIZE_SHRINK_END
	begin.pressed.connect(_begin)
	header.get_parent().add_child(begin)
	_changed()

## Shows the screen with the name ready to type over.
func open() -> void:
	show()
	_fit()
	name_edit.grab_focus()

## The peasant turning slowly on a patch of bare earth.
func _preview() -> SubViewportContainer:
	var frame := SubViewportContainer.new()
	frame.name = "Preview"
	frame.stretch = true
	frame.custom_minimum_size = Vector2(260, 420)
	var view := SubViewport.new()
	view.own_world_3d = true
	view.transparent_bg = true
	view.msaa_3d = Viewport.MSAA_4X
	frame.add_child(view)
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
	sun.shadow_enabled = true
	view.add_child(sun)
	var camera := Camera3D.new()
	camera.fov = 30.0
	camera.transform = Transform3D(Basis(), Vector3(0, 1.3, 4.4)).looking_at(Vector3(0, 0.9, 0))
	camera.environment = Environment.new()
	camera.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	camera.environment.ambient_light_color = Color(0.52, 0.48, 0.43)
	camera.environment.ambient_light_energy = 0.6
	view.add_child(camera)
	return frame

func _grid(parent: Control) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	parent.add_child(grid)
	return grid

## A titled control and, after it, a label saying what it is set to, which it returns.
func _field(grid: GridContainer, title: String, control: Control) -> Label:
	var label := _label(title, TimeHud.PARCHMENT, 15)
	label.custom_minimum_size.x = 80
	grid.add_child(label)
	control.custom_minimum_size.x = 300
	grid.add_child(control)
	_values[title] = _label("", MUTED, 15)
	_values[title].custom_minimum_size.x = 110
	grid.add_child(_values[title])
	return _values[title]

func _slider(grid: GridContainer, title: String, low: float, high: float, step: float, value: float, tooltip: String) -> void:
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.value = value
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.tooltip_text = tooltip + " (arrow keys adjust)"
	slider.value_changed.connect(func(_value: float) -> void: _changed())
	sliders[title] = slider
	_field(grid, title, slider)

## Exclusive choices for look `key`, the first chosen: colour swatches from a
## Dictionary of colours, or words from an Array.
func _choices(grid: GridContainer, key: String, options: Variant) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
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
			TimeHud.style_button(button, _serif)
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
	button.custom_minimum_size = Vector2(30, 30)
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var rings := {"normal": [TimeHud.GOLD.darkened(0.4), 1], "hover": [TimeHud.GOLD, 2], "pressed": [TimeHud.PARCHMENT, 3], "hover_pressed": [TimeHud.PARCHMENT, 3]}
	for state in rings:
		button.add_theme_stylebox_override(state, TimeHud.box(color, rings[state][0], 15, rings[state][1], Vector2.ZERO))
	var focus := TimeHud.box(Color(0, 0, 0, 0), TimeHud.GOLD.lightened(0.3), 18, 2, Vector2.ZERO)
	focus.set_expand_margin_all(4)
	button.add_theme_stylebox_override("focus", focus)

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
	begin.disabled = peasant.name == ""
	begin.tooltip_text = "Name your peasant first" if begin.disabled else "Start farming as %s (Enter in the name field)" % peasant.name

func _begin() -> void:
	# LineEdit reports typing a frame late, so read the name now.
	_changed()
	if begin.disabled:
		return
	Human.peasant = peasant.duplicate()
	var error := get_tree().change_scene_to_file("res://game.tscn")
	if error != OK:
		push_error("Could not open the game scene: " + error_string(error))

func _process(delta: float) -> void:
	if visible:
		_turn += delta * 0.4
		_person.facing = Vector2(sin(_turn), cos(_turn))
		_actor.show_person(_person, delta)

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		hide()
