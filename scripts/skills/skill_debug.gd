extends RefCounted
## Read-only estimates and measured damage use the same compiled skill and power snapshot.
static func report(game: Node, id: String) -> String:
	var state: Node=game.state
	var runtime: Node=game.skill_runtime
	var c: Dictionary=state.compiled_skill(id)
	var installed: Array=state.skills[id].evolutions
	var power: float=runtime.preview_power(id,c)
	var stats: Dictionary=runtime.debug_stats.get(id,{"casts":0,"parts":{}})
	var lines: Array[String]=[
		"[b]%s · %s[/b]" % [state.skills[id].name,str(c.type).replace("_"," ")],
		"Mana %.2f · cooldown %.2fs · range %.2fm · radius %.2fm" % [float(c.cost)*float(c.cost_scale),float(c.cooldown)*float(c.cooldown_scale),float(c.range),float(c.radius)],
		"[color=#cbb991]Calculated values are before enemy defenses and critical hits. Measured values are actual health removed this session.[/color]",
		"",
		"[b]BASE DELIVERY[/b]"
	]
	if c.tags.has("damage"):
		lines.append("Direct hit: %.2f damage per target%s" % [power," per channel emission" if c.tags.has("channel") else ""])
		if c.tags.has("channel"): lines.append("Interval %.2fs · %.2f base damage/s while hitting continuously" % [float(c.interval),power/maxf(.05,float(c.interval))])
	elif c.tags.has("heal"): lines.append("Healing: %.2f vitality before overheal · 0 direct damage" % power)
	elif c.type=="dash": lines.append("Dash distance %.2fm · 0 native damage" % (float(c.range)*float(c.power_scale)*(1+runtime.own_stat("damage",id))))
	else: lines.append("Guard duration %.2fs · 0 native damage" % (4*float(c.duration_scale)))
	if c.type=="cast_projectile_area": lines.append("Native impact splash: %.2f per nearby enemy, excluding direct target" % (power*.6))
	lines.append("Critical chance %.1f%% · critical multiplier %.2f× for direct hits" % [float(state.skill_catalog.data.rules.critical_chance)*100,float(state.skill_catalog.data.rules.critical_multiplier)])
	if int(c.projectiles)>1: lines.append("Projectiles: %d; a cast cannot shotgun the same target." % int(c.projectiles))
	if int(c.chain_hops)>0:
		for hop in range(1,int(c.chain_hops)+1): lines.append("Chain hop %d: %.2f direct damage; %.2fm reach" % [hop,power*pow(float(c.chain_retention),hop),float(c.chain_range)])
	if int(c.echo)>0: lines.append("Echo: %.2f damage/healing per target at %.1f%% power" % [power*float(c.echo_scale),float(c.echo_scale)*100])
	lines.append("")
	lines.append("[b]EVERY INSTALLED ENCHANTMENT[/b]")
	if installed.is_empty(): lines.append("No enchantments installed.")
	for index in range(installed.size()):
		var m: Dictionary=installed[index]
		var amount: float=float(m.get("values",{}).get("amount",0))
		var name: String=str(m.get("name","Evolution")).replace("[","(").replace("]",")")
		var response_power:=power
		if c.type=="dash" and m.get("event","") in ["ON_ENEMY_HIT_THIS_SKILL","ON_CRITICAL_HIT","ON_KILL"]:
			for provider: Dictionary in installed:
				if bool(provider.get("primary_delivery",provider.get("id","")=="arrival")): response_power=float(provider.values.amount); break
		if m.get("response","")=="fixed_damage": response_power=1.0
		lines.append("\n[b]%d. %s[/b] · %s" % [index+1,name,str(m.get("event","PASSIVE"))])
		if m.op not in state.skill_catalog.PASSIVE_OPS:
			lines.append("%.1f%% chance to %s · internal cooldown %.2fs" % [100*float(m.get("chance",1)),state.skill_catalog.effect_name(m),float(m.get("icd",0))])
		match str(m.op):
			"burst","bolt","mantle":
				var fixed: bool=m.get("response","")=="fixed_damage" or (m.op=="mantle" and c.role=="defense") or (m.op=="burst" and c.type=="dash" and m.get("event","")=="ON_FINISH_CAST" and bool(m.get("primary_delivery",m.get("id","")=="arrival")))
				var damage: float=amount if fixed else response_power*amount
				if m.get("response","")=="heal": lines.append("0 damage · %.2f healing per response" % damage)
				else: lines.append("%.2f damage per %s per activation; %.2f chance-weighted per eligible event" % [damage,"projectile hit" if m.op=="bolt" else "enemy in area",damage*float(m.get("chance",1))])
				if m.values.has("radius"): lines.append("Area radius %.2fm" % (float(m.values.radius)*sqrt(float(c.area_scale))))
				if m.op=="bolt": lines.append("Secondary projectiles inherit projectile count, Pierce and Chain; they cannot trigger more on-hit effects.")
			"field":
				var interval: float=maxf(.1,float(m.values.get("interval",.75)))
				var duration: float=float(m.values.duration)*float(c.duration_scale)
				var ticks:=ceili(duration/interval)
				lines.append("%.2f damage per tick · %.2f damage/s · up to %d ticks / %.2f total per target remaining inside" % [response_power*amount,response_power*amount/interval,ticks,response_power*amount*ticks])
				lines.append("Duration %.2fs · tick %.2fs · radius %.2fm" % [duration,interval,float(m.values.radius)*sqrt(float(c.area_scale))])
			"power","legacy","exploit":
				var without:=installed.duplicate()
				without.remove_at(index)
				var baseline: Dictionary=state.skill_catalog.compile(id,without)
				if m.op=="exploit": lines.append("Conditional damage multiplier +%.1f%% against weakened targets; %.2f additional base damage per qualifying hit." % [amount*100,power*amount])
				else: lines.append("Adds %.2f to shared skill power. Included in base and scaled responses; no separate damage hit." % (power-runtime.preview_power(id,baseline)))
			"weaken": lines.append("0 direct damage · reduces %s %.1f%% per stack, up to %d stacks, for %.2fs" % [str(m.stat).replace("_"," "),amount*100,int(m.values.stacks),float(m.values.duration)*float(c.duration_scale)])
			"empower": lines.append("0 separate damage · %s +%.1f%% per stack, up to %d stacks, for %.2fs" % [str(m.stat).replace("_"," "),amount*100,int(m.values.stacks),float(m.values.duration)*float(c.duration_scale)])
			"recover": lines.append("0 damage · restores %.2f %s per activation, subject to the %.2f per-cast budget" % [amount,str(m.stat),float(state.skill_catalog.data.rules.recovery_per_cast)])
			"leech": lines.append("0 damage · restores %.1f%% of actual hit damage as %s over %.2fs" % [amount*100,str(m.get("stat","health")),float(m.values.get("duration",2))])
			"barrier": lines.append("0 damage · converts %.1f%% of overhealing into a barrier, capped at %.1f%% base vitality" % [amount*100,float(state.skill_catalog.data.rules.barrier_cap)*100])
			"area":
				lines.append("0 separate hit · +%.1f%% area; current area multiplier %.3f× and radius multiplier %.3f×." % [amount*100,float(c.area_scale),sqrt(float(c.area_scale))])
				var receivers: Array[String]=[]
				if c.tags.has("area"): receivers.append("native skill area")
				for provider: Dictionary in installed:
					if provider.get("provides",[]).has("area"): receivers.append(str(provider.name))
				lines.append("Enlarges: "+", ".join(receivers))
			"range": lines.append("0 separate hit · +%.1f%% range from this enchantment; final delivery range %.2fm" % [amount*100,float(c.range)])
			"duration": lines.append("0 separate hit · +%.1f%% duration; current duration multiplier %.3f× applies to buffs, debuffs and fields" % [amount*100,float(c.duration_scale)])
			"efficiency": lines.append("0 damage · -%.1f%% base mana cost; final cost %.2f" % [amount*100,float(c.cost)*float(c.cost_scale)])
			"tempo": lines.append("0 damage · -%.1f%% base cooldown; final cooldown %.2fs" % [amount*100,float(c.cooldown)*float(c.cooldown_scale)])
			"projectiles": lines.append("%d additional projectiles; final count %d. Each deals the delivery's damage to a different target." % [int(amount),int(c.projectiles)])
			"pierce": lines.append("%d additional straight-line contacts, each at the projectile's retained damage; Pierce resolves before Chain." % int(c.pierce))
			"chain": lines.append("%d additional hops, %.2fm range, %.1f%% retained power each hop. Per-hop values appear above." % [int(c.chain_hops),float(c.chain_range),float(c.chain_retention)*100])
			"echo": lines.append("Repeats delivery after %.2fs at %.1f%% power (%.2f), sharing its proc/recovery budgets." % [float(c.echo_delay),float(c.echo_scale)*100,power*float(c.echo_scale)])
			_: lines.append("0 separate damage · "+state.skill_catalog.describe(m,id,installed).get_slice("\n",2))
		var key: String=str(m.get("id",m.family))
		var measured: Dictionary=stats.parts.get(key,{})
		lines.append(_measured_line(measured))
	lines.append("\n[b]MEASURED DAMAGE · SESSION[/b]")
	lines.append("Casts / initial channel starts: %d" % int(stats.casts))
	var total:=0.0
	for key: String in stats.parts:
		var measured: Dictionary=stats.parts[key]
		total+=float(measured.damage)
		lines.append("%s: %s" % [key.replace("_"," "),_measured_line(measured)])
	lines.append("[b]Total actual damage: %.2f[/b]" % total)
	lines.append("\n[b]ACTIVE EFFECTS FROM THIS SKILL[/b]")
	var active:=0
	for key: String in runtime.buffs:
		var buff: Dictionary=runtime.buffs[key]
		if buff.context.skill!=id: continue
		active+=1
		lines.append("%s · %d stacks · %.2fs remaining" % [key,int(buff.stacks),maxf(0,float(buff.expires)-float(runtime.clock))])
	for buff: Dictionary in runtime.debuffs.values():
		if buff.get("skill","")!=id: continue
		active+=1
		lines.append("Enemy %s · %s · %d stacks · %.2fs" % [str(buff.target),str(buff.stat),int(buff.stacks),maxf(0,float(buff.expires)-float(runtime.clock))])
	if active==0: lines.append("None.")
	return "\n".join(lines)

static func _measured_line(record: Dictionary) -> String:
	if record.is_empty(): return "No measured activations yet."
	return "%.2f damage · %d hits · last %.2f · %d criticals · %d/%d proc successes" % [float(record.damage),int(record.hits),float(record.last),int(record.critical),int(record.procs),int(record.attempts)]
