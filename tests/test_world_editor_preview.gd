extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var preview = load("res://scenes/world_editor_preview.tscn").instantiate()
	root.add_child(preview)
	await process_frame
	await process_frame
	assert(preview.world != null)
	assert(preview.camera != null and preview.camera.current)
	assert(not preview.world._terrain_paths.is_empty())
	assert(not preview.world._vegetation_paths.is_empty())
	var right := InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	preview._unhandled_input(right)
	var start_rotation: Vector3 = preview.camera.rotation
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(20.0, -10.0)
	preview._unhandled_input(motion)
	assert(not preview.camera.rotation.is_equal_approx(start_rotation))
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	Input.parse_input_event(key)
	var start_position: Vector3 = preview.camera.position
	await process_frame
	await process_frame
	assert(preview.camera.position.distance_to(start_position) > 0.0)
	key.pressed = false
	Input.parse_input_event(key)
	right.pressed = false
	preview._unhandled_input(right)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		assert(image.save_png("res://logs/world_editor_preview.png") == OK)
	print("PASS: world editor preview loads the authored map and camera")
	preview.queue_free()
	await process_frame
	quit()
