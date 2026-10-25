extends Node3D
## Strategy field: a square grid of building plots with a panning, zooming camera.

const GRID_SIZE := 16
const CELL_SIZE := 2.0
const Terrain := preload("res://terrain.gd")
const TimeHud := preload("res://time_hud.gd")
const METRES_TO_UNITS := CELL_SIZE / 10.0
const PAN_SPEED := 18.0
const ZOOM_STEP := 2.0
const ZOOM_MIN := 2.0
const ZOOM_MAX := 40.0
const ROTATE_SPEED := 1.8
const DRAG_ROTATE_SPEED := 0.008

## Real seconds per game day at 1×; tunable from the debug panel.
var seconds_per_day := 600.0
var day := 0
## Game-time multiplier; 0 is paused.
var speed := 1
var _resume_speed := 1
var _day_time := seconds_per_day / 4.0
var _time_hud: PanelContainer
var _debug_panel: PanelContainer
var _agri_debug: PanelContainer

var weather := Weather.new(randi())
var today := {}
## 0–1 snow lying on the field: snow days cover it, warm days melt it.
var snow_cover := 0.0
var _sun: DirectionalLight3D
var _environment: Environment
var _weather_effects: Node3D
var _weather_audio: Node
var _sound_control: Control

## Furrow rows per plot (matching the furrow texture) and crop stalks per row.
const FURROWS := 7
const STALKS_PER_FURROW := 9

var hovered_cell := Vector2i(-1, -1)
## Selected plots as a set: Vector2i cell -> true.
var selected := {}
## A left-button drag selects the rectangle from _drag_from to _drag_to, plus
## the plots _kept by holding Shift; _drag_from is (-1, -1) when not dragging.
var _drag_from := Vector2i(-1, -1)
var _drag_to := Vector2i(-1, -1)
var _kept := {}
## Where the right button went down, to tell a click from a rotating drag.
var _right_from := Vector2.INF

var farm := Farm.new()
var human = preload("res://human.gd").new()
var _human_actor: Node3D
var _human_hud: PanelContainer
var _game_over: ColorRect
var _camp_menu: Control
var _food_window: PanelContainer
var _sleep_window: PanelContainer
var _camp_press := Vector2.INF
## The crop last picked for sowing; see seed_crop().
var _seed_choice := ""
var _farm_hud: PanelContainer
var _ledger: PanelContainer
var _inventory: PanelContainer
var _body: PanelContainer
var _wiki: PanelContainer
## One texel per cell for the field and crop shaders: R is (Farm.STAGES index +
## 8 × crop number, 1 for the first of Farm.CROPS) / 255, G the growth, B 1 when
## selected, A the soil fertility.
var _crops := Image.create_empty(GRID_SIZE, GRID_SIZE, false, Image.FORMAT_RGBA8)
var _crop_texture := ImageTexture.create_from_image(_crops)

var _camera: Camera3D
var _camera_focus := Vector3.ZERO
var _field: ShaderMaterial
var _stalks: ShaderMaterial
var _water: ShaderMaterial
var terrain_seed := randi()
var terrain: RefCounted
var _zoom := 36.0

func _ready() -> void:
	terrain = Terrain.new(terrain_seed, Terrain.land)
	farm.terrain = terrain
	human.terrain = terrain
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = true
	add_child(_sun)

	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	var world := WorldEnvironment.new()
	world.environment = _environment
	add_child(world)

	_field = ShaderMaterial.new()
	_field.shader = preload("res://field.gdshader")
	_field.set_shader_parameter("cell_size", CELL_SIZE)
	_field.set_shader_parameter("grass_color", preload("res://assets/textures/grass_color.jpg"))
	_field.set_shader_parameter("grass_normal", preload("res://assets/textures/grass_normal.jpg"))
	_field.set_shader_parameter("furrow_color", preload("res://assets/textures/furrows_color.jpg"))
	_field.set_shader_parameter("furrow_normal", preload("res://assets/textures/furrows_normal.jpg"))
	_stalks = ShaderMaterial.new()
	_stalks.shader = preload("res://crops.gdshader")
	_stalks.set_shader_parameter("cell_size", CELL_SIZE)
	_water = ShaderMaterial.new()
	_water.shader = preload("res://water.gdshader")
	_water.set_shader_parameter("cell_size", CELL_SIZE)
	# Entry 0 is for plots without a crop.
	var tall := PackedFloat32Array([0.8])
	var ripe := PackedVector3Array([Vector3(0.88, 0.69, 0.3)])
	for kind in Farm.CROPS.values():
		tall.append(kind.height * METRES_TO_UNITS)
		ripe.append(Vector3(kind.color.r, kind.color.g, kind.color.b))
	_stalks.set_shader_parameter("tall", tall)
	_stalks.set_shader_parameter("ripe", ripe)
	_stalks.set_shader_parameter("metres_to_units", METRES_TO_UNITS)
	for material in [_field, _stalks, _water]:
		material.set_shader_parameter("grid_size", float(GRID_SIZE))
		material.set_shader_parameter("crops", _crop_texture)
	var ground := MeshInstance3D.new()
	ground.name = "Field"
	ground.mesh = terrain.create_mesh()
	ground.material_override = _field
	add_child(ground)
	var water := MeshInstance3D.new()
	water.name = "Water"
	var surface := PlaneMesh.new()
	surface.size = Vector2.ONE * Terrain.HALF_EXTENT * 2.0
	water.mesh = surface
	water.position.y = Terrain.WATER_LEVEL
	water.material_override = _water
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(water)
	add_child(_crop_stalks())
	_human_actor = preload("res://human_actor.gd").new(METRES_TO_UNITS)
	_human_actor.name = "HumanActor"
	if not Human.peasant.is_empty():
		human.create(Human.peasant)
		_human_actor.dress(Human.peasant)
	add_child(_human_actor)
	var camp: Node3D = _human_actor.create_camp()
	camp.position = _surface_point(human.home * METRES_TO_UNITS)
	add_child(camp)
	_weather_effects = preload("res://weather_effects.gd").new(_sun, _environment, _field, camp.get_node("Firelight"))
	add_child(_weather_effects)
	_weather_audio = preload("res://weather_audio.gd").new()
	add_child(_weather_audio)
	_weather_effects.lightning.connect(_weather_audio.lightning)

	_camera = Camera3D.new()
	_camera.rotation_degrees = Vector3(-55, 45, 0)
	add_child(_camera)
	_place_camera(Vector3.ZERO)

	var hud := CanvasLayer.new()
	add_child(hud)
	_time_hud = TimeHud.new()
	_time_hud.speed_selected.connect(set_speed)
	hud.add_child(_time_hud)
	_sound_control = preload("res://sound_control.gd").new()
	hud.add_child(_sound_control)
	_human_hud = preload("res://human_hud.gd").new()
	_human_hud.focus_requested.connect(_focus_person)
	_human_hud.wake_requested.connect(_wake_up)
	_human_hud.cancel_requested.connect(func() -> void:
		human.cancel(farm)
		_show_farm())
	hud.add_child(_human_hud)
	_farm_hud = preload("res://farm_hud.gd").new()
	_farm_hud.action_pressed.connect(work)
	_farm_hud.crop_chosen.connect(choose_crop)
	hud.add_child(_farm_hud)
	_ledger = preload("res://ledger.gd").new()
	hud.add_child(_ledger)
	_inventory = preload("res://inventory.gd").new()
	hud.add_child(_inventory)
	_body = preload("res://body_window.gd").new()
	hud.add_child(_body)
	_wiki = preload("res://wiki.gd").new()
	hud.add_child(_wiki)
	_food_window = preload("res://food_window.gd").new()
	_food_window.prepare_requested.connect(_prepare_porridge)
	hud.add_child(_food_window)
	_sleep_window = preload("res://sleep_window.gd").new()
	_sleep_window.sleep_requested.connect(_start_sleep)
	hud.add_child(_sleep_window)
	for window in [_food_window, _sleep_window]:
		window.visibility_changed.connect(_show_person)
	_farm_hud.ledger_pressed.connect(toggle.bind(_ledger))
	_farm_hud.inventory_pressed.connect(toggle.bind(_inventory))
	_farm_hud.wiki_pressed.connect(toggle.bind(_wiki))
	_human_hud.body_requested.connect(toggle.bind(_body))
	if OS.is_debug_build():
		_debug_panel = preload("res://debug_panel.gd").new(seconds_per_day)
		_debug_panel.day_length_changed.connect(func(seconds: float) -> void:
			var fraction := _day_time / seconds_per_day
			seconds_per_day = seconds
			_day_time = fraction * seconds_per_day)
		hud.add_child(_debug_panel)
		_agri_debug = preload("res://agri_debug.gd").new(self)
		hud.add_child(_agri_debug)
	# GUI input follows sibling order, so the modal wheel must follow every HUD window.
	hud.add_child(_farm_hud.action_wheel)
	_camp_menu = preload("res://camp_menu.gd").new()
	_camp_menu.eat_selected.connect(_open_food)
	_camp_menu.sleep_selected.connect(_open_sleep)
	hud.add_child(_camp_menu)
	_game_over = _make_game_over()
	hud.add_child(_game_over)
	_start_day()

func _make_game_over() -> ColorRect:
	var overlay := ColorRect.new()
	overlay.name = "GameOver"
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.z_index = 100
	overlay.hide()
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(centre)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", TimeHud.box(TimeHud.INK, TimeHud.GOLD, 10, 2, Vector2(30, 24)))
	centre.add_child(card)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 320
	column.add_theme_constant_override("separation", 18)
	card.add_child(column)
	var title := Label.new()
	title.name = "GameOverTitle"
	title.text = "Game Over"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", preload("res://assets/fonts/CormorantUnicase-Bold.ttf"))
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", TimeHud.GOLD)
	column.add_child(title)
	var explanation := Label.new()
	explanation.text = "Your health has reached zero."
	explanation.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	explanation.add_theme_font_override("font", TimeHud.serif_font())
	explanation.add_theme_color_override("font_color", TimeHud.PARCHMENT)
	column.add_child(explanation)
	var restart := Button.new()
	restart.text = "Restart (Enter)"
	restart.focus_mode = Control.FOCUS_NONE
	TimeHud.style_button(restart, TimeHud.serif_font())
	restart.pressed.connect(func() -> void: get_tree().reload_current_scene())
	column.add_child(restart)
	return overlay

func _end_game() -> void:
	speed = 0
	_sound_control.set_process_input(false)
	for window in [_farm_hud.action_wheel, _camp_menu, _food_window, _sleep_window, _inventory, _body, _ledger, _wiki, _sound_control, _debug_panel, _agri_debug]:
		if is_instance_valid(window):
			window.hide()
	get_viewport().gui_release_focus()
	_game_over.show()
	_show_date()

func _show_date() -> void:
	var hour := _day_time / seconds_per_day * 24.0
	_time_hud.show_time(day, speed, today, hour)
	_weather_effects.show_time(day, hour)

func _show_person(seconds := 0.0) -> void:
	_human_actor.show_person(human, seconds)
	_human_actor.position.y = terrain.height_at(human.position * METRES_TO_UNITS)
	_human_hud.show_person(human)
	_human_hud.visible = not _inventory.visible and not _wiki.visible and not _food_window.visible and not _sleep_window.visible and not _body.visible
	if _body.visible:
		_body.show_body(human)
	if _food_window.visible:
		_food_window.show_food(farm, human)
	if _sleep_window.visible:
		_sleep_window.show_sleep(human)

func _focus_person() -> void:
	_zoom = minf(_zoom, 8.0)
	_place_camera(_human_actor.position)

func _open_camp_menu(at := Vector2(-1, -1)) -> void:
	if human.activity == "Dead":
		return
	_farm_hud.action_wheel.hide()
	_drag_from = Vector2i(-1, -1)
	_camp_press = Vector2.INF
	if at == Vector2(-1, -1):
		var camp := _surface_point(human.home * METRES_TO_UNITS)
		_zoom = minf(_zoom, 8.0)
		_place_camera(camp)
		at = _camera.unproject_position(camp)
	_camp_menu.open_at(at)

func _open_food() -> void:
	if human.activity == "Dead":
		return
	_camp_menu.hide()
	_inventory.hide()
	_body.hide()
	_sleep_window.hide()
	_food_window.show_food(farm, human)
	_food_window.show()
	_food_window.quantity.get_line_edit().grab_focus()

func _prepare_porridge(crop: String, grams: int) -> void:
	if human.eat(farm, crop, grams):
		_food_window.hide()
	_show_farm()

func _open_sleep() -> void:
	if human.activity == "Dead":
		return
	_camp_menu.hide()
	_farm_hud.action_wheel.hide()
	_inventory.hide()
	_body.hide()
	_food_window.hide()
	_sleep_window.show_sleep(human)
	_sleep_window.show()
	_sleep_window.hours.get_line_edit().grab_focus()

func _start_sleep(hours: float) -> void:
	if human.sleep(hours):
		_sleep_window.hide()
	_show_person()

func _wake_up() -> void:
	human.wake_up()
	_show_person()

## Rolls the weather for the current day and applies it to the sky and field.
func _start_day() -> void:
	today = weather.on(day)
	if today.condition == "Snow":
		snow_cover = 1.0
	elif today.temperature > 2:
		snow_cover = maxf(snow_cover - 0.02 * today.temperature, 0.0)
	# The first day appears at once; later days blend in.
	_weather_audio.show_weather(today.condition, _weather_effects.condition == "")
	_weather_effects.show_weather(today.condition, _weather_effects.condition == "")
	for material in [_field, _stalks]:
		material.set_shader_parameter("snow", snow_cover)
	farm.grow(today, day)
	_show_farm()
	_show_date()

## Orders `action` (every ready action when empty) on the selected plots.
func work(action := "") -> void:
	human.order(farm, selected.keys(), day, action, seed_crop())
	_show_farm()

## The crop to sow: the one last picked if it can be sown today, else the first that can.
func seed_crop() -> String:
	var open := Farm.sowable(day)
	return _seed_choice if _seed_choice in open else (open[0] if not open.is_empty() else "")

## Picks the crop to sow and orders it on the selected plowed plots.
func choose_crop(crop: String) -> void:
	_seed_choice = crop
	work("Sow")

## Right-click: offers actions for the land under the pointer, selecting it unless
## it is already part of the selection.
func _open_action_menu(position: Vector2) -> void:
	if _camp_at(position):
		_open_camp_menu(position)
		return
	var cell := cell_at_screen(position)
	if cell == Vector2i(-1, -1):
		return
	if not selected.has(cell):
		_start_selection(cell, false)
	_drag_from = Vector2i(-1, -1)
	_farm_hud.open_action_menu(position)

## Debug: runs `days` whole days at once.
func skip_days(days: int) -> void:
	advance_time(maxi(days, 0) * seconds_per_day)

## Shows or hides a HUD window, refreshing what the windows show.
func toggle(window: Control) -> void:
	if human.activity == "Dead":
		return
	window.visible = not window.visible
	# Inventory and Body share the left side with the food and sleep windows.
	if window.visible and window in [_inventory, _body]:
		for other in [_inventory, _body, _food_window, _sleep_window]:
			if other != window:
				other.hide()
	_show_farm()

## Redraws crops and selection on the field and refreshes the farm panels.
func _show_farm() -> void:
	for x in GRID_SIZE:
		for y in GRID_SIZE:
			var cell := Vector2i(x, y)
			var packed: int = Farm.STAGES.find(farm.stage(cell)) + 8 * (Farm.CROPS.keys().find(farm.crop(cell)) + 1)
			_crops.set_pixelv(cell, Color(packed / 255.0, farm.growth(cell), float(selected.has(cell)), farm.fertility(cell)))
	_crop_texture.update(_crops)
	var queued: Array = human.queue.map(func(job: Dictionary): return job.cell)
	if not human.job.is_empty():
		queued.append(human.job.cell)
	_farm_hud.show_farm(farm, selected.keys(), day, seed_crop(), queued)
	if _ledger.visible:
		_ledger.show_ledger(farm, day)
	if _inventory.visible:
		_inventory.show_inventory(farm, day)
	if _agri_debug and _agri_debug.visible:
		_agri_debug.refresh()
	_show_person()

## Selects `cell` and starts a drag there; `add` keeps the current selection.
func _start_selection(cell: Vector2i, add: bool) -> void:
	_kept = selected.duplicate() if add else {}
	_drag_from = cell
	_select_to(cell)

## Selects the plots from the drag start to `cell`, plus any kept by Shift.
func _select_to(cell: Vector2i) -> void:
	_drag_to = cell
	selected = _kept.duplicate()
	if _drag_from != Vector2i(-1, -1) and cell != Vector2i(-1, -1):
		var corner := Vector2i(mini(_drag_from.x, cell.x), mini(_drag_from.y, cell.y))
		var size := (_drag_from - cell).abs()
		for x in size.x + 1:
			for y in size.y + 1:
				selected[corner + Vector2i(x, y)] = true
	_show_farm()

## Every plot gets a fixed set of stalks along its furrows. The crop shader sizes
## and colours them from the crop texture, so nothing is rebuilt as crops grow.
func _crop_stalks() -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = _stalk_mesh()
	multimesh.instance_count = GRID_SIZE * GRID_SIZE * FURROWS * STALKS_PER_FURROW
	var i := 0
	for x in GRID_SIZE:
		for y in GRID_SIZE:
			var corner := cell_center(Vector2i(x, y)) - Vector3(1, 0, 1) * CELL_SIZE / 2.0
			for row in FURROWS:
				for stalk in STALKS_PER_FURROW:
					# Keep clear of the plot edges, where the furrow texture has a dark border.
					var along := 0.06 + 0.88 * (stalk + randf()) / STALKS_PER_FURROW
					var across := (row + 0.5 + randf_range(-0.1, 0.1)) / FURROWS
					var root := corner + Vector3(along, 0, across) * CELL_SIZE
					root.y = terrain.height_at(Vector2(root.x, root.z))
					multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, randf() * TAU), root))
					i += 1
	var stalks := MultiMeshInstance3D.new()
	stalks.name = "Crops"
	stalks.multimesh = multimesh
	stalks.material_override = _stalks
	return stalks

## A tuft of three thin blades one unit tall, fanning outwards; normals point up
## so they light like grass.
func _stalk_mesh() -> ArrayMesh:
	var vertices := PackedVector3Array()
	for blade in 3:
		var out := Vector3.FORWARD.rotated(Vector3.UP, blade * TAU / 3)
		var side := out.cross(Vector3.UP) * 0.022 * METRES_TO_UNITS
		var tip := Vector3.UP * (1.0 - blade * 0.12) + out * 0.18 * METRES_TO_UNITS
		vertices.append_array([-side, side, tip + side * 0.15, -side, tip + side * 0.15, tip - side * 0.15])
	var uvs := PackedVector2Array()
	var normals := PackedVector3Array()
	for vertex in vertices:
		uvs.append(Vector2(0, float(vertex.y > 0)))
		normals.append(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func set_speed(new_speed: int) -> void:
	if human.activity == "Dead":
		speed = 0
		_show_date()
		return
	if new_speed > 0:
		_resume_speed = new_speed
	speed = new_speed
	_show_date()

## Advances game time; whole days roll over and update the date display.
func advance_time(seconds: float) -> void:
	if human.activity == "Dead" or not is_finite(seconds) or seconds <= 0.0:
		return
	var left := seconds
	var changed := false
	var jobs_before: int = human.queue.size() + int(not human.job.is_empty())
	while left > 0.0000001:
		var step := minf(left, seconds_per_day - _day_time)
		changed = human.advance(farm, day, _day_time / seconds_per_day * 24.0, step / seconds_per_day * 24.0) or changed
		var advanced: float = human.advanced_hours / 24.0 * seconds_per_day
		_day_time += advanced
		left -= advanced
		if _day_time >= seconds_per_day - 0.0000001:
			_day_time = 0.0
			day += 1
			_start_day()
		if human.activity == "Dead":
			_end_game()
			break
		if advanced <= 0.0:
			break
	if changed or jobs_before != human.queue.size() + int(not human.job.is_empty()):
		_show_farm()
	else:
		_show_person()
	_show_date()

func _process(delta: float) -> void:
	if is_instance_valid(_weather_audio):
		_weather_effects.set_wind(_weather_audio.wind_direction, _weather_audio.wind_strength)
		_stalks.set_shader_parameter("wind", _weather_audio.wind_direction * _weather_audio.wind_strength)
	if speed > 0:
		advance_time(delta * speed)
		_show_person(delta * speed)
	if human.activity == "Dead" or _sound_control.panel.visible or _farm_hud.action_wheel.visible or _camp_menu.visible or _food_window.visible or _sleep_window.visible:
		return
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	for key in [[KEY_A, Vector2.LEFT], [KEY_D, Vector2.RIGHT], [KEY_W, Vector2.UP], [KEY_S, Vector2.DOWN]]:
		if Input.is_physical_key_pressed(key[0]):
			input += key[1]
	if input != Vector2.ZERO:
		# Pan along the ground relative to the camera's facing, not world axes.
		var basis := Basis(Vector3.UP, _camera.rotation.y)
		var move := basis * Vector3(input.x, 0, input.y).limit_length(1.0) * PAN_SPEED * delta
		var half := (GRID_SIZE + 2) * CELL_SIZE / 2.0
		var target := (_focus() + move).clamp(Vector3(-half, 0, -half), Vector3(half, 0, half))
		_place_camera(target)
	var turn := float(Input.is_physical_key_pressed(KEY_E)) - float(Input.is_physical_key_pressed(KEY_Q))
	if turn != 0.0:
		rotate_camera(turn * ROTATE_SPEED * delta)

## Orbits the camera around the point it looks at.
func rotate_camera(radians: float) -> void:
	var focus := _focus()
	_camera.rotation.y += radians
	_place_camera(focus)

func _unhandled_input(event: InputEvent) -> void:
	if human.activity == "Dead":
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
			get_tree().reload_current_scene()
		return
	if _farm_hud.action_wheel.visible or _camp_menu.visible or (_sound_control.panel.visible and event is InputEventKey):
		return
	if (_food_window.visible or _sleep_window.visible) and not (event is InputEventKey and event.physical_keycode in [KEY_SPACE, KEY_1, KEY_2, KEY_3]):
		return
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		rotate_camera(-event.relative.x * DRAG_ROTATE_SPEED)
		# Once it moves, it is a rotating drag, even if it ends where it began.
		if event.position.distance_to(_right_from) >= 6.0:
			_right_from = Vector2.INF
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE: set_speed(0 if speed > 0 else _resume_speed)
			KEY_1: set_speed(1)
			KEY_2: set_speed(2)
			KEY_3: set_speed(4)
			# Keyboard alternative to clicking: WASD moves the view, Enter selects its centre plot.
			KEY_ENTER, KEY_KP_ENTER:
				_start_selection(cell_at_world(_focus()), event.shift_pressed)
			KEY_F: work()
			KEY_C: _farm_hud.open_action_menu()
			KEY_L: toggle(_ledger)
			KEY_I: toggle(_inventory)
			KEY_B: toggle(_body)
			KEY_H: _focus_person()
			KEY_R:
				if human.sleep_remaining > 0:
					_wake_up()
				else:
					_open_sleep()
			KEY_G: _open_camp_menu()
			KEY_BACKSPACE:
				human.cancel(farm)
				_show_farm()
			KEY_F1: toggle(_wiki)
			KEY_F4:
				if _agri_debug:
					toggle(_agri_debug)
			KEY_F3:
				if _debug_panel:
					_debug_panel.visible = not _debug_panel.visible
					get_viewport().gui_release_focus()
	# macOS trackpads send gestures instead of wheel clicks.
	if event is InputEventMagnifyGesture:
		zoom_by(_zoom * (1.0 / event.factor - 1.0))
	elif event is InputEventPanGesture:
		zoom_by(event.delta.y * ZOOM_STEP * 0.5)
	if event is InputEventMouseMotion:
		hovered_cell = cell_at_screen(event.position)
		for material in [_field, _stalks, _water]:
			material.set_shader_parameter("hovered", Vector2(hovered_cell))
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT and _drag_from != Vector2i(-1, -1) and hovered_cell not in [Vector2i(-1, -1), _drag_to]:
			_select_to(hovered_cell)
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_drag_from = Vector2i(-1, -1)
		if event.position.distance_to(_camp_press) < 6.0 and _camp_at(event.position):
			_open_camp_menu(event.position)
		_camp_press = Vector2.INF
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		# A right click, not the end of a camera-rotating drag.
		if event.position.distance_to(_right_from) < 6.0:
			_open_action_menu(event.position)
	elif event is InputEventMouseButton and event.pressed:
		# Clicking the world gives keys back to the game, e.g. after typing in the debug panel.
		get_viewport().gui_release_focus()
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				zoom_by(ZOOM_STEP if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -ZOOM_STEP)
			MOUSE_BUTTON_LEFT:
				if _camp_at(event.position):
					_camp_press = event.position
					_drag_from = Vector2i(-1, -1)
				else:
					_camp_press = Vector2.INF
					_start_selection(cell_at_screen(event.position), event.shift_pressed)
			MOUSE_BUTTON_RIGHT:
				_right_from = event.position

## Moves the camera closer (negative) or further (positive), keeping the view centre.
func zoom_by(amount: float) -> void:
	var focus := _focus()
	_zoom = clampf(_zoom + amount, ZOOM_MIN, ZOOM_MAX)
	_place_camera(focus)

## Grid cell under a screen point, or (-1, -1) when off the field.
func cell_at_screen(screen_position: Vector2) -> Vector2i:
	var hit = terrain.ray_hit(_camera.project_ray_origin(screen_position), _camera.project_ray_normal(screen_position))
	return cell_at_world(hit) if hit != null else Vector2i(-1, -1)

func _camp_at(screen_position: Vector2) -> bool:
	var hit = terrain.ray_hit(_camera.project_ray_origin(screen_position), _camera.project_ray_normal(screen_position))
	var camp := _surface_point(human.home * METRES_TO_UNITS)
	# The 2.2 m clearing has 0.3 m of picking padding.
	return hit != null and hit.distance_to(camp) <= 2.5 * METRES_TO_UNITS

func cell_at_world(point: Vector3) -> Vector2i:
	var cell := Vector2i(floori(point.x / CELL_SIZE + GRID_SIZE / 2.0), floori(point.z / CELL_SIZE + GRID_SIZE / 2.0))
	return cell if Rect2i(0, 0, GRID_SIZE, GRID_SIZE).has_point(cell) else Vector2i(-1, -1)

## World-space centre of a cell, where a future building would stand.
func cell_center(cell: Vector2i) -> Vector3:
	return _surface_point(Vector2(cell.x - GRID_SIZE / 2.0 + 0.5, cell.y - GRID_SIZE / 2.0 + 0.5) * CELL_SIZE)

func _surface_point(point: Vector2) -> Vector3:
	return Vector3(point.x, maxf(terrain.height_at(point), Terrain.WATER_LEVEL), point.y)

func _focus() -> Vector3:
	return _camera_focus

func _place_camera(focus: Vector3) -> void:
	_camera_focus = _surface_point(Vector2(focus.x, focus.z))
	var distance := _zoom
	_camera.position = _camera_focus + _camera.global_basis.z * distance
	# Back away from a hillside while retaining the selected focus and pitch.
	while _camera.position.y < terrain.height_at(Vector2(_camera.position.x, _camera.position.z)) + 0.35:
		distance += 0.5
		_camera.position = _camera_focus + _camera.global_basis.z * distance
