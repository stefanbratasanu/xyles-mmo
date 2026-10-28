# CURRENT_WORK.md

Last updated: **2026-10-28**
Branch: `main`

## Current state

The game is playable again. The previous startup failure was caused by the
Effekseer addon being gitignored: `scripts/main.gd` referenced
`EffekseerEmitter3D` at parse time, so the whole main scene script failed to
load. The player stayed at the origin, the camera never followed, and controls
were dead.

## Completed in this pass

- Bundled the official **EffekseerForGodot4 1.80.5.1** addon in
  `addons/effekseer/`, trimmed to the Windows x86_32/x86_64 libraries.
- Kept the runtime guard so the game still loads if the addon is missing.
- Confirmed `assets/effects/ember_bolt/EmberBolt.efkefc` imports and the Ember
  Bolt trail works through the addon.
- Replaced the enemy health bar with a framed, camera-facing world-space bar:
  dark background, left-anchored fill, smooth damage/heal animation, and
  green/amber/red colour states.
- Removed the duplicate top-centre target panel from the HUD. The enemy's
  world-space name and health bar are now the single enemy display.
- Added `AGENTS.md`, `GAME_RULES.md`, and this file.
- Repaired two stale test assumptions that had drifted from the content: the
  crafting test now inspects the item it just crafted instead of a fixed
  inventory index, and the skill-panel test expects the five skill rows plus
  the capacity and reset controls.

## Verification done

- Headless import completes without script/parse errors.
- `scripts/main.gd`, `scripts/combat_effects.gd`, `scripts/enemy.gd`, and
  `scripts/game_hud.gd` load successfully.
- Smoke test confirmed the player spawns at the camp spawn point, the camera is
  current and follows the player, and movement is enabled.
- Windowed launch produced no script or runtime errors.
- `test_progression.gd`, `test_combat_effects.gd`, and `test_skill_panel.gd`
  all pass.

## Next steps

1. Push the local commits from GitHub Desktop (the CLI has no stored token).
2. Have the friend pull `main` and confirm the game starts on the player.
3. In-game check: damage an enemy, let it heal out of combat, and confirm the
   bar depletes/fills from the left and disappears when combat ends.
4. In-game check: click/tab-target an enemy and confirm only the world-space bar
   appears, with no second top-centre panel.
5. Decide whether the local `modifier_list_editor` addon should be tracked or
   kept editor-only. It is currently gitignored.

## Known warnings

- `modifier_list_editor` is enabled in `project.godot` but absent on machines
  that do not have it. This is an editor warning only and does not affect play.
- Running a headless quit can report leaked ObjectDB instances at exit; this has
  not affected gameplay and should be investigated separately if it grows.
