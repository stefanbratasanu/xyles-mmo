"""Neutral front/profile/face review of a downloaded body before paid rigging.
blender --background --python-exit-code 1 --python render_source.py -- --input FILE.glb --output DIRECTORY
"""
import argparse
import math
from pathlib import Path
import sys
import bpy
from mathutils import Vector


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--input', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--no-normals', action='store_true')
    args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:])
    args.input = args.input.resolve()
    args.output = args.output.resolve()
    args.output.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(args.input))
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH' and obj.vertex_groups]
    if not meshes: meshes = [obj for obj in bpy.context.scene.objects if obj.type == 'MESH']
    body = max(meshes, key=lambda obj: len(obj.data.vertices))
    if args.no_normals:
        for material in body.data.materials:
            if material and material.use_nodes:
                for node in material.node_tree.nodes:
                    if node.type == 'BSDF_PRINCIPLED':
                        for link in list(node.inputs['Normal'].links): material.node_tree.links.remove(link)
                        node.inputs['Roughness'].default_value = .78
                        node.inputs['Specular IOR Level'].default_value = .22
    for obj in list(bpy.context.scene.objects):
        if obj.type == 'MESH' and obj not in meshes: bpy.data.objects.remove(obj, do_unlink=True)
    points = [body.matrix_world @ Vector(point) for point in body.bound_box]
    low = min(point.z for point in points); high = max(point.z for point in points)
    height = high - low
    center = Vector((0, 0, low + height * .5))
    face_center = Vector((0, 0, high - height * .09))
    bpy.ops.object.camera_add()
    camera = bpy.context.object; camera.data.type = 'ORTHO'
    scene = bpy.context.scene; scene.camera = camera
    for name, offset, energy in [('Key', (-2, -3, 3), 350), ('Fill', (2.5, -1, 1.5), 150), ('Rim', (0, 2, 2), 150)]:
        bpy.ops.object.light_add(type='AREA', location=center + Vector(offset) * height)
        light = bpy.context.object; light.name = name; light.data.energy = energy * height * height
        light.data.shape = 'DISK'; light.data.size = height * 2
        light.rotation_euler = (center - light.location).to_track_quat('-Z', 'Y').to_euler()
    scene.world.color = (.1, .1, .1)
    scene.render.engine = 'BLENDER_EEVEE_NEXT'
    scene.render.resolution_x = 800; scene.render.resolution_y = 1000
    for name, offset, portrait in [('front', (0, -3, 0), False), ('left', (3, 0, 0), False),
                                    ('right', (-3, 0, 0), False), ('back', (0, 3, 0), False),
                                    ('face_front', (0, -3, 0), True), ('face_left', (3, 0, 0), True),
                                    ('face_right', (-3, 0, 0), True)]:
        target = face_center if portrait else center
        camera.location = target + Vector(offset) * height
        camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()
        camera.data.ortho_scale = height * (.32 if portrait else 1.12)
        scene.render.filepath = str(args.output / (name + '.png'))
        bpy.ops.render.render(write_still=True)
    print('BODY REVIEW', len(body.data.vertices), 'vertices; seven views rendered')


if __name__ == '__main__': main()
