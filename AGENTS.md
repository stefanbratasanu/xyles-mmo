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
2. Run the remote-change check **before pulling**:
   `powershell -ExecutionPolicy Bypass -File .\scripts\dev\check_remote_changes.ps1`
   If it reports commits from another PC, read the report it appended to
   `Documentation/IMPLEMENTATION_LOG.md` and ask the user before changing,
   reverting or "fixing" anything.
3. Read `CURRENT_WORK.md`.
4. Read `GAME_RULES.md` and `Documentation/UI_STANDARD.md` for the area you are
   about to change.
5. Run the project and the relevant tests.
6. Make the smallest coherent change. Do not revert or overwrite other people's
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
.\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_world.gd
```

`tests/benchmark_skill_effects.gd` is a benchmark, not a pass/fail test.

Scripted visual tour (writes PNGs to `res://screenshots/`, including the
full-screen map and a night frame):

```powershell
.\Godot_v4.7.2-stable_win64.exe --path . -- --screenshot
```

A normal launch must show no `SCRIPT ERROR` or `Parse Error`. Warnings about the
missing local `modifier_list_editor` addon are expected on machines that do not
have that editor plugin installed.

## 3a. Debugging and project memory

Before changing a system, read its most recent entry in
`Documentation/IMPLEMENTATION_LOG.md`. After changing it, append a new entry.
That file is the engineering memory: intent, changed files, decisions,
verification and known risk. Do not rewrite old entries.

The game writes a runtime log every launch to `logs/session_*.log`;
`logs/LATEST.txt` points at the newest one. The log is gitignored and contains
`BOOT`, `GAMEPLAY`, `COMBAT`, `UI`, `WORLD`, `STATE`, `ERROR`, `PERF` and
`MARKER` events. In-game, `F10` writes a marker with a position/zone/HP/target
snapshot and `F9` opens the log folder. Read `Documentation/DEBUGGING.md` for
the inspection commands.

When investigating a bug, use this order:

1. newest runtime session, find the `[MARKER]` and read the lines before it;
2. `[ERROR]`, `[PERF]` and the session summary;
3. `Documentation/IMPLEMENTATION_LOG.md` for what changed most recently;
4. `CURRENT_WORK.md` for known-unfinished work;
5. reproduce with `--test-mode` before editing code.

Diagnostics must never change gameplay. Add event-level logs only; never log
per frame without a throttle.

### Watching for work done on other PCs

The project is shared, so `origin/main` can move without this machine doing
anything. At the start of a session, before pulling, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\dev\check_remote_changes.ps1
# optional, slower: also parse-check the fetched tree in a temporary worktree
powershell -ExecutionPolicy Bypass -File .\scripts\dev\check_remote_changes.ps1 -ParseCheck
```

The script:

- fetches `origin/main`;
- lists commits added since its last check (checkpoint in
  `logs/remote_check_state.json`, never committed);
- marks commits authored elsewhere or not present in local `HEAD`;
- flags changed core files, deleted files, conflict markers, debug leftovers,
  hard-failure calls, unknown addons and executable files;
- appends a dated **Remote changes from another machine (automatic)** section to
  `Documentation/IMPLEMENTATION_LOG.md` with proposed keep / adjust / revert
  actions.

It never edits game code or reverts anything. When it reports a problem, show the
user the report, explain the risk, propose the smallest fix, and **wait for the
user's explicit approval** before changing or reverting the other developer's
work. `-ParseCheck` is opt-in because a full import in a temporary worktree is
expensive.

## 4. Architecture

Keep these layers separate:

| Layer | File(s) | Responsibility |
|---|---|---|
| Orchestration | `scripts/main.gd` | Scene wiring, input routing, camera, spawning, combat flow |
| Persistent rules | `scripts/game_state.gd` | HP/mana, XP, skills, quests, inventory, equipment, saves |
| World | `scripts/world_builder.gd` | Zones, height field, roads, water, props, day/night, sealed waygate |
| Map | `scripts/world_map.gd` | Full-screen map drawn from the world data |
| Player | `scripts/player.gd` | Movement, animation state, equipment visuals |
| Enemies | `scripts/enemy.gd` | AI, health, telegraphs, world-space name/health display |
| Presentation | `scripts/actor_visual.gd`, `scripts/combat_effects.gd` | Models and pooled effects |
| Diagnostics | `scripts/game_log.gd` | Runtime event log and tester markers |
| HUD | `scripts/game_hud.gd`, `scripts/world_map.gd`, `skill_panel.gd`, `inventory_panel.gd` | Read state and render UI |
| Audio | `scripts/audio_director.gd` | Cues and volume |

Before implementing a new mob, ask Alin or Stefan when it should spawn during
the day/night cycle and which map, zones or biomes it belongs in. Do not invent
these decisions when they have not been specified; record the agreed spawn
rules in `GAME_RULES.md` and use them when implementing the mob.

Rules:

- Gameplay state belongs in `game_state.gd`, not in the HUD or visuals.
- The HUD reads state and emits requests; it must not own progression rules.
- `actor_visual.gd` draws actors; it must not decide damage or progression.
- Keep damage numbers, HP values, and UI values driven by the same source.
- `world_builder.gd` is the single source of truth for zone data, height, spawns,
  roads and the waygate. The map, terrain colour and enemy levels read from it;
  never duplicate zone numbers elsewhere.
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
- There is **no minimap**. `M` opens the full-screen map in `scripts/world_map.gd`.
- The five-skill hotbar has no frame panel; do not wrap it in `_panel()` again.
- Chat lives at the bottom left with World / Local / Party / Guild tabs and must
  block movement while its input has focus (`game.ui_text_input`). The system
  log sits at the bottom right.
- The day/night clock sits at the top right; do not add a second time display.
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
- the affected tests pass, including `tests/test_world.gd` for world/map/clock
  changes;
- the UI still follows `Documentation/UI_STANDARD.md`;
- no duplicate UI panels or competing sources of truth were introduced;
- the runtime log grows with the new events and contains no errors from the
  tested flow;
- `Documentation/IMPLEMENTATION_LOG.md` has an entry for the pass;
- `CURRENT_WORK.md` is updated with what changed and what remains;
- if `origin/main` moved, the remote-change check has been run and its findings
  were shown to the user before any of the other developer's code was touched.
