extends Node3D
class_name XylesWorldBuilder

## Map I - The Ashen Frontier.
##
## Every visual is original Godot geometry, one of the generated nature textures
## in res://assets/textures, or one of the low-poly trees exported from Blender
## into res://assets/models/trees. Terrain, roads, vegetation and landmarks are
## baked offline from this design and loaded in chunks during play.
##
## Zones are organic blobs defined by a centre, a radius and a wavy edge. The
## same definitions drive region detection, terrain colour, enemy levels, tree
## selection and the full-screen world map: one source of truth.

## Three times the former playable area, without stretching character scale.
const BOUNDS := 256.3435
## Preserve roughly the old terrain sampling density across the larger map.
const TERRAIN_EXTENT := 332.8888888889
const TERRAIN_SEGMENTS := 428
## Beyond the playable square the height field rises into a mountain rim. The rim
## is part of the terrain mesh, not a ring of separate cones, so peaks, slopes and
## collision all agree with the ground the player sees.
const RIM_START := 268.3435
const RIM_END := 308.3435
const RIM_HEIGHT := 32.0
## After the crest the height falls away again so the square edge of the terrain
## mesh hides behind the range instead of cutting a straight line across the sky.
const RIM_FALL_START := 314.3435
const RIM_FALL_END := 331.3435
const ROAD_WIDTH := 3.7
const ROAD_LIFT := 0.055
const DAY_SECONDS := 900.0
## Nearby cells are instantiated with a buffer for the orbit camera; distant
## terrain and landmarks remain visible beyond the streamed vegetation.
const STREAM_CELL_SIZE := 48.0
const STREAM_CELL_RADIUS := 2
const TERRAIN_TILE_SEGMENTS := 32
const TERRAIN_TILE_RADIUS := 2

const GRASS_TEXTURE := preload("res://assets/textures/polyhaven/forest_ground_tinted.png")
const GROUND_NORMAL := preload("res://assets/textures/polyhaven/forest_ground_04-nor_gl.jpg")
const ROCK_TEXTURE := preload("res://assets/textures/polyhaven/rock_face_03-Diffuse.jpg")
const ROCK_NORMAL := preload("res://assets/textures/polyhaven/rock_face_03-nor_gl.jpg")
const GRASS_BLADES := preload("res://assets/textures/grass_blades.png")
const ROAD_TEXTURE := preload("res://assets/textures/terrain_road.png")
const BARK_TEXTURE := preload("res://assets/textures/bark.png")
const LEAF_TEXTURE := preload("res://assets/textures/leaves.png")
const NEEDLE_TEXTURE := preload("res://assets/textures/needles.png")
## Alpha cards drawn by assets/models/trees/make_foliage_textures.py.
const LEAF_CARD_TEXTURE := preload("res://assets/textures/leaf_card.png")
const NEEDLE_CARD_TEXTURE := preload("res://assets/textures/needle_card.png")

var player_spawn: Vector3 = Vector3(-33.4, 0.0, 32.4)
var camp_position: Vector3 = Vector3(-36.0, 0.0, 32.0)
var quest_spawn: Vector3 = Vector3(100.0, 0.0, -95.0)
var boss_spawn: Vector3 = Vector3(-138.0, 0.0, -138.0)
## Empty means unrestricted (the current Hollow Regent rule). A future timed
## boss may set [start_hour, end_hour], including a window crossing midnight.
var boss_spawn_window: Array[float] = []
## The Hollow Regent is being reworked. Its spawn slot, map marker and quest
## stage stay in the data so the future boss can reuse them; this flag keeps the
## enemy out of the world in the meantime.
var boss_spawn_enabled: bool = false
## Original, non-interactive exploration landmarks on the extended roads.
var frontier_landmarks: Array[Dictionary] = [
	{"name": "THORN WATCH", "at": Vector2(-194.0, 128.0), "style": 0},
	{"name": "WINDWARD CIRCLE", "at": Vector2(78.0, 157.0), "style": 1},
	{"name": "FENWARD SHRINE", "at": Vector2(214.0, 105.0), "style": 2},
	{"name": "THE FALLEN WATCH", "at": Vector2(198.0, -148.0), "style": 3},
	{"name": "PILGRIM'S REST", "at": Vector2(-68.0, -202.0), "style": 4},
]
var smith_position: Vector3 = Vector3(-30.8, 0.0, 23.2)
var waygate_position: Vector3 = Vector3(-215.0, 0.0, -215.0)
var waygate_radius: float = 8.0
var normal_spawns: Array[Vector3] = [
	Vector3(-12.0, 0.0, 20.0), Vector3(24.0, 0.0, 36.0),
	Vector3(-118.0, 0.0, 4.0), Vector3(-164.0, 0.0, -36.0),
	Vector3(126.0, 0.0, 36.0), Vector3(172.0, 0.0, -12.0),
	Vector3(112.0, 0.0, -88.0), Vector3(160.0, 0.0, -118.0),
	Vector3(-112.0, 0.0, -165.0), Vector3(-165.0, 0.0, -130.0),
	Vector3(-146.0, 0.0, 63.0), Vector3(-186.0, 0.0, 120.0),
	Vector3(-125.0, 0.0, 178.0), Vector3(-64.0, 0.0, 202.0),
	Vector3(4.0, 0.0, 155.0), Vector3(78.0, 0.0, 165.0),
	Vector3(145.0, 0.0, 67.0), Vector3(204.0, 0.0, 113.0),
	Vector3(224.0, 0.0, 40.0), Vector3(190.0, 0.0, -25.0),
	Vector3(166.0, 0.0, -90.0), Vector3(204.0, 0.0, -138.0),
	Vector3(130.0, 0.0, -189.0), Vector3(65.0, 0.0, -183.0),
	Vector3(-60.0, 0.0, -209.0), Vector3(-119.0, 0.0, -174.0),
	Vector3(-188.0, 0.0, -164.0), Vector3(-228.0, 0.0, -118.0),
	Vector3(-202.0, 0.0, -69.0), Vector3(-157.0, 0.0, -44.0),
	Vector3(-68.0, 0.0, 4.0), Vector3(-70.0, 0.0, 48.0)]

## Level band and visual identity of each region. Areas are uneven but
## comparable; the central vale is the starting zone. `relief` scales the local
## rolling noise and `rocks` controls how stony the biome is, so the five regions
## differ physically as well as in colour. Dead trees are the Ashen Fen's
## signature: no other zone mixes them in, so the fen reads as the eerie place.
var zones: Array[Dictionary] = [
	{
		"id": "vale", "name": "EMBERFALL VALE", "subtitle": "The wayfarer's hearth",
		"level_min": 1, "level_max": 3, "center": Vector2(0.0, 16.0),
		"radius": 104.0, "phase": 0.4, "elevation": 0.0, "relief": 0.95,
		"tree_count": 680, "rock_count": 18, "grass_count": 22000,
		"ground": Color("7c8a53"), "accent": Color("c7a96b"),
		"trees": {"oak": 0.58, "birch": 0.42},
		"description": "Rolling meadow and the survivor camp. Safe for new wayfarers.",
	},
	{
		"id": "thornwood", "name": "THORNWOOD", "subtitle": "Where the old forest closes",
		"level_min": 4, "level_max": 6, "center": Vector2(-145.0, 12.0),
		"radius": 106.0, "phase": 2.2, "elevation": 0.9, "relief": 1.15,
		"tree_count": 760, "rock_count": 24, "grass_count": 24000,
		"ground": Color("445f37"), "accent": Color("8a6a4a"),
		"trees": {"oak": 0.54, "birch": 0.46},
		"description": "Dense oak and birch. The canopy keeps the ground dark.",
	},
	{
		"id": "fen", "name": "ASHEN FEN", "subtitle": "Still water, patient things",
		"level_min": 7, "level_max": 9, "center": Vector2(140.0, 35.0),
		"radius": 102.0, "phase": 4.1, "elevation": -1.6, "relief": 0.32,
		"tree_count": 400, "rock_count": 16, "grass_count": 4200,
		"ground": Color("55665b"), "accent": Color("7f9a86"),
		"trees": {"dead": 0.62, "pine": 0.38},
		"description": "Shallow black ponds and dead trees. Movement is exposed.",
	},
	{
		"id": "arch", "name": "THE BROKEN ARCH", "subtitle": "A monastery that lost its oath",
		"level_min": 10, "level_max": 12, "center": Vector2(120.0, -130.0),
		"radius": 105.0, "phase": 1.1, "elevation": 3.0, "relief": 1.30,
		"tree_count": 550, "rock_count": 48, "grass_count": 12000,
		"ground": Color("857a5c"), "accent": Color("b09a6c"),
		"trees": {"pine": 1.0},
		"description": "High stone terraces, broken columns and cold pines.",
	},
	{
		"id": "sanctum", "name": "CROWNLESS SANCTUM", "subtitle": "The sealed gate watches",
		"level_min": 13, "level_max": 15, "center": Vector2(-140.0, -145.0),
		"radius": 118.0, "phase": 5.3, "elevation": 4.2, "relief": 1.05,
		"tree_count": 480, "rock_count": 42, "grass_count": 10000,
		"ground": Color("3f5257"), "accent": Color("79a79b"),
		"trees": {"pine": 1.0},
		"description": "The highest ground. The dormant waygate stands in its corner.",
	},
]

var roads: Array[PackedVector2Array] = []
var time_of_day: float = 8.25
var day_number: int = 1
## Graphics options surfaced in Settings. They live on the world so the initial
## build and a live toggle share one application path, and so a test can assert
## exactly what the environment received.
var glow_enabled: bool = true
var ssao_enabled: bool = true
var ssao_strength: int = 1

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _hills: FastNoiseLite
var _detail: FastNoiseLite
var _mottle: FastNoiseLite
var _ridge: FastNoiseLite
var _ridge_detail: FastNoiseLite
var _terrain_heights: PackedFloat32Array = PackedFloat32Array()
var _terrain_colors: PackedColorArray = PackedColorArray()
var _terrain_grid_size: int = 0
var _map_cache: ImageTexture
var _authored_map: Image
var _tree_points: Array[Vector2] = []
## Shared spatial grid for every forest and foothill trunk. The conservative
## clearance covers the widest scaled trunk flare and the authored trunk lean.
const TREE_TRUNK_CLEARANCE := 3.2
var _tree_spacing_cells: Dictionary = {}
## Every point a grass tuft was placed at. The test driver runs headless, where a
## MultiMesh does not hand its transforms back from the rendering server, so the
## road-exclusion check reads this audit trail instead.
var grass_points: PackedVector2Array = PackedVector2Array()
var _tree_base: Dictionary = {}
var _prop_meshes: Dictionary = {}
var _streamed_visual_data: Dictionary = {}
var _streamed_visual_nodes: Dictionary = {}
var _stream_center := Vector2i(2147483647, 2147483647)
var _vegetation_paths: Dictionary = {}
var _vegetation_counts: Dictionary = {}
var _vegetation_meshes: Dictionary = {}
var _vegetation_pending: Dictionary = {}
var _vegetation_desired: Dictionary = {}
var _terrain_paths: Dictionary = {}
var _terrain_active: Dictionary = {}
var _terrain_far: Dictionary = {}
var _terrain_pending: Dictionary = {}
var _terrain_desired: Dictionary = {}
var _terrain_center := Vector2i(2147483647, 2147483647)
var _static_paths: Dictionary = {}
var _static_active: Dictionary = {}
var _static_pending: Dictionary = {}
var _static_desired: Dictionary = {}
var _static_center := Vector2i(2147483647, 2147483647)
var _stream_running_kind: String = ""
var _stream_running_path: String = ""
var _stream_running_cell := Vector2i.ZERO
var _stream_next_kind: int = 0
var _sites: Array[Dictionary] = []
var _ponds: Array[Dictionary] = []
var _road_cells: Dictionary = {}
var _materials: Dictionary = {}
var _sun: DirectionalLight3D
var _environment: Environment
var _sky_material: ShaderMaterial
var _portal_material: StandardMaterial3D
var _portal_ring: MeshInstance3D
var _flames: Array[Node3D] = []
var _night_lights: Array[OmniLight3D] = []
var _camp_embers: Array[Node3D] = []
var road_lamps: Array[Vector3] = []
var _elapsed: float = 0.0
var _last_stream_warning: float = -10.0
var _stream_timing: Dictionary = {}
var _prepared: bool = false
var _phase_name: String = "Day"


## Runtime loads the authored snapshot. The procedural builder below is an
## offline authoring tool and is never run as a fallback during normal play.
func build() -> void:
	var data: Resource = load("res://assets/world/baked_world.res")
	if data == null or data.static_scene == null or data.format_version != 7 or not is_equal_approx(data.playable_bounds, BOUNDS) or not is_equal_approx(data.terrain_extent, TERRAIN_EXTENT) or data.terrain_segments != TERRAIN_SEGMENTS or data.terrain_tiles.is_empty() or data.vegetation_paths.is_empty() or data.static_paths.is_empty() or data.map_image == null:
		push_error("The authored world asset is missing or incompatible; run scripts/dev/bake_world.gd.")
		return
	_init_noise()
	_sites = data.sites.duplicate(true)
	_ponds = data.ponds.duplicate(true)
	_prepared = true
	_finalize_spawns()
	_terrain_heights = data.terrain_heights
	_terrain_colors = data.terrain_colors
	_terrain_grid_size = data.terrain_grid_size
	_authored_map = data.map_image
	_map_cache = null
	roads = data.roads.duplicate(true)
	_road_cells = data.road_cells.duplicate(true)
	road_lamps = data.road_lamps.duplicate()
	_tree_points = data.tree_points.duplicate()
	_tree_spacing_cells = data.tree_spacing_cells.duplicate(true)
	grass_points = data.grass_points
	_streamed_visual_data.clear()
	_vegetation_paths = data.vegetation_paths
	_vegetation_counts = data.vegetation_counts
	_vegetation_meshes.clear()
	_vegetation_pending.clear()
	_vegetation_desired.clear()
	_streamed_visual_nodes.clear()
	_stream_center = Vector2i(2147483647, 2147483647)
	_terrain_paths = data.terrain_tiles
	_terrain_active.clear()
	_terrain_far.clear()
	_terrain_pending.clear()
	_terrain_desired.clear()
	_terrain_center = Vector2i(2147483647, 2147483647)
	_static_paths = data.static_paths
	_static_active.clear()
	_static_pending.clear()
	_static_desired.clear()
	_static_center = Vector2i(2147483647, 2147483647)
	_create_atmosphere()
	var authored: Node = data.static_scene.instantiate()
	for child: Node in authored.get_children():
		_clear_baked_owners(child)
		authored.remove_child(child)
		add_child(child)
	authored.free()
	for cell: Vector2i in _terrain_paths:
		var low := get_node_or_null("TerrainFar_%02d_%02d" % [cell.x, cell.y]) as MeshInstance3D
		if low != null:
			_terrain_far[cell] = low
	_refresh_baked_dynamic_nodes()
	update_streamed_visuals(player_spawn)
	update_terrain_chunks(player_spawn)
	update_static_chunks(player_spawn)
	_apply_time_of_day()

func _clear_baked_owners(node: Node) -> void:
	for child: Node in node.get_children():
		_clear_baked_owners(child)
	node.owner = null

func build_procedural() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_rng.seed = 293817
	_prepared = false
	_sites.clear()
	_ponds.clear()
	roads.clear()
	_road_cells.clear()
	_materials.clear()
	_flames.clear()
	_night_lights.clear()
	_camp_embers.clear()
	road_lamps.clear()
	_tree_points.clear()
	_tree_spacing_cells.clear()
	grass_points.clear()
	_tree_base.clear()
	_prop_meshes.clear()
	_streamed_visual_data.clear()
	_streamed_visual_nodes.clear()
	_stream_center = Vector2i(2147483647, 2147483647)
	_init_noise()
	_init_sites()
	_init_ponds()
	_prepared = true
	_finalize_spawns()
	_create_materials()
	_create_atmosphere()
	_create_terrain()
	_define_roads()
	_create_roads()
	_create_water()
	_create_camp()
	_create_road_lamps()
	_create_broken_arch()
	_create_sanctum()
	_create_waygate()
	_create_frontier_landmarks()
	_create_vegetation()
	_create_rocks_and_logs()
	_create_distant_landscape()
	_create_boundaries()
	update_streamed_visuals(player_spawn)
	_apply_time_of_day()


## Every placement system gets its own fixed seed, so adding a prop or changing a
## material cannot reshuffle the forest, the roads or the landmarks.
func _reseed(value: int) -> void:
	_rng.seed = value


func _process(delta: float) -> void:
	_elapsed += delta
	var started := Time.get_ticks_usec()
	_pump_streaming()
	var completed := Time.get_ticks_usec()
	if completed - started >= 25000 and _elapsed - _last_stream_warning >= 2.0:
		_last_stream_warning = _elapsed
		var logger := get_node_or_null("../GameLog")
		if logger != null:
			var detail: Dictionary = _stream_timing.duplicate()
			detail["duration_ms"] = (completed - started) / 1000.0
			logger.world("slow_chunk_activation", detail)
	if _portal_material != null:
		_portal_material.emission_energy_multiplier = 0.32 + sin(_elapsed * 1.4) * 0.10
	# A shared flicker phase per flame is cheap and keeps the camp feeling alive.
	for index: int in range(_flames.size()):
		var flame: Node3D = _flames[index]
		if not is_instance_valid(flame):
			continue
		var phase: float = float(index) * 1.73
		flame.scale.y = flame.scale.x * (1.0 + sin(_elapsed * 6.1 + phase) * 0.07)
		flame.rotation.y = sin(_elapsed * 2.3 + phase) * 0.10

func _exit_tree() -> void:
	# Every threaded request must be retrieved, including when logging out before
	# the background buffer finishes; otherwise Godot retains loader objects.
	if not _stream_running_path.is_empty():
		ResourceLoader.load_threaded_get(_stream_running_path)
	_stream_running_path = ""
	_stream_running_kind = ""
	_terrain_pending.clear()
	_vegetation_pending.clear()
	_static_pending.clear()

func _stream_queue(kind: String) -> Dictionary:
	match kind:
		"terrain": return _terrain_pending
		"scenery": return _static_pending
		_: return _vegetation_pending

func _stream_desired(kind: String) -> Dictionary:
	match kind:
		"terrain": return _terrain_desired
		"scenery": return _static_desired
		_: return _vegetation_desired

## One resource request is in flight at a time. This avoids renderer-resource
## creation races and spreads the prefetch work across frames.
func _pump_streaming() -> void:
	if not _stream_running_path.is_empty():
		var status := ResourceLoader.load_threaded_get_status(_stream_running_path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			return
		if status != ResourceLoader.THREAD_LOAD_LOADED:
			push_error("Could not load world chunk: " + _stream_running_path)
			_stream_queue(_stream_running_kind).erase(_stream_running_cell)
			_stream_running_path = ""
			_stream_running_kind = ""
			return
		_finish_running_stream()
		return
	var kinds := ["terrain", "scenery", "vegetation"]
	for offset in range(kinds.size()):
		var index: int = (_stream_next_kind + offset) % kinds.size()
		var kind: String = kinds[index]
		var queue: Dictionary = _stream_queue(kind)
		var desired: Dictionary = _stream_desired(kind)
		var center := _terrain_center if kind == "terrain" else (_static_center if kind == "scenery" else _stream_center)
		var best_cell := Vector2i.ZERO
		var best_distance := 2147483647
		var found := false
		for cell: Vector2i in queue.keys():
			if not desired.has(cell):
				queue.erase(cell)
				continue
			var distance := maxi(absi(cell.x - center.x), absi(cell.y - center.y))
			if distance < best_distance:
				best_distance = distance
				best_cell = cell
				found = true
		if found:
			var cell := best_cell
			var path: String = queue[cell]
			# The headless dummy renderer cannot safely create mesh resources in
			# parallel. Its tests stage one cell per frame on the main thread;
			# the normal renderer prepares each resource in the background.
			if DisplayServer.get_name() == "headless":
				queue.erase(cell)
				var read_started := Time.get_ticks_usec()
				var resource := load(path)
				var read_finished := Time.get_ticks_usec()
				match kind:
					"terrain": _activate_terrain_tile(cell, resource)
					"scenery": _activate_static_cell(cell, resource as PackedScene)
					"vegetation": _activate_vegetation_tile(cell, resource)
				_stream_timing = {"kind": kind, "cell_x": cell.x, "cell_z": cell.y, "read_ms": (read_finished - read_started) / 1000.0, "activate_ms": (Time.get_ticks_usec() - read_finished) / 1000.0}
				_stream_next_kind = (index + 1) % kinds.size()
				return
			if ResourceLoader.load_threaded_request(path) != OK:
				queue.erase(cell)
				push_error("Could not request world chunk: " + path)
				continue
			_stream_running_kind = kind
			_stream_running_cell = cell
			_stream_running_path = path
			_stream_next_kind = (index + 1) % kinds.size()
			return

func _finish_running_stream() -> void:
	if _stream_running_path.is_empty():
		return
	var kind := _stream_running_kind
	var cell := _stream_running_cell
	var started := Time.get_ticks_usec()
	var resource := ResourceLoader.load_threaded_get(_stream_running_path)
	var read_finished := Time.get_ticks_usec()
	_stream_queue(kind).erase(cell)
	_stream_running_path = ""
	_stream_running_kind = ""
	if not _stream_desired(kind).has(cell):
		return
	match kind:
		"terrain":
			if not _terrain_active.has(cell): _activate_terrain_tile(cell, resource)
		"scenery":
			if not _static_active.has(cell): _activate_static_cell(cell, resource as PackedScene)
		"vegetation":
			if not _streamed_visual_nodes.has(cell): _activate_vegetation_tile(cell, resource)
	_stream_timing = {"kind": kind, "cell_x": cell.x, "cell_z": cell.y, "read_ms": (read_finished - started) / 1000.0, "activate_ms": (Time.get_ticks_usec() - read_finished) / 1000.0, "background": true}


func advance_time(delta: float) -> void:
	time_of_day += 24.0 * delta / DAY_SECONDS
	while time_of_day >= 24.0:
		time_of_day -= 24.0
		day_number += 1
	var phase := _time_phase(time_of_day)
	if phase != _phase_name:
		_phase_name = phase
	_apply_time_of_day()


func clock_text() -> String:
	var total := int(floor(time_of_day * 60.0)) % (24 * 60)
	return "%02d:%02d" % [total / 60, total % 60]


## Development and screenshot tooling use this to jump the cycle instantly.
func set_time_of_day(hours: float) -> void:
	time_of_day = fposmod(hours, 24.0)
	_phase_name = _time_phase(time_of_day)
	_apply_time_of_day()


func phase_text() -> String:
	return _time_phase(time_of_day)


func _init_noise() -> void:
	_hills = FastNoiseLite.new()
	_hills.seed = 9127
	_hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hills.frequency = 0.0068
	_hills.fractal_type = FastNoiseLite.FRACTAL_FBM
	_hills.fractal_octaves = 3
	_hills.fractal_gain = 0.46
	_hills.fractal_lacunarity = 2.0
	_detail = FastNoiseLite.new()
	_detail.seed = 4413
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail.frequency = 0.028
	_detail.fractal_type = FastNoiseLite.FRACTAL_FBM
	_detail.fractal_octaves = 2
	_detail.fractal_gain = 0.5
	_mottle = FastNoiseLite.new()
	_mottle.seed = 7821
	_mottle.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_mottle.frequency = 0.32
	_ridge = FastNoiseLite.new()
	_ridge.seed = 6151
	_ridge.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ridge.frequency = 0.011
	_ridge.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridge.fractal_octaves = 4
	_ridge.fractal_gain = 0.55
	_ridge.fractal_lacunarity = 2.2
	_ridge_detail = FastNoiseLite.new()
	_ridge_detail.seed = 2243
	_ridge_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ridge_detail.frequency = 0.052
	_ridge_detail.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_ridge_detail.fractal_octaves = 3
	_ridge_detail.fractal_gain = 0.5


func _init_sites() -> void:
	# Flattened pads keep the hand-built landmarks readable on rolling ground.
	_sites = [
		{"center": Vector2(-36.0, 32.0), "radius": 9.5, "blend": 7.0, "kind": "camp"},
		{"center": Vector2(100.0, -95.0), "radius": 10.0, "blend": 7.0, "kind": "quest"},
		{"center": Vector2(-215.0, -215.0), "radius": 8.5, "blend": 7.0, "kind": "waygate"},
		# The hand-built monastery and sanctum need their own flat pads and a
		# tree-free apron, or the forest grows through the terrace and pillars.
		{"center": Vector2(122.0, -116.0), "radius": 10.5, "blend": 7.0, "kind": "arch"},
		{"center": Vector2(-142.0, -150.0), "radius": 9.5, "blend": 7.0, "kind": "sanctum"},
	]
	for landmark: Dictionary in frontier_landmarks:
		_sites.append({"center": landmark["at"], "radius": 5.0, "blend": 5.0, "kind": "frontier_landmark"})
	for site: Dictionary in _sites:
		var center: Vector2 = site["center"]
		site["level"] = _raw_height(center.x, center.y)


func _init_ponds() -> void:
	# Lakes are carved bowls, not discs dropped on the ground. Inside the wavy
	# shoreline the terrain drops to `level - depth` and rises into a bank that is
	# 42 cm above the water at the rim, so the water plane is always held below the
	# land (and below the coarse terrain triangles) and can never clip through it.
	# Centres avoid the trade roads, so no ribbon has to bridge a pool. The
	# waterline sits 30 cm under the lowest raw rim point.
	for spec: Dictionary in [
		{"center": Vector2(120.0, 0.0), "radius": 10.0, "depth": 1.5},
		{"center": Vector2(165.0, 62.0), "radius": 7.5, "depth": 1.25},
		{"center": Vector2(200.0, 12.0), "radius": 6.5, "depth": 1.0},
	]:
		var pond: Dictionary = spec.duplicate()
		pond["phase"] = _rng.randf_range(0.0, TAU)
		var lowest: float = INF
		for index: int in range(32):
			var angle: float = TAU * float(index) / 32.0
			var shore: Vector2 = spec["center"] + Vector2(cos(angle), sin(angle)) \
				* float(spec["radius"]) * _shore_shape(angle, float(pond["phase"]))
			lowest = minf(lowest, _raw_height(shore.x, shore.y))
		pond["level"] = lowest - 0.30
		_ponds.append(pond)


## Wavy, non-circular shoreline. Four sine harmonics are enough to read as a
## natural bank and, unlike noise, stay identical in the terrain mesh, the water
## mesh, the map and the wading test. The 2nd and 3rd harmonics carry the shape:
## they give each lake a long axis and one broad bay instead of a wobbling disc.
func _shore_shape(angle: float, phase: float) -> float:
	return 1.0 + 0.11 * sin(angle * 2.0 + phase * 0.6) \
		+ 0.15 * sin(angle * 3.0 - phase) \
		+ 0.08 * sin(angle * 5.0 + phase * 1.7) \
		+ 0.04 * sin(angle * 8.0 - phase * 2.3)


func _pond_shore_radius(pond: Dictionary, angle: float) -> float:
	return float(pond["radius"]) * _shore_shape(angle, float(pond["phase"]))


func _finalize_spawns() -> void:
	player_spawn = _ground(-33.4, 32.4)
	camp_position = _ground(-36.0, 32.0)
	quest_spawn = _ground(100.0, -95.0)
	boss_spawn = _ground(-138.0, -138.0)
	smith_position = _ground(-30.8, 23.2)
	waygate_position = _ground(-215.0, -215.0)
	for index: int in range(normal_spawns.size()):
		var point: Vector3 = normal_spawns[index]
		normal_spawns[index] = _ground(point.x, point.z)


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, height_at(x, z), z)


## Lowest ground under a small footprint. Props with a flat base (trunks, rocks,
## bushes) use this so the downhill edge never floats above the terrain.
func _ground_lowest(x: float, z: float, radius: float) -> Vector3:
	var y: float = height_at(x, z)
	y = minf(y, height_at(x + radius, z))
	y = minf(y, height_at(x - radius, z))
	y = minf(y, height_at(x, z + radius))
	y = minf(y, height_at(x, z - radius))
	return Vector3(x, y, z)


## Height is a pure function of x/z. The render mesh, the collision mesh, every
## prop, spawn point and the click-to-move ray all use this one function.
func height_at(x: float, z: float) -> float:
	if not _prepared:
		if _hills == null:
			_init_noise()
		if _sites.is_empty():
			_init_sites()
		if _ponds.is_empty():
			_init_ponds()
		_prepared = true
	var h: float = _raw_height(x, z)
	for pond: Dictionary in _ponds:
		var center: Vector2 = pond["center"]
		var delta := Vector2(x, z) - center
		var distance: float = delta.length()
		if distance > float(pond["radius"]) * 2.1:
			continue
		var shore: float = _pond_shore_radius(pond, atan2(delta.y, delta.x))
		var t: float = distance / maxf(shore, 0.001)
		var level: float = float(pond["level"])
		if t < 1.0:
			# Bowl: deepest at the centre, then a bank that climbs 42 cm above the
			# waterline at the rim. The wide lip is deliberate: the terrain grid
			# samples every ~1.56 m, so a 10 cm lip could be missed by a triangle
			# and let the water plane show through the bank.
			var bowl: float = maxf(1.0 - t * t, 0.0)
			h = level - float(pond["depth"]) * pow(bowl, 0.62) + 0.42 * smoothstep(0.70, 1.0, t)
		else:
			h = lerpf(level + 0.42, h, smoothstep(1.0, 1.55, t))
	for site: Dictionary in _sites:
		var center: Vector2 = site["center"]
		var radius: float = site["radius"]
		var blend: float = site["blend"]
		var distance: float = Vector2(x, z).distance_to(center)
		if distance < radius + blend:
			h = lerpf(float(site["level"]), h, smoothstep(radius, radius + blend, distance))
	# Beyond the playable rim the land rises into a mountain range. Because this
	# lives in the same height function as the forest floor, the peaks are real
	# terrain: they cast shadows, collide and fade into the fog with everything
	# else instead of hovering as separate cones.
	var edge: float = maxf(absf(x), absf(z))
	if edge > RIM_START:
		var rim: float = smoothstep(RIM_START, RIM_END, edge)
		var back: float = 1.0 - smoothstep(RIM_FALL_START, RIM_FALL_END, edge)
		var ridge_value: float = clampf(_ridge.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
		var crag_value: float = clampf(_ridge_detail.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
		h += rim * rim * back * (RIM_HEIGHT * (0.52 + 0.78 * ridge_value) + 9.0 * crag_value)
	return h


## Height of the rendered/collidable terrain triangles, for ground overlays.
## The analytic height field can differ slightly between mesh vertices.
func surface_height_at(x: float, z: float) -> float:
	if _terrain_grid_size < 2 or _terrain_heights.is_empty() or absf(x) > TERRAIN_EXTENT or absf(z) > TERRAIN_EXTENT:
		return height_at(x, z)
	var step: float = (TERRAIN_EXTENT * 2.0) / float(TERRAIN_SEGMENTS)
	var fx := (x + TERRAIN_EXTENT) / step
	var fz := (z + TERRAIN_EXTENT) / step
	var ix := clampi(floori(fx), 0, _terrain_grid_size - 2)
	var iz := clampi(floori(fz), 0, _terrain_grid_size - 2)
	var u := clampf(fx - float(ix), 0.0, 1.0)
	var v := clampf(fz - float(iz), 0.0, 1.0)
	var h00 := _terrain_heights[iz * _terrain_grid_size + ix]
	var h10 := _terrain_heights[iz * _terrain_grid_size + ix + 1]
	var h01 := _terrain_heights[(iz + 1) * _terrain_grid_size + ix]
	var h11 := _terrain_heights[(iz + 1) * _terrain_grid_size + ix + 1]
	if u + v <= 1.0: return h00 + u * (h10 - h00) + v * (h01 - h00)
	return h10 * (1.0 - v) + h11 * (u + v - 1.0) + h01 * (1.0 - u)


func _raw_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var h: float = _hills.get_noise_2d(x, z) * 3.1
	h += _detail.get_noise_2d(x, z) * 0.62
	var bias_sum: float = 0.0
	var relief_sum: float = 0.0
	var weight_sum: float = 0.0
	for zone: Dictionary in zones:
		var metric: float = maxf(_zone_metric(zone, p), 0.05)
		var weight: float = 1.0 / pow(metric, 4.0)
		bias_sum += float(zone["elevation"]) * weight
		relief_sum += float(zone.get("relief", 1.0)) * weight
		weight_sum += weight
	if weight_sum > 0.0:
		h = h * (relief_sum / weight_sum) + bias_sum / weight_sum
	return h


func _zone_metric(zone: Dictionary, p: Vector2) -> float:
	var center: Vector2 = zone["center"]
	var delta: Vector2 = p - center
	var angle: float = atan2(delta.y, delta.x)
	var phase: float = zone["phase"]
	var distortion: float = 1.0 + 0.16 * sin(angle * 3.0 + phase) + 0.07 * sin(angle * 5.0 - phase * 1.7)
	return delta.length() * distortion / float(zone["radius"])


func zone_at(point: Vector3) -> Dictionary:
	return zone_at_xz(Vector2(point.x, point.z))


func zone_at_xz(p: Vector2) -> Dictionary:
	var best: Dictionary = zones[0]
	var best_metric: float = INF
	for zone: Dictionary in zones:
		var metric: float = _zone_metric(zone, p)
		if metric < best_metric:
			best_metric = metric
			best = zone
	return best


## Boundary polygon in world X/Z for the full-screen map.
func zone_boundary(zone: Dictionary, segments: int = 64) -> PackedVector2Array:
	var center: Vector2 = zone["center"]
	var radius: float = zone["radius"]
	var phase: float = zone["phase"]
	var points := PackedVector2Array()
	for index: int in range(segments):
		var angle: float = TAU * float(index) / float(segments)
		var distortion: float = 1.0 + 0.16 * sin(angle * 3.0 + phase) + 0.07 * sin(angle * 5.0 - phase * 1.7)
		points.append(center + Vector2(cos(angle), sin(angle)) * radius / distortion)
	return points


func zone_level_text(zone: Dictionary) -> String:
	return "Lv %d-%d" % [int(zone["level_min"]), int(zone["level_max"])]


## Read-only access to the fen pools for the full-screen map.
func ponds() -> Array[Dictionary]:
	return _ponds


## World-space rectangle shown by the full-screen map. The mountain rim is left
## out: the map is about the ground the player can walk, not the scenery wall.
func map_bounds() -> Rect2:
	return Rect2(Vector2(-BOUNDS - 6.0, -BOUNDS - 6.0), Vector2((BOUNDS + 6.0) * 2.0, (BOUNDS + 6.0) * 2.0))


## Paints the real height field and vertex colours into a square map texture.
## Height shading, rock and biome tint all come from the same grid the terrain
## mesh uses, so the map looks like the land instead of like traced blobs.
func map_texture(size: int = 640) -> ImageTexture:
	if _map_cache != null and _map_cache.get_width() == size:
		return _map_cache
	if _authored_map != null:
		var image := _authored_map.duplicate() as Image
		if image.get_width() != size:
			image.resize(size, size, Image.INTERPOLATE_LANCZOS)
		_map_cache = ImageTexture.create_from_image(image)
		return _map_cache
	var image := _paint_map_image(size)
	if image == null:
		return null
	_map_cache = ImageTexture.create_from_image(image)
	return _map_cache

func _paint_map_image(size: int) -> Image:
	var count: int = _terrain_grid_size
	if count < 2 or _terrain_heights.is_empty():
		return null
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var bounds := map_bounds()
	var raster_step: float = (TERRAIN_EXTENT * 2.0) / float(count - 1)
	var light := Vector3(-0.55, 0.72, -0.42).normalized()
	# Trunk positions become soft density masses, so the painted map shows where
	# the forest actually closes instead of a uniform green wash.
	var density_size: int = 96
	var density := PackedFloat32Array()
	density.resize(density_size * density_size)
	for point: Vector2 in _tree_points:
		var dx: int = int((point.x - bounds.position.x) / bounds.size.x * float(density_size))
		var dz: int = int((point.y - bounds.position.y) / bounds.size.y * float(density_size))
		if dx < 0 or dz < 0 or dx >= density_size or dz >= density_size:
			continue
		density[dz * density_size + dx] += 1.0
	for pass_index: int in range(3):
		var blurred := PackedFloat32Array()
		blurred.resize(density.size())
		for dz: int in range(density_size):
			for dx: int in range(density_size):
				var total: float = 0.0
				var samples: int = 0
				for oy: int in range(-1, 2):
					for ox: int in range(-1, 2):
						var sx: int = dx + ox
						var sz: int = dz + oy
						if sx < 0 or sz < 0 or sx >= density_size or sz >= density_size:
							continue
						total += density[sz * density_size + sx]
						samples += 1
				blurred[dz * density_size + dx] = total / float(maxi(samples, 1))
		density = blurred
	for py: int in range(size):
		var z: float = bounds.position.y + (float(py) + 0.5) / float(size) * bounds.size.y
		var gz: float = (z + TERRAIN_EXTENT) / raster_step
		for px: int in range(size):
			var x: float = bounds.position.x + (float(px) + 0.5) / float(size) * bounds.size.x
			var gx: float = (x + TERRAIN_EXTENT) / raster_step
			var base: Color = _sample_color_grid(gx, gz)
			var h_left: float = _sample_height_grid(gx - 1.0, gz)
			var h_right: float = _sample_height_grid(gx + 1.0, gz)
			var h_down: float = _sample_height_grid(gx, gz - 1.0)
			var h_up: float = _sample_height_grid(gx, gz + 1.0)
			var normal := Vector3(h_left - h_right, raster_step * 2.0, h_down - h_up).normalized()
			var shade: float = clampf(normal.dot(light), 0.0, 1.0) * 0.58 + 0.52
			var point := Vector2(x, z)
			var forest: float = clampf(_mottle.get_noise_2d(x, z) * 0.5 + 0.5, 0.0, 1.0)
			base = base * shade * lerpf(0.90, 1.08, forest)
			var canopy: float = _sample_density(
				density, density_size,
				(x - bounds.position.x) / bounds.size.x,
				(z - bounds.position.y) / bounds.size.y)
			base = base.lerp(Color("24351f"), clampf(canopy * 2.3, 0.0, 0.58))
			# Topographic contours every 4 m, so the map reads as surveyed land
			# rather than a flat colour wash.
			var h_here: float = _sample_height_grid(gx, gz)
			var h_west: float = _sample_height_grid(gx - 1.6, gz)
			var h_south: float = _sample_height_grid(gx, gz - 1.6)
			if int(floor(h_here / 4.0)) != int(floor(h_west / 4.0)) \
					or int(floor(h_here / 4.0)) != int(floor(h_south / 4.0)):
				base = base.darkened(0.09)
			for pond: Dictionary in _ponds:
				var delta: Vector2 = point - (pond["center"] as Vector2)
				var distance: float = delta.length()
				var shore: float = _pond_shore_radius(pond, atan2(delta.y, delta.x))
				if distance < shore * 1.30:
					# The terrain height at this pixel decides the waterline exactly,
					# so the map cannot draw a pool larger than the carved basin.
					var surface: float = float(pond["level"]) + 0.02
					if h_here < surface:
						base = base.lerp(Color("2f4a4b"), 0.94)
					elif h_here < surface + 0.28:
						base = base.lerp(Color("4a4a3a"), 0.50)
			base.a = 1.0
			image.set_pixel(px, py, base)
	# Stamp the trunk positions as fine stipple on top of the canopy masses.
	for point: Vector2 in _tree_points:
		var px: int = int((point.x - bounds.position.x) / bounds.size.x * float(size))
		var py: int = int((point.y - bounds.position.y) / bounds.size.y * float(size))
		for oy: int in range(-1, 2):
			for ox: int in range(-1, 2):
				var sx: int = px + ox
				var sy: int = py + oy
				if sx < 0 or sy < 0 or sx >= size or sy >= size:
					continue
				var current: Color = image.get_pixel(sx, sy)
				image.set_pixel(sx, sy, current.lerp(Color("2e4227"), 0.38))
	return image


func _sample_density(grid: PackedFloat32Array, grid_size: int, u: float, v: float) -> float:
	var gx: float = clampf(u, 0.0, 0.9999) * float(grid_size)
	var gz: float = clampf(v, 0.0, 0.9999) * float(grid_size)
	var x0: int = clampi(int(floor(gx)), 0, grid_size - 1)
	var z0: int = clampi(int(floor(gz)), 0, grid_size - 1)
	var x1: int = mini(x0 + 1, grid_size - 1)
	var z1: int = mini(z0 + 1, grid_size - 1)
	var tx: float = gx - float(x0)
	var tz: float = gz - float(z0)
	var top: float = lerpf(grid[z0 * grid_size + x0], grid[z0 * grid_size + x1], tx)
	var bottom: float = lerpf(grid[z1 * grid_size + x0], grid[z1 * grid_size + x1], tx)
	return lerpf(top, bottom, tz)


func _sample_height_grid(gx: float, gz: float) -> float:
	var count: int = _terrain_grid_size
	var x0: int = clampi(int(floor(gx)), 0, count - 1)
	var z0: int = clampi(int(floor(gz)), 0, count - 1)
	var x1: int = mini(x0 + 1, count - 1)
	var z1: int = mini(z0 + 1, count - 1)
	var tx: float = clampf(gx - float(x0), 0.0, 1.0)
	var tz: float = clampf(gz - float(z0), 0.0, 1.0)
	var top: float = lerpf(_terrain_heights[z0 * count + x0], _terrain_heights[z0 * count + x1], tx)
	var bottom: float = lerpf(_terrain_heights[z1 * count + x0], _terrain_heights[z1 * count + x1], tx)
	return lerpf(top, bottom, tz)


func _sample_color_grid(gx: float, gz: float) -> Color:
	var count: int = _terrain_grid_size
	var x0: int = clampi(int(floor(gx)), 0, count - 1)
	var z0: int = clampi(int(floor(gz)), 0, count - 1)
	var x1: int = mini(x0 + 1, count - 1)
	var z1: int = mini(z0 + 1, count - 1)
	var tx: float = clampf(gx - float(x0), 0.0, 1.0)
	var tz: float = clampf(gz - float(z0), 0.0, 1.0)
	var top: Color = (_terrain_colors[z0 * count + x0] as Color).lerp(_terrain_colors[z0 * count + x1], tx)
	var bottom: Color = (_terrain_colors[z1 * count + x0] as Color).lerp(_terrain_colors[z1 * count + x1], tx)
	return top.lerp(bottom, tz)


func _time_phase(hours: float) -> String:
	if hours >= 5.0 and hours < 8.0:
		return "Dawn"
	if hours >= 8.0 and hours < 17.5:
		return "Day"
	if hours >= 17.5 and hours < 20.5:
		return "Dusk"
	return "Night"


func _create_materials() -> void:
	_material("earth", Color("3e4c35"))
	_material("earth_dark", Color("2c3a2d"))
	_material("dirt", Color("6a6048"))
	_material("moss", Color("53603b"))
	_material("stone", Color("757b70"))
	_material("stone_light", Color("96998a"))
	_material("stone_dark", Color("4d5c56"))
	_material("stone_blue", Color("626f6c"))
	_material("wood", Color("4a382b"))
	_material("wood_light", Color("796044"))
	var camp_timber := _textured(load("res://assets/textures/polyhaven/jolcham_oak_bark_01_diff_1k.jpg"), 0.96)
	camp_timber.normal_enabled = true
	camp_timber.normal_texture = load("res://assets/textures/polyhaven/jolcham_oak_bark_01_nor_gl_1k.jpg")
	camp_timber.normal_scale = 0.65
	_materials["camp_timber"] = camp_timber
	_material("iron", Color("333e40"))
	_material("copper", Color("ad8554"), 0.55)
	# Cloth is double sided: the bigger tents are walk-in shelters now, so the
	# player must see canvas from the inside as well as from the road.
	var cloth: StandardMaterial3D = _material("cloth", Color("c4ad80"))
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cloth_dark: StandardMaterial3D = _material("cloth_dark", Color("8f8465"))
	cloth_dark.cull_mode = BaseMaterial3D.CULL_DISABLED
	var banner: StandardMaterial3D = _material("banner", Color("365352"))
	banner.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material("straw", Color("b49a63"))
	_material("ash", Color("3c3b36"))
	_material("grass", Color("6e7848"))
	_material("coal", Color("1d2826"))
	_material("fire", Color("ffb45f"), 0.0, Color("ff8c32"), 1.6)
	# Flames are two additive, unshaded shells instead of one solid cone: the
	# layered overlap reads as fire from every angle and never as a paper pyramid.
	var fire_outer: StandardMaterial3D = _material("fire_outer", Color(1.0, 0.50, 0.16, 0.55), 0.0, Color(1.0, 0.34, 0.07), 1.35)
	fire_outer.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire_outer.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire_outer.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fire_outer.cull_mode = BaseMaterial3D.CULL_DISABLED
	var fire_core: StandardMaterial3D = _material("fire_core", Color(1.0, 0.84, 0.48, 0.85), 0.0, Color(1.0, 0.70, 0.26), 2.4)
	fire_core.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fire_core.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fire_core.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fire_core.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material("rune", Color("8fc7be"), 0.2, Color("5fada1"), 1.25)
	_material("rune_dim", Color("405c55"), 0.0, Color("42665a"), 0.35)
	_material("portal_ring", Color("6fa79c"), 0.2, Color("4f9e92"), 0.7)
	_material("mountain", Color("37464a"))
	_material("mountain_snow", Color("8b9a95"))
	_material("terrain", Color.WHITE)
	_materials["terrain"] = _textured(GRASS_TEXTURE, 0.96)
	_materials["terrain"].vertex_color_use_as_albedo = true
	_materials["terrain"].uv1_scale = Vector3(3.0, 3.0, 3.0)
	_materials["terrain"].normal_enabled = true
	_materials["terrain"].normal_texture = GROUND_NORMAL
	_materials["terrain"].normal_scale = 0.45
	var rock_material := _textured(ROCK_TEXTURE, 0.96)
	rock_material.albedo_color = Color(0.82, 0.88, 0.84)
	rock_material.normal_enabled = true
	rock_material.normal_texture = ROCK_NORMAL
	rock_material.normal_scale = 0.65
	_materials["natural_rock"] = rock_material
	_materials["road"] = _textured(ROAD_TEXTURE, 0.94)
	_materials["road"].vertex_color_use_as_albedo = true
	_materials["road"].transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materials["road"].cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials["road_flat"] = _textured(ROAD_TEXTURE, 0.95)
	_materials["road_flat"].albedo_color = Color(0.86, 0.82, 0.72)
	_materials["bark"] = _textured(BARK_TEXTURE, 0.97)
	var birch_bark: StandardMaterial3D = _textured(BARK_TEXTURE, 0.94)
	birch_bark.albedo_color = Color(0.85, 0.84, 0.82)
	_materials["bark_birch"] = birch_bark
	var dead_bark: StandardMaterial3D = _textured(BARK_TEXTURE, 0.98)
	dead_bark.albedo_color = Color(0.92, 0.91, 0.88)
	_materials["bark_dead"] = dead_bark
	_materials["leaves"] = _textured(LEAF_TEXTURE, 0.92)
	_materials["needles"] = _textured(NEEDLE_TEXTURE, 0.95)
	# Tree surfaces 1 are alpha cards, not solid puffs. Scissor transparency keeps
	# them in the opaque pass (no sorting artefacts), double sided so the canopy
	# never disappears from below, and backlit so thin leaves pick up sky light.
	_materials["leaves_card"] = _card_material(LEAF_CARD_TEXTURE, Color(1.22, 1.26, 1.10))
	_materials["needles_card"] = _card_material(NEEDLE_CARD_TEXTURE, Color(1.30, 1.42, 1.20))
	# The needle atlas is deliberately dark; a bright albedo keeps pine crowns from
	# collapsing into black silhouettes under the overcast sky.
	_materials["needles"].albedo_color = Color(1.25, 1.34, 1.16)
	var water: StandardMaterial3D = _material("water", Color(0.10, 0.16, 0.15, 0.90), 0.0)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.22
	water.metallic_specular = 0.22
	water.cull_mode = BaseMaterial3D.CULL_DISABLED
	var portal: StandardMaterial3D = _material("portal", Color(0.55, 0.95, 0.90, 0.22), 0.3)
	portal.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	portal.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	portal.emission_enabled = true
	portal.emission = Color("4fb3a4")
	portal.emission_energy_multiplier = 0.35
	portal.cull_mode = BaseMaterial3D.CULL_DISABLED
	portal.albedo_texture = null


func _material(key: String, color: Color, metallic: float = 0.0, emission: Color = Color.BLACK, energy: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.92
	material.metallic = metallic
	if energy > 0.0:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = energy
	_materials[key] = material
	return material


func _textured(texture: Texture2D, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = roughness
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.texture_repeat = true
	return material


## Alpha-scissor foliage card. Scissor (not alpha blend) keeps the canopy in the
## opaque pass, so leaves never sort in front of each other or the player.
func _card_material(texture: Texture2D, tint: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = tint
	material.roughness = 0.90
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.32
	# Alpha-to-coverage makes 4x MSAA smooth the card edges without the blur
	# alpha blending would introduce. Godot falls back to scissor if MSAA is off.
	material.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
	material.alpha_antialiasing_edge = 0.55
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.texture_repeat = true
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	material.backlight_enabled = true
	material.backlight = Color(0.58, 0.72, 0.42)
	return material


func _create_atmosphere() -> void:
	var world := WorldEnvironment.new()
	world.name = "FrontierAtmosphere"
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	_sky_material = ShaderMaterial.new()
	_sky_material.shader = preload("res://shaders/frontier_sky.gdshader")
	sky.sky_material = _sky_material
	# The cloud deck scrolls with TIME, so the radiance map has to follow it.
	# 256 px is the only cubemap size a realtime sky accepts; it is plenty for
	# the soft ambient bounce and much cheaper than a full-resolution sky update.
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.radiance_size = Sky.RADIANCE_SIZE_256
	_environment.sky = sky
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_environment.ambient_light_sky_contribution = 1.0
	_environment.ambient_light_energy = 0.45
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.tonemap_exposure = 1.02
	_environment.fog_enabled = true
	_environment.fog_light_color = Color("8a9c8d")
	_environment.fog_light_energy = 0.55
	_environment.fog_density = 0.0032
	_environment.fog_sky_affect = 0.35
	_environment.fog_aerial_perspective = 0.35
	_environment.ssao_enabled = ssao_enabled
	_environment.ssao_radius = 1.5
	_environment.ssao_intensity = 1.5 * ssao_strength
	_environment.ssao_power = 1.4
	_environment.ssao_detail = 0.5
	_environment.ssao_light_affect = 0.12
	# Glow is the payoff for the emissive fire, lanterns, runes and eyes. Screen
	# blending only adds light and never darkens or tints the base frame, and the
	# 1.0 HDR threshold keeps ordinary sunlit stone out of the effect. Levels 3-5
	# give the tight core a wide, soft halo instead of a hard cut-out.
	_environment.glow_enabled = glow_enabled
	_environment.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	_environment.glow_hdr_threshold = 1.0
	_environment.glow_hdr_scale = 2.0
	_environment.glow_intensity = 0.9
	_environment.glow_strength = 1.0
	_environment.glow_bloom = 0.0
	_environment.set_glow_level(1, 0.0)
	_environment.set_glow_level(2, 0.35)
	_environment.set_glow_level(3, 0.6)
	_environment.set_glow_level(4, 0.55)
	_environment.set_glow_level(5, 0.3)
	_environment.set_glow_level(6, 0.0)
	world.environment = _environment
	add_child(world)

	_sun = DirectionalLight3D.new()
	_sun.name = "FrontierSun"
	_sun.light_color = Color("ffdca6")
	_sun.light_energy = 1.35
	_sun.shadow_enabled = true
	# Two shadow cascades keep soft nearby shadows while avoiding repeated draws
	# across four long-range shadow maps for the dense forest.
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	_sun.directional_shadow_max_distance = 100.0
	_sun.directional_shadow_split_1 = 0.08
	_sun.directional_shadow_blend_splits = true
	_sun.directional_shadow_fade_start = 0.82
	_sun.light_angular_distance = 2.2
	_sun.shadow_blur = 1.8
	_sun.shadow_opacity = 0.82
	_sun.shadow_bias = 0.04
	_sun.shadow_normal_bias = 1.2
	add_child(_sun)


## Applies the Graphics options from Settings without a world rebuild. Both
## effects are per-scene Environment flags, so toggling them is immediate and
## costs nothing until the next frame.
func apply_graphics_settings(use_glow: bool, use_ssao: bool, ao_strength: int = 1) -> void:
	glow_enabled = use_glow
	ssao_enabled = use_ssao
	ssao_strength = clampi(ao_strength, 1, 3)
	if _environment == null:
		return
	_environment.glow_enabled = glow_enabled
	_environment.ssao_enabled = ssao_enabled
	_environment.ssao_intensity = 1.5 * ssao_strength


func _apply_time_of_day() -> void:
	if _sun == null or _environment == null or _sky_material == null:
		return
	var solar_t: float = fposmod(time_of_day - 6.0, 24.0) / 12.0
	var solar_height: float = sin(solar_t * PI)
	var daylight: float = smoothstep(0.0, 0.24, solar_height)
	var dusk: float = smoothstep(-0.04, 0.12, solar_height) * (1.0 - smoothstep(0.16, 0.55, solar_height))
	var is_day: bool = solar_height > 0.0
	var arc_t: float = solar_t if is_day else fposmod(time_of_day - 18.0, 24.0) / 12.0
	var arc_height: float = maxf(sin(arc_t * PI), 0.02)
	_sun.rotation_degrees = Vector3(-(4.0 + arc_height * 58.0), lerpf(-104.0, 104.0, arc_t), 0.0)
	if is_day:
		_sun.light_color = Color("ffb477").lerp(Color("fff4de"), clampf((arc_height - 0.08) / 0.65, 0.0, 1.0))
		_sun.light_energy = 0.10 + 1.55 * daylight + 0.30 * dusk
	else:
		_sun.light_color = Color("a9c2ee")
		_sun.light_energy = 0.12 + 0.24 * arc_height
	var day_top := Color("3c6f98")
	var day_horizon := Color("c3c9ac")
	var night_top := Color("0b1526")
	var night_horizon := Color("243a4d")
	var dusk_top := Color("3b4a5c")
	var dusk_horizon := Color("d08a5a")
	_sky_material.set_shader_parameter("top_color",
		night_top.lerp(day_top, daylight).lerp(dusk_top, dusk * 0.6))
	_sky_material.set_shader_parameter("horizon_color",
		night_horizon.lerp(day_horizon, daylight).lerp(dusk_horizon, dusk * 0.8))
	_sky_material.set_shader_parameter("ground_bottom_color",
		Color("0d1512").lerp(Color("3f4a34"), daylight))
	_sky_material.set_shader_parameter("ground_horizon_color",
		Color("1d2a2a").lerp(Color("8f9b83"), daylight).lerp(Color("a67d58"), dusk * 0.5))
	# Clouds keep their shape at night but lose almost all their light; at dusk
	# their undersides catch the same orange the horizon does.
	var cloud_lit := Color("69707c").lerp(Color("f1efe4"), daylight)
	cloud_lit = cloud_lit.lerp(Color("e8ad7c"), dusk * 0.65)
	_sky_material.set_shader_parameter("cloud_color", cloud_lit)
	_sky_material.set_shader_parameter("cloud_shadow",
		Color("222836").lerp(Color("7b8696"), daylight))
	_sky_material.set_shader_parameter("sun_tint", _sun.light_color)
	_sky_material.set_shader_parameter("sun_glow", clampf(daylight * 1.15 + dusk * 0.65, 0.0, 1.3))
	_sky_material.set_shader_parameter("night_amount", 1.0 - daylight)
	_environment.ambient_light_energy = lerpf(0.15, 0.48, daylight) + dusk * 0.05
	_environment.fog_light_color = Color("1c2b3a").lerp(Color("8a9c8d"), daylight).lerp(Color("b78a63"), dusk * 0.55)
	_environment.fog_density = lerpf(0.0058, 0.0029, daylight)
	# Fires fade in at dusk and out after dawn, including their local sound.
	var night_amount := 1.0 - daylight
	for light: OmniLight3D in _night_lights:
		if not is_instance_valid(light):
			continue
		var base_energy: float = float(light.get_meta("night_energy", light.light_energy))
		light.light_energy = base_energy * night_amount
	for flame: Node3D in _flames:
		if not is_instance_valid(flame):
			continue
		flame.visible = night_amount > 0.01
		var particles := flame.get_node_or_null("FireParticles") as GPUParticles3D
		if particles != null:
			particles.emitting = night_amount > 0.01
		var sound := flame.get_node_or_null("FireSound") as AudioStreamPlayer3D
		if sound != null:
			var director := get_node_or_null("../Audio")
			var volume := 1.0
			if director != null:
				volume = 0.0 if director.muted else float(director.master_volume)
			sound.volume_db = float(sound.get_meta("base_db")) + linear_to_db(maxf(night_amount * volume, 0.0001))
			if night_amount > 0.01 and not sound.playing:
				sound.play()
			elif night_amount <= 0.01 and sound.playing:
				sound.stop()
	for ember: Node3D in _camp_embers:
		if is_instance_valid(ember):
			ember.visible = night_amount > 0.01


func _create_terrain() -> void:
	var count: int = TERRAIN_SEGMENTS + 1
	var step: float = (TERRAIN_EXTENT * 2.0) / float(TERRAIN_SEGMENTS)
	var heights := PackedFloat32Array()
	heights.resize(count * count)
	var vertices := PackedVector3Array()
	vertices.resize(count * count)
	for iz: int in range(count):
		for ix: int in range(count):
			var x: float = -TERRAIN_EXTENT + float(ix) * step
			var z: float = -TERRAIN_EXTENT + float(iz) * step
			var index: int = iz * count + ix
			heights[index] = height_at(x, z)
			vertices[index] = Vector3(x, heights[index], z)
	var normals := PackedVector3Array()
	normals.resize(count * count)
	var colors := PackedColorArray()
	colors.resize(count * count)
	var uvs := PackedVector2Array()
	uvs.resize(count * count)
	for iz: int in range(count):
		for ix: int in range(count):
			var index: int = iz * count + ix
			var left: int = iz * count + maxi(ix - 1, 0)
			var right: int = iz * count + mini(ix + 1, count - 1)
			var down: int = maxi(iz - 1, 0) * count + ix
			var up: int = mini(iz + 1, count - 1) * count + ix
			var normal := Vector3(heights[left] - heights[right], 2.0 * step, heights[down] - heights[up]).normalized()
			normals[index] = normal
			var point := Vector2(vertices[index].x, vertices[index].z)
			colors[index] = _terrain_color(point, normal, heights[index])
			uvs[index] = point * 0.085
	var indices := PackedInt32Array()
	for iz: int in range(TERRAIN_SEGMENTS):
		for ix: int in range(TERRAIN_SEGMENTS):
			var a: int = iz * count + ix
			var b: int = a + 1
			var c: int = a + count
			var d: int = c + 1
			indices.append(a)
			indices.append(b)
			indices.append(c)
			indices.append(b)
			indices.append(d)
			indices.append(c)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _materials["terrain"])
	var terrain := MeshInstance3D.new()
	terrain.name = "RollingTerrain"
	terrain.mesh = mesh
	add_child(terrain)
	terrain.create_trimesh_collision()
	# Keep the sampled grid so the world map can paint the real terrain instead
	# of tracing approximate biome outlines.
	_terrain_heights = heights
	_terrain_colors = colors
	_terrain_grid_size = count
	_map_cache = null


func _terrain_color(p: Vector2, normal: Vector3, height_value: float) -> Color:
	var nearest: Array[Dictionary] = []
	var metrics: Array[float] = []
	for zone: Dictionary in zones:
		nearest.append(zone)
		metrics.append(_zone_metric(zone, p))
	# Sort the five zones by metric and blend the two closest so borders are soft.
	for i: int in range(1, nearest.size()):
		var j: int = i
		while j > 0 and metrics[j] < metrics[j - 1]:
			var tmp_zone: Dictionary = nearest[j]
			nearest[j] = nearest[j - 1]
			nearest[j - 1] = tmp_zone
			var tmp_metric: float = metrics[j]
			metrics[j] = metrics[j - 1]
			metrics[j - 1] = tmp_metric
			j -= 1
	var w1: float = 1.0 / pow(maxf(metrics[0], 0.03), 3.0)
	var w2: float = 1.0 / pow(maxf(metrics[1], 0.03), 3.0)
	var blend: float = maxf(w1 + w2, 0.0001)
	var c1: Color = nearest[0]["ground"]
	var c2: Color = nearest[1]["ground"]
	var base := Color(
		(c1.r * w1 + c2.r * w2) / blend,
		(c1.g * w1 + c2.g * w2) / blend,
		(c1.b * w1 + c2.b * w2) / blend,
		1.0)
	var mottle: float = _mottle.get_noise_2d(p.x, p.y)
	base = base.lerp(base.lightened(0.14), clampf(mottle * 0.5 + 0.5, 0.0, 1.0) * 0.32)
	base = base.darkened(0.08 * clampf(mottle, 0.0, 1.0))
	var slope: float = clampf((1.0 - normal.y) * 3.2, 0.0, 0.85)
	base = base.lerp(Color("74786c"), slope)
	# Mountains are terrain, so their colour has to climb with them: bare rock on
	# the high slopes, pale stone on the wind-scoured peaks.
	var altitude: float = smoothstep(11.0, 28.0, height_value)
	base = base.lerp(Color("5c645c"), altitude * (0.34 + 0.48 * slope))
	var alpine: float = smoothstep(34.0, 52.0, height_value)
	base = base.lerp(Color("9aa39a"), alpine * 0.78)
	for pond: Dictionary in _ponds:
		var delta: Vector2 = p - (pond["center"] as Vector2)
		var distance: float = delta.length()
		var shore: float = _pond_shore_radius(pond, atan2(delta.y, delta.x))
		if distance < shore * 1.55:
			var t: float = distance / maxf(shore, 0.001)
			if t < 1.02:
				# Wet silt below the waterline; the darker bed is what the water
				# shader fades out of, so the pool reads shallow at the edge.
				base = base.lerp(Color("363c2e"), 0.82)
			else:
				base = base.lerp(Color("5d5943"), 1.0 - smoothstep(1.02, 1.55, t))
	for site: Dictionary in _sites:
		var kind: String = str(site["kind"])
		if kind != "camp" and kind != "waygate":
			continue
		var distance: float = p.distance_to(site["center"])
		if distance < float(site["radius"]):
			base = base.lerp(Color("6a624a"), 0.55)
	return base


func _define_roads() -> void:
	var nodes: Dictionary = {
		"camp": Vector2(-36.0, 32.0),
		"camp_north": Vector2(-24.0, 52.0),
		"vale_north": Vector2(8.0, 60.0),
		"north_pass": Vector2(32.0, 42.0),
		"crossroads": Vector2(0.0, 12.0),
		"camp_west": Vector2(-64.0, 28.0),
		"west_road": Vector2(-88.0, 8.0),
		"thorn_deep": Vector2(-145.0, -28.0),
		"thorn_south": Vector2(-120.0, -70.0),
		"sanctum_road": Vector2(-90.0, -100.0),
		"sanctum": Vector2(-138.0, -138.0),
		"sanctum_west": Vector2(-185.0, -180.0),
		"waygate": Vector2(-215.0, -215.0),
		"fen_gate": Vector2(48.0, 40.0),
		"fen_road": Vector2(105.0, 65.0),
		"fen_deep": Vector2(155.0, -15.0),
		"fen_south": Vector2(110.0, -45.0),
		"arch_road": Vector2(52.0, -16.0),
		"arch": Vector2(100.0, -95.0),
		"arch_east": Vector2(150.0, -103.0),
		"arch_north": Vector2(110.0, -160.0),
		"south_vale": Vector2(-8.0, -28.0),
		"south_pass": Vector2(-24.0, -60.0),
		"high_ridge": Vector2(20.0, -137.0),
		"ancient_crossing": Vector2(-30.0, -115.0),
		"east_vale": Vector2(32.0, 4.0),
		"east_south": Vector2(36.0, -32.0),
		"north_wood": Vector2(-150.0, 60.0), "north_glade": Vector2(-185.0, 120.0),
		"northwest_ridge": Vector2(-125.0, 180.0), "north_ridge": Vector2(-65.0, 205.0),
		"north_ford": Vector2(0.0, 150.0), "northeast_ridge": Vector2(78.0, 165.0),
		"fen_outer": Vector2(145.0, 65.0), "fen_ridge": Vector2(205.0, 115.0),
		"east_ridge": Vector2(226.0, 40.0), "east_fen": Vector2(190.0, -28.0),
		"east_arch": Vector2(165.0, -90.0), "east_ruins": Vector2(205.0, -140.0),
		"south_ruins": Vector2(130.0, -190.0), "south_ridge": Vector2(65.0, -185.0),
		"south_crossing": Vector2(-60.0, -210.0), "south_sanctum": Vector2(-120.0, -175.0),
		"west_sanctum": Vector2(-190.0, -165.0), "west_ridge": Vector2(-230.0, -120.0),
		"west_pass": Vector2(-205.0, -70.0), "west_deep": Vector2(-160.0, -45.0),
	}
	var edges: Array = [
		["camp", "camp_north"], ["camp", "crossroads"], ["camp", "camp_west"],
		["camp", "south_vale"], ["camp_north", "vale_north"], ["vale_north", "north_pass"],
		["vale_north", "fen_gate"], ["north_pass", "fen_gate"], ["north_pass", "east_vale"],
		["east_vale", "crossroads"], ["east_vale", "east_south"], ["crossroads", "south_vale"],
		["crossroads", "arch_road"], ["south_vale", "east_south"], ["south_vale", "south_pass"],
		["east_south", "arch_road"], ["arch_road", "arch"], ["arch_road", "fen_south"],
		["arch", "arch_east"], ["arch", "arch_north"], ["arch_north", "high_ridge"],
		["high_ridge", "ancient_crossing"], ["ancient_crossing", "sanctum_road"],
		["arch_east", "fen_south"], ["fen_south", "fen_deep"],
		["fen_deep", "fen_road"], ["fen_road", "fen_gate"], ["camp_west", "west_road"],
		["west_road", "thorn_deep"], ["west_road", "thorn_south"], ["thorn_deep", "thorn_south"],
		["thorn_south", "sanctum_road"], ["sanctum_road", "sanctum"],
		["sanctum", "sanctum_west"], ["sanctum_west", "waygate"],
		["west_road", "north_wood"], ["north_wood", "north_glade"],
		["north_glade", "northwest_ridge"], ["northwest_ridge", "north_ridge"],
		["north_ridge", "north_ford"], ["north_ford", "vale_north"],
		["north_ford", "northeast_ridge"], ["northeast_ridge", "fen_ridge"],
		["fen_road", "fen_outer"], ["fen_outer", "fen_ridge"],
		["fen_ridge", "east_ridge"], ["east_ridge", "east_fen"], ["east_fen", "fen_deep"],
		["east_fen", "east_arch"], ["arch_east", "east_arch"], ["east_arch", "east_ruins"],
		["east_ruins", "south_ruins"], ["south_ruins", "south_ridge"],
		["south_ridge", "arch_north"], ["south_ridge", "south_crossing"],
		["south_crossing", "south_sanctum"], ["south_sanctum", "sanctum_west"],
		["south_sanctum", "west_sanctum"], ["west_sanctum", "west_ridge"],
		["west_ridge", "west_pass"], ["west_pass", "west_deep"], ["west_deep", "thorn_deep"],
	]
	for edge: Array in edges:
		var a: Vector2 = nodes[str(edge[0])]
		var b: Vector2 = nodes[str(edge[1])]
		var length: float = a.distance_to(b)
		var bend: float = _rng.randf_range(-2.6, 2.6) * clampf(length / 26.0, 0.35, 1.5)
		var polyline: PackedVector2Array = _edge_polyline(a, b, bend)
		roads.append(polyline)
		_mark_road_cells(polyline)
	# Junction discs used to be stamped here to hide ribbon seams, but a flat disc
	# on rolling terrain floats at one edge and reads as a dirt stain. The
	# alpha-feathered ribbons already overlap at every node.


func _edge_polyline(a: Vector2, b: Vector2, bend: float) -> PackedVector2Array:
	var length: float = a.distance_to(b)
	var steps: int = maxi(3, int(ceil(length / 2.0)))
	var direction: Vector2 = (b - a).normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var points := PackedVector2Array()
	for index: int in range(steps + 1):
		var t: float = float(index) / float(steps)
		var point: Vector2 = a.lerp(b, t)
		point += perpendicular * sin(t * PI) * bend
		point += perpendicular * sin(t * PI * 3.0) * 0.35
		points.append(point)
	return points


func _create_roads() -> void:
	_reseed(7719)
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var lanes: Array[float] = [-1.0, -0.55, 0.0, 0.55, 1.0]
	for original: PackedVector2Array in roads:
		var polyline := _road_outside_camp(original)
		var rows: int = polyline.size()
		if rows < 2:
			continue
		var distances := PackedFloat32Array()
		distances.resize(rows)
		var total: float = 0.0
		for index: int in range(1, rows):
			total += polyline[index].distance_to(polyline[index - 1])
			distances[index] = total
		var base_index: int = vertices.size()
		for index: int in range(rows):
			var previous: Vector2 = polyline[maxi(index - 1, 0)]
			var following: Vector2 = polyline[mini(index + 1, rows - 1)]
			var direction: Vector2 = (following - previous).normalized()
			var side := Vector2(-direction.y, direction.x)
			var end_fade: float = clampf(minf(distances[index], total - distances[index]) / 1.8, 0.0, 1.0)
			for lane: float in lanes:
				var point: Vector2 = polyline[index] + side * lane * ROAD_WIDTH * 0.5
				var y: float = height_at(point.x, point.y)
				vertices.append(Vector3(point.x, y + ROAD_LIFT, point.y))
				var e: float = 0.7
				var nx: float = height_at(point.x - e, point.y) - height_at(point.x + e, point.y)
				var nz: float = height_at(point.x, point.y - e) - height_at(point.x, point.y + e)
				normals.append(Vector3(nx, 2.0 * e, nz).normalized())
				var fade: float = clampf((1.0 - absf(lane)) / 0.45, 0.0, 1.0)
				colors.append(Color(1.0, 1.0, 1.0, fade * end_fade))
				uvs.append(Vector2((lane + 1.0) * 0.8, distances[index] * 0.30))
		for index: int in range(rows - 1):
			for lane_index: int in range(lanes.size() - 1):
				var a: int = base_index + index * lanes.size() + lane_index
				var b: int = a + 1
				var c: int = a + lanes.size()
				var d: int = c + 1
				indices.append(a)
				indices.append(c)
				indices.append(b)
				indices.append(b)
				indices.append(c)
				indices.append(d)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _materials["road"])
	var instance := MeshInstance3D.new()
	instance.name = "RoadNetwork"
	instance.mesh = mesh
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	_create_camp_ground()


## Keep the network data intact for gates and the map, but start its visible
## ribbons at the camp clearing rather than crossing the hearth and tents.
func _road_outside_camp(original: PackedVector2Array) -> PackedVector2Array:
	var center := Vector2(camp_position.x, camp_position.z)
	var points := original.duplicate()
	if points.size() < 2:
		return points
	if points[points.size() - 1].distance_to(center) < 2.0:
		points.reverse()
	if points[0].distance_to(center) >= 2.0:
		return points
	var result := PackedVector2Array()
	var radius := 12.5
	for index: int in range(1, points.size()):
		var a := points[index - 1]
		var b := points[index]
		if result.is_empty() and b.distance_to(center) >= radius:
			var low := 0.0
			var high := 1.0
			for step: int in range(16):
				var mid := (low + high) * 0.5
				if a.lerp(b, mid).distance_to(center) < radius:
					low = mid
				else:
					high = mid
			result.append(a.lerp(b, high))
		if not result.is_empty():
			result.append(b)
	return result


func _create_camp_ground() -> void:
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var center := Vector2(camp_position.x, camp_position.z)
	var normals := PackedVector3Array()
	var segments := 96
	var radii: Array[float] = [0.0, 3.0, 6.0, 9.0, 11.5, 13.5]
	for ring: int in range(radii.size()):
		for i: int in range(segments):
			var angle := TAU * float(i) / float(segments)
			var p := center + Vector2(cos(angle), sin(angle)) * radii[ring]
			vertices.append(Vector3(p.x, height_at(p.x, p.y) + ROAD_LIFT - 0.01, p.y))
			normals.append(Vector3.UP)
			colors.append(Color(1, 1, 1, 0.0 if ring == radii.size() - 1 else 1.0))
			uvs.append((p - center) * 0.3)
	for ring: int in range(radii.size() - 1):
		for i: int in range(segments):
			var a := ring * segments + i
			var b := ring * segments + (i + 1) % segments
			var c := a + segments
			var d := b + segments
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _materials["road"])
	var ground := MeshInstance3D.new()
	ground.name = "CampRoadClearing"
	ground.mesh = mesh
	ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ground)


func _mark_road_cells(polyline: PackedVector2Array) -> void:
	# Stamp a 3 x 3 block per sample. A single cell per node left diagonal
	# stretches of a 3.7 m ribbon unmatched, so ground cover could still appear
	# on the road between two samples.
	for point: Vector2 in polyline:
		var cell := Vector2i(int(floor(point.x / 2.5)), int(floor(point.y / 2.5)))
		for dx: int in range(-1, 2):
			for dz: int in range(-1, 2):
				_road_cells[Vector2i(cell.x + dx, cell.y + dz)] = true


func _near_road(x: float, z: float, radius_cells: int = 0) -> bool:
	var cx: int = int(floor(x / 2.5))
	var cz: int = int(floor(z / 2.5))
	for dx: int in range(-radius_cells, radius_cells + 1):
		for dz: int in range(-radius_cells, radius_cells + 1):
			if _road_cells.has(Vector2i(cx + dx, cz + dz)):
				return true
	return false


## Exact distance from a point to the nearest road centreline. The cell grid is
## only a broad phase; grass, flowers and bushes use this so no blade grows on
## the ribbon, including the diagonal edges the old cell test missed.
func _road_distance(point: Vector2) -> float:
	var best: float = 1.0e9
	for polyline: PackedVector2Array in roads:
		var count: int = polyline.size()
		for index: int in range(count - 1):
			var a: Vector2 = polyline[index]
			var b: Vector2 = polyline[index + 1]
			var segment: Vector2 = b - a
			var length_squared: float = segment.length_squared()
			var t: float = 0.0
			if length_squared > 0.0001:
				t = clampf((point - a).dot(segment) / length_squared, 0.0, 1.0)
			var delta: Vector2 = point - (a + segment * t)
			var distance_squared: float = delta.length_squared()
			if distance_squared < best:
				best = distance_squared
	return sqrt(best)


## True when a ground-cover point sits on the road surface itself. The coarse
## test is a cheap reject for the overwhelming majority of candidates.
func _on_road(point: Vector2, padding: float = 0.35) -> bool:
	if not _near_road(point.x, point.y, 1):
		return false
	return _road_distance(point) < ROAD_WIDTH * 0.5 + padding


func _polyline_point(polyline: PackedVector2Array, lengths: PackedFloat32Array, t: float) -> Vector2:
	if polyline.size() < 2:
		return polyline[0] if polyline.size() == 1 else Vector2.ZERO
	var total: float = lengths[lengths.size() - 1]
	var target: float = clampf(t, 0.0, 1.0) * total
	for index: int in range(1, polyline.size()):
		if lengths[index] >= target:
			var span: float = lengths[index] - lengths[index - 1]
			var local: float = 0.0 if span < 0.001 else (target - lengths[index - 1]) / span
			return polyline[index - 1].lerp(polyline[index], local)
	return polyline[polyline.size() - 1]


## Sparse medieval lamps along the roads. They stand on the verge, never on the
## ribbon, and only along the routes closest to camp first, so the player meets a
## few pools of light instead of a lit runway.
func _create_road_lamps() -> void:
	_reseed(9113)
	var candidates: Array[Dictionary] = []
	for road_index: int in range(roads.size()):
		var polyline: PackedVector2Array = roads[road_index]
		if polyline.size() < 4:
			continue
		var lengths := PackedFloat32Array()
		lengths.resize(polyline.size())
		var total: float = 0.0
		for index: int in range(1, polyline.size()):
			total += polyline[index].distance_to(polyline[index - 1])
			lengths[index] = total
		if total < 24.0:
			continue
		var midpoint: Vector2 = _polyline_point(polyline, lengths, 0.5)
		var camp_point := Vector2(camp_position.x, camp_position.z)
		candidates.append({
			"road": polyline,
			"lengths": lengths,
			"total": total,
			"distance": midpoint.distance_to(camp_point),
			"index": road_index,
		})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["distance"]) < float(b["distance"]))
	var limit: int = 13
	var minimum_gap: float = 44.0
	for candidate: Dictionary in candidates:
		if road_lamps.size() >= limit:
			break
		var polyline: PackedVector2Array = candidate["road"]
		var lengths: PackedFloat32Array = candidate["lengths"]
		for slot: int in range(2):
			if road_lamps.size() >= limit:
				break
			var t: float = 0.34 if slot == 0 else 0.68
			var at: Vector2 = _polyline_point(polyline, lengths, t)
			var ahead: Vector2 = _polyline_point(polyline, lengths, minf(t + 0.04, 1.0))
			var behind: Vector2 = _polyline_point(polyline, lengths, maxf(t - 0.04, 0.0))
			var tangent: Vector2 = ahead - behind
			if tangent.length() < 0.01:
				continue
			tangent = tangent.normalized()
			var side := Vector2(-tangent.y, tangent.x)
			var sign_value: float = 1.0 if (int(candidate["index"]) + slot) % 2 == 0 else -1.0
			var verge: Vector2 = at + side * sign_value * (ROAD_WIDTH * 0.5 + 1.35)
			# The camp gates have their own paired lights; a roadside light here
			# would overlap one of those stands on closely spaced approaches.
			if verge.distance_to(Vector2(camp_position.x, camp_position.z)) < 21.0:
				continue
			if absf(verge.x) > BOUNDS - 7.0 or absf(verge.y) > BOUNDS - 7.0:
				continue
			# Branched roads pass close to one another. A verge on one route can
			# sit in the middle of another, so re-check against the whole network
			# rather than only the road this candidate belongs to.
			if _road_distance(verge) < ROAD_WIDTH * 0.5 + 0.9:
				continue
			if _in_pond(verge, 0.8) or _near_site(verge, 2.0):
				continue
			var ground: Vector3 = _ground(verge.x, verge.y)
			if ground.y > 24.0:
				continue
			var spaced: bool = true
			for existing: Vector3 in road_lamps:
				if existing.distance_to(ground) < minimum_gap:
					spaced = false
					break
			if not spaced:
				continue
			var inward: Vector2 = -side * sign_value
			_road_lamp(self, ground, atan2(-inward.y, inward.x))
			road_lamps.append(ground)


func _near_site(p: Vector2, padding: float) -> bool:
	for site: Dictionary in _sites:
		var distance: float = p.distance_to(site["center"])
		if distance < float(site["radius"]) + padding:
			return true
	return false


func _in_pond(p: Vector2, padding: float) -> bool:
	for pond: Dictionary in _ponds:
		var delta: Vector2 = p - pond["center"]
		var shore: float = _pond_shore_radius(pond, atan2(delta.y, delta.x))
		if delta.length() < shore * 1.35 + padding:
			return true
	return false


## Depth of standing water at a point, in metres (0 when dry). The player uses it
## to wade a step into the shallows and stop, because there is no swimming.
func water_depth_at(x: float, z: float) -> float:
	var point := Vector2(x, z)
	var deepest: float = 0.0
	for pond: Dictionary in _ponds:
		var delta: Vector2 = point - pond["center"]
		var distance: float = delta.length()
		if distance > float(pond["radius"]) * 2.0:
			continue
		var shore: float = _pond_shore_radius(pond, atan2(delta.y, delta.x))
		if distance > shore:
			continue
		deepest = maxf(deepest, float(pond["level"]) - height_at(x, z))
	return maxf(deepest, 0.0)


## Water is a ring mesh that follows the same wavy shoreline as the carved
## terrain, so the surface ends inside the bank instead of cutting through it.
## The analytic basin depth is baked into vertex colour: the shader gets an exact
## depth field without reading the screen depth buffer, which keeps the gradient
## stable at every renderer setting and makes the shallows line up with the bank.
func _pond_water_mesh(pond: Dictionary) -> ArrayMesh:
	var center: Vector2 = pond["center"]
	var surface: float = float(pond["level"]) + 0.02
	var segments: int = 72
	var rings: int = 16
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	vertices.append(Vector3(center.x, surface, center.y))
	normals.append(Vector3.UP)
	uvs.append(center * 0.035)
	colors.append(Color(maxf(surface - height_at(center.x, center.y), 0.0) * 0.5, 0.0, 0.0, 1.0))
	for ring: int in range(1, rings + 1):
		# The disc deliberately runs past the waterline and slides *under* the
		# raised bank. Stopping the mesh exactly at the analytic shore leaves a
		# visible hard edge wherever the sampled terrain triangle crosses the
		# plane; burying the rim in the bank makes the actual shoreline the
		# intersection of water and land, which is what it should be.
		var t: float = float(ring) / float(rings) * 1.35
		for index: int in range(segments):
			var angle: float = TAU * float(index) / float(segments)
			var shore: float = _pond_shore_radius(pond, angle) * t
			var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * shore
			vertices.append(Vector3(point.x, surface, point.y))
			normals.append(Vector3.UP)
			uvs.append(point * 0.035)
			colors.append(Color(maxf(surface - height_at(point.x, point.y), 0.0) * 0.5, 0.0, 0.0, 1.0))
	for index: int in range(segments):
		var next: int = (index + 1) % segments
		indices.append_array([0, 1 + index, 1 + next])
	for ring: int in range(rings - 1):
		var inner: int = 1 + ring * segments
		var outer: int = inner + segments
		for index: int in range(segments):
			var next: int = (index + 1) % segments
			indices.append_array([inner + index, outer + index, outer + next,
				inner + index, outer + next, inner + next])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _create_water() -> void:
	_reseed(4421)
	var water_shader: Shader = load("res://shaders/water.gdshader") as Shader
	if water_shader == null:
		return
	var ripple: NoiseTexture2D = _ripple_normal_texture()
	for index: int in range(_ponds.size()):
		var pond: Dictionary = _ponds[index]
		var water := MeshInstance3D.new()
		water.name = "FenPool%d" % (index + 1)
		water.mesh = _pond_water_mesh(pond)
		var material := ShaderMaterial.new()
		material.shader = water_shader
		material.set_shader_parameter("ripple_normal", ripple)
		water.material_override = material
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(water)
	_create_pond_dressing()


## One seamless normal map shared by every pond. A NoiseTexture2D keeps the
## ripples procedural like the rest of the art, and sharing the texture means
## three lakes still cost one sampler upload.
func _ripple_normal_texture() -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = 3313
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.010
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 3
	noise.fractal_gain = 0.5
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.as_normal_map = true
	texture.bump_strength = 2.2
	texture.generate_mipmaps = true
	texture.noise = noise
	return texture


func _create_pond_dressing() -> void:
	# Shore grass sits beyond the water with clearance for the whole patch.
	# Stones sit on the bank; no grass-like plants are placed in water.
	_reseed(7723)
	var reed_mesh := _grass_tuft_mesh()
	var reed_material := StandardMaterial3D.new()
	reed_material.albedo_texture = GRASS_BLADES
	reed_material.albedo_color = Color(0.82, 0.90, 0.62)
	reed_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	reed_material.alpha_scissor_threshold = 0.40
	reed_material.vertex_color_use_as_albedo = true
	reed_material.roughness = 0.95
	reed_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	reed_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	reed_mesh.surface_set_material(0, reed_material)
	var entries: Array = []
	var shore_points := PackedVector2Array()
	for pond: Dictionary in _ponds:
		var center: Vector2 = pond["center"]
		var placed: int = 0
		var attempts: int = 0
		while placed < 80 and attempts < 420:
			attempts += 1
			var angle: float = _rng.randf_range(0.0, TAU)
			var t: float = _rng.randf_range(1.5, 1.9)
			var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * _pond_shore_radius(pond, angle) * t
			if absf(point.x) > BOUNDS - 2.0 or absf(point.y) > BOUNDS - 2.0:
				continue
			var at := _ground_lowest(point.x, point.y, 0.2)
			if _in_pond(point, 1.2) or _on_road(point, 1.0) or water_depth_at(point.x, point.y) > 0.0:
				continue
			var scale_value: float = _rng.randf_range(1.25, 2.1)
			var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(
				Vector3(scale_value * 0.8, scale_value, scale_value * 0.8))
			entries.append(Transform3D(basis, at))
			shore_points.append(point)
			placed += 1
		for index: int in range(6):
			var angle: float = _rng.randf_range(0.0, TAU)
			var point: Vector2 = center + Vector2(cos(angle), sin(angle)) \
				* _pond_shore_radius(pond, angle) * _rng.randf_range(1.0, 1.18)
			if absf(point.x) > BOUNDS - 2.0 or absf(point.y) > BOUNDS - 2.0:
				continue
			var mesh: Mesh = _load_prop_mesh("stone_%d.glb" % _rng.randi_range(1, 2), "stone")
			if mesh == null:
				break
			var stone := MeshInstance3D.new()
			stone.name = "ShoreStone"
			stone.mesh = mesh
			stone.position = _ground_lowest(point.x, point.y, 0.3) + Vector3.DOWN * 0.03
			stone.rotation = Vector3(0.0, _rng.randf_range(0.0, TAU), 0.0)
			var scale_value: float = _rng.randf_range(0.8, 1.5)
			stone.scale = Vector3.ONE * scale_value
			stone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			add_child(stone)
	var shore_grass := _create_multimesh("ShoreReeds", reed_mesh, entries, false)
	shore_grass.set_meta("shore_points", shore_points)


func _pick_tree(zone: Dictionary) -> String:
	var mix: Dictionary = zone["trees"]
	var roll: float = _rng.randf()
	var total: float = 0.0
	for key: String in mix.keys():
		total += float(mix[key])
		if roll <= total:
			return key
	return "oak"


func _inside_any_zone(point: Vector2, factor: float = 0.93) -> bool:
	for zone: Dictionary in zones:
		if point.distance_to(zone["center"]) < float(zone["radius"]) * factor:
			return true
	return false


## The playable square is wider than the five zone blobs, so the ground between
## the zones and the mountain rim needs its own cover. This returns the colour of
## the closest zone so the outskirt meadow still blends into the regions.
func _zone_ground_near(point: Vector2) -> Color:
	var best: float = 1.0e9
	var color := Color("6d7f4a")
	for zone: Dictionary in zones:
		var distance: float = point.distance_to(zone["center"]) - float(zone["radius"])
		if distance < best:
			best = distance
			color = zone["ground"]
	return color


## Outskirts inherit the nearest region's forest family. A pine ridge therefore
## never grows oaks at its foot, and a broadleaf wood never grows a stray
## conifer. Mixing inside a region is allowed by that region's own `trees` table,
## but the conifer regions list pines only.
func _outskirt_tree(point: Vector2) -> String:
	return _pick_tree(zone_at_xz(point))


func _reserve_tree_position(point: Vector2) -> bool:
	var cell := Vector2i(floori(point.x / TREE_TRUNK_CLEARANCE), floori(point.y / TREE_TRUNK_CLEARANCE))
	for dx: int in range(-1, 2):
		for dz: int in range(-1, 2):
			for existing: Vector2 in _tree_spacing_cells.get(cell + Vector2i(dx, dz), []):
				if point.distance_squared_to(existing) < TREE_TRUNK_CLEARANCE * TREE_TRUNK_CLEARANCE:
					return false
	if not _tree_spacing_cells.has(cell):
		_tree_spacing_cells[cell] = []
	(_tree_spacing_cells[cell] as Array).append(point)
	return true


func _create_vegetation() -> void:
	_reseed(9917)
	var transforms: Dictionary = {"oak": [], "birch": [], "pine": [], "dead": []}
	for zone: Dictionary in zones:
		var center: Vector2 = zone["center"]
		var radius: float = zone["radius"]
		var target: int = int(zone["tree_count"])
		var placed: int = 0
		var attempts: int = 0
		while placed < target and attempts < target * 16:
			attempts += 1
			var direction := Vector2(cos(_rng.randf_range(0.0, TAU)), sin(_rng.randf_range(0.0, TAU)))
			var point: Vector2 = center + direction * sqrt(_rng.randf()) * radius * 0.93
			if absf(point.x) > BOUNDS - 3.0 or absf(point.y) > BOUNDS - 3.0:
				continue
			if _near_road(point.x, point.y, 1) or _near_site(point, 7.0) or _in_pond(point, 1.0):
				continue
			if str(zone_at_xz(point)["id"]) != str(zone["id"]):
				continue
			var kind: String = _pick_tree(zone)
			var scale_value: float = _rng.randf_range(0.92, 1.34)
			var basis: Basis = Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * scale_value)
			if not _reserve_tree_position(point):
				continue
			var at: Vector3 = _ground_lowest(point.x, point.y, 0.45)
			# The per-kind base offset is applied when the instances are built, so
			# this is only a shallow bed for the root flare, not a burial.
			at.y -= 0.05
			(transforms[kind] as Array).append(Transform3D(basis, at))
			_tree_points.append(point)
			placed += 1
	# Continue the forest past the zone blobs. Without this the outer third of the
	# map is bare lawn, which makes the world read as five islands in a field.
	var outskirt_target: int = 1700
	var outskirt_placed: int = 0
	var outskirt_attempts: int = 0
	while outskirt_placed < outskirt_target and outskirt_attempts < outskirt_target * 16:
		outskirt_attempts += 1
		var point := Vector2(
			_rng.randf_range(-BOUNDS + 4.0, BOUNDS - 4.0),
			_rng.randf_range(-BOUNDS + 4.0, BOUNDS - 4.0))
		if maxf(absf(point.x), absf(point.y)) < 58.0:
			continue
		if _inside_any_zone(point, 0.9):
			continue
		if _near_road(point.x, point.y, 1) or _near_site(point, 7.0) or _in_pond(point, 1.0):
			continue
		var at: Vector3 = _ground_lowest(point.x, point.y, 0.45)
		# Rock and scree above the treeline stay bare.
		if at.y > 26.0:
			continue
		var kind: String = _outskirt_tree(point)
		var scale_value: float = _rng.randf_range(0.86, 1.24)
		var basis: Basis = Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * scale_value)
		if not _reserve_tree_position(point):
			continue
		at.y -= 0.05
		(transforms[kind] as Array).append(Transform3D(basis, at))
		_tree_points.append(point)
		outskirt_placed += 1
	for kind: String in transforms.keys():
		var entries: Array = transforms[kind]
		if entries.is_empty():
			continue
		var mesh: Mesh = _load_tree_mesh(kind)
		if mesh == null:
			continue
		_register_streamed_multimesh("Trees_" + kind, mesh, entries, [], true, float(_tree_base.get(kind, 0.0)))
	_create_grass()
	_create_flowers()
	_create_bushes()


func _load_tree_mesh(kind: String) -> Mesh:
	var path := "res://assets/models/trees/tree_%s.glb" % kind
	var packed: PackedScene = load(path) as PackedScene
	if packed == null:
		return null
	var instance := packed.instantiate()
	var found := instance.find_children("*", "MeshInstance3D", true, false)
	if found.is_empty():
		instance.free()
		return null
	var source: Mesh = (found[0] as MeshInstance3D).mesh
	var mesh: Mesh = source.duplicate() as Mesh
	instance.free()
	if mesh == null or mesh.get_surface_count() == 0:
		return null
	# Older exports put the GLB origin in the middle of the trunk, so the mesh
	# hung several metres below y=0 and every instance was half buried. The
	# exporter now writes a base pivot at y=0, but keep the AABB lift as a safety
	# net: a stale or hand-made GLB still plants its feet on the ground.
	_tree_base[kind] = -mesh.get_aabb().position.y
	var bark_key: String = "bark"
	if kind == "birch":
		bark_key = "bark_birch"
	elif kind == "dead":
		bark_key = "bark_dead"
	mesh.surface_set_material(0, _materials[bark_key])
	if mesh.get_surface_count() > 1:
		mesh.surface_set_material(1, _materials["needles_card"] if kind == "pine" else _materials["leaves_card"])
	return mesh


## Props (bush, boulders, stones) are Blender GLBs too. They are cached per file
## and given one of the generated materials, since the export is single-surface.
func _load_prop_mesh(file_name: String, material_key: String) -> Mesh:
	if _prop_meshes.has(file_name):
		return _prop_meshes[file_name]
	var packed: PackedScene = load("res://assets/models/props/" + file_name) as PackedScene
	if packed == null:
		return null
	var instance := packed.instantiate()
	var found := instance.find_children("*", "MeshInstance3D", true, false)
	if found.is_empty():
		instance.free()
		return null
	var mesh: Mesh = (found[0] as MeshInstance3D).mesh
	instance.free()
	if mesh == null or mesh.get_surface_count() == 0:
		return null
	var copy: Mesh = mesh.duplicate() as Mesh
	copy.surface_set_material(0, _materials["natural_rock"] if file_name.begins_with("rock_") or file_name.begins_with("stone_") else _materials[material_key])
	_prop_meshes[file_name] = copy
	return copy


func _create_multimesh(node_name: String, mesh: Mesh, entries: Array, shadows: bool, base_lift: float = 0.0) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = entries.size()
	for index: int in range(entries.size()):
		var entry: Transform3D = entries[index]
		if base_lift != 0.0:
			entry.origin.y += base_lift
		multimesh.set_instance_transform(index, entry)
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = multimesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node

func stream_cell(at: Vector3) -> Vector2i:
	return Vector2i(floori(at.x / STREAM_CELL_SIZE), floori(at.z / STREAM_CELL_SIZE))

func _refresh_baked_dynamic_nodes() -> void:
	_flames.clear()
	for flame: Node in get_tree().get_nodes_in_group("world_flames"):
		if is_ancestor_of(flame):
			_flames.append(flame as Node3D)
	_camp_embers.clear()
	for ember: Node in get_tree().get_nodes_in_group("campfire_embers"):
		if is_ancestor_of(ember):
			_camp_embers.append(ember as Node3D)
	_night_lights.clear()
	for light: Node in find_children("*", "OmniLight3D", true, false):
		if light.has_meta("night_energy"):
			_night_lights.append(light as OmniLight3D)
	_portal_ring = find_child("PortalRing", true, false) as MeshInstance3D
	var portal := find_child("DormantPortal", true, false) as MeshInstance3D
	_portal_material = portal.material_override as StandardMaterial3D if portal != null else null

func update_static_chunks(at: Vector3) -> void:
	if _static_paths.is_empty():
		return
	var center := stream_cell(at)
	if center == _static_center:
		return
	var initial := _static_center.x == 2147483647
	_static_center = center
	_static_desired.clear()
	for cell: Vector2i in _static_paths:
		if absi(cell.x - center.x) <= STREAM_CELL_RADIUS and absi(cell.y - center.y) <= STREAM_CELL_RADIUS:
			_static_desired[cell] = true
	var removed := false
	for cell: Vector2i in _static_active.keys():
		if _static_desired.has(cell):
			continue
		var node: Node = _static_active[cell]
		remove_child(node)
		node.queue_free()
		_static_active.erase(cell)
		removed = true
	if removed:
		_refresh_baked_dynamic_nodes()
	for cell: Vector2i in _static_desired:
		if _static_active.has(cell):
			continue
		var path: String = _static_paths[cell]
		if initial and absi(cell.x - center.x) <= 1 and absi(cell.y - center.y) <= 1:
			_finish_running_stream()
			_static_pending.erase(cell)
			if not _static_active.has(cell):
				_activate_static_cell(cell, load(path) as PackedScene)
		elif not _static_pending.has(cell):
			_static_pending[cell] = path

func _activate_static_cell(cell: Vector2i, scene: PackedScene) -> void:
	if scene == null:
		push_error("Invalid static cell: %s" % cell)
		return
	var node := scene.instantiate()
	add_child(node)
	_static_active[cell] = node
	_refresh_baked_dynamic_nodes()
	_apply_time_of_day()

func terrain_cell(at: Vector3) -> Vector2i:
	var tile_width := TERRAIN_EXTENT * 2.0 / TERRAIN_SEGMENTS * TERRAIN_TILE_SEGMENTS
	return Vector2i(floori((at.x + TERRAIN_EXTENT) / tile_width), floori((at.z + TERRAIN_EXTENT) / tile_width))

## A two-tile buffer is prepared ahead. Low-detail distant tiles provide the
## horizon and collision until each detailed tile is ready.
func update_terrain_chunks(at: Vector3) -> void:
	var center := terrain_cell(at)
	if center == _terrain_center:
		return
	var initial := _terrain_center.x == 2147483647
	_terrain_center = center
	_terrain_desired.clear()
	for cell: Vector2i in _terrain_paths:
		if absi(cell.x - center.x) <= TERRAIN_TILE_RADIUS and absi(cell.y - center.y) <= TERRAIN_TILE_RADIUS:
			_terrain_desired[cell] = true
	for cell: Vector2i in _terrain_active.keys():
		if _terrain_desired.has(cell):
			continue
		var node: Node = _terrain_active[cell]
		remove_child(node)
		node.queue_free()
		_terrain_active.erase(cell)
		if _terrain_far.has(cell):
			_terrain_far[cell].visible = true
			_set_far_terrain_collision(cell, true)
	# Prepare the initial 3x3 core during startup. Later movement never waits on
	# a chunk read: the low-detail collider remains until the detailed tile loads.
	for cell: Vector2i in _terrain_desired:
		if _terrain_active.has(cell):
			continue
		var path: String = _terrain_paths[cell]
		if initial and absi(cell.x - center.x) <= 1 and absi(cell.y - center.y) <= 1:
			_finish_running_stream()
			_terrain_pending.erase(cell)
			if not _terrain_active.has(cell):
				_activate_terrain_tile(cell, load(path))
		elif not _terrain_pending.has(cell):
			_terrain_pending[cell] = path

func _activate_terrain_tile(cell: Vector2i, tile: Resource) -> void:
	if tile == null or tile.mesh == null or tile.collision == null:
		push_error("Invalid baked terrain tile: %s" % cell)
		return
	var node := Node3D.new()
	node.name = "TerrainTile_%02d_%02d" % [cell.x, cell.y]
	var visual := MeshInstance3D.new()
	visual.mesh = tile.mesh
	node.add_child(visual)
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	collider.shape = tile.collision
	body.add_child(collider)
	node.add_child(body)
	add_child(node)
	_terrain_active[cell] = node
	if _terrain_far.has(cell):
		_terrain_far[cell].visible = false
		_set_far_terrain_collision(cell, false)

func _set_far_terrain_collision(cell: Vector2i, enabled: bool) -> void:
	var low: Node = _terrain_far.get(cell)
	if low == null:
		return
	var shapes := low.find_children("*", "CollisionShape3D", true, false)
	if not shapes.is_empty():
		(shapes[0] as CollisionShape3D).disabled = not enabled

## Offline authoring collects deterministic placement data into spatial cells.
## At runtime the per-cell assets are loaded and instantiated near the player.
func _register_streamed_multimesh(label: String, mesh: Mesh, entries: Array, colors: Array, shadows: bool, base_lift: float = 0.0) -> void:
	var buckets: Dictionary = {}
	for index in range(entries.size()):
		var transform: Transform3D = entries[index]
		transform.origin.y += base_lift
		var cell := stream_cell(transform.origin)
		if not buckets.has(cell):
			buckets[cell] = {"entries": [], "colors": []}
		buckets[cell]["entries"].append(transform)
		if not colors.is_empty():
			buckets[cell]["colors"].append(colors[index])
	for cell in buckets:
		if not _streamed_visual_data.has(cell):
			_streamed_visual_data[cell] = []
		_streamed_visual_data[cell].append({"name": label, "mesh": mesh, "entries": buckets[cell]["entries"], "colors": buckets[cell]["colors"], "shadows": shadows})

func update_streamed_visuals(at: Vector3) -> void:
	var center := stream_cell(at)
	if center == _stream_center:
		return
	var initial := _stream_center.x == 2147483647
	_stream_center = center
	if not _vegetation_paths.is_empty():
		_update_baked_vegetation(center, initial)
		return
	for cell: Vector2i in _streamed_visual_nodes.keys():
		if absi(cell.x - center.x) <= STREAM_CELL_RADIUS and absi(cell.y - center.y) <= STREAM_CELL_RADIUS:
			continue
		for node: Node in _streamed_visual_nodes[cell]:
			remove_child(node)
			node.queue_free()
		_streamed_visual_nodes.erase(cell)
	for cell: Vector2i in _streamed_visual_data:
		if _streamed_visual_nodes.has(cell) or absi(cell.x - center.x) > STREAM_CELL_RADIUS or absi(cell.y - center.y) > STREAM_CELL_RADIUS:
			continue
		var nodes: Array[Node] = []
		for group: Dictionary in _streamed_visual_data[cell]:
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.use_colors = not group["colors"].is_empty()
			multimesh.mesh = group["mesh"]
			multimesh.instance_count = group["entries"].size()
			for index in range(multimesh.instance_count):
				multimesh.set_instance_transform(index, group["entries"][index])
				if multimesh.use_colors:
					multimesh.set_instance_color(index, group["colors"][index])
			var node := MultiMeshInstance3D.new()
			node.name = "%s_%d_%d" % [group["name"], cell.x, cell.y]
			node.multimesh = multimesh
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if group["shadows"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(node)
			nodes.append(node)
		_streamed_visual_nodes[cell] = nodes

func _update_baked_vegetation(center: Vector2i, initial: bool) -> void:
	_vegetation_desired.clear()
	for cell: Vector2i in _vegetation_paths:
		if absi(cell.x - center.x) <= STREAM_CELL_RADIUS and absi(cell.y - center.y) <= STREAM_CELL_RADIUS:
			_vegetation_desired[cell] = true
	for cell: Vector2i in _streamed_visual_nodes.keys():
		if _vegetation_desired.has(cell):
			continue
		for node: Node in _streamed_visual_nodes[cell]:
			remove_child(node)
			node.queue_free()
		_streamed_visual_nodes.erase(cell)
	for cell: Vector2i in _vegetation_desired:
		if _streamed_visual_nodes.has(cell):
			continue
		var path: String = _vegetation_paths[cell]
		if initial and absi(cell.x - center.x) <= 1 and absi(cell.y - center.y) <= 1:
			_finish_running_stream()
			_vegetation_pending.erase(cell)
			if not _streamed_visual_nodes.has(cell):
				_activate_vegetation_tile(cell, load(path))
		elif not _vegetation_pending.has(cell):
			_vegetation_pending[cell] = path

func _activate_vegetation_tile(cell: Vector2i, tile: Resource) -> void:
	if tile == null:
		push_error("Invalid baked vegetation cell: %s" % cell)
		return
	var nodes: Array[Node] = []
	for group: Dictionary in tile.groups:
		var mesh_path: String = group["mesh_path"]
		if not _vegetation_meshes.has(mesh_path):
			_vegetation_meshes[mesh_path] = load(mesh_path)
		var mesh: Mesh = _vegetation_meshes[mesh_path]
		if mesh == null:
			push_error("Missing vegetation mesh: " + mesh_path)
			continue
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = not group["colors"].is_empty()
		multimesh.mesh = mesh
		multimesh.instance_count = group["entries"].size()
		for index in range(multimesh.instance_count):
			multimesh.set_instance_transform(index, group["entries"][index])
			if multimesh.use_colors:
				multimesh.set_instance_color(index, group["colors"][index])
		var node := MultiMeshInstance3D.new()
		node.name = "%s_%d_%d" % [group["name"], cell.x, cell.y]
		node.multimesh = multimesh
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if group["shadows"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(node)
		nodes.append(node)
	_streamed_visual_nodes[cell] = nodes


func _grass_tuft_mesh() -> ArrayMesh:
	# Three differently sized, short clumps share a single mesh and draw call.
	# Rotating/scaling each instance varies the patch without extra draw groups.
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var clumps := [
		{"offset": Vector2(-0.26, -0.16), "width": 0.56, "height": 0.36, "angle": 0.12},
		{"offset": Vector2(0.24, -0.10), "width": 0.49, "height": 0.30, "angle": 0.65},
		{"offset": Vector2(0.03, 0.27), "width": 0.53, "height": 0.33, "angle": 1.15},
	]
	for clump: Dictionary in clumps:
		var offset: Vector2 = clump["offset"]
		var width: float = clump["width"]
		var height_value: float = clump["height"]
		for quad in range(2):
			var angle: float = float(clump["angle"]) + PI * float(quad) * 0.5
			var side := Vector2(cos(angle), sin(angle)) * width * 0.5
			var base := vertices.size()
			vertices.append(Vector3(offset.x - side.x, 0.0, offset.y - side.y))
			vertices.append(Vector3(offset.x + side.x, 0.0, offset.y + side.y))
			vertices.append(Vector3(offset.x + side.x, height_value, offset.y + side.y))
			vertices.append(Vector3(offset.x - side.x, height_value, offset.y - side.y))
			for point_index in range(4): normals.append(Vector3(-side.y, 0.0, side.x).normalized())
			uvs.append_array([Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0)])
			indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
		# A small tilted card gives the overhead camera a leafy top view.
		var half := width * 0.43
		var base := vertices.size()
		vertices.append(Vector3(offset.x - half, height_value * 0.47, offset.y - half))
		vertices.append(Vector3(offset.x + half, height_value * 0.55, offset.y - half))
		vertices.append(Vector3(offset.x + half, height_value * 0.50, offset.y + half))
		vertices.append(Vector3(offset.x - half, height_value * 0.57, offset.y + half))
		for point_index in range(4): normals.append(Vector3.UP)
		uvs.append_array([Vector2(0.0, 1.0), Vector2(1.0, 1.0), Vector2(1.0, 0.0), Vector2(0.0, 0.0)])
		indices.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _create_grass() -> void:
	_reseed(3311)
	var mesh := _grass_tuft_mesh()
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/grass.gdshader")
	material.set_shader_parameter("grass_texture", GRASS_BLADES)
	mesh.surface_set_material(0, material)
	var entries: Array = []
	var tints: Array[Color] = []
	for zone: Dictionary in zones:
		var center: Vector2 = zone["center"]
		var radius: float = zone["radius"]
		var target: int = int(float(zone.get("grass_count", 1600)) * 0.90)
		var placed: int = 0
		var attempts: int = 0
		while placed < target and attempts < target * 14:
			attempts += 1
			var angle: float = _rng.randf_range(0.0, TAU)
			var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * sqrt(_rng.randf()) * radius * 0.94
			if absf(point.x) > BOUNDS - 2.0 or absf(point.y) > BOUNDS - 2.0:
				continue
			if _on_road(point, 0.80) or _near_site(point, 1.4) or _in_pond(point, 0.8):
				continue
			var scale_value: float = _rng.randf_range(0.82, 1.38)
			var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(
				Vector3(scale_value * _rng.randf_range(0.85, 1.2), scale_value, scale_value * _rng.randf_range(0.85, 1.2)))
			var at: Vector3 = _ground(point.x, point.y)
			at.y -= 0.03
			entries.append(Transform3D(basis, at))
			var tint: Color = (zone["ground"] as Color).lightened(_rng.randf_range(0.40, 0.58))
			tint = tint.lerp(Color("b9bd8c"), _rng.randf_range(0.06, 0.30))
			tints.append(tint)
			grass_points.append(point)
			placed += 1
	# Same for the meadow: grass has to reach the foothills, not stop at an
	# invisible zone boundary.
	var outskirt_target: int = 21000
	var outskirt_placed: int = 0
	var outskirt_attempts: int = 0
	while outskirt_placed < outskirt_target and outskirt_attempts < outskirt_target * 8:
		outskirt_attempts += 1
		var point := Vector2(
			_rng.randf_range(-BOUNDS + 2.0, BOUNDS - 2.0),
			_rng.randf_range(-BOUNDS + 2.0, BOUNDS - 2.0))
		if maxf(absf(point.x), absf(point.y)) < 56.0:
			continue
		if _inside_any_zone(point, 0.92):
			continue
		if _on_road(point, 0.80) or _near_site(point, 1.4) or _in_pond(point, 0.8):
			continue
		var at: Vector3 = _ground(point.x, point.y)
		if at.y > 24.0:
			continue
		var scale_value: float = _rng.randf_range(0.82, 1.38)
		var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(
			Vector3(scale_value * _rng.randf_range(0.85, 1.2), scale_value, scale_value * _rng.randf_range(0.85, 1.2)))
		at.y -= 0.03
		entries.append(Transform3D(basis, at))
		var tint: Color = _zone_ground_near(point).lightened(_rng.randf_range(0.40, 0.58))
		tint = tint.lerp(Color("b9bd8c"), _rng.randf_range(0.06, 0.30))
		tints.append(tint)
		grass_points.append(point)
		outskirt_placed += 1
	_register_streamed_multimesh("MeadowGrass", mesh, entries, tints, false)


func _create_flowers() -> void:
	_reseed(5527)
	var mesh := ArrayMesh.new()
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var vertex_colors := PackedColorArray()
	var stem := Color(0.30, 0.42, 0.18)
	var petal := Color.WHITE
	# Stem: a narrow upright quad. Without a stem a flat triangle reads as a
	# coloured shard lying on the grass.
	var stem_points: Array[Vector3] = [
		Vector3(-0.014, 0.0, 0.0), Vector3(0.014, 0.0, 0.0), Vector3(0.010, 0.27, 0.0),
		Vector3(-0.014, 0.0, 0.0), Vector3(0.010, 0.27, 0.0), Vector3(-0.010, 0.27, 0.0)]
	for point: Vector3 in stem_points:
		vertices.append(point)
		normals.append(Vector3.BACK)
		vertex_colors.append(stem)
	# Head: six petals around a tiny bright centre, laid flat so the camera reads
	# a flower instead of a spike.
	for index: int in range(6):
		var angle: float = TAU * float(index) / 6.0
		var tip_a := Vector3(cos(angle - 0.34) * 0.105, 0.27, sin(angle - 0.34) * 0.105)
		var tip_b := Vector3(cos(angle + 0.34) * 0.105, 0.27, sin(angle + 0.34) * 0.105)
		vertices.append(Vector3(0.0, 0.28, 0.0))
		vertices.append(tip_a)
		vertices.append(tip_b)
		for point_index: int in range(3):
			normals.append(Vector3.UP)
			vertex_colors.append(Color(1.0, 0.97, 0.80) if point_index == 0 else petal)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = vertex_colors
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.9
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.surface_set_material(0, material)
	var palette: Array[Color] = [Color("d9bd6d"), Color("a98ac0"), Color("e3ddd0"), Color("9fb8c8")]
	var entries: Array = []
	var colors: Array[Color] = []
	for zone: Dictionary in [zones[0], zones[1]]:
		var center: Vector2 = zone["center"]
		var radius: float = zone["radius"]
		var placed: int = 0
		var attempts: int = 0
		while placed < 420 and attempts < 5200:
			attempts += 1
			var angle: float = _rng.randf_range(0.0, TAU)
			var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * sqrt(_rng.randf()) * radius * 0.9
			if absf(point.x) > BOUNDS - 4.0 or absf(point.y) > BOUNDS - 4.0:
				continue
			if _on_road(point, 0.30) or _near_site(point, 2.0) or _in_pond(point, 0.0):
				continue
			var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * _rng.randf_range(0.75, 1.35))
			entries.append(Transform3D(basis, _ground(point.x, point.y)))
			colors.append(palette[_rng.randi_range(0, palette.size() - 1)])
			placed += 1
	_register_streamed_multimesh("Wildflowers", mesh, entries, colors, false)


func _create_bushes() -> void:
	_reseed(6653)
	var mesh := _load_prop_mesh("bush.glb", "bark")
	if mesh == null:
		return
	# Surface 0 is bark, surface 1 is the alpha-card foliage, same contract as
	# the trees. The old single-surface bush was a handful of smooth green balls.
	if mesh.get_surface_count() > 1:
		mesh.surface_set_material(1, _materials["leaves_card"])
	var entries: Array = []
	var colors: Array[Color] = []
	for zone: Dictionary in zones:
		var center: Vector2 = zone["center"]
		var radius: float = zone["radius"]
		var placed: int = 0
		var attempts: int = 0
		while placed < 95 and attempts < 1200:
			attempts += 1
			var angle: float = _rng.randf_range(0.0, TAU)
			var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * sqrt(_rng.randf()) * radius * 0.92
			if absf(point.x) > BOUNDS - 3.0 or absf(point.y) > BOUNDS - 3.0:
				continue
			if _on_road(point, 0.85) or _near_site(point, 5.0) or _in_pond(point, 0.0):
				continue
			var scale_value: float = _rng.randf_range(0.72, 1.45)
			var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(
				Vector3(scale_value * _rng.randf_range(0.85, 1.2), scale_value * _rng.randf_range(0.8, 1.25), scale_value * _rng.randf_range(0.85, 1.2)))
			var at := _ground_lowest(point.x, point.y, 0.45)
			at.y -= 0.04
			entries.append(Transform3D(basis, at))
			var tint: Color = Color(1.0, 1.0, 1.0).lerp((zone["ground"] as Color).lightened(0.22), _rng.randf_range(0.10, 0.34))
			colors.append(tint)
			placed += 1
	# The outskirts need underbrush as well, otherwise the forest thins into lawn.
	var outskirt_placed: int = 0
	var outskirt_attempts: int = 0
	while outskirt_placed < 170 and outskirt_attempts < 2600:
		outskirt_attempts += 1
		var point := Vector2(
			_rng.randf_range(-BOUNDS + 4.0, BOUNDS - 4.0),
			_rng.randf_range(-BOUNDS + 4.0, BOUNDS - 4.0))
		if maxf(absf(point.x), absf(point.y)) < 58.0 or _inside_any_zone(point, 0.9):
			continue
		if _on_road(point, 0.85) or _near_site(point, 5.0) or _in_pond(point, 0.0):
			continue
		var at := _ground_lowest(point.x, point.y, 0.45)
		if at.y > 24.0:
			continue
		var scale_value: float = _rng.randf_range(0.72, 1.35)
		var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * scale_value)
		at.y -= 0.04
		entries.append(Transform3D(basis, at))
		colors.append(Color(1.0, 1.0, 1.0).lerp(_zone_ground_near(point).lightened(0.2), _rng.randf_range(0.10, 0.3)))
		outskirt_placed += 1
	_register_streamed_multimesh("Underbrush", mesh, entries, colors, true)


func _create_rocks_and_logs() -> void:
	_reseed(8831)
	for zone: Dictionary in zones:
		var center: Vector2 = zone["center"]
		var radius: float = zone["radius"]
		var target: int = int(zone.get("rock_count", 12))
		var placed: int = 0
		var attempts: int = 0
		while placed < target and attempts < target * 24:
			attempts += 1
			var angle: float = _rng.randf_range(0.0, TAU)
			var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * sqrt(_rng.randf()) * radius * 0.95
			if absf(point.x) > BOUNDS - 4.0 or absf(point.y) > BOUNDS - 4.0:
				continue
			# Two cells of clearance keep boulders out of the road ribbon and its
			# shoulders; the third cell is the grass verge.
			if _near_road(point.x, point.y, 2) or _near_site(point, 4.0) or _in_pond(point, 0.5):
				continue
			var size_value: float = _rng.randf_range(0.25, 0.78)
			var size := Vector3(size_value * _rng.randf_range(0.9, 1.55), size_value * _rng.randf_range(0.45, 0.8), size_value)
			var at: Vector3 = _ground_lowest(point.x, point.y, size.x * 0.5)
			# Sink the sphere so it grows out of the soil instead of resting on it.
			at.y -= size.y * 0.22
			var rock := _rock(at, size, "stone_dark" if _rng.randf() < 0.55 else "stone")
			if size_value > 0.6:
				rock.create_trimesh_collision()
			placed += 1
	for index: int in range(14):
		var zone: Dictionary = zones[index % zones.size()]
		var center: Vector2 = zone["center"]
		var point: Vector2 = center + Vector2(_rng.randf_range(-24.0, 24.0), _rng.randf_range(-24.0, 24.0))
		if absf(point.x) > BOUNDS - 6.0 or absf(point.y) > BOUNDS - 6.0:
			continue
		if _near_road(point.x, point.y, 2) or _near_site(point, 5.0) or _in_pond(point, 0.5):
			continue
		var at: Vector3 = _ground(point.x, point.y)
		var log_mesh: MeshInstance3D = _add_mesh(self, "FallenLog", _cylinder_mesh(0.30, _rng.randf_range(2.8, 4.8), 8), "wood")
		log_mesh.position = Vector3(at.x, at.y + 0.26, at.z)
		log_mesh.rotation = Vector3(PI * 0.5, _rng.randf_range(-1.0, 1.0), 0.0)
		log_mesh.create_trimesh_collision()
	_create_stones()


func _create_distant_landscape() -> void:
	# The mountains are part of the height field now, so there are no separate
	# crag meshes. A belt of pines along the foot of the rim hides the transition
	# from forest floor to rock and gives the horizon a scale reference.
	_reseed(6619)
	var mesh: Mesh = _load_tree_mesh("pine")
	if mesh == null:
		return
	var entries: Array = []
	var gate := Vector2(waygate_position.x, waygate_position.z)
	for index: int in range(1500):
		var point := Vector2(_rng.randf_range(-BOUNDS - 22.0, BOUNDS + 22.0), _rng.randf_range(-BOUNDS - 22.0, BOUNDS + 22.0))
		var edge: float = maxf(absf(point.x), absf(point.y))
		if edge < BOUNDS - 8.0 or edge > BOUNDS + 22.0:
			continue
		if point.distance_to(gate) < 24.0:
			continue
		var scale_value: float = _rng.randf_range(0.95, 1.45)
		var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * scale_value)
		if not _reserve_tree_position(point):
			continue
		var at := _ground_lowest(point.x, point.y, 0.45)
		at.y -= 0.05
		entries.append(Transform3D(basis, at))
	_register_streamed_multimesh("FoothillPines", mesh, entries, [], false, float(_tree_base.get("pine", 0.0)))


func _create_boundaries() -> void:
	for side: int in range(4):
		var body := StaticBody3D.new()
		body.name = "FrontierBoundary"
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.0, 30.0, BOUNDS * 2.0 + 6.0) if side < 2 else Vector3(BOUNDS * 2.0 + 6.0, 30.0, 2.0)
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		body.position = [Vector3(-BOUNDS - 2.0, 4.0, 0.0), Vector3(BOUNDS + 2.0, 4.0, 0.0), Vector3(0.0, 4.0, -BOUNDS - 2.0), Vector3(0.0, 4.0, BOUNDS + 2.0)][side]
		add_child(body)

func _create_frontier_landmarks() -> void:
	for landmark: Dictionary in frontier_landmarks:
		var at: Vector2 = landmark["at"]
		var place := _group("FrontierLandmark", at.x, at.y)
		var style: int = landmark["style"]
		var plinth := _add_mesh(place, "WeatheredPlinth", _cylinder_mesh(2.2, 0.30, 8), "stone_dark")
		plinth.position.y = 0.15
		var columns := 2 + style % 3
		for i in range(columns):
			var angle := TAU * float(i) / float(columns) + float(style) * 0.3
			_pillar(place, Vector3(cos(angle) * 1.45, 0.3, sin(angle) * 1.45), 0.35, 1.7 + 0.3 * ((i + style) % 3), "stone")
		if style == 0 or style == 3:
			var beam := _add_mesh(place, "FallenBeam", _box_mesh(Vector3(3.2, 0.45, 0.5)), "stone_light")
			beam.position = Vector3(0.1, 0.42, 2.1)
			beam.rotation.y = 0.35 * style
		var marker := _add_mesh(place, "LandmarkMarker", _box_mesh(Vector3(2.8, 0.55, 0.16)), "wood")
		marker.position = Vector3(0.0, 1.25, 2.7)
		_text(place, Vector3(0.0, 1.3, 2.8), str(landmark["name"]), 48, Color("cdbb92"))


# ---------------------------------------------------------------------------
# Landmarks
# ---------------------------------------------------------------------------

func _group(node_name: String, x: float, z: float) -> Node3D:
	var group := Node3D.new()
	group.name = node_name
	group.position = Vector3(x, height_at(x, z), z)
	add_child(group)
	return group


func _add_mesh(parent: Node, node_name: String, mesh: Mesh, material_key: String) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	if not material_key.is_empty() and _materials.has(material_key):
		instance.material_override = _materials[material_key]
	parent.add_child(instance)
	return instance


func _box_mesh(size: Vector3) -> BoxMesh:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh


func _cylinder_mesh(radius: float, height_value: float, segments: int = 12) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height_value
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh


func _cone_mesh(radius: float, height_value: float, segments: int = 6) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height_value
	mesh.radial_segments = segments
	mesh.rings = 1
	return mesh


## A cylinder stretched between two local points. Used for tent poles, guy ropes
## and any other member that must actually touch what it connects.
func _strut(parent: Node3D, from: Vector3, to: Vector3, radius: float, material_key: String, node_name: String = "Strut") -> MeshInstance3D:
	var direction := to - from
	if direction.length_squared() < 0.0001:
		direction = Vector3.UP * 0.001
	var normalized := direction.normalized()
	var up := Vector3.UP
	if absf(normalized.dot(Vector3.UP)) > 0.98:
		up = Vector3.BACK
	var instance := _add_mesh(parent, node_name, _cylinder_mesh(radius, direction.length(), 5), material_key)
	instance.position = (from + to) * 0.5
	instance.basis = Basis.looking_at(normalized, up) * Basis(Vector3.RIGHT, -PI * 0.5)
	return instance


func _sphere_mesh(radius: float, segments: int = 8, rings: int = 4) -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = segments
	mesh.rings = rings
	return mesh


## World-space primitives used by the scatter pass. `at.y` is an offset above
## the sampled terrain; the mesh is placed with its centre at that height.
func _box(node_name: String, at: Vector3, size: Vector3, material_key: String) -> MeshInstance3D:
	var instance := _add_mesh(self, node_name, _box_mesh(size), material_key)
	instance.position = Vector3(at.x, height_at(at.x, at.z) + at.y + size.y * 0.5, at.z)
	return instance


func _cylinder(node_name: String, at: Vector3, radius: float, height_value: float, material_key: String, segments: int = 16) -> MeshInstance3D:
	var instance := _add_mesh(self, node_name, _cylinder_mesh(radius, height_value, segments), material_key)
	instance.position = Vector3(at.x, height_at(at.x, at.z) + at.y + height_value * 0.5, at.z)
	return instance


func _cone(node_name: String, at: Vector3, radius: float, height_value: float, material_key: String, segments: int = 6) -> MeshInstance3D:
	var instance := _add_mesh(self, node_name, _cone_mesh(radius, height_value, segments), material_key)
	instance.position = Vector3(at.x, height_at(at.x, at.z) + at.y + height_value * 0.5, at.z)
	return instance


## A flat disc at an exact world height, used for pools whose basin is already
## levelled by height_at. Terrain-relative helpers would sink or float them.
func _flattened_disc(node_name: String, at: Vector3, radius: float, material_key: String, segments: int = 20) -> MeshInstance3D:
	var instance := _add_mesh(self, node_name, _cylinder_mesh(radius, 0.04, segments), material_key)
	instance.position = at
	return instance


## `at` is already a world position (the caller sampled the terrain).
func _rock(at: Vector3, size: Vector3, material_key: String) -> MeshInstance3D:
	var variant: String = "rock_%d.glb" % _rng.randi_range(1, 3)
	var mesh: Mesh = _load_prop_mesh(variant, material_key)
	if mesh == null:
		mesh = _sphere_mesh(0.9, 7, 4)
	var instance := MeshInstance3D.new()
	instance.name = "Boulder"
	instance.mesh = mesh
	instance.position = at
	instance.scale = Vector3(size.x * 1.15, size.x * _rng.randf_range(0.75, 1.15), size.z * 1.05)
	instance.rotation = Vector3(0.0, _rng.randf_range(0.0, TAU), 0.0)
	add_child(instance)
	return instance


## Loose stones are the small stuff that makes a meadow floor read as ground
## instead of a flat texture: no collision, no shadows, one draw call each.
func _create_stones() -> void:
	_reseed(4471)
	for variant in ["stone_1.glb", "stone_2.glb"]:
		var mesh: Mesh = _load_prop_mesh(variant, "stone")
		if mesh == null:
			continue
		var entries: Array = []
		var attempts: int = 0
		while entries.size() < 190 and attempts < 3200:
			attempts += 1
			var point := Vector2(
				_rng.randf_range(-BOUNDS + 2.0, BOUNDS - 2.0),
				_rng.randf_range(-BOUNDS + 2.0, BOUNDS - 2.0))
			if _on_road(point, 0.15) or _near_site(point, 3.0) or _in_pond(point, 0.05):
				continue
			var at := _ground_lowest(point.x, point.y, 0.3)
			if at.y > 30.0:
				continue
			var scale_value: float = _rng.randf_range(0.45, 1.2)
			var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(
				Vector3(scale_value, scale_value * _rng.randf_range(0.7, 1.05), scale_value))
			at.y -= 0.02
			entries.append(Transform3D(basis, at))
		_create_multimesh("LooseStones_" + variant.get_basename(), mesh, entries, false)


func _light(parent: Node3D, at: Vector3, color: Color, energy: float, range_value: float) -> OmniLight3D:
	var light_node := OmniLight3D.new()
	light_node.name = "WarmLight"
	light_node.position = at
	light_node.light_color = color
	light_node.light_energy = energy
	light_node.omni_range = range_value
	light_node.omni_attenuation = 1.4
	light_node.shadow_enabled = false
	parent.add_child(light_node)
	return light_node


## A lamp or brazier light that follows the day/night cycle. The authored
## energy is remembered so `_apply_time_of_day` can dim it without drifting.
func _night_light(parent: Node3D, at: Vector3, color: Color, energy: float, range_value: float) -> OmniLight3D:
	var light := _light(parent, at, color, energy, range_value)
	light.set_meta("night_energy", energy)
	_night_lights.append(light)
	return light


func _text(parent: Node3D, at: Vector3, message: String, font_size: int = 72, color: Color = Color.WHITE, face_camera: bool = false) -> Label3D:
	var label := Label3D.new()
	label.name = "Sign"
	label.text = message
	label.position = at
	label.font_size = font_size
	label.pixel_size = 0.0075
	label.modulate = color
	label.outline_size = 16
	label.outline_modulate = Color(0.04, 0.05, 0.05, 0.92)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED if face_camera else BaseMaterial3D.BILLBOARD_DISABLED
	label.no_depth_test = false
	label.shaded = false
	parent.add_child(label)
	return label


## Soft animated fire sprites, authored in Blender and shared by all fires.
func _flame(parent: Node3D, at: Vector3, scale_value: float = 1.0, local_particles: bool = false) -> void:
	var group := Node3D.new()
	group.name = "Flame"
	group.position = at
	group.scale = Vector3.ONE * scale_value
	parent.add_child(group)
	group.add_to_group("world_flames", true)
	var material := StandardMaterial3D.new()
	material.albedo_texture = load("res://assets/textures/fire_sprite.png")
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.emission_enabled = true
	material.emission = Color("ff7626")
	material.emission_energy_multiplier = 0.65 if local_particles else 1.4
	if local_particles:
		material.albedo_color = Color(0.85, 0.7, 0.6, 0.65)
	var quad := QuadMesh.new()
	quad.size = Vector2(0.45, 0.8) if local_particles else Vector2(0.62, 1.0)
	quad.material = material
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.UP
	process.spread = 20.0
	process.gravity = Vector3(0, 0.25, 0)
	process.initial_velocity_min = 0.25
	process.initial_velocity_max = 0.65
	process.scale_min = 0.65
	process.scale_max = 1.15
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	process.emission_sphere_radius = 0.18
	var particles := GPUParticles3D.new()
	particles.name = "FireParticles"
	particles.amount = 8 if local_particles else 18
	particles.lifetime = 0.85
	particles.preprocess = 1.0
	# The lowest possible sprite edge (half-height * max scale plus the
	# emission radius) remains just above the rim, rather than under the bowl.
	particles.position.y = 0.66 if local_particles else 0.32
	particles.local_coords = local_particles
	particles.process_material = process
	particles.draw_pass_1 = quad
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	group.add_child(particles)
	var fire_sound := AudioStreamPlayer3D.new()
	fire_sound.name = "FireSound"
	var stream: AudioStreamWAV = load("res://assets/audio/campfire_crackle.wav" if scale_value > 1.0 else "res://assets/audio/torch_crackle.wav").duplicate()
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = stream.data.size() / 2
	fire_sound.stream = stream
	fire_sound.max_distance = 16.0 if scale_value > 1.0 else 8.0
	fire_sound.unit_size = 3.0 if scale_value > 1.0 else 1.5
	fire_sound.set_meta("base_db", -10.0 if scale_value > 1.0 else -15.0)
	group.add_child(fire_sound)
	_flames.append(group)


func _campfire(parent: Node3D, at: Vector3) -> void:
	# A sunken ash bed ringed by uneven field stones. The old fire floated on a
	# perfect circle of identical rocks; variation in size and height sells it.
	var ash := _add_mesh(parent, "FireAsh", _cylinder_mesh(0.98, 0.07, 12), "ash")
	ash.position = at + Vector3(0.0, 0.045, 0.0)
	for index: int in range(15):
		var angle: float = TAU * float(index) / 15.0 + 0.12
		var radius: float = 1.08 + (0.07 if index % 2 == 0 else -0.04)
		var stone_size: float = 0.23 + 0.05 * float(index % 3)
		var stone_mesh := _load_prop_mesh("stone_%d.glb" % (1 + index % 2), "stone")
		var stone := _add_mesh(parent, "FireStone", stone_mesh, "")
		stone.position = at + Vector3(cos(angle) * radius, 0.02, sin(angle) * radius)
		var stone_scale := stone_size / (0.32 if index % 2 == 0 else 0.22)
		stone.scale = Vector3(stone_scale, stone_scale * 0.9, stone_scale)
		stone.rotation.y = angle
	# Original charred and bark-covered firewood, built around the same flame.
	_camp_model(parent, "camp_firewood.glb", "Firewood", at)
	for index: int in range(12):
		var angle: float = TAU * float(index) / 12.0 + 0.2
		var radius: float = _rng.randf_range(0.18, 0.62)
		var ember := _add_mesh(parent, "FireEmber", _sphere_mesh(0.055, 5, 3), "fire")
		ember.add_to_group("campfire_embers", true)
		ember.position = at + Vector3(cos(angle) * radius, 0.10, sin(angle) * radius)
		ember.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_camp_embers.append(ember)
	_flame(parent, at + Vector3(0.0, 0.16, 0.0), 1.42)
	var fire_light := _night_light(parent, at + Vector3(0.0, 1.55, 0.0), Color("ffb266"), 2.4, 14.0)
	fire_light.name = "CampfireLight"


## A half-buried log beside the fire, cut flat on top so it reads as a seat.
func _sitting_log(parent: Node3D, at: Vector3, rotation_y: float) -> void:
	var log_node := Node3D.new()
	log_node.name = "SittingLog"
	log_node.position = at
	log_node.rotation.y = rotation_y
	parent.add_child(log_node)
	log_node.add_to_group("camp_seats", true)
	var body := StaticBody3D.new()
	body.name = "SeatCollision"
	log_node.add_child(body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.5, 0.55, 0.58)
	collision.name = "CollisionShape3D"
	collision.shape = shape
	collision.position.y = 0.275
	body.add_child(collision)
	_camp_model(log_node, "camp_log_seat.glb", "LogSeat", Vector3.ZERO)


func _camp_model(parent: Node3D, file_name: String, node_name: String, at: Vector3) -> Node3D:
	var scene: PackedScene = load("res://assets/models/props/" + file_name)
	var model := scene.instantiate() as Node3D
	model.name = node_name
	model.position = at
	parent.add_child(model)
	return model


func _ground_bed(tent: Node3D, at: Vector3, rotation_y: float) -> void:
	var bed := Node3D.new()
	bed.name = "GroundBed"
	bed.position = at
	bed.rotation.y = rotation_y
	tent.add_child(bed)
	_camp_model(bed, "camp_bed.glb", "Bedding", Vector3.ZERO)


## Walk-in A-frame. The front is open; both sloped sides and the rear wall are
## solid, so the player can step inside and stand beside a proper ground bed.
func _tent(parent: Node3D, at: Vector3, rotation_y: float, cloth_key: String = "cloth") -> void:
	var tent := Node3D.new()
	tent.name = "Tent"
	tent.position = at
	tent.rotation.y = rotation_y
	parent.add_child(tent)
	var width: float = 4.0
	var height_value: float = 2.7
	var depth: float = 5.6
	_camp_model(tent, "camp_tent.glb", "TentCanopy", Vector3.ZERO)
	# A rigid floor cloth and a pegged skirt hide the ground seam on the blend
	# slope beyond the flattened camp pad.
	var floor_cloth := _add_mesh(tent, "TentFloor", _box_mesh(Vector3(width * 0.92, 0.04, depth * 0.92)), "cloth_dark")
	floor_cloth.position = Vector3(0.0, 0.02, 0.0)
	for side: float in [-1.0, 1.0]:
		var skirt := _add_mesh(tent, "TentSkirt", _box_mesh(Vector3(0.05, 0.44, depth)), cloth_key)
		skirt.position = Vector3(side * width * 0.5, -0.18, 0.0)
	var back_skirt := _add_mesh(tent, "TentBackSkirt", _box_mesh(Vector3(width, 0.44, 0.05)), cloth_key)
	back_skirt.position = Vector3(0.0, -0.18, -depth * 0.5)
	var slope: float = sqrt(pow(width * 0.5, 2.0) + pow(height_value, 2.0))
	var slope_angle: float = atan2(height_value, width * 0.5)
	for side: float in [-1.0, 1.0]:
		# Guy ropes pulled to pegs fore and aft.
		for end: float in [-1.0, 1.0]:
			_strut(tent, Vector3(0.0, height_value, end * depth * 0.5), Vector3(side * (width * 0.5 + 1.15), 0.02, end * (depth * 0.5 + 0.95)), 0.014, "cloth_dark", "GuyRope")
	# Two ground beds at the back, one on either side, leave a clear aisle from
	# the entrance to the fire pit.
	_ground_bed(tent, Vector3(-0.98, 0.0, -0.55), 0.0)
	_ground_bed(tent, Vector3(0.98, 0.0, -0.55), 0.0)
	# A candle-lantern hanging from the ridge gives the interior a warm glow.
	var lantern := _add_mesh(tent, "TentLantern", _sphere_mesh(0.09, 6, 3), "fire")
	lantern.position = Vector3(0.0, 1.92, 0.35)
	lantern.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_night_light(tent, Vector3(0.0, 1.9, 0.35), Color("ffc27a"), 0.5, 4.2)
	# Solid cloth: sloped sides and the rear wall. The mouth stays open.
	var walls := StaticBody3D.new()
	walls.name = "TentWalls"
	tent.add_child(walls)
	for side: float in [-1.0, 1.0]:
		var wall := CollisionShape3D.new()
		var wall_shape := BoxShape3D.new()
		wall_shape.size = Vector3(slope, 0.12, depth)
		wall.shape = wall_shape
		wall.position = Vector3(side * width * 0.25, height_value * 0.5, 0.0)
		wall.rotation.z = -side * slope_angle
		walls.add_child(wall)
	var rear_wall := CollisionShape3D.new()
	var rear_shape := BoxShape3D.new()
	rear_shape.size = Vector3(width * 0.86, height_value * 0.86, 0.12)
	rear_wall.shape = rear_shape
	rear_wall.position = Vector3(0.0, height_value * 0.43, -depth * 0.5 + 0.09)
	walls.add_child(rear_wall)



func _banner(parent: Node3D, at: Vector3, rotation_y: float, cloth_key: String = "banner") -> void:
	var banner := Node3D.new()
	banner.name = "Banner"
	banner.position = at
	banner.rotation.y = rotation_y
	parent.add_child(banner)
	var pole := _add_mesh(banner, "BannerPole", _cylinder_mesh(0.07, 3.5, 6), "wood")
	pole.position = Vector3(0.0, 1.75, 0.0)
	var bar := _add_mesh(banner, "BannerBar", _box_mesh(Vector3(1.05, 0.07, 0.09)), "wood_light")
	bar.position = Vector3(0.5, 3.28, 0.0)
	var cloth := _add_mesh(banner, "BannerCloth", _box_mesh(Vector3(0.95, 1.45, 0.05)), cloth_key)
	cloth.position = Vector3(0.5, 2.54, 0.0)
	var tip := _add_mesh(banner, "BannerTip", _cone_mesh(0.11, 0.36, 5), "copper")
	tip.position = Vector3(0.0, 3.62, 0.0)


func _lamp(parent: Node3D, at: Vector3) -> void:
	_road_lamp(parent, at, 0.0)


## Medieval verge lamp: stone footing, iron post, one arm reaching over the road
## and a bar-caged lantern. Few and far apart, so each one reads as a waypoint.
func _road_lamp(parent: Node3D, at: Vector3, rotation_y: float) -> void:
	var lamp := Node3D.new()
	lamp.name = "RoadLamp"
	lamp.position = at
	lamp.rotation.y = rotation_y
	# The complete lit silhouette is approximately the height of the player.
	lamp.scale = Vector3.ONE * 0.60
	parent.add_child(lamp)
	var model: PackedScene = load("res://assets/models/props/road_cresset.glb")
	var cresset := model.instantiate() as Node3D
	cresset.name = "TripodCresset"
	lamp.add_child(cresset)
	_flame(lamp, Vector3(0.0, 2.28, 0.0), 0.60, true)
	_night_light(lamp, Vector3(0.0, 2.5, 0.0), Color("ffc27a"), 1.45, 11.0)
	# The post is solid: a player cannot walk through a lamp on the verge.
	var body := StaticBody3D.new()
	body.name = "LampBody"
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.48
	shape.height = 2.5
	collision.shape = shape
	collision.position.y = 1.25
	body.add_child(collision)
	lamp.add_child(body)


func _brazier(parent: Node3D, at: Vector3, energy: float = 1.1) -> void:
	var base := _add_mesh(parent, "BrazierBase", _cylinder_mesh(0.16, 0.85, 6), "iron")
	base.position = at + Vector3(0.0, 0.43, 0.0)
	var bowl := _add_mesh(parent, "BrazierBowl", _cylinder_mesh(0.44, 0.3, 8), "iron")
	bowl.position = at + Vector3(0.0, 0.95, 0.0)
	var coals := _add_mesh(parent, "BrazierCoals", _cylinder_mesh(0.35, 0.06, 8), "fire")
	coals.position = at + Vector3(0.0, 1.1, 0.0)
	coals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flame(parent, at + Vector3(0.0, 1.1, 0.0), 0.62)
	_night_light(parent, at + Vector3(0.0, 1.7, 0.0), Color("ff9d55"), energy, 9.0)


func _barrel(parent: Node3D, at: Vector3) -> void:
	var body := _add_mesh(parent, "Barrel", _cylinder_mesh(0.36, 0.86, 10), "wood_light")
	body.position = at + Vector3(0.0, 0.43, 0.0)
	for height_value: float in [0.2, 0.66]:
		var band := _add_mesh(parent, "BarrelBand", _cylinder_mesh(0.375, 0.07, 10), "iron")
		band.position = at + Vector3(0.0, height_value, 0.0)


func _crate(parent: Node3D, at: Vector3, size_value: float = 0.72, rotation_y: float = 0.0) -> void:
	var crate := Node3D.new()
	crate.name = "Crate"
	crate.position = at
	crate.rotation.y = rotation_y
	parent.add_child(crate)
	var body := _add_mesh(crate, "CrateBody", _box_mesh(Vector3.ONE * size_value), "wood_light")
	body.position.y = size_value * 0.5
	for side: float in [-1.0, 1.0]:
		var brace := _add_mesh(crate, "CrateBrace", _box_mesh(Vector3(size_value + 0.03, 0.06, 0.06)), "wood")
		brace.position = Vector3(0.0, size_value * 0.5, side * size_value * 0.5)


func _wall(parent: Node3D, at: Vector3, size: Vector3, rotation_y: float = 0.0, material_key: String = "stone") -> void:
	var block := _add_mesh(parent, "Wall", _box_mesh(size), material_key)
	block.position = at + Vector3(0.0, size.y * 0.5, 0.0)
	block.rotation.y = rotation_y


func _pillar(parent: Node3D, at: Vector3, radius: float, height_value: float, material_key: String = "stone", broken: bool = false, tilt: float = 0.0) -> Node3D:
	var pillar := Node3D.new()
	pillar.name = "Pillar"
	pillar.position = at
	pillar.rotation.z = tilt
	parent.add_child(pillar)
	var base := _add_mesh(pillar, "PillarBase", _box_mesh(Vector3(radius * 2.8, 0.32, radius * 2.8)), material_key)
	base.position.y = 0.16
	var shaft_height: float = height_value * (0.55 if broken else 1.0)
	var shaft := _add_mesh(pillar, "PillarShaft", _cylinder_mesh(radius, shaft_height, 10), material_key)
	shaft.position.y = 0.32 + shaft_height * 0.5
	if not broken:
		var capital := _add_mesh(pillar, "PillarCapital", _box_mesh(Vector3(radius * 2.5, 0.26, radius * 2.5)), material_key)
		capital.position.y = 0.32 + shaft_height + 0.13
	else:
		var stub := _add_mesh(pillar, "PillarStub", _cone_mesh(radius * 0.95, 0.3, 7), material_key)
		stub.position.y = 0.32 + shaft_height + 0.1
	return pillar


func _arch(parent: Node3D, at: Vector3, rotation_y: float, span: float, height_value: float, broken: bool = false) -> Node3D:
	var arch := Node3D.new()
	arch.name = "Arch"
	arch.position = at
	arch.rotation.y = rotation_y
	parent.add_child(arch)
	var left := _pillar(arch, Vector3(-span * 0.5, 0.0, 0.0), 0.44, height_value)
	var right := _pillar(arch, Vector3(span * 0.5, 0.0, 0.0), 0.44, height_value)
	if broken:
		right.rotation.z = 0.09
		var fallen := _add_mesh(arch, "FallenBlock", _box_mesh(Vector3(1.4, 0.55, 0.7)), "stone")
		fallen.position = Vector3(span * 0.5 + 1.2, 0.28, 0.5)
		fallen.rotation = Vector3(0.0, 0.5, 0.16)
		return arch
	var lintel := _add_mesh(arch, "ArchLintel", _box_mesh(Vector3(span + 1.5, 0.55, 0.95)), "stone_light")
	lintel.position.y = height_value + 0.58
	var crown := _add_mesh(arch, "ArchCrown", _box_mesh(Vector3(0.9, 0.4, 1.05)), "stone")
	crown.position.y = height_value + 1.02
	return arch


## A low split-rail fence rings the camp and opens exactly where a trade road
## crosses it. Each gate is centred on the road direction, so the approach is
## never blocked and the opening reads as a real entrance rather than a gap.
func _create_camp_fence(parent: Node3D) -> void:
	_reseed(5519)
	var radius: float = 13.2
	var gate_half_width: float = 3.0
	var gate_half: float = asin(clampf(gate_half_width / radius, 0.0, 1.0))
	var center := Vector2(camp_position.x, camp_position.z)
	var gate_angles: Array[float] = []
	for polyline: PackedVector2Array in roads:
		if polyline.size() < 2:
			continue
		var start: Vector2 = polyline[0]
		var direction: Vector2 = polyline[1] - polyline[0]
		if start.distance_to(center) > 2.0:
			start = polyline[polyline.size() - 1]
			direction = polyline[polyline.size() - 2] - start
			if start.distance_to(center) > 2.0:
				continue
		if direction.length() < 0.01:
			continue
		gate_angles.append(atan2(direction.y, direction.x))
	gate_angles.sort()
	if gate_angles.is_empty():
		gate_angles = [0.0]
	var walls := StaticBody3D.new()
	walls.name = "CampFenceBody"
	parent.add_child(walls)
	var gate_torch_positions: Array[Vector3] = []
	# Gate frames first: two tall posts and a lintel beam across the opening.
	for angle: float in gate_angles:
		var left := angle - gate_half
		var right := angle + gate_half
		_camp_fence_post(parent, left, radius, true)
		_camp_fence_post(parent, right, radius, true)
		# Outside the gate posts, with a clear pedestrian opening between them.
		for side: float in [-1.0, 1.0]:
			var torch_angle := angle + side * (gate_half + 0.085)
			var torch_at := _camp_fence_point(torch_angle, radius + 1.0)
			var overlaps := false
			for existing: Vector3 in gate_torch_positions:
				if Vector2(existing.x, existing.z).distance_to(Vector2(torch_at.x, torch_at.z)) < 2.0:
					overlaps = true
					break
			if overlaps:
				continue
			gate_torch_positions.append(torch_at)
			_road_lamp(parent, torch_at, torch_angle)
		var from := _camp_fence_point(left, radius) + Vector3.UP * 2.42
		var to := _camp_fence_point(right, radius) + Vector3.UP * 2.42
		_strut(parent, from, to, 0.075, "camp_timber", "GateBeam")
		_strut(parent, from, from + Vector3.DOWN * 0.62, 0.045, "camp_timber", "GateBrace")
		_strut(parent, to, to + Vector3.DOWN * 0.62, 0.045, "camp_timber", "GateBrace")
	# Then fill each arc between consecutive gates with posts and two rails.
	for gate_index: int in range(gate_angles.size()):
		var start_angle: float = gate_angles[gate_index] + gate_half
		var end_angle: float = gate_angles[(gate_index + 1) % gate_angles.size()] - gate_half
		if gate_index == gate_angles.size() - 1:
			end_angle += TAU
		var span: float = end_angle - start_angle
		if span <= 0.05:
			continue
		var pieces: int = maxi(2, int(round(span * radius / 2.35)))
		for piece: int in range(pieces):
			var a0: float = start_angle + span * float(piece) / float(pieces)
			var a1: float = start_angle + span * float(piece + 1) / float(pieces)
			if piece > 0:
				_camp_fence_post(parent, a0, radius, false)
			var from := _camp_fence_point(a0, radius)
			var to := _camp_fence_point(a1, radius)
			for rail_height: float in [0.52, 1.02]:
				_strut(parent, from + Vector3.UP * rail_height, to + Vector3.UP * rail_height, 0.07, "camp_timber", "FenceRail")
			var shape := BoxShape3D.new()
			var segment := to - from
			shape.size = Vector3(Vector2(segment.x, segment.z).length(), 1.16, 0.16)
			var collision := CollisionShape3D.new()
			collision.shape = shape
			collision.position = (from + to) * 0.5 + Vector3.UP * 0.58
			collision.rotation.y = atan2(-segment.z, segment.x)
			walls.add_child(collision)


func _camp_fence_point(angle: float, radius: float) -> Vector3:
	var x: float = camp_position.x + cos(angle) * radius
	var z: float = camp_position.z + sin(angle) * radius
	return Vector3(cos(angle) * radius, height_at(x, z) - camp_position.y, sin(angle) * radius)


func _camp_fence_post(parent: Node3D, angle: float, radius: float, tall: bool) -> void:
	var at := _camp_fence_point(angle, radius)
	var height_value: float = 2.34 if tall else 1.46 + 0.10 * sin(angle * 11.0)
	var thickness: float = 0.15 if tall else 0.10
	var post_mesh := _cylinder_mesh(thickness, height_value, 8)
	post_mesh.top_radius = thickness * 0.78
	var post := _add_mesh(parent, "FencePost", post_mesh, "camp_timber")
	post.position = at + Vector3.UP * (height_value * 0.5)
	post.rotation.y = angle
	if tall:
		var cap := _add_mesh(parent, "GateFinial", _cone_mesh(thickness * 1.5, 0.22, 6), "wood_light")
		cap.position = at + Vector3.UP * (height_value + 0.11)
	else:
		for rail_height: float in [0.52, 1.02]:
			var lashing := _add_mesh(parent, "FenceLashing", _cylinder_mesh(thickness * 1.10, 0.07, 8), "straw")
			lashing.position = at + Vector3.UP * rail_height


func _create_camp() -> void:
	_reseed(2203)
	var camp := _group("SurvivorCamp", camp_position.x, camp_position.z)
	_create_camp_fence(camp)
	_campfire(camp, Vector3.ZERO)
	# Two seats turned toward the hearth instead of an empty clearing.
	_sitting_log(camp, Vector3(0.0, 0.0, 3.35), 0.0)
	_sitting_log(camp, Vector3(0.0, 0.0, -3.35), 0.0)
	# Four walk-in tents, mouths facing the fire, backs inside the fence line.
	_tent(camp, Vector3(-6.3, 0.0, -5.5), 0.85, "cloth")
	_tent(camp, Vector3(6.4, 0.0, -5.5), -0.85, "cloth_dark")
	_tent(camp, Vector3(-6.3, 0.0, 5.5), 2.29, "cloth_dark")
	_tent(camp, Vector3(6.4, 0.0, 5.5), -2.29, "cloth")
	# Forge and anvil on the open east side of the ring; the blacksmith stands
	# here and faces the fire. The anvil horn points back toward the hearth.
	_wall(camp, Vector3(9.0, 0.0, -0.1), Vector3(1.9, 1.0, 1.3), -PI * 0.5, "stone_dark")
	var coal := _add_mesh(camp, "ForgeCoals", _box_mesh(Vector3(0.8, 0.1, 1.3)), "fire")
	coal.position = Vector3(9.0, 1.02, -0.1)
	coal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_light(camp, Vector3(9.0, 1.8, -0.1), Color("ff9a4d"), 1.35, 8.0)
	var stump := _add_mesh(camp, "AnvilStump", _cylinder_mesh(0.42, 0.62, 8), "wood")
	stump.position = Vector3(9.0, 0.31, 1.8)
	var anvil := _add_mesh(camp, "Anvil", _box_mesh(Vector3(0.34, 0.34, 0.62)), "iron")
	anvil.position = Vector3(9.0, 0.79, 1.8)
	var horn := _add_mesh(camp, "AnvilHorn", _cone_mesh(0.16, 0.5, 5), "iron")
	horn.position = Vector3(8.62, 0.8, 1.8)
	horn.rotation.z = PI * 0.5
	_barrel(camp, Vector3(7.6, 0.0, -3.0))
	_barrel(camp, Vector3(8.2, 0.0, -3.4))
	_crate(camp, Vector3(6.9, 0.0, -3.1), 0.7, 0.3)
	_crate(camp, Vector3(6.9, 0.7, -3.1), 0.55, -0.2)
	_banner(camp, Vector3(0.0, 0.0, 10.3), PI, "banner")
	_banner(camp, Vector3(0.0, 0.0, -10.3), 0.0, "banner")
	# Wayfarer sign just inside the eastern road gate, read from both sides.
	var sign_root := Vector3(10.1, 0.0, -4.9)
	var facing: float = atan2(-sign_root.x, -sign_root.z)
	var post := _add_mesh(camp, "SignPost", _box_mesh(Vector3(0.16, 2.0, 0.16)), "wood")
	post.position = sign_root + Vector3(0.0, 1.0, 0.0)
	var board := _add_mesh(camp, "SignBoard", _box_mesh(Vector3(3.2, 0.72, 0.14)), "wood_light")
	board.position = sign_root + Vector3(0.0, 1.82, 0.0)
	board.rotation.y = facing
	var face_normal := Vector3(sin(facing), 0.0, cos(facing))
	var sign_text := _text(camp, sign_root + Vector3(0.0, 1.82, 0.0) + face_normal * 0.095, "EMBERFALL CAMP", 34, Color("e6d6a8"))
	sign_text.rotation.y = facing
	# A signpost is read from both directions; the second face is rotated, not
	# mirrored, so the lettering stays legible on the road side.
	var sign_back := _text(camp, sign_root + Vector3(0.0, 1.82, 0.0) - face_normal * 0.095, "EMBERFALL CAMP", 34, Color("e6d6a8"))
	sign_back.rotation.y = facing + PI


func _create_broken_arch() -> void:
	_reseed(3307)
	var site := _group("BrokenArch", 122.0, -116.0)
	var terrace := _add_mesh(site, "Terrace", _cylinder_mesh(8.6, 0.55, 14), "stone")
	terrace.position.y = 0.27
	var inset := _add_mesh(site, "TerraceInset", _cylinder_mesh(7.4, 0.4, 14), "stone_light")
	inset.position.y = 0.52
	var aisle := _add_mesh(site, "Aisle", _box_mesh(Vector3(2.2, 0.1, 11.5)), "stone_dark")
	aisle.position.y = 0.6
	_arch(site, Vector3(0.0, 0.55, -3.4), 0.0, 5.2, 3.1, true)
	_arch(site, Vector3(-0.2, 0.55, 4.6), 0.0, 3.4, 2.2, true)
	for index: int in range(8):
		var angle: float = TAU * float(index) / 8.0 + 0.2
		var radius: float = 6.1 if index % 2 == 0 else 5.2
		var spot := Vector3(cos(angle) * radius, 0.52, sin(angle) * radius)
		if spot.z < -4.4:
			continue
		_pillar(site, spot, 0.34, _rng.randf_range(1.5, 2.8), "stone_light" if index % 3 == 0 else "stone", index % 3 == 1, _rng.randf_range(-0.05, 0.05))
	_brazier(site, Vector3(-4.4, 0.52, 5.2))
	_brazier(site, Vector3(4.4, 0.52, 5.2))
	for index: int in range(9):
		var angle: float = _rng.randf_range(0.0, TAU)
		var radius: float = _rng.randf_range(6.8, 9.4)
		var at := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		var rubble := _rock(site.position + Vector3(at.x, 0.22, at.z), Vector3(_rng.randf_range(0.4, 1.1), _rng.randf_range(0.25, 0.6), _rng.randf_range(0.4, 1.0)), "stone")
		rubble.rotation.y = angle


func _create_sanctum() -> void:
	_reseed(4409)
	var site := _group("CrownlessSanctum", -142.0, -150.0)
	var dais := _add_mesh(site, "Dais", _cylinder_mesh(4.4, 0.5, 16), "stone_dark")
	dais.position.y = 0.25
	var step := _add_mesh(site, "DaisStep", _cylinder_mesh(3.2, 0.36, 16), "stone")
	step.position.y = 0.68
	_light(site, Vector3(0.0, 1.6, 0.0), Color("79c3b5"), 1.1, 9.0)
	for index: int in range(9):
		var angle: float = TAU * float(index) / 9.0
		var radius: float = 7.4 if index % 2 == 0 else 8.6
		var spot := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		_pillar(site, spot, 0.52, _rng.randf_range(3.2, 5.4), "stone_dark" if index % 2 == 0 else "stone", index == 4)
		if index % 3 == 0:
			_brazier(site, spot + Vector3(0.0, 0.0, 1.6), 0.85)
	_banner(site, Vector3(-9.8, 0.0, -1.2), 0.7, "banner")
	_banner(site, Vector3(9.6, 0.0, -1.4), -0.8, "banner")
	for index: int in range(12):
		var angle: float = _rng.randf_range(0.0, TAU)
		var radius: float = _rng.randf_range(10.0, 14.0)
		var at := Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		_rock(site.position + Vector3(at.x, 0.2, at.z), Vector3(_rng.randf_range(0.5, 1.3), _rng.randf_range(0.3, 0.75), _rng.randf_range(0.5, 1.2)), "stone_dark")


func _create_waygate() -> void:
	_reseed(5519)
	var site := _group("SealedWaygate", waygate_position.x, waygate_position.z)
	var pad := _add_mesh(site, "WaygatePad", _cylinder_mesh(8.5, 0.4, 20), "stone_dark")
	pad.position.y = 0.2
	var inlay := _add_mesh(site, "WaygateInlay", _cylinder_mesh(7.1, 0.12, 20), "stone")
	inlay.position.y = 0.42
	for index: int in range(20):
		var angle: float = TAU * float(index) / 20.0
		var rune := _add_mesh(site, "GateRune", _box_mesh(Vector3(0.34, 0.05, 0.34)), "rune_dim")
		rune.position = Vector3(cos(angle) * 6.2, 0.5, sin(angle) * 6.2)
		rune.rotation.y = angle
	for side: float in [-1.0, 1.0]:
		var post := _pillar(site, Vector3(side * 4.3, 0.4, 0.0), 0.55, 5.6, "stone")
		post.rotation.y = 0.0
		var cap := _add_mesh(site, "GateCap", _box_mesh(Vector3(1.9, 0.4, 1.9)), "stone_light")
		cap.position = Vector3(side * 4.3, 6.35, 0.0)
	var lintel := _add_mesh(site, "GateLintel", _box_mesh(Vector3(10.4, 0.9, 1.6)), "stone_light")
	lintel.position.y = 6.98
	var keystone := _add_mesh(site, "GateKeystone", _cone_mesh(0.7, 0.7, 4), "rune_dim")
	keystone.position.y = 7.7
	keystone.rotation.y = PI * 0.25
	# The dormant portal: dim, slow-pulsing and never walkable.
	var portal := _add_mesh(site, "DormantPortal", _cylinder_mesh(2.55, 0.12, 28), "portal")
	portal.rotation.x = PI * 0.5
	portal.position = Vector3(0.0, 3.55, 0.0)
	portal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 2.68
	ring_mesh.outer_radius = 2.96
	ring_mesh.rings = 28
	ring_mesh.ring_segments = 8
	_portal_ring = _add_mesh(site, "PortalRing", ring_mesh, "portal_ring")
	_portal_ring.rotation.x = PI * 0.5
	_portal_ring.position = Vector3(0.0, 3.55, 0.0)
	_portal_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_portal_material = _materials["portal"] as StandardMaterial3D
	for side: float in [-1.0, 1.0]:
		_brazier(site, Vector3(side * 6.4, 0.4, 3.0), 0.9)
		_banner(site, Vector3(side * 7.4, 0.0, -1.6), side * 0.9, "banner")
	# The road arrives from the south-east, so the plaque faces +Z and is read
	# straight on instead of mirrored through its own backing board.
	var plaque := _add_mesh(site, "WaygatePlaque", _box_mesh(Vector3(4.4, 0.9, 0.18)), "stone_dark")
	plaque.position = Vector3(0.0, 1.0, 7.0)
	var plaque_text := _text(site, Vector3(0.0, 1.05, 7.12), "WAYGATE  /  SEALED", 60, Color("9fc9c1"))


