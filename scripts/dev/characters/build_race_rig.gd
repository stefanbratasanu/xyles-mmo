extends SceneTree
## Fit the animation skeleton to the generated anatomy. Never fit anatomy to bones.
var source_path := ""
var output_path := ""
var model: Dictionary
var placement := Transform3D.IDENTITY

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Pass a model ID after --, optionally --source PATH --output DIR")
		quit(1); return
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://resources/characters/race_models.json"))
	for candidate in manifest.models:
		if candidate.id == args[0]: model = candidate
	if model.is_empty():
		push_error("Unknown race model ID"); quit(1); return
	output_path = "res://assets/models/characters/races/" + str(model.id) + "/"
	source_path = output_path + "rigged.glb"
	var argument := 1
	while argument < args.size():
		if argument + 1 >= args.size():
			push_error("Missing argument value"); quit(1); return
		match args[argument]:
			"--source": source_path = args[argument + 1]
			"--output": output_path = args[argument + 1].trim_suffix("/") + "/"
			_:
				push_error("Unknown build option"); quit(1); return
		argument += 2
	if not ResourceLoader.exists(source_path):
		push_error("Rigged source missing: " + source_path); quit(1); return
	var character = load("res://assets/animations/player_runtime/character.tscn").instantiate()
	root.add_child(character)
	var skeleton: Skeleton3D = character.get_node("Skeleton3D")
	var generated = load(source_path).instantiate()
	root.add_child(generated)
	var generated_rig: Skeleton3D = generated.find_children("*", "Skeleton3D", true, false)[0]
	var meshes: Array[Node] = generated.find_children("*", "MeshInstance3D", true, false)
	if meshes.size() != 1:
		push_error("Expected one skinned mesh; combine source parts without changing the skin first")
		quit(1); return
	var source_body: MeshInstance3D = meshes[0]
	var bounds := source_body.mesh.get_aabb()
	var scale_factor := float(model.height_m) / bounds.size.y
	placement = Transform3D(Basis.from_scale(Vector3.ONE * scale_factor), Vector3(0, -bounds.position.y * scale_factor, 0))

	var mapping = load("res://scripts/fighter_retarget.gd").new()
	root.add_child(mapping)
	mapping.setup(skeleton, generated_rig)
	var source_rests: Array[Transform3D] = []
	var fitted_globals: Array[Transform3D] = []
	var bone_map := {}
	for index in range(skeleton.get_bone_count()):
		source_rests.append(skeleton.get_bone_rest(index))
		fitted_globals.append(skeleton.get_bone_global_rest(index))
	for index in range(mapping.bone_pairs.size()):
		var pair: Vector2i = mapping.bone_pairs[index]
		bone_map[pair.y] = pair.x
		# Bind axes account for the different arm/leg A poses. The animation
		# rotations remain in their authored axes; translations get adapted.
		fitted_globals[pair.x] = Transform3D(
			mapping.rest_alignments[index].inverse() * skeleton.get_bone_global_rest(pair.x).basis,
			placement * generated_rig.get_bone_global_rest(pair.y).origin)
	for index in range(skeleton.get_bone_count()):
		var parent := skeleton.get_bone_parent(index)
		var rest := fitted_globals[index] if parent < 0 else fitted_globals[parent].affine_inverse() * fitted_globals[index]
		skeleton.set_bone_rest(index, rest)
		skeleton.set_bone_pose_position(index, rest.origin)
		skeleton.set_bone_pose_rotation(index, rest.basis.get_rotation_quaternion())
		skeleton.set_bone_pose_scale(index, Vector3.ONE)
	character.set_meta("animation_source_rests", source_rests)
	for old_body in skeleton.find_children("*", "MeshInstance3D", true, false):
		old_body.get_parent().remove_child(old_body)
		old_body.free()
	var original: MeshInstance3D = generated.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh := ArrayMesh.new()
	mesh.set_meta("race_model_id", model.id)
	mesh.blend_shape_mode = original.mesh.blend_shape_mode
	for shape in range(original.mesh.get_blend_shape_count()):
		mesh.add_blend_shape(original.mesh.get_blend_shape_name(shape))
	for surface in range(original.mesh.get_surface_count()):
		var arrays := original.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in range(vertices.size()): vertices[vertex] = placement * vertices[vertex]
		arrays[Mesh.ARRAY_VERTEX] = vertices
		# A uniform scale/translation preserves the source normals, UVs, weights
		# and shape. No weighted translations, smoothing or normal reprojection.
		var shapes := original.mesh.surface_get_blend_shape_arrays(surface)
		for shape in shapes:
			var points: PackedVector3Array = shape[Mesh.ARRAY_VERTEX]
			for v in range(points.size()):
				points[v] = placement.basis * points[v] if mesh.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_RELATIVE else placement * points[v]
			shape[Mesh.ARRAY_VERTEX] = points
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, shapes)
		var source_material := original.mesh.surface_get_material(surface) as StandardMaterial3D
		var material := StandardMaterial3D.new()
		if source_material != null:
			material = source_material.duplicate()
		material.vertex_color_use_as_albedo = false
		material.normal_enabled = float(model.get("normal_strength", 0.0)) > 0.0
		material.normal_scale = float(model.get("normal_strength", 0.0))
		material.metallic_specular = .25
		# Preserve the provider PBR albedo/roughness/normal maps. Review under
		# neutral light; do not tint all races with the old human skin shader.
		mesh.surface_set_material(surface, material)
	var skin := Skin.new()
	skin.bind_count = original.skin.bind_count
	for bind in range(skin.bind_count):
		var generated_index := original.skin.get_bind_bone(bind)
		if generated_index < 0: generated_index = generated_rig.find_bone(original.skin.get_bind_name(bind))
		if not bone_map.has(generated_index):
			push_error("Source skin has an unmapped bone; review the provider skeleton before using it")
			quit(1); return
		var index: int = bone_map[generated_index]
		skin.set_bind_name(bind, skeleton.get_bone_name(index))
		skin.set_bind_bone(bind, index)
		skin.set_bind_pose(bind, fitted_globals[index].affine_inverse())
	DirAccess.make_dir_recursive_absolute(output_path)
	var error := ResourceSaver.save(mesh, output_path + "body.res", ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("Failed to save fighter mesh: " + str(error))
		quit(1)
		return
	var body := MeshInstance3D.new()
	body.name = "HumanFighter"
	body.mesh = load(output_path + "body.res")
	body.skin = skin
	body.skeleton = NodePath("..")
	skeleton.add_child(body)
	body.owner = character
	character.set_script(load("res://scripts/race_character.gd"))
	character.race_model_id = str(model.id)
	var packed := PackedScene.new()
	error = packed.pack(character)
	if error == OK: error = ResourceSaver.save(packed, output_path + "character.tscn")
	var total := 0
	for surface in range(mesh.get_surface_count()):
		total += (mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	print("RACE RIG ", model.id, ": ", error, "; bones=", skeleton.get_bone_count(), "; surfaces=", mesh.get_surface_count(), "; vertices=", total)
	character.queue_free()
	generated.queue_free()
	mapping.queue_free()
	await process_frame
	quit(0 if error == OK else 1)
