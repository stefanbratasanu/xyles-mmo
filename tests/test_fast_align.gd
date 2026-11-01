extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func mouse_move(hud: Node, delta: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.relative = delta
	event.screen_relative = delta
	hud._input(event)
func mouse_button(view: RefCounted, code: MouseButton, pressed: bool = true) -> bool:
	var event := InputEventMouseButton.new()
	event.button_index = code
	event.pressed = pressed
	event.factor = 1
	return view.handle_input(event)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(1600,900)
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for frame in range(3): await process_frame
	var player = game.player
	var hud = game.hud
	player.weapon_grips.path = "res://logs/fast_align_grips.cfg"
	player.weapon_grips.config = ConfigFile.new()
	player.hand_rotation_degrees = Vector3.ZERO
	player.hand_rotation_degrees = Vector3.ZERO
	player.update_equipment([{"slot":"weapon","weapon_type":"sword","name":"Sword"}])
	player.play_animation_override("travel/carry_run", 1.25)
	player.animation_player.seek(.31, true)
	hud.toggle_panel("weapon_position")
	var view = hud.weapon_position_view
	view.freeze_button.pressed.emit()
	var time: float = player.animation_player.current_animation_position
	var rig: Skeleton3D = player.fighter_visual.get_node(player.fighter_visual.skeleton)
	rig.force_update_all_bone_transforms()
	var hand := rig.find_bone("humanoid_ R Hand")
	var pose := rig.get_bone_global_pose(hand)
	player.play_skill_animation("cast_projectile")
	for frame in range(12): await process_frame
	rig.force_update_all_bone_transforms()
	check(player.animation_frozen and player.animation_override, "Freeze pauses instead of ending the override")
	check(is_equal_approx(player.animation_player.current_animation_position,time), "Freeze holds the exact clip time")
	check(pose.is_equal_approx(rig.get_bone_global_pose(hand)), "Freeze holds the bone pose across updates")
	view.freeze_button.pressed.emit()
	for frame in range(3): await process_frame
	check(not player.animation_frozen and player.animation_player.current_animation_position > time, "Resume continues the frozen clip")
	player.stop_animation_override()
	player._play_locomotion("travel/carry_idle")
	player.play_profile_action("channel_ray")
	player._process(.08)
	view._toggle_freeze()
	var upper_time: float = player.upper_body_player.current_animation_position
	player._process(.2)
	for frame in range(4): await process_frame
	check(is_equal_approx(player.upper_body_player.current_animation_position, upper_time), "Freeze also holds the manual upper-body layer")
	view._toggle_freeze()
	player._process(.05)
	check(player.upper_body_player.current_animation_position > upper_time, "Upper-body overlay resumes at its saved time")
	view._toggle_freeze()
	upper_time = player.upper_body_player.current_animation_position
	player.stop_skill_animation()
	check(is_equal_approx(player.upper_body_player.current_animation_position, upper_time), "Ending a skill cannot reset the frozen pose")
	view._toggle_freeze()
	check(not player.upper_body_player.is_playing(), "Resume does not restart a channel that already ended")
	player.play_animation_override("travel/carry_idle")
	view._toggle_freeze()
	view.fields[0].value = .1; view.fields[1].value = .2; view.fields[2].value = .3
	view.fields[3].value = 10; view.fields[4].value = 20; view.fields[5].value = 30
	var mode: int = Input.mouse_mode
	var yaw: float = game.camera_yaw
	view.align_button.pressed.emit()
	check(view.aligning and not view.rotating, "Plain Fast Align selects translation")
	mouse_move(hud, Vector2(40,-20))
	mouse_button(view,MOUSE_BUTTON_WHEEL_UP)
	check(player.weapon_visual.position.is_equal_approx(Vector3(.14,.22,.31)), "Mouse XY and wheel Z move the actual weapon")
	check(is_equal_approx(game.camera_yaw,yaw), "Alignment motion does not rotate the camera")
	check(is_equal_approx(view.fields[0].value,.14) and is_equal_approx(view.fields[2].value,.31), "Fast alignment updates the numeric fields")
	mouse_button(view,MOUSE_BUTTON_LEFT)
	check(not view.aligning and Input.mouse_mode == mode, "Click commits and restores mouse mode")
	check(mouse_button(view,MOUSE_BUTTON_LEFT,false), "Commit release cannot click through and restart alignment")
	var original: Transform3D = player.weapon_visual.transform
	var ctrl := InputEventMouseButton.new()
	ctrl.button_index = MOUSE_BUTTON_LEFT; ctrl.pressed = true; ctrl.ctrl_pressed = true
	view.align_button.gui_input.emit(ctrl)
	view.align_button.pressed.emit()
	check(view.aligning and view.rotating, "Ctrl-click Fast Align selects rotation")
	mouse_move(hud,Vector2(20,-8))
	mouse_button(view,MOUSE_BUTTON_WHEEL_DOWN)
	check(player.weapon_visual.position.is_equal_approx(original.origin), "Rotation leaves weapon position intact")
	check(player.weapon_visual.rotation_degrees.is_equal_approx(Vector3(12,25,28)), "Mouse pitch/yaw and wheel roll rotate the weapon")
	var escape := InputEventKey.new()
	escape.physical_keycode = KEY_ESCAPE; escape.pressed = true
	check(view.handle_input(escape), "Escape is consumed by alignment")
	check(not view.aligning and player.weapon_visual.transform.is_equal_approx(original), "Cancel restores the start transform")
	view.start_alignment(false)
	mouse_button(view,MOUSE_BUTTON_RIGHT)
	mouse_move(hud,Vector2(12,-4))
	mouse_button(view,MOUSE_BUTTON_WHEEL_UP)
	check(view.aligning and player.weapon_visual.rotation_degrees.is_equal_approx(Vector3(11,23,32)), "Right-drag rotates weapon without cancelling the pass")
	check(player.weapon_visual.position.is_equal_approx(original.origin), "Right-drag does not translate the weapon")
	mouse_button(view,MOUSE_BUTTON_RIGHT,false)
	mouse_move(hud,Vector2(10,0))
	check(player.weapon_visual.position.is_equal_approx(original.origin + Vector3(.01,0,0)), "Releasing right button returns to translation")
	view.handle_input(escape)
	var observed: Array[Quaternion] = []
	player.hand_modifier.modification_processed.connect(func(): observed.append(rig.get_bone_pose_rotation(hand)))
	for frame in range(3): await process_frame
	var before_hand: Basis = player.weapon_attachment.global_basis
	view.start_alignment(false)
	var alt := InputEventKey.new()
	alt.physical_keycode = KEY_ALT; alt.keycode = KEY_ALT; alt.pressed = true
	view.handle_input(alt)
	mouse_move(hud,Vector2(20,-8))
	mouse_button(view,MOUSE_BUTTON_WHEEL_UP)
	check(player.hand_rotation_degrees.is_equal_approx(Vector3(2,5,2)), "Alt motion and wheel rotate the actual hand calibration")
	check(player.weapon_visual.transform.is_equal_approx(original), "Hand adjustment does not alter the weapon-local grip")
	for frame in range(6): await process_frame
	check(player.weapon_attachment.global_basis.get_rotation_quaternion().angle_to(before_hand.get_rotation_quaternion()) > .05, "Hand bone adjustment moves the attached weapon in world space")
	check(observed.size() >= 2, "Skeleton modifier processes while the animation is frozen")
	if observed.size() >= 2:
		check(observed[-1].angle_to(observed[-2]) < .001, "Hand offset does not accumulate on a frozen pose")
	alt.pressed = false; view.handle_input(alt)
	mouse_move(hud,Vector2(10,0))
	check(player.weapon_visual.position.is_equal_approx(original.origin + Vector3(.01,0,0)), "Releasing Alt returns to weapon editing")
	view.handle_input(escape)
	check(player.hand_rotation_degrees.is_zero_approx() and player.weapon_visual.transform.is_equal_approx(original), "Escape restores hand and weapon together")
	view.start_alignment(false)
	alt.pressed = true; view.handle_input(alt)
	mouse_move(hud,Vector2(8,-4))
	view.finish_alignment(false)
	view.start_alignment(false)
	mouse_move(hud,Vector2(10,0))
	view.finish_alignment(false)
	view._save()
	var grips = load("res://scripts/weapon_grips.gd").new()
	grips.path = player.weapon_grips.path; grips.load_grips()
	var fixture := Node3D.new()
	grips.apply(player.weapon_grip_key(),fixture)
	check(fixture.transform.is_equal_approx(player.weapon_visual.transform), "Save persists Fast Align changes")
	check(grips.hand_rotation(player.weapon_grip_key()).is_equal_approx(player.hand_rotation_degrees), "Save reloads hand calibration too")
	fixture.free()
	player.update_equipment([])
	check(player.hand_rotation_degrees.is_zero_approx(), "Unequipping clears the hand calibration")
	player.update_equipment([{"slot":"weapon","weapon_type":"sword","name":"Sword"}])
	check(player.hand_rotation_degrees.is_equal_approx(Vector3(1,2,0)), "Reequipping restores the saved hand adjustment")
	view.start_alignment(false)
	player.apply_character_appearance({},"Dwarf","Female")
	var changed: Transform3D = player.weapon_visual.transform
	view.update_context()
	check(not view.aligning and Input.mouse_mode == mode and player.weapon_visual.transform.is_equal_approx(changed), "Changing models exits without restoring a stale grip")
	check(player.hand_rotation_degrees.is_zero_approx(), "Another model does not inherit the previous hand calibration")
	hud._render_overlay()
	player.play_animation_override("travel/carry_idle")
	view._toggle_freeze()
	if DisplayServer.get_name() != "headless":
		for frame in range(3): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://logs/fast_align_panel.png")
	view.start_alignment(false)
	game.queue_free()
	await process_frame
	check(Input.mouse_mode == mode, "HUD teardown releases captured mouse")
	print("FAST ALIGN: ", failures, " failures")
	quit(failures)
