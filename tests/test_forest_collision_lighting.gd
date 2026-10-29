extends SceneTree

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.player.set_physics_process(false)
	for enemy in game.enemies:
		enemy.set_physics_process(false)
	await physics_frame
	var trunks := get_nodes_in_group("tree_trunks")
	check(not trunks.is_empty() and trunks[0].get_child_count() > 0, "Streamed trees have collision shapes")
	if not trunks.is_empty() and trunks[0].get_child_count() > 0:
		var sample: CollisionShape3D = trunks[0].get_child(0)
		var middle: Vector3 = sample.global_position
		var query := PhysicsRayQueryParameters3D.create(middle + Vector3.LEFT * 1.5, middle + Vector3.RIGHT * 1.5, 8)
		var result: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
		check(not result.is_empty() and result.collider.is_in_group("tree_trunks"), "Streamed trunk blocks physics queries on the trunk layer")
		check((game.player.collision_mask & 8) != 0 and (game.camera_arm.collision_mask & 8) == 0, "Characters collide with trees without forcing the camera into the player")
	check(game.player_listener.is_current(), "Player listener is current")
	var test_forest_cell: Vector2i = game.world.stream_cell(Vector3(-145.0, 0.0, 19.1))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var cell := test_forest_cell + Vector2i(dx, dz)
			if not game.world._static_active.has(cell):
				var static_path: String = game.world._static_paths.get(cell, "")
				if not static_path.is_empty():
					game.world._activate_static_cell(cell, load(static_path))
	var rock_count := 0
	for cell in game.world._static_active:
		var static_cell: Node = game.world._static_active[cell]
		for rock: Node in static_cell.find_children("*", "MeshInstance3D", true, false):
			var boulder := rock as MeshInstance3D
			if boulder.mesh != null and (str(boulder.name).begins_with("Boulder") or boulder.mesh.resource_name.begins_with("rock_")):
				rock_count += 1
				var bottom: float = boulder.global_position.y + boulder.mesh.get_aabb().position.y * boulder.global_basis.get_scale().y
				check(bottom <= game.world.height_at(boulder.global_position.x, boulder.global_position.z) - 0.039, "Boulder bottom is sunk into the ground")
	check(rock_count > 0, "Loaded scenery contains settled boulders")
	game.player.global_position = Vector3(23.0, 5.0, 20.0)
	game._update_camera(1.0)
	check(game.player_listener.global_position.is_equal_approx(game.player.global_position + Vector3.UP), "Listener follows the player")
	check(game.player_listener.global_basis.is_equal_approx(game.camera.global_basis), "Listener retains the camera's stereo orientation")
	game.set_sun_shafts_enabled(false)
	check(not bool(game.world._shaft_material.get_shader_parameter("enabled")), "Sun shafts can be disabled")
	var shafts: Array[MultiMeshInstance3D] = []
	for cell in game.world._streamed_visual_nodes:
		for node: Node in game.world._streamed_visual_nodes[cell]:
			if node is MultiMeshInstance3D and str(node.name).begins_with("SunShafts_"):
				shafts.append(node)
	check(not shafts.is_empty(), "Forest cells contain localized shafts")
	if not shafts.is_empty():
		check(not shafts[0].visible, "Disabling shafts hides their draw calls")
	game.set_sun_shafts_enabled(true)
	check(bool(game.world._shaft_material.get_shader_parameter("enabled")), "Sun shafts can be enabled")
	var settings := ConfigFile.new()
	game._store_graphics_settings(settings)
	check(settings.get_value("graphics", "sun_shafts", false), "Sun shaft setting is saved")
	game.world.set_time_of_day(12.0)
	while not game.world._shaft_refresh_queue.is_empty():
		game.world._pump_shaft_refresh()
	check(float(game.world._shaft_material.get_shader_parameter("daylight")) > 0.0, "Sun shafts appear in daylight")
	var forest_cell: Vector2i = game.world.stream_cell(Vector3(-145.0, 0.0, 19.1))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var cell := forest_cell + Vector2i(dx, dz)
			if not game.world._streamed_visual_nodes.has(cell):
				var path: String = game.world._vegetation_paths.get(cell, "")
				if not path.is_empty():
					game.world._activate_vegetation_tile(cell, load(path))
				for node: Node in game.world._streamed_visual_nodes.get(cell, []):
					if node is MultiMeshInstance3D and node.has_meta("shaft_data"):
						shafts.append(node)
	var visible_rays := 0
	for shaft: MultiMeshInstance3D in shafts:
		var data: Array = shaft.get_meta("shaft_data")
		for index in shaft.multimesh.instance_count:
			if game.world._shaft_path_clear(data[index].position, game.world._shaft_slope, data[index].height, data[index].width):
				visible_rays += 1
				var item: Dictionary = data[index]
				check(game.world._shaft_path_clear(item.position, game.world._shaft_slope, item.height, item.width), "Displayed shaft clears trunks, roads and open areas")
	print("FOREST RAYS: ", visible_rays, " visible in ", shafts.size(), " batches")
	check(visible_rays > 0, "At least one clear forest shaft is visible at noon")
	var day_sky: Color = game.world._sky_material.get_shader_parameter("top_color")
	check(day_sky.b > day_sky.r and game.world._environment.fog_sky_affect < 0.2, "Day sky remains blue above the horizon fog")
	check(game.world._environment.fog_density > 0.0, "Distance fog remains enabled")
	if not shafts.is_empty(): check(shafts[0].visible, "Shafts are visible in daylight")
	var midday_slope: Vector2 = game.world._shaft_material.get_shader_parameter("sun_slope")
	game.world.set_time_of_day(8.0)
	check(not midday_slope.is_equal_approx(game.world._shaft_material.get_shader_parameter("sun_slope")), "Shaft direction follows the sun")
	check(is_zero_approx(float(game.world._shaft_material.get_shader_parameter("daylight"))), "No shafts before 10:00")
	game.world.set_time_of_day(10.5)
	check(float(game.world._shaft_material.get_shader_parameter("daylight")) > 0.0, "Shafts start after 10:00")
	game.world.set_time_of_day(16.0)
	check(is_equal_approx(float(game.world._shaft_material.get_shader_parameter("daylight")), 1.0), "Shafts begin fading at 16:00")
	game.world.set_time_of_day(16.5)
	check(float(game.world._shaft_material.get_shader_parameter("daylight")) < 1.0, "Shafts fade after 16:00")
	game.world.set_time_of_day(17.0)
	check(is_zero_approx(float(game.world._shaft_material.get_shader_parameter("daylight"))), "Shafts finish fading at 17:00")
	game.world.set_time_of_day(23.0)
	check(is_zero_approx(float(game.world._shaft_material.get_shader_parameter("daylight"))), "Sun shafts fade out at night")
	if not shafts.is_empty(): check(not shafts[0].visible, "Night shafts do not issue draw calls")
	# A representative trunk on an isolated platform tests physical impact and
	# the stun timer without relying on the particular streamed tree layout.
	var platform := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(20, 1, 20)
	floor_shape.shape = floor_box
	floor_shape.position = Vector3(0, -0.5, 0)
	platform.add_child(floor_shape)
	root.add_child(platform)
	platform.position = Vector3(0, 100, 0)
	var tree := StaticBody3D.new()
	tree.add_to_group("tree_trunks")
	tree.collision_layer = 8
	var trunk := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 0.43
	cylinder.height = 3.0
	trunk.shape = cylinder
	trunk.position.y = 1.4
	tree.add_child(trunk)
	root.add_child(tree)
	tree.position = Vector3(0, 100, 0)
	game.player.global_position = Vector3(15, 100, 0)
	var boar: CharacterBody3D = game._spawn_enemy("normal", Vector3(-3, 100, 0), 0, "boar")
	boar.set_physics_process(false)
	boar.global_position = Vector3(-3, 100.1, 0)
	boar.locked_dir = Vector3.RIGHT
	boar.charge_active = true
	boar.charge_distance = 12.0
	boar.charge_speed = 15.0
	for i in range(30):
		await physics_frame
		if not boar.charge_active:
			break
		boar._advance_charge(1.0 / 60.0)
	check(not boar.charge_active and is_equal_approx(boar.stun_time, 2.0), "Charging boar stops and is stunned for two seconds")
	check(boar.stun_indicator.visible and boar.stun_indicator.get_child_count() == 3, "Stun displays three stars")
	check(boar.stun_indicator.position.y < boar.health_bar_root.position.y, "Stun stars sit above the head, below the health bar")
	var star_before: Vector3 = (boar.stun_indicator.get_child(0) as Node3D).position
	check(boar.global_position.x < 0.0, "Boar did not pass through trunk")
	boar._physics_process(1.0)
	check(is_equal_approx(boar.stun_time, 1.0), "Stun prevents action while counting down")
	check(not (boar.stun_indicator.get_child(0) as Node3D).position.is_equal_approx(star_before), "Stun stars rotate during the stun")
	boar._physics_process(1.0)
	check(is_zero_approx(boar.stun_time), "Stun expires after two seconds")
	check(not boar.stun_indicator.visible, "Stun stars disappear when stun expires")
	game.queue_free()
	platform.queue_free()
	tree.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: forest collisions, stun, listener and sun shaft settings")
	quit(1 if failures else 0)
