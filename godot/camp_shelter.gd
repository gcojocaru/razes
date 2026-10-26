extends Node3D
## Original timber hut: the old bedroll and hearth stay inside the completed shell.
const Actor := preload("res://human_actor.gd")
var _parts: Array[MeshInstance3D] = []
var _timber := Actor._material(Color("8a7050"))
var _roof := Actor._material(Color("6e614b"))

func _init() -> void:
	name = "Shelter"
	_timber.albedo_texture = preload("res://assets/woodland/bark.jpg")
	for material in [_timber, _roof]:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for x in [-1.6, 1.6]:
		for z in [-1.0, 2.1]: _add(Actor._box(Vector3(0.15, 1.85, 0.15)), _timber, Vector3(x, 0.95, z))
	for level in 10:
		var y := 0.13 + level * 0.18
		for x in [-1.6, 1.6]: _add(Actor._box(Vector3(0.12, 0.17, 3.2)), _timber, Vector3(x, y, 0.55))
		_add(Actor._box(Vector3(3.2, 0.17, 0.12)), _timber, Vector3(0, y, 2.1))
		for x in [-1.16, 1.16]: _add(Actor._box(Vector3(0.88, 0.17, 0.12)), _timber, Vector3(x, y, -1))
	for side in [-1, 1]:
		for row in 7:
			for column in 10:
				var x: float = side * (0.12 + row * 0.27)
				var y: float = 2.75 - absf(x) * 0.48
				var shingle := _add(Actor._box(Vector3(0.33, 0.055, 0.42)), _roof, Vector3(x, y, -1.2 + column * 0.38))
				shingle.rotation.z = -side * 0.45
	var clay := Actor._material(Color("776f60"))
	_add(Actor._box(Vector3(0.38, 2.8, 0.38)), clay, Vector3(0.8, 1.4, -0.55))
	_add(Actor._box(Vector3(0.52, 0.1, 0.52)), clay, Vector3(0.8, 2.85, -0.55))
	visible = false

func _add(mesh: Mesh, material: Material, point: Vector3) -> MeshInstance3D:
	var part := Actor._part(self, mesh, material, point)
	_parts.append(part)
	return part

func show_camp(farm: Farm, person: Human) -> void:
	visible = farm.shelter or person.build_reserved > 0
	if not visible: return
	var progress: float = 1.0 if farm.shelter else 0.05 + 0.95 * (1.0 - person.build_remaining / Human.BUILD_HOURS)
	for index in _parts.size(): _parts[index].visible = index < ceili(_parts.size() * progress)
	var alpha := 0.2 if person.position.distance_to(person.home) < 4.0 else 1.0
	for material in [_timber, _roof]:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 1 else BaseMaterial3D.TRANSPARENCY_DISABLED
	_timber.albedo_color.a = alpha
	_roof.albedo_color.a = alpha
