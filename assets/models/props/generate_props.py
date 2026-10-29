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
from mathutils import Matrix, Vector, noise

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


def card_mesh(name, cards, mat):
    """Builds the bush foliage as alpha-card quads with UVs and a leaf tint.

    The runtime swaps this surface for `leaves_card`, so the cards must carry a
    0..1 UV square and a per-card vertex colour just like the tree canopies.
    """
    verts = []
    uvs = []
    faces = []
    tints = []
    for center, half_right, half_up in cards:
        if half_right.length < 0.01 or half_up.length < 0.01:
            continue
        p0 = center - half_right - half_up
        p1 = center + half_right - half_up
        p2 = center + half_right + half_up
        p3 = center - half_right + half_up
        base = len(verts)
        verts.extend([p0, p1, p2, p3])
        faces.append((base, base + 1, base + 2, base + 3))
        uvs.extend([(0.0, 1.0), (1.0, 1.0), (1.0, 0.0), (0.0, 0.0)])
        shade = random.uniform(0.80, 1.04)
        tints.append((
            shade * random.uniform(0.94, 1.04),
            shade * random.uniform(0.98, 1.06),
            shade * random.uniform(0.86, 0.98),
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


def bush_cards(clusters):
    """Three cards per cluster: two horizontal and two vertical, randomly yawed."""
    cards = []
    for center, size, outward in clusters:
        half_w = size * 0.5 * random.uniform(0.92, 1.10)
        half_h = size * 0.5 * random.uniform(0.86, 1.06)
        for blade in range(2):
            yaw = random.uniform(0.0, math.tau)
            tangent = Vector((math.cos(yaw), math.sin(yaw), 0.0))
            across = Vector((-math.sin(yaw), math.cos(yaw), 0.0))
            tilt = Vector((0.0, 0.0, random.uniform(-0.18, 0.18)))
            offset = Vector((random.uniform(-0.05, 0.05),
                             random.uniform(-0.05, 0.05),
                             random.uniform(-0.04, 0.04)))
            cards.append((center + offset,
                          tangent * half_w + tilt * half_w,
                          across * half_h))
        flat = Vector((outward.x, outward.y, 0.0))
        if flat.length < 0.01:
            flat = Vector((1.0, 0.0, 0.0))
        flat.normalize()
        across = Vector((-flat.y, flat.x, 0.0))
        for blade in range(2):
            yaw = random.uniform(-0.55, 0.55)
            tangent = Matrix.Rotation(yaw, 4, Vector((0.0, 0.0, 1.0))) @ across
            lean = Vector((flat.x, flat.y, 0.0)) * random.uniform(-0.22, 0.22)
            cards.append((center,
                          tangent * half_w,
                          (Vector((0.0, 0.0, 1.0)) + lean) * half_h))
    return cards


def build_bush():
    bark = material("Twig", (0.24, 0.19, 0.12), 0.96)
    leaves = material("BushLeafCards", (0.20, 0.36, 0.16), 0.90)
    twigs = []
    for index in range(6):
        angle = math.tau * float(index) / 6.0 + random.uniform(-0.3, 0.3)
        reach = random.uniform(0.24, 0.48)
        base = Vector((0.0, 0.0, 0.0))
        tip = Vector((
            math.cos(angle) * reach,
            math.sin(angle) * reach,
            random.uniform(0.28, 0.58),
        ))
        bpy.ops.mesh.primitive_cone_add(
            vertices=5,
            radius1=0.045,
            radius2=0.012,
            depth=(tip - base).length,
            location=(base + tip) * 0.5,
        )
        twig = bpy.context.object
        twig.rotation_mode = "QUATERNION"
        twig.rotation_quaternion = (tip - base).to_track_quat("Z", "Y")
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
        assign(twig, bark)
        twigs.append(twig)
    bark_obj = join(twigs, "BushTwigs")
    # Seven overlapping leaf clusters, including two low ones that hide the root
    # so the shrub is foliage all the way down instead of a ball on sticks.
    clusters = [
        (Vector((0.00, 0.00, 0.62)), 0.66, Vector((0.0, 0.0, 1.0))),
        (Vector((0.30, 0.10, 0.52)), 0.54, Vector((0.8, 0.2, 0.4))),
        (Vector((-0.28, 0.13, 0.50)), 0.55, Vector((-0.8, 0.2, 0.4))),
        (Vector((0.06, -0.30, 0.46)), 0.50, Vector((0.1, -0.9, 0.4))),
        (Vector((-0.05, 0.28, 0.56)), 0.48, Vector((-0.1, 0.9, 0.4))),
        (Vector((0.18, -0.02, 0.82)), 0.46, Vector((0.5, 0.0, 0.8))),
        (Vector((-0.17, -0.10, 0.78)), 0.44, Vector((-0.5, -0.2, 0.8))),
        (Vector((0.27, -0.26, 0.34)), 0.50, Vector((0.7, -0.7, 0.2))),
        (Vector((-0.29, -0.24, 0.34)), 0.51, Vector((-0.7, -0.7, 0.2))),
        (Vector((0.32, 0.23, 0.37)), 0.48, Vector((0.7, 0.6, 0.2))),
        (Vector((-0.30, 0.25, 0.37)), 0.49, Vector((-0.7, 0.6, 0.2))),
        (Vector((0.00, 0.00, 0.34)), 0.57, Vector((0.0, 0.0, 1.0))),
        (Vector((0.00, -0.16, 0.67)), 0.48, Vector((0.0, -0.6, 0.6))),
        (Vector((0.24, 0.00, 0.22)), 0.48, Vector((0.8, 0.0, 0.2))),
        (Vector((-0.24, 0.00, 0.22)), 0.48, Vector((-0.8, 0.0, 0.2))),
        (Vector((0.00, 0.24, 0.22)), 0.48, Vector((0.0, 0.8, 0.2))),
        (Vector((0.00, -0.24, 0.22)), 0.48, Vector((0.0, -0.8, 0.2))),
    ]
    foliage = card_mesh("BushLeaves", bush_cards(clusters), leaves)
    # Join with the twigs active so surface 0 stays bark and surface 1 stays
    # foliage, matching the tree contract used by world_builder.gd.
    bpy.ops.object.select_all(action="DESELECT")
    for obj in (bark_obj, foliage):
        obj.select_set(True)
    bpy.context.view_layer.objects.active = bark_obj
    bpy.ops.object.join()
    joined = bpy.context.object
    joined.name = "Bush"
    ground_flat(joined)
    return joined


def build_rock(name, seeds, radius, scale_x, scale_z, lumpy, material_name):
    stone = material(material_name, (0.42, 0.44, 0.40), 0.94)
    # Keep the shared CC0 maps on the Blender material as well as in Godot, so
    # the exported GLBs remain textured when an artist opens them independently.
    tex_dir = os.path.join(os.path.dirname(os.path.dirname(OUT_DIR)), "textures", "polyhaven")
    nodes = stone.node_tree.nodes
    links = stone.node_tree.links
    bsdf = nodes.get("Principled BSDF")
    color = nodes.new("ShaderNodeTexImage")
    color.image = bpy.data.images.load(os.path.join(tex_dir, "rock_face_03-Diffuse.jpg"), check_existing=True)
    links.new(color.outputs["Color"], bsdf.inputs["Base Color"])
    normal_texture = nodes.new("ShaderNodeTexImage")
    normal_texture.image = bpy.data.images.load(os.path.join(tex_dir, "rock_face_03-nor_gl.jpg"), check_existing=True)
    normal_texture.image.colorspace_settings.name = "Non-Color"
    normal = nodes.new("ShaderNodeNormalMap")
    normal.inputs["Strength"].default_value = 0.65
    links.new(normal_texture.outputs["Color"], normal.inputs["Color"])
    links.new(normal.outputs["Normal"], bsdf.inputs["Normal"])
    parts = []
    for index in range(seeds):
        offset = Vector((
            random.uniform(-0.45, 0.45) * radius,
            random.uniform(-0.45, 0.45) * radius,
            random.uniform(-0.1, 0.35) * radius,
        ))
        size = radius * random.uniform(0.55, 1.0)
        obj = ico("%sChunk%02d" % (name, index), offset, size,
                  (scale_x, 1.0, scale_z), stone, subdivision=3 if radius >= 0.9 else 2, lumpy=lumpy)
        # Break the sphere with low-frequency noise so the boulder has planes,
        # not a smooth balloon silhouette.
        for vert in obj.data.vertices:
            sample = noise.noise_vector(vert.co * 1.7 + offset) * size * 0.16
            vert.co += sample
            # Chipped, weathered planes break the original round silhouette;
            # finer cracks and mineral grain come from the shared rock texture.
            vert.co.z = min(vert.co.z, size * random.uniform(0.68, 0.74))
            vert.co.x = max(vert.co.x, -size * scale_x * 0.83)
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
