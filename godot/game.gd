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

var weather := Weather.new(randi())
var today := {}
## 0–1 snow lying on the field: snow days cover it, warm days melt it.
var snow_cover := 0.0
var _sun: DirectionalLight3D
var _environment: Environment
var _weather_effects: Node3D

var hovered_cell := Vector2i(-1, -1)
var selected_cell := Vector2i(-1, -1)

var _camera: Camera3D
var _field: ShaderMaterial
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
	_field.set_shader_parameter("grid_size", float(GRID_SIZE))
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * GRID_SIZE * CELL_SIZE
	var ground := MeshInstance3D.new()
	ground.name = "Field"
	ground.mesh = plane
	ground.material_override = _field
	add_child(ground)
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
	if OS.is_debug_build():
		_debug_panel = preload("res://debug_panel.gd").new(seconds_per_day)
		_debug_panel.day_length_changed.connect(func(seconds: float) -> void: seconds_per_day = seconds)
		hud.add_child(_debug_panel)
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
	_field.set_shader_parameter("snow", snow_cover)
	_show_date()

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
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE: set_speed(0 if speed > 0 else _resume_speed)
			KEY_1: set_speed(1)
			KEY_2: set_speed(2)
			KEY_3: set_speed(4)
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
		_field.set_shader_parameter("hovered", Vector2(hovered_cell))
	elif event is InputEventMouseButton and event.pressed:
		# Clicking the world gives keys back to the game, e.g. after typing in the debug panel.
		get_viewport().gui_release_focus()
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN:
				zoom_by(ZOOM_STEP if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -ZOOM_STEP)
			MOUSE_BUTTON_LEFT:
				selected_cell = cell_at_screen(event.position)
				_field.set_shader_parameter("selected", Vector2(selected_cell))

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
