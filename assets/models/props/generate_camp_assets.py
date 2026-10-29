"""Original Xyles camp assets. Run with Blender in background mode.

References for construction only: armstreet.com/news/medieval-vikings-canvas-tent
and sagy.vikingove.cz/en/sleep-in-the-early-middle-ages/. No reference images
or third-party artwork are included.
"""
import bpy
import math
import random
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[3]
MODELS = ROOT / "assets/models/props"
TEXTURES = ROOT / "assets/textures"
random.seed(21183)

def make_texture(name, kind):
    size = 256
    image = bpy.data.images.new(name, width=size, height=size, alpha=False)
    pixels = []
    for y in range(size):
        for x in range(size):
            n = random.uniform(-1, 1)
            if kind == "canvas":
                weave = 0.025 * math.sin(x * math.pi) + 0.025 * math.sin(y * math.pi)
                variation = 0.035 * math.sin(x * .09 + math.sin(y*.04)) + n*.035 + weave
                base = (0.69, 0.62, 0.48)
            elif kind == "wool":
                variation = n*.065 + 0.025*math.sin(x*.19) + 0.02*math.sin(y*.24)
                base = (0.34, 0.29, 0.23)
            else:
                grain = math.sin(x*.18 + 1.7*math.sin(y*.025)) + .5*math.sin(x*.47 + y*.011)
                variation = grain*.055 + n*.035 + .035*math.sin(y*.04)
                base = (0.31, 0.22, 0.14)
            pixels.extend([max(0, min(1, c + variation)) for c in base] + [1])
    image.pixels = pixels
    image.filepath_raw = str(TEXTURES / (name + ".png"))
    image.file_format = 'PNG'
    image.save()
    return image

canvas_image = make_texture("camp_canvas", "canvas")
wool_image = make_texture("camp_wool", "wool")
wood_image = make_texture("camp_timber", "wood")
bark_image = bpy.data.images.load(str(TEXTURES / "polyhaven/jolcham_oak_bark_01_diff_1k.jpg"), check_existing=True)

# End grain with imperfect growth rings, a dark heart and fine radial checks.
size = 512
end_image = bpy.data.images.new("camp_endgrain", width=size, height=size, alpha=False)
pixels = []
for y in range(size):
    for x in range(size):
        dx = (x - size*.52) / (size*.48)
        dy = (y - size*.48) / (size*.48)
        angle = math.atan2(dy, dx)
        radius = math.sqrt(dx*dx + (dy*1.03)**2)
        warped = radius + .012*math.sin(angle*5 + radius*9) + .006*math.sin(angle*11)
        rings = max(0.0, math.sin(warped*95))**14
        checks = 0.0
        for crack in (0.36, 2.3, -1.12, -2.7):
            delta = abs(math.atan2(math.sin(angle-crack), math.cos(angle-crack)))
            if delta < .012 and radius > .48:
                checks = max(checks, (1-delta/.012)*.18)
        grain = .026*math.sin(x*.15+y*.08) + random.uniform(-.025,.025)
        dark = .18*rings + checks + .05*max(0, 1-radius*5)
        pixels.extend([max(0, min(1, c + grain-dark)) for c in (.56,.41,.27)] + [1])
end_image.pixels = pixels
end_image.filepath_raw = str(TEXTURES / "camp_endgrain.png")
end_image.file_format = 'PNG'
end_image.save()

def mat(name, color, image=None):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1)
    bsdf.inputs["Roughness"].default_value = .95
    if image:
        tex = m.node_tree.nodes.new("ShaderNodeTexImage")
        tex.image = image
        m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    return m

canvas = mat("Aged canvas", (.7,.6,.45), canvas_image)
wool = mat("Wool blanket", (.3,.25,.2), wool_image)
wood = mat("Weathered wood", (.3,.2,.1), wood_image)
cut = mat("Cut end grain", (.46,.33,.20), end_image)
bark = mat("Scanned oak bark", (.25,.17,.11), bark_image)
bark_nodes = bark.node_tree.nodes
bark_bsdf = bark_nodes.get("Principled BSDF")
normal_tex = bark_nodes.new("ShaderNodeTexImage")
normal_tex.image = bpy.data.images.load(str(TEXTURES / "polyhaven/jolcham_oak_bark_01_nor_gl_1k.jpg"), check_existing=True)
normal_tex.image.colorspace_settings.name = 'Non-Color'
normal_map = bark_nodes.new("ShaderNodeNormalMap")
normal_map.inputs["Strength"].default_value = .65
bark.node_tree.links.new(normal_tex.outputs["Color"], normal_map.inputs["Color"])
bark.node_tree.links.new(normal_map.outputs["Normal"], bark_bsdf.inputs["Normal"])
char = mat("Charcoal and ash", (.07,.045,.035))
rope = mat("Hemp ties", (.4,.31,.2))

def clear():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)

def cube(name, loc, size, material, bevel=.03):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    obj.data.materials.append(material)
    if bevel:
        mod = obj.modifiers.new("Soft worn edges", 'BEVEL')
        mod.width = bevel
        mod.segments = 3
        obj.modifiers.new("Normals", 'WEIGHTED_NORMAL')
    return obj

def rod(name, a, b, radius, material, vertices=10):
    a,b = Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=(b-a).length, location=(a+b)*.5)
    obj=bpy.context.object
    obj.name=name
    obj.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler()
    obj.data.materials.append(material)
    return obj

def surface(name, verts, faces, material):
    mesh=bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    uv=mesh.uv_layers.new(name="Canvas UV")
    for poly in mesh.polygons:
        for li in poly.loop_indices:
            v=mesh.vertices[mesh.loops[li].vertex_index].co
            uv.data[li].uv=(v.y*.45+v.x*.22, v.z*.38)
    obj=bpy.data.objects.new(name,mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    material.use_backface_culling=False
    return obj

def export(filename):
    # Merge simple pieces by material to reduce draw calls at runtime.
    for material in (canvas, wool, wood, char, rope, bark):
        objects = [o for o in bpy.context.scene.objects if o.type == 'MESH' and len(o.data.materials) == 1 and o.data.materials[0] == material]
        bpy.ops.object.select_all(action='DESELECT')
        for obj in objects:
            bpy.context.view_layer.objects.active = obj
            obj.select_set(True)
            for modifier in list(obj.modifiers):
                bpy.ops.object.modifier_apply(modifier=modifier.name)
        if len(objects) > 1:
            bpy.context.view_layer.objects.active = objects[0]
            bpy.ops.object.join()
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(MODELS / filename), export_format='GLB', export_apply=True)

# Blender coordinates x width, y depth, z up; Godot front is +Z.
clear()
for side in (-1, 1):
    # Roof consists only of actual sloping sheets; no triangular front cap.
    surface("Stitched canvas roof", [(0,-2.8,2.7),(0,2.8,2.7),(side*2,-2.8,.08),(side*2,2.8,.08)], [(0,1,3,2)], canvas)
    # Broad flaps folded to either side leave a large unobstructed entrance.
    surface("Tied open flap", [(0,2.8,2.65),(side*1.9,2.8,.08),(side*2.15,2.98,.12),(side*1.05,2.97,1.35)], [(0,1,2,3)], canvas)
    rod("Entrance frame", (side*2,2.82,0), (0,2.82,2.75), .065, wood)
    rod("Flap tie", (side*1.62,2.86,.55), (side*1.82,2.90,.55), .028, rope)
    for y in (-1.9, 0, 1.9):
        rod("Canvas seam", (0,y,2.71), (side*2,y,.09), .012, rope, 6)
surface("Closed rear canvas", [(-2,-2.8,.08),(2,-2.8,.08),(0,-2.8,2.7)], [(0,1,2)], canvas)
rod("Ridge pole", (0,-3.05,2.73), (0,3.05,2.73), .075, wood)
root = bpy.data.objects.new("Tent orientation", None)
bpy.context.collection.objects.link(root)
for obj in list(bpy.context.scene.objects):
    if obj != root:
        obj.parent = root
root.rotation_euler.z = math.pi
export("camp_tent.glb")

clear()
# A low sleeping platform with planks, stuffed tick, folded wool and pillow.
for x in (-.48,.48):
    rod("Bed side rail", (x,-1.08,.12),(x,1.08,.12), .06, wood)
for y in (-1.02,1.02):
    rod("Bed cross rail", (-.5,y,.12),(.5,y,.12), .06, wood)
for y in (-.8,-.4,0,.4,.8):
    cube("Bed slat", (0,y,.15), (.9,.10,.07), wood, .01)
cube("Straw tick", (0,0,.25), (.91,1.94,.20), canvas, .09)
blanket=cube("Wool blanket", (0,.29,.37), (.92,1.27,.09), wool, .035)
for y in (-.12,.18,.48):
    rod("Blanket fold", (-.43,y,.42),(.43,y,.42), .015, wool, 6)
cube("Linen pillow", (0,-.74,.40), (.58,.34,.16), canvas, .08)
root = bpy.data.objects.new("Bed orientation", None)
bpy.context.collection.objects.link(root)
for obj in list(bpy.context.scene.objects):
    if obj != root:
        obj.parent = root
root.rotation_euler.z = math.pi
export("camp_bed.glb")

clear()
# Uneven trunk with bark ridges, a hewn upper face, and textured sawn ends.
segments=40
sections=25
verts=[]
for j in range(sections):
    x=-1.25+2.5*j/(sections-1)
    for i in range(segments):
        a=2*math.pi*i/segments
        ridge=.018*math.sin(i*5.1 + .4*math.sin(x*3)) + .012*math.sin(i*2.3+x*7)
        r=.30 + ridge + .014*math.sin(x*5+i*.5)
        z=min(.56,.28+r*math.sin(a))
        verts.append((x + .008*math.sin(i*1.7+x*2), r*math.cos(a), z))
faces=[]
for j in range(sections-1):
    for i in range(segments):
        faces.append((j*segments+i,j*segments+(i+1)%segments,(j+1)*segments+(i+1)%segments,(j+1)*segments+i))
faces += [tuple(reversed(range(segments))),tuple(range((sections-1)*segments,sections*segments))]
mesh=bpy.data.meshes.new("Rough hewn log")
mesh.from_pydata(verts,[],faces)
mesh.update()
uv=mesh.uv_layers.new(name="Log UV")
mesh.materials.append(bark)
mesh.materials.append(cut)
for poly in mesh.polygons:
    end_face = poly.index >= (sections-1)*segments
    flat_face = not end_face and all(mesh.vertices[mesh.loops[li].vertex_index].co.z >= .559 for li in poly.loop_indices)
    poly.material_index = 1 if end_face or flat_face else 0
    for li in poly.loop_indices:
        index=mesh.loops[li].vertex_index
        v=mesh.vertices[index].co
        if end_face:
            uv.data[li].uv=(.5+v.y/0.68,.5+(v.z-.28)/.68)
        elif flat_face:
            uv.data[li].uv=((v.x+1.25)/2.5,.5+v.y/.68)
        else:
            uv.data[li].uv=((index//segments)/(sections-1), (index%segments)/segments)
seat=bpy.data.objects.new("LogSeat",mesh)
bpy.context.collection.objects.link(seat)
for i in range(3):
    x=(-.82,.34,.83)[i]
    rod("Broken branch knot", (x,.23,.26),(x+.08,.32,.30), .065, bark, 10)
for x in (-.85,.85):
    cube("Wooden chock", (x,0,.08), (.34,.52,.16), wood, .025)
export("camp_log_seat.glb")

clear()
for i in range(7):
    a=i*2.38+.4
    direction=Vector((math.cos(a),math.sin(a),0))
    center=Vector((.15*math.sin(i*3),.15*math.cos(i*2),.13 + .075*(i%3)))
    half=.42 + .10*math.sin(i*1.3)
    start=center-direction*half
    end=center+direction*half
    rod("Charred irregular log", start, end, .085+.012*(i%3), char, 10)
    rod("Remaining bark", start.lerp(end,.05),start.lerp(end,.35), .095+.012*(i%3), bark, 10)
export("camp_firewood.glb")
