extends SceneTree
var failures := 0
func check(ok: bool, message: String):
 if not ok: failures += 1; push_error(message)
func _initialize(): call_deferred("run")
func run():
 var game = load("res://scenes/main.tscn").instantiate()
 root.add_child(game)
 for i in range(5): await process_frame
 var hud = game.hud
 check(not hud.floating_windows.has("menu") and not hud.floating_windows.has("system_log"), "Removed permanent panels")
 check(is_instance_valid(hud.drag_guides), "Drag outlines exist")
 check(not hud.corner_menu.visible, "Foldout starts closed")
 hud.toggle_panel("character")
 game.state.hp = 57
 hud.refresh()
 check(hud.character_values.hp.text.begins_with("57 /"), "Character values follow live state")
 hud.toggle_panel("settings")
 for index in range(4):
  hud.settings_tab = index
  hud._render_overlay()
  for i in range(3): await process_frame
  check(hud.overlay_content.get_child(1).visible == (index == 0), "Camera tab visibility")
  check(hud.overlay_content.get_child(2).visible == (index == 1), "Audio tab visibility")
 hud.close_panel()
 hud.drag_target = hud.floating_windows.hotbar
 hud.drag_id = "hotbar"
 hud.drag_guides.queue_redraw()
 if DisplayServer.get_name() != "headless":
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png("res://.godot/drag-guides-review.png")
 var release = InputEventMouseButton.new()
 release.button_index = MOUSE_BUTTON_LEFT
 hud._input(release)
 check(hud.drag_target == null, "Release ends outline display")
 game.queue_free()
 await process_frame
 print("CORNER UI: ", failures, " failures")
 quit(failures)
