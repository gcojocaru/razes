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
func joint_bounds(node: Node3D) -> AABB:
	var skeleton: Skeleton3D = node.find_children("*", "Skeleton3D", true, false)[0]
	var result := AABB(skeleton.global_transform * skeleton.get_bone_global_pose(0).origin, Vector3.ZERO)
	for bone in skeleton.get_bone_count():
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
	actor.show_person(person, 0.0)
	var tall := mesh_bounds(body)
	check(absf(tall.size.y - 1.85) < 0.005 and absf(tall.position.y) < 0.02 and actor.get_node("Name").position.y > 1.85, "A taller peasant stands at their own height, boots on the ground, under their name")
	person.height = 1.718
	person.weight = 88.0
	actor.show_person(person, 0.0)
	check(mesh_bounds(body).size.x > standing.size.x * 1.1 and is_equal_approx(mesh_bounds(body).size.y, standing.size.y), "A heavier body is wider, not taller")
	person.weight = 65.0
	actor.dress({"skin": "Olive", "hair": "Red", "beard": "Beard", "clothes": "Madder red"})
	person.name = "Toader"
	actor.show_person(person, 0.0)
	var bearded := mesh_bounds(body)
	check(actor._hands.albedo_color == actor.SKINS.Olive and actor._hair[0].albedo_color.r > actor._hair[0].albedo_color.b * 2 and actor._clothes[0].albedo_color.r > actor._clothes[0].albedo_color.g * 1.5 and actor._beard.visible and actor._moustache.visible and actor.get_node("Name").text == "Toader", "Dressing colours skin, hair and clothes, grows the beard, and the label names the peasant")
	check(bearded.size.y <= standing.size.y + 0.001 and bearded.size.z <= standing.size.z + 0.001, "The beard stays within the figure's height and depth")
	actor.dress({"skin": "Tanned", "hair": "Dark brown", "beard": "Moustache", "clothes": "Undyed linen"})
	check(actor._moustache.visible and not actor._beard.visible, "A moustache alone shows no beard")
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
