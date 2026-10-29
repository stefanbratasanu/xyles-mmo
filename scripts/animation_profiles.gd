extends RefCounted
## Per-weapon, per-delivery action presentation. No gameplay effects are previewed.
const SAVE_PATH := "res://saves/animation_profiles.json"
const WEAPONS := ["unarmed","sword","greatsword","staff","spear","bow"]
const ATTACK_TYPES := ["melee_cone","melee_area","melee_projectile","cast_cone","cast_area_self","cast_area_target","cast_projectile","cast_projectile_area","channel_ray","channel_projectiles","dash","cast_effect","block"]
const MOVEMENT := ["idle","run","sprint","walk_forward","walk_back","walk_left","walk_right","jump","fall","land","death"]
var path := SAVE_PATH
var overrides: Dictionary = {}

func actions() -> Array:
	return ATTACK_TYPES + MOVEMENT

func default_entry(weapon: String, action: String) -> Dictionary:
	var base := "greatsword" if weapon=="greatsword" else ("sword" if weapon=="sword" else "unarmed")
	var clip := ""
	var upper := action in ATTACK_TYPES and action not in ["block","dash"]
	var speed := 1.0
	if action in ["melee_cone","melee_projectile"]:
		clip = "actions/spear_thrust" if weapon=="spear" else "protof/"+base+"_attack"
	elif action=="melee_area":
		clip="protof/greatsword_AttackC2HandMelee" if weapon in ["greatsword","spear","staff"] else "protof/"+base+"_attack"
	elif action.begins_with("cast") or action.begins_with("channel"):
		clip="protof/wizard_support" if action=="cast_effect" else "protof/wizard_cast"
		speed=2.8 if action=="cast_effect" else 2.0
	elif action=="block": clip="protof/"+base+"_block"
	elif action=="dash": clip="procedural_roll"; upper=false
	elif action in ["idle","run","sprint"] or action.begins_with("walk_"):
		clip=("actions/staff_"+action) if weapon in ["staff","spear"] else "protof/"+base+"_"+action
	elif action=="jump": clip="protof/greatsword_JumpToApex2HandMelee" if weapon=="greatsword" else "protof/jump"
	elif action=="fall": clip="protof/greatsword_Falling2HandMelee" if weapon=="greatsword" else "protof/fall"
	elif action=="land": clip="protof/greatsword_LandingLight2HandMelee" if weapon=="greatsword" else "protof/land"
	elif action=="death": clip="protof/greatsword_DeathFront2HandMelee" if weapon=="greatsword" else "protof/death"
	return {"clip":clip,"speed":speed,"upper_body":upper}

func resolve(weapon: String, action: String, available: PackedStringArray = []) -> Dictionary:
	var entry: Dictionary=overrides.get(weapon,{}).get(action,default_entry(weapon,action)).duplicate(true)
	if not available.is_empty() and entry.clip!="procedural_roll" and not available.has(entry.clip):
		entry=default_entry(weapon,action)
		if not available.has(entry.clip):
			entry.clip="protof/unarmed_idle" if action=="idle" else ("protof/unarmed_run" if action in MOVEMENT else "protof/unarmed_attack")
	return entry

func set_entry(weapon: String, action: String, entry: Dictionary, available: PackedStringArray) -> bool:
	if weapon not in WEAPONS or action not in actions(): return false
	if not entry.get("clip") is String or (entry.clip!="procedural_roll" and not available.has(entry.clip)): return false
	if entry.clip=="procedural_roll" and action!="dash": return false
	if not (entry.get("speed") is float or entry.get("speed") is int) or not is_finite(float(entry.speed)) or float(entry.speed)<.1 or float(entry.speed)>4: return false
	if not entry.get("upper_body") is bool: return false
	if not overrides.has(weapon): overrides[weapon]={}
	overrides[weapon][action]={"clip":str(entry.clip),"speed":float(entry.speed),"upper_body":bool(entry.upper_body)}
	return true

func reset_entry(weapon: String, action: String) -> void:
	if overrides.has(weapon): overrides[weapon].erase(action)

func save() -> bool:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var file:=FileAccess.open(path+".pending",FileAccess.WRITE)
	if file==null: return false
	file.store_string(JSON.stringify({"version":1,"weapons":overrides},"  "))
	file.close()
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".pending"),ProjectSettings.globalize_path(path))==OK

func load_profiles(available: PackedStringArray) -> void:
	overrides.clear()
	if not FileAccess.file_exists(path): return
	var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("weapons") is Dictionary: return
	for weapon: String in parsed.weapons:
		if not parsed.weapons[weapon] is Dictionary: continue
		for action: String in parsed.weapons[weapon]:
			var entry: Variant=parsed.weapons[weapon][action]
			if entry is Dictionary: set_entry(weapon,action,entry,available)
