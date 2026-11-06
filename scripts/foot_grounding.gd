extends SkeletonModifier3D
## Correct near-ground feet after animation. Samples come from each model's
## actual skinned sole, so the contact height is not a shared human constant.
var actor: CharacterBody3D
var samples := {"L": [], "R": []}
const MAX_SAMPLES := 36
const MAX_CORRECTION := .16

func rebuild_samples() -> void:
	samples = {"L": [], "R": []}
	if not is_instance_valid(actor) or not is_instance_valid(actor.fighter_visual): return
	var body: MeshInstance3D = actor.fighter_visual
	var candidates := {"L": [], "R": []}
	for surface in range(body.mesh.get_surface_count()):
		var arrays := body.mesh.surface_get_arrays(surface)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
		var bones: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
		if vertices.is_empty() or weights.is_empty(): continue
		var stride := weights.size() / vertices.size()
		for i in range(vertices.size()):
			var v := vertices[i]
			if v.y > .045: continue
			var side := "L" if v.x > 0 else "R"
			candidates[side].append({"point": v, "weights": weights.slice(i*stride, (i+1)*stride), "bones": bones.slice(i*stride, (i+1)*stride)})
	for side in ["L", "R"]:
		var list: Array = candidates[side]
		if list.is_empty(): continue
		for i in range(mini(MAX_SAMPLES, list.size())):
			samples[side].append(list[floori(float(i) * list.size() / mini(MAX_SAMPLES, list.size()))])

func _process_modification() -> void:
	if not is_instance_valid(actor) or not is_instance_valid(actor.game): return
	if not actor.is_on_floor() or actor.sitting or actor.seat_returning or actor.rolling or actor.is_dying or actor.action_active or actor.animation_override or actor.animation_frozen: return
	var rig := get_skeleton()
	var body: MeshInstance3D = actor.fighter_visual
	if rig == null or body.skin == null: return
	var binds: Array[Transform3D] = []
	for bind in range(body.skin.bind_count):
		binds.append(rig.get_bone_global_pose(body.skin.get_bind_bone(bind)) * body.skin.get_bind_pose(bind))
	for side in ["L", "R"]:
		if samples[side].is_empty(): continue
		var foot_bone := rig.find_bone("humanoid_ %s Foot" % side)
		if foot_bone < 0: continue
		var foot_world := rig.to_global(rig.get_bone_global_pose(foot_bone).origin)
		# Query the actual road/camp triangles once per foot, then follow the
		# terrain slope across the small sole footprint without 72 mesh searches.
		var overlay: float = actor.game.world.foot_ground_height(foot_world.x, foot_world.z) - actor.game.world.surface_height_at(foot_world.x, foot_world.z)
		var clearance := INF
		for sample: Dictionary in samples[side]:
			var point := Vector3.ZERO
			for j in range(sample.weights.size()):
				var bone := int(sample.bones[j])
				if bone >= 0 and bone < binds.size(): point += (binds[bone] * sample.point) * float(sample.weights[j])
			var world_point := rig.to_global(point)
			var ground: float = actor.game.world.surface_height_at(world_point.x, world_point.z) + overlay
			clearance = minf(clearance, world_point.y - ground)
		# A lifted swing foot is left alone; only a foot near the surface is planted.
		if clearance > .10 or not is_finite(clearance): continue
		_adjust_leg(rig, side, clampf(.001 - clearance, -MAX_CORRECTION, MAX_CORRECTION))

func _adjust_leg(rig: Skeleton3D, side: String, offset: float) -> void:
	if absf(offset) < .002: return
	var thigh := rig.find_bone("humanoid_ %s Thigh" % side)
	var calf := rig.find_bone("humanoid_ %s Calf" % side)
	var foot := rig.find_bone("humanoid_ %s Foot" % side)
	if thigh < 0 or calf < 0 or foot < 0: return
	var hip_pose := rig.get_bone_global_pose(thigh)
	var knee_pose := rig.get_bone_global_pose(calf)
	var foot_pose := rig.get_bone_global_pose(foot)
	var hip := hip_pose.origin
	var knee := knee_pose.origin
	var ankle := foot_pose.origin
	var upper := hip.distance_to(knee)
	var lower := knee.distance_to(ankle)
	if upper < .01 or lower < .01: return
	var target := ankle + rig.global_basis.inverse() * (Vector3.UP * offset)
	var delta := target - hip
	var distance := clampf(delta.length(), absf(upper - lower) + .001, upper + lower - .001)
	var axis := delta.normalized()
	target = hip + axis * distance
	var bend := knee - hip - axis * (knee - hip).dot(axis)
	if bend.length_squared() < .000001: bend = axis.cross(Vector3.RIGHT)
	bend = bend.normalized()
	var along := (upper*upper + distance*distance - lower*lower) / (2.0*distance)
	var height := sqrt(maxf(0.0, upper*upper - along*along))
	var new_knee := hip + axis * along + bend * height
	var hip_rotation := Quaternion((knee-hip).normalized(), (new_knee-hip).normalized())
	hip_pose.basis = Basis(hip_rotation) * hip_pose.basis
	rig.set_bone_global_pose(thigh, hip_pose)
	knee_pose = rig.get_bone_global_pose(calf)
	var moved_ankle := rig.get_bone_global_pose(foot).origin
	var knee_rotation := Quaternion((moved_ankle-knee_pose.origin).normalized(), (target-knee_pose.origin).normalized())
	knee_pose.basis = Basis(knee_rotation) * knee_pose.basis
	rig.set_bone_global_pose(calf, knee_pose)
	var adjusted_foot := rig.get_bone_global_pose(foot)
	adjusted_foot.basis = foot_pose.basis
	rig.set_bone_global_pose(foot, adjusted_foot)
