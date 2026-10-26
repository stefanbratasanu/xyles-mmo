extends Node3D
class_name XylesWorldBuilder

## The Ashen Frontier: all scenery is native, deterministic Godot geometry.
## Combat takes place on the flat y=0 plane; distant scenery is decorative.
var player_spawn: Vector3 = Vector3(-15.0, 0.0, 16.0)
var camp_position: Vector3 = Vector3(-15.0, 0.0, 16.0)
var normal_spawns: Array[Vector3] = [
	Vector3(-3.0, 0.0, 10.0), Vector3(5.0, 0.0, 12.0),
	Vector3(12.0, 0.0, 7.0), Vector3(-5.0, 0.0, 1.0),
	Vector3(5.0, 0.0, -2.0), Vector3(13.0, 0.0, -2.0)]
var quest_spawn: Vector3 = Vector3(18.0, 0.0, -9.0)
var boss_spawn: Vector3 = Vector3(10.0, 0.0, -24.0)

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _materials: Dictionary = {}
var _paths: Array[PackedVector3Array] = []

func build() -> void:
	_rng.seed = 293817
	_create_materials()
	_create_atmosphere()
	_create_ground()
	_create_paths()
	_create_camp()
	_create_ruins()
	_create_shrine()
	_create_wilderness()
	_create_grass()
	_create_boundaries()

func _create_materials() -> void:
	_material("earth", Color("3e4c35"))
	_material("earth_dark", Color("35422f"))
	_material("moss", Color("53603b"))
	_material("path", Color("797461"))
	_material("path_dark", Color("676653"))
	_material("stone", Color("7c8276"))
	_material("stone_light", Color("a3a591"))
	_material("stone_dark", Color("4d5c56"))
	_material("stone_blue", Color("626f6c"))
	_material("wood", Color("4a382b"))
	_material("wood_light", Color("796044"))
	_material("iron", Color("333e40"))
	_material("copper", Color("ad8554"), 0.55)
	_material("cloth", Color("a69064"))
	_material("cloth_dark", Color("6b654e"))
	_material("banner", Color("365352"))
	_material("pine_dark", Color("243d32"))
	_material("pine_mid", Color("32513b"))
	_material("pine_light", Color("425c3c"))
	_material("grass", Color("6e7848"))
	_material("grass_light", Color("85845a"))
	_material("water", Color("3e625e"), 0.25)
	_material("coal", Color("1d2826"))
	_material("fire", Color("ffb45f"), 0.0, Color("ff8c32"), 2.0)
	_material("rune", Color("8fc7be"), 0.2, Color("5fada1"), 1.25)
	_material("rune_dim", Color("405c55"), 0.0, Color("42665a"), 0.35)

func _material(key: String, color: Color, metallic: float = 0.0, emission: Color = Color.BLACK, energy: float = 0.0) -> void:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.92
	mat.metallic = metallic
	if energy > 0.0:
		mat.emission_enabled = true
		mat.emission = emission
		mat.emission_energy_multiplier = energy
	_materials[key] = mat

func _create_atmosphere() -> void:
	var world: WorldEnvironment = WorldEnvironment.new()
	world.name = "FrontierAtmosphere"
	var environment: Environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	var sky_material: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("354f58")
	sky_material.sky_horizon_color = Color("b4b7a0")
	sky_material.ground_bottom_color = Color("283a32")
	sky_material.ground_horizon_color = Color("9ea78d")
	sky_material.sun_angle_max = 11.0
	sky.sky_material = sky_material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8caaa3")
	environment.ambient_light_energy = 0.65
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.fog_enabled = true
	environment.fog_light_color = Color("899d8c")
	environment.fog_light_energy = 0.6
	environment.fog_density = 0.0038
	world.environment = environment
	add_child(world)
	var sun: DirectionalLight3D = DirectionalLight3D.new()
	sun.name = "LateAutumnSun"
	sun.rotation_degrees = Vector3(-48.0, -38.0, 0.0)
	sun.light_color = Color("ffdda3")
	sun.light_energy = 1.75
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 100.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	add_child(sun)

func _create_ground() -> void:
	_box("FrontierGround", Vector3(0.0, -0.5, 0.0), Vector3(170.0, 1.0, 170.0), "earth", true)
	for index: int in range(65):
		var center: Vector3 = Vector3(_rng.randf_range(-45.0, 45.0), 0.007, _rng.randf_range(-45.0, 45.0))
		var patch: MeshInstance3D = _cylinder("MossPatch", center, _rng.randf_range(1.4, 5.0), 0.008, "moss" if index % 3 == 0 else "earth_dark", 11)
		patch.scale.z = _rng.randf_range(0.45, 1.0)
		patch.rotation.y = _rng.randf_range(0.0, TAU)
	# A shallow creek borders the eastern forest. Main combat lanes remain dry.
	for index: int in range(17):
		var z: float = -40.0 + float(index) * 4.8
		var x: float = 29.0 + sin(float(index) * 0.4) * 2.0
		var bank: MeshInstance3D = _cylinder("CreekBed", Vector3(x, 0.014, z), 4.0, 0.014, "stone_dark", 14)
		bank.scale.x = 0.68
		var water: MeshInstance3D = _cylinder("StillWater", Vector3(x, 0.025, z), 3.0, 0.015, "water", 16)
		water.scale.x = 0.7

func _create_paths() -> void:
	_paths = [
		PackedVector3Array([Vector3(-20, 0, 21), Vector3(-12, 0, 14), Vector3(-5, 0, 9), Vector3(2, 0, 4), Vector3(8, 0, -6), Vector3(10, 0, -15), Vector3(10, 0, -24)]),
		PackedVector3Array([Vector3(1, 0, 5), Vector3(11, 0, 5), Vector3(18, 0, -3), Vector3(18, 0, -10)]),
		PackedVector3Array([Vector3(-15, 0, 16), Vector3(-25, 0, 12), Vector3(-34, 0, 7)])]
	for route: PackedVector3Array in _paths:
		for section: int in range(route.size() - 1):
			var start: Vector3 = route[section]
			var end: Vector3 = route[section + 1]
			var length: float = start.distance_to(end)
			var count: int = int(ceil(length / 1.7))
			for step: int in range(count + 1):
				var point: Vector3 = start.lerp(end, float(step) / float(count))
				point.y = 0.032
				var patch: MeshInstance3D = _cylinder("WornRoad", point, _rng.randf_range(1.65, 2.2), 0.024, "path" if step % 3 else "path_dark", 10)
				patch.scale.z = _rng.randf_range(0.72, 1.0)
				patch.rotation.y = _rng.randf_range(0.0, TAU)
				if step % 2 == 0:
					for stone_index: int in range(2):
						var stone_point: Vector3 = point + Vector3(_rng.randf_range(-1.3, 1.3), 0.02, _rng.randf_range(-0.8, 0.8))
						var stone: MeshInstance3D = _box("OldRoadPaver", stone_point, Vector3(_rng.randf_range(0.3, 0.8), 0.05, _rng.randf_range(0.25, 0.5)), "stone")
						stone.rotation.y = _rng.randf_range(-0.6, 0.6)

func _create_camp() -> void:
	# The survivor camp forms a warm, readable safe landmark.
	_cylinder("CampClearing", Vector3(-18.0, 0.04, 16.0), 7.3, 0.03, "path_dark", 22)
	_tent(Vector3(-21.0, 0.0, 14.0), -0.15, false)
	_tent(Vector3(-18.4, 0.0, 21.0), PI, true)
	# Raised forge canopy; the open face looks onto the central road.
	for x: float in [-25.0, -19.0]:
		for z: float in [8.0, 12.0]:
			_box("ForgePost", Vector3(x, 1.65, z), Vector3(0.20, 3.3, 0.20), "wood", true)
	_box("CanopyRidge", Vector3(-22.0, 3.55, 10.0), Vector3(6.6, 0.18, 0.18), "wood")
	for slope: float in [-1.0, 1.0]:
		var roof: MeshInstance3D = _box("ForgeCanvas", Vector3(-22.0, 3.15, 10.0 + slope * 1.12), Vector3(6.9, 0.1, 2.55), "cloth_dark")
		roof.rotation.x = slope * 0.36
	_box("ForgeBase", Vector3(-23.1, 0.65, 9.0), Vector3(2.0, 1.3, 1.6), "stone_dark", true)
	_box("ForgeHearth", Vector3(-23.1, 1.35, 9.0), Vector3(1.55, 0.18, 1.15), "coal")
	for coal: int in range(9):
		_rock(Vector3(-23.6 + float(coal % 3) * 0.42, 1.5, 8.65 + float(coal / 3) * 0.30), Vector3(0.23, 0.14, 0.20), "fire")
	_box("ForgeBack", Vector3(-23.1, 1.8, 8.2), Vector3(2.0, 2.3, 0.5), "stone_dark", true)
	_box("ForgeChimney", Vector3(-23.6, 3.15, 8.2), Vector3(0.8, 3.0, 0.8), "stone_dark")
	_box("AnvilStump", Vector3(-20.8, 0.42, 10.7), Vector3(0.8, 0.8, 0.8), "wood", true)
	_box("AnvilFoot", Vector3(-20.8, 0.9, 10.7), Vector3(0.85, 0.18, 0.65), "iron")
	_box("AnvilStem", Vector3(-20.8, 1.12, 10.7), Vector3(0.35, 0.4, 0.4), "iron")
	_box("AnvilFace", Vector3(-20.8, 1.37, 10.7), Vector3(1.25, 0.25, 0.5), "iron")
	_cone("AnvilHorn", Vector3(-20.0, 1.36, 10.7), 0.25, 0.65, "iron", 6).rotation.z = -PI / 2.0
	_lamp(Vector3(-18.1, 0, 12.2))
	_lamp(Vector3(-13.0, 0, 19.5))
	_banner(Vector3(-13.0, 0, 12.3), 0.22)
	_barrel(Vector3(-24.5, 0, 14.5))
	_barrel(Vector3(-23.7, 0, 15.5))
	_crate(Vector3(-20.5, 0.0, 18.0), 1.1)
	_crate(Vector3(-21.5, 0.0, 18.2), 0.8)
	_crate(Vector3(-20.7, 1.1, 18.0), 0.7)
	# Campfire with stone ring and crossed firewood.
	for index: int in range(10):
		var angle: float = float(index) * TAU / 10.0
		_rock(Vector3(-16.8 + cos(angle) * 1.1, 0.13, 16.1 + sin(angle) * 1.1), Vector3(0.30, 0.22, 0.25), "stone_dark")
	for index: int in range(3):
		var log_mesh: MeshInstance3D = _cylinder("CampfireLog", Vector3(-16.8, 0.18, 16.1), 0.13, 1.8, "wood", 7)
		log_mesh.rotation = Vector3(PI / 2.0, float(index) * PI / 3.0, 0.0)
	_cone("FireGlow", Vector3(-16.8, 0.51, 16.1), 0.47, 0.92, "fire", 6)
	_light(Vector3(-16.8, 1.3, 16.1), Color("ffa45b"), 3.0, 7.0)
	# Wooden road marker with an understated, in-world title.
	_box("CampSignpost", Vector3(-11.7, 1.2, 17.3), Vector3(0.15, 2.4, 0.15), "wood")
	_box("CampSign", Vector3(-11.7, 2.1, 17.3), Vector3(2.1, 0.55, 0.16), "wood_light")
	_text("WAYFARER'S REST", Vector3(-11.7, 2.1, 17.4), 0.055, Color("e0d5ac"))

func _tent(origin: Vector3, angle: float, small: bool) -> void:
	var tent: Node3D = Node3D.new()
	tent.name = "WayfarerTent"
	add_child(tent)
	tent.position = origin
	tent.rotation.y = angle
	var roof_mesh: PrismMesh = PrismMesh.new()
	roof_mesh.size = Vector3(3.3 if small else 4.6, 2.8 if small else 3.2, 3.7)
	var canvas: MeshInstance3D = MeshInstance3D.new()
	canvas.mesh = roof_mesh
	canvas.material_override = _materials["cloth" if small else "cloth_dark"]
	canvas.position.y = (2.8 if small else 3.2) / 2.0
	tent.add_child(canvas)
	for side: float in [-1.0, 1.0]:
		var pole: MeshInstance3D = _cylinder("TentPole", origin + Vector3(side * 1.6, 1.35, 0), 0.055, 2.8, "wood", 6)
		pole.rotation.z = -side * 0.4
	_box("TentEntrance", origin + Vector3(0.0, 0.9, 1.87), Vector3(0.85, 1.8, 0.02), "coal")

func _create_ruins() -> void:
	# Broken monastery walls frame the east without enclosing the combat arena.
	_wall(Vector3(21.7, 0.0, -16.0), 14.0, 3.1, PI / 2.0)
	_wall(Vector3(16.0, 0.0, -16.5), 5.0, 2.6, 0.0)
	_wall(Vector3(25.0, 0.0, -16.5), 4.0, 3.7, 0.0)
	_arch(Vector3(18.0, 0.0, -14.0), 0.0, 4.5, 5.0)
	for index: int in range(7):
		var point: Vector3 = Vector3(16.0 + _rng.randf_range(-2.0, 9.0), 0.0, -19.0 + _rng.randf_range(-1.0, 10.0))
		_rock(point + Vector3(0.0, 0.2, 0.0), Vector3(_rng.randf_range(0.3, 0.8), _rng.randf_range(0.3, 0.9), _rng.randf_range(0.4, 0.9)), "stone")
	# A collapsed colonnade beside the approach to the old sanctum.
	for index: int in range(5):
		var z: float = -10.0 - float(index) * 4.2
		_pillar(Vector3(0.3, 0.0, z), 1.8 if index % 2 else 4.4, true)
		if index > 1:
			_pillar(Vector3(19.2, 0.0, z - 6.0), 3.7 if index % 2 else 2.0, true)
	_box("FallenLintel", Vector3(-1.1, 0.38, -15.0), Vector3(4.4, 0.65, 0.8), "stone").rotation.y = -0.55
	_box("FallenColumn", Vector3(21.0, 0.48, -27.0), Vector3(0.8, 0.8, 4.5), "stone").rotation.y = 0.35
	# Low plinths and a weathered stone guardian at the quest encounter.
	_cylinder("WardenDais", Vector3(18.0, 0.06, -9.0), 3.2, 0.12, "stone_dark", 12)
	for index: int in range(12):
		var a: float = TAU * float(index) / 12.0
		var block: MeshInstance3D = _box("WardenCircle", Vector3(18.0 + cos(a) * 3.1, 0.12, -9.0 + sin(a) * 3.1), Vector3(0.9, 0.08, 0.35), "stone_light")
		block.rotation.y = -a + PI / 2.0
	_lamp(Vector3(14.3, 0, -12.5))
	_lamp(Vector3(21.7, 0, -12.5))

func _create_shrine() -> void:
	# The circular boss arena is a strong destination visible beyond the ruins.
	_cylinder("SanctumFoundation", Vector3(10, 0.05, -24), 8.5, 0.10, "stone_dark", 32)
	_cylinder("SanctumPaving", Vector3(10, 0.12, -24), 7.5, 0.12, "stone_blue", 32)
	_cylinder("SanctumCenter", Vector3(10, 0.19, -24), 4.4, 0.06, "stone_dark", 24)
	for index: int in range(32):
		var angle: float = TAU * float(index) / 32.0
		var ring: MeshInstance3D = _box("SanctumBorder", Vector3(10.0 + cos(angle) * 7.65, 0.21, -24.0 + sin(angle) * 7.65), Vector3(1.3, 0.18, 0.48), "stone_light")
		ring.rotation.y = -angle + PI / 2.0
		if index % 2 == 0:
			var rune: MeshInstance3D = _box("SanctumGlyph", Vector3(10.0 + cos(angle) * 5.9, 0.192, -24.0 + sin(angle) * 5.9), Vector3(0.12, 0.022, 0.62), "rune_dim")
			rune.rotation.y = -angle
	for index: int in range(9):
		var angle: float = PI + float(index) * PI / 8.0
		var point: Vector3 = Vector3(10.0 + cos(angle) * 8.3, 0.0, -24.0 + sin(angle) * 8.3)
		_pillar(point, 4.8 if index % 3 else 3.2, true)
	# Back of sanctum: monumental relief with a cold runic heart.
	_box("SanctumRearWall", Vector3(10, 2.6, -33.5), Vector3(12.0, 5.2, 1.4), "stone_dark", true)
	for x: float in [5.0, 10.0, 15.0]:
		_box("SanctumButtress", Vector3(x, 3.1, -32.8), Vector3(0.9, 6.2, 1.6), "stone")
		_box("SanctumButtressCap", Vector3(x, 6.25, -32.8), Vector3(1.4, 0.4, 2.0), "stone_light")
	var crest: MeshInstance3D = _box("SanctumCrest", Vector3(10, 4.4, -32.75), Vector3(1.9, 1.9, 0.20), "copper")
	crest.rotation.z = PI / 4.0
	var core: MeshInstance3D = _box("SanctumHeart", Vector3(10, 4.4, -32.59), Vector3(1.2, 1.2, 0.24), "rune")
	core.rotation.z = PI / 4.0
	_light(Vector3(10, 4.0, -31.7), Color("85c8bb"), 2.5, 12.0)
	_banner(Vector3(3.5, 0.0, -18.3), -0.4)
	_banner(Vector3(16.5, 0.0, -18.3), 0.4)
	for side: float in [-1.0, 1.0]:
		_brazier(Vector3(10.0 + side * 5.1, 0.0, -18.2))
	_text("THE SUNDERED SANCTUM", Vector3(10, 5.9, -32.55), 0.24, Color("bac7b1"))

func _create_wilderness() -> void:
	# Denser trees mark the world perimeter; small groups break up the meadow.
	for index: int in range(108):
		var angle: float = _rng.randf_range(0.0, TAU)
		var radius: float = _rng.randf_range(31.0, 49.0)
		var point: Vector3 = Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
		if point.distance_to(Vector3(-20, 0, 15)) < 12.0 or (point.z < -20.0 and point.x > 0.0 and point.x < 21.0):
			continue
		_tree(point, _rng.randf_range(0.8, 1.65), index % 3)
	for point: Vector3 in [Vector3(-13, 0, 4), Vector3(-17, 0, -4), Vector3(-11, 0, -14), Vector3(23, 0, 15), Vector3(17, 0, 21), Vector3(-2, 0, 24), Vector3(-7, 0, 28), Vector3(-27, 0, -8), Vector3(24, 0, -1)]:
		_tree(point, _rng.randf_range(0.85, 1.15), 1)
	for index: int in range(64):
		var point: Vector3 = Vector3(_rng.randf_range(-34, 34), 0, _rng.randf_range(-34, 34))
		if _is_near_route(point, 2.5) or _is_landmark(point, 3.0):
			continue
		var size: float = _rng.randf_range(0.25, 1.0)
		_rock(point + Vector3(0, size * 0.25, 0), Vector3(size * 1.2, size * 0.75, size), "stone_dark" if index % 3 else "stone")
	for index: int in range(24):
		var angle: float = float(index) * TAU / 24.0
		var radius: float = _rng.randf_range(60.0, 78.0)
		var height: float = _rng.randf_range(14.0, 30.0)
		var mountain: MeshInstance3D = _cone("DistantCrag", Vector3(cos(angle) * radius, height * 0.5 - 3.0, sin(angle) * radius), _rng.randf_range(14.0, 24.0), height, "stone_dark", 5)
		mountain.rotation.y = _rng.randf_range(0.0, TAU)
		mountain.scale.z = _rng.randf_range(0.6, 1.3)
	# Fallen logs and old road posts lend human scale to the wilderness.
	for point: Vector3 in [Vector3(-10, 0, -2), Vector3(18, 0, 17), Vector3(-12, 0, 25)]:
		var log_mesh: MeshInstance3D = _cylinder("FallenLog", point + Vector3(0, 0.32, 0), 0.32, 3.0, "wood", 8)
		log_mesh.rotation = Vector3(PI / 2.0, _rng.randf_range(-1.0, 1.0), 0.0)
	for point: Vector3 in [Vector3(-5, 0, 13), Vector3(7, 0, -8), Vector3(15, 0, 2)]:
		_box("RoadMarker", point + Vector3(0, 0.55, 0), Vector3(0.45, 1.1, 0.35), "stone")
		_box("RoadMarkerCap", point + Vector3(0, 1.08, 0), Vector3(0.59, 0.13, 0.48), "stone_light")

func _create_grass() -> void:
	var blade: ArrayMesh = ArrayMesh.new()
	var vertices: PackedVector3Array = PackedVector3Array([
		Vector3(-0.15, 0, 0), Vector3(0.10, 0, 0), Vector3(0.01, 0.5, 0.06),
		Vector3(0, 0, -0.14), Vector3(0, 0, 0.13), Vector3(0.04, 0.38, 0)])
	var normals: PackedVector3Array = PackedVector3Array([
		Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.RIGHT, Vector3.RIGHT, Vector3.RIGHT])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	blade.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var grass_material: StandardMaterial3D = _materials["grass"].duplicate()
	grass_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	grass_material.vertex_color_use_as_albedo = false
	blade.surface_set_material(0, grass_material)
	var transforms: Array[Transform3D] = []
	for index: int in range(3600):
		var point: Vector3 = Vector3(_rng.randf_range(-37, 37), 0.035, _rng.randf_range(-37, 37))
		if _is_near_route(point, 2.1) or _is_landmark(point, 0.6) or point.x > 25.0:
			continue
		var basis: Basis = Basis(Vector3.UP, _rng.randf_range(0, TAU))
		basis = basis.scaled(Vector3.ONE * _rng.randf_range(0.65, 1.6))
		transforms.append(Transform3D(basis, point))
	var multimesh: MultiMesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = blade
	multimesh.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		multimesh.set_instance_transform(index, transforms[index])
	var grass: MultiMeshInstance3D = MultiMeshInstance3D.new()
	grass.name = "MeadowGrass"
	grass.multimesh = multimesh
	grass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grass)

func _create_boundaries() -> void:
	# Invisible field boundary keeps the prototype compact without horizon walls.
	for side: int in range(4):
		var body: StaticBody3D = StaticBody3D.new()
		body.name = "FrontierBoundary"
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = Vector3(2, 12, 82) if side < 2 else Vector3(82, 12, 2)
		var collision: CollisionShape3D = CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		body.position = [Vector3(-39, 4, 0), Vector3(39, 4, 0), Vector3(0, 4, -39), Vector3(0, 4, 39)][side]
		add_child(body)

func _is_near_route(point: Vector3, padding: float) -> bool:
	for route: PackedVector3Array in _paths:
		for index: int in range(route.size() - 1):
			var a: Vector3 = route[index]
			var b: Vector3 = route[index + 1]
			var direction: Vector3 = b - a
			var t: float = clampf((point - a).dot(direction) / direction.length_squared(), 0.0, 1.0)
			if point.distance_to(a + direction * t) < padding:
				return true
	return false

func _is_landmark(point: Vector3, padding: float) -> bool:
	return point.distance_to(Vector3(-19, 0, 15)) < 7.5 + padding or point.distance_to(boss_spawn) < 9.0 + padding or point.distance_to(quest_spawn) < 3.4 + padding

func _mesh(node_name: String, mesh: Mesh, point: Vector3, material_key: String, collision: bool = false) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = _materials[material_key]
	instance.position = point
	add_child(instance)
	if collision:
		instance.create_trimesh_collision()
	return instance

func _box(node_name: String, point: Vector3, size: Vector3, material_key: String, collision: bool = false) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return _mesh(node_name, mesh, point, material_key, collision)

func _cylinder(node_name: String, point: Vector3, radius: float, height: float, material_key: String, sides: int = 12) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	return _mesh(node_name, mesh, point, material_key)

func _cone(node_name: String, point: Vector3, radius: float, height: float, material_key: String, sides: int = 8) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	return _mesh(node_name, mesh, point, material_key)

func _rock(point: Vector3, size: Vector3, material_key: String) -> MeshInstance3D:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 6
	mesh.rings = 3
	var instance: MeshInstance3D = _mesh("WeatheredRock", mesh, point, material_key)
	instance.scale = size
	instance.rotation.y = _rng.randf_range(0, TAU)
	return instance

func _tree(point: Vector3, scale_value: float, variation: int) -> void:
	_cylinder("PineTrunk", point + Vector3(0, 1.65 * scale_value, 0), 0.22 * scale_value, 3.3 * scale_value, "wood", 7)
	var colors: Array[String] = ["pine_dark", "pine_mid", "pine_light"]
	for tier: int in range(3):
		var radius: float = (2.35 - float(tier) * 0.52) * scale_value
		var height: float = (3.35 - float(tier) * 0.26) * scale_value
		var crown: MeshInstance3D = _cone("PineBoughs", point + Vector3(0, (2.9 + float(tier) * 1.22) * scale_value, 0), radius, height, colors[(variation + tier) % 3], 7)
		crown.rotation.y = float(tier) * 0.33

func _wall(point: Vector3, length: float, height: float, angle: float) -> void:
	var parent: Node3D = Node3D.new()
	parent.name = "MonasteryWall"
	add_child(parent)
	parent.position = point
	parent.rotation.y = angle
	var rows: int = int(ceil(height / 0.6))
	for row: int in range(rows):
		var block_count: int = int(ceil(length / 1.4))
		for index: int in range(block_count):
			if row == rows - 1 and _rng.randf() < 0.3:
				continue
			var block: MeshInstance3D = _box("WallAshlar", Vector3(-length * 0.5 + float(index) * 1.4 + (0.35 if row % 2 else 0.0), float(row) * 0.57 + 0.28, 0), Vector3(1.33, 0.55, 0.8), "stone" if row % 3 else "stone_dark", row == 0)
			block.reparent(parent, false)
			if row == rows - 1:
				block.rotation.z = _rng.randf_range(-0.06, 0.06)

func _pillar(point: Vector3, height: float, weathered: bool) -> void:
	_box("ColumnPlinth", point + Vector3(0, 0.16, 0), Vector3(1.65, 0.32, 1.65), "stone_dark")
	_box("ColumnBase", point + Vector3(0, 0.38, 0), Vector3(1.24, 0.20, 1.24), "stone_light")
	var column: MeshInstance3D = _cylinder("MonasteryColumn", point + Vector3(0, height * 0.5 + 0.4, 0), 0.48, height, "stone", 8)
	column.create_trimesh_collision()
	if height > 3.0:
		_box("ColumnCapital", point + Vector3(0, height + 0.45, 0), Vector3(1.4, 0.35, 1.4), "stone_light")
		_box("ColumnAbacus", point + Vector3(0, height + 0.7, 0), Vector3(1.64, 0.18, 1.64), "stone")
	if weathered:
		_box("ColumnMoss", point + Vector3(0.23, 0.57, 0.0), Vector3(0.6, 0.09, 0.9), "moss")

func _arch(point: Vector3, angle: float, width: float, height: float) -> void:
	var forward: Vector3 = Vector3(sin(angle), 0, cos(angle))
	var across: Vector3 = Vector3(cos(angle), 0, -sin(angle))
	for side: float in [-1.0, 1.0]:
		var foot: Vector3 = point + across * side * width * 0.5
		_box("GatePlinth", foot + Vector3(0, 0.18, 0), Vector3(1.4, 0.36, 1.5), "stone_dark")
		_box("GatePillar", foot + Vector3(0, height * 0.5, 0), Vector3(0.95, height, 1.0), "stone", true)
		_box("GateCapital", foot + Vector3(0, height, 0), Vector3(1.5, 0.35, 1.5), "stone_light")
	var lintel: MeshInstance3D = _box("AncientGateLintel", point + Vector3(0, height + 0.4, 0), Vector3(width + 1.7, 0.7, 1.3), "stone_dark")
	lintel.rotation.y = angle
	var trim: MeshInstance3D = _box("AncientGateTrim", point + Vector3(0, height + 0.85, 0) + forward * 0.05, Vector3(width + 2.0, 0.22, 1.55), "stone_light")
	trim.rotation.y = angle
	var gem: MeshInstance3D = _box("GateKeystone", point + Vector3(0, height + 0.3, 0) + forward * 0.72, Vector3(0.56, 0.56, 0.14), "copper")
	gem.rotation.z = PI / 4.0

func _banner(point: Vector3, angle: float) -> void:
	_box("BannerBase", point + Vector3(0, 0.2, 0), Vector3(0.8, 0.4, 0.8), "stone_dark")
	_cylinder("BannerPole", point + Vector3(0, 2.5, 0), 0.065, 5.0, "copper", 8)
	_cone("BannerFinial", point + Vector3(0, 5.1, 0), 0.16, 0.45, "copper", 4)
	var cloth: MeshInstance3D = _box("FrontierStandard", point + Vector3(0.63, 3.75, 0), Vector3(1.15, 1.8, 0.06), "banner")
	cloth.rotation.y = angle
	var sigil: MeshInstance3D = _box("StandardSigil", point + Vector3(0.63, 3.85, 0.05), Vector3(0.43, 0.43, 0.07), "copper")
	sigil.rotation.z = PI / 4.0

func _lamp(point: Vector3) -> void:
	_cylinder("LanternPost", point + Vector3(0, 1.5, 0), 0.07, 3.0, "wood", 7)
	_box("LanternCrossbar", point + Vector3(0.3, 2.9, 0), Vector3(0.75, 0.1, 0.1), "iron")
	_box("LanternCage", point + Vector3(0.6, 2.55, 0), Vector3(0.4, 0.65, 0.4), "iron")
	_box("LanternGlass", point + Vector3(0.6, 2.55, 0.01), Vector3(0.32, 0.48, 0.42), "fire")
	_cone("LanternHood", point + Vector3(0.6, 2.96, 0), 0.38, 0.22, "iron", 4)
	_light(point + Vector3(0.6, 2.4, 0), Color("ffc07b"), 2.2, 5.0)

func _brazier(point: Vector3) -> void:
	_cylinder("BrazierBase", point + Vector3(0, 0.15, 0), 0.65, 0.3, "stone_dark", 8)
	_cylinder("BrazierStem", point + Vector3(0, 0.9, 0), 0.19, 1.5, "iron", 8)
	_cylinder("BrazierBowl", point + Vector3(0, 1.65, 0), 0.62, 0.22, "copper", 8)
	_cone("BrazierFlame", point + Vector3(0, 2.08, 0), 0.4, 0.8, "fire", 7)
	_light(point + Vector3(0, 2.25, 0), Color("ffba73"), 2.8, 6.0)

func _light(point: Vector3, color: Color, energy: float, light_range: float) -> void:
	var light: OmniLight3D = OmniLight3D.new()
	light.position = point
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = false
	add_child(light)

func _barrel(point: Vector3) -> void:
	_cylinder("ProvisionBarrel", point + Vector3(0, 0.65, 0), 0.48, 1.3, "wood_light", 10)
	for height: float in [0.2, 0.95]:
		_cylinder("BarrelHoop", point + Vector3(0, height, 0), 0.5, 0.08, "iron", 10)
	_cylinder("BarrelLid", point + Vector3(0, 1.31, 0), 0.46, 0.04, "wood", 10)

func _crate(point: Vector3, size: float) -> void:
	_box("ProvisionCrate", point + Vector3(0, size * 0.5, 0), Vector3.ONE * size, "wood_light")
	for height: float in [0.1, size - 0.1]:
		_box("CrateBinding", point + Vector3(0, height, 0), Vector3(size + 0.06, 0.09, size + 0.06), "wood")
	var diagonal: MeshInstance3D = _box("CrateBrace", point + Vector3(0, size * 0.5, size * 0.51), Vector3(size * 1.18, 0.1, 0.06), "wood")
	diagonal.rotation.z = 0.65

func _text(content: String, point: Vector3, size: float, color: Color) -> void:
	var label: Label3D = Label3D.new()
	label.text = content
	label.font_size = 44
	label.pixel_size = size / 10.0
	label.modulate = color
	label.outline_modulate = Color("26342d")
	label.outline_size = 5
	label.position = point
	label.no_depth_test = false
	add_child(label)
