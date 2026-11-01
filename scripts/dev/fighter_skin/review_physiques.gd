extends SceneTree
## Render the actual creator preview with isolated empty roster paths.
## --all-presets captures 25 builds from the front and side; otherwise corners.
const OUTPUT := "res://logs/physique_rebuild/"
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	var menu = load("res://scripts/character_select.gd").new()
	menu.store = load("res://scripts/character_store.gd").new(OUTPUT + "unused_saves", OUTPUT + "no_legacy.json")
	root.add_child(menu)
	await process_frame
	menu._open_creator()
	var viewport: SubViewport = menu.preview.viewport
	await process_frame
	viewport.size = Vector2i(660, 780)
	var sizes := [0, 2, 4]
	var muscles := [0, 4]
	if OS.get_cmdline_user_args().has("--all-presets"):
		sizes = [0, 1, 2, 3, 4]
		muscles = [0, 1, 2, 3, 4]
	for size in sizes:
		for muscle in muscles:
			menu.preview_character.body_size = size
			menu.preview_character.muscularity = muscle
			for side in range(2):
				menu.preview_character.rotation.y = PI + side * PI / 2
				for frame in range(3): await process_frame
				await RenderingServer.frame_post_draw
				viewport.get_texture().get_image().save_png(OUTPUT + "preset_%d_%d_%d.png" % [size, muscle, side])
	print("PHYSIQUE REVIEW: ", sizes.size() * muscles.size(), " builds captured from front/profile")
	menu.queue_free()
	await process_frame
	quit()
