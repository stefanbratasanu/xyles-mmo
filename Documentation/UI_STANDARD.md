# XYLES interface standard

Visual reference: [FA v4.7.11 interface](https://maxcheaters.com/topic/225202-fa-v4711-interface-under-development/).
The implementation uses original Godot-drawn frames; reference screenshots are not shipped as game artwork.

- Dark translucent brown interiors, bronze rims, ivory text, engraved corners and a centered crest.
- Compact sans-serif text, thin red vitality and blue mana bars, square artwork slots.
- Status at the top left; map and quest journal at the right; system journal at the bottom left; five active skill shortcuts at the bottom center.
- Inventory uses an equipment column and an eight-column bag grid. Item attributes and durability remain available through tooltips.
- All floating windows use title-bar dragging, stay within the viewport and remember their own positions in `saves/ui_layout.cfg`. Options includes a layout reset.
- Skills retain five active slots, square evolution groups, ten upgrade stages, the `+` / `X / 10` control and the completed `10/10` tile.

Reusable implementation: `scripts/classic_frame.gd` supplies the frame ornamentation, while the HUD's `_panel`, `_button`, `_bar` and `_label` helpers supply common styling. Register new floating HUD windows through `_register_window`; use a title-only hit area so content buttons remain interactive.
