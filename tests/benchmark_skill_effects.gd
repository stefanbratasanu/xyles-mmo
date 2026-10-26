extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	for effect in ["move", "cast", "reward"]:
		var start := Time.get_ticks_usec()
		for i in range(20):
			game.audio.cue(effect)
		print("AUDIO %s average_ms=%.3f" % [effect, (Time.get_ticks_usec() - start) / 20000.0])
	var start := Time.get_ticks_usec()
	for i in range(20):
		game.burst(Vector3.ZERO, Color.ORANGE)
	print("BURST average_ms=%.3f" % ((Time.get_ticks_usec() - start) / 20000.0))
	await create_timer(1.2).timeout
	game.queue_free()
	await process_frame
	quit()
