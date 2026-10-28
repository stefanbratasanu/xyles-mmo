# AGENTS.md - Xyles MMO working agreement

Read this file before changing the project. It is the operating manual for AI
agents and for human contributors.

## 1. What this project is

- **Engine:** Godot **4.7.2**, GDScript, Forward+ renderer, Direct3D 12 on Windows.
- **Entry scene:** `scenes/main.tscn`
- **Entry script:** `scripts/main.gd`
- **Genre:** hardcore classic MMO in the spirit of Lineage 2, with Path of Exile
  style skill evolution and item modifier pools.
- **Current scope:** a local single-player vertical slice; there is no server yet.

Read `CURRENT_WORK.md` for the active task and `GAME_RULES.md` before changing
gameplay, combat, progression, or UI behaviour.

## 2. First five minutes

1. `git status -sb` - know what is already modified before touching anything.
2. Read `CURRENT_WORK.md`.
3. Read `GAME_RULES.md` and `Documentation/UI_STANDARD.md` for the area you are
   about to change.
4. Run the project and the relevant tests.
5. Make the smallest coherent change. Do not revert or overwrite other people's
   work, even if it looks unfinished.

## 3. Run and test

Run the game:

```powershell
.\Godot_v4.7.2-stable_win64.exe --path .
```

Run a headless import after adding or moving assets:

```powershell
.\Godot_v4.7.2-stable_win64_console.exe --headless --path . --import
```

Run the test scripts:

```powershell
.\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_progression.gd
.\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_combat_effects.gd
.\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_skill_panel.gd
```

`tests/benchmark_skill_effects.gd` is a benchmark, not a pass/fail test.

A normal launch must show no `SCRIPT ERROR` or `Parse Error`. Warnings about the
missing local `modifier_list_editor` addon are expected on machines that do not
have that editor plugin installed.

## 4. Architecture

Keep these layers separate:

| Layer | File(s) | Responsibility |
|---|---|---|
| Orchestration | `scripts/main.gd` | Scene wiring, input routing, camera, spawning, combat flow |
| Persistent rules | `scripts/game_state.gd` | HP/mana, XP, skills, quests, inventory, equipment, saves |
| World | `scripts/world_builder.gd` | Procedural props and terrain helpers |
| Player | `scripts/player.gd` | Movement, animation state, equipment visuals |
| Enemies | `scripts/enemy.gd` | AI, health, telegraphs, world-space name/health display |
| Presentation | `scripts/actor_visual.gd`, `scripts/combat_effects.gd` | Models and pooled effects |
| HUD | `scripts/game_hud.gd`, `skill_panel.gd`, `inventory_panel.gd` | Read state and render UI |
| Audio | `scripts/audio_director.gd` | Cues and volume |

Rules:

- Gameplay state belongs in `game_state.gd`, not in the HUD or visuals.
- The HUD reads state and emits requests; it must not own progression rules.
- `actor_visual.gd` draws actors; it must not decide damage or progression.
- Keep damage numbers, HP values, and UI values driven by the same source.
- Use static typing where practical and match the existing tab indentation.

## 5. Dependencies and the Effekseer addon

- `addons/effekseer/` is **tracked in git** and enabled in `project.godot`.
  It contains the official EffekseerForGodot4 **1.80.5.1** plugin, trimmed to the
  Windows x86_32/x86_64 libraries used by this project.
- The Ember Bolt effect lives in `assets/effects/ember_bolt/`. `EmberBolt.efkefc`
  is imported by the Effekseer import plugin; `EmberBolt.efkproj` is the editable
  source. The effect texture is in the same folder.
- Runtime code intentionally checks `ClassDB.class_exists("EffekseerEmitter3D")`
  before creating an emitter. Keep that guard: a missing plugin must never stop
  `main.gd` from loading again.
- `modifier_list_editor` is a local/editor-only addon and is gitignored. Do not
  make runtime gameplay depend on it.
- Do not commit `.godot/`, `saves/`, `tools/`, or the large imported animation
  source folder; they are local/generated.

If the addon is updated, replace the whole `addons/effekseer/` folder and keep
the Windows libraries. If another platform is added, restore the matching
library and its line in `effekseer.gdextension`.

## 6. UI and visual reference workflow

**Reference:** <https://maxcheaters.com/topic/225202-fa-v4711-interface-under-development/>

Before designing or changing any panel, frame, icon, bar, or window, do this:

1. Open the reference topic above and review the relevant screen.
2. Read `Documentation/UI_STANDARD.md`.
3. Write down which ideas you are borrowing: layout, spacing, frame language,
   colour roles, icon treatment, information hierarchy.
4. Recreate the idea with original Godot-drawn assets and the existing helpers
   (`classic_frame.gd`, `_panel`, `_button`, `_bar`, `_label`,
   `_register_window`).
5. Do **not** ship screenshots or extracted artwork from the reference as game
   assets. Use them as design reference only.
6. If the reference is unavailable, follow the written standard and keep the
   existing visual language instead of inventing a new one.

Current UI rules that are easy to break:

- The HUD has **one** enemy health display: the world-space bar above the enemy
  in `scripts/enemy.gd`. Do not add a second top-centre target panel.
- Enemy bars must visibly react to both damage and healing and must deplete from
  the left edge, not shrink from the centre.
- Floating windows are draggable, clamped to the viewport, and remember their
  positions in `saves/ui_layout.cfg`.
- Use square inventory/skill slots, dark translucent brown interiors, bronze
  rims, ivory text, thin red vitality and blue mana bars.

## 7. Git workflow

- Repository: <https://github.com/stefanbratasanu/xyles-mmo.git>
- Default branch: `main`
- Commit only intended source, scene, resource, documentation, and tracked
  addon files.
- Keep generated files out of commits unless they are deliberately versioned
  (for example, `.uid` and `.import` files may be committed when the team wants
  stable references; ask first if unsure).
- Use a short imperative commit subject and explain risky changes in the body.
- Never force-push or rewrite shared history.
- The command-line Git installation on this machine has no stored GitHub token;
  pushes are normally made from GitHub Desktop. Do not assume `git push` will
  work without checking credentials.

## 8. Definition of done

A change is done when:

- the game launches without parse or runtime errors;
- the affected tests pass;
- the UI still follows `Documentation/UI_STANDARD.md`;
- no duplicate UI panels or competing sources of truth were introduced;
- `CURRENT_WORK.md` is updated with what changed and what remains.
