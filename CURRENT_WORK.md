# CURRENT_WORK.md

Last updated: **2026-10-29**
Branch: `main`

## Lighting preview, TAA and sword swing (2026-10-29)

- The clock panel includes an Auto / Day / Night atmosphere preview. The real
  world clock and time-based spawns continue underneath, and Auto returns to
  their lighting. The preview does not persist across launches.
- Settings → Graphics can toggle temporal anti-aliasing live and persist the
  choice; it defaults on. Godot documents that TAA can blur moving views, so
  compare it on and off to diagnose the user's reported motion softness.
- Sword and greatsword melee animations use the user's supplied slash from
  `assets/audio/player/`. The quiet lead-in and tail were trimmed for timing;
  sound follows master volume and mute and uses the existing audio voice pool.
- Day/night and graphics settings were inspected in a Direct3D test-mode view;
  the end-to-end preview, audio and graphics settings have a regression test.

## Forest distance and creature cues (2026-10-29)

- Increased distance fog and matched a soft sky-horizon band to the changing
  day/night fog color. Tree trunks and fallen logs now use the existing scanned
  oak bark color and normal maps with dark tints; broadleaf cards have subtler
  veins and color variation. Rebuilt the saved world assets.
- Wolf and boar rigs step when their visual body turns even if stationary. The
  existing locked attack targets and timings are unchanged.
- Added the selected wolf and boar aggro, attack and death sounds. Their sources
  and licenses are in `assets/audio/enemies/ATTRIBUTION.md`. The selected wolf
  death cue is GPL 2.0; review distribution obligations and compatibility.
- Day/night rendering, world and streaming checks, combat telegraphs and a rig/
  audio regression check were run. Judge turning and the sound mix interactively;
  the engine still reports resource/RID leaks on scripted shutdown.

## Camp and road-fire pass (2026-10-29)

- Replaced the old road lanterns with original Blender-authored timber tripods,
  rope lashings and fire bowls. Each camp exit has a pair outside the fence; no
  tripod stands are inside the camp.
- Camp ground now has a circular road-textured clearing, and the rendered road
  ribbons begin at the clearing edge toward the existing fence openings.
- Camp logs have collision and an E-to-sit interaction; movement stands the
  player up. The existing campfire sitting animation is reused on the log.
- Particle fire and original synthesized positional crackles fade in at dusk
  and out after dawn. Campfire embers and lights also go dark in the day.
- A rendered seat check, world/traversal/integrity, progression, combat and skill
  panel checks pass. Confirm the synthesized sound and seat transition in an
  interactive session, and review performance with all gate fires at night.

## Camp rebuild follow-up (2026-10-29)

- Rebuilt tents as separate open canvas sheets with tied-back entrances, and
  made original beds with straw ticks, pillows and blankets. Added bark-textured
  fence timbers, rough log seats with separate cut-end grain, and charred wood
  for the existing stone-ring campfire. Sources and regeneration instructions
  are in `assets/models/props/generate_camp_assets.py` and the Poly Haven README.
- Shared nearby gate torch placements and excluded roadside torches near the
  camp to prevent overlapping stands.
- Replaced the log's elevated floor-sitting animation with a rig-derived seated
  pose, and return the visual to the body's side of the log before movement.
- Per user request the latest revision was not launched or gameplay-tested.
  The world was rebaked headlessly. Review the pose, foot placement and stand-up,
  tent interiors, fire and sound mix when the user next plays.

## Seat and torch follow-up (2026-10-29)

- Log sitting uses the relaxed campfire upper body and a rig-derived leg pose,
  aligning the pelvis to the log surface. A reversible sit/stand transition runs
  before movement resumes; it preserves the separate X ground-sitting behavior.
- Torch stands, flames and colliders are scaled to roughly player height. The
  authored world snapshot has been rebaked.
- No game launch or gameplay tests were performed at the user's direction. The
  seated alignment, feet, relaxed arms and transition still need in-game review.

## Seat position and torch flame correction (2026-10-29)

- Sitting now retains the approached position along the log and side. During
  the sit transition the collision body moves to a nearby standing point there;
  getting up returns to that point rather than the original interaction point.
- Torch particles use local coordinates so they scale with the stand. Their
  sprites and emission point were adjusted to begin above the bowl, and their
  size, particle count and brightness were reduced.
- The off-center seat/stand test passed in the real renderer. One torch test
  confirmed the local-coordinate setup; its image revealed sprite overlap under
  the bowl, so the emission height and size were subsequently corrected and
  the world rebaked. The final visual adjustment was not re-tested in-game.

## Current state

Map I is playable as a real 3D forest continent. The old flat baked arena and the
minimap are gone; a single zone table drives the authored world, and the game has
a day/night cycle, MMO chat and a full-screen painted map, and the HUD has been
re-laid-out around a bare skill bar. The redesigned world is about 512.7 m
across, with spread-out level regions, an expanded road network and a sealed
waygate near the north-west corner. Authored world assets are baked offline;
terrain, vegetation and scenery stream in buffered chunks during play.

## Completed in this pass

- **World:** five uneven zones (Emberfall Vale 1-3, Thornwood 4-6, Ashen Fen 7-9,
  The Broken Arch 10-12, Crownless Sanctum 13-15) in a 512.7 m square
  (`BOUNDS` 256.3435). Rolling baked terrain, streamed collision, an expanded
  road network, fen ponds, a camp, ruins, a sanctum and a sealed waygate.
- **Mountains:** the square edge of the world rises into a real ridge
  (`RIM_START` 268.34, crest at `RIM_END` 308.34, `RIM_HEIGHT` 32) built from two
  ridged-noise fields, then falls away again at 314.34-331.34 so the mesh edge hides
  behind the crest. No separate cone/crag props remain; rock and alpine colour
  climb with altitude, and a pine belt covers the outer foothills.
- **Biomes:** each zone now has its own `elevation`, `relief`, `tree_count`,
  `rock_count` and `grass_count`, so the fen is a wet lowland, the arch and
  sanctum sit on high ground, and the colour/vegetation change is physical, not
  only painted on the map.
- **Vegetation:** taller Blender trees (oak ~11 m, birch ~11.5 m, pine ~11.8 m,
  dead ~10 m) with smooth-shaded crowns; additional forest and grass continue
  past the zone blobs to the rim; grass
  is a three-card alpha-scissor tuft (`grass_blades.png`) in the thousands per
  zone; rocks and logs are smaller, sunk into the ground and kept two road cells
  clear.
- **Dead trees:** only the Ashen Fen mixes `dead` trees (62 %); every other zone
  uses living oak/birch/pine, so the fen is the one eerie woodland. The exported
  tree GLBs now use a base pivot at y=0, and the loader keeps an AABB-minimum
  lift as a safety net, so no trunk or root flare starts below the terrain.
- **Props in Blender:** bushes, boulders and shore stones are generated by
  `assets/models/props/generate_props.py` and instanced from
  `bush.glb`, `rock_1..3.glb` and `stone_1..2.glb`; the old code-built shrub and
  boulder meshes were removed.
- **Lakes:** three wavy carved bowls in the fen (`(64, 6)`, `(86, 54)`,
  `(110, 36)`), each with a 4-harmonic shoreline, a 0.42 m bank lip and a baked
  water depth in vertex colour. The water shader reads that depth directly, so
  the shallow/deep gradient and foam collar cannot disagree with the terrain.
  The water mesh runs 1.35x past the analytic shore and hides under the bank, so
  there is no exposed rim.
- **Wading:** lakes are for wading only. Movement slows from x0.72 at the
  waterline to x0.32 at the waist and stops at `WADE_MAX_DEPTH` 0.62 m; the
  depth query is the same analytic field that carved the basin.
- **Enemies:** attacks commit to a windup, then use the same reach as the
  telegraph; enemies collide with the player and each other, snap to the
  terrain, spread out, and sidestep after half a second without progress. The
  Hollow Regent only slams while engaged. HP and damage scale with the zone level
  band, and the level is shown next to the name.
- **Audio:** the looping synthesized wind bed was removed. Interaction, combat
  and reward cues remain; the world is quiet between them.
- **Day/night:** a 15-minute in-game day starting at 08:15 day 1, with a clock
  and phase (Dawn / Day / Dusk / Night) in the HUD.
- **Map:** no minimap. `M` opens a square, painted map rendered from the same
  height and colour grids as the terrain: hillshade, 4 m contours, canopy
  density from real tree positions, trunk stipple, ponds and roads, with side
  panels for regions, legend, compass and a 50 m scale bar. No zone outlines.
- **Chat:** bottom-left World / Local / Party / Guild panel with timestamps;
  `Enter` focuses the input and typing does not move the character.
- **HUD:** bare ten-slot skill bar with no frame, clock/menu top right, quest
  journal right, status left, system log bottom right.
- **Visuals:** generated grass/bark/leaf/needle/road textures, Blender low-poly
  trees, softer sunlight shadows, dimmer pools, rebuilt tents and a smaller
  dormant portal.
- **Post-processing:** screen-blended HDR glow on fire, lanterns, runes, the
  portal and creature eyes, plus SSAO contact shadow. Both default on and can be
  switched off under **Settings → Graphics**, persisted in
  `saves/settings.cfg` under `[graphics]` and applied live to the
  `WorldEnvironment`.
- **Diagnostics:** `scripts/game_log.gd`, `Documentation/DEBUGGING.md`,
  `Documentation/IMPLEMENTATION_LOG.md`, `--screenshot` tour (11 frames incl.
  the pond, map, night and frontier), `F10` marker, `F9` log folder, `F12`
  screenshot.
- **Remote watch:** `scripts/dev/check_remote_changes.ps1` reports commits from
  another PC, flags risky edits and appends a report to the implementation log.
  It never edits code; the user must approve any follow-up.

## Verification done

- Headless import and script parse gate: no script or parse errors.
- `tests/test_world.gd`: zones, gentle-but-real terrain relief, terrain rim,
  terrain collision, world bounds, waygate, roads, ponds, day/night, painted map
  texture, no crag props, chat and log all pass. The pond checks now cover the
  wavy shoreline, the carved depth, baked vertex-colour depth and the rendered
  terrain mesh above the waterline. The enemy check proves an in-reach wolf
  winds up before damaging and that a distant boss never starts its slam.
- `test_progression.gd`, `test_combat_effects.gd`, `test_skill_panel.gd`,
  `test_skill_catalog.gd`, `test_skill_runtime.gd`, `test_skill_reset.gd`,
  `test_skill_secondary_review.gd`, `test_skill_chance_debug.gd`,
  `test_animation_selection.gd`, `test_distribution_editor.gd`,
  `test_spear_items.gd` and `test_window_snap.gd` pass.
- Graphics: `test_world.gd` proves glow and SSAO default on, that glow threshold
  and levels are set, and that a live toggle reaches the environment. A
  throwaway probe (deleted afterwards) proved the Settings calls write
  `[graphics]` to `saves/settings.cfg` and that `reset_settings()` restores and
  re-applies both effects. Day and night `--screenshot` frames were inspected
  with the effects on; the daytime frame is not hazed and the night fire carries
  a soft halo.
- `test_hud_snapping.gd` still fails one assertion ("Clear saved placement
  restores without drifting"). It reproduces on the pre-change HEAD in a clean
  worktree, so it is a pre-existing UI-snap bug, not part of this pass.
- `--screenshot` tour inspected at 1600x900; visual defects found in review were
  fixed and re-checked (tree bases, fen-only dead trees, pond shoreline, water
  shine, camp and Thornwood framing).
- Remote-change script tested against the real remote (clean) and a simulated
  external run (report + exit code 2).

## Next steps

1. Push the local commits from GitHub Desktop (the CLI has no stored token).
2. Ask the friend to run the game and confirm the new world, map and chat on
   their machine.
3. In-game check: walk every road branch, confirm the sealed waygate never
   teleports, and confirm Map II is unreachable.
4. In-game check: day/night clock crosses Day -> Dusk -> Night -> Dawn while
   playing; lamps and campfire read at night.
5. In-game check: wade into each fen pond and confirm the waist-deep stop feels
   readable and that the bank never clips through the water.
6. In-game check: pull a wolf onto a slope and a boulder and confirm it sidesteps
   instead of jittering; check the Regent only slams once engaged.
7. Decide whether the local `modifier_list_editor` addon should be tracked or
   kept editor-only. It is currently gitignored.
8. Map II is not built. The waygate is decorative until it is.
9. In-game check: fight wolves and boars at gameplay distance and confirm the
   eyes read, the fur cards hold up, and the bite/gore/charge dodge windows are
   readable. Watch the 13.6k/14.9k-triangle creatures in a full pack.
10. In-game check: walk the camp ring at night and confirm every gate aligns with
    its road, tents can be entered, and the lamp pools are sparse rather than a
    runway.
11. In-game check: confirm no pine stands in the vale, no broadleaf in the
    sanctum, and no cross-family tree on the outskirts.

## Known warnings

- `modifier_list_editor` is enabled in `project.godot` but absent on machines
  that do not have it. This is an editor warning only and does not affect play.
- A headless quit can report 2 leaked ObjectDB instances at exit; tests still
  exit 0 and gameplay is unaffected. Investigate only if the count grows.
- World load timing is logged as `[WORLD] world_ready {"build_ms": ...}`;
  the old procedural startup figures in the historical entries are superseded
  by the baked-world work below.

## 2026-10-28 - Skill stash integration

- Applied the preserved GitHub Desktop stash on the pulled world branch, prioritizing the ten-slot skill catalog, runtime and enchantments. Kept world-scaled enemy damage, the frameless hotbar, world bounds, chat focus and logging.
- The skill runtime currently reports out-of-range targeted skills instead of the former automatic approach. The prior three-branch skill and five-slot rules are superseded in the prototype; the longer-term design remains documented separately.
- The original stash remains available. Progression, combat, skill panel, skill runtime, catalog, secondary damage and world tests passed; a Direct3D 12 test-mode launch completed without script errors. The full import reported missing textures in local source FBX files. Visually review the ten-slot HUD in game.

## 2026-10-28 - Training minion spawner

- Open Options → **Debug Menu** to spawn hostile Briarwolves around the player. Choose 1–30 per batch and level 1–100; the popup shows the active count (maximum 50) and can clear them.
- Training minions use normal level scaling and combat AI, but never grant rewards, advance the bestiary or quest, or respawn. They are temporary and are not saved.
- The popup uses the existing compact bronze frame, ivory labels and window dragging. The referenced forum's popup images were unavailable, so the written UI standard guided the layout.
- Verified with the training minion test, combat effects and world tests, plus a Direct3D 12 popup render. Headless runs report sandbox user-log/certificate errors and the existing ObjectDB exit warning.

## 2026-10-28 - Debug menu

- Options → Debug Menu groups training minions with health/mana recovery, cooldown reset, session-only invulnerability, day/night pause and dawn/noon/dusk/night presets. The toggles start disabled each launch.
- The debug controls and existing combat/world tests passed; the 1600×900 Direct3D 12 layout was inspected.

## 2026-10-28 - Playable debug window and configurable shortcuts

- The debug window no longer blocks movement, combat, camera or channeling; clicking its controls stays within the window. Other panels and the map still block gameplay. Chat focus still blocks gameplay shortcuts.
- Debug shortcuts default to F2 (invulnerability), F3 (restore health/mana) and F4 (spawn the currently selected batch and level). Click a key in the debug menu and press an unused replacement; Esc cancels. Bindings are stored in `saves/settings.cfg` and apply while gameplay is available, including with the debug window closed.
- Verified movement, skill use, rebinding, conflict rejection, text/modal suppression and debug actions in the integration test, plus combat, skill and world tests. The Direct3D 12 layout was inspected at 1600×900.

## 2026-10-28 - Creature, forest, camp, lamp and sky pass

- **Enemy combat** now commits to a world-space point. `scripts/enemy.gd` adds
  `species`, a locked point at windup start, a wolf point bite, a boar point gore
  plus a straight committed charge, and a boss slam on a locked circle. Hit
  tests use the locked point, so stepping off it is a real dodge. Map I normals
  alternate wolf/boar deterministically and respawns keep the species.
- **Creatures** were rebuilt in `assets/models/creatures/generate_creatures.py`
  and `make_creature_textures.py`: UV-unwrapped pelt atlases with fibre noise and
  fine strands, three-part eyes (dark socket, offset amber iris, black pupil)
  with low emission, nostrils, inner ears, claws or cloven hooves, tusks, a
  bristle ridge on the boar, a bushy four-section wolf tail, and alpha-card fur
  clumps (`fur_card.png`). `scripts/actor_visual.gd` swaps the GLB's blended fur
  material for the project's alpha-scissor + coverage material and tints the
  cards per species. Triangle counts are about 13.6k (wolf) and 14.9k (boar).
- **Forest** was rebuilt in `assets/models/trees/generate_trees.py`: one
  continuous lofted trunk with roots and limbs, dense alpha-scissor leaf/needle
  cards, and the same foliage mass on conifers. Zone families are pure
  (vale/thornwood oak+birch, fen dead+pine, arch/sanctum pine); outskirts inherit
  the nearest family. Bushes are card foliage (`bush.glb`, surface 1).
- **Ground cover**: `shaders/grass.gdshader` uses alpha-to-coverage and wind;
  grass, flowers and bushes reject the road ribbon with exact
  `_road_distance()` / `_on_road()` tests. Grass positions are kept in
  `world.grass_points` because a MultiMesh does not return its transforms under
  the headless test driver.
- **Camp**: ring fence with road-aligned gates and gate frames, four walk-in
  tents with ground beds, a rebuilt fire pit with a live flame, two log seats,
  forge/anvil, banners and a road sign. The player spawns inside the ring.
- **Road lamps** are medieval poles on the verge, off the ribbon and off any
  nearby branch, at least 44 m apart, camp roads first, 13 maximum, with omni
  lights dimmed to 20 % in daylight.
- **Sky and clarity**: `shaders/frontier_sky.gdshader` scrolls 3D noise clouds
  with the day/night clock; the sky runs `PROCESS_MODE_REALTIME` at radiance
  256. TAA, debanding and 4x MSAA removed the noise veil and smoothed the grass.
- `tests/test_world.gd` now also checks modelled creatures (triangle count,
  emissive eyes, runtime fur cards), ladder-free road lamps and their lights,
  grass off the road, the grass coverage shader, bush foliage, the camp tents,
  beds, seats, gates and fire, and the realtime moving sky.
- Verified: headless import, all four AGENTS tests, a 300-frame normal launch
  and the 11-frame screenshot tour, all with exit code 0 and no script errors.
- Remaining: Map II is still unbuilt; the waygate stays decorative. In-game
  review should confirm the new creature silhouettes and fur at combat distance
  and the lamp spacing at night on a slower machine.
## 2026-10-28 - Inspect installed enchantments

- Clicking an installed enchantment opens a read-only view of its exact saved effect and rolls. The `+` tile still presents the next stage's choices; inspection changes neither points nor offers. Individual replacement is no longer exposed through installed tiles; Reset All remains available.
- Skill-panel integration checks passed for the first and second installed stages and the `+` picker. The Direct3D 12 inspection window was visually checked at 1600×900.

## 2026-10-28 - Debug panel shortcut

- F1 opens or closes the debug menu during gameplay. Change it under Debug Menu → Keyboard Shortcuts. Existing custom bindings are retained when upgrading; if F1 is already in use, an unused default is selected.
- The debug integration test passed, including opening, closing, rebinding, chat suppression and migrating a conflicting older binding; the Direct3D 12 layout was inspected.

## 2026-10-28 - Authored enchantment tiers

- Enchantments now have authored Basic, Rare, Epic, Legendary and Mythical tiers. The 47 current definitions are classified by their existing effect strength and complexity. Offers and installed-stage inspection show the tier in text, with restrained tier colors; existing rolls and their values remain unchanged.
- Tier names do not apply automatic power multipliers or alter offer weights. Both ranges and distribution remain explicitly authored. Old saved rolls without a tier display their definition's current tier, or Basic when the definition is unavailable.
- Relocated the distribution-editor plugin to `addons/skill_distribution/` so Godot can discover it in Project Settings → Plugins. Restart the editor, enable Skill Distribution Editor if needed, then use Project → Tools → Skill & Modifier Distribution. The catalog's tier field is editable there.
- Catalog, distribution editor, skill UI, progression, combat effects, skill runtime and chance/debug tests passed. The tiered choice window was inspected at 1600×900 under Direct3D 12. The editor window itself could not be visually captured by the computer-use helper; check discovery after restarting the currently open editor.

## 2026-10-28 - Local character selection

- Create a named Human, Orc, Elf, Dark Elf or Dwarf as a Fighter or Mystic; race/class are currently identity only and all characters use the same model and starting gameplay.
- Existing `saves/journey.json` appears as Original journey and stays in place. New characters use separate files in `saves/characters/`. Options → Log out saves and returns to selection. Recover dropped gear and wait for respawn before logout, since ground loot is not persisted.
- Character files are written through a temporary file before replacement. Integration tests cover legacy preservation, new saves, all choices, selected-save routing and logout; the selector was inspected at 1600×900. Normal startup left the original save unchanged.

## 2026-10-28 - Automatic character login

- Normal startup loads the last successfully selected character. With no remembered character, a single existing save is loaded; otherwise the roster opens. Missing, invalid or unreadable last saves return to the roster without overwriting them. Options → Log out still explicitly opens character selection.
- The last-character pointer is stored separately in `saves/last_character.cfg`; character integration, progression and skill-panel tests passed with isolated saves.

## 2026-10-28 - Remote merge

- Fast-forwarded to `69acc1bc` and reapplied the preserved local character, skill and debug changes. The stash remains as a backup. World assets were imported.
- The incoming enemy rules and implementation initially disagreed about direction-locked attacks; the user chose telegraphed attacks, implemented in the following pass.
- Progression, skill panel, skill runtime, combat effects, training minions, characters and world tests passed, as did a normal Direct3D 12 test-mode launch. `test_hud_snapping.gd` retains its documented pre-existing saved-placement failure.

## 2026-10-28 - Direction-locked enemy telegraphs

- Normal, quest and boss basic attacks show a terrain-fitted red cone during their 0.8 / 0.9 / 1.0 second windup. The origin, direction and reach are fixed; only players inside that cone at impact are hit. Dying interrupts the attack.
- The boss slam retains its circular warning and now uses the same 5.5 m radius for its hit check. Combat events log windup and hit/miss.
- World, progression, combat-effects, training-minion and dedicated telegraph tests passed. Direct3D 12 test-mode launch passed; the cone was visually inspected at 1600×900. A 20-cone headless microbenchmark was about 6 ms on this machine after sampling the rendered terrain grid.

## 2026-10-29 - Merge conflict resolution

- Merge local `84a19b1` with remote `c544b2c`. The user chose to retain locked-point attacks for wolves and boars, including the boar charge and the boss's locked slam; the older direction-locked cone description in the implementation history is superseded by that decision.
- Retained the combined character-selection, graphics, enemy combat logging, skill and world changes. Kept the local training-minion test UID and excluded an Effekseer temporary file without deleting it from disk.
- Headless tests passed: enemy telegraphs, training minions, characters, world, progression, combat effects, skill panel, skill catalog, skill runtime and distribution editor. A 300-frame headless test-mode launch exited successfully. Visual playtesting and the previously documented HUD snapping issue remain follow-ups.

## 2026-10-29 - Forest, creatures and local sword

- Regenerated the procedural pine with a continuous tapering crown and enforced 3.2 m tree-center spacing across all placement paths. Original creature models remain available; new Blender-generated rigs add a basic diagonal walking gait and attack head motion. Normal wolf and boar bite/gore warnings and hit checks are confined in front of the attacker; the existing locked-point design and boar charge remain.
- The selected local `journey.json` character now carries an original modeled, longer silver sword inspired by the supplied front-view reference. Its former equipped sword was moved intact to inventory; a pre-change save is in `logs/sword_swap_backup/`. Other character saves were not changed.
- SSAO settings and toggle are connected; a static Direct3D 12 comparison shows contact darkening, while the effect in the forest is subtle. Settings → Graphics now offers 1×, 2× and 3× intensity, with 1× preserving the previous default and the choice saved independently of the on/off toggle. The world test and Direct3D 12 settings preview verified the control.
- Headless sword, enemy telegraph, world spacing, training minion, combat effects, progression and animation-selection tests passed. Godot previews of the sword, pine and creature walk poses were inspected. Creature rigging is approximate and needs interactive movement/combat playtesting; the reference image does not show every surface of the sword. The editor import still emits an existing empty-name diagnostic.

## 2026-10-29 - Streamed vegetation and spawn catch-up

- Vegetation instance buffers are allocated for a buffered 5×5 grid of 48 m cells around the player. Normal, boss and quest spawn slots activate in a buffered 3×3 grid; engaged enemies remain active while chased. Living unloaded enemies retain health and position. Catch-up uses stored respawn deadlines, not per-frame creature simulation, and supports configured boss windows without changing the Hollow Regent's existing unrestricted schedule.
- Boars spawn 05:00–17:30 and wolves 17:30–05:00; the other species is removed at the boundary as requested. World clock, spawn deadlines and slot state save with each local character and pause while the game is closed. The existing normal-kill quest already counted both species, so its text now says so.
- Terrain, landmarks and whole-map procedural placement data still build at startup; this is not full terrain streaming. The starting-area test allocated 26,821 of 35,260 vegetation instances, not an FPS benchmark. The map and terrain stay complete. Measure startup, frame times, memory and boundary transitions on target hardware before claiming a performance improvement; full streaming, asynchronous generation and multiplayer server ownership remain future work.

## 2026-10-29 - Larger authored world and buffered terrain

- The previous entry's startup limitation is superseded. Map I now has three times the former playable area, five level regions distributed around the map, new outer roads and 22 additional normal spawn points. The waygate is at the end of a road near the north-west corner; its sanctum, boss, guardian, fen pools and level-region centers were placed for the new layout. Five small named landmarks are decorative exploration points, not new quests.
- The landscape, roads, vegetation placements, static scenery and painted map are baked offline into `assets/world/`; normal play loads the snapshot instead of rebuilding it. Terrain and collision, vegetation and scenery use buffered cells. Distant low-detail terrain, its fallback collision, roads, water and map metadata remain available globally. With a normal renderer, the loader prepares one nearby cell resource at a time in the background; headless tests use main-thread staging to avoid a dummy-renderer race. Rebuild the authored assets after changing the world design with `Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://scripts/dev/bake_world.gd`.
- Older spawn saves preserve slot identity, deadlines and health when the unique enemies move; stored pre-redesign positions reset to the new homes. New saves retain their current positions. Day/night and offline-pause rules are unchanged.
- Integrity, world, chunk, actual player boundary traversal, character, enemy, training, progression, combat and skill checks passed; the final headless test-mode launch had no script/parse/runtime errors. A Direct3D 12 map and five landmark views were inspected. Import still reports the existing missing local editor addon warning and empty-name diagnostic.
- On this i5-9300HF / RTX 2060, one headless world initialization measurement was about 318 ms for the baked build versus 28.6 s for the offline procedural builder; the baked figure excludes later staged loading and rendering. In a 15-second scripted 1280×720 Direct3D 12 traversal with game logic active, the sampled portion after the first 1.5 seconds averaged about 60 FPS with a 38 ms worst frame, but an earlier frame stalled for about 551 ms. A stationary no-prefetch run also stalled early. Test on slower PCs and investigate the startup stall; this remains a local single-player system, not a server-authoritative MMO.

## 2026-10-29 - Background chunk loading and stutter investigation

- The reported session recorded chunk activations taking as long as 210 ms. Further timing showed synchronous scenery reads taking 321–346 ms. Normal rendering now loads terrain, scenery and vegetation resources in the background, with one request in flight and no synchronous wait when crossing a chunk boundary. Fallback ground and collision remain until the detailed tile arrives. Headless tests retain synchronous staging because the dummy renderer has shown a concurrent resource race. Long activation diagnostics are throttled.
- Chunk tests check fallback collision, detailed collision after loading, and that distant terrain nodes, their meshes and vegetation nodes are freed. A Direct3D test moved the target twice during an outstanding load and verified that the latest neighborhood loaded without activating stale terrain. World, traversal, baked integrity, enemy telegraph and character checks and a headless smoke launch passed.
- In one scripted 1280×720 traversal, comparing the measured portion after the first 1.5 seconds, the 95th-percentile frame time fell from 34.6 to 17.1 ms and the worst frame from 373 to 48.5 ms. A separate 1600×900 run averaged 59.6 FPS in that portion but still had a 124 ms worst frame. Early startup stalls of roughly 0.3–0.5 seconds remain unexplained. Teleporting can temporarily show fallback ground and missing scenery while the new area loads. Interactive gameplay and slower computers still need testing; results are single runs, not guarantees.

## 2026-10-29 - Resource profiling and frame limit

- The reported 154-second session held around 60 FPS but logged several 59–133 ms frames; its log has no GPU utilization or per-process memory measurements. A 1600×900 camp profile showed 25 active vegetation cells with approximately 1,311 trees, 25,112 grass tufts, 619 flowers and 207 bushes; scenery counts vary by location.
- Two soft-shadow cascades now cover 100 m rather than four covering 150 m. A paired stationary Direct3D 12 run on the RTX 2060 measured roughly 16.4–16.5 ms GPU render time and 1,768–1,770 draws before, versus 13.0–13.3 ms and 1,033 draws after. This is one scene on one machine; distant shadows fade sooner and other locations may differ. Camp screenshots were compared. The renderer's reported allocation and working-set samples are not dedicated per-process VRAM measurements.
- Settings → Graphics now offers a live, persistent 20–60 FPS slider with a 60 FPS default and reset. Actual frame rate can be below the cap. A Direct3D run measured approximately 30 and 20 FPS at those limits. Further interactive testing, slower hardware profiling, distant/night shadow review and memory optimization remain.

## 2026-10-29 - Nature assets, terrain detail and spawn-design rule

- The bush and five rock/stone variants were rebuilt with `assets/models/props/generate_props.py` in Blender, with fuller foliage, varied weathered forms and shared color/normal maps. The rock maps are also embedded in each GLB for independent Blender use. Campfire stones use the new models. Ground uses a neutral-tinted, tiled forest-floor photograph and normal map, with tangents in baked terrain. Asset source, author and CC0 license details are in `assets/textures/polyhaven/README.md`.
- Birch and dead-tree bark no longer receive brightening. Grass instances now each contain three differently shaped small clumps, with random rotation, scaling and tint; meadow patch targets were reduced to 90% and wider shoreline exclusion prevents the full patch overlapping water. The former shallow-water grass-like reeds now grow on dry shore. Roads stay clear. The authored world was rebuilt, preserving a pre-change copy in `logs/nature_before_20261029/`.
- An in-engine camp, shoreline and prop preview was inspected; the baked integrity test validates terrain tangents, bush foliage, bark tint, and every recorded meadow and shoreline patch's water clearance. World, chunk and player traversal tests and a headless smoke test were run, plus Direct3D background streaming. In separate stationary camp runs at 1600×900, loaded meadow patches fell from about 25,112 to 22,547; complete-scene GPU render time was 13.0–13.3 ms in the earlier run and 10.3–12.8 ms in the new runs. Other locations, slower systems, and interactive gameplay have not been benchmarked or playtested.
- AGENTS.md and GAME_RULES.md require asking Alin or Stefan about spawn time and map/zone/biome before implementing a new mob, and recording their decision.

## 2026-10-29 - Missing camp after pulling and launch preparation

- The pulled camp files existed, but this PC lacked Godot's local imported copies for new models, textures and fire assets. Before importing, the world test reported missing `.godot/imported` files and missing scenery/camp; the ordinary gameplay log did not capture those engine-level resource errors. Ran headless import, restoring the camp. A Direct3D camp preview was inspected. The world, baked-integrity and chunk checks produced their pass messages without script/assertion or missing-file errors, but retain the previously documented renderer/resource cleanup diagnostics at exit. A separate scan loaded all 72 scenery cells, 196 terrain tiles, 144 vegetation cells and eight shared vegetation meshes; no missing assets were reported.
- Use `PLAY XYLES.bat` to start the game on this PC. The launcher checks an asset/source fingerprint and imported output files, runs Godot import and a world-asset check after changes or missing cache files, and refuses to launch on detected import or world-load errors. A no-change start skips import; first use or an update takes longer. The launcher cannot intercept direct Godot launches. Its fingerprint is metadata-based, so it is not a cryptographic check of asset contents, and not every possible runtime error is caught. Launcher source must be committed and pulled to use it on another computer.
- Verified forced import, unchanged fast path, recovery after temporarily removing an imported camp-model cache file, and an actual 120-frame test-mode launcher start. Import retains the previously documented local editor addon warning and empty-name diagnostic; renderer cleanup diagnostics remain unresolved. The remote-change checker recorded the incoming changes in the implementation log; no incoming game code or world assets were edited.

## In progress: basic attack and sword grip

/attack command added; sword attack grip and end-to-end combat verification remain outstanding.

Basic attack combat test now passes; sword grip remains outstanding.

Per-skill removal now empties one slot and refunds its upgrades; save/reload and re-equipping are covered by tests. Sword grip remains outstanding.

Actions / Human Fighter redesign in progress: F7 Actions and disabled enchantment flags are in place. Human Fighter class redesign, emote animation and reference-quality icon artwork remain unfinished.

Fighter skill-tree request in progress: saved click-to-move option added. Class unlocks, bow weapon and drag/drop remain outstanding.

Fighter milestone definitions added as data only. Skill unlocking, functional bow, draggable hotbar and save migration are still outstanding.

Fighter milestones, level-gated skill view, hotbar assignment and craftable bow prototype are implemented; rendered drag/drop, bow combat and existing-save migration remain to be verified.

All listed Actions accept hotbar drag/drop and persist, with an original dance icon. Automated drop API test passed; mouse-drag visual verification remains outstanding. Social and party actions remain placeholders.

All Actions now have matching pale-blue silhouette icons in the Actions window and hotbar; action and icon-presence tests pass. Small-size visual review is still pending.

Actions and hotbar use original expressive pale-blue icon artwork; the rendered Actions window was reviewed and the action-hotbar test passed.

## 2026-10-28 - Classic UI refresh

Shared metallic frame polish, compact Adventure navigation including Actions, illustrated Fighter milestone cards, compact grouped Actions, XP strip and contextual hotbar guidance implemented. Rendered HUD/Skills/Actions/Inventory inspected at 1600x900. Action-hotbar and Fighter tests pass; legacy enchantment-panel test still assumes enabled enchantments and the former layout and requires a separate fixture update. Existing saved placements are retained; Options > Reset Window Positions restores current defaults.

Status now follows supplied classic reference: compact header, yellow XP percentage, red HP and blue MP with centered values. Rendered and integration checked.

Angled status frame, no bottom spacer, unified 86% panel opacity; clock/chat/region/hotbar now draggable and snapping with saved positions. Expanded HUD snapping and action-hotbar tests pass; rendered layout checked.

2026-10-29: removed Adventure/System Journal HUD, added bottom-right head/Options/window foldout, live character sheet, tabbed Options, diagonal live bar fills and visible snap bounds. Hotbar grip moved right without instruction text. Rendered and corner UI/snapping/action/world tests passed.

## 2026-10-29 - Pull and GitHub Desktop stash reconciliation

- Preserved the pulled AGENTS.md, the incoming world/lighting changes, and the saved local UI, Fighter and action changes. The clock retains its lighting preview and drag registration; Options includes a Graphics tab. The bow and ornate sword visuals coexist.
- Headless world, action hotbar, corner UI, HUD snapping, basic attack, enemy telegraph and ornate sword checks passed. Existing progression and skill-panel tests assume enabled enchantments, while the saved redesign disabled them. The combat-effects and visual-preview/sound tests assume a populated starting hotbar, while the saved redesign starts with empty slots; they failed and need fixtures reviewed against the intended design.
- Headless test-mode launch completed. The rendered test launch failed to initialize Direct3D 12, fell back to Vulkan, then crashed with an illegal instruction in the sandbox; graphical play and audio still need verification. The original GitHub Desktop stash remains available.

## 2026-10-29 - GitHub Git LFS migration

- Git LFS uses the normal GitHub origin endpoint. Existing binary assets and two large runtime animation resources are converted to LFS pointers in a new commit without rewriting history; working files stay intact. Other contributors must install Git LFS before pulling and run `git lfs pull` if needed, then run PLAY XYLES or import assets in Godot.
- Verified all 509 pointers against working-file hashes and local LFS objects; headless world and baked-world integrity tests passed. The GitHub LFS upload and another machine's checkout remain to be verified after pushing. The old Git blobs remain in history.
