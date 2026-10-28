# CURRENT_WORK.md

Last updated: **2026-10-28**
Branch: `main`

## Current state

Map I is playable as a real 3D continent. The old flat baked arena and the
minimap are gone; the world is built at runtime from one zone table, the game has
a day/night cycle, MMO chat and a full-screen map, and the HUD has been
re-laid-out around a bare skill bar.

## Completed in this pass

- **World:** five uneven zones (Emberfall Vale 1-3, Thornwood 4-6, Ashen Fen 7-9,
  The Broken Arch 10-12, Crownless Sanctum 13-15), rolling height-field terrain
  with collision, a branched 34-edge road network, fen ponds, a camp, ruins, a
  sanctum and a sealed waygate. All of it lives in `scripts/world_builder.gd`.
- **Day/night:** a 15-minute in-game day starting at 08:15 day 1, with a clock
  and phase (Dawn / Day / Dusk / Night) in the HUD.
- **Map:** no minimap. `M` opens a full-screen map generated from the same zone,
  road, pond and landmark data, with the player heading, clock and legend.
- **Chat:** bottom-left World / Local / Party / Guild panel with timestamps;
  `Enter` focuses the input and typing does not move the character.
- **HUD:** bare five-slot skill bar with no frame, clock/menu top right, quest
  journal right, status left, system log bottom right.
- **Visuals:** generated grass/bark/leaf/needle/road textures, Blender low-poly
  trees, softer sunlight shadows, dimmer pools, rebuilt tents and a smaller
  dormant portal.
- **Diagnostics:** `scripts/game_log.gd`, `Documentation/DEBUGGING.md`,
  `Documentation/IMPLEMENTATION_LOG.md`, `--screenshot` tour (9 frames incl. the
  map and night), `F10` marker, `F9` log folder, `F12` screenshot.
- **Remote watch:** `scripts/dev/check_remote_changes.ps1` reports commits from
  another PC, flags risky edits and appends a report to the implementation log.
  It never edits code; the user must approve any follow-up.
- **Enemies:** HP and damage scale with the zone level band; the level is shown
  next to the name.

## Verification done

- Headless import and script parse gate: no script or parse errors.
- `tests/test_world.gd`: zones, terrain, collision, waygate, roads, ponds,
  day/night, map, chat and log all pass.
- `test_progression.gd`, `test_combat_effects.gd`, `test_skill_panel.gd` pass.
- `--screenshot` tour inspected at 1600x900; visual defects found in review were
  fixed and re-checked.
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
5. Decide whether the local `modifier_list_editor` addon should be tracked or
   kept editor-only. It is currently gitignored.
6. Map II is not built. The waygate is decorative until it is.

## Known warnings

- `modifier_list_editor` is enabled in `project.godot` but absent on machines
  that do not have it. This is an editor warning only and does not affect play.
- A headless quit can report 2 leaked ObjectDB instances at exit; tests still
  exit 0 and gameplay is unaffected. Investigate only if the count grows.
- The world rebuild costs about 0.4 s at startup; it is logged as
  `[WORLD] world_ready {"build_ms": ...}`.
