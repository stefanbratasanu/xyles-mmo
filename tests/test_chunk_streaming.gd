extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.player.set_physics_process(false)
	var world: Node = game.world
	var manager: RefCounted = game.chunk_spawns
	assert(world._terrain_active.has(world.terrain_cell(game.player.global_position)), "starting terrain collision must be ready")
	var old_terrain_cell: Vector2i = world.terrain_cell(game.player.global_position)
	var old_terrain_node: WeakRef = weakref(world._terrain_active[old_terrain_cell])
	var old_terrain_mesh: WeakRef = weakref((world._terrain_active[old_terrain_cell].get_child(0) as MeshInstance3D).mesh)
	var outer_point := Vector3(220.0, 0.0, 180.0)
	world.update_terrain_chunks(outer_point)
	assert(not world._terrain_active.has(old_terrain_cell), "distant terrain collision should unload")
	assert(world._terrain_far[old_terrain_cell].visible, "distant low-detail terrain should remain visible")
	var far_shapes: Array = world._terrain_far[old_terrain_cell].find_children("*", "CollisionShape3D", true, false)
	assert(not far_shapes.is_empty() and not far_shapes[0].disabled, "unloaded terrain needs fallback collision")
	var near_shapes: Array = world._terrain_far[world.terrain_cell(outer_point)].find_children("*", "CollisionShape3D", true, false)
	assert(not near_shapes.is_empty() and not near_shapes[0].disabled, "fallback collision must cover the player while the tile loads")
	await physics_frame
	await physics_frame
	assert(old_terrain_node.get_ref() == null, "unloaded detailed terrain nodes must actually be freed")
	assert(old_terrain_mesh.get_ref() == null, "unloaded detailed terrain meshes must release their references")
	var ray := PhysicsRayQueryParameters3D.create(Vector3(outer_point.x, 40.0, outer_point.z), Vector3(outer_point.x, -30.0, outer_point.z), 1)
	var hit := root.world_3d.direct_space_state.intersect_ray(ray)
	assert(not hit.is_empty(), "fallback terrain must have collision before the detailed tile loads")
	for frame in range(180):
		if world._terrain_active.has(world.terrain_cell(outer_point)):
			break
		await process_frame
	assert(world._terrain_active.has(world.terrain_cell(outer_point)), "high-detail terrain should eventually load")
	assert(near_shapes[0].disabled, "high-detail terrain should replace fallback collision")
	await physics_frame
	await physics_frame
	hit = root.world_3d.direct_space_state.intersect_ray(ray)
	assert(not hit.is_empty(), "outer terrain must have collision")
	assert(absf(float(hit.position.y) - world.surface_height_at(outer_point.x, outer_point.z)) < 0.05, "terrain collision must match the baked surface")
	world.update_terrain_chunks(game.player.global_position)
	assert(manager.active.size() < world.normal_spawns.size() + 1, "distant enemies should not run at startup")
	var legacy_slots: Array = []
	for index in range(10):
		legacy_slots.append({"ready_at": float(index)})
	legacy_slots.append({"ready_at": 123.0, "species": "guardian", "hp": 400.0, "position": [-48.0, 5.0, -88.0]})
	legacy_slots.append({"ready_at": 234.0, "species": "guardian"})
	var legacy_manager: RefCounted = load("res://scripts/chunk_spawn_manager.gd").new()
	legacy_manager.setup(game, {"elapsed": 5.0, "slots": legacy_slots})
	assert(legacy_manager.slots[9]["ready_at"] == 9.0, "legacy normal slot changed identity")
	assert(legacy_manager.slots[10]["ready_at"] == 0.0, "new normal slot must not inherit the old boss")
	assert(legacy_manager.slots[world.normal_spawns.size()]["ready_at"] == 123.0, "legacy boss timer must be retained")
	assert(legacy_manager.slots[world.normal_spawns.size()]["hp"] == 400.0 and legacy_manager.slots[world.normal_spawns.size()]["position"].is_empty(), "a moved boss must retain health but return to its new home")
	assert(legacy_manager.slots[world.normal_spawns.size() + 1]["ready_at"] == 234.0, "legacy quest timer must be retained")
	var hour_seconds: float = world.DAY_SECONDS / 24.0
	assert(not manager.window_occurred(10.0 * hour_seconds, 12.0 * hour_seconds, 20.0, 5.0), "a window outside the interval must not fire")
	assert(manager.window_occurred(23.0 * hour_seconds, 26.0 * hour_seconds, 20.0, 5.0), "a window crossing midnight must be recognized")
	assert(manager.window_occurred(6.0 * hour_seconds, 24.0 * hour_seconds * 4.0, 20.0, 5.0), "multi-day catch-up must recognize a missed window")
	var initial_instances := 0
	var total_instances := 0
	for count: int in world._vegetation_counts.values():
		total_instances += count
	for cell in world._streamed_visual_nodes:
		for node: MultiMeshInstance3D in world._streamed_visual_nodes[cell]:
			initial_instances += node.multimesh.instance_count
	assert(initial_instances < total_instances, "distant vegetation buffers should not be allocated")
	world.day_number = 1
	world.set_time_of_day(12.0)
	game.player.global_position = world.normal_spawns[0]
	manager.advance(0.0)
	assert(manager.active.has(0), "nearby spawn should be active")
	var boar: Node = manager.active[0]
	assert(boar.species == "boar", "day must spawn boars")
	boar.set_physics_process(false)
	boar.aggro = false
	boar.hp = boar.max_hp * 0.5
	var injured: float = boar.hp
	game.player.global_position = Vector3(145, 0, -145)
	manager.advance(0.0)
	assert(not manager.active.has(0), "distant spawn should unload")
	game.player.global_position = world.normal_spawns[0]
	manager.advance(0.0)
	boar = manager.active[0]
	assert(is_equal_approx(boar.hp, injured), "unloading must preserve a living enemy's health")
	manager.defeated(boar)
	game.enemies.erase(boar)
	boar.queue_free()
	var paused_snapshot: Dictionary = manager.snapshot()
	var restored_manager: RefCounted = load("res://scripts/chunk_spawn_manager.gd").new()
	restored_manager.setup(game, paused_snapshot)
	assert(is_equal_approx(float(restored_manager.slots[0]["ready_at"]) - restored_manager.now, 28.0), "saved respawn deadline must stay paused while closed")
	game.player.global_position = Vector3(145, 0, -145)
	manager.advance(10.0)
	game.player.global_position = world.normal_spawns[0]
	manager.advance(0.0)
	assert(not manager.active.has(0), "a dead mob must not respawn early")
	game.player.global_position = Vector3(145, 0, -145)
	manager.advance(18.0)
	game.player.global_position = world.normal_spawns[0]
	manager.advance(0.0)
	assert(manager.active.has(0), "expired spawn deadline must catch up on return")
	boar = manager.active[0]
	game.target = boar
	world.set_time_of_day(22.0)
	manager.advance(0.0)
	assert(game.target == null, "a removed time-window enemy must clear targeting")
	assert(manager.active[0].species == "wolf", "night must replace boars with wolves")
	var wolf: Node = manager.active[0]
	wolf.hp = wolf.max_hp * 0.4
	world.day_number += 2
	manager.advance(1800.0)
	assert(manager.active[0] != wolf and is_equal_approx(manager.active[0].hp, manager.active[0].max_hp), "crossed windows must be caught up even when species matches again")
	var boss_index: int = world.normal_spawns.size()
	if manager.active.has(boss_index):
		manager._remove(boss_index, false)
	manager.slots[boss_index]["hp"] = -1.0
	manager.slots[boss_index]["ready_at"] = 0.0
	manager.slots[boss_index]["window_pending"] = false
	world.boss_spawn_window.assign([20.0, 5.0])
	world.day_number = 10
	world.set_time_of_day(12.0)
	manager.last_clock = manager._world_clock()
	game.player.global_position = world.boss_spawn
	manager.advance(0.0)
	assert(not manager.active.has(boss_index), "timed boss should wait for its window")
	game.player.global_position = Vector3(145, 0, 145)
	world.set_time_of_day(22.0)
	manager.advance(0.0)
	world.day_number += 1
	world.set_time_of_day(6.0)
	game.player.global_position = world.boss_spawn
	manager.advance(0.0)
	assert(manager.active.has(boss_index), "a boss window passed offscreen should be caught up")
	world.boss_spawn_window.clear()
	var quest_index := boss_index + 1
	game.state.quests[0]["active"] = true
	game.state.quests[0]["stage"] = 2
	game.player.global_position = world.quest_spawn
	manager.advance(0.0)
	assert(manager.active.has(quest_index), "active quest enemy should load near its spawn")
	var guardian: Node = manager.active[quest_index]
	guardian.hp = guardian.max_hp * 0.6
	guardian.aggro = false
	game.player.global_position = Vector3(-145, 0, 145)
	manager.advance(0.0)
	assert(not manager.active.has(quest_index), "distant quest enemy should unload")
	game.player.global_position = world.quest_spawn
	manager.advance(0.0)
	assert(is_equal_approx(manager.active[quest_index].hp, guardian.max_hp * 0.6), "quest enemy health must survive unloading")
	game.state.world_session = manager.snapshot()
	var path := "res://.godot/chunk_streaming_test_save.json"
	assert(game.state.save_game(path), "test save failed")
	var restored: Node = load("res://scripts/game_state.gd").new()
	root.add_child(restored)
	assert(restored.load_game(path), "test save failed to reload")
	assert(is_equal_approx(float(restored.world_session["elapsed"]), manager.now), "paused clock must survive save/load")
	assert(int(restored.world_session["day"]) == world.day_number, "world day must survive save/load")
	assert(float(restored.world_session["hour"]) == world.time_of_day, "world time must survive save/load")
	var count_before: int = world._streamed_visual_nodes.size()
	var old_vegetation: WeakRef
	if count_before > 0:
		var old_cell: Vector2i = world._streamed_visual_nodes.keys()[0]
		if not world._streamed_visual_nodes[old_cell].is_empty():
			old_vegetation = weakref(world._streamed_visual_nodes[old_cell][0])
	world.update_streamed_visuals(Vector3(145, 0, -145))
	await process_frame
	if old_vegetation != null:
		assert(old_vegetation.get_ref() == null, "unloaded vegetation nodes must actually be freed")
	for frame in range(180):
		if not world._streamed_visual_nodes.is_empty():
			break
		await process_frame
	assert(world._streamed_visual_nodes.size() > 0 and world._streamed_visual_nodes.size() < world._vegetation_paths.size(), "only nearby vegetation cells should be allocated")
	assert(world._stream_center == world.stream_cell(Vector3(145, 0, -145)), "visual chunks did not follow player")
	print("CHUNK STREAMING: PASS; initial visual cells=", count_before, " total cells=", world._vegetation_paths.size(), "; initial instances=", initial_instances, " total instances=", total_instances)
	restored.queue_free()
	game.queue_free()
	await process_frame
	quit()
