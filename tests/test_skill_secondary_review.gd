extends SceneTree
var failures:=0
func check(ok: bool,message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("_run")
func resolved(game: Node,id: String,event: String) -> Dictionary:
	var m: Dictionary=game.state.skill_catalog.data.modifiers[id].duplicate(true)
	m.id=id; m.event=event; m.chance=1.0; m.icd=0.0
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
	for i in range(game.enemies.size()):
		var e: Node3D=game.enemies[i]
		e.set_physics_process(false); e.aggro=false; e.max_hp=10000; e.hp=10000
		e.global_position=Vector3(31+i,0,30) if i<2 else Vector3(100+i*3,0,100)
	await physics_frame
	var arrival:=resolved(game,"arrival","ON_FINISH_CAST")
	arrival.values.amount=20.0; arrival.values.radius=3.0
	var burst:=resolved(game,"chance_burst","ON_ENEMY_HIT_THIS_SKILL")
	burst.values.amount=.5; burst.values.radius=3.0
	game.state.skills.move.evolutions=[arrival,burst]; game.state.compiled_skills.clear()
	runtime._finish(runtime._context("move"))
	var parts: Dictionary=runtime.debug_stats.move.parts
	check(runtime.counts.get("ON_ENEMY_HIT_THIS_SKILL",0)==2,"Only arrival's two primary contacts emit hit events")
	check(parts.chance_burst.procs==2,"Chance burst procs once for each primary arrival contact")
	check(is_equal_approx(parts.arrival.damage,20.0*.92*2),"Arrival has its own fixed-power measured damage")
	check(is_equal_approx(parts.chance_burst.damage,20.0*.5*.92*4),"Triggered burst inherits arrival's power and damages two enemies per proc")
	var actual: float=(10000-game.enemies[0].hp)+(10000-game.enemies[1].hp)
	check(is_equal_approx(actual,float(parts.arrival.damage)+float(parts.chance_burst.damage)),"Per-enchantment damage partitions total actual health removed")
	check(runtime.event_queue.is_empty(),"Arrival chance responses cannot recurse")
	# Authoring a flat response must preserve flat damage through every secondary delivery.
	for id: String in ["chance_burst","chance_bolt","chance_field"]:
		runtime.clear_combat(); runtime.clear_debug_stats(); runtime.counts.clear(); runtime.next_proc.clear()
		for enemy: Node3D in game.enemies: enemy.hp=10000
		var modifier:=resolved(game,id,"ON_ENEMY_HIT_THIS_SKILL")
		modifier.response="fixed_damage"; modifier.values.amount=8.0
		if modifier.values.has("radius"): modifier.values.radius=3.0
		if modifier.values.has("duration"): modifier.values.duration=.5
		if modifier.values.has("interval"): modifier.values.interval=.2
		game.state.skills.cast.evolutions=[modifier]; game.state.compiled_skills.clear()
		runtime.hit(runtime._context("cast"),game.enemies[0])
		if id=="chance_field": runtime._tick_fields()
		for i in range(42): runtime._physics_process(1.0/60)
		var measured: Dictionary=runtime.debug_stats.cast.parts[id]
		var contacts := 1 if id=="chance_bolt" else (6 if id=="chance_field" else 2)
		check(measured.hits==contacts,id+" flat response has the expected contacts")
		check(is_equal_approx(measured.damage,8.0*.92*contacts),id+" deals flat amount after mitigation instead of multiplying by skill power")
		check(runtime.counts.get("ON_ENEMY_HIT_THIS_SKILL",0)==1,id+" secondary contacts cannot recurse")
		var report: String=load("res://scripts/skills/skill_debug.gd").report(game,"cast")
		check(report.contains("8.00 damage per"),id+" debug estimate matches authored flat amount")
	var draft: Resource=game.state.skill_catalog.duplicate(true)
	draft.data.modifiers.chance_field.response="heal"
	var errors: PackedStringArray=draft.validate()
	check(not errors.is_empty() and str(errors).contains("healing response requires burst or mantle"),"Validator rejects a field healing response")
	print("SECONDARY DAMAGE REVIEW: ",failures," failures")
	game.queue_free()
	await process_frame
	quit(failures)
