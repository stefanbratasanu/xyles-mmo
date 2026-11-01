# Player animation assets

The supplied Ultimate Animation Collection provides the original 55-bone rig,
clips and prototype weapon props. character.tscn is the source rig/reference;
playable race meshes resolve through resources/characters/race_models.json.
The source FBX folder stays local/ignored. Share runtime resources and builders.

## Ordinary travel and readiness

travel_animations.res has 69 clips, built from Basic Locomotion rather than the
Combat Bare Fists set: ordinary standing, walking, directional running and sprint,
plus carrying variants and reviewed ready/idle candidates. Normal run uses
RunFastForwardUnarmed, appropriate to game pace; jog retains RunForwardUnarmed.
Carry variants close the right-hand fingers and author wrist rotations so the
sword points down beside the body. Pole variants hold longer weapons upright.
No vertex deformation or changed skeleton rest is used to force these poses.

animation_profiles.gd separates idle from combat_idle. Peaceful standing is
relaxed; attacks/blocking hold a four-second readiness timer, and channels extend
it. Sword readiness uses a one-handed fencing source, without the missing-shield
stance. Death/revival clears readiness. Original combat aliases remain available
for compatibility; protof/unarmed_idle is still the old fighting clip, not the
new peaceful default. F6 labels and search identify travel and combat categories.

Base movement is 3.71m/s (5.3 * .70), before existing bonuses. Walking/backpedal/
crouch caps also receive .70. Dash remains independently timed. Travel playback
uses final horizontal displacement after collision/manual boundary correction.
travel_speeds.json retains source root-motion speeds; travel_strides.json stores
measured low-foot stance speeds on every race's retargeted skeleton. Playback
rate is travel speed divided by that measured stride speed. Unknown custom or
legacy clips fall back to source speed scaled by fitted leg length. Moving gait
rate is automatic; profile Speed applies to idle/actions and previews. Gait
changes preserve cycle phase. This matches pace, not terrain contact IK.

Rebuild, in this order, after changing travel clips or any race's rig/proportions:

```powershell
.\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://scripts/editor/build_travel_animation_library.gd
.\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://scripts/editor/calibrate_travel_strides.gd
```

The calibration report is ignored logs/travel_calibration_report.json. Inspect
sword and long-weapon carrying, transitions, and foot motion in the actual game.
Native candidate review: scripts/dev/characters/review_travel.gd. Regression tests:
test_relaxed_locomotion.gd, test_locomotion_pace.gd and test_race_motion.gd.

## Existing combat and authoring resources

protof_animations.tres retains original combat/sword/shield/two-handed/crouch/
jump/fall/landing clips, including the in-place two-handed collection by FBX name.
action_animations.tres supplements sword attacks, wizard casts/staff movement and
fencing thrusts. Existing damage and skill timings are independent of presentation.
Upper-body actions still overlay locomotion. Existing explicit mappings remain.

Rebuild original libraries with scripts/editor/build_native_protof.gd and
scripts/editor/build_action_animation_library.gd respectively. The original
native builder also rewrites the reference character/props; use the travel
builder for a travel-only change. Do not replace race scenes with the Protof body.

F6 captures the active animation, even with its window already open. Selecting a
clip replaces the actual character visual immediately. Stop Override releases a
loop. Save Mapping separately persists per-weapon/action mappings in
saves/animation_profiles.json. F7 opens live XYZ position/rotation calibration;
Save Grip writes resources/characters/weapon_grips.cfg per model/type/variant.
Neither tool changes skill damage. Animation selection remains in Options/menu.

F7 now freezes/resumes the exact base and upper-body animation pose instead of
stopping the override. Fast Align: click for mouse XY position / wheel Z;
Ctrl-click for mouse pitch/yaw / wheel roll. Click/Enter finishes the pass;
Esc/right-click cancels it. Save Grip persists it. F6 selecting a new clip
releases a frozen pose. Input capture is isolated from camera and released on
finish/context change/teardown. Test with tests/test_fast_align.gd.

Fast Align control update: hold right mouse to rotate the weapon; hold Alt to
rotate the hand (mouse pitch/yaw, wheel roll). Right-click no longer cancels.
Escape restores both hand and weapon; Save Grip persists both. Hand calibration
uses an additive SkeletonModifier3D after playback, so it affects fingers and
weapon attachment without editing source clips or accumulating on frozen poses.

Forward-diagonal sprint uses native SprintForwardLeft/RightUnarmed clips, with
carry/pole variants. sprint_forward_left/right have separate mappings and
per-model stride calibration. Shift+W+A / Shift+W+D retain normalized speed
and step phase. Rebuild the library and calibrations together as above.

Shift-sprinting now uses the unarmed travel variant while the weapon is on the
back. Normal running retains carry_/pole_ clips with their original authored
arm motion. The former running_weapon_carry.gd IK modifier and its test were
removed after user feedback about robotic shoulder/elbow motion. F6 previews
also retain the original clip poses.

scripts/sprint_weapon_visual.gd is a plain Node3D presentation component: a
Spine2 BoneAttachment3D follows the shoulder-to-pelvis line, plus a tiny clip-phase
bounce/sway on the holder. It never writes skeleton bones. No extra timer drives
the sway, so playback speed/phase and F7 pause remain consistent. There is no
procedural reach-to-sheath animation or generated scabbard. Gameplay readiness
lives in game_state.gd, skill/basic-attack gates in their central dispatch paths.
Test tests/test_sprint_weapon.gd and tests/test_locomotion_pace.gd.

Sword idle wrist refinement: carry_idle and sword_ready now align the palm's
middle-finger base direction toward the forearm (80% correction), leaving a
small relaxed bend. The older blade-to-forearm aim caused an extreme sideways
wrist angle. Ready idle copies the closed sword finger grip. This is baked into
the two clips, without runtime arm IK or changes to shoulder/elbow/leg tracks.
Saved F7 grip/hand edits still apply. Other weapon styles/gaits retain their aim.

Update just these idles without rebuilding locomotion/stride data:
Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://scripts/editor/build_travel_animation_library.gd -- --idle-only
This resets original source wrist keys before baking, including untracked
constant wrist rotations, so repeated updates do not accumulate corrections.
The combat source FBX is required locally. Full builds use the same grip/aim rule.
