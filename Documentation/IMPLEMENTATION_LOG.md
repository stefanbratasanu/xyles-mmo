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
