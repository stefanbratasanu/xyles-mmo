extends SceneTree
const State = preload("res://scripts/game_state.gd")
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; push_error(message)
func same_json_value(a: Variant,b: Variant) -> bool:
	# JSON has one number type. Godot parses integers as floats and can shift a
	# full-precision decimal by one binary ULP (seed 2: 0.23700000000000002 -> 0.237).
	if (a is int or a is float) and (b is int or b is float):
		if a is int and b is int: return a==b
		var magnitude:=maxf(1.0,maxf(absf(float(a)),absf(float(b))))
		return absf(float(a)-float(b))<=magnitude*1e-14
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key: Variant in a:
			if not b.has(key) or not same_json_value(a[key],b[key]): return false
		return true
	if a is Array and b is Array:
		if a.size()!=b.size(): return false
		for index in range(a.size()):
			if not same_json_value(a[index],b[index]): return false
		return true
	return typeof(a)==typeof(b) and a==b
func _initialize() -> void:
	var state := State.new()
	state.skill_seed=0
	var cat: Resource = state.skill_catalog
	check(cat.validate().is_empty(), "Catalog validation: " + str(cat.validate()))
	check(state.loadout.size()==10, "Ten initial slots")
	check(cat.data.skills.cast.type=="cast_projectile", "Slot two is a pure projectile")
	for id: String in cat.data.skills:
		var installed: Array=[]
		for stage in range(10):
			var options: Array=cat.offers(id,installed,1000+stage)
			check(options.size()==5,id+" must have five choices at stage "+str(stage))
			check(not options.is_empty(), id + " has no viable choice at stage " + str(stage))
			if options.is_empty(): break
			var families: Array=[]
			for m: Dictionary in options:
				check(not families.has(m.family),"Distinct offer families")
				check(cat.compatible(id,m,installed),"Offer compatibility "+str(m.name))
				families.append(m.family)
			installed.append(options[0])
			cat.compile(id,installed)
		print(id, " : ", installed.size(), " stages; ", cat.eligible(id,[]).size(), " base variants")
	state.earned_skill_points=50
	state.skill_points=50
	var first: Array=state.get_skill_offers("cast",0).duplicate(true)
	check(first.size()==5, "Five choices")
	check(state.install_evolution("cast",0,0), "Install first enchantment")
	check(state.skill_points==49, "Spend one point")
	check(state.reset_evolutions()==1, "Refund one point")
	check(state.get_skill_offers("cast",0)==first, "Reset retains original rolls")
	check(state.install_evolution("cast",0,0), "Reinstall retained choice")
	var path := "res://.godot/test_skill_save.json"
	check(state.save_game(path),"Save")
	var restored := State.new()
	check(restored.load_game(path),"Load")
	check(same_json_value(restored.get_skill_offers("cast",0),first),"Save retains offers")
	check(same_json_value(restored.skills.cast.evolutions,state.skills.cast.evolutions),"Save retains resolved values")
	check(restored.skill_points==49,"Save conserves points")
	var legacy := State.new()
	legacy.earned_skill_points=7
	legacy.skills.melee.history=[0,1,2]
	legacy._restore_evolutions({})
	check(legacy.skills.melee.evolutions.size()==3 and legacy.skill_points==4,"Legacy migration preserves point spending")
	check(is_equal_approx(legacy.compiled_skill("melee").power_scale,1.24),"Legacy migration preserves power")
	var draft: Resource=cat.duplicate(true)
	draft.data.modifiers.power.events={"ON_HIT_TAKEN":1}
	check(not draft.validate().is_empty(),"Reject unimplemented event/operation pairing")
	state.free(); restored.free(); legacy.free()
	print("SKILL CATALOG: ", failures, " failures")
	quit(failures)
