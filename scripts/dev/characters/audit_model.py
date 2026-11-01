"""Blender audit for exported race/armor GLBs; writes a repeatable quality report.
blender --background --python audit_model.py -- --input FILE.glb --output REPORT.json
--armor skips body fidelity/neck thresholds for equipment-only assets.
"""
import argparse
from collections import defaultdict
import json
from pathlib import Path
import sys
import bpy
import bmesh


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--armor', action='store_true')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(args.input))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    armatures = [obj for obj in bpy.context.scene.objects if obj.type == 'ARMATURE']
    widgets = {bone.custom_shape for arm in armatures for bone in arm.pose.bones if bone.custom_shape}
    meshes = [obj for obj in meshes if obj not in widgets]
    report = dict(input=str(args.input), vertices=sum(len(obj.data.vertices) for obj in meshes),
                  armatures=len(armatures), bones=sum(len(obj.data.bones) for obj in armatures),
                  textures=[], meshes=[], failures=[], review_required=['front and both profiles', 'neck color and tangent continuity', 'idle/walk/run/attack/sit deformation'])
    if not args.armor and not 20000 <= report['vertices'] <= 200000:
        report['failures'].append('Body vertex count outside 20,000-200,000')
    if len(armatures) != 1: report['failures'].append('Exactly one armature required')
    seen = set()
    albedo_images = set()
    for obj in meshes:
        weights_bad = 0
        seam_groups = defaultdict(list)
        for vertex in obj.data.vertices:
            weights = {obj.vertex_groups[group.group].name: group.weight for group in vertex.groups if group.weight > 1e-5}
            if abs(sum(weights.values()) - 1) > .002 or len(weights) > 4: weights_bad += 1
            seam_groups[tuple(round(value, 6) for value in vertex.co)].append(weights)
        mismatches = 0
        for copies in seam_groups.values():
            if len(copies) < 2: continue
            first = copies[0]
            for other in copies[1:]:
                if any(abs(first.get(name, 0) - other.get(name, 0)) > .002 for name in first.keys() | other.keys()): mismatches += 1
        bm = bmesh.new(); bm.from_mesh(obj.data)
        bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=.00001)
        positions = [obj.matrix_world @ vertex.co for vertex in bm.verts]
        minimum = min(point.z for point in positions); maximum = max(point.z for point in positions)
        height = maximum - minimum
        neck_bone = next((bone for arm in armatures for bone in arm.data.bones if bone.name in ['Neck', 'humanoid_ Neck']), None)
        neck_height = (armatures[0].matrix_world @ neck_bone.head_local).z if neck_bone else minimum + height * .82
        neck_edges = sum(1 for edge in bm.edges if edge.is_boundary and all(abs((obj.matrix_world @ vertex.co).z - neck_height) < height * .025 for vertex in edge.verts))
        mesh_report = dict(name=obj.name, vertices=len(obj.data.vertices), bad_weights=weights_bad,
                           seam_weight_mismatches=mismatches, neck_boundary_edges=neck_edges)
        report['meshes'].append(mesh_report)
        if weights_bad: report['failures'].append(obj.name + ': unnormalized or excessive skin weights')
        if mismatches: report['failures'].append(obj.name + ': split weights at duplicated seam vertices')
        if not args.armor and neck_edges: report['failures'].append(obj.name + ': open boundary near neck/head; inspect before acceptance')
        bm.free()
        for material in obj.data.materials:
            if material is None or not material.use_nodes: continue
            pending = [link.from_node for node in material.node_tree.nodes if node.type == 'BSDF_PRINCIPLED'
                       for link in node.inputs['Base Color'].links]
            visited = set()
            while pending:
                node = pending.pop()
                if node in visited: continue
                visited.add(node)
                if node.type == 'TEX_IMAGE' and node.image: albedo_images.add(node.image.name)
                pending.extend(link.from_node for socket in node.inputs for link in socket.links)
            for node in material.node_tree.nodes:
                if node.type == 'TEX_IMAGE' and node.image and node.image.name not in seen:
                    seen.add(node.image.name)
                    report['textures'].append(dict(name=node.image.name, width=node.image.size[0], height=node.image.size[1]))
    for texture in report['textures']: texture['albedo'] = texture['name'] in albedo_images
    if not args.armor and not any(item['width'] >= 2048 and item['albedo'] for item in report['textures']):
        report['failures'].append('No albedo atlas at least 2K; request or retain higher-fidelity textures')
    report['automatic_checks_pass'] = not report['failures']
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
    print(json.dumps(report, indent=2))
    if report['failures']: raise RuntimeError('Asset needs correction; see audit report')


if __name__ == '__main__': main()
