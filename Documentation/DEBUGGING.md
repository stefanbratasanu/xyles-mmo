# Debugging and runtime logs

Three records exist, and they solve different problems:

| Record | File | Purpose |
|---|---|---|
| Current work | `CURRENT_WORK.md` | What is true right now, what is next |
| Engineering history | `Documentation/IMPLEMENTATION_LOG.md` | What changed, why, how it was verified |
| Runtime session | `logs/session_*.log` | What the game actually did, second by second |

Read the implementation log **before** debugging. If a system was changed
recently, the answer is usually there or in the commit that followed it.

## Finding a run

- Every launch writes `res://logs/session_<date>_<time>.log`.
- `res://logs/LATEST.txt` points at the newest session.
- Up to 24 sessions are kept; the oldest are deleted automatically.
- `logs/` is gitignored. Logs stay on the tester's machine and are never
  packaged into a build.
- The absolute path is printed to the Godot console at startup as
  `[GameLog] runtime log: ...`.

On this machine the project folder is `C:\Games\xyles-mmo`, so logs live in
`C:\Games\xyles-mmo\logs`.

## In-game controls

| Key | Action |
|---|---|
| `F10` | Write a `[MARKER]` block with a full snapshot. Use this the moment something looks wrong. |
| `F9` | Open the log folder in Explorer. |
| `F12` | Save a PNG of the current frame to `res://screenshots/`. |
| `F8` | Mute / unmute audio. |
| `M` | Open / close the full-screen map. |

A marker contains the wall-clock time, session time, player position, current
zone and level band, in-game day/time, HP/mana, level, current target, number
of living enemies and FPS. That is enough to find the surrounding events in the
same file.

## Categories

| Tag | What it records |
|---|---|
| `BOOT` | Session start/end, engine and scene, world build duration |
| `GAMEPLAY` | Notices, quest steps, interactions, zone changes, loot, gathering, waygate |
| `COMBAT` | Skills used, damage dealt/taken, blocks, deaths, spawns, kills |
| `UI` | Panels, map, chat channel changes, chat messages, settings |
| `WORLD` | World build, time-of-day phase changes, spawn point resolution |
| `STATE` | Level-ups, saves, loads, equipment and progression changes |
| `ERROR` | Handled failures that should never be silent |
| `PERF` | Frames slower than 50 ms, throttled to one every four seconds |
| `MARKER` | Tester-created pin with a snapshot |

Each line starts with the local date and time:

```
2026-10-28 14:12:03  [COMBAT] enemy_damaged  {"target":"Briarwolf","amount":18.4,"hp":41.2}
```

## Reading a session

PowerShell, from the project folder:

```powershell
# newest session
Get-Content (Get-Content .\logs\LATEST.txt -First 1)

# last 200 lines
Get-Content (Get-Content .\logs\LATEST.txt -First 1) -Tail 200

# every marker and error
Select-String -Path .\logs\*.log -Pattern '\[MARKER\]|\[ERROR\]'

# combat around a bug report
Select-String -Path .\logs\*.log -Pattern '\[COMBAT\]' | Select-Object -Last 80

# slow frames
Select-String -Path .\logs\*.log -Pattern '\[PERF\]'
```

## Visual passes

The game can run a scripted camera tour and save screenshots without a human at
the mouse. This is the fastest way to check terrain, props, lighting, HUD layout
and the map after a world or UI change:

```powershell
.\Godot_v4.7.2-stable_win64.exe --path . -- --screenshot
```

It writes `01_camp` … `08_camp_night` plus `09_world_map` into
`res://screenshots/` (gitignored) and quits. `F12` captures a single frame while
playing. Read the PNGs; the runtime log records each capture as
`[GAMEPLAY] screenshot`.

## Changes made on another PC

`origin/main` can move without this machine doing anything. Before pulling, run:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\dev\check_remote_changes.ps1
```

The script fetches `origin/main`, compares it with its checkpoint in
`logs/remote_check_state.json`, and appends a **Remote changes from another
machine (automatic)** entry to `Documentation/IMPLEMENTATION_LOG.md`. That entry
lists each commit, author, files and diff size, then flags:

- core files (`project.godot`, `scenes/main.tscn`, `scripts/main.gd`,
  `game_state.gd`, `world_builder.gd`, `game_hud.gd`, …);
- deleted files, unknown addons and executable files;
- merge-conflict markers, `TODO`/`FIXME`/`breakpoint`, `push_error` and `assert`
  lines added by the change.

It also prints proposed keep / adjust / revert actions, but **never edits code**.
Show the report to the user and wait for approval before touching the other
developer's work. Add `-ParseCheck` to run a full headless import of the fetched
tree in a temporary worktree (slower, opt-in).

## When reporting a bug

1. Press `F10` immediately and type the label in your notes (for example
   `stuck in waygate wall`).
2. Note the in-game clock and your approximate position.
3. Quit normally so the session summary is written. If the game crashed, the
   buffered lines are still on disk up to the last flush (at most half a
   second old).
4. Attach or point to `logs/LATEST.txt`'s session file.

When an AI agent is asked to investigate, it should read the newest session,
find the marker, then read the 30-60 lines before it. The implementation log
narrows down which system changed most recently.

## Adding log calls

Use `game.game_log` from `main.gd` and from anything that already holds a
`game` reference (enemies, HUD, player):

```gdscript
game.game_log.combat("enemy_damaged", {"target": display_name, "amount": amount, "hp": hp})
game.game_log.gameplay("waygate_examined", {"sealed": true})
```

Rules:

- Log **events**, not frames. Never log inside `_process`/`_physics_process`
  without a throttle.
- Keep payloads small and flat; `JSON.stringify` is applied automatically.
- Never put secrets or personal data in a log.
- Diagnostics must never change gameplay. A failed log write disables logging
  and the game continues.
