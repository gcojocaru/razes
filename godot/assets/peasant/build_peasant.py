# Builds peasant.glb from a generated figure (one mesh, nude, bald, barefoot, with a Mixamo-named skeleton): the body
# is scaled to fit the peasant rig's joints, skinned with Blender's automatic weights, its grey clay texture is
# tinted to skin, and it is dressed in clothes built around it. See SOURCE.md.
# blender -b -P build_peasant.py -- <figure GLB>
# The rig and the eight animation clips are read from this folder's peasant.glb, which is then rewritten,
# so keep a copy of that file before running it.
import bpy, bmesh, math, sys
import numpy as np
from mathutils import Matrix, Vector, kdtree
from mathutils.bvhtree import BVHTree

import os
here = os.path.dirname(os.path.abspath(__file__))
figure_path = sys.argv[sys.argv.index("--") + 1]
rig_path = os.path.join(here, "peasant.glb")
out = rig_path
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=rig_path)
rig = next(o for o in bpy.data.objects if o.type == "ARMATURE")
for o in list(bpy.data.objects):
	if o.type == "MESH":
		bpy.data.objects.remove(o, do_unlink=True)
# The old model's textures and materials go too, so the figure's own are found and keep their names.
for blocks in (bpy.data.materials, bpy.data.images):
	for block in list(blocks):
		blocks.remove(block)
# So do the skirt's bones and their keys, which are made afresh below.
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
for bone in [b for b in rig.data.edit_bones if b.name.startswith("skirt_")]:
	rig.data.edit_bones.remove(bone)
bpy.ops.object.mode_set(mode="OBJECT")
for action in bpy.data.actions:
	for layer in action.layers:
		for strip in layer.strips:
			for bag in strip.channelbags:
				for curve in [c for c in bag.fcurves if c.data_path.startswith('pose.bones["skirt_')]:
					bag.fcurves.remove(curve)
print("RIG bones", len(rig.data.bones))
bpy.ops.import_scene.gltf(filepath=figure_path)
figure_rig = next(o for o in bpy.data.objects if o.type == "ARMATURE" and o is not rig)
body = next(o for o in bpy.data.objects if o.type == "MESH" and o.name.startswith("tripo_node"))
for o in list(bpy.data.objects):
	if o.type == "MESH" and o is not body:
		bpy.data.objects.remove(o, do_unlink=True)
# The peasant rig was built for a taller body than 1.72 m, so the figure is scaled to fit the rig's joints: the
# scale that best matches the heights of the figure's own skeleton joints (Tripo places these well) to the rig's.
PAIRS = [("Hips", "pelvis"), ("Spine2", "spine_03"), ("Neck", "neck_01"), ("Head", "Head"), ("LeftShoulder", "clavicle_l"),
	("LeftArm", "upperarm_l"), ("LeftForeArm", "lowerarm_l"), ("LeftHand", "hand_l"), ("RightShoulder", "clavicle_r"),
	("RightArm", "upperarm_r"), ("RightForeArm", "lowerarm_r"), ("RightHand", "hand_r"), ("LeftUpLeg", "thigh_l"),
	("LeftLeg", "calf_l"), ("LeftFoot", "foot_l"), ("RightUpLeg", "thigh_r"), ("RightLeg", "calf_r"), ("RightFoot", "foot_r")]
ground = min((body.matrix_world @ v.co).z for v in body.data.vertices)
figure_heights = [(figure_rig.matrix_world @ figure_rig.data.bones["mixamorig:" + m].head_local).z - ground for m, _ in PAIRS]
rig_heights = [(rig.matrix_world @ rig.data.bones[p].head_local).z for _, p in PAIRS]
fit_scale = sum(f * r for f, r in zip(figure_heights, rig_heights)) / sum(f * f for f in figure_heights)
bpy.data.objects.remove(figure_rig, do_unlink=True)
bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
for m in list(body.modifiers):
	body.modifiers.remove(m)
for g in list(body.vertex_groups):
	body.vertex_groups.remove(g)

zs = [v.co.z for v in body.data.vertices]
xs = [v.co.x for v in body.data.vertices]
ys = [v.co.y for v in body.data.vertices]
scale = fit_scale
centre = Vector(((min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2, min(zs)))
body.data.transform(Matrix.Scale(scale, 4) @ Matrix.Translation(-centre))
body.data.update()
body.name = "Skin"
print("ORIGINAL verts", len(body.data.vertices), "fitted height %.4f" % (scale * (max(zs) - min(zs))))

# The welded copy, for the weights only.
copy_mesh = body.data.copy()
copy = bpy.data.objects.new("Weld", copy_mesh)
bpy.context.scene.collection.objects.link(copy)
welder = bmesh.new()
welder.from_mesh(copy_mesh)
bmesh.ops.remove_doubles(welder, verts=welder.verts, dist=0.0001)
welder.to_mesh(copy_mesh)
welder.free()
copy_mesh.update()
print("WELDED verts", len(copy_mesh.vertices))
bpy.ops.object.select_all(action="DESELECT")
copy.select_set(True)
rig.select_set(True)
bpy.context.view_layer.objects.active = rig
bpy.ops.object.parent_set(type="ARMATURE_AUTO")
weighted = sum(1 for v in copy_mesh.vertices if any(g.weight > 0 for g in v.groups))
print("HEAT weighted", weighted, "of", len(copy_mesh.vertices))

# Copy each welded vertex's weights to the original vertices next to it.
tree = kdtree.KDTree(len(copy_mesh.vertices))
for v in copy_mesh.vertices:
	tree.insert(v.co, v.index)
tree.balance()
for bone in rig.data.bones:
	body.vertex_groups.new(name=bone.name)
for v in body.data.vertices:
	_, nearest, _ = tree.find(v.co)
	for g in copy_mesh.vertices[nearest].groups:
		if g.weight > 0:
			body.vertex_groups[copy.vertex_groups[g.group].name].add([v.index], g.weight, "REPLACE")
covered = sum(1 for v in body.data.vertices if any(g.weight > 0 for g in v.groups))
print("TRANSFER covered", covered, "of", len(body.data.vertices))
bpy.data.objects.remove(copy, do_unlink=True)
bpy.data.meshes.remove(copy_mesh)

body.parent = rig
body.matrix_parent_inverse = rig.matrix_world.inverted()
arm = body.modifiers.new("Armature", "ARMATURE")
arm.object = rig

# Skin: the basecolour and the normal map, at their full size: the face is a small share of them.
basecolour = next(i for i in bpy.data.images if i.size[0] > 0 and "basecolor" in i.name)
normal = next(i for i in bpy.data.images if i.size[0] > 0 and "normal" in i.name)
normal.colorspace_settings.name = "Non-Color"
FAIR = np.array([0xe0, 0xb8, 0x9a]) / 255.0
pixels = np.empty(basecolour.size[0] * basecolour.size[1] * 4, dtype=np.float32)
basecolour.pixels.foreach_get(pixels)
pixels = pixels.reshape(-1, 4)
grey = pixels[:, :3].mean(axis=1)
variation = 1.0 + 0.4 * (grey / grey.mean() - 1.0)
pixels[:, :3] = np.clip(FAIR[None, :] * variation[:, None], 0.0, 1.0)
basecolour.pixels.foreach_set(pixels.ravel())
basecolour.update()
print("TINT mean", tuple(round(float(c), 3) for c in pixels[:, :3].mean(axis=0)))
skin = bpy.data.materials.new("MI_Skin")
skin.use_nodes = True
nodes = skin.node_tree.nodes
links = skin.node_tree.links
principled = nodes["Principled BSDF"]
principled.inputs["Roughness"].default_value = 0.6
colour_node = nodes.new("ShaderNodeTexImage")
colour_node.image = basecolour
links.new(colour_node.outputs["Color"], principled.inputs["Base Color"])
normal_node = nodes.new("ShaderNodeTexImage")
normal_node.image = normal
normal_node.image.colorspace_settings.name = "Non-Color"
map_node = nodes.new("ShaderNodeNormalMap")
links.new(normal_node.outputs["Color"], map_node.inputs["Color"])
links.new(map_node.outputs["Normal"], principled.inputs["Normal"])
body.data.materials.clear()
body.data.materials.append(skin)

bpy.ops.object.select_all(action="DESELECT")
body.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.shade_smooth()

# Clothes: a long linen shirt (cămașă) to mid-thigh with red embroidery at the collar, cuffs and hem, linen trousers
# (ițari), a red woven belt (brâu), and leather sandals (opinci) with laces (nojițe) wound around the lower legs.
# Garments over the skin are the skin itself, lifted and smoothed, so they keep its bone weights; the shirt's skirt,
# belt, bands and laces are generated around them.
SHIRT = {"spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r", "upperarm_l", "upperarm_r", "lowerarm_l", "lowerarm_r"}
TROUSERS = {"pelvis", "thigh_l", "thigh_r", "calf_l", "calf_r"}
FEET = {"foot_l", "foot_r", "ball_l", "ball_r", "ball_leaf_l", "ball_leaf_r"}
LINEN = (0.86, 0.83, 0.74)
RED = (0.62, 0.08, 0.07)
DARK = (0.10, 0.08, 0.07)
LEATHER = (0.33, 0.20, 0.11)
LACE = (0.20, 0.12, 0.07)
FLEECE = (0.17, 0.16, 0.15)
FELT = (0.09, 0.085, 0.08)
BRASS = (0.78, 0.6, 0.28)

def joint(name):
	return rig.matrix_world @ rig.data.bones[name].head_local

# Each face belongs to the bone most of its vertices follow most.
names = {g.index: g.name for g in body.vertex_groups}
vertex_bone = []
for v in body.data.vertices:
	best = max(v.groups, key=lambda g: g.weight, default=None)
	vertex_bone.append(names[best.group] if best else "")
def face_bone(poly):
	votes = {}
	for i in poly.vertices:
		votes[vertex_bone[i]] = votes.get(vertex_bone[i], 0) + 1
	return max(votes, key=votes.get)
face_bones = [face_bone(p) for p in body.data.polygons]
points = [body.matrix_world @ v.co for v in body.data.vertices]
skin_tree = BVHTree.FromPolygons(points, [list(p.vertices) for p in body.data.polygons])

def image(name, pixels):
	# `pixels` is rows bottom-up, RGB in 0..1.
	h, w, _ = pixels.shape
	img = bpy.data.images.new(name, width=w, height=h)
	rgba = np.concatenate([pixels, np.ones((h, w, 1))], axis=2).astype(np.float32)
	img.pixels.foreach_set(rgba.ravel())
	img.pack()
	return img

def embroidery():
	# A border band: thin red lines along both edges and a chain of red diamonds with dark centres.
	h, w = 64, 128
	px = np.tile(np.array(LINEN), (h, w, 1))
	y, x = np.mgrid[0:h, 0:w]
	v = y / (h - 1)
	px[(np.abs(v - 0.12) < 0.04) | (np.abs(v - 0.88) < 0.04)] = RED
	tile = (x % 64) - 32
	d = np.abs(tile) / 30 + np.abs(y - 32) / 22
	px[d < 0.9] = RED
	px[d < 0.45] = DARK
	px[(d >= 0.9) & (d < 1.0)] = LINEN
	return image("Embroidery", px)

def belt_weave():
	h, w = 64, 64
	px = np.tile(np.array(RED), (h, w, 1))
	v = np.mgrid[0:h, 0:w][0] / (h - 1)
	px[(v < 0.14) | (v > 0.86)] = DARK
	px[np.abs(v - 0.5) < 0.07] = (0.85, 0.66, 0.2)
	px[np.abs(v - 0.3) < 0.025] = DARK
	px[np.abs(v - 0.7) < 0.025] = DARK
	return image("BeltWeave", px)

def surface(name, pixels, height, strength):
	# A tiling sRGB colour image of `pixels` (rows, columns, RGB) and the normal map of its `height` map.
	gx = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) / 2
	gy = (np.roll(height, -1, axis=0) - np.roll(height, 1, axis=0)) / 2
	normal = np.dstack([-gx * strength, -gy * strength, np.ones_like(height)])
	normal /= np.linalg.norm(normal, axis=2, keepdims=True)
	normal_image = image(name + "Normal", normal * 0.5 + 0.5)
	normal_image.colorspace_settings.name = "Non-Color"
	return image(name, np.clip(pixels, 0.0, 1.0)), normal_image

def shaded(colour, shade):
	# `colour` (sRGB) darkened or lightened pixel by pixel.
	return np.array(colour)[None, None, :] * shade[..., None]

def linen():
	# Homespun linen: a plain weave of uneven threads.
	n, threads = 256, 32
	cell = n // threads
	rng = np.random.default_rng(3)
	y, x = np.mgrid[0:n, 0:n]
	warp = rng.uniform(0.75, 1.25, threads)[x // cell]
	weft = rng.uniform(0.75, 1.25, threads)[y // cell]
	over = (x // cell + y // cell) % 2 == 0
	height = np.where(over, np.sin(np.pi * (x % cell + 0.5) / cell) ** 2 * warp, np.sin(np.pi * (y % cell + 0.5) / cell) ** 2 * weft)
	return surface("Linen", shaded(LINEN, 0.86 + 0.1 * height + 0.04 * np.where(over, warp, weft)), height, 1.5)

def noise(n, passes, seed):
	# Tiling noise in 0..1, blurred `passes` times.
	field = np.random.default_rng(seed).random((n, n))
	for _ in range(passes):
		field = (field + np.roll(field, 1, 0) + np.roll(field, -1, 0) + np.roll(field, 1, 1) + np.roll(field, -1, 1)) / 5
	return (field - field.min()) / (field.max() - field.min())

def fleece():
	# Lambskin for the cușmă: tight curls.
	curls = 0.5 + 0.5 * np.sin(noise(128, 6, 5) * 60)
	return surface("Fleece", shaded(FLEECE, 0.55 + 0.45 * curls), curls, 4.0)

def felt():
	# Felt for the pălărie: matted fibres.
	fibres = noise(128, 2, 9)
	return surface("Felt", shaded(FELT, 0.85 + 0.15 * fibres), fibres, 1.0)

def strands():
	# Hair: strands running down the texture, light and uneven, for the game to tint to the chosen colour.
	n = 128
	rng = np.random.default_rng(13)
	column = rng.random(n)
	column = (column + np.roll(column, 1) + np.roll(column, -1)) / 3
	height = 0.8 * column[None, :] + 0.2 * noise(n, 3, 17)
	return surface("Hair", shaded((0.95, 0.93, 0.9), 0.65 + 0.35 * height), height, 3.0)

def studded():
	# The chimir's leather, the belt's texture laid out the same way: stitched along both edges, with brass studs
	# down the middle.
	n = 64
	y, x = np.mgrid[0:n, 0:n]
	v = y / (n - 1)
	grain = noise(n, 1, 11)
	stud = np.clip(1.0 - np.hypot(x % 16 - 8, y - 32) / 5, 0.0, 1.0)
	stitch = ((np.abs(v - 0.15) < 0.02) | (np.abs(v - 0.85) < 0.02)) & (x % 6 < 4)
	pixels = np.where(stud[..., None] > 0, shaded(BRASS, 0.7 + 0.3 * stud), shaded(LEATHER, 0.85 + 0.15 * grain)) * np.where(stitch, 0.55, 1.0)[..., None]
	return surface("Chimir", pixels, 0.3 * grain + 2.0 * stud + 0.5 * stitch, 2.0)

def material(name, colour=None, img=None, roughness=0.95, normal=None):
	m = bpy.data.materials.new(name)
	m.use_nodes = True
	bsdf = m.node_tree.nodes["Principled BSDF"]
	bsdf.inputs["Roughness"].default_value = roughness
	if img is None:
		# The colours are sRGB, as painted into the textures; the base colour wants them linear.
		bsdf.inputs["Base Color"].default_value = (*(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in colour), 1.0)
	else:
		node = m.node_tree.nodes.new("ShaderNodeTexImage")
		node.image = img
		m.node_tree.links.new(node.outputs["Color"], bsdf.inputs["Base Color"])
	if normal is not None:
		node = m.node_tree.nodes.new("ShaderNodeTexImage")
		node.image = normal
		bump = m.node_tree.nodes.new("ShaderNodeNormalMap")
		m.node_tree.links.new(node.outputs["Color"], bump.inputs["Color"])
		m.node_tree.links.new(bump.outputs["Normal"], bsdf.inputs["Normal"])
	return m

EMBROIDERY = material("MI_Embroidery", img=embroidery())
LINEN_COLOUR, LINEN_NORMAL = linen()
LINEN_MAT = material("MI_Linen", img=LINEN_COLOUR, normal=LINEN_NORMAL)
FLEECE_COLOUR, FLEECE_NORMAL = fleece()
FELT_COLOUR, FELT_NORMAL = felt()
CHIMIR_COLOUR, CHIMIR_NORMAL = studded()
HAIR_COLOUR, HAIR_NORMAL = strands()
# Metres of cloth to one repeat of the linen texture, and to one diamond of the embroidery.
TILE, MOTIF = 0.1, 0.07

def attach(o):
	o.parent = rig
	o.matrix_parent_inverse = rig.matrix_world.inverted()
	arm = o.modifiers.new("Armature", "ARMATURE")
	arm.object = rig

def finish(o):
	bpy.ops.object.select_all(action="DESELECT")
	o.select_set(True)
	bpy.context.view_layer.objects.active = o
	bpy.ops.object.shade_smooth()

def shell(name, faces, offset, smoothing, mat, cuts=0):
	# The skin over `faces`, welded, each edge cut `cuts` times where the skin is too coarse, smoothed so it drapes,
	# its edges straightened, then kept `offset` above the skin.
	o = body.copy()
	o.data = body.data.copy()
	o.name = name
	bpy.context.scene.collection.objects.link(o)
	bm = bmesh.new()
	bm.from_mesh(o.data)
	bm.faces.ensure_lookup_table()
	bmesh.ops.delete(bm, geom=[f for f in bm.faces if f.index not in faces], context="FACES")
	bmesh.ops.delete(bm, geom=[v for v in bm.verts if not v.link_faces], context="VERTS")
	bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0001)
	if cuts:
		bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=cuts, use_grid_fill=True)
	for _ in range(smoothing):
		bmesh.ops.smooth_vert(bm, verts=bm.verts, factor=0.5, use_axis_x=True, use_axis_y=True, use_axis_z=True)
	def lift():
		for v in bm.verts:
			p = o.matrix_world @ v.co
			location, normal, _, _ = skin_tree.find_nearest(p)
			if location is not None and (p - location).dot(normal) < offset:
				v.co = o.matrix_world.inverted() @ (location + normal * offset)
	lift()
	edge = [v for v in bm.verts if v.is_boundary]
	for _ in range(8):
		targets = {}
		for v in edge:
			ring = [e.other_vert(v) for e in v.link_edges if e.is_boundary]
			if ring:
				targets[v] = sum((n.co for n in ring), Vector()) / len(ring)
		for v, t in targets.items():
			v.co = v.co.lerp(t, 0.5)
	lift()
	bm.to_mesh(o.data)
	bm.free()
	if cuts:
		# The vertices the cuts made have no weights, and the game would gather them all at the origin: every vertex
		# takes its nearest skin vertex's instead.
		tree = kdtree.KDTree(len(points))
		for i, p in enumerate(points):
			tree.insert(p, i)
		tree.balance()
		for v in o.data.vertices:
			nearest = body_weights[tree.find(o.matrix_world @ v.co)[1]]
			for g in list(v.groups):
				if o.vertex_groups[g.group].name not in nearest:
					o.vertex_groups[g.group].remove([v.index])
			for g, w in nearest.items():
				o.vertex_groups[g].add([v.index], w, "REPLACE")
	finish(o)
	bpy.ops.mesh.customdata_custom_splitnormals_clear()
	o.data.materials.clear()
	o.data.materials.append(mat)
	print("SHELL", name, len(o.data.vertices), "verts", sum(1 for v in o.data.vertices if not any(g.weight > 0 for g in v.groups)), "without weights")
	return o

body_points = np.array([tuple(p) for p in points])
body_bones = np.array(vertex_bone)
body_weights = [{names[g.group]: g.weight for g in v.groups if g.weight > 0} for v in body.data.vertices]

def outline(centre, axis, e1, e2, mask, slab, segments):
	# The convex outline of the body points in `mask` within `slab` of the plane square to `axis` through `centre`, as
	# its radius at each of `segments` angles from `e1` towards `e2`; None if no point is that close.
	rel = body_points[mask] - np.array(centre)
	rel = rel[np.abs(rel @ np.array(axis)) < slab]
	if len(rel) == 0:
		return None
	angles = np.arange(segments) * 2 * math.pi / segments
	return (np.outer(rel @ np.array(e1), np.cos(angles)) + np.outer(rel @ np.array(e2), np.sin(angles))).max(axis=0)

def frame(axis, up):
	# Two directions square to `axis` and each other, the first as near `up` as it can be.
	e1 = (up - axis * up.dot(axis)).normalized()
	return e1, axis.cross(e1)

def envelope(xs, ys):
	# The least concave function at or above the points (xs ascending), at each of xs: how cloth stretched over them runs.
	hull = []
	for p in zip(xs, ys):
		while len(hull) >= 2 and (hull[-1][0] - hull[-2][0]) * (p[1] - hull[-2][1]) - (hull[-1][1] - hull[-2][1]) * (p[0] - hull[-2][0]) >= 0:
			hull.pop()
		hull.append(p)
	return np.interp(xs, [h[0] for h in hull], [h[1] for h in hull])

def eased(raw, ease, along, passes=3, stretch=False):
	# Radii a ring of cloth hangs at around outlines `raw` (None where nothing is near: the nearest ring's is taken), at
	# distances `along` the tube, plus `ease`, smoothed from ring to ring over `passes`. With `stretch` the cloth first
	# runs lengthways straight over the body's high points, spanning the hollows between muscles: right for the chest,
	# but on a limb it carries the widest point (the shoulder, the hip) down its whole length.
	known = [i for i, r in enumerate(raw) if r is not None]
	raw = np.array([raw[i] if raw[i] is not None else raw[min(known, key=lambda j: abs(j - i))] for i in range(len(raw))])
	if stretch:
		order = np.argsort(along)
		for k in range(raw.shape[1]):
			raw[order, k] = envelope(np.array(along)[order], raw[order, k])
	least = [r + e for r, e in zip(raw, ease)]
	radii = [np.array(r) for r in least]
	for _ in range(passes):
		radii = [(radii[max(i - 1, 0)] + 2 * radii[i] + radii[min(i + 1, len(radii) - 1)]) / 4 for i in range(len(radii))]
	return [np.maximum(r, l * 0.97) for r, l in zip(radii, least)]

def garment(name, tubes, materials=(LINEN_MAT, EMBROIDERY)):
	# Cloth tubes in one mesh, each a dict of `rings` [(centre, radii)], `axis` (the way the rings run), `up` (where
	# angle 0 points), `mask` (the body points whose weights its vertices take), and optional embroidered `bands`
	# [(first ring, last ring)] and `stripes` [(first column, last column, first ring, last ring)], `keep`, which
	# says whether the face after ring i and column k is there, and `clear`, the least its vertices stand off the skin.
	bm = bmesh.new()
	uv = bm.loops.layers.uv.new("UVMap")
	weights = []
	for tube in tubes:
		rings, segments = tube["rings"], len(tube["rings"][0][1])
		e1, e2 = frame(tube["axis"], tube["up"])
		angles = [2 * math.pi * k / segments for k in range(segments)]
		rows = [[bm.verts.new(c + (e1 * math.cos(a) + e2 * math.sin(a)) * float(r[k])) for k, a in enumerate(angles)] for c, r in rings]
		if "clear" in tube:
			for row in rows:
				for v in row:
					location, normal, _, _ = skin_tree.find_nearest(v.co)
					if (v.co - location).dot(normal) < tube["clear"]:
						v.co = location + normal * tube["clear"]
		indices = np.nonzero(tube["mask"])[0]
		tree = kdtree.KDTree(len(indices))
		for j, i in enumerate(indices):
			tree.insert(points[i], j)
		tree.balance()
		for row in rows:
			for v in row:
				found = tree.find_n(v.co, 6)
				total, share = {}, 0.0
				for _, j, distance in found:
					w = 1.0 / max(distance, 1e-4)
					share += w
					for g, x in body_weights[indices[j]].items():
						total[g] = total.get(g, 0.0) + w * x
				weights.append({g: x / share for g, x in total.items()})
		along = [0.0]
		for i in range(1, len(rings)):
			along.append(along[-1] + (rings[i][0] - rings[i - 1][0]).length)
		around = sum(2 * math.pi * float(r.mean()) for _, r in rings) / len(rings)
		repeats, motifs = max(1, round(around / TILE)), max(1, round(around / MOTIF))
		for i in range(len(rows) - 1):
			for k in range(segments):
				if not tube.get("keep", lambda i, k: True)(i, k):
					continue
				f = bm.faces.new((rows[i][k], rows[i][(k + 1) % segments], rows[i + 1][(k + 1) % segments], rows[i + 1][k]))
				corners = [(k, i), (k + 1, i), (k + 1, i + 1), (k, i + 1)]
				stripe = next((s for s in tube.get("stripes", ()) if s[0] <= k < s[1] and s[2] <= i < s[3]), None)
				band = next((b for b in tube.get("bands", ()) if b[0] <= i < b[1]), None)
				if stripe:
					f.material_index = 1
					coords = [((along[r] - along[stripe[2]]) / MOTIF, (c - stripe[0]) / (stripe[1] - stripe[0])) for c, r in corners]
				elif band:
					f.material_index = 1
					coords = [(c / segments * motifs, (r - band[0]) / (band[1] - band[0])) for c, r in corners]
				else:
					coords = [(c / segments * repeats, along[r] / TILE) for c, r in corners]
				for l, coord in zip(f.loops, coords):
					l[uv].uv = coord
	mesh = bpy.data.meshes.new(name)
	bm.to_mesh(mesh)
	bm.free()
	o = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(o)
	for i, groups in enumerate(weights):
		for g, w in groups.items():
			if g not in o.vertex_groups:
				o.vertex_groups.new(name=g)
			o.vertex_groups[g].add([i], w, "REPLACE")
	attach(o)
	for m in materials:
		o.data.materials.append(m)
	finish(o)
	print("GARMENT", name, len(mesh.vertices), "verts")
	return o

def ring_radii(xy, centre, segments, support):
	# Radius of the cross-section `xy` around `centre` at each of `segments` angles.
	angles = [2 * math.pi * k / segments for k in range(segments)]
	rel = xy - centre
	if support:
		# The support function: a convex outline around everything, e.g. both thighs.
		return [float((rel @ np.array([math.cos(a), math.sin(a)])).max()) for a in angles]
	theta = np.arctan2(rel[:, 1], rel[:, 0])
	r = np.hypot(rel[:, 0], rel[:, 1])
	out = []
	for a in angles:
		near = r[np.abs((theta - a + math.pi) % (2 * math.pi) - math.pi) < 2 * math.pi / segments]
		out.append(float(near.max()) if len(near) else float(r.max()))
	return out

# The shirt's body: rings from under the belt to the shoulders round the torso's outline, loose and gathered into folds
# under the belt, then a collar standing round the neck. Embroidered stripes run down the chest either side of the front.
X, Y, Z = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
TORSO = np.isin(body_bones, ["pelvis", "spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r"])
NECK = body_bones == "neck_01"
SEG = 48
around = np.arange(SEG) * 2 * math.pi / SEG
heights = list(np.arange(joint("spine_01").z - 0.07, joint("neck_01").z, 0.02))
# One straight line up the middle, so neighbouring rings line up.
middle = float(np.median(body_points[TORSO][:, 1]))
# Inside the shoulder joints: beyond them the sleeves cover the shoulder, and turn with the arm.
inside = TORSO & (np.abs(body_points[:, 0]) < joint("upperarm_l").x - 0.045)
centres, raw, ease = [], [], []
for z in heights:
	centres.append(Vector((0.0, middle, z)))
	raw.append(outline(centres[-1], Z, X, Y, inside, 0.015, SEG))
	ease.append(0.025 + 0.007 * max(0.0, 1.0 - (z - heights[0]) / 0.18) * (0.5 + 0.5 * np.cos(14 * around)))
torso_rings = list(zip(centres, eased(raw, ease, heights, stretch=True)))
for z in (joint("neck_01").z + 0.01, joint("neck_01").z + 0.04):
	centre = Vector((0.0, float(body_points[NECK & (np.abs(body_points[:, 2] - z) < 0.015)][:, 1].mean()), z))
	torso_rings.append((centre, outline(centre, Z, X, Y, NECK, 0.015, SEG) + 0.012))
# The front is -y, a quarter turn before angle 0 (+x); the stripes run from the chest to the collar.
chest = next(i for i, z in enumerate(heights) if z >= 1.22)
tubes = [{"rings": torso_rings, "axis": Z, "up": X, "mask": TORSO | NECK, "bands": [(len(torso_rings) - 2, len(torso_rings) - 1)],
	"stripes": [(3 * SEG // 4 - 6, 3 * SEG // 4 - 4, chest, len(heights) - 1), (3 * SEG // 4 + 4, 3 * SEG // 4 + 6, chest, len(heights) - 1)]}]
# The sleeves: rings down each arm, widening to the forearm and gathered into folds above an embroidered cuff, with an
# embroidered band (altiță) just below the shoulder. Each begins inside the shirt's body, so the two always overlap.
for side in ("_l", "_r"):
	shoulder, wrist = joint("upperarm" + side), joint("hand" + side)
	axis = (wrist - shoulder).normalized()
	e1, e2 = frame(axis, Z)
	# Only the arm itself: near the shoulder some chest and back skin follows the upper arm too.
	rel = body_points - np.array(shoulder)
	reach = np.linalg.norm(rel - np.outer(rel @ np.array(axis), axis), axis=1)
	arm = np.isin(body_bones, ["upperarm" + side, "lowerarm" + side]) & (reach < 0.09)
	length = (wrist - shoulder).length - 0.025
	steps = list(np.arange(-0.04, length, 0.02)) + [length]
	ease = []
	for t in steps:
		if length - t <= 0.045:
			ease.append(np.full(24, 0.012))
		else:
			gather = 0.01 * max(0.0, 1.0 - (length - t - 0.045) / 0.15)
			ease.append(0.018 + 0.017 * min(1.0, t / 0.25) + gather * (0.5 + 0.5 * np.cos(8 * np.arange(24) * 2 * math.pi / 24)))
	centres = [shoulder + axis * float(t) for t in steps]
	rings = list(zip(centres, eased([outline(c, axis, e1, e2, arm, 0.012, 24) for c in centres], ease, steps, passes=2)))
	altita = [i for i, t in enumerate(steps) if 0.08 <= t < 0.14]
	cuff = next(i for i, t in enumerate(steps) if length - t <= 0.045)
	tubes.append({"rings": rings, "axis": axis, "up": Z, "mask": arm | (body_bones == "clavicle" + side), "bands": [(altita[0], altita[-1] + 1), (cuff, len(rings) - 1)]})
shirt = garment("Shirt", tubes)

# Ițari: a leg each from under the belt to the ankle, loose over the thigh and gathered into rings of folds down the calf.
tubes = []
for side, sign in (("_l", 1.0), ("_r", -1.0)):
	leg = np.isin(body_bones, ["thigh" + side, "calf" + side, "foot" + side])
	knee = joint("calf" + side).z
	heights = list(np.arange(joint("spine_01").z - 0.06, 0.5, -0.02)) + list(np.arange(0.5, 0.085, -0.0125))
	# The leg's centre line runs through the ankle, knee and hip joints.
	line = [joint(b + side) for b in ("foot", "calf", "thigh")]
	centres, raw, ease = [], [], []
	for z in heights:
		centres.append(Vector((float(np.interp(z, [p.z for p in line], [p.x for p in line])), float(np.interp(z, [p.z for p in line], [p.y for p in line])), z)))
		raw.append(outline(centres[-1], -Z, X, -Y, leg, 0.012, 24))
		ripple = 0.005 * (0.5 + 0.5 * math.sin(2 * math.pi * z / 0.05)) if z < knee - 0.04 else 0.0
		ease.append(np.full(24, (0.015 if z > knee else 0.012) + ripple))
	# The top, above the thigh, takes the hips' weights on its own side too.
	hips = (body_bones == "pelvis") & (body_points[:, 0] * sign > 0.0)
	tubes.append({"rings": list(zip(centres, eased(raw, ease, heights, passes=2))), "axis": -Z, "up": X, "mask": leg | hips})
trousers = garment("Trousers", tubes)
# The leather wraps the sole, the sides of the foot and all the toes, as opinci gather it over the front.
opinci = shell("Opinci", {i for i, p in enumerate(body.data.polygons) if face_bones[i] in {"ball_l", "ball_r", "ball_leaf_l", "ball_leaf_r"} or (face_bones[i] in FEET and (body.matrix_world @ p.center).z < 0.075)}, 0.006, 3, material("MI_Leather", LEATHER, roughness=0.7))
# The soles rest on the ground the bare feet stood on (the body's own space is the world's), so the model keeps its height.
for v in opinci.data.vertices:
	v.co.z = max(v.co.z, 0.0)

# The head, for hats, hair and beards: where this figure's hairline, ears, nostrils, mouth and chin are, below the top
# of its head (measured on the bare figure in its rest pose).
HEAD = body_bones == "Head"
head_y = float(np.median(body_points[HEAD][:, 1]))
top = skin_tree.ray_cast(Vector((0.0, head_y, 3.0)), -Z, 5.0)[0].z
HAIRLINE, EAR_TOP, EAR_BOTTOM, NOSE, MOUTH, CHIN = (top - d for d in (0.045, 0.108, 0.175, 0.175, 0.203, 0.245))

# Hats, each worn or not as the peasant chooses (human_actor.gd shows one at most): a tall lambskin cușmă, and a black
# felt pălărie with a brim and an embroidered band. Both sit on the head at the hairline, with room for hair under
# them, and turn with it.
rim = Vector((0.0, head_y, HAIRLINE))
fit = outline(rim, Z, X, Y, HEAD, 0.01, SEG) + 0.024
def hat(name, profile, materials, bands=()):
	# Rings at (height above the rim, room beyond the head, share of the head's outline) in turn: from the brim or the
	# rim, up round the head and across the top.
	rings = [(rim + Z * h, fit * share + room) for h, room, share in profile]
	return garment(name, [{"rings": rings, "axis": Z, "up": X, "mask": HEAD, "bands": bands}], materials)
cusma = hat("Cusma", [(0.0, 0.0, 1.0), (0.06, 0.006, 1.0), (0.12, 0.012, 1.0), (0.19, 0.014, 1.0), (0.205, 0.0, 0.75), (0.21, 0.0, 0.03)],
	(material("MI_Fleece", img=FLEECE_COLOUR, normal=FLEECE_NORMAL), EMBROIDERY))
palarie = hat("Palarie", [(-0.004, 0.075, 1.0), (0.004, 0.04, 1.0), (0.012, 0.0, 1.0), (0.04, 0.0, 1.0), (0.105, -0.008, 1.0), (0.115, -0.02, 0.8), (0.118, 0.0, 0.03)],
	(material("MI_Felt", img=FELT_COLOUR, normal=FELT_NORMAL, roughness=0.85), EMBROIDERY), bands=[(2, 3)])

# Hairstyles, one worn at most: cropped short, a bowl cut down to the brows, and long hair (plete) falling past the
# ears to the neck. Each is rings round the head from the top down, open for the face.
HAIR_MAT = material("MI_Hair", img=HAIR_COLOUR, normal=HAIR_NORMAL, roughness=0.6)
def hair(name, bottom, thickness, opening, hang=False, ends=None):
	# Hair from the top of the head down to `bottom`, thickness(z) off it and never closer than its least, with the face
	# open opening(z) degrees either side of the front. With `hang` it falls straight from the head's widest instead of
	# following it in under the jaw, and ends(degrees from the front) is how far down it reaches all round.
	# From the scalp's highest point, which is behind the head's middle line.
	crown = float(body_points[HEAD][:, 2].max())
	heights = list(np.arange(crown - 0.004, bottom, -0.01)) + [bottom]
	raw = [outline(Vector((0.0, head_y, z)), -Z, X, -Y, HEAD, 0.015, SEG) for z in heights]
	radii = eased(raw, [np.full(SEG, thickness(z)) for z in heights], heights, passes=1)
	if hang:
		radii = list(np.maximum.accumulate(np.array(radii), axis=0))
	rings = [(Vector((0.0, head_y, crown + thickness(crown))), np.full(SEG, 0.004))] + [(Vector((0.0, head_y, z)), r) for z, r in zip(heights, radii)]
	def keep(i, k):
		# Angles run from +x towards -y, so the front is a quarter turn round.
		off = abs(((k + 0.5) * 360 / SEG - 90 + 180) % 360 - 180)
		z = rings[i + 1][0].z
		return off >= opening(z) and (ends is None or z >= ends(off))
	least = min(thickness(z) for z in heights)
	return garment(name, [{"rings": rings, "axis": -Z, "up": X, "mask": HEAD, "keep": keep, "clear": least}], (HAIR_MAT,))
hairs = [
	hair("HairCropped", EAR_BOTTOM - 0.02, lambda z: 0.005, lambda z: 0 if z > HAIRLINE else 55 if z > EAR_TOP else 115),
	hair("HairBowl", EAR_TOP - 0.005, lambda z: 0.012 + 0.006 * max(0.0, 1.0 - (z - EAR_TOP) / 0.03), lambda z: 0),
	# Longest at the back, shorter beside the face.
	hair("HairLong", CHIN - 0.03, lambda z: 0.012 if z > EAR_TOP else 0.016, lambda z: 0 if z > HAIRLINE else 55 if z > NOSE else 75 if z > CHIN else 100,
		hang=True, ends=lambda off: CHIN - 0.03 + 0.05 * min(1.0, max(0.0, (150 - off) / 75))),
]

# Facial hair: a moustache (mustață) over the upper lip, and a full beard round the jaw and chin, leaving the lips.
# Both are the skin there, lifted off and thickened towards the chin and the moustache's drooping ends.
def front_angle(p):
	# Degrees round from the front of the head to `p`.
	return math.degrees(math.atan2(abs(p.x), max(1e-6, head_y - p.y))) if p.y < head_y else 180 - math.degrees(math.atan2(abs(p.x), p.y - head_y))
def facial(name, test, offset, thicken):
	o = shell(name, {i for i, p in enumerate(body.data.polygons) if face_bones[i] in {"Head", "neck_01"} and test(body.matrix_world @ p.center)}, offset, 8, HAIR_MAT, cuts=2)
	o.data.update()
	for v in o.data.vertices:
		v.co += v.normal * thicken(o.matrix_world @ v.co)
	return o
lips = lambda c: abs(c.x) < 0.028 and MOUTH - 0.012 < c.z < MOUTH + 0.01
moustache = facial("Moustache", lambda c: abs(c.x) < 0.05 and MOUTH < c.z < NOSE + 0.004 and front_angle(c) < 50, 0.004,
	lambda p: 0.006)
for v in moustache.data.vertices:
	v.co.z -= max(0.0, abs(v.co.x) - 0.018) * 0.6
beard = facial("Beard", lambda c: CHIN - 0.04 < c.z < EAR_BOTTOM - 0.005 and front_angle(c) < 100 and not lips(c) and (abs(c.x) > 0.035 or c.z < NOSE - 0.002),
	0.005, lambda p: 0.003 + 0.012 * min(1.0, max(0.0, (MOUTH - p.z) / 0.04)))

# The shirt's skirt: from the belt down to mid-thigh, clearing the hips and both thighs and only flaring outwards
# below, with an embroidered border above the hem. Its top follows the hips; lower down it takes more of each thigh.
waist = joint("spine_01").z - 0.03
top, hem = waist + 0.02, (joint("thigh_l").z + joint("calf_l").z) / 2 - 0.02
BAND = 0.06
SEGMENTS, ROWS = 48, 12
centre = np.array([joint("pelvis").x, joint("pelvis").y])
cloth = np.array(points + [shirt.matrix_world @ v.co for v in shirt.data.vertices] + [trousers.matrix_world @ v.co for v in trousers.data.vertices])
zs = [top - (top - (hem + BAND)) * r / (ROWS - 1) for r in range(ROWS)] + [hem]
radii = []
for z in zs:
	near = cloth[np.abs(cloth[:, 2] - z) < 0.025]
	r = ring_radii(near[:, :2], centre, SEGMENTS, support=True)
	t = (top - z) / (top - hem)
	# Folds gathered by the belt, deepening towards the hem.
	r = [x + 0.014 + 0.038 * t + (0.002 + 0.014 * t) * (0.5 + 0.5 * math.cos(12 * 2 * math.pi * k / SEGMENTS)) for k, x in enumerate(r)]
	if radii:
		r = [max(a, b) for a, b in zip(r, radii[-1])]
	radii.append(r)
bm = bmesh.new()
uv = bm.loops.layers.uv.new("UVMap")
rows = [[bm.verts.new((centre[0] + r[k] * math.cos(2 * math.pi * k / SEGMENTS), centre[1] + r[k] * math.sin(2 * math.pi * k / SEGMENTS), z)) for k in range(SEGMENTS)] for z, r in zip(zs, radii)]
circumference = sum((rows[-1][(k + 1) % SEGMENTS].co - rows[-1][k].co).length for k in range(SEGMENTS))
repeats = max(1, round(circumference / 0.07))
for r in range(len(rows) - 1):
	for k in range(SEGMENTS):
		n = (k + 1) % SEGMENTS
		f = bm.faces.new((rows[r][k], rows[r][n], rows[r + 1][n], rows[r + 1][k]))
		if r == len(rows) - 2:
			f.material_index = 1
			for l, (u, v) in zip(f.loops, [(k, 1), (k + 1, 1), (k + 1, 0), (k, 0)]):
				l[uv].uv = (u / SEGMENTS * repeats, v)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
skirt_mesh = bpy.data.meshes.new("Skirt")
bm.to_mesh(skirt_mesh)
bm.free()
skirt = bpy.data.objects.new("Skirt", skirt_mesh)
bpy.context.scene.collection.objects.link(skirt)
# The skirt hangs from a chain of two bones down every third column of the cloth, so it can bend halfway over the
# buttocks; each vertex follows the columns either side of it, and the upper or lower bone by its height.
COLUMNS = SEGMENTS // 3
for v in skirt_mesh.vertices:
	u = (math.atan2(v.co.y - centre[1], v.co.x - centre[0]) / (2 * math.pi) % 1.0) * COLUMNS
	k, f = int(u) % COLUMNS, u - int(u)
	upper = min(1.0, max(0.0, (0.6 - (top - v.co.z) / (top - hem)) / 0.2))
	for j, w in ((k, 1.0 - f), ((k + 1) % COLUMNS, f)):
		for name, share in (("skirt_%02d_a" % j, upper), ("skirt_%02d_b" % j, 1.0 - upper)):
			if name not in skirt.vertex_groups:
				skirt.vertex_groups.new(name=name)
			skirt.vertex_groups[name].add([v.index], w * share, "ADD")
column_top = [Vector((centre[0] + radii[0][3 * j] * math.cos(2 * math.pi * j / COLUMNS), centre[1] + radii[0][3 * j] * math.sin(2 * math.pi * j / COLUMNS), zs[0])) for j in range(COLUMNS)]
column_hem = [Vector((centre[0] + radii[-1][3 * j] * math.cos(2 * math.pi * j / COLUMNS), centre[1] + radii[-1][3 * j] * math.sin(2 * math.pi * j / COLUMNS), zs[-1])) for j in range(COLUMNS)]
bpy.ops.object.select_all(action="DESELECT")
bpy.context.view_layer.objects.active = rig
bpy.ops.object.mode_set(mode="EDIT")
for j in range(COLUMNS):
	upper = rig.data.edit_bones.new("skirt_%02d_a" % j)
	upper.head = rig.matrix_world.inverted() @ column_top[j]
	upper.tail = rig.matrix_world.inverted() @ column_top[j].lerp(column_hem[j], 0.5)
	upper.parent = rig.data.edit_bones["pelvis"]
	lower = rig.data.edit_bones.new("skirt_%02d_b" % j)
	lower.head = upper.tail
	lower.tail = rig.matrix_world.inverted() @ column_hem[j]
	lower.parent = upper
	lower.use_connect = True
bpy.ops.object.mode_set(mode="OBJECT")

# Every clip gets the skirt's bones baked in. Each frame, each column's upper bone and then its lower one hangs as low
# as it can on the arc from moving with the hips to moving with the thigh on its side, without coming within CLEAR of
# the legs or the ground: kneeling, its back hangs from the hips and its front lies on the thighs; bending over, it
# folds over the buttocks and hangs along the thighs.
CLEAR, STEPS, SAMPLES, PUSH = 0.035, 20, 5, 30.0
collider = body.copy()
collider.data = body.data.copy()
bpy.context.scene.collection.objects.link(collider)
bm = bmesh.new()
bm.from_mesh(collider.data)
bm.faces.ensure_lookup_table()
bmesh.ops.delete(bm, geom=[f for f in bm.faces if face_bones[f.index] not in TROUSERS | FEET], context="FACES")
bm.to_mesh(collider.data)
bm.free()
rest = {b.name: rig.matrix_world @ b.matrix_local for b in rig.data.bones}
half = abs(joint("thigh_l").x) * 1.2
columns = []
for j in range(COLUMNS):
	left = min(1.0, max(0.0, 0.5 + 0.5 * float(column_top[j].x - centre[0]) / half))
	columns.append(("skirt_%02d" % j, column_top[j], (column_hem[j] - column_top[j]).normalized(), (column_hem[j] - column_top[j]).length / 2, left))
def posed(name):
	return rig.matrix_world @ rig.pose.bones[name].matrix @ rest[name].inverted()
def swing(side):
	# How the thigh has turned to point where it does now, leaving out its twist about its own length.
	thigh, knee = rig.data.bones["thigh_" + side], rig.data.bones["calf_" + side]
	now = rig.matrix_world @ (rig.pose.bones[knee.name].head - rig.pose.bones[thigh.name].head)
	return (rig.matrix_world @ (knee.head_local - thigh.head_local)).rotation_difference(now)
def overlap(tree, p):
	# How far `p` is inside CLEAR of the legs (whose own space is the world's) or of the ground.
	location, normal, _, distance = tree.find_nearest(p)
	depth = 0.0
	if location is not None:
		depth = max(0.0, CLEAR - (distance if (p - location).dot(normal) > 0 else -distance))
	return depth + max(0.0, 0.01 - p.z)
def hang(tree, start, reach, with_hips, with_thigh):
	# The lowest direction on the arc from `with_hips` to `with_thigh` that keeps `reach` metres from `start` clear.
	def cost(d):
		return d.z + PUSH * sum(overlap(tree, start + d * reach * (i + 1) / SAMPLES) for i in range(SAMPLES))
	return min((with_hips.slerp(with_thigh, s / STEPS, with_hips) for s in range(STEPS + 1)), key=cost)
scene = bpy.context.scene
depsgraph = bpy.context.evaluated_depsgraph_get()
strips = [(track, strip) for track in rig.animation_data.nla_tracks for strip in track.strips]
mutes = [track.mute for track, _ in strips]
for track, _ in strips:
	track.mute = True
for _, strip in strips:
	action = strip.action
	rig.animation_data.action = action
	first, last = (int(round(x)) for x in action.frame_range)
	keys = []
	for frame in range(first, last + 1):
		scene.frame_set(frame)
		tree = BVHTree.FromObject(collider, depsgraph)
		hips, thigh_l, thigh_r = posed("pelvis"), swing("l"), swing("r")
		for name, head, down, half_length, left in columns:
			head = hips @ head
			with_hips = hips.to_3x3() @ down
			with_thigh = (left * (thigh_l @ down) + (1.0 - left) * (thigh_r @ down)).normalized()
			upper = hang(tree, head, half_length, with_hips, with_thigh)
			lower = hang(tree, head + upper * half_length, half_length, with_hips, with_thigh)
			turn_upper, turn_lower = with_hips.rotation_difference(upper), with_hips.rotation_difference(lower)
			# Each bone's own rotation, from its rest pose carried by the hips; the lower one's is on top of the upper's.
			follow = (hips @ rest[name + "_a"]).to_quaternion()
			keys.append((frame, name + "_a", follow.inverted() @ turn_upper @ follow))
			follow = (hips @ rest[name + "_b"]).to_quaternion()
			keys.append((frame, name + "_b", follow.inverted() @ turn_upper.inverted() @ turn_lower @ follow))
	previous = {}
	for frame, name, turn in keys:
		# Keep each bone's quaternions on one side, so the keys interpolate the short way.
		if name in previous and previous[name].dot(turn) < 0:
			turn.negate()
		previous[name] = turn
		bone = rig.pose.bones[name]
		bone.rotation_quaternion = turn
		bone.keyframe_insert("rotation_quaternion", frame=frame)
	print("SKIRT baked", action.name, last - first + 1, "frames")
rig.animation_data.action = None
for (track, _), mute in zip(strips, mutes):
	track.mute = mute
for name, *_ in columns:
	rig.pose.bones[name + "_a"].rotation_quaternion = (1, 0, 0, 0)
	rig.pose.bones[name + "_b"].rotation_quaternion = (1, 0, 0, 0)
bpy.data.objects.remove(collider, do_unlink=True)
attach(skirt)
skirt.data.materials.append(LINEN_MAT)
skirt.data.materials.append(EMBROIDERY)
finish(skirt)

# The belt, 6 cm wide, close over the shirt where the skirt begins.
HALF = 0.03
near = cloth[np.abs(cloth[:, 2] - waist) < HALF]
near = np.concatenate([near, np.array([skirt.matrix_world @ v.co for v in skirt_mesh.vertices if abs(v.co.z - waist) < HALF])])
belt_r = [x + 0.004 for x in ring_radii(near[:, :2], centre, SEGMENTS, support=True)]
bm = bmesh.new()
uv = bm.loops.layers.uv.new("UVMap")
rows = [[bm.verts.new((centre[0] + belt_r[k] * math.cos(2 * math.pi * k / SEGMENTS), centre[1] + belt_r[k] * math.sin(2 * math.pi * k / SEGMENTS), z)) for k in range(SEGMENTS)] for z in (waist - HALF, waist + HALF)]
for k in range(SEGMENTS):
	n = (k + 1) % SEGMENTS
	f = bm.faces.new((rows[0][k], rows[0][n], rows[1][n], rows[1][k]))
	for l, (u, v) in zip(f.loops, [(k, 0), (k + 1, 0), (k + 1, 1), (k, 1)]):
		l[uv].uv = (u / SEGMENTS * 4, v)
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
belt_mesh = bpy.data.meshes.new("Belt")
bm.to_mesh(belt_mesh)
bm.free()
belt = bpy.data.objects.new("Belt", belt_mesh)
bpy.context.scene.collection.objects.link(belt)
for g in ("spine_01", "pelvis"):
	belt.vertex_groups.new(name=g)
	belt.vertex_groups[g].add(list(range(len(belt_mesh.vertices))), 0.5, "REPLACE")
attach(belt)
belt.data.materials.append(material("MI_Belt", img=belt_weave()))
finish(belt)
# The chimir, the wide leather belt worn instead of the brâu: the same band in studded leather.
chimir = belt.copy()
chimir.data = belt.data.copy()
chimir.name = "Chimir"
bpy.context.scene.collection.objects.link(chimir)
chimir.data.materials.clear()
chimir.data.materials.append(material("MI_Chimir", img=CHIMIR_COLOUR, normal=CHIMIR_NORMAL, roughness=0.6))

# Nojițe: leather laces wound around each lower leg over the trousers, following the trouser leg.
trouser_pts = np.array([trousers.matrix_world @ v.co for v in trousers.data.vertices])
tree = kdtree.KDTree(len(trouser_pts))
for i, p in enumerate(trouser_pts):
	tree.insert(p, i)
tree.balance()
tgroups = {g.index: g.name for g in trousers.vertex_groups}
bm = bmesh.new()
lace_weights = []
# The trousers' vertices are the left leg's, then the right's.
legs = np.arange(len(trouser_pts)) < len(trouser_pts) // 2
for own in (legs, ~legs):
	for z in (0.14, 0.2, 0.26):
		leg = trouser_pts[(np.abs(trouser_pts[:, 2] - z) < 0.015) & own]
		c = leg[:, :2].mean(axis=0)
		r = [x + 0.005 for x in ring_radii(leg[:, :2], c, 24, support=False)]
		rows = [[bm.verts.new((c[0] + r[k] * math.cos(2 * math.pi * k / 24), c[1] + r[k] * math.sin(2 * math.pi * k / 24), zz)) for k in range(24)] for zz in (z - 0.006, z + 0.006)]
		for k in range(24):
			bm.faces.new((rows[0][k], rows[0][(k + 1) % 24], rows[1][(k + 1) % 24], rows[1][k]))
		for row in rows:
			for vert in row:
				_, index, _ = tree.find(vert.co)
				lace_weights.append([(tgroups[g.group], g.weight) for g in trousers.data.vertices[index].groups])
bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
lace_mesh = bpy.data.meshes.new("Laces")
bm.to_mesh(lace_mesh)
bm.free()
laces = bpy.data.objects.new("Laces", lace_mesh)
bpy.context.scene.collection.objects.link(laces)
for i, weights in enumerate(lace_weights):
	for g, w in weights:
		if g not in laces.vertex_groups:
			laces.vertex_groups.new(name=g)
		laces.vertex_groups[g].add([i], w, "REPLACE")
attach(laces)
laces.data.materials.append(material("MI_Lace", LACE, roughness=0.7))
finish(laces)

# Cloth thickness on the garments, so their open edges show a hem.
for o, thickness in ((shirt, 0.005), (trousers, 0.005), (skirt, 0.005), (opinci, 0.006), (cusma, 0.006), (palarie, 0.004), *((h, 0.004) for h in hairs), (beard, 0.003), (moustache, 0.003)):
	bpy.ops.object.select_all(action="DESELECT")
	o.select_set(True)
	bpy.context.view_layer.objects.active = o
	solid = o.modifiers.new("Solidify", "SOLIDIFY")
	solid.thickness = thickness
	solid.offset = -1.0
	bpy.ops.object.modifier_move_to_index(modifier="Solidify", index=0)
	bpy.ops.object.modifier_apply(modifier="Solidify")

# The skin under the shirt and trousers is never seen; it goes, keeping two rings under the garment edges, except round
# the neck, where the collar covers the edge and the kept skin would poke out over the shirt's shoulders.
bm = bmesh.new()
bm.from_mesh(body.data)
bm.faces.ensure_lookup_table()
covered = {f for f in bm.faces if face_bones[f.index] in SHIRT | TROUSERS}
hidden = set(covered)
for _ in range(2):
	hidden -= {f for f in hidden if any(g not in hidden for v in f.verts for g in v.link_faces)}
hidden |= {f for f in covered if f.calc_center_median().z > joint("neck_01").z - 0.06}
bmesh.ops.delete(bm, geom=list(hidden), context="FACES")
bm.to_mesh(body.data)
bm.free()
print("HIDDEN skin faces", len(hidden))

bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animation_mode="NLA_TRACKS", export_image_format="JPEG", export_jpeg_quality=85)
print("Wrote", out, sorted(o.name for o in bpy.data.objects if o.type == "MESH"))
