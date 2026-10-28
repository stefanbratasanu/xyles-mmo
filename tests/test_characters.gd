extends SceneTree
const Store = preload("res://scripts/character_store.gd")
const State = preload("res://scripts/game_state.gd")
const Selector = preload("res://scripts/character_select.gd")
const Main = preload("res://scripts/main.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var dir := "res://.godot/character_test_%d" % Time.get_ticks_usec()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var old_path := dir.path_join("journey.json")
	var old_state := State.new()
	old_state.gold = 777
	check(old_state.save_game(old_path), "Create isolated legacy fixture")
	old_state.free()
	var old_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(old_path))
	old_data.erase("character_name")
	old_data.erase("character_race")
	old_data.erase("character_class")
	var legacy_file := FileAccess.open(old_path, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(old_data, "", true, true))
	legacy_file.close()
	var legacy_before := FileAccess.get_file_as_string(old_path)
	var store := Store.new(dir.path_join("characters"), old_path)
	var existing: Array = store.list_characters()
	check(existing.size() == 1 and existing[0].legacy and existing[0].name == "Wayfarer", "Original journey appears without migration")
	check(store.auto_login_path() == old_path, "A sole existing journey is the initial last character")
	var first: Dictionary = store.create_character("Aster", "Dark Elf", "Mystic")
	var second: Dictionary = store.create_character("Bram", "Dwarf", "Fighter")
	check(first.has("path") and second.has("path") and first.get("path") != second.get("path"), "Characters get separate saves")
	check(store.auto_login_path().is_empty(), "Several characters without a last selection open the selector")
	check(store.create_character("aster", "Human", "Fighter").has("error"), "Duplicate names rejected")
	check(store.create_character("", "Human", "Fighter").has("error"), "Empty name rejected")
	check(store.create_character("Invalid", "Unknown", "Fighter").has("error"), "Invalid race rejected")
	check(FileAccess.get_file_as_string(old_path) == legacy_before, "Original journey not modified")
	if first.has("path") and second.has("path"):
		var a := State.new()
		var b := State.new()
		check(a.load_game(first.path) and b.load_game(second.path), "Both characters load")
		check(a.character_name == "Aster" and a.character_race == "Dark Elf" and a.character_class == "Mystic", "Identity persists")
		a.gold = 444
		check(a.save_game(first.path), "Save first character")
		var reloaded := State.new()
		check(reloaded.load_game(second.path) and reloaded.gold == b.gold, "Other character remains independent")
		a.free(); b.free(); reloaded.free()
	var legacy := State.new()
	check(legacy.load_game(old_path) and legacy.gold == 777 and legacy.character_name == "Wayfarer", "Legacy save remains playable")
	legacy.free()
	var selector := Selector.new()
	selector.store = store
	root.add_child(selector)
	await process_frame
	check(selector.list.item_count == 3, "Selector lists all characters")
	check(selector.race_input.item_count == 5 and selector.class_input.item_count == 2, "Five races and two classes are offered")
	var selected_paths: Array[String] = []
	selector.character_selected.connect(func(path: String): selected_paths.append(path))
	selector.list.select(0)
	selector._enter_selected()
	check(selected_paths.size() == 1 and selected_paths[0] == old_path, "Can select original journey")
	selector.name_input.text = "Dagna"
	selector.race_input.select(4)
	selector.class_input.select(1)
	selector._create_character()
	check(selected_paths.size() == 2, "Create and enter emits character path")
	var third_path := selected_paths[1] if selected_paths.size() > 1 else ""
	if not third_path.is_empty():
		var dwarf := State.new()
		check(dwarf.load_game(third_path) and dwarf.character_race == "Dwarf" and dwarf.character_class == "Mystic", "Dwarf Mystic can be created")
		dwarf.free()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/character-selector-preview.png")
	selector.queue_free()
	await process_frame
	if first.has("path") and second.has("path"):
		var game: Node = load("res://scenes/main.tscn").instantiate()
		game.set_meta("character_test_store", store)
		root.add_child(game)
		await process_frame
		var start_menu := game.get_node_or_null("CharacterSelection")
		check(start_menu != null and game.current_save_path.is_empty(), "Startup waits for character selection")
		if start_menu != null:
			for index in range(start_menu.roster.size()):
				if start_menu.roster[index].path == first.path: start_menu.list.select(index)
			start_menu._enter_selected()
			await process_frame
			check(game.current_save_path == first.path and game.state.character_name == "Aster", "Selection loads chosen character into the world")
			check(store.auto_login_path() == first.path, "Successful selection remembers the character")
			check(game.hud != null and game.hud.player_name.text.contains("ASTER"), "HUD displays character name")
			check(game.hud.player_identity.text.contains("DARK ELF") and game.hud.player_identity.text.contains("MYSTIC"), "HUD displays race and class")
			game.state.gold = 987
			game.test_mode = false
			check(game._save_journey(), "Save routes to selected character")
			game.ground_loot.append({})
			game.logout_to_characters()
			check(game.is_inside_tree() and not game.ground_loot.is_empty(), "Logout is blocked while dropped gear remains")
			game.ground_loot.clear()
			game.is_dead = true
			game.logout_to_characters()
			check(game.is_inside_tree(), "Logout is blocked until respawn")
			game.is_dead = false
			var other := State.new()
			check(other.load_game(second.path) and other.character_name == "Bram" and other.gold != 987, "Selected save does not overwrite another character")
			other.free()
			current_scene = game
			game.logout_to_characters()
			await process_frame
			await process_frame
			check(current_scene != null and current_scene != game, "Logout saves and transitions to a fresh scene")
			if current_scene != null:
				current_scene.queue_free()
			current_scene = null
		else:
			game.queue_free()
		await process_frame
		check(store.remember_character(second.path), "Remember a different character")
		var auto_game: Node = load("res://scenes/main.tscn").instantiate()
		auto_game.set_meta("character_test_store", store)
		auto_game.set_meta("character_test_auto", true)
		root.add_child(auto_game)
		await process_frame
		check(auto_game.get_node_or_null("CharacterSelection") == null and auto_game.current_save_path == second.path and auto_game.state.character_name == "Bram", "Startup loads the last selected character")
		auto_game.queue_free()
		await process_frame
		Main.select_character_on_next_start = true
		var logout_menu_game: Node = load("res://scenes/main.tscn").instantiate()
		logout_menu_game.set_meta("character_test_store", store)
		logout_menu_game.set_meta("character_test_auto", true)
		root.add_child(logout_menu_game)
		await process_frame
		check(logout_menu_game.get_node_or_null("CharacterSelection") != null, "Logout forces the character selector")
		logout_menu_game.queue_free()
		await process_frame
		var stale := ConfigFile.new()
		stale.set_value("character", "last_path", dir.path_join("missing.json"))
		stale.save(store.last_character_path)
		check(store.auto_login_path().is_empty(), "Missing last save does not choose a different character")
		var fallback_game: Node = load("res://scenes/main.tscn").instantiate()
		fallback_game.set_meta("character_test_store", store)
		fallback_game.set_meta("character_test_auto", true)
		root.add_child(fallback_game)
		await process_frame
		check(fallback_game.get_node_or_null("CharacterSelection") != null, "Missing last save opens selection")
		fallback_game.queue_free()
		await process_frame
		var corrupt_path := dir.path_join("characters/corrupt.json")
		var corrupt_file := FileAccess.open(corrupt_path, FileAccess.WRITE)
		corrupt_file.store_string('{"version":1,"skill_ranks":[]}')
		corrupt_file.close()
		stale.set_value("character", "last_path", corrupt_path)
		stale.save(store.last_character_path)
		var corrupt_before := FileAccess.get_file_as_string(corrupt_path)
		var corrupt_game: Node = load("res://scenes/main.tscn").instantiate()
		corrupt_game.set_meta("character_test_store", store)
		corrupt_game.set_meta("character_test_auto", true)
		root.add_child(corrupt_game)
		await process_frame
		check(corrupt_game.get_node_or_null("CharacterSelection") != null and corrupt_game.current_save_path.is_empty(), "Damaged last save opens selection")
		check(FileAccess.get_file_as_string(corrupt_path) == corrupt_before, "Damaged save is not overwritten")
		corrupt_game.queue_free()
		await process_frame
		DirAccess.remove_absolute(ProjectSettings.globalize_path(corrupt_path))
	for result: Dictionary in [first, second]:
		if result.has("path"): DirAccess.remove_absolute(ProjectSettings.globalize_path(result.path))
	if not third_path.is_empty(): DirAccess.remove_absolute(ProjectSettings.globalize_path(third_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(store.last_character_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir.path_join("characters")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(old_path))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(dir))
	print("CHARACTERS: ", failures, " failures")
	quit(failures)
