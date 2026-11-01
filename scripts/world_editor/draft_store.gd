extends RefCounted
## Stores map drafts separately from the active game map. Draft payloads are
## dictionaries so the authoring tools can evolve without writing game assets.

const VERSION := 1
const DEFAULT_DIR := "user://world_editor"
var directory: String

func _init(path: String = DEFAULT_DIR) -> void:
	directory = path.trim_suffix("/")

func new_draft_id() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

func _valid_id(id: String) -> bool:
	if id.length() != 32:
		return false
	for character in id:
		if not character in "0123456789abcdef":
			return false
	return true

func _draft_path(id: String) -> String:
	return directory.path_join("drafts").path_join(id + ".json")

func _ensure_directory(path: String) -> Error:
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))

## Writes through a temporary file and keeps a copy of the last good version.
## Callers receive an error instead of treating a failed write as a saved draft.
func _write_json(path: String, value: Dictionary) -> Error:
	var error := _ensure_directory(path.get_base_dir())
	if error != OK:
		return error
	var absolute := ProjectSettings.globalize_path(path)
	var temporary := absolute + ".tmp"
	var backup := absolute + ".bak"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(value, "\t", true))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK:
		DirAccess.remove_absolute(temporary)
		return error
	if FileAccess.file_exists(absolute):
		if FileAccess.file_exists(backup):
			error = DirAccess.remove_absolute(backup)
			if error != OK:
				DirAccess.remove_absolute(temporary)
				return error
		error = DirAccess.rename_absolute(absolute, backup)
		if error != OK:
			DirAccess.remove_absolute(temporary)
			return error
	error = DirAccess.rename_absolute(temporary, absolute)
	if error != OK:
		if FileAccess.file_exists(backup) and not FileAccess.file_exists(absolute):
			DirAccess.rename_absolute(backup, absolute)
		return error
	return OK

func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return {}
	return parser.data

func save_draft(id: String, name: String, map_id: String, payload: Dictionary) -> Error:
	if not _valid_id(id) or name.strip_edges().is_empty() or map_id.strip_edges().is_empty():
		return ERR_INVALID_PARAMETER
	var previous := load_draft(id)
	# Preserve a recoverable backup when the primary file was damaged. Rotating
	# the damaged file over that backup would otherwise lose the last good copy.
	if FileAccess.file_exists(_draft_path(id)) and not _valid_draft(_read_json(_draft_path(id)), id):
		return ERR_FILE_CORRUPT
	var now := Time.get_datetime_string_from_system(true)
	var draft := {
		"version": VERSION,
		"id": id,
		"name": name.strip_edges(),
		"map_id": map_id,
		"created_at": previous.get("created_at", now),
		"updated_at": now,
		"payload": payload,
	}
	return _write_json(_draft_path(id), draft)

func load_draft(id: String) -> Dictionary:
	if not _valid_id(id):
		return {}
	var data := _read_json(_draft_path(id))
	if not _valid_draft(data, id):
		data = _read_json(_draft_path(id) + ".bak")
	if not _valid_draft(data, id):
		return {}
	return data

func _valid_draft(data: Dictionary, id: String) -> bool:
	return int(data.get("version", 0)) == VERSION and str(data.get("id", "")) == id and data.get("payload") is Dictionary

## Publish a copy, rather than a pointer to an editable draft. Later saves to
## the draft therefore cannot silently alter the currently selected map.
## The caller must validate gameplay readiness before calling this method.
func publish_draft(id: String) -> Error:
	var draft := load_draft(id)
	if draft.is_empty():
		return ERR_FILE_NOT_FOUND
	var path := directory.path_join("active_map.json")
	if FileAccess.file_exists(path):
		var previous := _read_json(path)
		var previous_id := str(previous.get("id", ""))
		if not _valid_id(previous_id) or not _valid_draft(previous, previous_id):
			return ERR_FILE_CORRUPT
	return _write_json(path, draft)

func load_published() -> Dictionary:
	var path := directory.path_join("active_map.json")
	var data := _read_json(path)
	var id := str(data.get("id", ""))
	if not _valid_id(id) or not _valid_draft(data, id):
		data = _read_json(path + ".bak")
		id = str(data.get("id", ""))
	if not _valid_id(id) or not _valid_draft(data, id):
		return {}
	return data

func publish_original() -> Error:
	var original := {"version": VERSION, "id": "00000000000000000000000000000000", "name": "Original Ashen Frontier", "map_id": "map_i", "payload": {"format": 1, "original": true, "placements": []}}
	return _write_json(directory.path_join("active_map.json"), original)

func list_drafts() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var seen: Dictionary = {}
	var folder := DirAccess.open(directory.path_join("drafts"))
	if folder == null:
		return result
	folder.list_dir_begin()
	var entry := folder.get_next()
	while not entry.is_empty():
		if not folder.current_is_dir() and (entry.ends_with(".json") or entry.ends_with(".json.bak")):
			var id := entry.trim_suffix(".bak").trim_suffix(".json")
			if not seen.has(id):
				seen[id] = true
				var data := load_draft(id)
				if not data.is_empty():
					result.append(data)
		entry = folder.get_next()
	folder.list_dir_end()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("name", "")).naturalnocasecmp_to(str(b.get("name", ""))) < 0)
	return result
