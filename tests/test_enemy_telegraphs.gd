extends SceneTree
## Verifies the committed target-point contract on Map I: every windup locks a
## world point, the telegraph marks that point, and stepping off it before the
## impact is a real miss. The boss slam keeps the same rule on a circle.
##
## Run:
##   .\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_enemy_telegraphs.gd

var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1600, 900)
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.player.set_physics_process(false)
	for enemy in game.enemies:
		enemy.set_physics_process(false)
	var wolf: CharacterBody3D = game.enemies[0]
	wolf.global_position = game.player.global_position + Vector3(2.0, 0.0, 0.0)
	wolf.home = wolf.global_position
	wolf._begin_attack()
	var point: Vector3 = wolf.locked_point
	check(Vector2(point.x, point.z).distance_to(Vector2(game.player.global_position.x, game.player.global_position.z)) < 0.001,
		"The bite locks the player's horizontal position")
	check(is_equal_approx(point.y, game.world.height_at(point.x, point.z) + 0.02),
		"The bite target is projected onto the ground")
	check(is_instance_valid(wolf.telegraph), "Windup displays a telegraph")
	check(wolf.telegraph.global_position.distance_to(point) < 0.1,
		"The telegraph marks the locked point")
	var locked_yaw: float = wolf.visual.rotation.y
	game.player.global_position = point + Vector3(4.0, 0.0, 0.0)
	wolf._physics_process(0.1)
	check(wolf.visual.rotation.y == locked_yaw,
		"Enemy does not turn towards a moving player")
	check(wolf.locked_point.is_equal_approx(point),
		"The locked point does not follow the player")
	var before: float = game.state.hp
	wolf._finish_attack()
	check(is_equal_approx(game.state.hp, before),
		"Stepping off the locked point avoids the bite")
	check(not is_instance_valid(wolf.telegraph),
		"Telegraph is removed after impact")

	game.player.global_position = point
	wolf.global_position = point + Vector3(-2.0, 0.0, 0.0)
	wolf._begin_attack()
	wolf.global_position += Vector3(0.0, 0.0, 0.5)
	check(wolf.telegraph.global_position.distance_to(wolf.locked_point) < 0.1,
		"Telegraph stays at the committed point")
	before = game.state.hp
	wolf._finish_attack()
	check(game.state.hp < before, "Standing on the locked point takes damage")

	wolf._begin_attack()
	wolf.take_damage(wolf.hp + 1.0)
	check(not wolf.winding_up and not is_instance_valid(wolf.telegraph),
		"Death cancels the windup and telegraph")

	var boss: CharacterBody3D = game.enemies.back()
	boss.global_position = point
	game.player.global_position = point + Vector3(4.0, 0.0, 0.0)
	boss._begin_slam()
	var slam_point: Vector3 = boss.locked_point
	check(Vector2(slam_point.x, slam_point.z).distance_to(Vector2(game.player.global_position.x, game.player.global_position.z)) < 0.001,
		"The slam locks the player's horizontal position")
	check(is_equal_approx(slam_point.y, game.world.height_at(slam_point.x, slam_point.z) + 0.02),
		"The slam target is projected onto the ground")
	game.player.global_position = slam_point + Vector3(boss.SLAM_RADIUS + 0.5, 0.0, 0.0)
	before = game.state.hp
	await create_timer(1.9).timeout
	check(is_equal_approx(game.state.hp, before),
		"Outside the boss circle is safe")

	game.player.global_position = point + Vector3(3.0, 0.0, 0.0)
	before = game.state.hp
	boss._begin_slam()
	await create_timer(1.9).timeout
	check(game.state.hp < before, "Inside the boss circle takes damage")

	game.queue_free()
	await process_frame
	print("ENEMY TELEGRAPHS: ", failures, " failures")
	quit(failures)
