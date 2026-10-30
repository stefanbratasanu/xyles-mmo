extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1600, 900)
	var editor = load("res://scenes/world_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	var point := Vector2(50.0, 50.0)
	var height: float = editor.world.surface_height_at(point.x, point.y)
	editor.camera.position = Vector3(point.x + 22.0, height + 22.0, point.y + 26.0)
	editor.camera.look_at(Vector3(point.x, height, point.y), Vector3.UP)
	editor.selected_asset = "lake"
	editor._place(Vector3(point.x, height, point.y))
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://logs/world_editor_lake_shore.png") == OK)
	editor.queue_free()
	await process_frame
	print("PASS: editor lake shore rendered")
	quit()
