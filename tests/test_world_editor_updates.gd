extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1600, 900)
	var editor = load("res://scenes/world_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	await physics_frame
	var path := "user://editor_updates_test_%d" % Time.get_ticks_usec()
	editor.store = load("res://scripts/world_editor/draft_store.gd").new(path)

	# The existing five regions appear as distinct colors in the zone view.
	editor.tabs.current_tab = 4
	assert(editor.zone_overlay.visible and editor.zone_overlay.multimesh.instance_count > 1000)
	var colors := {}
	for index in editor.zone_base_cells.values(): colors[index] = true
	assert(colors.size() == editor.world.zones.size())
	for zone: Dictionary in editor.world.zones:
		assert(str(zone["name"]) in editor.zone_legend.text)

	# Wheel zoom approaches the actual ground closely and moves back out.
	var screen: Vector2 = editor.camera.unproject_position(editor.world.player_spawn) + editor.view_container.global_position
	var ground: Vector3 = editor._ground_point(screen)
	var old_distance: float = editor.camera.global_position.distance_to(ground)
	for unused in 30: editor._zoom_at(screen, true)
	var close_distance: float = editor.camera.global_position.distance_to(ground)
	assert(close_distance < 0.5 and close_distance > 0.15)
	editor._zoom_at(screen, false)
	assert(editor.camera.global_position.distance_to(ground) > close_distance)
	# WASD works with the mouse over the viewport without holding right mouse.
	var before_move: Vector3 = editor.camera.global_position
	editor._move_camera(0.25, true, false, false, false, true, false, false, false, false, false)
	assert(not editor.looking and editor.camera.global_position.distance_to(before_move) > 1.0)
	before_move = editor.camera.global_position
	editor._move_camera(0.25, true, true, false, false, true, false, false, false, false, false)
	assert(editor.camera.global_position == before_move)

	# One drag of the asset brush is one undo, even with multiple placements.
	editor.tabs.current_tab = 0
	editor.selected_asset = "stone_1"
	editor.stroke_active = true
	editor._place(Vector3(20, 3, 20), false)
	editor._place(Vector3(23, 3, 20), false)
	assert(editor.placements.size() == 2 and editor.undo_stack.size() == 1)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	editor._input(release)
	var undo := InputEventKey.new()
	undo.pressed = true
	undo.ctrl_pressed = true
	undo.keycode = KEY_Z
	editor._input(undo)
	assert(editor.placements.is_empty())

	# Painting terrain, then undoing, restores the original height and state.
	var point := Vector2(20.0, 20.0)
	var original_height: float = editor.world.surface_height_at(point.x, point.y)
	editor.mode = "raise"
	editor._paint(Vector3(point.x, original_height, point.y))
	assert(editor.terrain_changed and editor.grid.sample_height(point) > original_height)
	editor._undo()
	assert(not editor.terrain_changed and absf(editor.world.surface_height_at(point.x, point.y) - original_height) < 0.001)

	# Lakes create walkable terrain, a submerged basin and a matching shore.
	editor.selected_asset = "lake"
	editor._place(Vector3(point.x, original_height, point.y))
	assert(editor.terrain_changed and editor.placements.size() == 1)
	var water_level: float = editor.placements[0]["position"][1]
	assert(editor.grid.sample_height(point) < water_level - 0.8)
	assert(editor.world.water_depth_at(point.x, point.y) > 0.8)
	assert(absf(editor.grid.sample_height(point + Vector2(8.0, 0.0)) - water_level) < 0.35)
	var serialized: Dictionary = JSON.parse_string(JSON.stringify(editor._payload()))
	var game_world = load("res://scripts/world_builder.gd").new()
	root.add_child(game_world)
	game_world.build()
	assert(load("res://scripts/world_editor/map_runtime.gd").apply(game_world, serialized, false).is_empty())
	assert(game_world.water_depth_at(point.x, point.y) > 0.8)
	assert(absf(game_world.surface_height_at(point.x + 8.0, point.y) - water_level) < 0.35)
	game_world.free()
	editor._undo()
	assert(editor.placements.is_empty() and not editor.terrain_changed)
	assert(absf(editor.world.surface_height_at(point.x, point.y) - original_height) < 0.001)
	editor.stroke_active = true
	editor.brush_radius = 2.0
	editor.brush_rng.seed = 77
	editor._scatter_assets(Vector3(point.x, original_height, point.y))
	editor._input(release)
	assert(editor.placements.size() == 1 and editor.terrain_changed)
	var brushed: Array = editor.placements[0]["position"]
	assert(editor.world.water_depth_at(float(brushed[0]), float(brushed[2])) > 0.8)
	editor._undo()
	assert(editor.placements.is_empty() and not editor.terrain_changed)

	# A finished zone and its strokes can be undone independently.
	editor.brush_radius = 10.0
	editor.tabs.current_tab = 4
	editor.zone_name.text = "New field"
	editor._begin_zone()
	editor.stroke_active = true
	editor._paint_zone(Vector3(12, 0, 20))
	editor._paint_zone(Vector3(16, 0, 20))
	editor._input(release)
	var pending_count: int = editor.zone_pending.size()
	assert(pending_count > 0)
	editor._finish_zone()
	assert(editor.zone_definitions.size() == 1)
	editor._undo()
	assert(editor.zone_editing and editor.zone_pending.size() == pending_count and editor.zone_definitions.is_empty())
	editor._undo()
	assert(editor.zone_editing and editor.zone_pending.is_empty())

	# New Project copies the applied snapshot, not later saved draft changes.
	editor._new_draft()
	editor.selected_asset = "stone_1"
	editor._place(Vector3(10, 2, 10), false)
	editor.name_edit.text = "Applied version"
	editor._apply()
	var id: String = editor.draft_id
	editor._place(Vector3(14, 2, 10), false)
	editor._save()
	assert(editor.store.load_draft(id)["payload"]["placements"].size() == 2)
	editor.project_source.select(0)
	editor._new_project_confirmed()
	assert(editor.draft_id.is_empty() and editor.placements.size() == 1)
	assert(editor.store.load_published()["payload"]["placements"].size() == 1)
	editor.project_source.select(1)
	editor._new_project_confirmed()
	assert(editor.clear_base and editor.placements.is_empty() and is_nan(editor.grid.sample_height(Vector2.ZERO)))
	assert(editor.store.load_published()["payload"]["placements"].size() == 1)

	for suffix: String in ["", ".bak", ".tmp"]:
		for file: String in [path.path_join("drafts").path_join(id + ".json"), path.path_join("active_map.json")]:
			var absolute := ProjectSettings.globalize_path(file + suffix)
			if FileAccess.file_exists(absolute): DirAccess.remove_absolute(absolute)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path.path_join("drafts")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	editor.queue_free()
	await process_frame
	print("PASS: camera zoom, existing zones, undo, lake shores and new project sources")
	quit()
