extends SceneTree
## Run explicitly when authoring the map; never invoked during gameplay.
const DATA_PATH := "res://assets/world/baked_world.res"

func _initialize() -> void:
	call_deferred("run")

func set_owners(node: Node, root_node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = root_node
		set_owners(child, root_node)

func run() -> void:
	var world: Node = load("res://scripts/world_builder.gd").new()
	root.add_child(world)
	world.build_procedural()
	var data: Resource = load("res://scripts/baked_world_data.gd").new()
	data.playable_bounds = world.BOUNDS
	data.terrain_extent = world.TERRAIN_EXTENT
	data.terrain_segments = world.TERRAIN_SEGMENTS
	data.terrain_heights = world._terrain_heights
	data.terrain_colors = world._terrain_colors
	data.terrain_grid_size = world._terrain_grid_size
	data.sites = world._sites
	data.ponds = world._ponds
	data.roads = world.roads
	data.road_cells = world._road_cells
	data.road_lamps = world.road_lamps
	data.tree_points = world._tree_points
	data.tree_spacing_cells = world._tree_spacing_cells
	data.grass_points = world.grass_points
	data.map_image = world._paint_map_image(640)
	if data.map_image == null:
		push_error("Map image baking failed; world asset was not replaced.")
		quit(1)
		return
	var vegetation: Dictionary = _bake_vegetation(world)
	if vegetation.is_empty():
		push_error("Vegetation baking failed; world asset was not replaced.")
		quit(1)
		return
	data.vegetation_paths = vegetation["paths"]
	data.vegetation_counts = vegetation["counts"]
	var static_root := Node3D.new()
	static_root.name = "AuthoredWorld"
	root.add_child(static_root)
	data.terrain_tiles = _bake_terrain_tiles(world, static_root)
	if data.terrain_tiles.is_empty():
		push_error("Terrain baking failed; world asset was not replaced.")
		quit(1)
		return
	var streamed_nodes := _streamed_nodes(world)
	data.static_paths = _bake_static_chunks(world, streamed_nodes)
	if data.static_paths.is_empty():
		push_error("Static chunk baking failed; world asset was not replaced.")
		quit(1)
		return
	for node: Node in world.get_children():
		if node.name == "FrontierAtmosphere" or node.name == "FrontierSun" or node.name == "RollingTerrain" or node in streamed_nodes:
			continue
		world.remove_child(node)
		static_root.add_child(node)
	set_owners(static_root, static_root)
	var packed := PackedScene.new()
	var pack_error := packed.pack(static_root)
	if pack_error != OK:
		push_error("Could not pack authored world: %d" % pack_error)
		quit(1)
		return
	data.static_scene = packed
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/world"))
	var error := ResourceSaver.save(data, DATA_PATH, ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("Could not save authored world: %d" % error)
		quit(1)
		return
	print("BAKED WORLD: ", DATA_PATH, " vegetation cells=", data.vegetation_paths.size())
	static_root.queue_free()
	world.queue_free()
	await process_frame
	quit()

func _streamed_nodes(world: Node) -> Array:
	var result: Array = []
	for nodes: Array in world._streamed_visual_nodes.values():
		result.append_array(nodes)
	return result

func _bake_vegetation(world: Node) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/world/vegetation"))
	var paths: Dictionary = {}
	var counts: Dictionary = {}
	var meshes: Dictionary = {}
	for cell: Vector2i in world._streamed_visual_data:
		var tile: Resource = load("res://scripts/baked_vegetation_tile.gd").new()
		var groups: Array[Dictionary] = []
		for group: Dictionary in world._streamed_visual_data[cell]:
			var label: String = group["name"]
			if not meshes.has(label):
				var mesh_path := "res://assets/world/vegetation/mesh_%s.res" % label
				var mesh_error := ResourceSaver.save(group["mesh"], mesh_path, ResourceSaver.FLAG_COMPRESS)
				if mesh_error != OK:
					push_error("Could not save vegetation mesh %s: %d" % [label, mesh_error])
					return {}
				meshes[label] = mesh_path
			counts[label] = int(counts.get(label, 0)) + group["entries"].size()
			groups.append({"name": label, "mesh_path": meshes[label], "entries": group["entries"], "colors": group["colors"], "shadows": group["shadows"]})
		tile.groups = groups
		var path := "res://assets/world/vegetation/cell_%d_%d.res" % [cell.x, cell.y]
		var error := ResourceSaver.save(tile, path, ResourceSaver.FLAG_COMPRESS)
		if error != OK:
			push_error("Could not save vegetation cell %s: %d" % [path, error])
			return {}
		paths[cell] = path
	return {"paths": paths, "counts": counts}

func _bake_static_chunks(world: Node, streamed_nodes: Array) -> Dictionary:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/world/static"))
	var chunks: Dictionary = {}
	for node: Node in world.get_children():
		if not node is Node3D or node is MultiMeshInstance3D or node in streamed_nodes:
			continue
		var node_name := str(node.name)
		if node_name in ["FrontierSun", "RollingTerrain", "RoadNetwork"] or node_name.begins_with("FenPool") or node_name.begins_with("FrontierBoundary") or node is StaticBody3D:
			continue
		var cell: Vector2i = world.stream_cell((node as Node3D).position)
		if not chunks.has(cell):
			var holder := Node3D.new()
			holder.name = "StaticCell_%d_%d" % [cell.x, cell.y]
			root.add_child(holder)
			chunks[cell] = holder
		world.remove_child(node)
		chunks[cell].add_child(node)
	var paths: Dictionary = {}
	for cell: Vector2i in chunks:
		var holder: Node3D = chunks[cell]
		set_owners(holder, holder)
		var packed := PackedScene.new()
		var error := packed.pack(holder)
		if error != OK:
			push_error("Could not pack static cell %s: %d" % [cell, error])
			return {}
		var path := "res://assets/world/static/cell_%d_%d.scn" % [cell.x, cell.y]
		error = ResourceSaver.save(packed, path, ResourceSaver.FLAG_COMPRESS)
		if error != OK:
			push_error("Could not save static cell %s: %d" % [cell, error])
			return {}
		paths[cell] = path
		holder.queue_free()
	return paths

func _sample_indices(count: int, stride: int) -> Array[int]:
	var result: Array[int] = []
	for value in range(0, count + 1, stride):
		result.append(value)
	if result.back() != count:
		result.append(count)
	return result

func _terrain_mesh(source: Array, grid_size: int, x0: int, z0: int, width: int, depth: int, stride: int, material: Material) -> ArrayMesh:
	var xs := _sample_indices(width, stride)
	var zs := _sample_indices(depth, stride)
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var source_positions: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
	var source_normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
	var source_colors: PackedColorArray = source[Mesh.ARRAY_COLOR]
	var source_uvs: PackedVector2Array = source[Mesh.ARRAY_TEX_UV]
	for z in zs:
		for x in xs:
			var source_index := (z0 + z) * grid_size + x0 + x
			positions.append(source_positions[source_index])
			var normal := source_normals[source_index]
			normals.append(normal)
			var tangent := (Vector3.RIGHT - normal * normal.x).normalized()
			tangents.append_array([tangent.x, tangent.y, tangent.z, -1.0])
			colors.append(source_colors[source_index])
			uvs.append(source_uvs[source_index])
	for z in range(zs.size() - 1):
		for x in range(xs.size() - 1):
			var a := z * xs.size() + x
			var b := a + 1
			var c := a + xs.size()
			var d := c + 1
			indices.append_array([a, b, c, b, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, material)
	return mesh

func _bake_terrain_tiles(world: Node, static_root: Node3D) -> Dictionary:
	var source_node := world.get_node("RollingTerrain") as MeshInstance3D
	var source: Array = source_node.mesh.surface_get_arrays(0)
	var material: Material = source_node.mesh.surface_get_material(0)
	var result: Dictionary = {}
	var grid_size: int = world.TERRAIN_SEGMENTS + 1
	var tile_segments: int = world.TERRAIN_TILE_SEGMENTS
	var tile_count := ceili(float(world.TERRAIN_SEGMENTS) / float(tile_segments))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/world/terrain"))
	for z in range(tile_count):
		for x in range(tile_count):
			var x0 := x * tile_segments
			var z0 := z * tile_segments
			var width := mini(tile_segments, world.TERRAIN_SEGMENTS - x0)
			var depth := mini(tile_segments, world.TERRAIN_SEGMENTS - z0)
			var high := _terrain_mesh(source, grid_size, x0, z0, width, depth, 1, material)
			var tile: Resource = load("res://scripts/baked_terrain_tile.gd").new()
			tile.mesh = high
			tile.collision = high.create_trimesh_shape()
			var path := "res://assets/world/terrain/tile_%02d_%02d.res" % [x, z]
			var error := ResourceSaver.save(tile, path, ResourceSaver.FLAG_COMPRESS)
			if error != OK:
				push_error("Could not save terrain tile %s: %d" % [path, error])
				return {}
			result[Vector2i(x, z)] = path
			var low := MeshInstance3D.new()
			low.name = "TerrainFar_%02d_%02d" % [x, z]
			low.mesh = _terrain_mesh(source, grid_size, x0, z0, width, depth, 4, material)
			low.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			static_root.add_child(low)
			# A lightweight distant collider prevents a gap if a player reaches a
			# tile before its high-detail asset has finished preloading.
			low.create_trimesh_collision()
	return result
