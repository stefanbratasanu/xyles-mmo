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

## 2026-10-29 - GitHub Git LFS migration

**Intent and changes.** Use GitHub's default LFS service with the existing origin, preserving shared history. `.gitattributes` tracks game-asset GLB, PNG, JPEG, WAV, OGG, MP3, RES and SCN files and two large runtime animation TRES resources; 509 existing assets were staged as LFS pointers without altering their working files. Installed the repository-local LFS pre-push hook. Other contributors need Git LFS installed before pulling, and should run `git lfs pull` and the existing asset import/launcher if needed. Old Git blobs remain in history; this does not reduce historic repository size.

**Verification and limits.** All 509 staged pointers were checked against working-file SHA-256 hashes and local LFS objects (about 141 MiB unique content). The headless world and baked integrity tests passed; sandbox user-log/certificate warnings and known shutdown diagnostics remain. GitHub upload, quota, credentials and a fresh checkout on the other machine have not yet been verified. A prior sandbox Direct3D launch crashed, so no new graphical launch was attempted.

## 2026-10-29 - Highlight skill modifiers and immediate item descriptions

**Intent and design.** Make current skill modifiers visible and remove the delay for inventory item descriptions. The reference topic was reachable, but its linked images were unavailable; followed the existing compact dark bronze/ivory interface and used gold to distinguish sources.

**Changed.** Skill cards and shortcut tooltips derive current values from the existing compiled skill and runtime power preview. Equipment base-power and relevant damage/support multipliers, plus enabled installed enchantments, are identified and highlighted. Broken equipment's reduced power follows the runtime rule and inactive modifiers are omitted. Inventory item and material hover uses an immediate viewport-clamped panel which closes on exit or window changes. No combat or progression formula was changed.

**Verification and limits.** Headless `test_ui_modifier_hover.gd` checks actual panel opening, live equipment power, broken equipment, enabled/disabled enchantments and immediate hover lifecycle. Action-hotbar, Fighter-tree and world tests passed. A headless test-mode launch completed without script/parse errors. Visual playtesting was not performed because the previous sandbox Direct3D launch crashed; inspect tooltip sizing and appearance interactively. Sandbox log/certificate and existing shutdown-resource diagnostics remain.

## 2026-10-29 - Hyper3D human fighter draft

**Intent and changes.** Generated an isolated human fighter from the user-supplied reference using Hyper3D Rodin Gen-2.5-Medium, a 30,000-quad target and GLB output. Saved PBR and shaded exports with provenance in `assets/models/characters/human_fighter/`. The image-to-3D service required a JPEG extension because the original `.png` was actually JPEG; an unchanged temporary copy under ignored `logs/` was used for upload. No existing playable character was replaced.

**Verification and limits.** The generated GLBs each contain one mesh with 30,330 vertices and 54,984 triangles, without skins or animations. Godot headless import ran and both scenes loaded successfully. The import logged an error for the original mislabeled reference under `addons/`, in addition to known editor/sandbox diagnostics. Visual fidelity, topology, performance, rigging and compatibility with the animation library were not verified. No interactive graphics launch was attempted because of the prior sandbox crash.

## 2026-10-29 - Default generated human fighter

**Intent and changes.** At the user's request, rigged the generated fighter with Hyper3D's human skeleton (job `02a13b4b-7c39-4073-986e-6363d98ef21b`) and made `fighter_rigged.glb` the default player visual. `scripts/fighter_retarget.gd` maps major joints and fingers from the existing animation skeleton using global rest-relative rotation; the original mesh is hidden while its rig continues to drive gameplay, existing clips and seat calculations. Weapon attachment is on the new right hand with a rest-orientation correction. The generated mesh is about 55k triangles. No combat or progression rules were changed.

**Verification and limits.** Headless startup, `test_fighter_retarget.gd`, camp seating, animation selection, basic attack and world tests passed. The retarget test confirms mapped bones, run leg movement and weapon parent. A 500-iteration headless microbenchmark averaged about 0.09 ms per bridge update on this machine; it is not a gameplay frame-rate measurement. An offline Blender reference render and a run pose reconstructed from the in-engine skeleton were inspected; small shoulder skin artifacts are visible. No actual in-game rendered or interactive test was performed after the previous sandbox graphics crash. Different proportions, seat alignment, all combat animations, hand grip, deformation and performance in gameplay need user review. The mislabeled supplied reference continues to cause a separate import diagnostic; known sandbox log/certificate and exit diagnostics remain.

**Reference import correction.** Renamed the supplied JPEG from `.png` to `.jpg` without changing its bytes; the final headless import recognized it and no longer reported the mislabeled-file error. Existing editor empty-name and sandbox certificate/settings errors remain.

## 2026-10-29 - Fighter pose and sword grip correction

**Evidence and cause.** The user reported poor walking and supplied a screenshot with the sword displaced from the hand. The latest real session recorded no gameplay errors and had no marker. A test-mode OpenGL reproduction showed the same issue. Comparison to the original animated character showed that the generated rig's arms and legs start at different angles; copying only global rest-relative rotations retained those differences, placing the arms and hands incorrectly. This was an error in our retargeting, although the generated skin also has imperfections.

**Changed.** `fighter_retarget.gd` computes rest-direction corrections for arm, leg, foot and finger segments, then applies the existing animation's rest-relative motion. `player.gd` compensates for the hand correction when orienting the weapon mount. Gameplay, animation timing and the underlying clips are unchanged. `test_fighter_retarget.gd` now checks source and target limb directions and sword proximity.

**Verification and limits.** Captured and compared original, before and corrected test-mode OpenGL sword idle and multiple walk/run frames. The corrected pose and grip are closer to the original. Headless retarget, camp seating, animation-selection and basic-attack checks passed. These frames do not substitute for interactive playback: different body proportions, generated skin weights, weapon variants, combat and seat alignment still need review. Existing test shutdown diagnostics remain.

## 2026-10-29 - Fighter face and shorts refinement

**Evidence and intent.** The user reported a bad side profile and shorts texture/deformation while running. The recent runtime log had no error or marker relevant to the report. Blender rest-profile renders confirmed the face asymmetry is present in the generated source. Weight inspection showed the central lower pelvis was almost entirely split between the two thigh bones, with little hip influence; this is a plausible contributor to the moving shorts artifact, not a confirmed diagnosis of temporal flicker.

**Changed.** `assets/models/characters/human_fighter/refine_fighter.py` produces a separate `fighter_refined.glb` from the preserved Hyper3D rig. It mirrors the better side, transfers original skin weights, adjusts hip/thigh influence near the shorts, and restores the non-tattooed upper-arm texture. `player.gd` loads the refined copy. The symmetry also changes body geometry and UVs; this is not a hand-authored replacement face.

**Verification and limits.** Inspected both profiles in Blender and in an isolated Godot OpenGL render, plus several test-mode running frames from behind before and after. The facial profile is improved; close-up neck/shoulder shading still shows a transition. Retarget, camp seating, animation selection and basic attack checks passed, and the final asset imported. Still frames do not prove that a motion-dependent shorts shimmer is resolved; interactive playback and other lighting/poses remain to be reviewed. Sandbox certificate/editor-setting and existing engine shutdown diagnostics remain.

## 2026-10-29 - Two-view fighter regeneration

**Intent and changes.** Regenerated the human fighter with Hyper3D Rodin Gen-2.5-High from the user's front and side reference images to improve the texture and profile. Saved the resulting PBR and shaded GLBs in `assets/models/characters/human_fighter/regenerated/`; generation ID and details are in its README. Preserved the existing playable model and rig.

**Verification and limits.** The two exports each contain approximately 55,456 triangles and have no skeleton or animations. Both imported and loaded in Godot. Blender front and both profile renders were inspected: shorts have more detail, but one side has rough/pitted skin and the other still has a distorted mouth. The result is a draft, not integrated or rigged; texture quality and movement remain unresolved. Existing Godot import empty-name and sandbox certificate/editor-settings warnings remain.

## 2026-10-29 - Rig two-view fighter

**Intent and changes.** At the user's request, submitted the regenerated two-view fighter to Hyper3D's human rigging pipeline. Saved PBR and shaded rigged GLBs under `assets/models/characters/human_fighter/regenerated/` and recorded job provenance in its README. The user requested high-fidelity textures and approximately 20,000–200,000 vertices for future generated assets; this preference is recorded in GAME_RULES. The current playable character remains unchanged.

**Verification and limits.** Both rigged GLBs contain 30,034 exported vertices, 55,456 triangles, one 52-joint skin and no animation clips. Godot headless import completed and both variants loaded; all 52 joints mapped through the current animation bridge, and a sampled running-leg direction matched the source. A Blender rest-pose render was inspected. There was no interactive or in-game visual animation test; skinning in motion, the generated rough skin, and the previously identified mouth-profile defect remain unresolved. Existing sandbox certificate/editor settings and editor empty-name diagnostics remain.

## 2026-10-29 - Regenerated fighter rig animation preview

**Changed and verified.** Kept the two-view rigged model as a separate draft. Used a temporary test-mode scene to attach it to the current retargeting bridge and weapon, and inspected OpenGL frames of sword idle, run and attack. The model follows the clips and the sword stays near the hand in the sampled frames, but shoulder skinning remains imperfect. These are sampled stills, not an interactive motion or full weapon/seat test. The existing playable fighter was not replaced.

## 2026-10-29 - Switch playable fighter to regenerated rig

**Changed.** At the user's request, `scripts/player.gd` now loads `regenerated/fighter_rigged_pbr.glb` as the default player visual. The original animation bridge and weapon attachment remain, and the earlier refined model is preserved.

**Verification and limits.** Headless fighter-retarget, camp seating, basic attack and animation-selection tests passed after the switch. The same rig was inspected in test-mode OpenGL idle, run and attack frames before switching. Interactive motion, seating, weapon variants and visual appearance need review; the generated rough skin, uneven mouth profile and shoulder deformation remain known issues. Existing sandbox log/certificate and test-shutdown diagnostics persist.

## 2026-10-29 - Higher-density fighter attempt

**Intent and changes.** The user reported distorted-looking body and possible baked lighting or low texture quality. Submitted a new generation from the same front and side references using the connected Hyper3D tool: Gen-2.5-High, Quad target 50,000, texture de-lighting enabled, and a prompt for natural anatomy and even unlit skin. Job `8ab73a67-c853-47c9-958f-5f464afa4105` completed and returns PBR and shaded GLBs. The available MCP/CLI controls do not expose the API's Extreme-High tier or high-resolution texture options. No game assets or code were replaced.

**Verification and limits.** Completion and output names confirmed by Hyper3D. The output has not been downloaded, inspected, rigged, or tested; actual vertices, texture dimensions, appearance and suitability remain unknown. No claim of improvement is made.

## 2026-10-29 23:40 - Remote changes from another machine (automatic)

**Source.** `origin/main` moved from `df45631d` to `c1a85845`. Local HEAD is `df45631d`.

**Commits not authored on this PC** (local identity: `bratasanu.stefan@gmail.com`):

- `c1a85845` 2026-10-29T23:39:29+02:00 **XyLeS** - Merge branch 'main' of https://github.com/stefanbratasanu/xyles-mmo (517 files, +203/-65372) [not in local HEAD]
- `945aa434` 2026-10-29T23:26:47+02:00 **XyLeS** - Update 8 (32 files, +851/-56) [not in local HEAD]

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
- `assets/models/trees/generate_trees.py`
- `assets/models/trees/tree_birch.glb`
- `assets/models/trees/tree_dead.glb`
- `assets/models/trees/tree_oak.glb`
- `assets/models/trees/tree_pine.glb`
- ... and 473 more source file(s)
- Generated Godot metadata: 4 `.uid`/`.import` file(s) (regenerate with a headless import)

**Flags.**

- Core file changed: `scripts/enemy.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/game_hud.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/game_state.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/main.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/player.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/world_builder.gd`. Re-run the game and the tests before trusting it.
- Hard failure calls on 6 added line(s).

**Proposed actions (not applied).**

- **Re-verify:** launch the game, run the tests, and re-read the changed core files against `GAME_RULES.md`.
- Nothing was changed automatically. Confirm each action with the user before editing or reverting.

**Status.** Awaiting the user's decision. This report did not modify any game code.

## 2026-10-29 - User-tweaked playable fighter

**Changes.** Downloaded the user's edited Hyper3D model (`df18cad1-2a09-4c2f-9058-f4302348557b`): OBJ plus texture images, with no OBJ material library. Submitted humanoid rigging job `9f8ddefd-f041-42bc-9ac7-37b72d4917a3` and selected its PBR GLB in `player.gd`, retaining the prior assets and game animation bridge. The rigged export has 63,990 vertices, 52 joints, no animation clips, an embedded 4K diffuse texture and 2K normal and metallic/roughness textures.

**Verification and limits.** Headless import and fighter-retarget, camp-seating, basic-attack and animation-selection tests passed. OpenGL test-mode idle and run frames were inspected with the material visible; interactive playback, all poses and weapon grips need review. Existing sandbox certificate/editor-settings and exit diagnostics persist. The remote checker found two incoming commits from another machine; they remain unmerged and its report is preserved above.

## 2026-10-29 - Fighter skin normal correction

**Evidence and change.** After the user reported the face looked wrong, compared a Blender render of the downloaded OBJ using its diffuse texture to the rigged PBR GLB. The rigged normal map greatly exaggerated fine facial and skin detail; the downloaded source geometry and color also already differ from the reference. `player.gd` duplicates the generated material and disables its normal map at runtime, keeping the 4K color texture and other PBR properties; the GLB remains unchanged.

**Verification and limits.** Fighter retarget test passed and an OpenGL test-mode idle frame showed smoother skin. This cannot repair the source model's facial proportions or texture, and the user's interactive visual review is still needed. Existing sandbox and renderer shutdown warnings remain.

## 2026-10-29 - Original-skeleton binding investigation

**Intent and evidence.** The user requested checking whether the animation-pack character's bone structure could be adapted to the generated fighter. The original player rig has 55 bones including root and helper bones; the Hyper3D rig has 52 joints with different bone rest positions, orientations and skin weights. Neither provides facial articulation. The face in the downloaded OBJ remains visually unlike the supplied reference even in a static diffuse-only render, so its proportions and texture are independent of retargeting.

**Experiment.** In a temporary test-mode probe, mapped the generated skin's joints directly to corresponding original-skeleton bones, built rest bind transforms, and attached the weapon to the original hand. Rendered sword idle and run frames using OpenGL. The body retained some movement but hands and fingers stretched severely and the face did not improve; this straightforward bind is not usable. It was not applied to the playable character. A proper transfer requires fitting the rest pose and reauthoring skin weights, then visually testing all poses; facial geometry/texture requires separate correction.

**Verification and limits.** OpenGL test-mode probe completed; no gameplay files changed by the experiment. Existing playable character and retarget bridge remain. Test-exit rendering resource diagnostics persist.

## 2026-10-30 - Fitted original skeleton experiment

**Intent and experiment.** At the user's request, continued testing adaptation of the original animation-pack bones to the Hyper3D fighter. A temporary test-mode script maps all matching bones, transforms each weighted vertex and normal from the generated rig's rest pose to the original skeleton's rest positions and directions, rebuilds bind poses, and attaches the weapon to the original right hand. No player code or source assets were replaced.

**Result and limits.** Inspected OpenGL sword-idle and running frames. The previous direct bind's exploding fingers no longer appeared, but the torso was visibly stretched and deformed, and the face remained unlike the reference. The experiment is unsuitable for integration; its script and images are in ignored `logs/`. This does not complete a proper rebind: manual rest-pose fitting and weight painting plus full animation review remain, and the face geometry/texture needs separate correction. Existing test-mode renderer shutdown diagnostics persist.

## 2026-10-30 - Native animation-pack skin for the playable fighter

**Problem.** The generated fighter's 52-joint rest pose, spine pivots and skin weights did not match the original animation-pack skeleton. Merely mapping bones or moving every weighted vertex to each original joint distorted the torso and hands. The requested fix was to adapt the original rig to the generated model.

**Implemented.** The player now loads `assets/models/characters/human_fighter/native_skin/fighter.tscn` under its existing `Skeleton3D`, hides the original body and binds the new body directly to the original 55-bone skeleton. It uses 53 named skin binds, including the original hand and finger bones. No separate fighter skeleton or per-frame retarget bridge is created. The weapon remains on the original right-hand attachment. Existing animations, upper-body overlays, seating, movement and gameplay code keep the original rig.

**Asset preparation.** The build exports both bodies and the original rig; rotates/translates generated limbs into the original rest pose while leaving axial torso/head geometry in place; welds imported UV splits; relaxes the shoulder transition; transfers weights by nearest-surface interpolation from `SK_Protof-Actor`; smooths weights and limits/normalizes four influences. Welding before weight smoothing prevents the visible UV-seam cracks found in the first native test. The final compressed mesh resource has 53,975 exported vertices and 100,000 triangles. Its material references the user's original 4096px diffuse and 2048px roughness maps, without the exaggerated normal map. Source files are preserved. The repeatable pipeline is saved in `scripts/dev/fighter_skin/`; intermediate files are placed under ignored `logs/fighter_skin_build/` with `.gdignore`. `fighter_retarget.gd` is retained only as an offline source of rest mappings.

**Verification.** Rebuilt successfully with Godot 4.7.2 and Blender 4.4.3. Updated `tests/test_fighter_retarget.gd` to validate the native binding: single original skeleton, correct bind names/indices, 4K texture, requested vertex range, normalized weights for every vertex, identical weights at UV duplicates, rest-position error below 0.0001m (measured maximum 0.0000742m), bounded sampled skin positions in idle/run/attack/seated clips and sword attachment. It passed, as did camp seating, animation selection (242 imported clips) and basic attack. Inspected front/side/back OpenGL captures of sword idle, walk, run, attack and a seated pose. Test-mode normal startup completed without parse errors, script errors or runtime `[ERROR]` events. Existing Godot renderer shutdown RID/resource diagnostics remain; headless sandbox runs also report unavailable home-log/certificate writes.

**Limits.** This improves the body binding and animation compatibility; the downloaded model's facial proportions and baked skin shading remain. A separate head-smoothing experiment softened the eyes excessively and was not included. The rendered checks sample poses rather than all 242 clips; a full interactive Direct3D 12 motion review remains. Remote changes previously reported from another machine are still unmerged. No commits or pushes were made.

## 2026-10-30 - Correct rejected fighter body fitting and shading

**User feedback and diagnosis.** The screenshot showed that the preceding native-skin conversion was visibly unacceptable. The earlier claim that rig compatibility was resolved overstated the evidence. Independent geometry/normal audits under logs/ found the original fitting blended large limb-joint translations into chest/waist vertices shared with shoulder/thigh weights. Matched surface points showed outer-chest displacement up to about 12cm and waist/pelvis displacement up to 13cm. Custom normals also survived mesh deformation and shoulder smoothing: the final native model had 9,330 corners differing strongly from geometric normals and 779 inverted directions. The existing tests checked numerical bounds but missed these visual defects.

**Correction.** Added `scripts/dev/fighter_skin/build_anatomy_rig.gd`, which adapts the original animation-pack hierarchy and bone axes/positions to the generated anatomy. It does not reshape vertices: only the established uniform scale/placement is applied. The new `assets/models/characters/human_fighter/anatomy_rig/character.tscn` and body.res retain 63,990 vertices, 100,000 triangles, original UVs/weights/normals and 4K diffuse. `scripts/fighter_animation_adapter.gd` duplicates and caches libraries, adapts bone-position keys to the fitted rests while retaining motion deltas and original rotations, and adds missing static bone tracks. `player.gd` adapts libraries before building its seating pose. `scenes/main.tscn` and the player's fallback scene both use the new character. The old native_skin version is retained and marked superseded. No texture regeneration or provider requests were used.

**Verification.** Updated `tests/test_fighter_retarget.gd` to compare every output vertex/UV/normal against the actual input. Source-shape error is zero; maximum packed-normal vector error is 0.000130, and maximum CPU rest-skin error is 0.000133m (weight packing). Normalized weights, UV-seam equality, bind names, single skeleton, material resolution, bounded animated vertices and weapon attachment pass. Camp seating, animation selection (242 clips) and basic attack pass. Inspected OpenGL front/side/back captures and Direct3D 12 Forward+ low-angle/close captures for idle, walk, run, attack and seated poses. Rendered sessions completed without script/parse errors; existing renderer-exit resource diagnostics persist. Runtime logs show no handled ERROR events in these flows.

**Limits.** The conversion-induced chest/waist stretching and invalid shading normals are removed. Source facial likeness, baked shading/tattoo artifacts and automatic skinning limitations remain, and sampled poses are not a full 242-clip interactive acceptance test. No shared Git history, remote commits or user saves were changed.

## 2026-10-31 - Head-focused replacement and 5-by-5 body draft

**Request.** Improve the unacceptable generated face, then provide independent five-level size/fat and five-level muscularity choices (25 combinations), not five bundled physiques.

**Assets and implementation.** Downloaded the already-submitted Hyper3D job `17559b21-2d9c-4a46-a9c8-d8164cd5e696` (Gen-2.5-High, 30k quad target, de-lighting) using cropped supplied front/profile references. Head output: 28,808 vertices, 2K textures. Neutral front and both profiles have clearer eyes/lips than the old source. `head_revision/` contains the raw head, combined source, and experimental original-hierarchy rig. The combined export has 68,987 vertices with separate 4K body/2K head atlases. `build_head_revision.py` joins neck boundaries, samples original neck weights/colors, welds UV duplicates while preserving corner UVs, and creates joint-centered endpoint morphs. `build_head_rig.gd` preserves multiple materials and blend shapes when adapting the original animation skeleton. `fighter_body_shapes.gd` exposes independent 0–4 values; `fighter_body_surface.gdshader` softens baked abdominal detail on low-muscle/high-fat combinations. Material instances are isolated per actor.

**Verification and limitations.** `test_fighter_body_shapes.gd` passes all 25 combinations, normalized weights, geometry bounds, requested vertex range, and independent instances. D3D12 test-mode grids of initial iterations exposed stretched torso boundaries, visible muscle detail at the soft endpoint and stale-normal artifacts. Corrected hard torso/limb boundaries, smoothed endpoint displacement, and regenerated normals; kept the asset experimental because neck transition and extreme-body art still require refinement. Test-mode renders do not alter saves. The original playable default is unchanged, and no character-creation UI/persistence was added. This is partial asset work, not an accepted final art pass. Godot headless sandbox reports certificate/user-log access errors; renderer runs use normal local-cache access. No pull, commit, push or changes to the two incoming remote commits.

## 2026-10-31 - Expose the creator from character creation

**Cause.** The preceding pass created only asset/preset infrastructure. `character_select.gd` had no entry point, preview or appearance persistence, so the user could not access customization.

**Change.** Added APPEARANCE to the existing creation form and a modal preview using its existing classic_frame, dark brown/bronze/ivory styling and helper buttons/labels. Reviewed the reference topic; its linked main screenshot failed to load, so followed UI_STANDARD and the existing menu's visual language. Two five-choice selectors update the isolated 3D preview; rotation permits profile/back review. USE APPEARANCE accepts, BACK/Escape cancels. The screen identifies the draft art status. `character_store.gd` accepts appearance data; `game_state.gd` normalizes and persists it with backward-compatible empty defaults. `main.gd` applies the chosen appearance after loading. `player.gd` installs the selected mesh and clones/rebinds its skin precisely to the existing animated skeleton, preserving gameplay/weapon logic. The body controller exposes explicit material initialization for this path. Existing saves without appearance data keep their old visual.

**Verification.** Extended `tests/test_characters.gd` through the real button signal, five-by-five controls, live preview, acceptance/cancel, save/load, malformed values, rig compatibility within export precision and world application. Also corrected its obsolete uppercase-only HUD-name assertion to match existing mixed-case HUD behavior. Headless and D3D12 tests pass (0 failures). Inspected `.godot/appearance-creator-preview.png`: correct front-facing model, visible controls, rotation and action buttons within the frame. No script/parse errors in the rendered flow; pre-existing shutdown resource diagnostics remain. No shared-history changes, user-save edits or remote pull. This fixes creator access and persistence, not the outstanding body/neck art quality.

## 2026-10-31 - Correct neck atlas mapping and non-shrinking body morph smoothing

**Findings.** The collar faces use the body material but previously copied UVs from both neighboring materials, sampling unrelated body-atlas regions for donor-head coordinates. The morph relaxation averaged absolute positions, unnecessarily shrinking extremities. The soft-body shader sampled mip 7 of a 4K atlas (32px equivalent), losing local skin detail and risking UV-island color bleed.

**Changes.** `build_head_revision.py` now derives all collar UVs from nearest original body samples and smooths displacement vectors rather than absolute vertex positions. `fighter_body_surface.gdshader` uses a local nine-tap mip-5 filter instead of the coarse atlas sample. Rebuilt head_revision source.glb/body.res/character.tscn; combined vertex count is 69,191. Extended `test_fighter_body_shapes.gd` to assert head/neck invariance across all 25 presets.

**Verification.** Shape checks pass (25 combinations, normalized weights, instance independence, finite bounds, fixed head/neck); character-flow tests pass including save/load and playable application. Rendered all combinations in D3D12 through `apply_character_appearance`, then sampled largest/softest idle, walk, run, attack and seated poses. No parse/script errors. The source neck color boundary and patchy/angular torso appearance remain visible, including with directional shadows disabled. Do not interpret passing tests as final visual acceptance. No user saves, remote commits or gameplay rules changed; no new provider generation used. Existing renderer shutdown resource diagnostics persist.

## 2026-10-31 - Fix neck color boundary, cut-ring crease and exported blend data

**Request.** Fix the remaining neck seam and related defects. The prior UV correction alone left a material-color discontinuity and a tangent crease at the joined rings.

**Implementation.** `build_head_revision.py` now samples a common neck color, converts it from sRGB to linear, stores a smooth localized alpha mask on both head/body vertices, relaxes geometry across the welded join, and recalculates face normals. Blender previews blend the source texture toward that common color rather than multiplying a one-sided ratio. The runtime `fighter_body_surface.gdshader` uses the same blend. `fighter_body_shapes.gd` initializes this shader for both materials from the mesh resource, preserving per-instance softness and making initialization repeatable. An in-game white-model check exposed Blender exporting a white placeholder as COLOR_0 with the named blend attribute as COLOR_1. The build now remaps the actual attribute to COLOR_0 in the GLB JSON while preserving binary data and textures; this addresses the actual cause of missing blend data in Godot. Rebuilt combined asset: 69,207 vertices.

**Verification.** `test_fighter_body_shapes.gd` now checks that both surfaces contain localized masks, non-white linear skin targets and the runtime shader, in addition to all 25 combinations, stable head/neck, weights and instance isolation. It passes. `test_characters.gd` passes creation, preview, save/load and playable application. Inspected neutral Blender renders and D3D12 front/both-profile close-ups; the sharp horizontal neck line and material boundary are removed in these views. Sampled largest/softest idle, walking, running, sword attack and sitting captures retain the join. No script/parse errors; existing shutdown RID/resource warnings persist. Source torso/tattoo shading and extreme physique realism are still art limitations, not claimed fixed. No new external generation, save modification, pull or commit.

## 2026-10-31 - Rebuild the rejected skinny/heavy appearance presets

**Failure.** User screenshots showed an enlarged muscular torso with stick-thin limbs at the skinny end and inflated hips/high abdomen at the heavy end. Four independent additive endpoint deformations could compound size/muscle reductions. Texture blur also retained the source sculpt's actual abdominal grooves. Bounds tests had not established acceptable anatomical proportions.

**Implementation.** Added `scripts/dev/fighter_skin/physique_shapes.py` and connected it to the repeatable head-revision build. It produces a complete target for each size/muscle combination (24 targets plus the existing neutral basis), with one active target at runtime. Soft geometry uses a continuous abdominal envelope rather than merely scaling the existing carved abdomen; joint-centered volume changes taper into wrists/ankles and preserve the head/neck join. Heavy volume concentrates around the abdomen with restrained back/hip expansion. A geometric pelvis expansion experiment created an obvious shorts ring and was excluded after profile review. `fighter_body_shapes.gd` selects the complete named preset while preserving existing saved indices. The shader reduces broad painted muscle contrast toward the sampled skin tone while retaining fine detail. Motion inspection also found thigh weights above the pelvis: the build fades those influences into Hips across the lower abdomen (3,060 affected vertices), retaining leg/shorts and hand/finger bindings elsewhere. The combined asset retains 69,207 exported vertices, 4K body/2K head maps and the original 55-bone animation hierarchy.

**Verification.** Extended body-shape checks to ensure one complete preset is selected, size steps increase actual torso width (excluding arms via skin weights), skinny/soft limb displacement stays limited, the lower back is restrained, and upper-abdomen skin has no thigh bleed. Corrected the test's back/front sign to match the imported +Z-forward mesh. All 25 combinations pass these checks, existing head/neck/color-channel checks and normalized weights. Added `test_fighter_physique_motion.gd`: all 150 preset/rest/idle/walk/run/attack/seated checks pass, with max rest-bind error 0.0000727m. `test_characters.gd` passes, including actual saved-target activation. Captured all 25 builds from front/profile using the reusable `review_physiques.gd` in D3D12. Inspected extreme-preset walk/run/attack/seated images and ran the actual camp sit/stand interaction with the heavy preset (PASS). No script/parse errors; existing renderer shutdown RID/resource diagnostics persist. Source skin/tattoo and facial detail remain rough; this pass fixes the rejected physique construction rather than claiming final art fidelity. Logs and comparison PNGs are under ignored `logs/physique_rebuild/`. No external generation, user-save changes, pull, commit or push.

## 2026-10-31 14:44 - Remote changes from another machine (automatic)

**Source.** `origin/main` moved from `c1a85845` to `f4316f79`. Local HEAD is `df45631d`.

**Commits not authored on this PC** (local identity: `bratasanu.stefan@gmail.com`):

- `f4316f79` 2026-10-30T17:27:46+02:00 **XyLeS** - Wolrd (54 files, +3762/-23) [not in local HEAD]

**Files touched by the external commits:**

- `CURRENT_WORK.md`
- `Documentation/IMPLEMENTATION_LOG.md`
- `Documentation/PROJECT_DOCUMENTATION.txt`
- `Documentation/WORLD_EDITOR.md`
- `GAME_RULES.md`
- `scenes/world_editor.tscn`
- `scenes/world_editor_preview.tscn`
- `scripts/dev/world_editor_launcher.cs`
- `scripts/game_state.gd`
- `scripts/main.gd`
- `scripts/world_builder.gd`
- `scripts/world_editor/asset_catalog.gd`
- `scripts/world_editor/draft_store.gd`
- `scripts/world_editor/map_editor.gd`
- `scripts/world_editor/map_preview.gd`
- `scripts/world_editor/map_runtime.gd`
- `scripts/world_editor/terrain_grid.gd`
- `scripts/world_editor/zone_data.gd`
- `scripts/world_map.gd`
- `tests/test_combat_effects.gd`
- `tests/test_progression.gd`
- `tests/test_skill_panel.gd`
- `tests/test_world_editor_assets.gd`
- `tests/test_world_editor_drafts.gd`
- `tests/test_world_editor_game.gd`
- `tests/test_world_editor_game_terrain.gd`
- `tests/test_world_editor_lake_visual.gd`
- `tests/test_world_editor_preview.gd`
- `tests/test_world_editor_runtime.gd`
- `tests/test_world_editor_terrain.gd`
- `tests/test_world_editor_updates.gd`
- `tests/test_world_editor_visual.gd`
- `tests/test_world_editor_workflow.gd`
- `tests/test_world_editor_zones.gd`
- `WORLD EDITOR PREVIEW.bat`
- `XYLES WORLD EDITOR.exe`
- Generated Godot metadata: 18 `.uid`/`.import` file(s) (regenerate with a headless import)

**Flags.**

- Core file changed: `scripts/game_state.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/main.gd`. Re-run the game and the tests before trusting it.
- Core file changed: `scripts/world_builder.gd`. Re-run the game and the tests before trusting it.
- Executable/script added or changed: `WORLD EDITOR PREVIEW.bat`. Do not run it until reviewed.
- Executable/script added or changed: `XYLES WORLD EDITOR.exe`. Do not run it until reviewed.
- Hard failure calls on 171 added line(s).

**Proposed actions (not applied).**

- **Re-verify:** launch the game, run the tests, and re-read the changed core files against `GAME_RULES.md`.
- **Ask first:** review the addon/executable diff with the user before it is allowed to run.
- Nothing was changed automatically. Confirm each action with the user before editing or reverting.

**Status.** Awaiting the user's decision. This report did not modify any game code.


## 2026-11-01 - Restore and verify the complete 5-by-5 character creator

**Request and regression.** Continue until the character creator follows the user's independent five size/fat levels and five muscularity levels, with a usable preview and correct playable result. Inspection found later local changes that exposed only three paired builds and quantized accepted values on reopening. Restored the two independent controls in character_select.gd, removed the paired-build helper from fighter_body_shapes.gd, and added an exact 4/0 reopen/accept regression plus coverage of all 25 reachable pairs.

**Presentation and interaction.** Added character_appearance_preview.gd: private SubViewport world, twice the displayed render resolution, 4x MSAA, soft key/fill illumination, drag/slider rotation, bounded wheel zoom, Full Body / Face / Reset framing and adapted Rest / Idle / Walk / Run previews. Portrait framing tracks head translation. The modal fits the supported minimum and larger viewports, uses the existing brown/bronze/ivory frame and choice styling, traps Tab traversal, cancels on Escape and restores focus to Appearance. Back, repeat accept and late signals are guarded. Outfit visibility is inspection-only; accepted saves retain the two cosmetic indices. The reference topic was reviewed; its main screenshot was unavailable, so the written UI standard and existing helpers supplied compact spacing, frame language and colour roles. No reference artwork was shipped.

**Asset work.** Extended physique_shapes.py with smoother low-muscle torso/limb sections and fuller heavy limbs. Rejected a direct anterior projection after rendered review exposed inverted patches: finite bounds were insufficient validation. The installed fat deformation uses a continuous spatial field rather than discontinuous hip/leg skin weights. Added a front-triangle orientation check relative to the neutral mesh; across approximately ten thousand selected front-torso triangles per preset, the installed version has a maximum of 3 reversals versus 437 in the rejected prototype. Head/neck positions remain fixed. Added outfit_geometry.py with continuous lofted/voxel-unioned cloth sections and rounded boots. build_outfit.py now reads the clean head build, rejects already dressed input, interpolates and diffuses garment weights/morph fields, and exports a body-coverage alpha mask. The runtime shader hides covered skin only while dressed; the creator restores it for silhouette inspection. The optional hair surface stays hidden in both contexts to match the bald source reference. Shared material resources are not mutated during initialization. The rebuilt asset has 130,937 exported vertices, eight surfaces, the original 55-bone hierarchy, 4K body and 2K head atlases. No new external generation or charges.

**Verification.** test_fighter_body_shapes.gd passes 25 combinations, single-target selection, progressive waist width, limb/back bounds, fixed head/neck, normalized weights, independent materials, reversible coverage and front-surface orientation. test_fighter_physique_motion.gd passes 150 preset/pose checks with maximum rest-bind error about 0.000073m. test_fighter_retarget.gd passes with zero position error against source geometry. test_characters.gd passes actual control signals, all 25 pairs, Tab/Shift-Tab, Escape, rotation endpoints, view/pose/outfit controls, accept/cancel/reopen, malformed data, save/load and playable application. review_selector.gd reports zero layout failures at 1100x650, 1600x900 and 1920x1080; portraits, extreme front/profile builds, outfit views and motion samples were inspected in D3D12 Forward+. Rendered all 25 builds from front/profile with review_physiques.gd. The heavy-preset camp sit/stand flow passes. Tested runtime flow has no handled ERROR events or script/parse errors. Existing renderer-exit RID/resource diagnostics persist. Native evidence is under ignored logs/character_polish and logs/physique_rebuild.

**Limits and repository state.** Generated skin/tattoo detail and facial likeness retain source-art limitations; geometry checks do not establish subjective visual perfection or acceptance of every frame of every animation. Choices remain cosmetic and do not change collision or stats. Updated CURRENT_WORK, UI_STANDARD, GAME_RULES and asset rebuild notes. The remote check found no new commits beyond f4316f79; the three incoming commits were not pulled or altered. No user saves, commit, push or history rewrite.

## 2026-11-01 - Race-first models, male/female support and reusable armor tooling

**Scope correction.** User replaced the five-by-five body objective with five races first, one fixed authored build each, and confirmed original classic Lineage 2 inspired proportions. They then added female models and requested reliable necks, rigging, fidelity and streamlined armor generation. This entry supersedes the prior body-control objective; the underlying experimental morph data is retained for possible later work, but no size/muscle controls remain in the selector.

**Art and catalog.** Created nine original front-reference images with built-in ImageGen: male Orc/Elf/Dark Elf/Dwarf, and female Human/Orc/Elf/Dark Elf/Dwarf. References match the supplied Human style and neutral A-pose setup; female figures are adult and clothed in opaque athletic undergarments. Saved all references under assets/concepts/characters/races. resources/characters/race_models.json defines ten explicit entries, intended heights, concept paths, readiness and fidelity targets. The existing Human male is the only reviewed 3D scene. Pending entries display their own reference and preparation status; new creation is disabled until a reviewed scene exists. They are never shown as a Human mesh labeled as a different race. Existing journeys remain loadable with the current fallback while art is pending. No new paid 3D generation was submitted.

**Identity and runtime.** Added backward-compatible character_gender persistence and validation (Male for old saves) in game_state/character_store, plus the Male/Female selector. New creation and rendering use the fixed reference build without rewriting old body indices on disk. The preview and player resolve the same reviewed catalog scene. player.gd copies each model's skeleton rests, clears old material overrides, rebinds skin and rebuilds adapted libraries. New race materials retain provider PBR data through race_character.gd; they do not receive the old Human tint or replacement-head neck band. fighter_animation_adapter.gd now keys its cache by rest transforms as well as library identity, preventing human joint translations leaking into dwarf proportions. Added a regression that changes pelvis height and checks the resulting position track. A camp test caught duplicate seat-library registration during reapplication; removed the old library before rebuilding the pose and reverified sitting/standing.

**Tools.** scripts/dev/characters/race_pipeline.py uses the installed Hyper3D CLI, requests Gen-2.5-High/50k quads/de-lighting/GLB with high-fidelity 4K albedo requested in the prompt, records job state before submission and never automatically retries an uncertain paid action. curl_fetch.mjs provides a Windows HTTPS fallback with credentials in process pipes only, cancellation and URL-only diagnostics. build_race_rig.gd fits the original animation skeleton to source anatomy with uniform geometry placement, rejects unmapped bones/multiple meshes and preserves PBR materials. normalize_skin.py retains raw inputs, normalizes four influences and equalizes duplicated-seam weights. audit_model.py checks body budget, actual albedo sizes, rig count, weights, seam consistency and open neck boundaries; it excludes Blender bone widgets. fit_armor.py creates a chest modeling seed or binds an authored armor mesh by closest-triangle barycentric interpolation, supports explicit rigid-bone plates, enforces rest clearance, rejects misalignment and writes an audit report. Equipment exports exclude source body geometry. Commands, prompts, acceptance limits and current readiness are documented in Documentation/Characters/RACE_AND_ARMOR_WORKFLOW.md.

**Verification.** Updated test_characters.gd for fixed builds, both genders, old-save defaults, all ten reference previews, pending-model creation guards and save/load. Headless and rendered passes report zero failures. test_race_catalog.gd reports zero failures for ten entries and race-specific animation caching. Rendered the form/preview at 1100x650, 1600x900 and 1920x1080; all ten entries reviewed, zero layout failures. Existing fighter anatomy checks pass, and rendered camp sitting/standing passes after the seat-library fix. Generic race builder smoke test creates a 55-bone/63,990-vertex scene in ignored logs without touching installed assets. Raw provider audit correctly caught excess skin influences; a normalized copy passes weight/seam/neck checks. Chest seed and rigid Spine2 rebinding pass armor audits (one armature, no bad weights or seam mismatches). Native evidence is under logs/race_build. No script/parse errors in final tested flows; pre-existing engine resource/RID shutdown diagnostics persist.

**Blocker and remaining art.** Hyper3D's saved generation login expired. Account lookups stalled, direct MCP read confirmed expired authentication, and the first device authorization expired without issuing tokens despite browser confirmation. A fresh device flow is awaiting browser completion. The nine new full 3D models, provider rigs, neutral/game-light neck and face review, and animation acceptance remain unfinished. Concepts and tooling are not represented as completed playable assets. The remote checkpoint is still f4316f79 (three incoming commits unmerged); no pull, history rewrite, commit, push or user-save modification.

**Authorization follow-up.** The second device code also expired without tokens;
no authorization process or paid model job remains active. Resume with a fresh
CLI device login when the user is ready, then verify via an existing generation
read before creating new jobs. The remaining production model work is blocked
by authorization, not represented as complete. Skin cleanup's GLB round trip was
also checked against source positions with a 10-micrometre tolerance; preserve
raw provider files for exact comparisons.


## 2026-11-01 - Ten playable race/gender models installed

Hyper3D authorization succeeded. Completed nine Gen-2.5-High / 50k-quad model
jobs and nine humanoid/core rig jobs, with the original supplied Human male
retained as the tenth choice. Human, Orc, Elf, Dark Elf and Dwarf now each have
Male and Female scenes enabled in resources/characters/race_models.json. One
fixed authored build per entry; size/muscle controls remain inactive. Existing
saves retain their identity, and loading a female Dark Elf now installs her
actual model rather than the temporary Human fallback.

The nine new exports have approximately 50k vertices each, normalized maximum
four influences, consistent duplicated-seam weights and no open neck boundary.
Source PBR/provider rig GLBs remain intact; normalized rigged.glb and generated
body.res/character.tscn are stored per model. Runtime rigs have the animation
pack's 55-bone hierarchy fitted to each body's own joint positions. The model
builder preserves anatomy with uniform scale/feet placement. Provider normal
maps exaggerated facial/body bumps, so runtime normal strength defaults to zero;
original maps remain available. The Human female ponytail-tip pale projection
artifact received an explicit material correction in normalize_skin.py.

Actual delivered PBR atlases are 2048x2048. A 4K request in the prompt did not
produce 4K files; do not describe the new textures as 4K or the art as flawless.
The original Human male retains its previous 4K body / 2K head assets. Hair and
facial detail remain generated art with limited atlas resolution; no facial
animation or hair simulation was added. Armor tools create modeling seeds and
fit authored equipment; they do not constitute a completed armor collection.

Verification: all nine asset audits pass. All nine new bodies pass nine actual
player-skeleton rest/idle/walk/run/weapon/attack/seat pose checks, with maximum
sampled rest-binding error below 0.000083m. Neutral source renders and Godot
Forward+ D3D12 front/back/both-profile/face/idle/walk/run renders were inspected.
Character creation/save/load and ten-entry race/cache tests pass. The selector
has zero layout failures at 1100x650, 1600x900 and 1920x1080, with all ten live
3D entries. Rendered camp sit/stand tests pass for the shortest female Dwarf and
tallest male Orc. Female Dwarf chest-seed fitting and skin audit also pass.
Native review evidence and job checkpoints are under ignored logs/race_build.
Existing engine shutdown resource/RID diagnostics remain; no script/parse errors
were found in these final tested flows. Geometry/bounds tests do not establish
subjective perfection or acceptance of every animation frame.

Updated character_select's preparation note, test_characters' now-obsolete
Human-fallback assumptions, and test_camp_seating's optional --model=ID fixture.
The armor workflow documents the actual API fidelity and authorization state.
No user saves, incoming commits, shared history, commit or push were changed.
The remote checkpoint remains f4316f79; three incoming commits stay unmerged.


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

## 2026-11-01 - F6 current-animation replacement and F7 weapon calibration

User clarified that F6 captures the animation playing when pressed, including
when the animation window is already open; selecting a new clip then replaces
that active visual without requiring a skill/action mapping. F6 now captures
the active upper-body layer if present, otherwise the base AnimationPlayer, and
opens or keeps the selection window. Picking a clip plays it immediately on the
actual character and in the preview. Live replacement is full-body regardless
of the mapping's upper-body option. Existing per-weapon/action Save Mapping is
still separate: temporary replacement does not rewrite combat configuration.
Nonlooping replacements release on completion; loops have Stop Override. Skill
and locomotion animation requests cannot overwrite an active replacement.
Death releases the override. Roll presentation yields while its movement timer
continues. Seated transitions are protected from replacement. No skill damage,
cooldown, mana, or other gameplay timing is changed by these visual controls.
The preview uses the installed model's adapted animation libraries.

F7 now opens Weapon Position instead of Actions. Its XYZ metre and XYZ degree
fields adjust the actual weapon relative to the animated hand immediately.
Save Grip writes resources/characters/weapon_grips.cfg, keyed by model ID,
weapon type and visual variant. Re-equipping/reloading/model switching reapplies
the matching calibration, with authored transforms as the fallback. Reset to
Model resets live values; Save makes that reset persistent. Empty hands show an
equip-weapon message. Failed saves report their error without updating cached
saved data. This is a development authoring panel; exported read-only resources
cannot be saved. Actions remains accessible from the corner menu. F6/F7 are
reserved against debug-key reassignment and old debug handlers.

UI reference topic was opened; the existing written UI standard supplied the
compact rows, dark brown/bronze/ivory frame, helper labels/buttons and hierarchy.
The new panel reuses the registered floating frame, title drag, viewport clamp
and saved layout mechanism. It initially opens at the right to leave the player
visible. No reference artwork was copied. Animation controls retain the existing
window's style. Files: player.gd, animation_selection.gd, game_hud.gd, main.gd,
weapon_grips.gd, weapon_position_panel.gd and the focused test. Updated the older
training-shortcut fixture to use free key P now that F7 is reserved.

Verification: test_weapon_controls passes headless and Forward+ D3D12: capture
of channel overlay, selection replacement, repeat F6 while open, superseding
skill/locomotion requests, nonloop release, F7 fields, disk save/reload,
re-equipping, independent race calibration and return to the original race.
Native F6/F7 captures were visually inspected in logs/weapon_controls_*.png.
test_animation_selection passes with 242 imported clips; test_basic_attack
passes. The legacy training-minion test stops at line 48's skill cooldown
assertion before its debug-rebinding checks, consistent with the previously
recorded legacy skill-test problems; its entire run is not claimed passing.
Existing engine-exit RID/resource diagnostics remain. Final tested controls
have no script/parse errors. No real calibration file, user saves or UI/settings
file was written by the tests (grips use an ignored logs fixture). Remote check
found no new commits beyond f4316f79; incoming work was not pulled or changed.

## 2026-11-01 - Human male rebuilt to match the race set

User rejected the default Human male's synthetic clothing/style mismatch and
requested a new classic Lineage 2 inspired Human fighter from scratch. Built-in
ImageGen produced a new original reference: adult clean-shaven athlete, medium
dark middle-parted hair, square jaw, natural proportions, plain charcoal training
shorts, bare feet, neutral A-pose and even studio lighting. User's clothed game
screenshot supplied style inspiration, not an outfit to bake into the body.
Reference: assets/concepts/characters/races/human_male_front_v2.png, with prompt
summary in that folder's README. Hyper3D Gen-2.5-High/Quad 50000/de-lighting then
generated a new PBR mesh and human/core rig. This is a new asset, not a clothing
visibility patch or a replacement head on the old body. The installed model has
48,942 vertices, one surface, actual 2048x2048 PBR maps, a continuous head/neck,
normalized top-four influences and the fitted 55-bone animation hierarchy.
Provider normal maps remain stored but are disabled in the runtime to match the
other races' shading. No 4K fidelity or hand-authored facial detail is claimed.

Geometry job 1ab79795-26d3-48ce-bfa2-db4604ab73f7; rig job
e86afc2f-6420-4186-84ae-db6c9df00386. Both completed once; no paid retries.
Raw geometry/provider rig, normalized GLB, runtime mesh/scene and non-secret
provenance.json are under assets/models/characters/races/human_male. Replaced the
catalog scene, player.gd default, main.tscn default instance and isolated-preview
fallback together. The animation selection preview also resolves the active
catalog model. The previous head_revision and experimental morph sources are
retained for history but are no longer the default. One authored build remains;
no new body morphs or clothing were added. Old saves keep Human/Male identity
and now render the new base. Existing weapon calibration identity remains.

Updated source-preservation regression to compare the actual current source and
uniform height/ground placement, rather than the old head-revision scale/4K
assumption. Character tests now check the disabled outfit control and intact PBR
materials on base meshes without separable coverage. Review tools can inspect
a built Human male before changing catalog readiness.

Verification: Blender skin/vertex/atlas/neck audit passes. Source neutral and
Godot Forward+ D3D12 front/back/both profiles/face/idle/walk/run were reviewed.
Actual player nine-pose test passes (803 samples, maximum rest error ~0.000072m).
Full source anatomy/UV/normal regression passes with zero source-shape error.
Character creation/save/load, ten-entry catalog, 242-clip animation selection,
F6/F7 controls and basic attack tests pass with the new default. Three-size
selector layout passes with all ten entries. Rendered Human male camp sitting
and standing passes. Native evidence: logs/race_build/rendered/human_male_*.png,
review/race_0_0_1600x900.png and human_male_*.log. No script/parse errors or handled
runtime ERROR events in the final tested flows; existing renderer-exit resource
warnings and the previously documented broad legacy-suite failures remain.
A running game must be relaunched to load the new default scene. No user saves,
commit, push, pull or incoming developer work was changed.

## 2026-11-01 - Relaxed travel, separate ready stance and distance-matched pace

User rejected fighting idles being used for ordinary standing and the boxing
posture in movement. Source inspection confirmed unarmed_idle/run/walk were
imported from Combat Bare Fists, while sword_idle used IdleCombatS&S (imaginary
shield guard). Imported a separate 63-clip travel library from the supplied
Basic Locomotion set, with ordinary idle/walk/directional run/sprint, a faster
ordinary run, closed right-hand carrying variants and upright long-weapon carry.
Right-hand rotations are authored from the original animation skeleton: sword
blade continues the lowered forearm away from the body; long weapons stay
upright. Neither meshes nor skeleton rests are warped. Original combat clips
remain available for compatibility and authoring. Source sword breathe was
reviewed and rejected for peaceful standing because it still has a shield guard.
One-handed fencing ready supplies sword combat_idle without a raised offhand
shield pose. The private character preview now uses the ordinary travel set.
F6 labels/search distinguish Relaxed travel from Combat stance.

animation_profiles.gd separates idle and combat_idle. Player attacks/blocking
refresh a four-second presentation timer; active channels hold it. Peaceful
standing is arms-down, and attack readiness expires back to relaxed idle.
Death/revival clears readiness. This is visual state, not a gameplay combat flag.
Existing custom mappings are retained. F6 temporary overrides still take priority;
F7 saved weapon grips are unchanged. Travel direction changes preserve the step
phase instead of restarting the cycle. Basic attacks and skill damage/timing
are not changed by these presentation selections.

The user additionally requested approximately 30 percent slower default movement
and faster/slower animation playback to eliminate pace mismatch. Base speed is
now 5.3 * .70 = 3.71m/s; existing flat movement bonuses remain additive. Existing
walk/backpedal/crouch source-based movement caps also receive .70. Dash retains
its independent skill displacement. Thus the fresh test character with the
existing +.12 movement bonus travels about 3.83m/s, rather than claiming every
character must travel at exactly 3.71 regardless of bonuses.

Built source root-motion speed metadata and calibrated each retargeted loop's
low-foot stance speed on all ten actual race/gender skeletons (18 gaits each).
travel_strides.json supplies the measured per-model distance per animation
second. Playback rate uses final horizontal displacement after physics,
shoreline rollback and bounds clamping divided by that measured stride speed.
It is not driven by input alone, nor multiplied by a manual profile speed while
moving. Idle/action/preview speed remains adjustable. Unknown legacy/custom
clips fall back to source metadata scaled by fitted leg length. Stop against a
wall stops the running feet. Lowered/raised carrying variants share their source
leg gait measurements. This matches cycle pace; it does not add terrain foot IK
or promise zero contact error in every source frame/uneven-ground pose.

Rebuild commands: scripts/editor/build_travel_animation_library.gd, then
scripts/editor/calibrate_travel_strides.gd, both via Godot --headless --path .
--script res://... . Recalibrate after any body/rig or travel-clip change. Source
FBX files remain local/ignored; runtime RES/JSON files are the shared outputs.
README documents sources, runtime behavior and rebuilding. No API generations
or paid animation requests were made.

Verification: test_relaxed_locomotion passes all ten hands-down/sword-direction
poses, ready/peace timeout, saved mapping support, gait phase and F6 priority.
test_locomotion_pace passes real physics speed, measured stride playback and a
collision-wall stop. Human and female Dwarf both move 3.8301m/s; their measured
run rates are 1.0691x and 1.7472x respectively. test_race_motion passes 90
rest/pose checks across ten models, including new travel and sword-ready clips.
Existing animation selection (305 clips), character save/selector, basic attack,
F6/F7, Human camp sit/stand, world traversal and world-contract tests pass.
Native Direct3D12 relaxed/ready/walk/run and sword/greatsword/staff/spear carry
renders were inspected (logs/travel_review); three character motion reviews are
in logs/race_build/rendered. The comparison tool now checks clip existence
before capture; an initial duplicate-library diagnostic was corrected before
acceptance. Final tested flows have no script/parse or handled runtime errors.
Existing engine-exit RID/resource diagnostics and previously recorded unrelated
legacy skill-suite failures remain. Tests use ignored fixtures, not user saves.
Remote check found no commits after f4316f79; incoming work was not pulled,
changed, committed or pushed. Restart a running game to load the new library.

## 2026-11-01 - F7 pose freeze and mouse Fast Align

User requested F7 Stop Animation freeze the current pose instead of ending it,
and click-to-enter mouse alignment with Ctrl-click selecting rotation. Replaced
the button with Freeze Animation / Resume Animation. player.gd pauses both the
base AnimationPlayer and manual upper-body overlay, retains time/speed/pose and
blocks animation replacement while frozen. Resume continues layers that were
playing. A gameplay channel ending while frozen does not reset the held pose,
and resuming does not restart that ended channel. New F6 replacement, model
application, death and revival release the freeze. The freeze is transient
presentation state, not saved character data or a paused gameplay world.

Weapon Position now has Fast Align. Plain click edits hand-local position:
mouse horizontal X, vertical Y (up positive), wheel Z. Ctrl at activation selects
rotation: vertical motion pitches X, horizontal motion yaws Y, wheel rolls Z.
Translation uses 1mm/pixel and 1cm/wheel notch; rotation uses .25 degree/pixel and
2 degrees/notch. Numeric fields follow without recursively emitting changes.
Position stays within existing +/-2m bounds; fast rotation wraps equivalent
Euler angles. The button is click-to-enter, not hold-to-drag. Click or Enter
keeps the pass; Esc/right-click cancels to its starting transform. Save Grip is
still required for persistence. Existing reset, save and per-model/type/variant
storage remain. Freeze can remain active while inspecting outside F7; Resume
or a new F6 clip releases it.

game_hud.gd routes active alignment input before GUI/camera/gameplay handlers.
Mouse movement/wheel cannot rotate the camera, zoom or scroll the panel. Commit/
cancel releases are consumed to prevent click-through. Closing/switching panels,
changing weapons/models or HUD teardown releases capture; stale grips are never
restored onto a replacement model. Mouse mode restores to its prior value. The
panel uses the existing registered floating frame, bronze/ivory helpers and
compact rows, sized 600x440; the reference topic was opened and the written UI
standard supplied the existing visual language. No reference artwork was added.
Freeze toggles log one UI event; mouse motion is not logged per frame.

Verification: test_fast_align passes headless and native Forward+ D3D12. Checks
exact frozen clip time and hand pose across updates, resume, upper-body freeze,
channel-end preservation, translation/wheel axes, Ctrl-click rotation, camera
isolation, live field updates, commit release, cancel rollback, saved grip reload,
model replacement and capture cleanup during teardown. Native F7 layout was
inspected in logs/fast_align_panel.png. Existing test_weapon_controls,
test_animation_selection (305 clips) and test_locomotion_pace pass. Final tested
flows have no script/parse errors; existing engine-exit resource diagnostics
remain. Grip test writes use ignored logs fixtures, not project calibration or
user saves. Earlier broad legacy-suite caveats remain. Remote check found no
commits after f4316f79; no incoming work, pull, commit or push was changed.

## 2026-11-01 - Fast Align right-drag and Alt hand rotation

User changed the mouse controls: right button now temporarily rotates the weapon
while Fast Align remains active; releasing it returns to the prior mode. It no
longer cancels. Holding Alt directs mouse XY rotation and wheel Z roll to the
actual right-hand bone, with priority over weapon rotation. Releasing Alt returns
to weapon editing. Existing Ctrl-click rotation remains available. Escape alone
cancels the pass; click/Enter keeps it. Input remains isolated from the camera.

Added hand_grip_offset.gd, a SkeletonModifier3D that applies an additive hand-local
quaternion after animation. The hand mesh, fingers and BoneAttachment weapon
move together. It does not rewrite clips, bone rests or weapon-local rotation,
and does not accumulate when animation is frozen. Player exposes transient
hand_rotation_degrees. weapon_grips.gd persists hand_rotation_degrees alongside
weapon position/rotation under the same model/type/variant key. Old calibrations
without that field default to zero. Unequip/reset clears it; re-equip/model
application loads the matching value. Save Grip saves both targets. Fast Align
snapshots both hand and weapon so Escape rolls both back; context replacement
never reapplies the old model's hand adjustment. Added a hand-angle readout and
updated the existing compact help/status text. No new window or style system.
Skeleton modifier behavior follows Godot's official SkeletonModifier3D docs:
https://docs.godotengine.org/en/stable/classes/class_skeletonmodifier3d.html

Verification: extended test_fast_align passes headless and native Forward+ D3D12.
Checks right-drag/wheel rotation, release-to-translation, Alt hand axes, unchanged
weapon-local transform, actual attached-weapon world rotation, stable modifier
output on frozen frames, Alt release, combined cancellation, hand save/reload,
unequip/re-equip and model isolation. Existing weapon controls, 305-clip animation
selection and ten-model relaxed-pose tests pass. Native panel/readout reviewed in
logs/fast_align_panel.png; logs/hand_align_*.log contain evidence. No final script/
parse errors or handled runtime errors; pre-existing engine-exit resource
warnings remain. Test calibration writes are isolated in logs. No real user
saves/calibration or remote code was edited; remote check found no new commits
beyond f4316f79. No pull, commit or push.

## 2026-11-01 - Forward-diagonal sprint animation routing

User reported lateral/diagonal sprinting lacked the W+A / W+D animation behavior.
Found sprint selection returned the straight-forward clip before consulting the
horizontal direction. Added native SprintForwardLeftUnarmed and
SprintForwardRightUnarmed sources to the travel builder, including lowered
carry/upright pole variants. Library now contains 69 clips (311 total player
clips). Added independent sprint_forward_left/right profile actions, directional
routing and normalized-input-safe sign detection. Direction changes preserve
sprint phase. Existing movement speeds and normalized diagonal displacement
remain unchanged.

Rebuilt travel_animations.res/travel_speeds.json and recalibrated 20 gaits per
race in travel_strides.json. Calibrator now includes sprint_* keys, so new clips
use measured per-model pace rather than falling back to straight sprint speed.
No source meshes, user overrides or hand/weapon calibration files were changed.

Verification: relaxed-locomotion tests cover raw and normalized diagonal input,
available profile actions for every weapon style and sprint phase continuity.
Actual input/physics tests pass Shift+W+A and Shift+W+D with their distinct clips;
both travel at 5.7451m/s on the test character, with matched stride playback and
no extra diagonal speed. Animation selection passes with 311 clips. Native
Direct3D12 poses were reviewed under logs/travel_review/travel_carry_sprint_*.png.
Race-motion test includes both new sprint clips (11 checks per model, ten models).
Evidence: logs/sprint_*.log. Existing engine-exit resource diagnostics and earlier
legacy-suite caveats remain. No user saves, incoming code, pull/commit/push or
external generation changed; remote check found no new commits after f4316f79.
Restart the running game to load the new library.

## 2026-11-01 - Stabilized right-hand running weapon carry

User requested a steady weapon while running, with the right hand drawn backward
like a hard sprint. Added scripts/running_weapon_carry.gd, a SkeletonModifier3D
installed on the actual player and armed F6 preview. It uses a reachable rear
model-space target, an analytical two-bone arm solve and fixed wrist direction.
The target is based on the running shoulder pose and scaled to each rig's arm
length. A rest-pose-based target initially exceeded reach on sprinting Orc rigs;
cycle checks caught this and the final target uses the running pose instead.
Sword blade trails backward/slightly down; pole styles retain an upward/rear
carry. Weapon stays attached to the real hand; legs, left arm and source rests
are unchanged. Attack overlays bypass stabilization, including frozen overlays.
HandGripOffset runs afterward, preserving saved F7 hand edits. Paused base clips
use assigned_animation so F7 freeze retains the stabilized carry.

Changed player.gd, animation_selection.gd, new modifier and focused pose test;
updated CURRENT_WORK, GAME_RULES and animation README. No asset regeneration,
stride recalibration, speed/stat changes or user calibration writes required.

Verification: test_steady_weapon_run checks 16 phases of twelve gait cycles on
all ten playable models, testing hand translation/orientation stability, rearward
placement and continued left-arm motion. Final translation drift is below .003m
on every cycle (typically sub-micrometre). Native Direct3D12 side poses reviewed
under logs/steady_review. test_fast_align passes headless and native D3D12;
test_weapon_controls, test_animation_selection (311 clips), test_basic_attack
and relaxed-locomotion baseline pass. Existing engine-exit resource diagnostics
and earlier legacy-suite caveats remain. Evidence: logs/steady_*.log.
Remote check found no new commits beyond f4316f79; no pull, commit, push, incoming
work changes, external generation or user save changes. Restart game to load.

## 2026-11-01 - Replace rigid running carry with restrained organic motion

User clarified that the previous fixed hand target was too rigid. Revised
running_weapon_carry.gd to retain authored shoulder translation (70%), bounded
arm swing (10%) and gentle torso rotation (30%). Wrist orientation follows the
same restrained torso turn rather than independent wrist oscillation. Rearward
carry and two-bone solve remain, but hand position and orientation now move with
the running body. No synthetic clock or temporal smoothing: clip sampling keeps
freeze exact and avoids frame-rate-dependent results. F6 preview shares it;
attack/frozen overlays and downstream F7 calibration remain unchanged.

Updated the pose regression to require nonzero hand/wrist motion, substantially
less hand swing than the original clip, rear placement and continued left-arm
motion, plus overlay priority. Ten models × twelve full gait cycles pass with
zero failures (logs/organic_run_test.log). Human straight run moves about .077m
versus .461m raw, wrist excursion .093 radians; sprint .087m versus .579m raw.
Native D3D12 eight-phase poses for four running/sprint clips reviewed under
logs/organic_review; native test_fast_align passes (organic_fast_align.log).
No parse/runtime errors in these checks. Existing exit-resource diagnostics
remain. Updated CURRENT_WORK, GAME_RULES and animation README to describe the
corrected behavior, superseding the rigid-carry entry above. No source assets,
speed/stride data, user saves or calibrations changed; no pull/commit/push.

## 2026-11-01 - Simplify Shift sprint to a back attachment and natural arms

User stopped the procedural sheath/draw implementation, then clarified that only
Shift-sprinting should put the weapon on the back, with a small jiggle. Removed
running_weapon_carry.gd and test_steady_weapon_run.gd; player and F6 preview no
longer install rear-hand IK. Replaced the in-progress sprint_weapon_visual.gd
SkeletonModifier with a plain Node3D back attachment component. It never writes
bone poses. Also removed the procedural reach/insert/release arm solve and large
generated scabbard from that interrupted implementation. Ordinary running uses
original carry/pole motion; sprint/readiness uses corresponding unarmed travel.

Back mount follows the actual shoulder-to-pelvis line, avoiding excessive tilt
from a single bent spine bone during sprint. Secondary motion is clip-phase
synchronized: 4mm lateral/depth, 8mm vertical, roughly 1-2 degrees angular sway.
F7 freeze preserves attachment transform/visibility. All race/weapon variants
use the same rig-relative placement; saved hand/weapon calibration is untouched.

Transient game_state readiness: Shift-sprint immediately stows the weapon and
blocks skills/basic attacks. Releasing sprint starts one second of readiness,
then returns weapon to hand/unlocks combat. Resuming sprint cancels readiness.
Central skill/basic-attack gates reject before mana/cooldown spending, including
same-frame input checks; sprint stops active channels. Existing effects continue.
Death, model and equipment changes reset readiness. Logs emit phase changes only.
No gameplay rule lives in the visual component.

Verification: tests/test_sprint_weapon.gd passes headless and native D3D12 on ten
models: back visibility, untouched original arm poses, bounded nonzero jiggle,
F7 freeze, readiness/re-sprint/reset rules and no resources spent on blocked casts.
Final headless pass logs/back_mount_verified.log; native pass
logs/back_mount_native_test.log. Actual locomotion pace/diagonal/blocked-idle
checks pass (back_mount_pace_final.log), with test platform enlarged for the
longer sprint duration. F7 Fast Align, F6 weapon controls and animation selection
pass (back_mount_fast_align/weapon_controls/selection.log). Native rear poses
reviewed in logs/back_mount_review; back_mount_render_verified.log has no script
errors. Existing shutdown resource diagnostics remain. Updated CURRENT_WORK,
GAME_RULES and animation README. No source asset/stride rebuild, user saves,
calibration changes, external generation, pull, commit or push.

## 2026-11-01 - Learn class skills from the starting NPC dialogue

User reached level 4 and could not learn skills, requesting NPC-based training,
locked future entries and visible required levels inside the dialogue. Existing
Fighter logic granted availability automatically by level and had no learning
transaction/NPC dialogue; HUD refresh signatures omitted level/class/learned
state, leaving displayed milestones stale after levelling. Added explicit
class_skill_status/learn_class_skill rules to game_state. is_skill_available
requires trained Fighter flags plus class/level; the existing learned_skills
save field persists them. Pre-trainer equipped milestone skills migrate into
learned flags without granting every eligible skill. Existing Mystic acquisition
is unchanged because no Mystic trainer milestones have been authored.

Torven's E interaction now opens the shared NPC dialogue on first/repeat visits,
retaining quest start/restore behavior and access to crafting. All five authored
Fighter milestones appear directly, with required level and Locked/Available/
Learned state. Main owns proximity/combat validation and logs successful training
as a STATE event. UI renders requests and reads state. Training costs no currency
or enchantment points; repeated learning rejected. K directs the player to Torven
and permits dragging only trained abilities. Live refresh includes level/class/
learned skills and trainer range/combat state. Added level-up/context guidance.
An initial UI range check used the forge's camp-centre radius; native testing
caught disabled Learn buttons beside Torven, so training now uses the same actual
NPC range in presentation and the main transaction.

Reviewed the UI reference topic and UI_STANDARD. Borrowed compact inset list
hierarchy, square icons, bronze rims and ivory/gold text roles through existing
helpers/shared window. No external art shipped. Native 1100x650 captures inspected
under logs/trainer_level1.png, trainer_level4.png and trainer_learned.png.

Verification: tests/test_trainer_dialogue.gd passes headless and D3D12: actual E
interaction, required-level text, under-level rejection, live level-4 refresh,
real Learn-button callbacks, learned-state feedback, no point spending, duplicate
rejection, hotbar assignment, new-save reload, legacy-equipped migration, NPC
range and wrong-class gates. test_fighter_tree updated for explicit training and
passes; test_characters passes. Evidence: trainer_dialogue_verified.log,
trainer_native_verified.log, trainer_fighter_verified.log, trainer_characters.log.
No parse/runtime errors in these flows; existing shutdown resource diagnostics
and earlier legacy enchantment-suite limitations remain. Fixtures write logs
only; real user saves untouched. Remote check found no new origin commits after
f4316f79; no incoming edits, pull, commit or push. Restart game to load changes.

## 2026-11-01 - K displays learned skills only

User requested unlearned skills appear only at the learner NPC. Filtered Fighter
K cards through the existing learned/available rule; empty K points to Torven.
Trainer dialogue continues showing every authored milestone with required level
and Locked/Available/Learned state. No progression or save behavior changed.
Extended the trainer regression to inspect empty K, learn one skill, verify its
immediate appearance while other eligible skills stay hidden, then continue the
NPC/save/load checks. Zero failures in logs/trainer_learned_only.log. Updated
CURRENT_WORK, GAME_RULES and UI_STANDARD. Existing shared frame/style preserved;
no user save, asset, remote work, commit or push changed.

## 2026-11-01 - Relax sword idle wrist and grip

User said the sword-holding idle hand looked forced. Native closeups exposed
that aim_carry_wrist aligned the blade with the forearm, bending the actual
palm sideways by about 66 degrees before saved hand calibration. Changed only
peaceful carry_idle and combat sword_ready to align the palm (wrist to middle
finger base) toward the forearm with 80% correction, preserving a slight natural
bend. Ready idle now uses closed sword fingers instead of open fencing fingers.
No shoulder/elbow/leg posing or runtime IK was introduced. Existing saved F7
weapon transform and hand offsets remain unchanged and apply normally; their
final visible sword angle remains user-calibrated.

Updated build_travel_animation_library.gd with a shared finger-grip helper and
an --idle-only bake path. The path restores original wrist keys (or the source
rest quaternion for untracked constant hands) before sampling, preventing repeated
bakes from accumulating corrections. Saved travel_animations.res with only the
two idle poses changed. Gaits, stride calibration and combat timing were not
rebuilt. Full library builds produce the same idle rule. Added README guidance.

Verification: test_relaxed_locomotion passes ten adapted race/gender poses and
four combat-ready phases per model, requiring palm/forearm angle under 25 degrees
before user calibration. Existing idle/locomotion/profile checks pass. Native
D3D12 hand closeups reviewed with/without saved F7 grip settings under
logs/idle_hand_review. test_fast_align and test_weapon_controls pass. Final logs:
natural_idle_final_test.log, natural_idle_weapon_controls.log,
natural_idle_fast_align.log, natural_idle_grip_render.log. Bake log
natural_idle_grip_bake.log reports success without script errors. Existing exit
resource diagnostics remain. Updated CURRENT_WORK and GAME_RULES. No user saves,
calibration files, source meshes, remote code, external generation, commit or
push changed. Restart the game to load the resource.
