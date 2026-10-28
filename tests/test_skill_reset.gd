extends SceneTree
class IsolatedSaveGame extends "res://scripts/main.gd":
	func _save_journey() -> bool:
		return state.save_game("res://.godot/reset-regression-save.json")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("_run")
func click(button: Button) -> void:
	var point:=button.get_global_rect().get_center()
	var move:=InputEventMouseMotion.new(); move.position=point; move.global_position=point
	Input.parse_input_event(move)
	await process_frame
	var event:=InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT; event.position=point; event.global_position=point; event.pressed=true
	Input.parse_input_event(event)
	await process_frame
	event=event.duplicate(); event.pressed=false
	Input.parse_input_event(event)
	await process_frame
func find_reset(node: Node) -> Button:
	if node is Button and node.text.begins_with("RESET ALL"): return node
	for child: Node in node.get_children():
		var found:=find_reset(child)
		if found!=null: return found
	return null
func _run() -> void:
	root.size=Vector2i(1600,900)
	var game: Node=load("res://scenes/main.tscn").instantiate()
	game.set_script(IsolatedSaveGame)
	root.add_child(game)
	game.set_process(false); game.player.set_physics_process(false)
	for enemy: Node in game.enemies: enemy.set_physics_process(false); enemy.aggro=false
	game.test_mode=false
	game.state.earned_skill_points=10
	game.state.skills.cast.history=[0,0,1,2,2,1,2]
	game.state.skills.support.history=[1,1,0]
	game.state._restore_evolutions({})
	var retained: Array=game.state.get_skill_offers("cast",0).duplicate(true)
	check(game.state.skill_points==0,"Ten legacy upgrades consume ten points")
	game.hud.toggle_panel("skills")
	for i in range(5): await process_frame
	var button:=find_reset(game.hud.overlay_content)
	check(button!=null,"Reset button exists")
	game.enemies[0].aggro=true
	game.hud.refresh()
	button=find_reset(game.hud.overlay_content)
	check(button.disabled and game.hud.skill_view.edit_status.text.contains("combat"),"Combat lock is visible")
	game.hud.skill_view._reset()
	check(game.state.skill_points==0,"Combat cannot reset upgrades")
	check(game.hud.toast.get_index()>game.hud.overlay.get_index(),"Restriction message appears above skill window")
	game.enemies[0].aggro=false
	game.hud.refresh()
	button=find_reset(game.hud.overlay_content)
	check(not button.disabled,"Reset automatically re-enables after combat")
	game.block_time=3.0; game.support_time=2.0
	if button!=null:
		var scroll: ScrollContainer=game.hud.overlay_content.get_parent()
		scroll.ensure_control_visible(button)
		for i in range(3): await process_frame
		await click(button)
	check(game.state.skill_points==10,"Real mouse click refunds ten legacy points")
	check(game.state.skills.cast.evolutions.is_empty() and game.state.skills.support.evolutions.is_empty(),"Real mouse click clears upgrades")
	check(game.block_time==0 and game.support_time==0,"Reset removes temporary skill effects")
	check(game.state.get_skill_offers("cast",0)==retained,"Reset retains discovered choices")
	check(game.hud.toast.text.contains("10 points refunded"),"Visible completion feedback")
	var restored: Node=load("res://scripts/game_state.gd").new()
	check(restored.load_game("res://.godot/reset-regression-save.json"),"Reset saves immediately")
	check(restored.skill_points==10 and restored.skills.cast.evolutions.is_empty(),"Reset persists on restart")
	check(game.hud.skill_view.reset_button.disabled,"Empty reset cannot be repeated for points")
	restored.free()
	print("SKILL RESET: ",failures," failures")
	game.queue_free()
	await process_frame
	quit(failures)
