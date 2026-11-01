extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var state = load("res://scripts/game_state.gd").new()
	state.update_sprint_weapon(0, true, true)
	check(state.sprint_weapon_phase == "sheathed" and state.sprint_blocks_combat(), "Sprint immediately puts weapon on back")
	state.update_sprint_weapon(0, false, true)
	state.update_sprint_weapon(.99, false, true)
	check(state.sprint_blocks_combat(), "Readiness lasts one second")
	state.update_sprint_weapon(.02, false, true)
	check(not state.sprint_blocks_combat(), "Combat unlocks after one second")
	state.update_sprint_weapon(0, true, true)
	state.update_sprint_weapon(0, false, true)
	state.update_sprint_weapon(.4, true, true)
	check(state.sprint_weapon_phase == "sheathed", "Resuming sprint cancels readiness")
	state.update_sprint_weapon(0, false, false)
	check(not state.sprint_blocks_combat(), "Unequip clears readiness")
	state.free()
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for frame in range(3): await process_frame
	game.set_process(false)
	var player = game.player
	player.set_physics_process(false)
	player.update_equipment([{"slot":"weapon", "weapon_type":"sword", "name":"Sword"}])
	player.animation_player.play("travel/carry_run", 0)
	player.animation_player.seek(.2, true); player.animation_player.pause()
	game.state.update_sprint_weapon(0, true, true)
	var mana: float = game.state.mana
	var cooldowns: Dictionary = game.skill_runtime.skill_cooldowns.duplicate()
	check(not game.skill_runtime.cast_slot(0), "Actual skill dispatcher rejects sprint cast")
	game.basic_attack()
	check(game.state.mana == mana and game.skill_runtime.skill_cooldowns == cooldowns, "Blocked attacks spend no mana or cooldown")
	for model in JSON.parse_string(FileAccess.get_file_as_string("res://resources/characters/race_models.json")).models:
		player.apply_character_appearance({}, model.race, model.gender)
		player.hand_rotation_degrees = Vector3.ZERO
		var rig: Skeleton3D = player.fighter_visual.get_node(player.fighter_visual.skeleton)
		game.state.update_sprint_weapon(0, true, true)
		player.animation_player.play("travel/sprint", 0)
		var first := Transform3D.IDENTITY
		var movement := 0.0
		for phase in range(8):
			player.animation_player.seek(player.animation_player.current_animation_length * phase / 8.0, true)
			player.animation_player.pause()
			var bones := ["humanoid_ R UpperArm", "humanoid_ R Forearm", "humanoid_ L UpperArm"]
			var poses: Array[Transform3D] = []
			for bone in bones: poses.append(rig.get_bone_global_pose(rig.find_bone(bone)))
			for frame in range(3): await process_frame
			for index in range(bones.size()): check(poses[index].is_equal_approx(rig.get_bone_global_pose(rig.find_bone(bones[index]))), str(model.id) + ": authored arm preserved")
			var visual = player.sprint_weapon_visual
			check(visual.stored_weapon.visible and not player.weapon_visual.visible, str(model.id) + ": back-mounted during sprint")
			var secondary: Transform3D = visual.mount_pose.affine_inverse() * visual.holder.transform
			if phase == 0: first = secondary
			movement = maxf(movement, secondary.origin.distance_to(first.origin))
		check(movement > .002 and movement < .03, str(model.id) + ": subtle jiggle " + str(movement))
		var frozen: Transform3D = player.sprint_weapon_visual.holder.transform
		player.set_animation_frozen(true)
		for frame in range(4): await process_frame
		check(frozen.is_equal_approx(player.sprint_weapon_visual.holder.transform), "F7 freezes jiggle")
		player.set_animation_frozen(false)
		game.state.update_sprint_weapon(0, false, true)
		check(not game.skill_runtime.cast_slot(0), "Readiness blocks skill dispatcher")
		game.state.update_sprint_weapon(1.01, false, true)
		for frame in range(3): await process_frame
		check(player.weapon_visual.visible and not player.sprint_weapon_visual.stored_weapon.visible, "Weapon returns to hand")
	game.state.update_sprint_weapon(0, true, true)
	player.death_animation()
	check(not game.state.sprint_blocks_combat(), "Death clears transient readiness")
	game.queue_free()
	await process_frame
	print("SPRINT WEAPON: ", failures, " failures")
	quit(failures)
