extends SceneTree
## Refresh only the shared tree meshes after editing their GLBs. Placement and
## the rest of the authored world are deliberately left untouched.

func _initialize() -> void:
	var world: Node = load("res://scripts/world_builder.gd").new()
	world._create_materials()
	for kind in ["oak", "birch", "pine", "dead"]:
		var mesh: Mesh = world._load_tree_mesh(kind)
		if mesh == null:
			push_error("Could not load tree mesh: " + kind)
			world.free()
			quit(1)
			return
		var paths := ["res://assets/world/vegetation/mesh_Trees_%s.res" % kind]
		if kind == "pine":
			paths.append("res://assets/world/vegetation/mesh_FoothillPines.res")
		for path in paths:
			if ResourceSaver.save(mesh, path, ResourceSaver.FLAG_COMPRESS) != OK:
				push_error("Could not save " + path)
				world.free()
				quit(1)
				return
	world.free()
	print("Refreshed shared tree meshes")
	quit()
