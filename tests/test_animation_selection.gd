extends SceneTree
const Profiles = preload("res://scripts/animation_profiles.gd")
var failures := 0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	root.size=Vector2i(1600,900)
	var game: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.player.set_physics_process(false)
	for enemy: Node in game.enemies: enemy.set_physics_process(false); enemy.aggro=false
	var player: Node=game.player
	var profiles: RefCounted=player.animation_profiles
	profiles.path="res://.godot/animation-profile-test.json"
	profiles.overrides.clear()
	var clips: PackedStringArray=player.available_animations()
	check(clips.has("actions/spear_thrust") and clips.has("actions/staff_idle"),"Spear and staff animation clips exist")
	for weapon: String in Profiles.WEAPONS:
		for action: String in profiles.actions():
			var entry: Dictionary=profiles.default_entry(weapon,action)
			check(entry.clip=="procedural_roll" or clips.has(entry.clip),"Default mapping exists: "+weapon+"/"+action+" → "+str(entry.clip))
	var entry: Dictionary={"clip":"actions/spear_thrust","speed":1.25,"upper_body":true}
	check(profiles.set_entry("spear","melee_cone",entry,clips),"Set spear attack")
	check(profiles.set_entry("sword","melee_area",{"clip":"protof/greatsword_AttackC2HandMelee","speed":.9,"upper_body":true},clips),"Set sword area attack separately")
	check(profiles.save(),"Save per-weapon mappings")
	var restored:=Profiles.new()
	restored.path=profiles.path
	restored.load_profiles(clips)
	check(restored.resolve("spear","melee_cone",clips)==entry,"Spear mapping persists")
	check(restored.resolve("sword","melee_cone",clips).clip!="actions/spear_thrust","Another weapon keeps its mapping")
	check(not restored.set_entry("spear","melee_cone",{"clip":"missing","speed":1,"upper_body":true},clips),"Reject missing clip")
	check(not restored.set_entry("spear","melee_cone",{"clip":"actions/spear_thrust","speed":0,"upper_body":true},clips),"Reject invalid playback speed")
	player.update_equipment([{"slot":"weapon","name":"Infantry Spear","weapon_type":"spear"}])
	check(player.weapon_style=="spear" and is_instance_valid(player.weapon_visual),"Spear equips with a visible model")
	check(player.play_skill_animation("melee_cone"),"Gameplay resolves saved spear attack")
	check(player.upper_body_player.current_animation=="upper/actions_spear_thrust","Saved spear clip reaches upper body layer")
	check(is_equal_approx(player.upper_body_player.get_playing_speed(),1.25),"Saved playback speed applies")
	check(player.play_skill_animation("channel_ray"),"Channel animation starts")
	var channel_clip: Animation=player.upper_body_player.get_animation(player.upper_body_player.current_animation)
	check(channel_clip.loop_mode==Animation.LOOP_LINEAR,"Channel holds a looping animation")
	player.stop_skill_animation()
	check(not player.upper_body_player.is_playing(),"Channel stop releases the animation layer")
	profiles.set_entry("spear","block",{"clip":"protof/unarmed_idle","speed":1,"upper_body":false},clips)
	player.block_animation()
	check(player.animation_player.current_animation.begins_with("selected_once/"),"Looping clip selected as an attack becomes a one-shot")
	var selected: Animation=player.animation_player.get_animation(player.animation_player.current_animation)
	check(selected.loop_mode==Animation.LOOP_NONE,"Selected attack cannot leave actor stuck in a loop")
	var ui: RefCounted=game.hud.animation_view
	ui.selected_weapon="spear"; ui.selected_action="melee_cone"
	game.hud.toggle_panel("animations")
	for i in range(5): await process_frame
	ui._preview()
	check(ui.preview_upper_player.current_animation=="preview/actions_spear_thrust","Preview plays chosen upper-body clip")
	ui.draft.speed=1.1
	ui._save()
	check(profiles.resolve("spear","melee_cone",clips).speed==1.1,"Save button applies selected mapping")
	if DisplayServer.get_name()!="headless":
		await create_timer(.35).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/animation-selection-preview.png")
	print("ANIMATION SELECTION: ",failures," failures; ",clips.size()," imported clips")
	game.queue_free()
	await process_frame
	quit(failures)
