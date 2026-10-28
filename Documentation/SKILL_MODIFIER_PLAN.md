# Skill modifier system — proposed implementation

Status: design plan, revised October 28, 2026. Gameplay has not been changed by this plan.

## Confirmed scope

- Ten equipped active skills, each with up to ten installed evolution modifiers.
- Choosing an upgrade presents five fully rolled, compatible alternatives; choose one.
- Keep the 50 lifetime bestiary skill points. Installing a modifier costs one point, so the character can fill at most 50 of the 100 possible upgrade positions.
- Keep ordered evolution previews, individual replacement and the full reset/refund button.
- Replace the three fixed rank branches and their compulsory branch-spreading rule. Distinct modifier families, tradeoffs and stack limits provide build diversity instead.
- Use only the twelve delivery types specified below. Ten active slots are loadout capacity, not ten delivery types. Additional named abilities will be authored from this list rather than introducing new types.
- Skill #2 is a cast projectile only: its base impact has no splash, explosion or area. A separately installed enchantment may create a secondary area effect.
- These are proposed balance values, not claims about Path of Exile's rules. Compatibility branches broaden enchantment availability across skill types without promising that every enchantment fits every skill.

## 0. Approved skill types and compatibility contract

| Type ID | Delivery and targeting | Native capabilities / dimensions |
|---|---|---|
| `melee_cone` | Weapon sweep in facing direction | Hit, melee, cone; reach and opening angle |
| `melee_area` | Radial weapon strike around caster | Hit, melee, area; radius |
| `melee_projectile` | Weapon-driven projectile | Hit, melee-origin, projectile; projectile speed, travel range, count |
| `cast_cone` | Spell cone from caster | Hit/effect, spell, cone; reach and opening angle |
| `cast_area_self` | Spell area centered on caster | Spell, area; radius; movement does not move an already placed field unless explicitly attached |
| `cast_area_target` | Spell area centered on selected enemy | Spell, area, enemy-targeted; cast range and effect radius are separate |
| `cast_projectile` | Spell projectile; direct impact only | Spell, projectile, hit; no native area. This is skill #2 |
| `cast_projectile_area` | Spell projectile with impact area | Spell, projectile, hit, impact-area; travel range and explosion radius are separate |
| `channel_ray` | Sustained aimed ray | Channel, ray; range and beam width. Beam width alone does not imply an area explosion |
| `channel_projectiles` | Sustained projectile emissions | Channel, projectile, hit; emission rate, projectile speed and travel range |
| `dash` | Movement action along a direction/path | Movement, dash; distance and travel speed. No native hit, area or invulnerability unless specified by the base ability or an installed modifier |
| `cast_effect` | Direct recipient effect, such as healing | Spell, effect; recipient self/ally/enemy set by the ability. No native hit, projectile or area |

These describe geometry and delivery, not damage elements or classes. Individual abilities declare which events they emit: a ray can deal hit pulses or periodic damage, but periodic ticks must not quietly become hits. Cone/area spells can carry healing when explicitly authored for friendly recipients; enemy-only templates must still filter them out.

**Channel movement:** while actively channeling, movement speed is 50% of the character's otherwise applicable movement speed. This is one multiplier applied once, including while strafing or backpedaling. Costs and pulses use simulation time rather than frame rate. Releasing, cancellation, death, interruption and insufficient mana end the channel cleanly. No new channel-specific mobility bypasses are proposed initially.

**Channel turning:** cap facing change at 360 degrees/second (2π radians/second), using the shortest angular difference and `turn_rate * delta`. The free-look camera remains free; the ray/projectile origin follows character facing, not an instantly rotated camera. The aim indicator displays the actual attack direction. Initial channel turning cap is shared across mouse and click/keyboard aiming, rather than dependent on input device. Channeling rejects dash, roll and jump until the channel is cancelled.

### General implementation plus weighted implementations

An enchantment family owns a default implementation and zero or more explicit variants. The family stays recognizable; its variant has its own honest name and precise tooltip. Offering a projectile-capable variant of a broad family is valid; offering a melee-only implementation to a projectile-only skill is not.

Each variant declares:

```text
family_id / implementation_id
requires_all / requires_any / excludes
scope: base_skill | named_secondary_effect | matching_effect_nodes
provides: capabilities created by this variant
target_filter: self | ally | enemy
trigger / effect / allowed propagation
weight / value ranges / tradeoff
scales: explicit named dimensions or stat IDs
dependencies: provider modifier IDs or base effect IDs
```

Offer resolution: inspect the effective skill graph → gather compatible implementations of a family → remove invalid recipients, unmet dependencies and conflicts → normalize positive branch weights within that family → roll one implementation and its variables. Family weight and implementation weight are separate controls; adding three variants must not unintentionally triple that family's chance. Zero weight disables an implementation. Unsupported families are omitted from the five choices; a developer preview explains why.

Use the default implementation whenever its declared requirements are satisfied. Weighted fallback variants resolve where that default is unavailable. An editor switch may explicitly allow alternative implementations alongside the default, with weights normalized across the enabled alternatives. This avoids silently replacing a normal area bonus with an explosion when a native area already exists.

No random implementation selection occurs during hits. The chosen implementation, values and dependency IDs are stored with the offer and installed instance. New definitions on hot reload do not reroll existing choices.

### Area of effect: the required concrete example

“Increased area” and “increased radius” are different operations. Standardize the generic enchantment as **increased area of effect**: +25% area scales circular radius by √1.25, approximately +11.8%. A cone with fixed opening angle scales its reach by the same square-root factor. An enchantment that widens opening angle instead names the angle change explicitly. Healing potency, debuff strength, projectile damage, projectile count, collision thickness and cast range do not increase from an area bonus.

| Current effective skill | Area-family implementation | What changes and required tooltip |
|---|---|---|
| Native cone | Default area scaling | “25% increased Cleave cone area: reach 3.00 → 3.35 m; angle unchanged.” |
| Native self/target area | Default area scaling | “25% increased Nova area: radius 3.00 → 3.35 m.” Does not change target-selection range |
| Projectile with native impact explosion | Default area scaling scoped to explosion | “25% increased impact explosion area: radius 2.00 → 2.24 m. Projectile travel unchanged.” |
| Projectile only, with an installed on-hit burst | Default area scaling bound to that burst | “25% increased Ember Burst area: radius 2.00 → 2.24 m. Synergy: Ember Burst, evolution #3.” |
| Projectile only, no area provider | Weighted fallback: Impact Burst | Adds a secondary hit-area, e.g. radius 1.50 m, 25% base impact damage, explicit proc interval. Label: “Adds Impact Burst”; does not claim to enlarge a nonexistent area |
| Projectile only, no area provider | Weighted fallback: Ground Field | Impact creates a 1.50 m field for 2 s at an explicit tick rate/power. Label: “Adds impact field”; ordinary field ticks do not trigger on-hit chains |
| Dash, no area provider | Weighted fallback: Arrival Pulse | Adds an arrival effect with explicit radius, recipient and potency; no automatic damage if the selected variant is defensive |
| Ray, no area provider | Weighted fallback: Contact Pulse | Adds bounded pulses at the actual beam contact point; a miss does not create an enemy impact |
| Direct heal, no area provider | Weighted fallback: Healing Burst | Adds a secondary ally heal around the original recipient at a specified fraction of effective base healing, excluding the original recipient to avoid hidden double healing |

The 25% example and fallback weights/values are editable starting values. For a projectile with no area, example fallback weights could be Impact Burst 70 / Ground Field 30. Each variant is independently enabled and tuned. Adding a provider spends one evolution; subsequently increasing its area spends another evolution. A bundled “creates an area and enlarges it” variant would require a separate definition and explicit combined cost/tradeoff, rather than secretly granting both effects.

When an effect already provides an area, the offer explains its current and resulting size. If several area nodes exist, the definition explicitly chooses `all eligible areas` or one named target node; the tooltip enumerates each affected radius. A generic bonus applies once per effect node; inherited and local scaling must never double-count it.

### Other broadly shared families

| Enchantment family | Default implementation | Explicit weighted fallback examples |
|---|---|---|
| Additional delivery | Extra projectile for a projectile source | Extra cone sweep, extra area pulse, secondary healing pulse; each has its own power/cost and timing |
| Propagation | Projectile chain where projectiles exist | Jumping debuff application, bounded ally-heal relay, dash-arrival relay. They do not inherit projectile penetration or projectile-speed bonuses |
| Duration | Scale existing timed effect nodes | Add an aftermath buff on completion, add a short field, or omit when no approved variant exists. Does not extend dash invulnerability or channel duration by accident |
| Speed | Projectile travel speed for projectile nodes | Cone execution speed, area activation time, ray pulse rate or dash travel speed as separately named variants. Animation speed, cooldown and cast rate remain distinct stats |
| On-event weakening | On-hit reduction on enemy-hit nodes | Ray-hit weakening for hit rays, interval-limited channel-contact weakening for periodic rays, arrival-hit weakening for an already damaging dash. A friendly heal does not reduce an ally's armor |
| Empowerment | On-hit self buff on hit-producing nodes | On-effective-heal ally/self buff, on-channel-completion buff, on-dash-completion buff. Trigger names and recipients change visibly |
| Recovery | Damage-derived leech on damaging nodes | Mana return after effective healing, shield after successful movement, resource recovery after channel interval; no fake damage or invented hit needed |
| Focused power | More direct damage with a delivery drawback | More healing with shorter cast range, more ray power with higher mana/sec, more dash-arrival effect power with shorter travel; only approved existing dimensions can be traded away |

Variants share a family theme, not necessarily identical numerical strength. Broad availability comes from deliberate implementations and valid dependencies, not replacing every unsupported stat with generic damage. A family with no useful, authored variant remains unavailable for that skill for now.

### Effect graph, dependencies and respec

Compile each skill as named effect nodes: e.g. `projectile → impact_hit → ember_burst(area_hit) → burning_ground(periodic_area)`. Enchantments bind to nodes and capabilities, not skill names. “Spell projectile only” describes the base delivery; optional explicitly installed secondary effects can expand its effective capabilities.

Construction happens in two passes: first install base nodes and approved provider variants; then bind amplifiers and triggers to valid nodes. Preview order remains historical and cannot change combat results. Provider definitions cannot require a capability that only their own dependent amplifier creates; validate dependency cycles.

Replacing/removing an area provider immediately previews dependent enchantments. If the replacement creates an equivalent eligible area, dependencies can rebind with an explicit confirmation in the allocation preview. Otherwise the operation requires replacing/removing its dependents too; refund removed allocations. Do not silently keep a dead upgrade, roll a fallback for an already chosen modifier, or convert its stored values. Full reset refunds all allocations as before. Offer choices that have become incompatible remain recorded but are disabled with a reason; regenerate neither their rolls nor hidden replacement choices.

Tooltip format:

```text
Expanded Area — +25% increased area
Applies to: Ember Burst (evolution #3)
Radius: 2.00 m → 2.24 m
Synergizes with: Ember Burst; Lingering Flames
Unchanged: projectile travel, direct impact damage, burn damage per tick
Requires: an eligible area effect from this skill
```

Synergy references come from actual effect bindings and shared stats, including exact stage names. Do not generate speculative compatibility claims in tooltip prose. Editor preview shows compatible, fallback and unavailable states for all twelve approved types, including the effective graph after adding/removing each modifier.

## 1. Player-facing upgrade flow

1. Click a skill's `+ / X / 10` tile.
2. Open five choices showing the exact trigger, effect, rolled stat, magnitude, duration, restrictions and cost tradeoff.
3. Show a before/after summary and compatibility notes: “Your chain hits can apply this effect”; “Your existing slow satisfies this condition.”
4. Pick one, spend one skill point, and install its rolled instance in the selected position.
5. All installed modifiers support that skill together. Position order is visual history, not combat execution order.
6. Each offered set is generated once and saved. Closing the window, restarting, or resetting does not reroll the same offer.
7. Replacing one stage opens that stage's retained alternatives. Its original roll remains recorded; currently incompatible options explain their unmet requirements. A one-for-one replacement does not refund or spend another point and cannot generate fresh rolls. Removing dependent allocations explicitly refunds them as described in the compatibility contract.
8. Reset removes allocations and refunds spent points, retaining discovered rolls. Starting balance policy: change allocations out of combat; inspect at any time. No reset currency initially.

Five choices are five candidate modifiers, not five compulsory branch ranks. Offers are weighted across compatible families, contain no exact duplicates, and prefer at least three families when enough valid candidates exist. Each candidate rolls a template first, then allowed variables. There are no arbitrary script expressions in data.

## 2. A modifier is a composed effect

Example instance:

```text
Template: On-hit weakening
Trigger: direct hit from the supported skill
Recipient: hit enemy
Action: reduce stat
Rolled stat: armor
Magnitude: 6% increased armor reduction per stack
Duration: 4 seconds
Stack limit: 3
Proc chance: 100%
Tradeoff: supported skill costs 8% more mana
Source: character / skill / installed modifier instance
```

The same template can roll outgoing damage, movement speed, attack speed, cast speed, elemental resistance or healing received. Labels must be explicit: “reduce outgoing damage” is different from “increase damage taken”; “movement speed” is different from “attack speed.”

Randomness is resolved when the offer is created, not every frame. The installed modifier keeps its values. Hit chance and proc chance are separate combat rolls. Triggered effects do not automatically roll every eligible stat.

## 3. Modifier families and initial catalogue

Each row is a reusable template with weighted sub-pools. Values are a starting balance proposal and need encounter testing.

| Family / template | Parameters and initial values | Interactions and boundaries |
|---|---|---|
| Power: added damage | Add 8–14% of base damage as physical, fire, frost, lightning or arcane | Supports damaging hits; conversion happens first; does not recursively scale added damage from itself |
| Power: focused impact | 15–22% more direct damage; 15% smaller area | Suitable for boss builds; does not multiply attached healing or debuff magnitude |
| Power: area scaling | 15–25% increased area; damage variants may trade 8% hit damage | Scales eligible area nodes; radius/reach follows square-root scaling. Friendly variants require an appropriate independent tradeoff |
| Conversion | Convert 20–35% of original physical damage to one element | Total conversion capped at 100%; conversion has one pass and cannot loop |
| Critical chance | +2–4 percentage points of critical chance | Only skills with critical-capable hits; periodic ticks do not become hits |
| Critical payoff | +15–25 percentage points of critical multiplier | Works with critical-trigger modifiers; no automatic critical healing |
| Penetration | Ignore 5–10% of a relevant defense for this skill's hit | Local to the hit, unlike shared armor/resistance debuffs |
| Delivery: extra projectiles | +1 projectile; each deals 20% less damage | Spreads eligible on-hit effects; one cast cannot shotgun one target unless explicitly allowed |
| Delivery: pierce | Pierce 1–2 additional enemies | All eligible traversed hits can apply on-hit effects; no rehit of the same enemy on the same outbound segment |
| Delivery: chain | Chain to 1 additional target; chained hits deal 25% less damage | New target only; chain target selection is deterministic and range-limited |
| Delivery: fork | First hit splits into 2 child projectiles; children deal 40% less damage | One generation; children inherit allowed damage and hit debuffs, not fork itself |
| Delivery: return | Projectile returns; return hit deals 50% less damage | At most one return hit per target per cast; explicit second hit can trigger eligible on-hit effects |
| Delivery: echo | Repeat after 0.35 seconds at 45–60% effectiveness; +20% mana cost | One echo; repeats share a cast identity; cannot echo another echo |
| Delivery: pulse | Ground field pulses 2 additional times at reduced damage/healing | Each pulse has an ID; damage-over-time remains separate from pulse hits |
| Duration | 15–25% increased duration of this skill's effects | Extends valid buffs, debuffs and fields; does not extend cooldowns or invulnerability by default |
| On-hit: weaken | Reduce one rolled enemy stat by 4–7%, for 4 seconds, max 3 stacks | Armor, outgoing damage, movement speed, attack speed, cast speed, one elemental resistance, healing received |
| On-hit: expose | Target takes 4–6% increased damage of one rolled type for 4 seconds | Different from defense reduction; belongs to a shared vulnerability family cap |
| On-hit: empower | Gain 2–4% attack speed, cast speed, movement speed, armor or mana regeneration for 3 seconds, max 3 stacks | Recipient is self, not enemy; own stats only; fast hits refresh the cap rather than create unlimited stacks |
| On-hit: recovery | Recover 1–2% max health or mana with a 0.5-second internal cooldown | Self-recipient only; recovery budget shared across projectiles in one cast |
| On-hit: leech | Store 2–4% actual damage as health or mana recovery over 2 seconds | Requires real damage; global recovery-rate cap; overkill does not generate extra leech |
| On-hit: mark | Apply a named mark for 5 seconds | Exposes a condition for payoff, spread and consumption templates; one mark of a given family per target/source |
| On-critical: exploit | Apply one stronger weakening stack, or gain a short self buff | Separate pool; requires a critical-capable skill; uses internal cooldown and family caps |
| On-kill: momentum | Gain 5–8% movement speed or mana regeneration for 5 seconds | Direct kills and owned periodic kills qualify; party credit alone does not |
| On-kill: burst | Explosion for 12–18% of the victim's base maximum health, capped by skill power | Cannot kill-chain another explosion; can apply explicitly allowed debuffs at reduced effectiveness |
| On-block: counter | After a successful block, gain 6–10% damage or armor for 3 seconds | Only actual blocked incoming hits; not holding the guard key |
| On-block: retaliation | Nearby physical counter-hit, at most once per second | Emits a secondary hit; cannot trigger itself or another retaliation chain |
| On-dodge: opening | After successfully evading an enemy hit during a roll, empower the next direct hit | Performing a roll alone does not count as successful evasion |
| Movement: trail | Leave a damaging, slowing or healing field for 2–3 seconds | Fixed placement interval; pooled field visuals; does not trigger on-hit from periodic damage |
| Movement: arrival | Small burst at arrival that damages, weakens or grants ally armor | Only on a completed movement skill, not every movement frame |
| On-heal: fortify | Effective healing grants 3–6% armor or damage reduction for 4 seconds | Requires actual health restored; repeated tiny heals share an application interval |
| On-heal: overflow | Convert 15–25% overhealing into a temporary barrier | Barrier capped at 15% recipient max health and lasts 4 seconds; barrier is not healing |
| On-support: haste | Buffed ally gains 4–7% attack speed, cast speed or movement speed | Explicit ally/self recipient; same-family buffs use strongest value rather than party-member stacking |
| On-expiry: aftermath | Natural expiration creates a small pulse or resource return | Dispel, replacement, respec and death are separate removal reasons and do not qualify |
| Condition: execution | 15–22% more hit damage below 30% target health | Applied at hit resolution; tooltip distinguishes threshold from chance |
| Condition: exploitation | 12–18% more hit damage against slowed, marked, burning or weakened enemies | Roll a condition the build can create, or offer it with a clearly stated unmet dependency |
| Condition: healthy | Gain damage while above 80% health, or mitigation below 35% | Values evaluated at event time; no per-frame search of all modifiers |
| Spread | Spread one eligible weakening/ailment family to 1–2 nearby enemies | Copies remaining duration at 60% magnitude; spread cannot spread again |
| Consumption | Consume up to 3 mark/weakening stacks for extra damage, healing or mana | Consumes only the named eligible family, once per direct cast; cannot consume party members' stacks by default |
| Ailment: burn / poison / bleed | Apply tagged damage over time, scaled from base hit contribution | Explicit type and refresh/stack rules; ticks do not count as hit events |
| Ailment: chill / shock | Apply slow or damage vulnerability based on ailment power | Resistant bosses reduce magnitude/duration; no permanent crowd-control loop |
| Control | Chance to briefly stagger, root or silence with internal cooldown | Compatible delivery only; diminishing returns and boss resistance are mandatory |
| Resource: efficiency | 10–15% reduced mana cost with 5–8% less damage/healing | Meaningful economy choice; minimum final cost enforced |
| Resource: blood cost | Pay 15–25% of mana cost as health instead | Cannot pay below 1 health; separate from damage taken and does not trigger defensive procs |
| Resource: reservation | Reserve 10–20% mana to maintain an aura version of a compatible buff | One delivery conversion per skill; cannot combine with arbitrary echo/projectile conversion |
| Tempo | 8–12% reduced cooldown; 8% less power | Cooldown, cast time and animation playback are separate; action events follow actual cast timing |
| Charge | +1 charge, slower recharge | Explicit charge recovery; cooldown reduction affects recharge once, not twice |
| Party: relay | Directly applied support affects one extra nearby ally at 60% strength | Target cap; relay cannot relay; avoids exponential party propagation |

Enchantment families should generally span skill types through authored variants. Each resolved implementation must support the effective skill graph. A movement skill without a hit cannot roll on-hit until a compatible arrival-hit modifier supplies that capability; an approved on-arrival fallback is a distinct implementation. Healing does not roll enemy armor reduction without an enemy-damaging delivery. Offer generation previews capabilities added by installed modifiers, but must not offer an unusable effect as if it already works. Only the twelve approved delivery types are in scope initially; catalogue entries outside those capabilities remain disabled until an explicit branch supplies the needed effect.

## 4. Stat registry and valid actions

| Stat pool | Allowed recipients / operations | Initial cap policy |
|---|---|---|
| Armor / elemental resistance | Enemy reduction; self/ally increase | Armor reduction max 40%; resistance reduction max 30 percentage points per element |
| Outgoing damage | Enemy decrease; self/ally increase | Enemy damage reduction max 30% from modifier debuffs |
| Damage taken | Enemy increase; self/ally decrease | Separate vulnerability and mitigation buckets, each capped |
| Movement speed | Enemy slow; self/ally haste | Slow max 50%; movement remains functional unless explicit root applies |
| Attack / cast speed | Enemy reduction; self/ally increase | Separate stats; floor prevents zero-speed characters |
| Health / mana recovery rate | Self/ally increase; enemy recovery suppression | Separate leech, regeneration and direct restoration caps |
| Critical chance / multiplier | Self or supported skill | Critical chance capped at 75% initially |
| Block chance / block strength | Self or guard effect | Cannot exceed configured defense caps |
| Area / projectile speed / duration | Supported skill only | Bounded multipliers; no irrelevant entity debuffs |
| Maximum health / mana | Persistent self or buff template only | Never randomly included in the basic enemy weakening pool |

Percent reductions and percentage-point changes are different stat operations and must be displayed differently. Costs, cooldowns, projectile count and defense values cannot be produced through one unconstrained random-stat list.

## 5. How modifiers work together

**Ember Bolt — spreading exposure:** extra projectile → chain → on-hit fire resistance reduction → longer debuffs → damage against weakened targets. An impact applies weakening after its damage; subsequent impacts benefit. The same impact cannot consume a debuff it has not applied yet.

**Cleave — armor breaker:** on-hit armor reduction → mark → consumption on a later direct cast → leech → area scaling. Multi-target hits apply debuffs per victim; recovery retains its per-cast cap.

**Guard — retaliation fighter:** successful block → retaliation hit → on-hit slow on that retaliation if explicitly permitted → bonus direct damage against slowed enemies. Retaliation cannot trigger another retaliation or self-loop through “on hit taken.”

**Restoring Light — party support:** effective healing → armor buff → duration → overheal barrier → relay to one ally. The actual healed portion and overhealed portion are distinct values; a barrier never emits a healing event.

**Dodge Roll — field controller:** arrival pulse → on-hit outgoing-damage reduction → lingering slow field → successful evasion empowers next attack. The field's periodic damage cannot repeatedly trigger the arrival pulse.

**Cross-skill interaction:** Cleave reduces armor and a physical ranged skill benefits from that enemy debuff. Guard grants a self haste buff and both weapon skills benefit. Restoring Light's barrier protects a caster while they channel. Skill-local bonuses stay local; entity buffs and target debuffs expose explicit shared effects.

Compatibility should come from declared capabilities and event permissions, not hardcoded checks against skill display names. All meaningful combinations have a rule; incompatible combinations are explained and excluded from offers rather than silently doing nothing.

## 6. Deterministic combat and stacking rules

Resolution order:

1. Validate action, pay cost and allocate cast ID.
2. Resolve delivery changes and snapshot relevant caster values.
3. Resolve avoidance/block and current target defenses.
4. Convert base damage once, add eligible damage, sum increased/reduced bonuses, apply explicit more/less multipliers, then apply defense/penetration and damage.
5. Emit hit and critical events using actual resolved results.
6. Apply debuffs, ailments and recovery in a stable priority order. Emit death/kill once.
7. Queue bounded secondary effects; update expiry timers and record removal reasons.

- Same source + template + stat + target stacks up to its own cap, then refreshes; reaching the cap does not create new objects.
- Identical debuff families from different players use the strongest effective stack group, with independent durations, rather than adding without limit. Contributors still receive valid combat attribution.
- Different stats coexist: slow, armor reduction and healing suppression all work together. Global family caps are applied after aggregation.
- Increased/reduced values add within their bucket. Explicit more/less modifiers multiply and carry stronger tradeoffs. Tooltips name the bucket.
- Secondary events carry origin, parent cast, generation, visited targets and allowed trigger mask. Maximum secondary generation is two; a global per-cast event budget bounds fork/chain/explosion combinations.
- On-kill explosions cannot trigger on-kill explosions. Echo cannot echo; spread cannot spread; retaliation cannot retaliate. Every exception is explicit data.
- Persistent damage uses the caster snapshot from application and current target mitigation at tick time. Periodic ticks do not rerun hit effects.
- Combat RNG is separated from offer RNG. A future authoritative server owns both and validates allocations and event results.

## 7. Runtime performance

“Fast” should mean both responsive gameplay and predictable computation.

- Compile installed modifiers only after allocation, replacement, gear changes or data reload.
- Cache final scalar stats and index handlers by event type; an ordinary hit visits only its hit-related handlers.
- Use numeric stat IDs and validated effect records. No parsing tooltip strings during combat.
- Use one shared status scheduler and per-actor status arrays; no Node/Timer allocation per stack or per tick.
- Spatial queries use bounded candidate counts and existing physics/spatial indexing. Chain/relay/spread have explicit radii and target caps.
- Pool projectiles, fields, impact visuals and floating text. Warm required assets before combat, following the earlier hitch fixes.
- Dispatch events through a bounded queue; never recursive synchronous proc calls.
- Target initial benchmark: 30 enemies, ten heavily modified skills, simultaneous projectiles and periodic effects. Record median/p95/p99 frame time and allocation spikes on the actual machine before setting a numerical performance promise.

## 8. Godot resources and editor

New versioned text resources:

- `SkillDefinition`: ID, tags/capabilities, base delivery, costs, targeting, cast action, animations.
- `SkillModifierDefinition`: family ID and family weight, default implementation, independently weighted fallback implementations, capability requirements/provisions, effect-node scope and dependencies, trigger, recipient, operation, weighted stat pool, roll ranges, stacking, tradeoff and propagation policy.
- `StatDefinition`: ID, display label, unit, allowed operations, aggregation bucket, min/max.
- `ModifierOffer`: stable offer ID, five rolled alternatives, seed/version, skill ID, stage, chosen option.
- `InstalledModifier`: definition ID, resolved variables, source identity and schema version.
- Runtime-only compiled handlers and status instances; saves do not serialize nodes or callable scripts.

Extend the Modifier List Editor with a separate Skill Modifiers tab. Keep equipment affix pools separate. Editors expose family/implementation/stat weights, value ranges, compatibility, stack limits, internal cooldown and proc inheritance. Positive weights normalize to 100% within their own selection level; changing one updates displayed percentages. Validate missing IDs, invalid ranges, impossible stat operations, empty offer pools, incompatible capabilities, dependency cycles and unsafe propagation before reload. Preview every approved skill type and show exactly which effect dimensions each branch changes. Existing casts finish with their old snapshot; new casts use the new data version.

## 9. Ten active skills and UI

- Ten slots bound to `1–9, 0`, with drag-to-equip and a learned-skills list.
- Retain existing abilities where they fit the approved types. Skill #2 becomes `cast_projectile`, with no base splash. Existing Guard must be mapped deliberately to a defensive `cast_effect` ability if retained; this plan does not add an unapproved thirteenth skill type.
- Additional learned abilities must use the approved types. The previous proposed five-skill roster is superseded; named abilities and unlocks remain to be authored. Twelve types need not all appear on one ten-slot loadout.
- Scrollable skill rows preserve square evolution icons and `X / 10`. Five-option picker includes exact values and interaction explanations, with vertical scrolling on smaller screens.
- Show installed effects in the tooltip, with separate sections for damage, delivery, triggers, statuses, cost and cooldown. A compact summary avoids unreadable walls of text.
- Keep windows movable and preserve their positions.

## 10. Delivery order and acceptance checks

1. **Schema and migration:** introduce resources, five-option saved offers, ten allocations, and 50-point accounting. Translate old branch upgrades to explicit legacy power/tempo/efficiency modifiers so existing investment keeps its function. Offer a full refund; do not silently reroll established characters.
2. **Combat foundation:** centralized damage, defense, events and status handling. First vertical slice: weakening with armor/damage/speed variants, haste, recovery, duration and conditional damage. Verify modifier combinations before increasing pool size.
3. **Delivery and propagation:** implement the twelve approved types, including projectile-only skill #2 and channel movement/turn caps. Then add compatible chain, pierce, area-provider branches, echo, ailment, spread and consumption with event budgets and visual feedback.
4. **Defense and support:** block, evasion, healing, barriers, party recipients and removal reasons.
5. **Ten-skill loadout:** author learned abilities from approved types, add equip controls and bindings, and integrate each ability with the modifier pipeline.
6. **Editor and balance pass:** full resource editing, compatibility previews, runtime reload, profiling and build testing.

Required checks: five compatible unique choices; stable offers across reload/reset; exact point refunds; safe dependency-aware replacement; legacy-save migration; independent family/implementation/stat roll distributions; additive vs multiplicative math; real outgoing-damage reduction; real movement/attack/cast slow; armor and resistance actually affect damage; multi-hit recovery cap; immunity/boss resistance; no cyclic proc growth; overheal/barrier separation; death/expiry handling; multiplayer-ready source attribution; ten usable hotbar bindings; 16:9 fit; no first-cast loading hitch. Verify every family against all twelve base types and relevant augmented graphs. A pure projectile must receive no area bonus without a provider; an area bonus must change its named provider once and show the numerical change. Channel travel in equal time must be half equivalent non-channel travel; a 180-degree turn must take at least 0.5 seconds at the base cap, independent of frame rate, mouse sensitivity or camera rotation. Test channel cancellation, mana exhaustion and missed ray contacts. Launch and visually check the game after implementation changes.

## 11. Trigger grammar: depth through shared rules

Design extension, October 28: favor a small reusable event vocabulary and a small set of effect operations over a catalogue of unrelated special cases. Keep player choices as five complete, readable enchantments; the editor composes their permitted trigger/effect variants.

### Event names and precise semantics

| Player/editor trigger | Canonical event and filter | Meaning |
|---|---|---|
| `ON_BEGIN_CAST` | `CAST_BEGIN`, source skill = supported skill | A valid action is committed and its mana cost, or initial channel cost, is paid. Not input press, targeting preview or rejected cast |
| `ON_FINISH_CAST` | `CAST_FINISH`, successful release | Base payload has been emitted/applied. Does not wait for a projectile to arrive. Cancellation/interruption is not success |
| `ON_HIT_TAKEN` | `HIT_RECEIVED`, victim = owner | Successful incoming direct hit, after avoidance; may be fully absorbed. Not damage over time or self-paid health cost. Effects needing real damage use a positive-damage filter |
| `ON_ENEMY_HIT_THIS_SKILL` | `HIT_DEALT`, source skill = supported skill, target = enemy | The supported skill actually hits an enemy. A miss is not a hit; zero post-mitigation damage can still be a hit unless the definition requires damage. Secondary hits require explicit permission |
| `ON_ALLY_HIT` | Prefer `EFFECT_APPLIED_TO_ALLY`, source skill = supported skill | The supported skill successfully applies its intended friendly effect. Effective healing uses `HEAL_APPLIED` with restored health > 0. No invented hostile hit for a heal |
| `ON_BUFF_RECEIVED` | `STATUS_APPLIED`, recipient = owner, beneficial = true | A new qualifying buff is applied. Refreshing an existing buff is a separate event and does not repeatedly activate this trigger |
| `ON_THIS_BUFF_EXPIRED` | `STATUS_REMOVED`, instance = bound buff, reason = natural expiry | Exactly the buff created/bound by this enchantment expires. Consumption, refresh, replacement, dispel, death and reset do not qualify |
| `ON_DEATH` | `ACTOR_DIED`, actor = owner | Owner actually dies, once. Enemy death/kill is a distinct trigger. No automatic resurrection; ordinary self buffs cannot benefit a dead actor |
| `ON_PROJECTILE_LAUNCHED` | `PROJECTILE_SPAWNED`, source skill = supported skill | A real projectile is emitted, including an approved child projectile when permitted; frequency policy decides whether each projectile or each volley qualifies |
| `ON_PROJECTILE_LANDED` | `PROJECTILE_CONTACT`, source skill = supported skill | Contact with enemy or world geometry; variant must specify which. Timeout/range expiry is a different removal reason. Piercing contacts can occur more than once |
| `ON_PROJECTILE_DAMAGE_RECEIVED` | `DAMAGE_RECEIVED`, incoming delivery = projectile, damage > 0 | Owner loses health or an eligible barrier to projectile damage. Does not imply spell damage; weapon projectiles qualify too |
| `ON_MELEE_DAMAGE_RECEIVED` | `DAMAGE_RECEIVED`, incoming delivery = melee contact, damage > 0 | Owner takes direct contact damage. A melee-origin thrown weapon is projectile delivery, not contact; ray/area damage is not automatically melee |

Also retain the existing precise events for `ON_KILL`, `ON_CRITICAL_HIT`, `ON_BLOCK`, `ON_EFFECTIVE_HEAL` and `ON_SUCCESSFUL_EVADE`. These are filters over shared combat results rather than independent processing systems. Do not add a new event name for every stat or target variation.

If “ally hit” instead means an ally receives enemy damage, expose **`ON_PROTECTED_ALLY_HIT`**, scoped to an ally carrying a buff from this skill. This is a different event from applying a friendly effect and must have a different player label. Avoid global listeners to every party hit by default.

### Scope prevents passive overload

Every trigger has an explicit subscription scope:

- `THIS_CAST`: only the committed cast and its approved descendants.
- `THIS_SKILL`: casts of the supported skill, with optional approved secondary nodes.
- `WHILE_THIS_BUFF_ACTIVE`: owner/protected ally events only while a particular buff supplied by the skill exists.
- `WHILE_THIS_CHANNEL_ACTIVE`: incoming/contact events only during that skill's channel.
- `OWNER_PASSIVE`: always-on while equipped; explicit exceptional definition, not the default for every allocated enchantment.

Defensive triggers on an offensive projectile normally use a temporary buff granted by firing or hitting, or a clearly advertised short response window after casting. Allocating ten such enchants across ten skills must not silently grant 100 permanent listeners and defensive effects. Owner-death effects likewise require a named active buff or an explicitly balanced passive implementation.

### Shared enchantment record

```text
WHEN: enemy hit by this skill
SCOPE: this skill, direct hits only
FREQUENCY: once per enemy per cast
CONDITION: none
RECIPIENT: self
EFFECT: +4% increased damage dealt
DURATION: 4 seconds
STACKING: gain 1 stack; max 5; refreshing extends the common duration
BUFF SCOPE: this skill's future casts
TRADEOFF: +8% skill mana cost
```

This produces: **“Each different enemy hit grants 4% increased damage with this skill for 4 seconds, up to 5 stacks.”** A 5-target cone gives 5 stacks; one projectile hitting one enemy gives 1. The on-hit bonus occurs after damage resolution. It cannot retroactively improve the hit that earned it. By default damage snapshots at cast release, so even later projectiles from that already released cast use its snapshot; the buff improves future releases. A channel snapshots anew for each emission/pulse, letting later emissions benefit. All contacts in one emission resolve before its newly earned buffs affect the next emission, avoiding target-order advantages.

If the desired effect is broader, a separate weighted variant may say **“increased damage with all skills.”** It needs a smaller value or stronger tradeoff and shares a named buff-family cap across equipped skills. Scope never silently changes from skill-local to global.

### Four frequency policies, not dozens of bespoke triggers

1. **Once per cast/release:** rewards committing an action; five projectiles do not produce five independent resource refunds.
2. **Once per enemy per cast:** rewards coverage; chain, cone and area naturally interact with it.
3. **Every eligible hit, internal cooldown:** rewards repeated contact without unlimited attack-speed scaling. The definition states whether the cooldown is shared by owner, skill or target.
4. **Once per N eligible events:** rewards sustained use; a small capped counter feeds the same effect operations. Counter scope and reset are explicit.

Every-enemy-per-cast sets and counters have bounded lifetimes and storage. A channel is one begin event, but each paid emission/pulse defines a bounded frequency window, e.g. unique enemies over one second, with a configured per-second proc budget. It does not accumulate an unlimited target set for an indefinitely held channel. Extra projectiles do not restart the budget. Tooltip wording says “per second” when this normalization applies.

### Three depth levers worth prioritizing

**Build and spend:** a trigger adds stacks to a named self buff or enemy mark; a later explicit action consumes them. Example: each distinct enemy hit grants Momentum, and the next cast consumes up to 5 stacks for additional damage. The cast's consumption and benefit happen together before its payload snapshots, so a consume event is not needed to implement this. Newly earned stacks survive for the next cast. There is no buff-expired reward when stacks are consumed.

**Maintain or let expire:** a temporary buff has a useful active effect and a modest natural-expiry payoff. Refresh it to sustain the benefit or stop refreshing to receive the payoff. Example: gain armor for 3 seconds after finishing a cast; natural expiry restores a fixed amount of mana, capped below that cast's cost. Ticks, refreshes and dispels cannot farm the expiry payoff. Do not let the expiry payoff recreate its own parent buff.

**Set up and exploit:** one modifier applies a status and another checks that status. Example: projectile impact weakens enemy armor; a later hit against an already weakened target grants a short damage buff. Check conditions from the target's pre-hit status snapshot, not from statuses added later in the same hit. Add at most one condition to a normal enchantment initially; depth comes from interactions across allocations rather than long boolean expressions on one choice.

### Examples using the same operations across types

| Enchantment | Trigger and outcome | Interesting decision |
|---|---|---|
| Gathering Force | Begin a paid cast: consume stored Momentum for stronger next payload | Commit stacks now or retain them; cancelled casts lose consumed stacks by the declared cost policy |
| Follow Through | Finish casting: gain 6% movement speed for 2 seconds | Rewards successful release and repositioning; cannot activate by repeatedly cancelling |
| Crowd Momentum | Each unique enemy hit: gain 4% skill damage for 4 seconds, max 5 | Area builds ramp quickly; single-target builds maintain a smaller ramp |
| Focused Momentum | Repeated hits on the same enemy build the same buff, one stack per 0.5 seconds | Weighted single-target alternative to Crowd Momentum; comparable sustained benefit without free multi-projectile bursts |
| Patient Guard | While this skill's armor buff is active, an incoming melee hit refreshes part of its duration, up to a maximum lifetime | Rewards remaining under pressure without permanent duration extension |
| Ranged Reprieve | While the skill's ward is active, receiving projectile damage grants a short movement buff, with shared cooldown | Explicit defensive window; no passive effect when the ward is absent |
| Kindled Resolve | Effective healing of a different ally grants one stack of next-cast power, capped per cast | Friendly equivalent of coverage; overhealing and the same ally are not infinite sources |
| Afterglow | This skill's buff naturally expires: restore a small amount of mana | Duration scaling delays the payoff as well as extending the buff |
| Launch Rhythm | Every third paid projectile emission empowers the next emission | Works with channel projectiles; fork/chain children do not increment its paid-emission counter |
| Impact Shelter | Enemy projectile contact creates a short ward on the caster, at most once per cast | Requires actual enemy contact; firing into a wall does not qualify |
| Last Echo | Die while this skill's ward is active: give nearby allies a weaker remaining ward once | Party utility with no resurrection or recursive death explosion; requires explicit ally-area provider |

Values above are proposals. Default to guaranteed, clearly timed events; reserve random proc chance for effects whose timing is not central to controlling the build. Randomized offers already supply variety, so random stat + random trigger + random chance + random duration on every effect would obscure agency.

### Keep the editor and choice UI small

- Reuse six core operations first: modify stat, deal damage, heal/restore resource, grant barrier, add/consume stacks, spawn an approved effect node. A buff is a timed wrapper around those operations, not a new operation for each stat.
- A normal enchantment is either one trigger/effect, or a common authored reactive-buff bundle: an activation grants a timed buff, which listens to one event and emits its defined response. At most one additional condition and one tradeoff initially. Multiple numeric values are expected; arbitrary chains of nested trigger logic are not.
- Roll only authored valid combinations. Do not randomly combine death + self healing, friendly hit + enemy debuff or projectile landing + a nonexistent recipient.
- Show ordinary prose first, then frequency, stacking, scope and dependencies on hover. Example: “Hit different enemies to build up to 20% damage with this skill.” Detailed view names exact values and timing.
- Add template/variant validation for trigger availability, compatible recipient, status ownership, removal reason, event-budget inheritance and snapshot phase.
- `ON_BEGIN_CAST` cannot yield net resources through cancellation. Pay nonrefundable initial cost before begin-trigger rewards; resource-recovery variants normally use successful finish instead. Channel opening costs and paid emissions are separately accounted.
- Test blocked/absorbed hits, walls versus enemies, piercing contacts, simultaneous contacts, repeated buff refresh, channel start/stop spam, source death, natural expiry versus consumption, and cross-skill duplicate buff-family caps.

## 12. Common reactive-buff enchantments and affinity weights

User direction: compound enhancements such as “gain a 10-second buff; taking damage during it releases an area of damage” should be common choices, not restricted to rare keystones. Such effects carry several independently editable values. Later balancing should make appropriate enchantments occur more frequently on melee, cast and support skill/item contexts, without turning general availability into unnecessary hard restrictions.

### A concrete reusable template: Reactive Mantle

```text
Activation: successfully finish using the supported skill
Grants: Reactive Mantle to self
Buff duration: 10 seconds
While active: on receiving positive enemy hit damage to health/barrier
Response: damage enemies in a circular area centered on the buff holder
Burst damage: 25% of supported skill's reference power (initial proposal)
Burst radius: 2 metres (initial proposal)
Activation cooldown: 1 second, shared by this mantle's buff family on its holder
Burst limit per incoming hit: 1
Refresh: recasting refreshes duration; does not reset activation cooldown
Stacking: one mantle of this family per holder; stronger potency wins
Additional condition: none
Expiry: remove listener; no expiry burst unless an explicitly authored variant says so
```

Duration, damage coefficient, radius, proc interval, damage type, recipient, optional trigger chance and tradeoff are fields on one resolved enchantment instance. They are not separately purchased modifiers. Use a guaranteed reaction by default; do not make the event hard to read through unnecessary random proc chance.

This enchantment supplies two nodes: `mantle_buff(timed)` and `retaliation_burst(area_hit)`. A duration modifier can extend the mantle to 12 seconds; +25% area scales the 2 m burst radius to about 2.24 m; damage scaling can improve the burst where its scope permits. A proc-interval modifier changes the mantle response interval, not the parent ability's cast cooldown. Show all those bindings separately. None of them implicitly increases every other value on the enchantment.

Burst power uses an explicit base reference from the skill, snapshotted when the buff is granted, rather than the numeric result of a previous hit. A direct heal has healing reference power, not hidden attack damage; its damaging-mantle variant needs a separately authored conversion coefficient and smaller value, or a friendly response variant. Tooltip previews flat computed damage for the current character. Buff refresh updates the snapshot only under the documented refresh policy and never multiplies its old snapshot again.

Damage received includes barrier absorption when declared, but excludes self-paid health, damage over time and friendly/environmental damage by default. An incoming hit can satisfy both a general hit listener and this listener, but the same mantle does not react twice to that one hit. Reactive damage is marked secondary and cannot activate another reactive mantle, including another actor's, preventing reciprocal retaliation loops.

Server authority and future networking: subscriptions attach to the active buff instance, use its source skill/enchantment IDs for attribution, and are removed on expiry, dispel, owner death or respec. They are not permanent global listeners. Death ends this mantle and suppresses its ordinary retaliation; post-death responses require an explicit death-specific definition.

### Common compound variations from the same structure

| Template | Activation → temporary state → reaction | Values exposed |
|---|---|---|
| Reactive Mantle | Finish cast → self mantle → taking damage emits enemy area burst | Duration, burst power/radius, proc interval, damage type |
| Vengeful Focus | Finish cast → self focus → taking damage empowers next supported cast | Duration, granted damage bonus, charges, internal cooldown |
| Mending Ward | Effective heal → ally ward → protected ally takes damage and receives healing | Duration, heal power, proc interval, max activations; no automatic party-wide duplication |
| Shared Shelter | Apply ally buff → timed shelter → protected ally takes damage and grants a small nearby barrier | Duration, barrier strength/lifetime, radius, ally cap, proc interval |
| Pursuer's Mantle | Complete dash → self buff → next enemy hit emits a slowing pulse | Buff duration, slow strength/duration, radius; consumes buff without natural-expiry rewards |
| Channeling Aegis | Begin paid channel → channel-bound buff → incoming hit releases a bounded response | Lifetime follows channel with optional short grace duration, response power/radius, interval |

These are implementation variants built from the existing event, status, stat and effect-node systems. They do not introduce additional base skill types. They should appear often enough to define builds early. An initial tunable offer-mix target is at least one compatible compound option in about half of new five-choice sets when sufficient valid templates exist; the rest of the choices still include efficient direct modifiers. This is a proposal, not a rarity restriction or a guarantee for every offer.

### Affinity is a probability adjustment, not compatibility

Resolve eligibility first, then affinity, then implementation/stat/value selection. Keep four separate controls:

1. **Compatibility:** can this implementation work with the current skill/effect graph and recipients? Invalid implementations have zero eligibility regardless of weight.
2. **General family weight:** how often the enchantment family appears overall.
3. **Context affinity:** multipliers for melee/cast/channel/dash/support capabilities and, later, the relevant source item/weapon type. These contexts are data, not a class-name switch statement.
4. **Implementation weights:** given the family and eligible context, select the authored response variant. Its stats then roll from that variant's approved pool.

Example future tuning, only illustrative:

| Enchantment | Melee | Cast | Support | What this changes |
|---|---|---|---|---|
| Enemy-damaging Reactive Mantle | ×2.0 | ×1.0 | ×0.5 where authored | Offer likelihood, not burst damage |
| Vengeful Focus | ×1.0 | ×1.8 | ×0.8 where authored | Likelihood of the compatible focus variant |
| Mending Ward | ×0.7 where authored | ×1.0 where authored | ×2.0 | Friendly response appears more often on support |

These multipliers need not add to 100%; the eligible final weights normalize. A hybrid skill uses a single defined context profile or documented blend, not accidental multiplication of every overlapping tag. Item affinity is a further explicit profile with bounded weights, not an uncontrolled product of tags. Family selection is deduplicated so extra variants do not inflate family probability. The editor shows the final conditional probability for the selected skill, its current enchantments and source item.

Apply affinity changes to future offers. Existing saved offers and installed enchantments retain their chosen implementation/values, including after reset; tuning their generation weights must not reroll them. Numerical balance edits remain separately versioned. Keep affinities broadly neutral in the first implementation and tune by build/playtest data later, as requested.

## 13. Full distribution and power control in the editor

User requirement: expand the existing Modifier List Editor into a Skill & Modifier Distribution window, preserving its equipment-affix tools. The author must control skill availability weights, enchantment families, item/skill/event combinations, variant selection, activation probabilities, numerical power and chain behavior. This is required implementation scope, not a hardcoded future tuning task.

### Keep the different meanings of probability visible

| Control | Meaning | Example |
|---|---|---|
| Skill acquisition weight | Relative occurrence of a skill in a named reward/drop/learning pool | Projectile spell 30, cone spell 20; fixed starters are explicit fixed grants |
| Enchantment offer weight | Chance of a family being selected among eligible offers | Reactive Mantle weight 12 |
| Context affinity / override | Item type, skill delivery, role or exact-ID adjustment | Greatsword ×1.8 for retaliation; direct-heal context ×0.5 for damaging response |
| Event variant weight | Which compatible event an offered implementation binds to | Mantle reactions: damage received 60, block 25, successful evasion 15 |
| Implementation weight | Which authored response implementation is selected | Enemy burst 70, empowered next cast 30 |
| Stat/value distribution | Which legal stat and value/profile the offer rolls | Armor 40, outgoing damage 35, movement speed 25 |
| Runtime activation chance | Probability an installed enchantment activates on a qualifying event | 35% per eligible hit, after frequency checks |
| Runtime frequency controls | Internal cooldown, per-cast/target limits, charge cost and max active instances | At most one mantle burst per second |
| Power and dimensions | Flat value, percentage, coefficient, radius, duration, stacks, range, delay, cost | Burst at 25% reference power; 2 m radius; 10 s buff |

Events report facts: changing the chance of a hit-received enchantment does not alter how often enemies actually hit. If an event has no valid producer in the skill graph or active buff, the editor explains that incompatibility. Runtime proc chance and offer chance have separate labels and are never stored in the same field.

### Window layout

- **Skills:** searchable skill definitions and the twelve delivery types, base power/cost/timing, emitted events, source item compatibility, acquisition pools and ten-slot loadout preview. Fixed starter #2 remains projectile-only.
- **Enchantment families:** enable/disable, general weights, default/alternative implementations, display names, unique-family limits and authored offer constraints.
- **Item × Skill × Event matrix:** rows for item categories or exact items, columns for skill types or exact skills, and an event filter. Cells show inherited weight, effective override, eligibility and reason. Editing a cell opens its event/implementation distribution and power overrides.
- **Events & responses:** choose activation event, subscription scope, target filters, bound buff, reaction event, conditions, response operations and allowed secondary-trigger propagation. Reactive Mantle shows both activation and reaction clearly.
- **Values & power:** edit every numerical field, units, fixed or min/max rolls, profile weights, scaling reference, increased/reduced versus more/less operation, clamping, level scaling, target class/PvP overrides where authored, and snapshot policy.
- **Chain & delivery:** chain parameters below, plus interaction order with pierce/fork/return and whether an effect has native or added delivery.
- **Preview & simulation:** select concrete item, skill, installed enchantments, actor/target stats and a seed. Show the final distribution, five-offer examples, computed tooltips, effect dependencies and event traces.
- **Validation & versions:** errors, warnings, resource diffs, change history, rollback and compatibility migration preview before applying data.

Each field indicates its source and supports “reset to inherited.” Include search, duplicate template, bulk selection, copy/paste profiles, undo/redo and unsaved-change indicators. Saving writes versionable text resources. Preview, save and apply-to-running-game are distinct actions; an atomic versioned reload validates the whole catalog first. This editor is not exposed as a normal player's balancing menu.

### Distribution editing rules

Support two modes per selection pool: relative weights, or explicit percentages with optional locked entries. In percentage mode, editing an unlocked entry redistributes the remaining mass proportionally over other unlocked eligible entries. Locked totals cannot exceed 100%; impossible allocations produce an error instead of silently changing locks. Zero disables an entry. Empty eligible pools are validation errors or use an explicitly configured fallback pool.

Probabilities are conditional on context. An author locks 20% within the selected pool/context, not an impossible universal 20% across every skill and every filtered offer set. When eligibility changes, preview the effective distribution and show which configured targets cannot be met. Do not present raw family weight as the probability of appearing anywhere in a five-choice set: deduplication, weighted selection without replacement and offer guarantees change that probability. Show single-draw conditional chance separately from simulated five-choice inclusion rate, with sample count and uncertainty for estimates.

Rule precedence must be inspectable: base definition → selected item/skill context profile → explicit combination override. Event/implementation pools are selected inside that resolved context. Exact override replaces the inherited field; a multiplier only multiplies when explicitly labeled. Do not accidentally multiply all overlapping tags. Equal-priority matching overrides conflict and must be resolved. Display a small calculation trace, e.g. `family 10 × profile 1.5 = weight 15; compatible variant share 40%; runtime proc 100%`.

Every general balance cap is a named editor setting. Structural invariants—no invalid target references, non-finite numbers, unbounded recursive triggers or inconsistent IDs—remain enforced. A parameter requiring a new effect operation is shown as unsupported until that operation is implemented; “full control” over supported data must never imply arbitrary unavailable gameplay code.

Existing installations retain their stored roll and implementation identity. Weight edits affect future generation; numeric formula changes use explicit version/migration policies. The editor must show affected existing instances before applying a balance patch.

## 14. Chain support and chain events

Chain is a first-class delivery support, with explicit compatible variants. A projectile can jump to another enemy; an authored direct ally effect can relay to another ally; an area pulse can produce a separate secondary pulse if that variant exists. All variants use the same bounded traversal/targeting infrastructure but expose their own recipients, scaling and event permissions. A pure dash has no native chain and only receives an authored arrival-effect variant or remains incompatible.

### Editable chain fields

- Enabled, offer weight, allowed base/effective capabilities and item/skill affinity.
- Additional hop count, independently from projectile count. `3 chains` means up to three additional targets after the initial hit.
- Chain range in metres, measured from the previous contact/recipient to the next target's valid targeting point. This is separate from initial cast range and area radius.
- Hop power multiplier and model: initial-power-relative or compounded per hop. Example compounded 80% gives 100% → 80% → 64% → 51.2% across initial hit and three hops.
- Separate coefficients for damage, healing, barrier and status application where the implementation supports them; a damage coefficient must not silently scale slow strength too.
- Hop delay, projectile travel speed, lifetime/total chain duration and whether chaining uses moving projectiles or immediate authored relay effects.
- Target selection: nearest, lowest health, marked/unmarked preference or seeded random, with explicit deterministic tie-breaks. Recipient type, line of sight, alive/valid state and optional angle constraints.
- Revisit policy, default never revisit within one chain traversal. Cross-projectile per-cast hit limits are a separate policy and remain visible.
- Per-cast hop budget, shared trigger/recovery budgets, and whether descendants may apply specific on-hit effects.
- Interaction priority with pierce/fork/return; primary continuation conflicts are explicitly resolved in data. Chain cannot grant fresh chain budgets to its own descendants.
- Optional range/power/hop roll ranges or profiles, and explicit mana/cooldown tradeoffs.

### Event contract

- **`ON_CHAIN`**: an actual hop commits to a valid next recipient and emits its delivery. Fires once per committed hop, after successful target selection. Initial impact is hop 0 and does not count. No target means no chain event.
- **`ON_CHAIN_HIT`**: the committed hop successfully hits/applies its effect to the next recipient. Use this for rewards that require a successful arrival; a missed or invalidated projectile does not qualify.
- **`ON_CHAIN_END`**: the traversal ends once, carrying a reason such as hop limit, no target, obstruction, source removal or lifetime. Ordinary payoff definitions specify which end reasons qualify; shutdown/reset is not a combat payoff.

Payload includes source skill/enchantment/caster, original cast ID, chain ID, hop index, from/to targets, contact position, remaining hop budget, actual delivery result and termination reason where relevant. A chain is a sequence of deliveries; forks create sibling traversal IDs sharing the original cast budget. `ON_PROJECTILE_LAUNCHED`, `ON_ENEMY_HIT_THIS_SKILL` and chain events may describe the same hop, so an enchantment subscribing to alternatives uses event/cast/hop deduplication rather than receiving accidental duplicate activations.

### Example enchantment combinations

1. **Chain Support:** projectile chains to two additional enemies within 5 m; each hop retains 80% of the previous hop's damage.
2. **Gathering Arc:** `ON_CHAIN_HIT`, gain one stack of next-cast power, up to three stacks per cast. Benefit is for the next cast; it cannot retroactively strengthen the hop that earned it.
3. **Final Discharge:** last successful chain contact creates a small area burst once the traversal ends for hop limit or lack of a target. It uses the recorded last contact, not an unrelated current target. Burst cannot restart Chain Support.
4. **Restorative Relay:** supported direct heal jumps to two other injured allies; each subsequent heal has an explicit reduction. Its `ON_CHAIN_HIT` is a successful friendly-effect application, not hostile damage.
5. **Extended Reach:** increases chain acquisition range, with a tooltip showing `5.0 → 6.0 m`; it does not enlarge explosion radius or initial cast range.

The editor visualizes the chosen route and reports why traversal stopped. Validate hop counts, no-target termination, target death/despawn in flight, obstructions, simultaneous competing projectiles, repeated targets, friendly relays, event duplication, per-hop attenuation and deterministic overflow. Chaining can never exceed the configured cast/event budgets through another modifier's activation.

## Decisions still open

The confirmed ten active skills, ten upgrades per skill, twelve delivery types, projectile-only skill #2, and base channel movement/rotation restrictions are fixed scope. This plan recommends retaining 50 lifetime points, five rolled offers per stage, persistent offers and replacement out of combat. Exact fallback implementations, weights, balance values, new named abilities and unlocks remain tunable proposals. These are design changes, not gameplay changes already made.
