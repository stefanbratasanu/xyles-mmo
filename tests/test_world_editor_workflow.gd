extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1600, 900)
	var editor = load("res://scenes/world_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	await physics_frame
	var directory := "user://editor_workflow_test_%d" % Time.get_ticks_usec()
	editor.store = load("res://scripts/world_editor/draft_store.gd").new(directory)
	editor.name_edit.text = "Test map"
	var initial_position: Vector3 = editor.world.player_spawn
	var projected: Vector2 = editor.camera.unproject_position(initial_position) + editor.view_container.global_position
	assert(editor.view_container.get_global_rect().has_point(projected))
	var ground: Variant = editor._ground_point(projected)
	assert(ground is Vector3, "the contained viewport must raycast to the map")
	editor.mode = "place"
	editor.selected_asset = "stone_1"
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = projected
	click.pressed = true
	editor._unhandled_input(click)
	assert(editor.placements.size() == 1, "viewport click should place the selected asset")
	editor._delete_selected()
	assert(editor.placements.is_empty())
	var original: StaticBody3D
	for nodes: Array in editor.world._streamed_visual_nodes.values():
		for node: Node in nodes:
			var candidate := node.get_node_or_null("TreeTrunks") as StaticBody3D
			if candidate != null and not candidate.get_shape_owners().is_empty():
				original = candidate
				break
		if original != null: break
	assert(original != null)
	var owner_id: int = original.get_shape_owners()[0]
	var shape_index: int = original.shape_owner_get_shape_index(owner_id, 0)
	editor._select_tree(original, shape_index)
	assert(not editor.selected_tree.is_empty())
	editor._delete_selected()
	assert(editor.removed_trees.size() == 1)
	var vegetation: Dictionary = {}
	for veg_cell: Vector2i in editor.world._streamed_visual_nodes:
		var tile: Resource = load(editor.world._vegetation_paths[veg_cell])
		for group: Dictionary in tile.groups:
			if str(group["name"]) == "Underbrush" and not group["entries"].is_empty():
				vegetation = {"cell": [veg_cell.x, veg_cell.y], "group": "Underbrush", "index": 0}
				break
		if not vegetation.is_empty(): break
	assert(not vegetation.is_empty())
	editor._select_vegetation(vegetation)
	assert(not editor.selected_tree.is_empty())
	editor._delete_selected()
	assert(editor.removed_trees.size() == 2)
	var tent_walls: StaticBody3D
	for holder: Node in editor.world._static_active.values():
		for candidate: Node in holder.find_children("*", "StaticBody3D", true, false):
			if str(candidate.name).begins_with("TentWalls"):
				tent_walls = candidate
				break
		if tent_walls != null: break
	assert(tent_walls != null)
	editor._select_static(tent_walls)
	assert(not editor.selected_static.is_empty())
	var moved_x: float = editor.selected.global_position.x + 2.0
	editor.fields["X"].value = moved_x
	assert(absf(editor.selected.global_position.x - moved_x) < 0.01)
	assert(editor.static_edits.size() == 1)
	editor.selected_asset = "tent"
	editor._place(Vector3(-34.0, editor.world.height_at(-34.0, 30.0), 30.0))
	assert(editor.placements.size() == 1)
	var id: String = editor.placements[0]["uid"]
	editor.fields["Rotation"].value = 90.0
	assert(absf(float(editor.placements[0]["rotation"]) - PI / 2.0) < 0.001)
	editor._save()
	assert(not editor.dirty)
	var saved: Dictionary = editor.store.load_draft(editor.draft_id)
	assert(saved["payload"]["placements"][0]["uid"] == id)
	assert(saved["payload"]["removed_trees"].size() == 2)
	assert(saved["payload"]["static_edits"].size() == 1)
	assert(editor.store.load_published().is_empty())
	editor._apply()
	assert(editor.store.load_published()["payload"]["placements"].size() == 1)
	assert("Test map" in editor.active_map_label.text)
	var draft_id: String = editor.draft_id
	editor._show_load_project()
	assert(editor.load_project_list.item_count == 1)
	assert("applied snapshot" in editor.load_project_list.get_item_text(0))
	var published_position: float = editor.store.load_published()["payload"]["placements"][0]["position"][0]
	editor.fields["X"].value += 1.0
	editor._save()
	assert(is_equal_approx(float(editor.store.load_published()["payload"]["placements"][0]["position"][0]), published_position))
	editor._show_load_project()
	assert("draft differs from applied snapshot" in editor.load_project_list.get_item_text(0))
	editor.load_project_list.select(0)
	editor._load_project_confirmed()
	assert(editor.draft_id == draft_id and editor.placements.size() == 1)
	editor._new_draft()
	editor._open_draft(draft_id)
	assert(editor.placements.size() == 1)
	assert(editor.removed_trees.size() == 2)
	assert(editor.static_edits.size() == 1)
	var edit: Dictionary = editor.static_edits[0]
	var cell := Vector2i(int(edit["cell"][0]), int(edit["cell"][1]))
	var original_tent: Node3D = editor.world._static_active[cell].get_node(NodePath(edit["path"]))
	assert(absf(original_tent.global_position.x - moved_x) < 0.01)
	assert(editor.world.find_child("Placed_tent", true, false) != null)
	editor._clear_all()
	assert(editor.clear_base and editor.placements.is_empty())
	assert(is_nan(editor.grid.sample_height(Vector2.ZERO)))
	editor._paint(Vector3.ZERO)
	assert(is_finite(editor.grid.sample_height(Vector2.ZERO)))
	assert(not editor.world.find_children("EditedTerrain_*", "MeshInstance3D", false, false).is_empty())
	assert(not preload("res://scripts/world_editor/map_runtime.gd").validate(editor._payload(), editor.world).is_empty())
	editor._fill_ground()
	assert(preload("res://scripts/world_editor/map_runtime.gd").validate(editor._payload(), editor.world).is_empty())
	editor._apply()
	assert(bool(editor.store.load_published()["payload"]["clear_base"]))
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://logs/world_editor_ui.png")
	for suffix: String in ["", ".bak", ".tmp"]:
		var draft_path := ProjectSettings.globalize_path(directory.path_join("drafts").path_join(draft_id + ".json" + suffix))
		if FileAccess.file_exists(draft_path): DirAccess.remove_absolute(draft_path)
		var active_path := ProjectSettings.globalize_path(directory.path_join("active_map.json" + suffix))
		if FileAccess.file_exists(active_path): DirAccess.remove_absolute(active_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory.path_join("drafts")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))
	editor.queue_free()
	await process_frame
	print("PASS: editor place, transform, draft save, apply, reopen and clear")
	quit()
