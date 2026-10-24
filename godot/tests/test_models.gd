extends SceneTree

const Models = preload("res://scripts/village_models.gd")
const IDS = ["house", "woodshed", "cellar", "barn", "well", "granary", "workshop", "bakery", "smithy", "stable", "apiary", "storehouse"]
var passed := 0
var failures: Array[String] = []

func _initialize() -> void:
	var silhouettes: Dictionary = {}
	for id in IDS:
		var previous := ""
		for level in range(1, 6):
			var complete := Models.building(id, level)
			var signature := _signature(complete)
			_check(signature != previous, "%s level %d changes geometry" % [id, level])
			previous = signature
			if level == 1:
				_check(not silhouettes.has(signature), "%s has a distinct composition" % id)
				silhouettes[signature] = id
			var full_height := _bounds(complete).end.y
			_check(_meshes(complete).size() >= 5, "%s is built from real parts" % id)
			_check(_textured_count(complete) >= 4, "%s uses textured materials" % id)
			for mesh in _meshes(complete):
				if mesh.name == "DarkGlass":
					var frame := mesh.get_parent() as Node3D
					_check((frame.basis * mesh.position).dot(Vector3(frame.position.x, 0, frame.position.z)) > 0, "%s glazing faces outside its wall" % id)
			complete.free()
			for winter in [false, true]:
				for progress in [0.0, 0.45, 0.8, 0.99, 1.0]:
					var model := Models.building(id, level, 100.0, winter, progress)
					_check_bounds(model, 6.0 if id == "house" else 4.0, 6.0 if id == "house" else 4.0, "%s/%d/%s/%.2f" % [id, level, winter, progress])
					var height := _bounds(model).end.y
					if progress == 0.0:
						_check(height <= 0.5, "%s begins with a foundation" % id)
					elif progress < 1.0:
						_check(height > 0.5 and height < full_height, "%s has unfinished construction geometry" % id)
					model.free()
				var worn := Models.building(id, level, 0.0, winter)
				_check_bounds(worn, 6.0 if id == "house" else 4.0, 6.0 if id == "house" else 4.0, "damaged %s/%d/%s" % [id, level, winter])
				worn.free()
		var foundation := Models.building(id, 0)
		_check(_bounds(foundation).end.y <= 0.5, "%s level zero is a foundation" % id)
		foundation.free()
		var healthy := Models.building(id)
		var damaged := Models.building(id, 1, 20)
		var snowy := Models.building(id, 1, 100, true)
		_check(_signature(healthy) != _signature(damaged), "%s damage changes visible geometry" % id)
		_check(_signature(healthy) != _signature(snowy), "%s winter adds snow geometry" % id)
		healthy.free()
		damaged.free()
		snowy.free()
	for entry in [["barn", 4.0, 4.0], ["well", 2.0, 2.0], ["stores", 2.0, 2.0], ["fence", 4.0, 2.0]]:
		for winter in [false, true]:
			var prop := Models.scenery(entry[0], winter)
			_check_bounds(prop, entry[1], entry[2], "scenery %s" % entry[0])
			prop.free()
	var resting := Models.figure()
	var working := Models.figure("woodcutting")
	_check_bounds(resting, 1.5, 1.5, "Ion")
	_check(_bounds(resting).end.y >= 1.6 and _bounds(resting).end.y <= 1.85, "Ion is human scale")
	_check(_signature(resting) != _signature(working), "Ion carries a task prop")
	resting.free()
	working.free()
	var a := Models.building("house")
	var b := Models.building("house")
	if not _meshes(a).is_empty() and not _meshes(b).is_empty():
		_check(_meshes(a)[0].mesh == _meshes(b)[0].mesh, "mesh resources are shared")
		_check(_meshes(a)[0].material_override == _meshes(b)[0].material_override, "material resources are shared")
	a.free()
	b.free()
	for failure in failures:
		printerr("FAIL: " + failure)
	print("Models: %d passed, %d failed" % [passed, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failures.append(label)

func _meshes(node: Node) -> Array[MeshInstance3D]:
	var found: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		found.append(node)
	for child in node.get_children():
		found.append_array(_meshes(child))
	return found

func _bounds(model: Node3D, rotation_angle: float = 0) -> AABB:
	var result := AABB()
	var first := true
	var turn := Transform3D(Basis(Vector3.UP, rotation_angle), Vector3.ZERO)
	for mesh in _meshes(model):
		var transform := mesh.transform
		var parent := mesh.get_parent()
		while parent != model and parent is Node3D:
			transform = parent.transform * transform
			parent = parent.get_parent()
		var box: AABB = turn * transform * mesh.get_aabb()
		result = box if first else result.merge(box)
		first = false
	return result

func _check_bounds(model: Node3D, width: float, depth: float, label: String, rotate: bool = true) -> void:
	_check(not _meshes(model).is_empty(), label + " has meshes")
	for facing in range(4 if rotate else 1):
		var box := _bounds(model, facing * PI / 2)
		var w := width if facing % 2 == 0 else depth
		var d := depth if facing % 2 == 0 else width
		_check(absf(box.position.y) < 0.015, label + " rests on ground")
		_check(box.position.x >= -w / 2 - 0.01 and box.end.x <= w / 2 + 0.01, label + " fits width")
		_check(box.position.z >= -d / 2 - 0.01 and box.end.z <= d / 2 + 0.01, label + " fits depth")

func _signature(model: Node3D) -> String:
	var parts: PackedStringArray = []
	for mesh in _meshes(model):
		parts.append("%s:%s:%s" % [mesh.mesh.get_class(), mesh.mesh.get_aabb(), mesh.transform])
	return "|".join(parts)

func _textured_count(model: Node3D) -> int:
	var count := 0
	for mesh in _meshes(model):
		var mat := mesh.material_override as StandardMaterial3D
		if mat != null and mat.albedo_texture != null and mat.roughness >= 0.8:
			count += 1
	return count
