extends Node3D
## Original low-poly clothing and camp, interpreted rather than reconstructed.
## Geometry is in metres; only this root and the separate camp convert units.

## Looks the creation screen offers; the farmer starts with the first of each.
const SKINS := {"Tanned": Color("b6805c"), "Fair": Color("e0b89a"), "Rosy": Color("d39a7e"), "Olive": Color("9d7651"), "Brown": Color("7a523a")}
const HAIRS := {"Dark brown": Color("382a23"), "Black": Color("1c1917"), "Chestnut": Color("6b3f26"), "Fair": Color("b08d58"), "Red": Color("8a3a1e"), "Grey": Color("8d877d")}
const BEARDS := ["None", "Moustache", "Beard"]
const CLOTHES := {"Undyed linen": Color("c4b393"), "Bleached linen": Color("e4ddc9"), "Grey wool": Color("8b877b"), "Brown wool": Color("6d5844"), "Madder red": Color("8f3d2f"), "Woad blue": Color("4d6275")}

var _metres_to_units: float
var _time := 0.0
var _body: Node3D
var _tunic: MeshInstance3D
var _head: Node3D
var _moustache: MeshInstance3D
var _beard: MeshInstance3D
var _left_arm: Node3D
var _right_arm: Node3D
var _left_forearm: Node3D
var _right_forearm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _sack: Node3D
var _hoe: Node3D
var _sickle: Node3D
var _label: Label3D

var _linen := _material(Color("c4b393"))
var _clothes := _material(CLOTHES.values()[0])
var _trousers := _material(Color("484b40"))
var _leather := _material(Color("493427"))
var _skin := _material(SKINS.values()[0])
var _hair := _material(HAIRS.values()[0])
var _wood := _material(Color("775336"))
var _iron := _material(Color("606665"))
var _burlap := _material(Color("a78c60"))

func _init(metres_to_units: float) -> void:
	_metres_to_units = metres_to_units
	name = "Farmer"
	scale = Vector3.ONE * metres_to_units
	_body = _pivot(self, "Body", Vector3.ZERO)
	_tunic = _part(_body, _cylinder(0.23, 0.28, 0.64), _clothes, Vector3(0, 1.08, 0))
	_tunic.scale.z = 0.65
	var belt := _part(_body, _cylinder(0.266, 0.266, 0.06), _leather, Vector3(0, 0.95, 0))
	belt.scale.z = 0.66
	_part(_body, _box(Vector3(0.07, 0.055, 0.025)), _iron, Vector3(0, 0.95, -0.182))
	_part(_body, _cylinder(0.065, 0.07, 0.12), _skin, Vector3(0, 1.41, 0))
	_head = _pivot(_body, "Head", Vector3(0, 1.56, 0))
	_part(_head, _sphere(0.125, 0.27), _skin, Vector3.ZERO)
	var hair := _part(_head, _sphere(0.132, 0.18), _hair, Vector3(0, 0.068, 0.014))
	hair.scale.z = 0.94
	_part(_head, _box(Vector3(0.07, 0.075, 0.06)), _skin, Vector3(0, -0.005, -0.12))
	_moustache = _part(_head, _box(Vector3(0.1, 0.022, 0.03)), _hair, Vector3(0, -0.045, -0.118))
	_beard = _part(_head, _sphere(0.1, 0.16), _hair, Vector3(0, -0.09, -0.055))
	_moustache.visible = false
	_beard.visible = false
	for side in [-1, 1]:
		var arm := _pivot(_body, "LeftArm" if side < 0 else "RightArm", Vector3(side * 0.265, 1.34, 0))
		_part(arm, _cylinder(0.095, 0.078, 0.25), _clothes, Vector3(0, -0.12, 0))
		var forearm := _pivot(arm, "Forearm", Vector3(0, -0.24, 0))
		_part(forearm, _cylinder(0.058, 0.042, 0.22), _skin, Vector3(0, -0.11, 0))
		_part(forearm, _box(Vector3(0.085, 0.105, 0.07)), _skin, Vector3(0, -0.255, 0))
		var leg := _pivot(_body, "LeftLeg" if side < 0 else "RightLeg", Vector3(side * 0.105, 0.82, 0))
		_part(leg, _cylinder(0.095, 0.065, 0.65), _trousers, Vector3(0, -0.325, 0))
		_part(leg, _cylinder(0.072, 0.072, 0.22), _leather, Vector3(0, -0.64, 0))
		_part(leg, _box(Vector3(0.16, 0.16, 0.29)), _leather, Vector3(0, -0.74, -0.04))
		if side < 0:
			_left_arm = arm
			_left_forearm = forearm
			_left_leg = leg
		else:
			_right_arm = arm
			_right_forearm = forearm
			_right_leg = leg
	_sack = _pivot(_body, "CarriedSack", Vector3(0, 1.02, 0.25))
	var sack := _part(_sack, _sphere(0.17, 0.45), _burlap, Vector3.ZERO)
	sack.scale.z = 0.7
	_part(_sack, _cylinder(0.055, 0.075, 0.08), _leather, Vector3(0, 0.22, 0))
	for side in [-1, 1]:
		var strap := _part(_sack, _box(Vector3(0.035, 0.39, 0.025)), _leather, Vector3(side * 0.13, 0.12, -0.12))
		strap.rotation.x = -0.4
	_sack.visible = false
	_make_tools()
	var marker := _material(Color("e4cb7c"))
	marker.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring := TorusMesh.new()
	ring.inner_radius = 0.56
	ring.outer_radius = 0.62
	ring.rings = 24
	ring.ring_segments = 6
	var locator := _part(self, ring, marker, Vector3(0, 0.02, 0))
	locator.name = "Locator"
	locator.scale.y = 0.25
	_label = Label3D.new()
	_label.name = "Name"
	_label.font_size = 32
	_label.pixel_size = 0.003
	_label.fixed_size = true
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position.y = 2.15
	_label.modulate = Color("f3e4bc")
	_label.outline_modulate = Color("2c281f")
	add_child(_label)

## Colours the farmer and grows the beard chosen on the creation screen.
func dress(peasant: Dictionary) -> void:
	_skin.albedo_color = SKINS[peasant.skin]
	_hair.albedo_color = HAIRS[peasant.hair]
	_clothes.albedo_color = CLOTHES[peasant.clothes]
	_moustache.visible = peasant.beard != "None"
	_beard.visible = peasant.beard == "Beard"

func show_person(person, seconds: float) -> void:
	_time += maxf(seconds, 0.0)
	position = Vector3(person.position.x, 0, person.position.y) * _metres_to_units
	if person.facing.length_squared() > 0.0001:
		rotation.y = atan2(-person.facing.x, -person.facing.y)
	var swing := sin(_time * 7.5)
	# The mesh is the default body; mass grows with height and the square of width.
	var tall: float = person.height / Human.HEIGHT
	var wide := sqrt(person.mass() / (Human.START_FAT + Human.START_LEAN) / tall)
	_body.scale = Vector3(wide, tall, wide)
	_label.text = person.name
	_label.position.y = person.height + 0.43
	_body.position = Vector3.ZERO
	_body.rotation = Vector3.ZERO
	_tunic.scale.z = 0.65
	_head.rotation = Vector3.ZERO
	_left_leg.rotation = Vector3.ZERO
	_right_leg.rotation = Vector3.ZERO
	_left_arm.rotation = Vector3(0, 0, 0.06)
	_right_arm.rotation = Vector3(0, 0, -0.06)
	_left_forearm.rotation = Vector3.ZERO
	_right_forearm.rotation = Vector3.ZERO
	_sack.visible = person.carried > 0 and person.activity not in ["Sleeping", "Dead"]
	_hoe.visible = false
	_sickle.visible = false
	_label.modulate = Color("bc8c81") if person.activity == "Dead" else Color("f3e4bc")
	match person.activity:
		"Walking":
			_body.position.y = 0.012 * absf(swing)
			_left_leg.rotation.x = swing * 0.34
			_right_leg.rotation.x = -swing * 0.34
			_left_arm.rotation.x = -swing * 0.3
			_right_arm.rotation.x = swing * 0.3
			_left_forearm.rotation.x = 0.12
			_right_forearm.rotation.x = 0.12
		"Working":
			_head.rotation.x = -0.12
			match person.job.get("action", ""):
				"Plow":
					_hoe.visible = true
					_right_arm.rotation.x = 0.5 + swing * 0.2
					_left_arm.rotation.x = 0.6 + swing * 0.18
					_left_arm.rotation.z = -0.35
					_right_forearm.rotation.x = 0.35
					_left_forearm.rotation.x = 0.7
				"Sow":
					_right_arm.rotation = Vector3(0.65 + swing * 0.35, 0, 0.2 + cos(_time * 7.5) * 0.35)
					_right_forearm.rotation.x = 0.25
					_left_arm.rotation.x = 0.45
					_left_forearm.rotation.x = 0.9
				"Harvest":
					_sickle.visible = true
					_right_arm.rotation = Vector3(0.9, 0, swing * 0.5)
					_right_forearm.rotation.x = 0.65
					_left_arm.rotation.x = 1.0 + swing * 0.15
					_left_forearm.rotation.x = 0.25
		"Resting", "Cooking":
			_body.position.y = -0.68 * tall
			_tunic.scale.z += sin(_time * 2.0) * 0.009
			_left_leg.rotation.x = PI / 2
			_right_leg.rotation.x = PI / 2
			_left_forearm.rotation.x = 0.5
			_right_forearm.rotation.x = 0.5
			if person.activity == "Cooking":
				_right_arm.rotation.x = 0.65 + swing * 0.15
				_left_arm.rotation.x = 0.5
		"Sleeping", "Dead":
			_body.position.y = 0.25
			_body.rotation.x = PI / 2
			_left_forearm.rotation.x = 0.18
			_right_forearm.rotation.x = 0.18
			if person.activity == "Dead":
				_body.rotation.z = 0.2
				_head.rotation.z = 0.25
				_left_arm.rotation.z = 0.16
			else:
				_body.position.y = 0.3
				# The fixed bedroll has one direction, whatever the walk home faced.
				_body.rotation.y = -rotation.y
				_tunic.scale.z += sin(_time * 2.0) * 0.009

func create_camp() -> Node3D:
	var camp := Node3D.new()
	camp.name = "Camp"
	camp.scale = Vector3.ONE * _metres_to_units
	var soil := _material(Color("75674c"))
	_part(camp, _cylinder(2.2, 2.2, 0.018, 20), soil, Vector3(0, 0.009, 0))
	var blanket := _material(Color("71715a"))
	# Long and wide enough for the tallest and heaviest peasant the creation screen allows.
	var bedroll := _part(camp, _box(Vector3(0.9, 0.08, 2.0)), blanket, Vector3(0, 0.06, 0.9))
	bedroll.name = "Bedroll"
	_part(camp, _box(Vector3(0.64, 0.12, 0.28)), _linen, Vector3(0, 0.13, 1.56))
	var rolled := _part(camp, _cylinder(0.12, 0.12, 0.78), blanket, Vector3(0, 0.17, -0.08))
	rolled.rotation.z = PI / 2
	var fire_at := Vector3(0.8, 0, -0.55)
	for angle in [-0.6, 0.6]:
		var log_piece := _part(camp, _cylinder(0.055, 0.055, 0.62), _wood, fire_at + Vector3(0, 0.07, 0))
		log_piece.rotation = Vector3(PI / 2, angle, 0)
	var ember := _material(Color("d17a36"))
	ember.emission_enabled = true
	ember.emission = Color("c75d26")
	ember.emission_energy_multiplier = 0.5
	_part(camp, _cylinder(0.0, 0.15, 0.18), ember, fire_at + Vector3(0, 0.15, 0))
	var firelight := OmniLight3D.new()
	firelight.name = "Firelight"
	firelight.light_color = Color(1.0, 0.6, 0.3)
	firelight.omni_range = 9.0
	firelight.position = fire_at + Vector3(0, 0.6, 0)
	camp.add_child(firelight)
	var pot := _material(Color("353938"))
	_part(camp, _cylinder(0.19, 0.14, 0.25), pot, fire_at + Vector3(0, 0.32, 0))
	var rim := TorusMesh.new()
	rim.inner_radius = 0.17
	rim.outer_radius = 0.2
	rim.rings = 12
	rim.ring_segments = 6
	_part(camp, rim, _iron, fire_at + Vector3(0, 0.445, 0))
	_part(camp, _cylinder(0.165, 0.165, 0.01), _material(Color("635b39")), fire_at + Vector3(0, 0.42, 0))
	for spot in [Vector3(0.8, 0.28, 0.95), Vector3(1.25, 0.3, 0.7)]:
		_part(camp, _sphere(0.24, spot.y * 2 - 0.03), _burlap, spot)
		_part(camp, _cylinder(0.07, 0.09, 0.08), _linen, spot + Vector3(0, spot.y - 0.02, 0))
	var grain := Label3D.new()
	grain.text = "Grain"
	grain.font_size = 32
	grain.pixel_size = 0.008
	grain.position = Vector3(1.1, 0.3, 0.51)
	grain.modulate = Color("3d3023")
	grain.outline_size = 0
	camp.add_child(grain)
	return camp

func _make_tools() -> void:
	_hoe = _pivot(_right_forearm, "Hoe", Vector3(0, -0.23, 0))
	_hoe.rotation.x = -0.85
	_part(_hoe, _cylinder(0.017, 0.017, 1.0), _wood, Vector3(0, -0.4, 0))
	_part(_hoe, _box(Vector3(0.24, 0.035, 0.17)), _iron, Vector3(0, -0.89, -0.06))
	_sickle = _pivot(_right_forearm, "Sickle", Vector3(0, -0.25, 0))
	_part(_sickle, _cylinder(0.023, 0.023, 0.22), _wood, Vector3(0, -0.1, 0))
	for index in 4:
		var angle := -0.9 + index * 0.55
		var blade := _part(_sickle, _box(Vector3(0.11, 0.025, 0.025)), _iron, Vector3(0.14 + sin(angle) * 0.14, -0.22 - cos(angle) * 0.14, 0))
		blade.rotation.z = angle
	_hoe.visible = false
	_sickle.visible = false

static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	return material

static func _pivot(parent: Node3D, title: String, at: Vector3) -> Node3D:
	var node := Node3D.new()
	node.name = title
	node.position = at
	parent.add_child(node)
	return node

static func _part(parent: Node3D, mesh: Mesh, material: Material, at: Vector3) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = at
	parent.add_child(node)
	return node

static func _box(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh

static func _cylinder(top: float, bottom: float, height: float, sides := 8) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = sides
	return mesh

static func _sphere(radius: float, height: float) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 4
	return mesh
