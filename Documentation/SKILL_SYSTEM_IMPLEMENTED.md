# Skill system: implemented prototype

## Open and use

- Run the project, press **K** for Skills & enchantments.
- There are **10 equipped slots**, activated with **1–9 and 0**, with **10 enchantment stages per skill**.
- Click a slot number to change the equipped skill. Equipping an already equipped skill swaps slots.
- Click **+** to choose from the stage's five saved offers. Click an installed enchantment to inspect its saved effect and rolled values; the inspection is read-only.
- **Reset all** refunds points and retains discovered offers. Reset does not reroll saved offers. Individual replacement is not exposed by the skill panel.
- First regional bestiary completions grant points and discover additional abilities. The lifetime budget remains **50 points**.
- Changes to skills, loadout and balance reloads require leaving combat.
- Hold a channel's keyboard key; release it to stop. A hotbar click toggles channeling. Channels consume mana per emission, move at 50% speed and turn at up to 360 degrees per second.

## Authoring window

In the Godot editor, open **Project → Tools → Skill & Modifier Distribution**.
The plugin lives in addons/skill_distribution/ so Godot can discover it. Restart the editor after pulling the plugin move.
If it is disabled, enable **Skill Distribution** under **Project → Project Settings → Plugins**.

The editable native Resource is resources/skills/skill_catalog.tres.

- **Enchantments:** authored tier (Basic, Rare, Epic, Legendary or Mythical), family occurrence weight, implementation weight, event weights, stat weights, activation chance, internal cooldown, mana surcharge, compatibility requirements and exclusions, provided capabilities and rolled min/max values.
- **Skills:** delivery type, base power, mana cost, cooldown, radius, range, projectile speed, channel interval, acquisition weight and enabled state for acquisition.
- **Affinities:** item, exact skill or delivery type, family, event and stat filters. An asterisk matches all. Weight multiplier 0 disables a matching outcome. Power percentage scales the rolled **amount**; it does not change duration, range or radius.
- **Rules:** projectile, field, status and event budgets; weakening/barrier/buff caps; recovery allowance; critical chance and multiplier; channel movement and facing limits.
- **Family percentages:** set normalized base shares, preserve locked families, redistribute the remainder. All implementations in a family share its base occurrence weight.
- **Context preview:** choose a skill/item and enter installed modifier IDs (for example impact, chain). Inspect compatibility, effective event weights and sample offers. The 1,000-sample simulation reports five-choice inclusion rates.

Tiers describe authored effect power and complexity; they do not automatically multiply values or change offer probabilities. Numerical ranges and offer weights remain independently editable. Saved rolls with no tier use the current definition’s tier, or Basic if the definition no longer exists.

Weights are relative probabilities, not activation chances. Family selection occurs without replacement, followed by a weighted implementation, event, stat and numerical roll. A custom configuration that disables most of the pool may produce fewer than five offers; the shipped default pool supports five through ten stages.

Changes remain drafts until **Save catalog**. Undo/redo applies to draft data. Saving validates the catalog, writes a temporary resource, then replaces the destination. In game, use **K → Reload Balance Data** to apply the saved base definitions outside combat. Existing rolled enchantments and already discovered offers retain their values.

## Delivery and interactions

All twelve planned delivery types run through the shared skill runtime: melee cone/area/projectile, cast cone/self area/target area/projectile/projectile with impact area, channel ray/projectiles, dash and cast effect.

Slot 2, Ember Bolt, starts as a pure projectile. Area support becomes eligible after an area provider such as Impact Burst, Lingering Field or a reactive area ward. The tooltip names the effects it enlarges. Area increases scale radius by the square root, preserving the intended area percentage.

Chain supports additional hops, range, damage retention per hop, a small hop delay and nearest/lowest-health/seeded-random selection. Targets require line of sight and cannot be revisited within the same cast. Pierce runs before Chain. **ON_CHAIN** fires when a hop launches, **ON_CHAIN_HIT** on contact, and **ON_CHAIN_END** on exhaustion, obstruction or target loss.

Hit modifiers can roll armor, enemy damage, movement speed or attack speed reductions. Empower effects can increase skill power or movement speed. Recover effects can roll health or mana. Leech restores a fraction of actual damage over time. Echo repeats a delivery at its saved power roll and delay while sharing its proc and recovery budget.

Compound wards commonly grant a timed buff after casting, then respond to received hits, blocks, evades or death with a burst or healing response. Refreshing a ward does not reset its shared family cooldown. Expiry events require natural expiry; reset, removal and death cleanup do not count.

The event processor uses per-cast budgets, per-enchantment activation tokens, internal cooldowns, bounded effect collections and secondary damage that cannot recursively trigger ordinary hit effects. Replacing a capability provider is rejected if an installed enchantment depends on it. Dependency cycles cannot bootstrap each other.

## Prototype boundaries

This remains a local combat prototype. Friendly area-heal propagation uses the skill_allies group and receive_skill_heal(amount) recipient contract; the current scene has no party members. Party targeting, network authority, PvP-specific balance, specialized icons for every new skill and final encounter balance remain future work.

Registered effect operations are implemented code. The editor can combine supported operations, events, stats and parameters and create new definitions by duplication; an entirely new operation requires a runtime implementation. Unsupported combinations fail validation.

## Chance effects, diagnostics, animation selection and spears

- New chance enchantments roll and save an activation probability from an authored min/max interval. Tooltips explicitly say “X% chance to…”. Direct contact can roll an area burst, field, enemy-stat reduction, resource recovery, leech, buff or secondary projectile. Healing can roll a pulse to other allies. Secondary damage does not recursively generate ordinary hit effects. Probability, event/stat weights, strength and intervals remain editable in the distribution editor.
- Open **K → Debug Effects** and choose any skill. The panel lists every installed enchantment, calculated pre-defense damage (including fields and Chain), and measured damage by source. It also shows hits, criticals, proc attempts/successes, active effects and a session total. Base, native splash, Echo, Pierce, Chain and each damaging enchantment are attributed separately. Passive modifiers show their shared-power/stat contribution. Clear Session Counters clears measurements without changing the build.
- Draggable window edges snap to the viewport and other visible windows with an 8px gap. Releasing a window chooses the closest clear placement when one fits. Reopening, restoring and resizing also settle positions. A large overlay may still overlap HUD panels when the viewport cannot fit them all; impossible layouts retain a stable position.
- Open **F6**, **Animations** in the menu footer, or **Options → Animation Selection**. Select weapon and action, filter the imported clips, preview the character, choose speed and upper/full-body playback, then **Save This Mapping**. Mappings persist per weapon and action in saves/animation_profiles.json. Preview does not deal combat damage. There are 240 imported clips, including 73 additionally converted actions; channel choices loop until channeling stops.
- A starter spear is added once for existing and new characters. Equip it through **I**. The forge now offers Sword, Greatsword, Spear and Staff. Spear defaults use a supplied fencing thrust and staff locomotion because the pack has no dedicated spear set; all mappings remain editable.

## Verification

Additional regression checks: test_skill_chance_debug.gd, test_skill_secondary_review.gd, test_spear_items.gd, test_window_snap.gd, test_hud_snapping.gd and test_animation_selection.gd.

Automated checks cover point conservation, legacy-save migration, stable offer/save/reset behavior, ten stages, compatibility, all delivery types, pure projectiles, impact area, Chain events and falloff, reactive wards, gradual leech, Echo and channeling. UI checks cover ten hotbar controls, ten square upgrade tiles, counters and five-choice picking at 1600×900. Editor checks cover drafting, undo/redo, context simulation and native-resource saving.

Run scripts with the included Godot executable, --headless --path . --script res://tests/TEST.gd -- --test-mode. Relevant tests are test_progression.gd, test_skill_catalog.gd, test_skill_runtime.gd, test_skill_panel.gd, test_distribution_editor.gd and test_combat_effects.gd. Run the UI tests without --headless to capture visual previews under .godot/.
