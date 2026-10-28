extends SceneTree
const Snap = preload("res://scripts/window_snap.gd")
var failures := 0
var game: Node
var hud: CanvasLayer
func check(ok: bool, message: String) -> void:
	if not ok:
		failures+=1
		push_error(message)
func _initialize() -> void:
	call_deferred("_run")
func clear_of(control: Control, peers: Array) -> bool:
	var obstacles: Array[Rect2]=[]
	for peer: Control in peers:
		if peer!=control and peer.is_visible_in_tree(): obstacles.append(peer.get_global_rect())
	return not Snap.overlaps(control.get_global_rect(),obstacles)
func _run() -> void:
	root.size=Vector2i(1600,900)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	game=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode=true
	game.set_process(false)
	game.player.set_physics_process(false)
	for enemy: Node in game.enemies: enemy.set_physics_process(false)
	hud=game.hud
	for i in range(5): await process_frame
	for control: Control in hud.floating_windows.values(): control.hide()
	var status: Control=hud.floating_windows.status
	var quest: Control=hud.floating_windows.quest
	status.show(); quest.show()
	quest.global_position=Vector2(650,250)
	status.global_position=quest.global_position+Vector2(20,20)
	hud.drag_target=status
	hud.drag_id="status"
	var release:=InputEventMouseButton.new()
	release.button_index=MOUSE_BUTTON_LEFT; release.pressed=false
	hud._input(release)
	check(clear_of(status,[quest]),"Actual HUD drop clears overlap")
	check(hud.drag_target==null,"Drop ends drag")
	check(hud.window_positions.status==status.position,"Drop persists settled position")
	var saved_position: Vector2=hud.window_positions.status
	status.global_position=Vector2(20,20)
	status.position=hud.window_positions.status
	hud._snap_window(status,true)
	check(status.position==saved_position,"Clear saved placement restores without drifting")
	# Exercise dynamic registration, which also restores a saved position.
	var restored: Control=hud._panel()
	hud._place(restored,Vector2(100,100),Vector2(180,110))
	hud.window_positions["snap_restore_test"]=quest.position
	hud._register_window(restored,"snap_restore_test")
	for i in range(4): await process_frame
	check(clear_of(restored,[status,quest]),"Restored dynamic HUD window settles clear")
	# The initial/full HUD settle uses actual control minimum sizes and peer rects.
	status.global_position=quest.global_position
	restored.global_position=quest.global_position
	await hud._settle_hud()
	check(clear_of(status,[quest,restored]) and clear_of(quest,[status,restored]),"Full HUD settle removes feasible saved overlaps")
	# Reopening a main draggable window must settle its saved position too.
	hud.window_positions.inventory=quest.position
	hud.toggle_panel("inventory")
	for i in range(5): await process_frame
	check(clear_of(hud.window_frame,[status,quest,restored]),"Saved inventory position settles against HUD")
	# A viewport resize may clamp the active panel into a fixed-anchor HUD panel.
	quest.hide(); restored.hide()
	status.global_position=Vector2(650,250)
	hud.window_frame.global_position=Vector2(976,100)
	check(clear_of(hud.window_frame,[status]),"Resize fixture starts clear")
	root.size=Vector2i(1200,800)
	for i in range(3): await process_frame
	check(clear_of(hud.window_frame,[status]),"Viewport resize keeps active and fixed-anchor HUD windows clear")
	root.size=Vector2i(1600,900)
	for i in range(3): await process_frame
	# Empty, genuinely impossible layouts remain stable rather than oscillating.
	hud.close_panel()
	quest.hide(); status.hide(); restored.hide()
	var huge: Control=hud._panel()
	hud._place(huge,Vector2(4,12),Vector2(1592,884))
	hud._register_window(huge,"snap_impossible_test")
	status.show(); status.global_position=Vector2(500,300)
	hud._snap_window(status,true)
	var impossible_position:=status.global_position
	for i in range(5): hud._snap_window(status,true)
	check(status.global_position==impossible_position,"Impossible packed viewport remains stable")
	huge.hide(); quest.show(); restored.show()
	quest.global_position=Vector2(1050,280)
	status.global_position=Vector2(760,280)
	restored.global_position=Vector2(550,280)
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/hud-snapping-preview.png")
	print("HUD SNAPPING: ",failures," failures")
	game.queue_free()
	await process_frame
	quit(failures)
