extends SceneTree
const Runtime := preload("res://scripts/world_editor/map_runtime.gd")
const Grid := preload("res://scripts/world_editor/terrain_grid.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scripts/world_builder.gd").new()
	root.add_child(world)
	world.build()
	var invalid := {"format": 1, "clear_base": true, "terrain": null, "placements": []}
	assert(not Runtime.validate(invalid, world).is_empty())
	var grid = Grid.new()
	assert(grid.import_baked(load("res://assets/world/baked_world.res")) == OK)
	var point := Vector2(world.player_spawn.x, world.player_spawn.z)
	grid.sculpt(point, 10.0, 3.0)
	var expected: float = grid.sample_height(point)
	var payload := {"format": 1, "clear_base": true, "terrain": grid.to_data(), "placements": [{"asset": "oak", "position": [0.0, 2.0, 0.0], "rotation": 0.3, "scale": 1.0}, {"asset": "lake", "position": [point.x, expected + 0.4, point.y], "rotation": 0.0, "scale": 1.0}]}
	assert(Runtime.apply(world, payload).is_empty())
	assert(is_equal_approx(world.height_at(point.x, point.y), expected))
	assert(world.roads.is_empty() and world.ponds().size() == 1)
	assert(absf(world.water_depth_at(point.x, point.y) - 0.4) < 0.01)
	assert(world._vegetation_paths.is_empty() and world._static_paths.is_empty())
	assert(world.get_node_or_null("Placed_oak") != null)
	assert(not world.find_children("EditedTerrain_*", "MeshInstance3D", false, false).is_empty())
	assert(world.map_texture(64) != null)
	world.free()
	print("PASS: editor map applies terrain, collision, clearing, objects and map data")
	quit()
