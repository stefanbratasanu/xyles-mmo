extends SceneTree
## Checks the actual baked assets, not only the code used to generate them.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world: Node = load("res://scripts/world_builder.gd").new()
	root.add_child(world)
	world.build()
	assert(world._terrain_paths.size() > 100, "the terrain must be tiled")
	assert(world._vegetation_paths.size() > 100, "the forest must be tiled")
	assert(world._static_paths.size() > 10, "landmarks and props must be tiled")
	var trees := 0
	for cell: Vector2i in world._vegetation_paths:
		var path: String = world._vegetation_paths[cell]
		var tile: Resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
		assert(tile != null, "missing vegetation tile: %s" % path)
		for group: Dictionary in tile.groups:
			assert(ResourceLoader.exists(group["mesh_path"]), "missing shared vegetation mesh")
			var label := str(group["name"])
			if not label.begins_with("Trees_"):
				continue
			var kind := label.trim_prefix("Trees_")
			for transform: Transform3D in group["entries"]:
				var pos := transform.origin
				var zone: Dictionary = world.zone_at_xz(Vector2(pos.x, pos.z))
				assert((zone["trees"] as Dictionary).has(kind), "%s tree is in the %s biome at %s" % [kind, zone["id"], pos])
				trees += 1
	assert(trees > 1500, "the baked world needs a populated forest")
	for kind: String in ["oak", "birch", "pine", "dead"]:
		var tree_mesh := load("res://assets/world/vegetation/mesh_Trees_%s.res" % kind) as Mesh
		var bark := tree_mesh.surface_get_material(0) as StandardMaterial3D
		assert(bark != null and bark.albedo_color.r <= 1.0 and bark.albedo_color.g <= 1.0, "tree bark must not be brightened")
	var bush_mesh := load("res://assets/world/vegetation/mesh_Underbrush.res") as Mesh
	var foliage: Array = bush_mesh.surface_get_arrays(1)
	assert((foliage[Mesh.ARRAY_INDEX] as PackedInt32Array).size() >= 300, "bush foliage must have dense leaf cards")
	# Inspect every baked meadow location, including the footprint around each
	# patch, instead of only testing the offline placement function.
	for point: Vector2 in world.grass_points:
		assert(not world._in_pond(point, 0.79), "meadow patch is too close to water: %s" % point)
		if world._in_pond(point, 4.0):
			for offset: Vector2 in [Vector2.ZERO, Vector2(0.8, 0), Vector2(-0.8, 0), Vector2(0, 0.8), Vector2(0, -0.8)]:
				assert(world.water_depth_at(point.x + offset.x, point.y + offset.y) <= 0.0, "grass patch overlaps water")
	var shore := world.find_child("ShoreReeds", false, false) as MultiMeshInstance3D
	assert(shore != null and shore.has_meta("shore_points"), "shore grass audit missing")
	var shore_points: PackedVector2Array = shore.get_meta("shore_points")
	assert(shore_points.size() == shore.multimesh.instance_count, "shore grass audit disagrees with instances")
	for point: Vector2 in shore_points:
		assert(not world._in_pond(point, 1.19), "shore grass is too close to water: %s" % point)
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(5, 7), Vector2i(9, 10), Vector2i(13, 13)]:
		var tile: Resource = ResourceLoader.load(world._terrain_paths[cell], "", ResourceLoader.CACHE_MODE_IGNORE)
		assert(tile != null and tile.mesh != null and tile.collision != null, "terrain tile or collision missing")
		var vertices: PackedVector3Array = tile.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var tangents: PackedFloat32Array = tile.mesh.surface_get_arrays(0)[Mesh.ARRAY_TANGENT]
		var terrain_material := tile.mesh.surface_get_material(0) as StandardMaterial3D
		assert(tangents.size() == vertices.size() * 4 and terrain_material.normal_enabled and terrain_material.normal_texture != null, "detailed ground normal map requires tangents")
		for index in range(0, vertices.size(), 67):
			var p := vertices[index]
			assert(absf(p.y - world.surface_height_at(p.x, p.z)) < 0.003, "tile seam disagrees with the shared terrain grid")
	print("BAKED WORLD INTEGRITY: PASS; validated trees=", trees, " terrain tiles=", world._terrain_paths.size())
	world.queue_free()
	await process_frame
	quit()
