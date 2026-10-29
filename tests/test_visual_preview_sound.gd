extends SceneTree

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
	var world: Node = game.world
	world.set_time_of_day(9.0)
	var real_day: int = world.day_number
	var actual_phase: String = world.phase_text()
	var daylight: float = world._environment.ambient_light_energy
	game.hud.lighting_preview_button.pressed.emit()
	check(world.visual_time_preview == "day" and game.hud.lighting_preview_button.text == "VIEW: DAY", "day preview button")
	game.hud.lighting_preview_button.pressed.emit()
	check(world.visual_time_preview == "night" and game.hud.lighting_preview_button.text == "VIEW: NIGHT", "night preview button")
	check(world._environment.ambient_light_energy < daylight, "night preview changes lighting")
	check(is_equal_approx(world.time_of_day, 9.0) and world.day_number == real_day and world.phase_text() == actual_phase, "preview does not change the world clock or phase")
	world.advance_time(1.0)
	check(world.time_of_day > 9.0 and world.visual_time_preview == "night", "world time continues while preview stays active")
	game.hud.lighting_preview_button.pressed.emit()
	check(world.visual_time_preview == "auto" and game.hud.lighting_preview_button.text == "VIEW: AUTO", "auto restores real-time lighting")
	check(world._environment.ambient_light_energy > 0.4, "real day lighting restored")
	game.set_taa_enabled(false)
	check(not root.use_taa, "TAA turns off immediately")
	var config := ConfigFile.new()
	game._store_graphics_settings(config)
	check(config.get_value("graphics", "temporal_antialiasing", true) == false, "TAA setting is stored")
	game.set_taa_enabled(true)
	game._load_graphics_settings(config)
	game._apply_graphics_settings()
	check(not root.use_taa, "TAA setting reloads")
	game.set_taa_enabled(true)
	var slash: AudioStream = game.audio.cues.get("sword_slash") as AudioStream
	check(slash != null and slash.resource_path == "res://assets/audio/player/sword_slash_user.wav", "the user-supplied slash is loaded")
	game.audio.muted = false
	game.player.weapon_style = "sword"
	var before: int = game.audio.next_voice
	game.player.attack_animation()
	check(game.audio.next_voice != before, "sword attack plays sound")
	var slash_played := false
	for voice: AudioStreamPlayer in game.audio.voices:
		if voice.stream == slash and slash != null:
			slash_played = true
	check(slash_played, "the active voice uses a selected slash sample")
	before = game.audio.next_voice
	check(game.skill_runtime.cast_slot(0), "starting melee skill activates")
	check(game.audio.next_voice != before, "melee skill triggers a sword slash")
	for style in ["sword", "greatsword"]:
		game.player.weapon_style = style
		for iteration in range(3):
			for voice: AudioStreamPlayer in game.audio.voices:
				voice.stop()
			before = game.audio.next_voice
			game.player.attack_animation()
			check(game.audio.next_voice != before and game.audio.voices[0].stream == slash, "%s attack %d uses the supplied slash" % [style, iteration])
	game.player.weapon_style = "unarmed"
	before = game.audio.next_voice
	game.player.attack_animation()
	check(game.audio.next_voice == before, "unarmed attack does not play sword sound")
	game.audio.muted = true
	game.player.weapon_style = "sword"
	game.player.attack_animation()
	check(game.audio.next_voice == before, "sword slash respects mute")
	game.queue_free()
	await process_frame
	if failures == 0:
		print("PASS: lighting preview, TAA setting and sword slashes")
	quit(1 if failures else 0)
