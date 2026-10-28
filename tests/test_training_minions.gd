extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.debug_keys = {"invulnerable": KEY_F2, "heal": KEY_F3, "spawn": KEY_F4, "panel": KEY_F1}
	var panel_key := InputEventKey.new()
	panel_key.physical_keycode = KEY_F1
	panel_key.pressed = true
	game._unhandled_input(panel_key)
	check_panel(game.hud.current_panel == "debug", "Panel shortcut opens debug")
	game._unhandled_input(panel_key)
	check_panel(game.hud.current_panel.is_empty(), "Panel shortcut closes debug")
	game.ui_text_input = true
	game._unhandled_input(panel_key)
	check_panel(game.hud.current_panel.is_empty(), "Panel shortcut is suppressed in chat")
	game.ui_text_input = false
	game._unhandled_input(panel_key)
	await process_frame
	assert(game.hud.is_panel_open() and not game.hud.blocks_gameplay())
	var w_down := InputEventKey.new()
	w_down.physical_keycode = KEY_W
	w_down.pressed = true
	Input.parse_input_event(w_down)
	await physics_frame
	await physics_frame
	assert(game.player.velocity.length() > 0.0)
	w_down.pressed = false
	Input.parse_input_event(w_down)
	var skill_key := InputEventKey.new()
	skill_key.physical_keycode = KEY_3
	skill_key.pressed = true
	game._unhandled_input(skill_key)
	assert(float(game.skill_runtime.skill_cooldowns.get(game.state.loadout[2], 0.0)) > 0.0)
	game.hud._start_debug_rebind("heal")
	var rebind := InputEventKey.new()
	rebind.physical_keycode = KEY_F7
	rebind.pressed = true
	assert(game.hud._capture_debug_key(rebind))
	assert(game.debug_keys["heal"] == KEY_F7)
	assert(not game.set_debug_key("spawn", KEY_F7))
	assert(not game.set_debug_key("spawn", KEY_W))
	assert(not game.set_debug_key("panel", KEY_F7))
	game.hud._start_debug_rebind("panel")
	var panel_rebind := InputEventKey.new()
	panel_rebind.physical_keycode = KEY_F11
	panel_rebind.pressed = true
	assert(game.hud._capture_debug_key(panel_rebind))
	assert(game.debug_keys["panel"] == KEY_F11)
	game._unhandled_input(panel_rebind)
	assert(game.hud.current_panel.is_empty())
	game._unhandled_input(panel_rebind)
	assert(game.hud.current_panel == "debug")
	assert(game.set_debug_key("panel", KEY_F1))
	var config := ConfigFile.new()
	config.set_value("debug_keys", "heal", KEY_F11)
	game._load_debug_keys(config)
	assert(game.debug_keys["heal"] == KEY_F11)
	config.set_value("debug_keys", "heal", KEY_W)
	game._load_debug_keys(config)
	assert(game.debug_keys["heal"] == KEY_F11)
	assert(game.set_debug_key("heal", KEY_F7))
	var old_config := ConfigFile.new()
	old_config.set_value("debug_keys", "heal", KEY_F1)
	game._load_debug_keys(old_config)
	assert(game.debug_keys["heal"] == KEY_F1 and game.debug_keys["panel"] != KEY_F1)
	game.debug_keys = {"invulnerable": KEY_F2, "heal": KEY_F7, "spawn": KEY_F4, "panel": KEY_F1}
	game.state.hp = 5.0
	game._unhandled_input(rebind)
	assert(game.state.hp >= game.state.max_hp)
	game.ui_text_input = true
	game.state.hp = 5.0
	game._unhandled_input(rebind)
	assert(game.state.hp == 5.0)
	game.ui_text_input = false
	game.hud.toggle_panel("settings")
	assert(game.hud.blocks_gameplay())
	game._unhandled_input(rebind)
	assert(game.state.hp == 5.0)
	game.hud.toggle_panel("debug")
	await process_frame
	var shortcut := InputEventKey.new()
	shortcut.pressed = true
	shortcut.physical_keycode = int(game.debug_keys["invulnerable"])
	var was_invulnerable: bool = game.debug_invulnerable
	game._unhandled_input(shortcut)
	assert(game.debug_invulnerable != was_invulnerable)
	game._unhandled_input(shortcut)
	assert(game.debug_invulnerable == was_invulnerable)
	shortcut.physical_keycode = int(game.debug_keys["spawn"])
	game._unhandled_input(shortcut)
	assert(game.training_minion_count() == game.hud.minion_spawn_count)
	game.clear_training_minions()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/debug-menu-preview.png")
	var god_mode := game.hud.window_frame.find_child("DebugInvulnerable", true, false) as CheckButton
	var pause_time := game.hud.window_frame.find_child("DebugPauseTime", true, false) as CheckButton
	assert(god_mode != null and pause_time != null)
	game.state.hp = 10.0
	game.state.mana = 5.0
	game.hud.window_frame.find_child("DebugRestore", true, false).pressed.emit()
	assert(game.state.hp >= game.state.max_hp and game.state.mana >= game.state.max_mana)
	game.skill_runtime.skill_cooldowns["melee"] = 20.0
	game.hud.window_frame.find_child("DebugCooldowns", true, false).pressed.emit()
	assert(game.skill_runtime.skill_cooldowns.is_empty())
	god_mode.button_pressed = true
	var hp_before: float = game.state.hp
	game.damage_player(100.0)
	assert(game.state.hp == hp_before)
	god_mode.button_pressed = false
	game.damage_player(1.0)
	assert(game.state.hp < hp_before)
	pause_time.button_pressed = true
	game.debug_set_time(22.0)
	game._process(1.0)
	assert(is_equal_approx(game.world.time_of_day, 22.0))
	pause_time.button_pressed = false
	game._process(1.0)
	assert(game.world.time_of_day > 22.0)
	var count_slider := game.hud.window_frame.find_child("MinionCountSlider", true, false) as HSlider
	var level_slider := game.hud.window_frame.find_child("MinionLevelSlider", true, false) as HSlider
	assert(count_slider != null and level_slider != null)
	count_slider.value = 3
	level_slider.value = 12
	game.hud._spawn_minions()
	assert(game.training_minion_count() == 3)
	var minions: Array = []
	for enemy in game.enemies:
		if enemy.has_meta("training_minion"):
			minions.append(enemy)
			assert(enemy.level == 12 and enemy.max_hp > 64.0)
			assert(absf(enemy.home.y - game.world.height_at(enemy.home.x, enemy.home.z)) < 0.01)
	assert(game.hud.minion_count_label.text.contains("3 / 50"))
	var xp: int = game.state.xp
	var book: Dictionary = game.state.bestiary.duplicate(true)
	var respawns: int = game.respawns.size()
	minions[0].take_damage(100000.0)
	assert(game.training_minion_count() == 2)
	assert(game.state.xp == xp and game.state.bestiary == book)
	assert(game.respawns.size() == respawns)
	assert(game.spawn_training_minions(30, 12) == 30)
	assert(game.spawn_training_minions(30, 12) == 18)
	assert(game.spawn_training_minions(1, 12) == 0)
	assert(game.training_minion_count() == 50)
	game.hud._clear_minions()
	assert(game.training_minion_count() == 0)
	game.queue_free()
	await process_frame
	print("PASS: debug controls, time, training minions, scaling, rewards and cleanup")
	quit()

func check_panel(ok: bool, message: String) -> void:
	assert(ok, message)
