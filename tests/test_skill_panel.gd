extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1600, 900)
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	game.state.earned_skill_points = 20
	game.state.skill_points = 20
	for index in range(10):
		assert(game.state.evolve_skill("melee", index % 3))
	for index in range(5):
		assert(game.state.evolve_skill("cast", index % 3))
	assert(game.state.skills["melee"]["history"] == [0,1,2,0,1,2,0,1,2,0])
	assert(not game.state.evolve_skill("melee", 0))
	assert(game.state.replace_evolution("melee", 0, 1))
	assert(game.state.skill_points == 5)
	var save_path := "res://.godot/skill-history-test.json"
	assert(game.state.save_game(save_path))
	var restored: Node = load("res://scripts/game_state.gd").new()
	assert(restored.load_game(save_path))
	assert(restored.skills["melee"]["history"] == game.state.skills["melee"]["history"])
	assert(restored.get_unlocked_active_slots() == 5)
	restored.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	game.hud.toggle_panel("skills")
	await process_frame
	await process_frame
	var rows: Array = game.hud.overlay_content.get_children()
	# Five skill rows plus the slot-capacity and reset controls.
	assert(rows.size() == 7)
	var full_row: Control = rows[1]
	assert(full_row.get_global_rect().end.x <= root.get_visible_rect().size.x - 48)
	var strip: Control = full_row.get_child(2)
	var grouping_style: StyleBoxFlat = strip.get_theme_stylebox("panel")
	assert(grouping_style.corner_radius_top_left == 0)
	assert(grouping_style.corner_radius_top_right == 0)
	assert(grouping_style.corner_radius_bottom_left == 0)
	assert(grouping_style.corner_radius_bottom_right == 0)
	var choices: HBoxContainer = strip.get_child(0).get_child(0)
	assert(choices.get_child_count() == 11)
	assert(choices.get_child(10).text == "10/10")
	var partial: HBoxContainer = rows[0].get_child(2).get_child(0).get_child(0)
	assert(partial.get_child_count() == 6)
	assert(partial.get_child(5).text == "+\n5 / 10")
	game.hud.skill_view._choose("cast", -1)
	await process_frame
	assert(game.hud.skill_view.picker.visible)
	game.hud.skill_view.picker.hide()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/skill-panel-preview.png")
	print("PASS: five slots; 5/10 and 10/10 strips fit 16:9; picker; targeted replacement; history persistence")
	game.queue_free()
	await process_frame
	quit()


