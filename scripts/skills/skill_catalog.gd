@tool
extends Resource
## One versioned, editable catalog. Runtime instances store their resolved rolls.
@export var data: Dictionary = {}
const EVENTS := ["PASSIVE", "ON_BEGIN_CAST", "ON_FINISH_CAST", "ON_ENEMY_HIT_THIS_SKILL", "ON_ALLY_HIT", "ON_HIT_TAKEN", "ON_BUFF_RECEIVED", "ON_THIS_BUFF_EXPIRED", "ON_DEATH", "ON_PROJECTILE_LAUNCHED", "ON_PROJECTILE_LANDED", "ON_PROJECTILE_DAMAGE_RECEIVED", "ON_MELEE_DAMAGE_RECEIVED", "ON_CHAIN", "ON_CHAIN_HIT", "ON_CHAIN_END", "ON_BLOCK", "ON_SUCCESSFUL_EVADE", "ON_KILL", "ON_CRITICAL_HIT"]
const OPERATIONS := ["power", "area", "range", "duration", "efficiency", "tempo", "projectiles", "chain", "pierce", "echo", "burst", "field", "bolt", "weaken", "empower", "recover", "leech", "mantle", "barrier", "exploit", "legacy"]
const TYPES := ["melee_cone", "melee_area", "melee_projectile", "cast_cone", "cast_area_self", "cast_area_target", "cast_projectile", "cast_projectile_area", "channel_ray", "channel_projectiles", "dash", "cast_effect"]
const TIERS := ["basic", "rare", "epic", "legendary", "mythical"]
const PASSIVE_OPS := ["power", "area", "range", "duration", "efficiency", "tempo", "projectiles", "chain", "pierce", "echo", "exploit", "legacy"]
const REACTIONS := ["ON_HIT_TAKEN", "ON_PROJECTILE_DAMAGE_RECEIVED", "ON_MELEE_DAMAGE_RECEIVED", "ON_BLOCK", "ON_SUCCESSFUL_EVADE", "ON_DEATH"]
const EVENT_TAGS := {"ON_ENEMY_HIT_THIS_SKILL":"hit", "ON_ALLY_HIT":"heal", "ON_PROJECTILE_LAUNCHED":"projectile", "ON_PROJECTILE_LANDED":"projectile", "ON_CHAIN":"chain", "ON_CHAIN_HIT":"chain", "ON_CHAIN_END":"chain", "ON_KILL":"damage", "ON_CRITICAL_HIT":"hit", "ON_THIS_BUFF_EXPIRED":"duration", "ON_BUFF_RECEIVED":"buff"}

func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if not data.get("skills") is Dictionary or not data.get("modifiers") is Dictionary or not data.get("rules") is Dictionary:
		errors.append("Catalog requires skills, modifiers and rules dictionaries.")
		return errors
	for id: String in data.skills:
		var skill: Dictionary = data.skills[id]
		for field in ["tags"]:
			if not skill.get(field) is Array: errors.append(id + ": missing " + field)
		for field in ["name", "role", "icon"]:
			if not skill.get(field) is String: errors.append(id + ": missing " + field)
		if not TYPES.has(skill.get("type", "")): errors.append(id + ": invalid delivery type")
		for key in ["power", "cost", "cooldown", "range", "radius", "interval", "speed", "acquisition_weight"]:
			if not _number(skill.get(key)) or float(skill[key]) < 0: errors.append(id + ": invalid " + key)
		if float(skill.get("interval", 0)) < 0.05: errors.append(id + ": interval must be at least 0.05 s")
	for id: String in data.modifiers:
		var m: Dictionary = data.modifiers[id]
		if str(m.get("tier", "basic")) not in TIERS: errors.append(id + ": invalid enchantment tier")
		for field in ["name", "family", "op"]:
			if not m.get(field) is String or str(m.get(field, "")).is_empty(): errors.append(id + ": missing " + field)
		for field in ["requires", "excludes", "provides"]:
			if not m.get(field) is Array: errors.append(id + ": missing tag array " + field)
		if not m.get("values") is Dictionary or not m.get("events") is Dictionary or not m.get("stats") is Dictionary:
			errors.append(id + ": values, events and stats must be dictionaries")
			continue
		if not OPERATIONS.has(m.get("op", "")): errors.append(id + ": unsupported operation")
		if not _number(m.get("weight")) or float(m.get("weight", -1)) < 0: errors.append(id + ": invalid weight")
		if not _number(m.get("variant_weight")) or float(m.get("variant_weight", -1)) < 0: errors.append(id + ": invalid variant weight")
		var event_total := 0.0
		for event: String in m.get("events", {}):
			if not EVENTS.has(event): errors.append(id + ": unsupported event " + event)
			if not _number(m.events[event]) or float(m.events[event]) < 0: errors.append(id + ": invalid event weight")
			else: event_total += float(m.events[event])
			if float(m.events[event]) > 0:
				if m.op in PASSIVE_OPS and event != "PASSIVE": errors.append(id + ": passive operation requires PASSIVE")
				if m.op == "mantle" and event not in REACTIONS: errors.append(id + ": mantle requires a received-damage, block, evade or death event")
				if m.op not in PASSIVE_OPS and m.op != "mantle" and (event == "PASSIVE" or event in REACTIONS): errors.append(id + ": reaction events require a mantle")
				if m.op in ["weaken", "leech"] and event not in ["ON_ENEMY_HIT_THIS_SKILL", "ON_CRITICAL_HIT", "ON_CHAIN_HIT"]: errors.append(id + ": needs a damaging contact event")
				if m.op == "barrier" and event != "ON_ALLY_HIT": errors.append(id + ": overheal barrier requires ON_ALLY_HIT")
		if event_total <= 0: errors.append(id + ": enable at least one event")
		for key: String in m.get("values", {}):
			var bounds: Variant = m.values[key]
			if not bounds is Array or bounds.size() != 2 or not _number(bounds[0]) or not _number(bounds[1]) or float(bounds[0]) > float(bounds[1]):
				errors.append(id + ": invalid range for " + key)
			elif float(bounds[0]) < 0: errors.append(id + ": " + key + " cannot be negative")
		if m.op in ["weaken", "empower", "recover", "leech"]:
			var stat_total := 0.0
			var supported: Array = ["armor", "outgoing_damage", "movement_speed", "attack_speed"] if m.op == "weaken" else (["damage", "movement_speed"] if m.op == "empower" else ["health", "mana"])
			for stat: String in m.stats:
				if not _number(m.stats[stat]) or float(m.stats[stat]) < 0: errors.append(id + ": invalid stat weight")
				else:
					stat_total += float(m.stats[stat])
					if float(m.stats[stat]) > 0 and stat not in supported: errors.append(id + ": unsupported stat " + stat)
			if stat_total <= 0: errors.append(id + ": choose at least one supported stat")
		if float(m.get("chance", 1)) < 0 or float(m.get("chance", 1)) > 1: errors.append(id + ": chance must be 0..1")
		if m.has("chance_range"):
			var bounds: Variant=m.chance_range
			if not bounds is Array or bounds.size()!=2 or not _number(bounds[0]) or not _number(bounds[1]) or float(bounds[0])<0 or float(bounds[1])>1 or float(bounds[0])>float(bounds[1]): errors.append(id+": chance range must be min/max between 0 and 1")
			elif m.op in PASSIVE_OPS and bounds != [1.0,1.0]: errors.append(id+": passive support chance must be 100%")
		if float(m.get("icd", 0)) < 0: errors.append(id + ": cooldown cannot be negative")
		if m.get("op") in PASSIVE_OPS and (not is_equal_approx(float(m.get("chance",1)),1) or not is_zero_approx(float(m.get("icd",0)))): errors.append(id+": passive supports use chance 1 and interval 0")
		var needed: Array=["amount"]
		if m.op in ["weaken","empower"]: needed.append_array(["duration","stacks"])
		if m.op in ["mantle","field"]: needed.append_array(["duration","radius"])
		if m.op=="burst": needed.append("radius")
		if m.op=="chain": needed.append_array(["range","retention"])
		if m.op=="bolt": needed.append("range")
		if m.op=="legacy": needed=[]
		for field: String in needed:
			if not m.values.has(field): errors.append(id+": missing value "+field)
		if m.get("target_policy","nearest") not in ["nearest","lowest_health","random"]: errors.append(id+": invalid chain target policy")
		if m.get("response","") not in ["","heal","fixed_damage"]: errors.append(id+": invalid response")
		if m.get("response","")=="heal" and m.op not in ["burst","mantle"]: errors.append(id+": healing response requires burst or mantle")
		if m.get("response","")=="fixed_damage" and m.op not in ["burst","field","bolt","mantle"]: errors.append(id+": fixed damage requires burst, field, bolt or mantle")
		if m.get("primary_delivery",false) and (m.op!="burst" or m.events.keys()!=["ON_FINISH_CAST"] or not m.get("requires",[]).has("movement")): errors.append(id+": primary delivery is reserved for movement completion bursts")
		if m.op=="mantle" and float(m.events.get("ON_DEATH",0))>0 and m.get("response","")=="heal": errors.append(id+": death cannot restore health")
	for rule: Dictionary in data.get("affinities", []):
		if float(rule.get("multiplier", -1)) < 0: errors.append("Negative affinity")
		if not _number(rule.get("power_percent", 100)) or float(rule.get("power_percent", 100)) < 0: errors.append("Invalid affinity power percentage")
		if rule.get("event", "*") != "*" and rule.event not in EVENTS: errors.append("Unknown affinity event")
	for key: String in data.rules:
		if not _number(data.rules[key]) or float(data.rules[key]) < 0: errors.append("Invalid global rule " + key)
	for key in ["channel_speed", "weakening_cap", "barrier_cap", "critical_chance"]:
		if float(data.rules.get(key, 0)) > 1: errors.append(key + " must be between 0 and 1")
	for key in ["event_budget", "max_fields", "max_statuses", "max_projectiles"]:
		if float(data.rules.get(key, 0)) < 1 or float(data.rules.get(key, 0)) > 256: errors.append(key + " must be 1..256")
	return errors

func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

func valid_roll(value: Variant) -> bool:
	if not value is Dictionary or not value.get("op") in OPERATIONS or not value.get("event") in EVENTS or not value.get("values") is Dictionary: return false
	if value.has("tier") and str(value.tier) not in TIERS: return false
	for field in ["family","name"]:
		if not value.get(field) is String: return false
	for amount: Variant in value.values.values():
		if not _number(amount) or float(amount)<0: return false
	if value.op=="legacy": return true
	for field in ["requires","excludes","provides"]:
		if not value.get(field) is Array: return false
	if not value.values.has("amount"): return false
	if value.op in ["weaken","empower"] and (not value.values.has("duration") or not value.values.has("stacks")): return false
	if value.op=="mantle" and (not value.values.has("duration") or not value.values.has("radius")): return false
	return true

func tier_of(modifier: Dictionary) -> String:
	var tier := str(modifier.get("tier", ""))
	if tier in TIERS: return tier
	var definition: Variant = data.get("modifiers", {}).get(str(modifier.get("id", "")), {})
	if definition is Dictionary and str(definition.get("tier", "")) in TIERS:
		return str(definition.tier)
	return "basic"

func capabilities(id: String, installed: Array = []) -> Array:
	var caps: Array = data.skills[id].get("tags", []).duplicate()
	for modifier: Dictionary in installed:
		for tag: String in modifier.get("provides", []):
			if not caps.has(tag): caps.append(tag)
	return caps

func compatible(id: String, modifier: Dictionary, installed: Array) -> bool:
	var caps := capabilities(id, installed)
	for tag: String in modifier.get("requires", []):
		if not caps.has(tag): return false
	for tag: String in modifier.get("excludes", []):
		if caps.has(tag): return false
	if modifier.has("event") and not event_supported(str(modifier.event), caps, modifier): return false
	return true

func event_supported(event: String, caps: Array, modifier: Dictionary) -> bool:
	if event in REACTIONS: return modifier.op == "mantle" and (event != "ON_BLOCK" or caps.has("block"))
	if event == "ON_THIS_BUFF_EXPIRED": return caps.has("buff") and caps.has("duration")
	if event == "ON_BUFF_RECEIVED": return caps.has("buff") or modifier.op == "empower"
	return not EVENT_TAGS.has(event) or caps.has(EVENT_TAGS[event])

func _matches(rule: Dictionary, id: String, family: String, item: String) -> bool:
	return str(rule.get("item","*")) in ["*",item] and str(rule.get("skill","*")) in ["*",id,str(data.skills[id].type)] and str(rule.get("family","*")) in ["*",family]

func roll_weights(id: String, m: Dictionary, installed: Array, item: String, axis: String, event: String = "") -> Dictionary:
	var weights: Dictionary = m.get("events" if axis == "event" else "stats", {}).duplicate()
	var caps := capabilities(id, installed)
	for key: String in weights:
		if axis == "event" and not event_supported(key,caps,m): weights[key]=0.0
		for rule: Dictionary in data.get("affinities", []):
			if not _matches(rule,id,str(m.family),item): continue
			if axis == "event" and rule.get("event","*") == key and rule.get("stat","*") == "*": weights[key]*=float(rule.multiplier)
			if axis == "stat" and rule.get("stat","*") == key and rule.get("event","*") in ["*",event]: weights[key]*=float(rule.multiplier)
	return weights

func eligible(id: String, installed: Array, item_type: String = "any") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key: String in data.modifiers:
		var m: Dictionary = data.modifiers[key]
		if not bool(m.get("enabled", true)) or not compatible(id, m, installed): continue
		var duplicate := false
		for owned: Dictionary in installed:
			if owned.get("family", "") == m.family: duplicate = true
		if duplicate: continue
		var weight: float = float(m.weight)
		for rule: Dictionary in data.get("affinities", []):
			if str(rule.get("item", "*")) not in ["*", item_type]: continue
			if str(rule.get("skill", "*")) not in ["*", id, str(data.skills[id].type)]: continue
			if str(rule.get("family", "*")) not in ["*", str(m.family)]: continue
			if rule.get("event","*") != "*" or rule.get("stat","*") != "*": continue
			weight *= float(rule.get("multiplier", 1.0))
		var events := roll_weights(id,m,installed,item_type,"event")
		if not events.values().any(func(v): return float(v)>0): continue
		if float(m.get("variant_weight", 1)) <= 0: continue
		if weight > 0: result.append({"id": key, "family": m.family, "weight": weight, "variant_weight": float(m.get("variant_weight", 1))})
	return result

func offers(id: String, installed: Array, seed_value: int, item_type: String = "any") -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pool := eligible(id, installed, item_type)
	var result: Array = []
	# Group by family: adding variants never multiplies the family probability.
	var families: Dictionary = {}
	for entry: Dictionary in pool:
		if not families.has(entry.family): families[entry.family] = []
		families[entry.family].append(entry)
	while result.size() < 5 and not families.is_empty():
		var weights: Dictionary = {}
		for family: String in families: weights[family] = float(families[family][0].weight)
		var family := weighted(weights, rng)
		var variants: Dictionary = {}
		for entry: Dictionary in families[family]: variants[entry.id] = entry.variant_weight
		var chosen := weighted(variants, rng)
		families.erase(family)
		if chosen.is_empty(): continue
		var m: Dictionary = data.modifiers[chosen].duplicate(true)
		m["id"] = chosen
		m["event"] = weighted(roll_weights(id,m,installed,item_type,"event"), rng)
		m["stat"] = weighted(roll_weights(id,m,installed,item_type,"stat",m.event), rng)
		if m.has("chance_range"): m.chance=snappedf(rng.randf_range(float(m.chance_range[0]),float(m.chance_range[1])),.001)
		if m.op in ["weaken","empower","recover","leech"] and m.stat.is_empty(): continue
		var values: Dictionary = {}
		for key: String in m.get("values", {}):
			var bounds: Array = m.values[key]
			values[key] = snappedf(rng.randf_range(float(bounds[0]), float(bounds[1])), 0.001)
		m["values"] = values
		for rule: Dictionary in data.get("affinities", []):
			if _matches(rule,id,str(m.family),item_type) and rule.get("event","*") in ["*",m.event] and rule.get("stat","*") in ["*",m.stat] and values.has("amount"):
				values.amount *= float(rule.get("power_percent",100)) / 100.0
		result.append(m)
	return result

func weighted(weights: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for value: Variant in weights.values(): total += maxf(0, float(value))
	if total <= 0: return ""
	var roll := rng.randf() * total
	for key: String in weights:
		roll -= maxf(0, float(weights[key]))
		if roll <= 0: return key
	return str(weights.keys().back())

func compile(id: String, installed: Array) -> Dictionary:
	var result: Dictionary = data.skills[id].duplicate(true)
	result.merge({"power_scale": 1.0, "area_scale": 1.0, "duration_scale": 1.0, "cost_scale": 1.0, "cooldown_scale": 1.0, "handlers": [], "projectiles": 1, "chain_hops": 0, "chain_range": 5.0, "chain_retention": 0.8, "pierce": 0, "echo": 0, "modifiers": installed.duplicate(true)}, true)
	result.chain_policy = "nearest"
	result.chain_delay = 0.0
	result.echo_scale = .5
	result.echo_delay = .35
	for m: Dictionary in installed:
		var value: float = float(m.get("values", {}).get("amount", 0))
		match str(m.op):
			"power": result.power_scale += value
			"area": result.area_scale += value
			"range": result.range *= 1 + value
			"duration": result.duration_scale += value
			"efficiency": result.cost_scale -= value
			"tempo": result.cooldown_scale -= value
			"projectiles": result.projectiles += int(value)
			"chain":
				result.chain_hops += int(value)
				result.chain_range = float(m.values.get("range", 5))
				result.chain_retention = float(m.values.get("retention", 0.8))
				result.chain_policy = str(m.get("target_policy", "nearest"))
				result.chain_delay = float(m.values.get("delay",0))
			"pierce": result.pierce += int(value)
			"echo":
				result.echo = 1
				result.echo_scale = value
				result.echo_delay = float(m.values.get("delay",.35))
			"legacy":
				result.power_scale += float(m.values.get("power", 0))
				result.cost_scale -= float(m.values.get("cost", 0))
				result.cooldown_scale -= float(m.values.get("cooldown", 0))
				result.range *= 1 + float(m.values.get("range", 0))
			_: result.handlers.append(m)
		result.cost_scale += float(m.get("cost_increase", 0))
	result.cost_scale = clampf(result.cost_scale, 0.25, 5)
	result.cooldown_scale = clampf(result.cooldown_scale, 0.25, 5)
	result.radius *= sqrt(maxf(0.1, result.area_scale))
	if str(result.type).ends_with("cone"): result.range *= sqrt(maxf(0.1, result.area_scale))
	result.chain_hops = mini(result.chain_hops, int(data.rules.max_chain_hops))
	result.projectiles = mini(result.projectiles, int(data.rules.max_projectiles))
	return result

func describe(m: Dictionary, skill_id: String = "", installed: Array = []) -> String:
	var parts: Array[String] = ["%s · %s" % [str(m.get("name", "Evolution")), tier_of(m).capitalize()], str(m.get("event", "PASSIVE")).replace("ON_", "").replace("_", " ").capitalize()]
	if m.op not in PASSIVE_OPS:
		var chance_text:=("%.1f" % (float(m.get("chance",1))*100)).trim_suffix(".0")
		parts.insert(1,"%s%% chance to %s" % [chance_text,effect_name(m)])
	if not str(m.get("stat", "")).is_empty(): parts.append("Stat: " + str(m.stat).replace("_", " "))
	for key: String in m.get("values", {}):
		var value: float=float(m.values[key])
		var unit := ""
		var label := key.capitalize()
		if key in ["duration","delay","interval"]: unit=" s"
		elif key in ["radius","range"]: unit=" m"
		elif key=="retention": value*=100; unit="% per hop"
		elif key=="amount" and m.op not in ["recover","chain","pierce","projectiles"] and m.get("response","")!="fixed_damage":
			value*=100; unit="%"
			label={"power":"Increased power","area":"Increased area","range":"Increased range","duration":"Increased duration","efficiency":"Reduced mana cost","tempo":"Reduced cooldown","leech":"Damage leeched"}.get(str(m.op),"Effect strength")
		elif key=="amount" and m.op=="chain": label="Additional hops"
		parts.append("%s: %s%s" % [label,str(snappedf(value,.01)),unit])
	parts.append("Activation: %d%% | interval: %.2fs" % [roundi(float(m.get("chance", 1)) * 100), float(m.get("icd", 0))])
	parts.append(str(m.get("description", "")))
	if not m.get("requires",[]).is_empty(): parts.append("Requires: "+", ".join(m.requires))
	if not m.get("provides",[]).is_empty(): parts.append("Enables support for: "+", ".join(m.provides))
	if m.op=="area" and not skill_id.is_empty():
		var receivers: Array[String]=[]
		if data.skills[skill_id].tags.has("area"): receivers.append(str(data.skills[skill_id].name)+" native area")
		for provider: Dictionary in installed:
			if provider.get("provides",[]).has("area"): receivers.append(str(provider.name))
		parts.append("Enlarges: "+", ".join(receivers)+". Radius becomes %.1f%% of its original size." % (100*sqrt(1+float(m.values.amount))))
	return "\n".join(parts)

func effect_name(m: Dictionary) -> String:
	match str(m.op):
		"burst": return "release a healing pulse" if m.get("response","")=="heal" else "release an area burst"
		"field": return "create a damaging field"
		"bolt": return "launch a secondary projectile"
		"weaken": return "reduce enemy "+str(m.get("stat","stats")).replace("_"," ")
		"empower": return "gain "+str(m.get("stat","power")).replace("_"," ")
		"recover": return "restore "+str(m.get("stat","health"))
		"leech": return "leech "+str(m.get("stat","health"))
		"barrier": return "gain an overheal barrier"
		"mantle": return "release the ward's "+("healing" if m.get("response","")=="heal" else "damage")+" response"
	return str(m.op).replace("_"," ")
