extends Node
class_name XylesGameState

## Local prototype state. Leveling grants stats; only regional bestiary discoveries
## award skill points. Rules are kept outside combat and presentation code.
signal changed
signal notice(message: String)

const MAX_LIFETIME_SKILL_POINTS := 50
const MAX_SKILL_EVOLUTIONS := 10
const CATEGORY_POINTS := {"normal": 2, "quest": 5, "boss": 3}
const MODIFIER_CATALOG_PATH := "res://resources/modifiers/modifier_catalog.tres"
const CRAFT_MULTIPLIERS := {"basic": 1.0, "rare": 1.5, "epic": 2.2, "legendary": 3.2}
const SAVE_PATH := "user://xyles_frontier_save.json"
const CHARACTER_RACES := ["Human", "Orc", "Elf", "Dark Elf", "Dwarf"]
const CHARACTER_CLASSES := ["Fighter", "Mystic"]
const EquipmentSlots = preload("res://scripts/equipment_slots.gd")
const WEAPON_DEFINITIONS := {
	"sword": {"name":"Ashforged Sword","base_power":15,"icon":"sword","modifier_slot":"weapon"},
	"greatsword": {"name":"Ashforged Greatsword","base_power":18,"icon":"sword","modifier_slot":"weapon"},
	"spear": {"name":"Ashforged Spear","base_power":16,"icon":"spear","modifier_slot":"weapon"},
	"staff": {"name":"Ashforged Staff","base_power":13,"icon":"sword","modifier_slot":"staff"},
}
var equipment_schema_version: int = 2

var skill_catalog = preload("res://resources/skills/skill_catalog.tres")
var skill_offers: Dictionary = {}
var skill_seed: int = 0
var loadout: Array = []
var learned_skills: Array = []
var compiled_skills: Dictionary = {}
var modifier_catalog: ModifierCatalog = preload("res://resources/modifiers/modifier_catalog.tres")
var character_name: String = "Wayfarer"
var character_race: String = "Human"
var character_class: String = "Fighter"

var hp: float = 120.0
var max_hp: float = 120.0
var mana: float = 100.0
var max_mana: float = 100.0
var gold: int = 180
var wood: int = 120
var iron: int = 120
var level: int = 1
var xp: int = 0
var skill_points: int = 0
var earned_skill_points: int = 0
var current_region: String = "ashen_reach"
var world_session: Dictionary = {}
var skills: Dictionary = {}
var bestiary: Dictionary = {}
var equipment: Array[Dictionary] = []
var inventory: Array[Dictionary] = []
var quests: Array[Dictionary] = []
var logs: Array[String] = []
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.randomize()
	skill_seed = rng.randi()
	changed.connect(func(): compiled_skills.clear())
	_define_skills()
	_define_quests()
	equipment = [
		_make_item("Worn Ironblade", "basic", "weapon", 12, 88.0),
		_make_item("Wayfarer's Cuirass", "basic", "armor", 10, 92.0),
		_make_item("Ashen Focus", "rare", "offhand", 9, 76.0),
	]
	_add_equipment_examples()
	_add_spear_example()
	logs.append("You have reached the Ashen Reach. Speak with the blacksmith [E].")


func _define_skills() -> void:
	skills.clear()
	for id: String in skill_catalog.data.skills:
		var definition: Dictionary = skill_catalog.data.skills[id]
		skills[id] = {"name": definition.name, "description": str(definition.type).replace("_", " ").capitalize(), "ranks": [0, 0, 0], "investments": 0, "history": [], "evolutions": []}
	loadout = skill_catalog.data.default_loadout.duplicate()
	learned_skills = loadout.duplicate()
	compiled_skills.clear()


func _skill(title: String, description: String, branches: Array, branch_descriptions: Array) -> Dictionary:
	return {"name": title, "description": description, "branches": branches,
		"branch_descriptions": branch_descriptions, "ranks": [0, 0, 0], "investments": 0, "history": []}


func _define_quests() -> void:
	# Tasks and stage rewards are separate records, suitable for moving to a DB.
	quests = [{
		"id": "a_debt_of_iron", "title": "A Debt of Iron", "stage": 0,
		"active": false, "completed": false,
		"stages": [
			{"id": "meet_smith", "title": "Speak with the blacksmith", "tasks": [
				{"kind": "interact", "target": "blacksmith", "required": 1, "count": 0}], "next": 1},
			{"id": "clear_road", "title": "Defeat wolves or boars", "tasks": [
				{"kind": "kill", "target": "normal", "required": 3, "count": 0}], "next": 2},
			{"id": "break_ward", "title": "Defeat the Oathbound Guardian", "tasks": [
				{"kind": "kill", "target": "quest", "required": 1, "count": 0}], "next": 3},
			{"id": "ancient_threat", "title": "Confront the Hollow Regent", "tasks": [
				{"kind": "kill", "target": "boss", "required": 1, "count": 0}], "next": 4},
			{"id": "complete", "title": "The Reach remembers", "tasks": [], "next": -1},
		],
		"rewards": {
			"clear_road": {"gold": 45, "wood": 30, "iron": 30,
				"clue": "The Oathbound Guardian watches the broken arch north of camp."},
			"break_ward": {"gold": 80, "wood": 50, "iron": 50,
				"clue": "Beyond the northern ruins, the Hollow Regent waits in the ancient circle."},
			"ancient_threat": {"gold": 180, "wood": 100, "iron": 100,
				"clue": "The Hollow Regent has fallen. His relic is yours. The Reach is safe, for now."},
		}
	}]


func start_quest() -> void:
	var quest: Dictionary = quests[0]
	if bool(quest["completed"]):
		_notify("Blacksmith: The Reach owes you a debt. Keep your equipment repaired.")
		return
	if bool(quest["active"]):
		_notify("Blacksmith: " + get_quest_text())
		return
	quest["active"] = true
	quest["stages"][0]["tasks"][0]["count"] = 1
	quest["stage"] = 1
	_notify("Quest accepted · A Debt of Iron. Defeat 3 wolves or boars on the old road.")
	changed.emit()


func register_kill(kind: String, monster_name: String) -> void:
	if not CATEGORY_POINTS.has(kind):
		return
	var key := current_region + ":" + kind
	var entry: Dictionary = bestiary.get(key, {
		"region": current_region, "category": kind, "kills": 0,
		"name": monster_name, "discovered": false, "points_awarded": 0,
	})
	entry["kills"] = int(entry["kills"]) + 1
	if not bool(entry["discovered"]):
		entry["discovered"] = true
		discover_skill()
		var award := mini(int(CATEGORY_POINTS[kind]), MAX_LIFETIME_SKILL_POINTS - earned_skill_points)
		award = maxi(award, 0)
		entry["points_awarded"] = award
		earned_skill_points += award
		skill_points += award
		_notify("Bestiary discovery · %s  +%d skill points" % [monster_name, award])
	bestiary[key] = entry
	var reward_xp := 25 if kind == "normal" else (100 if kind == "quest" else 350)
	var reward_gold := 9 if kind == "normal" else (35 if kind == "quest" else 120)
	xp += reward_xp
	gold += reward_gold
	wood += 4 if kind == "normal" else 15
	iron += 5 if kind == "normal" else 15
	while xp >= level * 100:
		xp -= level * 100
		level += 1
		max_hp += 8.0
		max_mana += 4.0
		hp = minf(hp + 25.0, max_hp)
		_notify("Level %d · Vitality increased. Active slot milestone: level 5." % level)
	if kind == "boss":
		var relic := _make_item("Crownfall Greatblade", "legendary", "weapon", 32, 100.0)
		inventory.append(relic)
		_notify("World boss spoils · Legendary Crownfall Greatblade added to your inventory.")
	elif kind == "quest":
		inventory.append(_make_item("Oathkeeper's Signet", "rare", "relic", 17, 100.0))
	_progress_quest("kill", kind)
	changed.emit()


func _progress_quest(task_kind: String, target: String) -> void:
	for quest in quests:
		if not bool(quest["active"]) or bool(quest["completed"]):
			continue
		var stage: Dictionary = quest["stages"][int(quest["stage"])]
		var all_complete := true
		for task: Dictionary in stage["tasks"]:
			if task["kind"] == task_kind and task["target"] == target:
				task["count"] = mini(int(task["count"]) + 1, int(task["required"]))
			if int(task["count"]) < int(task["required"]):
				all_complete = false
		if not all_complete or stage["tasks"].is_empty():
			continue
		var reward: Dictionary = quest["rewards"].get(stage["id"], {})
		gold += int(reward.get("gold", 0))
		wood += int(reward.get("wood", 0))
		iron += int(reward.get("iron", 0))
		quest["stage"] = int(stage["next"])
		if reward.has("clue"):
			_notify("Quest advanced · " + str(reward["clue"]))
		if int(quest["stage"]) == 4:
			quest["completed"] = true


func get_quest_text() -> String:
	var quest: Dictionary = quests[0]
	if not bool(quest["active"]):
		return "Speak with the blacksmith in Emberfall camp [E]."
	if bool(quest["completed"]):
		return "A Debt of Iron complete · The Hollow Regent has fallen."
	var stage: Dictionary = quest["stages"][int(quest["stage"])]
	var task: Dictionary = stage["tasks"][0]
	var direction := " · Old road east of camp" if int(quest["stage"]) == 1 else (
		" · Broken arch, north of camp" if int(quest["stage"]) == 2 else " · Ancient circle, far north")
	return "%s  %d / %d%s" % [stage["title"], task["count"], task["required"], direction]


func get_skill_offers(id: String, stage: int) -> Array:
	if not skills.has(id) or stage < 0 or stage >= 10: return []
	var key := "%s:%d" % [id, stage]
	if not skill_offers.has(key):
		var equipped: Array = skills[id].evolutions.duplicate(true)
		if stage < equipped.size(): equipped.remove_at(stage)
		skill_offers[key] = skill_catalog.offers(id, equipped, hash(str(skill_seed) + key), weapon_context())
	return skill_offers[key]

func weapon_context() -> String:
	for item: Dictionary in equipment:
		if item.slot == "weapon":
			return item_weapon_type(item)
	return "unarmed"

func item_weapon_type(item: Dictionary) -> String:
	var explicit := str(item.get("weapon_type",""))
	if WEAPON_DEFINITIONS.has(explicit): return explicit
	var title := str(item.get("name","")).to_lower()
	if "spear" in title or "polearm" in title or "pike" in title: return "spear"
	if "greatblade" in title or "greatsword" in title: return "greatsword"
	if "staff" in title: return "staff"
	return "sword"

func can_install(id: String, stage: int, candidate: Dictionary) -> bool:
	if not skills.has(id) or stage < 0 or stage > skills[id].evolutions.size() or stage >= 10: return false
	var entries: Array = skills[id].evolutions.duplicate(true)
	if stage < entries.size(): entries[stage] = candidate
	else:
		if skill_points <= 0: return false
		entries.append(candidate)
	var families: Array = []
	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		if entry.op != "legacy" and families.has(entry.family): return false
		families.append(entry.family)
		var others := entries.duplicate()
		others.remove_at(i)
		if not skill_catalog.compatible(id, entry, others): return false
	# Resolve providers from the base skill outward; mutually dependent nodes cannot bootstrap each other.
	var resolved: Array=[]
	var pending: Array=entries.duplicate()
	while not pending.is_empty():
		var progress := false
		for i in range(pending.size()-1,-1,-1):
			if skill_catalog.compatible(id,pending[i],resolved):
				resolved.append(pending.pop_at(i)); progress=true
		if not progress: return false
	return true

func install_evolution(id: String, stage: int, choice: int) -> bool:
	var options := get_skill_offers(id, stage)
	if choice < 0 or choice >= options.size(): return false
	var candidate: Dictionary = options[choice]
	if not can_install(id, stage, candidate):
		_notify("Incompatible choice: check points, duplicate families and dependent effects.")
		return false
	if stage == skills[id].evolutions.size():
		skills[id].evolutions.append(candidate.duplicate(true))
		skill_points -= 1
	else: skills[id].evolutions[stage] = candidate.duplicate(true)
	skills[id].history = skills[id].evolutions.duplicate(true)
	skills[id].investments = skills[id].evolutions.size()
	changed.emit()
	_notify("%s: %s installed." % [skills[id].name, candidate.name])
	return true

func reset_evolutions() -> int:
	var refunded := 0
	for skill: Dictionary in skills.values():
		refunded += skill.evolutions.size()
		skill.evolutions = []
		skill.history = []
		skill.ranks = [0, 0, 0]
		skill.investments = 0
	skill_points = mini(earned_skill_points, skill_points + refunded)
	changed.emit()
	_notify("Evolutions reset: %d points refunded. Discovered offers retained." % refunded)
	return refunded

func compiled_skill(id: String) -> Dictionary:
	if not compiled_skills.has(id): compiled_skills[id] = skill_catalog.compile(id, skills[id].evolutions)
	return compiled_skills[id]

func get_skill_effects(id: String) -> Dictionary:
	var compiled := compiled_skill(id)
	return {"power": compiled.power_scale, "cooldown": compiled.cooldown_scale, "mana_cost": compiled.cost_scale, "range": 1.0}

func get_skill_bonus(id: String) -> float:
	return float(get_skill_effects(id).power)

func get_unlocked_active_slots() -> int:
	return 10

func equip_skill(id: String, slot: int) -> bool:
	if not learned_skills.has(id) or slot < 0 or slot >= 10: return false
	var other := loadout.find(id)
	if other >= 0: loadout[other] = loadout[slot]
	loadout[slot] = id
	changed.emit()
	return true

func discover_skill() -> String:
	var weights: Dictionary = {}
	for id: String in skill_catalog.data.skills:
		if not learned_skills.has(id) and skill_catalog.data.skills[id].get("enabled",true): weights[id] = skill_catalog.data.skills[id].acquisition_weight
	var id: String = skill_catalog.weighted(weights, rng)
	if not id.is_empty():
		learned_skills.append(id)
		_notify("Learned skill: " + str(skills[id].name))
	return id

func reload_skill_catalog() -> bool:
	var candidate = ResourceLoader.load("res://resources/skills/skill_catalog.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if candidate == null or not candidate.validate().is_empty(): return false
	# Existing skill IDs are stable save identities.
	for id: String in skills:
		if not candidate.data.skills.has(id): return false
	skill_catalog = candidate
	for id: String in candidate.data.skills:
		var definition: Dictionary=candidate.data.skills[id]
		if not skills.has(id): skills[id]={"name":definition.name,"description":str(definition.type).replace("_"," "),"ranks":[0,0,0],"investments":0,"history":[],"evolutions":[]}
		else: skills[id].name=definition.name
	changed.emit()
	return true

func _restore_evolutions(parsed: Dictionary) -> void:
	skill_offers = {}
	if parsed.get("skill_offers") is Dictionary:
		for key: String in parsed.skill_offers:
			var options: Variant=parsed.skill_offers[key]
			if not options is Array or options.size()>5: continue
			var valid := true
			for m: Variant in options:
				if not skill_catalog.valid_roll(m): valid=false; break
			if valid: skill_offers[key]=options
	skill_seed = int(parsed.get("skill_seed", skill_seed))
	var saved: Dictionary = parsed.get("evolutions", {}) if parsed.get("evolutions", {}) is Dictionary else {}
	var spent := 0
	for id: String in skills:
		var entries: Array = []
		if saved.has(id) and saved[id] is Array:
			for m: Variant in saved[id]:
				if skill_catalog.valid_roll(m) and entries.size() < 10 and spent < earned_skill_points:
					entries.append(m)
					spent += 1
		else:
			for branch: Variant in skills[id].history:
				if not (branch is int or branch is float) or spent >= earned_skill_points: continue
				entries.append({"id": "legacy", "family": "legacy", "name": "Legacy evolution", "op": "legacy", "event": "PASSIVE", "values": {"power": .16 if int(branch) == 0 else .04, "cost": .09 if int(branch) == 2 else 0, "cooldown": .07 if int(branch) == 1 else 0, "range": .06 if int(branch) == 1 else 0}})
				spent += 1
		skills[id].evolutions = entries
		skills[id].history = entries.duplicate(true)
		skills[id].investments = entries.size()
	skill_points = earned_skill_points - spent
	if parsed.get("learned_skills") is Array:
		for id: Variant in parsed.learned_skills:
			if skills.has(str(id)) and not learned_skills.has(str(id)): learned_skills.append(str(id))
	if parsed.get("loadout") is Array and parsed.loadout.size() == 10:
		var seen: Array = []
		for id: Variant in parsed.loadout:
			if not learned_skills.has(str(id)) or seen.has(str(id)): break
			seen.append(str(id))
		if seen.size() == 10: loadout = seen
	compiled_skills.clear()


func get_craft_cost(tier: String = "basic") -> Dictionary:
	if not CRAFT_MULTIPLIERS.has(tier):
		return {}
	var amount := int(round(100.0 * float(CRAFT_MULTIPLIERS[tier])))
	return {"wood": amount, "iron": amount}


func craft_sword(tier: String = "basic") -> bool:
	return craft_weapon("sword",tier)

func craft_spear(tier: String = "basic") -> bool:
	return craft_weapon("spear",tier)

func craft_weapon(kind: String, tier: String = "basic") -> bool:
	if not WEAPON_DEFINITIONS.has(kind): return false
	if inventory.size() >= EquipmentSlots.CAPACITY:
		_notify("Your inventory is full.")
		return false
	var cost := get_craft_cost(tier)
	if cost.is_empty():
		return false
	if wood < int(cost["wood"]) or iron < int(cost["iron"]):
		_notify("Insufficient materials · Requires %d wood and %d iron." % [cost["wood"], cost["iron"]])
		return false
	wood -= int(cost["wood"])
	iron -= int(cost["iron"])
	var tier_index := ["basic", "rare", "epic", "legendary"].find(tier)
	var definition: Dictionary=WEAPON_DEFINITIONS[kind]
	var item := _make_item(definition.name, tier, "weapon", int(definition.base_power) + tier_index * 6, 100.0,kind)
	inventory.append(item)
	_notify("Crafted · %s %s with %d modifiers. Equip it from your inventory." % [tier.capitalize(), definition.name,modifier_catalog.get_modifier_count(tier)])
	changed.emit()
	return true


func _make_item(title: String, tier: String, slot: String, power: int, durability: float, weapon_type: String = "") -> Dictionary:
	var modifier_slot := slot
	slot = EquipmentSlots.canonical(slot)
	if slot=="weapon":
		if weapon_type.is_empty(): weapon_type=item_weapon_type({"name":title})
		modifier_slot=str(WEAPON_DEFINITIONS[weapon_type].modifier_slot)
	var modifiers: Array[String] = modifier_catalog.roll_modifiers(tier, "focus" if slot == "offhand" else modifier_slot, rng)
	var result := {"id": "%s_%d_%d" % [slot, Time.get_ticks_usec(), rng.randi()],
		"name": title, "tier": tier, "slot": slot, "power": power,
		"durability": durability, "max_durability": 100.0,
		"modifiers": modifiers, "exposed": durability < 50.0}
	if slot=="weapon":
		result.weapon_type=weapon_type
		result.icon=WEAPON_DEFINITIONS[weapon_type].icon
	return result


func get_modifier_display_text(modifier_id_or_name: String) -> String:
	return modifier_catalog.get_modifier_display_text(modifier_id_or_name)


func reload_modifier_catalog() -> bool:
	var loaded: Resource = ResourceLoader.load(MODIFIER_CATALOG_PATH, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP)
	if not loaded is ModifierCatalog:
		push_warning("Modifier catalog could not be reloaded from %s." % MODIFIER_CATALOG_PATH)
		return false
	modifier_catalog = loaded as ModifierCatalog
	changed.emit()
	_notify("Modifier data reloaded.")
	return true


func equip_item(index: int) -> bool:
	if index < 0 or index >= inventory.size():
		return false
	var item: Dictionary = inventory[index]
	inventory.remove_at(index)
	for equipped_index in range(equipment.size()):
		if equipment[equipped_index]["slot"] == item["slot"]:
			inventory.append(equipment[equipped_index])
			equipment.remove_at(equipped_index)
			break
	equipment.append(item)
	_notify("Equipped · " + str(item["name"]))
	changed.emit()
	return true


func unequip_slot(slot: String) -> bool:
	if inventory.size() >= EquipmentSlots.CAPACITY:
		_notify("Your inventory is full.")
		return false
	for index in range(equipment.size()):
		if equipment[index]["slot"] == slot:
			var item: Dictionary = equipment.pop_at(index)
			inventory.append(item)
			_notify("Unequipped · " + str(item["name"]))
			changed.emit()
			return true
	return false


func _add_equipment_examples() -> void:
	# One-time migration gives existing characters access to the expanded slots.
	for entry: Array in EquipmentSlots.SLOTS:
		var occupied := false
		for item: Dictionary in equipment + inventory:
			if str(item["slot"]) == entry[0]:
				occupied = true
				break
		if not occupied:
			inventory.append(_make_item(str(entry[3]), "basic", str(entry[0]), 2, 100))
	# The existing Ashen Focus shares the shield slot; supply a shield alternative.
	var has_buckler := false
	for item: Dictionary in equipment + inventory:
		if str(item.get("name", "")) == "Emberfall Buckler":
			has_buckler = true
	if not has_buckler:
		inventory.append(_make_item("Emberfall Buckler", "basic", "offhand", 2, 100))
	equipment_schema_version = 1

func _add_spear_example() -> void:
	# One-time, versioned migration: lost/dropped spears are not regenerated on later loads.
	var owns_spear := false
	for item: Dictionary in equipment+inventory:
		if item.get("slot","")=="weapon" and item_weapon_type(item)=="spear":
			owns_spear=true
			break
	if not owns_spear:
		inventory.append(_make_item("Emberfall Infantry Spear","basic","weapon",14,100.0,"spear"))
	equipment_schema_version=2


func get_equipment_power() -> float:
	var power := 0.0
	for item in equipment:
		power += float(item["power"]) * (0.25 if float(item["durability"]) <= 0.0 else 1.0)
	return power


func get_equipment_modifiers() -> Dictionary:
	# Flat vitality/mana values supplement base maxima; all combat fields are
	# multipliers, except armor which is an additive mitigation fraction.
	var result := {"max_hp": 0.0, "max_mana": 0.0, "attack_multiplier": 1.0,
		"armor": 0.0, "mana_regen": 1.0, "melee_multiplier": 1.0,
		"cast_multiplier": 1.0, "support_multiplier": 1.0, "block_strength": 1.0}
	for item in equipment:
		if float(item.get("durability", 0.0)) <= 0.0:
			continue
		for modifier_ref: String in item.get("modifiers", []):
			var definition := modifier_catalog.get_modifier(modifier_ref)
			if definition == null or not result.has(String(definition.stat_key)):
				continue
			var stat_key := String(definition.stat_key)
			result[stat_key] = float(result[stat_key]) + definition.amount
	result["armor"] = minf(float(result["armor"]), 0.6)
	return result


func get_repair_cost() -> int:
	var cost := 0.0
	for item in equipment:
		cost += (100.0 - float(item["durability"])) * (0.06 + float(item["power"]) * 0.004)
	return int(ceil(cost))


func repair_all() -> bool:
	var cost := get_repair_cost()
	if cost <= 0:
		_notify("Your equipment is already fully repaired.")
		return false
	if gold < cost:
		_notify("Repair requires %d gold. You carry %d." % [cost, gold])
		return false
	gold -= cost
	for item in equipment:
		item["durability"] = 100.0
		item["exposed"] = false
	_notify("Equipment repaired · %d gold. All equipped items restored to 100%%." % cost)
	changed.emit()
	return true


func get_exposure_chance(item: Dictionary) -> float:
	var durability := float(item.get("durability", 100.0))
	if durability <= 0.0:
		return 1.0
	if durability >= 50.0:
		return 0.0
	return clampf(0.05 + (50.0 - durability) * 0.005, 0.05, 0.3)


func apply_death() -> Dictionary:
	var damaged: Array[Dictionary] = []
	var dropped: Array[Dictionary] = []
	var guaranteed_target := rng.randi_range(0, maxi(equipment.size() - 1, 0))
	for index in range(equipment.size()):
		var item: Dictionary = equipment[index]
		if index == guaranteed_target or rng.randf() < 0.65:
			var loss := rng.randf_range(7.0, 15.0) * (1.0 + float(item["power"]) / 45.0)
			item["durability"] = maxf(0.0, float(item["durability"]) - loss)
			item["exposed"] = float(item["durability"]) < 50.0
			damaged.append({"name": item["name"], "loss": loss, "durability": item["durability"]})
		if rng.randf() < get_exposure_chance(item):
			dropped.append(item.duplicate(true))
	for item in dropped:
		for index in range(equipment.size() - 1, -1, -1):
			if equipment[index]["id"] == item["id"]:
				equipment.remove_at(index)
	_notify("You have fallen · %d items damaged. %d items dropped." % [damaged.size(), dropped.size()])
	changed.emit()
	return {"damaged": damaged, "dropped": dropped}


func spend_mana(amount: float) -> bool:
	if amount < 0.0 or mana < amount:
		return false
	mana = maxf(0.0, mana - amount)
	changed.emit()
	return true


func restore() -> void:
	hp = max_hp
	mana = max_mana
	changed.emit()


func _notify(message: String) -> void:
	logs.append(message)
	while logs.size() > 40:
		logs.pop_front()
	notice.emit(message)


func save_game(path: String = SAVE_PATH) -> bool:
	# Write beside the destination, then replace it only after a successful
	# flush. A failed save must not truncate the character's previous progress.
	var temporary := path + "." + Crypto.new().generate_random_bytes(12).hex_encode() + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return false
	var ranks := {}
	var histories := {}
	for id: String in skills:
		ranks[id] = skills[id]["ranks"]
		histories[id] = skills[id]["history"]
	file.store_string(JSON.stringify({"version": 1, "character_name": character_name, "character_race": character_race, "character_class": character_class, "level": level, "xp": xp,
		"gold": gold, "wood": wood, "iron": iron, "hp": hp, "max_hp": max_hp,
		"mana": mana, "max_mana": max_mana, "skill_points": skill_points,
		"earned_skill_points": earned_skill_points, "skill_ranks": ranks, "skill_histories": histories,
		"bestiary": bestiary, "equipment": equipment, "inventory": inventory,
		"evolutions": _evolution_save(), "skill_offers": skill_offers, "skill_seed": skill_seed, "loadout": loadout, "learned_skills": learned_skills,
		"equipment_schema_version": equipment_schema_version,
		"quests": quests, "current_region": current_region, "world_session": world_session}, "", true, true))
	file.flush()
	var write_ok := file.get_error() == OK
	file.close()
	var temp_absolute := ProjectSettings.globalize_path(temporary)
	if not write_ok:
		DirAccess.remove_absolute(temp_absolute)
		return false
	if DirAccess.rename_absolute(temp_absolute, ProjectSettings.globalize_path(path)) != OK:
		DirAccess.remove_absolute(temp_absolute)
		return false
	return true


func load_game(path: String = SAVE_PATH) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or int(parsed.get("version", 0)) != 1:
		return false
	for field in ["skill_ranks", "bestiary"]:
		if parsed.has(field) and not parsed[field] is Dictionary:
			return false
	for field in ["equipment", "inventory", "quests"]:
		if parsed.has(field) and not parsed[field] is Array:
			return false
	_define_skills()
	_define_quests()
	character_name = str(parsed.get("character_name", "Wayfarer")).strip_edges().left(24)
	if character_name.is_empty(): character_name = "Wayfarer"
	character_race = str(parsed.get("character_race", "Human"))
	if character_race not in CHARACTER_RACES: character_race = "Human"
	character_class = str(parsed.get("character_class", "Fighter"))
	if character_class not in CHARACTER_CLASSES: character_class = "Fighter"
	level = maxi(1, int(parsed.get("level", 1)))
	xp = maxi(0, int(parsed.get("xp", 0)))
	gold = maxi(0, int(parsed.get("gold", 180)))
	wood = maxi(0, int(parsed.get("wood", 120)))
	iron = maxi(0, int(parsed.get("iron", 120)))
	max_hp = maxf(120.0, float(parsed.get("max_hp", 120.0)))
	max_mana = maxf(100.0, float(parsed.get("max_mana", 100.0)))
	hp = clampf(float(parsed.get("hp", max_hp)), 1.0, max_hp)
	mana = clampf(float(parsed.get("mana", max_mana)), 0.0, max_mana)
	earned_skill_points = clampi(int(parsed.get("earned_skill_points", 0)), 0, MAX_LIFETIME_SKILL_POINTS)
	var spent := 0
	var saved_ranks: Dictionary = parsed.get("skill_ranks", {})
	for id: String in skills:
		if not saved_ranks.get(id, [0, 0, 0]) is Array:
			continue
		var ranks: Array = saved_ranks.get(id, [0, 0, 0]).duplicate()
		if ranks.size() != 3:
			continue
		var total := 0
		for index in range(3):
			ranks[index] = clampi(int(ranks[index]), 0, 5)
			total += int(ranks[index])
		if total > MAX_SKILL_EVOLUTIONS or spent + total > earned_skill_points or int(ranks.max()) > int(ranks.min()) + 2:
			continue
		skills[id]["ranks"] = ranks
		skills[id]["investments"] = total
		# Older saves contained ranks only. Reconstruct a stable history once;
		# new saves preserve the player's actual selection order.
		var history: Array = []
		var saved_histories: Variant = parsed.get("skill_histories", {})
		if saved_histories is Dictionary and saved_histories.get(id, []) is Array:
			var candidate_history: Array = saved_histories.get(id, [])
			var counts := [0, 0, 0]
			for value: Variant in candidate_history:
				if (value is int or value is float) and int(value) >= 0 and int(value) < 3:
					history.append(int(value))
					counts[int(value)] += 1
			if history.size() != total or counts != ranks:
				history.clear()
		if history.is_empty() and total > 0:
			var remaining: Array = ranks.duplicate()
			while history.size() < total:
				for branch in range(3):
					if int(remaining[branch]) > 0:
						history.append(branch)
						remaining[branch] -= 1
		skills[id]["history"] = history
		spent += total
	skill_points = earned_skill_points - spent
	bestiary.clear()
	var saved_bestiary: Dictionary = parsed.get("bestiary", {})
	for key: String in saved_bestiary:
		var entry: Variant = saved_bestiary[key]
		if not entry is Dictionary or not CATEGORY_POINTS.has(str(entry.get("category", ""))):
			continue
		bestiary[key] = {"region": str(entry.get("region", "ashen_reach")),
			"category": str(entry["category"]), "kills": maxi(0, int(entry.get("kills", 0))),
			"name": str(entry.get("name", "Unknown creature")), "discovered": bool(entry.get("discovered", false)),
			"points_awarded": clampi(int(entry.get("points_awarded", 0)), 0, int(CATEGORY_POINTS[entry["category"]]))}
	equipment.clear()
	var occupied_slots: Array[String] = []
	for item: Variant in parsed.get("equipment", []):
		var valid_item := _validated_saved_item(item)
		if not valid_item.is_empty() and not occupied_slots.has(str(valid_item["slot"])):
			equipment.append(valid_item)
			occupied_slots.append(str(valid_item["slot"]))
	inventory.clear()
	for item: Variant in parsed.get("inventory", []):
		var valid_item := _validated_saved_item(item)
		if not valid_item.is_empty():
			inventory.append(valid_item)
	var saved_quests: Array = parsed.get("quests", [])
	for saved_quest: Variant in saved_quests:
		if not saved_quest is Dictionary or str(saved_quest.get("id", "")) != str(quests[0]["id"]):
			continue
		var quest: Dictionary = quests[0]
		quest["stage"] = clampi(int(saved_quest.get("stage", 0)), 0, 4)
		quest["active"] = bool(saved_quest.get("active", false))
		quest["completed"] = bool(quest["active"]) and int(quest["stage"]) == 4
		if not bool(quest["active"]):
			quest["stage"] = 0
		var saved_stages: Variant = saved_quest.get("stages", [])
		if not saved_stages is Array:
			continue
		for stage_index in range(mini(saved_stages.size(), quest["stages"].size())):
			if not saved_stages[stage_index] is Dictionary:
				continue
			var saved_tasks: Variant = saved_stages[stage_index].get("tasks", [])
			if not saved_tasks is Array:
				continue
			var tasks: Array = quest["stages"][stage_index]["tasks"]
			for task_index in range(mini(tasks.size(), saved_tasks.size())):
				if saved_tasks[task_index] is Dictionary:
					tasks[task_index]["count"] = clampi(int(saved_tasks[task_index].get("count", 0)), 0, int(tasks[task_index]["required"]))
	current_region = str(parsed.get("current_region", "ashen_reach"))
	world_session = parsed.get("world_session", {}).duplicate(true) if parsed.get("world_session", {}) is Dictionary else {}
	equipment_schema_version = int(parsed.get("equipment_schema_version", 0))
	if equipment_schema_version < 1:
		_add_equipment_examples()
	if equipment_schema_version < 2:
		_add_spear_example()
	_restore_evolutions(parsed)
	_notify("Journey restored · Welcome back to the Ashen Reach.")
	changed.emit()
	return true


func _validated_saved_item(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var tier := str(value.get("tier", ""))
	var slot: String = EquipmentSlots.canonical(str(value.get("slot", "")))
	if not modifier_catalog.has_rarity(tier) or EquipmentSlots.definition(slot).is_empty():
		return {}
	var saved_modifiers: Variant = value.get("modifiers", [])
	if not saved_modifiers is Array:
		return {}
	var modifiers: Array[String] = []
	for modifier: Variant in saved_modifiers:
		if modifier is String and modifiers.size() < modifier_catalog.get_modifier_count(tier):
			var definition := modifier_catalog.get_modifier(modifier)
			modifiers.append(String(definition.id) if definition != null else modifier)
	var durability := clampf(float(value.get("durability", 100.0)), 0.0, 100.0)
	var result := {"id": str(value.get("id", "%s_%d" % [slot, rng.randi()])),
		"name": str(value.get("name", "Recovered equipment")), "tier": tier, "slot": slot,
		"power": clampi(int(value.get("power", 1)), 1, 100),
		"durability": durability, "max_durability": 100.0,
		"modifiers": modifiers, "exposed": durability < 50.0}
	if slot=="weapon":
		result.weapon_type=item_weapon_type(value)
		result.icon=WEAPON_DEFINITIONS[result.weapon_type].icon
		if result.weapon_type == "sword" and str(value.get("visual_id", "")) == "ornate_silver_sword":
			result.visual_id = "ornate_silver_sword"
	return result


func _evolution_save() -> Dictionary:
	var result: Dictionary = {}
	for id: String in skills: result[id] = skills[id].evolutions
	return result
