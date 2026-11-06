extends SceneTree
var failures := 0
func check(ok: bool, description: String) -> void:
 if not ok: failures += 1; push_error(description)
func _initialize() -> void: call_deferred("run")
func run() -> void:
 var game = load("res://scenes/main.tscn").instantiate(); root.add_child(game)
 game.set_process(false); game.player.set_physics_process(false)
 for e in game.enemies: e.set_physics_process(false)
 var enemy: CharacterBody3D = game.enemies[0]
 enemy.global_position = game.player.global_position + Vector3(0,0,-2)
 game.camera.global_position = game.player.global_position + Vector3(0,2,5)
 game.camera.look_at(enemy.global_position + Vector3.UP * .7)
 await physics_frame
 var point: Vector2 = game.camera.unproject_position(enemy.global_position + Vector3.UP * .7)
 check(game._enemy_at_screen(point) == enemy, "Screen ray selects enemy")
 var press := InputEventMouseButton.new(); press.button_index = MOUSE_BUTTON_RIGHT; press.pressed = true; press.position = point
 var release := InputEventMouseButton.new(); release.button_index = MOUSE_BUTTON_RIGHT; release.pressed = false; release.position = point
 game.target = null; game._unhandled_input(press); game._unhandled_input(release)
 check(game.target == enemy and game.auto_attack_enabled, "Right click engages target")
 game.auto_attack_enabled = false; game.target = null
 game._unhandled_input(press)
 var motion := InputEventMouseMotion.new(); motion.screen_relative = Vector2(20,0)
 game._unhandled_input(motion); game._unhandled_input(release)
 check(not game.auto_attack_enabled and game.target == null, "Right drag rotates camera without attacking")
 check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Releasing right button restores cursor")
 game.queue_free(); await process_frame
 print("RIGHT CLICK COMBAT: ", failures, " failures")
 quit(failures)
