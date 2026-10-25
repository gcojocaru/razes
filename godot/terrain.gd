extends RefCounted
## One seeded surface for the landscape, farming, walking and picking.

const HALF_EXTENT := 128.0
const WATER_LEVEL := -0.3
const CAMP := Vector2(-17, 0)
const NAV_BOUNDS := Rect2i(-18, -18, 37, 37)
const SAMPLE_WIDTH := 257
const WALK_CLEARANCE := 0.3
## Lands offered before a game: how many metres the field's hills rise and how
## many ponds lie in it.
const PRESETS := {
	"Steppe": {"hills": 7.0, "ponds": 1},
	"Hills": {"hills": 18.0, "ponds": 2},
	"Lakeland": {"hills": 11.0, "ponds": 4},
}
## The highest custom hills: with four ponds, 200 seeds still left every dry plot
## reachable from camp and at least 78 of them farmable.
const MAX_HILLS := 24.0

## The land chosen on the creation screen. Each new game's terrain is made from
## it, so Restart keeps it with a fresh seed.
static var land: Dictionary = PRESETS.Hills

var seed: int
## How many metres the field's hills rise.
var hills: float
var ponds: Array[Dictionary] = []
var _noise := FastNoiseLite.new()
var _heights := PackedFloat32Array()
var _navigation := AStar2D.new()
var _reachable := {}
var _reasons := {}

func _init(terrain_seed: int, chosen: Dictionary = PRESETS.Hills) -> void:
	seed = terrain_seed
	hills = chosen.hills
	_noise.seed = seed
	_noise.frequency = 0.055
	_noise.fractal_octaves = 2
	var random := RandomNumberGenerator.new()
	random.seed = seed
	var rotation := random.randi_range(0, 3) * PI / 2.0
	var locations := [Vector2(-7, -7), Vector2(7, 7), Vector2(7, -7), Vector2(-7, 7)]
	for index in chosen.ponds:
		ponds.append({"center": (locations[index] + Vector2(random.randf_range(-1.5, 1.5), random.randf_range(-1.5, 1.5))).rotated(rotation), "radii": Vector2(random.randf_range(2.5, 3.5), random.randf_range(2.5, 3.5))})
	_heights.resize(SAMPLE_WIDTH * SAMPLE_WIDTH)
	# The camp's compact clearing is level at its own ground height, so no bank walls it in.
	var camp_level := _generated_height(CAMP)
	for z in SAMPLE_WIDTH:
		for x in SAMPLE_WIDTH:
			var point := Vector2(x - 128, z - 128)
			_heights[z * SAMPLE_WIDTH + x] = lerpf(camp_level, _generated_height(point), smoothstep(1.5, 4.0, point.distance_to(CAMP)))
	for x in range(-18, 19):
		for z in range(-18, 19):
			if _walkable(Vector2(x, z)):
				_navigation.add_point(_navigation_id(Vector2i(x, z)), Vector2(x, z))
	for x in range(-18, 19):
		for z in range(-18, 19):
			var current := Vector2i(x, z)
			if not _navigation.has_point(_navigation_id(current)):
				continue
			for offset in [Vector2i.RIGHT, Vector2i.DOWN]:
				var next: Vector2i = current + offset
				if NAV_BOUNDS.has_point(next) and _navigation.has_point(_navigation_id(next)) and _segment_clear(Vector2(current), Vector2(next)):
					_navigation.connect_points(_navigation_id(current), _navigation_id(next))
	var pending: Array[Vector2i] = [Vector2i(CAMP)]
	_reachable[pending[0]] = true
	while not pending.is_empty():
		var current: Vector2i = pending.pop_back()
		for connection in _navigation.get_point_connections(_navigation_id(current)):
			var next := Vector2i(_navigation.get_point_position(connection))
			if not _reachable.has(next):
				_reachable[next] = true
				pending.append(next)
	for x in 16:
		for z in 16:
			var cell := Vector2i(x, z)
			_reasons[cell] = _cell_reason(cell)

func _generated_height(point: Vector2) -> float:
	# A full 3.6-unit rise is 18 m.
	var noise := clampf((_noise.get_noise_2dv(point) + 1.0) / 2.0, 0.0, 1.0) * hills / 18.0
	var height := lerpf(0.2 + noise * 3.6, 1.0 + noise * 7.0, smoothstep(16.0, 45.0, maxf(absf(point.x), absf(point.y))))
	for pond in ponds:
		var shoreline := 1.0 + _noise.get_noise_2dv(point + Vector2(137, -83)) * 0.12
		var distance: float = ((point - pond.center) / pond.radii).length() / shoreline
		var basin := WATER_LEVEL + (distance * distance - 1.0) * 0.9
		var join := maxf(0.4 - absf(height - basin), 0.0) / 0.4
		height = minf(height, basin) - join * join * 0.1
	return height

func _sample(x: int, z: int) -> float:
	return _heights[clampi(z + 128, 0, 256) * SAMPLE_WIDTH + clampi(x + 128, 0, 256)]

func _navigation_id(point: Vector2i) -> int:
	return (point.y + 18) * 37 + point.x + 18

## PlaneMesh splits each one-unit square along its descending diagonal.
func height_at(point: Vector2) -> float:
	var x := clampi(floori(point.x), -128, 127)
	var z := clampi(floori(point.y), -128, 127)
	var fraction := (point - Vector2(x, z)).clamp(Vector2.ZERO, Vector2.ONE)
	if fraction.x + fraction.y <= 1.0:
		return _sample(x, z) + (_sample(x + 1, z) - _sample(x, z)) * fraction.x + (_sample(x, z + 1) - _sample(x, z)) * fraction.y
	return _sample(x + 1, z + 1) + (_sample(x, z + 1) - _sample(x + 1, z + 1)) * (1.0 - fraction.x) + (_sample(x + 1, z) - _sample(x + 1, z + 1)) * (1.0 - fraction.y)

func cell_reason(cell: Vector2i) -> String:
	return _reasons.get(cell, "Unreachable")

func _cell_reason(cell: Vector2i) -> String:
	var corner := Vector2(cell) * 2.0 - Vector2.ONE * 16.0
	var steep := false
	for x in 3:
		for z in 3:
			var point := corner + Vector2(x, z)
			var height := height_at(point)
			if height <= WATER_LEVEL + 0.15:
				return "Water"
			if x < 2:
				steep = steep or absf(height_at(point + Vector2.RIGHT) - height) > 0.55
			if z < 2:
				steep = steep or absf(height_at(point + Vector2.DOWN) - height) > 0.55
	if steep:
		return "Too steep"
	return "" if _reachable.has(Vector2i(corner + Vector2.ONE)) else "Unreachable"

func _walkable(point: Vector2) -> bool:
	for offset in [Vector2.ZERO, Vector2(WALK_CLEARANCE, 0), Vector2(-WALK_CLEARANCE, 0), Vector2(0, WALK_CLEARANCE), Vector2(0, -WALK_CLEARANCE)]:
		if height_at(point + offset) <= WATER_LEVEL + 0.07:
			return false
	return absf(height_at(point + Vector2.RIGHT * 0.5) - height_at(point - Vector2.RIGHT * 0.5)) <= 1.0 and absf(height_at(point + Vector2.DOWN * 0.5) - height_at(point - Vector2.DOWN * 0.5)) <= 1.0

func _segment_clear(from: Vector2, to: Vector2) -> bool:
	var crossings := {0.0: true, 1.0: true}
	var starts := [from.x, from.y, from.x + from.y]
	var ends := [to.x, to.y, to.x + to.y]
	# Every clearance and slope sample is linear between these triangle edges.
	for axis in 3:
		var delta: float = ends[axis] - starts[axis]
		if delta == 0.0:
			continue
		for offset in [-0.5, -WALK_CLEARANCE, 0.0, WALK_CLEARANCE, 0.5]:
			var start: float = starts[axis] + offset
			var end: float = ends[axis] + offset
			for boundary in range(ceili(minf(start, end)), floori(maxf(start, end)) + 1):
				var crossing := (boundary - start) / delta
				if crossing > 0.0 and crossing < 1.0:
					crossings[crossing] = true
	for crossing in crossings:
		if not _walkable(from.lerp(to, crossing)):
			return false
	return true

func _path_id(point: Vector2) -> Vector2i:
	var nearest := Vector2i(1000, 1000)
	var distance := INF
	var rounded := Vector2i(point.round())
	for x in range(-1, 2):
		for z in range(-1, 2):
			var id := rounded + Vector2i(x, z)
			var away := point.distance_squared_to(Vector2(id))
			if away < distance and _reachable.has(id) and _segment_clear(point, Vector2(id)):
				nearest = id
				distance = away
	return nearest

## Paths are world units; the human model converts them to metres.
func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if maxf(absf(from.x), absf(from.y)) > 18.0 or maxf(absf(to.x), absf(to.y)) > 18.0:
		return PackedVector2Array()
	if not _walkable(from) or not _walkable(to):
		return PackedVector2Array()
	if from == to:
		return PackedVector2Array([from])
	if _segment_clear(from, to):
		return PackedVector2Array([from, to])
	var start := _path_id(from)
	var end := _path_id(to)
	if not _reachable.has(start) or not _reachable.has(end):
		return PackedVector2Array()
	var route := PackedVector2Array([from])
	for point in _navigation.get_point_path(_navigation_id(start), _navigation_id(end)):
		if not route[-1].is_equal_approx(point):
			route.append(point)
	if not route[-1].is_equal_approx(to):
		route.append(to)
	else:
		route[-1] = to
	return route

## Traverse crossed lattice squares; intersect their actual rendered triangles.
func ray_hit(origin: Vector3, direction: Vector3) -> Variant:
	if direction.is_zero_approx():
		return null
	var water = Plane(Vector3.UP, WATER_LEVEL).intersects_ray(origin, direction)
	if water != null and (absf(water.x) > HALF_EXTENT or absf(water.z) > HALF_EXTENT or height_at(Vector2(water.x, water.z)) > WATER_LEVEL):
		water = null
	var near := 0.0
	var far := INF
	for axis in 3:
		var low := -4.0 if axis == 1 else -HALF_EXTENT
		var high := 10.0 if axis == 1 else HALF_EXTENT
		if is_zero_approx(direction[axis]):
			if origin[axis] < low or origin[axis] > high:
				return water
		else:
			var first: float = (low - origin[axis]) / direction[axis]
			var last: float = (high - origin[axis]) / direction[axis]
			near = maxf(near, minf(first, last))
			far = minf(far, maxf(first, last))
	if far < near:
		return water
	var entry := origin + direction * (near + 0.00001)
	var cell := Vector2i(clampi(floori(entry.x), -128, 127), clampi(floori(entry.z), -128, 127))
	for _step in 1024:
		var a := Vector3(cell.x, _sample(cell.x, cell.y), cell.y)
		var b := Vector3(cell.x + 1, _sample(cell.x + 1, cell.y), cell.y)
		var c := Vector3(cell.x, _sample(cell.x, cell.y + 1), cell.y + 1)
		var d := Vector3(cell.x + 1, _sample(cell.x + 1, cell.y + 1), cell.y + 1)
		var hit = null
		for upper in 2:
			var plane := Plane(a, c, b) if upper == 0 else Plane(b, c, d)
			var candidate = plane.intersects_ray(origin, direction)
			if candidate == null:
				continue
			var fraction := Vector2(candidate.x - cell.x, candidate.z - cell.y)
			# Inclusive edges avoid float precision holes where adjacent triangles meet.
			if fraction.x < -0.0001 or fraction.x > 1.0001 or fraction.y < -0.0001 or fraction.y > 1.0001:
				continue
			if (upper == 0 and fraction.x + fraction.y > 1.0001) or (upper == 1 and fraction.x + fraction.y < 0.9999):
				continue
			if hit == null or origin.distance_squared_to(candidate) < origin.distance_squared_to(hit):
				hit = candidate
		if hit != null:
			return water if water != null and origin.distance_squared_to(water) < origin.distance_squared_to(hit) else hit
		var next_x := INF if is_zero_approx(direction.x) else (cell.x + (1 if direction.x > 0 else 0) - origin.x) / direction.x
		var next_z := INF if is_zero_approx(direction.z) else (cell.y + (1 if direction.z > 0 else 0) - origin.z) / direction.z
		if minf(next_x, next_z) > far:
			break
		if next_x <= next_z:
			cell.x += 1 if direction.x > 0 else -1
		if next_z <= next_x:
			cell.y += 1 if direction.z > 0 else -1
		if cell.x < -128 or cell.x >= 128 or cell.y < -128 or cell.y >= 128:
			break
	return water

func create_mesh() -> ArrayMesh:
	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * HALF_EXTENT * 2.0
	plane.subdivide_width = 255
	plane.subdivide_depth = 255
	var arrays := plane.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
	for index in vertices.size():
		var vertex := vertices[index]
		var point := Vector2(vertex.x, vertex.z)
		vertex.y = height_at(point)
		vertices[index] = vertex
		var dx := (height_at(point + Vector2(0.25, 0)) - height_at(point - Vector2(0.25, 0))) / 0.5
		var dz := (height_at(point + Vector2(0, 0.25)) - height_at(point - Vector2(0, 0.25))) / 0.5
		normals[index] = Vector3(-dx, 1, -dz).normalized()
		var tangent := Vector3(1, dx, 0).normalized()
		tangents[index * 4] = tangent.x
		tangents[index * 4 + 1] = tangent.y
		tangents[index * 4 + 2] = tangent.z
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
