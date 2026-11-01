import bpy
from pathlib import Path
from mathutils import Vector

root = Path(r"K:/GoDotProjects/xyles-mmo")
scene = bpy.context.scene
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(root / 'assets/models/characters/human_fighter/head_revision/source.glb'))
meshes = [o for o in scene.objects if o.type == 'MESH']
arms = [o for o in scene.objects if o.type == 'ARMATURE']
print('MESHES', [(m.name, len(m.data.vertices), len(m.data.polygons)) for m in meshes])
print('ARMS', [(a.name, len(a.data.bones)) for a in arms])
body = max(meshes, key=lambda o: len(o.data.vertices))
print('ACTIVE', body.name, 'bound', tuple(round(v, 4) for v in body.dimensions))
print('MATERIALS', [(i, m.name if m else None) for i, m in enumerate(body.data.materials)])
print('SHAPE KEYS', [(i, k.name) for i, k in enumerate(body.data.shape_keys.key_blocks)] if body.data.shape_keys else 'none')
print('VGROUPS', len(body.vertex_groups), [g.name for g in body.vertex_groups])
print('BOUNDS', [tuple(round(c, 3) for c in body.matrix_world @ Vector(c)) for c in body.bound_box])
# Sample Z distribution of vertices by group.
import collections
for bone in ['Head', 'Neck', 'Spine2', 'Spine1', 'Spine', 'Hips', 'LeftArm', 'LeftForeArm', 'LeftUpLeg', 'LeftLeg', 'LeftFoot']:
    gi = body.vertex_groups.get(bone)
    if gi is None:
        continue
    zs = [body.data.vertices[v.index].co.z for v in body.data.vertices for g in v.groups if g.group == gi.index and g.weight > .5]
    if zs:
        print('GROUPZ', bone, round(min(zs), 3), round(max(zs), 3), len(zs))
# Render four views with material preview.
import math
bpy.ops.object.camera_add(location=(0, -3.5, 1.0))
cam = bpy.context.object
cam.data.type = 'ORTHO'
cam.data.ortho_scale = 2.05
bpy.context.scene.camera = cam
cam.rotation_euler = (math.radians(90), 0, 0)
bpy.ops.object.light_add(type='AREA', location=(2, -3, 3))
bpy.context.object.data.energy = 500
bpy.context.object.data.size = 4
world = bpy.context.scene.world
world.color = (.05, .05, .05)
scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.render.resolution_x = 640
scene.render.resolution_y = 800
out = root / 'logs/character_compare/blender'
out.mkdir(parents=True, exist_ok=True)
for name, loc, rot in [
    ('front', (0, -3.5, 1.0), (math.radians(90), 0, 0)),
    ('side', (3.5, 0, 1.0), (math.radians(90), 0, math.radians(90))),
    ('back', (0, 3.5, 1.0), (math.radians(90), 0, math.radians(180))),
    ('head', (0, -1.1, 1.67), (math.radians(90), 0, 0)),
]:
    cam.location = loc
    cam.rotation_euler = rot
    cam.data.ortho_scale = .55 if name == 'head' else 2.05
    scene.render.filepath = str(out / f'{name}.png')
    bpy.ops.render.render(write_still=True)
print('INSPECT DONE', flush=True)
