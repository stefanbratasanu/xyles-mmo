"""Builds the underbrush and stone props used by Xyles MMO.

Run with Blender in background mode:
  "D:/Blender/blender.exe" --background --python generate_props.py

Outputs go next to this script and are loaded by `world_builder.gd`:

  bush.glb      a leafy shrub, base at y=0 (one leaf-material surface)
  rock_1..3.glb boulders, base at y=0 (one stone-material surface)
  stone_1..2.glb hand-sized stones

Every asset keeps its pivot on the ground plane and a flat base clamp, so the
placement code can sit it on the terrain without the "floating pebble" or
"half-buried sphere" look the old sphere primitives had.
"""

import math
import os
import random

import bpy
from mathutils import Vector, noise

OUT_DIR = os.path.dirname(os.path.abspath(__file__))
random.seed(20261028)


def clear_scene():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for block in (bpy.data.meshes, bpy.data.materials):
        for item in list(block):
            if item.users == 0:
                block.remove(item)


def material(name, color, roughness=0.92):
    mat = bpy.data.materials.get(name)
    if mat is not None:
        return mat
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = roughness
    return mat


def assign(obj, mat):
    obj.data.materials.clear()
    obj.data.materials.append(mat)


def smooth(obj, enabled=True):
    for polygon in obj.data.polygons:
        polygon.use_smooth = enabled
    return obj


def join(objects, name):
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.object
    joined.name = name
    return joined


def ground_flat(joined, base_z=0.0):
    lowest = min(vert.co.z for vert in joined.data.vertices)
    centre_x = sum(vert.co.x for vert in joined.data.vertices) / len(joined.data.vertices)
    centre_y = sum(vert.co.y for vert in joined.data.vertices) / len(joined.data.vertices)
    for vert in joined.data.vertices:
        vert.co.z -= lowest - base_z
        vert.co.x -= centre_x
        vert.co.y -= centre_y
    return joined


def export(joined, filename):
    bpy.ops.object.select_all(action="DESELECT")
    joined.select_set(True)
    bpy.context.view_layer.objects.active = joined
    joined.location = (0.0, 0.0, 0.0)
    path = os.path.join(OUT_DIR, filename)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
    )
    tris = sum(len(poly.vertices) - 2 for poly in joined.data.polygons)
    print("EXPORTED", path, "tris", tris)


def ico(name, center, radius, scale, mat, subdivision=1, lumpy=0.08):
    bpy.ops.mesh.primitive_ico_sphere_add(
        subdivisions=subdivision, radius=radius, location=Vector(center)
    )
    obj = bpy.context.object
    obj.name = name
    obj.scale = Vector(scale)
    obj.rotation_euler = (
        random.uniform(0.0, math.tau),
        random.uniform(0.0, math.tau),
        random.uniform(0.0, math.tau),
    )
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    for vert in obj.data.vertices:
        vert.co *= random.uniform(1.0 - lumpy, 1.0 + lumpy)
    assign(obj, mat)
    return smooth(obj)


def build_bush():
    bark = material("Twig", (0.24, 0.19, 0.12), 0.96)
    leaves = material("Leaves", (0.19, 0.33, 0.15), 0.90)
    parts = []
    for index in range(5):
        angle = math.tau * float(index) / 5.0 + random.uniform(-0.3, 0.3)
        reach = random.uniform(0.25, 0.55)
        base = Vector((0.0, 0.0, 0.0))
        tip = Vector((
            math.cos(angle) * reach,
            math.sin(angle) * reach,
            random.uniform(0.30, 0.62),
        ))
        bpy.ops.mesh.primitive_cone_add(
            vertices=5,
            radius1=0.045,
            radius2=0.014,
            depth=(tip - base).length,
            location=(base + tip) * 0.5,
        )
        twig = bpy.context.object
        twig.rotation_mode = "QUATERNION"
        twig.rotation_quaternion = (tip - base).to_track_quat("Z", "Y")
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        assign(twig, bark)
        parts.append(twig)
    clumps = [
        ((0.0, 0.0, 0.62), 0.42, (1.15, 1.0, 0.78)),
        ((0.34, 0.12, 0.48), 0.30, (1.1, 0.95, 0.75)),
        ((-0.30, 0.16, 0.46), 0.31, (1.1, 0.95, 0.78)),
        ((0.08, -0.34, 0.44), 0.29, (1.0, 1.1, 0.75)),
        ((-0.10, 0.30, 0.74), 0.26, (1.0, 1.0, 0.80)),
        ((0.18, 0.02, 0.90), 0.24, (1.0, 1.0, 0.82)),
    ]
    for index, (center, radius, scale) in enumerate(clumps):
        parts.append(
            ico("BushLeaf%02d" % index, center, radius, scale, leaves,
                subdivision=1, lumpy=0.12)
        )
    # Foliage must be the strongest silhouette: join twigs first, then leaves so
    # the flat base clamp still sees the twig roots.
    joined = join(parts, "Bush")
    ground_flat(joined)
    return joined


def build_rock(name, seeds, radius, scale_x, scale_z, lumpy, material_name):
    stone = material(material_name, (0.42, 0.44, 0.40), 0.94)
    parts = []
    for index in range(seeds):
        offset = Vector((
            random.uniform(-0.45, 0.45) * radius,
            random.uniform(-0.45, 0.45) * radius,
            random.uniform(-0.1, 0.35) * radius,
        ))
        size = radius * random.uniform(0.55, 1.0)
        obj = ico("%sChunk%02d" % (name, index), offset, size,
                  (scale_x, 1.0, scale_z), stone, subdivision=2, lumpy=lumpy)
        # Break the sphere with low-frequency noise so the boulder has planes,
        # not a smooth balloon silhouette.
        for vert in obj.data.vertices:
            sample = noise.noise_vector(vert.co * 1.7 + offset) * size * 0.16
            vert.co += sample
        parts.append(obj)
    joined = join(parts, name)
    ground_flat(joined, base_z=0.0)
    # Flatten everything within 8 cm of the base: a rock that grows out of the
    # soil instead of balancing on one vertex.
    for vert in joined.data.vertices:
        if vert.co.z < 0.08:
            vert.co.z = 0.0
    return joined


clear_scene()
export(build_bush(), "bush.glb")

clear_scene()
export(build_rock("BoulderA", 3, 1.0, 1.15, 0.78, 0.10, "Stone"), "rock_1.glb")

clear_scene()
export(build_rock("BoulderB", 2, 1.0, 0.95, 0.62, 0.12, "Stone"), "rock_2.glb")

clear_scene()
export(build_rock("BoulderC", 4, 1.0, 1.25, 0.55, 0.09, "Stone"), "rock_3.glb")

clear_scene()
export(build_rock("StoneA", 1, 0.32, 1.0, 0.55, 0.14, "Stone"), "stone_1.glb")

clear_scene()
export(build_rock("StoneB", 2, 0.22, 1.1, 0.5, 0.16, "Stone"), "stone_2.glb")
