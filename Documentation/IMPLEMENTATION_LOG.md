# Implementation log

This is the **engineering memory** of Xyles MMO. It is not a changelog of
player-facing features and it is not a replacement for `CURRENT_WORK.md`.
`CURRENT_WORK.md` says what is true *now*; this file says *what we changed,
why we changed it, what we verified, and what could still break*.

Every work pass that touches gameplay, world data, UI layout, persistence or
tooling gets an entry here. Entries are newest first.

Sections titled **Remote changes from another machine (automatic)** are written
by `scripts/dev/check_remote_changes.ps1`. They are evidence, not decisions:
read them, then ask the user before keeping, adjusting or reverting anything.

## How to write an entry

Use this shape and keep it short:

```markdown
## YYYY-MM-DD - short title

**Intent.** One or two sentences: the problem or request.
**Changed.** Files and the specific behaviour that changed.
**Why this way.** The decision and the alternative that was rejected.
**Verified.** Commands run, tests passed, in-game checks.
**Risk / follow-up.** What to watch and what is deliberately unfinished.
```

Rules:

- Append a new entry instead of rewriting history. If a later pass fixes an
  earlier one, add a follow-up entry that points at the old date.
- Mention generated assets and their source script (`assets/models/trees/...`,
  `scripts/editor/...`) so they can be regenerated.
- If a change was reverted, say so and say why.
- If an entry is still in progress, mark it `(in progress)` in the heading.

## 2026-10-28 - Forest, enemy and lake correction pass

**Intent.** The fen's dead trees had spread into every biome, trees sat half
buried, the synthesized ambience was a constant hiss, mobs missed attacks and
clipped through each other, and the lakes were flat discs that cut through the
terrain.

**Changed.**
- `scripts/world_builder.gd`: removed `dead` from every zone except the fen
  (`dead: 0.62`); added a base-pivot lift from the mesh AABB so a stale GLB
  cannot bury a tree; replaced code-built bushes/boulders with the generated
  `assets/models/props/*.glb`; rebuilt the three lakes as 4-harmonic carved bowls
  with a 0.42 m bank, water mesh 1.35x past the analytic shore, and analytic
  depth baked into vertex colour; the map now paints water from the rendered
  height at each pixel.
- `shaders/water.gdshader`: new depth-gradient water with world-space ripple
  normals, foam collar, reduced fresnel and a matte sheen (a mirror plane under
  the overcast sky read as grey glass).
- `scripts/player.gd`: wading slow-down and the 0.62 m `WADE_MAX_DEPTH` stop,
  reusing `world.water_depth_at()`.
- `scripts/enemy.gd`: committed windup + strike, reach-matched damage test,
  collision mask `1|2|4`, floor snap, crowd separation, stuck sidestep, and the
  boss slam gate on `aggro`.
- `scripts/audio_director.gd`: removed the looping noise/wind bed. Interaction
  cues remain.
- `assets/models/trees/generate_trees.py`: base pivot at y=0, root flare, stacked
  tapered trunk, dense foliage clumps, jagged/drooping pine tiers. Regenerated
  `tree_oak.glb`, `tree_birch.glb`, `tree_pine.glb`, `tree_dead.glb`.
- `assets/models/props/generate_props.py`: new generator for `bush.glb`,
  `rock_1..3.glb`, `stone_1..2.glb`.
- `scripts/main.gd`: added the `11_pond` screenshot and re-framed the camp and
  Thornwood shots so canopies no longer hide the subject.
- `tests/test_world.gd`: pond checks for wavy shoreline, carved depth, baked
  colour depth, and rendered terrain above the waterline (plus a
  `_rendered_height()` bilinear sampler); an enemy-AI section proving the windup
  and the boss aggro gate.

**Why this way.** Dead trees are a biome signal, so the fix belongs in the zone
table rather than in placement jitter. The AABB lift stays after the exporter
fix because it costs nothing and protects hand-made or stale GLBs. Baked depth
was preferred over the screen-depth texture because the procedural mesh has no
tangents and the depth buffer path was unstable at every renderer setting. The
enemy rewrite keeps the old detection/leash numbers, changing only the commit
window and physics so fights remain readable without becoming slower.

**Verified.**
- `--headless --path . --quit-after 300` and `--import`: no script, parse or
  shader errors.
- `tests/test_world.gd` passes, including the pond and enemy-AI sections.
- All other `test_*.gd` suites pass except `test_hud_snapping.gd`, which fails the
  same assertion on pre-change HEAD in a clean worktree.
- `--screenshot` tour regenerated at 1600x900 and inspected: `01_camp`,
  `03_thornwood`, `04_ashen_fen`, `05_broken_arch`, `06_sanctum`, `07_waygate`,
  `08_camp_night`, `09_world_map`, `10_frontier`, `11_pond`.

**Risk / follow-up.** Enemy AI and wading are logic-tested and visually checked
but not yet playtested on a slope/boulder fight; the water sheen is intentionally
matte and may need a small boost on a clear-sky setting. `test_hud_snapping` is a
separate pre-existing UI bug.

## 2026-10-28 - Chat moves to the bottom-left

**Intent.** The friend wanted the MMO chat where the old system journal sat
(bottom-left), so the conversation panel sits beside the skill bar and the
bottom-right returns to being secondary information.

**Changed.**
- `scripts/game_hud.gd`: `_build_chat()` now places the panel at `(12, -238)`
  anchored bottom-left (360x238, 12 px margins); `_build_log()` moves to
  `(-362, -193)` anchored bottom-right (350x181) and registers as
  `"system_log"` instead of `"journal"` so stale saved positions cannot drop it
  under the chat.
- `scripts/world_builder.gd`: `_portal_ring.rotation.x = PI * 0.5` so the torus
  wraps the upright portal disc instead of lying flat like a bowl.
- `AGENTS.md`, `GAME_RULES.md`, `Documentation/UI_STANDARD.md`,
  `CURRENT_WORK.md`: chat bottom-left, log bottom-right.

**Why this way.** A straight swap keeps every screen corner used and leaves the
top-right clock/menu/quest stack untouched. Renaming the journal window id was
preferred over versioning the whole layout file because `saves/ui_layout.cfg` on
this machine only stores `skills`, `forge` and `inventory`, so no player layouts
are lost.

**Verified.** `--screenshot` tour at 1600x900: chat bottom-left, log bottom-right,
no overlap with the bare hotbar; waygate ring now upright. `test_world`,
`test_progression`, `test_combat_effects`, `test_skill_panel` exit 0;
`tests/_parse.gd` reports `failures=0`.

**Risk / follow-up.** At the 1100x650 minimum window the 238 px chat can touch
the left edge of the hotbar; at 1600x900 there is clear space. The chat panel is
not draggable (only the log is); if the friend wants to move it, register it as
a floating window with its own id.

## 2026-10-28 - Remote-change watcher

**Intent.** The project is shared, so `origin/main` can receive commits made on
the other developer's PC. We need to notice those changes, understand them and
decide what to keep, adjust or undo - without silently editing someone else's
work.

**Changed.**
- Added `scripts/dev/check_remote_changes.ps1`. It fetches `origin/main`, lists
  commits since its own checkpoint (`logs/remote_check_state.json`, gitignored),
  marks commits authored elsewhere or missing from local `HEAD`, and reports
  author, date, subject, files and diff size.
- Risk heuristics: changed core files, deleted files, unknown addons, executable
  files, conflict markers, `TODO`/`FIXME`/`breakpoint`, `push_error`/`assert`.
- It appends a dated **Remote changes from another machine (automatic)** section
  to this file with proposed keep / adjust / revert actions and an explicit
  "awaiting the user's decision" status.
- It never edits game code or reverts anything. `-ParseCheck` optionally imports
  the fetched tree in a temporary worktree to catch parse errors.
- Documented the workflow in `AGENTS.md` (first five minutes, 3a, definition of
  done) and `Documentation/DEBUGGING.md`.

**Why this way.** The checkpoint makes repeated runs quiet, and the report lives
in the same engineering memory the agent already reads before touching a system.
A dedicated worktree parse check is opt-in because a full import is expensive on
a shared machine.

**Verified.** Ran against the real remote: a clean run reports "no new commits".
A simulated external run (older checkpoint plus a different author identity)
produced the expected report, exit code 2 and no code changes. Restored the log
afterwards so no fake report is committed.

**Risk / follow-up.** The script cannot see a commit that was pulled before the
checkpoint advanced; run it *before* pulling. No remote commits have arrived
yet, so the first real report is still untested against the friend's style.

## 2026-10-28 - Map I world overhaul

**Intent.** Replace the flat baked arena with a real five-zone, rolling 3D
continent; remove the minimap in favour of a full-screen `M` map; add a
day/night cycle, MMO chat, softer sunlight, generated nature textures and
Blender-built low-poly trees.

**Changed.**
- `scripts/world_builder.gd` is the single source of truth for zone shapes,
  terrain height, roads, water, props, spawn points, the sealed waygate and the
  day/night lighting. `scenes/main.tscn` no longer bakes a flat world.
- Five zones: Emberfall Vale (1-3, central), Thornwood (4-6), Ashen Fen (7-9),
  The Broken Arch (10-12) and Crownless Sanctum (13-15). Zone shapes are wavy
  blobs; one table drives terrain, ground colour, enemy levels and the map.
- Real height field with `create_trimesh_collision()`, 34-edge branched road
  network with alpha-feathered ribbons, three fen ponds, a survivor camp, a
  broken arch and a sanctum, plus a distant mountain ring and boundary bodies.
- Generated textures live in `assets/textures/` and are produced by
  `scripts/editor/generate_nature_textures.gd`.
- Low-poly trees live in `assets/models/trees/` and are produced by
  `assets/models/trees/generate_trees.py` (Blender background mode, no render).
- `scripts/world_map.gd` draws the full-screen map from the same zone, road,
  pond and landmark data as gameplay.
- `scripts/game_hud.gd` gains the clock, chat panel, bare hotbar and map
  control; the minimap is removed. `M` is the map, `Enter` focuses chat and
  `F8` mutes audio.
- `scripts/enemy.gd` scales HP and damage by the zone level band.
- `scripts/player.gd` clamps to `world.BOUNDS`, recovers from falls and ignores
  movement while chat is focused.
- `scenes/main.tscn` reduced to GameState, Player, CameraOrbit, CombatEffects,
  HUD and Audio; the world is built at runtime.
- Added `tests/test_world.gd`, the `--screenshot` tour (including the map and a
  night frame) and `F12` screenshots.

**Why this way.** Zone blobs with a wavy radius keep the regions uneven but
comparable, and one definition serves gameplay, terrain colour, enemy level and
the map. Terrain height is a pure function shared by the render mesh, collision
and every prop, so nothing floats. Camera-facing art was rejected for the terrain
because it cannot produce rolling ground or real shadows.

**Verified.**
- Headless import and `--check-only` on the touched scripts: no parse errors.
- `tests/test_world.gd` passes: 5 zones with the expected level bands, finite
  rolling terrain, terrain collision, the sealed waygate inside the sanctum,
  20+ branched roads reaching every zone, fen-only ponds, day/dusk/night phases,
  the full-screen map, four chat channels, typing blocking movement, and the
  runtime log containing boot, world and combat entries.
- `test_progression.gd`, `test_combat_effects.gd` and `test_skill_panel.gd`
  still pass.
- `--screenshot` tour inspected at 1600x900: camp, vale road, thornwood, fen,
  broken arch, sanctum, sealed waygate, world map and night camp. Fixed during
  review: white grass shards, cyan ponds, oversized portal, mirrored waygate
  plaque, benches-as-tents, hidden camp sign text, floating junction discs,
  unreadable region label, missing chat panel and a mountain that swallowed the
  waygate camera.

**Risk / follow-up.** The world is rebuilt on every launch (about 0.4 s), so
nothing in `main.tscn` may depend on baked `World` children. The map is
read-only; fast travel is deliberately not implemented. The waygate is
decorative and must never open until Map II exists.

## 2026-10-28 - Runtime diagnostics and implementation memory

**Intent.** When a glitch happens we need to know what was changed beforehand
and what the game was doing at that second, without relying on memory or a
screenshot.

**Changed.**
- Added `scripts/game_log.gd`: one text log per run in `res://logs/`, with
  categories `BOOT`, `GAMEPLAY`, `COMBAT`, `UI`, `WORLD`, `STATE`, `ERROR`,
  `PERF` and `MARKER`.
- The log records the engine version, OS and scene at boot; zone, position,
  HP/mana, target and FPS in every snapshot; and a session summary on exit.
- `F10` writes a marker block with a full snapshot. `F9` opens the log folder.
  Signals and slow frames (over 50 ms) are recorded automatically.
- Added `Documentation/DEBUGGING.md` (how to inspect a run) and this file.
- `logs/` is gitignored. Logs never feed back into gameplay state.

**Why this way.** A single append-only text file is readable by humans, by
PowerShell and by an AI agent, survives a crash, and needs no server. Godot's
`user://` folder is hard to find on Windows, so development builds write into
the project folder instead.

**Verified.** Headless smoke run creates `logs/session_*.log` and
`logs/LATEST.txt`; the session contains boot, world and session-end entries.

**Risk / follow-up.** Logging is file I/O, so it is buffered and capped at 8 MB
per session. Keep heavy per-frame data out of it; use markers and events.

## 2026-10-28 - Forest biome, terrain mountains and painted map

**Intent.** The first 3D pass still read as five green blobs on a lawn: cone
mountains floated at the edge, props hovered or sank, the grass looked like
spikes, the trees were short and blobby, and the map was traced zone outlines.
This pass makes Map I a real forest continent: larger, physically varied,
grounded, ringed by mountains that are part of the terrain, and mapped from the
land itself.

**Changed.**
- The world is now 296 m across (`BOUNDS` 148, `TERRAIN_EXTENT` 224,
  `TERRAIN_SEGMENTS` 288). Zone centres, radii, spawns, roads, ponds, resources
  and tour coordinates were scaled x2.
- Mountains are a rising terrain rim: `RIM_START` 160, crest at `RIM_END` 200,
  `RIM_HEIGHT` 32, driven by `_ridge` plus a high-frequency `_ridge_detail`, then
  falling away at 206-223 so the square mesh edge hides behind the crest. The
  old `DistantCrag`, `DistantSnow` and `FarPine` cone props are gone; a 900-
  attempt pine belt at 140-170 m covers the foothills.
- Terrain relief is gentle rolling forest (`_hills` 3.1, `_detail` 0.62), and
  each zone has its own `elevation`, `relief`, `tree_count`, `rock_count` and
  `grass_count` (vale 0.0, thornwood 0.9, fen -1.6, arch 3.0, sanctum 4.2).
  Rock colour starts at 11 m and alpine stone at 34 m.
- Vegetation: 760 outskirt trees and 7000 outskirt grass tufts continue the
  forest past the zone blobs to the rim. Grass is a three-card alpha-scissor
  tuft using `grass_blades.png`, 1900-8500 per zone. Bushes are a five-puff
  clustered mesh. Rocks are smaller and sunk (`at.y -= size.y*0.16`), logs use
  the absolute ground height, and both keep two road cells clear.
- Trees were rebuilt in Blender: smooth-shaded foliage, many small clumps
  instead of a few giant spheres, oak ~11 m, birch ~11.5 m, pine ~11.8 m, dead
  ~10 m; in-game scale 0.92-1.34 and 0.22 m sunk.
- The Broken Arch and Crownless Sanctum were moved to their scaled coordinates
  and added to `_sites`, so their pads are flat and tree-free.
- `map_texture()` now paints the map from the cached terrain height/colour
  grids: hillshade, 4 m contours, a blurred canopy-density mask built from real
  tree positions, trunk stipple, ponds and roads. `scripts/world_map.gd` draws it
  as a square with regions, legend, compass and a 50 m scale bar; zone polygons
  and outlines are gone.
- Camera far plane 420 and shadow distance 150. The screenshot tour gained a
  tenth frame (`10_frontier`) and several framings were adjusted.
- `tests/test_world.gd` now asserts gentle-but-real relief (2-24 m), the terrain
  rim, `BOUNDS >= 140`, a painted map texture and the absence of crag props.

**Why this way.** Terrain height is one pure function, so the rim, collision,
rock colour and prop placement cannot disagree. The map is rendered from the
same grids instead of tracing zone blobs, which was the original complaint. An
outskirt vegetation pass was preferred over enlarging the zone radii because the
zones must keep their level bands and identities while the forest still reaches
the mountains.

**Verified.**
- Parse gate `tests/_parse.gd`: `failures=0`.
- `tests/test_world.gd`, `test_combat_effects.gd`, `test_progression.gd` and
  `test_skill_panel.gd` pass with exit code 0.
- The 10-frame `--screenshot` tour was inspected repeatedly at 1600x900: camp,
  vale road, thornwood, fen, broken arch, sanctum, waygate, world map, night
  camp and frontier. Fixed during review: floating and sunken props, boulders in
  the road, an empty outer lawn, a tree inside the rim camera, map zone traces,
  and the sanctum/arch standing in the forest.
- `world_ready` logs about 2.5 s of build time with ~2,000 trees and ~31,000
  grass tufts.

**Risk / follow-up.** Build time grew from 0.4 s to about 2.5 s; if it becomes
annoying, the grass placement rejection loops are the first thing to optimise.
The 640 px map texture is generated lazily on first open and cached, so the first
`M` press can hitch. The waygate is still decorative.

## 2026-10-28 - Integrate skill stash with forest world

**Intent.** Apply the local skill, animation and editor work on top of the pulled forest world, prioritizing the skill implementation while retaining compatible world and HUD changes.

**Changed.** Resolved enemy, HUD, main, player and test conflicts. The skill runtime and ten-slot loadout are retained, with a frameless hotbar; area damage retains zone scaling, landing uses the selected animation profile, and world bounds, chat focus and diagnostic events remain. Updated the world test and current rules for the skill prototype.

**Verified.** After importing, progression, combat effects, skill panel, world, skill runtime, skill catalog and secondary damage tests passed; world was rerun separately to avoid concurrent LATEST.txt contention. A normal Direct3D 12 test-mode launch exited successfully without script errors, and its runtime log recorded boot and world construction. The import completed but reported missing textures in local source FBX files; the sandbox also could not write Godot user settings/logs. A normal launch outside the sandbox used Direct3D 12 successfully.

**Risk / follow-up.** The new skill runtime reports out-of-range targets instead of automatically approaching them. The ten-slot HUD needs an in-game visual review at the intended resolutions. The original GitHub Desktop stash is retained; generated UID/import files and an Effekseer temporary file are not part of the conflict resolution.

## 2026-10-28 - Hostile training minion popup

**Intent.** Provide a temporary combat testing tool for spawning multiple hostile minions at a chosen level.

**Changed.** `scripts/game_hud.gd` adds an Options entry and compact draggable popup with spawn-count and level sliders, a live active count, spawn and clear controls. `scripts/main.gd` spawns normal hostile Briarwolves at terrain height around the player, reusing zone level scaling, with 1–30 per batch and a 50-active cap. Training kills bypass rewards, progression and respawns; clear removes only training minions. `tests/test_training_minions.gd` covers controls, scaling, terrain placement, reward isolation, cap and clearing.

**Visual decisions.** The reference topic was reachable, but its popup images were unavailable. Followed `Documentation/UI_STANDARD.md`: compact layout, dark interior, bronze frames and ivory labels, using the existing overlay and helpers.

**Verified.** The new test passed headless and under Direct3D 12; its popup screenshot was inspected at 1600x900. `test_combat_effects.gd` and `test_world.gd` passed. The runtime log recorded training spawn, defeat and clear events without game errors. Headless sandbox runs reported user-log and certificate access errors and the known two ObjectDB leaks on exit.

**Risk / follow-up.** Spawned enemies are temporary and can attack immediately; they are not persisted. High levels and large groups can be lethal and may affect performance.

## 2026-10-28 - Debug menu for combat and world testing

**Intent.** Group the existing training spawner with useful debug controls in one in-game window.

**Changed.** `scripts/game_hud.gd` exposes Options → Debug Menu with the existing minion controls, recovery and cooldown buttons, an invulnerability toggle, world-time pause and dawn/noon/dusk/night presets. It reuses the existing compact bronze window and card helpers. `scripts/main.gd` owns the actions, logs them, restores equipment-adjusted maximum vitals, clears channel cooldowns safely, and keeps invulnerability and time pause disabled by default and out of saves. `tests/test_training_minions.gd` exercises these actions and the previous minion behavior.

**Verified.** Debug-menu integration test passed headless and under Direct3D 12; the popup was visually inspected at 1600×900. `test_combat_effects.gd` and `test_world.gd` passed. The headless sandbox reports user-log/certificate access errors and the known two ObjectDB exit leaks.

**Risk / follow-up.** Vitals restored through the menu are normal game state and may be included in an ordinary save. Debug invulnerability, paused time and temporary minions are not persisted. Resetting cooldowns stops an active channel.

## 2026-10-28 - Nonmodal debug tools and key bindings

**Intent.** Allow gameplay with the debug window open and let the player bind the three frequently used debug actions.

**Changed.** `scripts/game_hud.gd` separates window visibility from blocking gameplay, retains map/other panel and text-input protection, consumes clicks on the debug frame, and provides rebinding controls with Escape cancellation. `scripts/main.gd` routes configurable physical-key shortcuts, avoids collisions with gameplay or other debug bindings, ignores shortcuts during chat and blocking panels, and persists keys in settings. Defaults: F2 invulnerability, F3 restore vitals, F4 spawn configured training minions. `scripts/player.gd` and `scripts/skills/skill_runtime.gd` use the gameplay-blocking check so movement and channels continue with the debug window open. `tests/test_training_minions.gd` covers movement, skill use, rebinding validation, settings loading, shortcut actions and input suppression.

**Verified.** Integration test passed under Direct3D 12 and its 1600×900 layout was inspected. Skill runtime, skill panel, combat effects and world tests passed. Runtime diagnostics recorded key changes and debug actions without game errors. Headless sandbox runs reported user-log/certificate access errors and the known ObjectDB exit warning.

**Risk / follow-up.** Shortcuts operate outside the debug window whenever gameplay input is available. Rebinding accepts unused single physical keys only; modifier combinations and existing gameplay bindings are rejected. Window positions and bindings are saved separately.

## 2026-10-28 - Creature, forest, camp, lamp and sky presentation pass

**Intent.** Make Map I read as a believable action game rather than a prototype:
enemies that commit to attacks the player can dodge, animals with real eyes and
fur, forest and camp set dressing that holds up close, and a sky and ground that
are not noisy or flat.

**Changed.**
- `scripts/enemy.gd` adds `species` and world-space committed attacks. A wolf
  locks a point and bites it; a boar locks a point, gores it and can charge down a
  straight lane; the boss slams a locked circle. Damage tests the locked point,
  so a sidestep or a step back is a real miss. Map I normals alternate wolf and
  boar and keep their species on respawn; there are no AoE or cone attacks on
  normals.
- `assets/models/creatures/generate_creatures.py` and
  `make_creature_textures.py` rebuild the wolf and boar: UV-unwrapped pelt atlases
  (isotropic fibre noise, per-pixel strands, neutral palettes), three nested eye
  spheres (dark socket, offset amber iris, black pupil) with low emission instead
  of glowing headlights, nostrils, inner ears, three-claw paws or cloven hooves,
  tusks, a bristle ridge and two side rows on the boar, a deeper wolf muzzle and
  brow, and a four-section bushy wolf tail. Fur is a dense alpha-card tuft
  (`fur_card.png`) placed as crossed quads; `scripts/actor_visual.gd` overrides
  the GLB's blended material with the project's alpha-scissor + alpha-to-coverage
  material and tints the cards per species. The old opaque cone tufts read as
  porcupine quills and were removed.
- `assets/models/trees/generate_trees.py` now exports one continuous lofted trunk
  with roots and limbs and dense alpha-scissor leaf/needle cards; conifers carry
  the same foliage mass as broadleaf crowns. Zone tree tables are single-family:
  vale/thornwood oak+birch, fen dead+pine, arch/sanctum pine only, outskirts
  inherit the nearest zone family.
- `bush.glb` was rebuilt with card foliage (surface 0 bark, surface 1 leaves) and
  the loader assigns the leaf-card material to surface 1.
- `shaders/grass.gdshader` uses alpha-to-coverage plus world-space wind, with 4x
  MSAA and TAA/debanding in `project.godot`. Grass, flowers and bushes reject
  the road with exact `_road_distance()` / `_on_road()` tests.
- `scripts/world_builder.gd` rebuilds the camp: a fenced ring whose gates are
  cut where roads enter, four walk-in tents with ground beds, a stone-ringed fire
  pit with a live flame, two log seats, forge/anvil, banners and a road sign, with
  the player spawn inside the ring. Road lamps are sparse medieval poles on the
  verge (13 max, 44 m apart, camp roads first) and reject positions near any
  branch; they are dimmed to 20% in daylight. The sky shader scrolls 3D noise
  clouds with the clock and runs a realtime radiance update.
- `tests/test_world.gd` adds checks for modelled creatures (triangle count,
  emissive eye material, runtime fur-card override), road lamps off the ribbon
  and off other roads with matching lights, grass off the road and the coverage
  shader, bush foliage surfaces, camp tents/beds/seats/gates/fire, and the
  realtime moving sky. `world.grass_points` is a small audit array used because
  a MultiMesh does not return transforms under the headless driver.
- Probe scripts and probe screenshots used during authoring were deleted.

**Verified.** Headless import and a 300-frame Direct3D 12 launch reported no
script or parse errors. `test_progression.gd`, `test_combat_effects.gd`,
`test_skill_panel.gd` and `test_world.gd` pass with exit code 0; the world
test reports the new creature, lamp, ground-cover, camp and sky assertions. The
11-frame `--screenshot` tour was inspected at 1600x900, including the day and
night camp frames.

**Risk / follow-up.** The two creature meshes are roughly 13.6k and 14.9k
triangles; a large pack of boars costs more than the old primitives, so watch the
frame time in crowded fights. Fur cards are alpha-tested and depend on the
runtime override: if a future glTF export drops the card material or renames it,
`_apply_fur_cards` warns and the creatures lose their coat. The lamp guard now
checks the whole road network, which moved four lamps off intersecting ribbons
and kept 12 of the 13 allowed. Grass placement stores 31k points for the test;
that is about 250 KB and can be dropped if the headless driver ever exposes
MultiMesh transforms. Map II is still unbuilt.

## 2026-10-28 23:59 - Remote changes from another machine (automatic)

**Source.** `origin/main` moved from `69acc1bc` to `c544b2cd`. Local HEAD is `69acc1bc`.

**Commits not authored on this PC** (local identity: `d.alin_09@yahoo.com`):

- `c544b2cd` 2026-10-28T21:48:56+02:00 **Stefan Bratasanu** - merges (35 files, +1117/-45) [not in local HEAD]

**Files touched by the external commits:**

- `.gitignore`
- `{editor_plugins => addons}/skill_distribution/plugin.cfg`
- `{editor_plugins => addons}/skill_distribution/plugin.gd`
- `addons/effekseer/bin/windows/~libeffekseer.x86_64.dll~RF633b90.TMP`
- `CURRENT_WORK.md`
- `Documentation/IMPLEMENTATION_LOG.md`
- `Documentation/PROJECT_DOCUMENTATION.txt`
- `Documentation/SKILL_SYSTEM_IMPLEMENTED.md`
- `Documentation/UI_STANDARD.md`
- `GAME_RULES.md`
- `project.godot`
- `resources/skills/skill_catalog.tres`
- `scripts/character_select.gd`
- `scripts/character_store.gd`
- `scripts/editor/skill_distribution_window.gd`
- `scripts/enemy.gd`
- `scripts/game_hud.gd`
- `scripts/game_state.gd`
- `scripts/main.gd`
- `scripts/skill_panel.gd`
- `scripts/skills/skill_catalog.gd`
- `scripts/world_builder.gd`
- `tests/test_characters.gd`
- `tests/test_distribution_editor.gd`
- `tests/test_enemy_telegraphs.gd`
- `tests/test_progression.gd`
- `tests/test_skill_catalog.gd`
- `tests/test_skill_panel.gd`
- `tests/test_training_minions.gd`
- `tests/test_world.gd`
- Generated Godot metadata: 5 `.uid`/`.import` file(s) (regenerate with a headless import)

**Flags.**

- New or changed addon outside addons/effekseer: `addons/skill_distribution/plugin.cfg`. Review before running.
- New or changed addon outside addons/effekseer: `addons/skill_distribution/plugin.gd`. Review before running.
- Core file changed: `project.godot`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/enemy.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/game_hud.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/game_state.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/main.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/world_builder.gd`. Re-run the game and the tests before trusting it.
- Hard failure calls on 11 added line(s).

**Proposed actions (not applied).**

- **Re-verify:** launch the game, run the tests, and re-read the changed core files against `GAME_RULES.md`.
- **Ask first:** review the addon/executable diff with the user before it is allowed to run.
- Nothing was changed automatically. Confirm each action with the user before editing or reverting.

**Status.** Awaiting the user's decision. This report did not modify any game code.


## 2026-10-29 - Glow and ambient occlusion in Settings → Graphics

**Intent.** Make the authored emissive sources actually read as light, ground
props and actors with contact shadow, and let a slower machine switch both
effects off without touching the world build.

**Changed.**
- `scripts/world_builder.gd`: `_create_atmosphere()` now configures glow —
  screen blend, `glow_hdr_threshold` 1.0, `glow_hdr_scale` 2.0, intensity 0.9,
  strength 1.0, bloom 0.0, and levels 2-5 at 0.35 / 0.60 / 0.55 / 0.30 (level 1
  and 6 off). Screen blend only adds light, so the frame is never tinted or
  darkened, and the 1.0 threshold keeps ordinary sunlit stone out while the
  emissive fire (1.6-2.4), lanterns, runes and eyes cross it. The existing SSAO
  values are kept (radius 1.5, intensity 1.5, power 1.4, detail 0.5, light
  affect 0.12) but now read the `ssao_enabled` flag. New public `glow_enabled` /
  `ssao_enabled` fields and `apply_graphics_settings()` let a live toggle reach
  the `Environment` without rebuilding the scene.
- `scripts/main.gd`: `glow_enabled` / `ssao_enabled` fields, loaded and saved
  under `[graphics]` (`glow`, `ambient_occlusion`) in `saves/settings.cfg`,
  applied after the world build, restored by `reset_settings()`, and exposed
  through `set_glow_enabled()` / `set_ssao_enabled()` which apply, save and write
  a `graphics_option` UI log event.
- `scripts/game_hud.gd`: the Settings overlay gains a **GRAPHICS** card between
  Camera and Audio with two CheckButtons in the existing style: "Glow on fire,
  lanterns and runes" and "Ambient occlusion (contact shadows)", plus a low-end
  GPU hint. Both apply immediately.
- `tests/test_world.gd`: asserts both effects default on (world and game),
  screen blend, a threshold at or above 1.0, non-zero levels 2-4, and that
  `apply_graphics_settings(false, false)` / `(true, true)` reach the live
  environment.
- `saves/settings.cfg` now carries the `[graphics]` section.

**Verified.** `test_world.gd` passes with the new assertions. A temporary probe
(removed afterwards) instantiated the game, toggled both options off, confirmed
the live `Environment` flags, confirmed the `[graphics]` values in
`saves/settings.cfg`, then confirmed `reset_settings()` restored and re-applied
them. A 300-frame Direct3D 12 launch reported no script or parse errors.
`test_progression.gd` (one known transient save-cache failure on the first run,
passing on rerun), `test_combat_effects.gd` and `test_skill_panel.gd` pass. The
11-frame `--screenshot` tour was inspected: the night camp fire carries a soft
halo and lights the tents, and the daytime camp frame shows no haze or tint.

**Risk / follow-up.** Glow and SSAO cost GPU time; both are opt-out for that
reason. The emissive authors still have to keep light materials above the 1.0
HDR threshold — dimming a lantern below it silently drops its glow. Fluid
simulation and the fog hand-off are unchanged. The remote `origin/main` commit
reported in the automatic section above still needs the user's decision before a
merge; this pass did not touch that work.


