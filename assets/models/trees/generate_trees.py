"""Builds the low-poly frontier trees used by the Xyles MMO.

Run with Blender in background mode:
  "D:/Blender/blender.exe" --background --python generate_trees.py

Design notes (why the shapes are built this way):

* **The trunk is one continuous lofted mesh.** The old version stacked four
  cones; their random jitter left visible gaps and misaligned rings in game.
  `lofted_trunk()` now samples one tapered profile along a single leaning spine
  and bridges every ring, so the trunk cannot split. Roots and limbs are extra
  geometry that grows out of that solid trunk, not replacement segments.
* The pivot is the base of the trunk and the mesh is not re-centred on the
  foliage centroid (which used to push the trunk off the placement point).
* Foliage is made of alpha cards, not ico spheres: each cluster is a pair of
  crossed quads mapped to `assets/textures/leaf_card.png` or
  `needle_card.png`. Cards are cheap, read as leaves at gameplay distance, and
  let light through. Pines use horizontal needle fronds radiating from each
  tier plus a few upright sprigs to keep the side silhouette full.
* Bark is smooth shaded; cards are single sided geometry but Godot renders the
  leaf/needle materials double sided.
* Every tree is still two material slots: surface 0 = bark, surface 1 =
  foliage. `world_builder.gd` relies on that contract.
"""

import math
import os
import random

import bmesh
import bpy
from mathutils import Matrix, Vector

OUT_DIR = os.path.dirname(os.path.abspath(__file__))
random.seed(4815)

# Height fraction -> trunk radius multiplier. Wide root flare, long clean run,
# then a quick taper into the crown so limbs emerge from solid wood.
TRUNK_PROFILE = (
    (0.000, 1.95),
    (0.018, 1.52),
    (0.050, 1.22),
    (0.100, 1.03),
    (0.200, 0.94),
    (0.320, 0.85),
    (0.460, 0.74),
    (0.600, 0.61),
    (0.740, 0.47),
    (0.860, 0.33),
    (0.940, 0.22),
    (0.985, 0.13),
    (1.000, 0.07),
)


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


def radius_factor(t):
    t = max(0.0, min(1.0, t))
    for index in range(len(TRUNK_PROFILE) - 1):
        t0, r0 = TRUNK_PROFILE[index]
        t1, r1 = TRUNK_PROFILE[index + 1]
        if t <= t1:
            span = max(t1 - t0, 1e-6)
            blend = (t - t0) / span
            return r0 + (r1 - r0) * blend
    return TRUNK_PROFILE[-1][1]


def spine_point(t, height, lean, bend):
    """Single spine shared by the trunk loft, limbs and roots."""
    curve = math.sin(t * math.pi)
    return Vector((
        lean[0] * t + bend[0] * curve,
        lean[1] * t + bend[1] * curve,
        height * t,
    ))


def lofted_trunk(name, height, radius, mat, lean=(0.0, 0.0), bend=(0.0, 0.0),
                 sides=10):
    """One sealed trunk mesh: rings bridged along a single spine.

    The seam ring is duplicated with u=2.0 so the bark texture wraps cleanly;
    caps are fans. Because the trunk is a single connected surface there is no
    ring-to-ring jitter that can open a visible crack in game.
    """
    rings = [(t, radius_factor(t)) for t, _ in TRUNK_PROFILE]
    verts = []
    uvs = []
    faces = []
    per_ring = sides + 1
    for ring_index, (t, factor) in enumerate(rings):
        center = spine_point(t, height, lean, bend)
        for side in range(per_ring):
            actual = 0 if side == sides else side
            angle = math.tau * actual / sides
            # Bark ridges: static around the trunk, softer near the crown.
            ridge = 1.0 + 0.060 * math.sin(actual * 2.4 + 0.9)
            ridge += 0.028 * math.sin(actual * 5.1 + t * 7.0)
            r = radius * factor * ridge
            z_jitter = 0.0
            if 0 < ring_index < len(rings) - 1:
                z_jitter = 0.004 * height * math.sin(actual * 3.1 + t * 11.0)
            verts.append((
                center.x + math.cos(angle) * r,
                center.y + math.sin(angle) * r,
                center.z + z_jitter,
            ))
            uvs.append((float(side) / float(sides) * 2.0, height * t / 2.2))
    for ring_index in range(len(rings) - 1):
        base = ring_index * per_ring
        nxt = (ring_index + 1) * per_ring
        for side in range(sides):
            faces.append((base + side, base + side + 1,
                          nxt + side + 1, nxt + side))
    side_faces = len(faces)
    bottom = spine_point(0.0, height, lean, bend)
    bottom_index = len(verts)
    verts.append((bottom.x, bottom.y, 0.0))
    uvs.append((0.5, 0.0))
    for side in range(sides):
        faces.append((bottom_index, side, (side + 1) % sides))
    top = spine_point(1.0, height, lean, bend)
    top_index = len(verts)
    verts.append((top.x, top.y, top.z))
    uvs.append((0.5, height / 2.2))
    top_base = (len(rings) - 1) * per_ring
    for side in range(sides):
        faces.append((top_index, top_base + side, top_base + (side + 1) % sides))

    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    uv_layer = mesh.uv_layers.new(name="UVMap")
    for loop in mesh.loops:
        uv_layer.data[loop.index].uv = uvs[loop.vertex_index]
    for index, polygon in enumerate(mesh.polygons):
        polygon.use_smooth = index < side_faces
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    assign(obj, mat)
    return obj


def add_roots(parts, name, height, radius, mat, lean, count=6):
    for index in range(count):
        angle = math.tau * float(index) / count + random.uniform(-0.18, 0.18)
        reach = radius * random.uniform(1.9, 2.6)
        start = Vector((
            math.cos(angle) * radius * 0.35,
            math.sin(angle) * radius * 0.35,
            radius * 0.62,
        ))
        end = Vector((
            math.cos(angle) * reach,
            math.sin(angle) * reach,
            radius * 0.05,
        ))
        parts.append(cone("%sRoot%d" % (name, index), start, end,
                          radius * 0.62, radius * 0.05, 5, mat, jagged=0.08))


def card_mesh(name, cards, mat):
    """Builds one mesh from quads. `cards` holds (centre, half_right, half_up).

    Each card also receives a subtle green vertex tint. Godot multiplies it into
    the leaf texture (`vertex_color_use_as_albedo`), so a canopy built from one
    atlas still has light and dark clumps instead of a flat green mass.
    """
    verts = []
    uvs = []
    faces = []
    tints = []
    for raw in cards:
        center, half_right, half_up = raw[0], raw[1], raw[2]
        rotated_uv = len(raw) > 3 and bool(raw[3])
        if half_right.length < 0.01 or half_up.length < 0.01:
            continue
        p0 = center - half_right - half_up
        p1 = center + half_right - half_up
        p2 = center + half_right + half_up
        p3 = center - half_right + half_up
        base = len(verts)
        verts.extend([p0, p1, p2, p3])
        faces.append((base, base + 1, base + 2, base + 3))
        if rotated_uv:
            # Texture u runs up the card, v across it. Used by the upright pine
            # sprigs so the branch does not lie sideways on a vertical card.
            uvs.extend([(0.0, 0.0), (0.0, 1.0), (1.0, 1.0), (1.0, 0.0)])
        else:
            uvs.extend([(0.0, 1.0), (1.0, 1.0), (1.0, 0.0), (0.0, 0.0)])
        shade = random.uniform(0.78, 1.04)
        tints.append((
            shade * random.uniform(0.95, 1.04),
            shade * random.uniform(0.98, 1.06),
            shade * random.uniform(0.88, 0.98),
            1.0,
        ))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    uv_layer = mesh.uv_layers.new(name="UVMap")
    for loop in mesh.loops:
        uv_layer.data[loop.index].uv = uvs[loop.vertex_index]
    color_layer = mesh.color_attributes.new(name="Col", type="FLOAT_COLOR", domain="CORNER")
    for loop in mesh.loops:
        color_layer.data[loop.index].color = tints[loop.index // 4]
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    assign(obj, mat)
    return obj


def crown_clusters(count, z_low, z_high, radius_low, radius_high,
                   size_low, size_high, inner=0.35):
    """Leaf-cluster centres on a hollow ellipsoid shell.

    Each entry is (centre, card size, outward direction). The outward direction
    is the local shell normal, so cards face away from the crown and do not
    disappear when the camera is level with the canopy.
    """
    clusters = []
    start = random.uniform(0.0, math.tau)
    for index in range(count):
        angle = start + (float(index) / float(count)) * math.tau
        angle += random.uniform(-0.28, 0.28)
        spread = random.uniform(radius_low, radius_high)
        if random.random() < inner:
            spread *= random.uniform(0.25, 0.60)
        center = Vector((
            math.cos(angle) * spread + random.uniform(-0.20, 0.20),
            math.sin(angle) * spread + random.uniform(-0.20, 0.20),
            random.uniform(z_low, z_high),
        ))
        outward = Vector((
            math.cos(angle) + random.uniform(-0.25, 0.25),
            math.sin(angle) + random.uniform(-0.25, 0.25),
            random.uniform(0.15, 0.55),
        )).normalized()
        clusters.append((center, random.uniform(size_low, size_high), outward))
    return clusters


def cluster_cards(clusters):
    """Four cards per cluster: two roughly horizontal, two roughly vertical.

    A pair of coplanar quads disappears when seen edge-on, which is why the
    first card pass looked wispy from the top-down camera. Every cluster now
    carries horizontal cards (read from above) and vertical cards (read from the
    side), each yawed independently.
    """
    cards = []
    for center, size, outward in clusters:
        half_w = size * 0.5 * random.uniform(0.90, 1.10)
        half_h = size * 0.5 * random.uniform(0.84, 1.04)
        # Horizontal pair: the plane faces the sky, so a top-down camera sees it.
        for blade in range(2):
            yaw = random.uniform(0.0, math.tau)
            tangent = Vector((math.cos(yaw), math.sin(yaw), 0.0))
            across = Vector((-math.sin(yaw), math.cos(yaw), 0.0))
            tilt = Vector((0.0, 0.0, random.uniform(-0.22, 0.22)))
            offset = Vector((random.uniform(-0.12, 0.12),
                             random.uniform(-0.12, 0.12),
                             random.uniform(-0.08, 0.08)))
            cards.append((
                center + offset,
                tangent * half_w + tilt * half_w,
                across * half_h,
            ))
        # Vertical pair: the plane faces out of the crown, so a side camera sees
        # the same cluster as a leaf wall rather than a line.
        flat = Vector((outward.x, outward.y, 0.0))
        if flat.length < 0.01:
            flat = Vector((1.0, 0.0, 0.0))
        flat.normalize()
        across = Vector((-flat.y, flat.x, 0.0))
        for blade in range(2):
            yaw = random.uniform(-0.55, 0.55)
            tangent = Matrix.Rotation(yaw, 4, Vector((0.0, 0.0, 1.0))) @ across
            lean = Vector((flat.x, flat.y, 0.0)) * random.uniform(-0.25, 0.25)
            cards.append((
                center,
                tangent * half_w,
                (Vector((0.0, 0.0, 1.0)) + lean) * half_h,
            ))
    return cards


def build_oak():
    bark = material("Bark", (0.20, 0.14, 0.095), 0.96)
    leaves = material("LeavesCards", (0.19, 0.33, 0.15), 0.90)
    height = 8.4
    trunk_radius = 0.34
    lean = (random.uniform(-0.55, 0.55), random.uniform(-0.55, 0.55))
    bend = (random.uniform(-0.32, 0.32), random.uniform(-0.32, 0.32))
    trunk = lofted_trunk("OakTrunk", height, trunk_radius, bark, lean, bend, sides=12)
    parts = [trunk]
    add_roots(parts, "Oak", height, trunk_radius, bark, lean, count=6)
    # Heavy limbs leave the solid trunk between 2.9 m and 6.5 m and fork once.
    # They are deliberately slim: with card foliage the old fat limbs read as
    # bare poles crossing the canopy.
    for index in range(7):
        base_z = 2.9 + index * 0.53
        t = base_z / height
        angle = math.tau * float(index) / 7.0 + random.uniform(-0.28, 0.28)
        reach = random.uniform(1.5, 2.5)
        start = spine_point(t, height, lean, bend)
        tip = start + Vector((
            math.cos(angle) * reach,
            math.sin(angle) * reach,
            random.uniform(1.2, 2.3),
        ))
        thickness = trunk_radius * radius_factor(t) * 0.36
        parts.append(cone("OakLimb%d" % index, start, tip,
                          thickness, thickness * 0.22, 5, bark))
        for fork in range(2):
            fork_angle = angle + random.uniform(-0.85, 0.85)
            fork_tip = tip + Vector((
                math.cos(fork_angle) * random.uniform(0.55, 1.15),
                math.sin(fork_angle) * random.uniform(0.55, 1.15),
                random.uniform(0.35, 1.15),
            ))
            parts.append(cone("OakTwig%d_%d" % (index, fork), tip, fork_tip,
                              max(0.035, thickness * 0.24), 0.012, 4, bark))
    # A full crown: an outer shell, a mid shell and an inner fill, plus a low
    # fringe so the underside of the canopy is not a bare umbrella.
    clumps = crown_clusters(44, 4.2, 9.5, 1.10, 2.70, 1.45, 2.10, inner=0.10)
    clumps += crown_clusters(26, 5.0, 9.2, 0.40, 1.60, 1.30, 1.85, inner=0.0)
    clumps += crown_clusters(14, 5.8, 8.8, 0.10, 0.80, 1.10, 1.55, inner=0.0)
    clumps += crown_clusters(8, 3.6, 4.5, 1.30, 2.30, 1.15, 1.65, inner=0.0)
    foliage = card_mesh("OakLeaves", cluster_cards(clumps), leaves)
    return join(parts, "OakBark"), foliage


def build_birch():
    bark = material("BarkPale", (0.47, 0.43, 0.34), 0.92)
    leaves = material("LeavesCards", (0.23, 0.36, 0.16), 0.90)
    height = 9.6
    trunk_radius = 0.16
    lean = (random.uniform(-0.70, 0.70), random.uniform(-0.70, 0.70))
    bend = (random.uniform(-0.35, 0.35), random.uniform(-0.35, 0.35))
    trunk = lofted_trunk("BirchTrunk", height, trunk_radius, bark, lean, bend, sides=10)
    parts = [trunk]
    add_roots(parts, "Birch", height, trunk_radius, bark, lean, count=5)
    for index in range(5):
        base_z = 4.0 + index * 0.78
        t = base_z / height
        angle = math.tau * float(index) / 5.0 + random.uniform(-0.3, 0.3)
        reach = random.uniform(0.8, 1.6)
        start = spine_point(t, height, lean, bend)
        tip = start + Vector((
            math.cos(angle) * reach,
            math.sin(angle) * reach,
            random.uniform(1.1, 2.0),
        ))
        thickness = trunk_radius * radius_factor(t) * 0.55
        parts.append(cone("BirchLimb%d" % index, start, tip,
                          thickness, thickness * 0.20, 5, bark))
    # An airy, loose column rather than a solid ball, but still three layers so
    # it does not read as a twig with a few leaves stuck to it.
    clumps = crown_clusters(26, 4.6, 9.8, 0.60, 1.70, 1.05, 1.55, inner=0.10)
    clumps += crown_clusters(14, 5.4, 9.4, 0.25, 1.00, 0.95, 1.40, inner=0.0)
    clumps += crown_clusters(8, 6.2, 9.0, 0.10, 0.55, 0.90, 1.25, inner=0.0)
    foliage = card_mesh("BirchLeaves", cluster_cards(clumps), leaves)
    return join(parts, "BirchBark"), foliage


def build_pine():
    bark = material("Bark", (0.18, 0.13, 0.09), 0.96)
    needles = material("NeedlesCards", (0.13, 0.25, 0.18), 0.92)
    height = 11.8
    trunk_radius = 0.27
    lean = (random.uniform(-0.30, 0.30), random.uniform(-0.30, 0.30))
    bend = (random.uniform(-0.18, 0.18), random.uniform(-0.18, 0.18))
    trunk = lofted_trunk("PineTrunk", height, trunk_radius, bark, lean, bend, sides=10)
    parts = [trunk]
    add_roots(parts, "Pine", height, trunk_radius, bark, lean, count=5)
    cards = []
    tiers = 16
    for index in range(tiers):
        t = float(index) / float(tiers - 1)
        z = 1.70 + t * 8.60
        radius = 2.35 * (1.0 - t) ** 0.82 + 0.26
        center_spine = spine_point(z / height, height, lean, bend)
        # Horizontal needle fronds radiating from the tier: these catch the
        # top-down camera angle and build the classic fir silhouette. Many short
        # fronds overlap into a solid tier instead of a few long fern leaves.
        fronds = 14
        start_angle = random.uniform(0.0, math.tau)
        for frond in range(fronds):
            angle = start_angle + math.tau * float(frond) / fronds
            angle += random.uniform(-0.12, 0.12)
            outward = Vector((math.cos(angle), math.sin(angle), 0.0))
            across = Vector((-math.sin(angle), math.cos(angle), 0.0))
            length = radius * random.uniform(0.88, 1.12)
            width = random.uniform(0.46, 0.70) * (0.78 + 0.30 * (1.0 - t))
            center = Vector((center_spine.x, center_spine.y, z))
            center += outward * (radius * random.uniform(0.18, 0.36))
            center.z += random.uniform(-0.10, 0.10)
            half_right = outward * (length * 0.5) + Vector((0.0, 0.0, -0.14 * length))
            # Horizontal copy: seen from above.
            cards.append((center, half_right, across * (width * 0.5)))
            # Vertical copy of the same branch: seen from the side. Without it a
            # horizontal frond becomes a thin ribbon when the camera is level.
            cards.append((center, half_right,
                          Vector((0.0, 0.0, width * 0.5)) + across * (width * 0.06)))
        # Upright sprigs close the vertical gaps between fronds. Their UVs are
        # rotated so the needle branch runs up the card instead of sideways.
        uprights = 4
        for upright in range(uprights):
            angle = start_angle + math.tau * float(upright) / uprights + 0.4
            outward = Vector((math.cos(angle), math.sin(angle), 0.0))
            across = Vector((-math.sin(angle), math.cos(angle), 0.0))
            center = Vector((center_spine.x, center_spine.y, z + 0.06))
            center += outward * (radius * random.uniform(0.12, 0.30))
            width = random.uniform(0.48, 0.68) * (0.82 + 0.22 * (1.0 - t))
            half_right = across * (width * 0.5)
            half_up = Vector((0.0, 0.0, random.uniform(0.38, 0.58)))
            cards.append((center, half_right, half_up, True))
    # Crown spire: crossed upright cards close the top instead of a bare pole.
    top = spine_point(1.0, height, lean, bend)
    for index in range(4):
        angle = math.tau * float(index) / 4.0 + 0.35
        outward = Vector((math.cos(angle), math.sin(angle), 0.0))
        center = top + Vector((0.0, 0.0, -0.55))
        half_right = outward * 0.48
        half_up = Vector((0.0, 0.0, 0.95))
        cards.append((center, half_right, half_up))
    foliage = card_mesh("PineNeedles", cards, needles)
    return join(parts, "PineBark"), foliage


def build_dead():
    bark = material("BarkPale", (0.34, 0.31, 0.26), 0.98)
    height = 9.2
    trunk_radius = 0.24
    lean = (random.uniform(-0.55, 0.55), random.uniform(-0.55, 0.55))
    bend = (random.uniform(-0.30, 0.30), random.uniform(-0.30, 0.30))
    trunk = lofted_trunk("DeadTrunk", height, trunk_radius, bark, lean, bend, sides=9)
    parts = [trunk]
    add_roots(parts, "Dead", height, trunk_radius, bark, lean, count=5)
    # Gnarled, crooked limbs: every segment bends, nothing is symmetrical.
    for index in range(8):
        base_z = 2.6 + index * 0.72
        t = base_z / height
        angle = math.tau * float(index) / 8.0 + random.uniform(-0.4, 0.4)
        reach = random.uniform(1.2, 2.6)
        start = spine_point(t, height, lean, bend)
        thickness = trunk_radius * radius_factor(t) * 0.48
        mid = start + Vector((
            math.cos(angle) * reach * 0.55,
            math.sin(angle) * reach * 0.55,
            random.uniform(0.4, 1.0),
        ))
        tip = mid + Vector((
            math.cos(angle + random.uniform(-0.55, 0.55)) * reach * 0.55,
            math.sin(angle + random.uniform(-0.55, 0.55)) * reach * 0.55,
            random.uniform(0.9, 2.0),
        ))
        parts.append(cone("DeadLimb%d" % index, start, mid,
                          thickness, max(0.04, thickness * 0.45), 5, bark))
        parts.append(cone("DeadTip%d" % index, mid, tip,
                          max(0.035, thickness * 0.42), 0.012, 4, bark))
    return join(parts, "DeadTree"), None


def finish_asset(name, joined):
    """Plant the trunk base at z=0 without shifting it off the placement pivot."""
    bpy.ops.object.select_all(action="DESELECT")
    joined.select_set(True)
    bpy.context.view_layer.objects.active = joined
    joined.location = (0.0, 0.0, 0.0)
    lowest = min(vert.co.z for vert in joined.data.vertices)
    for vert in joined.data.vertices:
        vert.co.z -= lowest
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
