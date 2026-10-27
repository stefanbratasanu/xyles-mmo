@tool
extends Resource
class_name ModifierCatalog

@export var general_modifiers: ModifierPool
@export var item_specific_modifiers: ModifierPool
## The current focus item uses this staff enchantment pool. A separate pool
## keeps staff-only enchantments from being mixed into other equipment rolls.
@export var staff_enchantments: ModifierPool
## Legendary starts at five modifiers, matching the documented 5+ minimum.
@export var rarity_modifier_counts: Dictionary = {
	"basic": 2,
	"rare": 3,
	"epic": 4,
	"legendary": 5,
}


func has_rarity(tier: String) -> bool:
	return rarity_modifier_counts.has(tier)


func get_modifier_count(tier: String) -> int:
	return maxi(0, int(rarity_modifier_counts.get(tier, 0)))


func get_modifier(modifier_id_or_name: String) -> ItemModifierDefinition:
	for pool: ModifierPool in [general_modifiers, item_specific_modifiers, staff_enchantments]:
		if pool == null:
			continue
		for entry in pool.entries:
			if entry == null or entry.modifier == null:
				continue
			if String(entry.modifier.id) == modifier_id_or_name or entry.modifier.display_name == modifier_id_or_name:
				return entry.modifier
	return null


func get_modifier_display_text(modifier_id_or_name: String) -> String:
	var modifier := get_modifier(modifier_id_or_name)
	return modifier.display_name if modifier != null else modifier_id_or_name


func get_normalized_distribution(pool_id: String, excluded_ids: Array[String] = []) -> Array[Dictionary]:
	var pool := get_pool(pool_id)
	return pool.get_normalized_distribution(excluded_ids) if pool != null else []


func get_pool(pool_id: String) -> ModifierPool:
	match pool_id:
		"general":
			return general_modifiers
		"item_specific":
			return item_specific_modifiers
		"staff_enchantments":
			return staff_enchantments
	return null


func roll_modifiers(tier: String, item_slot: String, rng: RandomNumberGenerator) -> Array[String]:
	var result: Array[String] = []
	var modifier_count := get_modifier_count(tier)
	if modifier_count <= 0 or rng == null:
		return result
	var selected_specific_pool := staff_enchantments if item_slot in ["staff", "focus"] else item_specific_modifiers
	for _index in range(maxi(0, modifier_count - 1)):
		if general_modifiers == null:
			break
		var general_modifier := general_modifiers.pick_modifier(rng, result)
		if general_modifier == null:
			break
		result.append(String(general_modifier.id))
	if selected_specific_pool != null:
		var specific_modifier := selected_specific_pool.pick_modifier(rng, result)
		if specific_modifier != null:
			result.append(String(specific_modifier.id))
	return result
