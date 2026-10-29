extends SceneTree
var failures := 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in range(3): await process_frame
	var state = game.state
	var id := "fighter_cone"
	state.equipment.clear()
	state.equipment.append({"name":"Test Blade", "slot":"weapon", "power":20.0, "durability":100.0, "modifiers":[]})
	state.changed.emit()
	var text: String = game.hud.skill_description_bbcode(id)
	check(text.contains("[color=#e6c27b]") and text.contains("Equipment · Test Blade: +6.0 base power"), "Equipment contribution highlighted")
	state.equipment[0].durability = 0.0
	state.changed.emit()
	text = game.hud.skill_description_bbcode(id)
	check(text.contains("+1.5 base power"), "Broken equipment contribution matches runtime")
	var modifier_id := ""
	for key: String in state.skill_catalog.data.modifiers:
		if state.skill_catalog.data.modifiers[key].op == "power":
			modifier_id = key
			break
	check(not modifier_id.is_empty(), "Power enchantment fixture exists")
	if not modifier_id.is_empty():
		var definition: Dictionary = state.skill_catalog.data.modifiers[modifier_id]
		var was_enabled: bool = definition.get("enabled", false)
		var enchantment := {"id": modifier_id, "name": "Test enchantment", "op": "power", "event": "PASSIVE", "values": {"amount": 0.2}}
		state.skills["melee"].evolutions.append(enchantment)
		definition.enabled = false
		state.changed.emit()
		check(not game.hud.skill_description_bbcode("melee").contains("Enchantment · Test enchantment"), "Disabled enchantments are not shown as active")
		definition.enabled = true
		state.changed.emit()
		check(game.hud.skill_description_bbcode("melee").contains("Enchantment · Test enchantment"), "Active enchantment is highlighted")
		definition.enabled = was_enabled
		state.skills["melee"].evolutions.clear()
		state.changed.emit()
	game.hud.toggle_panel("skills")
	await process_frame
	check(game.hud.current_panel == "skills", "Fighter skill panel opens")
	game.hud.toggle_panel("inventory")
	await process_frame
	check(game.hud.current_panel == "inventory", "Inventory panel opens")
	var inventory = game.hud.inventory_view
	var item = {"name":"Test Blade", "id":"test", "slot":"weapon", "durability":100, "max_durability":100, "modifiers":[]}
	var tile: Button = inventory._tile(item, "", 36)
	game.hud.add_child(tile)
	inventory._enable_immediate_tooltip(tile)
	tile.mouse_entered.emit()
	check(is_instance_valid(inventory.item_tooltip), "Item tooltip appears immediately on mouse entry")
	check(inventory.item_tooltip.get_child(0).get_child(0).text.contains("Test Blade"), "Item tooltip shows the hovered item")
	tile.mouse_exited.emit()
	check(inventory.item_tooltip == null, "Item tooltip closes on mouse exit")
	tile.queue_free()
	game.queue_free()
	await process_frame
	print("UI MODIFIER AND HOVER: ", failures, " failures")
	quit(failures)
