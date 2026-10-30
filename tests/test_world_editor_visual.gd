extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var editor = load("res://scenes/world_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://logs/world_editor_ui.png") == OK)
	var card: Dictionary = editor.asset_cards["tent"]
	assert(card["image"].texture != null and card["model"] is Node3D)
	card["button"].mouse_entered.emit()
	var before: float = card["model"].rotation.y
	editor._process(0.5)
	assert(card["model"].rotation.y > before)
	card["button"].mouse_exited.emit()
	var tabs: Array[Node] = editor.find_children("*", "TabContainer", true, false)
	assert(tabs.size() == 1)
	tabs[0].current_tab = 1
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://logs/world_editor_buildings.png") == OK)
	tabs[0].current_tab = 2
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://logs/world_editor_terrain.png") == OK)
	tabs[0].current_tab = 4
	editor.zone_name.text = "Starter area"
	editor._begin_zone()
	editor._paint_zone(Vector3(-36.0, 0.0, 32.0))
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://logs/world_editor_zones.png") == OK)
	editor._finish_zone()
	editor._show_new_project()
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://logs/world_editor_new_project.png") == OK)
	editor.project_dialog.hide()
	root.size = Vector2i(1100, 650)
	await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://logs/world_editor_small.png") == OK)
	editor.queue_free()
	await process_frame
	print("PASS: editor rendered")
	quit()
