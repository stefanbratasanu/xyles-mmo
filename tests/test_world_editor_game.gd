extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	var zone_id := "zone_0123456789abcdef0123456789abcdef"
	game.set_meta("editor_map_payload", {"format": 1, "clear_base": false, "terrain": null, "placements": [{"asset": "fence", "position": [-20.0, 2.0, 10.0], "rotation": 0.5, "scale": 1.0}], "zones": [{"id": zone_id, "name": "Enemy field", "kind": "enemy", "level_min": 7, "level_max": 9, "cells": [[-3, 5]]}]})
	root.add_child(game)
	await process_frame
	var fence: Node3D = game.world.get_node_or_null("Placed_fence")
	assert(fence != null)
	assert(absf(fence.position.x + 20.0) < 0.001)
	assert(not fence.find_children("*", "CollisionShape3D", true, false).is_empty())
	assert(not game.world._vegetation_paths.is_empty())
	var enemy = game._spawn_enemy("normal", game.world.normal_spawns[0], 0, "wolf")
	assert(enemy.level == 8)
	game.enemy_defeated(enemy)
	assert(game.state.bestiary.has(zone_id + ":normal"))
	assert(game.state.bestiary[zone_id + ":normal"]["points_awarded"] == 2)
	game.queue_free()
	await process_frame
	print("PASS: game startup applies an editor snapshot without replacing the original world")
	quit()
