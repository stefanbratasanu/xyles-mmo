extends SceneTree
## Measure low-foot travel in each retargeted loop, rather than assuming human strides.
const Adapter = preload("res://scripts/fighter_animation_adapter.gd")
const Motions = preload("res://assets/animations/player_runtime/travel_animations.res")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var result := {}
	var report := {}
	var manifest = JSON.parse_string(FileAccess.get_file_as_string("res://resources/characters/race_models.json"))
	for model in manifest.models:
		var actor = load(model.scene).instantiate()
		root.add_child(actor)
		var rig: Skeleton3D = actor.get_node("Skeleton3D")
		var animator: AnimationPlayer = actor.get_node("AnimationPlayer")
		animator.add_animation_library("stride", Adapter.adapt(Motions, rig, actor.get_meta("animation_source_rests")))
		var sensors: Array[int] = []
		for name in ["humanoid_ R Foot", "humanoid_ R Toe0", "humanoid_ L Foot", "humanoid_ L Toe0"]: sensors.append(rig.find_bone(name))
		result[model.id] = {}
		report[model.id] = {}
		for key in Motions.get_animation_list():
			if not (key.begins_with("walk_") or key.begins_with("run") or key.begins_with("sprint") or key == "jog"): continue
			var clip := Motions.get_animation(key)
			var steps := maxi(40, ceili(clip.length * 60))
			var positions: Array = [[], [], [], []]
			var lows := [INF, INF, INF, INF]
			for sample in range(steps):
				animator.stop(); rig.reset_bone_poses()
				animator.play("stride/" + key, 0)
				animator.seek(clip.length * sample / steps, true)
				rig.force_update_all_bone_transforms()
				for sensor in range(4):
					var point := rig.get_bone_global_pose(sensors[sensor]).origin
					positions[sensor].append(point)
					lows[sensor] = minf(lows[sensor], point.y)
			var speeds: Array[float] = []
			for sensor in range(4):
				for sample in range(1, steps - 1):
					var point: Vector3 = positions[sensor][sample]
					if point.y > float(lows[sensor]) + .025 * float(model.height_m) / 1.8: continue
					var velocity: Vector3 = (positions[sensor][sample+1] - positions[sensor][sample-1]) / (2 * clip.length / steps)
					var speed := Vector2(velocity.x, velocity.z).length()
					if speed > .08: speeds.append(speed)
			if speeds.size() < 8:
				push_error("Insufficient stance samples for " + str(model.id) + "/" + key); quit(1); return
			speeds.sort()
			var speed := speeds[speeds.size() / 2]
			result[model.id][key] = speed
			report[model.id][key] = {"speed":speed, "contact_samples":speeds.size(), "p25":speeds[speeds.size()/4], "p75":speeds[speeds.size()*3/4]}
		actor.free()
		print("STRIDE CALIBRATION ", model.id, ": ", result[model.id])
	var file := FileAccess.open("res://assets/animations/player_runtime/travel_strides.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(result, "  ") + "\n"); file.close()
	file = FileAccess.open("res://logs/travel_calibration_report.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  ") + "\n"); file.close()
	quit()
