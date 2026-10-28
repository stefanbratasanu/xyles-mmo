extends RefCounted
## Compact equipment paperdoll and nine-column bag matching the inventory standard.
const Slots = preload("res://scripts/equipment_slots.gd")
var hud: CanvasLayer
var active_tab := "All"
var selected_id := ""
var confirm_discard := false
var icons: Dictionary = {}

func _init(owner_hud: CanvasLayer) -> void:
	hud = owner_hud

func icon(kind: String) -> Texture2D:
	if not icons.has(kind):
		var image := Image.new()
		image.load_svg_from_string(FileAccess.get_file_as_string("res://assets/ui/equipment/%s.svg" % kind), 2.0)
		icons[kind] = ImageTexture.create_from_image(image)
	return icons[kind]

func render() -> void:
	var state: Node = hud.game.state
	var used_slots: int = state.inventory.size() + int(state.wood > 0) + int(state.iron > 0)
	hud.overlay_title.text = "Inventory                                      (%d/%d)" % [used_slots, Slots.CAPACITY]
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	hud.overlay_content.add_child(body)
	var frame: PanelContainer = hud._panel()
	frame.custom_minimum_size = Vector2(200, 354)
	body.add_child(frame)
	var board := Control.new()
	board.custom_minimum_size = Vector2(196, 350)
	frame.add_child(board)
	# The smaller central row holds the three dye/tattoo slots.
	for entry: Array in Slots.SLOTS:
		var id := str(entry[0])
		var item: Dictionary = {}
		for equipped: Dictionary in state.equipment:
			if equipped["slot"] == id:
				item = equipped
				break
		var small: bool = int(entry[5]) == 4
		var tile := _tile(item, str(entry[2]), 22 if small else 38)
		tile.position = Vector2(16 + int(entry[4]) * 60 + (8 if small else 0), _row_y(int(entry[5])))
		board.add_child(tile)
		if item.is_empty():
			tile.tooltip_text = "%s\nEmpty equipment slot" % entry[1]
		else:
			tile.tooltip_text += "\nClick to unequip."
			tile.pressed.connect(_unequip.bind(id))
	var engraving: Label = hud._label("✦   XYLES   ✦", 12, Color("514b3c"))
	engraving.position = Vector2(44, 326)
	board.add_child(engraving)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 3)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 1)
	right.add_child(tabs)
	for tab: String in ["All", "Equip", "Supplies", "Crafting", "Quest"]:
		var button: Button = hud._button(tab, 10, tab == active_tab)
		button.add_theme_stylebox_override("normal", hud._style(Color("464031") if tab == active_tab else Color("29261f"), hud.GOLD_DIM, 1, 2, 5, 3))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_set_tab.bind(tab))
		tabs.add_child(button)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(342, 288)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	scroll.add_child(grid)
	var entries: Array[Dictionary] = []
	for index in range(state.inventory.size()):
		var item: Dictionary = state.inventory[index]
		if _matches_tab(item):
			entries.append({"item": item, "index": index})
	# Materials are backed by the existing crafting resource balances.
	if active_tab in ["All", "Crafting"]:
		for material: String in ["wood", "iron"]:
			if int(state.get(material)) > 0:
				entries.append({"item": {"id": material, "name": material.capitalize(), "category": "material", "count": int(state.get(material))}, "index": -1})
	for index in range(maxi(72, entries.size())):
		if index < entries.size():
			var item: Dictionary = entries[index].item
			var definition: Array = Slots.definition(str(item.get("slot", "")))
			var artwork: String = str(item.id) if item.get("category", "") == "material" else (str(definition[2]) if not definition.is_empty() else "dye")
			var tile := _tile(item, artwork, 36)
			grid.add_child(tile)
			if int(entries[index].index) >= 0:
				tile.pressed.connect(_select.bind(str(item.id)))
				tile.gui_input.connect(_bag_input.bind(int(entries[index].index)))
				tile.tooltip_text += "\nDouble-click or right-click to equip."
			if str(item.id) == selected_id:
				tile.add_theme_stylebox_override("normal", hud._style(Color("3d3829"), hud.GOLD, 2, 0))
		else:
			grid.add_child(_tile({}, "", 36))
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 3)
	right.add_child(bottom)
	var repair: Button = hud._button("⚒", 16)
	repair.custom_minimum_size = Vector2(32, 32)
	repair.tooltip_text = "Repair equipment · %d gold\nAvailable near the blacksmith." % state.get_repair_cost()
	repair.disabled = not hud._near_forge()
	repair.pressed.connect(hud._repair)
	bottom.add_child(repair)
	var sort_button: Button = hud._button("↕", 16)
	sort_button.custom_minimum_size = Vector2(32, 32)
	sort_button.tooltip_text = "Sort bag by equipment slot and name"
	sort_button.pressed.connect(_sort_bag)
	bottom.add_child(sort_button)
	var currencies := VBoxContainer.new()
	currencies.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(currencies)
	var gold: Label = hud._label("◈  %s" % state.gold, 11, hud.GOLD)
	gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	currencies.add_child(gold)
	var capacity: Label = hud._label("Bag capacity  %.2f%%" % (used_slots * 100.0 / Slots.CAPACITY), 9, hud.TEXT)
	capacity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	currencies.add_child(capacity)
	var trash: Button = hud._button("×" if not confirm_discard else "Sure?", 12)
	trash.custom_minimum_size = Vector2(34, 32)
	trash.disabled = selected_id.is_empty()
	trash.tooltip_text = "Discard the selected bag item. Click twice to confirm."
	trash.pressed.connect(_discard)
	bottom.add_child(trash)

func _row_y(row: int) -> float:
	return [14, 58, 102, 146, 190, 220, 266][row]

func _tile(item: Dictionary, silhouette: String, edge: int) -> Button:
	# An equipped spear keeps the same main-hand slot but uses its own item artwork.
	silhouette=str(item.get("icon",silhouette))
	var tile: Button = hud._button("", 10)
	tile.custom_minimum_size = Vector2(edge, edge)
	tile.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tile.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	tile.add_theme_stylebox_override("normal", hud._style(Color("12110f"), Color("454035"), 1, 0))
	tile.add_theme_stylebox_override("hover", hud._style(Color("2d291f"), hud.GOLD, 1, 0))
	if not silhouette.is_empty():
		var picture := TextureRect.new()
		picture.texture = icon(silhouette)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		picture.offset_left = 3
		picture.offset_top = 3
		picture.offset_right = -3
		picture.offset_bottom = -3
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		picture.modulate = Color("3b3932") if item.is_empty() else Color.WHITE
		tile.add_child(picture)
	if not item.is_empty():
		tile.tooltip_text = _description(item)
		if item.has("count"):
			var count: Label = hud._label(str(item.count), 9, hud.TEXT)
			count.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
			count.offset_left = 2
			count.offset_top = -14
			count.offset_right = -2
			count.offset_bottom = -1
			count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			tile.add_child(count)
	return tile

func _description(item: Dictionary) -> String:
	if item.get("category", "") == "material":
		return "%s × %d\nCrafting material" % [item.name, item.count]
	var result := "%s\n%s · %s\nDurability: %d / %d" % [item.get("name", "Equipment"), str(item.get("tier", "basic")).capitalize(), Slots.label(str(item.get("slot", ""))), item.get("durability", 100), item.get("max_durability", 100)]
	if item.get("slot","")=="weapon": result+="\nWeapon type: "+hud.game.state.item_weapon_type(item).capitalize()
	for modifier: String in item.get("modifiers", []):
		result += "\n" + hud.game.state.get_modifier_display_text(modifier)
	return result

func _matches_tab(item: Dictionary) -> bool:
	if active_tab == "All": return true
	var category := str(item.get("category", "equipment"))
	return category == {"Equip": "equipment", "Supplies": "supply", "Crafting": "material", "Quest": "quest"}.get(active_tab, "")

func _set_tab(tab: String) -> void:
	active_tab = tab
	confirm_discard = false
	hud._render_overlay()

func _select(id: String) -> void:
	selected_id = id
	confirm_discard = false
	# Defer the rebuild so the second click of a double-click is received.
	hud._render_overlay.call_deferred()

func _bag_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT or (event.button_index == MOUSE_BUTTON_LEFT and event.double_click):
			selected_id = ""
			confirm_discard = false
			hud._equip(index)

func _unequip(slot: String) -> void:
	hud.game.state.unequip_slot(slot)
	hud.refresh()

func _sort_bag() -> void:
	hud.game.state.inventory.sort_custom(func(a: Dictionary, b: Dictionary): return str(a.slot) + str(a.name) < str(b.slot) + str(b.name))
	hud._render_overlay()

func _discard() -> void:
	if not confirm_discard:
		confirm_discard = true
		hud._render_overlay()
		return
	var state: Node = hud.game.state
	for index in range(state.inventory.size()):
		if str(state.inventory[index].id) == selected_id:
			state.inventory.remove_at(index)
			break
	selected_id = ""
	confirm_discard = false
	state.changed.emit()
	hud.refresh()
