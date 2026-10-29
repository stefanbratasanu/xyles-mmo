extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	var config := ConfigFile.new()
	game._load_graphics_settings(config)
	assert(game.fps_limit == 60, "Existing settings default to 60 FPS")
	game._apply_graphics_settings()
	assert(Engine.max_fps == 60, "Default FPS cap must be applied")
	config.set_value("graphics", "fps_limit", 35)
	game._load_graphics_settings(config)
	game._apply_graphics_settings()
	assert(game.fps_limit == 35 and Engine.max_fps == 35, "Saved FPS cap must load and apply")
	var saved := ConfigFile.new()
	game._store_graphics_settings(saved)
	assert(saved.get_value("graphics", "fps_limit") == 35, "FPS cap must persist")
	game.set_fps_limit(4)
	assert(game.fps_limit == 20 and Engine.max_fps == 20, "FPS cap lower bound")
	game.set_fps_limit(200)
	assert(game.fps_limit == 60 and Engine.max_fps == 60, "FPS cap upper bound")
	game.hud.toggle_panel("settings")
	var slider := game.hud.find_child("FrameRateLimit", true, false) as HSlider
	assert(slider != null and slider.min_value == 20 and slider.max_value == 60, "FPS slider missing")
	slider.value = 30
	assert(game.fps_limit == 30 and Engine.max_fps == 30, "FPS slider must apply immediately")
	game.reset_settings()
	assert(game.fps_limit == 60 and Engine.max_fps == 60, "Reset restores 60 FPS")
	game.queue_free()
	await process_frame
	print("GRAPHICS PERFORMANCE: PASS")
	quit()
