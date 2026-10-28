# GAME_RULES.md - Xyles MMO gameplay and interface contract

This file records the rules the prototype is built on. When code and this file
disagree, stop and decide which one is wrong before changing either. Keep
`Documentation/PROJECT_DOCUMENTATION.txt` as the long-term design document; this
file is the shorter contract used during implementation.

## 1. Core pillars

1. **Hardcore risk:** death costs durability and can expose or drop equipment.
2. **Deep customisation:** three-branch skill evolution and weighted item
   modifier pools, inspired by Path of Exile.
3. **Discovery-driven progression:** skill points come from first-time bestiary
   discoveries, not from ordinary levelling.
4. **Classic presentation:** Lineage 2 style HUD, dark bronze frames, compact
   information, readable combat feedback.

## 2. Controls

| Input | Action |
|---|---|
| `W A S D` | Move |
| Right mouse | Capture mouse / orbit camera |
| Mouse wheel | Zoom camera |
| `1` - `5` | Use skill slot |
| `E` | Interact (blacksmith, resource, dropped loot) |
| `Tab` | Cycle nearby enemy target |
| Left click | Select enemy or move to ground point |
| `X` | Sit / stand |
| `Shift` | Sprint when moving forward |
| `Alt` | Walk |
| `Ctrl` | Crouch |
| `Space` | Jump |
| `K` / `I` / `C` / `H` / `O` / `B` | Skills, inventory, forge, guide, options, bestiary |
| `M` | Open / close the full-screen world map |
| `Enter` | Focus chat input (sends with `Enter`, cancels with `Esc`) |
| `Esc` | Close panel or map |
| `F5` | Save |
| `F8` | Mute / unmute audio |
| `F9` | Open the runtime log folder |
| `F10` | Write a bug marker to the runtime log |
| `F12` | Save a screenshot to `screenshots/` |

## 2a. World, zones and presentation

- **Map I - The Ashen Frontier** is one continent of five uneven zones of roughly
  equal area. Emberfall Vale is the central starting zone; the others ring it.
- The playable square is **296 m across** (`BOUNDS` 148). Zone shapes are wavy
  blobs, not circles. One zone table in `scripts/world_builder.gd` drives the
  terrain, the ground colour, elevation, vegetation density, enemy levels, the
  HUD region label and the world map.
- The **mountain rim is terrain, not props**: past 160 m the shared height field
  rises into a ridged range (crest at 200 m, `RIM_HEIGHT` 32) and falls away
  again behind the crest. There are no separate mountain meshes, so collision,
  rock colour and the horizon always agree.
- Each zone is physically different: the fen sits low and wet, the Broken Arch
  and Crownless Sanctum sit on high ground, and tree, rock and grass density
  differ per zone. The forest also continues past the zone blobs to the
  foothills; the world is never a bare lawn between regions.

| Zone | Levels | Identity |
|---|---|---|
| Emberfall Vale | 1-3 | Central starting vale; survivor camp and forge |
| Thornwood | 4-6 | Dense dark pine forest |
| Ashen Fen | 7-9 | Low wetland with standing pools |
| The Broken Arch | 10-12 | Ruined stone terrace and altar |
| Crownless Sanctum | 13-15 | Highest ground, pillars, world boss |

- The **sealed waygate** stands in the north-west corner of the Crownless
  Sanctum. It leads to Map II, **which does not exist yet**: it must never
  teleport the player. The waygate pad and the camp are safe zones with faster
  regeneration.
- The terrain is a real 3D height field shared by the render mesh, collision,
  roads and every prop. Props must never be placed on a flat assumption.
- Sunlight uses a wide angular diameter and blurred shadow splits so shadows are
  soft and diffuse, never hard cut-outs.
- The day/night cycle is automatic: one in-game day lasts 15 real minutes and
  starts at 08:15 on day 1. The HUD clock shows the time, day and phase
  (Dawn / Day / Dusk / Night).
- There is **no minimap**. `M` opens a full-screen, square **painted map**
  rendered from the same height and colour grids as the terrain: hillshade,
  contours every 4 m, forest canopy from real tree positions, ponds, roads and
  landmarks, with side panels for regions, legend, compass and a 50 m scale bar.
  Zone outlines are never traced. North is up (-Z).


## 3. Combat and feedback

- Five active skill slots: Melee, Cast, Block, Move, Support.
- Base mana costs: `4`, `15`, `12`, `9`, `24`.
- Base cooldowns: `0.8`, `3.0`, `7.0`, `4.0`, `11.0` seconds.
- Melee range is short; casting range is long. A skill used out of range makes
  the player walk into range and then fire automatically.
- `Tab` and clicking an enemy set a single current target. The target ring is the
  only selection marker.
- Every enemy has **one** health display: a world-space bar above the enemy.
  - It must be visible while the enemy is damaged or selected.
  - It must update on damage **and** on healing.
  - The fill must deplete from the left edge and keep a dark background frame.
  - Colour shifts from green to amber to red as health falls.
  - Do not add a second target panel in the HUD. Duplicate HP displays are a
    regression, not a feature.
- Damage must produce visible feedback: floating number, brief hit reaction, and
  a health-bar change on the same frame as the hit.
- Player vitality and mana are shown in the top-left HUD. Enemy information
  belongs above the enemy, not in a second floating window.

## 4. Progression

- Levelling grants XP and increases maximum health and mana.
- Skill points are awarded only for the **first** bestiary discovery of a
  category in a region:
  - Normal enemy: **2** points
  - Quest enemy: **5** points
  - World boss: **3** points
- Lifetime skill points are capped at **50**.
- Each skill has three branches and at most **10** evolutions.
- A branch may not run more than two ranks ahead of the lowest other branch;
  players must spread investments. Individual evolutions can be respec'd.
- Skill points are never awarded twice for the same region/category.

## 5. Enemies

| Kind | Max HP | Role |
|---|---:|---|
| Normal (Briarwolf) | 64 | Open-world pressure |
| Quest (Oathbound Guardian) | 200 | Quest stage target |
| Boss (Hollow Regent) | 850 | World boss with telegraphed slam |

- Enemies aggro inside their detection radius and leash back to their home point.
- Enemies regenerate health while not aggroed. The health bar must reflect that
  regeneration.
- Enemy HP and damage scale with the level band of the zone they spawn in, so a
  Briarwolf in the sanctum is not the tutorial wolf from the vale. The level band
  is shown next to the enemy name.
- The boss telegraphs its slam with a red ring; leaving the ring avoids damage.

## 6. Death and recovery

- Player death applies the state rules in `game_state.gd`: durability loss and,
  below the exposure threshold, a chance to drop equipment.
- The player respawns at Emberfall Camp after about four seconds.
- Dropped equipment remains where the player fell and is recovered with `E`.

## 7. Quest, resources, crafting

- **A Debt of Iron** stages: speak to Torven, defeat 3 Briarwolves, defeat the
  Oathbound Guardian, defeat the Hollow Regent, complete.
- Wood and iron deposits give **+35** and replenish after **60 seconds**.
- Crafting cost multipliers: basic `1.0`, rare `1.5`, epic `2.2`, legendary `3.2`.
- World bosses drop the legendary Crownfall Greatblade; the quest guardian drops
  Oathkeeper's Signet.
- Modifier data is stored in `.tres` resources under `resources/modifiers/`.
  Pools use relative weights and are normalised to 100% at roll time; never store
  hard-coded percentages that can drift out of sync.

## 8. Interface rules and visual reference

**Primary visual reference:**
<https://maxcheaters.com/topic/225202-fa-v4711-interface-under-development/>

This link is a **design reference**, not an asset source. Before implementing a
new panel, icon set, frame, bar, or window arrangement:

1. Open the reference and review the matching screen.
2. Read `Documentation/UI_STANDARD.md`.
3. Identify the layout, spacing, colour roles, and frame details worth adapting.
4. Build the result from original Godot controls and `classic_frame.gd`.
5. Never ship reference screenshots or extracted artwork as game assets.

Visual language:

- Dark translucent brown interiors with bronze rims and ivory text.
- Thin red vitality and blue mana bars.
- Square artwork and skill slots.
- Compact sans-serif labels; avoid oversized panels.
- Status top-left; clock, menu and quest journal top/right; chat bottom-left;
  system log bottom-right; five skills bottom centre.
- The five-skill hotbar is **bare**: the tiles sit directly on the world with no
  container panel around them.
- The clock panel shows time, day and phase; the full-screen map replaces the old
  minimap entirely.
- Chat has World / Local / Party / Guild tabs, timestamps, and blocks movement
  while the input has focus.
- Floating windows drag by their title bar, stay inside the viewport, and save
  their positions.
- One concept, one panel. If information already exists in the world (such as an
  enemy health bar), do not duplicate it in the HUD.

## 9. Change rules

- Do not change a core formula, reward, or cap without updating this file and
  `Documentation/PROJECT_DOCUMENTATION.txt`.
- Keep UI feedback and underlying state in sync; never fake a bar or number that
  disagrees with `game_state.gd`.
- Verify combat changes with `tests/test_combat_effects.gd` and progression
  changes with `tests/test_progression.gd`.
