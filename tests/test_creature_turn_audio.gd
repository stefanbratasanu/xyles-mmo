extends SceneTree
## Checks that stationary turning moves the creature rig and that selected
## positional sounds respect the audio settings and aggro cooldown.

var failures := 0

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.player.set_physics_process(false)
	for existing in game.enemies:
		existing.set_physics_process(false)
	game.audio.muted = false
	game.audio.master_volume = 1.0
	for species in ["wolf", "boar"]:
		var enemy: CharacterBody3D = game._spawn_enemy("normal", game.world.normal_spawns[0], 0, species)
		enemy.set_physics_process(false)
		var visual: Node3D = enemy.visual
		check(is_instance_valid(visual.creature_rig), species + " has a rig")
		if is_instance_valid(visual.creature_rig):
			var leg: int = int(visual.creature_bones.get("front_left", -1))
			check(leg >= 0, species + " has a front leg bone")
			if leg >= 0:
				visual.animate(0.2, 0.0, false, 0.0)
				var rest: Quaternion = visual.creature_rig.get_bone_pose_rotation(leg)
				visual.animate(0.2, 0.0, false, 2.0)
				var stepping: Quaternion = visual.creature_rig.get_bone_pose_rotation(leg)
				check(not stepping.is_equal_approx(rest), species + " steps while turning in place")
				visual.animate(0.2, 0.0, false, 0.0)
				check(visual.creature_rig.get_bone_pose_rotation(leg).is_equal_approx(rest), species + " rests its leg when turning stops")
		check(is_instance_valid(enemy.creature_voice) and enemy.creature_voice.stream != null, species + " loads its selected aggro sound")
		enemy.age = 1.0
		enemy._play_aggro_sound()
		check(is_equal_approx(enemy.last_aggro_sound, 1.0), species + " starts aggro sound")
		enemy.age = 2.0
		enemy._play_aggro_sound()
		check(is_equal_approx(enemy.last_aggro_sound, 1.0), species + " respects aggro cooldown")
		game.audio.muted = true
		enemy.age = 10.0
		enemy._play_aggro_sound()
		check(is_equal_approx(enemy.last_aggro_sound, 1.0), species + " does not play while muted")
		game.audio.muted = false
		game.player.global_position = enemy.global_position + Vector3(1.0, 0.0, 0.0)
		enemy._begin_attack()
		enemy._finish_attack()
		check(enemy.creature_voice.stream.resource_path == "res://assets/audio/enemies/%s_attack.wav" % species, species + " attack selects the approved sound")
		enemy.take_damage(enemy.hp + 1.0)
		check(enemy.dead and enemy.creature_voice.stream.resource_path == "res://assets/audio/enemies/%s_death.wav" % species, species + " death selects the approved sound")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: creature turn animation and selected sounds")
	quit(1 if failures else 0)
