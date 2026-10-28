extends SceneTree
var failures := 0
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var state: Node = load("res://scripts/game_state.gd").new()
	root.add_child(state)
	var old: Dictionary = state.equipment[0].duplicate(true)
	var sword: Dictionary = old.duplicate(true)
	sword.id = "test_ornate_sword"
	sword.name = "Ornate Silver Sword"
	sword.visual_id = "ornate_silver_sword"
	state.inventory.append(sword)
	check(state.equip_item(state.inventory.size() - 1), "Equip the new sword")
	check(state.inventory.any(func(item: Dictionary) -> bool: return item.id == old.id), "Original sword is retained in the bag")
	check(state.equipment.any(func(item: Dictionary) -> bool: return item.get("visual_id", "") == "ornate_silver_sword"), "New sword is equipped")
	var path := "res://.godot/ornate_sword_test.json"
	check(state.save_game(path), "Save test character")
	var restored: Node = load("res://scripts/game_state.gd").new()
	root.add_child(restored)
	check(restored.load_game(path), "Reload test character")
	check(restored.equipment.any(func(item: Dictionary) -> bool: return item.get("visual_id", "") == "ornate_silver_sword"), "Sword visual survives save/load")
	check(restored.inventory.any(func(item: Dictionary) -> bool: return item.id == old.id), "Original sword survives save/load")
	var player: CharacterBody3D = load("res://scripts/player.gd").new()
	root.add_child(player)
	player.set_physics_process(false)
	player.update_equipment(restored.equipment)
	check(player.weapon_visual_variant == "ornate_silver_sword", "New sword visual selected")
	var previous: Node3D = player.weapon_visual
	player.update_equipment([old])
	check(player.weapon_style == "sword" and player.weapon_visual_variant == "", "Switching to the old sword restores its appearance")
	check(player.weapon_visual != previous, "Switching swords refreshes the model")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	player.queue_free()
	state.queue_free()
	restored.queue_free()
	await process_frame
	print("ORNATE SWORD: ", failures, " failures")
	quit(failures)
