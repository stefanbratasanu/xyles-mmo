# Visual development: grip, ground and color

## Preview color grading

In game, click **DEV → COLOR**. Original restores the current game look. Purple
dusk, Crimson, Golden amber, Cool forest and Dark cinematic are temporary live
previews; turning DEV off restores Original. The grades change only the rendered
3D environment, not the HUD, gameplay, time of day, or saved settings. They are
starting points for art direction, not approved final palettes.

The code in `scripts/color_grading.gd` generates small 3D lookup textures and
sets the existing Environment's brightness, contrast and saturation. Godot
applies its [color adjustments and LUTs after tonemapping](https://docs.godotengine.org/en/4.7/tutorials/3d/environment_and_post_processing.html#adjustments).
This preserves the existing filmic tonemapper and allows independent red, green
and blue changes. Compare a palette in daylight, at dusk, at night, and in
combat before making it permanent: the current samples are not a final balance.

## Weapon and hand contact

The fitting path measures hand-weighted vertices of each model's mesh near its
finger roots, places `PalmGripAnchor` on the gripping side, and aligns a weapon's
`GripAnchor` to it. The ornate sword's contact was measured at the middle of its
visible grip, not at the pommel. `scripts/weapon_anchor.gd` supplies contact
frames for current weapons; a new unusual weapon should author a `GripAnchor`
Marker3D with its local position and orientation. An exact saved F7 adjustment
still overrides automatic alignment. To replace it, open F7, choose Reset to
Model, then Save Grip. Fitted attachment uses Godot's
[BoneAttachment3D](https://docs.godotengine.org/en/4.7/classes/class_boneattachment3d.html).

The hand animation still determines finger pose and orientation, and the second
hand on a two-handed weapon is animation-authored. A marker match alone does not
guarantee every pose looks good: inspect the actual model from both sides during
idle, travel and attacks, and review new races and weapon assets individually.

## Feet and forest rays

The grounded-leg modifier samples skinned sole vertices, while a spatial index
interpolates actual visible road and camp triangles at each foot. This avoids
using a single analytic road height above the visible surface. Correction is
bounded and disabled for nonlocomotion poses; it is not full foot placement for
steep steps, arbitrary props, or airborne actions.

Forest rays are a lightweight visual approximation, not physical volumetric
scattering. A deterministic subset of living baked trees supplies vertices from
branch geometry; pines have no separate branch mesh, so use needle-canopy
vertices. Each beam pivots around that point while following the sun. Existing
clearance, graphics-toggle and 10:00–17:00 fade rules remain. Godot also supports
[volumetric fog](https://docs.godotengine.org/en/4.7/tutorials/3d/volumetric_fog.html),
which can produce physical-looking light scattering but requires a separate
quality and performance evaluation before replacing the localized effect.
