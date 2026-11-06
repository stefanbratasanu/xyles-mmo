extends SkeletonModifier3D
## Two-hand overhead wind-up layered over the authored full-body sword swing.
## Solve from each fitted rig's own shoulder and arm lengths, without moving
## the character's collision or changing the normal weapon grip.
var actor: CharacterBody3D

func _process_modification() -> void:
	if not is_instance_valid(actor) or not actor.heavy_strike_active or not actor.action_active: return
	var rig := get_skeleton()
	if rig == null or actor.animation_player == null: return
	var time: float = actor.animation_player.current_animation_position
	var weight := smoothstep(0.0, .20, time) * (1.0 - smoothstep(.60, .84, time))
	if weight <= .001: return
	var head := rig.find_bone("humanoid_ Head")
	if head < 0: return
	var head_world := rig.to_global(rig.get_bone_global_pose(head).origin)
	var forward: Vector3 = -actor.visual.global_basis.z.normalized()
	var right: Vector3 = actor.visual.global_basis.x.normalized()
	var windup: Vector3 = head_world + Vector3.UP * .32 + right * .08 + forward * .08
	var impact: Vector3 = head_world - Vector3.UP * .42 + forward * .60 + right * .08
	var target: Vector3 = windup.lerp(impact, smoothstep(.38, .60, time))
	_solve_arm(rig, "R", rig.to_local(target), weight)
	# Keep the supporting hand beside the main grip through the wind-up and cut.
	_solve_arm(rig, "L", rig.to_local(target - right * .08 - Vector3.UP * .04), weight)

func _solve_arm(rig: Skeleton3D, side: String, target: Vector3, weight: float) -> void:
	var upper := rig.find_bone("humanoid_ %s UpperArm" % side)
	var forearm := rig.find_bone("humanoid_ %s Forearm" % side)
	var hand := rig.find_bone("humanoid_ %s Hand" % side)
	if upper < 0 or forearm < 0 or hand < 0: return
	var shoulder_pose := rig.get_bone_global_pose(upper)
	var elbow_pose := rig.get_bone_global_pose(forearm)
	var hand_pose := rig.get_bone_global_pose(hand)
	var shoulder := shoulder_pose.origin
	var elbow := elbow_pose.origin
	var wrist := hand_pose.origin
	var upper_length := shoulder.distance_to(elbow)
	var lower_length := elbow.distance_to(wrist)
	if upper_length < .01 or lower_length < .01: return
	target = wrist.lerp(target, weight)
	var delta := target - shoulder
	var distance := clampf(delta.length(), absf(upper_length - lower_length) + .001, upper_length + lower_length - .001)
	var axis := delta.normalized()
	target = shoulder + axis * distance
	var bend := elbow - shoulder - axis * (elbow - shoulder).dot(axis)
	if bend.length_squared() < .000001: bend = axis.cross(Vector3.FORWARD)
	bend = bend.normalized()
	var along := (upper_length * upper_length + distance * distance - lower_length * lower_length) / (2.0 * distance)
	var height := sqrt(maxf(0.0, upper_length * upper_length - along * along))
	var new_elbow := shoulder + axis * along + bend * height
	shoulder_pose.basis = Basis(Quaternion((elbow - shoulder).normalized(), (new_elbow - shoulder).normalized())) * shoulder_pose.basis
	rig.set_bone_global_pose(upper, shoulder_pose)
	elbow_pose = rig.get_bone_global_pose(forearm)
	var moved_wrist := rig.get_bone_global_pose(hand).origin
	elbow_pose.basis = Basis(Quaternion((moved_wrist - elbow_pose.origin).normalized(), (target - elbow_pose.origin).normalized())) * elbow_pose.basis
	rig.set_bone_global_pose(forearm, elbow_pose)
	var adjusted := rig.get_bone_global_pose(hand)
	adjusted.basis = hand_pose.basis
	rig.set_bone_global_pose(hand, adjusted)
