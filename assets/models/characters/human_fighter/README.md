# Human Fighter — Hyper3D draft

Generated with Hyper3D Rodin (Gen-2.5-Medium), 2026-10-29, using the user-supplied human fighter reference. Hyper3D generation ID: `1e8514b1-8963-4830-8501-161706a23719`.

- `base_basic_pbr.glb`: generated PBR-textured model.
- `base_basic_shaded.glb`: generated shaded variant.
- Requested GLB, quad mesh, target 30,000 polygons, neutral A-pose and isolated full body. Each exported GLB has 30,330 vertices and 54,984 triangles; it is unrigged and has no animations.
- These are draft, unintegrated generated assets. Visual quality, topology, deformability and reference fidelity still require review. Rigging and compatibility with the player animation library have not been established.
- Godot imported and loaded both scenes headlessly. The supplied reference contained JPEG bytes despite its `.png` extension; it was renamed to `.jpg` without changing its contents so Godot can import it.

## Rigged default character

`fighter_rigged.glb` is the Hyper3D humanoid-rigged PBR export (rigging job `02a13b4b-7c39-4073-986e-6363d98ef21b`). The game retargets the original player skeleton onto it, retaining the existing animations and moving weapon attachment to the generated right hand. The original body remains as a hidden animation driver. The generated skin and retargeting need interactive review, particularly shoulders, hand grips, sitting and extreme poses.

## Refined model

`fighter_refined.glb` is the playable version, generated from `fighter_rigged.glb` by `refine_fighter.py` in Blender 4.4. It mirrors the better face/profile, restores the non-tattooed side's upper-arm texture, transfers rig weights, and softens hip/thigh weights near the shorts. The original Hyper3D rig is retained for comparison. The mirrored geometry can show a close-up neck shading transition; the generated skin and movement need further interactive review.
