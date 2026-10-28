extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("_run")
func capture(path: String) -> void:
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(path)
func _run() -> void:
	root.size=Vector2i(1600,900)
	var game: Node=load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.state.earned_skill_points=50; game.state.skill_points=50
	for stage in range(10): check(game.state.install_evolution("melee",stage,0),"Melee stage "+str(stage))
	for stage in range(5): check(game.state.install_evolution("cast",stage,0),"Cast stage "+str(stage))
	game.hud.refresh()
	await process_frame
	await process_frame
	await capture("res://.godot/skill-hotbar-preview.png")
	check(game.hud.hotbar.size()==10,"Ten hotbar controls")
	game.hud.toggle_panel("skills")
	for i in range(4): await process_frame
	var rows: Array=game.hud.overlay_content.get_children()
	check(rows.size()==12,"Actions, ten rows and footer")
	var full: Control=rows[1]
	check(full.get_global_rect().end.x<=root.get_visible_rect().size.x-48,"Ten upgrades fit with room for tooltips")
	var strip: Control=full.get_child(1)
	var style: StyleBoxFlat=strip.get_theme_stylebox("panel")
	check(style.corner_radius_top_left==0 and style.corner_radius_bottom_right==0,"Square grouping panel corners")
	var choices: HBoxContainer=strip.get_child(0).get_child(0)
	check(choices.get_child_count()==11 and choices.get_child(10).text=="10/10","Completed count")
	var partial: HBoxContainer=rows[2].get_child(1).get_child(0).get_child(0)
	check(partial.get_child_count()==6 and partial.get_child(5).text=="+\n5 / 10","Partial count")
	await capture("res://.godot/skill-panel-preview.png")
	var installed_before: Array = game.state.skills["melee"].evolutions.duplicate(true)
	var offers_before: Dictionary = game.state.skill_offers.duplicate(true)
	var points_before: int = game.state.skill_points
	for stage in range(2):
		choices.get_child(stage).pressed.emit()
		for i in range(3): await process_frame
		var picker: PanelContainer = game.hud.skill_view.picker
		var details := picker.find_child("EnchantmentDetails", true, false) as Label
		check(picker.visible and details != null, "Installed stage opens its inspector")
		if details != null:
			check(details.text == game.state.skill_catalog.describe(installed_before[stage], "melee", installed_before), "Inspector displays selected installed enchantment")
		check(picker.find_children("*", "Button", true, false).size() == 1, "Inspector contains only a close button")
		check(game.state.skills["melee"].evolutions == installed_before and game.state.skill_offers == offers_before and game.state.skill_points == points_before, "Inspection does not change choices or points")
		if stage == 1: await capture("res://.godot/skill-inspection-preview.png")
	partial.get_child(5).pressed.emit()
	for i in range(4): await process_frame
	check(game.hud.skill_view.picker.visible,"Picker opens")
	check(game.state.get_skill_offers("cast",5).size()==5,"Five saved choices")
	await capture("res://.godot/skill-choices-preview.png")
	print("SKILL UI: ",failures," failures")
	game.queue_free()
	await process_frame
	quit(failures)
