extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.player.set_physics_process(false)
	for existing in game.enemies:
		existing.set_physics_process(false)
	var mob: CharacterBody3D = game._spawn_enemy("normal", game.world.normal_spawns[0], 0, "wolf")
	mob.set_physics_process(false)
	mob.home = mob.global_position
	game.player.global_position = mob.global_position + Vector3(1.0, 0.0, 0.0)
	mob.aggro_mode = "passive"
	mob.aggro = false
	mob.attack_timer = 0.0
	mob._physics_process(0.02)
	check(not mob.aggro and not mob.winding_up, "Passive creature does not attack nearby player")
	check((mob.health_fill.material_override as StandardMaterial3D).albedo_color.is_equal_approx(Color("e5cd4a")), "Passive health bar is yellow")
	mob.take_damage(1.0)
	check(mob.aggro, "Passive creature retaliates when hit")
	mob._physics_process(0.02)
	check(mob.winding_up, "Attacked passive creature starts an attack")
	mob._cancel_attack()
	check((mob.health_fill.material_override as StandardMaterial3D).albedo_color.is_equal_approx(Color("d3473d")), "Passive creature's health bar turns red during combat")
	check(game._in_combat(), "Damaging a passive creature enters combat")
	mob.combat_time = 0.0
	mob.aggro_mode = "territorial"
	mob.aggro = false
	mob.attack_timer = 20.0
	game.player.global_position = mob.global_position + Vector3(4.0, 0, 0)
	mob._physics_process(0.02)
	check(not mob.aggro, "Territorial creature ignores a player four metres away")
	check((mob.health_fill.material_override as StandardMaterial3D).albedo_color.is_equal_approx(Color("eb9637")), "Territorial health bar is orange")
	game.player.global_position = mob.global_position + Vector3(2.0, 0, 0)
	mob._physics_process(0.02)
	check(mob.aggro, "Territorial creature aggros at close range")
	check((mob.health_fill.material_override as StandardMaterial3D).albedo_color.is_equal_approx(Color("d3473d")), "Territorial health bar becomes red in combat")
	mob.aggro_mode = "aggressive"
	mob.aggro = false
	mob.home = mob.global_position
	game.player.global_position = mob.global_position + Vector3(6.0, 0, 0)
	mob._physics_process(0.02)
	check(mob.aggro, "Aggressive creature aggros from its existing longer range")
	check(mob.health_bar_root.visible, "Health bar is visible before and during combat")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: passive, territorial and aggressive aggro and bar colors")
	quit(1 if failures else 0)
