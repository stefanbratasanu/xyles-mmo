# Superseded experiment — do not use as the playable character

This conversion distorted torso proportions and retained stale normals. The default now uses ../anatomy_rig/. The historical notes below describe the rejected version.

# Fighter bound to the original animation skeleton

`fighter.tscn` is the default playable visual. Its `Body` mesh resolves
`../..` to the original character's `Skeleton3D` when its root is added under
that skeleton. The original 55-bone rig, animation libraries, seating pose and
weapon hand are unchanged; the visible mesh uses 53 named binds from that rig.
There is no second runtime skeleton or rotation bridge.

The generated fighter was fitted to the animation pack's arm, finger and leg
rest directions while preserving the torso/head geometry. Its skin weights
were transferred by nearest surface interpolation from `SK_Protof-Actor`, then
smoothed and normalized with four influences per vertex. UV seam duplicates
were welded before weight smoothing so the skin cannot tear along those seams.
The shoulder fit was relaxed locally. UVs and the one-sided tattoo are retained.

The mesh has 53,975 exported vertices and 100,000 triangles. Its material uses
the user's 4K diffuse and 2K roughness maps from `user_tweaked_df18cad1/`.
The exaggerated generated normal map is omitted. This conversion repairs
animation compatibility, not the generated face's likeness or baked shading.
Original generated source files remain available.

## Rebuild (from repository root)

Requires Blender 4.4 and Godot 4.7.2. Intermediate files go to ignored `logs/`.
The export step uses `fighter_retarget.gd` only to calculate rest-pose mappings;
that helper is not instantiated by the player.

```powershell
.\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://scripts/dev/fighter_skin/export_source.gd
& 'C:\Program Files\Blender Foundation\Blender 4.4\blender.exe' -b --python scripts/dev/fighter_skin/transfer_weights.py
.\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://scripts/dev/fighter_skin/bake_scene.gd
.\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_fighter_retarget.gd -- --test-mode
```

The bake writes `fighter_body.res` and `fighter.tscn`. Review rendered idle,
walk, run, attack and sitting poses after rebuilding; automated bounds and seam
checks cannot judge artistic quality.
