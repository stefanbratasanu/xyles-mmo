"""Dress the human fighter: short hair, tunic, trousers, boots and belt.

Reads the clean head-revision build and adds skin-weighted garments that
follow every physique blend shape. Never reads its installed, dressed output.

Run with: blender --background --python scripts/dev/fighter_skin/build_outfit.py
"""
import bpy, bmesh, math, sys, argparse, json, struct
import numpy as np
from pathlib import Path
from mathutils import Vector
from mathutils.kdtree import KDTree

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "logs/character_compare/outfit"
OUT.mkdir(parents=True, exist_ok=True)
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parent))
from outfit_geometry import build as build_clothes
parser = argparse.ArgumentParser()
parser.add_argument('--source', type=Path, default=ROOT / 'logs/face_rebuild/head_swap.glb')
args = parser.parse_args(sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else [])
if not args.source.is_file():
    raise RuntimeError('Build the clean head source first or supply --source PATH.')

bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(args.source))
body = max((o for o in bpy.context.scene.objects if o.type == 'MESH'), key=lambda o: len(o.data.vertices))
arm = next(o for o in bpy.context.scene.objects if o.type == 'ARMATURE')
if len(body.data.materials) != 2:
    raise RuntimeError('Outfit input must contain only the two skin surfaces, not an already dressed character.')
for o in list(bpy.context.scene.objects):
    if o.type == 'MESH' and o is not body:
        bpy.data.objects.remove(o, do_unlink=True)

source = body.data
basis = np.array([v.co[:] for v in source.vertices], dtype=np.float64)
shape_names = [k.name for k in source.shape_keys.key_blocks] if source.shape_keys else []
shape_delta = {}
for name in shape_names[1:]:
    key = source.shape_keys.key_blocks[name]
    shape_delta[name] = np.array([v.co[:] for v in key.data], dtype=np.float64) - basis

group_name = {g.index: g.name for g in body.vertex_groups}
orig_weights = {}
for v in source.vertices:
    orig_weights[v.index] = {group_name[g.group]: g.weight for g in v.groups}
kd = KDTree(len(source.vertices))
for v in source.vertices:
    kd.insert(v.co, v.index)
kd.balance()

# Weld the UV-split surface into a continuous garment base. The source mesh has
# duplicated vertices along UV seams; duplicating selected faces on the raw mesh
# leaves cracks along every seam.
bm = bmesh.new()
bm.from_mesh(source)
bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-5)
bm.verts.ensure_lookup_table()
bm.faces.ensure_lookup_table()
bm.normal_update()
coords = np.array([v.co[:] for v in bm.verts], dtype=np.float64)
normals = np.array([v.normal[:] for v in bm.verts], dtype=np.float64)
faces = [tuple(v.index for v in f.verts) for f in bm.faces]
adjacency = [[] for _ in bm.verts]
for e in bm.edges:
    a, b = e.verts[0].index, e.verts[1].index
    adjacency[a].append(b)
    adjacency[b].append(a)
source_index = []
for c in coords:
    _, index, _ = kd.find(Vector(c))
    source_index.append(index)
source_index = np.array(source_index, dtype=np.int64)
kd_weld = KDTree(len(coords))
for i, c in enumerate(coords):
    kd_weld.insert(Vector(c), i)
kd_weld.balance()

weight_cache = {}
def welded_weights(i):
    key = int(source_index[i])
    if key not in weight_cache:
        weight_cache[key] = orig_weights[key]
    return weight_cache[key]


def wsum(i, names):
    w = welded_weights(i)
    return sum(w.get(n, 0.0) for n in names)


# Build a low-frequency cloth proxy from the dense sculpt. Taubin smoothing on
# the whole body removes the carved abs, sternum groove and knee knobs while
# keeping the torso and limb volume; the garments drape over this proxy.
edge_a = np.array([e.verts[0].index for e in bm.edges], dtype=np.int64)
edge_b = np.array([e.verts[1].index for e in bm.edges], dtype=np.int64)
count = np.bincount(edge_a, minlength=len(coords)) + np.bincount(edge_b, minlength=len(coords))
count = np.maximum(count, 1)
hand_groups = ('LeftHand', 'RightHand', 'LeftHandThumb1', 'LeftHandThumb2', 'LeftHandThumb3',
               'LeftHandIndex1', 'LeftHandIndex2', 'LeftHandIndex3', 'LeftHandMiddle1',
               'LeftHandMiddle2', 'LeftHandMiddle3', 'LeftHandRing1', 'LeftHandRing2',
               'LeftHandRing3', 'LeftHandPinky1', 'LeftHandPinky2', 'LeftHandPinky3',
               'RightHandThumb1', 'RightHandThumb2', 'RightHandThumb3', 'RightHandIndex1',
               'RightHandIndex2', 'RightHandIndex3', 'RightHandMiddle1', 'RightHandMiddle2',
               'RightHandMiddle3', 'RightHandRing1', 'RightHandRing2', 'RightHandRing3',
               'RightHandPinky1', 'RightHandPinky2', 'RightHandPinky3')
body_mask = np.array([coords[i][2] < 0.665 and wsum(i, hand_groups) < 0.08
                      for i in range(len(coords))], dtype=bool)


def neighbour_mean(values):
    out = np.empty_like(values)
    for axis in range(3):
        total = (np.bincount(edge_a, weights=values[edge_b, axis], minlength=len(coords))
                 + np.bincount(edge_b, weights=values[edge_a, axis], minlength=len(coords)))
        out[:, axis] = total / count
    return out


proxy = coords.copy()
for _ in range(80):
    mean = neighbour_mean(proxy)
    proxy[body_mask] += 0.55 * (mean[body_mask] - proxy[body_mask])
    mean = neighbour_mean(proxy)
    proxy[body_mask] -= 0.53 * (mean[body_mask] - proxy[body_mask])
proxy_normals = np.zeros_like(proxy)
for face in faces:
    a, b, c = face
    normal = np.cross(proxy[b] - proxy[a], proxy[c] - proxy[a])
    proxy_normals[a] += normal
    proxy_normals[b] += normal
    proxy_normals[c] += normal
length = np.linalg.norm(proxy_normals, axis=1)
length[length < 1e-12] = 1.0
proxy_normals /= length[:, None]
kd_proxy = KDTree(len(proxy))
for i, c in enumerate(proxy):
    kd_proxy.insert(Vector(c), i)
kd_proxy.balance()
print('CLOTH PROXY READY', int(np.sum(body_mask)), flush=True)


def taubin(points, used, boundary, iterations):
    """Smooth in place while retaining cross-section volume."""
    index = {v: i for i, v in enumerate(used)}
    points = points.copy()
    for _ in range(iterations):
        previous = points.copy()
        for v in used:
            if v in boundary:
                continue
            nb = [n for n in adjacency[v] if n in index]
            if not nb:
                continue
            mean = np.mean([previous[index[n]] for n in nb], axis=0)
            points[index[v]] = previous[index[v]] + 0.55 * (mean - previous[index[v]])
        previous = points.copy()
        for v in used:
            if v in boundary:
                continue
            nb = [n for n in adjacency[v] if n in index]
            if not nb:
                continue
            mean = np.mean([previous[index[n]] for n in nb], axis=0)
            points[index[v]] = previous[index[v]] - 0.53 * (mean - previous[index[v]])
    return points


def smooth_boundaries(obj, line=None):
    """Relax every open hem into a clean curve instead of a triangle staircase."""
    mesh = obj.data
    counts = {}
    for poly in mesh.polygons:
        verts = [mesh.loops[i].vertex_index for i in poly.loop_indices]
        for i, a in enumerate(verts):
            b = verts[(i + 1) % len(verts)]
            key = (min(a, b), max(a, b))
            counts[key] = counts.get(key, 0) + 1
    boundary_edges = [e for e, count in counts.items() if count == 1]
    edges = {}
    for a, b in boundary_edges:
        edges.setdefault(a, []).append(b)
        edges.setdefault(b, []).append(a)
    loops = []
    seen = set()
    for start in edges:
        if start in seen:
            continue
        loop = []
        previous = None
        current = start
        while current not in seen:
            seen.add(current)
            loop.append(current)
            nxt = [n for n in edges[current] if n != previous]
            if not nxt:
                break
            previous, current = current, nxt[0]
        if len(loop) > 3:
            loops.append(loop)
    for loop in loops:
        n = len(loop)
        for _ in range(18):
            values = [mesh.vertices[i].co.copy() for i in loop]
            for i, vertex in enumerate(loop):
                mean = values[(i - 1) % n] * 0.25 + values[i] * 0.5 + values[(i + 1) % n] * 0.25
                mesh.vertices[vertex].co = mean
        if line is not None:
            for vertex in loop:
                co = mesh.vertices[vertex].co
                co.z = line(co.x, co.y)
                mesh.vertices[vertex].co = co
    print('BOUNDARIES', obj.name, [len(loop) for loop in loops], flush=True)
    mesh.update()


def recalc_normals(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.normal_update()
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


def relax_mesh(obj, iterations=8):
    """Remove folds introduced by decimation while keeping every hem pinned."""
    mesh = obj.data
    adjacency = [[] for _ in mesh.vertices]
    for edge in mesh.edges:
        a, b = edge.vertices
        adjacency[a].append(b)
        adjacency[b].append(a)
    edge_use = {}
    for poly in mesh.polygons:
        verts = [mesh.loops[i].vertex_index for i in poly.loop_indices]
        for i, a in enumerate(verts):
            b = verts[(i + 1) % len(verts)]
            key = (min(a, b), max(a, b))
            edge_use[key] = edge_use.get(key, 0) + 1
    boundary = {v for key, use in edge_use.items() if use == 1 for v in key}
    interior = [i for i in range(len(mesh.vertices)) if i not in boundary]
    points = np.array([v.co[:] for v in mesh.vertices], dtype=np.float64)
    for _ in range(iterations):
        previous = points.copy()
        for i in interior:
            if not adjacency[i]:
                continue
            points[i] = previous[i] + 0.5 * (np.mean(previous[adjacency[i]], axis=0) - previous[i])
        previous = points.copy()
        for i in interior:
            if not adjacency[i]:
                continue
            points[i] = previous[i] - 0.48 * (np.mean(previous[adjacency[i]], axis=0) - previous[i])
    mesh.vertices.foreach_set('co', points.astype(np.float32).ravel())
    mesh.update()
    recalc_normals(obj)


def resolve_penetration(obj, minimum):
    for v in obj.data.vertices:
        _, src, _ = kd_weld.find(v.co)
        normal = Vector(normals[src])
        depth = (v.co - Vector(coords[src])).dot(normal)
        if depth < minimum:
            v.co += normal * (minimum - depth)


def new_material(name, color, roughness=0.9, metallic=0.0):
    mat = bpy.data.materials.new(name)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1.0)
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metallic
    return mat


MATERIALS = {
    'ClothTunic': new_material('ClothTunic', (0.045, 0.058, 0.027), 0.96),
    'ClothTrouser': new_material('ClothTrouser', (0.052, 0.042, 0.030), 0.97),
    'Leather': new_material('Leather', (0.030, 0.017, 0.010), 0.70),
    'LeatherLight': new_material('LeatherLight', (0.062, 0.034, 0.016), 0.74),
    'Brass': new_material('Brass', (0.34, 0.22, 0.08), 0.36, 0.85),
    'Hair': new_material('Hair', (0.026, 0.014, 0.007), 0.68),
}

bpy.ops.object.select_all(action='DESELECT')
objects = []

def make_garment(name, mask, offset, material, bias=(0, 0, 0), smooth=8, solidify=0.0,
                 variable=None, line=None, smooth_boundary=True, use_proxy=False, decimate=0.0):
    selected = np.array([mask(i) for i in range(len(coords))], dtype=bool)
    garment_faces = [f for f in faces if all(selected[i] for i in f)]
    used = sorted({i for f in garment_faces for i in f})
    if not used:
        return None
    remap = {old: new for new, old in enumerate(used)}
    base = np.zeros((len(used), 3), dtype=np.float64)
    base_normals = np.zeros((len(used), 3), dtype=np.float64)
    for n, i in enumerate(used):
        if use_proxy:
            base[n] = proxy[i]
            base_normals[n] = proxy_normals[i]
        else:
            base[n] = coords[i]
            base_normals[n] = normals[i]
    points = np.array([base[n] + base_normals[n] * offset + np.array(bias) for n in range(len(used))])
    if variable is not None:
        for n, i in enumerate(used):
            points[n] += base_normals[n] * variable(coords[i])
    index = {v: i for i, v in enumerate(used)}
    boundary = {v for v in used if any(n not in index for n in adjacency[v])}
    points = taubin(points, used, boundary, smooth)
    # Push the relaxed cloth back outside the body.
    if not use_proxy:
        for n, i in enumerate(used):
            depth = np.dot(points[n] - coords[i], normals[i])
            minimum = max(0.012, offset * 0.6)
            if depth < minimum:
                points[n] += normals[i] * (minimum - depth)
    polys = [tuple(remap[i] for i in f) for f in garment_faces]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([tuple(p) for p in points], [], polys)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.data.materials.append(material)
    for poly in mesh.polygons:
        poly.use_smooth = True
    if smooth_boundary:
        smooth_boundaries(obj, line)
        if not use_proxy:
            resolve_penetration(obj, max(0.012, offset * 0.55))
        recalc_normals(obj)
    if decimate:
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        mod = obj.modifiers.new(name='Simplify', type='DECIMATE')
        mod.ratio = decimate
        mod.use_collapse_triangulate = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
        relax_mesh(obj, 8)
        smooth_boundaries(obj, line)
        if not use_proxy:
            resolve_penetration(obj, max(0.012, offset * 0.55))
        recalc_normals(obj)
    if solidify:
        bpy.ops.object.select_all(action='DESELECT')
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        mod = obj.modifiers.new(name='Thickness', type='SOLIDIFY')
        mod.thickness = solidify
        mod.offset = -1.0
        mod.use_rim = True
        bpy.ops.object.modifier_apply(modifier=mod.name)
        for poly in obj.data.polygons:
            poly.use_smooth = True
    return bind_garment(obj)


def bind_garment(obj):
    # Smoothly interpolate deformation fields. A single nearest sculpt vertex
    # can abruptly change across a cloth edge, tearing hems on large builds.
    samples = []
    for v in obj.data.vertices:
        near = kd.find_n(v.co, 8)
        indices = np.array([item[1] for item in near], dtype=np.int64)
        blend = 1.0 / np.maximum(np.array([item[2] for item in near]), .003) ** 2
        blend /= blend.sum()
        samples.append((indices, blend))
    group_names = sorted({name for weights in orig_weights.values() for name in weights})
    group_ids = {name: index for index, name in enumerate(group_names)}
    skin_weights = np.zeros((len(obj.data.vertices), len(group_names)))
    for v in obj.data.vertices:
        indices, blend = samples[v.index]
        for src, influence in zip(indices, blend):
            for gname, weight in orig_weights[int(src)].items():
                skin_weights[v.index, group_ids[gname]] += weight * influence
    edges = np.array([edge.vertices[:] for edge in obj.data.edges], dtype=np.int64)
    ea, eb = edges[:, 0], edges[:, 1]
    degree = np.maximum(np.bincount(ea, minlength=len(skin_weights)) + np.bincount(eb, minlength=len(skin_weights)), 1)

    def diffuse(values, iterations):
        values = values.copy()
        for _ in range(iterations):
            mean = np.column_stack([(np.bincount(ea, weights=values[eb, axis], minlength=len(values))
                                    + np.bincount(eb, weights=values[ea, axis], minlength=len(values))) / degree
                                   for axis in range(values.shape[1])])
            values += (mean - values) * .45
        return values

    # Nearest body samples may alternate between thighs or arm/torso across a
    # loose cloth panel. Diffuse on the garment's own continuous topology.
    skin_weights = diffuse(skin_weights, 35)
    groups = {}
    for v in obj.data.vertices:
        # Match the game's four skin influences without losing normalization.
        ids = np.argsort(skin_weights[v.index])[-4:]
        top = [(group_names[index], skin_weights[v.index, index]) for index in ids]
        total = sum(weight for _, weight in top)
        for gname, raw_weight in top:
            weight = raw_weight / total
            if weight <= 1e-5:
                continue
            group = groups.get(gname)
            if group is None:
                group = obj.vertex_groups.new(name=gname)
                groups[gname] = group
            group.add([v.index], weight, 'REPLACE')
    obj.shape_key_add(name='Basis')
    for key_name in shape_names[1:]:
        key = obj.shape_key_add(name=key_name)
        delta = shape_delta[key_name]
        co = np.array([v.co[:] for v in obj.data.vertices], dtype=np.float64)
        for v in obj.data.vertices:
            indices, blend = samples[v.index]
            co[v.index] += np.sum(delta[indices] * blend[:, None], axis=0)
        base_co = np.array([v.co[:] for v in obj.data.vertices], dtype=np.float64)
        co = base_co + diffuse(co - base_co, 12)
        key.data.foreach_set('co', co.astype(np.float32).ravel())
    objects.append(obj)
    return obj


def mask_shirt(i):
    x, y, z = coords[i]
    trunk = wsum(i, ('Hips', 'Spine', 'Spine1', 'Spine2', 'Neck', 'LeftShoulder', 'RightShoulder'))
    arm = wsum(i, ('LeftArm', 'RightArm'))
    if z <= 0.035 or z >= 0.648:
        return False
    return trunk > 0.28 or (arm > 0.25 and z > 0.440)

def mask_pants(i):
    x, y, z = coords[i]
    legs = wsum(i, ('LeftUpLeg', 'RightUpLeg', 'LeftLeg', 'RightLeg', 'LeftFoot', 'RightFoot', 'LeftToeBase', 'RightToeBase'))
    hips = wsum(i, ('Hips',))
    return z < 0.205 and z > -0.805 and (legs > 0.22 or hips > 0.28)

def mask_boots(i):
    x, y, z = coords[i]
    legs = wsum(i, ('LeftLeg', 'RightLeg', 'LeftFoot', 'RightFoot', 'LeftToeBase', 'RightToeBase'))
    return z < -0.600 and legs > 0.22

def mask_boot_cuff(i):
    x, y, z = coords[i]
    legs = wsum(i, ('LeftLeg', 'RightLeg'))
    return -0.678 < z < -0.598 and legs > 0.3

def mask_belt(i):
    x, y, z = coords[i]
    trunk = wsum(i, ('Hips', 'Spine', 'Spine1'))
    return 0.155 < z < 0.228 and trunk > 0.30

def hairline(x, y):
    temple = math.exp(-((abs(x) - 0.082) / 0.026) ** 2)
    wave = 0.0035 * math.sin(x * 120.0 + 0.5) + 0.002 * math.sin(x * 260.0)
    return 0.886 - 0.30 * y - 0.018 * temple + wave

def mask_hair(i):
    x, y, z = coords[i]
    if wsum(i, ('Head',)) < 0.5:
        return False
    return z > hairline(x, y) + 0.004

def mask_bracer(i):
    x, y, z = coords[i]
    for side in ('Left', 'Right'):
        weight = wsum(i, (side + 'ForeArm',))
        if weight <= 0.35:
            continue
        bone = arm.data.bones[side + 'ForeArm']
        a = np.array(bone.head_local[:], dtype=np.float64)
        b = np.array(bone.tail_local[:], dtype=np.float64)
        segment = b - a
        t = np.clip((coords[i] - a) @ segment / (segment @ segment), 0.0, 1.0)
        if 0.62 < t < 0.91:
            return True
    return False

for garment in build_clothes(arm, MATERIALS):
    bind_garment(garment)
make_garment('Hair', mask_hair, 0.014, MATERIALS['Hair'], smooth=2, solidify=0.008, decimate=0.45,
             variable=lambda c: 0.011 * max(0.0, min(1.0, (c[2] - 0.86) / 0.09)) * (0.7 + 0.3 * math.sin(c[0] * 70.0) * math.sin(c[2] * 45.0)),
             line=hairline)

# Belt buckle, rigid to the waist and following the front belt vertex per shape.
bpy.ops.mesh.primitive_cube_add(size=1)
buckle = bpy.context.object
buckle.name = 'Buckle'
buckle.scale = (0.034, 0.011, 0.028)
buckle.location = (0, -0.158, 0.192)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
buckle.data.materials.append(MATERIALS['Brass'])
for poly in buckle.data.polygons:
    poly.use_smooth = False
group = buckle.vertex_groups.new(name='Spine')
group.add(list(range(len(buckle.data.vertices))), 1.0, 'REPLACE')
_, buckle_src, _ = kd.find(Vector((0, -0.12, 0.192)))
buckle.shape_key_add(name='Basis')
buckle_base = np.array([v.co[:] for v in buckle.data.vertices], dtype=np.float64)
for key_name in shape_names[1:]:
    key = buckle.shape_key_add(name=key_name)
    key.data.foreach_set('co', (buckle_base + shape_delta[key_name][buckle_src]).astype(np.float32).ravel())
objects.append(buckle)

bpy.ops.object.select_all(action='DESELECT')
for o in objects:
    o.select_set(True)
body.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.object.join()
body.name = 'FighterBody'
print('DRESSED', len(body.data.vertices), 'verts', len(body.data.materials), 'materials', flush=True)

bpy.ops.object.camera_add(location=(0, -3.5, 0.0))
cam = bpy.context.object
cam.data.type = 'ORTHO'
cam.data.ortho_scale = 2.15
bpy.context.scene.camera = cam
cam.rotation_euler = (math.radians(90), 0, 0)
bpy.ops.object.light_add(type='AREA', location=(2, -3, 3))
bpy.context.object.data.energy = 500
bpy.context.object.data.size = 4
bpy.ops.object.light_add(type='AREA', location=(-2.5, 1.5, 2.5))
bpy.context.object.data.energy = 250
bpy.context.object.data.size = 4
bpy.context.scene.world.color = (.05, .05, .05)
scene = bpy.context.scene
scene.render.engine = 'BLENDER_EEVEE_NEXT'
scene.render.resolution_x = 640
scene.render.resolution_y = 800
for name, loc, rot in [
    ('front', (0, -3.5, 0.0), (math.radians(90), 0, 0)),
    ('side', (3.5, 0, 0.0), (math.radians(90), 0, math.radians(90))),
    ('back', (0, 3.5, 0.0), (math.radians(90), 0, math.radians(180))),
    ('head', (0, -0.85, 0.80), (math.radians(90), 0, 0)),
]:
    cam.location = loc
    cam.rotation_euler = rot
    cam.data.ortho_scale = .48 if name == 'head' else 2.15
    scene.render.filepath = str(OUT / f'{name}.png')
    bpy.ops.render.render(write_still=True)
bpy.ops.object.select_all(action='DESELECT')
body.select_set(True)
arm.select_set(True)
bpy.context.view_layer.objects.active = body
bpy.ops.export_scene.gltf(filepath=str(OUT / 'dressed.glb'), use_selection=True, export_format='GLB', export_animations=False, export_all_vertex_colors=True)
# Store body coverage on the exported skin vertices. A dressed character does
# not need to render skin underneath opaque cloth; the preview can restore the
# whole body by changing only its per-instance material. This also keeps feet
# from poking through the boots in motion without deleting their geometry.
path = OUT / 'dressed.glb'
raw = path.read_bytes()
json_size = struct.unpack_from('<I', raw, 12)[0]
document = json.loads(raw[20:20 + json_size])
binary = bytearray(raw[28 + json_size:])

def read_positions(accessor_id):
    accessor = document['accessors'][accessor_id]
    view = document['bufferViews'][accessor['bufferView']]
    return np.frombuffer(binary, dtype='<f4', count=accessor['count'] * 3,
                         offset=view.get('byteOffset', 0) + accessor.get('byteOffset', 0)).reshape(-1, 3).copy()

for primitive in document['meshes'][0]['primitives']:
    material = document['materials'][primitive['material']]
    if 'baseColorTexture' not in material.get('pbrMetallicRoughness', {}):
        continue
    positions = read_positions(primitive['attributes']['POSITION'])
    colors = np.ones((len(positions), 4), dtype='<f4')
    for i, point in enumerate(positions):
        local = Vector((float(point[0]), -float(point[2]), float(point[1])))
        _, index, _ = kd.find(local)
        weights = orig_weights[index]
        hand = sum(weights.get(name, 0) for name in hand_groups)
        axial = sum(weights.get(name, 0) for name in ('Hips', 'Spine', 'Spine1', 'Spine2', 'Neck', 'LeftShoulder', 'RightShoulder'))
        covered = local.z < .07 and hand < .05
        covered |= .05 < local.z < .64 and axial > .5
        for side in ('Left', 'Right'):
            bone = arm.data.bones[side + 'Arm']
            a, segment = bone.head_local, bone.tail_local - bone.head_local
            t = (local - a).dot(segment) / segment.length_squared
            covered |= weights.get(side + 'Arm', 0) > .5 and t < .56
        colors[i, 3] = 1.0 if covered else 0.0
    while len(binary) % 4:
        binary.append(0)
    view_index = len(document['bufferViews'])
    document['bufferViews'].append({'buffer': 0, 'byteOffset': len(binary), 'byteLength': colors.nbytes})
    binary.extend(colors.tobytes())
    accessor_index = len(document['accessors'])
    document['accessors'].append({'bufferView': view_index, 'componentType': 5126, 'count': len(colors), 'type': 'VEC4'})
    primitive['attributes']['COLOR_0'] = accessor_index
    print('OUTFIT COVERAGE', material.get('name'), int(np.sum(colors[:, 3])), '/', len(colors), flush=True)
document['buffers'][0]['byteLength'] = len(binary)
encoded = json.dumps(document, separators=(',', ':')).encode('utf-8')
encoded += b' ' * ((-len(encoded)) % 4)
binary.extend(b'\0' * ((-len(binary)) % 4))
total = 12 + 8 + len(encoded) + 8 + len(binary)
path.write_bytes(struct.pack('<III', 0x46546C67, 2, total) + struct.pack('<II', len(encoded), 0x4E4F534A)
                 + encoded + struct.pack('<II', len(binary), 0x004E4942) + binary)
print('OUTFIT DONE', flush=True)




