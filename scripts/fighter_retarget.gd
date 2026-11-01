extends Node
## Offline rest-mapping helper for scripts/dev/fighter_skin; no longer used by player.gd.
## Transfer the existing animation skeleton's global rest-relative rotations to
## the generated fighter rig. Gameplay continues to use the original skeleton.
var source: Skeleton3D
var target: Skeleton3D
var bone_pairs: Array[Vector2i] = []
var source_rests: Array[Basis] = []
var target_rests: Array[Basis] = []
var rest_alignments: Array[Basis] = []
var source_hip := -1
var target_hip := -1

func setup(source_rig: Skeleton3D, target_rig: Skeleton3D) -> void:
	source = source_rig
	target = target_rig
	process_priority = 110
	var map := {"Hips":"humanoid_ Pelvis", "Spine":"humanoid_ Spine", "Spine1":"humanoid_ Spine1", "Spine2":"humanoid_ Spine2", "Neck":"humanoid_ Neck", "Head":"humanoid_ Head"}
	for side in ["Left", "Right"]:
		var short := "L" if side == "Left" else "R"
		for pair in [["Shoulder", "Clavicle"], ["Arm", "UpperArm"], ["ForeArm", "Forearm"], ["Hand", "Hand"], ["UpLeg", "Thigh"], ["Leg", "Calf"], ["Foot", "Foot"], ["ToeBase", "Toe0"]]:
			map[side + pair[0]] = "humanoid_ " + short + " " + pair[1]
		for finger in range(5):
			var finger_name: String = ["Thumb", "Index", "Middle", "Ring", "Pinky"][finger]
			for joint in range(3):
				var suffix := str(finger) if joint == 0 else str(finger) + str(joint)
				map[side + "Hand" + finger_name + str(joint + 1)] = "humanoid_ " + short + " Finger" + suffix
	var children := {}
	for side in ["Left", "Right"]:
		for pair in [["Shoulder", "Arm"], ["Arm", "ForeArm"], ["ForeArm", "Hand"], ["Hand", "HandIndex1"], ["UpLeg", "Leg"], ["Leg", "Foot"], ["Foot", "ToeBase"]]:
			children[side + pair[0]] = side + pair[1]
		for finger_name in ["Thumb", "Index", "Middle", "Ring", "Pinky"]:
			for joint in [1, 2]:
				children[side + "Hand" + finger_name + str(joint)] = side + "Hand" + finger_name + str(joint + 1)
	for i in range(target.get_bone_count()):
		var target_name := String(target.get_bone_name(i))
		var source_index := source.find_bone(str(map.get(target_name, "")))
		if source_index < 0: continue
		bone_pairs.append(Vector2i(source_index, i))
		source_rests.append(source.get_bone_global_rest(source_index).basis.orthonormalized())
		target_rests.append(target.get_bone_global_rest(i).basis.orthonormalized())
		var alignment := Basis.IDENTITY
		var child_name := str(children.get(target_name, ""))
		var target_child := target.find_bone(child_name)
		var source_child := source.find_bone(str(map.get(child_name, "")))
		if target_child >= 0 and source_child >= 0:
			var src_dir := source.get_bone_global_rest(source_child).origin - source.get_bone_global_rest(source_index).origin
			var dst_dir := target.get_bone_global_rest(target_child).origin - target.get_bone_global_rest(i).origin
			if src_dir.length_squared() > 0.000001 and dst_dir.length_squared() > 0.000001:
				alignment = Basis(Quaternion(dst_dir.normalized(), src_dir.normalized()))
		rest_alignments.append(alignment)
	source_hip = source.find_bone("humanoid_ Pelvis")
	target_hip = target.find_bone("Hips")

func _process(_delta: float) -> void:
	if not is_instance_valid(source) or not is_instance_valid(target): return
	source.force_update_all_bone_transforms()
	for i in range(bone_pairs.size()):
		var source_index := bone_pairs[i].x
		var target_index := bone_pairs[i].y
		var delta_rotation := source.get_bone_global_pose(source_index).basis.orthonormalized() * source_rests[i].inverse()
		var desired_global := delta_rotation * rest_alignments[i] * target_rests[i]
		var parent := target.get_bone_parent(target_index)
		var parent_basis := Basis.IDENTITY if parent < 0 else target.get_bone_global_pose(parent).basis.orthonormalized()
		target.set_bone_pose_rotation(target_index, (parent_basis.inverse() * desired_global).get_rotation_quaternion())
		target.force_update_all_bone_transforms()
	if source_hip >= 0 and target_hip >= 0:
		var displacement := source.get_bone_global_pose(source_hip).origin - source.get_bone_global_rest(source_hip).origin
		target.set_bone_pose_position(target_hip, target.get_bone_rest(target_hip).origin + displacement)

