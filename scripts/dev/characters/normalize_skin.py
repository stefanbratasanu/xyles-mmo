"""Normalize source skin to four influences and consistent duplicated seams.
Never changes mesh positions, UVs, normals, bone rests or the original file.
blender --background --python-exit-code 1 --python normalize_skin.py -- --input RAW.glb --output CLEAN.glb
"""
import argparse
from collections import defaultdict
import json
from pathlib import Path
import sys
import bpy


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--repair-brown-ponytail', action='store_true', help='Correct a neutral white projection artifact on the Human female hair tip')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    if args.input.resolve() == args.output.resolve(): parser.error('Keep the raw source; use a different output')
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(args.input))
    arms = [obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE']
    widgets = {bone.custom_shape for arm in arms for bone in arm.pose.bones if bone.custom_shape}
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH' and obj not in widgets]
    report = []
    for obj in meshes:
        groups = defaultdict(list)
        for vertex in obj.data.vertices:
            groups[tuple(round(value, 6) for value in vertex.co)].append(vertex)
        for copies in groups.values():
            weights = defaultdict(float)
            for vertex in copies:
                for group in vertex.groups:
                    weights[group.group] += group.weight / len(copies)
            top = sorted(weights.items(), key=lambda item: item[1], reverse=True)[:4]
            total = sum(weight for _, weight in top)
            if total < .001: raise RuntimeError('Unweighted source vertex requires explicit binding')
            for vertex in copies:
                for group in list(vertex.groups): obj.vertex_groups[group.group].remove([vertex.index])
                for group, weight in top:
                    obj.vertex_groups[group].add([vertex.index], weight / total, 'REPLACE')
        report.append(dict(mesh=obj.name, vertices=len(obj.data.vertices), seams=len(groups), max_influences=4))
        if args.repair_brown_ponytail:
            material = bpy.data.materials.new('Brown ponytail tip')
            material.use_nodes = True
            shader = material.node_tree.nodes.get('Principled BSDF')
            shader.inputs['Base Color'].default_value = (.060, .026, .012, 1)
            shader.inputs['Roughness'].default_value = .84
            material_index = len(obj.data.materials)
            obj.data.materials.append(material)
            sources = {}
            for index, mat in enumerate(obj.data.materials):
                if mat is None or not mat.use_nodes: continue
                bsdf = next((node for node in mat.node_tree.nodes if node.type == 'BSDF_PRINCIPLED'), None)
                if bsdf and bsdf.inputs['Base Color'].links:
                    node = bsdf.inputs['Base Color'].links[0].from_node
                    if node.type == 'TEX_IMAGE' and node.image:
                        sources[index] = (node.image.size[:], node.image.pixels[:])
            repaired = 0
            uv = obj.data.uv_layers.active
            for face in obj.data.polygons:
                center = obj.matrix_world @ face.center
                if not (abs(center.x) < .13 and center.y > .12 and .15 < center.z < .75): continue
                source = sources.get(face.material_index)
                if source is None or uv is None: continue
                (width, height), pixels = source
                coords = sum((uv.data[index].uv for index in face.loop_indices), __import__('mathutils').Vector((0, 0))) / len(face.loop_indices)
                pixel = (int(coords.y * height) % height * width + int(coords.x * width) % width) * 4
                rgb = pixels[pixel:pixel + 3]
                if min(rgb) > .15 and max(rgb) - min(rgb) < .20:
                    face.material_index = material_index
                    repaired += 1
            report[-1]['hair_tip_faces_repaired'] = repaired
    bpy.ops.object.select_all(action='DESELECT')
    for obj in meshes + arms: obj.select_set(True)
    bpy.context.view_layer.objects.active = meshes[0]
    args.output.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(args.output), use_selection=True, export_format='GLB', export_animations=False)
    args.output.with_suffix('.weights.json').write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print('NORMALIZED SKIN', json.dumps(report))


if __name__ == '__main__': main()
