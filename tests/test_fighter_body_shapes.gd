extends SceneTree
var failures := 0
var max_front_flips := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var scene = load("res://assets/models/characters/human_fighter/head_revision/character.tscn")
	var actor = scene.instantiate()
	var other = scene.instantiate()
	root.add_child(actor)
	root.add_child(other)
	var body: MeshInstance3D = actor.get_node("Skeleton3D/HumanFighter")
	var other_body: MeshInstance3D = other.get_node("Skeleton3D/HumanFighter")
	check(body.mesh.get_blend_shape_count() == 24, "Twenty-four complete presets plus neutral basis are present")
	check(body.mesh.get_surface_count() == 8, "Character carries skin, tunic, trousers, leather, hair and brass surfaces")
	check(bool(body.mesh.get_meta("outfit_coverage", false)), "Dressed asset declares its reversible skin coverage mask")
	var count := 0
	for surface in range(body.mesh.get_surface_count()):
		var base := body.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = base[Mesh.ARRAY_VERTEX]
		count += vertices.size()
		var material := body.get_active_material(surface)
		if surface < 2:
			check(material is ShaderMaterial, "Both skin surfaces use the runtime skin shader")
			check(bool(material.get_shader_parameter("coverage_enabled")) == (surface == 0), "Only the body skin is masked under clothing")
			if surface == 0:
				var colors: PackedColorArray = base[Mesh.ARRAY_COLOR]
				var covered := 0
				for color in colors:
					if color.a > 0.5: covered += 1
				check(covered > 10000 and covered < colors.size() - 1000, "Coverage hides clothed skin while preserving exposed hands, arms and neck")
		else:
			check(material is StandardMaterial3D, "Clothing and hair keep their authored materials")
			check(material.resource_name in ["ClothTunic", "ClothTrouser", "Leather", "LeatherLight", "Hair", "Brass"], "Unexpected cosmetic surface material: " + material.resource_name)
			check((material as StandardMaterial3D).cull_mode == BaseMaterial3D.CULL_DISABLED, "Open cloth hems render both faces")
			if material.resource_name == "Hair":
				check((material as StandardMaterial3D).albedo_color.a == 0.0, "The playable fighter matches the bald reference")
		var weights: PackedFloat32Array = base[Mesh.ARRAY_WEIGHTS]
		var bone_indices: PackedInt32Array = base[Mesh.ARRAY_BONES]
		var stride: int = weights.size() / vertices.size()
		var torso_vertices := PackedByteArray()
		torso_vertices.resize(vertices.size())
		for v in range(vertices.size()):
			var total := 0.0
			var torso_weight := 0.0
			var thigh_weight := 0.0
			for i in range(stride):
				var offset := v * stride + i
				total += weights[offset]
				var name: String = body.skin.get_bind_name(bone_indices[offset])
				if name.contains("Spine") or name.ends_with("Pelvis"): torso_weight += weights[offset]
				if name.contains("Thigh"): thigh_weight += weights[offset]
			torso_vertices[v] = 1 if torso_weight > 0.6 else 0
			if surface == 0 and absf(vertices[v].x) < 0.09 and vertices[v].y > 1.18 and vertices[v].y < 1.40 and vertices[v].z > 0.06:
				check(thigh_weight < 0.001, "Leg motion must not pull the upper abdomen")
			if absf(total - 1.0) > 0.002:
				check(false, "Skin weight normalization failed")
				break
		var targets := body.mesh.surface_get_blend_shape_arrays(surface)
		var front_faces: Array[Vector3i] = []
		var front_normals := PackedVector3Array()
		if surface == 0:
			var indices: PackedInt32Array = base[Mesh.ARRAY_INDEX]
			for offset in range(0, indices.size(), 3):
				var face := Vector3i(indices[offset], indices[offset + 1], indices[offset + 2])
				var center := (vertices[face.x] + vertices[face.y] + vertices[face.z]) / 3.0
				var normal := (vertices[face.y] - vertices[face.x]).cross(vertices[face.z] - vertices[face.x])
				if center.y > .98 and center.y < 1.51 and absf(center.x) < .215 and center.z > 0 and normal.length_squared() > 0.00000000000001:
					front_faces.append(face)
					front_normals.append(normal)
		var waist_widths := {}
		for size in range(5):
			for muscle in range(5):
				actor.body_size = size
				actor.muscularity = muscle
				var total_shapes := 0.0
				for target in range(targets.size()): total_shapes += body.get_blend_shape_value(target)
				check(total_shapes == (0.0 if size == 2 and muscle == 3 else 1.0), "A preset selects one complete shape without stacking deformations")
				var waist_half_width := 0.0
				for v in range(0, vertices.size(), 13):
					var point := vertices[v]
					for target in range(targets.size()):
						var delta: Vector3 = targets[target][Mesh.ARRAY_VERTEX][v]
						if body.mesh.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_NORMALIZED: delta -= vertices[v]
						point += delta * body.get_blend_shape_value(target)
					check(point.is_finite() and absf(point.x) < 1.5 and absf(point.z) < 1.0 and point.y > -0.2 and point.y < 2.1, "Body combination has invalid geometry")
					if torso_vertices[v] == 1 and vertices[v].y > 1.10 and vertices[v].y < 1.24:
						waist_half_width = maxf(waist_half_width, absf(point.x))
					if surface < 2 and vertices[v].y > 1.56:
						check(point.distance_to(vertices[v]) < 0.00001, "Body sliders must preserve the head and neck join")
					if surface == 0 and size == 0 and muscle == 0 and vertices[v].y < 0.8:
						check(point.distance_to(vertices[v]) < 0.045, "Skinny and soft settings must not compound into stick-thin legs")
					# Imported source faces +Z before the character's PI rotation.
					if surface == 0 and size == 4 and absf(vertices[v].x) < 0.10 and vertices[v].y > 1.05 and vertices[v].y < 1.25 and vertices[v].z < -0.06:
						check(absf(point.z - vertices[v].z) < 0.04, "Heavy preset must not overinflate the lower back")
				waist_widths[Vector2i(size, muscle)] = waist_half_width
				if surface == 0:
					var selected := body.find_blend_shape_by_name("Physique_%d_%d" % [size, muscle])
					var points: PackedVector3Array = vertices if selected < 0 else targets[selected][Mesh.ARRAY_VERTEX]
					var flips := 0
					for face_index in range(front_faces.size()):
						var face := front_faces[face_index]
						var a := points[face.x]; var b := points[face.y]; var c := points[face.z]
						if selected >= 0 and body.mesh.blend_shape_mode == Mesh.BLEND_SHAPE_MODE_RELATIVE:
							a += vertices[face.x]; b += vertices[face.y]; c += vertices[face.z]
						if (b - a).cross(c - a).dot(front_normals[face_index]) < 0: flips += 1
					max_front_flips = maxi(max_front_flips, flips)
					check(flips <= 20, "Preset %d/%d must not fold the torso surface inside out (%d reversed triangles)" % [size, muscle, flips])
		if surface == 0:
			for muscle in range(5):
				for size in range(1, 5):
					check(waist_widths[Vector2i(size, muscle)] > waist_widths[Vector2i(size - 1, muscle)] + 0.005, "Every size step visibly increases waist width")
	check(count >= 20000 and count <= 200000, "Combined character fits requested vertex budget")
	for i in range(other_body.mesh.get_blend_shape_count()): check(other_body.get_blend_shape_value(i) == 0.0, "Presets must not change another actor")
	check(body.get_active_material(0) != other_body.get_active_material(0), "Surface settings are per instance")
	actor.queue_free()
	other.queue_free()
	await process_frame
	print("BODY SHAPES: ", failures, " failures; 25 combinations; ", count, " vertices; max front flips=", max_front_flips)
	quit(failures)
