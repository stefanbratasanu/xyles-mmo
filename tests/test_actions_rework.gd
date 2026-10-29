extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var game: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	var state: Node=game.state
	for id: String in state.skill_catalog.data.modifiers:
		check(not state.skill_catalog.data.modifiers[id].enabled,"Disabled "+id)
	check(state.get_skill_offers("melee",0).is_empty(),"No offers while disabled")
	check(not state.skill_offers.has("melee:0"),"Empty offers are not permanently cached")
	game.hud.toggle_panel("actions")
	await process_frame
	check(game.hud.overlay_title.text=="Actions","Actions opens")
	check(game.hud.overlay_content.get_child_count()==6,"Three action groups")
	for enemy: Node in game.enemies: enemy.set_physics_process(false)
	game.player.set_physics_process(false)
	var enemy: Node3D=game.enemies[0]
	enemy.global_position=game.player.global_position+Vector3(0,0,-2)
	enemy.max_hp=10000; enemy.hp=10000; game.target=enemy
	game.hud._perform_action("attack")
	check(enemy.hp<10000,"Action attack damages target")
	game.queue_free()
	await process_frame
	print("ACTIONS REWORK: ",failures," failures")
	quit(failures)
