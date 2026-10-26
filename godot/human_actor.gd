extends Node3D
## The farmer is a Tripo body rigged to the peasant skeleton, with clothes built around it to
## choose from (assets/peasant/SOURCE.md); the tools, sack and camp are original low-poly meshes,
## interpreted rather than reconstructed. Geometry is in metres; only this root and the
## separate camp convert units.

## Skin tones the creation screen offers; the farmer starts with the first.
const SKINS := {"Tanned": Color("b6805c"), "Fair": Color("e0b89a"), "Rosy": Color("d39a7e"), "Olive": Color("9d7651"), "Brown": Color("7a523a")}
## Hair and facial hair the creation screen offers; the farmer starts with the first of each.
const HAIR := {
	"hair": ["Cropped", "Bald", "Bowl", "Long"],
	"beard": ["Moustache", "Shaven", "Beard"],
}
## Hair colours, for the hair and the beard alike; the farmer starts with the first.
const HAIR_COLOURS := {"Dark brown": Color("4a3426"), "Black": Color("2a211c"), "Brown": Color("6e5039"), "Fair": Color("b0905e"), "Grey": Color("9a948c")}
## Clothes the creation screen offers, by what they are worn as; the farmer starts in the first of each.
const CLOTHES := {
	"shirt": ["Embroidered", "Plain"],
	"belt": ["Brâu", "Chimir"],
	"hat": ["None", "Cușmă", "Pălărie"],
	"footwear": ["Opinci", "Barefoot"],
}
## The model's parts each choice of hair or clothes puts on; the parts of the others are taken off.
const WORN := {
	"Cropped": ["HairCropped"], "Bowl": ["HairBowl"], "Long": ["HairLong"], "Moustache": ["Moustache"], "Beard": ["Beard", "Moustache"],
	"Brâu": ["Belt"], "Chimir": ["Chimir"], "Cușmă": ["Cusma"], "Pălărie": ["Palarie"], "Opinci": ["Opinci", "Laces"],
}

## Which clip, and which seconds of it, each pose plays: loops repeat the span,
## holds sway through it and back every four seconds, and once plays and stays.
const POSES := {
	"Idle": ["Idle", 0.0, 2.5, "loop"],
	"Walking": ["Walk", 0.0, 1.333, "loop"],
	"Chop": ["TreeChopping", 0.0, 0.958, "loop"],
	"Plow": ["TreeChopping", 0.0, 0.958, "loop"],
	"Sow": ["Farm_PlantSeed", 0.0, 2.75, "loop"],
	"Harvest": ["Farm_Harvest", 0.0, 2.5, "loop"],
	"Building": ["Fixing_Kneeling", 0.8, 4.0, "loop"],
	"Recovering": ["Fixing_Kneeling", 0.8, 4.0, "hold"],
	"Cooking": ["Fixing_Kneeling", 0.8, 4.0, "hold"],
	"Resting": ["LayToIdle", 0.42, 0.48, "hold"],
	"Sleeping": ["LayToIdle", 0.0, 0.05, "hold"],
	"Dead": ["Death01", 0.0, 2.375, "once"],
}
const MODEL := preload("res://assets/peasant/peasant.glb")
## Soles to crown, the imported model stands this tall; it is shrunk to the default peasant.
## build_peasant.py scales the body to fit the rig's joints, which were made for this taller figure.
const MODEL_HEIGHT := 1.833

var _metres_to_units: float
var _time := 0.0
var _pose := ""
var _body: Node3D
var _model: Node3D
var _skeleton: Skeleton3D
var _player: AnimationPlayer
## Turns and shifts the lying clip onto the bedroll's length, along +z from the feet.
var _lying: Transform3D
var _sack: Node3D
var _hoe: Node3D
var _sickle: Node3D
var _axe: Node3D
var _logs: Node3D
var _label: Label3D

var _linen := _material(Color("c4b393"))
var _leather := _material(Color("493427"))
var _wood := _material(Color("775336"))
var _iron := _material(Color("606665"))
var _burlap := _material(Color("a78c60"))
var _skin: Array[StandardMaterial3D] = []
var _hair: Array[StandardMaterial3D] = []

func _init(metres_to_units: float) -> void:
	_metres_to_units = metres_to_units
	name = "Farmer"
	scale = Vector3.ONE * metres_to_units
	_body = _pivot(self, "Body", Vector3.ZERO)
	_model = MODEL.instantiate()
	_body.add_child(_model)
	_skeleton = _model.find_children("*", "Skeleton3D")[0]
	_player = _model.find_children("*", "AnimationPlayer")[0]
	# Posed only by show_person, so a paused game holds still.
	_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for surface in _skeleton.get_node("Skin").mesh.get_surface_count():
		_skin.append(_recolour("Skin", surface))
	for part in ["HairCropped", "HairBowl", "HairLong", "Moustache", "Beard"]:
		_hair.append(_recolour(part, 0))
	_player.play("LayToIdle")
	_player.seek(0.0, true)
	var feet := (_bone("foot_l") + _bone("foot_r")) / 2
	var along := _bone("Head") - feet
	_lying = Transform3D(Basis(Vector3.UP, -atan2(along.x, along.z)).scaled(Vector3.ONE * Human.HEIGHT / MODEL_HEIGHT), Vector3.ZERO)
	# The toes reach about 0.17 m past the ankles; the bedroll's top is 0.1 m up.
	_lying.origin = Vector3(0, 0.12, 0.2) - _lying * Vector3(feet.x, 0, feet.z)
	# On the back, which faces the model's -z.
	_sack = _attach("spine_03", "CarriedSack", Transform3D(Basis(), Vector3(0, 1.05, -0.24)))
	var sack := _part(_sack, _sphere(0.17, 0.45), _burlap, Vector3.ZERO)
	sack.scale.z = 0.7
	_part(_sack, _cylinder(0.055, 0.075, 0.08), _leather, Vector3(0, 0.22, 0))
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
	dress({"skin": SKINS.keys()[0]})

## Colours the farmer's skin and hair and puts on the hair and clothes `peasant`
## chose, the first of each kind where it chose none.
func dress(peasant: Dictionary) -> void:
	# The texture is light skin; the choice tints it.
	for material in _skin:
		material.albedo_color = _ratio(SKINS[peasant.skin], SKINS.Fair)
	# The hair's texture is near white, tinted to the colour.
	for material in _hair:
		material.albedo_color = HAIR_COLOURS[peasant.get("hair_colour", HAIR_COLOURS.keys()[0])]
	# Choices can share a part (a beard has a moustache), so a part is on if any choice wears it.
	var worn := []
	var parts := []
	var kinds := HAIR.merged(CLOTHES)
	for kind in kinds:
		worn.append_array(WORN.get(peasant.get(kind, kinds[kind][0]), []))
		for option in kinds[kind]:
			parts.append_array(WORN.get(option, []))
	for part in parts:
		_skeleton.get_node(part).visible = part in worn
	# A plain shirt has linen where the embroidery would be.
	var plain: bool = peasant.get("shirt", CLOTHES.shirt[0]) == "Plain"
	for part in ["Shirt", "Skirt"]:
		var cloth: MeshInstance3D = _skeleton.get_node(part)
		cloth.set_surface_override_material(1, cloth.mesh.surface_get_material(0) if plain else null)

func show_person(person, seconds: float) -> void:
	seconds = maxf(seconds, 0.0)
	position = Vector3(person.position.x, 0, person.position.y) * _metres_to_units
	if person.facing.length_squared() > 0.0001:
		rotation.y = atan2(-person.facing.x, -person.facing.y)
	# The mesh is the default body; mass grows with height and the square of width.
	var tall: float = person.height / Human.HEIGHT
	var wide := sqrt(person.mass() / (Human.START_FAT + Human.START_LEAN) / tall)
	_label.text = person.name
	_label.position.y = person.height + 0.43
	_label.modulate = Color("bc8c81") if person.activity == "Dead" else Color("f3e4bc")
	_sack.visible = person.carried > 0 and person.carried_crop != "Wood" and person.activity not in ["Sleeping", "Dead"]
	_logs.visible = person.carried > 0 and person.carried_crop == "Wood" and person.activity not in ["Sleeping", "Dead"]
	var action: String = person.job.get("action", "") if person.activity == "Working" else ""
	_axe.visible = action == "Chop"
	_hoe.visible = action == "Plow"
	_sickle.visible = action == "Harvest"
	var pose: String = action if POSES.has(action) else person.activity if POSES.has(person.activity) else "Idle"
	if pose != _pose:
		_pose = pose
		_time = 0.0
	_time += seconds
	var clip: Array = POSES[pose]
	var span: float = clip[2] - clip[1]
	var at: float = clip[1] + (fposmod(_time, span) if clip[3] == "loop" else span * (0.5 - 0.5 * cos(_time * TAU / 4.0)) if clip[3] == "hold" else minf(_time, span))
	_player.play(clip[0])
	_player.seek(at, true)
	_body.rotation = Vector3.ZERO
	_body.scale = Vector3(wide, tall, wide)
	# The model faces +z; the farmer faces -z.
	_model.transform = Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * Human.HEIGHT / MODEL_HEIGHT), Vector3.ZERO)
	if pose == "Sleeping":
		# The fixed bedroll has one direction, whatever the walk home faced.
		_body.rotation.y = -rotation.y
		_body.scale = Vector3(wide, wide, tall)
		_model.transform = _lying

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
	var flame := _part(camp, _cylinder(0.0, 0.15, 0.18), ember, fire_at + Vector3(0, 0.15, 0))
	flame.name = "FireEmber"
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
	camp.add_child(preload("res://camp_shelter.gd").new())
	return camp

func _make_tools() -> void:
	# Gripped like an axe: in the model's rest pose the hand points sideways, thumb forward.
	var grip := Transform3D(Basis(Vector3.RIGHT, -PI / 2), _bone_rest("hand_r"))
	_hoe = _attach("hand_r", "Hoe", grip)
	_part(_hoe, _cylinder(0.017, 0.017, 1.0), _wood, Vector3(0, -0.4, 0))
	_part(_hoe, _box(Vector3(0.24, 0.035, 0.17)), _iron, Vector3(0, -0.89, -0.06))
	_sickle = _attach("hand_r", "Sickle", grip)
	_part(_sickle, _cylinder(0.023, 0.023, 0.22), _wood, Vector3(0, -0.1, 0))
	for index in 4:
		var angle := -0.9 + index * 0.55
		var blade := _part(_sickle, _box(Vector3(0.11, 0.025, 0.025)), _iron, Vector3(0.14 + sin(angle) * 0.14, -0.22 - cos(angle) * 0.14, 0))
		blade.rotation.z = angle
	_axe = _attach("hand_r", "Axe", grip)
	_part(_axe, _cylinder(0.024, 0.021, 0.8), _wood, Vector3(0, -0.3, 0))
	_part(_axe, _box(Vector3(0.28, 0.14, 0.045)), _iron, Vector3(0.08, -0.65, 0))
	_logs = _attach("spine_03", "CarriedWood", Transform3D(Basis(), Vector3(0, 0.9, -0.3)))
	for x in [-0.12, 0.0, 0.12]:
		var log_piece := _part(_logs, _cylinder(0.065, 0.075, 0.7), _wood, Vector3(x, 0, 0))
		log_piece.rotation.x = PI / 2
	_logs.visible = false
	_axe.visible = false
	_hoe.visible = false
	_sickle.visible = false

## A node that follows `bone`, placed at `rest` in the model's own space while
## the model stands in its rest pose.
func _attach(bone: String, title: String, rest: Transform3D) -> Node3D:
	var attachment := BoneAttachment3D.new()
	attachment.bone_name = bone
	_skeleton.add_child(attachment)
	var node := Node3D.new()
	node.name = title
	node.transform = (_to_model() * _skeleton.get_bone_global_rest(_skeleton.find_bone(bone))).affine_inverse() * rest
	attachment.add_child(node)
	return node

## The model-space position of `bone` in the current pose.
func _bone(bone: String) -> Vector3:
	return _to_model() * _skeleton.get_bone_global_pose(_skeleton.find_bone(bone)).origin

func _bone_rest(bone: String) -> Vector3:
	return _to_model() * _skeleton.get_bone_global_rest(_skeleton.find_bone(bone)).origin

## From skeleton space to the model's own, unshrunk space.
func _to_model() -> Transform3D:
	return _skeleton.get_parent().transform * _skeleton.transform

## A copy of surface `surface` of mesh `part`'s material, to tint for this farmer alone.
func _recolour(part: String, surface: int) -> StandardMaterial3D:
	var mesh: MeshInstance3D = _skeleton.get_node(part)
	var material: StandardMaterial3D = mesh.mesh.surface_get_material(surface).duplicate()
	mesh.set_surface_override_material(surface, material)
	return material

static func _ratio(colour: Color, base: Color) -> Color:
	return Color(colour.r / base.r, colour.g / base.g, colour.b / base.b)

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
