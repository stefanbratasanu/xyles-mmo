extends SceneTree
const Runtime := preload("res://scripts/world_editor/map_runtime.gd")
const Zones := preload("res://scripts/world_editor/zone_data.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1600, 900)
	var editor = load("res://scenes/world_editor.tscn").instantiate()
	root.add_child(editor)
	await process_frame
	var path := "user://editor_zones_test_%d" % Time.get_ticks_usec()
	editor.store = load("res://scripts/world_editor/draft_store.gd").new(path)
	editor._set_brush_size(12.0)
	assert(editor.brush_size_input.value == 12.0 and editor.terrain_size_slider.value == 12.0)
	editor.selected_asset = "stone_1"
	editor.brush_rng.seed = 1234
	editor._scatter_assets(Vector3(10.0, 0.0, 10.0))
	assert(editor.placements.size() == 3)
	var before: float = editor.world.height_at(12.0, 20.0)
	editor.zone_name.text = "Training Grounds"
	editor.zone_kind.select(1)
	editor.zone_minimum.value = 7
	editor.zone_maximum.value = 9
	editor._begin_zone()
	editor._paint_zone(Vector3(12.0, 0.0, 20.0))
	assert(not editor.zone_pending.is_empty())
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_RIGHT
	click.pressed = true
	click.position = editor.view_container.global_position + Vector2(100.0, 100.0)
	editor._unhandled_input(click)
	assert(not editor.zone_editing and editor.zone_definitions.size() == 1)
	assert(editor.world.zone_at_xz(Vector2(12.0, 20.0))["name"] == "TRAINING GROUNDS")
	assert(editor.world.zone_at_xz(Vector2(12.0, 20.0))["level_min"] == 7)
	assert(absf(editor.world.height_at(12.0, 20.0) - before) < 0.001)
	assert(Zones.validate(editor.zone_definitions, editor.world.BOUNDS).is_empty())
	editor.name_edit.text = "Zone test"
	editor._save()
	var id: String = editor.draft_id
	var saved: Dictionary = editor.store.load_draft(id)
	assert(saved["payload"]["zones"].size() == 1)
	var target = load("res://scripts/world_builder.gd").new()
	root.add_child(target)
	target.build()
	assert(Runtime.apply(target, saved["payload"]).is_empty())
	assert(target.zone_at_xz(Vector2(12.0, 20.0))["level_max"] == 9)
	var enemy = load("res://scripts/enemy.gd").new()
	enemy.configure_zone(target.zone_at_xz(Vector2(12.0, 20.0)))
	assert(enemy.level == 8)
	enemy.free()
	var state = load("res://scripts/game_state.gd").new()
	var zone_id: String = str(saved["payload"]["zones"][0]["id"])
	state.register_kill("normal", "Briarwolf", zone_id)
	state.register_kill("normal", "Briarwolf", zone_id)
	assert(state.bestiary[zone_id + ":normal"]["kills"] == 2)
	assert(state.earned_skill_points == 2)
	state.free()
	target.free()
	for suffix: String in ["", ".bak", ".tmp"]:
		var item := ProjectSettings.globalize_path(path.path_join("drafts").path_join(id + ".json" + suffix))
		if FileAccess.file_exists(item): DirAccess.remove_absolute(item)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path.path_join("drafts")))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	editor.queue_free()
	await process_frame
	print("PASS: asset brush, zone painting, right-click finish, save and game lookup")
	quit()
