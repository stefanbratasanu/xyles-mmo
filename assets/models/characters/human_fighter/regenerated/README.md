# Two-view Hyper3D fighter draft

Generated on 2026-10-29 with Hyper3D Rodin Gen-2.5-High, using the user's front and side reference images. Generation ID: `c8fb79ee-69d1-433c-ae50-a3820fac2c39`. Requested a single bald muscular fighter, one-sided tattoo, black shorts, A-pose, GLB and 30,000-quad target.

`base_basic_pbr.glb` and `base_basic_shaded.glb` each have approximately 55,456 triangles and no skeleton or animations. Both import and load in Godot. They are comparison drafts and do not replace the current playable model.

Blender previews showed more detailed shorts but rough/pitted skin on one side and an inaccurate mouth profile on the opposite side. The generated model has not been rigged or playtested.

## Humanoid rig

Hyper3D rigging job `bd4e7a61-8dd8-4af7-a8d2-eb3822f748de` produced `fighter_rigged_pbr.glb` and `fighter_rigged_shaded.glb`. Each contains 30,034 exported vertices, 55,456 triangles, one 52-joint humanoid skin and no animation clips. A headless check mapped all 52 joints through the game's retargeting bridge and verified a sampled leg direction. The rigged versions are still comparison assets; they do not replace the playable character. Skin deformation, appearance in motion, and the previously observed rough skin and mouth profile need visual review.

The PBR rig became the playable default at the user’s request; earlier notes describing it as a comparison-only asset predate that switch.
