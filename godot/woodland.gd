extends Node3D
## Four instanced batches share two original EZ-Tree exports; no tree nodes per plot.
const MODELS := [preload("res://assets/woodland/ash_0.glb"), preload("res://assets/woodland/ash_1.glb")]
const Actor := preload("res://human_actor.gd")
var _terrain: RefCounted
var _scale: float
var _groups: Array[MultiMeshInstance3D] = []
var _materials: Array[ShaderMaterial] = []
var _logs := Node3D.new()
var _state := []

func _init(terrain: RefCounted, metres_to_units: float, crop_texture: Texture2D) -> void:
	name = "Woodland"
	_terrain = terrain
	_scale = metres_to_units
	for model: PackedScene in MODELS:
		var tree := model.instantiate()
		for part in ["Trunk", "Leaves"]:
			var source: MeshInstance3D = tree.find_child(part, true, false)
			var instances := MultiMeshInstance3D.new()
			instances.multimesh = MultiMesh.new()
			instances.multimesh.transform_format = MultiMesh.TRANSFORM_3D
			instances.multimesh.mesh = source.mesh
			var material := ShaderMaterial.new()
			material.shader = preload("res://woodland.gdshader")
			material.set_shader_parameter("bark", preload("res://assets/woodland/bark.jpg"))
			material.set_shader_parameter("leaves", preload("res://assets/woodland/ash.png"))
			material.set_shader_parameter("crops", crop_texture)
			material.set_shader_parameter("foliage", part == "Leaves")
			instances.material_override = material
			_materials.append(material)
			_groups.append(instances)
			add_child(instances)
		tree.free()
	add_child(_logs)

func refresh(farm: Farm, day: int) -> void:
	var season: float = fposmod(float(day), Calendar.DAYS_PER_YEAR) / Calendar.DAYS_PER_SEASON
	for material in _materials:
		material.set_shader_parameter("autumn_mix", smoothstep(2.0, 2.8, season))
		material.set_shader_parameter("leaf_cover", 0.0 if season >= 3.0 else lerpf(0.2, 1.0, smoothstep(0.0, 0.35, season)) if season < 1.0 else 1.0 - smoothstep(2.7, 3.0, season))
	var state := [farm.woodland.keys(), farm.wood_piles.duplicate(), farm.regrowth.duplicate()]
	if state == _state: return
	_state = state
	var transforms := [[], []]
	for cell: Vector2i in farm.woodland:
		for index in 2:
			var variant := posmod(cell.x * 7 + cell.y * 13 + index, 2)
			var point := Vector2(cell) * 2.0 - Vector2.ONE * 15.0 + Vector2(-0.52 if index == 0 else 0.52, 0.35 if index == 0 else -0.35)
			var basis := Basis(Vector3.UP, float(cell.x * 17 + cell.y * 7 + index) * 0.71).scaled(Vector3.ONE * _scale * (0.85 + posmod(cell.x + cell.y, 4) * 0.1))
			transforms[variant].append(Transform3D(basis, Vector3(point.x, _terrain.height_at(point), point.y)))
	for variant in 2:
		for part in 2:
			var multi := _groups[variant * 2 + part].multimesh
			multi.instance_count = transforms[variant].size()
			for index in transforms[variant].size(): multi.set_instance_transform(index, transforms[variant][index])
	for child in _logs.get_children(): child.free()
	var bark := Actor._material(Color("715338"))
	for cell: Vector2i in farm.regrowth:
		var point := Vector2(cell) * 2.0 - Vector2.ONE * 15.0 + Vector2(0.5, 0.3)
		Actor._part(_logs, Actor._cylinder(0.045, 0.065, 0.065), bark, Vector3(point.x, _terrain.height_at(point) + 0.025, point.y))
	for cell: Vector2i in farm.wood_piles:
		var point := Vector2(cell) * 2.0 - Vector2.ONE * 15.0
		for index in ceili(float(farm.wood_piles[cell]) / 40000.0):
			var offset := Vector2((index % 3 - 1) * 0.09, 0)
			var log_piece := Actor._part(_logs, Actor._cylinder(0.035, 0.04, 0.4), bark, Vector3(point.x + offset.x, _terrain.height_at(point + offset) + 0.045 + (index / 3) * 0.06, point.y))
			log_piece.rotation.x = PI / 2

func show_conditions(person: Vector3, camera: Vector3, wind: Vector2, snow: float) -> void:
	for material in _materials:
		material.set_shader_parameter("person", person + Vector3.UP * 0.25)
		material.set_shader_parameter("camera_position", camera)
		material.set_shader_parameter("wind", wind)
		material.set_shader_parameter("snow", snow)
