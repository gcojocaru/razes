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

# Skin: the basecolour and the normal map, both at 2048 px.
basecolour = next(i for i in bpy.data.images if i.size[0] > 0 and "basecolor" in i.name)
normal = next(i for i in bpy.data.images if i.size[0] > 0 and "normal" in i.name)
basecolour.scale(2048, 2048)
normal.scale(2048, 2048)
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

def material(name, colour=None, img=None, roughness=0.95):
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
	return m

EMBROIDERY = material("MI_Embroidery", img=embroidery())
LINEN_MAT = material("MI_Linen", LINEN)

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

def shell(name, faces, offset, smoothing, mat):
	# The skin over `faces`, welded, smoothed so it drapes, its edges straightened, then kept `offset` above the skin.
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
	finish(o)
	bpy.ops.mesh.customdata_custom_splitnormals_clear()
	o.data.materials.clear()
	o.data.materials.append(mat)
	print("SHELL", name, len(o.data.vertices), "verts")
	return o

def boundary_loops(o):
	bm = bmesh.new()
	bm.from_mesh(o.data)
	bm.verts.ensure_lookup_table()
	bm.normal_update()
	neighbours = {}
	for e in bm.edges:
		if e.is_boundary:
			a, b = e.verts[0].index, e.verts[1].index
			neighbours.setdefault(a, []).append(b)
			neighbours.setdefault(b, []).append(a)
	seen, loops = set(), []
	for start in neighbours:
		if start in seen:
			continue
		loop, previous, current = [start], None, start
		seen.add(start)
		while True:
			following = [n for n in neighbours[current] if n != previous and n not in seen]
			if not following:
				break
			previous, current = current, following[0]
			loop.append(current)
			seen.add(current)
		if len(loop) >= 8:
			loops.append(loop)
	return bm, loops

def band(name, garment, bm, loop, width, offset=0.003, motif=0.07):
	# An embroidered strip along one edge of `garment`, `width` into the cloth, following its surface.
	tree = BVHTree.FromBMesh(bm)
	groups = {g.index: g.name for g in garment.vertex_groups}
	out_bm = bmesh.new()
	uv = out_bm.loops.layers.uv.new("UVMap")
	edge_pts, inner_pts, weights = [], [], []
	last = Vector((0, 0, -1))
	for i in loop:
		v = bm.verts[i]
		inner = [e.other_vert(v).co - v.co for e in v.link_edges if not e.is_boundary]
		direction = (sum(inner, Vector()) / len(inner)).normalized() if inner else last
		last = direction
		location, normal, _, _ = tree.find_nearest(v.co + direction * width)
		edge_pts.append(out_bm.verts.new(v.co + v.normal * offset))
		inner_pts.append(out_bm.verts.new(location + normal * offset))
		weights.append([(groups[g.group], g.weight) for g in garment.data.vertices[i].groups])
	n = len(loop)
	length = 0.0
	for k in range(n):
		j = (k + 1) % n
		step = (edge_pts[j].co - edge_pts[k].co).length
		f = out_bm.faces.new((edge_pts[k], edge_pts[j], inner_pts[j], inner_pts[k]))
		u0, u1 = length / motif, (length + step) / motif
		for l, (u, w) in zip(f.loops, [(u0, 0), (u1, 0), (u1, 1), (u0, 1)]):
			l[uv].uv = (u, w)
		length += step
	out_bm.normal_update()
	if sum(f.normal.dot(bm.verts[loop[0]].normal) for f in out_bm.faces) < 0:
		bmesh.ops.reverse_faces(out_bm, faces=out_bm.faces)
	mesh = bpy.data.meshes.new(name)
	out_bm.to_mesh(mesh)
	out_bm.free()
	o = bpy.data.objects.new(name, mesh)
	bpy.context.scene.collection.objects.link(o)
	for k in range(n):
		for g, w in weights[k]:
			if g not in o.vertex_groups:
				o.vertex_groups.new(name=g)
			o.vertex_groups[g].add([2 * k, 2 * k + 1], w, "REPLACE")
	attach(o)
	o.data.materials.append(EMBROIDERY)
	finish(o)
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

# Shirt top, trousers, opinci: the skin over their regions.
faces = lambda bones, test=lambda p: True: {i for i, p in enumerate(body.data.polygons) if face_bones[i] in bones and test(p)}
shirt = shell("Shirt", faces(SHIRT), 0.028, 25, LINEN_MAT)
trousers = shell("Trousers", faces(TROUSERS), 0.016, 16, LINEN_MAT)
# The leather wraps the sole, the sides of the foot and all the toes, as opinci gather it over the front.
opinci = shell("Opinci", {i for i, p in enumerate(body.data.polygons) if face_bones[i] in {"ball_l", "ball_r", "ball_leaf_l", "ball_leaf_r"} or (face_bones[i] in FEET and (body.matrix_world @ p.center).z < 0.075)}, 0.006, 3, material("MI_Leather", LEATHER, roughness=0.7))
# The soles rest on the ground the bare feet stood on (the body's own space is the world's), so the model keeps its height.
for v in opinci.data.vertices:
	v.co.z = max(v.co.z, 0.0)

# Collar and cuff embroidery along the shirt's edges: the neck is the highest edge, the cuffs the furthest out.
bm, loops = boundary_loops(shirt)
heights = [sum(bm.verts[i].co.z for i in l) / len(l) for l in loops]
reach = [sum(abs(bm.verts[i].co.x) for i in l) / len(l) for l in loops]
collar = loops[heights.index(max(heights))]
cuffs = [l for l, x in zip(loops, reach) if x > 0.45]
bands = [band("Collar", shirt, bm, collar, 0.035)] + [band("Cuff", shirt, bm, l, 0.045) for l in cuffs]
bm.free()
print("BANDS collar 1 cuffs", len(cuffs), "of", len(loops), "edges")

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
	r = [x + 0.022 + 0.03 * t for x in r]
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

# The belt, over the shirt where the skirt begins.
HALF = 0.045
near = cloth[np.abs(cloth[:, 2] - waist) < HALF]
near = np.concatenate([near, np.array([skirt.matrix_world @ v.co for v in skirt_mesh.vertices if abs(v.co.z - waist) < HALF])])
belt_r = [x + 0.008 for x in ring_radii(near[:, :2], centre, SEGMENTS, support=True)]
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

# Nojițe: leather laces wound around each lower leg over the trousers, following the trouser leg.
trouser_pts = np.array([trousers.matrix_world @ v.co for v in trousers.data.vertices])
tree = kdtree.KDTree(len(trouser_pts))
for i, p in enumerate(trouser_pts):
	tree.insert(p, i)
tree.balance()
tgroups = {g.index: g.name for g in trousers.vertex_groups}
bm = bmesh.new()
lace_weights = []
for side in (1, -1):
	for z in (0.14, 0.2, 0.26):
		leg = trouser_pts[(np.abs(trouser_pts[:, 2] - z) < 0.015) & (np.sign(trouser_pts[:, 0]) == side)]
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
for o, thickness in ((shirt, 0.005), (trousers, 0.005), (skirt, 0.005), (opinci, 0.006)):
	bpy.ops.object.select_all(action="DESELECT")
	o.select_set(True)
	bpy.context.view_layer.objects.active = o
	solid = o.modifiers.new("Solidify", "SOLIDIFY")
	solid.thickness = thickness
	solid.offset = -1.0
	bpy.ops.object.modifier_move_to_index(modifier="Solidify", index=0)
	bpy.ops.object.modifier_apply(modifier="Solidify")

# The skin under the shirt and trousers is never seen; it goes, keeping two rings under the garment edges.
bm = bmesh.new()
bm.from_mesh(body.data)
bm.faces.ensure_lookup_table()
hidden = {f for f in bm.faces if face_bones[f.index] in SHIRT | TROUSERS}
for _ in range(2):
	hidden -= {f for f in hidden if any(g not in hidden for v in f.verts for g in v.link_faces)}
bmesh.ops.delete(bm, geom=list(hidden), context="FACES")
bm.to_mesh(body.data)
bm.free()
print("HIDDEN skin faces", len(hidden))

bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animation_mode="NLA_TRACKS", export_image_format="JPEG", export_jpeg_quality=85)
print("Wrote", out, sorted(o.name for o in bpy.data.objects if o.type == "MESH"))
