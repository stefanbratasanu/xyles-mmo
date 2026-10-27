# Player animation assets

These resources were generated from the FBX files in `assets/animations/Ultimate Animation Collection/`. The playable character is the Protof Actor, using its own skeleton and base-color texture. The sword, greatsword, shield and staff props also come from the collection.

Sword and greatsword equipment selects matching directional idle, walk, run, sprint, attack and block clips. The basic locomotion set supplies crouch, jump, fall and landing clips. Casting and support use wizard animations. Melee attacks play on an upper-body layer so walking and sprinting continue. A weapon model is attached to the right-hand bone while a weapon is equipped. Staff and shield props are available for future equipment types.

The library also contains every non-root-motion `Humanoid@...fbx` clip from the two-handed melee set. From gameplay code, call `player.play_greatsword_animation("ParryFront2HandMelee")` to play a clip by its FBX name, or pass `true` as the second argument to use its upper-body tracks only. The function returns `false` when a clip does not exist. Call `player.stop_greatsword_animation()` to stop a looping full-body clip. Importing the clips makes them available to game code; it does not assign every clip to a gameplay action.

`authored_speeds.json` stores speeds measured from the corresponding root-motion FBX clips. The controller uses these measurements to adjust playback speed to the actual movement speed while playing the in-place animations. Walking and backpedaling are capped to keep the walk cycle from playing excessively fast. When a source clip has no matching root-motion file, the controller uses a default speed estimate.

The two-handed set contains dodge steps but no forward roll. The movement skill uses a procedural body rotation over a crouched pose, with its movement and rotation timed together. Casting and healing use the wizard's shorter spell gestures on the upper body.

To rebuild these resources, run Godot with `--headless --path . --script res://scripts/editor/build_native_protof.gd`. This imports the source FBX data and writes Godot scenes, textures and an animation library. Review the character's materials and weapon alignment in Godot after changing source assets.
