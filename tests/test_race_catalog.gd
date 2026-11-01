extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var models = load("res://scripts/character_models.gd")
	var state = load("res://scripts/game_state.gd")
	var ids := {}
	for race in state.CHARACTER_RACES:
		for gender in state.CHARACTER_GENDERS:
			var entry: Dictionary = models.entry(race, gender)
			check(not entry.is_empty(), "Each race has male and female catalog entries")
			check(not ids.has(entry.id), "Model IDs are unique")
			ids[entry.id] = true
			check(models.concept(race, gender) != null, "Each model has its own concept reference")
			check(float(entry.height_m) > 1 and float(entry.height_m) < 2.5, "Authored race height is plausible")
			if entry.status != "reviewed":
				check(models.scene(race, gender) == null, "Pending race is never returned as a human scene")
	check(ids.size() == 10, "Five races have ten distinct model entries")
	var scene = load("res://assets/models/characters/human_fighter/head_revision/character.tscn")
	var tall = scene.instantiate()
	var short_actor = scene.instantiate()
	var tall_rig: Skeleton3D = tall.get_node("Skeleton3D")
	var short_rig: Skeleton3D = short_actor.get_node("Skeleton3D")
	var pelvis := short_rig.find_bone("humanoid_ Pelvis")
	var rest := short_rig.get_bone_rest(pelvis)
	rest.origin *= .65
	short_rig.set_bone_rest(pelvis, rest)
	var source = load("res://assets/animations/player_runtime/protof_animations.tres")
	var adapter = load("res://scripts/fighter_animation_adapter.gd")
	var tall_library: AnimationLibrary = adapter.adapt(source, tall_rig, tall.get_meta("animation_source_rests"))
	var short_library: AnimationLibrary = adapter.adapt(source, short_rig, short_actor.get_meta("animation_source_rests"))
	check(tall_library != short_library, "Different race proportions cannot share adapted translation tracks")
	check(tall_library == adapter.adapt(source, tall_rig, tall.get_meta("animation_source_rests")), "Identical rigs still share the animation cache")
	var tall_clip := tall_library.get_animation("unarmed_idle")
	var short_clip := short_library.get_animation("unarmed_idle")
	var path := NodePath("Skeleton3D:humanoid_ Pelvis")
	var tall_track := tall_clip.find_track(path, Animation.TYPE_POSITION_3D)
	var short_track := short_clip.find_track(path, Animation.TYPE_POSITION_3D)
	check(tall_track >= 0 and short_track >= 0, "Adapted rigs both have a pelvis position track")
	var delta: Vector3 = short_clip.track_get_key_value(short_track, 0) - tall_clip.track_get_key_value(tall_track, 0)
	check(delta.is_equal_approx(rest.origin - tall_rig.get_bone_rest(pelvis).origin), "Each race uses its own authored pelvis offset")
	tall.free(); short_actor.free()
	print("RACE CATALOG: ", failures, " failures; 10 model entries; race-aware animation cache")
	quit(failures)
