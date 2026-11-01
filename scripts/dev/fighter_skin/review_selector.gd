extends SceneTree
## Review the fixed-build race/gender selector, including pending concept art.
const OUTPUT := "res://logs/race_build/review/"
var failures := 0
func _initialize() -> void:
	call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func capture(name: String) -> void:
	for frame in range(3): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUTPUT + name + ".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUTPUT)
	for dimensions in [Vector2i(1100, 650), Vector2i(1600, 900), Vector2i(1920, 1080)]:
		root.content_scale_size = dimensions
		root.size = dimensions
		var menu = load("res://scripts/character_select.gd").new()
		menu.store = load("res://scripts/character_store.gd").new(OUTPUT + "unused_saves", OUTPUT + "missing_legacy.json")
		root.add_child(menu)
		for frame in range(3): await process_frame
		var bounds := root.get_visible_rect()
		for control in [menu.name_input, menu.race_input, menu.gender_input, menu.class_input, menu.create_button]:
			check(bounds.encloses(control.get_global_rect()), "Selection content fits " + str(dimensions) + ": " + str(control.name))
		await capture("selection_%dx%d" % [dimensions.x, dimensions.y])
		for race in range(5):
			for gender in range(2):
				if dimensions != Vector2i(1600, 900) and (race != 0 or gender != 0): continue
				menu.race_input.select(race); menu.gender_input.select(gender); menu._update_model_status()
				menu._open_creator()
				for frame in range(3): await process_frame
				check(bounds.encloses(menu.creator_panel.get_global_rect()), "Preview fits " + str(dimensions))
				await capture("race_%d_%d_%dx%d" % [race, gender, dimensions.x, dimensions.y])
				menu._close_creator()
				await process_frame
		menu.queue_free()
		await process_frame
	print("RACE SELECTOR REVIEW: ", failures, " failures; 3 viewport sizes; 10 race/gender previews")
	quit(failures)
