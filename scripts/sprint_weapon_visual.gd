extends Node3D
## Back-mounted weapon with clip-synchronized secondary motion; never edits bones.
var actor: Node
var mount: BoneAttachment3D
var holder: Node3D
var stored_weapon: Node3D
var mount_pose := Transform3D.IDENTITY
var _frozen_stowed := false

func configure() -> void:
	if is_instance_valid(mount):
		mount.get_parent().remove_child(mount)
		mount.queue_free()
	mount = null
	_frozen_stowed = false
	if actor.weapon_style == "unarmed": return
	var rig := get_parent() as Skeleton3D
	var chest := rig.find_bone("humanoid_ Spine2")
	var shoulder := rig.get_bone_global_rest(rig.find_bone("humanoid_ R UpperArm")).origin
	var scale_value := rig.get_bone_global_rest(chest).origin.y / 1.35
	var side := signf(shoulder.x)
	var direction := Vector3(-side * .40, -.90, -.12).normalized()
	var model_pose := Transform3D(Basis(Quaternion(Vector3.UP, direction)), shoulder + Vector3(0, -.04, -.20) * scale_value)
	mount_pose = rig.get_bone_global_rest(chest).affine_inverse() * model_pose
	mount = BoneAttachment3D.new()
	mount.name = "SprintWeaponBackMount"
	mount.bone_name = "humanoid_ Spine2"
	rig.add_child(mount)
	holder = Node3D.new()
	holder.transform = mount_pose
	mount.add_child(holder)
	stored_weapon = actor.create_weapon_visual(actor.weapon_style, actor.weapon_visual_variant)
	stored_weapon.transform = Transform3D.IDENTITY
	holder.add_child(stored_weapon)
	stored_weapon.hide()

func _process(_delta: float) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(actor.game) or not is_instance_valid(mount) or not is_instance_valid(actor.weapon_visual): return
	var phase: String = actor.game.state.sprint_weapon_phase
	var stowed := phase != "drawn"
	if actor.animation_frozen:
		stowed = _frozen_stowed
	else:
		_frozen_stowed = stowed
	var hidden: bool = actor.sitting or actor.seat_returning
	stored_weapon.visible = stowed and not hidden
	actor.weapon_visual.visible = not stowed and not hidden
	if actor.animation_frozen: return
	var animator: AnimationPlayer = actor.animation_player
	var rig := get_parent() as Skeleton3D
	var chest := rig.find_bone("humanoid_ Spine2")
	var right := rig.get_bone_global_pose(rig.find_bone("humanoid_ R UpperArm")).origin
	var left := rig.get_bone_global_pose(rig.find_bone("humanoid_ L UpperArm")).origin
	var hip := rig.get_bone_global_pose(rig.find_bone("humanoid_ Pelvis")).origin
	var up := ((right + left) * .5 - hip).normalized()
	var side := (right - left).normalized()
	var back := side.cross(up).normalized()
	if rig.get_bone_global_rest(rig.find_bone("humanoid_ R UpperArm")).origin.x > 0: back = -back
	var scale_value := rig.get_bone_global_rest(chest).origin.y / 1.35
	var origin := right + back * .15 * scale_value + up * .03 * scale_value
	var tip := hip - side * .13 * scale_value + up * .18 * scale_value + back * .15 * scale_value
	# Follow the shoulder-to-pelvis line rather than amplifying a single spine
	# bone's bend. The attachment stays against the back during the sprint lean.
	mount_pose = rig.get_bone_global_pose(chest).affine_inverse() * Transform3D(Basis(Quaternion(Vector3.UP, (tip-origin).normalized())), origin)
	var clip := str(animator.assigned_animation).trim_prefix("travel/").trim_prefix("carry_").trim_prefix("pole_")
	var gait := clip.begins_with("sprint") or clip.begins_with("run") or clip == "jog"
	var bounce := Vector3.ZERO
	var sway := Vector3.ZERO
	if stowed and gait and animator.current_animation_length > 0:
		var step := TAU * animator.current_animation_position / animator.current_animation_length
		# Small translation and a few degrees of sway, following the authored steps.
		bounce = Vector3(.004 * sin(step), .008 * sin(step * 2), .004 * cos(step))
		sway = Vector3(.018 * sin(step * 2 + .4), .025 * sin(step - .35), .015 * cos(step))
	holder.transform = mount_pose * Transform3D(Basis.from_euler(sway), bounce)
