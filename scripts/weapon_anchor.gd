extends RefCounted
## Handle contact points in each weapon scene's local coordinates. Future
## authored weapons may instead contain a Marker3D named GripAnchor.
const CONTACTS := {
	"sword": Vector3(0, -.065, 0),
	# The ornate mesh's cylindrical handle runs from y=-.098 to y=.075.
	"ornate_silver_sword": Vector3(0, -.012, 0),
	"greatsword": Vector3(0, -.16, 0),
	"staff": Vector3.ZERO,
	"spear": Vector3.ZERO,
	"bow": Vector3.ZERO,
}

static func apply(skeleton: Skeleton3D, weapon: Node3D, style: String, variant: String) -> bool:
	if skeleton == null or weapon == null: return false
	var hand := skeleton.find_bone("humanoid_ R Hand")
	var index := skeleton.find_bone("humanoid_ R Finger1")
	var little := skeleton.find_bone("humanoid_ R Finger4")
	if hand < 0 or index < 0 or little < 0: return false
	var hand_inverse := skeleton.get_bone_global_rest(hand).affine_inverse()
	var a := (hand_inverse * skeleton.get_bone_global_rest(index)).origin
	var b := (hand_inverse * skeleton.get_bone_global_rest(little)).origin
	var across := (a - b).normalized()
	var palm := (a + b) * .5
	var along := (palm - across * palm.dot(across)).normalized()
	if across.length_squared() < .9 or along.length_squared() < .9: return false
	var normal := along.cross(across).normalized()
	along = across.cross(normal).normalized()
	var basis := Basis(along, across, normal).orthonormalized()
	var attachment := weapon.get_parent() as BoneAttachment3D
	var body := skeleton.get_node_or_null("HumanFighter") as MeshInstance3D
	if attachment == null or body == null: return false
	var palm_marker := attachment.get_node_or_null("PalmGripAnchor") as Marker3D
	if palm_marker == null:
		palm_marker = Marker3D.new()
		palm_marker.name = "PalmGripAnchor"
		attachment.add_child(palm_marker)
	var mesh_id := body.mesh.get_instance_id()
	if int(palm_marker.get_meta("mesh_id", 0)) != mesh_id:
		var surface := _palm_surface(body, hand, hand_inverse, palm, along, across, -normal, a.distance_to(b))
		# The contact is on the gripping face of this actual mesh and just past
		# the palm, where the bent fingers meet the handle.
		var contact_point := palm * 1.12 - normal * (surface + .009)
		palm_marker.transform = Transform3D(basis, contact_point)
		palm_marker.set_meta("mesh_id", mesh_id)
	var anchor: Node3D = weapon.find_child("GripAnchor", true, false) as Node3D
	var contact: Vector3 = CONTACTS.get(variant, CONTACTS.get(style, Vector3.ZERO))
	if anchor == null:
		anchor = Marker3D.new()
		anchor.name = "GripAnchor"
		weapon.add_child(anchor)
		anchor.position = contact
	var handle_frame := weapon.global_transform.affine_inverse() * anchor.global_transform
	weapon.transform = palm_marker.transform * handle_frame.affine_inverse()
	return true

static func _palm_surface(body: MeshInstance3D, hand: int, inverse: Transform3D, palm: Vector3, along: Vector3, across: Vector3, outward: Vector3, width: float) -> float:
	var depths: Array[float] = []
	for surface in range(body.mesh.get_surface_count()):
		var arrays := body.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		if vertices.is_empty() or weights.is_empty(): continue
		var stride := weights.size() / vertices.size()
		for i in range(vertices.size()):
			var local := inverse * vertices[i]
			if local.dot(along) < palm.dot(along) * .7 or local.dot(along) > palm.dot(along) * 1.05: continue
			if absf((local - palm).dot(across)) > width * .4: continue
			var hand_weight := 0.0
			for j in range(stride):
				var bind := bones[i*stride+j]
				if bind >= 0 and bind < body.skin.bind_count and body.skin.get_bind_bone(bind) == hand: hand_weight += weights[i*stride+j]
			if hand_weight >= .6: depths.append(local.dot(outward))
	if depths.is_empty(): return width * .22
	depths.sort()
	return depths[clampi(floori(depths.size() * .8), 0, depths.size() - 1)]
