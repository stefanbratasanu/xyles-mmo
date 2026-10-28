extends Node3D
class_name XylesWorldBuilder

## Map I - The Ashen Frontier.
##
## Every visual is original Godot geometry, one of the generated nature textures
## in res://assets/textures, or one of the low-poly trees exported from Blender
## into res://assets/models/trees. The world is rebuilt at startup so terrain,
## roads, vegetation, landmarks and lighting always agree with gameplay data.
##
## Zones are organic blobs defined by a centre, a radius and a wavy edge. The
## same definitions drive region detection, terrain colour, enemy levels, tree
## selection and the full-screen world map: one source of truth.

const BOUNDS := 74.0
const TERRAIN_EXTENT := 96.0
const TERRAIN_SEGMENTS := 128
const EDGE_FADE_START := 78.0
const ROAD_WIDTH := 3.7
const ROAD_LIFT := 0.055
const DAY_SECONDS := 900.0

const GRASS_TEXTURE := preload("res://assets/textures/terrain_grass.png")
const ROAD_TEXTURE := preload("res://assets/textures/terrain_road.png")
const BARK_TEXTURE := preload("res://assets/textures/bark.png")
const LEAF_TEXTURE := preload("res://assets/textures/leaves.png")
const NEEDLE_TEXTURE := preload("res://assets/textures/needles.png")

var player_spawn: Vector3 = Vector3(-16.0, 0.0, 17.5)
var camp_position: Vector3 = Vector3(-18.0, 0.0, 16.0)
var quest_spawn: Vector3 = Vector3(30.0, 0.0, -26.0)
var boss_spawn: Vector3 = Vector3(-24.0, 0.0, -44.0)
var smith_position: Vector3 = Vector3(-15.4, 0.0, 11.4)
var waygate_position: Vector3 = Vector3(-52.0, 0.0, -66.0)
var waygate_radius: float = 8.0
var normal_spawns: Array[Vector3] = [
	Vector3(-6.0, 0.0, 10.0), Vector3(12.0, 0.0, 18.0),
	Vector3(-34.0, 0.0, 2.0), Vector3(-46.0, 0.0, -18.0),
	Vector3(38.0, 0.0, 18.0), Vector3(46.0, 0.0, -6.0),
	Vector3(32.0, 0.0, -18.0), Vector3(42.0, 0.0, -36.0),
	Vector3(-8.0, 0.0, -60.0), Vector3(-36.0, 0.0, -34.0)]

## Level band and visual identity of each region. Areas are uneven but
## comparable; the central vale is the starting zone.
var zones: Array[Dictionary] = [
	{
		"id": "vale", "name": "EMBERFALL VALE", "subtitle": "The wayfarer's hearth",
		"level_min": 1, "level_max": 3, "center": Vector2(0.0, 8.0),
		"radius": 34.0, "phase": 0.4, "elevation": 0.0, "tree_count": 80,
		"ground": Color("7c8a53"), "accent": Color("c7a96b"),
		"trees": {"oak": 0.50, "birch": 0.35, "pine": 0.15},
		"description": "Rolling meadow and the survivor camp. Safe for new wayfarers.",
	},
	{
		"id": "thornwood", "name": "THORNWOOD", "subtitle": "Where the old forest closes",
		"level_min": 4, "level_max": 6, "center": Vector2(-46.0, -2.0),
		"radius": 33.0, "phase": 2.2, "elevation": 0.7, "tree_count": 96,
		"ground": Color("4f6c3e"), "accent": Color("8a6a4a"),
		"trees": {"oak": 0.45, "birch": 0.35, "pine": 0.20},
		"description": "Dense oak and birch. The canopy keeps the ground dark.",
	},
	{
		"id": "fen", "name": "ASHEN FEN", "subtitle": "Still water, patient things",
		"level_min": 7, "level_max": 9, "center": Vector2(42.0, 14.0),
		"radius": 32.0, "phase": 4.1, "elevation": -1.4, "tree_count": 58,
		"ground": Color("5c6b60"), "accent": Color("7f9a86"),
		"trees": {"dead": 0.55, "pine": 0.25, "birch": 0.20},
		"description": "Shallow black ponds and dead trees. Movement is exposed.",
	},
	{
		"id": "arch", "name": "THE BROKEN ARCH", "subtitle": "A monastery that lost its oath",
		"level_min": 10, "level_max": 12, "center": Vector2(36.0, -40.0),
		"radius": 32.0, "phase": 1.1, "elevation": 2.8, "tree_count": 66,
		"ground": Color("857a5c"), "accent": Color("b09a6c"),
		"trees": {"pine": 0.60, "oak": 0.20, "dead": 0.20},
		"description": "High stone terraces, broken columns and cold pines.",
	},
	{
		"id": "sanctum", "name": "CROWNLESS SANCTUM", "subtitle": "The sealed gate watches",
		"level_min": 13, "level_max": 15, "center": Vector2(-26.0, -50.0),
		"radius": 37.0, "phase": 5.3, "elevation": 2.0, "tree_count": 58,
		"ground": Color("44575c"), "accent": Color("79a79b"),
		"trees": {"dead": 0.55, "pine": 0.30, "oak": 0.15},
		"description": "The highest ground. The dormant waygate stands in its corner.",
	},
]

var roads: Array[PackedVector2Array] = []
var time_of_day: float = 8.25
var day_number: int = 1

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _hills: FastNoiseLite
var _detail: FastNoiseLite
var _mottle: FastNoiseLite
var _sites: Array[Dictionary] = []
var _ponds: Array[Dictionary] = []
var _road_cells: Dictionary = {}
var _materials: Dictionary = {}
var _sun: DirectionalLight3D
var _environment: Environment
var _sky_material: ProceduralSkyMaterial
var _portal_material: StandardMaterial3D
var _portal_ring: MeshInstance3D
var _flames: Array[Node3D] = []
var _elapsed: float = 0.0
var _prepared: bool = false
var _phase_name: String = "Day"


func build() -> void:
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
	_create_broken_arch()
	_create_sanctum()
	_create_waygate()
	_create_vegetation()
	_create_rocks_and_logs()
	_create_distant_landscape()
	_create_boundaries()
	_apply_time_of_day()


## Every placement system gets its own fixed seed, so adding a prop or changing a
## material cannot reshuffle the forest, the roads or the landmarks.
func _reseed(value: int) -> void:
	_rng.seed = value


func _process(delta: float) -> void:
	_elapsed += delta
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
	_hills.frequency = 0.0115
	_hills.fractal_type = FastNoiseLite.FRACTAL_FBM
	_hills.fractal_octaves = 4
	_hills.fractal_gain = 0.5
	_hills.fractal_lacunarity = 2.05
	_detail = FastNoiseLite.new()
	_detail.seed = 4413
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail.frequency = 0.055
	_detail.fractal_type = FastNoiseLite.FRACTAL_FBM
	_detail.fractal_octaves = 3
	_detail.fractal_gain = 0.55
	_mottle = FastNoiseLite.new()
	_mottle.seed = 7821
	_mottle.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_mottle.frequency = 0.32


func _init_sites() -> void:
	# Flattened pads keep the hand-built landmarks readable on rolling ground.
	_sites = [
		{"center": Vector2(-18.0, 16.0), "radius": 9.5, "blend": 7.0, "kind": "camp"},
		{"center": Vector2(30.0, -26.0), "radius": 10.0, "blend": 7.0, "kind": "quest"},
		{"center": Vector2(-24.0, -44.0), "radius": 11.5, "blend": 8.0, "kind": "boss"},
		{"center": Vector2(-52.0, -66.0), "radius": 8.5, "blend": 7.0, "kind": "waygate"},
	]
	for site: Dictionary in _sites:
		var center: Vector2 = site["center"]
		site["level"] = _raw_height(center.x, center.y)


func _init_ponds() -> void:
	for spec: Dictionary in [
		{"center": Vector2(50.0, 2.0), "radius": 7.0},
		{"center": Vector2(35.0, -4.0), "radius": 5.2},
		{"center": Vector2(47.0, 24.0), "radius": 4.4},
	]:
		var center: Vector2 = spec["center"]
		var radius: float = spec["radius"]
		var level: float = _raw_height(center.x, center.y) - 0.55
		_ponds.append({"center": center, "radius": radius, "level": level})


func _finalize_spawns() -> void:
	player_spawn = _ground(-16.0, 17.5)
	camp_position = _ground(-18.0, 16.0)
	quest_spawn = _ground(30.0, -26.0)
	boss_spawn = _ground(-24.0, -44.0)
	smith_position = _ground(-15.4, 11.6)
	waygate_position = _ground(-52.0, -66.0)
	for index: int in range(normal_spawns.size()):
		var point: Vector3 = normal_spawns[index]
		normal_spawns[index] = _ground(point.x, point.z)


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, height_at(x, z), z)


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
		var radius: float = pond["radius"]
		var distance: float = Vector2(x, z).distance_to(center)
		if distance < radius * 1.8:
			h = lerpf(float(pond["level"]), h, smoothstep(radius, radius * 1.8, distance))
	for site: Dictionary in _sites:
		var center: Vector2 = site["center"]
		var radius: float = site["radius"]
		var blend: float = site["blend"]
		var distance: float = Vector2(x, z).distance_to(center)
		if distance < radius + blend:
			h = lerpf(float(site["level"]), h, smoothstep(radius, radius + blend, distance))
	# Beyond the playable rim the land falls away into the fog so the square
	# edge of the mesh is never visible from inside the map.
	var edge: float = maxf(absf(x), absf(z))
	if edge > EDGE_FADE_START:
		h = lerpf(h, -12.0, smoothstep(EDGE_FADE_START, TERRAIN_EXTENT, edge))
	return h


func _raw_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var h: float = _hills.get_noise_2d(x, z) * 7.2
	h += _detail.get_noise_2d(x, z) * 1.1
	h *= 0.62 + 0.38 * clampf(p.distance_to(Vector2(0.0, 8.0)) / 38.0, 0.0, 1.0)
	var bias_sum: float = 0.0
	var weight_sum: float = 0.0
	for zone: Dictionary in zones:
		var metric: float = maxf(_zone_metric(zone, p), 0.05)
		var weight: float = 1.0 / pow(metric, 4.0)
		bias_sum += float(zone["elevation"]) * weight
		weight_sum += weight
	if weight_sum > 0.0:
		h += bias_sum / weight_sum
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
	_material("iron", Color("333e40"))
	_material("copper", Color("ad8554"), 0.55)
	_material("cloth", Color("c4ad80"))
	_material("cloth_dark", Color("8f8465"))
	_material("banner", Color("365352"))
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
	_materials["road"] = _textured(ROAD_TEXTURE, 0.94)
	_materials["road"].vertex_color_use_as_albedo = true
	_materials["road"].transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_materials["road"].cull_mode = BaseMaterial3D.CULL_DISABLED
	_materials["road_flat"] = _textured(ROAD_TEXTURE, 0.95)
	_materials["road_flat"].albedo_color = Color(0.86, 0.82, 0.72)
	_materials["bark"] = _textured(BARK_TEXTURE, 0.97)
	_materials["leaves"] = _textured(LEAF_TEXTURE, 0.92)
	_materials["needles"] = _textured(NEEDLE_TEXTURE, 0.95)
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


func _create_atmosphere() -> void:
	var world := WorldEnvironment.new()
	world.name = "FrontierAtmosphere"
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	_sky_material = ProceduralSkyMaterial.new()
	_sky_material.sky_top_color = Color("3c6f98")
	_sky_material.sky_horizon_color = Color("c3c9ac")
	_sky_material.ground_bottom_color = Color("24342c")
	_sky_material.ground_horizon_color = Color("8f9b83")
	_sky_material.sun_angle_max = 9.0
	_sky_material.sun_curve = 0.18
	sky.sky_material = _sky_material
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
	_environment.ssao_enabled = true
	_environment.ssao_radius = 1.5
	_environment.ssao_intensity = 1.5
	_environment.ssao_power = 1.4
	_environment.ssao_detail = 0.5
	_environment.ssao_light_affect = 0.12
	world.environment = _environment
	add_child(world)

	_sun = DirectionalLight3D.new()
	_sun.name = "FrontierSun"
	_sun.light_color = Color("ffdca6")
	_sun.light_energy = 1.35
	_sun.shadow_enabled = true
	_sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_sun.directional_shadow_max_distance = 110.0
	_sun.directional_shadow_split_1 = 0.08
	_sun.directional_shadow_split_2 = 0.22
	_sun.directional_shadow_split_3 = 0.48
	_sun.directional_shadow_blend_splits = true
	_sun.directional_shadow_fade_start = 0.82
	_sun.light_angular_distance = 2.2
	_sun.shadow_blur = 1.8
	_sun.shadow_opacity = 0.82
	_sun.shadow_bias = 0.04
	_sun.shadow_normal_bias = 1.2
	add_child(_sun)


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
	_sky_material.sky_top_color = night_top.lerp(day_top, daylight).lerp(dusk_top, dusk * 0.6)
	_sky_material.sky_horizon_color = night_horizon.lerp(day_horizon, daylight).lerp(dusk_horizon, dusk * 0.8)
	_sky_material.ground_bottom_color = Color("0d1512").lerp(Color("3f4a34"), daylight)
	_sky_material.ground_horizon_color = Color("1d2a2a").lerp(Color("8f9b83"), daylight).lerp(Color("a67d58"), dusk * 0.5)
	_environment.ambient_light_energy = lerpf(0.15, 0.48, daylight) + dusk * 0.05
	_environment.fog_light_color = Color("1c2b3a").lerp(Color("8a9c8d"), daylight).lerp(Color("b78a63"), dusk * 0.55)
	_environment.fog_density = lerpf(0.0058, 0.0029, daylight)


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
			colors[index] = _terrain_color(point, normal)
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


func _terrain_color(p: Vector2, normal: Vector3) -> Color:
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
	var slope: float = clampf((1.0 - normal.y) * 2.4, 0.0, 0.55)
	base = base.lerp(Color("847f6b"), slope)
	for pond: Dictionary in _ponds:
		var center: Vector2 = pond["center"]
		var radius: float = pond["radius"]
		var distance: float = p.distance_to(center)
		if distance < radius * 1.55:
			base = base.lerp(Color("4a4d3c"), (1.0 - smoothstep(radius, radius * 1.55, distance)) * 0.55)
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
		"camp": Vector2(-18.0, 16.0),
		"camp_north": Vector2(-12.0, 26.0),
		"vale_north": Vector2(4.0, 30.0),
		"north_pass": Vector2(16.0, 21.0),
		"crossroads": Vector2(0.0, 6.0),
		"camp_west": Vector2(-32.0, 14.0),
		"west_road": Vector2(-44.0, 4.0),
		"thorn_deep": Vector2(-56.0, -14.0),
		"thorn_south": Vector2(-45.0, -31.0),
		"sanctum_road": Vector2(-28.0, -35.0),
		"sanctum": Vector2(-24.0, -44.0),
		"sanctum_west": Vector2(-44.0, -56.0),
		"waygate": Vector2(-52.0, -66.0),
		"fen_gate": Vector2(24.0, 20.0),
		"fen_road": Vector2(38.0, 18.0),
		"fen_deep": Vector2(52.0, 6.0),
		"fen_south": Vector2(44.0, -14.0),
		"arch_road": Vector2(26.0, -8.0),
		"arch": Vector2(30.0, -26.0),
		"arch_east": Vector2(46.0, -34.0),
		"arch_north": Vector2(30.0, -48.0),
		"south_vale": Vector2(-4.0, -14.0),
		"south_pass": Vector2(-12.0, -30.0),
		"east_vale": Vector2(16.0, 2.0),
		"east_south": Vector2(18.0, -16.0),
	}
	var edges: Array = [
		["camp", "camp_north"], ["camp", "crossroads"], ["camp", "camp_west"],
		["camp", "south_vale"], ["camp_north", "vale_north"], ["vale_north", "north_pass"],
		["vale_north", "fen_gate"], ["north_pass", "fen_gate"], ["north_pass", "east_vale"],
		["east_vale", "crossroads"], ["east_vale", "east_south"], ["crossroads", "south_vale"],
		["crossroads", "arch_road"], ["south_vale", "east_south"], ["south_vale", "south_pass"],
		["east_south", "arch_road"], ["arch_road", "arch"], ["arch_road", "fen_south"],
		["arch", "arch_east"], ["arch", "arch_north"], ["arch_north", "sanctum_road"],
		["arch_north", "sanctum"], ["arch_east", "fen_south"], ["fen_south", "fen_deep"],
		["fen_deep", "fen_road"], ["fen_road", "fen_gate"], ["camp_west", "west_road"],
		["west_road", "thorn_deep"], ["west_road", "thorn_south"], ["thorn_deep", "thorn_south"],
		["thorn_south", "sanctum_road"], ["sanctum_road", "sanctum"],
		["sanctum", "sanctum_west"], ["sanctum_west", "waygate"],
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
	for polyline: PackedVector2Array in roads:
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


func _mark_road_cells(polyline: PackedVector2Array) -> void:
	for point: Vector2 in polyline:
		_road_cells[Vector2i(int(floor(point.x / 2.5)), int(floor(point.y / 2.5)))] = true


func _near_road(x: float, z: float, radius_cells: int = 0) -> bool:
	var cx: int = int(floor(x / 2.5))
	var cz: int = int(floor(z / 2.5))
	for dx: int in range(-radius_cells, radius_cells + 1):
		for dz: int in range(-radius_cells, radius_cells + 1):
			if _road_cells.has(Vector2i(cx + dx, cz + dz)):
				return true
	return false


func _near_site(p: Vector2, padding: float) -> bool:
	for site: Dictionary in _sites:
		var distance: float = p.distance_to(site["center"])
		if distance < float(site["radius"]) + padding:
			return true
	return false


func _in_pond(p: Vector2, padding: float) -> bool:
	for pond: Dictionary in _ponds:
		if p.distance_to(pond["center"]) < float(pond["radius"]) * 1.5 + padding:
			return true
	return false


func _create_water() -> void:
	_reseed(4421)
	for pond: Dictionary in _ponds:
		var center: Vector2 = pond["center"]
		var radius: float = pond["radius"]
		var bank: MeshInstance3D = _cylinder("FenBank", Vector3(center.x, 0.0, center.y), radius * 1.04, 0.05, "earth_dark", 24)
		bank.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var water: MeshInstance3D = _cylinder("FenPool", Vector3(center.x, 0.04, center.y), radius * 0.97, 0.03, "water", 24)
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _pick_tree(zone: Dictionary) -> String:
	var mix: Dictionary = zone["trees"]
	var roll: float = _rng.randf()
	var total: float = 0.0
	for key: String in mix.keys():
		total += float(mix[key])
		if roll <= total:
			return key
	return "oak"


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
			if absf(point.x) > 71.0 or absf(point.y) > 71.0:
				continue
			if _near_road(point.x, point.y, 1) or _near_site(point, 6.0) or _in_pond(point, 1.0):
				continue
			var kind: String = _pick_tree(zone)
			var scale_value: float = _rng.randf_range(0.72, 1.28)
			var basis: Basis = Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * scale_value)
			(transforms[kind] as Array).append(Transform3D(basis, _ground(point.x, point.y)))
			placed += 1
	for kind: String in transforms.keys():
		var entries: Array = transforms[kind]
		if entries.is_empty():
			continue
		var mesh: Mesh = _load_tree_mesh(kind)
		if mesh == null:
			continue
		_create_multimesh("Trees_" + kind, mesh, entries, true)
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
	mesh.surface_set_material(0, _materials["bark"])
	if mesh.get_surface_count() > 1:
		mesh.surface_set_material(1, _materials["needles"] if kind == "pine" else _materials["leaves"])
	return mesh


func _create_multimesh(node_name: String, mesh: Mesh, entries: Array, shadows: bool) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = entries.size()
	for index: int in range(entries.size()):
		multimesh.set_instance_transform(index, entries[index])
	var node := MultiMeshInstance3D.new()
	node.name = node_name
	node.multimesh = multimesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


func _create_grass() -> void:
	_reseed(3311)
	var blade := ArrayMesh.new()
	var vertices := PackedVector3Array([
		Vector3(-0.10, 0.0, 0.0), Vector3(0.07, 0.0, 0.0), Vector3(0.01, 0.44, 0.04),
		Vector3(0.0, 0.0, -0.09), Vector3(0.0, 0.0, 0.09), Vector3(0.03, 0.34, 0.0)])
	var normals := PackedVector3Array([
		Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT])
	# Without explicit vertex colours the untextured blade renders pure white.
	var colors := PackedColorArray([
		Color(0.30, 0.38, 0.20), Color(0.34, 0.42, 0.22), Color(0.58, 0.68, 0.36),
		Color(0.30, 0.38, 0.20), Color(0.34, 0.42, 0.22), Color(0.58, 0.68, 0.36)])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	blade.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.95
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	blade.surface_set_material(0, material)
	var entries: Array = []
	var tints: Array[Color] = []
	var zones_for_grass: Array[Dictionary] = [zones[0], zones[1], zones[2]]
	for zone: Dictionary in zones_for_grass:
		var center: Vector2 = zone["center"]
		var radius: float = zone["radius"]
		var placed: int = 0
		var attempts: int = 0
		while placed < 620 and attempts < 7000:
			attempts += 1
			var angle: float = _rng.randf_range(0.0, TAU)
			var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * sqrt(_rng.randf()) * radius * 0.94
			if absf(point.x) > 71.0 or absf(point.y) > 71.0:
				continue
			if _near_road(point.x, point.y, 0) or _near_site(point, 1.2) or _in_pond(point, 0.0):
				continue
			var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * _rng.randf_range(0.65, 1.35))
			entries.append(Transform3D(basis, _ground(point.x, point.y)))
			var tint: Color = (zone["ground"] as Color).lightened(_rng.randf_range(0.0, 0.22))
			tints.append(tint)
			placed += 1
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = blade
	multimesh.instance_count = entries.size()
	for index: int in range(entries.size()):
		multimesh.set_instance_transform(index, entries[index])
		multimesh.set_instance_color(index, tints[index])
	var node := MultiMeshInstance3D.new()
	node.name = "MeadowGrass"
	node.multimesh = multimesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


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
		while placed < 150 and attempts < 2200:
			attempts += 1
			var angle: float = _rng.randf_range(0.0, TAU)
			var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * sqrt(_rng.randf()) * radius * 0.9
			if absf(point.x) > 68.0 or absf(point.y) > 68.0:
				continue
			if _near_road(point.x, point.y, 0) or _near_site(point, 2.0) or _in_pond(point, 0.0):
				continue
			var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3.ONE * _rng.randf_range(0.75, 1.35))
			entries.append(Transform3D(basis, _ground(point.x, point.y)))
			colors.append(palette[_rng.randi_range(0, palette.size() - 1)])
			placed += 1
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = entries.size()
	for index: int in range(entries.size()):
		multimesh.set_instance_transform(index, entries[index])
		multimesh.set_instance_color(index, colors[index])
	var node := MultiMeshInstance3D.new()
	node.name = "Wildflowers"
	node.multimesh = multimesh
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)


func _create_bushes() -> void:
	_reseed(6653)
	var sphere := SphereMesh.new()
	sphere.radius = 0.85
	sphere.height = 1.15
	sphere.radial_segments = 6
	sphere.rings = 3
	sphere.material = _materials["leaves"]
	var entries: Array = []
	for zone: Dictionary in zones:
		var center: Vector2 = zone["center"]
		var radius: float = zone["radius"]
		var placed: int = 0
		var attempts: int = 0
		while placed < 26 and attempts < 400:
			attempts += 1
			var angle: float = _rng.randf_range(0.0, TAU)
			var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * sqrt(_rng.randf()) * radius * 0.9
			if absf(point.x) > 70.0 or absf(point.y) > 70.0:
				continue
			if _near_road(point.x, point.y, 0) or _near_site(point, 2.5) or _in_pond(point, 0.0):
				continue
			var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(_rng.randf_range(0.7, 1.5), _rng.randf_range(0.55, 1.05), _rng.randf_range(0.7, 1.5)))
			var at := _ground(point.x, point.y)
			at.y += 0.12
			entries.append(Transform3D(basis, at))
			placed += 1
	_create_multimesh("Underbrush", sphere, entries, true)


func _create_rocks_and_logs() -> void:
	_reseed(8831)
	for zone: Dictionary in zones:
		var center: Vector2 = zone["center"]
		var radius: float = zone["radius"]
		var placed: int = 0
		var attempts: int = 0
		while placed < 22 and attempts < 320:
			attempts += 1
			var angle: float = _rng.randf_range(0.0, TAU)
			var point: Vector2 = center + Vector2(cos(angle), sin(angle)) * sqrt(_rng.randf()) * radius * 0.95
			if absf(point.x) > 72.0 or absf(point.y) > 72.0:
				continue
			if _near_road(point.x, point.y, 0) or _near_site(point, 2.0) or _in_pond(point, 0.0):
				continue
			var size_value: float = _rng.randf_range(0.35, 1.5)
			var size := Vector3(size_value * _rng.randf_range(0.8, 1.5), size_value * _rng.randf_range(0.5, 0.9), size_value)
			var at := _ground(point.x, point.y)
			at.y += size.y * 0.35
			var rock := _rock(at, size, "stone_dark" if _rng.randf() < 0.55 else "stone")
			if size_value > 1.15:
				rock.create_trimesh_collision()
			placed += 1
	for index: int in range(12):
		var zone: Dictionary = zones[index % zones.size()]
		var center: Vector2 = zone["center"]
		var point: Vector2 = center + Vector2(_rng.randf_range(-14.0, 14.0), _rng.randf_range(-14.0, 14.0))
		if _near_road(point.x, point.y, 0) or _near_site(point, 3.0):
			continue
		var log_mesh: MeshInstance3D = _cylinder("FallenLog", Vector3(point.x, 0.32, point.y), 0.32, _rng.randf_range(2.4, 4.2), "wood", 8)
		log_mesh.rotation = Vector3(PI * 0.5, _rng.randf_range(-1.0, 1.0), 0.0)
		log_mesh.create_trimesh_collision()


func _create_distant_landscape() -> void:
	_reseed(6619)
	var gate := Vector2(waygate_position.x, waygate_position.z)
	var sanctum := Vector2(-26.0, -50.0)
	for index: int in range(30):
		var angle: float = TAU * float(index) / 30.0 + _rng.randf_range(-0.05, 0.05)
		var radius: float = _rng.randf_range(108.0, 138.0)
		var mountain_height: float = _rng.randf_range(22.0, 42.0)
		var at := Vector2(cos(angle) * radius, sin(angle) * radius)
		# A crag this close to the gate or the sanctum would swallow the camera
		# during the sealed-gate scene, so the north-west approach stays open.
		if at.distance_to(gate) < 54.0 or at.distance_to(sanctum) < 34.0:
			continue
		var crag: MeshInstance3D = _add_mesh(self, "DistantCrag", _cone_mesh(_rng.randf_range(14.0, 24.0), mountain_height, 5), "mountain")
		# Every crag shares one sub-horizon base so the ring reads as a range, not
		# as individual cones floating above the fading terrain.
		crag.position = Vector3(at.x, -18.0 + mountain_height * 0.5, at.y)
		crag.rotation.y = _rng.randf_range(0.0, TAU)
		crag.scale.z = _rng.randf_range(0.65, 1.35)
		crag.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if mountain_height > 34.0:
			var cap_height: float = mountain_height * 0.20
			var cap: MeshInstance3D = _add_mesh(self, "DistantSnow", _cone_mesh(_rng.randf_range(3.0, 5.0), cap_height, 5), "mountain_snow")
			cap.position = Vector3(at.x, -18.0 + mountain_height - cap_height * 0.5, at.y)
			cap.rotation.y = crag.rotation.y
			cap.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for index: int in range(70):
		var angle: float = _rng.randf_range(0.0, TAU)
		var radius: float = _rng.randf_range(80.0, 92.0)
		var height: float = _rng.randf_range(9.0, 20.0)
		var at := Vector2(cos(angle) * radius, sin(angle) * radius)
		if at.distance_to(gate) < 15.0:
			continue
		var silhouette: MeshInstance3D = _cone("FarPine", Vector3(at.x, height * 0.5 - 1.0, at.y), _rng.randf_range(2.6, 5.0), height, "stone_dark", 5)
		silhouette.rotation.y = _rng.randf_range(0.0, TAU)
		silhouette.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
	var instance := _add_mesh(parent, node_name, _cylinder_mesh(radius, direction.length(), 5), material_key)
	instance.position = (from + to) * 0.5
	instance.basis = Basis.looking_at(direction.normalized(), Vector3.UP) * Basis(Vector3.RIGHT, -PI * 0.5)
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


## `at` is already a world position (the caller sampled the terrain).
func _rock(at: Vector3, size: Vector3, material_key: String) -> MeshInstance3D:
	var instance := _add_mesh(self, "Boulder", _sphere_mesh(0.9, 7, 4), material_key)
	instance.position = at
	instance.scale = size
	instance.rotation = Vector3(_rng.randf_range(-0.22, 0.22), _rng.randf_range(0.0, TAU), _rng.randf_range(-0.22, 0.22))
	return instance


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


## Layered additive flame: a wide orange tongue, a bright core and a small tip.
## The overlap hides each cone's silhouette, which is what made the old single
## cone read as a paper pyramid.
func _flame(parent: Node3D, at: Vector3, scale_value: float = 1.0) -> void:
	var group := Node3D.new()
	group.name = "Flame"
	group.position = at
	group.scale = Vector3.ONE * scale_value
	parent.add_child(group)
	var outer := _add_mesh(group, "FlameOuter", _cone_mesh(0.32, 0.98, 9), "fire_outer")
	outer.position.y = 0.49
	outer.rotation.y = _rng.randf_range(0.0, TAU)
	var inner := _add_mesh(group, "FlameInner", _cone_mesh(0.19, 0.66, 8), "fire_core")
	inner.position = Vector3(0.03, 0.33, 0.015)
	inner.rotation.y = _rng.randf_range(0.0, TAU)
	var tip := _add_mesh(group, "FlameTip", _cone_mesh(0.10, 0.44, 7), "fire_core")
	tip.position = Vector3(-0.055, 0.84, 0.0)
	tip.rotation.z = 0.14
	for piece: MeshInstance3D in [outer, inner, tip]:
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flames.append(group)


func _campfire(parent: Node3D, at: Vector3) -> void:
	for index: int in range(10):
		var angle: float = TAU * float(index) / 10.0
		var stone := _add_mesh(parent, "FireStone", _sphere_mesh(0.3, 6, 3), "stone")
		stone.position = at + Vector3(cos(angle) * 1.15, 0.14, sin(angle) * 1.15)
		stone.scale = Vector3(1.0, 0.65, 1.0)
		stone.rotation.y = angle
	for index: int in range(4):
		var angle: float = TAU * float(index) / 4.0 + 0.4
		var log_piece := _add_mesh(parent, "FireLog", _cylinder_mesh(0.11, 1.35, 6), "wood")
		log_piece.position = at + Vector3(0.0, 0.3, 0.0)
		log_piece.rotation = Vector3(PI * 0.5, angle, 0.0)
	_flame(parent, at + Vector3(0.0, 0.18, 0.0), 1.15)
	_light(parent, at + Vector3(0.0, 1.5, 0.0), Color("ffb266"), 2.1, 13.0)


func _tent(parent: Node3D, at: Vector3, rotation_y: float, cloth_key: String = "cloth") -> void:
	var tent := Node3D.new()
	tent.name = "Tent"
	tent.position = at
	tent.rotation.y = rotation_y
	parent.add_child(tent)
	# A triangular prism is a real A-frame silhouette; thin tilted boxes read as
	# benches from the default camera angle.
	var width: float = 2.5
	var height_value: float = 1.75
	var depth: float = 3.0
	var canopy := PrismMesh.new()
	canopy.size = Vector3(width, height_value, depth)
	canopy.left_to_right = 0.5
	var body := _add_mesh(tent, "TentCanopy", canopy, cloth_key)
	body.position.y = height_value * 0.5
	var back := PrismMesh.new()
	back.size = Vector3(width - 0.06, height_value - 0.04, 0.12)
	back.left_to_right = 0.5
	var rear := _add_mesh(tent, "TentBack", back, cloth_key)
	rear.position = Vector3(0.0, height_value * 0.5, -depth * 0.5 + 0.06)
	# Ridge pole and seam strips break up the two large canvas slopes so the
	# shelter never reads as a blank wall from the side.
	var ridge := _add_mesh(tent, "TentRidge", _cylinder_mesh(0.07, depth + 0.45, 6), "wood")
	ridge.rotation.x = PI * 0.5
	ridge.position = Vector3(0.0, height_value + 0.02, 0.0)
	var slope: float = sqrt(pow(width * 0.5, 2.0) + pow(height_value, 2.0))
	var slope_angle: float = atan2(height_value, width * 0.5)
	for side: float in [-1.0, 1.0]:
		var seam := _add_mesh(tent, "TentSeam", _box_mesh(Vector3(slope * 0.94, 0.05, depth + 0.02)), "cloth_dark")
		seam.position = Vector3(side * width * 0.25, height_value * 0.5, 0.0)
		seam.rotation.z = -side * slope_angle
		# Guy ropes pulled to pegs fore and aft: the clearest tent tell from any angle.
		for end: float in [-1.0, 1.0]:
			_strut(tent, Vector3(0.0, height_value, end * depth * 0.5), Vector3(side * (width * 0.5 + 0.95), 0.02, end * (depth * 0.5 + 0.8)), 0.012, "cloth_dark", "GuyRope")
		# A-frame legs at the mouth.
		_strut(tent, Vector3(side * width * 0.5, 0.0, depth * 0.5 + 0.02), Vector3(0.0, height_value + 0.02, depth * 0.5 + 0.02), 0.05, "wood", "TentLeg")
	# One curtain tied open so the entrance reads as a way in, not a wall.
	var curtain := _add_mesh(tent, "TentCurtain", _box_mesh(Vector3(0.85, 1.55, 0.05)), cloth_key)
	curtain.position = Vector3(-0.62, 0.78, depth * 0.5 + 0.03)
	curtain.rotation.y = 0.22
	var bedroll := _add_mesh(tent, "Bedroll", _box_mesh(Vector3(0.8, 0.13, 1.9)), "cloth_dark")
	bedroll.position = Vector3(0.0, 0.07, 0.1)


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
	var pole := _add_mesh(parent, "LampPole", _cylinder_mesh(0.07, 2.5, 6), "iron")
	pole.position = at + Vector3(0.0, 1.25, 0.0)
	var arm := _add_mesh(parent, "LampArm", _box_mesh(Vector3(0.55, 0.07, 0.07)), "iron")
	arm.position = at + Vector3(0.24, 2.42, 0.0)
	var cage := _add_mesh(parent, "LampCage", _box_mesh(Vector3(0.34, 0.42, 0.34)), "iron")
	cage.position = at + Vector3(0.5, 2.18, 0.0)
	var glow := _add_mesh(parent, "LampGlow", _sphere_mesh(0.13, 6, 3), "fire")
	glow.position = at + Vector3(0.5, 2.18, 0.0)
	glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_light(parent, at + Vector3(0.5, 2.1, 0.0), Color("ffc27a"), 0.9, 7.0)


func _brazier(parent: Node3D, at: Vector3, energy: float = 1.1) -> void:
	var base := _add_mesh(parent, "BrazierBase", _cylinder_mesh(0.16, 0.85, 6), "iron")
	base.position = at + Vector3(0.0, 0.43, 0.0)
	var bowl := _add_mesh(parent, "BrazierBowl", _cylinder_mesh(0.44, 0.3, 8), "iron")
	bowl.position = at + Vector3(0.0, 0.95, 0.0)
	var coals := _add_mesh(parent, "BrazierCoals", _cylinder_mesh(0.35, 0.06, 8), "fire")
	coals.position = at + Vector3(0.0, 1.1, 0.0)
	coals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flame(parent, at + Vector3(0.0, 1.1, 0.0), 0.62)
	_light(parent, at + Vector3(0.0, 1.7, 0.0), Color("ff9d55"), energy, 9.0)


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


func _create_camp() -> void:
	_reseed(2203)
	var camp := _group("SurvivorCamp", camp_position.x, camp_position.z)
	_campfire(camp, Vector3.ZERO)
	_tent(camp, Vector3(-5.3, 0.0, -3.1), 0.55, "cloth")
	_tent(camp, Vector3(4.9, 0.0, 2.4), -0.75, "cloth_dark")
	_tent(camp, Vector3(-3.9, 0.0, 5.4), 2.55, "cloth_dark")
	_tent(camp, Vector3(0.9, 0.0, -7.0), 0.1, "cloth")
	# Forge and anvil: the blacksmith stands here.
	_wall(camp, Vector3(3.4, 0.0, -4.6), Vector3(1.9, 1.0, 1.3), -0.16, "stone_dark")
	var coal := _add_mesh(camp, "ForgeCoals", _box_mesh(Vector3(1.3, 0.1, 0.8)), "fire")
	coal.position = Vector3(3.4, 1.02, -4.6)
	coal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_light(camp, Vector3(3.4, 1.8, -4.6), Color("ff9a4d"), 1.35, 8.0)
	var stump := _add_mesh(camp, "AnvilStump", _cylinder_mesh(0.42, 0.62, 8), "wood")
	stump.position = Vector3(4.9, 0.31, -3.4)
	var anvil := _add_mesh(camp, "Anvil", _box_mesh(Vector3(0.62, 0.34, 0.34)), "iron")
	anvil.position = Vector3(4.9, 0.79, -3.4)
	var horn := _add_mesh(camp, "AnvilHorn", _cone_mesh(0.16, 0.5, 5), "iron")
	horn.position = Vector3(5.28, 0.8, -3.4)
	horn.rotation.z = -PI * 0.5
	_barrel(camp, Vector3(2.6, 0.0, -5.9))
	_barrel(camp, Vector3(3.2, 0.0, -6.3))
	_crate(camp, Vector3(1.6, 0.0, -5.5), 0.7, 0.3)
	_crate(camp, Vector3(1.6, 0.7, -5.5), 0.55, -0.2)
	_banner(camp, Vector3(-7.1, 0.0, 0.4), 0.8, "banner")
	_banner(camp, Vector3(6.6, 0.0, -1.2), -0.9, "banner")
	_lamp(camp, Vector3(-3.4, 0.0, -0.6))
	_lamp(camp, Vector3(3.6, 0.0, -0.4))
	# Wayfarer sign at the eastern entrance.
	var post := _add_mesh(camp, "SignPost", _box_mesh(Vector3(0.14, 1.9, 0.14)), "wood")
	post.position = Vector3(2.2, 0.95, 2.6)
	var board := _add_mesh(camp, "SignBoard", _box_mesh(Vector3(3.1, 0.68, 0.12)), "wood_light")
	board.position = Vector3(2.2, 1.72, 2.6)
	board.rotation.y = -0.35
	# The label sits on the rotated board face, not inside the plank. The old
	# offset left it buried in the board and half a line too high.
	var sign_text := _text(camp, Vector3(2.174, 1.72, 2.670), "EMBERFALL CAMP", 34, Color("e6d6a8"))
	sign_text.rotation.y = -0.35
	# A signpost is read from both directions; the second face is rotated, not
	# mirrored, so the lettering stays legible on the road side.
	var sign_back := _text(camp, Vector3(2.226, 1.72, 2.530), "EMBERFALL CAMP", 34, Color("e6d6a8"))
	sign_back.rotation.y = -0.35 + PI


func _create_broken_arch() -> void:
	_reseed(3307)
	var site := _group("BrokenArch", 36.0, -40.0)
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
	var altar := _add_mesh(site, "Altar", _box_mesh(Vector3(1.7, 0.7, 1.0)), "stone_dark")
	altar.position = Vector3(0.0, 0.92, 1.4)
	altar.rotation.y = 0.1
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
	var site := _group("CrownlessSanctum", -26.0, -50.0)
	var dais := _add_mesh(site, "Dais", _cylinder_mesh(4.4, 0.5, 16), "stone_dark")
	dais.position.y = 0.25
	var step := _add_mesh(site, "DaisStep", _cylinder_mesh(3.2, 0.36, 16), "stone")
	step.position.y = 0.68
	var altar := _add_mesh(site, "SanctumAltar", _box_mesh(Vector3(1.9, 1.0, 1.2)), "stone_light")
	altar.position.y = 1.36
	var crown := _add_mesh(site, "CrownShard", _cone_mesh(0.5, 1.5, 5), "rune")
	crown.position.y = 2.6
	crown.rotation.y = 0.3
	_light(site, Vector3(0.0, 2.4, 0.0), Color("79c3b5"), 1.3, 10.0)
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


