extends SceneTree

## Temporary parse gate: loads every script touched by the Map I overhaul.
## Run: godot --headless --path . --script res://tests/_parse.gd

func _init() -> void:
	var paths: Array[String] = [
		"res://scripts/world_builder.gd",
		"res://scripts/world_map.gd",
		"res://scripts/game_hud.gd",
		"res://scripts/main.gd",
		"res://scripts/player.gd",
		"res://scripts/enemy.gd",
		"res://scripts/game_log.gd",
	]
	var failures: int = 0
	for path: String in paths:
		var script: Script = load(path) as Script
		if script == null:
			failures += 1
			printerr("PARSE FAIL ", path)
		else:
			print("PARSE OK   ", path)
	print("failures=", failures)
	quit(1 if failures > 0 else 0)
