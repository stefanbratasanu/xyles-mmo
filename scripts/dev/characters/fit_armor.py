"""Fit an authored armor GLB to a rigged race body and transfer skin weights.

blender --background --python fit_armor.py -- --body BODY.glb --armor ARMOR.glb
  --output OUTPUT.glb [--clearance .006] [--rigid-bone Spine2]
Use --template chest instead of --armor to make a fitted modeling seed.
The output is a review asset; visual acceptance is required before game use.
"""
import argparse
import json
import sys
from pathlib import Path
import bpy
import bmesh
from mathutils import Vector
from mathutils.bvhtree import BVHTree


def load(path):
    old = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    return [obj for obj in bpy.context.scene.objects if obj not in old]


def barycentric(point, a, b, c):
    ab, ac, ap = b - a, c - a, point - a
    d00, d01, d11 = ab.dot(ab), ab.dot(ac), ac.dot(ac)
    divisor = d00 * d11 - d01 * d01
    if abs(divisor) < 1e-20: return (1.0, 0.0, 0.0)
    v = (d11 * ap.dot(ab) - d01 * ap.dot(ac)) / divisor
    w = (d00 * ap.dot(ac) - d01 * ap.dot(ab)) / divisor
    values = [max(0.0, 1 - v - w), max(0.0, v), max(0.0, w)]
    total = sum(values)
    return [value / total for value in values]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--body', type=Path, required=True)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument('--armor', type=Path)
    source.add_argument('--template', choices=['chest'])
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--clearance', type=float, default=.006)
    parser.add_argument('--rigid-bone')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    if not .001 <= args.clearance <= .05: parser.error('Clearance must be .001-.05m')
    if args.output.resolve() in [p.resolve() for p in [args.body, args.armor] if p]:
        parser.error('Output must not overwrite source geometry')
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    body_objects = load(args.body)
    arm = next((obj for obj in body_objects if obj.type == 'ARMATURE'), None)
    if arm is None: raise RuntimeError('Target body has no armature')
    body = max((obj for obj in body_objects if obj.type == 'MESH'), key=lambda obj: len(obj.data.vertices))
    if args.rigid_bone and args.rigid_bone not in arm.data.bones:
        raise RuntimeError('Rigid bone is not in the target skeleton')
    body.data.calc_loop_triangles()
    vertices = [body.matrix_world @ v.co for v in body.data.vertices]
    faces = [tuple(face.vertices) for face in body.data.loop_triangles]
    bvh = BVHTree.FromPolygons(vertices, faces, all_triangles=True)
    source_weights = [{body.vertex_groups[g.group].name: g.weight for g in vertex.groups}
                      for vertex in body.data.vertices]
    if args.template:
        axial = ('Spine', 'Spine1', 'Spine2')
        mask = [sum(weight for name, weight in weights.items() if any(name.endswith(key) for key in axial)) > .72
                for weights in source_weights]
        selected = [face for face in faces if all(mask[index] for index in face)]
        used = sorted({index for face in selected for index in face})
        remap = {old: new for new, old in enumerate(used)}
        mesh = bpy.data.meshes.new('Chest modeling seed')
        mesh.from_pydata([vertices[index] for index in used], [], [tuple(remap[index] for index in face) for face in selected])
        armor = bpy.data.objects.new('ChestSeed', mesh)
        bpy.context.collection.objects.link(armor)
        material = bpy.data.materials.new('Armor preview')
        material.diffuse_color = (.14, .12, .09, 1)
        armor.data.materials.append(material)
        garments = [armor]
    else:
        armor_objects = load(args.armor)
        armor_rigs = [obj for obj in armor_objects if obj.type == 'ARMATURE']
        widgets = {bone.custom_shape for rig in armor_rigs for bone in rig.pose.bones if bone.custom_shape}
        garments = [obj for obj in armor_objects if obj.type == 'MESH' and obj not in widgets]
    if not garments: raise RuntimeError('Armor input contains no meshes')
    report = dict(body=str(args.body), output=str(args.output), meshes=[], clearance_m=args.clearance)
    for garment in garments:
        group_map = {}
        garment.vertex_groups.clear()
        pushed = 0
        distant = 0
        for vertex in garment.data.vertices:
            world = garment.matrix_world @ vertex.co
            nearest, normal, face_index, distance = bvh.find_nearest(world)
            if face_index is None: raise RuntimeError('Target surface query failed')
            if distance > .20: distant += 1
            signed = (world - nearest).dot(normal)
            if signed < args.clearance:
                world += normal * (args.clearance - signed)
                vertex.co = garment.matrix_world.inverted() @ world
                pushed += 1
            face = faces[face_index]
            blend = barycentric(nearest, *[vertices[index] for index in face])
            weights = {}
            for index, influence in zip(face, blend):
                for name, weight in source_weights[index].items():
                    weights[name] = weights.get(name, 0.0) + influence * weight
            top = [(args.rigid_bone, 1.0)] if args.rigid_bone else sorted(weights.items(), key=lambda item: item[1], reverse=True)[:4]
            total = sum(weight for _, weight in top)
            if total < .001: raise RuntimeError('Target skin has an unweighted surface point')
            for name, weight in top:
                if name not in arm.data.bones: raise RuntimeError('Skin references an absent bone: ' + name)
                group = group_map.get(name)
                if group is None:
                    group = garment.vertex_groups.new(name=name)
                    group_map[name] = group
                group.add([vertex.index], weight / total, 'REPLACE')
        if distant > len(garment.data.vertices) * .2:
            raise RuntimeError('Armor does not match this body rest pose; align or reshape it before binding')
        for modifier in list(garment.modifiers):
            if modifier.type == 'ARMATURE': garment.modifiers.remove(modifier)
        modifier = garment.modifiers.new('Race skeleton', 'ARMATURE')
        modifier.object = arm
        world_matrix = garment.matrix_world.copy()
        garment.parent = arm
        garment.matrix_world = world_matrix
        bm = bmesh.new()
        bm.from_mesh(garment.data)
        bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
        bm.to_mesh(garment.data)
        bm.free()
        report['meshes'].append(dict(name=garment.name, vertices=len(garment.data.vertices), corrected_vertices=pushed,
                                    max_influences=4, rigid_bone=args.rigid_bone))
    # glTF may include unselected children of a selected armature. Remove the
    # reference meshes from this in-memory export scene to avoid shipping a
    # duplicate body or generator helper inside every equipment piece.
    for obj in body_objects:
        if obj.type == 'MESH' and obj not in garments:
            bpy.data.objects.remove(obj, do_unlink=True)
    bpy.ops.object.select_all(action='DESELECT')
    for garment in garments: garment.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = garments[0]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(args.output), use_selection=True, export_format='GLB', export_animations=False)
    args.output.with_suffix('.report.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, indent=2))


if __name__ == '__main__': main()
