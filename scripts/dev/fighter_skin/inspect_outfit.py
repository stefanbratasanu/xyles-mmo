import bpy, bmesh, math
from pathlib import Path
root = Path(r"K:/GoDotProjects/xyles-mmo")
out = root / 'logs/character_compare/outfit_debug'
out.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(root / 'logs/character_compare/outfit/dressed.glb'))
body = max((o for o in bpy.context.scene.objects if o.type == 'MESH'), key=lambda o: len(o.data.vertices))
for o in list(bpy.context.scene.objects):
    if o.type == 'MESH' and o is not body:
        bpy.data.objects.remove(o, do_unlink=True)
# Split faces by material into separate objects.
materials = [m.name for m in body.data.materials]
print('MATS', materials)
for index, name in enumerate(materials):
    bm = bmesh.new(); bm.from_mesh(body.data)
    bm.faces.ensure_lookup_table()
    keep = [f for f in bm.faces if f.material_index == index]
    delete = [f for f in bm.faces if f.material_index != index]
    bmesh.ops.delete(bm, geom=delete, context='FACES')
    mesh = bpy.data.meshes.new(name)
    bm.to_mesh(mesh); bm.free()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    mat = bpy.data.materials.new('debug_' + name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (.55, .55, .55, 1)
    bsdf.inputs['Roughness'].default_value = .6
    obj.data.materials.append(mat)
    for poly in obj.data.polygons:
        poly.use_smooth = True
    obj.hide_render = name not in ('ClothTunic',)
    print(name, 'faces', len(obj.data.polygons))
# Render the tunic.
bpy.ops.object.camera_add(location=(0, -3.5, 0.0))
cam = bpy.context.object
cam.data.type = 'ORTHO'
cam.data.ortho_scale = 1.1
bpy.context.scene.camera = cam
cam.rotation_euler = (math.radians(90), 0, 0)
bpy.ops.object.light_add(type='AREA', location=(2, -3, 2))
bpy.context.object.data.energy = 400
bpy.context.object.data.size = 3
bpy.ops.object.light_add(type='AREA', location=(-2, 1, 2))
bpy.context.object.data.energy = 200
bpy.ops.object.light_add(type='SUN', location=(0, -3, 2))
bpy.context.object.data.energy = 1.5
bpy.context.scene.world.color = (.03, .03, .03)
scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.render.resolution_x = 600
scene.render.resolution_y = 600
for label, loc, rot in [
    ('tunic_front', (0, -3.5, 0.45), (math.radians(90), 0, 0)),
    ('tunic_side', (3.5, 0, 0.45), (math.radians(90), 0, math.radians(90))),
    ('tunic_back', (0, 3.5, 0.45), (math.radians(90), 0, math.radians(180))),
]:
    cam.location = loc
    cam.rotation_euler = rot
    scene.render.filepath = str(out / f'{label}.png')
    bpy.ops.render.render(write_still=True)
print('DEBUG DONE')
