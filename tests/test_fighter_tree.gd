extends SceneTree
var failures := 0
func check(value: bool, description: String) -> void:
	if not value: failures+=1; push_error(description)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var game: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode=true
	var state: Node=game.state
	state.character_class="Fighter"
	for level in range(1,5):
		state.level=level
		check(state.is_skill_available("fighter_cleave") and state.is_skill_available("fighter_bow"),"Level 1 skills")
		check(state.is_skill_available("fighter_guard")== (level>=2),"Guard level")
		check(state.is_skill_available("fighter_dash")== (level>=3),"Dash level")
		check(state.is_skill_available("fighter_cone")== (level>=4),"Cone level")
	state.level=1
	check(not state.assign_hotbar("fighter_dash",0),"Cannot equip locked skill")
	check(state.assign_hotbar("fighter_cleave",0),"Equip unlocked skill")
	check(state.get_skill_offers("fighter_cleave",0).is_empty(),"Fighter skill has no enchantments")
	check(state.assign_hotbar("action:attack",1),"Assign basic action")
	game.hud.toggle_panel("skills")
	await process_frame
	check(game.hud.overlay_title.text=="Fighter skill tree","Fighter tree opens")
	var path="res://.godot/fighter-tree-test.json"
	check(state.save_game(path),"Save")
	var loaded: Node=load("res://scripts/game_state.gd").new()
	check(loaded.load_game(path),"Load")
	check(loaded.loadout[0]=="fighter_cleave" and loaded.loadout[1]=="action:attack","Saved assignments survive")
	loaded.free()
	game.queue_free()
	await process_frame
	print("FIGHTER TREE: ",failures," failures")
	quit(failures)
