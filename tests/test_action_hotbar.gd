extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	if not value: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var game: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode=true
	for enemy: Node in game.enemies: enemy.aggro=false; enemy.set_physics_process(false)
	game.hud.toggle_panel("actions")
	for i in range(3): await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/actions-icon-preview.png")
	var found: Array=[]
	for child: Node in game.hud.overlay_content.get_children():
		if child is GridContainer:
			for button: Button in child.get_children():
				check(button.icon != null,"Every action has artwork")
				check(button.drag_payload.get("kind","")=="hotbar","Action has drag payload")
				found.append(button.drag_payload.id)
				check(game.hud.hotbar[0]._can_drop_data(Vector2.ZERO,button.drag_payload),"Hotbar accepts "+str(button.drag_payload.id))
				game.hud.hotbar[0]._drop_data(Vector2.ZERO,button.drag_payload)
				check(game.state.loadout[0]==button.drag_payload.id,"Drop assigns "+str(button.drag_payload.id))
	check(found.size()==game.state.ACTION_IDS.size(),"Every action is covered")
	var path: String="res://.godot/action-hotbar-test.json"
	check(game.state.save_game(path),"Save")
	var state: Node=load("res://scripts/game_state.gd").new()
	check(state.load_game(path) and state.loadout[0]=="action:dance","Dance slot survives reload")
	state.free()
	game.hud.close_panel()
	game.hud._perform_action("party_invite")
	check(game.hud.toast.text.contains("not available"),"Party placeholder is explicit")
	game.queue_free()
	await process_frame
	print("ACTION HOTBAR: ",failures," failures")
	quit(failures)
