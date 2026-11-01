import bpy
from pathlib import Path
root = Path(r"K:/GoDotProjects/xyles-mmo")
for label, path in [
    ('source', root / 'assets/models/characters/human_fighter/head_revision/source.glb'),
    ('dressed', root / 'logs/character_compare/outfit/dressed.glb'),
]:
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)
    bpy.ops.import_scene.gltf(filepath=str(path))
    body = max((o for o in bpy.context.scene.objects if o.type == 'MESH'), key=lambda o: len(o.data.vertices))
    print(label, 'verts', len(body.data.vertices), 'attrs', [(a.name, a.data_type, a.domain) for a in body.data.color_attributes])
    for a in body.data.color_attributes:
        sample = [tuple(round(c, 3) for c in a.data[i].color) for i in range(0, min(5, len(a.data)))]
        print(' ', a.name, a.data_type, a.domain, sample)
    print(' active', body.data.color_attributes.active_color_index)
