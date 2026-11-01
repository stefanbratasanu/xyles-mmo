extends SceneTree
## Regression coverage for source anatomy and the adapted animation-pack rig.
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func skin_point(point: Vector3, vertex: int, bones: PackedInt32Array, weights: PackedFloat32Array, stride: int, transforms: Array[Transform3D]) -> Vector3:
	var result := Vector3.ZERO
	for j in range(stride):
		var offset := vertex * stride + j
		if weights[offset] > 0.0:
			result += (transforms[bones[offset]] * point) * weights[offset]
	return result
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(5): await process_frame
	var player = game.player
	player.set_process(false)
	player.set_physics_process(false)
	var character = player.visual.get_node("Character")
	var skeleton: Skeleton3D = character.get_node("Skeleton3D")
	var fighter: Node3D = player.fighter_visual
	check(is_instance_valid(fighter), "Fighter is default visual")
	if not is_instance_valid(fighter): quit(1); return
	var body: MeshInstance3D = fighter as MeshInstance3D
	check(body.get_node(body.skeleton) == skeleton, "Fighter uses original animation skeleton")
	check(character.find_children("*", "Skeleton3D", true, false).size() == 1, "Only one rig drives the player")
	check(skeleton.get_node_or_null("SK_Protof-Actor") == null, "Original body is not rendered")
	check(player.weapon_attachment.get_parent() == skeleton and player.weapon_attachment.bone_name == "humanoid_ R Hand", "Weapon uses the original animated hand")
	var skin: Skin = body.skin
	for i in range(skin.bind_count):
		check(skeleton.find_bone(skin.get_bind_name(i)) == skin.get_bind_bone(i), "Skin bind name matches original index")
	# Compare the current default to its own source, including uniform placement.
	var rebuilt := str(player.CHARACTER_SCENE.resource_path).contains("/races/human_male/")
	var source_path := "res://assets/models/characters/races/human_male/rigged.glb" if rebuilt else "res://assets/models/characters/human_fighter/head_revision/source.glb"
	var generated = load(source_path).instantiate()
	var generated_body: MeshInstance3D = generated.find_children("*", "MeshInstance3D", true, false)[0]
	var placement_scale := 1.8 / generated_body.mesh.get_aabb().size.y if rebuilt else .974
	var placement_offset := Vector3(0, -generated_body.mesh.get_aabb().position.y * placement_scale, 0) if rebuilt else Vector3(0, .923, 0)
	var reference := generated_body.mesh.surface_get_arrays(0)
	var arr := body.mesh.surface_get_arrays(0)
	var source_vertices: PackedVector3Array = reference[Mesh.ARRAY_VERTEX]
	var source_normals: PackedVector3Array = reference[Mesh.ARRAY_NORMAL]
	var source_uvs: PackedVector2Array = reference[Mesh.ARRAY_TEX_UV]
	var final_vertices: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var final_normals: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var final_uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var shape_error := 0.0
	var normal_error := 0.0
	var uv_error := 0.0
	check(source_vertices.size() == final_vertices.size(), "Source topology retained")
	for v in range(mini(source_vertices.size(), final_vertices.size())):
		var expected := source_vertices[v] * placement_scale + placement_offset
		shape_error = maxf(shape_error, expected.distance_to(final_vertices[v]))
		normal_error = maxf(normal_error, source_normals[v].distance_to(final_normals[v]))
		uv_error = maxf(uv_error, source_uvs[v].distance_to(final_uvs[v]))
	check(shape_error < 0.000001, "Rigging must not stretch the chest, waist, head or limbs")
	print("MAX NORMAL ERROR ", normal_error)
	check(normal_error < 0.001, "Uniform placement preserves the source shading normals")
	check(uv_error < 0.000001, "Original texture coordinates retained")
	generated.free()
	var vertices: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
	var weights: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
	var stride: int = bones.size() / vertices.size()
	check(vertices.size() >= 20000 and vertices.size() <= 200000, "Fighter meets requested vertex range")
	var material := body.mesh.surface_get_material(0) as BaseMaterial3D
	check(material != null and material.albedo_texture != null and material.albedo_texture.get_width() >= 2048, "Source skin texture retains at least 2K detail")
	var seam_weights := {}
	var bad_weights := 0
	var cracked_seams := 0
	for v in range(vertices.size()):
		var total := 0.0
		var influences := {}
		for j in range(stride):
			var k := v * stride + j
			total += weights[k]
			if weights[k] > 0.00001: influences[bones[k]] = weights[k]
		if absf(total - 1.0) > 0.001: bad_weights += 1
		if seam_weights.has(vertices[v]):
			var previous: Dictionary = seam_weights[vertices[v]]
			for bone in influences:
				if absf(float(previous.get(bone, 0.0)) - float(influences[bone])) > 0.001:
					cracked_seams += 1
		else: seam_weights[vertices[v]] = influences
	check(bad_weights == 0, "Every vertex has normalized skin weights")
	check(cracked_seams == 0, "UV seam duplicates share weights and cannot split during motion")
	player.animation_player.stop()
	skeleton.reset_bone_poses()
	skeleton.force_update_all_bone_transforms()
	var transforms: Array[Transform3D] = []
	for i in range(skin.bind_count):
		transforms.append(skeleton.get_bone_global_pose(skin.get_bind_bone(i)) * skin.get_bind_pose(i))
	var rest_error := 0.0
	for v in range(0, vertices.size(), 37):
		rest_error = maxf(rest_error, skin_point(vertices[v], v, bones, weights, stride, transforms).distance_to(vertices[v]))
	check(rest_error < 0.0002, "Binding preserves the fitted rest geometry")
	var clips := ["protof/unarmed_idle", "protof/unarmed_run", "protof/sword_idle", "protof/sword_run", "seat/idle"]
	clips.append("protof/sword_attack")
	for clip in clips:
		check(player.animation_player.has_animation(clip), "Required animation exists: " + clip)
		for time in [0.0, 0.18, 0.36, 0.55]:
			player.animation_player.play(clip)
			player.animation_player.seek(time, true)
			skeleton.force_update_all_bone_transforms()
			for i in range(skin.bind_count): transforms[i] = skeleton.get_bone_global_pose(skin.get_bind_bone(i)) * skin.get_bind_pose(i)
			var bad_vertices := 0
			for v in range(0, vertices.size(), 37):
				var point := skin_point(vertices[v], v, bones, weights, stride, transforms)
				if not point.is_finite() or absf(point.x) > 2.5 or absf(point.z) > 2.5 or point.y < (-1.0 if clip == "seat/idle" else -0.3) or point.y > 2.5: bad_vertices += 1
			check(bad_vertices == 0, "Skin remains bounded in " + clip + " at " + str(time))
	player.update_equipment([{"slot":"weapon", "weapon_type":"sword", "power":10, "durability":100, "modifiers":[]}])
	await process_frame
	check(is_instance_valid(player.weapon_visual), "Sword visual is created")
	if is_instance_valid(player.weapon_visual):
		var hand := skeleton.get_bone_global_pose(skeleton.find_bone("humanoid_ R Hand")).origin
		check(player.weapon_visual.global_position.distance_to(skeleton.to_global(hand)) < 0.2, "Sword remains attached to the animated hand")
	game.queue_free()
	await process_frame
	print("FIGHTER ANATOMY: ", failures, " failures; vertices=", vertices.size(), "; rest_error=", rest_error, "; source_shape_error=", shape_error)
	quit(failures)


