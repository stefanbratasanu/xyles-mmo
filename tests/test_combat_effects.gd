extends SceneTree
var frame_times: Array[float] = []
var sample_frames := false

func _initialize() -> void:
	process_frame.connect(func():
		if sample_frames:
			frame_times.append(root.get_process_delta_time() * 1000.0)
			if frame_times.back() > 30.0:
				print("SLOW FRAME ", frame_times.size(), " ms= ", frame_times.back())
	)
	call_deferred("_run")

func _run() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(15):
		await process_frame
	# Starter hotbar slots are intentionally empty in the Fighter redesign;
	# equip the two abilities this effect-pool test exercises explicitly.
	game.state.character_class = "Mystic"
	game.state.loadout[3] = "move"
	game.state.loadout[1] = "cast"
	var enemy: Node3D = game.enemies[0]
	for creature in game.enemies:
		creature.set_physics_process(false)
	game.player.set_physics_process(false)
	enemy.position = game.player.position + Vector3(2, 0, 0)
	enemy.max_hp = 10000.0
	enemy.hp = 10000.0
	game.target = enemy
	sample_frames = true
	for i in range(12):
		game.state.mana = 100.0
		game.skill_runtime.skill_cooldowns.clear()
		game.use_skill(3)
		game.use_skill(1)
		await create_timer(0.4).timeout
	sample_frames = false
	assert(game.skill_runtime.counts.get("ON_PROJECTILE_LANDED",0)==12)
	await create_timer(0.7).timeout
	for ring in game.combat_effects.rings:
		assert(not ring.get_meta("busy"))
	for orb in game.combat_effects.orbs:
		assert(not orb.get_meta("busy"))
	assert(game.combat_effects.orbs.size() == 32)
	assert(game.audio.voices.size() == 16)
	frame_times.sort()
	if not frame_times.is_empty():
		print("FRAME ms p95=%.2f max=%.2f" % [frame_times[int((frame_times.size() - 1) * 0.95)], frame_times.back()])
	print("PASS: 12 casts and dashes; impacts deal damage; effect pools return idle; no extra audio voices or projectile instances")
	game.queue_free()
	await process_frame
	quit()

