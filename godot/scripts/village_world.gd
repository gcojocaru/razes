class_name VillageWorld
extends Node3D

const Rules = preload("res://scripts/village_rules.gd")
const Models = preload("res://scripts/village_models.gd")
const TILE := 2.0
const PAINT_TOOLS := ["pavement", "dirtPath", "farmland", "fence", "wattleFence", "erase"]
const GROUND := Plane(Vector3.UP, 0)

signal selection_changed(selection: Dictionary)
signal placement_requested(kind: String, tile: Vector2i, facing: int)
signal parcel_selected(parcel: Vector2i)
signal tool_rotated(facing: int)

var camera: Camera3D
var camera_target := Vector3.ZERO
var _camera_turn := 0
var _state: Dictionary = {}
var _selection: Dictionary = {}
var _tool := ""
var _facing := 0
var _instant := false
var _reduced_motion := false
var _terrain: Node3D
var _entities: Node3D
var _surfaces: Node3D
var _selection_outline: Node3D
var _preview: Node3D
var _preview_tile := Vector2i.ZERO
var _preview_signature := ""
var _preview_outline: Node3D
var _terrain_signature := ""
var _materials: Dictionary = {}
var _box_meshes: Dictionary = {}
var _drag_button := 0
var _drag_start := Vector2.ZERO
var _drag_last := Vector2.ZERO
var _dragged := false
var _painted: Dictionary = {}

static func grid_to_world(tile: Vector2, footprint: Vector2i = Vector2i.ONE) -> Vector3:
	return Vector3((tile.x + (footprint.x - 1) * 0.5 - 7.5) * TILE, 0,
		(tile.y + (footprint.y - 1) * 0.5 - 7.5) * TILE)

static func world_to_grid(point: Vector3, footprint: Vector2i = Vector2i.ONE) -> Vector2i:
	return Vector2i(floori(point.x / TILE + 8.0 - (footprint.x - 1) * 0.5),
		floori(point.z / TILE + 8.0 - (footprint.y - 1) * 0.5))

func _ready() -> void:
	name = "VillageWorld"
	_terrain = _container("Terrain")
	_entities = _container("Entities")
	_surfaces = _container("Surfaces")
	_selection_outline = _container("Selection")
	_preview = _container("Preview")
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 42.0
	camera.near = 0.1
	camera.far = 300
	add_child(camera)
	camera.current = true
	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Vector3(-52, -32, 0)
	sunlight.light_color = Color("fff8eb")
	sunlight.light_energy = 0.72
	sunlight.shadow_enabled = true
	sunlight.directional_shadow_max_distance = 180
	sunlight.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sunlight.shadow_bias = 0.025
	add_child(sunlight)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("9caeaa")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("d0d8d2")
	environment.environment.ambient_light_energy = 0.28
	environment.environment.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	add_child(environment)
	_apply_camera()
	set_process(false)
	if not _state.is_empty():
		_sync_state()

func _container(title: String) -> Node3D:
	var node := Node3D.new()
	node.name = title
	add_child(node)
	return node

func set_state(state: Dictionary) -> void:
	_state = state.duplicate(true)
	if is_node_ready():
		_sync_state()

func set_tool(kind: String, facing: int = 0, instant: bool = false) -> void:
	_tool = kind
	_facing = posmod(facing, 4)
	_instant = instant
	_painted.clear()
	if is_node_ready():
		_update_preview()

func set_selection(selection: Dictionary) -> void:
	_selection = selection.duplicate()
	if is_node_ready():
		_update_selection()

func set_reduce_motion(value: bool) -> void:
	_reduced_motion = value
	# Scene changes are immediate; no idle animation runs, including when inactive.

func rotate_map(delta: int) -> void:
	_camera_turn = posmod(_camera_turn + delta, 4)
	if camera != null:
		_apply_camera()

func zoom_camera(factor: float) -> void:
	if camera != null and is_finite(factor) and factor > 0:
		camera.size = clampf(camera.size * factor, 16.0, 115.0)

func reset_camera() -> void:
	camera_target = Vector3.ZERO
	if camera != null:
		camera.size = 42
		_apply_camera()

func _apply_camera() -> void:
	var angle := PI * 0.25 + _camera_turn * PI * 0.5
	camera.position = camera_target + Vector3(sin(angle) * 50, 48, cos(angle) * 50)
	camera.look_at(camera_target)

func _pan_target(delta: Vector3) -> void:
	camera_target = Vector3(clampf(camera_target.x + delta.x, -44, 44), 0,
		clampf(camera_target.z + delta.z, -44, 44))
	_apply_camera()

func _sync_state() -> void:
	var winter := Rules.display_season(_state) == 3
	_sync_terrain()
	var expected: Dictionary = {"house": true, "worker-ion": true}
	_sync_entity("house", "house:%s:%s:%s" % [_state.get("houseLevel", 1), _state.get("house", 55), winter],
		func(): return Models.building("house", int(_state.get("houseLevel", 1)), float(_state.get("house", 55)), winter),
		Vector2i(6, 6), Vector2i(3, 3), 0, {"kind": "hotspot", "id": "house"})
	var records: Dictionary = {}
	for record: Dictionary in _state.get("buildings", []):
		records[str(record["id"])] = record
	var layout: Dictionary = _state.get("layout", {})
	for placement: Dictionary in layout.get("buildings", []):
		var id := str(placement["id"])
		var record: Dictionary = records.get(id, {})
		var task: String = "buildWoodshed" if id == "woodshed" else "buildCellar"
		var planned: bool = record.is_empty() and _state.get("assignments", {}).values().has(task)
		if record.is_empty() and not planned:
			continue
		var level := int(record.get("level", 0))
		var condition := float(record.get("condition", 100))
		var progress := 1.0 if level > 0 else clampf((float(_state.get("week", 0)) + 1) / 12.0, 0.08, 0.92)
		var key := "building-" + id
		expected[key] = true
		_sync_entity(key, "%s:%d:%s:%s:%s" % [id, level, condition, winter, progress],
			func(): return Models.building(id, level, condition, winter, progress),
			_point(placement["position"]), Rules.footprint(id, int(placement.get("facing", 0))),
			int(placement.get("facing", 0)), {"kind": "building", "id": id})
	for placement: Dictionary in layout.get("scenery", []):
		var id := str(placement["id"])
		var kind := str(placement["kind"])
		var key := "scenery-" + id
		expected[key] = true
		_sync_entity(key, "%s:%s" % [kind, winter], func(): return Models.scenery(kind, winter),
			_point(placement["position"]), Rules.footprint("scenery:" + kind, int(placement.get("facing", 0))),
			int(placement.get("facing", 0)), {"kind": "scenery", "id": id})
	var task := str(_state.get("assignments", {}).get("ion", "rest"))
	_sync_entity("worker-ion", task, func(): return Models.figure(task), Vector2i.ZERO, Vector2i.ONE, 0,
		{"kind": "worker", "id": "ion"})
	var worker := _entities.get_node("worker-ion") as Node3D
	worker.position = _worker_position(task)
	worker.visible = _state.get("phase", "work") != "dead"
	for child in _entities.get_children():
		if not expected.has(str(child.name)):
			_entities.remove_child(child)
			child.queue_free()
	_sync_surfaces(winter)
	_update_selection()
	_update_preview()

func _point(value: Dictionary) -> Vector2i:
	return Vector2i(int(value["x"]), int(value["y"]))

func _sync_entity(key: String, signature: String, factory: Callable, tile: Vector2i,
		footprint: Vector2i, facing: int, selection: Dictionary) -> void:
	var entity := _entities.get_node_or_null(NodePath(key)) as Node3D
	if entity == null:
		entity = Node3D.new()
		entity.name = key
		_entities.add_child(entity)
	if entity.get_meta("signature", "") != signature:
		_clear(entity)
		var model := factory.call() as Node3D
		entity.add_child(model)
		_add_selection_body(entity, _model_bounds(model), selection)
		entity.set_meta("signature", signature)
	entity.set_meta("selection", selection)
	entity.set_meta("footprint", footprint)
	entity.position = grid_to_world(Vector2(tile), footprint)
	entity.rotation.y = -facing * PI * 0.5

func _model_bounds(node: Node3D, transform: Transform3D = Transform3D.IDENTITY) -> AABB:
	var combined := AABB()
	var current := transform * node.transform
	if node is MeshInstance3D and node.mesh != null:
		combined = current * node.mesh.get_aabb()
	for child in node.get_children():
		if child is Node3D:
			var bounds := _model_bounds(child, current)
			if bounds.size != Vector3.ZERO:
				combined = bounds if combined.size == Vector3.ZERO else combined.merge(bounds)
	return combined

func _add_selection_body(entity: Node3D, bounds: AABB, selection: Dictionary) -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.set_meta("selection", selection)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(bounds.size.x, 0.35), maxf(bounds.size.y, 0.35), maxf(bounds.size.z, 0.35))
	shape.shape = box
	shape.position = bounds.get_center()
	body.add_child(shape)
	entity.add_child(body)

func _worker_position(task: String) -> Vector3:
	var tile := Vector2(7.4, 9.05)
	match task:
		"plant", "tend", "harvest":
			var field: Array = _state.get("layout", {}).get("farmland", [])
			if not field.is_empty():
				tile = Vector2(_point(field[0])) + Vector2(0.25, 0.35)
		"repair": tile = Vector2(8.65, 7.1)
		"paid": tile = Vector2(12, 8)
		"supplies": tile = Vector2(9.7, 8.3)
		"gatherWood": tile = Vector2(1, 12)
		"gatherStone": tile = Vector2(14, 3)
		"buildWoodshed", "buildCellar":
			var id := "woodshed" if task == "buildWoodshed" else "cellar"
			tile = Vector2(3, 8) if id == "woodshed" else Vector2(10, 5)
			for placement: Dictionary in _state.get("layout", {}).get("buildings", []):
				if placement["id"] == id:
					tile = Vector2(_point(placement["position"]))
			tile += Vector2(1.45, 1.5)
	return grid_to_world(tile)

func _sync_terrain() -> void:
	var layout: Dictionary = _state.get("layout", {})
	var season := int(Rules.display_season(_state))
	var signature := "%s:%s" % [season, layout.get("ownedParcels", [])]
	if signature == _terrain_signature:
		return
	_terrain_signature = signature
	_clear(_terrain)
	var owned: Array = layout.get("ownedParcels", [{"x": 0, "y": 0}])
	var colors := [Color("69774f"), Color("737b4f"), Color("897c59"), Color("bec5be")]
	for z in range(-1, 2):
		for x in range(-1, 2):
			var parcel := Vector2i(x, z)
			var unlocked := owned.any(func(value): return _point(value) == parcel)
			var root := Node3D.new()
			root.position = Vector3(x * 32, -0.1, z * 32)
			_terrain.add_child(root)
			var tint: Color = colors[season] if unlocked else colors[season].lerp(Color("626b5e"), 0.68)
			_box(root, Vector3(32, 0.2, 32), Vector3.ZERO,
				_material("ground:%d:%s" % [season, unlocked], tint, "snow" if season == 3 else "grass", 16))
			_outline(root, Vector2(32, 32), Color("858d6c") if unlocked else Color("7c826f"), 0.035, 0.22)
			if not unlocked:
				var label := Label3D.new()
				label.text = "Locked land\n16 × 16"
				label.font_size = 32
				label.pixel_size = 0.022
				label.outline_size = 2
				label.outline_modulate = Color(0.19, 0.23, 0.18, 0.32)
				label.position.y = 0.4
				label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				label.modulate = Color(0.63, 0.67, 0.56, 0.68)
				label.no_depth_test = false
				root.add_child(label)

func _sync_surfaces(winter: bool) -> void:
	var wanted: Dictionary = {}
	var layout: Dictionary = _state.get("layout", {})
	var crop: String = Rules.crop_stage(_state)
	for pair in [["pavement", "pavement"], ["dirtPaths", "dirtPath"], ["farmland", "farmland"]]:
		for value: Dictionary in layout.get(pair[0], []):
			var tile := _point(value)
			var key := "%s_%d_%d" % [pair[1], tile.x, tile.y]
			wanted[key] = true
			_sync_surface(key, "%s:%s:%s" % [pair[1], winter, crop if pair[1] == "farmland" else ""],
				pair[1], tile, 0, winter, crop)
	for fence: Dictionary in layout.get("fences", []):
		var tile := _point(fence["position"])
		var facing := int(fence.get("facing", 0))
		var kind := "wattleFence" if fence.get("style", "rail") == "wattle" else "fence"
		var key := "fence_%d_%d_%d" % [tile.x, tile.y, facing]
		wanted[key] = true
		_sync_surface(key, "%s:%s" % [kind, winter], kind, tile, facing, winter, "")
	for child in _surfaces.get_children():
		if not wanted.has(str(child.name)):
			_surfaces.remove_child(child)
			child.queue_free()

func _sync_surface(key: String, signature: String, kind: String, tile: Vector2i, facing: int, winter: bool, crop: String) -> void:
	var node := _surfaces.get_node_or_null(NodePath(key)) as Node3D
	if node == null:
		node = Node3D.new()
		node.name = key
		_surfaces.add_child(node)
	if node.get_meta("signature", "") != signature:
		_clear(node)
		node.add_child(_infrastructure(kind, winter, crop))
		node.set_meta("signature", signature)
	node.position = grid_to_world(Vector2(tile))
	node.rotation.y = -facing * PI * 0.5

func _infrastructure(kind: String, winter: bool, crop: String = "") -> Node3D:
	var node := Node3D.new()
	var wood := _material("wood", Color("88704a"), "wood")
	match kind:
		"fence", "wattleFence":
			for x in [-0.9, 0.9]:
				_box(node, Vector3(0.13, 1.1, 0.13), Vector3(x, 0.55, -1), wood)
			if kind == "fence":
				for y in [0.4, 0.84]:
					_box(node, Vector3(1.88, 0.1, 0.09), Vector3(0, y, -1), wood)
			else:
				var reeds: Array[Transform3D] = []
				for x in range(13):
					reeds.append(Transform3D(Basis.IDENTITY, Vector3(-0.84 + x * 0.14, 0.45, -1)))
				_instances(node, Vector3(0.045, 0.9, 0.045), reeds, wood)
				for y in range(6):
					_box(node, Vector3(1.9, 0.05, 0.08), Vector3(0, 0.13 + y * 0.14, -1), wood)
			if winter:
				var snow := _material("snow", Color("e4e6df"), "snow")
				_box(node, Vector3(1.88, 0.045, 0.13), Vector3(0, 0.91, -1), snow)
				for x in [-0.9, 0.9]:
					_box(node, Vector3(0.16, 0.045, 0.16), Vector3(x, 1.12, -1), snow)
		"pavement":
			_box(node, Vector3(1.98, 0.055, 1.98), Vector3(0, 0.025, 0),
				_material("paving", Color("b5ad93"), "stone"))
		"dirtPath":
			_box(node, Vector3(1.99, 0.035, 1.99), Vector3(0, 0.015, 0),
				_material("path", Color("ae9667"), "dirt"))
		"farmland":
			_box(node, Vector3(1.98, 0.04, 1.98), Vector3(0, 0.02, 0),
				_material("soil-snow" if winter else "soil", Color("c4c8b8") if winter else Color("735537"), "snow" if winter else "dirt"))
			var furrows: Array[Transform3D] = []
			for row in range(5):
				furrows.append(Transform3D(Basis.IDENTITY, Vector3(0, 0.053, -0.8 + row * 0.4)))
			_instances(node, Vector3(1.85, 0.05, 0.055), furrows, _material("furrow", Color("503c2a"), "dirt"))
			if not winter and crop not in ["empty", "bare", "fallow", "harvested", "dormant", "snow", ""]:
				var ripe := crop in ["ripe", "ready", "mature"]
				var height := 0.7 if ripe else 0.08 if crop in ["planted", "seedling", "sown"] else 0.22 if crop in ["sprout", "sprouting"] else 0.46
				var stalks: Array[Transform3D] = []
				var heads: Array[Transform3D] = []
				for row in range(4):
					for col in range(4):
						var p := Vector3(-0.72 + col * 0.48, height * 0.5 + 0.08, -0.65 + row * 0.42)
						stalks.append(Transform3D(Basis.IDENTITY, p))
						if ripe:
							heads.append(Transform3D(Basis(Vector3.FORWARD, 0.2), p + Vector3(0, height * 0.5, 0)))
				var crop_material := _material("grain" if ripe else "shoot", Color("d2af50") if ripe else Color("69883b"), "grass")
				_instances(node, Vector3(0.055, height, 0.055), stalks, crop_material)
				if ripe:
					_instances(node, Vector3(0.13, 0.22, 0.09), heads, crop_material)
	return node

func _instances(parent: Node3D, size: Vector3, transforms: Array[Transform3D], material: StandardMaterial3D) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = _box_mesh(size)
	multi.instance_count = transforms.size()
	for index in range(transforms.size()):
		multi.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.multimesh = multi
	instance.material_override = material
	parent.add_child(instance)

func _box_mesh(size: Vector3) -> BoxMesh:
	if not _box_meshes.has(size):
		var mesh := BoxMesh.new()
		mesh.size = size
		_box_meshes[size] = mesh
	return _box_meshes[size]

func _box(parent: Node3D, size: Vector3, point: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = _box_mesh(size)
	instance.material_override = material
	instance.position = point
	parent.add_child(instance)
	return instance

func _material(key: String, tint: Color, texture_kind: String = "", repeats: float = 1) -> StandardMaterial3D:
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.roughness = 0.94
	if not texture_kind.is_empty():
		var image := Image.create(64, 64, false, Image.FORMAT_RGB8)
		var ground_texture := key.begins_with("ground:")
		for y in range(64):
			for x in range(64):
				var noise := float(posmod(x * 73 + y * 137 + x * y * 19, 97)) / 97.0
				var shade := 0.94 + noise * 0.06 if ground_texture else 0.79 + noise * 0.3
				if texture_kind == "stone" and (x % 21 <= 1 or (y + (x / 21) * 9) % 21 <= 1):
					shade = 0.53
				elif texture_kind == "wood":
					shade *= 0.85 if (x + y / 16) % 13 <= 1 else 1.0
				elif texture_kind == "grass":
					shade *= (0.98 if ground_texture else 0.86) if (x * 3 + y) % 17 < 2 else 1.0
				image.set_pixel(x, y, Color(shade, shade, shade))
		image.generate_mipmaps()
		material.albedo_texture = ImageTexture.create_from_image(image)
		material.uv1_scale = Vector3(repeats, repeats, repeats)
	_materials[key] = material
	return material

func _outline(parent: Node3D, size: Vector2, color: Color, width: float = 0.06, height: float = 0.09) -> void:
	var material := _material("outline:" + color.to_html(), color)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for z in [-size.y / 2, size.y / 2]:
		_box(parent, Vector3(size.x, width, width), Vector3(0, height, z), material)
	for x in [-size.x / 2, size.x / 2]:
		_box(parent, Vector3(width, width, size.y), Vector3(x, height, 0), material)

func _update_selection() -> void:
	_clear(_selection_outline)
	_selection_outline.position = Vector3.ZERO
	if _selection.is_empty():
		return
	if _selection.get("kind") == "hotspot" and _selection.get("id") == "field":
		for value: Dictionary in _state.get("layout", {}).get("farmland", []):
			var node := Node3D.new()
			node.position = grid_to_world(Vector2(_point(value)))
			_selection_outline.add_child(node)
			_outline(node, Vector2(2, 2), Color("ead08a"))
		return
	for entity in _entities.get_children():
		if entity.get_meta("selection", {}) == _selection:
			_selection_outline.position = entity.position
			var footprint: Vector2i = entity.get_meta("footprint", Vector2i.ONE)
			_outline(_selection_outline, Vector2(footprint) * TILE, Color("efcb76"))
			return

func _update_preview() -> void:
	if _preview == null:
		return
	_preview.visible = not _tool.is_empty() and not _state.is_empty()
	if not _preview.visible:
		return
	var winter := Rules.display_season(_state) == 3
	var problem: String = Rules.placement_problem(_state, _tool, _preview_tile, _facing)
	var tint := Color(0.35, 0.85, 0.48, 0.4) if problem.is_empty() else Color(0.95, 0.28, 0.2, 0.4)
	var level := 1 if _instant else 0
	var condition := 100.0
	for record: Dictionary in _state.get("buildings", []):
		if record["id"] == _tool:
			level = int(record.get("level", level))
			condition = float(record.get("condition", condition))
	var progress := 1.0 if level > 0 else clampf((float(_state.get("week", 0)) + 1) / 12.0, 0.08, 0.92)
	var signature := "%s:%s:%s:%s:%s:%s" % [_tool, winter, problem.is_empty(), level, condition, progress]
	if signature != _preview_signature:
		_preview_signature = signature
		_clear(_preview)
		var model: Node3D
		if _tool.begins_with("scenery:"):
			model = Models.scenery(_tool.trim_prefix("scenery:"), winter)
		elif PAINT_TOOLS.has(_tool):
			model = _infrastructure(_tool, winter)
		else:
			model = Models.building(_tool, level, condition, winter, progress)
		_preview.add_child(model)
		_tint_ghost(model, tint)
		_preview_outline = Node3D.new()
		_preview.add_child(_preview_outline)
	var footprint: Vector2i = Rules.footprint(_tool, _facing)
	_preview.position = grid_to_world(Vector2(_preview_tile), footprint)
	_preview.rotation.y = -_facing * PI * 0.5
	_clear(_preview_outline)
	# The outline remains world-aligned for rectangular footprints after rotating the ghost.
	_preview_outline.rotation.y = _facing * PI * 0.5
	_outline(_preview_outline, Vector2(footprint) * TILE, Color(tint.r, tint.g, tint.b, 1), 0.07, 0.12)

func _tint_ghost(node: Node3D, tint: Color) -> void:
	if node is GeometryInstance3D:
		var material := StandardMaterial3D.new()
		material.albedo_color = tint
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for child in node.get_children():
		if child is CollisionObject3D:
			node.remove_child(child)
			child.queue_free()
		elif child is Node3D:
			_tint_ghost(child, tint)

func _clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _ground_point(screen: Vector2) -> Variant:
	if camera == null:
		return null
	return GROUND.intersects_ray(camera.project_ray_origin(screen), camera.project_ray_normal(screen))

func _pointer_tile(screen: Vector2) -> Variant:
	var point: Variant = _ground_point(screen)
	if point == null:
		return null
	return world_to_grid(point, Rules.footprint(_tool, _facing) if not _tool.is_empty() else Vector2i.ONE)

func _place_at(screen: Vector2) -> void:
	var tile: Variant = _pointer_tile(screen)
	if tile == null:
		return
	var key := "%s:%s:%s" % [_tool, tile, _facing]
	if _painted.has(key):
		return
	_painted[key] = true
	_preview_tile = tile
	_update_preview()
	# Rules own rejection messages and atomic changes; every attempt reaches the interface.
	placement_requested.emit(_tool, tile, _facing)

func _select_at(screen: Vector2) -> void:
	var point: Variant = _ground_point(screen)
	if point == null:
		return
	var ray := PhysicsRayQueryParameters3D.create(camera.project_ray_origin(screen),
		camera.project_ray_origin(screen) + camera.project_ray_normal(screen) * 300, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		var selection: Dictionary = hit["collider"].get_meta("selection", {})
		set_selection(selection)
		selection_changed.emit(selection)
		return
	var tile := world_to_grid(point)
	if tile.x < -16 or tile.y < -16 or tile.x > 31 or tile.y > 31:
		return
	var parcel := Vector2i(floori(tile.x / 16.0), floori(tile.y / 16.0))
	var owned: Array = _state.get("layout", {}).get("ownedParcels", [])
	if not owned.any(func(value): return _point(value) == parcel):
		parcel_selected.emit(parcel)
		return
	var selection: Dictionary = {}
	if _state.get("layout", {}).get("farmland", []).any(func(value): return _point(value) == tile):
		selection = {"kind": "hotspot", "id": "field"}
	set_selection(selection)
	selection_changed.emit(selection)

func _unhandled_input(event: InputEvent) -> void:
	if camera == null or _state.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R and not _tool.is_empty():
			_facing = posmod(_facing + 1, 4)
			tool_rotated.emit(_facing)
			_update_preview()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_HOME:
			reset_camera()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE and not _tool.is_empty():
			set_tool("")
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and event.pressed:
			var direction := -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
			if event.shift_pressed:
				_pan_target(camera.global_basis.x * direction * camera.size * 0.06)
			else:
				zoom_camera(pow(1.12, direction * maxf(event.factor, 0.1)))
			get_viewport().set_input_as_handled()
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if event.pressed:
				_drag_button = event.button_index
				_drag_start = event.position
				_drag_last = event.position
				_dragged = false
				_painted.clear()
			elif _drag_button == event.button_index:
				if not _dragged and event.button_index == MOUSE_BUTTON_LEFT:
					if _tool.is_empty():
						_select_at(event.position)
					else:
						_place_at(event.position)
				_drag_button = 0
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		var tile: Variant = _pointer_tile(event.position)
		if tile != null and tile != _preview_tile:
			_preview_tile = tile
			_update_preview()
		if _drag_button != 0:
			if not Input.is_mouse_button_pressed(_drag_button):
				_drag_button = 0
				return
			var started: bool = not _dragged and event.position.distance_to(_drag_start) > 7
			_dragged = _dragged or started
			if _dragged:
				if _drag_button == MOUSE_BUTTON_LEFT and PAINT_TOOLS.has(_tool):
					if started:
						_place_at(_drag_start)
					_place_at(event.position)
				else:
					var previous: Variant = _ground_point(_drag_last)
					var current: Variant = _ground_point(event.position)
					if previous != null and current != null:
						_pan_target(previous - current)
			_drag_last = event.position
			get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture:
		zoom_camera(1.0 / maxf(event.factor, 0.01))
		get_viewport().set_input_as_handled()
	elif event is InputEventPanGesture:
		var right := camera.global_basis.x
		var forward := Vector3(camera.global_basis.z.x, 0, camera.global_basis.z.z).normalized()
		_pan_target((right * event.delta.x + forward * event.delta.y) * camera.size * 0.012)
		get_viewport().set_input_as_handled()
