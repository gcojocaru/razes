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

var hovered_cell := Vector2i(-1, -1)
var selected_cell := Vector2i(-1, -1)

var _camera: Camera3D
var _field: ShaderMaterial
var _zoom := 24.0

func _ready() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.shadow_enabled = true
	add_child(sun)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.55, 0.68, 0.78)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.75, 0.78, 0.8)
	environment.ambient_light_energy = 0.6
	var world := WorldEnvironment.new()
	world.environment = environment
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

	_camera = Camera3D.new()
	_camera.rotation_degrees = Vector3(-55, 45, 0)
	add_child(_camera)
	_place_camera(Vector3.ZERO)

func _process(delta: float) -> void:
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
	# macOS trackpads send gestures instead of wheel clicks.
	if event is InputEventMagnifyGesture:
		zoom_by(_zoom * (1.0 / event.factor - 1.0))
	elif event is InputEventPanGesture:
		zoom_by(event.delta.y * ZOOM_STEP * 0.5)
	if event is InputEventMouseMotion:
		hovered_cell = cell_at_screen(event.position)
		_field.set_shader_parameter("hovered", Vector2(hovered_cell))
	elif event is InputEventMouseButton and event.pressed:
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
