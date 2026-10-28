extends Node
## Central skill delivery, bounded event queue and shared status scheduler.
var game: Node
var clock := 0.0
var serial := 0
var channel_id := ""
var channel_slot := -1
var channel_clock := 0.0
var channel_elapsed := 0.0
var channel_context: Dictionary = {}
var channel_yaw := 0.0
var projectiles: Array[Dictionary] = []
var fields: Array[Dictionary] = []
var scheduled: Array[Dictionary] = []
var buffs: Dictionary = {}
var debuffs: Dictionary = {}
var event_queue: Array[Dictionary] = []
var draining := false
var trace: Array[String] = []
var counts: Dictionary = {}
var skill_cooldowns: Dictionary = {}
var next_proc: Dictionary = {}
var barrier := 0.0
var barrier_expiry := 0.0
var recoveries: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var debug_stats: Dictionary = {}
var debug_revision := 0

func _stat_part(id: String, part: String) -> Dictionary:
	if not debug_stats.has(id): debug_stats[id]={"casts":0,"parts":{},"since":clock}
	if not debug_stats[id].parts.has(part): debug_stats[id].parts[part]={"damage":0.0,"hits":0,"last":0.0,"critical":0,"attempts":0,"procs":0}
	return debug_stats[id].parts[part]

func clear_debug_stats() -> void:
	debug_stats.clear()
	debug_revision+=1

func _proc_roll(m: Dictionary, context: Dictionary) -> bool:
	var record:=_stat_part(str(context.skill),str(m.get("id",m.family)))
	record.attempts+=1
	var chance:=clampf(float(m.get("chance",1)),0,1)
	var succeeds:=chance>=1 or (chance>0 and rng.randf()<chance)
	if succeeds: record.procs+=1
	debug_revision+=1
	return succeeds

func setup(owner_game: Node) -> void:
	game = owner_game
	rng.randomize()

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game): return
	clock += delta
	for id: String in skill_cooldowns: skill_cooldowns[id] = maxf(0, float(skill_cooldowns[id]) - delta)
	for key: String in buffs.keys():
		if float(buffs[key].expires) <= clock:
			var old: Dictionary = buffs[key]
			buffs.erase(key)
			if not game.is_dead: emit_event("ON_THIS_BUFF_EXPIRED", old.context, null, {"buff": key})
	for key: String in debuffs.keys():
		if float(debuffs[key].expires) <= clock: debuffs.erase(key)
	if barrier_expiry <= clock: barrier = 0
	for i in range(recoveries.size()-1,-1,-1):
		var recovery: Dictionary = recoveries[i]
		var step := minf(delta, float(recovery.remaining))
		if not game.is_dead: _recover(recovery.stat, float(recovery.rate)*step)
		recovery.remaining -= step
		if recovery.remaining <= 0 or game.is_dead: recoveries.remove_at(i)
	for i in range(scheduled.size()-1, -1, -1):
		if scheduled[i].at <= clock:
			var job: Dictionary = scheduled.pop_at(i)
			if not game.is_dead:
				if job.has("chain_target"):
					if is_instance_valid(job.chain_target) and not job.chain_target.dead: _launch(job.context,job.origin,job.chain_target,job.hop,job.scale,job.pierce,true)
					else: emit_event("ON_CHAIN_END",job.context,null,{"position":job.origin,"reason":"target_lost"})
				else:
					var delivery_context: Dictionary=job.context
					if job.get("echo",false):
						delivery_context=job.context.duplicate(false)
						delivery_context.visited=[]
						delivery_context.component="echo"
					_deliver(delivery_context, float(job.get("scale", 1)))
	_tick_projectiles(delta)
	_tick_fields()
	if not channel_id.is_empty():
		if game.is_dead or game.hud.is_panel_open():
			stop_channel()
			return
		channel_elapsed += delta
		channel_yaw = rotate_toward(channel_yaw, game.camera_yaw, deg_to_rad(float(game.state.skill_catalog.data.rules.channel_turn_degrees)) * delta)
		game.player.visual.rotation.y = channel_yaw
		channel_clock -= delta
		if channel_clock <= 0:
			var compiled: Dictionary = game.state.compiled_skill(channel_id)
			var price: float = float(compiled.cost) * float(compiled.cost_scale)
			if not game.state.spend_mana(price):
				stop_channel()
				return
			channel_clock += maxf(.05, float(compiled.interval))
			# Each paid emission gets a bounded event context and current caster snapshot.
			channel_context = _context(channel_id)
			_deliver(channel_context)

func cast_slot(slot: int) -> bool:
	if slot < 0 or slot >= game.state.loadout.size() or game.is_dead: return false
	var id: String = game.state.loadout[slot]
	if not channel_id.is_empty():
		if id == channel_id:
			stop_channel()
			return true
		stop_channel()
	if game.player.sitting:
		game.player.stand_up()
		return false
	if float(skill_cooldowns.get(id, 0)) > 0: return false
	var compiled: Dictionary = game.state.compiled_skill(id)
	if str(compiled.type) in ["cast_projectile", "cast_projectile_area", "melee_projectile", "cast_area_target"]:
		if not is_instance_valid(game.target) or game.target.dead: game.target = game._nearest_enemy(float(compiled.range))
		if not is_instance_valid(game.target):
			game._fail_notice("No enemy in range.")
			return false
		if game.target.global_position.distance_to(game.player.global_position) > float(compiled.range):
			game._fail_notice("Target is out of range.")
			return false
	if not game.state.spend_mana(float(compiled.cost) * float(compiled.cost_scale)):
		game._fail_notice("Not enough mana.")
		return false
	var context := _context(id)
	_stat_part(id,"base")
	debug_stats[id].casts+=1
	debug_revision+=1
	if compiled.tags.has("channel"):
		channel_id = id
		channel_slot = slot
		channel_yaw = game.player.visual.rotation.y
		channel_clock = float(compiled.interval)
		channel_elapsed = 0
		channel_context = context
		game.player.play_skill_animation(str(compiled.type))
	else: skill_cooldowns[id] = float(compiled.cooldown) * float(compiled.cooldown_scale)
	emit_event("ON_BEGIN_CAST", context)
	# Begin-cast buffs affect the initiating cast, without double-counting an existing buff.
	context.power *= (1 + own_stat("damage", id)) / float(context.power_buff)
	_deliver(context)
	if not compiled.tags.has("channel"):
		# Dash finish is emitted at actual arrival, not at button press.
		if compiled.type != "dash": _finish(context)
		if int(compiled.echo) > 0 and float(compiled.echo_scale)>0 and scheduled.size() < 32:
			scheduled.append({"at": clock + float(compiled.echo_delay), "context": context, "scale": float(compiled.echo_scale),"echo":true})
	return true

func stop_channel() -> void:
	if channel_id.is_empty(): return
	var id := channel_id
	var context := channel_context
	channel_id = ""
	channel_slot = -1
	game.player.stop_skill_animation()
	if not game.is_dead and channel_elapsed >= .2: _finish(context)
	skill_cooldowns[id] = float(context.compiled.cooldown) * float(context.compiled.cooldown_scale)

func preview_power(id: String, compiled: Dictionary = {}) -> float:
	if compiled.is_empty(): compiled=game.state.compiled_skill(id)
	var equipment: Dictionary = game.state.get_equipment_modifiers()
	var role: String = compiled.role
	var power := float(compiled.power) * float(compiled.power_scale)
	if compiled.tags.has("damage"):
		power += game.state.get_equipment_power() * .3
		power *= float(equipment.get("melee_multiplier" if role == "melee" else "cast_multiplier", 1))
	if role == "support": power *= float(equipment.support_multiplier)
	power *= 1 + own_stat("damage", id)
	return power

func _context(id: String) -> Dictionary:
	serial += 1
	var compiled: Dictionary = game.state.compiled_skill(id).duplicate(true)
	return {"id": serial, "skill": id, "compiled": compiled, "power": preview_power(id,compiled), "component":"base", "secondary":false,"power_buff":1+own_stat("damage",id), "visited": [], "used": {}, "events": 0, "recovery": 0.0, "budget":{"events":0,"recovery":0.0}, "last": game.player.global_position, "hits": 0}

func _finish(context: Dictionary) -> void:
	for m: Dictionary in context.compiled.handlers:
		if m.op == "mantle":
			var key := "ward:" + str(m.family)
			var existing: Dictionary = buffs.get(key, {})
			if existing.is_empty() and buffs.size()+debuffs.size()>=int(game.state.skill_catalog.data.rules.max_statuses): continue
			# Atomic payload, shared family interval persists through refresh.
			if existing.is_empty() or float(context.power) >= float(existing.context.power):
				buffs[key] = {"expires": clock + float(m.values.duration) * float(context.compiled.duration_scale), "modifier": m, "context": context, "stat": "ward", "amount": 0, "stacks": 1}
			else: buffs[key].expires = clock + float(m.values.duration) * float(context.compiled.duration_scale)
			if existing.is_empty(): emit_event("ON_BUFF_RECEIVED", context)
	emit_event("ON_FINISH_CAST", context)

func _deliver(context: Dictionary, scale_value: float = 1) -> void:
	if scale_value < 0:
		_finish(context)
		return
	var c: Dictionary = context.compiled
	var origin: Vector3 = game.player.global_position
	var facing: Vector3 = Vector3.FORWARD.rotated(Vector3.UP, channel_yaw if c.tags.has("channel") else game.player.visual.rotation.y)
	match str(c.type):
		"cast_projectile", "cast_projectile_area", "melee_projectile", "channel_projectiles":
			var targets := nearby(origin, float(c.range))
			if is_instance_valid(game.target) and targets.has(game.target):
				targets.erase(game.target)
				targets.push_front(game.target)
			var launched := 0
			for enemy: Node3D in targets:
				if c.tags.has("channel") and facing.dot((enemy.global_position-origin).normalized()) < .85: continue
				_launch(context, origin + Vector3.UP, enemy, 0, scale_value, int(c.pierce))
				launched += 1
				if launched >= int(c.projectiles): break
			if launched == 0 and c.tags.has("channel"): game.burst(origin + facing * 3 + Vector3.UP, Color("83bddd"), .15, .15)
			if not c.tags.has("channel"):
				if c.type=="melee_projectile": game.player.attack_animation(str(c.type))
				else: game.player.cast_animation(str(c.type))
		"melee_cone", "cast_cone":
			if is_instance_valid(game.target):
				game.player.face_point(game.target.global_position)
				facing = Vector3.FORWARD.rotated(Vector3.UP, game.player.visual.rotation.y)
			for enemy: Node3D in nearby(origin, float(c.range)):
				var toward: Vector3 = enemy.global_position - origin
				toward.y = 0
				if facing.dot(toward.normalized()) >= cos(deg_to_rad(float(c.angle) * .5)): hit(context, enemy, scale_value)
			game.burst(origin + facing * 1.5, Color("e9bc77"), minf(float(c.range), 3), .2)
			if c.type == "melee_cone": game.player.attack_animation(str(c.type))
			else: game.player.cast_animation(str(c.type))
		"melee_area", "cast_area_self", "cast_area_target":
			var center: Vector3 = game.target.global_position if c.type == "cast_area_target" and is_instance_valid(game.target) else origin
			_area(context, center, float(c.radius), scale_value, false)
			game.player.attack_animation(str(c.type)) if c.type == "melee_area" else game.player.cast_animation(str(c.type))
		"channel_ray":
			var end: Vector3 = origin + facing * float(c.range)
			var first: Node3D = null
			for enemy: Node3D in nearby(origin, float(c.range)):
				var relative: Vector3 = enemy.global_position - origin
				var along := relative.dot(facing)
				if along > 0 and (relative-facing*along).length() < .8 and _visible(origin+Vector3.UP, enemy.global_position+Vector3.UP):
					first = enemy
					end = enemy.global_position
					break
			for i in range(1, 9): game.burst(origin.lerp(end, i/8.0) + Vector3.UP, Color("70b8e8"), .12, .15)
			if first != null: hit(context, first, scale_value)
		"dash":
			game.player.dash()
			# The existing dodge keeps its animation; distance is scaled by skill range.
			game.player.dash_speed = float(c.range) * float(c.power_scale) * (1+own_stat("damage",context.skill)) / game.player.DODGE_DURATION
			scheduled.append({"at": clock + game.player.DODGE_DURATION, "context": context, "scale": -1.0})
		"cast_effect":
			if c.tags.has("heal"):
				game.player.support_animation(str(c.type))
				var maximum: float = game.state.max_hp + game.state.get_equipment_modifiers().max_hp
				var restored := minf(float(context.power)*scale_value, maximum-game.state.hp)
				game.state.hp += restored
				emit_event("ON_ALLY_HIT", context, game.player, {"healed": restored, "overheal": maxf(0,float(context.power)*scale_value-restored)})
				game.floating_text(origin+Vector3.UP*2, "+%d" % int(restored), Color("9bdca3"))
			else:
				game.player.block_animation("block")
				game.block_time = 4 * float(c.duration_scale)
				var new_buff := not buffs.has("native:guard")
				buffs["native:guard"]={"expires":clock+game.block_time,"context":context,"stat":"guard","amount":0,"stacks":1}
				if new_buff: emit_event("ON_BUFF_RECEIVED", context)
			game.burst(origin, Color("9acccc"), 1.3, .3)

func _launch(context: Dictionary, origin: Vector3, target: Node3D, hop: int, scale_value: float, piercing: int, chain_hop: bool = false, damage_component: String = "") -> void:
	if projectiles.size() >= int(game.state.skill_catalog.data.rules.max_projectile_instances) or not is_instance_valid(target): return
	var orb: MeshInstance3D = game.combat_effects.take_orb()
	orb.global_position = origin
	var flame := orb.get_node_or_null("EmberTrail")
	if flame != null: flame.play()
	if damage_component.is_empty(): damage_component="chain" if chain_hop and not context.get("secondary",false) else str(context.get("component","base"))
	projectiles.append({"orb": orb, "target": target, "context": context, "hop": hop, "is_chain":chain_hop,"component":damage_component,"scale": scale_value, "pierce": piercing, "travel": 0.0, "direction": (target.global_position+Vector3.UP-origin).normalized()})
	if not context.get("secondary",false):
		if chain_hop: emit_event("ON_CHAIN", context, target, {"hop": hop})
		else: emit_event("ON_PROJECTILE_LAUNCHED", context, target)

func _tick_projectiles(delta: float) -> void:
	for i in range(projectiles.size()-1,-1,-1):
		var p: Dictionary = projectiles[i]
		var orb: MeshInstance3D = p.orb
		if not is_instance_valid(p.target) or p.target.dead or game.is_dead:
			if not game.is_dead and int(p.context.compiled.chain_hops)>0: emit_event("ON_CHAIN_END",p.context,null,{"position":orb.global_position,"reason":"target_lost"})
			game.combat_effects.release_orb(orb)
			projectiles.remove_at(i)
			continue
		var goal: Vector3 = p.target.global_position + Vector3.UP
		var before := orb.global_position
		orb.global_position = before.move_toward(goal, float(p.context.compiled.speed)*delta)
		p.travel += before.distance_to(orb.global_position)
		if not _visible(before, orb.global_position) or p.travel > float(p.context.compiled.range)*1.5:
			if int(p.context.compiled.chain_hops)>0: emit_event("ON_CHAIN_END",p.context,null,{"position":before,"reason":"blocked_or_range"})
			game.combat_effects.release_orb(orb)
			projectiles.remove_at(i)
			continue
		if orb.global_position.distance_to(goal) < .15:
			projectiles.remove_at(i)
			game.combat_effects.release_orb(orb)
			var enemy: Node3D = p.target
			var contact: Vector3 = enemy.global_position
			p.context.last = contact
			if not p.context.visited.has(enemy.get_instance_id()):
				p.context.visited.append(enemy.get_instance_id())
				var actual_damage := hit(p.context, enemy, p.scale,bool(p.context.get("secondary",false)),str(p.component))
				if not p.context.get("secondary",false):
					emit_event("ON_PROJECTILE_LANDED", p.context, enemy, {"position": contact})
					if p.is_chain: emit_event("ON_CHAIN_HIT", p.context, enemy, {"hop": p.hop,"damage":actual_damage})
					if p.context.compiled.type == "cast_projectile_area": _area(p.context, contact, float(p.context.compiled.radius), p.scale * .6, true, enemy,"native_area")
			var next: Node3D = null
			var chain_range: float = p.context.compiled.chain_range
			var next_hop: int = p.hop
			var next_scale: float = p.scale
			var next_pierce: int = p.pierce
			if int(p.pierce)>0:
				for candidate: Node3D in nearby(contact, float(p.context.compiled.range)):
					if not p.context.visited.has(candidate.get_instance_id()) and p.direction.dot((candidate.global_position-contact).normalized()) > .94:
						next = candidate
						next_pierce -= 1
						break
			if next == null and int(p.hop) < int(p.context.compiled.chain_hops):
				var candidates := nearby(contact, chain_range)
				if p.context.compiled.chain_policy == "lowest_health": candidates.sort_custom(func(a,b): return a.hp < b.hp)
				elif p.context.compiled.chain_policy == "random":
					var local_rng := RandomNumberGenerator.new()
					local_rng.seed = int(p.context.id)*13+int(p.hop)
					for j in range(candidates.size()-1,0,-1):
						var k := local_rng.randi_range(0,j)
						var swap: Node3D=candidates[j]; candidates[j]=candidates[k]; candidates[k]=swap
				for candidate: Node3D in candidates:
					if not p.context.visited.has(candidate.get_instance_id()) and _visible(contact+Vector3.UP,candidate.global_position+Vector3.UP):
						next = candidate
						next_hop += 1
						next_scale *= float(p.context.compiled.chain_retention)
						break
			if next != null:
				if next_hop>int(p.hop) and float(p.context.compiled.chain_delay)>0 and scheduled.size()<int(game.state.skill_catalog.data.rules.max_scheduled):
					scheduled.append({"at":clock+float(p.context.compiled.chain_delay),"context":p.context,"chain_target":next,"origin":contact+Vector3.UP,"hop":next_hop,"scale":next_scale,"pierce":next_pierce})
				else: _launch(p.context, contact+Vector3.UP, next, next_hop, next_scale, next_pierce,next_hop>int(p.hop),"pierce" if next_pierce<int(p.pierce) and not p.context.get("secondary",false) else "")
			elif int(p.context.compiled.chain_hops)>0: emit_event("ON_CHAIN_END", p.context, enemy, {"position":contact})

func hit(context: Dictionary, enemy: Node3D, scale_value: float = 1.0, secondary: bool = false, component: String = "") -> float:
	if not is_instance_valid(enemy) or enemy.dead: return 0
	var damage: float = float(context.power) * scale_value
	for m: Dictionary in context.compiled.handlers:
		if m.op == "exploit" and enemy_stat(enemy,"armor") + enemy_stat(enemy,"movement_speed") + enemy_stat(enemy,"outgoing_damage") > 0: damage *= 1 + float(m.values.amount)
	var critical := not secondary and rng.randf() < float(game.state.skill_catalog.data.rules.critical_chance)
	if critical: damage *= float(game.state.skill_catalog.data.rules.critical_multiplier)
	var armor := .15 * (1-enemy_stat(enemy,"armor")) if context.compiled.role == "melee" else .08
	damage = minf(enemy.hp, maxf(0, damage*(1-armor)))
	var record:=_stat_part(str(context.skill),component if not component.is_empty() else str(context.get("component","base")))
	record.damage+=damage; record.hits+=1; record.last=damage
	if critical: record.critical+=1
	debug_revision+=1
	enemy.take_damage(damage)
	context.hits += 1
	context.last = enemy.global_position
	if not secondary:
		emit_event("ON_ENEMY_HIT_THIS_SKILL", context, enemy, {"damage":damage})
		if critical: emit_event("ON_CRITICAL_HIT",context,enemy,{"damage":damage})
		if enemy.dead: emit_event("ON_KILL",context,enemy,{"damage":damage})
	return damage

func _area(context: Dictionary, center: Vector3, radius: float, scale_value: float, secondary: bool = true, exclude: Node = null, component: String = "") -> void:
	game.burst(center, Color("ce975c") if secondary else Color("89aedc"), radius, .25)
	for enemy: Node3D in nearby(center,radius):
		if enemy != exclude: hit(context,enemy,scale_value,secondary,component)

func nearby(center: Vector3, radius: float) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for enemy in game.enemies:
		if is_instance_valid(enemy) and not enemy.dead and center.distance_to(enemy.global_position) <= radius: result.append(enemy)
	result.sort_custom(func(a: Node3D,b: Node3D):
		var da := center.distance_squared_to(a.global_position)
		var db := center.distance_squared_to(b.global_position)
		return da < db if not is_equal_approx(da,db) else a.get_instance_id() < b.get_instance_id())
	return result

func _visible(a: Vector3,b: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(a,b,1)
	return game.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func emit_event(event: String, context: Dictionary, target: Node = null, extra: Dictionary = {}) -> void:
	if context.is_empty(): return
	if context.get("secondary",false): return
	if int(context.budget.events) >= int(game.state.skill_catalog.data.rules.event_budget): return
	context.budget.events += 1
	context.events += 1
	event_queue.append({"event":event,"context":context,"target":target,"extra":extra})
	if draining: return
	draining = true
	var processed := 0
	while not event_queue.is_empty() and processed < 256:
		var job: Dictionary = event_queue.pop_front()
		processed += 1
		counts[job.event] = int(counts.get(job.event,0))+1
		trace.append("%s · %s · cast %d" % [job.event,job.context.skill,job.context.id])
		if trace.size()>80: trace.pop_front()
		for m: Dictionary in job.context.compiled.handlers:
			if m.op == "mantle" or str(m.get("event","")) != str(job.event): continue
			_activate(m,job.context,job.target,job.extra)
	event_queue.clear()
	draining = false

func _activate(m: Dictionary, context: Dictionary, target: Node, extra: Dictionary) -> void:
	var token: String = str(m.get("id", m.family))
	if (m.op in ["weaken", "empower"] or m.get("event","") in ["ON_ENEMY_HIT_THIS_SKILL","ON_CRITICAL_HIT","ON_CHAIN_HIT","ON_PROJECTILE_LANDED","ON_ALLY_HIT"]) and is_instance_valid(target): token += ":" + str(target.get_instance_id())
	if context.used.has(token): return
	var cooldown_key := str(context.skill)+":"+str(m.family)
	if clock < float(next_proc.get(cooldown_key,0)): return
	if not _proc_roll(m,context): return
	context.used[token] = true
	next_proc[cooldown_key] = clock + float(m.get("icd",0))
	var amount: float = float(m.get("values",{}).get("amount",0))
	var duration: float = float(m.get("values",{}).get("duration",4))*float(context.compiled.duration_scale)
	match str(m.op):
		"weaken":
			if not is_instance_valid(target) or target == game.player or target.get("dead") == null or target.dead: return
			var key := "%s:%s:%s" % [target.get_instance_id(),context.skill,m.stat]
			var old: Dictionary = debuffs.get(key,{})
			if old.is_empty() and buffs.size()+debuffs.size()>=int(game.state.skill_catalog.data.rules.max_statuses): return
			debuffs[key] = {"target":target.get_instance_id(),"skill":context.skill,"stat":m.stat,"amount":amount,"stacks":mini(int(old.get("stacks",0))+1,int(m.values.get("stacks",3))),"expires":clock+duration}
		"empower":
			var key := str(context.skill)+":"+str(m.family)
			var old: Dictionary = buffs.get(key,{})
			if old.is_empty() and buffs.size()+debuffs.size()>=int(game.state.skill_catalog.data.rules.max_statuses): return
			buffs[key] = {"stat":m.stat,"amount":amount,"stacks":mini(int(old.get("stacks",0))+1,int(m.values.get("stacks",1))),"expires":clock+duration,"context":context}
			if old.is_empty(): emit_event("ON_BUFF_RECEIVED",context)
		"recover", "leech":
			var gain := amount if m.op == "recover" else float(extra.get("damage",0))*amount
			gain = minf(gain,maxf(0,float(game.state.skill_catalog.data.rules.recovery_per_cast)-float(context.budget.recovery)))
			context.budget.recovery += gain
			context.recovery += gain
			if m.op=="leech":
				var seconds := maxf(.1,float(m.values.get("duration",2)))
				if recoveries.size()<128: recoveries.append({"stat":m.get("stat","health"),"rate":gain/seconds,"remaining":seconds})
			else: _recover(m.get("stat","health"),gain)
		"barrier":
			barrier = minf(game.state.max_hp*float(game.state.skill_catalog.data.rules.barrier_cap),barrier+float(extra.get("overheal",0))*amount)
			barrier_expiry = clock+duration
		"bolt":
			var center: Vector3=extra.get("position",target.global_position if is_instance_valid(target) else game.player.global_position)
			var targets:=nearby(center,float(m.values.range))
			var child: Dictionary=context.duplicate(false)
			child.compiled=context.compiled.duplicate(true)
			child.compiled.range=float(m.values.range)
			child.power=amount if m.get("response","")=="fixed_damage" else float(context.power)*amount
			child.component=str(m.get("id",m.family))
			child.secondary=true
			child.visited=[]
			if is_instance_valid(target): child.visited.append(target.get_instance_id())
			var launched:=0
			for enemy: Node3D in targets:
				if enemy==target or not _visible(center+Vector3.UP,enemy.global_position+Vector3.UP): continue
				_launch(child,center+Vector3.UP,enemy,0,1,int(child.compiled.pierce))
				launched+=1
				if launched>=int(child.compiled.projectiles): break
		"burst", "field":
			var center: Vector3 = extra.get("position", target.global_position if is_instance_valid(target) else game.player.global_position)
			var radius: float = float(m.values.get("radius",2))*sqrt(float(context.compiled.area_scale))
			if m.get("response","") == "heal":
				# Friendly recipients are explicitly registered; the original healed actor is excluded.
				for ally: Node in get_tree().get_nodes_in_group("skill_allies"):
					if ally != target and ally is Node3D and ally.global_position.distance_to(center)<=radius and ally.has_method("receive_skill_heal"): ally.receive_skill_heal(float(context.power)*amount)
			elif m.op == "field":
				var field_context: Dictionary=context
				if m.get("response","")=="fixed_damage":
					field_context=context.duplicate(false); field_context.power=1.0
				if fields.size()<int(game.state.skill_catalog.data.rules.max_fields): fields.append({"context":field_context,"component":str(m.get("id",m.family)),"center":center,"radius":radius,"scale":amount,"expires":clock+duration,"next":clock,"interval":maxf(.1,float(m.values.get("interval",.75)))})
			else:
				if context.compiled.type == "dash" and m.get("event","")=="ON_FINISH_CAST" and bool(m.get("primary_delivery",m.get("id","")=="arrival")):
					var pulse: Dictionary = context.duplicate(true)
					pulse.power = amount
					_area(pulse,center,radius,1,false,null,str(m.get("id",m.family)))
				elif m.get("response","")=="fixed_damage":
					var response: Dictionary=context.duplicate(false)
					response.power=1.0
					_area(response,center,radius,amount,true,null,str(m.get("id",m.family)))
				else: _area(context,center,radius,amount,true,null,str(m.get("id",m.family)))

func _tick_fields() -> void:
	for i in range(fields.size()-1,-1,-1):
		var field: Dictionary = fields[i]
		if clock>=float(field.expires) or game.is_dead:
			fields.remove_at(i)
		elif clock>=float(field.next):
			field.next = clock+field.interval
			_area(field.context,field.center,field.radius,field.scale,true,null,str(field.component))

func _recover(stat: String, amount: float) -> void:
	if game.is_dead: return
	if stat=="mana": game.state.mana=minf(game.state.max_mana+game.state.get_equipment_modifiers().max_mana,game.state.mana+amount)
	else: game.state.hp=minf(game.state.max_hp+game.state.get_equipment_modifiers().max_hp,game.state.hp+amount)

func incoming(amount: float, source: Node, delivery: String, blocked: bool, evaded: bool = false) -> float:
	if evaded:
		_react("ON_SUCCESSFUL_EVADE",source)
		return 0
	var absorbed := minf(barrier,amount)
	barrier -= absorbed
	return amount-absorbed

func after_incoming(amount: float, source: Node, delivery: String, blocked: bool) -> void:
	if blocked: _react("ON_BLOCK",source)
	if amount > 0:
		_react("ON_HIT_TAKEN",source)
		if delivery in ["projectile", "melee"]: _react("ON_PROJECTILE_DAMAGE_RECEIVED" if delivery == "projectile" else "ON_MELEE_DAMAGE_RECEIVED",source)

func _react(event: String, source: Node) -> void:
	for key: String in buffs.keys():
		if not buffs.has(key) or not buffs[key].has("modifier"): continue
		var buff: Dictionary = buffs[key]
		var m: Dictionary = buff.modifier
		if m.event != event or clock<float(next_proc.get(key,0)): continue
		if not _proc_roll(m,buff.context): continue
		next_proc[key] = clock+maxf(.1,float(m.icd))
		var context: Dictionary = buff.context
		counts[event] = int(counts.get(event,0))+1
		if m.get("response","") == "heal" and not game.is_dead:
			game.state.hp = minf(game.state.max_hp+game.state.get_equipment_modifiers().max_hp,game.state.hp+float(context.power)*float(m.values.amount))
		else:
			var response: Dictionary = context.duplicate(true)
			if m.get("response","") == "fixed_damage" or context.compiled.role == "defense": response.power = 1
			_area(response,game.player.global_position,float(m.values.radius)*sqrt(float(context.compiled.area_scale)),float(m.values.amount),true,null,str(m.get("id",m.family)))

func enemy_stat(enemy: Node, stat: String) -> float:
	var strongest := 0.0
	for entry: Dictionary in debuffs.values():
		if entry.target==enemy.get_instance_id() and entry.stat==stat: strongest=maxf(strongest,float(entry.amount)*int(entry.stacks))
	return minf(strongest,float(game.state.skill_catalog.data.rules.weakening_cap))

func own_stat(stat: String, id: String = "") -> float:
	var amount := 0.0
	for entry: Dictionary in buffs.values():
		if entry.stat==stat and (id.is_empty() or entry.context.skill==id): amount+=float(entry.amount)*int(entry.stacks)
	return minf(amount,float(game.state.skill_catalog.data.rules.own_buff_cap))

func clear_combat() -> void:
	game.player.stop_skill_animation()
	channel_id=""
	channel_slot=-1
	buffs.clear()
	debuffs.clear()
	fields.clear()
	scheduled.clear()
	recoveries.clear()
	for p: Dictionary in projectiles: game.combat_effects.release_orb(p.orb)
	projectiles.clear()
	barrier=0

func status_text() -> String:
	var parts: Array[String] = []
	for key: String in buffs:
		parts.append("%s %.1fs" % [key.get_slice(":",1).capitalize(),maxf(0,buffs[key].expires-clock)])
	if barrier>0: parts.append("Barrier %d" % barrier)
	if not channel_id.is_empty(): parts.append("CHANNELING · release key or press again to stop")
	return "  |  ".join(parts.slice(0,4))
