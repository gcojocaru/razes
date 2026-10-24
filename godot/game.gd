extends Node3D
## Strategy field: a square grid of building plots with a panning, zooming camera.

const GRID_SIZE := 16
const CELL_SIZE := 2.0
const PAN_SPEED := 18.0
const ZOOM_STEP := 2.0
const ZOOM_MIN := 8.0
const ZOOM_MAX := 40.0
const ROTATE_SPEED := 1.8
const DRAG_ROTATE_SPEED := 0.008

## Real seconds per game day at 1×; tunable from the debug panel.
var seconds_per_day := 2.0
var day := 0
## Game-time multiplier; 0 is paused.
var speed := 1
var _resume_speed := 1
var _day_time := 0.0
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
## The crop last picked for sowing; see seed_crop().
var _seed_choice := ""
var _farm_hud: PanelContainer
var _ledger: PanelContainer
var _inventory: PanelContainer
var _wiki: PanelContainer
## One texel per cell for the field and crop shaders: R is (Farm.STAGES index +
## 8 × crop number, 1 for the first of Farm.CROPS) / 255, G the growth, B 1 when
## selected, A the soil fertility.
var _crops := Image.create_empty(GRID_SIZE, GRID_SIZE, false, Image.FORMAT_RGBA8)
var _crop_texture := ImageTexture.create_from_image(_crops)

var _camera: Camera3D
var _field: ShaderMaterial
var _stalks: ShaderMaterial
var _zoom := 24.0

func _ready() -> void:
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-55, -35, 0)
	_sun.shadow_enabled = true
	add_child(_sun)

	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color(0.75, 0.78, 0.8)
	_environment.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = _environment
	add_child(world)

	_field = ShaderMaterial.new()
	_field.shader = preload("res://field.gdshader")
	_field.set_shader_parameter("grass_color", preload("res://assets/textures/grass_color.jpg"))
	_field.set_shader_parameter("grass_normal", preload("res://assets/textures/grass_normal.jpg"))
	_field.set_shader_parameter("furrow_color", preload("res://assets/textures/furrows_color.jpg"))
	_field.set_shader_parameter("furrow_normal", preload("res://assets/textures/furrows_normal.jpg"))
	_stalks = ShaderMaterial.new()
	_stalks.shader = preload("res://crops.gdshader")
	_stalks.set_shader_parameter("cell_size", CELL_SIZE)
	# Entry 0 is for plots without a crop.
	var tall := PackedFloat32Array([0.8])
	var ripe := PackedVector3Array([Vector3(0.88, 0.69, 0.3)])
	for kind in Farm.CROPS.values():
		tall.append(kind.height)
		ripe.append(Vector3(kind.color.r, kind.color.g, kind.color.b))
	_stalks.set_shader_parameter("tall", tall)
	_stalks.set_shader_parameter("ripe", ripe)
	for material in [_field, _stalks]:
		material.set_shader_parameter("grid_size", float(GRID_SIZE))
		material.set_shader_parameter("crops", _crop_texture)
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * GRID_SIZE * CELL_SIZE
	var ground := MeshInstance3D.new()
	ground.name = "Field"
	ground.mesh = plane
	ground.material_override = _field
	add_child(ground)
	add_child(_crop_stalks())
	_weather_effects = preload("res://weather_effects.gd").new(_sun, _environment, _field)
	add_child(_weather_effects)

	_camera = Camera3D.new()
	_camera.rotation_degrees = Vector3(-55, 45, 0)
	add_child(_camera)
	_place_camera(Vector3.ZERO)

	var hud := CanvasLayer.new()
	add_child(hud)
	_time_hud = preload("res://time_hud.gd").new()
	_time_hud.speed_selected.connect(set_speed)
	hud.add_child(_time_hud)
	_farm_hud = preload("res://farm_hud.gd").new()
	_farm_hud.action_pressed.connect(work)
	_farm_hud.crop_chosen.connect(choose_crop)
	hud.add_child(_farm_hud)
	_ledger = preload("res://ledger.gd").new()
	hud.add_child(_ledger)
	_inventory = preload("res://inventory.gd").new()
	hud.add_child(_inventory)
	_wiki = preload("res://wiki.gd").new()
	hud.add_child(_wiki)
	_farm_hud.ledger_pressed.connect(toggle.bind(_ledger))
	_farm_hud.inventory_pressed.connect(toggle.bind(_inventory))
	_farm_hud.wiki_pressed.connect(toggle.bind(_wiki))
	if OS.is_debug_build():
		_debug_panel = preload("res://debug_panel.gd").new(seconds_per_day)
		_debug_panel.day_length_changed.connect(func(seconds: float) -> void: seconds_per_day = seconds)
		hud.add_child(_debug_panel)
		_agri_debug = preload("res://agri_debug.gd").new(self)
		hud.add_child(_agri_debug)
	_start_day()

func _show_date() -> void:
	_time_hud.show_time(day, speed, today)

## Rolls the weather for the current day and applies it to the sky and field.
func _start_day() -> void:
	today = weather.on(day)
	if today.condition == "Snow":
		snow_cover = 1.0
	elif today.temperature > 2:
		snow_cover = maxf(snow_cover - 0.02 * today.temperature, 0.0)
	# The first day appears at once; later days blend in.
	_weather_effects.show_weather(today.condition, _weather_effects.condition == "")
	for material in [_field, _stalks]:
		material.set_shader_parameter("snow", snow_cover)
	farm.grow(today, day)
	_show_farm()
	_show_date()

## Does `action` (every ready action when empty) on the selected plots.
func work(action := "") -> void:
	if farm.work(selected.keys(), day, action, seed_crop()) > 0:
		_show_farm()

## The crop to sow: the one last picked if it can be sown today, else the first that can.
func seed_crop() -> String:
	var open := Farm.sowable(day)
	return _seed_choice if _seed_choice in open else (open[0] if not open.is_empty() else "")

## Picks the crop to sow and sows it on the selected plowed plots.
func choose_crop(crop: String) -> void:
	_seed_choice = crop
	farm.work(selected.keys(), day, "Sow", crop)
	_show_farm()

## Right-click: offers crops for the plot under the pointer, selecting it unless
## it is already part of the selection.
func _open_crop_menu(position: Vector2) -> void:
	var cell := cell_at_screen(position)
	if cell == Vector2i(-1, -1):
		return
	if not selected.has(cell):
		_start_selection(cell, false)
	_farm_hud.open_crop_menu(position)

## Debug: runs `days` whole days at once.
func skip_days(days: int) -> void:
	for i in days:
		day += 1
		_start_day()

## Shows or hides a HUD window, refreshing what the windows show.
func toggle(window: Control) -> void:
	window.visible = not window.visible
	_show_farm()

## Redraws crops and selection on the field and refreshes the farm panels.
func _show_farm() -> void:
	for x in GRID_SIZE:
		for y in GRID_SIZE:
			var cell := Vector2i(x, y)
			var packed: int = Farm.STAGES.find(farm.stage(cell)) + 8 * (Farm.CROPS.keys().find(farm.crop(cell)) + 1)
			_crops.set_pixelv(cell, Color(packed / 255.0, farm.growth(cell), float(selected.has(cell)), farm.fertility(cell)))
	_crop_texture.update(_crops)
	_farm_hud.show_farm(farm, selected.keys(), day, seed_crop())
	if _ledger.visible:
		_ledger.show_ledger(farm, day)
	if _inventory.visible:
		_inventory.show_inventory(farm, day)
	if _agri_debug and _agri_debug.visible:
		_agri_debug.refresh()

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
					multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, randf() * TAU), corner + Vector3(along, 0, across) * CELL_SIZE))
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
		var side := out.cross(Vector3.UP) * 0.022
		var tip := Vector3.UP * (1.0 - blade * 0.12) + out * 0.18
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
	if new_speed > 0:
		_resume_speed = new_speed
	speed = new_speed
	_show_date()

## Advances game time; whole days roll over and update the date display.
func advance_time(seconds: float) -> void:
	_day_time += seconds
	while _day_time >= seconds_per_day:
		_day_time -= seconds_per_day
		day += 1
		_start_day()
	_show_date()

func _process(delta: float) -> void:
	if speed > 0:
		advance_time(delta * speed)
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	for key in [[KEY_A, Vector2.LEFT], [KEY_D, Vector2.RIGHT], [KEY_W, Vector2.UP], [KEY_S, Vector2.DOWN]]:
		if Input.is_physical_key_pressed(key[0]):
			input += key[1]
	if input != Vector2.ZERO:
		# Pan along the ground relative to the camera's facing, not world axes.
		var basis := Basis(Vector3.UP, _camera.rotation.y)
		var move := basis * Vector3(input.x, 0, input.y).limit_length(1.0) * PAN_SPEED * delta
		var half := GRID_SIZE * CELL_SIZE / 2.0
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
			KEY_ENTER, KEY_KP_ENTER: _start_selection(cell_at_world(_focus()), event.shift_pressed)
			KEY_F: work()
			KEY_C: _farm_hud.open_crop_menu()
			KEY_L: toggle(_ledger)
			KEY_I: toggle(_inventory)
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
		for material in [_field, _stalks]:
			material.set_shader_parameter("hovered", Vector2(hovered_cell))
		if event.button_mask & MOUSE_BUTTON_MASK_LEFT and _drag_from != Vector2i(-1, -1) and hovered_cell not in [Vector2i(-1, -1), _drag_to]:
			_select_to(hovered_cell)
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_drag_from = Vector2i(-1, -1)
	elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		# A right click, not the end of a camera-rotating drag.
		if event.position.distance_to(_right_from) < 6.0:
			_open_crop_menu(event.position)
	elif event is InputEventMouseButton and event.pressed:
		# Clicking the world gives keys back to the game, e.g. after typing in the debug panel.
		get_viewport().gui_release_focus()
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				zoom_by(ZOOM_STEP if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -ZOOM_STEP)
			MOUSE_BUTTON_LEFT:
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
	var hit = Plane.PLANE_XZ.intersects_ray(_camera.project_ray_origin(screen_position), _camera.project_ray_normal(screen_position))
	return cell_at_world(hit) if hit != null else Vector2i(-1, -1)

func cell_at_world(point: Vector3) -> Vector2i:
	var cell := Vector2i(floori(point.x / CELL_SIZE + GRID_SIZE / 2.0), floori(point.z / CELL_SIZE + GRID_SIZE / 2.0))
	return cell if Rect2i(0, 0, GRID_SIZE, GRID_SIZE).has_point(cell) else Vector2i(-1, -1)

## World-space centre of a cell, where a future building would stand.
func cell_center(cell: Vector2i) -> Vector3:
	return Vector3((cell.x - GRID_SIZE / 2.0 + 0.5) * CELL_SIZE, 0, (cell.y - GRID_SIZE / 2.0 + 0.5) * CELL_SIZE)

func _focus() -> Vector3:
	var hit = Plane.PLANE_XZ.intersects_ray(_camera.position, -_camera.global_basis.z)
	return hit if hit != null else Vector3.ZERO

func _place_camera(focus: Vector3) -> void:
	_camera.position = focus + _camera.global_basis.z * _zoom
