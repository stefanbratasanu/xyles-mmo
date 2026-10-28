# Skill enchantment design review

October 28, 2026. Recommendations for discussion; these do not supersede confirmed requirements or change gameplay. The companion plan now also specifies full distribution-editor control and first-class Chain support in sections 13–14.

The existing plan has a sound foundation: twelve delivery types, capability-based implementations, common reactive buffs, named event scopes, editable affinities and a small shared effect vocabulary. The priority now should be stronger choices and fewer exceptions, rather than additional modifier families.

## 1. Protect the identity of the skill

Risk: broad fallbacks let every projectile become an explosion, healing field and retaliation aura. Distinct starting abilities converge on the same build, while stronger compound enchantments dominate plain modifiers.

Recommendation: separate internally the roles of modifiers into behavior creators, amplifiers and conditional payoffs. Keep the roles informational initially, not compulsory slot colors or new currencies. Ensure all three have competitive uses. A damage/range/efficiency option should sometimes be the right choice for a reliable single-target skill.

Give each base skill a small identity statement: what its native delivery does well, what its risk is, and what modifications may change it. Secondary effects add options without erasing the original delivery for free. Do not hard-cap all interesting compound buffs as rare transformations; they remain common as requested.

## 2. Make five-choice offers fair without removing discovery

Risk: five permanently fixed choices can become five useless choices after changing providers, or permanently deny an interesting family. Repeated compatible low-value rolls can still feel bad even when the math is valid. Fully unrestricted rerolls would create a different problem.

Recommendation for the first version:

- Every set has at least one broadly useful compatible choice whose validity does not depend on another installed modifier.
- Prefer distinct play patterns, not five near-identical numbers. When available, include a reliable amplifier, a behavior/compound choice and an option that builds on an existing synergy. Fill remaining choices from the weighted pool. These are soft offer goals rather than hard class restrictions.
- Choose a general build preference such as damage, control or sustain to modestly bias future offers, with a wildcard chance preserved. Affinity and preference affect availability, never potency. Changing preference must not reroll already created offers.
- Retain old rolls, explicitly mark incompatibilities, and test reset/rebuild sequences for dead ends. If retained offers still make rebuilding frustrating, adopt an account/character discovery library later rather than an unlimited reroll button.

Do not add the preference layer before observing actual offer quality. The immediate must-have is an always-usable option and no duplicate-function offers.

## 3. Roll coherent packages, not every number independently

Risk: a 10-second reactive buff has duration, damage, radius and interval. Independent rolls permit simultaneous best duration, strongest damage, largest coverage and fastest activation. Four random dimensions also make upgrades difficult to compare.

Recommendation: author two or three coherent profiles for a compound template, e.g. wide/weak, concentrated/strong or sustained/slower. Randomize one primary value and at most one secondary value in the initial version. All fields remain editable in the resource editor; fewer fields need to be random in player-facing rolls.

Use an internal balance budget to compare maximum activations, expected uptime, secondary damage/healing and coverage. A useful first estimate is `expected activations × effect power`, evaluated separately for one target and packs. This is a balancing heuristic, not an exact formula for utility or PvP power. No new player currency or complexity meter is needed.

## 4. Reward using skills, not maintaining ten buff timers

Risk: ten skills with finish-cast mantles incentivize casting every button before combat and refreshing buffs on cooldown. Repeated family restrictions alone do not remove the “buff piano” pattern.

Recommendation:

- Most offensive reactive buffs activate when the supported skill achieves something: hits an enemy, completes a meaningful channel interval, blocks or restores real health. Friendly preparation buffs may still activate on cast when preparation is their intended role.
- Own repeated applications refresh a buff or add defined charges; they do not multiply independent copies.
- Cross-skill copies of the same family share a cap/response interval; ten copies are not ten separate free detonations.
- Re-equipping does not clear cooldowns, restore charges or create a fresh ready state. Effect lifetime after source removal follows an explicit policy.
- Keep some longer buffs and let new successful uses maintain them naturally. Do not require every play style to refresh a three-second buff manually.

Show shared-family conflicts before the player installs a duplicate. Different reaction families can still coexist where intended.

## 5. Normalize trigger effectiveness without making speed upgrades pointless

Risk: +1 projectile or faster channel emissions multiplies damage, weakening stacks, leech and healing simultaneously. A simple hard internal cooldown can make further attack/cast speed feel wasted.

Recommendation: attach a proc-effectiveness value to each source/delivery node. Secondary hits have explicitly reduced ability to generate stacks/recovery when needed. Keep proc chance, proc effectiveness and internal cooldown distinct. Explain effectiveness in advanced tooltips.

Use per-cast or per-interval budgets mainly for scarce resources, defensive recovery and reactive responses. Let normal on-hit statuses retain satisfying coverage where safe. Primary skill damage can continue scaling with attack/emission rate even when a resource proc reaches its disclosed cap. Test single target, packs, bosses and multiple party casters separately.

Do not use one universal cooldown that shuts off every interesting interaction when any proc activates.

## 6. Give retaliation choices beyond deliberately taking damage

Risk: on-damage effects reward standing in hazards, farming weak enemies or accepting hits instead of dodging. They can also feel useless on bosses whose attacks must be avoided.

Recommendation: retain damaging-hit retaliation as a valid tank identity, but author compatible alternatives using the same response operation: successful block, successful evasion, or a protected ally being hit. Offer these as explicit variants, not an invisible trigger substitution. Avoid rewarding self damage or environmental ticking hazards by default.

Reactive Mantle example profiles:

- **Retaliatory:** taking enemy hit damage releases a bounded burst.
- **Guarded:** successful block releases a smaller burst and preserves the original defensive benefit.
- **Elusive:** a successfully evaded hit primes the next supported hit to release the burst.

These use existing events and do not introduce a new defensive resource. Getting hurt should never be universally superior to avoiding the same attack.

## 7. Bound propagation while retaining visible synergy

Risk: the current blanket two-generation limit is safe but can silently cut off legitimate combinations. A recursive event budget without deterministic overflow handling can also make identical fights resolve differently.

Recommendation: distinguish **effect delivery descendants** from **new triggered activations**. A projectile creating an explosion and a timed field is one authored compound package, with explicit child nodes. The explosion does not automatically inherit every on-hit trigger. One approved secondary activation can use an allowed trigger mask; a family cannot reactivate itself along the same chain.

Bound event count and target count, specify stable processing order, and make overflow behavior deterministic. Validation rejects content whose normal use exceeds the budget; overflow is an exceptional guard, not an ordinary invisible balance mechanism. Advanced tooltips show whether a burst can apply on-hit statuses, leech or kill effects. “It hits” and “it triggers every on-hit enchantment” are separate facts.

## 8. Make reactive-buff ownership unambiguous

Risk: several players can apply different versions of a ward. “Strongest wins” is ambiguous if one version has higher damage but another has larger radius, longer duration or shorter interval. If wards trigger wards, support and retaliation can loop indirectly.

Recommendation:

- Define an explicit family competition rule, such as authored potency score plus deterministic tie-break, rather than guessing from multiple fields.
- Keep a compound buff's payload atomic; do not cherry-pick the best value from each player's version.
- Preserve both caster and holder IDs: an ally can hold the ward while the healer owns its stats, costs and combat attribution.
- Document whether damage bonuses belong to the caster or holder, whose enemies are targeted, and whether recipient movement changes burst position.
- Reactive healing/barriers are not fresh successful casts and do not automatically grant new wards. Nested responses obey provenance permissions just like reactive damage.

## 9. Remove hidden geometry and snapshot surprises

Risk: +25% area produces only about +12% radius, which can appear broken without a preview. Generic projectile sequencing is also undefined when chain, pierce, fork and return coexist. Buffs that snapshot at release may seem ineffective during already-running channels or fields.

Recommendation:

- Keep mathematically correct area scaling, but show before/after metres and an in-world outline. Widening a cone and extending its reach are named choices.
- Define contact processing explicitly: resolve eligible impact once, then the ordered traversal policy. Choose one primary continuation behavior initially when combined continuation is too difficult to explain. Return remains a separate phase with its own hit ledger. The UI explains conflicts before installation.
- A cast snapshots caster damage at release; a paid channel emission snapshots on emission. Timed buff grant snapshots its payload. Defense/recipient state resolves at the declared event time. Use the same policy for every corresponding template.
- Show when a newly gained buff benefits the next cast/emission rather than the hit that generated it.

## 10. Build evaluation and combat feedback are part of the system

Recommendation: add a simple local practice target and an editor preview rather than more rules. Preview reports affected nodes, expected costs, current limits and one concrete synergy. Practice targets expose actual proc counts, uptime, damage/healing by effect and reasons for suppression. Offer resettable single-target and small-pack scenarios.

In normal combat, show buff duration/charges, a brief readiness pulse for a reaction, and distinguishable effect colors/shapes. Cull visual noise separately from damage simulation. Allies should be able to read a ward without every trigger filling the screen.

Provide build presets for experimentation using the same learned options and 50-point limit. Applying a preset validates dependencies and happens out of combat. This avoids repeated manual allocation without adding power.

## 11. Resolve two specification gaps before implementation

**Offer and content versions:** retain chosen rolled values and implementation IDs; version formulas separately. For balance patches, migrate or refund removed/invalid definitions explicitly. Hot reload uses one atomic catalog version, with no half-old dependency graph. Preview unsupported/missing references before committing data.

**Scope:** the earlier catalogue includes reservation, conversion, hard control, charges, multiple continuation types and owner-death effects. These are a backlog, not all necessary for the first release. Start with direct modifiers, one secondary area provider, weakening, common reactive wards, duration/area amplification and build/spend stacks. Prove those across the approved deliveries before expanding special mechanics. Broad compatibility need not mean shipping every family immediately.

## Recommended next design decisions

1. Adopt coherent multi-value profiles and keep common compound enchantments competitive with direct upgrades.
2. Commit to meaningful activation and shared buff-family limits to avoid ten-button prebuff routines.
3. Specify trigger effectiveness, secondary-event permissions and source ownership before combat implementation.
4. Require useful five-choice offers, dependency-aware rebuilding and exact effect previews.
5. Prototype one projectile build and one support/retaliation build with measurable combat results. Tune from those before increasing the catalogue.

Example prototype: Ember Bolt → enemy-hit armor weakening or elemental vulnerability → a common 10-second mantle → taking a qualified hit releases a bounded burst → area/duration amplification → next-cast stack payoff. Compare it with a simple high-impact projectile build and a healer's protected-ally ward build. Each should have encounters where it is useful, without identical rotations or mandatory shared components.
