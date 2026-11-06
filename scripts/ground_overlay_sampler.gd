extends RefCounted
## Spatial index of the actual visible road/camp triangles; terrain collision
## alone sits underneath these thin surfaces.
const CELL := 8.0
var signature := ""
var cells: Dictionary = {}

func height_at(world: Node3D, x: float, z: float, fallback: float) -> float:
	var nodes: Array[MeshInstance3D] = []
	for name in ["RoadNetwork", "CampRoadClearing"]:
		var node := world.get_node_or_null(name) as MeshInstance3D
		if is_instance_valid(node) and node.visible and node.mesh != null: nodes.append(node)
	var next_signature := ""
	for node in nodes: next_signature += "%s:%s;" % [node.get_instance_id(), node.mesh.get_instance_id()]
	if next_signature != signature:
		signature = next_signature
		_rebuild(nodes)
	var point := Vector2(x, z)
	var height := fallback
	for tri: Dictionary in cells.get(Vector2i(floori(x / CELL), floori(z / CELL)), []):
		var a: Vector3 = tri.a
		var b: Vector3 = tri.b
		var c: Vector3 = tri.c
		var ab := Vector2(b.x-a.x, b.z-a.z)
		var ac := Vector2(c.x-a.x, c.z-a.z)
		var ap := point - Vector2(a.x, a.z)
		var denominator := ab.cross(ac)
		if absf(denominator) < .000001: continue
		var u := ap.cross(ac) / denominator
		var v := ab.cross(ap) / denominator
		if u < 0.0 or v < 0.0 or u + v > 1.0: continue
		var w := 1.0-u-v
		if float(tri.aa)*w + float(tri.ba)*u + float(tri.ca)*v < .35: continue
		height = maxf(height, a.y*w + b.y*u + c.y*v)
	return height

func _rebuild(nodes: Array[MeshInstance3D]) -> void:
	cells.clear()
	for node in nodes:
		for surface in range(node.mesh.get_surface_count()):
			var arrays := node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			for i in range(0, indices.size() - 2, 3):
				var ia := indices[i]; var ib := indices[i+1]; var ic := indices[i+2]
				var a := node.transform * vertices[ia]; var b := node.transform * vertices[ib]; var c := node.transform * vertices[ic]
				var tri := {"a":a, "b":b, "c":c, "aa": colors[ia].a if not colors.is_empty() else 1.0, "ba": colors[ib].a if not colors.is_empty() else 1.0, "ca": colors[ic].a if not colors.is_empty() else 1.0}
				var min_x := floori(minf(a.x, minf(b.x,c.x))/CELL)
				var max_x := floori(maxf(a.x, maxf(b.x,c.x))/CELL)
				var min_z := floori(minf(a.z, minf(b.z,c.z))/CELL)
				var max_z := floori(maxf(a.z, maxf(b.z,c.z))/CELL)
				for cx in range(min_x, max_x+1):
					for cz in range(min_z, max_z+1):
						var key := Vector2i(cx, cz)
						if not cells.has(key): cells[key] = []
						cells[key].append(tri)
