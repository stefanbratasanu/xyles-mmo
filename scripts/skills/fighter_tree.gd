extends RefCounted
## Authored Fighter milestones.
const SKILLS := [
	{"id":"fighter_cleave", "name":"Cleave", "level":1, "delivery":"melee_area"},
	{"id":"fighter_bow", "name":"Bow Attack", "level":1, "delivery":"bow_projectile"},
	{"id":"fighter_guard", "name":"Guard", "level":2, "delivery":"guard"},
	{"id":"fighter_dash", "name":"Dash", "level":3, "delivery":"dash"},
	{"id":"fighter_cone", "name":"Cone Attack", "level":4, "delivery":"melee_cone"}
]

static func available(level: int) -> Array:
	var result: Array = []
	for skill: Dictionary in SKILLS:
		if level >= int(skill.level): result.append(skill.id)
	return result

static func definition(id: String) -> Dictionary:
	for skill: Dictionary in SKILLS:
		if skill.id == id: return skill
	return {}
