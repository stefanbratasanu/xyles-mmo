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
	var torches: Array[Node3D] = []
	for node: Node in camp.get_children():
		if node.get_node_or_null("TripodCresset") != null:
			torches.append(node as Node3D)
	assert(not torches.is_empty())
	for torch: Node3D in torches:
		var flame := torch.get_node("Flame") as Node3D
		var particles := flame.get_node("FireParticles") as GPUParticles3D
		assert(particles.local_coords, "Torch particles must follow stand transforms")
		assert(is_equal_approx(torch.scale.y, 0.6), "Torch stand scale changed unexpectedly")
		assert(is_equal_approx(flame.position.y, 2.28), "Flame must originate at the bowl")
		assert(flame.scale.x < 0.75, "Flame must be reduced with the stand")
		var quad := particles.draw_pass_1 as QuadMesh
		var process := particles.process_material as ParticleProcessMaterial
		assert(particles.position.y - quad.size.y * process.scale_max * 0.5 - process.emission_sphere_radius >= 0.0, "Particle sprite must not extend below the bowl")
	world.set_time_of_day(22.0)
	var target: Node3D = torches[0]
	game.camera_distance = 5.0
	game.camera_pitch = 0.25
	game.player.global_position = target.global_position + Vector3(0, 0.3, 1.3)
	game.camera_focus = target.global_position + Vector3.UP * 1.0
	game._update_camera(1.0)
	if DisplayServer.get_name() != "headless":
		for i in range(90):
			await process_frame
		root.get_texture().get_image().save_png("res://screenshots/camp_torch_test.png")
	game.queue_free()
	await process_frame
	print("CAMP TORCH: PASS")
	quit()
