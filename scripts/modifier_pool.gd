@tool
extends Resource
class_name ModifierPool

@export var pool_id: StringName = &""
@export var display_name: String = ""
@export var entries: Array[WeightedModifierEntry] = []


func get_normalized_distribution(excluded_ids: Array[String] = []) -> Array[Dictionary]:
	var valid_entries: Array[WeightedModifierEntry] = []
	var total_weight := 0.0
	for entry in entries:
		if entry == null or entry.modifier == null:
			continue
		if entry.weight <= 0.0 or not is_finite(entry.weight):
			continue
		if excluded_ids.has(String(entry.modifier.id)):
			continue
		valid_entries.append(entry)
		total_weight += entry.weight
	var distribution: Array[Dictionary] = []
	if total_weight <= 0.0 or not is_finite(total_weight):
		return distribution
	for entry in valid_entries:
		distribution.append({
			"id": String(entry.modifier.id),
			"name": entry.modifier.display_name,
			"weight": entry.weight,
			"chance_percent": entry.weight / total_weight * 100.0,
		})
	return distribution


func pick_modifier(rng: RandomNumberGenerator, excluded_ids: Array[String] = []) -> ItemModifierDefinition:
	var distribution := get_normalized_distribution(excluded_ids)
	if distribution.is_empty():
		return null
	var total_weight := 0.0
	for option: Dictionary in distribution:
		total_weight += float(option["weight"])
	var roll := rng.randf() * total_weight
	var cumulative := 0.0
	for option: Dictionary in distribution:
		cumulative += float(option["weight"])
		if roll < cumulative:
			return _find_modifier(str(option["id"]))
	return _find_modifier(str(distribution.back()["id"]))


func _find_modifier(modifier_id: String) -> ItemModifierDefinition:
	for entry in entries:
		if entry != null and entry.modifier != null and String(entry.modifier.id) == modifier_id:
			return entry.modifier
	return null
