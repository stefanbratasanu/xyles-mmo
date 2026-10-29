extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	if not value: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var game: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	game.player.set_physics_process(false)
	for enemy: Node in game.enemies: enemy.set_physics_process(false)
	var enemy: Node3D=game.enemies[0]
	enemy.global_position=game.player.global_position+Vector3(0,0,-2)
	enemy.max_hp=10000; enemy.hp=10000
	game.target=enemy
	game.state.skill_catalog=game.state.skill_catalog.duplicate(true)
	game.state.skill_catalog.data.rules.critical_chance=0
	var mana: float=game.state.mana
	game.hud._submit_chat("/attack")
	var damage: float=10000-enemy.hp
	check(damage>0,"Chat command damages a nearby enemy")
	check(game.state.mana==mana,"Basic attack uses no mana")
	game.basic_attack()
	check(is_equal_approx(10000-enemy.hp,damage),"Cooldown prevents repeat hit")
	game.skill_runtime.skill_cooldowns.clear()
	game.state.skills.melee.evolutions=[{"id":"legacy","op":"legacy","family":"legacy","values":{"power":10}}]
	game.state.compiled_skills.clear()
	game.basic_attack()
	check(is_equal_approx(10000-enemy.hp,damage*2),"Melee upgrades do not increase basic attack")
	game.skill_runtime.skill_cooldowns.clear()
	enemy.global_position=game.player.global_position+Vector3(0,0,-10)
	game.basic_attack()
	check(is_equal_approx(10000-enemy.hp,damage*2),"Out-of-range target cannot be hit")
	print("BASIC ATTACK: ",failures," failures")
	game.queue_free()
	await process_frame
	quit(failures)
