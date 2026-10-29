extends SceneTree
## Run with the real renderer to exercise background loads and rapid relocation.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.player.set_physics_process(false)
	var world: Node = game.world
	var first := Vector3(180, 0, 120)
	world.update_terrain_chunks(first)
	world.update_static_chunks(first)
	world.update_streamed_visuals(first)
	await process_frame
	var destination := Vector3(-195, 0, -185)
	world.update_terrain_chunks(destination)
	world.update_static_chunks(destination)
	world.update_streamed_visuals(destination)
	var terrain_cell: Vector2i = world.terrain_cell(destination)
	var visual_cell: Vector2i = world.stream_cell(destination)
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 15000:
		var terrain_ready: bool = world._terrain_active.has(terrain_cell)
		var vegetation_ready: bool = not world._vegetation_paths.has(visual_cell) or world._streamed_visual_nodes.has(visual_cell)
		var scenery_ready: bool = not world._static_paths.has(visual_cell) or world._static_active.has(visual_cell)
		if terrain_ready and vegetation_ready and scenery_ready:
			break
		await process_frame
	if not world._terrain_active.has(terrain_cell):
		push_error("Detailed terrain did not load after relocation")
		quit(1)
		return
	if world._vegetation_paths.has(visual_cell) and not world._streamed_visual_nodes.has(visual_cell):
		push_error("Vegetation did not load after relocation")
		quit(1)
		return
	if world._static_paths.has(visual_cell) and not world._static_active.has(visual_cell):
		push_error("Scenery did not load after relocation")
		quit(1)
		return
	for cell: Vector2i in world._terrain_active:
		if absi(cell.x - terrain_cell.x) > world.TERRAIN_TILE_RADIUS or absi(cell.y - terrain_cell.y) > world.TERRAIN_TILE_RADIUS:
			push_error("A stale terrain cell became active after relocation")
			quit(1)
			return
	print("BACKGROUND STREAMING: PASS; target loaded after ", Time.get_ticks_msec() - started, " ms")
	game.queue_free()
	await process_frame
	quit()
