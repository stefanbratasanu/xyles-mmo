# XYLES interface standard

Visual reference: [FA v4.7.11 interface](https://maxcheaters.com/topic/225202-fa-v4711-interface-under-development/).
The implementation uses original Godot-drawn frames; reference screenshots are not shipped as game artwork.

- Dark translucent brown interiors, bronze rims, ivory text, engraved corners and a centered crest.
- Compact sans-serif text, thin red vitality and blue mana bars, square artwork slots.
- Status at the top left; clock, compact menu and quest journal at the top/right;
  chat at the bottom left; system journal at the bottom right; ten active skill
  shortcuts at the bottom center.
- The skill bar has **no frame**: the tiles sit on the world with only their own
  dark tile backgrounds. Do not re-register it as a floating window.
- There is no minimap. `M` opens a full-screen, opaque, square **painted map**
  built from the same height/colour grids as the terrain: hillshade, 4 m
  contours, canopy density from real tree positions, ponds, roads, landmarks and
  the sealed waygate. Side panels hold regions, legend, compass and a 50 m scale
  bar. Zone outlines are never traced. The map blocks gameplay input while open
  and closes with `M` or `Esc`.
- Chat is a bottom-left panel with World / Local / Party / Guild tabs,
  timestamps and a line input. Typing must not move the character.
- Inventory follows the reference paperdoll: 21 equipment slots on the left, a nine-column bag on the right, and All / Equip / Supplies / Crafting / Quest tabs. Hover shows attributes and durability; double-click or right-click a bag item to equip it, and click worn equipment to remove it. Bottom controls repair, sort, and discard (with a second confirmation click). Wood and iron appear as live crafting stacks.
- All floating windows use title-bar dragging, stay within the viewport and remember their own positions in `saves/ui_layout.cfg`. Options includes a layout reset.
- Skills retain ten equipped slots, square evolution groups, ten upgrade stages, the `+` / `X / 10` control and the completed `10/10` tile. Clicking an installed enchantment shows its saved details; the `+` tile opens new choices. Enchantment tiers appear in the description and use restrained slot/choice colours alongside text.

Reusable implementation: `scripts/classic_frame.gd` supplies the frame ornamentation, while the HUD's `_panel`, `_button`, `_bar` and `_label` helpers supply common styling. Register new floating HUD windows through `_register_window`; use a title-only hit area so content buttons remain interactive.

- Character selection uses a compact bronze-framed roster and creation form. Show the chosen race/class and explain that race-specific models and gameplay are not implemented.

## Current Fighter slice navigation

Adventure exposes Inventory / Class skills / Actions / Bestiary / Crafting / Options. Each floating window owns its content without a duplicated navigation footer. Fighter skills use compact illustrated level-milestone cards; Actions uses a small grouped square grid, with Party/Social previews identified in tooltips. Development tools stay in Options. Status includes a thin XP strip; the hotbar shows assignment guidance while enchantments are disabled. Shared frames have recessed bronze bevels and a restrained title highlight.

Status: compact level/name header above full-width yellow XP percentage, red HP and blue MP bars, with live values centered over each fill.

Status uses the user's diagonal right-edge cut. Shared panel interiors use 86% opacity. Clock, chat, region label and frameless hotbar join persistent dragging/snapping; the hotbar has a separate grip above the slots. The full-screen map stays full-screen.

2026-10-29 supersedes permanent menu/journal layout: bottom-right head opens Character Status, gear opens tabbed Options, arrow folds out all windows. No permanent Adventure or System Journal. Shortcuts use a right-side dot grip; active drag shows gold bounds and cyan peers with the snap gap. Resource fill ends are diagonal at partial as well as full values.
