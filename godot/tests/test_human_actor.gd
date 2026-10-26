extends SceneTree
## Geometry and animation contracts, using presentation input without simulation.

class Person extends RefCounted:
	var name := "Ion"
	var height := 1.718
	var weight := 65.0
	var position := Vector2.ZERO
	var facing := Vector2(0, -1)
	var home := Vector2.ZERO
	var activity := "Idle"
	var job := {}
	var carried := 0
	func mass() -> float:
		return weight

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func mesh_bounds(node: Node3D) -> AABB:
	var result := AABB()
	var found := false
	for child in node.find_children("*", "MeshInstance3D", true, false):
		if not child.is_visible_in_tree():
			continue
		var bounds: AABB = child.global_transform * child.get_aabb()
		result = result.merge(bounds) if found else bounds
		found = true
	return result

## Where the posed skeleton's joints are; skinned meshes keep their rest-pose bounds.
## The skirt's bones hang from the cloth around the hips, outside the body, so they are left out.
func joint_bounds(node: Node3D) -> AABB:
	var skeleton: Skeleton3D = node.find_children("*", "Skeleton3D", true, false)[0]
	var result := AABB(skeleton.global_transform * skeleton.get_bone_global_pose(0).origin, Vector3.ZERO)
	for bone in skeleton.get_bone_count():
		if not skeleton.get_bone_name(bone).begins_with("skirt_"):
			result = result.expand(skeleton.global_transform * skeleton.get_bone_global_pose(bone).origin)
	return result

func pose(node: Node3D) -> Array:
	var skeleton: Skeleton3D = node.find_children("*", "Skeleton3D", true, false)[0]
	var result := [node.transform]
	for bone in skeleton.get_bone_count():
		result.append(skeleton.get_bone_pose(bone))
	for child in node.find_children("*", "Node3D", true, false):
		if not child is BoneAttachment3D:
			result.append([child.transform, child.visible])
	return result

func run() -> void:
	check(ResourceLoader.exists("res://human_actor.gd"), "A procedural farmer renderer exists")
	if not failures.is_empty():
		quit(1)
		return
	var script = load("res://human_actor.gd")
	var person := Person.new()
	var actor = script.new(1.0)
	root.add_child(actor)
	actor.show_person(person, 0.0)
	var body: Node3D = actor.get_node("Body")
	check(["Shirt", "Skirt", "Belt", "Trousers", "Laces", "Opinci"].all(func(part: String) -> bool: return actor._skeleton.has_node(part)), "The farmer wears a shirt, belt, trousers and opinci")
	var shirt: MeshInstance3D = actor._skeleton.get_node("Shirt")
	check(shirt.mesh.get_surface_count() == 2 and shirt.mesh.surface_get_material(0).normal_enabled, "The shirt is woven linen with embroidery")
	var worn := func() -> Array:
		return ["HairCropped", "HairBowl", "HairLong", "Beard", "Moustache", "Belt", "Chimir", "Cusma", "Palarie", "Opinci", "Laces"].filter(func(part: String) -> bool: return actor._skeleton.get_node(part).visible)
	check(worn.call() == ["HairCropped", "Moustache", "Belt", "Opinci", "Laces"] and shirt.get_surface_override_material(1) == null, "The farmer starts with cropped hair and a moustache, in an embroidered shirt, the brâu and opinci, bareheaded")
	actor.dress({"skin": "Tanned", "hair": "Long", "beard": "Beard", "hair_colour": "Grey", "shirt": "Plain", "belt": "Chimir", "hat": "Pălărie", "footwear": "Barefoot"})
	check(worn.call() == ["HairLong", "Beard", "Moustache", "Chimir", "Palarie"] and shirt.get_surface_override_material(1) == shirt.mesh.surface_get_material(0), "Dressing changes hair, beard and clothes: long hair, a full beard with its moustache, a plain shirt, the chimir, the pălărie, bare feet")
	check(actor._hair.all(func(material: StandardMaterial3D) -> bool: return material.albedo_color == actor.HAIR_COLOURS.Grey), "The hair and beard take the chosen colour")
	actor.dress({"skin": "Tanned", "hair": "Bald", "beard": "Shaven", "hat": "Cușmă"})
	check(worn.call() == ["Belt", "Cusma", "Opinci", "Laces"], "A bald, shaven farmer wears no hair; looks not chosen are the first of their kind")
	# The first looks again, for the heights below.
	actor.dress({"skin": "Tanned"})
	var standing := mesh_bounds(body)
	check(standing.size.y >= 1.65 and standing.size.y <= 1.8, "The adult's standing mesh is about 1.7 metres tall")
	check(absf(standing.position.y) < 0.02, "Standing boots meet the ground rather than hovering or sinking")
	var joints := joint_bounds(body)
	check(joints.size.x < 0.9 and joints.size.z < 0.6, "The adult has human proportions in metres")

	var small = script.new(0.2)
	root.add_child(small)
	small.show_person(person, 0.0)
	var scaled := mesh_bounds(small.get_node("Body"))
	check(scaled.size.is_equal_approx(standing.size * 0.2), "A 10-metre plot scales the whole human to one fifth of metre geometry")
	person.position = Vector2(25, -10)
	person.facing = Vector2(1, 0)
	small.show_person(person, 0.0)
	check(small.position.is_equal_approx(Vector3(5, 0, -2)), "The root converts simulation metres to scene units exactly once")
	check((-small.basis.z).normalized().dot(Vector3.RIGHT) > 0.999, "The face follows the simulation's travel direction")
	person.position = Vector2.ZERO
	person.facing = Vector2(0, -1)
	var idle := pose(body)
	person.activity = "Walking"
	actor.show_person(person, 0.12)
	var walk := pose(body)
	check(walk != idle, "Walking visibly moves the rig")
	actor.show_person(person, 0.12)
	check(pose(body) != walk, "Walking continues through changing limb poses")
	var paused := pose(body)
	for frame in 10:
		actor.show_person(person, 0.0)
	check(pose(body) == paused, "Paused redraws do not advance the animation")
	for frame in 24:
		actor.show_person(person, 0.05)
		check(joint_bounds(body).position.y >= -0.02, "Walking keeps the boots above the ground")

	person.activity = "Working"
	var work_poses := []
	for action in ["Plow", "Sow", "Harvest"]:
		person.job = {"action": action, "cell": Vector2i.ZERO, "crop": "Barley", "remaining": 1.0}
		actor.show_person(person, 0.15)
		var before := pose(body)
		actor.show_person(person, 0.15)
		check(pose(body) != before, action + " animates the working farmer")
		work_poses.append(pose(body))
		check(joint_bounds(body).position.y >= -0.02, action + " stays grounded")
	check(work_poses[0] != work_poses[1] and work_poses[1] != work_poses[2], "Hoeing, sowing and harvesting use distinct poses or tools")
	person.activity = "Idle"
	person.carried = 0
	actor.show_person(person, 0.0)
	var empty := pose(body)
	person.carried = 7000
	actor.show_person(person, 0.0)
	check(pose(body) != empty, "Grain in transit shows a carried sack")
	person.carried = 0
	person.height = 1.85
	# Bald, as height is measured: hair stands a little above the scalp.
	actor.dress({"skin": "Tanned", "hair": "Bald"})
	actor.show_person(person, 0.0)
	var tall := mesh_bounds(body)
	check(absf(tall.size.y - 1.85) < 0.005 and absf(tall.position.y) < 0.02 and actor.get_node("Name").position.y > 1.85, "A taller peasant stands at their own height, boots on the ground, under their name")
	actor.dress({"skin": "Tanned"})
	person.height = 1.718
	person.weight = 88.0
	actor.show_person(person, 0.0)
	check(mesh_bounds(body).size.x > standing.size.x * 1.1 and is_equal_approx(mesh_bounds(body).size.y, standing.size.y), "A heavier body is wider, not taller")
	person.weight = 65.0
	actor.dress({"skin": "Olive"})
	person.name = "Toader"
	actor.show_person(person, 0.0)
	check(actor._skin[0].albedo_color == actor._ratio(actor.SKINS.Olive, actor.SKINS.Fair) and actor.get_node("Name").text == "Toader", "Dressing colours the skin, and the label names the peasant")
	actor.dress({"skin": "Tanned"})
	for activity in ["Sleeping", "Resting", "Dead"]:
		person.activity = activity
		# Falling down takes the death clip's length.
		actor.show_person(person, 3.0 if activity == "Dead" else 0.0)
		var resting := joint_bounds(body)
		check(resting.position.y >= -0.02, activity + " keeps the body above ground")
		check(resting.size.y < (1.3 if activity == "Resting" else 0.6), activity + " visibly lowers the body")
		if activity != "Dead":
			var still := pose(body)
			actor.show_person(person, 0.2)
			check(pose(body) != still, activity + " retains a subtle living pose")
			var resting_pause := pose(body)
			actor.show_person(person, 0.0)
			check(pose(body) == resting_pause, activity + " animation pauses with the simulation")
	person.activity = "Dead"
	actor.show_person(person, 0.0)
	var dead := pose(body)
	actor.show_person(person, 3.0)
	check(pose(body) == dead, "The dead farmer stays motionless")
	person.activity = "Cooking"
	actor.show_person(person, 0.12)
	var cooking := pose(body)
	actor.show_person(person, 0.12)
	check(pose(body) != cooking, "Cooking uses the rig rather than an idle pose")
	# Each column of the skirt hangs from two bones, the upper one at the belt.
	var skeleton: Skeleton3D = body.find_children("*", "Skeleton3D", true, false)[0]
	person.job = {"action": "Harvest", "cell": Vector2i.ZERO, "crop": "Barley", "remaining": 1.0}
	for activity in ["Walking", "Cooking", "Working"]:
		person.activity = activity
		var drop := INF
		for step in 40:
			actor.show_person(person, 0.1)
			for column in 16:
				var top := skeleton.get_bone_global_pose(skeleton.find_bone("skirt_%02d_a" % column)).origin
				drop = minf(drop, top.y - skeleton.get_bone_global_pose(skeleton.find_bone("skirt_%02d_b" % column)).origin.y)
		check(drop > 0.02, activity + " lets the skirt hang from the belt rather than stand out")
	person.job = {}

	var camp: Node3D = small.create_camp()
	root.add_child(camp)
	check(camp.get_parent() != small and camp.position == Vector3.ZERO, "The camp is a separate node for placement at home")
	var camp_bounds := mesh_bounds(camp)
	check(camp_bounds.size.x >= 0.6 and camp_bounds.size.x <= 1.2 and camp_bounds.size.y < 0.3, "The metre-scaled camp fits outside one 10-metre plot")
	check(camp_bounds.position.y >= -0.005, "Camp objects sit above the ground")
	person.activity = "Sleeping"
	var bedroll: MeshInstance3D = camp.get_node_or_null("Bedroll")
	check(bedroll != null, "The farmer's camp has a bedroll")
	if bedroll != null:
		var bedding: AABB = bedroll.global_transform * bedroll.get_aabb()
		for build in [[1.55, 65.0], [1.718, 65.0], [1.85, 65.0], [1.85, 102.0]]:
			person.height = build[0]
			person.weight = build[1]
			for facing in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
				person.facing = facing
				small.show_person(person, 0.0)
				var sleeper := joint_bounds(small.get_node("Body"))
				check(Rect2(bedding.position.x, bedding.position.z, bedding.size.x, bedding.size.z).encloses(Rect2(sleeper.position.x, sleeper.position.z, sleeper.size.x, sleeper.size.z)), "A %.2f m, %d kg farmer sleeping at home lies on the bedroll regardless of approach direction" % build)
	camp.free()
	small.free()
	actor.free()
	if failures.is_empty():
		print("PASS: 1.7 m model farmer bounds, height, build and looks from the peasant, one-fifth scale, grounding, direction, walking/work/cooking/rest/death poses, pause, carried sack and separate camp")
		print("Standing bounds in metres: ", standing, "; scaled size: ", scaled.size, "; camp size: ", camp_bounds.size)
	quit(0 if failures.is_empty() else 1)
