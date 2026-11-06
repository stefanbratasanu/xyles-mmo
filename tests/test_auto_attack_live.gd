extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var game=load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 game.debug_invulnerable = true
 for e in game.enemies: e.set_physics_process(false)
 var enemy=game.enemies[0]
 enemy.global_position=game.player.global_position+Vector3(0,0,-2)
 enemy.max_hp=10000; enemy.hp=10000
 game.state.max_mana=0; game.state.mana=0
 game._engage_auto_attack(enemy)
 await create_timer(4.0).timeout
 var record: Dictionary = game.skill_runtime.debug_stats.get("basic_attack", {})
 var hits: int = int(record.get("parts", {}).get("base", {}).get("hits", 0))
 print("LIVE AUTO ATTACK hits=", hits, " mana=",game.state.mana, " remaining_hp=",enemy.hp)
 var failed: bool = hits < 3 or game.state.mana != 0
 game.queue_free(); await process_frame
 quit(1 if failed else 0)
