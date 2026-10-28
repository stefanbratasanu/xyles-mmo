extends SceneTree
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("_run")
func resolved(game: Node,id: String,chance: float) -> Dictionary:
	var m: Dictionary=game.state.skill_catalog.data.modifiers[id].duplicate(true)
	m.id=id; m.event="ON_ENEMY_HIT_THIS_SKILL"; m.chance=chance
	m.stat=m.stats.keys()[0] if not m.stats.is_empty() else ""
	for key: String in m.values: m.values[key]=float(m.values[key][0])
	return m
func _run() -> void:
	var game: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.set_process(false); game.player.set_physics_process(false)
	var runtime: Node=game.skill_runtime
	runtime.set_physics_process(false)
	game.state.skill_catalog=game.state.skill_catalog.duplicate(true)
	game.state.skill_catalog.data.rules.critical_chance=0
	game.player.global_position=Vector3(30,0,30)
	for index in range(game.enemies.size()):
		var e: Node3D=game.enemies[index]
		e.set_physics_process(false); e.aggro=false; e.max_hp=10000; e.hp=10000
		e.global_position=Vector3(30+index,0,26) if index<2 else Vector3(100+index*3,0,100)
	await physics_frame
	var a: Node3D=game.enemies[0]
	var b: Node3D=game.enemies[1]
	var burst:=resolved(game,"chance_burst",0)
	game.state.skills.cast.evolutions=[burst]; game.state.compiled_skills.clear()
	var context: Dictionary=runtime._context("cast")
	runtime.hit(context,a)
	check(b.hp==10000,"0% chance never triggers")
	check(runtime.debug_stats.cast.parts.chance_burst.attempts==1 and runtime.debug_stats.cast.parts.chance_burst.procs==0,"Failed proc measured")
	burst.chance=1; burst.values.amount=.5; burst.values.radius=3
	game.state.compiled_skills.clear(); runtime.clear_debug_stats()
	context=runtime._context("cast")
	var power: float=context.power
	runtime.hit(context,a)
	var parts: Dictionary=runtime.debug_stats.cast.parts
	check(is_equal_approx(parts.base.damage,power*.92),"Base measured damage matches actual mitigation")
	check(is_equal_approx(parts.chance_burst.damage,power*.92),"Burst measured separately across two targets")
	check(parts.chance_burst.procs==1 and parts.chance_burst.hits==2,"Proc and area hit counts")
	check(runtime.event_queue.is_empty(),"Secondary burst cannot recurse")
	var debug: String=load("res://scripts/skills/skill_debug.gd").report(game,"cast")
	check(debug.contains("chance to release an area burst") and debug.contains("Total actual damage"),"Debug explains trigger and actual totals")
	check(game.state.skill_catalog.describe(burst).contains("100% chance to"),"Player-facing chance wording")
	# A secondary projectile can damage another enemy but cannot trigger another on-hit effect.
	runtime.clear_combat(); runtime.clear_debug_stats()
	var bolt:=resolved(game,"chance_bolt",1)
	game.state.skills.cast.evolutions=[bolt]; game.state.compiled_skills.clear()
	runtime.hit(runtime._context("cast"),a)
	for i in range(90): runtime._physics_process(1.0/60)
	check(runtime.projectiles.is_empty(),"Secondary projectile terminates")
	check(runtime.debug_stats.cast.parts.chance_bolt.hits==1 and runtime.debug_stats.cast.parts.chance_bolt.procs==1,"Secondary projectile attributed to its enchantment without recursion")
	# Rolled chance is saved in each offer and controlled by authored min/max.
	var seen:=false
	for seed_value in range(100):
		for offer: Dictionary in game.state.skill_catalog.offers("cast",[],seed_value):
			if offer.has("chance_range"):
				seen=true
				check(offer.chance>=offer.chance_range[0] and offer.chance<=offer.chance_range[1],"Chance roll lies within authored bounds")
	check(seen,"Chance enchantments occur in the shipped pool")
	game.hud.toggle_panel("skills")
	game.hud.skill_view.debug_mode=true
	game.hud._render_overlay()
	for i in range(3): await process_frame
	check(game.hud.skill_view.debug_label.text.contains("Splintering Contact"),"K debug view includes installed effect")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/skill-debug-preview.png")
	print("CHANCE AND DEBUG: ",failures," failures")
	game.queue_free()
	await process_frame
	quit(failures)
