extends RefCounted
## Applies a validated published snapshot to an already-built world. The baked
## source files stay untouched and can be restored by choosing the original.

const Grid := preload("res://scripts/world_editor/terrain_grid.gd")
const Catalog := preload("res://scripts/world_editor/asset_catalog.gd")
const Store := preload("res://scripts/world_editor/draft_store.gd")
const Zones := preload("res://scripts/world_editor/zone_data.gd")
const FORMAT := 1

static func validate(payload: Dictionary, world: Node3D, require_spawns: bool = true) -> String:
	if int(payload.get("format", 0)) != FORMAT or not payload.get("placements", []) is Array:
		return "Unsupported or damaged map draft."
	var zone_problem := Zones.validate(payload.get("zones", []), world.BOUNDS)
	if not zone_problem.is_empty():
		return zone_problem
	if not payload.get("removed_trees", []) is Array:
		return "The removed tree list is invalid."
	for tree in payload.get("removed_trees", []):
		if not tree is Dictionary or tree_info(world, tree).is_empty():
			return "A removed original tree no longer exists in this map version."
	if not payload.get("static_edits", []) is Array:
		return "The original scenery edit list is invalid."
	for edit in payload.get("static_edits", []):
		if not edit is Dictionary or not _valid_static_edit(world, edit):
			return "An edited original object no longer exists or has invalid coordinates."
	if payload.get("terrain", null) != null:
		if not payload["terrain"] is Dictionary:
			return "The terrain data is invalid."
		var grid = Grid.new()
		if grid.from_data(payload["terrain"]) != OK or grid.segments != world.TERRAIN_SEGMENTS or not is_equal_approx(grid.extent, world.TERRAIN_EXTENT):
			return "The terrain grid is invalid or belongs to another map."
		# Every existing game spawn must have a surface. Without this check the
		# player, NPCs or quest enemies can be created over the void.
		var required: Array[Vector3] = [world.player_spawn, world.player_spawn + Vector3(0.4, 0.0, 0.6), world.camp_position, world.smith_position, world.quest_spawn]
		if not bool(payload.get("clear_base", false)):
			required.append(world.waygate_position)
		if world.boss_spawn_enabled:
			required.append(world.boss_spawn)
		for spawn: Vector3 in world.normal_spawns:
			required.append(spawn)
		for spawn: Vector3 in required:
			if require_spawns and not is_finite(grid.sample_height(Vector2(spawn.x, spawn.z))):
				return "Paint ground at gameplay spawn X %.1f, Z %.1f before applying. Existing spawn positions remain active." % [spawn.x, spawn.z]
	elif bool(payload.get("clear_base", false)):
		return "A cleared map needs terrain before it can be applied."
	var placements: Array = payload.get("placements", [])
	if placements.size() > 20000:
		return "This draft contains too many individual objects."
	for item in placements:
		if not item is Dictionary or not Catalog.ASSETS.has(str(item.get("asset", ""))):
			return "A placed asset is missing or unsupported."
		var position: Variant = item.get("position")
		if not position is Array or position.size() != 3:
			return "A placed asset has an invalid position."
		for value in position:
			if not (value is float or value is int) or not is_finite(float(value)):
				return "A placed asset has an invalid position."
		var rotation: Variant = item.get("rotation", 0.0)
		var scale_value: Variant = item.get("scale", 1.0)
		if not (rotation is float or rotation is int) or not is_finite(float(rotation)) or not (scale_value is float or scale_value is int) or not is_finite(float(scale_value)) or float(scale_value) < 0.05 or float(scale_value) > 20.0:
			return "A placed asset has an invalid rotation or scale."
	return ""

static func make_materials(world: Node3D) -> Dictionary:
	if world._materials.is_empty():
		world._create_materials()
	var grass: StandardMaterial3D = world._materials["terrain"]
	var dirt: StandardMaterial3D = world._materials["road_flat"].duplicate()
	dirt.vertex_color_use_as_albedo = true
	var rock: StandardMaterial3D = world._materials["natural_rock"].duplicate()
	rock.vertex_color_use_as_albedo = true
	return {0: grass, 1: grass, 2: dirt, 3: rock}

static func remove_node(node: Node) -> void:
	if node.get_parent() != null:
		node.get_parent().remove_child(node)
	node.queue_free()

static func apply(world: Node3D, payload: Dictionary, require_spawns: bool = true) -> String:
	if bool(payload.get("original", false)):
		return ""
	var problem := validate(payload, world, require_spawns)
	if not problem.is_empty():
		return problem
	var clear_base := bool(payload.get("clear_base", false))
	var terrain_data: Variant = payload.get("terrain", null)
	var grid = null
	if terrain_data != null:
		grid = Grid.new()
		if grid.from_data(terrain_data) != OK:
			return "Could not read terrain data."
	var materials := make_materials(world)
	world._finish_running_stream()
	world._terrain_pending.clear()
	world._static_pending.clear()
	world._vegetation_pending.clear()
	if clear_base:
		clear_world(world)
	else:
		if not payload.get("removed_trees", []).is_empty():
			apply_tree_removals(world, payload["removed_trees"])
		if not payload.get("static_edits", []).is_empty():
			apply_static_edits(world, payload["static_edits"])
	if grid != null:
		if not clear_base:
			for node: Node in world._terrain_active.values():
				remove_node(node)
			for node: Node in world._terrain_far.values():
				remove_node(node)
			world._terrain_active.clear()
			world._terrain_far.clear()
		world._terrain_paths.clear()
		world.editor_terrain = grid
		world._terrain_heights = grid.heights
		world._terrain_colors = grid.colors
		world._terrain_grid_size = grid.segments + 1
		world._authored_map = null
		world._map_cache = null
		_build_terrain(world, grid, materials)
		world._finalize_spawns()
		if not clear_base:
			_refresh_existing_surfaces(world)
	Zones.apply(world, payload.get("zones", []))
	for entry: Dictionary in payload.get("placements", []):
		var instance := Catalog.create(world, str(entry["asset"]))
		if instance == null:
			return "Could not load placed asset: " + str(entry["asset"])
		var p: Array = entry["position"]
		instance.position = Vector3(float(p[0]), float(p[1]), float(p[2]))
		instance.rotation.y = float(entry.get("rotation", 0.0))
		instance.scale = Vector3.ONE * float(entry.get("scale", 1.0))
		world.add_child(instance)
		if bool(Catalog.ASSETS[str(entry["asset"])].get("tree", false)):
			var point := Vector2(instance.position.x, instance.position.z)
			world._tree_points.append(point)
			world._reserve_tree_position(point)
	sync_lakes(world, payload.get("placements", []))
	world._authored_map = null if clear_base or grid != null or not payload.get("placements", []).is_empty() else world._authored_map
	world._map_cache = null
	world._refresh_baked_dynamic_nodes()
	world._apply_time_of_day()
	return ""

static func _valid_static_edit(world: Node3D, edit: Dictionary) -> bool:
	var cell_data: Variant = edit.get("cell")
	var path := str(edit.get("path", ""))
	if not cell_data is Array or cell_data.size() != 2 or path.is_empty() or path.begins_with("/") or ".." in path:
		return false
	var cell := Vector2i(int(cell_data[0]), int(cell_data[1]))
	if not world._static_paths.has(cell):
		return false
	var scene: PackedScene = load(world._static_paths[cell])
	if scene == null:
		return false
	var holder := scene.instantiate()
	var exists := holder.get_node_or_null(NodePath(path)) is Node3D
	holder.free()
	if not exists:
		return false
	if bool(edit.get("removed", false)):
		return true
	for field: String in ["position", "rotation", "scale"]:
		var values: Variant = edit.get(field)
		if not values is Array or values.size() != 3:
			return false
		for value in values:
			if not (value is int or value is float) or not is_finite(float(value)):
				return false
	return true

static func apply_static_edits(world: Node3D, edits: Array) -> void:
	set_static_edits(world, edits)
	for cell: Vector2i in world.editor_static_edits:
		if not world._static_active.has(cell):
			continue
		remove_node(world._static_active[cell])
		world._static_active.erase(cell)
		world._activate_static_cell(cell, load(world._static_paths[cell]) as PackedScene)

static func set_static_edits(world: Node3D, edits: Array) -> void:
	world.editor_static_edits.clear()
	for edit: Dictionary in edits:
		var cell := Vector2i(int(edit["cell"][0]), int(edit["cell"][1]))
		if not world.editor_static_edits.has(cell):
			world.editor_static_edits[cell] = []
		world.editor_static_edits[cell].append(edit.duplicate(true))

static func tree_info(world: Node3D, item: Dictionary) -> Dictionary:
	var cell_data: Variant = item.get("cell")
	if not cell_data is Array or cell_data.size() != 2:
		return {}
	var cell := Vector2i(int(cell_data[0]), int(cell_data[1]))
	if not world._vegetation_paths.has(cell):
		return {}
	var tile: Resource = load(world._vegetation_paths[cell])
	if tile == null:
		return {}
	var group_name := str(item.get("group", ""))
	var index := int(item.get("index", -1))
	var mapping := {"FoothillPines": "pine", "MeadowGrass": "grass", "Underbrush": "bush", "Wildflowers": "flowers"}
	for group: Dictionary in tile.groups:
		if str(group["name"]) == group_name and (group_name.begins_with("Trees_") or mapping.has(group_name)) and index >= 0 and index < group["entries"].size():
			var asset := str(mapping[group_name]) if mapping.has(group_name) else group_name.trim_prefix("Trees_")
			if asset == "dead": asset = "dead_tree"
			return {"transform": group["entries"][index], "asset": asset, "is_tree": bool(Catalog.ASSETS[asset].get("tree", false))}
	return {}

static func apply_tree_removals(world: Node3D, items: Array) -> void:
	var affected: Dictionary = {}
	world.editor_removed_trees.clear()
	for item: Dictionary in items:
		var cell := Vector2i(int(item["cell"][0]), int(item["cell"][1]))
		var info := tree_info(world, item)
		if info.is_empty():
			continue
		var key := "%d,%d:%s" % [cell.x, cell.y, str(item["group"])]
		if not world.editor_removed_trees.has(key):
			world.editor_removed_trees[key] = {}
		world.editor_removed_trees[key][int(item["index"])] = true
		affected[cell] = true
		if not bool(info["is_tree"]):
			continue
		var position: Vector3 = (info["transform"] as Transform3D).origin
		for index in range(world._tree_points.size() - 1, -1, -1):
			if (world._tree_points[index] as Vector2).distance_squared_to(Vector2(position.x, position.z)) < 0.0001:
				world._tree_points.remove_at(index)
				break
	world._tree_spacing_cells.clear()
	for point: Vector2 in world._tree_points:
		world._reserve_tree_position(point)
	for cell: Vector2i in affected:
		if not world._streamed_visual_nodes.has(cell):
			continue
		for node: Node in world._streamed_visual_nodes[cell]:
			remove_node(node)
		world._streamed_visual_nodes.erase(cell)
		world._activate_vegetation_tile(cell, load(world._vegetation_paths[cell]))
	world._authored_map = null
	world._map_cache = null

static func clear_world(world: Node3D) -> void:
	world.editor_cleared_base = true
	world._finish_running_stream()
	world._terrain_pending.clear()
	world._static_pending.clear()
	world._vegetation_pending.clear()
	for child: Node in world.get_children():
		if child.name != "FrontierAtmosphere" and child.name != "FrontierSun":
			remove_node(child)
	world._streamed_visual_nodes.clear()
	world._streamed_visual_data.clear()
	world._vegetation_paths.clear()
	world._static_active.clear()
	world._static_paths.clear()
	world._terrain_active.clear()
	world._terrain_far.clear()
	world.roads.clear()
	world._road_cells.clear()
	world.road_lamps.clear()
	world._ponds.clear()
	world.editor_lakes.clear()
	world.editor_zones.clear()
	world.editor_zone_cells.clear()
	world._tree_points.clear()
	world._tree_spacing_cells.clear()
	world.grass_points.clear()
	world._refresh_baked_dynamic_nodes()

static func sync_lakes(world: Node3D, items: Array) -> void:
	world.editor_lakes.clear()
	for item: Dictionary in items:
		if str(item.get("asset", "")) != "lake":
			continue
		var p: Array = item["position"]
		world.editor_lakes.append({"center": Vector2(float(p[0]), float(p[2])), "radius": 8.0 * float(item.get("scale", 1.0)), "level": float(p[1]), "depth": 1.0, "phase": 0.0, "editor": true})
	world._map_cache = null

static func enable_editor_terrain(world: Node3D, grid: RefCounted, build_existing: bool) -> void:
	world._finish_running_stream()
	world._terrain_pending.clear()
	for node: Node in world._terrain_active.values():
		remove_node(node)
	for node: Node in world._terrain_far.values():
		remove_node(node)
	world._terrain_active.clear()
	world._terrain_far.clear()
	world._terrain_paths.clear()
	world.editor_terrain = grid
	world._terrain_heights = grid.heights
	world._terrain_colors = grid.colors
	world._terrain_grid_size = grid.segments + 1
	world._authored_map = null
	world._map_cache = null
	if build_existing:
		_build_terrain(world, grid, make_materials(world))

static func refresh_brush(world: Node3D, grid: RefCounted, center: Vector2, radius: float) -> void:
	world._terrain_heights = grid.heights
	world._terrain_colors = grid.colors
	var step: int = world.TERRAIN_TILE_SEGMENTS
	var spacing: float = grid.extent * 2.0 / grid.segments
	var x0 := clampi(floori((center.x - radius + grid.extent) / spacing / step) - 1, 0, ceili(float(grid.segments) / step) - 1)
	var x1 := clampi(floori((center.x + radius + grid.extent) / spacing / step) + 1, 0, ceili(float(grid.segments) / step) - 1)
	var z0 := clampi(floori((center.y - radius + grid.extent) / spacing / step) - 1, 0, ceili(float(grid.segments) / step) - 1)
	var z1 := clampi(floori((center.y + radius + grid.extent) / spacing / step) + 1, 0, ceili(float(grid.segments) / step) - 1)
	var materials := make_materials(world)
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var name := "EditedTerrain_%d_%d" % [x * step, z * step]
			var old: Node = world.get_node_or_null(name)
			if old != null:
				remove_node(old)
			_build_one_tile(world, grid, x * step, z * step, materials)
	if not world.roads.is_empty() and world._road_distance(center) <= radius + world.ROAD_WIDTH:
		_refresh_roads(world)
	for index in world._ponds.size():
		var pond: Dictionary = world._ponds[index]
		if center.distance_to(pond["center"]) <= radius + float(pond["radius"]) * 1.5:
			var water := world.get_node_or_null("FenPool%d" % (index + 1)) as MeshInstance3D
			if water != null:
				water.mesh = world._pond_water_mesh(pond)
	world._map_cache = null

static func _refresh_roads(world: Node3D) -> void:
	for name: String in ["RoadNetwork", "CampRoadClearing"]:
		var old: Node = world.get_node_or_null(name)
		if old != null:
			remove_node(old)
	world._create_roads()

static func _refresh_existing_surfaces(world: Node3D) -> void:
	if not world.roads.is_empty():
		_refresh_roads(world)
	for index in world._ponds.size():
		var water := world.get_node_or_null("FenPool%d" % (index + 1)) as MeshInstance3D
		if water != null:
			water.mesh = world._pond_water_mesh(world._ponds[index])

static func _build_terrain(world: Node3D, grid: RefCounted, materials: Dictionary) -> void:
	var step: int = world.TERRAIN_TILE_SEGMENTS
	for z in range(0, grid.segments, step):
		for x in range(0, grid.segments, step):
			_build_one_tile(world, grid, x, z, materials)

static func _build_one_tile(world: Node3D, grid: RefCounted, x: int, z: int, materials: Dictionary) -> void:
	var step: int = world.TERRAIN_TILE_SEGMENTS
	var mesh: ArrayMesh = grid.build_tile(x, z, mini(step, grid.segments - x), mini(step, grid.segments - z), materials)
	if mesh == null or mesh.get_surface_count() == 0:
		return
	var visual := MeshInstance3D.new()
	visual.name = "EditedTerrain_%d_%d" % [x, z]
	visual.mesh = mesh
	world.add_child(visual)
	visual.create_trimesh_collision()
