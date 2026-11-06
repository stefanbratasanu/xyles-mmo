extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(4): await process_frame
	var hud = game.hud
	var state = game.state
	var original: Array = state.loadout.duplicate()
	check(not state.is_skill_available("fighter_cone"), "Level 4 skill is locked normally")
	hud._toggle_developer_mode()
	check(hud.dev_skill_button.visible and state.is_skill_available("fighter_cone"), "Developer mode exposes locked skill")
	hud.dev_skill_button.pressed.emit()
	check(hud.current_panel == "dev_skills" and not hud.blocks_gameplay(), "Skills palette stays usable during gameplay")
	var tiles: Array[Node] = hud.overlay_content.find_children("*", "Button", true, false)
	var cone: Button
	for tile: Button in tiles:
		if tile.get("drag_payload") is Dictionary and tile.drag_payload.get("id", "") == "fighter_cone": cone = tile
	check(cone != null and tiles.size() == state.skills.size(), "Palette offers every catalog skill")
	if cone != null:
		check(hud.hotbar[0]._can_drop_data(Vector2.ZERO, cone.drag_payload), "Hotbar accepts palette drag payload")
		hud.hotbar[0]._drop_data(Vector2.ZERO, cone.drag_payload)
	check(state.loadout[0] == "fighter_cone", "Dropping assigns locked skill for testing")
	check(hud.dev_color_button.visible, "Color control appears in developer mode")
	hud.dev_color_button.pressed.emit()
	check(hud.current_panel == "dev_colors" and not hud.blocks_gameplay(), "Color palette remains nonmodal")
	var purple_button: Button
	for button: Button in hud.overlay_content.find_children("*", "Button", true, false):
		if button.text == "Purple dusk": purple_button = button
	check(purple_button != null, "Purple option is present in the palette")
	if purple_button != null:
		purple_button.pressed.emit()
		check(game.world.color_grade == "purple", "Clicking purple applies the intended grade")
	var before_hp: float = state.hp
	for id: String in game.world.color_grading.PRESETS:
		check(game.world.set_color_grade(id), "Can preview " + id)
		check(game.world.color_grade == id, "Selected color grade is active")
		check(game.world._environment.adjustment_enabled == (id != "neutral"), "Color adjustment state matches selection")
		if id != "neutral": check(game.world._environment.adjustment_color_correction is ImageTexture3D, "Color grade uses a 3D lookup texture")
	check(state.hp == before_hp and state.loadout[0] == "fighter_cone", "Color preview does not affect gameplay state")
	var path := "res://logs/dev_mode_save_test.json"
	check(state.save_game(path), "Save while testing")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(saved.loadout == original and not saved.learned_skills.has("fighter_cone"), "Testing does not save unlocks or temporary hotbar")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	hud._toggle_developer_mode()
	check(state.loadout == original and not state.is_skill_available("fighter_cone"), "Exit restores original hotbar and normal restrictions")
	check(game.world.color_grade == "neutral" and not hud.dev_color_button.visible, "Exit restores original colors and hides controls")
	game.queue_free(); await process_frame
	print("DEVELOPER MODE: ", failures, " failures")
	quit(failures)
