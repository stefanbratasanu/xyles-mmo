extends SceneTree
## Check every selectable physique on the actual playable skeleton.
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for frame in range(5): await process_frame
	game.set_process(false)
	var player = game.player
	player.set_process(false)
	player.set_physics_process(false)
	player.apply_character_appearance({"body_size": 2, "muscularity": 3})
	var character = player.visual.get_node("Character")
	var body: MeshInstance3D = player.fighter_visual
	var skeleton: Skeleton3D = body.get_node(body.skeleton)
	var samples: Array[Dictionary] = []
	for surface in range(body.mesh.get_surface_count()):
		var arrays := body.mesh.surface_get_arrays(surface)
		var shapes := body.mesh.surface_get_blend_shape_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var stride: int = weights.size() / vertices.size()
		for vertex in range(0, vertices.size(), 97):
			var targets := PackedVector3Array()
			for shape in shapes: targets.append(shape[Mesh.ARRAY_VERTEX][vertex])
			samples.append({"base": vertices[vertex], "targets": targets,
				"weights": weights.slice(vertex * stride, (vertex + 1) * stride),
				"bones": bones.slice(vertex * stride, (vertex + 1) * stride)})
	var checked := 0
	var max_rest_error := 0.0
	var clips := ["protof/unarmed_idle", "protof/sword_walk_forward", "protof/sword_run", "protof/sword_attack", "seat/idle"]
	for size in range(5):
		for muscle in range(5):
			character.body_size = size
			character.muscularity = muscle
			var shape_index := body.find_blend_shape_by_name("Physique_%d_%d" % [size, muscle])
			player.animation_player.stop()
			skeleton.reset_bone_poses()
			skeleton.force_update_all_bone_transforms()
			for clip in ["REST"] + clips:
				if clip != "REST":
					check(player.animation_player.has_animation(clip), "Motion clip is available: " + clip)
					player.animation_player.play(clip)
					player.animation_player.seek(0.28, true)
					skeleton.force_update_all_bone_transforms()
				var transforms: Array[Transform3D] = []
				for bind in range(body.skin.bind_count):
					transforms.append(skeleton.get_bone_global_pose(body.skin.get_bind_bone(bind)) * body.skin.get_bind_pose(bind))
				var invalid := 0
				for sample in samples:
					var point: Vector3 = sample.base if shape_index < 0 else sample.targets[shape_index]
					if shape_index >= 0 and body.mesh.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_RELATIVE: point += sample.base
					var skinned := Vector3.ZERO
					for influence in range(sample.weights.size()):
						skinned += (transforms[sample.bones[influence]] * point) * sample.weights[influence]
					if clip == "REST": max_rest_error = maxf(max_rest_error, point.distance_to(skinned))
					if not skinned.is_finite() or absf(skinned.x) > 2.5 or absf(skinned.z) > 2.5 or skinned.y < -1.0 or skinned.y > 2.5: invalid += 1
				check(invalid == 0, "Physique %d/%d stays bounded in %s" % [size, muscle, clip])
				checked += 1
	check(max_rest_error < 0.0002, "Every physique preserves its rest shape when bound to the player's rig")
	game.queue_free()
	await process_frame
	print("PHYSIQUE MOTION: ", failures, " failures; ", checked, " preset/pose checks; rest error=", max_rest_error)
	quit(failures)
