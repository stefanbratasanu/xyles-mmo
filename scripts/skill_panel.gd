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
	hud.overlay_title.text = "Skills & evolutions"
	hud.overlay_subtitle.text = "5 ACTIVE SLOTS     /     %d SKILL POINTS     /     %d OF 50 DISCOVERED" % [state.skill_points, state.earned_skill_points]
	for id: String in ORDER:
		var data: Dictionary = state.skills[id]
		var history: Array = data["history"]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		row.custom_minimum_size.y = 88
		hud.overlay_content.add_child(row)
		var base := VBoxContainer.new()
		base.custom_minimum_size.x = 110
		base.add_theme_constant_override("separation", 4)
		row.add_child(base)
		var skill_button := _tile(icon(id), 72, hud.GOLD)
		skill_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		skill_button.tooltip_text = "%s  [ %d ]\n%s\nClick to choose an evolution." % [data["name"], KEYS[id], data["description"]]
		skill_button.pressed.connect(_choose.bind(id, -1))
		base.add_child(skill_button)
		var name_label: Label = hud._label(data["name"], 11, hud.TEXT, true)
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		base.add_child(name_label)
		var connector: Label = hud._label("—", 24, hud.GOLD_DIM)
		connector.custom_minimum_size = Vector2(24, 72)
		connector.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		connector.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(connector)
		# Even 10 upgrades + the terminal tile occupy only 820 logical pixels.
		# At 1600x900 this leaves ample room for detail tooltips.
		var strip: PanelContainer = hud._panel(Color("1a1814"))
		strip.add_theme_stylebox_override("panel", hud._style(Color("1a1814"), hud.GOLD_DIM, 1, 0))
		strip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(strip)
		var margin: MarginContainer = hud._margin(strip, 8, 8)
		var choices := HBoxContainer.new()
		choices.add_theme_constant_override("separation", 8)
		margin.add_child(choices)
		var branch_ranks := [0, 0, 0]
		for stage in range(history.size()):
			var branch: int = int(history[stage])
			branch_ranks[branch] += 1
			var branch_art: Array = [[0, 1], [2, 4], [3]] if id == "cast" else [[0, 3, 4, 5, 8, 9], [1, 6], [2, 7]]
			var variants: Array = branch_art[branch]
			var art_index: int = int(variants[(int(branch_ranks[branch]) - 1) % variants.size()])
			var tile := _tile(icon(id, art_index), 64, COLORS[branch])
			choices.add_child(tile)
			var number: Label = hud._label(str(stage + 1), 13, Color("fff0c9"))
			number.position = Vector2(5, 3)
			number.add_theme_color_override("font_shadow_color", Color.BLACK)
			number.add_theme_constant_override("shadow_offset_x", 1)
			number.add_theme_constant_override("shadow_offset_y", 1)
			tile.add_child(number)
			tile.tooltip_text = "%s · Stage %d\n%s · Rank %d\n\n%s\n\nClick to change this evolution." % [data["name"], stage + 1, data["branches"][branch], branch_ranks[branch], EFFECTS[branch]]
			tile.pressed.connect(_choose.bind(id, stage))
		var end := _tile(null, 64, hud.GOLD_DIM)
		choices.add_child(end)
		if history.size() >= 10:
			end.text = "10/10"
			end.add_theme_font_size_override("font_size", 18)
			end.tooltip_text = "Fully evolved. Select an existing stage to change its branch."
			end.mouse_default_cursor_shape = Control.CURSOR_ARROW
		else:
			end.text = "+\n%d / 10" % history.size()
			end.add_theme_font_size_override("font_size", 18)
			end.tooltip_text = "Choose the next evolution · costs 1 skill point"
			end.pressed.connect(_choose.bind(id, -1))
	var capacity: Button = hud._button("+\n5 / 5 SLOTS", 11)
	capacity.custom_minimum_size = Vector2(110, 58)
	capacity.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	capacity.tooltip_text = "All five active skill slots are equipped."
	capacity.pressed.connect(func(): hud.show_notice("Your five active slots are equipped: melee, cast, guard, movement and support."))
	hud.overlay_content.add_child(capacity)

func _tile(texture: Texture2D, edge: int, color: Color) -> Button:
	var button: Button = hud._button("", 12, true)
	button.custom_minimum_size = Vector2(edge, edge)
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	button.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	button.add_theme_stylebox_override("normal", hud._style(Color("171511"), color.darkened(0.25), 1, 0, 3, 3))
	button.add_theme_stylebox_override("hover", hud._style(Color("494130"), hud.GOLD, 2, 0, 3, 3))
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

func _choose(id: String, stage: int) -> void:
	var state: Node = hud.game.state
	var data: Dictionary = state.skills[id]
	if stage < 0 and int(data["investments"]) >= 10:
		hud.show_notice("Fully evolved. Click an existing stage to change it.")
		return
	if is_instance_valid(picker):
		picker.queue_free()
	picker = hud._panel()
	picker.theme = hud.root.theme
	hud.root.add_child(picker)
	var column: VBoxContainer = hud._column(picker, 20, 10)
	column.add_child(hud._label(data["name"], 13, hud.TEXT, true))
	column.add_child(hud._label("Choose stage %d · 1 skill point" % (int(data["investments"]) + 1) if stage < 0 else "Change stage %d · no point cost" % (stage + 1), 12))
	for branch in range(3):
		var button: Button = hud._button("%s\n%s" % [data["branches"][branch], EFFECTS[branch]], 13)
		button.add_theme_color_override("font_color", COLORS[branch])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = Vector2(440, 65)
		column.add_child(button)
		if stage < 0:
			button.disabled = not state.can_evolve_skill(id, branch)
		else:
			var ranks: Array = data["ranks"].duplicate()
			var old: int = int(data["history"][stage])
			ranks[old] -= 1
			ranks[branch] += 1
			button.disabled = old == branch or int(ranks.max()) > int(ranks.min()) + 2
		button.pressed.connect(_apply.bind(id, stage, branch))
	column.add_child(hud._label("Spread upgrades across branches; no branch may lead by more than 2.", 11, hud.MUTED))
	if stage < 0 and state.skill_points <= 0:
		column.add_child(hud._label("Earn skill points through bestiary discoveries.", 12, hud.GOLD))
	var close: Button = hud._button("CLOSE", 12)
	close.pressed.connect(picker.hide)
	column.add_child(close)
	_position_picker.call_deferred()

func _position_picker() -> void:
	await hud.get_tree().process_frame
	if not is_instance_valid(picker):
		return
	picker.reset_size()
	picker.position = (hud.get_viewport().get_visible_rect().size - picker.size) * 0.5
	picker.set_meta("default_size", picker.size)
	hud._register_window(picker, "evolution_picker")

func _apply(id: String, stage: int, branch: int) -> void:
	var success: bool
	if stage < 0:
		success = hud.game.state.evolve_skill(id, branch)
	else:
		success = hud.game.state.replace_evolution(id, stage, branch)
	if success:
		picker.hide()
		hud.game._save_journey()
		hud.refresh()

