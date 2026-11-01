extends SceneTree
## Bake a mesh/skin resource that shares the player's original animation skeleton.
const OUTPUT := "res://assets/models/characters/human_fighter/native_skin/"
const TEXTURES := "res://assets/models/characters/human_fighter/user_tweaked_df18cad1/"

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	var error := document.append_from_file("res://logs/fighter_skin_build/native.glb", state)
	if error != OK:
		push_error("Cannot load transferred fighter: " + str(error))
		quit(1)
		return
	var native := document.generate_scene(state)
	root.add_child(native)
	var original = load("res://assets/animations/player_runtime/character.tscn").instantiate()
	root.add_child(original)
	var source: Skeleton3D = original.get_node("Skeleton3D")
	var target: Skeleton3D = native.find_children("*", "Skeleton3D", true, false)[0]
	var mesh: MeshInstance3D = native.find_children("*", "MeshInstance3D", true, false)[0]
	var skin := Skin.new()
	skin.bind_count = mesh.skin.bind_count
	for i in range(skin.bind_count):
		var index := mesh.skin.get_bind_bone(i)
		if index < 0:
			index = target.find_bone(mesh.skin.get_bind_name(i))
		var bone_name := target.get_bone_name(index)
		var original_index := source.find_bone(bone_name)
		if original_index < 0:
			push_error("Unmapped skin bind: " + bone_name)
			quit(1)
			return
		skin.set_bind_bone(i, original_index)
		skin.set_bind_name(i, bone_name)
		skin.set_bind_pose(i, source.get_bone_global_rest(original_index).affine_inverse())
	var material := StandardMaterial3D.new()
	material.resource_name = "Fighter skin and shorts"
	material.albedo_texture = load(TEXTURES + "texture_diffuse.png")
	material.roughness = 0.82
	material.roughness_texture = load(TEXTURES + "texture_roughness.png")
	material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	material.metallic_specular = 0.25
	mesh.mesh = mesh.mesh.duplicate()
	for surface in range(mesh.mesh.get_surface_count()):
		mesh.mesh.surface_set_material(surface, material)
	error = ResourceSaver.save(mesh.mesh, OUTPUT + "fighter_body.res", ResourceSaver.FLAG_COMPRESS)
	if error != OK:
		push_error("Cannot save fighter mesh: " + str(error))
		quit(1)
		return
	var fighter := Node3D.new()
	fighter.name = "HumanFighter"
	var body := MeshInstance3D.new()
	body.name = "Body"
	body.mesh = load(OUTPUT + "fighter_body.res")
	body.skin = skin
	body.skeleton = NodePath("../..")
	fighter.add_child(body)
	body.owner = fighter
	var packed := PackedScene.new()
	error = packed.pack(fighter)
	if error == OK:
		error = ResourceSaver.save(packed, OUTPUT + "fighter.tscn")
	if error != OK:
		push_error("Cannot save fighter scene: " + str(error))
		quit(1)
		return
	print("BAKED fighter: ", body.mesh.get_aabb(), "; binds=", skin.bind_count,
		"; vertices=", body.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX].size())
	fighter.free()
	native.queue_free()
	original.queue_free()
	await process_frame
	quit()
