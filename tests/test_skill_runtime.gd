extends SceneTree
var game: Node
var runtime: Node
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func roll(id: String, event: String = "") -> Dictionary:
	var m: Dictionary=game.state.skill_catalog.data.modifiers[id].duplicate(true)
	m.id=id
	m.event=m.events.keys()[0] if event.is_empty() else event
	m.stat=m.stats.keys()[0] if not m.stats.is_empty() else ""
	for key: String in m.values: m.values[key]=float(m.values[key][0])
	return m
func install(id: String, modifiers: Array) -> void:
	game.state.skills[id].evolutions=modifiers
	game.state.compiled_skills.clear()
	runtime.clear_combat()
	runtime.skill_cooldowns.clear()
	runtime.next_proc.clear()
	game.state.mana=1000
func tick(seconds: float) -> void:
	for i in range(ceili(seconds*60)): runtime._physics_process(1.0/60)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.set_process(false)
	game.player.set_physics_process(false)
	runtime=game.skill_runtime
	runtime.set_physics_process(false)
	game.player.global_position=Vector3(30,0,30)
	game.player.visual.rotation.y=0
	game.state.skill_catalog=game.state.skill_catalog.duplicate(true)
	game.state.skill_catalog.data.rules.critical_chance=0
	for i in range(game.enemies.size()):
		var e: Node3D=game.enemies[i]
		e.set_physics_process(false)
		e.global_position=Vector3(30+float(i%3)*2,0,26-float(i/3)*2) if i<3 else Vector3(100+i*3,0,100)
		e.max_hp=10000; e.hp=10000
	await physics_frame
	var a: Node3D=game.enemies[0]
	var b: Node3D=game.enemies[1]
	var c: Node3D=game.enemies[2]
	game.target=a
	install("cast",[])
	check(runtime.cast_slot(1),"Cast projectile")
	tick(1)
	check(a.hp<10000 and b.hp==10000 and c.hp==10000,"Pure projectile damages only its target")
	var first_damage: float=10000-a.hp
	install("cast",[roll("echo")])
	a.hp=10000
	check(runtime.cast_slot(1),"Echo cast")
	tick(2)
	check(is_equal_approx(10000-a.hp,first_damage*1.5),"Echo can hit the same enemy for half power")
	var chain:=roll("chain")
	chain.values.range=6; chain.values.amount=2; chain.values.retention=.8
	install("cast",[chain])
	for e in [a,b,c]: e.hp=10000
	runtime.counts.clear()
	check(runtime.cast_slot(1),"Cast chain projectile")
	tick(2)
	check(a.hp<10000 and b.hp<10000 and c.hp<10000,"Two additional chain targets")
	check(is_equal_approx(10000-b.hp,first_damage*.8) and is_equal_approx(10000-c.hp,first_damage*.64),"Per-hop retention")
	check(runtime.counts.get("ON_CHAIN",0)==2 and runtime.counts.get("ON_CHAIN_HIT",0)==2 and runtime.counts.get("ON_CHAIN_END",0)==1,"Chain event counts")
	check(runtime.projectiles.is_empty() and runtime.scheduled.is_empty(),"Chain terminates")
	var impact:=roll("impact")
	impact.values.radius=2.2
	install("cast",[impact])
	for e in [a,b,c]: e.hp=10000
	check(runtime.cast_slot(1),"Impact provider cast")
	tick(1)
	check(b.hp<10000,"Projectile area provider adds secondary impact damage")
	var weakening:=roll("weakening")
	weakening.stat="movement_speed"
	install("melee",[weakening])
	var context: Dictionary=runtime._context("melee")
	runtime.hit(context,a)
	check(runtime.enemy_stat(a,"movement_speed")>0,"Hit installs selected stat debuff")
	for i in range(12): runtime.hit(runtime._context("melee"),a)
	check(runtime.enemy_stat(a,"movement_speed")<=.4,"Weakening cap")
	var mantle:=roll("mantle","ON_HIT_TAKEN")
	install("cast",[mantle])
	runtime._finish(runtime._context("cast"))
	a.global_position=game.player.global_position+Vector3(1,0,0)
	var before: float=a.hp
	runtime.after_incoming(10,a,"melee",false)
	check(a.hp<before,"Ten-second reactive ward retaliates")
	before=a.hp
	runtime.after_incoming(10,a,"melee",false)
	check(a.hp==before,"Ward respects shared internal cooldown")
	runtime._finish(runtime._context("cast"))
	runtime.after_incoming(10,a,"melee",false)
	check(a.hp==before,"Refreshing ward does not bypass interval")
	tick(11)
	before=a.hp
	runtime.after_incoming(10,a,"melee",false)
	check(a.hp==before and runtime.buffs.is_empty(),"Ward expires")
	var leech:=roll("leech"); leech.stat="health"
	install("cast",[leech])
	game.state.hp=40
	runtime.hit(runtime._context("cast"),a)
	check(game.state.hp==40 and not runtime.recoveries.is_empty(),"Leech is scheduled")
	tick(2.1)
	check(game.state.hp>40 and game.state.hp<=52,"Leech bounded and paid over time")
	install("ray",[])
	game.camera_yaw=PI
	game.player.visual.rotation.y=0
	var slot: int=game.state.loadout.find("ray")
	check(runtime.cast_slot(slot),"Channel starts")
	var mana_start: float=game.state.mana
	runtime._physics_process(.1)
	check(absf(runtime.channel_yaw)<=TAU*.1+.001,"Channel turn speed capped")
	tick(.4)
	check(game.state.mana<mana_start,"Channel pays each emission")
	runtime.stop_channel()
	check(runtime.channel_id.is_empty() and runtime.skill_cooldowns.ray>0,"Channel release starts cooldown")
	game.state.mana=0; runtime.skill_cooldowns.clear()
	check(not runtime.cast_slot(slot),"Cannot channel without mana")
	# Every delivery executes, including the three discoverable abilities.
	for id: String in game.state.skills:
		install(id,[])
		game.state.loadout[0]=id
		game.player.sitting=false; game.player.dash_time=0
		game.target=a
		check(runtime.cast_slot(0),"Delivery "+id)
		tick(.6)
		runtime.stop_channel()
	check(runtime.event_queue.is_empty(),"Event queue drains")
	print("SKILL RUNTIME: ",failures," failures")
	game.queue_free()
	await process_frame
	quit(failures)
