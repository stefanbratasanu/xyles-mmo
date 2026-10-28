extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok: failures+=1; push_error(message)
func _initialize() -> void: call_deferred("_run")
func _run() -> void:
	root.size=Vector2i(1400,900)
	root.gui_embed_subwindows=true
	var editor: Window=load("res://scripts/editor/skill_distribution_window.gd").new()
	root.add_child(editor)
	editor.popup_centered(Vector2i(1280,800))
	for i in range(3): await process_frame
	check(editor.entries.item_count>30,"Catalog is populated")
	check(editor.catalog.validate().is_empty(),"Initial draft is valid")
	check(editor.catalog.data.modifiers.chain.has("tier"), "Tier is available in the editor")
	editor._change(["modifiers", "chain", "tier"], "mythical")
	check(editor.catalog.data.modifiers.chain.tier == "mythical", "Tier can be edited")
	editor._undo()
	var original: float=editor.catalog.data.modifiers.chain.weight
	editor._change(["modifiers","chain","weight"],31.0)
	check(editor.dirty and editor.catalog.data.modifiers.chain.weight==31,"Change is a draft")
	editor._undo()
	check(editor.catalog.data.modifiers.chain.weight==original,"Undo")
	editor._redo()
	check(editor.catalog.data.modifiers.chain.weight==31,"Redo")
	editor._add_affinity()
	var index: int=editor.catalog.data.affinities.size()-1
	editor._change(["affinities",index,"item"],"greatsword")
	editor._change(["affinities",index,"event"],"ON_ENEMY_HIT_THIS_SKILL")
	editor._change(["affinities",index,"power_percent"],150.0)
	check(editor._save_to("res://.godot/distribution-test.tres")==OK,"Atomic draft save")
	var saved: Resource=load("res://.godot/distribution-test.tres")
	check(saved.data.affinities.back().power_percent==150,"Native resource round trip")
	editor.context_installed.text="impact, chain"
	editor._preview()
	check(editor.preview.text.contains("EFFECTIVE EVENT WEIGHTS"),"Context preview includes event weights")
	editor._simulate()
	check(editor.preview.text.contains("1,000"),"Weighted simulation")
	editor.section="modifiers"; editor.section_picker.select(0); editor._refresh_list()
	for i in range(editor.entries.item_count):
		if editor.entries.get_item_metadata(i)=="chain": editor.entries.select(i); editor._selected(i); break
	for i in range(3): await process_frame
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.godot/distribution-editor-preview.png")
	print("DISTRIBUTION EDITOR: ",failures," failures")
	editor.queue_free()
	await process_frame
	quit(failures)
