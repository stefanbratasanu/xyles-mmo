extends RefCounted
## One source of truth for race/gender art. Never label a human fallback as a race.
const MANIFEST := "res://resources/characters/race_models.json"
static var _entries: Array = []

static func entry(race: String, gender: String) -> Dictionary:
	if _entries.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST))
		if parsed is Dictionary: _entries = parsed.get("models", [])
	for model: Dictionary in _entries:
		if model.race == race and model.gender == gender: return model.duplicate()
	return {}

static func is_ready(race: String, gender: String) -> bool:
	var model := entry(race, gender)
	return model.get("status", "") == "reviewed" and ResourceLoader.exists(str(model.get("scene", "")), "PackedScene")

static func scene(race: String, gender: String) -> PackedScene:
	if not is_ready(race, gender): return null
	return load(str(entry(race, gender).scene)) as PackedScene

static func concept(race: String, gender: String) -> Texture2D:
	var path := str(entry(race, gender).get("concept", ""))
	return load(path) as Texture2D if ResourceLoader.exists(path, "Texture2D") else null
