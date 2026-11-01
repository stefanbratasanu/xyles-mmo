extends SceneTree
## Test built race assets before catalog approval, on the actual player skeleton.
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var models = load("res://scripts/character_models.gd")
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(models.MANIFEST))
	var game = load("res://scenes/main.tscn").instantiate()
	game.test_mode = true
	root.add_child(game)
	for frame in range(3): await process_frame
	game.set_process(false)
	game.player.set_process(false); game.player.set_physics_process(false)
	# Inject only into this process; catalog files are untouched during review.
	models._entries = manifest.models
	var tested := 0
	for model in models._entries:
		if not OS.get_cmdline_user_args().is_empty() and model.id not in OS.get_cmdline_user_args() and model.id != "--test-mode": continue
		var path := "res://assets/models/characters/races/" + str(model.id) + "/character.tscn"
		if model.id == "human_male" and not ResourceLoader.exists(path): path = model.scene
		if not ResourceLoader.exists(path): continue
		model.scene = path; model.status = "reviewed"
		game.player.apply_character_appearance({}, model.race, model.gender)
		var body: MeshInstance3D = game.player.fighter_visual
		var rig: Skeleton3D = body.get_node(body.skeleton)
		check(rig.get_bone_count() == 55, str(model.id) + ": animation skeleton retained")
		check(game.player.weapon_attachment.get_parent() == rig, str(model.id) + ": weapon follows active skeleton")
		var samples: Array[Dictionary] = []
		for surface in range(body.mesh.get_surface_count()):
			var arrays := body.mesh.surface_get_arrays(surface)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var stride: int = weights.size() / points.size()
			for vertex in range(0, points.size(), 61):
				samples.append({"point": points[vertex], "weights": weights.slice(vertex * stride, (vertex + 1) * stride), "bones": bones.slice(vertex * stride, (vertex + 1) * stride)})
		var error := 0.0
		for clip in ["REST", "travel/idle", "travel/walk_forward", "travel/run", "travel/carry_idle", "travel/carry_run", "travel/carry_sprint_forward_left", "travel/carry_sprint_forward_right", "travel/sword_ready", "protof/sword_attack", "seat/idle"]:
			game.player.animation_player.stop()
			rig.reset_bone_poses()
			if clip != "REST":
				check(game.player.animation_player.has_animation(clip), str(model.id) + ": clip exists " + clip)
				game.player.animation_player.play(clip)
				game.player.animation_player.seek(.28, true)
			rig.force_update_all_bone_transforms()
			var binds: Array[Transform3D] = []
			for bind in range(body.skin.bind_count):
				binds.append(rig.get_bone_global_pose(body.skin.get_bind_bone(bind)) * body.skin.get_bind_pose(bind))
			var invalid := 0
			for sample in samples:
				var position := Vector3.ZERO
				for influence in range(sample.weights.size()): position += (binds[sample.bones[influence]] * sample.point) * sample.weights[influence]
				if clip == "REST": error = maxf(error, position.distance_to(sample.point))
				if not position.is_finite() or position.length() > 4: invalid += 1
			check(invalid == 0, str(model.id) + ": finite skin in " + clip)
		check(error < .00025, str(model.id) + ": rest binding preserves anatomy")
		print("RACE MOTION ", model.id, ": samples=", samples.size(), "; max rest error=", error)
		tested += 1
	game.queue_free()
	await process_frame
	print("RACE MOTION: ", failures, " failures; ", tested, " models, 11 rest/pose checks each")
	quit(failures)
