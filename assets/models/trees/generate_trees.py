"""Builds the low-poly frontier trees used by Xyles MMO.

Run with Blender in background mode:
  "C:/Games/Blender/blender.exe" --background --python generate_trees.py

The meshes are deliberately small: no subdivision, no modifiers, two material
slots per tree. That keeps both the Blender run and the Godot scenes light.
"""

import math
import os
import random

import bpy
from mathutils import Vector

OUT_DIR = os.path.dirname(os.path.abspath(__file__))
random.seed(4815)


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


def cone(name, base, top, radius_bottom, radius_top, verts, mat, sides=6):
    start = Vector(base)
    end = Vector(top)
    direction = end - start
    length = direction.length
    if length <= 0.001:
        return None
    bpy.ops.mesh.primitive_cone_add(
        vertices=verts,
        radius1=radius_bottom,
        radius2=radius_top,
        depth=length,
        location=(start + end) * 0.5,
    )
    obj = bpy.context.object
    obj.name = name
    obj.rotation_mode = "QUATERNION"
    obj.rotation_quaternion = direction.to_track_quat("Z", "Y")
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    assign(obj, mat)
    return obj


def ico(name, center, radius, scale, mat, subdivision=1):
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
    assign(obj, mat)
    return obj


def join(objects, name):
    if not objects:
        return None
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.object
    joined.name = name
    return joined


def build_oak():
    bark = material("Bark", (0.20, 0.14, 0.095), 0.96)
    leaves = material("Leaves", (0.19, 0.33, 0.15), 0.90)
    parts = []
    parts.append(cone("OakTrunk", (0, 0, 0), (0.15, 0.0, 4.4), 0.42, 0.20, 8, bark))
    branch_specs = [
        ((0.0, 0, 2.2), (1.6, 0.3, 4.4), 0.20, 0.05),
        ((0.0, 0, 2.8), (-1.7, 0.7, 4.8), 0.20, 0.05),
        ((0.0, 0, 3.2), (0.8, -1.5, 5.2), 0.16, 0.04),
        ((0.1, 0, 3.7), (-0.9, -0.8, 5.7), 0.13, 0.035),
        ((0.1, 0, 3.9), (0.5, 1.4, 5.9), 0.11, 0.03),
    ]
    for index, (start, end, r0, r1) in enumerate(branch_specs):
        parts.append(cone("OakBranch%d" % index, start, end, r0, r1, 5, bark))
    clumps = [
        ((0.0, 0.0, 5.6), 1.55),
        ((1.55, 0.25, 4.75), 1.25),
        ((-1.55, 0.6, 5.05), 1.30),
        ((0.75, -1.45, 5.45), 1.15),
        ((-0.75, -0.8, 6.05), 1.10),
        ((0.45, 1.45, 6.15), 1.05),
        ((-0.4, 0.1, 6.7), 0.95),
        ((1.0, 1.0, 5.6), 0.90),
    ]
    foliage = []
    for index, (center, radius) in enumerate(clumps):
        foliage.append(
            ico(
                "OakLeaves%d" % index,
                center,
                radius,
                (1.18, 0.88, 0.95),
                leaves,
                subdivision=1,
            )
        )
    return join(parts, "OakBark"), join(foliage, "OakLeaves")


def build_birch():
    bark = material("BarkPale", (0.47, 0.43, 0.34), 0.92)
    leaves = material("Leaves", (0.23, 0.36, 0.16), 0.90)
    parts = [cone("BirchTrunk", (0, 0, 0), (0.05, 0.05, 5.8), 0.25, 0.09, 7, bark)]
    branch_specs = [
        ((0.0, 0, 2.8), (1.0, 0.25, 4.5), 0.10, 0.025),
        ((0.0, 0, 3.4), (-1.0, 0.35, 5.0), 0.09, 0.022),
        ((0.0, 0, 4.0), (0.55, -0.9, 5.7), 0.08, 0.020),
        ((0.0, 0, 4.5), (-0.45, -0.55, 6.1), 0.07, 0.018),
    ]
    for index, (start, end, r0, r1) in enumerate(branch_specs):
        parts.append(cone("BirchBranch%d" % index, start, end, r0, r1, 5, bark))
    clumps = [
        ((0.0, 0.0, 6.0), 1.0),
        ((0.9, 0.25, 5.05), 0.8),
        ((-0.9, 0.3, 5.35), 0.82),
        ((0.5, -0.85, 5.85), 0.76),
        ((-0.4, -0.5, 6.35), 0.70),
        ((0.15, 0.8, 6.45), 0.68),
        ((-0.2, 0.0, 6.85), 0.55),
    ]
    foliage = []
    for index, (center, radius) in enumerate(clumps):
        foliage.append(
            ico(
                "BirchLeaves%d" % index,
                center,
                radius,
                (1.08, 0.86, 0.94),
                leaves,
                subdivision=1,
            )
        )
    return join(parts, "BirchBark"), join(foliage, "BirchLeaves")


def build_pine():
    bark = material("Bark", (0.18, 0.13, 0.09), 0.96)
    needles = material("Needles", (0.13, 0.25, 0.18), 0.92)
    parts = [cone("PineTrunk", (0, 0, 0), (0.02, 0.01, 7.4), 0.34, 0.10, 8, bark)]
    boughs = [
        ((0.0, 0.0, 2.0), 2.35, 0.72, 1.85),
        ((0.0, 0.0, 3.1), 2.05, 0.62, 1.75),
        ((0.0, 0.0, 4.15), 1.70, 0.52, 1.60),
        ((0.0, 0.0, 5.15), 1.32, 0.42, 1.45),
        ((0.0, 0.0, 6.05), 0.92, 0.32, 1.25),
        ((0.0, 0.0, 6.85), 0.52, 0.22, 0.90),
    ]
    foliage = []
    for index, (center, radius, top_radius, height) in enumerate(boughs):
        offset = Vector(
            (
                random.uniform(-0.12, 0.12),
                random.uniform(-0.12, 0.12),
                0.0,
            )
        )
        base = Vector(center) + offset
        top = base + Vector((random.uniform(-0.10, 0.10), random.uniform(-0.10, 0.10), height))
        foliage.append(
            cone(
                "PineBough%d" % index,
                base,
                top,
                radius,
                top_radius,
                8,
                needles,
            )
        )
    return join(parts, "PineBark"), join(foliage, "PineNeedles")


def build_dead():
    bark = material("BarkPale", (0.34, 0.31, 0.26), 0.98)
    parts = [cone("DeadTrunk", (0, 0, 0), (0.35, 0.1, 5.0), 0.30, 0.10, 7, bark)]
    branches = [
        ((0.1, 0, 1.8), (1.5, 0.35, 3.8), 0.11, 0.025),
        ((0.1, 0, 2.5), (-1.4, -0.25, 4.2), 0.11, 0.025),
        ((0.2, 0, 3.1), (0.8, -1.1, 4.8), 0.09, 0.02),
        ((0.2, 0, 3.8), (-0.7, 0.8, 5.5), 0.08, 0.018),
        ((0.3, 0.1, 4.4), (0.4, -0.4, 6.0), 0.06, 0.015),
        ((1.2, 0.3, 3.2), (2.0, 0.6, 3.5), 0.05, 0.012),
    ]
    for index, (start, end, r0, r1) in enumerate(branches):
        parts.append(cone("DeadBranch%d" % index, start, end, r0, r1, 5, bark))
    return join(parts, "DeadTree"), None


def export_tree(name, bark, foliage):
    clear_scene()
    # Build first so materials exist, then clear and rebuild cleanly.
    if name == "oak":
        bark, foliage = build_oak()
    elif name == "birch":
        bark, foliage = build_birch()
    elif name == "pine":
        bark, foliage = build_pine()
    else:
        bark, foliage = build_dead()
    objects = [obj for obj in (bark, foliage) if obj is not None]
    # Join foliage into the bark object so the export is one mesh with two
    # material slots. Bark must stay the active/first slot.
    if len(objects) == 2:
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = bark
        bpy.ops.object.join()
        joined = bpy.context.object
    else:
        joined = objects[0]
    joined.name = "Tree_" + name
    joined.location = (0, 0, 0)
    bpy.ops.object.select_all(action="DESELECT")
    joined.select_set(True)
    bpy.context.view_layer.objects.active = joined
    path = os.path.join(OUT_DIR, "tree_%s.glb" % name)
    bpy.ops.export_scene.gltf(
        filepath=path,
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_materials="EXPORT",
    )
    print("EXPORTED", path, "tris", sum(len(p.vertices) - 2 for p in joined.data.polygons))


def main():
    for name in ("oak", "birch", "pine", "dead"):
        export_tree(name, None, None)


if __name__ == "__main__":
    main()
