extends SceneTree
const Catalog := preload("res://scripts/world_editor/asset_catalog.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var world = load("res://scripts/world_builder.gd").new()
	root.add_child(world)
	for id: String in Catalog.ASSETS:
		var instance := Catalog.create(world, id)
		assert(instance != null, "missing editor asset: " + id)
		world.add_child(instance)
		assert(not instance.find_children("*", "MeshInstance3D", true, false).is_empty(), "asset has no model: " + id)
		if id == "seat":
			assert(not instance.find_children("*", "Node3D", true, false).filter(func(node: Node) -> bool: return node.is_in_group("camp_seats")).is_empty())
		if id == "oak" or id == "fence" or id == "tent":
			assert(not instance.find_children("*", "CollisionShape3D", true, false).is_empty(), "asset has no collision: " + id)
		instance.free()
	assert(Catalog.create(world, "invalid") == null)
	world.free()
	print("PASS: editor asset catalog creates all supported objects")
	quit()
