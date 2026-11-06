extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func mesh_at(height: float, alpha: float = 1.0) -> ArrayMesh:
	var data := []
	data.resize(Mesh.ARRAY_MAX)
	data[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(0,height,0), Vector3(4,height+2,0), Vector3(0,height+4,4)])
	data[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,2])
	data[Mesh.ARRAY_COLOR] = PackedColorArray([Color(1,1,1,alpha), Color(1,1,1,alpha), Color(1,1,1,alpha)])
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)
	return mesh
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var world := Node3D.new(); root.add_child(world)
	var road := MeshInstance3D.new(); road.name = "RoadNetwork"; road.mesh = mesh_at(1); world.add_child(road)
	var sampler = load("res://scripts/ground_overlay_sampler.gd").new()
	check(is_equal_approx(sampler.height_at(world,1,1,0), 2.5), "Interpolates visible road triangle instead of analytical ground")
	check(is_equal_approx(sampler.height_at(world,9,9,.5), .5), "Outside road retains terrain height")
	road.mesh = mesh_at(2)
	check(is_equal_approx(sampler.height_at(world,1,1,0), 3.5), "Rebuilds after editor replaces road mesh")
	road.mesh = mesh_at(3,.1)
	check(is_equal_approx(sampler.height_at(world,1,1,.5), .5), "Transparent road edge does not lift feet")
	road.visible = false
	check(is_equal_approx(sampler.height_at(world,1,1,.5), .5), "Hidden road no longer affects grounding")
	world.queue_free(); await process_frame
	print("GROUND OVERLAYS: ",failures," failures")
	quit(failures)
