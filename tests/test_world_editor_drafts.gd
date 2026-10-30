extends SceneTree

const Store := preload("res://scripts/world_editor/draft_store.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var path := "user://world_editor_test_%d" % Time.get_ticks_usec()
	var store = Store.new(path)
	var first: String = store.new_draft_id()
	var second: String = store.new_draft_id()
	assert(first != second)
	assert(store.save_draft("../escape", "Bad", "map_i", {}) == ERR_INVALID_PARAMETER)
	assert(store.save_draft(first, " ", "map_i", {}) == ERR_INVALID_PARAMETER)
	assert(store.save_draft(first, "Forest", "map_i", {"revision": 1}) == OK)
	assert(store.load_draft(first)["payload"]["revision"] == 1)
	assert(store.publish_draft(first) == OK)
	assert(store.save_draft(first, "Forest", "map_i", {"revision": 2}) == OK)
	assert(store.load_draft(first)["payload"]["revision"] == 2)
	assert(store.load_published()["payload"]["revision"] == 1)
	assert(store.publish_draft(first) == OK)
	assert(store.load_published()["payload"]["revision"] == 2)
	assert(store.save_draft(second, "Beach", "map_i", {}) == OK)
	var entries: Array[Dictionary] = store.list_drafts()
	assert(entries.size() == 2)
	assert(entries[0]["id"] == second)
	# A broken current file falls back to the last successfully saved version.
	var current := path.path_join("drafts").path_join(first + ".json")
	var file := FileAccess.open(current, FileAccess.WRITE)
	file.store_string("{")
	file.close()
	assert(store.load_draft(first)["payload"]["revision"] == 1)
	assert(store.save_draft(first, "Forest", "map_i", {"revision": 3}) == ERR_FILE_CORRUPT)
	assert(store.load_draft(first)["payload"]["revision"] == 1)
	for id: String in [first, second]:
		for suffix: String in [".json", ".json.bak", ".json.tmp"]:
			var item := ProjectSettings.globalize_path(path.path_join("drafts").path_join(id + suffix))
			if FileAccess.file_exists(item):
				DirAccess.remove_absolute(item)
	for suffix: String in ["", ".bak", ".tmp"]:
		var item := ProjectSettings.globalize_path(path.path_join("active_map.json" + suffix))
		if FileAccess.file_exists(item):
			DirAccess.remove_absolute(item)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path.path_join("drafts")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("PASS: map draft persistence, isolation, validation, and backup")
	quit()
