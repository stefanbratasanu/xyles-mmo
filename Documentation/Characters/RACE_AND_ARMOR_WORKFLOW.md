# Race characters and armor workflow

Current target: Human, Orc, Elf, Dark Elf and Dwarf, with Male and Female models.
Use one authored build for each race/gender. Body fat/muscle customization is
paused. Use original classic Lineage 2 inspired proportions in the same
semi-realistic art style as the supplied Human reference. Female characters are
clearly adult; dwarf proportions must read as adult, never childlike.

## Source of truth and status

`resources/characters/race_models.json` owns model IDs, height, concept paths,
scene paths, quality targets and review status. Only `reviewed` scenes can be
selected for new gameplay characters. Pending entries show their own reference
in Appearance; they must never masquerade as the Human mesh. Existing journeys
remain loadable while art is prepared. Male is the backward-compatible default
for old saves. Old body indices remain in existing save data, but rendering and
new creation use the fixed reference build.

At this checkpoint the existing Human male is the only reviewed 3D scene. Nine
new front references are under `assets/concepts/characters/races/`; they are
concept images, not completed meshes. Hyper3D device authorization is pending;
no new paid 3D generation was submitted. Do not mark entries reviewed merely
because a concept image or a generation job exists.

## Generation

`race_pipeline.py plan` prints all ten entries and their exact generation
prompts. Built-in ImageGen created the nine new raster references, matching the
supplied Human image as a style reference. The descriptions specify racial
silhouettes, mature adult faces, neutral A poses, separated fingers and opaque
undergarments. The prompt construction for 3D is in `race_pipeline.py` and
requires a continuous full body including neck, rather than another head splice.

Run with the project's available Python:

```powershell
python scripts/dev/characters/race_pipeline.py plan
python scripts/dev/characters/race_pipeline.py generate --model orc_male
python scripts/dev/characters/race_pipeline.py status --model orc_male
python scripts/dev/characters/race_pipeline.py result --model orc_male
# Inspect geometry before this next paid operation:
python scripts/dev/characters/race_pipeline.py rig --model orc_male
```

The installed Hyper3D CLI is used through its documented operations, with the
existing OAuth credential store. `curl_fetch.mjs` is a Windows HTTPS fallback;
credentials travel through process pipes, never command arguments or logs.
Do not run simultaneous authorization flows. Generation submissions are recorded
before sending in ignored `logs/race_build/jobs.json`. A timed-out or ambiguous
submission is NOT automatically retried; inspect provider history first to avoid
duplicate charges. Status/read operations may be repeated safely.

Request Gen-2.5-High, Quad target 50,000, texture de-lighting, GLB. Request 4K
albedo and detailed PBR maps; actual atlas sizes must be audited (the CLI does
not expose a texture-resolution parameter). Keep exported body vertices within
20,000-200,000. No subscription purchase or auto-top-up is part of this workflow.

## Rig and fidelity acceptance

Save each approved provider rig to
`assets/models/characters/races/<model_id>/rigged.glb`. Import, then build:

```powershell
blender --background --python-exit-code 1 --python scripts/dev/characters/normalize_skin.py -- --input RAW_PROVIDER_RIG.glb --output assets/models/characters/races/orc_male/rigged.glb
.\Godot_v4.7.2-stable_win64_console.exe --headless --path . --import
.\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://scripts/dev/characters/build_race_rig.gd -- orc_male
blender --background --python-exit-code 1 --python scripts/dev/characters/audit_model.py -- --input assets/models/characters/races/orc_male/rigged.glb --output logs/race_build/orc_male.audit.json
```

`build_race_rig.gd` preserves mesh anatomy with uniform scale/placement and fits
the original animation-pack skeleton to the body. It never translates vertices
per bone to force them into human proportions. It rejects multiple mesh inputs
rather than silently discarding pieces. `race_character.gd` preserves imported
PBR materials instead of applying the Human neck-color/skin shader to every race.
The runtime and preview resolve the same catalog scene. Animation caches include
the actual rest transforms, so a short dwarf does not reuse tall-human offsets.

Automated checks cover 20k-200k vertices, atlas dimensions, one armature,
normalized maximum-four weights, seam weight consistency and open boundaries at
the neck. Blender's bone-widget objects are excluded from geometry statistics.
They are diagnostics, not art acceptance. Inspect front, back, both profiles and
face close-ups under neutral and game lighting. Reject flat skull sides, neck
color rings, tangent creases, lumpy torso surfaces, fused fingers, joint collapse
and texture swimming. Inspect idle, walk, run, weapon attack and sit/stand poses,
including shoulders, hips, elbows, hands and knees. Run the relevant character,
rig and seating tests after installing a model. Do not change catalog status to
`reviewed` before the actual asset passes these checks and rendered review.

## Armor authoring and fitting

Armor is fitted to each race/gender rest mesh, preserving that body's skeleton.
A design can share materials and artistic language, but a Dwarf or Orc must not
be fitted by scaling the complete Human armor object. Model close to the target
rest pose first. Keep rigid plate segments separate at elbows/knees and avoid
crossing moving joints with a single rigid shell.

```powershell
# Make a body-fitted chest modeling seed, then refine it in Blender:
blender --background --python-exit-code 1 --python scripts/dev/characters/fit_armor.py -- --body BODY.glb --template chest --output CHEST_SEED.glb
# Bind an authored armor design to its target body:
blender --background --python-exit-code 1 --python scripts/dev/characters/fit_armor.py -- --body BODY.glb --armor ARMOR.glb --output FITTED.glb --clearance .006
# Rigid plate example (bone must exist in that target rig):
blender --background --python-exit-code 1 --python scripts/dev/characters/fit_armor.py -- --body BODY.glb --armor PLATE.glb --output FITTED_PLATE.glb --rigid-bone Spine2
blender --background --python-exit-code 1 --python scripts/dev/characters/audit_model.py -- --input FITTED.glb --output FITTED.audit.json --armor
```

The fitter uses closest-triangle barycentric weights, normalizes the top four,
maintains minimum rest clearance, rejects substantially misaligned input and
writes a JSON report. It retains the target armature and excludes reference
body geometry from the equipment output. Rigid mode binds to one explicit bone.
This is a fitting/binding tool, not a substitute for armor design or animated
collision/cloth simulation. Inspect every fitted piece during the same motion
suite, and use a body-coverage mask only for skin actually covered by opaque
armor. The tested chest seed is a modeling starting point, not finished art.

Authorization resumed successfully on 2026-11-01. All nine new model generations
and their rig jobs completed. Job IDs and download checkpoints are in the ignored
`logs/race_build/jobs.json`; never repeat a paid submission just because a CLI
process or editor restarted. The source PBR and provider rig GLBs are retained
alongside the normalized source and Godot runtime scene for each model.

The actual API exports contain 2048x2048 PBR maps, despite requesting 4K in the
prompt. Gen-2.5-High and 50k-quad generation are the highest exposed settings used
here; do not describe these new atlases as 4K. The runtime disables the provider's
exaggerated normal map by default (`normal_strength` can be set per catalog entry
after visual review). Raw maps remain in the source exports. The Human female's
neutral pale ponytail-tip projection artifact is corrected by the explicit
`normalize_skin.py --repair-brown-ponytail` material option; it is not a general
skin or hair recoloring rule.

Human male was rebuilt from scratch on 2026-11-01 using human_male_front_v2.png,
then the same audited source/rig/runtime pipeline. It now lives in races/human_male
and is the default player, selector and animation-preview asset. All ten entries
use the race-character fixed-build workflow. The older head_revision is retained
only as an inactive historical source. Human male's actual atlas is also 2K;
see its provenance.json for settings and provider job IDs.
