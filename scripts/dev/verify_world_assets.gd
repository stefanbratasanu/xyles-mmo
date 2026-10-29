extends SceneTree
## Read-only launcher check of the authored map after an import or pull.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var data = load("res://assets/world/baked_world.res")
	if data == null:
		push_error("Missing authored world data")
		quit(1)
		return
	var counts := {"static": 0, "terrain": 0, "vegetation": 0}
	var checked_meshes := {}
	var camp_count := 0
	var missing: Array[String] = []
	for label in counts.keys():
		var paths: Dictionary = data.static_paths if label == "static" else (data.terrain_tiles if label == "terrain" else data.vegetation_paths)
		for cell in paths:
			var path: String = paths[cell]
			if not ResourceLoader.exists(path):
				missing.append(path)
				continue
			var resource = load(path)
			if resource == null:
				missing.append(path)
				continue
			counts[label] += 1
			if label == "static":
				var scene := resource as PackedScene
				if scene == null:
					missing.append(path)
					continue
				var instance := scene.instantiate()
				if instance.find_child("SurvivorCamp", true, false) != null:
					camp_count += 1
				instance.free()
			elif label == "terrain":
				if resource.mesh == null or resource.collision == null:
					missing.append(path)
			else:
				for group: Dictionary in resource.groups:
					var mesh_path := str(group.get("mesh_path", ""))
					if not checked_meshes.has(mesh_path):
						checked_meshes[mesh_path] = true
						if mesh_path.is_empty() or not ResourceLoader.exists(mesh_path) or load(mesh_path) == null:
							missing.append(mesh_path)
	print("WORLD ASSET CHECK: ", counts, " shared_meshes=", checked_meshes.size(), " camp_cells=", camp_count, " missing=", missing)
	if not missing.is_empty() or camp_count != 1 or counts["static"] == 0 or counts["terrain"] == 0 or counts["vegetation"] == 0:
		quit(1)
	else:
		quit()
