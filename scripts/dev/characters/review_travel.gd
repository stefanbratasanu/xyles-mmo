extends SceneTree
const Preview = preload("res://scripts/character_appearance_preview.gd")
const Adapter = preload("res://scripts/fighter_animation_adapter.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.size = Vector2i(800, 900)
	DirAccess.make_dir_recursive_absolute("res://logs/travel_review")
	var preview = Preview.new()
	preview.model_scene = load("res://assets/models/characters/races/human_male/character.tscn")
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(preview)
	for frame in range(3): await process_frame
	var character: Node3D = preview.character
	var rig: Skeleton3D = character.get_node("Skeleton3D")
	preview.animator.remove_animation_library("preview")
	preview.animator.add_animation_library("travel", Adapter.adapt(load("res://assets/animations/player_runtime/travel_animations.res"), rig, character.get_meta("animation_source_rests")))
	preview.animator.add_animation_library("combat", Adapter.adapt(load("res://assets/animations/player_runtime/protof_animations.tres"), rig, character.get_meta("animation_source_rests")))
	var player = load("res://scripts/player.gd").new()
	var attachment := BoneAttachment3D.new()
	rig.add_child(attachment)
	attachment.bone_name = "humanoid_ R Hand"
	attachment.add_child(player.create_weapon_visual("sword"))
	for clip in ["combat/unarmed_idle", "combat/sword_idle", "travel/carry_idle", "travel/sword_ready", "travel/fencing_breathe", "travel/fencing_idle", "travel/carry_run", "travel/carry_walk_forward", "travel/carry_sprint_forward_left", "travel/carry_sprint_forward_right"]:
		if not preview.animator.has_animation(clip):
			push_error("Review clip missing: " + clip); quit(1); return
		preview.pose_index = 0
		preview.animator.stop(); rig.reset_bone_poses()
		preview.animator.play(clip, 0)
		preview.animator.seek(.28, true); preview.animator.pause()
		for frame in range(3): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://logs/travel_review/" + clip.replace("/", "_") + ".png")
	for weapon in ["sword", "greatsword", "staff", "spear"]:
		for child in attachment.get_children():
			attachment.remove_child(child); child.free()
		attachment.add_child(player.create_weapon_visual(weapon))
		var clip: String = player.animation_profiles.default_entry(weapon, "idle").clip
		preview.animator.stop(); rig.reset_bone_poses()
		preview.animator.play(clip, 0); preview.animator.seek(.28, true); preview.animator.pause()
		preview.zoom = .75; preview._update_camera()
		for frame in range(3): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://logs/travel_review/idle_" + weapon + ".png")
	preview.queue_free()
	player.free()
	await process_frame
	quit()
