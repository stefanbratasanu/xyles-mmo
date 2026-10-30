extends SceneTree
const Terrain := preload("res://scripts/world_editor/terrain_grid.gd")

func _initialize() -> void:
	var grid = Terrain.new()
	assert(grid.initialize(2, 1.0, false) == OK)
	assert(is_nan(grid.sample_height(Vector2.ZERO)))
	grid.paint_ground(Vector2(-0.5, -0.5), 0.6, true)
	assert(is_equal_approx(grid.sample_height(Vector2(-0.5, -0.5)), 0.0))
	assert(is_nan(grid.sample_height(Vector2(0.5, 0.5))))
	# Check both sides of the same diagonal used by the baked terrain.
	grid.heights[0] = 0.0
	grid.heights[1] = 2.0
	grid.heights[3] = 4.0
	grid.heights[4] = 8.0
	assert(is_equal_approx(grid.sample_height(Vector2(-0.75, -0.75)), 1.5))
	assert(is_equal_approx(grid.sample_height(Vector2(-0.25, -0.25)), 5.5))
	grid.sculpt(Vector2(-1.0, -1.0), 0.5, 2.0)
	assert(is_equal_approx(grid.heights[0], 2.0))
	grid.paint_surface(Vector2(-1.0, -1.0), 0.2, 1, Color.GREEN)
	var mesh: ArrayMesh = grid.build_tile(0, 0, 2, 2)
	assert(mesh.get_surface_count() == 1)
	assert(mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size() == 6)
	assert(mesh.create_trimesh_shape() != null)
	var copy = Terrain.new()
	assert(copy.from_data(grid.to_data()) == OK)
	assert(is_equal_approx(copy.heights[0], 2.0))
	assert(is_nan(copy.sample_height(Vector2(0.5, 0.5))))
	var json := JSON.new()
	assert(json.parse(JSON.stringify(grid.to_data())) == OK)
	assert(copy.from_data(json.data) == OK)
	assert(copy.surfaces[0] == 1)
	assert(copy.colors[0].is_equal_approx(Color.GREEN))
	var invalid: Dictionary = grid.to_data()
	invalid["cells"] = []
	assert(copy.from_data(invalid) == ERR_INVALID_DATA)
	copy.clear()
	assert(is_nan(copy.sample_height(Vector2(-0.5, -0.5))))
	assert(copy.build_tile(0, 0, 2, 2).get_surface_count() == 0)
	var baked: Resource = load("res://assets/world/baked_world.res")
	assert(copy.import_baked(baked) == OK)
	assert(copy.heights.size() == baked.terrain_heights.size())
	assert(is_equal_approx(copy.heights[100], baked.terrain_heights[100]))
	print("PASS: editable terrain import, clearing, brushes, sampling and round-trip")
	quit()
