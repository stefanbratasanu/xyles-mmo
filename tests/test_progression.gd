extends SceneTree

const GameState = preload("res://scripts/game_state.gd")
var failures: int = 0


func _initialize() -> void:
	_test_bestiary()
	_test_evolutions()
	_test_quest()
	_test_crafting_and_death()
	_test_modifiers()
	_test_save_round_trip()
	_test_save_validation()
	if failures == 0:
		print("PASS · progression, quest, crafting, death, and save rules")
	quit(failures)


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _test_bestiary() -> void:
	var state = GameState.new()
	state.register_kill("normal", "Briarwolf")
	state.register_kill("normal", "Briarwolf")
	_check(state.earned_skill_points == 2, "Repeat normal kills must not award more skill points")
	state.register_kill("quest", "Oathbound Guardian")
	state.register_kill("boss", "Hollow Regent")
	_check(state.earned_skill_points == 10, "Regional categories should award 2+5+3 skill points")
	for region in range(8):
		state.current_region = "region_%d" % region
		for kind in ["normal", "quest", "boss"]:
			state.register_kill(kind, "Test")
	_check(state.earned_skill_points == 50 and state.skill_points == 50, "Lifetime skill points must cap at 50")
	state.free()


func _test_evolutions() -> void:
	var state = GameState.new()
	state.earned_skill_points = 20
	state.skill_points = 20
	_check(state.evolve_skill("melee", 0), "First rank must be legal")
	_check(state.evolve_skill("melee", 0), "Second rank must be legal")
	_check(not state.evolve_skill("melee", 0), "Third straight investment must require spreading")
	_check(state.evolve_skill("melee", 1) and state.evolve_skill("melee", 2), "Other branches must be available")
	_check(state.evolve_skill("melee", 0), "Spreading should unlock the next rank")
	_check(not state.respec_skill("melee", 1), "Respec must not invalidate branch balance")
	_check(state.respec_skill("melee", 0), "A single top node should be reclaimable")
	_check(state.earned_skill_points == 20 and state.skill_points == 16, "Respec refunds available points without changing lifetime earnings")
	for index in range(20):
		state.evolve_skill("melee", index % 3)
	_check(state.skills["melee"]["investments"] == 10, "Skill tree must cap at ten evolutions")
	state.free()


func _test_quest() -> void:
	var state = GameState.new()
	state.register_kill("normal", "Briarwolf")
	_check(state.quests[0]["stage"] == 0, "Kills before accepting must not advance a quest")
	state.start_quest()
	for index in range(3):
		state.register_kill("normal", "Briarwolf")
	_check(state.quests[0]["stage"] == 2, "Three normal kills should unlock the guardian stage")
	state.register_kill("boss", "Hollow Regent")
	_check(state.quests[0]["stage"] == 2, "A later objective must not skip the active guardian stage")
	state.register_kill("quest", "Oathbound Guardian")
	_check(state.quests[0]["stage"] == 3, "Guardian kill should unlock the boss stage and clue")
	state.register_kill("boss", "Hollow Regent")
	_check(state.quests[0]["completed"], "Boss kill should complete the quest")
	state.free()


func _test_crafting_and_death() -> void:
	var state = GameState.new()
	state.rng.seed = 7919
	var before_wood: int = state.wood
	_check(state.craft_sword("basic"), "Base sword must be craftable with starter resources")
	_check(state.wood == before_wood - 100 and state.inventory[0]["modifiers"].size() == 2, "Base crafting must consume 100 wood and roll two modifiers")
	_check(not state.craft_sword("legendary"), "High-tier crafting must reject insufficient materials")
	state.wood = 1000
	state.iron = 1000
	_check(state.craft_sword("legendary") and state.inventory[1]["modifiers"].size() == 5, "Legendary crafting needs five modifiers")
	_check(state.get_exposure_chance({"durability": 50.0}) == 0.0, "50% is not exposed")
	_check(state.get_exposure_chance({"durability": 49.0}) > 0.0, "Below 50% must have a drop chance")
	state.equipment[0]["durability"] = 0.0
	var dropped_id: String = state.equipment[0]["id"]
	var result: Dictionary = state.apply_death()
	var found := false
	for item: Dictionary in result["dropped"]:
		found = found or item["id"] == dropped_id
	_check(found, "Broken equipment must drop on death")
	for item: Dictionary in state.equipment:
		_check(item["id"] != dropped_id, "Dropped equipment must leave equipped slots")
	state.gold = 1000
	_check(state.repair_all(), "Damaged equipment should be repairable")
	for item: Dictionary in state.equipment:
		_check(item["durability"] == 100.0 and not item["exposed"], "Repair must remove exposure")
	state.free()


func _test_save_round_trip() -> void:
	var state = GameState.new()
	state.register_kill("normal", "Briarwolf")
	state.start_quest()
	state.evolve_skill("cast", 1)
	_check(state.save_game("res://.godot/xyles_test_save.json"), "Save should write successfully")
	var restored = GameState.new()
	_check(restored.load_game("res://.godot/xyles_test_save.json"), "Save should reload successfully")
	_check(restored.earned_skill_points == 2 and restored.skill_points == 1, "Save must preserve earned and unspent points")
	_check(restored.skills["cast"]["ranks"][1] == 1, "Save must preserve individual evolution choices")
	_check(restored.quests[0]["stage"] == 1, "Save must preserve quest progress")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("res://.godot/xyles_test_save.json"))
	state.free()
	restored.free()


func _test_modifiers() -> void:
	var state = GameState.new()
	state.equipment.resize(1)
	state.equipment[0]["modifiers"] = ["+8 maximum vitality", "+6 maximum mana",
		"+4% attack power", "+3% armor", "+5% mana recovery", "+8% Iron Cleave damage",
		"+8% Ember Bolt damage", "+10% restoring power", "+6% guard strength"]
	var modifiers: Dictionary = state.get_equipment_modifiers()
	_check(is_equal_approx(modifiers["max_hp"], 8.0) and is_equal_approx(modifiers["max_mana"], 6.0), "Equipment must provide flat resource bonuses")
	_check(is_equal_approx(modifiers["attack_multiplier"], 1.04) and is_equal_approx(modifiers["armor"], 0.03), "Equipment must provide attack and armor bonuses")
	_check(is_equal_approx(modifiers["melee_multiplier"], 1.08) and is_equal_approx(modifiers["cast_multiplier"], 1.08), "Skill-specific attack modifiers must affect their skills")
	_check(is_equal_approx(modifiers["support_multiplier"], 1.1) and is_equal_approx(modifiers["block_strength"], 1.06), "Support and block modifiers must be functional")
	_check(is_equal_approx(modifiers["mana_regen"], 1.05), "Mana recovery modifier must affect regeneration")
	_check(state.max_hp == 120.0 and state.max_mana == 100.0, "Equipment helper must not alter base maxima")
	state.equipment[0]["durability"] = 0.0
	_check(state.get_equipment_modifiers()["attack_multiplier"] == 1.0, "Broken equipment must stop granting modifiers")
	state.free()


func _test_save_validation() -> void:
	var state = GameState.new()
	var path := "res://.godot/xyles_test_save.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "skill_ranks": []}))
	file.close()
	_check(not state.load_game(path), "Wrong-shaped skill ranks must fail loading without errors")
	file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"version": 1, "earned_skill_points": 8,
		"skill_ranks": {"melee": "invalid", "cast": [3, 3, 3]},
		"equipment": [false, {"tier": "invalid", "slot": "weapon"}],
		"bestiary": {"bad": false},
		"quests": [{"id": "a_debt_of_iron", "active": false, "stage": 999}]}))
	file.close()
	_check(state.load_game(path), "Malformed optional records should be ignored safely")
	_check(state.skill_points == 8 and state.skills["cast"]["investments"] == 0, "Loaded spending must never exceed lifetime earnings")
	_check(state.equipment.is_empty() and state.bestiary.is_empty(), "Invalid item and bestiary records must be discarded")
	_check(state.quests[0]["stage"] == 0, "Inactive saved quests must return to the starter stage")
	_check(state.quests[0]["stages"].size() == 5, "Saved content must not replace authored stage definitions")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	state.free()
