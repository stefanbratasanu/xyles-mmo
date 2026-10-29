extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1600, 900)
	var game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	await process_frame
	var world = game.world
	var camp: Node3D = world.find_child("SurvivorCamp", true, false)
	assert(camp != null)
	var seats := get_nodes_in_group("camp_seats")
	assert(seats.size() == 2, "Both logs must be interactable")
	var seat: Node3D = seats[0]
	assert(seat.get_node_or_null("SeatCollision/CollisionShape3D") != null)
	assert(world.get_node_or_null("CampRoadClearing") != null)
	var gate_lights: Array[Node3D] = []
	for child: Node in camp.get_children():
		if child.get_node_or_null("TripodCresset") != null:
			gate_lights.append(child as Node3D)
			assert(Vector2(child.position.x, child.position.z).length() > 13.2, "No torch stand belongs inside the fence")
	var gate_count := 0
	for road: PackedVector2Array in world.roads:
		var center := Vector2(world.camp_position.x, world.camp_position.z)
		if road.size() < 2 or road[0].distance_to(center) > 2.0:
			continue
		gate_count += 1
		var direction := (road[1] - road[0]).normalized()
		var angle := atan2(direction.y, direction.x)
		var sides := [false, false]
		for torch: Node3D in gate_lights:
			var torch_angle := atan2(torch.position.z, torch.position.x)
			var difference := angle_difference(angle, torch_angle)
			if absf(absf(difference) - (asin(3.0 / 13.2) + 0.085)) < 0.14:
				sides[0 if difference < 0 else 1] = true
		assert(sides[0] and sides[1], "Each gate must have one torch on either side")
	assert(gate_lights.size() <= gate_count * 2, "Only gate torches belong in the camp scene")
	for i in range(gate_lights.size()):
		for j in range(i + 1, gate_lights.size()):
			assert(gate_lights[i].position.distance_to(gate_lights[j].position) >= 2.0, "Gate torches overlap")
	for road_light: Vector3 in world.road_lamps:
		for gate_light: Node3D in gate_lights:
			assert(road_light.distance_to(gate_light.global_position) >= 3.0, "Road torch overlaps a gate torch")
	var flames := get_nodes_in_group("world_flames")
	assert(flames.size() >= gate_lights.size() + 1, "Campfire and gate torches must be present")
	world.set_time_of_day(12.0)
	for flame: Node3D in flames:
		assert(not flame.visible, "Fire must be unlit in daytime")
		assert(not (flame.get_node("FireSound") as AudioStreamPlayer3D).playing, "Fire sound must stop in daytime")
	world.set_time_of_day(22.0)
	for flame: Node3D in flames:
		assert(flame.visible, "Fire must be lit at night")
		assert((flame.get_node("FireSound") as AudioStreamPlayer3D).playing, "Night fire must have positional sound")
	world.set_time_of_day(12.0)
	var player = game.player
	var spot: Vector3 = seat.to_global(Vector3(0.8, 0.5, -1.4))
	player.global_position = spot
	player.velocity = Vector3.ZERO
	for i in range(60):
		await physics_frame
	assert(player.is_on_floor(), "Player must settle beside the seat")
	var start_local: Vector3 = seat.to_local(player.global_position)
	game.interact()
	assert(player.sitting, "E interaction must start sitting")
	for i in range(600):
		await physics_frame
		if player.animation_player.current_animation == "seat/idle":
			break
	print("Seat animation reached: ", player.animation_player.current_animation)
	assert(player.animation_player.current_animation == "seat/idle", "Sitting must use the log-seat pose")
	var seated_local: Vector3 = seat.to_local(player.global_position)
	assert(absf(seated_local.x - start_local.x) < 0.08, "The player must sit where they approached along the log")
	assert(seated_local.z < -0.55 and seated_local.z > -0.9, "Collision body must settle beside the same side of the log")
	var skeleton := player.visual.find_child("Skeleton3D", true, false) as Skeleton3D
	var hip := skeleton.find_bone("humanoid_ Pelvis")
	var hip_position := seat.to_local(skeleton.to_global(skeleton.get_bone_global_pose(hip).origin))
	assert(absf(hip_position.x - start_local.x) < 0.12 and absf(hip_position.z) < 0.12, "The hips must meet the selected point on the log")
	if DisplayServer.get_name() != "headless":
		game.camera_distance = 7.0
		game.camera_pitch = 0.35
		game.camera_focus = player.global_position + Vector3.UP
		game._update_camera(1.0)
		for i in range(15):
			await process_frame
		root.get_texture().get_image().save_png("res://screenshots/camp_seating_test.png")
	var event := InputEventKey.new()
	event.physical_keycode = KEY_W
	event.pressed = true
	Input.parse_input_event(event)
	for i in range(600):
		await physics_frame
		if not player.sitting and not player.seat_returning:
			break
	event.pressed = false
	Input.parse_input_event(event)
	print("After movement: sitting=", player.sitting, " animation=", player.animation_player.current_animation, " requested=", player.stand_requested)
	assert(not player.sitting, "Movement must stand the player up")
	assert(player.visual.position.distance_to(Vector3.ZERO) < 0.01, "Standing must restore visual position")
	var standing_local: Vector3 = seat.to_local(player.global_position)
	assert(absf(standing_local.x - seated_local.x) < 0.1 and absf(standing_local.z - seated_local.z) < 0.1, "Standing must finish at the seat, not the old starting position")
	game.queue_free()
	await process_frame
	print("CAMP SEATING: PASS")
	quit()
