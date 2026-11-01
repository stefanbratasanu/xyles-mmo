extends SkeletonModifier3D
## Apply hand calibration after animation, without rewriting the source clips.
var offset_degrees := Vector3.ZERO

func _process_modification_with_delta(_delta: float) -> void:
	if offset_degrees.is_zero_approx(): return
	var rig := get_skeleton()
	if rig == null: return
	var hand := rig.find_bone("humanoid_ R Hand")
	if hand < 0: return
	var offset := Quaternion.from_euler(offset_degrees * (PI / 180.0))
	rig.set_bone_pose_rotation(hand, (rig.get_bone_pose_rotation(hand) * offset).normalized())
