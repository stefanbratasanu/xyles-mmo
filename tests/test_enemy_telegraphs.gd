extends SceneTree
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
	for enemy in game.enemies: enemy.set_physics_process(false)
	var wolf: CharacterBody3D = game.enemies[0]
	wolf.global_position = game.player.global_position + Vector3(2.0, 0.0, 0.0)
	wolf.home = wolf.global_position
	wolf._begin_attack()
	var origin: Vector3 = wolf.attack_origin
	var facing: Vector3 = wolf.attack_direction
	var reach: float = wolf.attack_reach
	check(is_instance_valid(wolf.attack_telegraph), "Windup displays a cone")
	var cone_mesh: ArrayMesh = wolf.attack_telegraph.mesh
	var vertices: PackedVector3Array = cone_mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for point: Vector3 in vertices:
		var at: Vector3 = wolf.attack_telegraph.global_position + point
		check(absf(at.y - game.world.surface_height_at(at.x, at.z) - 0.08) < 0.001, "Cone vertices follow the rendered terrain")
	check(wolf._strike_contains(origin + facing * (reach - 0.01)), "Forward point inside the cone is hit")
	check(not wolf._strike_contains(origin + facing * (reach + 0.01)), "Beyond the visible range is safe")
	check(wolf._strike_contains(origin + facing.rotated(Vector3.UP, wolf.ATTACK_HALF_ANGLE - 0.01) * 1.0), "Inside the cone edge is hit")
	check(not wolf._strike_contains(origin + facing.rotated(Vector3.UP, wolf.ATTACK_HALF_ANGLE + 0.01) * 1.0), "Outside the cone edge is safe")
	check(not wolf._strike_contains(origin - facing), "Behind the enemy is safe")
	if DisplayServer.get_name() != "headless":
		await create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/enemy-telegraph-preview.png")
	var locked_yaw: float = wolf.visual.rotation.y
	game.player.global_position = origin - facing
	wolf.aggro = true
	wolf._physics_process(0.1)
	check(is_equal_approx(wolf.visual.rotation.y, locked_yaw), "Enemy does not turn towards a moving player")
	check(wolf.attack_origin == origin and wolf.attack_direction.is_equal_approx(facing), "Origin and direction remain locked")
	var before: float = game.state.hp
	wolf._finish_attack()
	check(is_equal_approx(game.state.hp, before), "Player behind the cone avoids damage")
	check(not is_instance_valid(wolf.attack_telegraph), "Cone is removed after impact")
	game.player.global_position = origin + Vector3(1, 0, 0)
	wolf.global_position = origin
	wolf._begin_attack()
	wolf.global_position += Vector3(0.0, 0.0, 0.5)
	check(wolf.attack_telegraph.global_position.is_equal_approx(wolf.attack_origin), "Telegraph stays at the committed origin")
	before = game.state.hp
	wolf._finish_attack()
	check(game.state.hp < before, "Player inside the committed cone takes damage")
	wolf._begin_attack()
	wolf.take_damage(wolf.hp + 1.0)
	check(not wolf.winding_up and not is_instance_valid(wolf.attack_telegraph), "Death cancels the windup and cone")
	var boss: CharacterBody3D = game.enemies.back()
	boss.global_position = origin
	game.player.global_position = origin + Vector3(boss.SLAM_RADIUS + 0.1, 0, 0)
	before = game.state.hp
	boss._begin_slam()
	await create_timer(1.9).timeout
	check(is_equal_approx(game.state.hp, before), "Outside the boss circle is safe")
	game.player.global_position = origin + Vector3(boss.SLAM_RADIUS - 0.1, 0, 0)
	before = game.state.hp
	boss._begin_slam()
	await create_timer(1.9).timeout
	check(game.state.hp < before, "Inside the boss circle takes damage")
	game.queue_free()
	await process_frame
	print("ENEMY TELEGRAPHS: ", failures, " failures")
	quit(failures)
