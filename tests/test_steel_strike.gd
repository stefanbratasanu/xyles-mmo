extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
	await process_frame
	game.set_process(false); game.player.set_physics_process(false); game.skill_runtime.set_physics_process(false)
	for enemy in game.enemies: enemy.set_physics_process(false)
	var s = game.state
	check(s.modifier_catalog.has_rarity("common"), "Common rarity is valid")
	check(s.equipment[0].tier == "common" and s.get_weapon_damage_range() == Vector2(5,9), "Starter sword is common with 5–9 weapon damage")
	check(s.get_attack_damage_range() == Vector2(6,12), "Base 1–3 plus sword 5–9 yields attack 6–12")
	check(s.skill_catalog.validate().is_empty(), "Skill catalog validates")
	check(s.is_skill_available("steel_strike") and s.assign_hotbar("steel_strike", 0), "New strike is learned and assignable")
	game.hud.toggle_panel("inventory")
	check(game.hud.current_panel == "inventory" and game.hud.character_values.has("attack_damage"), "I panel contains character stats and inventory")
	check(game.hud.character_values.attack_damage.text == "6–12", "Combined panel shows actual attack range")
	check(not game.hud.character_values.has("strike_damage"), "Character panel does not show skill-specific damage")
	check("5–9" in game.hud.inventory_view._description(s.equipment[0]), "Sword tooltip shows its damage range")
	game.hud.close_panel()
	game.hud.toggle_panel("skills")
	var in_skills := false
	for button: Button in game.hud.overlay_content.find_children("*", "Button", true, false):
		if button.get("drag_payload") is Dictionary and button.drag_payload.get("id", "") == "steel_strike": in_skills = true
	check(in_skills, "Learned Steel Strike appears in the normal Fighter skills panel")
	game.hud.close_panel()
	game.hud._toggle_developer_mode(); game.hud._switch_panel("dev_skills")
	var strike_tile: Button
	for button: Button in game.hud.overlay_content.find_children("*", "Button", true, false):
		if button.get("drag_payload") is Dictionary and button.drag_payload.get("id", "") == "steel_strike": strike_tile = button
	check(strike_tile != null, "Developer skill panel offers Steel Strike")
	if strike_tile != null:
		check(game.hud.hotbar[1]._can_drop_data(Vector2.ZERO, strike_tile.drag_payload), "Hotbar accepts Steel Strike from DEV")
		game.hud.hotbar[1]._drop_data(Vector2.ZERO, strike_tile.drag_payload)
		check(s.loadout[1] == "steel_strike", "Dropping Steel Strike in DEV assigns it")
	game.hud._toggle_developer_mode()
	var enemy: Node3D = game.enemies[0]
	enemy.global_position = game.player.global_position + Vector3(0,0,-2)
	enemy.max_hp = 10000; enemy.hp = 10000; game.target = enemy
	s.skill_catalog.data.rules.critical_chance = 0.0
	var rng := RandomNumberGenerator.new(); rng.seed = 721
	var expected: float = s.roll_attack_damage(rng) * 1.2 * .85
	game.skill_runtime.rng.seed = 721
	var mana: float = s.mana
	check(game.skill_runtime.cast_slot(0), "Strike starts on a nearby target")
	check(is_equal_approx(enemy.hp, 10000), "Strike does not deal damage before the hit frame")
	check(s.mana == mana - 4, "Strike spends four mana")
	check(str(game.player.animation_player.current_animation).contains("sword_SwordAttack2"), "Strike uses its dedicated attack clip")
	game.skill_runtime._physics_process(.43)
	check(is_equal_approx(10000-enemy.hp, expected), "Strike deals exactly 120% of its rolled attack after armor")
	check(game.combat_effects.steel_strike_effect != null and not game.combat_effects.steel_emitters.is_empty(), "Strike plays the imported Effekseer effect")
	check(not game.skill_runtime.cast_slot(0), "Strike respects cooldown")
	game.skill_runtime.skill_cooldowns.clear()
	enemy.global_position = game.player.global_position + Vector3(0,0,-10)
	var hp: float = enemy.hp
	check(not game.skill_runtime.cast_slot(0) and enemy.hp == hp, "Out-of-range strike is rejected")
	enemy.global_position = game.player.global_position + Vector3(0,0,-2)
	check(game.skill_runtime.cast_slot(0), "Second strike can start")
	enemy.global_position = game.player.global_position + Vector3(0,0,-10)
	game.skill_runtime._physics_process(.43)
	check(is_equal_approx(enemy.hp, hp), "Target leaving range avoids the delayed hit")
	var path := "res://logs/strike_save_test.json"
	var legacy: Dictionary = s.equipment[0].duplicate(true)
	legacy.tier = "basic"; legacy.erase("damage_min"); legacy.erase("damage_max")
	legacy.modifiers = ["attack_power"]
	s.equipment[0] = legacy
	check(s.save_game(path), "Write isolated legacy fixture")
	var restored = load("res://scripts/game_state.gd").new(); root.add_child(restored)
	check(restored.load_game(path), "Read isolated legacy fixture")
	check(restored.is_skill_available("heavy_strike"), "Existing save learns Heavy Strike")
	check(restored.equipment[0].tier == "common" and restored.get_weapon_damage_range() == Vector2(5,9), "Existing ornate sword migrates to common 5–9")
	check(restored.equipment[0].modifiers.has("attack_power"), "Legacy sword modifiers are preserved")
	check(restored.save_game(path) and restored.load_game(path) and restored.equipment[0].modifiers.has("attack_power"), "Legacy modifiers survive another save and reload")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	game.queue_free(); restored.queue_free(); await process_frame
	print("STEEL STRIKE: ", failures, " failures")
	quit(failures)
