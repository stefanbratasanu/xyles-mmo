"""Build the original roadside cresset asset in Blender, in metres.

Run: blender --background --python assets/models/props/generate_road_cresset.py
Visual references: Auckland Museum cresset (collection object 45797) and
GameGuru medieval torch-brazier reference, thread 221453. No reference art is used.
"""
import bpy
import math
from mathutils import Vector
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets/models/props/road_cresset.glb"
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

def material(name, color, metallic=0.0, image=None):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Metallic"].default_value = metallic
    bsdf.inputs["Roughness"].default_value = 0.82
    if image:
        tex = mat.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = bpy.data.images.load(str(image), check_existing=True)
        mat.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return mat

wood = material("Weathered timber", (0.25, 0.15, 0.09), image=ROOT / "assets/textures/bark.png")
iron = material("Blackened forged iron", (0.075, 0.065, 0.055), 0.65)
char = material("Charred fuel", (0.075, 0.035, 0.02))
rope = material("Hemp rope", (0.31, 0.23, 0.14))

def cylinder(name, radius, depth, location, mat, vertices=12):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    bevel = obj.modifiers.new("Worn edges", "BEVEL")
    bevel.width = 0.012
    bevel.segments = 2
    obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    return obj

def bar(name, a, b, radius, mat):
    a, b = Vector(a), Vector(b)
    obj = cylinder(name, radius, (b-a).length, (a+b)/2, mat, 6)
    obj.rotation_euler = (b-a).to_track_quat('Z', 'Y').to_euler()
    return obj

def ring(name, radius, z, thickness):
    bpy.ops.mesh.primitive_torus_add(major_segments=16, minor_segments=6, location=(0,0,z), major_radius=radius, minor_radius=thickness)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(iron)

# Three split stakes cross at the binding and cradle a shallow iron fire bowl.
# Blender Z-up becomes Godot Y-up at export.
for i in range(3):
    angle = 2 * math.pi * i / 3 + 0.35
    c, s = math.cos(angle), math.sin(angle)
    bar("Rough timber leg", (0.72*c,0.72*s,-0.04), (-0.22*c,-0.22*s,2.55), 0.075, wood)

# Individual coils give the lashing depth and an uneven hand-wrapped silhouette.
for i in range(19):
    z = 1.52 + i * 0.018
    bpy.ops.mesh.primitive_torus_add(major_segments=18, minor_segments=6, location=(0,0,z), major_radius=0.13 + 0.004*math.sin(i), minor_radius=0.014)
    bpy.context.object.name = "Hemp lashing"
    bpy.context.object.data.materials.append(rope)

# A shallow, open bowl with a rolled rim. The charred logs are visible inside.
profile = [(0.04,2.04), (0.22,2.06), (0.38,2.14), (0.49,2.27),
           (0.46,2.27), (0.35,2.17), (0.20,2.10), (0.04,2.08)]
verts = [(r*math.cos(2*math.pi*i/24), r*math.sin(2*math.pi*i/24), z)
         for r,z in profile for i in range(24)]
faces = [(j*24+i, j*24+(i+1)%24, (j+1)*24+(i+1)%24, (j+1)*24+i)
         for j in range(len(profile)-1) for i in range(24)]
mesh = bpy.data.meshes.new("Forged bowl mesh")
mesh.from_pydata(verts, [], faces)
mesh.update()
bowl = bpy.data.objects.new("Forged fire bowl", mesh)
bpy.context.collection.objects.link(bowl)
bowl.data.materials.append(iron)
ring("Rolled bowl rim", 0.49, 2.27, 0.035)
for i in range(4):
    angle = i*math.pi/4
    bar("Burnt wood", (-0.25*math.cos(angle),-0.25*math.sin(angle),2.28+i*0.035), (0.25*math.cos(angle),0.25*math.sin(angle),2.28+i*0.035), 0.065, char)

# Join by material to keep draw calls low when many lights are streamed in.
for mat in (wood, iron, rope, char):
    objects = [o for o in bpy.context.scene.objects if o.type == "MESH" and o.data.materials and o.data.materials[0] == mat]
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        bpy.context.view_layer.objects.active = obj
        obj.select_set(True)
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
    if objects:
        bpy.context.view_layer.objects.active = objects[0]
        bpy.ops.object.join()

bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=str(OUT), export_format="GLB", export_apply=True)

# Original soft flame sprite, generated for the game's animated particle fire.
size = 128
image = bpy.data.images.new("fire_sprite", width=size, height=size, alpha=True)
pixels = []
for y in range(size):
    v = (y + 0.5) / size
    width = 0.48 * (1.0 - v) ** 0.7 + 0.015
    for x in range(size):
        u = (x + 0.5) / size - 0.5
        edge = max(0.0, 1.0 - abs(u) / width)
        fade = min(1.0, v * 9.0) * min(1.0, (1.0-v)*5.0)
        alpha = min(1.0, edge * 2.3) * fade
        pixels.extend((1.0, 0.16 + 0.65*(1.0-v), 0.025 + 0.30*(1.0-v), alpha))
image.pixels = pixels
image.filepath_raw = str(ROOT / "assets/textures/fire_sprite.png")
image.file_format = 'PNG'
image.save()
