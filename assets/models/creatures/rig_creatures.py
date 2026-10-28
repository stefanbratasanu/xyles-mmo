"""Add a lightweight quadruped rig to the existing creature GLBs.

Run: blender --background --python assets/models/creatures/rig_creatures.py
Original meshes remain unchanged. Blender weights the fused mesh with soft
transitions at the shoulders/hips, and Godot poses the bones procedurally.
"""
from pathlib import Path
import bpy

HERE = Path(__file__).resolve().parent


def clamp(value):
    return max(0.0, min(1.0, value))


def rig(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(HERE / (name + '.glb')))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    if len(meshes) != 1:
        raise RuntimeError(f'{name}: expected one original joined mesh, got {len(meshes)}')
    mesh = meshes[0]
    bpy.ops.object.select_all(action='DESELECT')
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = mesh
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    wolf = name == 'wolf'
    scale = 0.90 if wolf else 0.95
    front_y, back_y = ((0.30, -0.29) if wolf else (0.28, -0.30))
    front_x, back_x = ((0.175, 0.19) if wolf else (0.205, 0.215))
    hip_z = 0.61 if wolf else 0.56
    armature_data = bpy.data.armatures.new(name + '_rig')
    armature = bpy.data.objects.new(name + '_rig', armature_data)
    bpy.context.collection.objects.link(armature)
    bpy.ops.object.select_all(action='DESELECT')
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode='EDIT')
    root = armature_data.edit_bones.new('body')
    root.head = (0, 0, 0)
    root.tail = (0, 0, 0.45 * scale)
    for front, y, x in ((True, front_y, front_x), (False, back_y, back_x)):
        for side, label in ((-1.0, 'left'), (1.0, 'right')):
            bone = armature_data.edit_bones.new(('front_' if front else 'hind_') + label)
            bone.head = (side * x * scale, y * scale, hip_z * scale)
            bone.tail = (side * x * scale, y * scale, 0.12 * scale)
            bone.parent = root
    head = armature_data.edit_bones.new('head')
    head.head = (0, 0.48 * scale, (0.86 if wolf else 0.72) * scale)
    head.tail = (0, 0.95 * scale, (0.94 if wolf else 0.68) * scale)
    head.parent = root
    bpy.ops.object.mode_set(mode='OBJECT')
    groups = {b.name: mesh.vertex_groups.new(name=b.name) for b in armature_data.bones}
    for vertex in mesh.data.vertices:
        # Coordinates in the original generator's unscaled Blender frame.
        x, y, z = (component / scale for component in vertex.co)
        # A gradual transition preserves the single remeshed body at each hip.
        low = clamp((0.55 - z) / 0.22) if wolf else clamp((0.48 - z) / 0.20)
        lateral = clamp((abs(x) - 0.07) / 0.07)
        longitudinal = clamp((abs(y) - 0.10) / 0.11)
        leg_weight = low * lateral * longitudinal
        head_weight = clamp((y - 0.43) / 0.22) * clamp((z - 0.28) / 0.18) * (1.0 - leg_weight)
        body_weight = 1.0 - leg_weight - head_weight
        if body_weight > 0.0001:
            groups['body'].add([vertex.index], body_weight, 'REPLACE')
        if leg_weight > 0.0001:
            leg = ('front_' if y >= 0 else 'hind_') + ('left' if x < 0 else 'right')
            groups[leg].add([vertex.index], leg_weight, 'REPLACE')
        if head_weight > 0.0001:
            groups['head'].add([vertex.index], head_weight, 'REPLACE')
    modifier = mesh.modifiers.new('CreatureRig', 'ARMATURE')
    modifier.object = armature
    mesh.parent = armature
    bpy.ops.object.select_all(action='DESELECT')
    armature.select_set(True)
    mesh.select_set(True)
    bpy.context.view_layer.objects.active = armature
    dest = HERE / (name + '_rigged.glb')
    bpy.ops.export_scene.gltf(filepath=str(dest), export_format='GLB', use_selection=True,
                              export_apply=True, export_yup=True, export_materials='EXPORT')
    print('EXPORTED RIG', dest, len(mesh.data.vertices), 'vertices', flush=True)


for species in ('wolf', 'boar'):
    rig(species)
