extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var grid = load("res://scripts/world_editor/terrain_grid.gd").new()
	assert(grid.import_baked(load("res://assets/world/baked_world.res")) == OK)
	var at := Vector2(-33.4, 32.4)
	grid.sculpt(at, 12.0, 4.0)
	var expected: float = grid.sample_height(at)
	var game = load("res://scenes/main.tscn").instantiate()
	game.set_meta("editor_map_payload", {"format": 1, "clear_base": true, "terrain": grid.to_data(), "placements": []})
	root.add_child(game)
	await process_frame
	await physics_frame
	assert(absf(game.world.player_spawn.y - expected) < 0.01)
	assert(game.world.roads.is_empty() and game.world.ponds().is_empty())
	var query := PhysicsRayQueryParameters3D.create(Vector3(at.x, expected + 20.0, at.y), Vector3(at.x, expected - 20.0, at.y), 1)
	var hit: Dictionary = game.world.get_world_3d().direct_space_state.intersect_ray(query)
	assert(not hit.is_empty())
	assert(absf(hit["position"].y - expected) < 0.05)
	game.queue_free()
	await process_frame
	print("PASS: game startup uses edited terrain heights and collision")
	quit()
