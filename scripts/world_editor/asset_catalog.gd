extends RefCounted
## IDs are saved in drafts; keep them stable across editor/game versions.

const ASSETS := {
	"oak": {"name": "Oak", "group": "Environment", "mesh": "mesh_Trees_oak.res", "tree": true},
	"birch": {"name": "Birch", "group": "Environment", "mesh": "mesh_Trees_birch.res", "tree": true},
	"pine": {"name": "Pine / conifer", "group": "Environment", "mesh": "mesh_Trees_pine.res", "tree": true},
	"dead_tree": {"name": "Dead tree", "group": "Environment", "mesh": "mesh_Trees_dead.res", "tree": true},
	"bush": {"name": "Bush", "group": "Environment", "mesh": "mesh_Underbrush.res"},
	"grass": {"name": "Grass patch", "group": "Environment", "mesh": "mesh_MeadowGrass.res"},
	"flowers": {"name": "Wildflowers", "group": "Environment", "mesh": "mesh_Wildflowers.res"},
	"fallen_log": {"name": "Fallen log", "group": "Environment", "factory": "fallen_log"},
	"lake": {"name": "Water surface", "group": "Environment", "factory": "lake"},
	"rock_1": {"name": "Boulder 1", "group": "Environment", "prop": "rock_1.glb"},
	"rock_2": {"name": "Boulder 2", "group": "Environment", "prop": "rock_2.glb"},
	"rock_3": {"name": "Boulder 3", "group": "Environment", "prop": "rock_3.glb"},
	"stone_1": {"name": "Stone 1", "group": "Environment", "prop": "stone_1.glb"},
	"stone_2": {"name": "Stone 2", "group": "Environment", "prop": "stone_2.glb"},
	"tent": {"name": "Camp tent", "group": "Buildings", "factory": "tent"},
	"bed": {"name": "Camp bed", "group": "Buildings", "factory": "bed"},
	"campfire": {"name": "Campfire", "group": "Buildings", "factory": "campfire"},
	"torch": {"name": "Torch stand", "group": "Buildings", "factory": "torch"},
	"seat": {"name": "Sitting log", "group": "Buildings", "factory": "seat"},
	"fence": {"name": "Fence segment", "group": "Buildings", "factory": "fence"},
	"wood_gate": {"name": "Wooden gate frame", "group": "Buildings", "factory": "wood_gate"},
	"firewood": {"name": "Firewood", "group": "Buildings", "factory": "firewood"},
	"barrel": {"name": "Barrel", "group": "Buildings", "factory": "barrel"},
	"crate": {"name": "Crate", "group": "Buildings", "factory": "crate"},
	"banner": {"name": "Banner", "group": "Buildings", "factory": "banner"},
	"brazier": {"name": "Brazier", "group": "Buildings", "factory": "brazier"},
	"pillar": {"name": "Stone pillar", "group": "Buildings", "factory": "pillar"},
	"arch": {"name": "Stone arch", "group": "Buildings", "factory": "arch"},
	"anvil": {"name": "Anvil", "group": "Buildings", "factory": "anvil"},
	"forge": {"name": "Forge", "group": "Buildings", "factory": "forge"},
}

static func list_group(group: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id: String in ASSETS:
		if ASSETS[id]["group"] == group:
			result.append({"id": id, "name": ASSETS[id]["name"]})
	return result

static func create(world: Node3D, id: String) -> Node3D:
	if not ASSETS.has(id):
		return null
	var spec: Dictionary = ASSETS[id]
	if world._materials.is_empty():
		world._create_materials()
	var root := Node3D.new()
	root.name = "Placed_" + id
	if spec.has("mesh"):
		var mesh: Mesh = load("res://assets/world/vegetation/" + str(spec["mesh"]))
		if mesh == null:
			root.free()
			return null
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		root.add_child(visual)
		if bool(spec.get("tree", false)):
			var body := StaticBody3D.new()
			body.collision_layer = 8
			body.add_to_group("tree_trunks")
			var shape := CylinderShape3D.new()
			shape.radius = 0.43
			shape.height = 3.0
			var collider := CollisionShape3D.new()
			collider.shape = shape
			collider.position.y = 1.4
			body.add_child(collider)
			root.add_child(body)
	elif spec.has("prop"):
		var mesh: Mesh = world._load_prop_mesh(str(spec["prop"]), "stone")
		if mesh == null:
			root.free()
			return null
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		root.add_child(visual)
		if id.begins_with("rock_"):
			visual.create_trimesh_collision()
	else:
		match str(spec.get("factory", "")):
			"tent": world._tent(root, Vector3.ZERO, 0.0)
			"bed": world._ground_bed(root, Vector3.ZERO, 0.0)
			"campfire": world._campfire(root, Vector3.ZERO)
			"torch": world._road_lamp(root, Vector3.ZERO, 0.0)
			"seat": world._sitting_log(root, Vector3.ZERO, 0.0)
			"barrel": world._barrel(root, Vector3.ZERO)
			"crate": world._crate(root, Vector3.ZERO)
			"banner": world._banner(root, Vector3.ZERO, 0.0)
			"brazier": world._brazier(root, Vector3.ZERO)
			"pillar": world._pillar(root, Vector3.ZERO, 0.52, 4.0)
			"arch": world._arch(root, Vector3.ZERO, 0.0, 5.2, 3.1)
			"anvil": _anvil(world, root)
			"forge": _forge(world, root)
			"lake": _lake(world, root)
			"fence": _fence(world, root)
			"wood_gate": _gate(world, root)
			"firewood": world._camp_model(root, "camp_firewood.glb", "Firewood", Vector3.ZERO)
			"fallen_log": _fallen_log(world, root)
			_:
				root.free()
				return null
	return root

static func _lake(world: Node3D, root: Node3D) -> void:
	var visual := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 8.0
	disc.bottom_radius = 8.0
	disc.height = 0.02
	disc.radial_segments = 64
	visual.mesh = disc
	visual.material_override = world._materials["water"]
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(visual)

static func _fallen_log(world: Node3D, root: Node3D) -> void:
	var log: MeshInstance3D = world._add_mesh(root, "FallenLog", world._cylinder_mesh(0.30, 3.5, 8), "bark")
	log.rotation.x = PI * 0.5
	log.position.y = 0.3
	log.create_trimesh_collision()

static func _gate(world: Node3D, root: Node3D) -> void:
	for x: float in [-2.2, 2.2]:
		var post: MeshInstance3D = world._add_mesh(root, "GatePost", world._cylinder_mesh(0.15, 2.4, 8), "camp_timber")
		post.position = Vector3(x, 1.2, 0.0)
		var body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(0.3, 2.4, 0.3)
		collision.shape = shape
		collision.position = Vector3(x, 1.2, 0.0)
		body.add_child(collision)
		root.add_child(body)
	world._strut(root, Vector3(-2.2, 2.4, 0), Vector3(2.2, 2.4, 0), 0.075, "camp_timber", "GateBeam")

static func _anvil(world: Node3D, root: Node3D) -> void:
	var stump: MeshInstance3D = world._add_mesh(root, "Stump", world._cylinder_mesh(0.42, 0.62, 8), "wood")
	stump.position.y = 0.31
	var top: MeshInstance3D = world._add_mesh(root, "Anvil", world._box_mesh(Vector3(0.34, 0.34, 0.62)), "iron")
	top.position.y = 0.79
	var horn: MeshInstance3D = world._add_mesh(root, "Horn", world._cone_mesh(0.16, 0.5, 5), "iron")
	horn.position = Vector3(-0.38, 0.8, 0.0)
	horn.rotation.z = PI * 0.5

static func _forge(world: Node3D, root: Node3D) -> void:
	world._wall(root, Vector3.ZERO, Vector3(1.9, 1.0, 1.3), 0.0, "stone_dark")
	var coal: MeshInstance3D = world._add_mesh(root, "Coals", world._box_mesh(Vector3(1.3, 0.1, 0.8)), "fire")
	coal.position.y = 1.02
	world._light(root, Vector3(0.0, 1.8, 0.0), Color("ff9a4d"), 1.35, 8.0)

static func _fence(world: Node3D, root: Node3D) -> void:
	for x: float in [-1.1, 1.1]:
		var post: MeshInstance3D = world._add_mesh(root, "Post", world._cylinder_mesh(0.10, 1.45, 8), "camp_timber")
		post.position = Vector3(x, 0.725, 0.0)
	for y: float in [0.52, 1.02]:
		world._strut(root, Vector3(-1.1, y, 0.0), Vector3(1.1, y, 0.0), 0.07, "camp_timber", "Rail")
	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 1.16, 0.16)
	collision.shape = shape
	collision.position.y = 0.58
	body.add_child(collision)
	root.add_child(body)
