extends SceneTree
const BASE := "res://assets/animations/Ultimate Animation Collection/Animations/Campfire Animset/FBX Files/Humanoid@"
const CLIPS := {"enter": "StandToKneelCampfire", "down": "KneelToSitCampfire", "idle": "IdleSitCampfire", "exit": "IdleSitToIdleKneelCampfire", "stand": "IdleKneelToStandCampfire"}
func _initialize() -> void:
	var library := AnimationLibrary.new()
	for key: String in CLIPS:
		var document := FBXDocument.new()
		var state := FBXState.new()
		if document.append_from_file(BASE + CLIPS[key] + ".fbx", state) != OK:
			quit(1)
			return
		var scene := document.generate_scene(state)
		var player := scene.find_child("AnimationPlayer", true, false) as AnimationPlayer
		var clip: Animation = player.get_animation(player.get_animation_list()[0]).duplicate(true)
		clip.loop_mode = Animation.LOOP_LINEAR if key == "idle" else Animation.LOOP_NONE
		library.add_animation(key, clip)
		scene.free()
	var error := ResourceSaver.save(library, "res://assets/animations/player_runtime/sit_animations.tres")
	print("Sitting animations saved: ", error)
	quit(error)
