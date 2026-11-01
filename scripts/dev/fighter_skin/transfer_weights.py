"""Fit the generated fighter's skin to the animation-pack character (Blender 4.4)."""
from math import exp
from pathlib import Path

import bpy

root = Path(__file__).resolve().parents[3]
build = root / "logs/fighter_skin_build"
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
bpy.ops.import_scene.gltf(filepath=str(build / "fitted.glb"))
source = bpy.data.objects["SK_Protof-Actor"]
fighter = bpy.data.objects["FighterBody"]
armature = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
bpy.context.view_layer.objects.active = fighter
bpy.ops.object.select_all(action="DESELECT")
fighter.select_set(True)

# GLTF splits vertices at UV seams. Weld before smoothing to keep their weights equal.
bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.mesh.remove_doubles(threshold=0.00003)
bpy.ops.object.mode_set(mode="OBJECT")

# Relax the shoulder transition where the fitted arm meets the preserved torso.
correction = fighter.vertex_groups.new(name="Shoulder fit correction")
for vertex in fighter.data.vertices:
    point = fighter.matrix_world @ vertex.co
    weight = exp(-((abs(point.x) - 0.23) / 0.105) ** 4
                 - ((point.z - 1.43) / 0.12) ** 4)
    if weight > 0.001:
        correction.add([vertex.index], weight, "REPLACE")
modifier = fighter.modifiers.new("Relax shoulder fit", "SMOOTH")
modifier.factor = 0.6
modifier.iterations = 35
modifier.vertex_group = correction.name
bpy.ops.object.modifier_move_to_index(modifier=modifier.name, index=0)
bpy.ops.object.modifier_apply(modifier=modifier.name)

fighter.vertex_groups.clear()
for group in source.vertex_groups:
    fighter.vertex_groups.new(name=group.name)
modifier = fighter.modifiers.new("Animation pack weight transfer", "DATA_TRANSFER")
modifier.object = source
modifier.use_vert_data = True
modifier.data_types_verts = {"VGROUP_WEIGHTS"}
modifier.vert_mapping = "POLYINTERP_NEAREST"
modifier.layers_vgroup_select_src = "ALL"
modifier.layers_vgroup_select_dst = "NAME"
bpy.ops.object.modifier_apply(modifier=modifier.name)

bpy.ops.object.mode_set(mode="EDIT")
bpy.ops.mesh.select_all(action="SELECT")
bpy.ops.object.vertex_group_smooth(group_select_mode="ALL", factor=0.4, repeat=3)
bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=4)
bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
bpy.ops.object.mode_set(mode="OBJECT")
assert all(vertex.groups for vertex in fighter.data.vertices), "Unweighted vertices"

# The final Godot bake supplies a separate material referencing the original maps.
for material in fighter.data.materials:
    if not material or not material.use_nodes:
        continue
    shader = next((node for node in material.node_tree.nodes
                   if node.type == "BSDF_PRINCIPLED"), None)
    if shader:
        for link in list(shader.inputs["Normal"].links):
            material.node_tree.links.remove(link)
        shader.inputs["Roughness"].default_value = 0.7

armature.select_set(True)
output = build / "native.glb"
bpy.ops.export_scene.gltf(
    filepath=str(output), use_selection=True, export_format="GLB",
    export_animations=False, export_apply=False, export_def_bones=False, export_yup=True,
)
print("SAVED", output, flush=True)
