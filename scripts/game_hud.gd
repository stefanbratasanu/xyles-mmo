extends CanvasLayer
class_name XylesHUD

const INK := Color("171614")
const PANEL := Color(0.075, 0.069, 0.058, 0.94)
const GOLD := Color("cbb991")
const GOLD_DIM := Color("716650")
const TEXT := Color("e0dcd1")
const MUTED := Color("a5a196")
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
var context_text: Label
var toast: Label
var toast_timer: float = 0.0
var overlay: Control
var overlay_content: VBoxContainer
var overlay_title: Label
var overlay_subtitle: Label
var current_panel: String = ""
var panel_signature: String = ""
var hotbar: Array[Button] = []
var heading_font: SystemFont
var clock_label: Label
var clock_phase: Label
var world_map: Control
var chat_panel: PanelContainer
var chat_log: RichTextLabel
var chat_input: LineEdit
var chat_hint: Label
var chat_tabs: Dictionary = {}
var chat_channel: String = "World"
var chat_messages: Dictionary = {"World": [], "Local": [], "Party": [], "Guild": []}
var _clock_tick: float = 0.0
const CHANNEL_COLORS := {"World": Color("9ec4b8"), "Local": Color("d7c48e"), "Party": Color("a9b6d6"), "Guild": Color("c9a9d0")}
var skill_view: RefCounted
var inventory_view: RefCounted
var overlay_footer: HBoxContainer
var window_frame: PanelContainer
var window_positions: Dictionary = {}
var drag_target: Control
var drag_id: String = ""
var drag_offset := Vector2.ZERO
var floating_windows: Dictionary = {}
var default_positions: Dictionary = {}
const LAYOUT_PATH := "res://saves/ui_layout.cfg"
const FrameScript = preload("res://scripts/classic_frame.gd")


func setup(owner_game: Node) -> void:
	game = owner_game
	skill_view = preload("res://scripts/skill_panel.gd").new(self)
	inventory_view = preload("res://scripts/inventory_panel.gd").new(self)
	heading_font = SystemFont.new()
	heading_font.font_names = PackedStringArray(["Tahoma", "Arial", "sans-serif"])
	_load_layout()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var ui_theme := Theme.new()
	ui_theme.default_font = heading_font
	ui_theme.default_font_size = 12
	ui_theme.set_stylebox("panel", "TooltipPanel", _style(Color("1c1a16"), GOLD_DIM, 2, 3, 12, 9))
	ui_theme.set_color("font_color", "TooltipLabel", TEXT)
	ui_theme.set_font_size("font_size", "TooltipLabel", 12)
	root.theme = ui_theme
	_build_brand()
	_build_player()
	_build_quest()
	_build_clock()
	_build_menu()
	_build_hotbar()
	_build_log()
	_build_chat()
	_build_toast()
	_build_overlay()
	world_map = preload("res://scripts/world_map.gd").new()
	world_map.name = "WorldMap"
	root.add_child(world_map)
	world_map.setup(game)
	root.move_child(world_map, root.get_child_count() - 1)
	if game.state.has_signal("notice"):
		game.state.notice.connect(show_notice)
	get_viewport().size_changed.connect(_clamp_windows)
	_settle_hud.call_deferred()
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
	elif key == KEY_M:
		toggle_map()
		get_viewport().set_input_as_handled()
	elif key == KEY_ENTER or key == KEY_KP_ENTER:
		if not is_panel_open():
			focus_chat()
			get_viewport().set_input_as_handled()
	elif key == KEY_ESCAPE and is_panel_open():
		if is_instance_valid(world_map) and world_map.visible:
			world_map.close()
		close_panel()
		get_viewport().set_input_as_handled()
	elif key == KEY_ESCAPE:
		toggle_panel("settings")
		get_viewport().set_input_as_handled()


func _build_brand() -> void:
	var compass := VBoxContainer.new()
	_place(compass, Vector2(-150, 12), Vector2(300, 40), Vector2(0.5, 0))
	region_label = _label("EMBERFALL CAMP", 13, TEXT, true)
	region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# The region plate floats over bright sky and pale terrain; a shadow keeps it
	# readable in every zone and at every hour.
	_shadowed(region_label)
	compass.add_child(region_label)
	var subtitle := _label("•  THE ASHEN FRONTIER  •", 9, GOLD)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shadowed(subtitle)
	compass.add_child(subtitle)


func _build_player() -> void:
	var panel: PanelContainer = _panel()
	_place(panel, Vector2(12, 12), Vector2(268, 100))
	_register_window(panel, "status")
	var column: VBoxContainer = _column(panel, 13, 10)
	player_name = _label("WANDERER  /  LV. 1", 12, TEXT)
	column.add_child(player_name)
	var hrow: HBoxContainer = HBoxContainer.new()
	hrow.add_theme_constant_override("separation", 8)
	column.add_child(hrow)
	hrow.add_child(_label("VITALITY", 9, MUTED))
	hp_bar = _bar(Color("a72d29"), 12)
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
	mana_bar = _bar(Color("305c9c"), 12)
	mana_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mrow.add_child(mana_bar)
	mana_text = _label("100 / 100", 10, TEXT)
	mana_text.custom_minimum_size.x = 62
	mana_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	mrow.add_child(mana_text)
	column.add_child(_label("XYLES  •  CONTESTED TERRITORY", 8, GOLD))


func _build_quest() -> void:
	var panel: PanelContainer = _panel(Color(0.04, 0.06, 0.07, 0.83), false)
	_place(panel, Vector2(-288, 196), Vector2(276, 140), Vector2(1, 0))
	_register_window(panel, "quest")
	var column: VBoxContainer = _column(panel, 14, 12)
	column.add_child(_label("Quest Journal", 9, GOLD))
	quest_title = _label("A Debt of Iron", 16, TEXT, true)
	column.add_child(quest_title)
	quest_text = _label("Speak to the camp blacksmith.", 12, TEXT)
	quest_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	quest_text.size.x = 230
	quest_text.custom_minimum_size.y = 45
	column.add_child(quest_text)
	column.add_child(_label("[E]  INTERACT NEAR THE FORGE", 9, MUTED))


func _build_clock() -> void:
	var panel: PanelContainer = _panel(Color(0.04, 0.06, 0.07, 0.72), false)
	_place(panel, Vector2(-252, 12), Vector2(240, 64), Vector2(1, 0))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var column := _column(panel, 12, 8)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 8)
	column.add_child(row)
	clock_label = _label("08:25   DAY 01", 15, TEXT, true)
	clock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(clock_label)
	clock_phase = _label("DAYLIGHT", 9, GOLD)
	row.add_child(clock_phase)
	column.add_child(_label("[M] world map     [F10] bug marker", 9, MUTED))


func _build_menu() -> void:
	var menu_box := _panel()
	_place(menu_box, Vector2(-252, 84), Vector2(240, 100), Vector2(1, 0))
	_register_window(menu_box, "menu")
	var menu_column := _column(menu_box, 10, 8)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	menu_column.add_child(grid)
	for item: Array in [["K", "Skills", "skills"], ["B", "Bestiary", "bestiary"], ["I", "Items", "inventory"], ["C", "Forge", "forge"], ["H", "Guide", "guide"], ["O", "Options", "settings"]]:
		var btn := _button("%s [%s]" % [item[1], item[0]], 9)
		btn.custom_minimum_size = Vector2(70, 28)
		btn.pressed.connect(toggle_panel.bind(str(item[2])))
		grid.add_child(btn)


func _build_chat() -> void:
	chat_panel = _panel(Color(0.035, 0.045, 0.05, 0.82), false)
	# Bottom-left: the chat takes the old journal slot so the bottom-right of the
	# screen stays free for the system log.
	_place(chat_panel, Vector2(12, -238), Vector2(360, 238), Vector2(0, 1))
	chat_panel.mouse_filter = Control.MOUSE_FILTER_PASS
	var column := _column(chat_panel, 10, 8)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 3)
	column.add_child(tabs)
	for channel: String in ["World", "Local", "Party", "Guild"]:
		var btn := _button(channel, 9)
		btn.custom_minimum_size = Vector2(76, 24)
		btn.toggle_mode = true
		btn.pressed.connect(_select_channel.bind(channel))
		tabs.add_child(btn)
		chat_tabs[channel] = btn
	chat_hint = _label("[Enter] to write     ·     channel " + chat_channel, 9, MUTED)
	column.add_child(chat_hint)
	chat_log = RichTextLabel.new()
	chat_log.bbcode_enabled = true
	chat_log.scroll_following = true
	chat_log.fit_content = false
	chat_log.custom_minimum_size.y = 120
	chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_log.add_theme_color_override("default_color", MUTED)
	chat_log.add_theme_font_size_override("normal_font_size", 11)
	chat_log.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(chat_log)
	chat_input = LineEdit.new()
	chat_input.placeholder_text = "Say something in World…  [Enter] to send, [Esc] to cancel"
	chat_input.max_length = 160
	chat_input.custom_minimum_size.y = 26
	chat_input.add_theme_font_size_override("font_size", 11)
	chat_input.add_theme_stylebox_override("normal", _style(Color("141713"), Color("4d4a3d"), 1, 2, 8, 5))
	chat_input.add_theme_stylebox_override("focus", _style(Color("181b16"), GOLD_DIM, 1, 2, 8, 5))
	chat_input.add_theme_color_override("font_color", TEXT)
	chat_input.add_theme_color_override("font_placeholder_color", Color("7b8075"))
	chat_input.text_submitted.connect(_submit_chat)
	chat_input.focus_entered.connect(_on_chat_focus.bind(true))
	chat_input.focus_exited.connect(_on_chat_focus.bind(false))
	column.add_child(chat_input)
	_append_chat_line("World", "Server", "Map I is live. The sealed waygate leads to Map II, which is not built yet.")
	_select_channel("World")


func _select_channel(channel: String) -> void:
	chat_channel = channel
	for name: String in chat_tabs.keys():
		var btn: Button = chat_tabs[name]
		btn.button_pressed = name == channel
		btn.add_theme_color_override("font_color", GOLD if name == channel else TEXT)
	chat_hint.text = "[Enter] to write     ·     channel " + chat_channel
	chat_input.placeholder_text = "Say something in %s…  [Enter] to send" % chat_channel
	_render_chat()
	if is_instance_valid(game) and game.get("game_log") != null:
		game.game_log.ui("chat_channel", {"channel": channel})


func _render_chat() -> void:
	if not is_instance_valid(chat_log):
		return
	chat_log.clear()
	var messages: Array = chat_messages.get(chat_channel, [])
	for line: Dictionary in messages:
		append_bbcode_line(str(line.get("channel", "")), str(line.get("author", "")), str(line.get("text", "")), str(line.get("time", "")))
	if messages.is_empty():
		chat_log.append_text("[color=#6d7368]No %s messages yet.[/color]" % chat_channel.to_lower())


func append_bbcode_line(channel: String, author: String, message: String, stamp: String) -> void:
	var color: Color = CHANNEL_COLORS.get(channel, TEXT)
	chat_log.append_text("[color=#6f756a]%s[/color] [color=#8f978c][%s][/color] [color=#%s]%s:[/color] %s\n" % [stamp, channel, color.to_html(false), author, message])


func _append_chat_line(channel: String, author: String, message: String) -> void:
	if not chat_messages.has(channel):
		channel = "World"
	var stamp := ""
	if is_instance_valid(game) and game.get("world") != null and game.world.get("time_of_day") != null:
		stamp = game.world.clock_text()
	else:
		stamp = Time.get_time_string_from_system().substr(0, 5)
	(chat_messages[channel] as Array).append({"channel": channel, "author": author, "text": message, "time": stamp})
	if (chat_messages[channel] as Array).size() > 60:
		(chat_messages[channel] as Array).pop_front()
	if channel == chat_channel:
		append_bbcode_line(channel, author, message, stamp)


func _submit_chat(text: String) -> void:
	var message := text.strip_edges()
	chat_input.clear()
	if message.is_empty():
		return
	_append_chat_line(chat_channel, "Wayfarer", message)
	if is_instance_valid(game) and game.get("game_log") != null:
		game.game_log.ui("chat_message", {"channel": chat_channel, "length": message.length()})
	chat_input.release_focus()


func _on_chat_focus(focused: bool) -> void:
	if is_instance_valid(game):
		game.ui_text_input = focused
	chat_panel.modulate = Color.WHITE if focused else Color(0.94, 0.94, 0.92)
	if not focused:
		chat_input.release_focus()


func focus_chat() -> void:
	if chat_input.has_focus():
		return
	chat_input.grab_focus()
	chat_input.caret_column = chat_input.text.length()


func toggle_map() -> void:
	if not is_instance_valid(world_map):
		return
	if world_map.visible:
		world_map.close()
		if is_instance_valid(game) and game.get("game_log") != null:
			game.game_log.ui("world_map_closed", {})
	else:
		if not current_panel.is_empty():
			close_panel()
		world_map.open()


func _build_hotbar() -> void:
	# Intentionally not a floating window: the skill bar must sit on the world
	# with no frame around it. Only the skill tiles have a background.
	var holder := Control.new()
	_place(holder, Vector2(-245, -128), Vector2(490, 112), Vector2(0.5, 1))
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.alignment = BoxContainer.ALIGNMENT_END
	column.mouse_filter = Control.MOUSE_FILTER_PASS
	column.add_theme_constant_override("separation", 5)
	holder.add_child(column)
	context_text = _label("Shortcuts   •   1–5", 11, Color("f0e6c8"))
	context_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shadowed(context_text)
	column.add_child(context_text)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	row.add_theme_constant_override("separation", 6)
	column.add_child(row)
	var names := ["Iron Cleave", "Ember Bolt", "Iron Guard", "Dodge Roll", "Restoring Light"]
	for i in range(5):
		var skill := _button("", 12, true)
		skill.custom_minimum_size = Vector2(54, 54)
		skill.add_theme_stylebox_override("normal", _style(Color(0.05, 0.06, 0.06, 0.80), Color("6f6854"), 1, 4, 0, 0))
		skill.add_theme_stylebox_override("hover", _style(Color(0.12, 0.13, 0.11, 0.9), GOLD, 1, 4, 0, 0))
		skill.add_theme_stylebox_override("pressed", _style(Color(0.02, 0.03, 0.03, 0.9), GOLD, 1, 4, 0, 0))
		skill.pressed.connect(_activate_skill.bind(i))
		skill.tooltip_text = "%s [%d]" % [names[i], i + 1]
		row.add_child(skill)
		var picture := TextureRect.new()
		picture.texture = skill_view.icon(SKILL_IDS[i])
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		picture.offset_left = 3
		picture.offset_top = 3
		picture.offset_right = -3
		picture.offset_bottom = -3
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		skill.add_child(picture)
		var key_label := _label(str(i + 1), 10, Color.WHITE)
		key_label.position = Vector2(5, 2)
		key_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		key_label.add_theme_constant_override("shadow_offset_x", 1)
		key_label.add_theme_constant_override("shadow_offset_y", 1)
		skill.add_child(key_label)
		var timer_label := _label("", 14, Color.WHITE)
		timer_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		timer_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		timer_label.add_theme_color_override("font_shadow_color", Color.BLACK)
		timer_label.add_theme_constant_override("shadow_offset_x", 2)
		timer_label.add_theme_constant_override("shadow_offset_y", 2)
		skill.add_child(timer_label)
		skill.set_meta("timer_label", timer_label)
		hotbar.append(skill)
	progression_text = _label("", 10, Color("d8c79a"))
	progression_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shadowed(progression_text)
	column.add_child(progression_text)
	resource_text = _label("", 9, Color("cfc8b2"))
	resource_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shadowed(resource_text)
	column.add_child(resource_text)


func _shadowed(label: Label) -> void:
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)


func _build_log() -> void:
	var panel: PanelContainer = _panel(Color(0.04, 0.06, 0.07, 0.68), false)
	_place(panel, Vector2(-362, -193), Vector2(350, 181), Vector2(1, 1))
	_register_window(panel, "system_log")
	var column: VBoxContainer = _column(panel, 12, 10)
	column.add_child(_label("All   |   System   |   Combat", 9, GOLD))
	log_text = RichTextLabel.new()
	log_text.bbcode_enabled = false
	log_text.add_theme_color_override("default_color", MUTED)
	log_text.add_theme_font_size_override("normal_font_size", 11)
	log_text.custom_minimum_size.y = 110
	log_text.fit_content = false
	log_text.scroll_active = false
	log_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(log_text)
	column.add_child(_label("RMB ORBIT  /  WHEEL ZOOM  /  X SIT  /  O OPTIONS", 9, TEXT))


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
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(overlay)
	window_frame = _panel()
	window_frame.ornate = true
	window_frame.position = Vector2(220, 120)
	window_frame.size = Vector2(1120, 720)
	overlay.add_child(window_frame)
	var outer := _column(window_frame, 14, 9)
	outer.add_theme_constant_override("separation", 9)
	var head := HBoxContainer.new()
	outer.add_child(head)
	overlay_title = _label("Skills", 13, TEXT, true)
	overlay_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.add_child(overlay_title)
	var close := _button("×", 16)
	close.custom_minimum_size = Vector2(26, 24)
	close.tooltip_text = "Close [Esc]"
	close.pressed.connect(close_panel)
	head.add_child(close)
	overlay_subtitle = _label("", 11, MUTED)
	overlay_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(overlay_subtitle)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	outer.add_child(scroll)
	overlay_content = VBoxContainer.new()
	overlay_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	overlay_content.add_theme_constant_override("separation", 9)
	scroll.add_child(overlay_content)
	var footer := HBoxContainer.new()
	overlay_footer = footer
	footer.add_theme_constant_override("separation", 3)
	outer.add_child(footer)
	for item: Array in [["Skills [K]", "skills"], ["Bestiary [B]", "bestiary"], ["Items [I]", "inventory"], ["Forge [C]", "forge"], ["Guide [H]", "guide"], ["Options [O]", "settings"]]:
		var btn := _button(str(item[0]), 11)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_switch_panel.bind(str(item[1])))
		footer.add_child(btn)
	var title_layer := Control.new()
	title_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	window_frame.add_child(title_layer)
	var handle := Control.new()
	title_layer.add_child(handle)
	handle.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	handle.offset_left = 8
	handle.offset_right = -48
	handle.offset_top = 5
	handle.offset_bottom = 38
	handle.mouse_default_cursor_shape = Control.CURSOR_MOVE
	handle.gui_input.connect(_begin_drag.bind(window_frame, "active"))
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
		for i: int in range(mini(hotbar.size(), cooldown_data.size())):
			var remaining: float = float(cooldown_data[i])
			(hotbar[i].get_meta("timer_label") as Label).text = "%.1f" % remaining if remaining > 0.0 else ""
			hotbar[i].modulate = Color(0.65, 0.72, 0.73) if remaining > 0.0 else Color.WHITE
	var hint: Variant = game.get("context_hint")
	if hint is String and not hint.is_empty():
		context_text.text = hint
	var lines: Array[String] = []
	var logs: Array = s.logs
	for i: int in range(maxi(0, logs.size() - 3), logs.size()):
		lines.append(str(logs[i]))
	log_text.text = "\n".join(lines)
	var world: Variant = game.get("world")
	if is_instance_valid(world) and world.get("time_of_day") != null:
		clock_label.text = "%s   DAY %02d" % [world.clock_text(), int(world.day_number)]
		clock_phase.text = str(world.phase_text()).to_upper()
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
	if is_instance_valid(world_map) and world_map.visible:
		return true
	return not current_panel.is_empty()


func toggle_panel(panel_name: String) -> void:
	if current_panel == panel_name:
		close_panel()
	else:
		_switch_panel(panel_name)


func close_panel() -> void:
	if current_panel == "settings" and game.has_method("save_settings"):
		game.save_settings()
	_store_active_position()
	current_panel = ""
	overlay.visible = false
	if is_instance_valid(skill_view.picker):
		skill_view.picker.hide()


func _switch_panel(panel_name: String) -> void:
	if is_instance_valid(world_map) and world_map.visible:
		world_map.close()
	if current_panel == "settings" and game.has_method("save_settings"):
		game.save_settings()
	_store_active_position()
	current_panel = panel_name
	var desired := _panel_size(panel_name)
	window_frame.size = desired.min(get_viewport().get_visible_rect().size - Vector2(24, 40))
	window_frame.position = window_positions.get(panel_name, (get_viewport().get_visible_rect().size - window_frame.size) * 0.5)
	_clamp_window(window_frame)
	if is_instance_valid(skill_view.picker):
		skill_view.picker.hide()
	panel_signature = ""
	overlay.visible = true
	overlay.move_to_front()
	_render_overlay()
	_settle_active.call_deferred(panel_name)


func _render_overlay() -> void:
	overlay_subtitle.visible = current_panel != "inventory"
	overlay_footer.visible = current_panel != "inventory"
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
	overlay_title.text = "Bestiary — Ashen Reach"
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
	inventory_view.render()


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
	overlay_title.text = "Blacksmith — Emberfall"
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
	var layout_reset := _button("RESET WINDOW POSITIONS", 11)
	layout_reset.pressed.connect(_reset_layout)
	overlay_content.add_child(layout_reset)


func _render_guide() -> void:
	overlay_title.text = "Field Guide"
	overlay_subtitle.text = "A playable first chapter in a dangerous world. Your progress is saved locally. Follow the blacksmith's chronicle from camp to the northern sanctuary."
	var sections: Array = [
		["TRAVEL & TARGETING", "WASD to move or click the ground. S backpedals; hold Shift while moving forward to sprint, hold Alt to walk, hold Ctrl to crouch, and press Space to jump. X toggles sitting; movement or using a skill starts standing up. Hold the right mouse button and drag to look around; scroll to zoom. Press O or Esc for settings. Click a creature or press Tab to select a target. E interacts with nearby objects."],
		["FIVE WAYS TO SURVIVE", "1  Iron Cleave: your close combat attack.  2  Ember Bolt: a ranged mana attack.  3  Iron Guard: mitigate incoming damage.  4  Wayfarer's Step: reposition quickly.  5  Restoring Light: spend mana to restore vitality. Watch mana and cooldowns."],
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
	control.set_meta("default_size", control_size)
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
	var panel: PanelContainer = FrameScript.new()
	panel.ornate = false
	panel.add_theme_stylebox_override("panel", _style(Color(0.085, 0.078, 0.065, maxf(color.a, 0.86)), GOLD_DIM if border else Color("494438"), 2, 4))
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	return panel


func _margin(parent: Node, horizontal: int, vertical: int) -> MarginContainer:
	var margin: MarginContainer = MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", horizontal)
	margin.add_theme_constant_override("margin_right", horizontal)
	margin.add_theme_constant_override("margin_top", vertical)
	margin.add_theme_constant_override("margin_bottom", vertical)
	parent.add_child(margin)
	return margin


func _column(parent: Node, horizontal: int, vertical: int) -> VBoxContainer:
	var margin: MarginContainer = _margin(parent, horizontal, vertical)
	var column: VBoxContainer = VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 7)
	margin.add_child(column)
	return column


func _bar(color: Color, height: int) -> ProgressBar:
	var bar: ProgressBar = ProgressBar.new()
	bar.custom_minimum_size.y = height
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = 100.0
	bar.add_theme_stylebox_override("background", _style(Color("161512"), Color("5d5444"), 0, 1))
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
	btn.add_theme_stylebox_override("normal", _style(Color("39362c") if primary else Color("28261f"), GOLD_DIM if primary else Color("786e58"), 1, 2, 10, 7))
	btn.add_theme_stylebox_override("hover", _style(Color("514a39"), GOLD, 1, 2, 10, 7))
	btn.add_theme_stylebox_override("pressed", _style(Color("1b1914"), GOLD, 1, 2, 10, 7))
	btn.add_theme_stylebox_override("disabled", _style(Color("1a1915"), Color("3c382f"), 1, 2, 10, 7))
	return btn


func _style(fill: Color, border: Color, width: int = 1, radius: int = 2, horizontal: int = 0, vertical: int = 0) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.border_blend = false
	if width > 0:
		style.shadow_color = Color(0, 0, 0, 0.5)
		style.shadow_size = 2
		style.shadow_offset = Vector2(1, 2)
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



func _register_window(control: Control, id: String) -> void:
	floating_windows[id] = control
	default_positions[id] = control.position
	control.ornate = true
	var handle := Control.new()
	handle.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	handle.offset_left = 7
	handle.offset_right = -7
	handle.offset_top = 4
	handle.offset_bottom = 26
	handle.mouse_default_cursor_shape = Control.CURSOR_MOVE
	handle.tooltip_text = "Drag to move this window"
	# A top-level Control avoids PanelContainer stretching the title handle over buttons.
	var handle_layer := Control.new()
	handle_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	control.add_child(handle_layer)
	handle_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	handle_layer.add_child(handle)
	handle.gui_input.connect(_begin_drag.bind(control, id))
	if window_positions.has(id):
		control.set_deferred("position", window_positions[id])
	_clamp_window.call_deferred(control)


func _settle_hud() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	for control: Control in floating_windows.values():
		control.size = control.get_meta("default_size")
		_clamp_window(control)


func _settle_active(panel_name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if current_panel != panel_name:
		return
	var desired := _panel_size(panel_name)
	window_frame.size = desired.min(get_viewport().get_visible_rect().size - Vector2(24, 40))
	_clamp_window(window_frame)


func _begin_drag(event: InputEvent, control: Control, id: String) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		drag_target = control
		drag_id = current_panel if id == "active" else id
		drag_offset = control.get_global_mouse_position() - control.global_position
		control.move_to_front()
		get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not is_instance_valid(drag_target):
		return
	if event is InputEventMouseMotion:
		drag_target.global_position = drag_target.get_global_mouse_position() - drag_offset
		_clamp_window(drag_target)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		window_positions[drag_id] = drag_target.position
		drag_target = null
		_save_layout()
		get_viewport().set_input_as_handled()


func _clamp_window(control: Control) -> void:
	var extent := get_viewport().get_visible_rect().size
	control.position = control.position.clamp(Vector2(4, 12), (extent - control.size - Vector2(4, 4)).max(Vector2(4, 12)))


func _clamp_windows() -> void:
	for control: Control in floating_windows.values():
		_clamp_window(control)
	if is_instance_valid(window_frame):
		window_frame.size = window_frame.size.min(get_viewport().get_visible_rect().size - Vector2(24, 40))
		_clamp_window(window_frame)


func _store_active_position() -> void:
	if not current_panel.is_empty():
		window_positions[current_panel] = window_frame.position
		_save_layout()


func _load_layout() -> void:
	if game.test_mode:
		return
	var config := ConfigFile.new()
	if config.load(LAYOUT_PATH) == OK and config.has_section("windows"):
		for key in config.get_section_keys("windows"):
			var saved: Variant = config.get_value("windows", key)
			if saved is Vector2:
				window_positions[key] = saved


func _save_layout() -> void:
	if game.test_mode:
		return
	var config := ConfigFile.new()
	for key: String in window_positions:
		config.set_value("windows", key, window_positions[key])
	config.save(LAYOUT_PATH)


func _reset_layout() -> void:
	window_positions.clear()
	for id: String in floating_windows:
		floating_windows[id].position = default_positions[id]
	window_frame.position = (get_viewport().get_visible_rect().size - window_frame.size) * 0.5
	_clamp_windows()
	_save_layout()
	show_notice("Interface positions restored.")


func _panel_size(panel_name: String) -> Vector2:
	if panel_name == "skills": return Vector2(1120, 720)
	if panel_name == "inventory": return Vector2(620, 440)
	return Vector2(820, 640)
