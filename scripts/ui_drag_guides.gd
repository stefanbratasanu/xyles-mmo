extends Control
var hud: CanvasLayer
func _draw() -> void:
	if not is_instance_valid(hud.drag_target): return
	var peers: Array = hud.floating_windows.values()
	peers.append(hud.window_frame)
	for peer: Control in peers:
		if not is_instance_valid(peer) or not peer.is_visible_in_tree(): continue
		var rect := peer.get_global_rect()
		var active: bool = peer == hud.drag_target
		draw_rect(rect, Color(0.95, 0.8, 0.4, 0.12) if active else Color(0.4, 0.8, 0.9, 0.04), true)
		draw_rect(rect, Color("f1cf7b") if active else Color(0.5, 0.8, 0.9, 0.7), false, 2 if active else 1)
		if active:
			draw_rect(rect.grow(8), Color(0.95, 0.8, 0.4, 0.4), false, 1)
