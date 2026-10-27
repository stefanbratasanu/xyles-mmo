# Modifier data assets

Modifier data is stored as Godot `Resource` assets under `resources/modifiers/` so it can be edited in the Inspector and versioned as text `.tres` files.

- `definitions/general/` contains universal stat modifiers.
- `definitions/item_specific/` contains skill or item-specific modifiers.
- `pools/` contains the weighted roll lists, including the separate staff enchantment list.
- `modifier_catalog.tres` connects the pools and stores the modifier counts for each rarity.

Each pool entry has a relative `weight`. The game converts the positive weights into a normalized probability distribution every time it rolls; the resulting chances therefore add up to 100% without manually balancing the other entries. `ModifierPool.get_normalized_distribution()` exposes each entry's current chance to the editor window and runtime tools. Entries with zero, negative, or non-finite weights are ignored. The roll API only selects a modifier definition from the resource catalog; it does not execute text or scripts from the data files.

The first set keeps the existing prototype modifiers and effects. The staff pool currently contains Ember Bolt damage because it is the only staff-compatible skill enchantment defined by the current project data. Add more `ItemModifierDefinition` assets and weighted entries as the available enchantments are designed. Focus items use this pool; other equipment uses the general and item-specific pools.

`XylesGameState.reload_modifier_catalog()` reloads the catalog and referenced assets while the game is running, which supports quick balancing iterations without restarting the session.

## Open the editor window

The `Modifier List Editor` Godot editor plugin is enabled for this project. Reopen the project in the Godot editor if it was already open while this plugin was added. Then choose **Project → Tools → Modifier List Editor**.

Choose a pool at the top of the window. Edit a modifier's display name, stat effect, value, or relative weight. The chance column updates as weights change. Use **Add modifier** or the row's × button to change the pool, then click **Save changes** to write the `.tres` files. The rarity counts are editable in the same window. Use **Reload from disk** after external changes; if there are unsaved edits, the window asks before discarding them.
