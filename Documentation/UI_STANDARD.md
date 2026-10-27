# XYLES interface standard

Visual reference: [FA v4.7.11 interface](https://maxcheaters.com/topic/225202-fa-v4711-interface-under-development/).
The implementation uses original Godot-drawn frames; reference screenshots are not shipped as game artwork.

- Dark translucent brown interiors, bronze rims, ivory text, engraved corners and a centered crest.
- Compact sans-serif text, thin red vitality and blue mana bars, square artwork slots.
- Status at the top left; map and quest journal at the right; system journal at the bottom left; five active skill shortcuts at the bottom center.
- Inventory follows the reference paperdoll: 21 equipment slots on the left, a nine-column bag on the right, and All / Equip / Supplies / Crafting / Quest tabs. Hover shows attributes and durability; double-click or right-click a bag item to equip it, and click worn equipment to remove it. Bottom controls repair, sort, and discard (with a second confirmation click). Wood and iron appear as live crafting stacks.
- All floating windows use title-bar dragging, stay within the viewport and remember their own positions in `saves/ui_layout.cfg`. Options includes a layout reset.
- Skills retain five active slots, square evolution groups, ten upgrade stages, the `+` / `X / 10` control and the completed `10/10` tile.

Reusable implementation: `scripts/classic_frame.gd` supplies the frame ornamentation, while the HUD's `_panel`, `_button`, `_bar` and `_label` helpers supply common styling. Register new floating HUD windows through `_register_window`; use a title-only hit area so content buttons remain interactive.
