extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func key(hud: Node, code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	hud._unhandled_key_input(event)
func select_clip(view: RefCounted, clip: String) -> void:
	for index in range(view.clip_list.item_count):
		if str(view.clip_list.get_item_metadata(index)) == clip:
			view.clip_list.select(index)
			view.clip_list.item_selected.emit(index)
			return
	check(false, "Clip not listed: " + clip)
func run() -> void:
	root.size = Vector2i(1600, 900)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for frame in range(3): await process_frame
	var player = game.player
	var hud = game.hud
	player.weapon_grips.path = "res://logs/weapon_controls_grips.cfg"
	player.weapon_grips.config = ConfigFile.new()
	player.update_equipment([{"slot":"weapon", "weapon_type":"sword", "name":"Test sword"}])
	player.play_profile_action("channel_ray")
	var before: String = str(player.upper_body_player.current_animation) if player.upper_body_player.is_playing() else str(player.animation_player.current_animation)
	key(hud, KEY_F6)
	check(hud.current_panel == "animations", "F6 opens animation selection")
	check(hud.animation_view.captured_clip == before, "F6 captures active skill animation")
	select_clip(hud.animation_view, "protof/sword_idle")
	check(player.animation_override and player.animation_player.current_animation == "protof/sword_idle", "Selection replaces skill immediately")
	check(not player.upper_body_player.is_playing(), "Old upper body overlay stops")
	player.play_skill_animation("cast_projectile")
	player._play_locomotion("protof/unarmed_idle")
	check(player.animation_player.current_animation == "protof/sword_idle", "Skill and locomotion cannot overwrite the selected visual")
	key(hud, KEY_F6)
	check(hud.current_panel == "animations" and hud.animation_view.captured_clip == "protof/sword_idle", "F6 recaptures without closing the open window")
	select_clip(hud.animation_view, "protof/sword_attack")
	check(player.animation_player.current_animation == "protof/sword_attack", "Repeated capture accepts a different replacement")
	if DisplayServer.get_name() != "headless":
		for frame in range(3): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://logs/weapon_controls_f6.png")
	player._on_animation_finished(&"protof/sword_attack")
	check(not player.animation_override, "Nonlooping override releases on completion")
	player.rolling = true
	player.roll_elapsed = player.DODGE_DURATION - .001
	player.play_animation_override("protof/sword_idle")
	player._physics_process(.01)
	check(player.animation_override and player.animation_player.current_animation == "protof/sword_idle", "Finishing a roll cannot stop the replacement")
	player.stop_animation_override()
	check(not player.animation_override, "Stop releases looping override")
	key(hud, KEY_F7)
	check(hud.current_panel == "weapon_position", "F7 opens weapon calibration")
	check(not game.set_debug_key("heal", KEY_F7), "F7 cannot be stolen by debug bindings")
	var view = hud.weapon_position_view
	check(view.fields.size() == 6, "Position and rotation have XYZ fields")
	view.fields[0].value = .123
	view.fields[1].value = -.045
	view.fields[2].value = .078
	view.fields[3].value = 12.5
	view.fields[4].value = -30
	view.fields[5].value = 5
	var position := Vector3(.123, -.045, .078)
	check(player.weapon_visual.position.is_equal_approx(position), "XYZ fields update the actual weapon live")
	view._save()
	check(view.status.text == "Grip saved.", "Save reports success")
	var grips = load("res://scripts/weapon_grips.gd").new()
	grips.path = player.weapon_grips.path
	grips.load_grips()
	var fixture := Node3D.new()
	grips.apply(player.weapon_grip_key(), fixture)
	check(fixture.position.is_equal_approx(position) and fixture.rotation_degrees.is_equal_approx(Vector3(12.5,-30,5)), "Saved calibration reloads from disk")
	fixture.free()
	player.update_equipment([])
	player.update_equipment([{"slot":"weapon", "weapon_type":"sword", "name":"Test sword"}])
	check(player.weapon_visual.position.is_equal_approx(position), "Reequipping restores saved grip")
	player.apply_character_appearance({}, "Dwarf", "Female")
	check(not player.weapon_visual.position.is_equal_approx(position), "Other race has an independent grip")
	player.apply_character_appearance({}, "Human", "Male")
	check(player.weapon_visual.position.is_equal_approx(position), "Switching back restores that model's grip")
	if DisplayServer.get_name() != "headless":
		for frame in range(3): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://logs/weapon_controls_f7.png")
	game.queue_free()
	await process_frame
	print("WEAPON CONTROLS: ", failures, " failures")
	quit(failures)

