# Xyles World Editor

Run **`XYLES WORLD EDITOR.exe`** from the game folder. The executable starts a separate editor process using the Godot executable and project assets in that same folder; it is not a self-contained export. If assets are missing after a pull, prepare them with the existing `PLAY XYLES.bat` launcher first.

The left side is the 3D map view. With the pointer over the map, use **W/A/S/D** to fly and **Q/E** to move down/up. Hold **right mouse** to look around, turn the **mouse wheel** to zoom toward or away from the pointer, and hold **Shift** while moving to fly faster. **Shift + wheel** adjusts camera speed. The top bar holds project and brush controls. The right side contains the asset, terrain, object, zone and draft panels. Map I is currently the only source map.

## Projects and the game

1. Choose **New project**, select Map I, and choose either a copy of the map currently applied to the game or an empty map. Alternatively, use **Load project** to open a saved draft. A copy of the applied map is a new, independent project even if its source draft has since been changed.
2. Enter a name and choose **Save draft**. This saves an editable local project without changing the game.
3. Choose **Apply to game** to publish a copy. Restart the game to load it. The right panel shows the currently applied snapshot. Saving or editing a draft after applying it does not change the game until Apply is used again.
4. To restore the original world, open the **Drafts** tab and choose **Use original map in game**, then restart the game.

Drafts and the applied snapshot are stored per Windows user under Godot's `app_userdata/XYLES_MMO/world_editor` directory, not in the Git repository. They are local to this computer and are not a multiplayer distribution or server system. A previous successful file is kept as a backup.

## Assets and terrain

The **Nature** and **Buildings** panels display the project's models in 3D. Hover over a card to rotate its preview; click a card and then click the map to place it. Enable **Asset brush** in the top bar and choose its radius to paint multiple copies while dragging. Nature brushes avoid water, roads and overlapping tree trunks and follow the existing zone tree families.

To change an object, open **Object**, select **Select objects**, click it in the map, and edit its position, rotation or scale or delete it. The editor can select placed objects, existing trees and vegetation, and many existing scenery objects. Some original compound structures are not individually editable: in particular, the original camp fence shares its collision across the entire ring. New fence segments can be placed from the Buildings panel.

In **Terrain**, click a 3D material card to paint it, or choose raise, lower or erase from the tool list. Adjust the brush radius at the top or in the terrain panel. The ring in the viewport shows the brush. Placing or brushing a lake from Nature automatically carves a shallow basin, blends the bank into nearby ground and paints a dirt shoreline. The lake brush places separate ponds with room between their banks. Moving or scaling a lake later does not reshape its existing shore; place the lake at its intended size and position or edit the terrain afterward.

Press **Ctrl+Z** to undo recent placements, brush strokes, object edits, zone edits, clear or fill actions. One continuous brush drag counts as one action. Up to 20 actions are retained for the current project session; opening or starting a project clears this history. Restoring a large edited terrain can take time. Undo changes the draft, not the applied game snapshot; save and apply again when ready.

**Clear entire map** removes the draft's terrain, roads, lakes, vegetation and scenery after confirmation. It does not immediately change the game. Use a terrain brush to add ground, or **Fill empty ground** to create a flat starting surface. Existing gameplay spawn locations and region rules remain; before a cleared map can be applied, ground must exist under the required player, NPC and enemy spawn positions. The editor reports the first missing position.

Terrain changes do not automatically reposition existing scenery. Original road and lake surfaces are rebuilt against edited heights, but the original road network and lake definitions are not separately editable as paths or water bodies; clear the map and rebuild them if those need to be removed. Edited terrain tiles are loaded together instead of using the original terrain's buffered streaming, and placed objects are individual nodes. Large painted populations or extensively edited terrain may reduce performance; startup, memory use and frame rate for large edited maps have not been benchmarked.

## Zones

Open **Zones** to see the original game zones and saved custom zones as colored areas; the panel's legend identifies the original colors and the custom list uses matching colors. Choose **New zone**, enter a name, type and enemy level range, then choose **Paint selected zone**. This enables the zone brush automatically: the yellow ring follows the mouse, and yellow cells mark the unfinished area. Paint in the viewport with the current brush radius. Right-click the map to finish the zone in the draft; while painting a zone, hold **Shift + right mouse** to look around. Select an existing custom zone to add to it, use **Erase from zone** to remove painted cells, or delete the selected zone. Save the draft after finishing. Undoing a finished zone first reopens the unfinished painting; another undo can remove the previous brush stroke.

Painted zones override the original region lookup within their area. Existing enemies whose spawn point is in a painted zone use the midpoint of its level range, rounded to an integer: for example, 1–3 produces level 2. The zone has its own first-discovery bestiary key. Starter, Enemy and Neutral are zone classifications; they do not automatically move player spawn points or create enemies. Decide new species, spawn locations and day/night windows with Alin or Stefan before adding mob spawning, as required by the project rules.
