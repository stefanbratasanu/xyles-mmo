extends SceneTree

const ROOT := "res://assets/animations/Ultimate Animation Collection/"
const BASE := ROOT + "Animations/"
const OUT := "res://assets/animations/player_runtime/"
const CLIPS := {
	"sword_idle": "Sword&Shield Animset/FBX Motions/Humanoid@IdleCombatS&S.fbx",
	"sword_run": "Sword&Shield Animset/FBX Motions/Humanoid@RunNormalS&S.fbx",
	"sword_attack": "Sword&Shield Animset/FBX Motions/Humanoid@SwordAttack1S&S.fbx",
	"sword_block": "Sword&Shield Animset/FBX Motions/Humanoid@BlockLightS&S.fbx",
	"greatsword_idle": "2Handed Melee Weapon Animset/FBX Files/Humanoid@IdleCombatA2HandMelee.fbx",
	"greatsword_run": "2Handed Melee Weapon Animset/FBX Files/Humanoid@RunNormal2HandMelee.fbx",
	"greatsword_sprint": "2Handed Melee Weapon Animset/FBX Files/Humanoid@Sprint2HandMelee.fbx",
	"sword_sprint": "Sword&Shield Animset/FBX Motions/Humanoid@RunFastNormalS&S.fbx",
	"unarmed_sprint": "Basic Locomotion Animset/FBX Motions/Humanoid@SprintForwardUnarmed.FBX",
	"greatsword_attack": "2Handed Melee Weapon Animset/FBX Files/Humanoid@AttackA2HandMelee.fbx",
	"greatsword_block": "2Handed Melee Weapon Animset/FBX Files/Humanoid@Blocked2HandMelee.fbx",
	"wizard_cast": "Wizard Animset/FBX Files/Humanoid@CastSpell6Wizard.fbx",
	"wizard_support": "Wizard Animset/FBX Files/Humanoid@CastSpell3Wizard.fbx",
	"unarmed_idle": "Combat Bare Fists Animset/FBX Motions/Humanoid@IdleCombat.fbx",
	"unarmed_run": "Combat Bare Fists Animset/FBX Motions/Humanoid@RunForwardCombat.fbx",
	"unarmed_attack": "Combat Bare Fists Animset/FBX Motions/Humanoid@Jab1.fbx",
	"unarmed_block": "Combat Bare Fists Animset/FBX Motions/Humanoid@BlockedHigh.fbx",
	"dodge": "Combat Bare Fists Animset/FBX Motions/Humanoid@DodgeForwardCombat.fbx",
	"death": "Combat Bare Fists Animset/FBX Motions/Humanoid@DeathFrontCombat.fbx",
	"crouch_idle": "Basic Locomotion Animset/FBX Motions/Humanoid@CrouchIdleBreathe1Unarmed.fbx",
	"jump": "Basic Locomotion Animset/FBX Motions/Humanoid@JumpToApexUnarmed.FBX",
	"fall": "Basic Locomotion Animset/FBX Motions/Humanoid@FallingUnarmed.FBX",
	"land": "Basic Locomotion Animset/FBX Motions/Humanoid@LandingLightUnarmed.FBX",
}
const PROPS := {
	"sword": "Sword&Shield Animset/Props/FBX Files/SM_1HandedSwordProp.fbx",
	"shield": "Sword&Shield Animset/Props/FBX Files/SM_ShieldProp.fbx",
	"greatsword": "2Handed Melee Weapon Animset/Prop/FBX Files/SM_2HandedSwordProp.fbx",
	"staff": "Wizard Animset/Prop/FBX Files/SM_WizardStaffProp.fbx",
}
const PROP_TEXTURES := {
	"sword": "Sword&Shield Animset/Props/Textures/T_Sword&Shield_BaseColor.png",
	"shield": "Sword&Shield Animset/Props/Textures/T_Sword&Shield_BaseColor.png",
	"greatsword": "2Handed Melee Weapon Animset/Prop/Textures/T_2HandedSwordProp_BaseColor.png",
	"staff": "Wizard Animset/Prop/Textures/T_WizardStaffProp_BaseColor.png",
}

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var character := load_fbx(ROOT + "Character/Protof-Actor/FBX Files/SK_Protof-Actor.fbx")
	if character == null:
		push_error("Could not load Protof character")
		quit(1)
		return
	apply_texture(character, ROOT + "Character/Protof-Actor/Textures/T_AverageHuman_BaseColor.png", "character")
	var character_scene := PackedScene.new()
	if character_scene.pack(character) != OK or ResourceSaver.save(character_scene, OUT + "character.tscn") != OK:
		push_error("Could not save character scene")
		quit(1)
		return
	var library := AnimationLibrary.new()
	character.free()
	var authored_speeds := {}
	var clips: Dictionary = CLIPS.duplicate()
	# Keep every supplied in-place two-handed clip available by its FBX name.
	var greatsword_folder := "2Handed Melee Weapon Animset/FBX Files/"
	var greatsword_directory := DirAccess.open(BASE + greatsword_folder)
	if greatsword_directory == null:
		push_error("Could not open the two-handed animation folder")
		quit(1)
		return
	for filename: String in greatsword_directory.get_files():
		if filename.begins_with("Humanoid@") and filename.to_lower().ends_with(".fbx") and not filename.get_basename().ends_with("_RM"):
			clips["greatsword_" + filename.get_basename().trim_prefix("Humanoid@")] = greatsword_folder + filename
	var direction_names := {
		"back": "Backwards", "left": "Left", "right": "Right",
		"forward_left": "ForwardLeft", "forward_right": "ForwardRight",
		"back_left": "BackwardsLeft", "back_right": "BackwardsRight",
	}
	var sets := {
		"sword": ["Sword&Shield Animset/FBX Motions/", "S&S"],
		"greatsword": ["2Handed Melee Weapon Animset/FBX Files/", "Combat2HandMelee"],
		"unarmed": ["Combat Bare Fists Animset/FBX Motions/", "Combat"],
	}
	for style: String in sets:
		var folder: String = sets[style][0]
		var suffix: String = sets[style][1]
		for direction: String in direction_names:
			var name: String = direction_names[direction]
			clips["%s_run_%s" % [style, direction]] = folder + "Humanoid@Run" + name + suffix + ".fbx"
			clips["%s_walk_%s" % [style, direction]] = folder + "Humanoid@Walk" + name + suffix + ".fbx"
		clips["%s_walk_forward" % style] = folder + "Humanoid@WalkForward" + suffix + ".fbx"
	var crouch_folder := "Basic Locomotion Animset/FBX Motions/Humanoid@Crouch"
	clips["crouch_forward"] = crouch_folder + "ForwardUnarmed.fbx"
	for direction: String in direction_names:
		clips["crouch_" + direction] = crouch_folder + str(direction_names[direction]) + "Unarmed.fbx"
	for clip_name: String in clips:
		var source := load_fbx(BASE + clips[clip_name])
		if source == null:
			push_error("Could not load " + clips[clip_name])
			quit(1)
			return
		var source_player := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if source_player == null or source_player.get_animation_list().is_empty():
			push_error("Missing animation: " + clip_name)
			quit(1)
			return
		var animation: Animation = source_player.get_animation(source_player.get_animation_list()[0]).duplicate(true)
		# The controller applies jump motion. Keep the imported root in place so
		# the clip doesn't add a second vertical jump on top of physics.
		if clip_name in ["jump", "fall", "land"] or (clip_name.begins_with("greatsword_") and ("JumpToApex" in clip_name or "Falling" in clip_name or "Landing" in clip_name)):
			for track in range(animation.get_track_count() - 1, -1, -1):
				if animation.track_get_type(track) == Animation.TYPE_POSITION_3D and str(animation.track_get_path(track)) == "Skeleton3D:humanoid_":
					animation.remove_track(track)
		var loop_clip: bool = clip_name.ends_with("_idle") or clip_name.ends_with("_run") or clip_name.ends_with("_sprint") or "_run_" in clip_name or "_walk_" in clip_name or clip_name.begins_with("crouch_") or clip_name == "fall"
		if clip_name.begins_with("greatsword_"):
			var source_name := clip_name.trim_prefix("greatsword_")
			loop_clip = loop_clip or source_name.begins_with("Idle") or source_name.begins_with("Walk") or source_name.begins_with("Run") or source_name.begins_with("Sprint") or source_name.begins_with("Crouch") or source_name.begins_with("Falling") or source_name.begins_with("Dead")
		animation.loop_mode = Animation.LOOP_LINEAR if loop_clip else Animation.LOOP_NONE
		library.add_animation(clip_name, animation)
		if clip_name.ends_with("_run") or clip_name.ends_with("_sprint") or "_run_" in clip_name or "_walk_" in clip_name or (clip_name.begins_with("crouch_") and clip_name != "crouch_idle") or clip_name.begins_with("greatsword_Crouch"):
			var fbx_path: String = BASE + clips[clip_name]
			var root_motion_path := fbx_path.get_basename() + "_RM." + fbx_path.get_extension()
			if FileAccess.file_exists(root_motion_path):
				var rate := get_authored_speed(root_motion_path)
				if rate > 0.05:
					authored_speeds[clip_name] = rate
		print("Imported ", clip_name, " tracks=", animation.get_track_count())
		source.free()
	if ResourceSaver.save(library, OUT + "protof_animations.tres") != OK:
		push_error("Could not save animation library")
		quit(1)
		return
	var speed_file := FileAccess.open(OUT + "authored_speeds.json", FileAccess.WRITE)
	if speed_file == null:
		push_error("Could not save animation speeds")
		quit(1)
		return
	speed_file.store_string(JSON.stringify(authored_speeds, "  "))
	speed_file.close()
	for prop_name: String in PROPS:
		var prop := load_fbx(BASE + PROPS[prop_name])
		if prop == null:
			push_error("Could not import prop: " + prop_name)
			quit(1)
			return
		apply_texture(prop, BASE + PROP_TEXTURES[prop_name], prop_name)
		var packed := PackedScene.new()
		if packed.pack(prop) != OK or ResourceSaver.save(packed, OUT + prop_name + ".tscn") != OK:
			push_error("Could not save prop: " + prop_name)
			quit(1)
			return
		prop.free()
	quit()

func load_fbx(path: String) -> Node:
	var doc := FBXDocument.new()
	var state := FBXState.new()
	if doc.append_from_file(path, state) != OK:
		return null
	return doc.generate_scene(state)

func get_authored_speed(path: String) -> float:
	var source := load_fbx(path)
	if source == null:
		return 0.0
	var source_player := source.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var rate := 0.0
	if source_player != null and not source_player.get_animation_list().is_empty():
		var animation: Animation = source_player.get_animation(source_player.get_animation_list()[0])
		for track in animation.get_track_count():
			if animation.track_get_type(track) == Animation.TYPE_POSITION_3D and str(animation.track_get_path(track)) == "Skeleton3D:root" and animation.track_get_key_count(track) > 1:
				var first: Vector3 = animation.track_get_key_value(track, 0)
				var last: Vector3 = animation.track_get_key_value(track, animation.track_get_key_count(track) - 1)
				var delta := last - first
				rate = Vector2(delta.x, delta.z).length() / maxf(animation.length, 0.001)
				break
	source.free()
	return rate

func apply_texture(node: Node, path: String, asset_name: String) -> void:
	if not FileAccess.file_exists(path):
		return
	var image := Image.load_from_file(path)
	if image == null:
		return
	var texture := ImageTexture.create_from_image(image)
	var texture_path := OUT + asset_name + "_texture.res"
	if ResourceSaver.save(texture, texture_path, ResourceSaver.FLAG_COMPRESS) != OK:
		push_error("Could not save texture: " + texture_path)
		return
	texture.take_over_path(texture_path)
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.roughness = 0.8
	set_material(node, material)

func set_material(node: Node, material: Material) -> void:
	if node is MeshInstance3D:
		node.material_override = material
	for child in node.get_children():
		set_material(child, material)
