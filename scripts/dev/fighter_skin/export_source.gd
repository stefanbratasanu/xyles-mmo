extends SceneTree
## Fit generated limbs to the animation-pack rest pose without warping the torso.
const INPUT := "res://assets/models/characters/human_fighter/user_tweaked_df18cad1/rigged_pbr.glb"
const OUTPUT := "res://logs/fighter_skin_build/fitted.glb"
const PRESERVE_SHAPE := ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head"]

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://logs/fighter_skin_build")
	FileAccess.open("res://logs/fighter_skin_build/.gdignore", FileAccess.WRITE).close()
	var character = load("res://assets/animations/player_runtime/character.tscn").instantiate()
	root.add_child(character)
	var source: Skeleton3D = character.get_node("Skeleton3D")
	var fighter = load(INPUT).instantiate()
	character.add_child(fighter)
	var target: Skeleton3D = fighter.find_children("*", "Skeleton3D", true, false)[0]
	# Use the earlier bridge's rest mapping only; no animation is played here.
	var mapping = load("res://scripts/fighter_retarget.gd").new()
	character.add_child(mapping)
	mapping.setup(source, target)
	var bones := {}
	var alignments := {}
	for i in range(mapping.bone_pairs.size()):
		var pair: Vector2i = mapping.bone_pairs[i]
		bones[pair.y] = pair.x
		alignments[pair.y] = mapping.rest_alignments[i]
	var body: MeshInstance3D = fighter.find_children("*", "MeshInstance3D", true, false)[0]
	var old_skin := body.skin
	var skin := Skin.new()
	skin.bind_count = old_skin.bind_count
	var placement := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.974), Vector3(0, 0.923, 0))
	var mesh := ArrayMesh.new()
	for surface in range(body.mesh.get_surface_count()):
		var arrays := body.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var stride: int = indices.size() / vertices.size()
		for vertex in range(vertices.size()):
			var point := placement * vertices[vertex]
			var fitted := Vector3.ZERO
			var normal := Vector3.ZERO
			var total := 0.0
			for influence in range(stride):
				var offset := vertex * stride + influence
				var weight := weights[offset]
				if weight < 0.00001: continue
				var target_index := resolve_bind(old_skin, indices[offset], target)
				if not bones.has(target_index):
					push_error("Unmapped generated bind: " + str(target_index))
					quit(1)
					return
				var source_index: int = bones[target_index]
				var alignment: Basis = alignments[target_index]
				var pivot := placement * target.get_bone_global_rest(target_index).origin
				if String(target.get_bone_name(target_index)) in PRESERVE_SHAPE:
					fitted += point * weight
					normal += normals[vertex] * weight
				else:
					fitted += (source.get_bone_global_rest(source_index).origin + alignment * (point - pivot)) * weight
					normal += alignment * normals[vertex] * weight
				total += weight
			if total > 0.001: vertices[vertex] = fitted / total
			if normal.length_squared() > 0.0001: normals[vertex] = normal.normalized()
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(surface, body.mesh.surface_get_material(surface))
	body.mesh = mesh
	for i in range(old_skin.bind_count):
		var source_index: int = bones[resolve_bind(old_skin, i, target)]
		skin.set_bind_bone(i, source_index)
		skin.set_bind_name(i, source.get_bone_name(source_index))
		skin.set_bind_pose(i, source.get_bone_global_rest(source_index).affine_inverse())
	body.owner = null
	body.reparent(source)
	body.transform = Transform3D.IDENTITY
	body.skeleton = NodePath("..")
	body.skin = skin
	body.name = "FighterBody"
	character.remove_child(fighter)
	fighter.free()
	character.remove_child(mapping)
	mapping.free()
	for animation_player in character.find_children("*", "AnimationPlayer", true, false):
		animation_player.get_parent().remove_child(animation_player)
		animation_player.free()
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_scene(character, state)
	if error == OK: error = document.write_to_filesystem(state, OUTPUT)
	print("FITTED EXPORT: ", error)
	character.queue_free()
	await process_frame
	quit(0 if error == OK else 1)

func resolve_bind(skin: Skin, bind: int, skeleton: Skeleton3D) -> int:
	var index := skin.get_bind_bone(bind)
	return index if index >= 0 else skeleton.find_bone(skin.get_bind_name(bind))
