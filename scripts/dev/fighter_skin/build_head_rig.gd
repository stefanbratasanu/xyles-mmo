extends SceneTree
## Fit the animation skeleton to the generated anatomy. Never fit anatomy to bones.
const SOURCE := "res://assets/models/characters/human_fighter/head_revision/source.glb"
const OUTPUT := "res://assets/models/characters/human_fighter/head_revision/"
const PLACEMENT := Transform3D(Basis(Vector3(0.974, 0, 0), Vector3(0, 0.974, 0), Vector3(0, 0, 0.974)), Vector3(0, 0.923, 0))

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var character = load("res://assets/animations/player_runtime/character.tscn").instantiate()
	root.add_child(character)
	var skeleton: Skeleton3D = character.get_node("Skeleton3D")
	var generated = load(SOURCE).instantiate()
	root.add_child(generated)
	var generated_rig: Skeleton3D = generated.find_children("*", "Skeleton3D", true, false)[0]
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
			PLACEMENT * generated_rig.get_bone_global_rest(pair.y).origin)
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
	mesh.set_meta("outfit_coverage", original.mesh.get_surface_count() > 2)
	mesh.blend_shape_mode = original.mesh.blend_shape_mode
	for shape in range(original.mesh.get_blend_shape_count()):
		mesh.add_blend_shape(original.mesh.get_blend_shape_name(shape))
	for surface in range(original.mesh.get_surface_count()):
		var arrays := original.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for vertex in range(vertices.size()): vertices[vertex] = PLACEMENT * vertices[vertex]
		arrays[Mesh.ARRAY_VERTEX] = vertices
		# A uniform scale/translation preserves the source normals, UVs, weights
		# and shape. No weighted translations, smoothing or normal reprojection.
		var shapes := original.mesh.surface_get_blend_shape_arrays(surface)
		for shape in shapes:
			var points: PackedVector3Array = shape[Mesh.ARRAY_VERTEX]
			for v in range(points.size()):
				points[v] = points[v] * 0.974 if mesh.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_RELATIVE else PLACEMENT * points[v]
			shape[Mesh.ARRAY_VERTEX] = points
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, shapes)
		var source_material := original.mesh.surface_get_material(surface) as StandardMaterial3D
		var material := StandardMaterial3D.new()
		if source_material != null:
			material = source_material.duplicate()
		if material.albedo_texture != null:
			# Skin uses the runtime neck blend and soft-body shader.
			material.resource_name = "Human fighter skin"
			material.vertex_color_use_as_albedo = false
			material.normal_enabled = false
			material.roughness = 0.82
			material.metallic_specular = 0.25
		else:
			# Cloth, hair and metal keep their authored glTF colours. Their
			# open hems are one-sided shells, so render both faces.
			material.vertex_color_use_as_albedo = false
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.surface_set_material(surface, material)
	var skin := Skin.new()
	skin.bind_count = original.skin.bind_count
	for bind in range(skin.bind_count):
		var generated_index := original.skin.get_bind_bone(bind)
		if generated_index < 0: generated_index = generated_rig.find_bone(original.skin.get_bind_name(bind))
		var index: int = bone_map[generated_index]
		skin.set_bind_name(bind, skeleton.get_bone_name(index))
		skin.set_bind_bone(bind, index)
		skin.set_bind_pose(bind, fitted_globals[index].affine_inverse())
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var error := ResourceSaver.save(mesh, OUTPUT + "body.res", ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("Failed to save fighter mesh: " + str(error))
		quit(1)
		return
	var body := MeshInstance3D.new()
	body.name = "HumanFighter"
	body.mesh = load(OUTPUT + "body.res")
	body.skin = skin
	body.skeleton = NodePath("..")
	skeleton.add_child(body)
	body.owner = character
	character.set_script(load("res://scripts/fighter_body_shapes.gd"))
	var packed := PackedScene.new()
	error = packed.pack(character)
	if error == OK: error = ResourceSaver.save(packed, OUTPUT + "character.tscn")
	var total := 0
	for surface in range(mesh.get_surface_count()):
		total += (mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	print("ANATOMY RIG: ", error, "; bones=", skeleton.get_bone_count(), "; surfaces=", mesh.get_surface_count(), "; vertices=", total)
	character.queue_free()
	generated.queue_free()
	mapping.queue_free()
	await process_frame
	quit(0 if error == OK else 1)
