extends RefCounted
## Native, interactive controls using artwork from the approved concept atlas.
## Evolution history is data, never baked into the artwork.
const ORDER := ["cast", "melee", "block", "move", "support"]
const KEYS := {"melee": 1, "cast": 2, "block": 3, "move": 4, "support": 5}
const COLORS := [Color("e6ae63"), Color("82b9e4"), Color("bf90de")]
const EFFECTS := [
	"+16% base skill power per rank\nMelee potency also enables a nearby cleave.",
	"+4% base skill power per rank\n-7% base cooldown and +6% range per rank",
	"+4% base skill power per rank\n-9% base mana cost per rank",
]
var hud: CanvasLayer
var atlas: Texture2D
var picker: PanelContainer
var textures: Dictionary = {}
var reset_button: Button
var edit_status: Label
var debug_mode := false
var debug_skill := "cast"
var debug_label: RichTextLabel
var debug_signature := ""
const SkillDebug = preload("res://scripts/skills/skill_debug.gd")

func _init(owner_hud: CanvasLayer) -> void:
	hud = owner_hud
	atlas = load("res://assets/ui/skill_concept.png") as Texture2D

func icon(id: String, stage: int = -1) -> Texture2D:
	var key := "%s:%d" % [id, stage]
	if textures.has(key):
		return textures[key]
	var rect: Rect2
	if stage < 0:
		var areas := {
			"cast": Rect2(60, 81, 111, 96),
			"melee": Rect2(60, 238, 111, 95),
			"block": Rect2(68, 395, 87, 82),
			"move": Rect2(68, 529, 87, 75),
			"support": Rect2(68, 652, 87, 72),
		}
		rect = areas.get(id, areas["cast"])
	else:
		# Trim stage numerals from the source art. Stage labels are live controls.
		var x_positions := [335, 464, 592, 721, 850, 980, 1108, 1237, 1366, 1495]
		var slot: int = stage % (5 if id == "cast" else 10)
		rect = Rect2(x_positions[slot] + 5, 119 if id == "cast" else 278, 94, 70)
	var result := AtlasTexture.new()
	result.atlas = atlas
	var factor := Vector2(atlas.get_width() / 1774.0, atlas.get_height() / 887.0)
	result.region = Rect2(rect.position * factor, rect.size * factor)
	result.filter_clip = true
	textures[key] = result
	return result

func render() -> void:
	var state: Node = hud.game.state
	hud.overlay_title.text = "Skills & enchantments"
	hud.overlay_subtitle.text = "10 ACTIVE SLOTS  /  %d POINTS AVAILABLE  /  %d OF 50 DISCOVERED   •   Click a slot number to change its skill" % [state.skill_points, state.earned_skill_points]
	var actions := HBoxContainer.new()
	hud.overlay_content.add_child(actions)
	reset_button = hud._button("RESET ALL · REFUND POINTS",11)
	reset_button.pressed.connect(_reset)
	actions.add_child(reset_button)
	var debug_button: Button=hud._button("UPGRADES" if debug_mode else "DEBUG EFFECTS",11)
	debug_button.pressed.connect(func():
		debug_mode=not debug_mode
		hud._render_overlay())
	actions.add_child(debug_button)
	edit_status = hud._label("",11,hud.MUTED)
	edit_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	edit_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	actions.add_child(edit_status)
	update_edit_status()
	if debug_mode:
		_render_debug()
		return
	for slot in range(state.loadout.size()):
		var id: String = state.loadout[slot]
		var data: Dictionary = state.skills[id]
		var installed: Array = data.evolutions
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		hud.overlay_content.add_child(row)
		var base := VBoxContainer.new()
		base.custom_minimum_size.x = 116
		row.add_child(base)
		var slot_button: Button = hud._button("SLOT %d ▾" % ((slot+1)%10), 10)
		slot_button.pressed.connect(_loadout_picker.bind(slot))
		base.add_child(slot_button)
		var skill_button := _tile(icon(str(state.skill_catalog.data.skills[id].icon)), 56, hud.GOLD)
		skill_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		skill_button.tooltip_text = "%s\n%s\nClick to enchant" % [data.name,data.description]
		skill_button.pressed.connect(_choose.bind(id, installed.size()))
		base.add_child(skill_button)
		var name_label: Label = hud._label(data.name,10,hud.TEXT)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		base.add_child(name_label)
		var strip: PanelContainer = hud._panel()
		strip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		strip.add_theme_stylebox_override("panel",hud._style(Color("171511"),hud.GOLD_DIM,1,0))
		row.add_child(strip)
		var margin: MarginContainer = hud._margin(strip,6,6)
		var choices := HBoxContainer.new()
		choices.add_theme_constant_override("separation",6)
		margin.add_child(choices)
		for stage in range(installed.size()):
			var m: Dictionary = installed[stage]
			var tile := _tile(icon("cast" if state.skill_catalog.data.skills[id].role != "melee" else "melee",stage),64,hud.GOLD)
			tile.tooltip_text = state.skill_catalog.describe(m,id,installed) + "\nClick to replace from this stage's retained five choices."
			tile.pressed.connect(_choose.bind(id,stage))
			choices.add_child(tile)
			var label: Label = hud._label(str(stage+1),12,Color.WHITE)
			label.position = Vector2(4,2)
			tile.add_child(label)
		var end := _tile(null,64,hud.GOLD_DIM)
		end.text = "10/10" if installed.size()==10 else "+\n%d / 10" % installed.size()
		end.add_theme_font_size_override("font_size",17)
		end.pressed.connect(_choose.bind(id,installed.size()))
		choices.add_child(end)
	var footer := HBoxContainer.new()
	hud.overlay_content.add_child(footer)
	var reload_button: Button = hud._button("RELOAD BALANCE DATA",11)
	reload_button.pressed.connect(func():
		if not _can_edit(): return
		if state.reload_skill_catalog():
			hud.game.skill_runtime.clear_combat()
			hud.show_notice("Skill catalog reloaded. Saved enchantment rolls are retained.")
		else: hud.show_notice("Catalog rejected. Check editor validation."))
	footer.add_child(reload_button)

func _render_debug() -> void:
	var state: Node=hud.game.state
	var controls:=HBoxContainer.new()
	hud.overlay_content.add_child(controls)
	var skill_picker:=OptionButton.new()
	var ids: Array=state.skills.keys()
	for id: String in ids: skill_picker.add_item(str(state.skills[id].name)+" · "+id)
	if not ids.has(debug_skill): debug_skill=str(ids[0])
	skill_picker.select(ids.find(debug_skill))
	skill_picker.item_selected.connect(func(i: int): debug_skill=str(ids[i]); update_debug(true))
	controls.add_child(skill_picker)
	var clear: Button=hud._button("CLEAR SESSION COUNTERS",11)
	clear.pressed.connect(func(): hud.game.skill_runtime.clear_debug_stats(); update_debug(true))
	controls.add_child(clear)
	debug_label=RichTextLabel.new()
	debug_label.bbcode_enabled=true
	debug_label.fit_content=true
	debug_label.scroll_active=false
	debug_label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	debug_label.add_theme_font_size_override("normal_font_size",12)
	debug_label.add_theme_font_size_override("bold_font_size",13)
	hud.overlay_content.add_child(debug_label)
	update_debug(true)

func update_debug(force: bool = false) -> void:
	if not debug_mode or not is_instance_valid(debug_label): return
	var runtime: Node=hud.game.skill_runtime
	var signature:=str([debug_skill,runtime.debug_revision,int(runtime.clock*2),hud.game.state.skills[debug_skill].evolutions,hud.game.state.equipment])
	if not force and signature==debug_signature: return
	debug_signature=signature
	debug_label.text=SkillDebug.report(hud.game,debug_skill)

func _tile(texture: Texture2D, edge: int, color: Color) -> Button:
	var button: Button = hud._button("", 12, true)
	button.custom_minimum_size = Vector2(edge, edge)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	button.add_theme_stylebox_override("normal", hud._style(Color("171511"), color.darkened(0.25), 1, 0, 3, 3))
	button.add_theme_stylebox_override("hover", hud._style(Color("494130"), hud.GOLD, 2, 0, 3, 3))
	# Every state must keep the same padding; the generic button's pressed
	# padding clipped the denominator on the narrow evolution counter.
	button.add_theme_stylebox_override("pressed", hud._style(Color("282419"), hud.GOLD, 2, 0, 3, 3))
	button.add_theme_stylebox_override("disabled", hud._style(Color("171511"), color.darkened(0.4), 1, 0, 3, 3))
	if texture:
		var picture := TextureRect.new()
		picture.texture = texture
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		picture.offset_left = 3
		picture.offset_top = 3
		picture.offset_right = -3
		picture.offset_bottom = -3
		picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(picture)
	return button

func _can_edit() -> bool:
	if hud.game.is_dead:
		hud.show_notice("Wait until you revive before changing skills.")
		return false
	if hud.game._in_combat():
		hud.show_notice("Leave combat before changing skills or enchantments.")
		return false
	return true

func update_edit_status() -> void:
	if not is_instance_valid(reset_button) or not is_instance_valid(edit_status): return
	var spent := 0
	for skill: Dictionary in hud.game.state.skills.values(): spent += skill.evolutions.size()
	var blocked: bool = hud.game.is_dead or hud.game._in_combat()
	reset_button.disabled = blocked or spent == 0
	if hud.game.is_dead: edit_status.text = "Reset unavailable while defeated."
	elif blocked: edit_status.text = "Reset unavailable during combat. Move away from enemies first."
	elif spent == 0: edit_status.text = "No upgrades installed. All earned points are available."
	else: edit_status.text = "Refund %d points and remove all upgrades. Saved choices stay the same." % spent
	reset_button.tooltip_text = edit_status.text

func _reset() -> void:
	if not _can_edit(): return
	if is_instance_valid(picker): picker.hide()
	hud.game.skill_runtime.clear_combat()
	hud.game.block_time = 0.0
	hud.game.support_time = 0.0
	var refunded: int = hud.game.state.reset_evolutions()
	var saved: bool = hud.game._save_journey()
	hud.show_notice("Reset complete: %d points refunded." % refunded if saved else "Upgrades reset, but saving failed. Check the save folder.")
	hud.refresh()

func _new_picker(title: String) -> VBoxContainer:
	if is_instance_valid(picker):
		hud.floating_windows.erase("evolution_picker")
		picker.queue_free()
	picker = hud._panel()
	picker.theme = hud.root.theme
	hud.root.add_child(picker)
	var column: VBoxContainer = hud._column(picker,16,10)
	column.add_child(hud._label(title,13,hud.TEXT))
	return column

func _choose(id: String, stage: int) -> void:
	var state: Node = hud.game.state
	if stage < 0: stage = state.skills[id].evolutions.size()
	if stage >= 10:
		hud.show_notice("Fully enchanted. Select an existing stage to replace it.")
		return
	var column := _new_picker("%s · Enchantment %d / 10" % [state.skills[id].name,stage+1])
	column.add_child(hud._label("Choose one of five. Rolls are retained across resets and reloads.",11,hud.MUTED))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(620,440)
	column.add_child(scroll)
	var options := VBoxContainer.new()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(options)
	var offers: Array = state.get_skill_offers(id,stage)
	# Save the offer as soon as it is discovered, including before selection.
	hud.game._save_journey()
	for index in range(offers.size()):
		var m: Dictionary = offers[index]
		var button: Button = hud._button(state.skill_catalog.describe(m,id,state.skills[id].evolutions),11)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.x = 590
		button.disabled = not state.can_install(id,stage,m)
		button.tooltip_text = "Unavailable: no points, duplicate family, or missing dependent effect." if button.disabled else "Install this enchantment"
		button.pressed.connect(_apply.bind(id,stage,index))
		options.add_child(button)
	var close: Button = hud._button("CLOSE",11)
	close.pressed.connect(picker.hide)
	column.add_child(close)
	_position_picker.call_deferred()

func _loadout_picker(slot: int) -> void:
	var column := _new_picker("Choose skill for slot %d" % ((slot+1)%10))
	for id: String in hud.game.state.learned_skills:
		var definition: Dictionary = hud.game.state.skill_catalog.data.skills[id]
		var button: Button = hud._button("%s · %s" % [definition.name,str(definition.type).replace("_"," ")],11)
		button.custom_minimum_size.x = 440
		button.pressed.connect(func():
			if _can_edit():
				hud.game.skill_runtime.stop_channel()
				hud.game.state.equip_skill(id,slot)
				hud.game._save_journey()
				picker.hide()
				hud.refresh())
		column.add_child(button)
	column.add_child(hud._label("Discover additional abilities through first bestiary completions.",11,hud.MUTED))
	var close: Button = hud._button("CLOSE",11)
	close.pressed.connect(picker.hide)
	column.add_child(close)
	_position_picker.call_deferred()

func _position_picker() -> void:
	await hud.get_tree().process_frame
	if not is_instance_valid(picker): return
	picker.reset_size()
	picker.position = (hud.get_viewport().get_visible_rect().size-picker.size)*.5
	picker.set_meta("default_size",picker.size)
	hud._register_window(picker,"evolution_picker")

func _apply(id: String, stage: int, choice: int) -> void:
	if not _can_edit(): return
	if hud.game.state.install_evolution(id,stage,choice):
		picker.hide()
		hud.game.skill_runtime.clear_combat()
		hud.game._save_journey()
		hud.refresh()
