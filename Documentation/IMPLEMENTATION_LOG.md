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

## 2026-10-28 - Read-only installed enchantment inspection

**Intent.** Clicking an installed enchantment should show that enchantment rather than immediately presenting the retained alternatives, as reported in the two screenshots.

**Changed.** `scripts/skill_panel.gd` opens a read-only inspector for installed tiles, using the actual saved modifier and existing description formatter. The `+` tile continues to open next-stage offers; accidental calls to the choice picker on an installed stage also route to inspection. Updated the full-skill notice and tile tooltip. `tests/test_skill_panel.gd` checks the first and second installed tiles, their exact details, lack of alternative-choice buttons, unchanged saved state, and the `+` picker.

**Visual decisions.** The reference topic was reviewed; its linked images were unavailable. Kept the existing compact bronze framed draggable picker, ivory text, square slots and hierarchy described in `Documentation/UI_STANDARD.md`.

**Verified.** Skill-panel integration passed headless and under Direct3D 12; the second-stage inspector was reviewed at 1600×900. Inspection did not change points, offers or installed effects. Headless sandbox reports user-log/certificate access errors and the known ObjectDB exit warning.

**Risk / follow-up.** Installed-stage replacement is no longer exposed in the panel, in keeping with the requested read-only inspection. Reset All still refunds points and retains saved choices; the underlying replacement API remains unchanged.

## 2026-10-28 - Configurable debug panel shortcut

**Intent.** Open and close the debug menu with a configurable key.

**Changed.** Added the debug panel action to the existing shortcut routing and rebind controls in `scripts/main.gd` and `scripts/game_hud.gd`; its default is F1. Settings predating the new action retain custom bindings, selecting an unused panel default if F1 is occupied. `tests/test_training_minions.gd` exercises opening, closing, rebinding, input suppression and old-settings migration.

**Verified.** Debug integration passed headless and with Direct3D 12; the four shortcut rows were inspected at 1600×900. Headless sandbox reported its usual user-log/certificate access errors and ObjectDB warning. The runtime log contained no game errors.

**Risk / follow-up.** Like the other debug shortcuts, the panel key is suppressed while chat or a blocking panel is active. Existing custom bindings can change the new shortcut's initial default.

## 2026-10-28 - Authored enchantment tiers and editor discovery

**Intent.** Classify enchantments as Basic, Rare, Epic, Legendary or Mythical according to their existing power and complexity, surface the tier to players and make it authorable.

**Changed.** The 47 definitions in `resources/skills/skill_catalog.tres` have explicit curated tiers. `scripts/skills/skill_catalog.gd` validates tiers, retains them in new offers, shows tier names in descriptions, and supports pre-tier saved rolls by looking up the current definition with a Basic fallback for missing definitions. `scripts/skill_panel.gd` displays names and restrained tier colors. The distribution editor exposes a tier selector and tier in its list. Moved its plugin from `editor_plugins/skill_distribution/` to `addons/skill_distribution/`, updated the enabled path and Git ignore exception so Godot can discover it in Plugins. Existing draft/source edits were preserved. `tests/test_skill_catalog.gd` and `tests/test_distribution_editor.gd` cover authoring, validation, persistence and legacy fallback. `tests/test_progression.gd` now compares JSON float round trips using the same small tolerance as the catalog test after an existing random-seed-dependent false failure.

**Visual decisions.** Reviewed the reference topic and followed `Documentation/UI_STANDARD.md`: square slots, bronze framing, compact ivory text, plus text labels and subdued colors so tier is not indicated by color alone. The linked reference images were unavailable.

**Verified.** Catalog, distribution editor, skill-panel, progression, skill-runtime, combat-effects and chance/debug tests passed. The in-game choice window was inspected at 1600×900 using Direct3D 12. Headless tests report sandbox user-log/certificate access errors and the known ObjectDB warning. Computer-use could not capture the existing editor window, so plugin discovery after restart remains a manual check.

**Risk / follow-up.** The tier is authored classification, not an automatic multiplier or rarity probability; numerical ranges and family/variant weights remain independent. Existing saved rolls without a tier follow their current definition's tier and otherwise fall back to Basic. Restart the open Godot editor to pick up the moved plugin, then verify its Plugins listing and Tools entry.

## 2026-10-28 - Character selection and local logout

**Intent.** Add separate local characters, a race and starting-class selector, and a way to log out and choose another character without losing the original journey.

**Changed.** `scripts/character_select.gd` provides a bronze-framed roster and creation form. `scripts/character_store.gd` lists the original `saves/journey.json` in place and creates uniquely named files in `saves/characters/`, validating names, race and class and refusing duplicates. `scripts/game_state.gd` persists identity with legacy Human/Fighter/Wayfarer defaults and writes saves via a temporary file and replacement to avoid truncating an existing save on a failed write. `scripts/main.gd` waits for selection before building gameplay, routes saves to the selected file and implements logout. `scripts/game_hud.gd` shows identity and offers logout in Options. Logout requires respawn and recovery of dropped equipment because world loot is not yet persisted. `tests/test_characters.gd` uses isolated fixtures to exercise old/new saves, race and class selection, save routing, failure guards and the logout transition. Existing CLI script tests and screenshot mode bypass the selection screen.

**Visual decisions.** Reviewed the project reference topic and followed `Documentation/UI_STANDARD.md`: compact dark brown interior, bronze frame, ivory text and clear roster/form hierarchy. Linked reference images were unavailable, so no reference artwork was used.

**Verified.** Character integration, progression, skill catalog, skill panel, combat effects and world tests passed. The selector was visually inspected at 1600×900 under Direct3D 12; normal startup reached it without script errors and the original journey's SHA-256 was unchanged. Headless sandbox runs report user-log/certificate access errors and the existing ObjectDB exit warning. A test found a deferred HUD callback during immediate logout; it now checks that the node remains in the tree.

**Risk / follow-up.** Race/class currently change identity only; all choices use the same rig, stats, skills and spawn. Ground equipment is still not persisted across application exit, so logout blocks until it is recovered. The original journey remains in its original file and will acquire default identity fields when next saved.

## 2026-10-28 - Automatically load the last character

**Intent.** Start directly in the last used character while preserving logout as an explicit way to choose another character.

**Changed.** `scripts/character_store.gd` stores the last selected save path separately in `saves/last_character.cfg`, written via a temporary file. It accepts only paths in the local character roster. `scripts/main.gd` loads the last valid save before building the world; with no pointer a single existing save is selected, and missing or damaged saves fall back to the selector. Successful selections update the pointer. A one-shot flag makes Options → Log out open the selector rather than immediately logging back in. `tests/test_characters.gd` covers remembered characters, first-time legacy migration, multiple characters without a pointer, logout selection, stale and corrupt saves, and save isolation.

**Verified.** Character integration, progression and skill-panel tests passed using isolated fixtures. The damaged-save test confirmed that the file was not overwritten. Headless runs reported sandbox user-log/certificate access errors and the existing ObjectDB exit warning.

**Risk / follow-up.** A failure writing the last-character pointer leaves gameplay available, but the next start may require character selection. Saved characters and the existing journey remain independent of the pointer.

## 2026-10-28 - Merge remote nature and combat changes

**Intent.** Integrate `origin/main` through `69acc1bc` while preserving the local character selection, enchantment and debug work.

**Changed.** Temporarily stashed local tracked and untracked work, excluding the locked Effekseer temporary file, fast-forwarded `main` and reapplied the stash. Git auto-merged the four overlapping files without conflict markers. Retained the merged world and enemy changes and local character and skill work. Corrected the current-work hotbar description to ten slots. The named stash remains as a recovery copy.

**Verified.** Headless import completed with exit 0; the editor reported an existing empty-name condition and case warnings from the local animation source collection. Progression, combat effects, skill panel, skill runtime, training minions, character selection and world tests passed. A Direct3D 12 test-mode launch exited 0 with no script errors; its runtime log recorded world build and no error events. `test_hud_snapping.gd` still reports the saved-placement failure already documented by the incoming work. Headless sandbox runs report user-log/certificate access errors.

**Decision needed.** The incoming `GAME_RULES.md` says enemy swings lock their direction and hit within a telegraphed cone, but incoming `scripts/enemy.gd` tracks the player during windup and uses a radial range check at impact; ordinary swings do not draw a cone. This discrepancy predates the local merge. Keep the merged behavior pending a decision whether to implement the written directional telegraph or adopt the current radial behavior as the rule.

## 2026-10-28 - Direction-locked enemy attack telegraphs

**Intent.** Resolve the post-merge rule/implementation discrepancy according to the user's choice: telegraphed, direction-locked attacks.

**Changed.** `scripts/enemy.gd` commits basic attacks to a fixed origin, direction, 100-degree sector and reach at windup start. It draws a red terrain-fitted sector for the full 0.8/0.9/1.0 s normal/quest/boss windup, prevents turning and sidestepping through the swing, applies damage only inside the committed sector, and removes the marker on impact or interruption/death. Combat logging records windups and hit/miss events. The boss slam remains circular and uses the same 5.5 m radius for the marker and horizontal hit check. `scripts/world_builder.gd` exposes the actual rendered terrain triangle height for ground overlays rather than resampling the analytic height. `tests/test_enemy_telegraphs.gd` checks the sector edges, locked facing and origin, movement out of danger, hit, death cleanup and boss circle; `tests/test_world.gd` independently checks surface interpolation against the terrain mesh.

**Verified.** Enemy telegraph, world, progression, combat effects and training-minion tests passed. Direct3D 12 rendered the telegraph in a 1600×900 test frame, and a normal test-mode launch exited 0 with no script errors. The runtime log recorded windups and hit/miss events with no error events. A headless microbenchmark of 20 telegraph creations improved from about 60 ms with analytic height queries to about 6 ms using the terrain grid on this machine; this is not a frame-time guarantee. Headless sandbox reports user-log/certificate access errors.

**Risk / follow-up.** The fixed 100-degree cone and 0.8/0.9/1.0 s windups are initial tuning values; playtest the feel on slopes and against groups. Terrain overlays are tessellated approximations of the sector and surface. The existing HUD saved-placement test failure remains unrelated.
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

## 2026-10-28 21:32 - Remote changes from another machine (automatic)

**Source.** `origin/main` moved from `2f2f4c59` to `69acc1bc`. Local HEAD is `2f2f4c59`.

**Commits not authored on this PC** (local identity: `bratasanu.stefan@gmail.com`):

- `69acc1bc` 2026-10-28T21:31:11+02:00 **XyLeS** - Merge branch 'main' of https://github.com/stefanbratasanu/xyles-mmo (8 files, +492/-18) [not in local HEAD]
- `03deb0a0` 2026-10-28T21:30:16+02:00 **XyLeS** - Xyle update 28 oct (29 files, +1605/-307) [not in local HEAD]

**Files touched by the external commits:**

- `assets/models/props/bush.glb`
- `assets/models/props/generate_props.py`
- `assets/models/props/rock_1.glb`
- `assets/models/props/rock_2.glb`
- `assets/models/props/rock_3.glb`
- `assets/models/props/stone_1.glb`
- `assets/models/props/stone_2.glb`
- `assets/models/trees/generate_trees.py`
- `assets/models/trees/tree_birch.glb`
- `assets/models/trees/tree_dead.glb`
- `assets/models/trees/tree_oak.glb`
- `assets/models/trees/tree_pine.glb`
- `CURRENT_WORK.md`
- `Documentation/IMPLEMENTATION_LOG.md`
- `GAME_RULES.md`
- `scripts/audio_director.gd`
- `scripts/enemy.gd`
- `scripts/game_hud.gd`
- `scripts/main.gd`
- `scripts/player.gd`
- `scripts/skills/skill_runtime.gd`
- `scripts/world_builder.gd`
- `shaders/water.gdshader`
- `tests/test_training_minions.gd`
- `tests/test_world.gd`
- Generated Godot metadata: 7 `.uid`/`.import` file(s) (regenerate with a headless import)

**Flags.**

- Core file changed: `scripts/enemy.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/game_hud.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/main.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/player.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/world_builder.gd`. Re-run the game and the tests before trusting it.
- Hard failure calls on 24 added line(s).

**Proposed actions (not applied).**

- **Re-verify:** launch the game, run the tests, and re-read the changed core files against `GAME_RULES.md`.
- Nothing was changed automatically. Confirm each action with the user before editing or reverting.

**Status.** Awaiting the user's decision. This report did not modify any game code.

## 2026-10-29 - Resolve concurrent world and character changes

**Intent.** Complete the interrupted merge between local `84a19b1` and remote `c544b2c` while preserving both developers' compatible work.

**Changed.** Kept the existing combined conflict resolutions for character selection, HUD, graphics and enemy combat. At the user's explicit direction, retained wolf and boar locked-point attacks and the boar charge; the earlier direction-locked enemy-cone entry remains as history, superseded by this decision. Kept the existing local training-minion UID. Restored an omitted remote-change report, repaired malformed UTF-8 in the merged notes, and corrected an outdated five-slot description. `tests/test_enemy_telegraphs.gd` checks the attack's horizontal locked position and ground projection separately rather than comparing a grounded point with the player's vertical position. Ignored and removed a generated Effekseer temporary DLL from the merge index; its local file was retained.

**Verified.** Headless enemy-telegraph, training-minion, character, world, progression, combat-effects, skill-panel, skill-catalog, skill-runtime and distribution-editor tests passed. A 300-frame headless test-mode launch exited 0 without script/parse errors. The remote-check script reported no new commits since its checkpoint.

**Risk / follow-up.** This pass did not perform a visual or interactive playtest. The previously documented HUD saved-placement failure remains outside scope. GitHub Desktop's UI could not be captured for inspection.

## 2026-10-29 - Forest spacing, creature motion and sword

**Intent.** Repair pine crowns and overlapping trunks, inspect ambient occlusion and creature movement, narrow attacks, and create the requested longer sword without a paid generation service.

**Changed.** Regenerated the script-built pine with tapering foliage and applied a spatial-grid minimum tree-center clearance to all forest placement paths. Blender scripts derive separate rigged wolf and boar assets from the original static models; runtime poses animate their legs and heads. Locked-point bite/gore areas now stay in front within reach, their markers match the hit radius, lunges follow the locked direction and stuck detection scales with frame time. The boar charge and boss slam retain their existing roles. Added an original procedural silver sword model and persistent visual identifier; equipped it on the selected local journey character and preserved the old equipped item in inventory, with a pre-edit backup under `logs/sword_swap_backup/`. Test-mode shutdown no longer saves player settings. Added `.gdignore` to the preserved merge backup so its old GDScript files do not register duplicate global classes.

**Verified.** Headless tests covered sword equipment and persistence, enemy telegraphs, world spacing, training minions, combat effects, progression and animation selection. Direct3D 12 previews of the sword, pine and multiple creature walk poses were inspected. A static SSAO on/off render showed contact darkening with the existing settings; the forest comparison was subtle and inconclusive, so the settings were retained. Godot imported the assets, but still produced an existing empty-name editor diagnostic.

**Risk / follow-up.** The new creature weights and procedural gait are approximate, and interactive gameplay testing is needed for locomotion, attack timing and appearance. The single watermarked reference does not expose all of the sword's 3D details; the model is an original approximation. The save edit applies only to the local selected character and is not shared through Git. Existing HUD saved-placement follow-up remains.

## 2026-10-29 - Ambient occlusion strength

**Changed.** Added 1×, 2× and 3× contact-shadow intensity to Settings → Graphics. It applies live, persists with the other graphics settings, defaults to the original 1× for older settings, and remains selected when ambient occlusion is switched off. Reset returns it to 1×.

**Verified.** The world test checked all levels, toggling, defaults, bounds and configuration storage/loading. A Direct3D 12 preview verified the settings control and its live effect on the environment; the layout was inspected at 1600×900.

## 2026-10-29 - Buffered chunks and timed spawns

**Intent.** Reduce distant active vegetation and enemies, preserve spawn state while the player travels, and support day/night species and retroactive boss windows. The user chose to remove animals at the end of their window and pause world time while closed.

**Changed.** `world_builder.gd` groups deterministic tree, grass, flower and bush placements into 48 m cells and allocates MultiMesh instance buffers in a 5×5 buffered neighborhood; terrain, landmarks and map data remain global. `chunk_spawn_manager.gd` manages normal, boss and quest spawn slots in a 3×3 neighborhood, retains living health and position, preserves engaged enemies when leaving their home cell, and resolves absolute respawn deadlines without simulating absent AI. Boar is active 05:00–17:30 and wolf 17:30–05:00; changes remove the old species. Optional boss windows use constant-time interval intersection, including midnight and multi-day gaps; the Regent remains unrestricted. `game_state.gd` stores the world clock and slot snapshot atomically with each character save, paused while closed; legacy saves default to day 1 at 08:15. Corrected quest and bestiary wording to match the existing normal-kill counter, which accepts either species. Chunk changes are logged at transitions.

**Verified.** The chunk test covers delayed respawn, living enemy health, multi-day species transitions, a missed timed-boss window, quest enemy unload/reload, saved clock and paused deadlines, and visual-cell allocation. The existing world, enemy telegraph, training, progression, combat and skill-panel checks and a headless launch were run. A Direct3D 12 forest preview was inspected at 1600×900. At the starting area, 26,821 of 35,260 vegetation instances are allocated; this is an allocation count, not a measured FPS or memory result.

**Risk / follow-up.** Terrain, placement generation and landmarks are still built globally, and loading neighboring visual cells occurs on the main thread; startup savings and transition stutter are not established. Review movement across cell edges and day/night transitions interactively and benchmark frame times, VRAM and CPU on slower systems. This is local single-player state; a real MMO requires server-authoritative shared world time, spawns and interest management.

## 2026-10-29 - Authored, expanded world and staged streaming

**Intent.** Replace startup world generation with an authored snapshot, make the playable area three times larger with more routes and places, spread difficulty regions and put the sealed waygate at the end of a road in the north-west. Preserve gently rolling terrain, progression and the prior timed-spawn work.

**Changed.** `world_builder.gd` defines a roughly 512.7 m square, expanded irregular biomes, connected outer routes, moved quest/boss/sanctum/pond/waygate sites, 22 additional normal spawn points and five decorative exploration landmarks. `scripts/dev/bake_world.gd` deliberately generates the design offline into `assets/world/`, including a baked painted map; normal startup loads it rather than invoking the generator. Detailed terrain and its collision, vegetation and static scenery are saved in separate spatial assets. Buffered loading prioritizes nearby cells, stages one cell per frame on the main thread by default, and retains a low-detail terrain horizon with fallback collision while detailed tiles load. Threaded loading is opt-in for profiling after a dummy-renderer resource race and larger stalls were observed. Log only slow activation events, throttled. Preserve saved enemy-slot identities and timers across the expanded spawn table; older stored positions are cleared when moving the layout so living enemies reappear at their new homes with retained health.

**Verified.** Headless chunk tests cover old-save migration, timed spawns, boss windows, staged loading state, fallback and detailed terrain collision. A real player-physics test walked across a tile boundary without falling. World tests cover the threefold area, widely separated level centers, a single road ending at the northwest gate, region assignments, streams, lamps, pools, terrain and gameplay. Asset integrity checks sampled terrain tiles and verified 4,570 baked trees against their biome. Character, enemy telegraph, training minion, progression, combat effects, skill panel and skill runtime tests passed, as did a 300-frame headless launch without script/parse/runtime errors. The Direct3D 12 map and five landmark views were inspected. The import reported the previously documented missing local `modifier_list_editor` warning and empty-name diagnostic.

**Measurement and limits.** On an i5-9300HF / RTX 2060, single headless world-initialization runs measured about 318 ms for the baked path and 28.6 s for the offline procedural path, with the staged loads and GPU rendering excluded from the baked figure. A 15-second scripted Direct3D 12 traversal at 1280×720 with game logic active averaged about 60 FPS and had a 38 ms maximum frame in the portion after the first 1.5 seconds; a roughly 551 ms frame occurred early. Separate stationary runs with prefetch disabled, including one with glow and SSAO off and one also without the sky, showed early stalls, so their cause is unresolved. These are not slower-PC measurements or a full manual playtest. Test normal gameplay and performance across machines; dedicated multiplayer server authority and multi-player interest management do not exist yet.

## 2026-10-29 - Reduce chunk-loading stalls

**Intent.** Investigate reported freezes during traversal and reduce the CPU/GPU and memory impact of streaming without losing enemy state or ground collision.

**Changed.** Timed resource reads separately from scene activation in throttled slow-chunk diagnostics. Normal-renderer streaming now requests terrain, vegetation and scenery resources through the threaded loader, with at most one request in flight, and no synchronous completion wait at a newly entered cell. Detailed collision replaces the existing low-detail fallback when ready. Out-of-range high-detail cells continue to be removed; fixed baked files, low-detail terrain and shared resources remain available. Headless mode stages loads synchronously because the dummy renderer previously exhibited a concurrent resource race. Existing enemy slot and character-save logic is unchanged.

**Verified.** The reported log contained 44–210 ms chunk activations; later instrumentation measured individual synchronous scenery reads at 321–346 ms. A Direct3D 12 test moved the streaming target twice during a load and checked that the latest terrain, vegetation and scenery arrived without stale terrain activation. Headless chunk checks verified fallback and detailed collisions, weak references to released terrain nodes and meshes and vegetation nodes, as well as spawn and save behavior. Traversal, world, baked-integrity, enemy-telegraph and character tests passed; a 300-frame headless smoke launch had no script/parse/runtime errors.

**Measurement and limits.** Single scripted 1280×720 runs, excluding the first 1.5 seconds, measured a 95th-percentile frame time of 34.6 ms and maximum 373 ms before, versus 17.1 ms and 48.5 ms after. A separate 1600×900 run averaged 59.6 FPS with a 17.3 ms 95th percentile and 124 ms maximum in its measured portion. Early stalls of about 0.3–0.5 seconds remain unexplained, and a teleport can expose fallback terrain or temporarily absent scenery while streaming catches up. These synthetic runs do not replace interactive testing or measurements on slower machines.

## 2026-10-29 - GPU resource profile and frame-rate cap

**Intent.** Investigate the user's report of high resource use after chunk streaming improvements, lower avoidable rendering work, and let players select a 20–60 FPS cap.

**Evidence and changes.** The user's 154-second session had no errors and logged several 59–133 ms frames, but lacks per-process CPU/GPU utilization and memory measurements. In a stationary 1600×900 Direct3D 12 camp profile, 25 loaded vegetation cells contained about 1,311 trees and 25,112 grass tufts plus flowers and bushes. Hiding vegetation reduced mean measured GPU frame rendering from 15.5 to 5.8 ms; disabling all shadows measured 6.3 ms, while disabling both post effects measured 14.4 ms. These are separate diagnostic states and their savings are not additive. Kept vegetation, MSAA, sky, glow and AO intact; changed the sun from four 150 m shadow cascades to two 100 m cascades with the existing soft blur and blend. More distant shadows now fade sooner.

A paired stationary run with a fixed world time measured 16.36 and 16.50 ms GPU render time and approximately 1,768 draws for the old shadow configuration, compared with 12.98 and 13.33 ms and 1,033 draws for the new one; render-thread CPU time decreased from about 2.85–2.98 ms to 2.18–2.42 ms. The two camp views were inspected, but distant shadows and night still require visual review. Draw totals include rendering passes. These are one-machine, one-scene measurements, not whole-system utilization or VRAM.

Added a live integer 20–60 FPS slider in `game_hud.gd`; `main.gd` clamps, applies, saves, loads and resets its value, defaulting older settings to 60 FPS. A real-renderer run measured about 30 and 20 frames per second at those caps. Following the linked UI reference and `UI_STANDARD.md`, reused the existing compact bronze-framed settings card, slider row and ivory numeric readout. No saved user settings are written by test mode.

**Verification and limits.** The graphics test checks defaults, storage/loading, bounds, live slider changes and reset; world, chunk, terrain traversal, combat and skill-panel checks and a headless launch were run. A Direct3D screenshot of the settings panel was inspected at 1600×900. 20/30 FPS smoothness and frame pacing depend on the display; lower caps reduce frame work but cannot guarantee a particular utilization or prevent a slower system from falling below the cap. No dedicated VRAM reduction was established, and further tests of other viewpoints, night, slower PCs and interactive gameplay are needed.

## 2026-10-29 - Nature materials, foliage and spawn-design rule

**Intent.** Improve rocks, pebbles, bushes, terrain and grass while keeping grass out of water and bark dark; establish an explicit designer question for new mob schedules and locations.

**Research and changes.** References included USGS's descriptions of fractured, rounded and weathered boulders, the Geomorphic Environments photographic atlas, and Poly Haven's scanned forest floor and weathered rock materials. `assets/models/props/generate_props.py` produces fuller low foliage and five textured, irregular rocks/pebbles in Blender; GLBs embed CC0 diffuse and normal maps for independent editing. Godot imports those models with embedded maps discarded, and the game assigns one shared normal-mapped material to avoid per-model extracted duplicates. Campfire stones now use those props. `assets/textures/polyhaven/README.md` records Poly Haven authors, original files, derivative and CC0 license. Terrain uses a muted derivative of Forest Ground 04 and its normal map; `scripts/dev/bake_world.gd` generates tangents for high- and low-detail terrain. Birch/dead bark tint no longer brightens the common bark texture.

Grass retains one batched MultiMesh group per cell: each patch combines three smaller clumps with varied shapes, and instances vary their scale, orientation and tint. Placement counts are 90% of the previous targets. Meadow patches and dry-shore grass reject locations near pond water; the former reed instances were knowingly placed in shallow water, so they now stand beyond the pond with extra clearance. The baked world was rebuilt; a pre-change backup is in `logs/nature_before_20261029/` and is excluded from Godot import. `AGENTS.md` and `GAME_RULES.md` now require asking Alin or Stefan for each new mob's day/night schedule and map, zones or biomes before implementation, then recording the decisions.

**Verification and limits.** The baked-integrity test checks all grass audit points and dry-shore placement, ground tangents/normal textures, tree bark and bush foliage; world, streaming and traversal tests and a headless smoke run were exercised. Direct3D background streaming and in-engine camp, pond and individual prop previews were inspected. In separate same-setup stationary camp runs, grass patch instances fell from 25,112 to 22,547 and GPU render time measured 13.0–13.3 ms before and 10.3–12.8 ms after across separate runs; this is a single-machine scene comparison, not a guarantee or a clean isolation of grass, rock, material and shadow costs. The existing missing-editor-addon warning and editor empty-name diagnostic remain. Other viewpoints, night, interactive gameplay and slower computers require further review.

## 2026-10-29 13:34 - Remote changes from another machine (automatic)

**Source.** `origin/main` moved from `ee4aaca3` to `8cbf1f8f`. Local HEAD is `8cbf1f8f`.

**Commits not authored on this PC** (local identity: `xylesmargera@gmail.com`):

- `8cbf1f8f` 2026-10-29T11:32:20+02:00 **XyLeS** - 4 (475 files, +2048/-296) [already in local HEAD]
- `0c4fc49f` 2026-10-29T01:23:32+02:00 **XyLeS** - Update 3 (37 files, +920/-38) [already in local HEAD]
- `c1e904dc` 2026-10-29T00:35:56+02:00 **XyLeS** - Merge branch 'main' of https://github.com/stefanbratasanu/xyles-mmo (33 files, +1089/-42) [already in local HEAD]
- `84a19b19` 2026-10-29T00:15:33+02:00 **XyLeS** - Update 2 (50 files, +3957/-361) [already in local HEAD]
- `c544b2cd` 2026-10-28T21:48:56+02:00 **Stefan Bratasanu** - merges (35 files, +1117/-45) [already in local HEAD]
- `69acc1bc` 2026-10-28T21:31:11+02:00 **XyLeS** - Merge branch 'main' of https://github.com/stefanbratasanu/xyles-mmo (8 files, +492/-18) [already in local HEAD]
- `03deb0a0` 2026-10-28T21:30:16+02:00 **XyLeS** - Xyle update 28 oct (29 files, +1605/-307) [already in local HEAD]
- `2f2f4c59` 2026-10-28T20:13:19+02:00 **Stefan Bratasanu** - spawner (8 files, +492/-18) [already in local HEAD]
- `9e65a2d8` 2026-10-28T19:50:47+02:00 **Stefan Bratasanu** - my changes (66 files, +20825/-496) [already in local HEAD]

**New commits authored on this PC:** 9 (not reported as external).

**Files touched by the external commits:**

- `.gitignore`
- `{editor_plugins => addons}/skill_distribution/plugin.cfg`
- `{editor_plugins => addons}/skill_distribution/plugin.gd`
- `addons/effekseer/bin/windows/~libeffekseer.x86_64.dll~RF633b90.TMP`
- `AGENTS.md`
- `assets/animations/player_runtime/action_animations.tres`
- `assets/animations/player_runtime/README.md`
- `assets/animations/player_runtime/spear.tscn`
- `assets/models/creatures/boar.glb`
- `assets/models/creatures/boar_boar_hide.png`
- `assets/models/creatures/boar_fur_card.png`
- `assets/models/creatures/boar_rigged.glb`
- `assets/models/creatures/boar_rigged_boar_hide.png`
- `assets/models/creatures/boar_rigged_fur_card.png`
- `assets/models/creatures/generate_creatures.py`
- `assets/models/creatures/make_creature_textures.py`
- `assets/models/creatures/rig_creatures.py`
- `assets/models/creatures/wolf.glb`
- `assets/models/creatures/wolf_fur_card.png`
- `assets/models/creatures/wolf_rigged.glb`
- `assets/models/creatures/wolf_rigged_fur_card.png`
- `assets/models/creatures/wolf_rigged_wolf_fur.png`
- `assets/models/creatures/wolf_wolf_fur.png`
- `assets/models/props/bush.glb`
- `assets/models/props/generate_props.py`
- `assets/models/props/rock_1.glb`
- `assets/models/props/rock_2.glb`
- `assets/models/props/rock_3.glb`
- `assets/models/props/stone_1.glb`
- `assets/models/props/stone_2.glb`
- `assets/models/trees/generate_trees.py`
- `assets/models/trees/make_foliage_textures.py`
- `assets/models/trees/tree_birch.glb`
- `assets/models/trees/tree_dead.glb`
- `assets/models/trees/tree_oak.glb`
- `assets/models/trees/tree_pine.glb`
- `assets/models/weapons/build_ornate_sword.py`
- `assets/models/weapons/ornate_silver_sword.glb`
- `assets/models/weapons/ornate_silver_sword_BrushedSilver.png`
- `assets/textures/boar_hide.png`
- `assets/textures/fur_card.png`
- `assets/textures/grass_blades.png`
- `assets/textures/leaf_card.png`
- `assets/textures/needle_card.png`
- `assets/textures/polyhaven/forest_ground_04-Diffuse.jpg`
- `assets/textures/polyhaven/forest_ground_04-nor_gl.jpg`
- `assets/textures/polyhaven/forest_ground_tinted.png`
- `assets/textures/polyhaven/README.md`
- `assets/textures/polyhaven/rock_face_03-Diffuse.jpg`
- `assets/textures/polyhaven/rock_face_03-nor_gl.jpg`
- `assets/textures/polyhaven/tint_ground.py`
- `assets/textures/wolf_fur.png`
- `assets/ui/equipment/spear.svg`
- `assets/world/baked_world.res`
- `assets/world/static/cell_0_0.scn`
- `assets/world/static/cell_0_1.scn`
- `assets/world/static/cell_0_-1.scn`
- `assets/world/static/cell_0_2.scn`
- `assets/world/static/cell_0_-2.scn`
- `assets/world/static/cell_0_-3.scn`
- ... and 480 more source file(s)
- Generated Godot metadata: 70 `.uid`/`.import` file(s) (regenerate with a headless import)

**Flags.**

- New or changed addon outside addons/effekseer: `addons/skill_distribution/plugin.cfg`. Review before running.
- New or changed addon outside addons/effekseer: `addons/skill_distribution/plugin.gd`. Review before running.
- Core file changed: `project.godot`. Re-run the game and the tests before trusting it.
- Executable/script added or changed: `scripts/dev/check_remote_changes.ps1`. Do not run it until reviewed.
- Core file changed: `scripts/enemy.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/game_hud.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/game_state.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/main.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/player.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/world_builder.gd`. Re-run the game and the tests before trusting it.
- Debug leftovers on 4 added line(s).
- Hard failure calls on 355 added line(s).
- Merge conflict markers on 1 added line(s).

**Proposed actions (not applied).**

- **Block:** resolve the conflict markers before running or committing.
- **Re-verify:** launch the game, run the tests, and re-read the changed core files against `GAME_RULES.md`.
- **Ask first:** review the addon/executable diff with the user before it is allowed to run.
- **Modify:** remove or gate debug leftovers after the user agrees.
- Nothing was changed automatically. Confirm each action with the user before editing or reverting.

**Status.** Awaiting the user's decision. This report did not modify any game code.

## 2026-10-29 13:57 - Post-pull asset cache rebuild

**Symptom.** After pulling `8cbf1f8`, the project failed to compile:
`scripts/player.gd` could not preload
`res://assets/models/weapons/ornate_silver_sword.glb`, and `scripts/main.gd`
reported "Failed to compile depended scripts". The pulled GLBs and textures were
newer than this PC's `.godot` import cache, so Godot kept stale remaps for the
old binary files.

**Fix.** Ran the headless import:

```powershell
.\Godot_v4.7.2-stable_win64_console.exe --headless --path . --import
```

The parse gate (`tests/_parse.gd`) then returned `failures=0`, all scripts parsed,
and a windowed launch loaded the saved Wayfarer at Emberfall Camp with
`errors: 0` in the runtime log. No game code, scene, asset or remote commit was
changed. The watcher's "merge conflict markers" flag was a false positive: the
only match was the watcher's own regex on `scripts/dev/check_remote_changes.ps1`
line 202; a repository-wide scan found no markers.

**Remaining, deliberately not changed (user decision).** The new oak/birch
crowns start at 3.6 m with 1.45-2.1 m cards and can fill the camera in dense
forest; `test_hud_snapping` still fails because `WindowSnap.settle` is not
idempotent (a saved window at x=670 is moved to x=658 on restore). Both are
remote-authored behaviour and were left untouched at the user's request.

## 2026-10-29 - Camp seats, paths and night fires

**Intent.** Replace modern-looking lamps with tripod fire bowls, provide seating
at the campfire, connect a circular camp clearing to the fence gates, and make
fires and their local audio night-only.

**Changed.** `assets/models/props/generate_road_cresset.py` creates the original
wooden tripod, rope, iron bowl and fire sprite in Blender, based on the user's
tripod image and the Auckland Museum's pole cresset and GameGuru outdoor fire
basket references. It uses the project's existing bark texture. The generator
`generate_fire_audio.py` creates original looped campfire and smaller torch
crackles. The world builder places paired tripods outside each road-derived gate
and replaces sparse road lanterns. It renders a terrain-following road-textured
camp clearing and clips the visible camp-bound road ribbons to its edge. The
authored world was rebaked. Fire particles, light, camp embers and positional
sound follow the sun, and the sound follows the game's master volume and mute.
Both camp logs have collision and persistent seat groups. E selects a nearby seat,
uses the existing sitting animation and WASD requests a stand-up; the physics
body stays outside the log while the visual sits on it.

**Verified.** Headless import and parse gate; world, traversal, baked integrity,
progression, combat effects and skill panel checks passed. The new real-renderer
`test_camp_seating.gd` checks the baked seats, gate torches, day/night visibility
and audio playback, E sitting and W standing; the seated daytime close-up and
night camp screenshot were inspected. The runtime screenshot log reported zero
errors. Godot still prints resource/RID leak diagnostics at test process exit;
these need further investigation. The editor import also emits its previously
documented missing local addon warning and empty-name diagnostic.

**Follow-up.** Audition the synthesized loops on speakers/headphones and adjust
their mix if necessary; visually review seating transitions, all gate approaches,
and night performance during interactive play. The sitting clip is a floor
campfire pose elevated onto a log, not a purpose-made bench animation.

## 2026-10-29 - Rebuilt camp assets and log seating follow-up

**Intent.** Improve the camp's material detail and open tent entrances, replace
the poorly textured logs, remove overlapping gate lights, and stop the elevated
floor-sitting pose from leaving the feet floating or crossing the log on exit.

**Changed.** `generate_camp_assets.py` builds separate open canvas tent panels,
frames, beds, rough hewn seat logs and charred firewood in Blender. Original
canvas, wool and end-grain textures are generated by that script; the log bark
and fence use Poly Haven's CC0 Jolcham Oak Bark 01 diffuse and normal maps,
credited in the texture README. Beds have slatted frames, straw ticks, wool
blankets and pillows. The fence keeps its existing gate layout and collision,
with tapered posts, bindings and bark material. Torch positions are deduplicated
and road lights stay away from the camp. `player.gd` derives a separate
log-seat pose from the existing rig, directing the thighs forward and shins
down, lowering the root to the log height and blending the visual back to the
standing body's position before movement. Ground sitting with X remains separate.
The world snapshot was rebuilt using the headless authoring script.

**Verification and limits.** An earlier in-engine preview showed the open tent
interior, but the user rejected the first log texture; that preview predates the
new bark, end grain and seating changes. At the user's direction no further game
launch or gameplay test was performed. The revised pose, both feet on ground,
stand-up behavior, final materials, sound quality and performance remain
unverified in play. Godot's earlier test-run exit leak diagnostics remain open.

## 2026-10-29 - Seating alignment and smaller torches

**Symptom.** User screenshots show the log sitter floating away from the seat,
holding its fists up and sliding into movement without a stand-up animation.
The previous custom pose inherited the unarmed combat idle and used an assumed
root offset; its exit blended directly to locomotion.

**Changed.** The log pose now starts from the existing relaxed campfire idle,
retains the rig-adjusted leg orientation and computes the seated pelvis position
from the animated skeleton. Seat placement aligns that point to the log top.
An authored-at-runtime transition interpolates from the campfire animation's
standing frame to the seated pose and plays backward to stand; movement remains
blocked until the transition finishes. Ground sitting retains its existing
clips. Tripod scenes, collision, flame and light are scaled together to 60%,
making the lit stand approximately player height. The authored world was rebaked.

**Verification and limits.** Per the user's instruction, no game launch or
gameplay test was run for this revision. The final pose, foot placement and
transition require in-game review; the height calculation uses the animated
pelvis and the log's 0.56 m top, not foot IK. Earlier exit leak diagnostics
remain unresolved.

## 2026-10-29 - Local torch flames and off-center log seating

**Symptom.** User reports that resized torches retained oversized, misplaced
flames, and the seat moved the player to the log center and returned them to
their original interaction location on standing.

**Changed.** Torch particle simulation now uses local coordinates and a smaller,
less intense sprite and particle count; the emitter height accounts for the
particle radius and sprite extent, keeping the lowest edge above the fire bowl.
The campfire's particle settings are unchanged. Log seating projects the approach
onto the log's length, chooses the same side, and moves the collision body during
the sit transition to a safe standing point at that position. The pelvis aligns
to that point on the log, and the reverse animation ends next to it. The authored
world was rebaked.

**Verification and limits.** The real-renderer `test_camp_seating.gd` passed an
off-center approach, pelvis alignment, W stand-up and final body position. The
`test_camp_torch_flame.gd` passed the local-coordinate and scale checks, but its
image showed the sprite extending under the bowl; the final sprite dimensions,
brightness and raised emitter were adjusted afterward based on their calculated
minimum extent and rebaked without a second in-game run. Inspect the resulting
torch in play. Both tests printed the previously observed renderer resource
cleanup diagnostics at process exit.


## 2026-10-29 16:53 - Remote changes from another machine (automatic)

**Source.** `origin/main` moved from `0c4fc49f` to `75238a0b`. Local HEAD is `75238a0b`.

**Commits not authored on this PC** (local identity: `d.alin_09@yahoo.com`):

- `75238a0b` 2026-10-29T14:53:34+02:00 **XyLeS** - Update 5 (293 files, +2461/-145) [already in local HEAD]

**New commits authored on this PC:** 1 (not reported as external).

**Files touched by the external commits:**

- `AGENTS.md`
- `assets/audio/campfire_crackle.wav`
- `assets/audio/torch_crackle.wav`
- `assets/models/props/camp_bed.glb`
- `assets/models/props/camp_bed_camp_canvas.png`
- `assets/models/props/camp_bed_camp_timber.png`
- `assets/models/props/camp_bed_camp_wool.png`
- `assets/models/props/camp_firewood.glb`
- `assets/models/props/camp_firewood_camp_timber.png`
- `assets/models/props/camp_firewood_jolcham_oak_bark_01_diff_1k.jpg`
- `assets/models/props/camp_firewood_jolcham_oak_bark_01_nor_gl_1k.jpg`
- `assets/models/props/camp_log_seat.glb`
- `assets/models/props/camp_log_seat_camp_endgrain.png`
- `assets/models/props/camp_log_seat_camp_timber.png`
- `assets/models/props/camp_log_seat_jolcham_oak_bark_01_diff_1k.jpg`
- `assets/models/props/camp_log_seat_jolcham_oak_bark_01_nor_gl_1k.jpg`
- `assets/models/props/camp_tent.glb`
- `assets/models/props/camp_tent_camp_canvas.png`
- `assets/models/props/camp_tent_camp_timber.png`
- `assets/models/props/generate_camp_assets.py`
- `assets/models/props/generate_fire_audio.py`
- `assets/models/props/generate_road_cresset.py`
- `assets/models/props/road_cresset.glb`
- `assets/models/props/road_cresset_bark.png`
- `assets/textures/camp_canvas.png`
- `assets/textures/camp_endgrain.png`
- `assets/textures/camp_timber.png`
- `assets/textures/camp_wool.png`
- `assets/textures/fire_sprite.png`
- `assets/textures/polyhaven/jolcham_oak_bark_01_diff_1k.jpg`
- `assets/textures/polyhaven/jolcham_oak_bark_01_nor_gl_1k.jpg`
- `assets/textures/polyhaven/README.md`
- `assets/world/baked_world.res`
- `assets/world/static/cell_0_0.scn`
- `assets/world/static/cell_0_1.scn`
- `assets/world/static/cell_0_-1.scn`
- `assets/world/static/cell_0_2.scn`
- `assets/world/static/cell_0_-2.scn`
- `assets/world/static/cell_0_-3.scn`
- `assets/world/static/cell_1_0.scn`
- `assets/world/static/cell_-1_0.scn`
- `assets/world/static/cell_1_1.scn`
- `assets/world/static/cell_1_-1.scn`
- `assets/world/static/cell_-1_1.scn`
- `assets/world/static/cell_-1_-1.scn`
- `assets/world/static/cell_1_-2.scn`
- `assets/world/static/cell_-1_2.scn`
- `assets/world/static/cell_1_3.scn`
- `assets/world/static/cell_1_-3.scn`
- `assets/world/static/cell_1_-4.scn`
- `assets/world/static/cell_-1_-4.scn`
- `assets/world/static/cell_1_-5.scn`
- `assets/world/static/cell_2_0.scn`
- `assets/world/static/cell_-2_0.scn`
- `assets/world/static/cell_2_1.scn`
- `assets/world/static/cell_2_-1.scn`
- `assets/world/static/cell_-2_1.scn`
- `assets/world/static/cell_-2_-1.scn`
- `assets/world/static/cell_2_2.scn`
- `assets/world/static/cell_-2_-2.scn`
- ... and 205 more source file(s)
- Generated Godot metadata: 28 `.uid`/`.import` file(s) (regenerate with a headless import)

**Flags.**

- Core file changed: `scripts/main.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/player.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/world_builder.gd`. Re-run the game and the tests before trusting it.
- Hard failure calls on 145 added line(s).

**Proposed actions (not applied).**

- **Re-verify:** launch the game, run the tests, and re-read the changed core files against `GAME_RULES.md`.
- Nothing was changed automatically. Confirm each action with the user before editing or reverting.

**Status.** Awaiting the user's decision. This report did not modify any game code.


## 2026-10-29 - Missing camp after pull and guarded launcher

**Symptom and cause.** The user's post-pull session showed a missing camp, although its gameplay logger reported zero errors. The incoming Git commit included the baked camp and source GLBs, textures, audio and scenes. Before import, the reproduced world test emitted missing `.godot/imported` errors for new camp and torch assets, and scenery/camp assertions failed. Godot's machine-local import cache is ignored by Git; engine resource-loader failures in the console did not reach the project's gameplay log.

**Changed.** Ran the existing Godot headless import to regenerate the local cache, without changing incoming game code or authored world assets. Added `PLAY XYLES.bat`, `scripts/dev/launch_xyles.ps1` and `scripts/dev/verify_world_assets.gd`. The launcher checks a fingerprint of project sources and the existence of default imported outputs; after a change or missing output it imports, inspects errors, then checks the baked terrain, scenery, vegetation, shared meshes and camp before launching. It stops with a log location on detected errors. Fingerprinting uses file names, sizes and modification times rather than file-content hashes. Direct Godot launches do not go through this check.

**Verification and limits.** Before import, the headless world test reproduced resource-loading errors and missing camp; after import it and the baked-integrity and chunk tests reported passes without script/assertion or missing-file errors. The all-cell scan loaded 72 static, 196 terrain and 144 vegetation cells, checked eight shared meshes and found one camp, with no missing assets. A Direct3D camp preview was inspected. Launcher checks covered forced import, the up-to-date fast path, a deliberately removed imported camp scene regenerated by the launcher, and a real 120-frame test-mode game launch; no player save was used. The editor's missing local addon warning and empty-name error remain, as do pre-existing test exit RID/resource cleanup diagnostics. The launcher cannot guarantee against every game or asset problem and must be committed/pulled to be available on other machines.

## 2026-10-29 - Forest distance, bark and creature movement/audio

**Intent.** Mask bare horizons beyond streamed vegetation, improve tree and fallen-log surfaces without changing the dark-trunk direction, animate creature legs while turning in place, and use only the sounds Alin chose in A/B previews. Combat and spawn rules are unchanged.

**Changed.** `world_builder.gd` increases day/night fog and applies the existing Poly Haven Jolcham oak bark albedo and normal maps to dark-tinted trees and fallen logs; `frontier_sky.gdshader` softly blends the horizon into the current fog color. The leaf-card generator adds secondary veins and mottling, and its PNG was regenerated. `scripts/dev/bake_world.gd` was run to update the shipped tree meshes and static chunk scenes; a backup of the prior baked world is in the ignored `logs/fog_forest_before_20261029/` directory. `actor_visual.gd` uses actual yaw speed to add stepping in place, and `enemy.gd` supplies it without changing attack locking. Positional wolf/boar aggro, attack and death cues use the six approved files, respect the master volume and mute, and throttle aggro repeats; `assets/audio/enemies/ATTRIBUTION.md` records provenance. The wolf death cue is GPL 2.0 and its original and license text are retained; review distribution obligations and compatibility.

**Verification and limits.** Headless import and world bake completed. `test_creature_turn_audio.gd`, `test_world.gd`, `test_baked_world_integrity.gd`, `test_chunk_streaming.gd`, `test_enemy_telegraphs.gd`, `test_world_traversal.gd`, `test_camp_seating.gd`, `test_progression.gd`, `test_combat_effects.gd` and `test_skill_panel.gd` completed with no script, parse, assertion, or asset-loading errors. Day/night Direct3D test-mode captures were inspected. A fixed-view RTX 2060 GPU profile measured approximately 12.7 ms per frame in two samples; scene counts differ from the older run, so it is not a controlled before/after performance comparison. Interactive animation, the mix and forest log detail still need human review. Existing engine exit RID/resource-leak diagnostics and the local editor-plugin warning remain.

## 2026-10-29 - Motion softness investigation, lighting preview and sword swing

**Intent and evidence.** The player reported diffuse surroundings while moving. The project has temporal anti-aliasing enabled in `project.godot`; [Godot's documentation](https://docs.godotengine.org/en/stable/tutorials/3d/3d_antialiasing.html#temporal-antialiasing-taa) says TAA can cause increased blur while the camera moves and ghosting. No separate motion-blur effect was found in the inspected project configuration and scripts. This is a likely cause, not a visually confirmed diagnosis of the user's exact symptom; camera follow smoothing and display behaviour may also affect perception.

**Changed.** Settings → Graphics now exposes a persistent TAA toggle (default on, including old saves; reset restores on). The existing MSAA setting remains. The clock panel has a compact Auto / Day / Night preview button. `world_builder.gd` uses an alternate hour only for atmosphere, lights, flames and their sound while leaving the real clock, day count, time-dependent spawns and saves untouched; Auto returns to the current world time. Its mode is deliberately session-only. The player's existing sword/greatsword melee animation path triggers a CC0 recorded swing via the existing audio voice pool; unarmed and other weapon styles do not. Credit is in `assets/audio/player/ATTRIBUTION.md`.

**Verification and limits.** Ran headless import and `test_visual_preview_sound.gd`, `test_world.gd`, `test_chunk_streaming.gd`, `test_combat_effects.gd`, and `test_skill_panel.gd`. The targeted test checks the preview cycle and unchanged world clock/phase, advancing time during preview, TAA application and config roundtrip, actual starting melee delivery, unarmed exclusion and mute. Inspected Direct3D test-mode captures of day, night, and the settings layout. The reported softness still needs an interactive on/off comparison on the user's display, and the swing sound needs the user's listening feedback. Known Godot import empty-name and scripted-exit resource/RID warnings persist.

## 2026-10-29 - Two randomized sword slashes

**Intent and changes.** Replaced the previously added air swish at the user's request with two short metallic sword-attack samples from StarNinjas' CC0 pack. Their original Ogg files were converted to WAV without further edits; provenance is recorded in `assets/audio/player/ATTRIBUTION.md`. Sword and greatsword attack animations use the existing pooled audio voices, picking either sample independently with a dedicated randomized generator. Consecutive attacks can choose the same sample. Other weapons, mute and master volume keep their existing behavior.

**Verification and limits.** Ran headless import and `test_visual_preview_sound.gd` and `test_combat_effects.gd`. The targeted test checked that both files load, the seeded selector can choose each, an attack assigns a slash to a voice, the starting melee skill triggers it, unarmed attacks remain silent and mute suppresses playback. The mix and choice of clips still need in-game listening. Existing editor import empty-name and scripted-shutdown resource diagnostics remain.

## 2026-10-29 - Sword slash feedback and replacement

**Intent.** The user rejected the two StarNinjas metallic scraping samples. Of two replacements from Gladiator Battle Arena, the user accepted qubodup's short slash hit and rejected the other. Further generic impact and bamboo whoosh samples were also rejected; the user asked specifically for a steel sword whoosh.

**Changed.** Replaced `sword_slash_1.wav` with the user's accepted qubodup sample and removed the rejected other file from the active pool. A short excerpt of an actual katana swing from the CC0 Still North Media weapon recordings was added as a provisional second sample, while the user's choice of steel A/B/C remains pending. Credit and source are in `assets/audio/player/ATTRIBUTION.md`. This preserves the existing attack trigger, mute, and voice pool.

**Verification and limits.** Reimported the approved sample and ran `test_visual_preview_sound.gd` to check loading, sword attack, normal skill activation, unarmed exclusion and mute. Steel swing A is provisional and still needs the user's listening feedback.

## 2026-10-29 - User-provided sword slash

**Changed.** At the user's request, replaced the provisional selection with the single supplied `54427377-sword-slash-476148.mp3` for every sword and greatsword attack. Converted 0.54–1.07 seconds of the recording to WAV to remove silence; the original remains in Downloads. The source and license were not provided. Mute and master volume still use the existing audio pool.

**Verification and limits.** Godot imported the WAV successfully. `test_visual_preview_sound.gd` passed checks for repeated sword and greatsword attacks using the supplied clip, normal skill activation, unarmed exclusion and mute. `test_combat_effects.gd` passed. The in-game audio mix has not been auditioned. The existing editor import empty-name and test-shutdown resource diagnostics remain.

**Risk / follow-up.** The fixed 100-degree cone and 0.8/0.9/1.0 s windups are initial tuning values; playtest the feel on slopes and against groups. Terrain overlays are tessellated approximations of the sector and surface. The existing HUD saved-placement test failure remains unrelated.

## 2026-10-28 - Basic attack command (partial)

Added /attack chat command for an independent, unupgradeable melee hit with its own cooldown. Progression test passed. Sword grip and in-game combat verification remain outstanding; this pass is not complete.

## 2026-10-28 - Basic attack combat verification

Tested /attack through chat against a nearby enemy, including mana, cooldown, range and immunity to melee upgrades. Corrected power calculation to use the basic attack's own buff identity. Sword grip still requires visual diagnosis.

## 2026-10-28 - Remove individual equipped skill

Added per-skill REMOVE in K; empties the selected slot and refunds that skill's upgrades, preserves learned skill and offers, saves empty slots, and handles empty hotbar/casts. UI uses existing compact bronze controls and square slots, following the project reference and UI standard. Dedicated removal/save/re-equip and skill-panel tests passed. Sword-grip work remains outstanding.

## 2026-10-28 - Actions and enchantment pause (partial)

Disabled all authored enchantment definitions using their existing editable enabled flag. Existing investments and rolls are preserved, but disabled effects no longer compile or appear in offers. Added F7 Actions with attack, sit, target and placeholder social/party controls. The action window follows the reference's grouped square-grid approach using existing controls. The Human Fighter class redesign, animated emotes and final visual polish remain unfinished. Dedicated Actions test passes.

## 2026-10-28 - Click-to-move option (partial)

Added a saved boolean in Options that disables ground-click movement while retaining enemy selection; disabling cancels an existing click path. Headless startup passed. Fighter skill tree, bow, progression and drag/drop remain unfinished.

## 2026-10-28 - Fighter tree data (in progress)

Recorded requested Fighter skill milestones in scripts/skills/fighter_tree.gd. This is authoring data only; class progression, bow attack, drag-and-drop, save migration and UI integration are not implemented. Existing gameplay was left intact while these dependencies remain.

## 2026-10-28 - Fighter tree integration (in progress)

Added Fighter milestone view, level-gated assignment, unmodifiable derived Fighter skills, empty new hotbars, and initial skill/action drag payloads. Added craftable bow weapon type and prototype visual. The milestone/save test passed. This remains incomplete: bow combat/projectile presentation, drag interaction and existing-save migration require rendered end-to-end verification; old Fighter loadouts require review.

## 2026-10-28 - Action hotbar and dance icon

Made every Basic, Party and Social action assignable to hotbar slots, preserving explicit placeholder behavior for unimplemented actions. Added original generated dance icon in the Actions window and hotbar. Saved action identifiers are validated against the registered list. Action assignment/drop API and save/reload tests pass. Headless import reported the existing editor empty-name warning and sandbox editor-settings error. Full mouse-drag visual verification remains outstanding.

## 2026-10-28 - Actions icon set

Generated an original 12-cell atlas in the reference's pale-blue silhouette and dark square style. Assigned distinct icons to all ten actions in F7 and the hotbar. Action assignment and icon-presence tests pass. Import encountered sandbox editor-settings warnings; visual small-size inspection remains outstanding.

## 2026-10-28 - Playful action icons

Replaced the temporary generic symbols with original generated pale-blue expressive figures, dark-blue squares and playful poses informed by the user's reference; applied to action window and hotbar. Reviewed a Direct3D 12 rendered window and action-hotbar test passed. Existing party and social actions remain placeholders.

## 2026-10-28 - Compact classic interface pass

Adapted the reference's compact hierarchy, inset bronze borders, dark interiors and square shortcuts using original Godot frame drawing. The reference topic was readable; its external screenshot URLs failed to load, so supplied reference images and UI_STANDARD guided details. Added fine bevels and title sheen across shared frames. Adventure menu exposes Inventory, Class skills, Actions, Bestiary, Crafting and Options; development tools remain in Options. Removed the redundant wide footer navigation. Fighter tree now uses compact illustrated milestone cards; Actions uses a 300x390 grouped icon window with honest placeholder tooltips. Status includes XP and the hotbar prioritizes assignment guidance over inactive enchantment points. Existing window position persistence remains intact.

Verified: Direct3D 12 render of HUD, Fighter skills, Actions and Inventory at 1600x900, no script errors in the rendered run. Action-hotbar and Fighter milestone tests pass. Legacy test_skill_panel is incompatible with the already-disabled enchantment definitions and Fighter default: it fails installation/row expectations then aborts on a missing old row child. It was stopped, not marked passing. No gameplay formulas changed. Existing saves may retain previous window placement; Options > Reset Window Positions applies the new default arrangement.
`nWorld integration test also passed. Normal game launched after verification.

## 2026-10-28 - Reference status bars

Replaced the spacious status card with a compact name/level header and stacked full-width XP, HP and MP bars, following the supplied reference. XP is yellow with current-level percentage; HP red and MP blue with centered live values. No CP resource invented. Headless action/HUD integration passed; Direct3D 12 render checked. Character identity remains state-backed but is no longer a separate visible row.

## 2026-10-28 - Angled status and movable HUD

Followed the user's diagonal right-edge cut using a polygon frame and child clipping; reduced the status height to its content to remove the black bottom strip. Normalized shared panel backgrounds to 86% opacity. Added clock, chat, region plate and frameless shortcut bar to the existing drag/snap/persistence system. Chat has a dedicated title above its interactive tabs; shortcuts have a separate drag grip above the tiles. Existing content windows and evolution picker retain title dragging. The full-screen map remains a full-screen view.

Verified Direct3D 12 rendered layout, diagonal clipping and bar text; action-hotbar integration and expanded HUD snapping tests pass (including registered panels, hotbar drop collision resolution and recorded placement). No gameplay or save data changed. Sandbox headless runs still emit environmental log/certificate warnings.

## 2026-10-29 - Corner navigation, character sheet and drag guides

Removed permanent Adventure and System Journal panels at the user's request. Bottom-right controls now offer an original head silhouette for live character stats, a gear for Options and a foldout listing windows/map. The character sheet groups current vitals, actual equipment multipliers/mitigation and progression, avoiding unimplemented attributes. Options uses Camera / Audio / Game / Tools tabs and immediate saved settings with OK; no nonfunctional Apply/Cancel controls. Resource fills themselves now have diagonal end caps, including partially depleted values. Hotbar drag instruction text is removed; its grip sits at the right. During dragging, cyan peer bounds and a gold active rectangle/gap outline expose the snapping geometry.

Verified: Direct3D 12 captures of corner menu, character sheet, Options and drag guides; fixed clipped corner navigation found during review. New test_corner_ui covers closed foldout, live HP, tab visibility and guide lifecycle. Action-hotbar, updated HUD snapping and world integration tests pass. Rendered integration produced no script errors. Shared background opacity remains 86%. No gameplay formulas changed; full-screen map remains full-screen. Headless sandbox log/certificate warnings remain environmental.

## 2026-10-29 20:20 - Remote changes from another machine (automatic)

**Source.** `origin/main` moved from `c544b2cd` to `6afc50ac`. Local HEAD is `6afc50ac`.

**Commits not authored on this PC** (local identity: `bratasanu.stefan@gmail.com`):

- `6afc50ac` 2026-10-29T19:13:11+02:00 **XyLeS** - Update 7 (13 files, +225/-7) [already in local HEAD]
- `8a5c1f4b` 2026-10-29T18:19:15+02:00 **XyLeS** - Update 6 (105 files, +672/-17) [already in local HEAD]
- `70494c66` 2026-10-29T17:10:55+02:00 **XyLeS** - Bat (7 files, +282/-0) [already in local HEAD]
- `75238a0b` 2026-10-29T14:53:34+02:00 **XyLeS** - Update 5 (293 files, +2461/-145) [already in local HEAD]
- `8cbf1f8f` 2026-10-29T11:32:20+02:00 **XyLeS** - 4 (475 files, +2048/-296) [already in local HEAD]
- `0c4fc49f` 2026-10-29T01:23:32+02:00 **XyLeS** - Update 3 (37 files, +920/-38) [already in local HEAD]
- `c1e904dc` 2026-10-29T00:35:56+02:00 **XyLeS** - Merge branch 'main' of https://github.com/stefanbratasanu/xyles-mmo (33 files, +1089/-42) [already in local HEAD]
- `84a19b19` 2026-10-29T00:15:33+02:00 **XyLeS** - Update 2 (50 files, +3957/-361) [already in local HEAD]

**Files touched by the external commits:**

- `.gitignore`
- `{editor_plugins => addons}/skill_distribution/plugin.cfg`
- `{editor_plugins => addons}/skill_distribution/plugin.gd`
- `AGENTS.md`
- `assets/audio/campfire_crackle.wav`
- `assets/audio/enemies/ATTRIBUTION.md`
- `assets/audio/enemies/boar_aggro.wav`
- `assets/audio/enemies/boar_attack.wav`
- `assets/audio/enemies/boar_death.wav`
- `assets/audio/enemies/sources/.gdignore`
- `assets/audio/enemies/sources/GPL-2.0.txt`
- `assets/audio/enemies/sources/wesnoth_wolf_die_1.ogg`
- `assets/audio/enemies/wolf_aggro.wav`
- `assets/audio/enemies/wolf_attack.wav`
- `assets/audio/enemies/wolf_death.wav`
- `assets/audio/player/ATTRIBUTION.md`
- `assets/audio/player/sword_slash_user.wav`
- `assets/audio/torch_crackle.wav`
- `assets/models/creatures/boar.glb`
- `assets/models/creatures/boar_boar_hide.png`
- `assets/models/creatures/boar_fur_card.png`
- `assets/models/creatures/boar_rigged.glb`
- `assets/models/creatures/boar_rigged_boar_hide.png`
- `assets/models/creatures/boar_rigged_fur_card.png`
- `assets/models/creatures/generate_creatures.py`
- `assets/models/creatures/make_creature_textures.py`
- `assets/models/creatures/rig_creatures.py`
- `assets/models/creatures/wolf.glb`
- `assets/models/creatures/wolf_fur_card.png`
- `assets/models/creatures/wolf_rigged.glb`
- `assets/models/creatures/wolf_rigged_fur_card.png`
- `assets/models/creatures/wolf_rigged_wolf_fur.png`
- `assets/models/creatures/wolf_wolf_fur.png`
- `assets/models/props/bush.glb`
- `assets/models/props/camp_bed.glb`
- `assets/models/props/camp_bed_camp_canvas.png`
- `assets/models/props/camp_bed_camp_timber.png`
- `assets/models/props/camp_bed_camp_wool.png`
- `assets/models/props/camp_firewood.glb`
- `assets/models/props/camp_firewood_camp_timber.png`
- `assets/models/props/camp_firewood_jolcham_oak_bark_01_diff_1k.jpg`
- `assets/models/props/camp_firewood_jolcham_oak_bark_01_nor_gl_1k.jpg`
- `assets/models/props/camp_log_seat.glb`
- `assets/models/props/camp_log_seat_camp_endgrain.png`
- `assets/models/props/camp_log_seat_camp_timber.png`
- `assets/models/props/camp_log_seat_jolcham_oak_bark_01_diff_1k.jpg`
- `assets/models/props/camp_log_seat_jolcham_oak_bark_01_nor_gl_1k.jpg`
- `assets/models/props/camp_tent.glb`
- `assets/models/props/camp_tent_camp_canvas.png`
- `assets/models/props/camp_tent_camp_timber.png`
- `assets/models/props/generate_camp_assets.py`
- `assets/models/props/generate_fire_audio.py`
- `assets/models/props/generate_props.py`
- `assets/models/props/generate_road_cresset.py`
- `assets/models/props/road_cresset.glb`
- `assets/models/props/road_cresset_bark.png`
- `assets/models/props/rock_1.glb`
- `assets/models/props/rock_2.glb`
- `assets/models/props/rock_3.glb`
- `assets/models/props/stone_1.glb`
- ... and 503 more source file(s)
- Generated Godot metadata: 87 `.uid`/`.import` file(s) (regenerate with a headless import)

**Deleted files:**

- `addons/effekseer/bin/windows/~libeffekseer.x86_64.dll~RF633b90.TMP`

**Flags.**

- New or changed addon outside addons/effekseer: `addons/skill_distribution/plugin.cfg`. Review before running.
- New or changed addon outside addons/effekseer: `addons/skill_distribution/plugin.gd`. Review before running.
- Executable/script added or changed: `PLAY XYLES.bat`. Do not run it until reviewed.
- Core file changed: `project.godot`. Re-run the game and the tests before trusting it.
- Executable/script added or changed: `scripts/dev/check_remote_changes.ps1`. Do not run it until reviewed.
- Executable/script added or changed: `scripts/dev/launch_xyles.ps1`. Do not run it until reviewed.
- Core file changed: `scripts/enemy.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/game_hud.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/game_state.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/main.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/player.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/world_builder.gd`. Re-run the game and the tests before trusting it.
- 1 file(s) deleted by the remote commits. Confirm the deletion was intended.
- Debug leftovers on 2 added line(s).
- Hard failure calls on 221 added line(s).

**Proposed actions (not applied).**

- **Re-verify:** launch the game, run the tests, and re-read the changed core files against `GAME_RULES.md`.
- **Ask first:** review the addon/executable diff with the user before it is allowed to run.
- **Modify:** remove or gate debug leftovers after the user agrees.
- Nothing was changed automatically. Confirm each action with the user before editing or reverting.

**Status.** Awaiting the user's decision. This report did not modify any game code.

## 2026-10-29 - Reconcile pulled work and GitHub Desktop stash

**Intent and changes.** The pull fast-forwarded and GitHub Desktop preserved local edits in a stash. Reconciled the stash with the incoming code and kept the pulled AGENTS.md. Preserved both histories, upstream enemy-telegraph UID and addon path, bow and ornate sword visuals, clock preview and draggable clock, and tabbed Options including Graphics. The original stash remains intact.

**Verification and limits.** Headless import completed with existing editor diagnostics and sandbox filesystem/certificate errors. Headless test-mode smoke, world, action hotbar, corner UI, HUD snapping, basic attack, enemy telegraphs and ornate sword checks passed. Progression and skill-panel checks fail because the saved skill redesign disables enchantments and changes the panel; combat-effects and visual-preview/sound checks assume a populated starting hotbar but the saved redesign starts empty. Review these fixtures and intended behavior before treating those areas as verified. A rendered test launch failed D3D12 initialization, fell back to Vulkan and crashed with illegal instruction (0xc000001d); no graphical or interactive verification was completed. Engine cleanup warnings persist.

## 2026-10-29 20:59 - Remote changes from another machine (automatic)

**Source.** `origin/main` moved from `8a5c1f4b` to `2115754f`. Local HEAD is `2115754f`.

**Commits not authored on this PC** (local identity: `d.alin_09@yahoo.com`):

- `2115754f` 2026-10-29T20:43:37+02:00 **Stefan Bratasanu** - mine (45 files, +1287/-140) [already in local HEAD]

**New commits authored on this PC:** 1 (not reported as external).

**Files touched by the external commits:**

- `assets/ui/actions/action_atlas.png`
- `assets/ui/actions/action_atlas_minimal.png`
- `assets/ui/actions/action_atlas_playful.png`
- `assets/ui/actions/dance.png`
- `assets/ui/character_head.svg`
- `CURRENT_WORK.md`
- `Documentation/IMPLEMENTATION_LOG.md`
- `Documentation/PROJECT_DOCUMENTATION.txt`
- `Documentation/UI_STANDARD.md`
- `GAME_RULES.md`
- `resources/skills/skill_catalog.tres`
- `scripts/animation_profiles.gd`
- `scripts/classic_frame.gd`
- `scripts/game_hud.gd`
- `scripts/game_state.gd`
- `scripts/main.gd`
- `scripts/player.gd`
- `scripts/skill_drag_button.gd`
- `scripts/skill_panel.gd`
- `scripts/skills/fighter_tree.gd`
- `scripts/skills/skill_runtime.gd`
- `scripts/status_resource_bar.gd`
- `scripts/ui_drag_guides.gd`
- `tests/test_action_hotbar.gd`
- `tests/test_actions_rework.gd`
- `tests/test_basic_attack.gd`
- `tests/test_corner_ui.gd`
- `tests/test_fighter_tree.gd`
- `tests/test_hud_snapping.gd`
- `tests/test_remove_skill.gd`
- Generated Godot metadata: 15 `.uid`/`.import` file(s) (regenerate with a headless import)

**Flags.**

- Core file changed: `scripts/game_hud.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/game_state.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/main.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/player.gd`. Re-run the game and the tests before trusting it.
- Hard failure calls on 7 added line(s).

**Proposed actions (not applied).**

- **Re-verify:** launch the game, run the tests, and re-read the changed core files against `GAME_RULES.md`.
- Nothing was changed automatically. Confirm each action with the user before editing or reverting.

**Status.** Awaiting the user's decision. This report did not modify any game code.

## 2026-10-29 - Forest collision, light shafts and starting equipment

**Intent and changes.** The user requested solid trees and props for mobs, a two-second stun when charging boars hit trees, removal of the pointed tree-base pieces, the Blender silver sword as the sole starting item, sun shafts, and fire audio heard from the character. Baked vegetation uses MultiMesh instances and previously had no trunk colliders. Each loaded tree group now owns a shared-shape trunk collision body, removed with its streamed cell; a dedicated physics layer keeps the orbit camera from collapsing against trunks. Existing solid prop collisions also stop a charge. Enemy charge impact with a tree ends the charge and stuns it for two seconds. The Blender generator discards separate root cones while retaining its random sequence, and `refresh_tree_meshes.gd` updates the five shared baked meshes without rebuilding placements. New characters equip the existing ornate silver sword and start with no bag items or wood/iron; current saves are not migrated or cleared. An AudioListener3D follows the player while using the camera orientation, affecting positional sounds including fire.

**Lighting.** Godot Forward+ volumetric fog scatters the existing directional sun and its shadows; regular fog remains for distant streaming. The sun's volumetric energy falls to zero at night. The Graphics option persists and permits disabling the extra GPU effect. Reference: https://docs.godotengine.org/en/stable/tutorials/3d/volumetric_fog.html .

**Verification and limits.** Re-exported the trees in Blender and imported them in Godot. Character creation, ornate-sword, forest collision/stun/listener/light-setting, world, enemy telegraph, basic attack, torch and chunk-streaming checks passed; the character-name and sword tests were adjusted for the current HUD casing and new starting equipment. A Direct3D screenshot tour and an on/off forest comparison were inspected; the separate root spikes are gone and the sunlight is subtle in the reviewed view. The effect, collision navigation, mix and performance still need interactive review; no controlled performance benchmark was run. The screenshot tour logged slow frames during its rapid teleports and engine shutdown reported the existing resource/RID leak diagnostics. The remote-change check flagged Stefan's already-pulled core changes for re-verification; no external commit was reverted.

## 2026-10-29 - Localized forest shafts and stronger SSAO

**Intent and references.** The user rejected the broad light wash and requested distinct beams with varied brightness and softness. Compared a real [redwood forest photograph](https://ianplant.com/photo/907045/20564086/sunbeams-in-the-forest-5-redwood-national-park-california) and a [game forest example](https://www.3djuegos.com/juegos/the-witcher-3-wild-hunt/noticias/los-mejores-bosques-de-videojuego-190728-95263). Godot documents volumetric fog and NVIDIA describes the role of occluders in light shafts, but the first global-volume result visibly washed out the whole view.

**Changes.** Replaced that global volumetric wash with localized, depth-tested crossed shader cards batched with the streamed vegetation, varying length, width and opacity. Their apparent slant follows the sun, they fade at night, and the graphics toggle hides their draw calls. This is an art-directed approximation: the cards are placed near trees and depth-tested against visible geometry, but they are not calculated from actual canopy gaps or physical shadow volumes. SSAO intensity is now 2.5 times the selected 1–3 level (formerly 1.5) and light affect is 0.35 (formerly 0.12), so occlusion remains more visible in sunlight. Existing settings retain their selected level.

**Verification and limits.** A Direct3D on/off forest comparison showed distinct localized light bands without the old screen-wide wash; separate 1× and 3× SSAO frames were inspected. Headless forest checks cover shaft setting, streaming nodes, changing sun direction and night visibility, plus the collision and listener changes. The world test checks the revised SSAO values and settings persistence. Run an interactive movement and target-PC performance review: screen-facing geometry is an approximation and the cost of additional transparent draws has not been benchmarked. The parallel rendered capture and world test initially shared a timestamped runtime log and the world-log assertion failed; the world test passed when rerun alone. Existing scripted-shutdown RID/resource diagnostics remain.

## 2026-10-29 - Restore blue daytime sky

**Intent and changes.** The user reported a grey daytime sky. The prior horizon-hiding pass used a grey-green daytime horizon, blended a wide grey fog band into the sky, and allowed scene fog to affect the sky. Changed the daytime gradient to blue, narrowed the shader's mist band, and reduced fog influence on the sky while retaining world fog density and the existing night/dusk progression. This preserves the intended concealment of distant streamed scenery without tinting the whole sky grey.

**Verification and limits.** Inspected Direct3D day and night frames: the daytime view is blue with clouds and the night view remains dark with stars. Headless forest and world tests passed, including checks for the blue-day shader parameter, reduced sky fog and retained distance fog. The progression fixture now supplies its own materials and damaged armor instead of depending on removed starting items; its crafting/death checks had no errors, but 13 enchantment-related assertions still fail because the current Fighter redesign has that system disabled (already recorded in the prior reconciliation entry). No interactive horizon-traversal or performance benchmark was done. Existing scripted-shutdown diagnostics remain.

## 2026-10-29 22:13 - Remote changes from another machine (automatic)

**Source.** `origin/main` moved from `2115754f` to `df45631d`. Local HEAD is `2115754f`.

**Commits not authored on this PC** (local identity: `d.alin_09@yahoo.com`):

- `df45631d` 2026-10-29T21:02:23+02:00 **Stefan Bratasanu** - lfs update (7 files, +174/-2) [not in local HEAD]
- `5580b0ab` 2026-10-29T20:46:02+02:00 **Stefan Bratasanu** - Track game assets with Git LFS (512 files, +29/-65370) [not in local HEAD]

**Files touched by the external commits:**

- `.gitattributes`
- `assets/animations/player_runtime/action_animations.tres`
- `assets/animations/player_runtime/character_texture.res`
- `assets/animations/player_runtime/greatsword_texture.res`
- `assets/animations/player_runtime/protof_animations.tres`
- `assets/animations/player_runtime/shield_texture.res`
- `assets/animations/player_runtime/staff_texture.res`
- `assets/animations/player_runtime/sword_texture.res`
- `assets/audio/campfire_crackle.wav`
- `assets/audio/enemies/boar_aggro.wav`
- `assets/audio/enemies/boar_attack.wav`
- `assets/audio/enemies/boar_death.wav`
- `assets/audio/enemies/sources/wesnoth_wolf_die_1.ogg`
- `assets/audio/enemies/wolf_aggro.wav`
- `assets/audio/enemies/wolf_attack.wav`
- `assets/audio/enemies/wolf_death.wav`
- `assets/audio/player/sword_slash_user.wav`
- `assets/audio/torch_crackle.wav`
- `assets/effects/ember_bolt/Texture/FlameRadiation.png`
- `assets/models/creatures/boar.glb`
- `assets/models/creatures/boar_boar_hide.png`
- `assets/models/creatures/boar_fur_card.png`
- `assets/models/creatures/boar_rigged.glb`
- `assets/models/creatures/boar_rigged_boar_hide.png`
- `assets/models/creatures/boar_rigged_fur_card.png`
- `assets/models/creatures/wolf.glb`
- `assets/models/creatures/wolf_fur_card.png`
- `assets/models/creatures/wolf_rigged.glb`
- `assets/models/creatures/wolf_rigged_fur_card.png`
- `assets/models/creatures/wolf_rigged_wolf_fur.png`
- `assets/models/creatures/wolf_wolf_fur.png`
- `assets/models/props/bush.glb`
- `assets/models/props/camp_bed.glb`
- `assets/models/props/camp_bed_camp_canvas.png`
- `assets/models/props/camp_bed_camp_timber.png`
- `assets/models/props/camp_bed_camp_wool.png`
- `assets/models/props/camp_firewood.glb`
- `assets/models/props/camp_firewood_camp_timber.png`
- `assets/models/props/camp_firewood_jolcham_oak_bark_01_diff_1k.jpg`
- `assets/models/props/camp_firewood_jolcham_oak_bark_01_nor_gl_1k.jpg`
- `assets/models/props/camp_log_seat.glb`
- `assets/models/props/camp_log_seat_camp_endgrain.png`
- `assets/models/props/camp_log_seat_camp_timber.png`
- `assets/models/props/camp_log_seat_jolcham_oak_bark_01_diff_1k.jpg`
- `assets/models/props/camp_log_seat_jolcham_oak_bark_01_nor_gl_1k.jpg`
- `assets/models/props/camp_tent.glb`
- `assets/models/props/camp_tent_camp_canvas.png`
- `assets/models/props/camp_tent_camp_timber.png`
- `assets/models/props/road_cresset.glb`
- `assets/models/props/road_cresset_bark.png`
- `assets/models/props/rock_1.glb`
- `assets/models/props/rock_2.glb`
- `assets/models/props/rock_3.glb`
- `assets/models/props/stone_1.glb`
- `assets/models/props/stone_2.glb`
- `assets/models/trees/tree_birch.glb`
- `assets/models/trees/tree_dead.glb`
- `assets/models/trees/tree_oak.glb`
- `assets/models/trees/tree_pine.glb`
- `assets/models/weapons/ornate_silver_sword.glb`
- ... and 457 more source file(s)

**Flags.**

- Core file changed: `scripts/game_hud.gd`. Re-run the game and the tests before trusting it.
- Hard failure calls on 1 added line(s).

**Proposed actions (not applied).**

- **Re-verify:** launch the game, run the tests, and re-read the changed core files against `GAME_RULES.md`.
- Nothing was changed automatically. Confirm each action with the user before editing or reverting.

**Status.** Awaiting the user's decision. This report did not modify any game code.


## 2026-10-29 - Shaft placement, night clouds, stun and aggro modes

**Intent and changes.** Fixed reported shafts crossing trunks or appearing over roads/open areas: Map I vegetation cells create candidate beams, and full slanted paths are checked against the authored tree index, road corridors, sites and ponds, with a four-tree density threshold. Checks repeat as the sun moves and are staged one batch per frame; unloaded nodes are referenced by instance ID. Shaft intensity ramps up from 10:00 to 11:00, stays full until 16:00 and fades out by 17:00, using the existing visual day/night preview. Night cloud opacity now reaches zero. Existing baked boulders are identified by their rock mesh resource name (their node names are often auto-generated) and settled partly into sampled ground when static chunks load, moving collision with them; the offline generator uses the same settling rule. Stun uses three rotating yellow star labels above the creature's head and below its health bar for the two-second stun.

**Aggro.** Added passive, territorial and aggressive modes. Passive creatures do not initiate proximity aggro but retaliate when attacked, as clarified by the user; territorial creatures detect within 3 m, while aggressive creatures keep the existing kind-specific detection radius. All retaliate when damaged. Health bars identify the behavior in yellow, orange or red before combat; an engaged or recently damaged creature's bar is red. The combat color clears eight seconds after the last damage when no longer engaged. Existing wolves, boars and guardians retain their aggressive behavior. Rules are recorded in GAME_RULES.md.

**Verification and limits.** The forest test checks time windows, clearance, boulder settling, stun placement/duration and audio listener; the aggro test covers the three modes, passive retaliation and colors. World, enemy telegraph and chunk-streaming tests were run, including unloading while queued shaft checks exist. Direct3D captures were inspected for a cloud-free night, grounded boulder, and stars below the health bar. A local forest check found 4.8–10.8 ms worst staged checks in successive runs using two batches per frame; the final version was reduced to one batch per frame. This is not a full frame-time or slower-PC benchmark. The card-based shafts are still an approximation and need interactive review across terrain and time. Existing shutdown RID/resource warnings persist. The remote check found two newer commits, including an LFS migration and UI changes; they were not pulled or altered, and local uncommitted changes remain.
