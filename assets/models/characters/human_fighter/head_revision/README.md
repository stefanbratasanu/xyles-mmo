# Human fighter appearance asset

The creator exposes independent five-level size/fat and muscularity choices.
Accepted settings persist on a character and apply to this asset in-game.
This is the current player visual. Characters without appearance data use the
neutral build. The previous anatomy_rig remains available as a reference asset.

## Current physique grid

- Size: very skinny, slim, average, fat, very fat (0–4).
- Muscle: no visible muscle, lightly toned, athletic, muscular, very muscular (0–4).
- Neutral size 2 / muscle 3 is the basis mesh. Each of the other 24 combinations
  selects one complete `Physique_size_muscle` blend shape with weight 1. This
  replaces the rejected stacking of four independent endpoint deformations.
- All presets share topology, 55-bone hierarchy, UVs, hand/finger bindings and
  animations. The dressed mesh has 130,937 exported vertices across eight surfaces;
  the underlying body/head has 69,207 vertices.
- Soft torsos use continuous sections to remove carved abs; size changes
  distribute volume between torso and limbs with fixed joint locations. Weight
  corrections remove thigh influence from the upper abdomen. Head and neck-join
  positions stay fixed.
- The shader reduces baked abdominal definition for soft builds while preserving
  fine detail. Both skin materials meet at a shared neck tone with a localized
  position-based blend. COLOR_0 alpha on the body is the outfit coverage mask:
  skin under opaque clothing is hidden while dressed and restored for body
  inspection. The head does not use this coverage mask.
- Tunic and trousers use continuous lofted/voxel-unioned shells; boots do not
  copy the skin's toe grooves. Garment weights and morph fields are interpolated
  and smoothed on the garment topology. Clothing uses authored flat materials.
- These settings are cosmetic and do not alter collision, stats or movement.
- The fighter renders bald in the creator and gameplay, matching the supplied
  reference. The optional hair surface remains stored but hidden at runtime.

The source tattoo/skin detail and face remain generated art; this is still a
prototype rather than a finished character art set.

## Source and rebuild

The replacement head is Hyper3D job `17559b21-2d9c-4a46-a9c8-d8164cd5e696`,
Gen-2.5-High, 30,000 quad target, texture de-lighting, using the supplied front
and profile references. The raw head has 28,808 vertices and 2K textures. The
combined model retains a separate 4K body atlas and 2K head atlas.

1. Run `scripts/dev/fighter_skin/build_head_revision.py` with Blender. It calls
   `physique_shapes.py`; intermediate blend/GLB files go to `logs/face_rebuild/`.
2. Run `build_outfit.py` with Blender. It reads that CLEAN `head_swap.glb` and
   uses `outfit_geometry.py`. An explicit clean path may be passed after `--source`.
   It rejects an already dressed input instead of adding duplicate garments.
3. Copy `logs/character_compare/outfit/dressed.glb` to `source.glb` here, run
   Godot headless import, then `scripts/dev/fighter_skin/build_head_rig.gd`.
4. Run `tests/test_fighter_body_shapes.gd`, `tests/test_fighter_physique_motion.gd`
   and `tests/test_characters.gd`.
5. Render the actual creator using `scripts/dev/fighter_skin/review_physiques.gd`
   with `--all-presets`; front/profile images go to `logs/physique_rebuild/`.
   `review_selector.gd` checks three viewport sizes and captures portraits,
   extreme builds, dressed/undressed views and animation samples in
   `logs/character_polish/`.

The creator uses a private world, 2x render resolution and 4x MSAA. Drag or the
slider rotates; wheel zooms; Face and Full Body change framing; Reset restores
the front full-body view. Rest/Idle/Walk/Run use the same adapted animation-pack
rig as the player. Show Outfit is inspection-only and does not change saves.

The numerical tests cover single-preset selection, weights, stable head/neck,
size progression, limb/back limits, front-surface orientation, 150 sampled preset/pose combinations and
creator persistence. Inspect the images as well; bounds alone do not validate
anatomical appearance.
