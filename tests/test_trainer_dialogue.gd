extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func button_for(hud: Node, id: String) -> Button:
	for button in hud.overlay_content.find_children("*", "Button", true, false):
		if str(button.get_meta("learn_skill", "")) == id: return button
	return null
func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://logs/trainer_" + name + ".png")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1100, 650)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for frame in range(3): await process_frame
	game.set_process(false)
	game.player.set_physics_process(false)
	for enemy in game.enemies: enemy.set_physics_process(false)
	var state = game.state
	state.character_class = "Fighter"
	for id in state.FighterTree.available(100): state.learned_skills.erase(id)
	state.level = 1
	game.player.position = game.smith_position
	game.interact()
	check(game.hud.current_panel == "npc_dialogue", "Speak to starting NPC opens dialogue")
	check(button_for(game.hud, "fighter_cone").disabled, "Level 4 Cone is locked at level 1")
	var required_visible := false
	for label in game.hud.overlay_content.find_children("*", "Label", true, false):
		if "Required level 4" in label.text and "Locked" in label.text: required_visible = true
	check(required_visible, "Locked skill visibly shows required level")
	button_for(game.hud, "fighter_cone").pressed.emit()
	check(not state.is_skill_available("fighter_cone"), "Under-level callback cannot bypass learning gate")
	await capture("level1")
	state.level = 4
	game.hud.refresh()
	check(not button_for(game.hud, "fighter_cone").disabled, "Open dialogue refreshes immediately on level change")
	check(not state.is_skill_available("fighter_cone"), "Level 4 eligibility is separate from learning")
	await capture("level4")
	game.hud._switch_panel("skills")
	for label in game.hud.overlay_content.find_children("*", "Label", true, false):
		check(label.text != "Cone Attack" and label.text != "Cleave", "K hides unlearned skills even when level-eligible")
	check(game.learn_from_trainer("fighter_cleave"), "Learn first skill for K visibility")
	var learned_visible := false
	for label in game.hud.overlay_content.find_children("*", "Label", true, false):
		if label.text == "Cleave": learned_visible = true
		check(label.text != "Cone Attack", "K still hides other unlearned skills")
	check(learned_visible, "Learned skill appears in K immediately")
	game.hud._switch_panel("npc_dialogue")
	var points: int = state.skill_points
	for definition in state.FighterTree.SKILLS:
		if not state.is_skill_available(definition.id): button_for(game.hud, definition.id).pressed.emit()
		check(state.is_skill_available(definition.id), "Learn through actual NPC button: " + definition.id)
		check(button_for(game.hud, definition.id).text == "LEARNED", "Learned entry refreshes")
	check(state.skill_points == points, "Base training spends no enchantment points")
	check(not game.learn_from_trainer("fighter_cone"), "Duplicate learning rejected")
	check(state.assign_hotbar("fighter_cone", 0), "Learned level 4 skill can be assigned")
	await capture("learned")
	var path := "res://logs/trainer_save_test.json"
	check(state.save_game(path), "Save training")
	var loaded = load("res://scripts/game_state.gd").new()
	check(loaded.load_game(path) and loaded.is_skill_available("fighter_cone"), "Learned skills persist after reload")
	check(loaded.loadout[0] == "fighter_cone", "Trained hotbar assignment persists")
	loaded.free()
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	for id in state.FighterTree.available(100): legacy.learned_skills.erase(id)
	var fixture := FileAccess.open("res://logs/trainer_legacy_test.json", FileAccess.WRITE)
	fixture.store_string(JSON.stringify(legacy)); fixture.close()
	loaded = load("res://scripts/game_state.gd").new()
	check(loaded.load_game("res://logs/trainer_legacy_test.json"), "Load pre-trainer fixture")
	check(loaded.is_skill_available("fighter_cone"), "Existing equipped skill remains learned")
	check(not loaded.is_skill_available("fighter_dash"), "Legacy migration does not grant unequipped eligible skills")
	loaded.free()
	state.learned_skills.erase("fighter_guard")
	game.player.position = game.smith_position + Vector3(20, 0, 0)
	check(not game.learn_from_trainer("fighter_guard"), "Training requires NPC range")
	state.character_class = "Mystic"
	check(not state.learn_class_skill("fighter_guard"), "Wrong class cannot learn Fighter skills")
	game.queue_free()
	await process_frame
	print("TRAINER DIALOGUE: ", failures, " failures")
	quit(failures)
