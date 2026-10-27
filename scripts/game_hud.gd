extends CanvasLayer
class_name XylesHUD

const INK := Color("101820")
const PANEL := Color(0.045, 0.067, 0.078, 0.94)
const GOLD := Color("c2a36d")
const GOLD_DIM := Color("625a45")
const TEXT := Color("e3dfd4")
const MUTED := Color("94a09e")
const RED := Color("b46860")
const TEAL := Color("71aaa1")
const SKILL_IDS := ["melee", "cast", "block", "move", "support"]
const SKILL_SIGILS := ["I", "II", "III", "IV", "V"]

var game: Node
var root: Control
var hp_bar: ProgressBar
var mana_bar: ProgressBar
var hp_text: Label
var mana_text: Label
var player_name: Label
var quest_text: Label
var quest_title: Label
var region_label: Label
var resource_text: Label
var progression_text: Label
var log_text: RichTextLabel
var target_panel: PanelContainer
var target_name: Label
var target_hp: ProgressBar
var target_info: Label
var context_text: Label
var toast: Label
var toast_timer: float = 0.0
var overlay: Control
var overlay_content: VBoxContainer
var overlay_title: Label
var overlay_subtitle: Label
var current_panel: String = ""
var panel_signature: String = ""
var minimap: FrontierMap
var hotbar: Array[Button] = []
var heading_font: SystemFont
var skill_view: RefCounted


class FrontierMap extends Control:
	var owner_game: Node

	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var radius: float = minf(size.x, size.y) * 0.43
		draw_circle(center, radius, Color("172b2c"))
		draw_arc(center, radius, 0.0, TAU, 72, Color("69644d"), 1.0, true)
		draw_arc(center, radius - 4.0, 0.0, TAU, 72, Color("303f3c"), 1.0, true)
		var path: PackedVector2Array = PackedVector2Array([
			center + Vector2(-38, 33), center + Vector2(-17, 18), center + Vector2(1, 8),
			center + Vector2(18, -8), center + Vector2(19, -23), center + Vector2(12, -44)])
		draw_polyline(path, Color("6d6c4b"), 7.0, true)
		draw_polyline(path, Color("97936a"), 1.0, true)
		for pos: Vector2 in [Vector2(-41, -17), Vector2(-22, -43), Vector2(39, 24), Vector2(47, -18), Vector2(-7, 42)]:
			draw_circle(center + pos, 9.0, Color("253f37"))
		for pos: Vector2 in [Vector2(-39, 34), Vector2(-34, 29), Vector2(-44, 28)]:
			draw_rect(Rect2(center + pos, Vector2(5, 5)), Color("baa16d"))
		draw_arc(center + Vector2(13, -44), 10.0, 0.0, TAU, 24, Color("9d7758"), 2.0, true)
		if is_instance_valid(owner_game) and is_instance_valid(owner_game.get("player")):
			var p: Vector3 = owner_game.player.position
			var marker: Vector2 = center + Vector2(p.x, p.z) * 1.75
			draw_circle(marker, 7.0, Color(0.8, 0.7, 0.42, 0.15))
			draw_circle(marker, 3.5, Color("eee1b2"))
			draw_arc(marker, 5.5, 0.0, TAU, 16, Color("e5cb86"), 1.0, true)
		var line_color: Color = Color("a29c80")
		draw_line(center + Vector2(0, -radius - 3), center + Vector2(0, -radius + 5), line_color)
		draw_line(center + Vector2(-radius - 3, 0), center + Vector2(-radius + 5, 0), line_color)
		draw_line(center + Vector2(radius - 5, 0), center + Vector2(radius + 3, 0), line_color)


func setup(owner_game: Node) -> void:
	game = owner_game
	skill_view = preload("res://scripts/skill_panel.gd").new(self)
	heading_font = SystemFont.new()
	heading_font.font_names = PackedStringArray(["Georgia", "Noto Serif", "serif"])
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	_build_brand()
	_build_player()
	_build_quest()
	_build_navigation()
	_build_hotbar()
	_build_target()
	_build_log()
	_build_toast()
	_build_overlay()
	if game.state.has_signal("notice"):
		game.state.notice.connect(show_notice)
	refresh()


func _process(delta: float) -> void:
	if toast_timer > 0.0:
		toast_timer -= delta
		toast.modulate.a = minf(toast_timer, 1.0)
		toast.visible = toast_timer > 0.0


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: int = event.physical_keycode
	var panel_keys: Dictionary = {KEY_K: "skills", KEY_B: "bestiary", KEY_I: "inventory", KEY_C: "forge", KEY_H: "guide", KEY_O: "settings"}
	if panel_keys.has(key):
		toggle_panel(str(panel_keys[key]))
		get_viewport().set_input_as_handled()
	elif key == KEY_ESCAPE and is_panel_open():
		close_panel()
		get_viewport().set_input_as_handled()
	elif key == KEY_ESCAPE:
		toggle_panel("settings")
		get_viewport().set_input_as_handled()


func _build_brand() -> void:
	var brand: VBoxContainer = VBoxContainer.new()
	_place(brand, Vector2(28, 23), Vector2(300, 67))
	brand.add_theme_constant_override("separation", 2)
	brand.add_child(_label("X Y L E S", 31, GOLD, true))
	brand.add_child(_label("A S H E N   F R O N T I E R", 10, TEXT))
	var compass: VBoxContainer = VBoxContainer.new()
	_place(compass, Vector2(-170, 26), Vector2(340, 45), Vector2(0.5, 0.0))
	var directions: Label = _label("W          N W          N          N E          E", 10, GOLD)
	directions.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compass.add_child(directions)
	region_label = _label("ASHEN REACH", 14, TEXT, true)
	region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compass.add_child(region_label)


func _build_player() -> void:
	var panel: PanelContainer = _panel()
	_place(panel, Vector2(28, 104), Vector2(280, 102))
	var column: VBoxContainer = _column(panel, 13, 10)
	player_name = _label("WANDERER  /  LV. 1", 12, TEXT)
	column.add_child(player_name)
	var hrow: HBoxContainer = HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 8)
	column.add_child(hrow)
	hrow.add_child(_label("VITALITY", 9, MUTED))
	hp_bar = _bar(Color("974d45"), 9)
	hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hrow.add_child(hp_bar)
	hp_text = _label("120 / 120", 10, TEXT)
	hp_text.custom_minimum_size.x = 62
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hrow.add_child(hp_text)
	var mrow: HBoxContainer = HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 8)
	column.add_child(mrow)
	mrow.add_child(_label("MANA     ", 9, MUTED))
	mana_bar = _bar(Color("477a8c"), 9)
	mana_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mrow.add_child(mana_bar)
	mana_text = _label("100 / 100", 10, TEXT)
	mana_text.custom_minimum_size.x = 62
	mana_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mrow.add_child(mana_text)
	column.add_child(_label("FREE EXPLORATION   /   CONTESTED LAND", 8, GOLD))


func _build_quest() -> void:
	var panel: PanelContainer = _panel(Color(0.04, 0.06, 0.07, 0.83), false)
	_place(panel, Vector2(28, 227), Vector2(280, 156))
	var column: VBoxContainer = _column(panel, 14, 12)
	column.add_child(_label("CHRONICLE  /  I", 9, GOLD))
	quest_title = _label("A Debt of Iron", 20, TEXT, true)
	column.add_child(quest_title)
	quest_text = _label("Speak to the camp blacksmith.", 12, TEXT)
	quest_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_text.custom_minimum_size.y = 45
	column.add_child(quest_text)
	column.add_child(_label("[E]  INTERACT NEAR THE FORGE", 9, MUTED))


func _build_navigation() -> void:
	var map_box: PanelContainer = _panel(Color(0.04, 0.06, 0.07, 0.87))
	_place(map_box, Vector2(-218, 24), Vector2(190, 230), Vector2(1, 0))
	var column: VBoxContainer = _column(map_box, 8, 8)
	var location: Label = _label("ASHEN REACH  /  01", 9, GOLD)
	location.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(location)
	minimap = FrontierMap.new()
	minimap.owner_game = game
	minimap.custom_minimum_size = Vector2(170, 170)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(minimap)
	var safe: Label = _label("CAMP  /  EMBERFALL", 8, MUTED)
	safe.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(safe)
	var menu: VBoxContainer = VBoxContainer.new()
	_place(menu, Vector2(-218, 267), Vector2(190, 218), Vector2(1, 0))
	menu.add_theme_constant_override("separation", 4)
	for item: Array in [["K", "SKILL EVOLUTIONS", "skills"], ["B", "BESTIARY", "bestiary"], ["I", "EQUIPMENT", "inventory"], ["C", "BLACKSMITH", "forge"], ["H", "FIELD GUIDE", "guide"], ["O", "SETTINGS", "settings"]]:
		var btn: Button = _button("  %s    %s" % [item[0], item[1]], 10, false)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size.y = 30
		btn.pressed.connect(toggle_panel.bind(str(item[2])))
		menu.add_child(btn)


func _build_hotbar() -> void:
	var holder: VBoxContainer = VBoxContainer.new()
	_place(holder, Vector2(-288, -156), Vector2(576, 136), Vector2(0.5, 1.0))
	holder.add_theme_constant_override("separation", 8)
	context_text = _label("WASD  MOVE    /    TAB  TARGET    /    1-5  ABILITIES", 10, TEXT)
	context_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(context_text)
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 7)
	holder.add_child(row)
	var names: Array[String] = ["CLEAVE", "EMBER BOLT", "GUARD", "STEP", "RESTORE"]
	for i: int in range(5):
		var skill: Button = _button("%s\n%s\n%s" % [str(i + 1), SKILL_SIGILS[i], names[i]], 11, true)
		skill.custom_minimum_size = Vector2(91, 73)
		skill.pressed.connect(_activate_skill.bind(i))
		skill.icon = skill_view.icon(SKILL_IDS[i])
		skill.expand_icon = true
		skill.add_theme_constant_override("icon_max_width", 30)
		skill.tooltip_text = "%s  [ %d ]" % [names[i].capitalize(), i + 1]
		row.add_child(skill)
		hotbar.append(skill)
	progression_text = _label("LEVEL 01    /    0 SKILL POINTS    /    0 OF 50 DISCOVERED", 10, GOLD)
	progression_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(progression_text)
	resource_text = _label("180 GOLD     120 WOOD     120 IRON", 9, MUTED)
	resource_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	holder.add_child(resource_text)


func _build_target() -> void:
	target_panel = _panel()
	_place(target_panel, Vector2(-160, 92), Vector2(320, 79), Vector2(0.5, 0))
	var column: VBoxContainer = _column(target_panel, 16, 9)
	target_name = _label("HOLLOWBOUND", 14, TEXT, true)
	target_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(target_name)
	target_hp = _bar(Color("9f5a46"), 7)
	column.add_child(target_hp)
	target_info = _label("NORMAL  /  LEVEL 1", 9, MUTED)
	target_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(target_info)
	target_panel.visible = false


func _build_log() -> void:
	var panel: PanelContainer = _panel(Color(0.04, 0.06, 0.07, 0.68), false)
	_place(panel, Vector2(28, -165), Vector2(330, 139), Vector2(0, 1))
	var column: VBoxContainer = _column(panel, 12, 10)
	column.add_child(_label("WORLD JOURNAL", 9, GOLD))
	log_text = RichTextLabel.new()
	log_text.bbcode_enabled = false
	log_text.add_theme_color_override("default_color", MUTED)
	log_text.add_theme_font_size_override("normal_font_size", 11)
	log_text.custom_minimum_size.y = 66
	log_text.fit_content = false
	log_text.scroll_active = false
	log_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(log_text)
	column.add_child(_label("RMB  ORBIT   /   WHEEL  ZOOM   /   [O]  SETTINGS", 9, TEXT))


func _build_toast() -> void:
	toast = _label("", 18, Color("e8cf98"), true)
	_place(toast, Vector2(-340, 188), Vector2(680, 50), Vector2(0.5, 0))
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	toast.add_theme_constant_override("shadow_offset_x", 2)
	toast.add_theme_constant_override("shadow_offset_y", 2)
	toast.visible = false


func _build_overlay() -> void:
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(overlay)
	var shade: ColorRect = ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.015, 0.025, 0.03, 0.75)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay.add_child(shade)
	var frame: PanelContainer = _panel(Color(0.035, 0.052, 0.061, 0.985))
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 48
	frame.offset_right = -48
	frame.offset_top = 30
	frame.offset_bottom = -30
	overlay.add_child(frame)
	var outer: VBoxContainer = _column(frame, 25, 20)
	outer.add_theme_constant_override("separation", 13)
	var head: HBoxContainer = HBoxContainer.new()
	outer.add_child(head)
	var titles: VBoxContainer = VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	titles.add_child(_label("X Y L E S   /   W A N D E R E R ' S   C O D E X", 9, GOLD))
	overlay_title = _label("Skill evolutions", 29, TEXT, true)
	titles.add_child(overlay_title)
	var close: Button = _button("CLOSE  [ESC]", 11)
	close.custom_minimum_size = Vector2(120, 35)
	close.pressed.connect(close_panel)
	head.add_child(close)
	overlay_subtitle = _label("", 12, MUTED)
	overlay_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(overlay_subtitle)
	var sep: HSeparator = HSeparator.new()
	sep.add_theme_stylebox_override("separator", _style(Color("6a6045"), Color.TRANSPARENT, 0, 0))
	outer.add_child(sep)
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	outer.add_child(scroll)
	overlay_content = VBoxContainer.new()
	overlay_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_content.add_theme_constant_override("separation", 12)
	scroll.add_child(overlay_content)
	var footer: HBoxContainer = HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	outer.add_child(footer)
	for item: Array in [["K  EVOLUTIONS", "skills"], ["B  BESTIARY", "bestiary"], ["I  EQUIPMENT", "inventory"], ["C  BLACKSMITH", "forge"], ["H  GUIDE", "guide"], ["O  SETTINGS", "settings"]]:
		var btn: Button = _button(str(item[0]), 10)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_switch_panel.bind(str(item[1])))
		footer.add_child(btn)
	overlay.visible = false


func refresh() -> void:
	if not is_instance_valid(game) or not is_instance_valid(game.get("state")):
		return
	var s: Node = game.state
	var equipment_mods: Dictionary = s.get_equipment_modifiers() if s.has_method("get_equipment_modifiers") else {}
	var effective_hp: float = float(s.max_hp) + float(equipment_mods.get("max_hp", 0.0))
	var effective_mana: float = float(s.max_mana) + float(equipment_mods.get("max_mana", 0.0))
	hp_bar.max_value = effective_hp
	hp_bar.value = float(s.hp)
	mana_bar.max_value = effective_mana
	mana_bar.value = float(s.mana)
	hp_text.text = "%d / %d" % [int(s.hp), int(effective_hp)]
	mana_text.text = "%d / %d" % [int(s.mana), int(effective_mana)]
	player_name.text = "WANDERER  /  LV. %02d" % int(s.level)
	quest_text.text = str(s.get_quest_text())
	if not s.quests.is_empty():
		quest_title.text = str(s.quests[0].get("title", "A Debt of Iron"))
	var region: Variant = game.get("region_name")
	if region is String:
		region_label.text = region.to_upper()
	progression_text.text = "LEVEL %02d    /    %d SKILL POINTS    /    %d OF 50 DISCOVERED" % [int(s.level), int(s.skill_points), int(s.earned_skill_points)]
	resource_text.text = "%d GOLD     %d WOOD     %d IRON" % [int(s.gold), int(s.wood), int(s.iron)]
	var cooldown_data: Variant = game.get("cooldowns")
	if cooldown_data is Array:
		var names: Array[String] = ["CLEAVE", "EMBER BOLT", "GUARD", "STEP", "RESTORE"]
		for i: int in range(mini(hotbar.size(), cooldown_data.size())):
			var remaining: float = float(cooldown_data[i])
			hotbar[i].text = "%d\n%s\n%s" % [i + 1, "%.1fs" % remaining if remaining > 0.0 else "", names[i]]
			hotbar[i].modulate = Color(0.65, 0.72, 0.73) if remaining > 0.0 else Color.WHITE
	var hint: Variant = game.get("context_hint")
	if hint is String and not hint.is_empty():
		context_text.text = hint
	var lines: Array[String] = []
	var logs: Array = s.logs
	for i: int in range(maxi(0, logs.size() - 3), logs.size()):
		lines.append(str(logs[i]))
	log_text.text = "\n".join(lines)
	var enemy: Node = game.get("target")
	target_panel.visible = is_instance_valid(enemy) and float(enemy.get("hp")) > 0.0
	if target_panel.visible:
		target_name.text = str(enemy.display_name)
		target_hp.max_value = float(enemy.max_hp)
		target_hp.value = float(enemy.hp)
		target_info.text = "%s  /  %d OF %d VITALITY" % [str(enemy.kind).to_upper(), int(enemy.hp), int(enemy.max_hp)]
	minimap.queue_redraw()
	if is_panel_open():
		var signature: String = str([s.skill_points, s.earned_skill_points, s.skills, s.bestiary, s.equipment, s.inventory, s.gold, s.wood, s.iron, _near_forge()])
		if signature != panel_signature:
			panel_signature = signature
			_render_overlay()


func set_context(message: String) -> void:
	context_text.text = message


func show_notice(message: String) -> void:
	if not is_instance_valid(toast):
		return
	toast.text = message
	toast_timer = 4.2
	toast.modulate.a = 1.0
	toast.visible = true


func is_panel_open() -> bool:
	return not current_panel.is_empty()


func toggle_panel(panel_name: String) -> void:
	if current_panel == panel_name:
		close_panel()
	else:
		_switch_panel(panel_name)


func close_panel() -> void:
	if current_panel == "settings" and game.has_method("save_settings"):
		game.save_settings()
	current_panel = ""
	overlay.visible = false


func _switch_panel(panel_name: String) -> void:
	if current_panel == "settings" and game.has_method("save_settings"):
		game.save_settings()
	current_panel = panel_name
	panel_signature = ""
	overlay.visible = true
	_render_overlay()


func _render_overlay() -> void:
	for child: Node in overlay_content.get_children():
		overlay_content.remove_child(child)
		child.queue_free()
	match current_panel:
		"skills": _render_skills()
		"bestiary": _render_bestiary()
		"inventory": _render_inventory()
		"forge": _render_forge()
		"settings": _render_settings()
		_: _render_guide()


func _render_skills() -> void:
	skill_view.render()


func _render_bestiary() -> void:
	var s: Node = game.state
	overlay_title.text = "The Ashen Reach bestiary"
	overlay_subtitle.text = "Knowledge is power. The first completion of each category in each region grants skill points, up to 50 over your character's life. Repeated kills provide materials and experience."
	var categories: Array = [["normal", "01", "Briarwolves", "The local predators along the old road", 2], ["quest", "02", "Oathbound Guardian", "A unique target in the blacksmith's chronicle", 5], ["boss", "03", "The Hollow Regent", "A world boss within the ancient sanctuary", 3]]
	for category: Array in categories:
		var data: Dictionary = _bestiary_entry(str(category[0]))
		var kills: int = int(data.get("kills", 0))
		var completed: bool = bool(data.get("completed", data.get("claimed", kills > 0)))
		var card: PanelContainer = _panel(Color("121f25"))
		overlay_content.add_child(card)
		var row: HBoxContainer = HBoxContainer.new()
		var margin: MarginContainer = _margin(card, 19, 17)
		margin.add_child(row)
		row.add_theme_constant_override("separation", 20)
		row.add_child(_label(str(category[1]), 32, GOLD, true))
		var col: VBoxContainer = VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(_label(str(category[2]), 21, TEXT, true))
		col.add_child(_label(str(category[3]), 12, MUTED))
		col.add_child(_label("%s  /  %d RECORDED KILLS" % ["DISCOVERED" if completed else "UNDISCOVERED", kills], 10, TEAL if completed else MUTED))
		row.add_child(_label("+%d\nSKILL POINTS" % int(category[4]), 16, TEAL if completed else GOLD))
	var note: Label = _label("REGIONAL RECORD  /  ASHEN REACH\nThe Guardian appears as the chronicle advances. The Hollow Regent waits at the northern shrine; its next spawn follows the world timer.", 12, MUTED)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_content.add_child(note)


func _bestiary_entry(kind: String) -> Dictionary:
	var book: Dictionary = game.state.bestiary
	if book.has(kind) and book[kind] is Dictionary:
		return book[kind]
	for key: Variant in book.keys():
		var value: Variant = book[key]
		if value is Dictionary:
			if str(key).ends_with(kind) or str(value.get("kind", "")) == kind:
				return value
			if value.has(kind) and value[kind] is Dictionary:
				return value[kind]
	return {}


func _render_inventory() -> void:
	var s: Node = game.state
	overlay_title.text = "Steel, scars & survival"
	overlay_subtitle.text = "Below 50% durability, equipment becomes exposed and may drop on death. At 0%, it always drops. Repair before returning to the Reach."
	var resources: Label = _label("%d GOLD    /    %d WOOD    /    %d IRON" % [int(s.gold), int(s.wood), int(s.iron)], 13, GOLD)
	overlay_content.add_child(resources)
	overlay_content.add_child(_label("E Q U I P P E D", 10, MUTED))
	for item: Dictionary in s.equipment:
		_equipment_card(item, true)
	var repair: Button = _button("REPAIR ALL EQUIPPED GEAR  /  %d GOLD" % int(s.get_repair_cost()), 12, true)
	repair.custom_minimum_size.y = 40
	repair.disabled = not _near_forge()
	repair.pressed.connect(_repair)
	overlay_content.add_child(repair)
	if not _near_forge():
		overlay_content.add_child(_label("Return to Emberfall to craft/repair.", 12, GOLD))
	overlay_content.add_child(_label("B A G   /   %d ITEMS" % s.inventory.size(), 10, MUTED))
	if s.inventory.is_empty():
		overlay_content.add_child(_label("Your bag is empty. Craft equipment or defeat powerful foes to fill it.", 12, MUTED))
	for index: int in range(s.inventory.size()):
		_equipment_card(s.inventory[index], false)
		var equip_button: Button = _button("EQUIP THIS ITEM", 10)
		equip_button.pressed.connect(_equip.bind(index))
		overlay_content.add_child(equip_button)


func _equipment_card(item: Dictionary, equipped: bool) -> void:
	var tier: String = str(item.get("tier", "basic"))
	var rarity: Color = _rarity_color(tier)
	var card: PanelContainer = _panel(Color("121f25"))
	overlay_content.add_child(card)
	var col: VBoxContainer = _column(card, 16, 11)
	var row: HBoxContainer = HBoxContainer.new()
	col.add_child(row)
	var name_label: Label = _label(str(item.get("name", "Unknown relic")), 18, rarity, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_label)
	row.add_child(_label("%s  /  %s" % [tier.to_upper(), str(item.get("slot", "weapon")).to_upper()], 10, MUTED))
	var durability: float = float(item.get("durability", 100))
	var maximum: float = float(item.get("max_durability", 100))
	var percentage: float = durability / maxf(maximum, 1.0) * 100.0
	var modifiers: Array = item.get("modifiers", [])
	var pieces: Array[String] = []
	for modifier: Variant in modifiers:
		if modifier is Dictionary:
			pieces.append(str(modifier.get("text", modifier.get("name", str(modifier)))))
		else:
			pieces.append(game.state.get_modifier_display_text(str(modifier)))
	var mod_label: Label = _label("   /   ".join(pieces), 11, TEXT)
	mod_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(mod_label)
	var status: String = "EXPOSED" if percentage < 50.0 else "SECURE"
	col.add_child(_label("DURABILITY  %d%%    /    %s%s" % [int(percentage), status, "    /    EQUIPPED" if equipped else "    /    IN BAG"], 10, RED if percentage < 50 else MUTED))
	var bar: ProgressBar = _bar(RED if percentage < 50 else rarity.darkened(0.25), 4)
	bar.value = percentage
	col.add_child(bar)


func _render_forge() -> void:
	var s: Node = game.state
	overlay_title.text = "The Emberfall forge"
	overlay_subtitle.text = "Shape your next weapon at the camp forge. A basic sword begins at 100 wood + 100 iron; greater investment yields more modifiers. Materials come from combat and chronicle rewards."
	overlay_content.add_child(_label("AVAILABLE   /   %d WOOD   /   %d IRON   /   %d GOLD" % [int(s.wood), int(s.iron), int(s.gold)], 13, GOLD))
	if not _near_forge():
		overlay_content.add_child(_label("Return to Emberfall to craft/repair.", 12, GOLD))
	for tier: String in ["basic", "rare", "epic", "legendary"]:
		var cost: Dictionary = s.get_craft_cost(tier)
		var card: PanelContainer = _panel(Color("121f25"))
		overlay_content.add_child(card)
		var col: VBoxContainer = _column(card, 18, 17)
		var row: HBoxContainer = HBoxContainer.new()
		col.add_child(row)
		var title: Label = _label("%s  /  ASHFORGED SWORD" % tier.to_upper(), 19, _rarity_color(tier), true)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(title)
		var count: Dictionary = {"basic": 2, "rare": 3, "epic": 4, "legendary": 5}
		row.add_child(_label("%d MODIFIERS" % int(count[tier]), 11, MUTED))
		var desc: Label = _label("%d wood  +  %d iron%s" % [int(cost.get("wood", 100)), int(cost.get("iron", 100)), "  +  %d gold" % int(cost.get("gold", 0)) if int(cost.get("gold", 0)) > 0 else ""], 13, TEXT)
		col.add_child(desc)
		var btn: Button = _button("FORGE %s SWORD" % tier.to_upper(), 11, true)
		btn.custom_minimum_size.y = 36
		btn.disabled = not _near_forge()
		btn.pressed.connect(_craft.bind(tier))
		col.add_child(btn)
	overlay_content.add_child(_label("WORLD BOSSES  /  The rarest equipment waits beyond the safety of the forge.", 11, MUTED))


func _render_settings() -> void:
	overlay_title.text = "Settings"
	overlay_subtitle.text = "Tune camera handling and audio. Changes apply immediately and save when you close the menu."
	var camera_card: PanelContainer = _panel(Color("121f25"))
	overlay_content.add_child(camera_card)
	var camera_column: VBoxContainer = _column(camera_card, 20, 16)
	camera_column.add_child(_label("CAMERA", 11, GOLD))
	var reverse_check: CheckButton = CheckButton.new()
	reverse_check.text = "Reverse vertical camera drag"
	reverse_check.button_pressed = bool(game.camera_reverse_vertical)
	reverse_check.focus_mode = Control.FOCUS_NONE
	reverse_check.add_theme_color_override("font_color", TEXT)
	reverse_check.add_theme_font_size_override("font_size", 13)
	reverse_check.toggled.connect(_set_camera_reverse_vertical)
	camera_column.add_child(reverse_check)
	var sensitivity_row: HBoxContainer = HBoxContainer.new()
	sensitivity_row.add_theme_constant_override("separation", 14)
	camera_column.add_child(sensitivity_row)
	var sensitivity_label: Label = _label("LOOK SENSITIVITY", 11, MUTED)
	sensitivity_label.custom_minimum_size.x = 170
	sensitivity_row.add_child(sensitivity_label)
	var sensitivity_slider: HSlider = HSlider.new()
	sensitivity_slider.min_value = 0.001
	sensitivity_slider.max_value = 0.015
	sensitivity_slider.step = 0.0005
	sensitivity_slider.value = float(game.camera_sensitivity)
	sensitivity_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sensitivity_slider.custom_minimum_size.x = 220
	sensitivity_row.add_child(sensitivity_slider)
	var sensitivity_value: Label = _label("%.2f° / px" % rad_to_deg(float(game.camera_sensitivity)), 11, TEXT)
	sensitivity_value.custom_minimum_size.x = 65
	sensitivity_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sensitivity_row.add_child(sensitivity_value)
	sensitivity_slider.value_changed.connect(_set_camera_sensitivity.bind(sensitivity_value))
	sensitivity_slider.drag_ended.connect(_commit_settings)

	var audio_card: PanelContainer = _panel(Color("121f25"))
	overlay_content.add_child(audio_card)
	var audio_column: VBoxContainer = _column(audio_card, 20, 16)
	audio_column.add_child(_label("AUDIO", 11, GOLD))
	var volume_row: HBoxContainer = HBoxContainer.new()
	volume_row.add_theme_constant_override("separation", 14)
	audio_column.add_child(volume_row)
	var volume_label: Label = _label("MASTER VOLUME", 11, MUTED)
	volume_label.custom_minimum_size.x = 170
	volume_row.add_child(volume_label)
	var volume_slider: HSlider = HSlider.new()
	volume_slider.min_value = 0.0
	volume_slider.max_value = 1.0
	volume_slider.step = 0.05
	volume_slider.value = float(game.master_volume)
	volume_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	volume_slider.custom_minimum_size.x = 220
	volume_row.add_child(volume_slider)
	var volume_value: Label = _label("%d%%" % roundi(float(game.master_volume) * 100.0), 11, TEXT)
	volume_value.custom_minimum_size.x = 65
	volume_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	volume_row.add_child(volume_value)
	volume_slider.value_changed.connect(_set_master_volume.bind(volume_value))
	volume_slider.drag_ended.connect(_commit_settings)

	var defaults: Button = _button("RESTORE DEFAULT SETTINGS", 11)
	defaults.custom_minimum_size.y = 38
	defaults.pressed.connect(_reset_settings)
	overlay_content.add_child(defaults)


func _render_guide() -> void:
	overlay_title.text = "A wanderer's field guide"
	overlay_subtitle.text = "A playable first chapter in a dangerous world. Your progress is saved locally. Follow the blacksmith's chronicle from camp to the northern sanctuary."
	var sections: Array = [
		["TRAVEL & TARGETING", "WASD to move or click the ground. Hold the right mouse button and drag to freely look up, down and around; scroll to zoom. The camera pulls in near walls. Press O or Esc for settings. Click a creature or press Tab to select a target. E interacts with the blacksmith, gathers nearby resources or collects dropped loot."],
		["FIVE WAYS TO SURVIVE", "1  Iron Cleave: your close combat attack.  2  Ember Bolt: a ranged mana attack.  3  Iron Guard: mitigate incoming damage.  4  Wayfarer's Step: reposition quickly.  5  Restoring Light: spend mana to restore vitality. Hold Space to repeatedly cleave. Watch mana and cooldowns."],
		["POWER THROUGH DISCOVERY", "Open B for the regional bestiary. Your first normal, quest and boss completions grant 2, 5 and 3 skill points. Leveling alone grants no skill points. Spend them with K, choosing three branching paths for each starter skill."],
		["RISK & REPAIR", "Death damages random pieces of equipment. Below 50% durability, gear can drop; at 0%, it always drops. Return to Emberfall and repair through I. Craft better equipment through C. F5 saves your journey, and progress also saves automatically."],
		["THE CHRONICLE", "Begin at the Emberfall blacksmith. Cull the Briarwolves, confront the Oathbound Guardian, then follow the clue toward the Hollow Regent. Powerful foes reward preparation and careful movement."]
	]
	for section: Array in sections:
		var card: PanelContainer = _panel(Color("121f25"))
		overlay_content.add_child(card)
		var col: VBoxContainer = _column(card, 18, 16)
		col.add_child(_label(str(section[0]), 11, GOLD))
		var text_label: Label = _label(str(section[1]), 14, TEXT)
		text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(text_label)


func _evolve(id: String, branch: int) -> void:
	game.state.evolve_skill(id, branch)
	refresh()


func _respec(id: String, branch: int) -> void:
	game.state.respec_skill(id, branch)
	refresh()


func _craft(tier: String) -> void:
	if not _near_forge():
		show_notice("Return to Emberfall to craft/repair.")
		return
	game.state.craft_sword(tier)
	refresh()


func _repair() -> void:
	if not _near_forge():
		show_notice("Return to Emberfall to craft/repair.")
		return
	game.state.repair_all()
	refresh()


func _equip(index: int) -> void:
	if game.state.has_method("equip_item"):
		game.state.equip_item(index)
	refresh()


func _activate_skill(index: int) -> void:
	if game.has_method("use_skill"):
		game.use_skill(index)


func _set_camera_reverse_vertical(enabled: bool) -> void:
	game.camera_reverse_vertical = enabled
	game.save_settings()


func _set_camera_sensitivity(value: float, readout: Label) -> void:
	game.camera_sensitivity = value
	readout.text = "%.2f° / px" % rad_to_deg(value)


func _set_master_volume(value: float, readout: Label) -> void:
	game.master_volume = value
	game.audio.set_master_volume(value)
	readout.text = "%d%%" % roundi(value * 100.0)


func _commit_settings(_value_changed: bool = true) -> void:
	game.save_settings()


func _reset_settings() -> void:
	game.reset_settings()
	_render_overlay()


func _near_forge() -> bool:
	if not is_instance_valid(game) or not is_instance_valid(game.get("world")) or not is_instance_valid(game.get("player")):
		return false
	return game.player.global_position.distance_to(game.world.camp_position) < 8.0


func _place(control: Control, position: Vector2, control_size: Vector2, anchor: Vector2 = Vector2.ZERO) -> void:
	root.add_child(control)
	control.anchor_left = anchor.x
	control.anchor_right = anchor.x
	control.anchor_top = anchor.y
	control.anchor_bottom = anchor.y
	control.offset_left = position.x
	control.offset_top = position.y
	control.offset_right = position.x + control_size.x
	control.offset_bottom = position.y + control_size.y
	if not control is Container:
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _label(text: String, font_size: int = 12, color: Color = TEXT, serif: bool = false) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	if serif:
		label.add_theme_font_override("font", heading_font)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _panel(color: Color = PANEL, border: bool = true) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(color, GOLD_DIM if border else Color(0.25, 0.32, 0.31, 0.3), 1, 2))
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	return panel


func _margin(parent: Node, horizontal: int, vertical: int) -> MarginContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", horizontal)
	margin.add_theme_constant_override("margin_right", horizontal)
	margin.add_theme_constant_override("margin_top", vertical)
	margin.add_theme_constant_override("margin_bottom", vertical)
	parent.add_child(margin)
	return margin


func _column(parent: Node, horizontal: int, vertical: int) -> VBoxContainer:
	var margin: MarginContainer = _margin(parent, horizontal, vertical)
	var column: VBoxContainer = VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)
	return column


func _bar(color: Color, height: int) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size.y = height
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 100.0
	bar.add_theme_stylebox_override("background", _style(Color("263037"), Color("35413f"), 0, 1))
	bar.add_theme_stylebox_override("fill", _style(color, color.lightened(0.1), 0, 1))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return bar


func _button(text: String, font_size: int = 11, primary: bool = false) -> Button:
	var btn: Button = Button.new()
	btn.text = text
	btn.focus_mode = Control.FOCUS_NONE
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn.add_theme_font_size_override("font_size", font_size)
	btn.add_theme_color_override("font_color", GOLD if primary else TEXT)
	btn.add_theme_color_override("font_hover_color", Color("f8e8bd"))
	btn.add_theme_color_override("font_disabled_color", Color("5c6767"))
	btn.add_theme_stylebox_override("normal", _style(Color("1f282a") if primary else Color(0.05, 0.08, 0.09, 0.85), GOLD_DIM if primary else Color("36453f"), 1, 2, 10, 7))
	btn.add_theme_stylebox_override("hover", _style(Color("34382f"), GOLD, 1, 2, 10, 7))
	btn.add_theme_stylebox_override("pressed", _style(Color("49452f"), GOLD, 1, 2, 10, 7))
	btn.add_theme_stylebox_override("disabled", _style(Color("121c21"), Color("2c3937"), 1, 2, 10, 7))
	return btn


func _style(fill: Color, border: Color, width: int = 1, radius: int = 2, horizontal: int = 0, vertical: int = 0) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = horizontal
	style.content_margin_right = horizontal
	style.content_margin_top = vertical
	style.content_margin_bottom = vertical
	return style


func _rarity_color(tier: String) -> Color:
	return {"basic": Color("a8b5b0"), "rare": Color("80b7bd"), "epic": Color("b29dc9"), "legendary": Color("d2af6e")}.get(tier, TEXT)

