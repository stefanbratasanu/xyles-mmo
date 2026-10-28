extends SceneTree
const ROOT := "res://assets/animations/Ultimate Animation Collection/Animations/"
const OUT := "res://assets/animations/player_runtime/action_animations.tres"
func _initialize() -> void:
	var paths: Dictionary={
		"spear_thrust":"Fencing Animset/FBX Files/Humanoid@Attack1AForwardFencing.fbx",
		"staff_idle":"Wizard Animset/FBX Files/Humanoid@IdleWizard.fbx",
		"staff_run":"Wizard Animset/FBX Files/Humanoid@RunWizard.fbx",
		"staff_sprint":"Wizard Animset/FBX Files/Humanoid@SprintWizard.fbx",
	}
	var directions: Dictionary={"forward":"Forward","back":"Backwards","left":"Left","right":"Right","forward_left":"ForwardLeft","forward_right":"ForwardRight","back_left":"BackwardsLeft","back_right":"BackwardsRight"}
	for direction: String in directions:
		paths["staff_walk_"+direction]="Wizard Animset/FBX Files/Humanoid@Walk"+str(directions[direction])+"Wizard.fbx"
		if direction!="forward": paths["staff_run_"+direction]="Wizard Animset/FBX Files/Humanoid@Run"+str(directions[direction])+"Wizard.fbx"
	for pair: Array in [["sword","Sword&Shield Animset/FBX Motions/"],["wizard","Wizard Animset/FBX Files/"],["fencing","Fencing Animset/FBX Files/"]]:
		var directory:=DirAccess.open(ROOT+str(pair[1]))
		if directory==null: continue
		for filename: String in directory.get_files():
			if not filename.to_lower().ends_with(".fbx") or filename.get_basename().ends_with("_RM"): continue
			if not ("Attack" in filename or "CastSpell" in filename or "Block" in filename or "Parry" in filename): continue
			paths[str(pair[0])+"_"+filename.get_basename().trim_prefix("Humanoid@")]=str(pair[1])+filename
	var library:=AnimationLibrary.new()
	for key: String in paths:
		var path:=ROOT+str(paths[key])
		if not FileAccess.file_exists(path):
			print("SKIP missing ",path)
			continue
		var doc:=FBXDocument.new()
		var state:=FBXState.new()
		if doc.append_from_file(path,state)!=OK: push_error(path); quit(1); return
		var source:=doc.generate_scene(state)
		var player: AnimationPlayer=source.find_child("AnimationPlayer",true,false)
		if player==null or player.get_animation_list().is_empty(): source.free(); continue
		var animation: Animation=player.get_animation(player.get_animation_list()[0]).duplicate(true)
		animation.loop_mode=Animation.LOOP_LINEAR if key.begins_with("staff_") else Animation.LOOP_NONE
		# Remove authored root translations; the controller owns movement.
		for track in range(animation.get_track_count()-1,-1,-1):
			if animation.track_get_type(track)==Animation.TYPE_POSITION_3D and str(animation.track_get_path(track))=="Skeleton3D:humanoid_": animation.remove_track(track)
		library.add_animation(key,animation)
		source.free()
	print("Action library clips: ",library.get_animation_list().size())
	var error:=ResourceSaver.save(library,OUT)
	quit(error)
