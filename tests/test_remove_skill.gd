extends SceneTree
const State = preload("res://scripts/game_state.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.test_mode = true
	for enemy: Node in game.enemies: enemy.aggro=false; enemy.set_physics_process(false)
	var state: Node = game.state
	state.earned_skill_points=10; state.skill_points=10
	check(state.install_evolution("melee",0,0),"Install first skill upgrade")
	check(state.install_evolution("cast",0,0),"Install other skill upgrade")
	var saved_offer: Array=state.get_skill_offers("melee",0).duplicate(true)
	game.hud.toggle_panel("skills")
	await process_frame
	game.hud.skill_view._remove_skill(0)
	check(state.loadout[0]=="" and state.skill_points==9,"Slot emptied and one point refunded")
	check(state.skills.cast.evolutions.size()==1,"Other skill keeps upgrade")
	check(state.learned_skills.has("melee"),"Removed skill remains learned")
	check(state.get_skill_offers("melee",0)==saved_offer,"Offers retained")
	check(not game.skill_runtime.cast_slot(0),"Empty slot cannot cast")
	var path: String="res://.godot/remove-skill-test.json"
	check(state.save_game(path),"Save")
	var restored: Node=State.new()
	check(restored.load_game(path),"Load")
	check(restored.loadout[0]=="" and restored.skill_points==9,"Empty slot and refund persist")
	check(restored.equip_skill("melee",0) and restored.loadout[0]=="melee","Re-equip learned skill")
	check(restored.remove_skill(0)==0 and restored.remove_skill(0)==-1 and restored.skill_points==9,"No duplicate refund")
	restored.free()
	game.queue_free()
	await process_frame
	print("REMOVE SKILL: ",failures," failures")
	quit(failures)
