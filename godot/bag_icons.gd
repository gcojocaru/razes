extends Node
## Grain bags for the inventory, each look rendered once as a small 3D scene and
## kept as a texture: an open burlap sack (sack.gdshader) that slumps lower and
## wider as it empties, its rim rolled down around a heap of separate kernels and
## the crop's initial stamped on its belly, lit from the upper left. Textures are
## premultiplied, so draw them with a premultiplied-alpha blend.

const SIZE := 128
## Fill levels, and lean and fold variants, a bag is drawn at.
const LEVELS := 8
const VARIANTS := 3
## Body roundness (2 is an ellipse, more a squarer, stuffed sack), and how far up
## that shape, from -1 at the bottom to 1 at the top, the mouth is cut.
const ROUND := 2.5
const MOUTH := 0.75
## Kernel length and width in bag units (a full bag is one unit, about 70 cm,
## tall), several times real size so they read at icon scale.
const KERNELS := {"Barley": Vector2(0.05, 0.022), "Oats": Vector2(0.062, 0.016), "Millet": Vector2(0.026, 0.023), "Wheat": Vector2(0.046, 0.026), "Rye": Vector2(0.054, 0.018)}
const BURLAP := preload("res://sack.gdshader")
const STENCIL := preload("res://assets/fonts/CormorantUnicase-Bold.ttf")
const BLOB := "shader_type spatial; render_mode unshaded, depth_draw_never, shadows_disabled;
void fragment() { ALBEDO = vec3(0.0); ALPHA = 0.6 * (1.0 - smoothstep(0.25, 1.0, length(UV * 2.0 - 1.0))); }"

## "crop/level/variant" -> ImageTexture, filled in once its render is copied.
var _icons := {}

## The texture for a bag of `crop` filled to `share`, the `number`th shown. It is
## blank until its render lands, a frame later.
func icon(crop: String, share: float, number: int) -> Texture2D:
	var level := clampi(ceili(share * LEVELS), 1, LEVELS)
	var key := "%s/%d/%d" % [crop, level, number % VARIANTS]
	if not _icons.has(key):
		_icons[key] = ImageTexture.create_from_image(Image.create_empty(SIZE, SIZE, false, Image.FORMAT_RGBA8))
		_render(_icons[key], _scene(crop, float(level) / LEVELS, number % VARIANTS))
	return _icons[key]

## Renders `scene` once in its own world, copies it into `texture` and frees it.
func _render(texture: ImageTexture, scene: Node3D) -> void:
	var view := SubViewport.new()
	view.size = Vector2i(SIZE, SIZE)
	view.own_world_3d = true
	view.transparent_bg = true
	view.msaa_3d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ONCE
	view.add_child(scene)
	add_child(view)
	await RenderingServer.frame_post_draw
	var image := view.get_texture().get_image()
	view.queue_free()
	# Headless runs render nothing.
	if image and not image.is_empty():
		image.generate_mipmaps()
		texture.set_image(image)

func _scene(crop: String, fill: float, variant: int) -> Node3D:
	var scene := Node3D.new()
	var sack := Node3D.new()
	sack.rotation = Vector3(0, (variant - 1) * 0.25, (variant - 1) * 0.04)
	scene.add_child(sack)
	var cloth := ShaderMaterial.new()
	cloth.shader = BURLAP
	cloth.set_shader_parameter("seed", float(variant))
	var shape := _body(fill, variant)
	var body := MeshInstance3D.new()
	body.mesh = shape.mesh
	body.material_override = cloth
	sack.add_child(body)

	# The heap: a dark dome, for the gaps, under kernels scattered over it.
	var color: Color = Farm.CROPS[crop].color
	var mouth: float = shape.mouth
	var top: float = shape.top
	var rise := lerpf(0.06, 0.14, fill)
	var dome := MeshInstance3D.new()
	dome.mesh = SphereMesh.new()
	dome.scale = Vector3(mouth, rise, mouth) * 2.0
	dome.position.y = top - rise * 0.2
	var dark := StandardMaterial3D.new()
	dark.albedo_color = color.darkened(0.55)
	dark.roughness = 1.0
	dome.material_override = dark
	sack.add_child(dome)
	var kernel: Vector2 = KERNELS[crop]
	var grains := MultiMesh.new()
	grains.transform_format = MultiMesh.TRANSFORM_3D
	grains.use_colors = true
	var seedling := SphereMesh.new()
	seedling.radial_segments = 8
	seedling.rings = 4
	grains.mesh = seedling
	grains.instance_count = roundi(PI * mouth * mouth / (kernel.x * kernel.y) * 1.3)
	var random := RandomNumberGenerator.new()
	random.seed = variant * 7919 + crop.hash()
	for i in grains.instance_count:
		var reach := mouth * 0.95 * sqrt(random.randf())
		var turn := random.randf() * TAU
		var spot := Vector3(cos(turn) * reach, 0, sin(turn) * reach)
		spot.y = dome.position.y + rise * sqrt(maxf(1.0 - pow(reach / mouth, 2.0), 0.0))
		var up := Vector3(spot.x / (mouth * mouth), (spot.y - dome.position.y) / (rise * rise), spot.z / (mouth * mouth)).normalized()
		var length := up.cross(Vector3.FORWARD.rotated(Vector3.UP, random.randf() * TAU)).normalized()
		grains.set_instance_transform(i, Transform3D(Basis(length * kernel.x, up * kernel.y * 0.75, length.cross(up) * kernel.y), spot))
		grains.set_instance_color(i, color * random.randf_range(0.72, 1.08))
	var husk := StandardMaterial3D.new()
	husk.vertex_color_use_as_albedo = true
	husk.vertex_color_is_srgb = true
	husk.roughness = 0.55
	var heap := MultiMeshInstance3D.new()
	heap.multimesh = grains
	heap.material_override = husk
	sack.add_child(heap)

	# Ink stamped on the belly.
	var stamp := Label3D.new()
	stamp.text = crop[0]
	stamp.font = STENCIL
	stamp.font_size = 64
	# An outline in the same ink thickens the thin title face into a stamp.
	stamp.outline_size = 10
	stamp.pixel_size = lerpf(0.0022, 0.003, fill)
	stamp.shaded = true
	stamp.modulate = Color(0.12, 0.07, 0.03, 0.7)
	stamp.outline_modulate = stamp.modulate
	stamp.position = shape.belly + Vector3(0, 0, 0.03)
	sack.add_child(stamp)

	var floor_shadow := MeshInstance3D.new()
	floor_shadow.mesh = PlaneMesh.new()
	floor_shadow.scale = Vector3(1.5, 1, 1.1)
	floor_shadow.position.y = 0.002
	var blob := ShaderMaterial.new()
	blob.shader = Shader.new()
	blob.shader.code = BLOB
	floor_shadow.material_override = blob
	scene.add_child(floor_shadow)

	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(Basis(), Vector3(-1.3, 2.0, 1.6)).looking_at(Vector3.ZERO)
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 6.0
	scene.add_child(sun)
	var sky := DirectionalLight3D.new()
	sky.transform = Transform3D(Basis(), Vector3(1.5, 0.8, -0.5)).looking_at(Vector3.ZERO)
	sky.light_color = Color(0.8, 0.86, 1.0)
	sky.light_energy = 0.35
	scene.add_child(sky)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1.2
	var aim := Vector3(0, 0.5, 0)
	camera.transform = Transform3D(Basis(), aim + Vector3(0, sin(0.42), cos(0.42)) * 4.0).looking_at(aim)
	camera.environment = Environment.new()
	camera.environment.background_mode = Environment.BG_CLEAR_COLOR
	camera.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	camera.environment.ambient_light_color = Color(0.52, 0.48, 0.43)
	camera.environment.ambient_light_energy = 0.5
	scene.add_child(camera)
	return scene

## The sack's cloth as {"mesh", "top": the mouth's height, "mouth": its mean
## radius, "belly": a point on the front where a stamp goes}. The body is a
## lathed superellipse cut at the mouth, settling wider at the bottom, with lumps,
## pleats gathered at the mouth and, on an emptier bag, slump wrinkles; the rim is
## rolled down around the mouth. COLOR.r darkens creases and the base.
func _body(fill: float, variant: int) -> Dictionary:
	var height := lerpf(0.5, 0.95, fill)
	var radius := lerpf(0.48, 0.41, fill)
	var settle := 0.15 + 0.15 * (1.0 - fill)
	var lumps := FastNoiseLite.new()
	lumps.seed = variant
	lumps.frequency = 1.2
	var rings := 30
	var sides := 48
	# The angle at which the superellipse reaches the mouth's height.
	var cut := asin(pow(MOUTH, ROUND / 2.0))
	var cloth := SurfaceTool.new()
	cloth.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mouth := PackedVector3Array()
	var belly := Vector3.ZERO
	for i in rings + 1:
		var t := float(i) / rings
		var angle := lerpf(-PI / 2, cut, t)
		var up := signf(sin(angle)) * pow(absf(sin(angle)), 2.0 / ROUND)
		var out := pow(cos(angle), 2.0 / ROUND) * (1.0 - settle * up)
		var y := (up + 1.0) / (MOUTH + 1.0) * height
		var gather := smoothstep(0.6, 1.0, t)
		for j in sides + 1:
			# The seam, where u wraps, faces away at the back.
			var around := -PI / 2 + TAU * j / sides
			var pleat := (sin(around * 7.0 + variant * 2.0) + 0.5 * sin(around * 11.0 + 1.3)) / 1.5
			var r := radius * out * (1.0 + 0.07 * lumps.get_noise_3d(cos(around), y * 1.5, sin(around)) + 0.08 * gather * pleat + 0.04 * (1.0 - fill) * (1.0 - t) * sin(y * 30.0 + around * 3.0))
			# The mouth's edge waves up and down.
			var point := Vector3(cos(around) * r, y + 0.03 * gather * sin(around * 5.0 + variant * 1.7), sin(around) * r)
			var shade := (1.0 - 0.45 * gather * maxf(-pleat, 0.0)) * lerpf(0.6, 1.0, smoothstep(0.0, 0.12, y))
			cloth.set_color(Color(shade, shade, shade))
			cloth.set_uv(Vector2(float(j) / sides, y))
			cloth.add_vertex(point)
			if i == rings:
				mouth.append(point)
			if j == sides / 2 and belly == Vector3.ZERO and y > height * 0.4:
				belly = point
	_stitch(cloth, rings, sides)
	# The rim: a tube rolled outward and down around the mouth.
	var tube := 0.05
	var steps := 8
	for k in steps + 1:
		var roll := -PI / 2 + TAU * k / steps
		var shade := 0.65 + 0.35 * (sin(roll) * 0.5 + 0.5)
		for j in sides + 1:
			var outward := Vector3(mouth[j].x, 0, mouth[j].z).normalized()
			var centre := mouth[j] + outward * tube * 0.6 + Vector3.DOWN * tube * 0.3
			cloth.set_color(Color(shade, shade, shade))
			cloth.set_uv(Vector2(float(j) / sides, height + 0.3 * k / steps))
			cloth.add_vertex(centre + (outward * cos(roll) + Vector3.UP * sin(roll)) * tube)
	_stitch(cloth, steps, sides, (rings + 1) * (sides + 1))
	var mean := 0.0
	for point in mouth:
		mean += Vector2(point.x, point.z).length() / mouth.size()
	cloth.generate_normals()
	cloth.generate_tangents()
	return {"mesh": cloth.commit(), "top": height, "mouth": mean, "belly": belly}

## Joins a grid of `rows` + 1 rows of `columns` + 1 vertices, from `first` on,
## into quads facing outward.
func _stitch(cloth: SurfaceTool, rows: int, columns: int, first := 0) -> void:
	for i in rows:
		for j in columns:
			var a := first + i * (columns + 1) + j
			var b := a + columns + 1
			for index in [a, a + 1, b, a + 1, b + 1, b]:
				cloth.add_index(index)
