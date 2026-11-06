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

- Character creation's Appearance button opens a modal framed live preview with independent size/muscularity choices, a rotation control, and Back / Use Appearance actions. Keep its brown/bronze/ivory styling consistent with the selection form.

## 2026-11-01 - Character appearance inspection

- Appearance keeps all five independent body-size and five muscularity choices (25 combinations). Opening or accepting the modal must preserve the exact pair; never reduce it to three paired builds.
- The modal has an isolated, antialiased preview at twice the displayed resolution. Drag or the slider rotates; wheel zooms; Full Body / Face / Reset control framing. Rest, Idle, Walk and Run inspect the same animation rig used by the player.
- Show Outfit is a preview-only toggle. The initial body inspection view exposes the silhouette; accepting appearance persists only the two body indices. The gameplay character wears the current starter outfit.
- Keep keyboard focus inside the modal. Back and Escape discard pending values and return focus to Appearance. Use Appearance accepts. The frame and all controls fit the supported minimum 1100 x 650 window and larger displays.

## Race-first preview - 2026-11-01

This supersedes the body-size/muscularity controls above. Keep one fixed build
per race/gender while all five races are authored. The creation form has Race,
Male/Female model and Class. Appearance retains the same bronze/brown/ivory frame,
compact text, rotatable model, close-up and pose tools for reviewed 3D assets.
Pending assets show their own race/gender reference with a clear preparation
status, never the Human model labeled as another race. Their creation button is
disabled. All ten entries and the form fit the minimum 1100x650 viewport.


### Installed race previews - 2026-11-01

All ten entries now use their live 3D scene in Appearance. Keep Race and Model
(Male/Female) on the creation form; fixed-build inspection has no body sliders.
The outfit inspection control is only enabled for assets with separable outfit
coverage, never inferred merely from multiple material surfaces (hair may be a
separate surface). New race undergarments are part of the authored PBR mesh.

### Weapon calibration and animation capture - 2026-11-01

F7 owns Weapon Position: paired XYZ rows for metres/degrees, live changes, Save
Grip, Reset to Model and Stop Animation. Use the existing shared floating frame
and helper buttons/labels. Default placement is at the right; drag and viewport
clamping use the existing window manager. Clearly identify model/weapon, empty
hands and save errors. F6 captures without closing the animation window; selecting
a new clip plays on the character. Keep temporary replacement visibly distinct
from persistent skill mapping. Actions has no F7 label and remains in the menu.

### Animation authoring categories - 2026-11-01

F6 lists label Relaxed travel and Combat stance, and search includes those labels.
Idle and Combat idle are separate mappings. Clarify that in-world ordinary travel
playback is distance-matched automatically; Speed still controls preview/action
playback. Keep the existing compact animation window and helpers.

### F7 Fast Align - 2026-11-01

Replace Stop Animation with Freeze Animation / Resume Animation. Keep Fast Align
on a separate compact row, with plain-click position and Ctrl-click rotation
instructions. Show active mouse/wheel axes and commit/cancel guidance. Numeric
fields follow mouse edits. Save Grip remains distinct from finishing a mouse
pass. Use the existing draggable/clamped bronze frame and helper controls.

### Fast Align right-drag / Alt - 2026-11-01

Update the F7 inline instructions: hold right button to rotate the weapon, hold
Alt to rotate the hand, wheel for Z. Show hand rotation values and active target.
Escape cancels; remove the previous right-click-cancel hint. Keep the existing
600x440 floating frame, numeric rows, freeze/resume and Save Grip controls.

Animation Selection includes separate Sprint forward left / Sprint forward right
mappings alongside straight Sprint; retain the existing dropdown and clip list.

### Torven dialogue and required levels - 2026-11-01

Use the shared draggable brown/bronze/ivory window for NPC dialogue. Torven's
550x580 dialogue lists five compact square-icon skill rows directly in the box;
show skill name and Required level N with Locked / Available / Learned text.
Locked icons are muted and their buttons disabled. Eligible rows have LEARN;
learned rows have a disabled LEARNED button. No second trainer window. Retain
crafting and Class skills links below the list. K is for assignment and clearly
directs untrained players to Torven. Refresh status when level/class/training
changes, including while the dialogue remains open. Existing scrolling/clamping
supports 1100x650. Reference ideas: compact list hierarchy, inset bronze rows,
square icons, ivory labels, restrained gold availability emphasis; original
Godot assets/helpers only, no reference screenshots shipped.

K learned-only follow-up: hide all unlearned skill cards in K. Keep locked and
available training entries with required levels exclusively in NPC dialogue.
Show a short trainer direction when K has no learned skills.

### Developer controls - 2026-11-06

Use small bronze/brown DEV and SKILL controls on the left edge. In DEV mode,
SKILL opens a compact, nonmodal, draggable and scrollable list with square skill
icons, ivory names and explicit temporary-assignment guidance. The existing
frameless hotbar remains visible and accepts these drag payloads. Exiting DEV
restores its original assignments. Match the reference's compact icon rows,
dark insets, bronze edges and clear information hierarchy using original assets.

DEV → COLOR opens a compact, nonmodal list of live color-grading presets, with
an Original reset and a short explanation that previews end when DEV is turned
off. Keep the scene visible beside the panel and preserve the original, untinted
HUD so colors can be compared without compromising legibility.

### Character and inventory - 2026-11-06

I and the character button open one Character & Inventory panel. Keep character
identity, health, mana, progression, base attack, weapon damage, total attack,
and relevant bonuses beside the existing
equipment and bag. Weapon tooltips show their damage range. Use the existing dark
insets, bronze borders and compact ivory typography, with equipment and bag
remaining usable at supported window sizes. Steel Strike has its own square icon
in both the learned-skills interface and the DEV skill palette.

Skill-specific damage, costs and cooldowns belong in skill descriptions and
tooltips, not character stats. Steel Strike and Heavy Strike use distinct
image-generated square icons with dark grounds, silver blades and bronze edges.
