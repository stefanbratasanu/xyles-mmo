extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func press(forward: bool) -> void:
	key_input(KEY_W, forward)

func key_input(code: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
func box(parent: Node, position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = position
	body.collision_layer = 1
	var shape := CollisionShape3D.new()
	var geometry := BoxShape3D.new()
	geometry.size = size
	shape.shape = geometry
	body.add_child(shape)
	parent.add_child(body)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for frame in range(3): await process_frame
	game.set_process(false)
	var player = game.player
	player.animation_profiles.overrides.clear()
	game.camera_yaw = 0
	var origin: Vector3 = game.world.player_spawn
	# Isolated level platform keeps terrain slope/props out of the speed check.
	box(game, Vector3(origin.x, 100, origin.z), Vector3(100,1,100))
	player.global_position = Vector3(origin.x, 102, origin.z)
	for frame in range(60): await physics_frame
	player.update_equipment([{"slot":"weapon", "weapon_type":"sword", "name":"Sword"}])
	var rates := {}
	for identity in [["Human","Male"],["Dwarf","Female"]]:
		player.apply_character_appearance({}, identity[0], identity[1])
		press(true)
		for frame in range(45): await physics_frame
		var velocity: Vector3 = player.get_real_velocity()
		var speed := Vector2(velocity.x, velocity.z).length()
		var expected: float = 3.71 + game.state.get_skill_bonus("move") * .12
		check(is_equal_approx(player.BASE_MOVEMENT_SPEED, 5.3 * .7), "Default base is reduced by 30 percent")
		check(absf(speed - expected) < .05, str(identity) + ": real movement uses reduced base plus existing bonuses")
		check(player.animation_player.current_animation == "travel/carry_run", "Movement uses ordinary run")
		var rate: float = player.animation_player.speed_scale
		rates[identity[0]] = rate
		check(absf(rate * float(player.stride_speeds.run) - speed) < .03, str(identity) + ": rendered stride pace matches actual translation")
		print("PACE ", identity, ": actual=", speed, "; animation rate=", rate, "; measured stride=", player.stride_speeds.run)
		press(false)
		for frame in range(10): await physics_frame
	check(float(rates.Dwarf) > float(rates.Human) * 1.3, "Shorter legs cycle faster at the same travel speed")
	for side in ["left", "right"]:
		var side_key := KEY_A if side == "left" else KEY_D
		key_input(KEY_SHIFT, true); press(true); key_input(side_key, true)
		for frame in range(90): await physics_frame
		var actual: Vector3 = player.get_real_velocity()
		var speed := Vector2(actual.x, actual.z).length()
		var key: String = "sprint_forward_" + side
		var prefix := "travel/" if game.state.sprint_weapon_phase == "sheathed" else "travel/carry_"
		check(player.animation_player.current_animation == prefix + key, "Shift+W+" + side + " selects diagonal sprint with current carry state")
		check(game.state.sprint_blocks_combat(), "Actual sprint input locks combat readiness")
		var expected: float = (player.BASE_MOVEMENT_SPEED + game.state.get_skill_bonus("move") * .12) * player.SPRINT_SPEED_FACTOR
		check(absf(speed - expected) < .05, "Diagonal sprint keeps the same normalized sprint speed")
		check(absf(player.animation_player.speed_scale * float(player.stride_speeds[key]) - speed) < .03, "Diagonal sprint playback matches actual travel")
		print("DIAGONAL SPRINT ", side, ": speed=", speed, "; clip=", player.animation_player.current_animation)
		key_input(side_key,false); press(false); key_input(KEY_SHIFT,false)
		for frame in range(6): await physics_frame
	box(game, player.global_position + Vector3(0,1,-.8), Vector3(6,3,.2))
	press(true)
	for frame in range(35): await physics_frame
	var stopped: Vector3 = player.get_real_velocity()
	check(Vector2(stopped.x, stopped.z).length() < .05, "Wall blocks actual movement")
	var idle := "travel/carry_idle" if game.state.sprint_weapon_phase == "drawn" else "travel/idle"
	check(player.animation_player.current_animation == idle, "Blocked movement cannot keep running feet in place")
	press(false)
	game.queue_free()
	await process_frame
	print("LOCOMOTION PACE: ", failures, " failures")
	quit(failures)
