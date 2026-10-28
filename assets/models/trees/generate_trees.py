"""Builds the low-poly frontier trees used by Xyles MMO.

Run with Blender in background mode:
  "C:/Games/Blender/blender.exe" --background --python generate_trees.py

The meshes are deliberately small: no modifiers, two material slots per tree.
Bark keeps crisp facets; foliage is smooth-shaded so a crown reads as a leafy
mass instead of a pile of green rocks. That keeps both the Blender run and the
Godot scenes light.
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


def smooth(obj):
    if obj is None:
        return obj
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    return obj


def cone(name, base, top, radius_bottom, radius_top, verts, mat, smooth_shade=False):
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
    if smooth_shade:
        smooth(obj)
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
    # Smooth normals hide the polygon facets while the silhouette stays low-poly.
    return smooth(obj)


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


def crown_ring(count, z_low, z_high, spread_low, spread_high, radius_low, radius_high):
    """A jittered ring of small foliage puffs. Rings at several heights make a
    broken, natural crown silhouette without hand-placing every clump."""
    clumps = []
    start = random.uniform(0.0, math.tau)
    for index in range(count):
        angle = start + (float(index) / float(count)) * math.tau
        angle += random.uniform(-0.24, 0.24)
        spread = random.uniform(spread_low, spread_high)
        clumps.append(
            (
                (
                    math.cos(angle) * spread + random.uniform(-0.18, 0.18),
                    math.sin(angle) * spread + random.uniform(-0.18, 0.18),
                    random.uniform(z_low, z_high),
                ),
                random.uniform(radius_low, radius_high),
            )
        )
    return clumps


def build_oak():
    bark = material("Bark", (0.20, 0.14, 0.095), 0.96)
    leaves = material("Leaves", (0.19, 0.33, 0.15), 0.90)
    # 11 m mature oak: a sturdy tapered trunk, eight limbs and a crown built from
    # many small puffs. The lowest puffs stay above 6 m, so the trunk stays
    # visible and the canopy does not swallow the player.
    parts = [cone("OakTrunk", (0, 0, 0), (0.24, 0.0, 6.8), 0.56, 0.20, 9, bark)]
    branch_specs = [
        ((0.0, 0, 2.8), (2.1, 0.5, 5.9), 0.25, 0.06),
        ((0.0, 0, 3.2), (-2.2, 1.0, 6.3), 0.25, 0.06),
        ((0.0, 0, 3.7), (1.1, -2.0, 6.8), 0.21, 0.05),
        ((0.1, 0, 4.2), (-1.3, -1.1, 7.4), 0.18, 0.045),
        ((0.1, 0, 4.7), (0.8, 2.0, 7.7), 0.16, 0.04),
        ((0.1, 0, 5.2), (-0.9, 1.3, 8.2), 0.14, 0.035),
        ((0.2, 0, 5.7), (1.2, 0.4, 8.6), 0.12, 0.03),
        ((0.2, 0, 6.2), (-0.5, -0.6, 9.0), 0.10, 0.025),
    ]
    for index, (start, end, r0, r1) in enumerate(branch_specs):
        parts.append(cone("OakBranch%d" % index, start, end, r0, r1, 5, bark))
    clumps = crown_ring(9, 6.3, 7.1, 1.55, 2.15, 0.78, 0.98)
    clumps += crown_ring(8, 7.5, 8.2, 0.95, 1.55, 0.68, 0.88)
    clumps += crown_ring(6, 8.5, 9.2, 0.55, 1.15, 0.56, 0.76)
    clumps.append(((0.0, 0.0, 7.9), 0.88))
    clumps.append(((0.1, -0.1, 9.7), 0.56))
    foliage = []
    for index, (center, radius) in enumerate(clumps):
        foliage.append(
            ico(
                "OakLeaves%d" % index,
                center,
                radius,
                (1.14, 0.86, 0.94),
                leaves,
                subdivision=1,
            )
        )
    return join(parts, "OakBark"), join(foliage, "OakLeaves")


def build_birch():
    bark = material("BarkPale", (0.47, 0.43, 0.34), 0.92)
    leaves = material("Leaves", (0.23, 0.36, 0.16), 0.90)
    parts = [cone("BirchTrunk", (0, 0, 0), (0.09, 0.07, 9.2), 0.28, 0.08, 7, bark)]
    branch_specs = [
        ((0.0, 0, 3.8), (1.35, 0.32, 6.4), 0.11, 0.025),
        ((0.0, 0, 4.5), (-1.30, 0.42, 7.0), 0.10, 0.022),
        ((0.0, 0, 5.2), (0.75, -1.15, 7.8), 0.09, 0.020),
        ((0.0, 0, 5.9), (-0.60, -0.70, 8.5), 0.08, 0.018),
        ((0.0, 0, 6.6), (0.50, 0.60, 9.1), 0.07, 0.016),
        ((0.0, 0, 7.3), (-0.35, 0.35, 9.7), 0.06, 0.014),
    ]
    for index, (start, end, r0, r1) in enumerate(branch_specs):
        parts.append(cone("BirchBranch%d" % index, start, end, r0, r1, 5, bark))
    # Birch reads as a loose, airy column of small leaf clusters.
    clumps = crown_ring(8, 6.6, 7.8, 1.15, 1.65, 0.55, 0.68)
    clumps += crown_ring(7, 8.2, 9.4, 0.55, 1.15, 0.46, 0.60)
    clumps += crown_ring(4, 9.6, 10.4, 0.25, 0.70, 0.42, 0.54)
    clumps.append(((-0.05, 0.0, 8.6), 0.58))
    clumps.append(((0.05, 0.05, 10.9), 0.46))
    foliage = []
    for index, (center, radius) in enumerate(clumps):
        foliage.append(
            ico(
                "BirchLeaves%d" % index,
                center,
                radius,
                (1.06, 0.84, 0.92),
                leaves,
                subdivision=1,
            )
        )
    return join(parts, "BirchBark"), join(foliage, "BirchLeaves")


def build_pine():
    bark = material("Bark", (0.18, 0.13, 0.09), 0.96)
    needles = material("Needles", (0.13, 0.25, 0.18), 0.92)
    parts = [cone("PineTrunk", (0, 0, 0), (0.04, 0.02, 11.4), 0.40, 0.10, 8, bark)]
    boughs = [
        ((0.0, 0.0, 2.3), 2.55, 0.90, 1.95),
        ((0.0, 0.0, 3.3), 2.38, 0.82, 1.90),
        ((0.0, 0.0, 4.3), 2.16, 0.72, 1.85),
        ((0.0, 0.0, 5.3), 1.92, 0.62, 1.75),
        ((0.0, 0.0, 6.3), 1.66, 0.54, 1.65),
        ((0.0, 0.0, 7.3), 1.38, 0.46, 1.55),
        ((0.0, 0.0, 8.3), 1.10, 0.38, 1.45),
        ((0.0, 0.0, 9.2), 0.84, 0.30, 1.30),
        ((0.0, 0.0, 10.1), 0.58, 0.22, 1.05),
        ((0.0, 0.0, 10.9), 0.36, 0.14, 0.80),
    ]
    foliage = []
    for index, (center, radius, top_radius, height) in enumerate(boughs):
        offset = Vector(
            (
                random.uniform(-0.18, 0.18),
                random.uniform(-0.18, 0.18),
                0.0,
            )
        )
        base = Vector(center) + offset
        top = base + Vector((random.uniform(-0.12, 0.12), random.uniform(-0.12, 0.12), height))
        foliage.append(
            cone(
                "PineBough%d" % index,
                base,
                top,
                radius,
                top_radius,
                8,
                needles,
                smooth_shade=True,
            )
        )
    return join(parts, "PineBark"), join(foliage, "PineNeedles")


def build_dead():
    bark = material("BarkPale", (0.34, 0.31, 0.26), 0.98)
    parts = [cone("DeadTrunk", (0, 0, 0), (0.48, 0.14, 8.8), 0.36, 0.09, 7, bark)]
    branches = [
        ((0.1, 0, 2.6), (2.0, 0.50, 5.4), 0.13, 0.026),
        ((0.1, 0, 3.5), (-1.9, -0.34, 6.1), 0.12, 0.025),
        ((0.2, 0, 4.4), (1.1, -1.50, 7.0), 0.10, 0.022),
        ((0.2, 0, 5.3), (-1.0, 1.10, 7.8), 0.09, 0.020),
        ((0.3, 0.1, 6.1), (0.60, -0.60, 8.7), 0.07, 0.016),
        ((0.3, 0, 6.9), (-0.40, 0.50, 9.4), 0.06, 0.014),
        ((0.3, 0, 7.7), (0.30, 0.30, 10.1), 0.05, 0.012),
        ((1.5, 0.35, 4.4), (2.55, 0.75, 4.9), 0.05, 0.012),
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


for tree_name in ("oak", "birch", "pine", "dead"):
    export_tree(tree_name, None, None)
