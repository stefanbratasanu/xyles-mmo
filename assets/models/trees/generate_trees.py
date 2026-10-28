"""Builds the low-poly frontier trees used by Xyles MMO.

Run with Blender in background mode:
  "D:/Blender/blender.exe" --background --python generate_trees.py

Design notes (why the shapes are built this way):

* The pivot is the **base of the trunk**. The previous export joined the trunk
  into a cone whose origin sat at the middle of the trunk, so every instance
  hung 3-6 m below the terrain. `finish_asset()` now moves the mesh data so
  min-z is exactly 0 and x/y are centred on the trunk.
* A tree reads as a tree from the shape hierarchy: flared base, tapered trunk,
  a few thick limbs, then *many small* foliage clumps. Few large spheres read
  as broccoli at gameplay distance, so the crown is 18-30 small puffs in a
  hollow shell, each slightly squashed and jittered.
* Bark is flat shaded and foliage smooth shaded. That contrast is what makes
  a low-poly canopy look leafy instead of faceted.
* Every mesh is two material slots (bark, foliage) so Godot can swap the
  procedurally generated bark/leaf/needle textures in `world_builder.gd`.
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


def jitter_ring(obj, amount=0.14, z_jitter=0.1):
    """Breaks the perfect circular silhouette of a cone tier."""
    for vert in obj.data.vertices:
        if vert.co.z <= 0.0:
            factor = random.uniform(1.0 - amount, 1.0 + amount)
            vert.co.x *= factor
            vert.co.y *= factor
            vert.co.z += random.uniform(-z_jitter, z_jitter)


def cone(name, base, top, radius_bottom, radius_top, verts, mat,
         smooth_shade=False, jagged=0.0):
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
    if jagged > 0.0:
        jitter_ring(obj, jagged)
    assign(obj, mat)
    if smooth_shade:
        smooth(obj)
    return obj


def ico(name, center, radius, scale, mat, subdivision=1, lumpy=0.07):
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
    if lumpy > 0.0:
        for vert in obj.data.vertices:
            vert.co *= random.uniform(1.0 - lumpy, 1.0 + lumpy)
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


def crown_shell(count, z_low, z_high, radius_low, radius_high, size_low, size_high,
                flat=0.72, inner=0.35):
    """Puffs on a hollow ellipsoid shell, plus a few inner puffs to fill gaps."""
    clumps = []
    start = random.uniform(0.0, math.tau)
    for index in range(count):
        angle = start + (float(index) / float(count)) * math.tau
        angle += random.uniform(-0.28, 0.28)
        spread = random.uniform(radius_low, radius_high)
        # Bias the ring towards the outside so the middle of the crown stays
        # open and the silhouette is broken instead of a solid ball.
        if random.random() < inner:
            spread *= random.uniform(0.25, 0.6)
        clumps.append(
            (
                (
                    math.cos(angle) * spread + random.uniform(-0.22, 0.22),
                    math.sin(angle) * spread + random.uniform(-0.22, 0.22),
                    random.uniform(z_low, z_high),
                ),
                random.uniform(size_low, size_high),
                flat,
            )
        )
    return clumps


def trunk_with_flare(name, height, radius, mat, lean=(0.0, 0.0), sides=10):
    """Stacked tapered segments plus root buttresses, so the base widens into the
    ground instead of standing on a flat disc."""
    lean_x, lean_y = lean
    parts = []
    segments = [
        (0.0, height * 0.10, radius * 1.75, radius * 0.98),
        (height * 0.10, height * 0.34, radius * 0.98, radius * 0.74),
        (height * 0.34, height * 0.66, radius * 0.74, radius * 0.48),
        (height * 0.66, height, radius * 0.48, radius * 0.11),
    ]
    for index, (z0, z1, r0, r1) in enumerate(segments):
        t = (z0 + z1) * 0.5 / max(height, 0.001)
        parts.append(
            cone(
                "%sSeg%d" % (name, index),
                (lean_x * t, lean_y * t, z0),
                (lean_x * t, lean_y * t, z1),
                r0, r1, sides, mat,
            )
        )
    roots = 5
    for index in range(roots):
        angle = math.tau * float(index) / roots + random.uniform(-0.2, 0.2)
        start = Vector((math.cos(angle) * radius * 0.5, math.sin(angle) * radius * 0.5, 0.0))
        end = Vector((
            math.cos(angle) * radius * 2.3,
            math.sin(angle) * radius * 2.3,
            radius * 0.55,
        ))
        parts.append(cone("%sRoot%d" % (name, index), start, end,
                          radius * 0.6, radius * 0.08, 5, mat, jagged=0.10))
    return parts


def build_oak():
    bark = material("Bark", (0.20, 0.14, 0.095), 0.96)
    leaves = material("Leaves", (0.19, 0.33, 0.15), 0.90)
    height = 8.4
    trunk_radius = 0.34
    lean = (random.uniform(-0.5, 0.5), random.uniform(-0.5, 0.5))
    parts = trunk_with_flare("Oak", height, trunk_radius, bark, lean, sides=11)
    # Heavy limbs leave the trunk between 3.2 m and 6.2 m and fork once each.
    for index in range(7):
        base_z = 3.2 + index * 0.48
        angle = math.tau * float(index) / 7.0 + random.uniform(-0.25, 0.25)
        reach = random.uniform(1.7, 2.7)
        tip = Vector((
            math.cos(angle) * reach + lean[0] * 0.6,
            math.sin(angle) * reach + lean[1] * 0.6,
            base_z + random.uniform(1.6, 2.6),
        ))
        start = Vector((lean[0] * 0.25, lean[1] * 0.25, base_z))
        parts.append(cone("OakLimb%d" % index, start, tip,
                          0.19, 0.045, 5, bark))
        for fork in range(2):
            fork_angle = angle + random.uniform(-0.9, 0.9)
            fork_tip = tip + Vector((
                math.cos(fork_angle) * random.uniform(0.5, 1.1),
                math.sin(fork_angle) * random.uniform(0.5, 1.1),
                random.uniform(0.4, 1.2),
            ))
            parts.append(cone("OakTwig%d_%d" % (index, fork), tip, fork_tip,
                              0.05, 0.016, 4, bark))
    clumps = crown_shell(22, 5.6, 9.6, 1.25, 2.45, 0.62, 0.98, flat=0.70)
    clumps += crown_shell(6, 7.1, 8.6, 0.25, 0.9, 0.55, 0.85, flat=0.75)
    foliage = []
    for index, (center, radius, flat) in enumerate(clumps):
        foliage.append(
            ico("OakLeaf%02d" % index, center, radius,
                (1.15, 0.95, flat), leaves, subdivision=1, lumpy=0.09)
        )
    return join(parts, "OakBark"), join(foliage, "OakLeaves")


def build_birch():
    bark = material("BarkPale", (0.47, 0.43, 0.34), 0.92)
    leaves = material("Leaves", (0.23, 0.36, 0.16), 0.90)
    height = 9.6
    trunk_radius = 0.16
    lean = (random.uniform(-0.7, 0.7), random.uniform(-0.7, 0.7))
    parts = trunk_with_flare("Birch", height, trunk_radius, bark, lean, sides=8)
    for index in range(6):
        base_z = 4.0 + index * 0.7
        angle = math.tau * float(index) / 6.0 + random.uniform(-0.3, 0.3)
        reach = random.uniform(0.9, 1.7)
        tip = Vector((
            math.cos(angle) * reach + lean[0] * 0.7,
            math.sin(angle) * reach + lean[1] * 0.7,
            base_z + random.uniform(1.2, 2.1),
        ))
        start = Vector((lean[0] * 0.45, lean[1] * 0.45, base_z))
        parts.append(cone("BirchLimb%d" % index, start, tip, 0.075, 0.02, 5, bark))
    # An airy, loose column rather than a solid ball.
    clumps = crown_shell(16, 5.4, 9.2, 0.55, 1.45, 0.42, 0.68, flat=0.82)
    clumps += crown_shell(6, 7.4, 10.3, 0.20, 0.72, 0.36, 0.58, flat=0.85)
    foliage = []
    for index, (center, radius, flat) in enumerate(clumps):
        foliage.append(
            ico("BirchLeaf%02d" % index, center, radius,
                (1.05, 0.9, flat), leaves, subdivision=1, lumpy=0.10)
        )
    return join(parts, "BirchBark"), join(foliage, "BirchLeaves")


def build_pine():
    bark = material("Bark", (0.18, 0.13, 0.09), 0.96)
    needles = material("Needles", (0.13, 0.25, 0.18), 0.92)
    height = 11.8
    parts = trunk_with_flare("Pine", height, 0.26, bark, (0.0, 0.0), sides=8)
    foliage = []
    # Tiers start low with a wide drooping skirt and shrink towards a spike.
    # Each tier is jagged and offset, so the tree never reads as stacked cones.
    tiers = 9
    for index in range(tiers):
        t = float(index) / float(tiers - 1)
        z = 2.1 + t * 8.6
        radius = 2.55 * (1.0 - t) ** 0.82 + 0.28
        height_tier = 1.55 * (1.0 - t * 0.45)
        offset = Vector((
            random.uniform(-0.22, 0.22),
            random.uniform(-0.22, 0.22),
            0.0,
        ))
        base = Vector((0.0, 0.0, z)) + offset
        top = base + Vector((random.uniform(-0.1, 0.1), random.uniform(-0.1, 0.1), height_tier))
        foliage.append(
            cone("PineBough%d" % index, base, top, radius, 0.10, 9, needles,
                 smooth_shade=True, jagged=0.17)
        )
    top = Vector((0.0, 0.0, 10.7))
    foliage.append(cone("PineSpire", top, top + Vector((0.0, 0.0, 1.35)),
                        0.34, 0.02, 7, needles, smooth_shade=True, jagged=0.12))
    return join(parts, "PineBark"), join(foliage, "PineNeedles")


def build_dead():
    bark = material("BarkPale", (0.34, 0.31, 0.26), 0.98)
    height = 9.2
    lean = (random.uniform(-0.5, 0.5), random.uniform(-0.5, 0.5))
    parts = trunk_with_flare("Dead", height, 0.24, bark, lean, sides=7)
    # Gnarled, crooked limbs: every segment bends, nothing is symmetrical.
    for index in range(8):
        base_z = 2.6 + index * 0.72
        angle = math.tau * float(index) / 8.0 + random.uniform(-0.4, 0.4)
        reach = random.uniform(1.2, 2.6)
        mid = Vector((
            math.cos(angle) * reach * 0.55,
            math.sin(angle) * reach * 0.55,
            base_z + random.uniform(0.4, 1.0),
        ))
        tip = Vector((
            math.cos(angle + random.uniform(-0.5, 0.5)) * reach,
            math.sin(angle + random.uniform(-0.5, 0.5)) * reach,
            base_z + random.uniform(1.3, 2.8),
        ))
        start = Vector((lean[0] * 0.3, lean[1] * 0.3, base_z))
        parts.append(cone("DeadLimb%d" % index, start, mid, 0.13, 0.06, 5, bark))
        parts.append(cone("DeadTip%d" % index, mid, tip, 0.06, 0.012, 4, bark))
    return join(parts, "DeadTree"), None


def finish_asset(name, joined):
    """Move the mesh so the trunk base is y=0 (glTF up) and x/z centred."""
    bpy.ops.object.select_all(action="DESELECT")
    joined.select_set(True)
    bpy.context.view_layer.objects.active = joined
    joined.location = (0.0, 0.0, 0.0)
    lowest = min(vert.co.z for vert in joined.data.vertices)
    centre_x = sum(vert.co.x for vert in joined.data.vertices) / len(joined.data.vertices)
    centre_y = sum(vert.co.y for vert in joined.data.vertices) / len(joined.data.vertices)
    for vert in joined.data.vertices:
        vert.co.z -= lowest
        vert.co.x -= centre_x
        vert.co.y -= centre_y
        # Flat base exactly on 0 so placement never shows a floating rim.
        if vert.co.z < 0.02:
            vert.co.z = 0.0
    path = os.path.join(OUT_DIR, "tree_%s.glb" % name)
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


for tree_name in ("oak", "birch", "pine", "dead"):
    clear_scene()
    if tree_name == "oak":
        bark, foliage = build_oak()
    elif tree_name == "birch":
        bark, foliage = build_birch()
    elif tree_name == "pine":
        bark, foliage = build_pine()
    else:
        bark, foliage = build_dead()
    objects = [obj for obj in (bark, foliage) if obj is not None]
    if len(objects) == 2:
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.context.view_layer.objects.active = bark
        bpy.ops.object.join()
        joined = bpy.context.object
    else:
        joined = objects[0]
    joined.name = "Tree_" + tree_name
    finish_asset(tree_name, joined)
