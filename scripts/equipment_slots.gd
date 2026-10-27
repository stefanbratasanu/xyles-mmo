extends RefCounted
## Shared equipment schema for inventory layout, validation and starter items.
const CAPACITY := 250
const SLOTS := [
	["hair_left", "Hair accessory I", "hair", "Ashen Feather", 0, 0],
	["head", "Helmet", "helmet", "Iron Sallet", 1, 0],
	["hair_right", "Hair accessory II", "hair", "Silver Hairpin", 2, 0],
	["gloves", "Gloves", "gloves", "Wayfarer's Gauntlets", 0, 1],
	["armor", "Chest armor", "chest", "Wayfarer's Cuirass", 1, 1],
	["boots", "Boots", "boots", "Wayfarer's Boots", 2, 1],
	["cloak", "Cloak", "cloak", "Emberfall Mantle", 0, 2],
	["legs", "Leg armor", "legs", "Wayfarer's Leggings", 1, 2],
	["belt", "Belt", "belt", "Ironclasp Belt", 2, 2],
	["weapon", "Main-hand weapon", "sword", "Worn Ironblade", 0, 3],
	["offhand", "Shield / focus", "shield", "Emberfall Buckler", 1, 3],
	["shirt", "Shirt", "shirt", "Linen Undershirt", 2, 3],
	["dye_1", "Dye / tattoo I", "dye", "Dye of Strength", 0, 4],
	["dye_2", "Dye / tattoo II", "dye", "Dye of Dexterity", 1, 4],
	["dye_3", "Dye / tattoo III", "dye", "Dye of Wisdom", 2, 4],
	["earring_left", "Left earring", "earring", "Amber Earring", 0, 5],
	["necklace", "Necklace", "necklace", "Ember Pendant", 1, 5],
	["earring_right", "Right earring", "earring", "Moonstone Earring", 2, 5],
	["bracelet", "Talisman bracelet", "bracelet", "Bronze Talisman Bracelet", 0, 6],
	["ring_left", "Left ring", "ring", "Iron Signet", 1, 6],
	["ring_right", "Right ring", "ring", "Silver Band", 2, 6],
]

static func canonical(slot: String) -> String:
	return {"focus": "offhand", "relic": "ring_left", "staff": "weapon"}.get(slot, slot)

static func definition(slot: String) -> Array:
	for entry: Array in SLOTS:
		if entry[0] == canonical(slot):
			return entry
	return []

static func label(slot: String) -> String:
	var entry := definition(slot)
	return str(entry[1]) if not entry.is_empty() else slot.capitalize()
