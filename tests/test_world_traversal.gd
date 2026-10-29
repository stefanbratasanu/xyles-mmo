extends SceneTree
## Exercises actual player physics over a streamed terrain-cell edge.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.debug_invulnerable = true
	for enemy: Node in game.enemies:
		enemy.set_physics_process(false)
	var start := Vector3(13.0, 0.0, 100.0)
	start.y = game.world.surface_height_at(start.x, start.z) + 0.25
	game.world.update_terrain_chunks(start)
	game.world.update_static_chunks(start)
	game.world.update_streamed_visuals(start)
	game.player.global_position = start
	game.player.velocity = Vector3.ZERO
	for frame in range(12):
		await physics_frame
	var initial_cell: Vector2i = game.world.terrain_cell(game.player.global_position)
	game.player.destination = Vector3(22.0, start.y, start.z)
	game.player.moving_to_click = true
	var minimum_y := 1000.0
	for frame in range(180):
		await physics_frame
		minimum_y = minf(minimum_y, game.player.global_position.y)
		if not game.player.moving_to_click:
			break
	var end: Vector3 = game.player.global_position
	assert(end.x > 18.0, "player did not cross the terrain boundary")
	assert(game.world.terrain_cell(end) != initial_cell, "test did not cross a terrain tile")
	assert(minimum_y > -6.0, "player fell through the streamed terrain")
	assert(absf(end.y - game.world.surface_height_at(end.x, end.z)) < 1.0, "player left the terrain surface")
	assert(game.world._terrain_active.has(game.world.terrain_cell(end)), "new terrain cell must have collision")
	print("WORLD TRAVERSAL: PASS; player walked from ", start, " to ", end)
	game.queue_free()
	await process_frame
	quit()
