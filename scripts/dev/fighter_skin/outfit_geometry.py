"""Clean closed cloth shells independent of sculpt grooves and UV seams."""
import bpy
import math
from mathutils import Vector


def loft(name, rings, material, segments=48):
    vertices = []
    for center, axis_x, axis_y, rx, ry in rings:
        for step in range(segments):
            a = step * math.tau / segments
            vertices.append(tuple(Vector(center) + Vector(axis_x) * (rx * math.cos(a))
                                  + Vector(axis_y) * (ry * math.sin(a))))
    faces = []
    for ring in range(len(rings) - 1):
        for step in range(segments):
            nxt = (step + 1) % segments
            faces.append((ring * segments + step, ring * segments + nxt,
                          (ring + 1) * segments + nxt, (ring + 1) * segments + step))
    faces.append(tuple(reversed(range(segments))))
    faces.append(tuple((len(rings) - 1) * segments + i for i in range(segments)))
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(vertices, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    for face in mesh.polygons:
        face.use_smooth = len(face.vertices) == 4
    return obj


def horizontal(name, sections, material):
    return loft(name, [((x, y, z), (1, 0, 0), (0, 1, 0), rx, ry)
                       for x, y, z, rx, ry in sections], material)


def union(parts, name, voxel=.007, smooth=5):
    bpy.ops.object.select_all(action='DESELECT')
    for part in parts:
        part.select_set(True)
    obj = parts[0]
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.join()
    remesh = obj.modifiers.new('Continuous cloth seams', 'REMESH')
    remesh.mode = 'VOXEL'
    remesh.voxel_size = voxel
    remesh.use_smooth_shade = True
    bpy.ops.object.modifier_apply(modifier=remesh.name)
    relax = obj.modifiers.new('Soft cloth', 'SMOOTH')
    relax.factor = .5
    relax.iterations = smooth
    bpy.ops.object.modifier_apply(modifier=relax.name)
    obj.name = name
    for face in obj.data.polygons:
        face.use_smooth = True
    return obj


def build(armature, materials):
    tunic = horizontal('Tunic', [(0, .025, z, rx, ry) for z, rx, ry in [
        (.055, .210, .163), (.08, .211, .164), (.18, .204, .163),
        (.30, .200, .164), (.41, .225, .182), (.49, .244, .190),
        (.55, .255, .170), (.60, .231, .145), (.645, .180, .112),
        (.675, .085, .078)]], materials['ClothTunic'])
    shirt_parts = [tunic]
    for side in ['Left', 'Right']:
        bone = armature.data.bones[side + 'Arm']
        a, b = bone.head_local, bone.tail_local
        direction = (b - a).normalized()
        side_axis = direction.cross(Vector((0, 1, 0))).normalized()
        depth_axis = direction.cross(side_axis).normalized()
        shirt_parts.append(loft(side + 'Sleeve', [
            (a.lerp(b, t), side_axis, depth_axis, radius, radius * 1.05)
            for t, radius in [(-.14, .095), (.05, .105), (.30, .100), (.60, .087), (.67, .086)]
        ], materials['ClothTunic']))
    tunic = union(shirt_parts, 'Tunic')

    pelvis = horizontal('Trousers', [(0, .025, z, rx, ry) for z, rx, ry in [
        (-.11, .125, .105), (-.04, .196, .150), (.07, .208, .170),
        (.17, .203, .167), (.21, .196, .161)]], materials['ClothTrouser'])
    pants_parts = [pelvis]
    boots, cuffs = [], []
    for side in ['Left', 'Right']:
        thigh, calf = armature.data.bones[side + 'UpLeg'], armature.data.bones[side + 'Leg']
        sections = []
        for z, rx, ry in [(-.815, .068, .077), (-.76, .073, .083),
                          (-.62, .087, .096), (-.48, .100, .107), (-.36, .095, .110),
                          (-.20, .112, .133), (-.03, .123, .149), (.12, .126, .150)]:
            a, b = (calf.tail_local, calf.head_local) if z < calf.head_local.z else (thigh.tail_local, thigh.head_local)
            center = a.lerp(b, max(0, min(1, (z - a.z) / (b.z - a.z))))
            sections.append((center.x, center.y, z, rx, ry))
        pants_parts.append(horizontal(side + 'Trouser', sections, materials['ClothTrouser']))
        foot = armature.data.bones[side + 'Foot'].head_local
        boots.append(horizontal(side + 'Boot', [(foot.x, y, z, rx, ry) for y, z, rx, ry in [
            (-.045, -.963, .083, .171), (-.045, -.944, .087, .174),
            (-.035, -.900, .085, .163), (.005, -.860, .075, .118),
            (.034, -.820, .064, .079), (.040, -.720, .072, .080),
            (.038, -.625, .078, .085)]], materials['Leather']))
        cuffs.append(horizontal(side + 'BootCuff', [(foot.x, .038, z, .084, .091)
                                                  for z in [-.659, -.652, -.622, -.615]], materials['LeatherLight']))
    trousers = union(pants_parts, 'Trousers', voxel=.008, smooth=4)
    belt = horizontal('Belt', [(0, .025, z, .216, .177) for z in [.135, .141, .185, .191]], materials['Leather'])
    return [tunic, trousers, belt] + boots + cuffs
