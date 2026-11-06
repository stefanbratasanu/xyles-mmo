# CURRENT_WORK.md

Last updated: **2026-10-30**
Branch: `main`

## World editor (2026-10-30)

- Editor navigation now uses WASD/QE over the viewport, mouse-wheel zoom, right-mouse look and Shift speed controls. Ctrl+Z keeps up to 20 session actions, grouping a continuous brush drag; restoring a large terrain state can take time. Zones view overlays the original five regions and custom painted areas with a legend, and describes the existing enemy-level midpoint rule. The zone brush shows a yellow mouse ring and pending cells.
- New Project can start from a copy of the currently applied snapshot or an empty map. Lake placement and brushing carve a shallow basin, blend a dirt shoreline and save that terrain with the draft. Brushed lakes keep separation between banks; moving/scaling a lake afterward does not reshape the shore. Existing spawn requirements and explicit Apply remain in force.
- `XYLES WORLD EDITOR.exe` launches the separate editor using the Godot executable and project assets in the game folder; it is not a standalone export. Map I is the only source map. The interface contains a 3D viewport, free camera, 3D asset and material cards, placement and asset brushes, terrain painting/sculpting, object editing, and a confirmed clear-all operation. New Project, Load Project, Save Draft and Apply to Game are on the top bar.
- Drafts and an independently applied snapshot live in per-user local storage; saving or loading a draft does not change the game. The applied snapshot loads on the next game start and the editor identifies it. Restoring the original map is available in Drafts. Clear-all also removes terrain, roads and lakes, but preserves gameplay spawn definitions; applying requires ground under required spawn locations.
- Custom zones are painted and finished with right-click. They provide starter/enemy/neutral classification and level ranges; existing enemies use their painted zone's levels. They do not create mobs or move player spawns. The existing rule requiring Alin or Stefan's spawn decisions for new mobs still applies.
- Original compound objects such as the camp's shared-collision fence cannot all be edited individually. Original roads and lakes are not editable as individual paths; clear and rebuild to remove them. Edited terrain tiles are loaded together, and painted objects are individual nodes; large edited maps have not been performance benchmarked. See `Documentation/WORLD_EDITOR.md` for controls and limitations. Interactive mouse-driven acceptance remains outstanding because Windows capture timed out; rendered previews and scripted input checks were used instead.
- The editor's draft, terrain, asset, zone, workflow, runtime and game-integration checks passed, as did world, baked-integrity, streaming, traversal, enemy telegraph, progression, combat-effects, skill-panel and action tests. Rendered layout tests and the executable smoke launch passed. Several Godot tests report renderer/resource cleanup diagnostics at exit.

## Forest shafts, stun feedback and aggro behavior (2026-10-29)

- Map I's shafts are restricted to dense tree areas. Their full slanted path is
  checked for trunks, roads, sites and ponds; checks are spread across frames.
  They appear after 10:00 and fade from 16:00 to 17:00. Night clouds fade away.
- Boulder meshes are sunk into sampled terrain as static cells load. Stunned
  creatures display rotating yellow stars above the head, below the health bar.
- Aggro modes are passive (retaliates when hit), territorial (3 m proximity)
  and aggressive (existing longer range). Bars are yellow, orange and red before
  combat respectively, and red in combat. Existing enemies stay aggressive.
- Forest/AI/streaming tests and rendered previews were run; review the effects,
  creature bars and transitions in live play. Origin has newer LFS/UI commits;
  they have not been pulled into this checkout and local edits remain uncommitted.

## Forest collisions, sun shafts and new-character equipment (2026-10-29)

- Baked vegetation cells now create streamed trunk colliders for characters;
  the camera ignores that layer. A boar charge stops on solid obstacles and a
  tree impact stuns it for two seconds. Review navigation and chunk-loading
  performance in an interactive session.
- Removed the separate Blender root spikes and refreshed the shared baked tree
  meshes without regenerating the authored world or its placements.
- New characters start with the ornate silver sword equipped, no other equipment
  or bag items, and zero wood and iron. Existing saves retain their contents.
- Positional audio uses the character's location with the camera's orientation.
  Forest shafts use localized crossed cards, varied in intensity and width,
  follow the sun and fade at night; Graphics can disable them. SSAO's 1×–3×
  levels are stronger and more visible in direct light. Inspect the mix and
  effects while playing and measure performance on target PCs.
- Daytime sky is bluer, with less sky-wide fog and a narrower horizon band;
  distance fog over world geometry remains to conceal streaming boundaries.

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

## 2026-10-29 - Skill modifiers and inventory hover

- Fighter skill cards and skill shortcut tooltips show current computed power and highlight applicable equipment and active enchantment contributions in gold. Disabled enchantments and broken equipment modifiers are excluded; broken equipment's reduced base power is shown.
- Inventory equipment and material descriptions appear immediately on hover and close when the pointer leaves or the window changes. Existing item actions are unchanged.
- Headless modifier/hover, action-hotbar, Fighter-tree and world checks passed. Visual review remains necessary; the previous rendered test launch crashed in this sandbox.

## 2026-10-29 - Hyper3D human fighter draft

- Generated PBR and shaded GLB variants from the supplied fighter reference. Each has about 55k triangles and no skeleton or animations. Both load headlessly in Godot; they are not yet integrated with the player. Visual fidelity, topology, rigging and existing-animation compatibility remain to be reviewed.
- Import also flagged the supplied reference under `addons/`: its `.png` extension contains JPEG data. The original was left untouched.

## 2026-10-29 - Default human fighter

- Hyper3D's generated humanoid-rigged fighter is now the default player visual. Existing character animation tracks drive the new rig through a rest-relative rotation bridge; weapon attachment follows the generated right hand. The original mesh is hidden but its skeleton remains the animation driver.
- Headless retarget, camp seating, animation selection, basic attack and world tests passed. An offline Blender preview of the reference rig and one retargeted run pose was inspected; its generated shoulder skin shows small artifacts. Interactive Godot review of all movement, hand grip, combat and sitting remains necessary, especially since the rigs have different proportions.
- The original JPEG reference was renamed from `.png` to `.jpg`; a subsequent headless import no longer reported that asset error.

## 2026-10-29 - Fighter limb retarget correction

- Corrected the mismatch between the old and generated rigs' rest-pose limb directions, including fingers, and updated the sword mount orientation. Test-mode OpenGL renders of sword idle and multiple walk/run poses were compared with the original player; the grip and pose follow the original more closely.
- Retarget, camp seating, animation selection and basic attack checks passed. Review walking, other weapons, combat and sitting interactively; the generated mesh still has imperfect skinning and different proportions.

## 2026-10-29 - Fighter face and shorts refinement

- The playable model now uses a refined copy of the generated rig: the more accurate face profile is mirrored, the one-sided tattoo is retained, and the abrupt hip/thigh weight split is softened around the shorts. The original generated rig remains available.
- Compared rest profiles in Blender and Godot and sampled test-mode running frames before and after. Retarget, seating and basic-attack checks passed. The pants issue needs an interactive motion check; a subtle neck shading transition is still visible at extreme close-up.

## 2026-10-29 - Two-view fighter regeneration

- Generated a separate Hyper3D Gen-2.5-High fighter using the user's front and side references. The new unrigged PBR and shaded GLBs import and load; the existing playable fighter remains unchanged.
- Blender review found more detailed shorts but rough skin on one side and a distorted opposite mouth profile. The new model has not been rigged or tested in motion; choose or refine it before integration.

## 2026-10-29 - Two-view fighter humanoid rig

- Hyper3D rigged the regenerated fighter in PBR and shaded GLBs. Each has 30,034 vertices and 52 joints; both load in Godot and map to the existing animation bridge in a sampled headless run pose. They remain comparison assets and have not replaced the playable character. Inspect skinning in motion and the previously noted face/texture defects.
- User preference for future generated 3D assets: high-fidelity textures and roughly 20,000–200,000 exported vertices, with actual counts verified.
- Follow-up: rendered the rigged PBR draft in test mode with existing sword idle, run and attack poses. The skeleton and weapon follow the animation bridge, with visible skin deformation around shoulders; movement and full playtesting remain unverified. The playable model has not been switched to the draft.

## 2026-10-29 - Regenerated fighter as player

- The regenerated two-view rigged PBR fighter is now the playable default; the earlier refined fighter remains available. Retarget, camp seating, basic attack and animation-selection tests passed. Sampled idle, run and attack renders were inspected before the switch. Interactive review of movement, seating, weapon grip, shoulder deformation and the known uneven face/skin texture remains.

## 2026-10-29 - Higher-density fighter attempt

- Submitted a new two-reference Hyper3D Gen-2.5-High fighter with 50,000-quad target and texture de-lighting. Job `8ab73a67-c853-47c9-958f-5f464afa4105` completed and is available in Hyper3D; this connected tool does not expose Extreme-High tier or highest texture controls. The output has not been downloaded, visually inspected, rigged or integrated. Existing playable fighter is unchanged.

## 2026-10-29 - User-tweaked playable fighter

- Downloaded the user's edited Hyper3D OBJ and texture maps, then rigged it with a humanoid skeleton and made the PBR GLB the playable fighter. The OBJ has UVs and maps but no material library; the GLB embeds its material and maps, including a 4K diffuse texture.
- Headless retarget, seating, basic attack and animation-selection tests passed; OpenGL test-mode idle and running frames were inspected. Interactive movement, sitting, weapon grip and skin deformation need review. Incoming remote commits remain unmerged; see the remote report.

## 2026-10-29 - Fighter skin normal correction

- The Hyper3D rig's normal map exaggerated skin pores and creases. The playable material now disables that map while keeping its 4K color map; the original GLB is unchanged. Test-mode idle render and retarget test passed. The downloaded source face itself still differs from the reference, and interactive review remains needed.

## 2026-10-29 - Original-skeleton binding investigation

- Compared the animation-pack skeleton (55 bones) with the generated fighter rig (52 joints). A temporary direct binding to the original skeleton produced severe hand deformation and did not improve the face, so it was not applied. The face defect is present in the source mesh/texture; a proper original-rig rebind requires adapting the rest pose and repainting weights, and would not by itself fix the face. The existing playable setup remains.

## 2026-10-30 - Fitted original skeleton experiment

- Tested a more complete temporary fit of the generated fighter to the original animation-pack skeleton, transforming the skin to its rest pose before binding. Sampled idle and running frames no longer had the previous exploding fingers, but the torso became visibly distorted and the source face was not corrected. The experiment was not applied; the current playable fighter remains. A usable conversion still needs manual rest-pose fitting and weight work, and the face needs separate geometry/texture work.

## 2026-10-30 - Fighter rebound to the animation-pack skeleton

- The playable fighter now uses the original character's 55-bone animation skeleton directly. Fitted the generated limbs/fingers to its rest pose while preserving torso/head shape, transferred the original mesh's weights by surface interpolation, relaxed the shoulder transition, and normalized four weights per vertex. The second runtime skeleton and rotation bridge are no longer used by the player; weapons and seating use the original bones.
- Welded UV seam duplicates before smoothing weights, eliminating the visible cracks in the first transfer. The final mesh has 53,975 exported vertices, 100,000 triangles and 53 skin binds; it keeps the user's 4K diffuse and 2K roughness maps. Original source assets remain available. Rebuild scripts and asset notes are in `scripts/dev/fighter_skin/` and `assets/models/characters/human_fighter/native_skin/README.md`.
- Native skin, camp seating, animation-selection (242 clips) and basic-attack checks passed. The new skin test checks normalized weights, equal seam weights, preservation of rest geometry, bounded animated vertices and weapon attachment. Rendered front/side/back idle, walk, run, sword-attack and seated poses reviewed in OpenGL test mode; normal test-mode startup had no parse/runtime script errors. Existing engine shutdown resource warnings persist.
- This resolves the rig compatibility work and is installed as the default. The downloaded face's likeness and baked skin shading remain source-art limitations; a head-smoothing experiment lost eye definition and was deliberately excluded. Full interactive review across all 242 clips and Direct3D 12 remains unverified. The two incoming remote commits remain unmerged.

## 2026-10-30 - Correcting the rejected native-skin conversion

- The user correctly rejected the preceding visual result. The previous completion claim was too strong: tests of bounds and bind indices did not establish visual correctness. Audit found stale normals (including inverted shading directions) and actual torso distortion: the weighted rest fitting moved outer-chest points by up to roughly 12cm and waist points by up to 13cm.
- Replaced the playable character with `anatomy_rig/character.tscn`: original animation-pack 55-bone names/hierarchy, joint rests fitted to the generated mesh, and copied animation tracks with adapted offsets. The generated geometry, normals, UVs and weights are preserved after uniform placement; all 63,990 vertices compare to the source with zero position error. Both main.tscn and the player's fallback character use the new asset. The rejected native_skin asset is retained and marked superseded.
- Added stronger source-anatomy regression checks. Anatomy, seating, animation-selection and attack tests pass. Reviewed idle, walking, running, attack and seated poses in OpenGL and Direct3D 12 Forward+, including low camera angles matching the user's report. The severe stretching/shading errors from the previous conversion are removed. Source facial likeness, tattoo/skin texture defects and automatic skinning quality still have limits; this pass is not a claim that the source art is perfected. Existing renderer shutdown resource diagnostics persist.

## 2026-10-31 - Replacement head and independent body axes (draft)

- Generated a head-focused Hyper3D Gen-2.5-High replacement from the supplied front/profile references. The new eyes and lips read more clearly in neutral front/side reviews. Built an experimental combined source and animation-pack rig under `assets/models/characters/human_fighter/head_revision/`; the playable default remains `anatomy_rig`.
- User clarified two independent axes: five body fat/size levels from very skinny to very fat, and five muscularity levels from no visible muscle to very muscular, making 25 combinations. Added four shared-topology morph endpoints, exported preset properties, and a per-instance shader that reduces baked abdominal detail for softer bodies.
- The 68,987-vertex draft passes `tests/test_fighter_body_shapes.gd` for all 25 combinations, normalized skin weights, finite/bounded geometry and instance isolation. Initial D3D12 grids exposed unacceptable torso/limb discontinuities and surface artifacts; subsequent passes blend displacement with bone weights, smooth endpoints and regenerate normals. Neck shading and extreme-body art still need refinement. Tests are not visual acceptance; no completion claim or default switch. No customization UI/save integration yet.

## 2026-10-31 - Character creator menu connection

- Added APPEARANCE to the character creation form. It opens a live, rotatable 3D preview with independent five-level size/muscularity selectors. USE APPEARANCE accepts; BACK/Escape discards pending changes.
- New-character saves persist the accepted appearance, and loading a customized character applies its mesh, skin and shape choices to the animated player. Legacy characters without appearance data retain their existing model. All race choices still use the human visual; body art remains a prototype.
- Headless and Direct3D 12 character-flow tests pass, including the actual menu button, preview controls, accept/cancel, malformed data/clamping, save/reload and application in the world. Inspected the front-facing creator render. No script/parse errors; existing renderer shutdown leaks persist. No user saves or incoming remote commits were changed.

## 2026-10-31 - Creator asset refinement follow-up

- Corrected neck collar UVs: every collar vertex now samples the body atlas rather than mixing incompatible head/body atlas coordinates. Changed morph relaxation to smooth displacement instead of absolute positions, avoiding unintended shrinkage. Rebuilt the 69,191-vertex combined source and rig.
- Replaced the soft-body shader's coarse 32px-equivalent atlas sampling with a local nine-sample filter. Added a regression ensuring all 25 combinations preserve the head/neck coordinates. Body-shape and character creation/save/load tests pass.
- Reviewed D3D12 all-combination captures and extreme soft-body idle/walk/run/attack/sitting poses through the actual appearance application path. No script/parse errors; existing shutdown warnings remain. The neck color boundary, angular torso shading and low-muscle anatomical realism remain visibly imperfect. A shadows-disabled comparison confirms the broad surface patches are not solely shadow artifacts. These corrections are not final art acceptance.

## 2026-10-31 - Remove the hard neck seam

- Replaced one-sided color multiplication with a localized two-sided neck blend in linear color space; head and body now use the same shader. Smoothed the welded join and recalculated normals to remove the horizontal cut-ring crease.
- Fixed a discovered GLB export issue: the real neck color/mask was in COLOR_1 while Godot read white COLOR_0. The repeatable build now remaps the actual channel. Material initialization now rebuilds per-instance materials from mesh resources and works repeatedly.
- Rebuilt 69,207-vertex character. All 25 shape checks and character creator/save/load tests pass, with new assertions for both surfaces' blend channels and masks. Inspected front/both profiles in D3D12 and sampled walk/run/attack/sitting; the hard neck join is no longer visible in these captures. Source torso/tattoo shading and extreme-body anatomy remain imperfect. No user saves or remote commits changed.

## 2026-10-31 - Rebuild rejected skinny and heavy physiques

- Replaced the rejected stacking of four size/muscle endpoints with 24 complete combination targets plus the neutral basis. Each of the 25 settings now selects a single geometry target, so low size and low muscle cannot compound into stick-thin limbs. The same skeleton, animations, head/neck join and saved 0–4 settings are retained.
- Added `physique_shapes.py` with a continuous soft abdomen, balanced torso/limb volume changes, restrained back/hip expansion and joint tapering. Low-muscle shading now reduces painted abdominal contrast as well as blurring it. Corrected thigh-bone influence on 3,060 upper-abdomen vertices that caused larger bellies to crease with leg motion.
- All 25 shapes pass weight, limb/back, fixed-head/neck, mask, single-selection and progressive waist-width checks. All 150 preset/pose checks pass; maximum CPU rest-bind error is 0.000073m. Character creator/save/load checks pass, including actual selection of the saved shape. Rendered front/profile grids for all 25 and sampled skinny/heavy walk/run/attack/seated poses in D3D12; heavy camp interaction sits and stands successfully. No parse/script errors. Existing renderer-exit resource warnings persist.
- Revised presets are installed for customized characters; restart the running game to load rebuilt resources. Native review captures and a comparison are in `logs/physique_rebuild/`. Underlying generated skin/tattoo/face detail remains rough; these changes address the rejected physique proportions and abdomen definition. No user saves, remote commits or Git history changed.

## 2026-11-01 - Complete the independent character creator and inspection flow

- Restored the specified five body sizes and five muscularity choices. The undocumented three paired builds could silently replace a chosen pair on reopening; that path is removed. All 25 combinations remain exact through preview, accept, cancel, reopen, save/load and entry into gameplay.
- Added an isolated 2x-resolution / 4x-MSAA preview with drag rotation, wheel zoom, full-body/face framing, view reset, and adapted rest/idle/walk/run poses. Portrait framing follows animated head translation. Keyboard focus stays inside the modal; Escape cancels and returns focus to Appearance. Reviewed 1100x650, 1600x900 and 1920x1080 layouts.
- Refined soft builds and fat distribution. A rejected direct shell projection inverted hundreds of front-torso triangles; the installed version uses a continuous spatial fat field instead of hip-weight boundaries. The new orientation regression measures at most 3 reversed front triangles across the 25 builds, compared with 437 in the rejected experiment. Existing head/neck invariance, limb/back and progressive-width checks pass.
- Rebuilt starter garments from continuous sections and smoothed their skin/morph fields. A reversible body coverage mask prevents skin showing through opaque clothing. Outfit inspection restores the full body. The fighter stays bald in preview and gameplay, matching the supplied reference; optional hair geometry is retained but hidden.
- Current asset: 130,937 exported vertices, eight surfaces, original 55-bone animation hierarchy, 4K body / 2K head atlases. No new provider generation was submitted. Updated rebuild instructions in head_revision/README.md.
- Verification: body-shape checks pass all 25 combinations; 150 sampled preset/pose checks pass; source-anatomy/rig checks pass with zero source-position error and about 0.000073m rest-bind error; rendered character-flow/keyboard/save tests pass. Heavy camp sit/stand interaction passes. Native front/profile grids and rendered menu/portrait/motion captures are in logs/character_polish and logs/physique_rebuild. Existing engine shutdown resource/RID diagnostics persist; tested flows contain no script/parse errors or handled runtime ERROR events.
- Restart an already running game to reload the rebuilt resources. Source skin/tattoo detail and likeness remain properties of the generated art; passing geometry/flow tests is not a guarantee of subjective art perfection. No user saves, incoming remote commits or Git history were changed. The remote check found no newer commits; three incoming commits remain unmerged.

## 2026-11-01 - Priority change: five races, male and female, fixed builds

This supersedes the body-customization objective above. The user wants Human,
Orc, Elf, Dark Elf and Dwarf in an original classic Lineage 2 inspired style,
including male and female models. Use one authored build per race/gender until
the race art is satisfactory. Size and muscularity controls are removed; new
characters and the current player render the fixed reference build. Existing
save indices are retained on disk. Gender persists with Male as the old-save
default. The race catalog contains ten entries with explicit readiness status.

Nine new front-reference images were generated and saved under
assets/concepts/characters/races. Pending entries show their own concepts in
Appearance and cannot be created as new playable characters until their actual
3D scene is reviewed. The current Human male remains playable. Existing journeys
remain loadable with the current fallback while race art is pending. These are
reference images, not completed models; no new paid 3D job has been submitted.

Added a resume-safe Hyper3D submission tool, a reusable anatomy-preserving race
rig builder, four-influence/seam-weight normalization, a model/neck/texture audit,
and a Blender armor seed/fitter with barycentric weights, rigid plate binding
and clearance reports. Details and commands:
Documentation/Characters/RACE_AND_ARMOR_WORKFLOW.md. New models preserve their
own PBR materials instead of the Human neck shader. Animation caches now include
rig rest transforms; runtime and preview resolve the same model catalog.

Verified: character save/selector tests and ten-entry race/cache tests pass;
three-size rendered review passes with all ten race/gender previews. Existing
fighter anatomy and camp sit/stand tests pass. Reusable rig smoke build passes
on the existing 63,990-vertex provider body. Raw source auditing caught excessive
bone influences; the normalized copy passes weight/seam/neck checks. Armor seed
and rigid rebind exports pass normalization/seam checks. No user saves or remote
commits changed. Existing engine shutdown resource diagnostics remain.

Outstanding: Hyper3D CLI authorization expired. The first device code expired
without issuing tokens despite browser confirmation; a fresh device flow is
waiting. The nine new 3D models, their rigs, neutral/game-light face and neck
reviews, and animation acceptance are still pending. Do not claim all races are
finished or mark concept entries reviewed. No pull/commit/push was performed.

### Authorization follow-up

The fresh Hyper3D device code also expired while awaiting browser completion.
There is no active login poll or paid generation job. A new device authorization
must be started when the user is ready; do not reuse the expired links/codes.
All independent selector/catalog/armor tooling checks above are complete, but
nine production 3D models and their visual/animation acceptance remain blocked
on this external authorization.


### Completed race installation - 2026-11-01

Supersedes the expired-authorization blocker above. Authorization succeeded;
nine new 3D models and nine rig jobs completed. All ten race/gender entries are
now reviewed and playable: Human, Orc, Elf, Dark Elf and Dwarf, Male and Female.
Each uses one fixed authored build. Appearance opens the actual model with
rotation, face framing and rest/idle/walk/run inspection. Selecting a saved race
installs its own mesh, materials, joint rests and adapted animation libraries.

New models are roughly 50k vertices with actual 2K PBR atlases (4K was requested
but not delivered by the API). Raw exports are retained. Exaggerated provider
normal maps are disabled in the runtime material; no texture upscaling claims.
All nine audits and nine-pose skin checks pass. Character/catalog tests and the
three-size selector render pass; shortest/tallest camp sit/stand checks pass.
Reusable armor seed/barycentric fitting/rigid binding tools are documented in
Documentation/Characters/RACE_AND_ARMOR_WORKFLOW.md and tested on female Dwarf
as well as the prior Human fixture. Seeds still require authored armor design
and animated art review. No completed armor collection or facial/hair animation
is claimed. Existing engine resource/RID shutdown diagnostics persist.

Evidence: logs/race_build/review/all_races.jpg, rendered/*, audit JSONs,
characters_final.log, catalog_final.log, motion_batch1/2.log and seat_*.log.
No user saves, pull, commit or push. Incoming remote work remains untouched.


### Broader regression caveat - 2026-11-01

The character-specific checks above pass. The additional legacy regression run
is not clean: test_progression has 13 evolution/point-conservation/save-point
failures, reproduced with an isolated copy of the untouched HEAD game_state.gd
in logs/race_build/baseline. test_combat_effects asserts at line 35 expecting
12 projectile-landed events, and test_skill_panel reports legacy evolution
installation failures. The combat assertion left its test loop running; that
test process was stopped, and the remaining skill test was bounded. These
failures were not concealed or addressed by changing gameplay rules during the
race-art task. See *_final.log and progression_baseline.log. Do not claim the
entire repository suite passes. Character, race catalog, skin/motion, selector
layout and shortest/tallest seating verification remain passing.

The legacy skill-panel run also stops at tests/test_skill_panel.gd with a null get_theme_stylebox call; it is not a passing UI regression run. The live race selector and character tests above are separate and pass.

### F6 / F7 authoring controls - 2026-11-01

F6 captures the currently playing animation and opens/keeps Animation Selection.
Selecting another clip replaces it immediately on the character regardless of
skill. Repeat F6 recaptures while the window stays open. Stop Override releases
looping replacement; nonloops finish naturally. Save Mapping remains a separate
persistent skill configuration action. These controls only change presentation.

F7 opens live weapon XYZ position (metres) and rotation (degrees), Save Grip,
Reset to Model and Stop Animation. Saved hand-local grips use
resources/characters/weapon_grips.cfg per model / weapon / variant and restore
on equip/reload/model switching. Actions is still available in the corner menu.

Focused controls, rendered controls, existing animation selection and basic
attack checks pass. The older training test fails at its skill-cooldown assertion
before rebinding checks; the earlier broad-suite caveat remains. Test writes are
isolated in logs/weapon_controls_grips.cfg. No real grip settings were created.

### Human male v2 installed - 2026-11-01

Supersedes the retained old Human-male checkpoint: Human male is now rebuilt
from scratch and installed as the default everywhere. Original classic fighter
reference with medium dark hair, clean-shaven natural athletic body, plain dark
training shorts and bare feet. No old synthetic shirt, boots, spliced head or
body-size morphs are part of this default. New scene:
assets/models/characters/races/human_male/character.tscn. All ten entries now use
the same fixed-build PBR/race-character workflow, with individual anatomy.

48,942 vertices, actual 2K PBR atlases, 55 runtime bones. Source/provenance and
raw provider outputs are retained; old assets are inactive historical sources.
Neutral and game-render face/profile/neck/motion review passes, as do the audit,
nine-pose actual-player checks, source-preservation test, creation/save/catalog,
animation, F6/F7, basic attack, three-size selector and Human camp sit/stand.
Previously documented broad legacy skill-test failures and engine-exit resource
diagnostics remain. Relaunch a running game to see the new default.

### Relaxed locomotion and 30 percent slower base - 2026-11-01

Ordinary idle/walk/run now use the Basic Locomotion sources, not fist-combat
cycles or an imaginary shield guard. Sword carries down; greatsword/staff/spear
carry upright. Combat idle is separate and briefly follows attacks, then returns
to relaxed standing after four seconds. Character preview uses ordinary poses.
F6 labels distinguish Relaxed travel and Combat stance; overrides retain priority.

Base movement is now 3.71m/s (30 percent below 5.3), before existing bonuses;
walk/back/crouch caps receive the same scale. Animation playback matches actual
final displacement to measured per-race foot strides, including quicker cycles
for shorter legs. Normal locomotion speed multipliers cannot desynchronize it.
Direction changes retain cycle phase; wall/shoreline/bounds stops do not run
feet in place. This is pace synchronization, not a new terrain foot-IK system.

New build/calibration scripts and RES/JSON outputs are documented in
assets/animations/player_runtime/README.md. Recalibrate after model or travel
animation changes. Relaxed pose/pace, 90 race-motion checks, animation mapping,
creation/save, attacks, F6/F7, seating, world traversal and world-contract checks
pass. Native carry and motion renders were inspected. Existing broad legacy
skill-test failures and shutdown resource diagnostics remain. No user saves,
remote code, pull/commit/push or new external generation charges. Restart game.

### F7 freeze and Fast Align - 2026-11-01

F7 Freeze Animation now holds the current pose/time, including upper-body layers,
and toggles to Resume Animation. A skill ending cannot reset the frozen pose.
Fast Align is click-to-enter: mouse moves hand-local XY and wheel moves Z;
Ctrl-click selects rotation (mouse pitch/yaw, wheel roll). Click/Enter keeps the
pass; Esc/right-click cancels it. Save Grip persists the result as before. Camera
input is consumed and capture releases on finish, panel/context change or exit.
Frozen pose stays until Resume or a new F6 clip/lifecycle reset.

Headless/native Fast Align, existing weapon controls, animation selection and
locomotion pace checks pass. Native panel was inspected; tests use logs fixtures.
No user save/calibration, remote work, commit or push changed. Restart game.

### Fast Align hand editing - 2026-11-01

Right-drag now rotates the weapon without leaving Fast Align; release returns
to the prior mode. Hold Alt to rotate the actual hand/fingers/attached weapon
with mouse XY and wheel Z. Escape cancels the hand and weapon changes together;
click/Enter keeps them, Save Grip persists both. Right-click no longer cancels.
Hand offset uses an animation-safe skeleton modifier and persists per model/
weapon/variant; older files default to zero. Reset/unequip clears it, re-equip
restores it. Headless/native Fast Align and weapon/animation/relaxed-pose checks
pass. Tests write ignored fixtures only. Restart the game for updated controls.

### Diagonal sprint clips - 2026-11-01

Shift+W+A and Shift+W+D now select native forward-left/right sprint clips rather
than straight sprint. Added carry/pole variants and independent profile actions.
Rebuilt the 69-clip travel library and calibrated both new gaits on all ten races.
Normalized input and step phase are preserved. Actual keyboard/physics tests pass
both directions at equal sprint speed with distance-matched playback; animation
selection and directional pose tests pass. Native poses reviewed. Restart game.

### Shift-sprint back-mounted weapon - 2026-11-01

User simplified the request: back mounting applies only to Shift-sprinting.
Removed the rear-hand IK modifier and procedural sheath/draw arm posing from
player and F6 preview. Ordinary running keeps the weapon in hand and uses the
authored arm motion. Shift-sprint attaches a duplicate weapon visual to the back,
with under 1cm bounce and roughly 1-2 degrees of step-synchronized sway. Placement
follows the shoulder/pelvis line to stay against the back during the forward lean.
No generated scabbard. Attachment code never writes bone poses.

Skills/basic attacks are blocked during sprint; leaving sprint keeps the weapon
on the back for one second before returning it to hand and unlocking combat.
Resuming sprint cancels readiness. Active channels stop when sprint starts.
State is transient and resets on death, model/equipment changes; F7 freezes sway.

All ten models pass native/headless placement, subtle jiggle, untouched-arm and
readiness tests. Actual diagonal sprint pace, F7/F6 and animation selector checks
pass. No source animation/stride data, user saves or calibration files changed.
Restart the game to load changes.

### NPC skill learning - 2026-11-01

Torven in Emberfall Camp now opens a dialogue listing all five Fighter skills.
Each entry shows Required level and Locked / Available / Learned. Learn is enabled
only at the required level, near Torven, outside combat. Base training is free;
enchantment points are unchanged. Level 4 Cone Attack can be learned here, then
assigned from Class skills [K]. Crafting remains accessible from the dialogue.
K displays only learned skills; locked and available-but-unlearned entries appear
only in Torven's dialogue. Empty K directs players to Torven.
HUD signatures now include level, class and learned skills, fixing stale status
when levelling with a window open. Level-up and E prompts point to Torven.

Trained abilities persist in learned_skills. Existing equipped Fighter skills
are preserved when loading pre-trainer saves; other eligible skills require
training. Mystic has no authored trainer milestones yet; its existing skills
remain unchanged. NPC/level 1/level 4/locked/repeat/class/range/save/load/migration
checks pass headless and native D3D12; minimum-size dialogue reviewed. Fighter
and character-save tests pass. No user saves modified. Restart to load changes.

### Natural sword idle hand - 2026-11-01

Peaceful carry_idle and short combat sword_ready idles now align the palm with
the forearm with a slight natural bend, instead of forcing the sword blade into
the forearm direction. This removes the extreme sideways wrist bend. Combat
ready now uses the closed sword grip instead of open fencing fingers. Breathing,
shoulder/elbow motion and all movement/attack clips remain authored as before.
Saved F7 grip and hand offsets remain untouched and still apply afterward.

Baked idle-only update; no runtime IK or new arm modifier. All ten race/gender
wrist checks and combat-idle cycle checks pass. Native closeups reviewed with
and without saved calibration. F7 Fast Align and F6 weapon controls pass.
Restart the game to load the updated animation resource.

### Automatic grip, ground contact and developer skill testing - 2026-11-06

Weapon handles now align to each model's fitted hand/finger frame; weapon-local
contact points cover the existing sword, ornate sword, greatsword, staff, spear
and bow. New assets can author a GripAnchor marker. Existing exact F7 saves take
precedence; use Reset to Model followed by Save Grip to replace one with the
automatic fit. Two-handed off-hand contact remains animation-authored.

Grounded locomotion samples each model's skinned sole and uses bounded leg IK on
the rendered terrain, including original raised road/camp overlays. Swing feet,
jumps, actions, seating and overrides keep their authored pose. DEV on the left
edge enables a temporary all-skills palette. Drag onto the hotbar to test; exiting
restores the original loadout, and normal saves retain that original loadout.

The ten character rigs and six weapon variants pass contact-frame checks; all
ten have idle sole-contact checks on uneven terrain. Live physics traversal,
solver, test-mode save/restore and drag/drop tests pass. World, camp seating,
weapon controls, sprint weapon, trainer, action-hotbar and animation selection
tests pass. Native Direct3D starter-sword/feet and developer-panel views were
reviewed; the other 59 model/weapon pairings were checked geometrically, not
individually art-reviewed. Ground correction is bounded and does not solve steep
steps, off-hand grips or unusual future rigs/assets automatically. Existing
shutdown renderer/resource diagnostics persist. Restart the game to load changes.

### Mesh-measured grip, visible ground and color previews - 2026-11-06

Follow-up to the reported floating and misplaced sword: the palm marker now
samples each model's hand-weighted mesh near the fingers, and the ornate sword
marker is centered on its measured handle rather than near its pommel. Native
front/back closeups show the handle through the Human hand; other race/weapon
combinations have geometric checks but not full art/motion review. Saved exact
F7 overrides remain in force. The 1 mm foot target and actual interpolated
road/camp triangle heights reduce the prior excess clearance; a sole uses the
overlay height at its foot and samples terrain across the footprint.

Living-tree shaft anchors now come from actual branch vertices, or needle-canopy
vertices for pines with no branch mesh. They pivot around their canopy anchor as
the sun moves and retain the existing time window and clearance rules. DEV →
COLOR offers six temporary world-only grades including Original; disabling DEV
resets the preview. `Documentation/VISUAL_DEVELOPMENT.md` records the workflow,
Godot references and limitations. The frame-time microcheck for the new foot
sampler was approximately 0.51 ms per call on this machine in headless test
mode, not a whole-game benchmark.

Ground overlay interpolation, ten-race contact/weapon anchors, moving traversal,
forest ray geometry/schedule, developer mode, F7 Fast Align, world and edited
terrain checks passed. Direct3D screenshots of the grip, ground, forest shafts
and grades were reviewed. Existing renderer/resource shutdown diagnostics remain.

### Steel Strike, damage and character inventory - 2026-11-06

Steel Strike is a learned sword skill available in K and DEV → SKILL. It uses a
dedicated existing sword animation clip, an editable Effekseer slash/impact, and
a delayed single-target hit. Its 120% damage uses the same 1–3 base plus weapon
roll as basic attacks; the common ornate starter sword contributes 5–9. Existing
ornate swords migrate without losing modifiers. Other skills still use their
previous formulas. I opens the combined character stats/equipment/inventory view.

Focused damage, cooldown, range, hit timing, DEV drag, learned skills and save
migration tests pass, as do basic attack, Fighter tree, developer mode, hotbar,
inventory tooltip and animation tests. Direct3D captures of the impact and the
combined panel at 1600×900 and 1100×650 were reviewed. The older skill-catalog
test still expects disabled legacy enchantments and does not pass; existing
renderer/resource diagnostics occur on shutdown. Restart to load these changes.

### Heavy Strike and automatic attacks - 2026-11-06

Heavy Strike deals 200% of a rolled attack, costs 10 mana, and has a 5 second
cooldown. It is learned by both classes, visible in K and DEV → SKILL, and uses
an overhead two-hand arm solver layered over an authored full-body attack plus
its own editable Effekseer impact. Both strikes have new image-generated icons;
the character/inventory panel no longer shows individual skill damage.

Right-clicking an enemy engages mana-free repeating basic attacks while in range
and ready. Dragging right mouse continues to rotate the camera. Attacks pause for
skill animations, channels, sitting, sprint/readiness and modal UI. Out-of-range
targets are not chased automatically. New tests cover click versus drag, damage,
mana, cooldown, distance, impact and DEV assignment; related skill, hotbar,
animation and sprint tests pass. Ten character rigs were checked geometrically
for overhead arm placement, and the Human animation and effect were reviewed in
Direct3D. Finger wrapping and every race's appearance in motion are not fully
art-reviewed. A live four-second test delivered five auto-attacks at zero mana.
Existing shutdown resource diagnostics persist.
