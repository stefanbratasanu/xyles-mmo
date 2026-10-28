# CURRENT_WORK.md

Last updated: **2026-10-28**
Branch: `main`

## Current state

Map I is playable as a real 3D forest continent. The old flat baked arena and the
minimap are gone; the world is built at runtime from one zone table, the game has
a day/night cycle, MMO chat and a full-screen painted map, and the HUD has been
re-laid-out around a bare skill bar. The world is about 296 m across, ringed by
mountains that are part of the same height field, and the forest runs from the
starting camp all the way to the foothills.

## Completed in this pass

- **World:** five uneven zones (Emberfall Vale 1-3, Thornwood 4-6, Ashen Fen 7-9,
  The Broken Arch 10-12, Crownless Sanctum 13-15) in a 296 m square
  (`BOUNDS` 148). Rolling height-field terrain with collision, a branched
  34-edge road network, fen ponds, a camp, ruins, a sanctum and a sealed
  waygate. All of it lives in `scripts/world_builder.gd`.
- **Mountains:** the square edge of the world rises into a real ridge
  (`RIM_START` 160, crest at `RIM_END` 200, `RIM_HEIGHT` 32) built from two
  ridged-noise fields, then falls away again at 206-223 so the mesh edge hides
  behind the crest. No separate cone/crag props remain; rock and alpine colour
  climb with altitude, and a pine belt covers the 140-170 m foothills.
- **Biomes:** each zone now has its own `elevation`, `relief`, `tree_count`,
  `rock_count` and `grass_count`, so the fen is a wet lowland, the arch and
  sanctum sit on high ground, and the colour/vegetation change is physical, not
  only painted on the map.
- **Vegetation:** taller Blender trees (oak ~11 m, birch ~11.5 m, pine ~11.8 m,
  dead ~10 m) with smooth-shaded crowns; a 760-tree outskirt pass and 7000
  outskirt grass tufts continue the forest past the zone blobs to the rim; grass
  is a three-card alpha-scissor tuft (`grass_blades.png`) in the thousands per
  zone; bushes are five-puff shrubs; rocks and logs are smaller, sunk into the
  ground and kept two road cells clear.
- **Day/night:** a 15-minute in-game day starting at 08:15 day 1, with a clock
  and phase (Dawn / Day / Dusk / Night) in the HUD.
- **Map:** no minimap. `M` opens a square, painted map rendered from the same
  height and colour grids as the terrain: hillshade, 4 m contours, canopy
  density from real tree positions, trunk stipple, ponds and roads, with side
  panels for regions, legend, compass and a 50 m scale bar. No zone outlines.
- **Chat:** bottom-left World / Local / Party / Guild panel with timestamps;
  `Enter` focuses the input and typing does not move the character.
- **HUD:** bare five-slot skill bar with no frame, clock/menu top right, quest
  journal right, status left, system log bottom right.
- **Visuals:** generated grass/bark/leaf/needle/road textures, Blender low-poly
  trees, softer sunlight shadows, dimmer pools, rebuilt tents and a smaller
  dormant portal.
- **Diagnostics:** `scripts/game_log.gd`, `Documentation/DEBUGGING.md`,
  `Documentation/IMPLEMENTATION_LOG.md`, `--screenshot` tour (10 frames incl.
  the map, night and frontier), `F10` marker, `F9` log folder, `F12` screenshot.
- **Remote watch:** `scripts/dev/check_remote_changes.ps1` reports commits from
  another PC, flags risky edits and appends a report to the implementation log.
  It never edits code; the user must approve any follow-up.
- **Enemies:** HP and damage scale with the zone level band; the level is shown
  next to the name.

## Verification done

- Headless import and script parse gate: no script or parse errors.
- `tests/test_world.gd`: zones, gentle-but-real terrain relief, terrain rim,
  terrain collision, world bounds, waygate, roads, ponds, day/night, painted map
  texture, no crag props, chat and log all pass.
- `test_progression.gd`, `test_combat_effects.gd`, `test_skill_panel.gd` pass.
- `--screenshot` tour inspected at 1600x900; visual defects found in review were
  fixed and re-checked (floating props, road boulders, empty outskirts, rim
  framing, map traces).
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
- The world rebuild costs about 2.5 s at startup (terrain, ~2,000 trees and
  ~31,000 grass tufts); it is logged as
  `[WORLD] world_ready {"build_ms": ...}`.
