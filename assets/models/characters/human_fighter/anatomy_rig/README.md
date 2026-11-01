# Anatomy-preserving human fighter

This is the retained pre-creator reference. The current player uses head_revision.
`character.tscn` uses the animation pack's original
55 bone names and hierarchy, with joint positions/rest axes fitted to the user's
generated anatomy. `body.res` preserves all 63,990 exported vertices, 100,000
triangles, UVs, source skin weights and source normals. Geometry receives only a
uniform 0.974 scale and a 0.923m vertical offset. The 4K diffuse texture is retained;
the exaggerated generated normal map is omitted and the skin is nonmetallic.

The earlier `native_skin/` conversion stretched the chest/waist and retained
invalid normals after deformation. It is superseded and is not loaded by player.
Do not use the old export_source/transfer_weights/bake_scene pipeline for this rig.

`scripts/fighter_animation_adapter.gd` copies animation libraries, replaces
constant joint offsets with the new rig offsets while preserving translation
motion, and supplies missing constant tracks. Rotations stay in animation-pack
axes, including upper-body action overlays. Original animation resources remain
unchanged. Copies are cached for reuse by additional instances of this one rig.

Rebuild from the repository root:

```powershell
.\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://scripts/dev/fighter_skin/build_anatomy_rig.gd
.\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_fighter_retarget.gd -- --test-mode
```

The test compares every vertex, UV and normal against the actual generated input,
checks skin seams/binds/weights and samples movement, attack and sitting. Asset
packing quantizes normals and weights slightly; test tolerances allow that only.
Rendered poses were reviewed in OpenGL and Direct3D 12 Forward+ at low and close
camera angles. Source facial likeness, texture artifacts and remaining automatic
skinning limitations are not repaired by this skeleton conversion.
