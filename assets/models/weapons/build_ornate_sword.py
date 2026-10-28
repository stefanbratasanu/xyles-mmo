"""Create a silver straight sword inspired by the supplied front reference.

Run with Blender: blender --background --python assets/models/weapons/build_ornate_sword.py
The source image is only a visual reference; no image or watermark is used as a texture.
The origin is the centre of the hand grip. Blade points up in Blender (+Z).
"""
import math
import random
from pathlib import Path
import bpy
from mathutils import Vector

HERE = Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)


def mat(name, color, metallic, roughness):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Metallic'].default_value = metallic
    bsdf.inputs['Roughness'].default_value = roughness
    return m

silver = mat('Polished silver steel', (0.61, 0.65, 0.68), 0.92, 0.23)
edge = mat('Bright blade bevel', (0.77, 0.80, 0.82), 0.95, 0.19)
recess = mat('Engraved steel recesses', (0.20, 0.22, 0.23), 0.86, 0.34)
grip = mat('Charcoal wrapped grip', (0.055, 0.058, 0.059), 0.15, 0.75)
wire = mat('Grip wire and engraving', (0.42, 0.44, 0.45), 0.85, 0.32)

# Original, procedurally generated fine brushed-steel texture. It contains no
# pixels from the supplied reference image and is embedded in the exported GLB.
rng = random.Random(19417)
image = bpy.data.images.new('BrushedSilver', width=256, height=256, alpha=True)
pixels = []
for y in range(256):
    grain = rng.uniform(-0.006, 0.006)
    for x in range(256):
        value = max(0.0, min(1.0, 0.75 + grain + rng.uniform(-0.003, 0.003)))
        pixels.extend((value * 0.96, value * 0.98, value, 1.0))
image.pixels = pixels
image.pack()
for material in (silver, edge):
    texture = material.node_tree.nodes.new('ShaderNodeTexImage')
    texture.name = 'Original brushed steel'
    texture.image = image
    material.node_tree.links.new(texture.outputs['Color'], material.node_tree.nodes.get('Principled BSDF').inputs['Base Color'])


def mesh_obj(name, vertices, faces, materials, indices=None):
    data=bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.update()
    obj=bpy.data.objects.new(name, data)
    bpy.context.collection.objects.link(obj)
    for m in materials: data.materials.append(m)
    if indices:
        for face, index in zip(data.polygons, indices): face.material_index=index
    return obj


def curve(name, coords, thickness, material):
    data=bpy.data.curves.new(name,'CURVE')
    data.dimensions='3D'
    data.resolution_u=12
    data.bevel_depth=thickness
    data.bevel_resolution=2
    spline=data.splines.new('POLY')
    spline.points.add(len(coords)-1)
    for p,co in zip(spline.points,coords): p.co=(*co,1)
    obj=bpy.data.objects.new(name,data)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    return obj


def cylinder(name, radius, depth, z, material, vertices=24):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=(0,0,z))
    o=bpy.context.object
    o.name=name
    o.data.materials.append(material)
    return o


def sphere(name, location, scale, material, segments=20, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=location)
    o=bpy.context.object
    o.name=name
    o.scale=scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(material)
    for poly in o.data.polygons: poly.use_smooth=True
    return o


# Broad double-beveled steel blade, gently tapered to a pointed tip. The two
# shallow central channels give the long reflective lines seen in the reference.
rows=[(0.09,0.031),(0.22,0.031),(0.78,0.029),(0.91,0.024),(0.98,0.009),(1.015,0.0)]
profile=[(-1,0),(-0.70,-0.006),(-0.20,-0.004),(-0.07,-0.0035),(0.07,-0.0035),(0.20,-0.004),(0.70,-0.006),(1,0),(0.70,0.006),(0.20,0.004),(0.07,0.0035),(-0.07,0.0035),(-0.20,0.004),(-0.70,0.006)]
verts=[(u*w,y,z) for z,w in rows for u,y in profile]
faces=[]; ids=[]; n=len(profile)
for i in range(len(rows)-1):
    for j in range(n):
        faces.append((i*n+j,i*n+(j+1)%n,(i+1)*n+(j+1)%n,(i+1)*n+j))
        ids.append(1 if j in (0,6,7,13) else 0)
faces.append(tuple(range(n-1,-1,-1))); ids.append(0)
mesh_obj('Double edged blade',verts,faces,[silver,edge],ids)

# Broad, gently bowed crossguard with mirrored ornamental steel plates.
outline=[(-0.17,0.105),(-0.15,0.126),(-0.07,0.139),(0,0.151),(0.07,0.139),(0.15,0.126),(0.17,0.105),(0.15,0.085),(0.065,0.089),(0,0.075),(-0.065,0.089),(-0.15,0.085)]
verts=[(x,y,z) for y in (-0.014,0.014) for x,z in outline]
n=len(outline)
faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]
faces += [(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
guard=mesh_obj('Swept silver crossguard',verts,faces,[silver])
bevel=guard.modifiers.new('Rounded forged edges','BEVEL'); bevel.width=0.005; bevel.segments=3
normal=guard.modifiers.new('Smooth guard normals','WEIGHTED_NORMAL')
for side in (-1,1):
    sphere('Guard end finial',(side*0.168,0,0.105),(0.022,0.021,0.020),silver)
    for face in (-1,1):
        y=face*0.0155
        curve('Guard border',[(side*x,y,z) for x,z in ((0.012,0.137),(0.055,0.128),(0.11,0.117),(0.151,0.116))],0.0022,wire)
        curve('Guard lower border',[(side*x,y,z) for x,z in ((0.012,0.085),(0.055,0.099),(0.11,0.100),(0.15,0.095))],0.002,recess)
        for index in range(5):
            x=0.035+index*0.021
            curve('Engraved leaf',[(side*x,y,0.103),(side*(x+0.003),y,0.109),(side*(x+0.008),y,0.115),(side*(x+0.014),y,0.121)],0.0015,recess)
            curve('Leaf vein',[(side*(x+0.003),y,0.108),(side*(x+0.008),y,0.106),(side*(x+0.012),y,0.109)],0.0010,wire)
        curve('Central engraving',[(0,y,0.083),(side*0.027,y,0.110),(0,y,0.140)],0.0025,recess)
        # Small scrolls and a second fine border give the guard relief rather
        # than a flat stripe while keeping the reference's symmetrical shape.
        for center_x in (0.055, 0.106):
            scroll=[]
            for j in range(18):
                angle=math.pi*2.4*j/17
                radius=0.011*(1.0-j/24.0)
                scroll.append((side*(center_x+radius*math.cos(angle)), y, 0.111+radius*0.62*math.sin(angle)))
            curve('Guard scroll',scroll,0.0010,wire)
        curve('Inner guard ridge',[(side*x,y,z) for x,z in ((0.03,0.127),(0.065,0.119),(0.11,0.111),(0.145,0.109))],0.0011,wire)

cylinder('Dark cord wrapped grip',0.020,0.180,-0.010,grip)
for i in range(27):
    z=-0.097+i*0.0067
    points=[(0.0205*math.cos(a),0.0205*math.sin(a),z+(a/(2*math.pi))*0.0067) for a in [2*math.pi*j/20 for j in range(21)]]
    curve('Grip wire winding',points,0.0011,wire)
for z in (-0.104,0.085): cylinder('Grip collar',0.024,0.012,z,silver)
# The round pommel has radial rays, like the flower / sunburst in the image.
sphere('Round pommel',(0,0,-0.135),(0.034,0.021,0.034),silver,32,16)
for face in (-1,1):
    for j in range(16):
        angle=2*math.pi*j/16
        coords=[(r*math.cos(angle),face*(0.021 if r<0.025 else 0.015),-0.135+r*math.sin(angle)) for r in (0.006,0.017,0.029)]
        curve('Pommel sunburst',coords,0.0014,recess)
    sphere('Pommel central stud',(0,face*0.021,-0.135),(0.006,0.003,0.006),edge,12,8)

bpy.ops.object.select_all(action='SELECT')
for obj in list(bpy.context.selected_objects):
    if obj.type=='CURVE':
        bpy.context.view_layer.objects.active=obj
        bpy.ops.object.convert(target='MESH')
bpy.ops.object.select_all(action='SELECT')
bpy.context.view_layer.objects.active = bpy.context.selected_objects[0]
bpy.ops.object.convert(target='MESH')
bpy.ops.object.join()
joined = bpy.context.object
joined.name = 'OrnateSilverSword'
bpy.context.scene.cursor.location = (0, 0, 0)
bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
bpy.ops.object.mode_set(mode='EDIT')
bpy.ops.mesh.select_all(action='SELECT')
bpy.ops.uv.smart_project(island_margin=0.01)
bpy.ops.object.mode_set(mode='OBJECT')
bpy.ops.export_scene.gltf(filepath=str(HERE/'ornate_silver_sword.glb'),export_format='GLB',use_selection=True,export_yup=True,export_materials='EXPORT')
print('EXPORTED', HERE/'ornate_silver_sword.glb')
