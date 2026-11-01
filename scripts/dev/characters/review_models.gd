extends SceneTree
## Review built race scenes before their catalog status becomes playable.
const Preview = preload("res://scripts/character_appearance_preview.gd")
const OUTPUT := "res://logs/race_build/rendered/"
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	root.size = Vector2i(900, 1000)
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://resources/characters/race_models.json"))
	var captured := 0
	for model in manifest.models:
		if not OS.get_cmdline_user_args().is_empty() and model.id not in OS.get_cmdline_user_args(): continue
		var path := "res://assets/models/characters/races/" + str(model.id) + "/character.tscn"
		if model.id == "human_male" and not ResourceLoader.exists(path): path = model.scene
		if not ResourceLoader.exists(path): continue
		var preview = Preview.new()
		preview.model_scene = load(path)
		preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(preview)
		for frame in range(3): await process_frame
		preview.set_outfit_visible(true)
		for angle in [0, -90, 90, 180]:
			preview.set_yaw_degrees(angle)
			for frame in range(3): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUTPUT + "%s_body_%d.png" % [model.id, angle])
		preview.set_portrait(true)
		for angle in [0, -90, 90]:
			preview.set_yaw_degrees(angle)
			for frame in range(3): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUTPUT + "%s_face_%d.png" % [model.id, angle])
		preview.reset_view()
		for pose in range(1, 4):
			preview.set_pose(pose)
			preview.animator.seek(.28, true)
			preview.animator.pause()
			for frame in range(3): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png(OUTPUT + "%s_pose_%d.png" % [model.id, pose])
		preview.queue_free()
		await process_frame
		captured += 1
	print("RACE MODEL REVIEW: ", captured, " models, 10 views each")
	quit()
