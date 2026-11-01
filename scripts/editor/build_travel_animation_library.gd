extends SceneTree
## Import ordinary locomotion separately from the weapon/fist combat clips.
const ROOT := "res://assets/animations/Ultimate Animation Collection/Animations/"
const BASIC := "Basic Locomotion Animset/FBX Motions/Humanoid@"
const OUT := "res://assets/animations/player_runtime/"

func copy_right_grip(clip: Animation, sword: Animation) -> void:
	for track in range(clip.get_track_count() - 1, -1, -1):
		if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D and " R Finger" in str(clip.track_get_path(track)): clip.remove_track(track)
	for track in range(sword.get_track_count()):
		if sword.track_get_type(track) != Animation.TYPE_ROTATION_3D or not " R Finger" in str(sword.track_get_path(track)): continue
		var target := clip.add_track(Animation.TYPE_ROTATION_3D)
		clip.track_set_path(target, sword.track_get_path(track))
		clip.track_insert_key(target, 0, sword.rotation_track_interpolate(track, 0))

func aim_carry_wrist(clip: Animation, actor: Node3D, animator: AnimationPlayer, upright: bool = false, relaxed_idle: bool = false) -> void:
	var rig := actor.get_node("Skeleton3D") as Skeleton3D
	var hand := rig.find_bone("humanoid_ R Hand")
	var forearm := rig.find_bone("humanoid_ R Forearm")
	var parent := rig.get_bone_parent(hand)
	var temporary := AnimationLibrary.new()
	temporary.add_animation("pose", clip)
	animator.add_animation_library("_carry_author", temporary)
	var samples: Array[Quaternion] = []
	var steps := maxi(1, ceili(clip.length * 30))
	for sample in range(steps + 1):
		animator.stop(); rig.reset_bone_poses()
		animator.play("_carry_author/pose", 0)
		animator.seek(clip.length * sample / steps, true)
		rig.force_update_all_bone_transforms()
		var pose := rig.get_bone_global_pose(hand)
		var direction := (pose.origin - rig.get_bone_global_pose(forearm).origin).normalized()
		if upright: direction = Vector3(0, 1, .2).normalized()
		var blade := (pose.basis * Vector3(.25, -.06, .96).normalized()).normalized()
		var aimed := Basis(Quaternion(blade, direction)) * pose.basis
		if relaxed_idle:
			# Align the palm with the forearm, not the blade. Forcing the blade
			# along the arm made the wrist bend sideways to an unnatural angle.
			var middle := rig.find_bone("humanoid_ R Finger2")
			var palm := (rig.get_bone_global_pose(middle).origin - pose.origin).normalized()
			aimed = Basis(Quaternion(palm, palm.slerp(direction, .80).normalized())) * pose.basis
		samples.append((rig.get_bone_global_pose(parent).basis.inverse() * aimed).get_rotation_quaternion().normalized())
	animator.stop()
	animator.remove_animation_library("_carry_author")
	for track in range(clip.get_track_count() - 1, -1, -1):
		if clip.track_get_type(track) == Animation.TYPE_ROTATION_3D and str(clip.track_get_path(track)) == "Skeleton3D:humanoid_ R Hand": clip.remove_track(track)
	var track := clip.add_track(Animation.TYPE_ROTATION_3D)
	clip.track_set_path(track, NodePath("Skeleton3D:humanoid_ R Hand"))
	for sample in range(steps + 1): clip.track_insert_key(track, clip.length * sample / steps, samples[sample])
	clip.set_meta("carry_wrist", "blade continues the forearm away from the body")
	if relaxed_idle: clip.set_meta("carry_wrist", "relaxed palm aligned with forearm; slight natural wrist bend")

func read_clip(path: String) -> Animation:
	# Source filenames contain both .FBX and .fbx; preserve their actual casing.
	var directory := DirAccess.open((ROOT + path).get_base_dir())
	if directory != null:
		for filename in directory.get_files():
			if filename.to_lower() == path.get_file().to_lower():
				path = path.get_base_dir() + "/" + filename
				break
	var document := FBXDocument.new()
	var state := FBXState.new()
	if document.append_from_file(ROOT + path, state) != OK: return null
	var source := document.generate_scene(state)
	var player := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clip: Animation
	if player != null:
		for name in player.get_animation_list():
			if name != "RESET":
				clip = player.get_animation(name).duplicate(true)
				break
	source.free()
	return clip

func _initialize() -> void:
	if "--idle-only" in OS.get_cmdline_user_args():
		var library: AnimationLibrary = load(OUT + "travel_animations.res").duplicate(true)
		var actor := load(OUT + "character.tscn").instantiate() as Node3D
		root.add_child(actor)
		for idle_key in ["carry_idle", "sword_ready"]:
			var carry: Animation = library.get_animation(idle_key)
			copy_right_grip(carry, load(OUT + "protof_animations.tres").get_animation("sword_idle"))
			var source: Animation = library.get_animation("idle") if idle_key == "carry_idle" else read_clip(str(carry.get_meta("source_fbx")))
			if source == null:
				actor.free()
				push_error("Missing source for relaxed idle: " + idle_key)
				quit(1)
				return
			var path := NodePath("Skeleton3D:humanoid_ R Hand")
			var track := carry.find_track(path, Animation.TYPE_ROTATION_3D)
			if track >= 0: carry.remove_track(track)
			track = carry.add_track(Animation.TYPE_ROTATION_3D)
			carry.track_set_path(track, path)
			var original := source.find_track(path, Animation.TYPE_ROTATION_3D)
			if original >= 0:
				for key in range(source.track_get_key_count(original)):
					carry.track_insert_key(track, source.track_get_key_time(original, key), source.track_get_key_value(original, key))
			else:
				var rig: Skeleton3D = actor.get_node("Skeleton3D")
				carry.track_insert_key(track, 0, rig.get_bone_rest(rig.find_bone("humanoid_ R Hand")).basis.get_rotation_quaternion())
			aim_carry_wrist(carry, actor, actor.get_node("AnimationPlayer"), false, true)
		actor.free()
		var result := ResourceSaver.save(library, OUT + "travel_animations.res", ResourceSaver.FLAG_COMPRESS)
		print("RELAXED SWORD IDLE: ", result)
		quit(result)
		return
	var paths := {
		"idle": BASIC + "IdleUnarmed.FBX",
		"idle_look": BASIC + "IdleLookAroundUnarmed.FBX",
		"run": BASIC + "RunFastForwardUnarmed.fbx",
		"jog": BASIC + "RunForwardUnarmed.FBX",
		"sprint": BASIC + "SprintForwardUnarmed.FBX",
		"sprint_forward_left": BASIC + "SprintForwardLeftUnarmed.fbx",
		"sprint_forward_right": BASIC + "SprintForwardRightUnarmed.fbx",
		"sword_breathe": "Sword&Shield Animset/FBX Motions/Humanoid@IdleBreatheS&S.fbx",
		"greatsword_breathe": "2Handed Melee Weapon Animset/FBX Files/Humanoid@IdleBreathe2HandMelee.fbx"
	}
	paths["sword_ready"] = "Fencing Animset/FBX Files/Humanoid@IdleCombatFencing.fbx"
	paths["fencing_breathe"] = "Fencing Animset/FBX Files/Humanoid@IdleBreatheFencing.fbx"
	paths["fencing_idle"] = "Fencing Animset/FBX Files/Humanoid@Idle1Fencing.fbx"
	var directions := {"forward":"Forward", "back":"Backwards", "left":"Left", "right":"Right", "forward_left":"ForwardLeft", "forward_right":"ForwardRight", "back_left":"BackwardsLeft", "back_right":"BackwardsRight"}
	for direction in directions:
		paths["walk_" + direction] = BASIC + "Walk" + directions[direction] + "Unarmed.fbx"
		if direction != "forward": paths["run_" + direction] = BASIC + "Run" + directions[direction] + "Unarmed.fbx"
	var library := AnimationLibrary.new()
	var speeds := {}
	for key in paths:
		var clip := read_clip(paths[key])
		if clip == null:
			push_error("Missing ordinary locomotion clip: " + paths[key]); quit(1); return
		clip.loop_mode = Animation.LOOP_LINEAR
		clip.set_meta("source_fbx", paths[key])
		# Physics owns displacement; preserve pelvis bob and foot movement.
		for track in range(clip.get_track_count() - 1, -1, -1):
			if clip.track_get_type(track) == Animation.TYPE_POSITION_3D and str(clip.track_get_path(track)) in ["Skeleton3D:root", "Skeleton3D:humanoid_"]:
				clip.remove_track(track)
		library.add_animation(key, clip)
		var rm_path: String = str(paths[key]).get_basename() + "_RM.fbx"
		if FileAccess.file_exists(ROOT + rm_path):
			var rm := read_clip(rm_path)
			if rm != null:
				for track in range(rm.get_track_count()):
					if rm.track_get_type(track) != Animation.TYPE_POSITION_3D or str(rm.track_get_path(track)) != "Skeleton3D:root" or rm.track_get_key_count(track) < 2: continue
					var delta: Vector3 = rm.track_get_key_value(track, rm.track_get_key_count(track)-1) - rm.track_get_key_value(track, 0)
					speeds["travel/" + str(key)] = Vector2(delta.x, delta.z).length() / maxf(rm.length, .001)
	# Relaxed carrying uses ordinary arm swing with a real right-hand grip,
	# rather than raising both fists or pretending an absent shield is present.
	var sword: Animation = load(OUT + "protof_animations.tres").get_animation("sword_idle")
	var actor := load(OUT + "character.tscn").instantiate() as Node3D
	root.add_child(actor)
	var animator := actor.get_node("AnimationPlayer") as AnimationPlayer
	copy_right_grip(library.get_animation("sword_ready"), sword)
	aim_carry_wrist(library.get_animation("sword_ready"), actor, animator, false, true)
	for key in library.get_animation_list():
		if key in ["sword_breathe", "greatsword_breathe", "idle_look", "sword_ready", "fencing_breathe", "fencing_idle"]: continue
		var carry := library.get_animation(key).duplicate(true) as Animation
		copy_right_grip(carry, sword)
		carry.set_meta("carry_grip", "right hand, sword source")
		var pole := carry.duplicate(true) as Animation
		aim_carry_wrist(carry, actor, animator, false, key == "idle")
		aim_carry_wrist(pole, actor, animator, true)
		library.add_animation("carry_" + key, carry)
		library.add_animation("pole_" + key, pole)
		if speeds.has("travel/" + key): speeds["travel/carry_" + key] = speeds["travel/" + key]
		if speeds.has("travel/" + key): speeds["travel/pole_" + key] = speeds["travel/" + key]
	actor.free()
	var error := ResourceSaver.save(library, OUT + "travel_animations.res", ResourceSaver.FLAG_COMPRESS)
	if error != OK: push_error("Could not save travel library"); quit(error); return
	var file := FileAccess.open(OUT + "travel_speeds.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(speeds, "  ") + "\n")
	print("TRAVEL LIBRARY: ", library.get_animation_list().size(), " ordinary clips; speeds=", speeds)
	quit()
