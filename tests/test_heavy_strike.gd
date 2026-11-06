extends SceneTree
var failures := 0
func check(ok: bool, label: String) -> void:
 if not ok: failures += 1; push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 await process_frame
 game.set_process(false); game.player.set_physics_process(false); game.skill_runtime.set_physics_process(false)
 for e in game.enemies: e.set_physics_process(false)
 var s = game.state
 check(s.skill_catalog.validate().is_empty(), "Catalog validates")
 check(s.is_skill_available("heavy_strike") and s.assign_hotbar("heavy_strike",0), "Heavy Strike learned and assignable")
 var c: Dictionary = s.compiled_skill("heavy_strike")
 check(c.power == 2.0 and c.cost == 10.0 and c.cooldown == 5.0, "200%, 10 mana and 5 second cooldown")
 game.hud.toggle_panel("inventory")
 check(not game.hud.character_values.has("strike_damage"), "No skill damage in character stats")
 game.hud.close_panel(); game.hud.toggle_panel("skills")
 var found := false
 for b: Button in game.hud.overlay_content.find_children("*", "Button", true, false):
  if b.get("drag_payload") is Dictionary and b.drag_payload.get("id", "") == "heavy_strike": found = true
 check(found, "Heavy Strike visible in learned skills")
 game.hud.close_panel(); game.hud._toggle_developer_mode(); game.hud._switch_panel("dev_skills")
 var heavy: Button
 for b: Button in game.hud.overlay_content.find_children("*", "Button", true, false):
  if b.get("drag_payload") is Dictionary and b.drag_payload.get("id", "") == "heavy_strike": heavy = b
 check(heavy != null, "Heavy Strike visible in DEV")
 if heavy:
  game.hud.hotbar[1]._drop_data(Vector2.ZERO, heavy.drag_payload)
  check(s.loadout[1] == "heavy_strike", "DEV skill can be dragged")
 game.hud._toggle_developer_mode()
 var enemy: CharacterBody3D = game.enemies[0]
 enemy.global_position = game.player.global_position + Vector3(0,0,-2)
 enemy.max_hp = 10000; enemy.hp = 10000; game.target = enemy
 s.skill_catalog.data.rules.critical_chance = 0.0
 var rand := RandomNumberGenerator.new(); rand.seed = 88
 var expected: float = s.roll_attack_damage(rand) * 2.0 * .85
 game.skill_runtime.rng.seed = 88
 var mana: float = s.mana
 check(game.skill_runtime.cast_slot(0), "Can start Heavy Strike")
 check(s.mana == mana - 10 and game.player.heavy_strike_active and game.player.action_active, "Mana and two-handed motion")
 check(str(game.player.animation_player.current_animation).contains("greatsword_AttackA2HandMelee"), "Dedicated two-hand motion")
 game.skill_runtime._physics_process(.60)
 check(enemy.hp == 10000, "Damage waits for impact")
 game.skill_runtime._physics_process(.06)
 check(is_equal_approx(10000 - enemy.hp, expected), "Deals 200% attack after armor")
 check(game.combat_effects.heavy_strike_effect != null and not game.combat_effects.heavy_emitters.is_empty(), "Heavy Effekseer effect loaded and played")
 check(not game.skill_runtime.cast_slot(0), "Heavy cooldown enforced")
 game.skill_runtime.skill_cooldowns.clear()
 enemy.global_position = game.player.global_position + Vector3(0,0,-10)
 var before_mana: float = s.mana
 check(not game.skill_runtime.cast_slot(0) and s.mana == before_mana, "Out of range costs no mana")
 enemy.global_position = game.player.global_position + Vector3(0,0,-2)
 s.mana = 9
 check(not game.skill_runtime.cast_slot(0) and s.mana == 9, "Insufficient mana prevents Heavy Strike")
 s.mana = before_mana
 var before_evade: float = enemy.hp
 check(game.skill_runtime.cast_slot(0), "Second Heavy Strike starts")
 enemy.global_position += Vector3(0,0,-10)
 game.skill_runtime._physics_process(.66)
 check(enemy.hp == before_evade, "Enemy leaving range avoids the delayed strike")
 game.skill_runtime.skill_cooldowns.clear()
 enemy.global_position = game.player.global_position + Vector3(0,0,-2)
 game.player.action_active = false
 game.player.upper_body_player.stop()
 game._engage_auto_attack(enemy)
 var hp: float = enemy.hp
 var m: float = s.mana
 game._process_auto_attack()
 check(enemy.hp < hp and s.mana == m, "Auto attack hits without mana")
 hp = enemy.hp
 game._process_auto_attack()
 check(enemy.hp == hp, "Auto attack respects cooldown")
 game.skill_runtime._physics_process(.81); game.player.upper_body_player.stop()
 enemy.global_position += Vector3(0,0,-10)
 game._process_auto_attack(); check(enemy.hp == hp, "Auto attack waits out of range")
 enemy.global_position = game.player.global_position + Vector3(0,0,-2)
 game.player.action_active = true; game._process_auto_attack(); check(enemy.hp == hp, "Auto attack does not interrupt a full-body skill")
 game.player.action_active = false; game._process_auto_attack(); check(enemy.hp < hp and s.mana == m, "Auto resumes when able")
 enemy.dead = true; game._process_auto_attack(); check(not game.auto_attack_enabled, "Auto attack stops when target dies")
 game.queue_free(); await process_frame
 print("HEAVY STRIKE AND AUTO ATTACK: ", failures, " failures")
 quit(failures)
