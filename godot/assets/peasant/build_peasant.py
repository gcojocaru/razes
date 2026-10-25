# Assembles peasant.glb from the CC0 Quaternius packs listed in SOURCE.md.
# blender -b -P build_peasant.py -- <folder holding the four unzipped packs>
import bpy
import bmesh
import glob
import os
import sys

packs = sys.argv[sys.argv.index("--") + 1]
out = os.path.join(os.path.dirname(os.path.abspath(__file__)), "peasant.glb")
KEEP = ["Idle_Loop", "Walk_Loop", "Fixing_Kneeling", "Death01", "Farm_PlantSeed", "Farm_Harvest", "TreeChopping_Loop", "LayToIdle"]
LIP = 1.615


def find(pattern):
	return glob.glob(os.path.join(packs, "**", pattern), recursive=True)[0]


def load(path):
	before = set(bpy.data.objects)
	bpy.ops.import_scene.gltf(filepath=path)
	return [o for o in bpy.data.objects if o not in before]


bpy.ops.wm.read_factory_settings(use_empty=True)
outfit = load(find("Outfits/Male_Peasant.gltf"))
rig = next(o for o in outfit if o.type == "ARMATURE")
rig.name = "Peasant"
parts = [o for o in outfit if o.type == "MESH"]
extras = load(find("Godot - UE/Superhero_Male_FullBody.gltf"))
extras += load(find("Rigged to Head Bone/*/Hair_SimpleParted.gltf"))
extras += load(find("Rigged to Head Bone/*/Hair_Beard.gltf"))
for obj in extras:
	if obj.type != "MESH":
		continue
	mats = [slot.material.name for slot in obj.material_slots if slot.material]
	if "MI_Superhero_Male" in mats:
		obj.name = "Skin"
		# The outfit covers the body; keep only what the head and neck bones carry.
		groups = {g.index: g.name for g in obj.vertex_groups}
		mesh = bmesh.new()
		mesh.from_mesh(obj.data)
		deform = mesh.verts.layers.deform.active
		mesh.verts.ensure_lookup_table()
		bmesh.ops.delete(mesh, geom=[v for v in mesh.verts if sum(w for g, w in v[deform].items() if groups[g] in ("Head", "neck_01")) < 0.5], context="VERTS")
		mesh.to_mesh(obj.data)
		image = obj.material_slots[0].material.node_tree.nodes
		for node in image:
			if node.type == "TEX_IMAGE" and "Dark" in node.image.name:
				node.image = bpy.data.images.load(find("Base Characters/Textures/T_Superhero_Male_Ligh.png"))
	elif "MI_Eyes" in mats:
		obj.name = "Eyes"
	elif "Plane.002" in obj.data.name or obj.name.startswith("Plane.002"):
		obj.name = "Hair"
	elif obj.name.startswith("Plane.006") or "Plane.006" in obj.data.name:
		obj.name = "Beard"
	else:
		obj.name = "Eyebrows"
	obj.parent = rig
	for mod in obj.modifiers:
		if mod.type == "ARMATURE":
			mod.object = rig
	parts.append(obj)
for obj in extras:
	if obj.type != "MESH":
		bpy.data.objects.remove(obj)
# The moustache is the beard's upper lip, so either can be shown alone.
beard = bpy.data.objects["Beard"]
moustache = beard.copy()
moustache.data = beard.data.copy()
moustache.name = "Moustache"
bpy.context.scene.collection.objects.link(moustache)
for obj, keep in [(moustache, True), (beard, False)]:
	mesh = bmesh.new()
	mesh.from_mesh(obj.data)
	lip = lambda v: v.co.z > LIP and abs(v.co.x) < 0.05 and v.co.y < -0.06
	bmesh.ops.delete(mesh, geom=[f for f in mesh.faces if all(lip(v) for v in f.verts) != keep], context="FACES")
	mesh.to_mesh(obj.data)
parts.append(moustache)

for path in [find("UAL1_Standard.glb"), find("UAL2_Standard.glb")]:
	for obj in load(path):
		bpy.data.objects.remove(obj)
rig.animation_data_create()
for action in list(bpy.data.actions):
	name = next((k for k in KEEP if action.name.startswith(k)), None)
	if name is None or name in [t.name for t in rig.animation_data.nla_tracks]:
		bpy.data.actions.remove(action)
		continue
	action.name = name
	track = rig.animation_data.nla_tracks.new()
	track.name = name
	strip = track.strips.new(name, int(action.frame_range[0]), action)
	if action.slots:
		strip.action_slot = action.slots[0]
for image in bpy.data.images:
	if image.size[0] > 1024:
		image.scale(1024, 1024)

# Left at its own 1.718 m, the default peasant's height.
bpy.ops.object.select_all(action="DESELECT")
bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_animation_mode="NLA_TRACKS", export_image_format="JPEG", export_jpeg_quality=85)
print("Wrote", out, "with", [t.name for t in rig.animation_data.nla_tracks])
