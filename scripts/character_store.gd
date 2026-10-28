extends RefCounted
## Character files are independent; the pre-existing journey stays in place.
const State = preload("res://scripts/game_state.gd")
var directory: String
var legacy_path: String
var last_character_path: String

func _init(save_directory: String = "res://saves/characters", old_path: String = "res://saves/journey.json") -> void:
	directory = save_directory
	legacy_path = old_path
	last_character_path = directory.get_base_dir().path_join("last_character.cfg")

func auto_login_path() -> String:
	var entries := list_characters()
	if FileAccess.file_exists(last_character_path):
		var config := ConfigFile.new()
		if config.load(last_character_path) != OK: return ""
		var saved_path := str(config.get_value("character", "last_path", ""))
		for entry: Dictionary in entries:
			if entry.valid and entry.path == saved_path: return saved_path
		return ""
	# Before this feature existed, a single save is the only possible last character.
	if entries.size() == 1 and entries[0].valid: return str(entries[0].path)
	return ""

func remember_character(path: String) -> bool:
	var found := false
	for entry: Dictionary in list_characters():
		if entry.valid and entry.path == path: found = true
	if not found: return false
	var config := ConfigFile.new()
	config.set_value("character", "last_path", path)
	var temporary := last_character_path + "." + Crypto.new().generate_random_bytes(12).hex_encode() + ".tmp"
	if config.save(temporary) != OK: return false
	var temp_absolute := ProjectSettings.globalize_path(temporary)
	if DirAccess.rename_absolute(temp_absolute, ProjectSettings.globalize_path(last_character_path)) != OK:
		DirAccess.remove_absolute(temp_absolute)
		return false
	return true

func list_characters() -> Array[Dictionary]:
	var paths: Array[String] = []
	if FileAccess.file_exists(legacy_path): paths.append(legacy_path)
	var dir := DirAccess.open(directory)
	if dir != null:
		var files := dir.get_files()
		files.sort()
		for file: String in files:
			if file.ends_with(".json"): paths.append(directory.path_join(file))
	var results: Array[Dictionary] = []
	for path: String in paths:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary or int(parsed.get("version", 0)) != 1:
			results.append({"path": path, "valid": false, "name": "Unreadable save"})
			continue
		results.append({"path": path, "valid": true, "name": str(parsed.get("character_name", "Wayfarer")), "race": str(parsed.get("character_race", "Human")), "class": str(parsed.get("character_class", "Fighter")), "level": maxi(1, int(parsed.get("level", 1))), "legacy": path == legacy_path})
	return results

func create_character(character_name: String, race: String, character_class: String) -> Dictionary:
	var clean_name := character_name.strip_edges()
	if clean_name.is_empty() or clean_name.length() > 24 or clean_name.contains("\n") or clean_name.contains("\r"):
		return {"error": "Enter a name between 1 and 24 characters."}
	if race not in State.CHARACTER_RACES or character_class not in State.CHARACTER_CLASSES:
		return {"error": "Choose a valid race and class."}
	for entry: Dictionary in list_characters():
		if entry.get("valid", false) and str(entry.name).to_lower() == clean_name.to_lower():
			return {"error": "A character with that name already exists."}
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)) != OK:
		return {"error": "Could not create the character save folder."}
	var path := ""
	for attempt in range(10):
		var candidate := directory.path_join("character_" + Crypto.new().generate_random_bytes(12).hex_encode() + ".json")
		if not FileAccess.file_exists(candidate):
			path = candidate
			break
	if path.is_empty(): return {"error": "Could not allocate a new character save."}
	var state := State.new()
	state.character_name = clean_name
	state.character_race = race
	state.character_class = character_class
	var saved := state.save_game(path)
	state.free()
	if not saved: return {"error": "Could not save the new character."}
	return {"path": path}
