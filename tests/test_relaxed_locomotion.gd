extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for frame in range(3): await process_frame
	var player = game.player
	player.animation_profiles.overrides.clear()
	player.set_physics_process(false)
	game.set_process(false)
	var idle: String = player.animation_entry("idle", "sword").clip
	check(idle == "travel/carry_idle", "Sword peace idle uses lowered-arm carry")
	for weapon in player.animation_profiles.WEAPONS:
		for action in ["idle", "combat_idle", "run", "sprint", "sprint_forward_left", "sprint_forward_right", "walk_forward", "walk_back", "walk_left", "walk_right"]:
			var entry: Dictionary = player.animation_entry(action, weapon)
			check(player.animation_player.has_animation(entry.clip), weapon + ": available " + action)
			if action != "combat_idle":
				var clip: Animation = player.animation_player.get_animation(entry.clip)
				check("Basic Locomotion" in str(clip.get_meta("source_fbx", "")), weapon + ": ordinary source for " + action)
	player.update_equipment([{"slot":"weapon", "weapon_type":"sword", "name":"Sword"}])
	for direction in [Vector2(-1,-1), Vector2(1,-1), Vector2(-1,-1).normalized(), Vector2(1,-1).normalized()]:
		var side := "left" if direction.x < 0 else "right"
		check(player._movement_animation(direction,false,false,true,true) == "travel/carry_sprint_forward_" + side, "Diagonal sprint chooses its own source: " + side)
		check(player._locomotion_action(direction,false,true,true) == "sprint_forward_" + side, "Diagonal sprint exposes a separate mapping: " + side)
	var rig: Skeleton3D = player.fighter_visual.get_node(player.fighter_visual.skeleton)
	player.combat_stance_time = 0
	check(player._movement_animation(Vector2.ZERO, false, false, false) == idle, "Standing without combat is relaxed")
	for model in JSON.parse_string(FileAccess.get_file_as_string("res://resources/characters/race_models.json")).models:
		player.apply_character_appearance({}, model.race, model.gender)
		player.animation_player.stop(); rig.reset_bone_poses()
		player.animation_player.play(idle, 0)
		player.animation_player.seek(.28, true); player.animation_player.pause()
		rig.force_update_all_bone_transforms()
		var chest := rig.get_bone_global_pose(rig.find_bone("humanoid_ Spine2")).origin.y
		for hand in ["humanoid_ L Hand", "humanoid_ R Hand"]:
			check(rig.get_bone_global_pose(rig.find_bone(hand)).origin.y < chest - .12, str(model.id) + ": relaxed hands below chest")
		var hand_pose := rig.get_bone_global_pose(rig.find_bone("humanoid_ R Hand"))
		var palm := (rig.get_bone_global_pose(rig.find_bone("humanoid_ R Finger2")).origin - hand_pose.origin).normalized()
		var forearm := (hand_pose.origin - rig.get_bone_global_pose(rig.find_bone("humanoid_ R Forearm")).origin).normalized()
		check(rad_to_deg(palm.angle_to(forearm)) < 25.0, str(model.id) + ": relaxed wrist follows the forearm without forced sideways bend")
		for phase in [0.0, .25, .50, .75]:
			player.animation_player.stop(); rig.reset_bone_poses()
			player.animation_player.play("travel/sword_ready", 0)
			player.animation_player.seek(player.animation_player.current_animation_length * phase, true); player.animation_player.pause()
			hand_pose = rig.get_bone_global_pose(rig.find_bone("humanoid_ R Hand"))
			palm = (rig.get_bone_global_pose(rig.find_bone("humanoid_ R Finger2")).origin - hand_pose.origin).normalized()
			forearm = (hand_pose.origin - rig.get_bone_global_pose(rig.find_bone("humanoid_ R Forearm")).origin).normalized()
			check(rad_to_deg(palm.angle_to(forearm)) < 25.0, str(model.id) + ": combat-ready wrist remains relaxed through the idle cycle")
	player.apply_character_appearance({}, "Human", "Male")
	player.play_profile_action("melee_cone")
	check(player.combat_stance_time > 0, "Attack enters combat presentation")
	check(player._movement_animation(Vector2.ZERO, false, false, false) == "travel/sword_ready", "Combat uses one-handed ready, not shield guard")
	player.combat_stance_time = .01
	player._physics_process(.02)
	check(player.combat_stance_time == 0 and player._movement_animation(Vector2.ZERO, false, false, false) == idle, "Combat timeout restores relaxed idle")
	check(player._movement_animation(Vector2(-1,-1), false, false, true) == "travel/carry_run_forward_left", "Diagonal movement uses ordinary locomotion too")
	check(float(player.authored_animation_speeds.get("travel/carry_run",0)) > 4, "Ordinary run uses measured fast-running speed")
	var profiles = player.animation_profiles
	check(profiles.set_entry("sword", "idle", {"clip":"travel/idle_look", "speed":1.0,"upper_body":false}, player.available_animations()), "Custom peaceful idle remains editable")
	check(player.animation_entry("idle").clip == "travel/idle_look", "Saved profile mechanism takes priority")
	player.animation_player.stop()
	player._play_locomotion("travel/carry_run")
	player.animation_player.seek(player.animation_player.current_animation_length * .4, true)
	player._play_locomotion("travel/carry_run_left")
	check(absf(player.animation_player.current_animation_position / player.animation_player.current_animation_length - .4) < .01, "Changing direction keeps the step phase")
	player._play_locomotion("travel/carry_sprint")
	player.animation_player.seek(player.animation_player.current_animation_length * .4, true)
	player._play_locomotion("travel/carry_sprint_forward_left")
	check(absf(player.animation_player.current_animation_position / player.animation_player.current_animation_length - .4) < .01, "Diagonal sprint keeps the step phase")
	player.play_animation_override("travel/idle")
	player.play_profile_action("melee_cone")
	check(player.animation_player.current_animation == "travel/idle", "F6 override retains priority")
	game.queue_free()
	await process_frame
	print("RELAXED LOCOMOTION: ", failures, " failures; 10 race/gender poses")
	quit(failures)
