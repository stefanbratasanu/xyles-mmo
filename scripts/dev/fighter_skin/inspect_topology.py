import bpy, bmesh
from pathlib import Path
root = Path(r"K:/GoDotProjects/xyles-mmo")
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(root / 'assets/models/characters/human_fighter/head_revision/source.glb'))
body = max((o for o in bpy.context.scene.objects if o.type == 'MESH'), key=lambda o: len(o.data.vertices))
bm = bmesh.new(); bm.from_mesh(body.data)
bmesh.ops.remove_doubles(bm, verts=list(bm.verts), dist=1e-5)
bm.verts.ensure_lookup_table(); bm.faces.ensure_lookup_table(); bm.normal_update()
print('WELDED', len(bm.verts), len(bm.faces))
# Connected components via faces.
seen = set(); comps = []
for f in bm.faces:
    if f.index in seen: continue
    stack = [f]; seen.add(f.index); comp = []
    while stack:
        cur = stack.pop(); comp.append(cur)
        for e in cur.edges:
            for lf in e.link_faces:
                if lf.index not in seen:
                    seen.add(lf.index); stack.append(lf)
    comps.append(comp)
print('COMPONENTS', len(comps), sorted([len(c) for c in comps], reverse=True)[:10])
for i, c in enumerate(sorted(comps, key=len, reverse=True)[:5]):
    zs = [v.co.z for f in c for v in f.verts]
    xs = [v.co.x for f in c for v in f.verts]
    print('COMP', i, 'faces', len(c), 'z', round(min(zs), 3), round(max(zs), 3), 'x', round(min(xs), 3), round(max(xs), 3))
# Boundary edges of the whole mesh.
be = [e for e in bm.edges if len(e.link_faces) == 1]
print('BOUNDARY EDGES', len(be))
# Angle split normals? Check custom normals.
print('HAS CUSTOM NORMALS', body.data.has_custom_normals)
print('POLYS', len(body.data.polygons), 'VERTS', len(body.data.vertices))
# UV island count estimate: count uv seams by loop coordinates is hard; print uv layers.
print('UV LAYERS', [l.name for l in body.data.uv_layers])
