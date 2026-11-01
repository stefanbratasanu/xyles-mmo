extends CanvasLayer
## Local character selection; no world state is active until a save is selected.
signal character_selected(path: String)
const Store = preload("res://scripts/character_store.gd")
const State = preload("res://scripts/game_state.gd")
const Frame = preload("res://scripts/classic_frame.gd")
const AppearancePreview = preload("res://scripts/character_appearance_preview.gd")
const Models = preload("res://scripts/character_models.gd")
var store: RefCounted
var roster: Array[Dictionary] = []
var list: ItemList
var name_input: LineEdit
var race_input: OptionButton
var class_input: OptionButton
var gender_input: OptionButton
var status: Label
var enter_button: Button
var create_button: Button
var model_status: Label
var appearance: Dictionary = {"revision": 1, "body_size": 2, "muscularity": 3}
var creator: Control
var preview_character: Node3D
var preview: TextureRect
var creator_panel: Control
var rotation_input: HSlider
var pose_input: OptionButton
var outfit_input: CheckButton
var selected_details: Label

func _ready() -> void:
	if store == null: store = Store.new()
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	var backdrop := ColorRect.new()
	backdrop.color = Color("171510")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var panel: PanelContainer = Frame.new()
	panel.ornate = true
	panel.add_theme_stylebox_override("panel", _style(Color("211e18"), Color("8b7856"), 2))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.offset_left = -470
	panel.offset_right = 470
	panel.offset_top = -290
	panel.offset_bottom = 290
	backdrop.add_child(panel)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 24)
	panel.add_child(margin)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)
	var title := _label("XYLES  /  CHARACTER SELECTION", 20, Color("e9dbbb"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(title)
	var subtitle := _label("Select a character or create a new one.", 12, Color("b2a894"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	outer.add_child(subtitle)
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 24)
	outer.add_child(columns)
	var roster_column := VBoxContainer.new()
	roster_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(roster_column)
	roster_column.add_child(_label("YOUR CHARACTERS", 12, Color("d2af6e")))
	list = ItemList.new()
	list.name = "CharacterList"
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size = Vector2(360, 260)
	list.item_selected.connect(func(_index: int): _update_enter())
	list.item_activated.connect(func(_index: int): _enter_selected())
	roster_column.add_child(list)
	selected_details = _label("", 11, Color("b2a894"))
	selected_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	roster_column.add_child(selected_details)
	enter_button = _button("ENTER WORLD")
	enter_button.name = "EnterWorld"
	enter_button.pressed.connect(_enter_selected)
	roster_column.add_child(enter_button)
	var creation := VBoxContainer.new()
	creation.custom_minimum_size.x = 350
	creation.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	creation.add_theme_constant_override("separation", 9)
	columns.add_child(creation)
	creation.add_child(_label("CREATE CHARACTER", 12, Color("d2af6e")))
	creation.add_child(_label("NAME", 10, Color("b2a894")))
	name_input = LineEdit.new()
	name_input.name = "CharacterName"
	name_input.placeholder_text = "Choose a name"
	name_input.max_length = 24
	creation.add_child(name_input)
	creation.add_child(_label("RACE", 10, Color("b2a894")))
	race_input = _choice()
	race_input.name = "CharacterRace"
	for race: String in State.CHARACTER_RACES: race_input.add_item(race)
	creation.add_child(race_input)
	creation.add_child(_label("MODEL", 10, Color("b2a894")))
	gender_input = _choice()
	gender_input.name = "CharacterGender"
	for gender: String in State.CHARACTER_GENDERS: gender_input.add_item(gender)
	creation.add_child(gender_input)
	race_input.item_selected.connect(func(_index): _update_model_status())
	gender_input.item_selected.connect(func(_index): _update_model_status())
	creation.add_child(_label("CLASS", 10, Color("b2a894")))
	class_input = _choice()
	class_input.name = "CharacterClass"
	for character_class: String in State.CHARACTER_CLASSES: class_input.add_item(character_class)
	creation.add_child(class_input)
	var note := _label("One fixed build per race and gender. Abilities and starting stats are shared.", 11, Color("b2a894"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	creation.add_child(note)
	var customize := _button("APPEARANCE")
	customize.name = "CustomizeAppearance"
	customize.pressed.connect(_open_creator)
	creation.add_child(customize)
	model_status = _label("", 11, Color("d2af6e"))
	model_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	creation.add_child(model_status)
	create_button = _button("CREATE & ENTER")
	create_button.name = "CreateCharacter"
	create_button.pressed.connect(_create_character)
	creation.add_child(create_button)
	status = _label("", 11, Color("e1a899"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(status)
	_refresh_roster()
	_update_model_status()

func _update_model_status() -> void:
	var ready := Models.is_ready(race_input.get_item_text(race_input.selected), gender_input.get_item_text(gender_input.selected))
	create_button.disabled = not ready
	model_status.text = "" if ready else "Reference ready · 3D model and rig in preparation."

func _refresh_roster() -> void:
	roster = store.list_characters()
	list.clear()
	for entry: Dictionary in roster:
		if not entry.valid:
			list.add_item("Unreadable save  ·  " + str(entry.path).get_file())
			list.set_item_disabled(list.item_count - 1, true)
		else:
			list.add_item("%s   ·   Lv %d%s" % [entry.name, entry.level, "  ·  Original journey" if entry.legacy else ""])
	if list.item_count > 0:
		for i in range(roster.size()):
			if roster[i].valid:
				list.select(i)
				break
	_update_enter()

func _update_enter() -> void:
	var selected := list.get_selected_items()
	enter_button.disabled = selected.is_empty()
	selected_details.text = "" if selected.is_empty() else "%s  /  %s  /  %s" % [roster[selected[0]].race, roster[selected[0]].get("gender", "Male"), roster[selected[0]]["class"]]

func _enter_selected() -> void:
	var selected := list.get_selected_items()
	if selected.is_empty(): return
	var path: String = roster[selected[0]].path
	var probe := State.new()
	var valid := probe.load_game(path)
	probe.free()
	if not valid:
		status.text = "That save could not be loaded. It has not been changed."
		return
	character_selected.emit(path)

func _create_character() -> void:
	if not Models.is_ready(race_input.get_item_text(race_input.selected), gender_input.get_item_text(gender_input.selected)):
		status.text = "This model is still being prepared."
		return
	var result: Dictionary = store.create_character(name_input.text, race_input.get_item_text(race_input.selected), class_input.get_item_text(class_input.selected), {"revision": 1, "body_size": 2, "muscularity": 3}, gender_input.get_item_text(gender_input.selected))
	if result.has("error"):
		status.text = str(result.error)
		return
	character_selected.emit(str(result.path))

func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(value: String) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 38
	button.add_theme_color_override("font_color", Color("e9dbbb"))
	button.add_theme_stylebox_override("normal", _style(Color("343026"), Color("8b7856"), 1))
	button.add_theme_stylebox_override("hover", _style(Color("514a39"), Color("d2af6e"), 1))
	button.add_theme_stylebox_override("pressed", _style(Color("191713"), Color("d2af6e"), 1))
	button.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), Color("d2af6e"), 1))
	return button

func _choice() -> OptionButton:
	var choice := OptionButton.new()
	choice.custom_minimum_size.y = 34
	choice.add_theme_color_override("font_color", Color("e9dbbb"))
	choice.add_theme_stylebox_override("normal", _style(Color("191713"), Color("8b7856"), 1))
	choice.add_theme_stylebox_override("hover", _style(Color("343026"), Color("d2af6e"), 1))
	choice.add_theme_stylebox_override("pressed", _style(Color("191713"), Color("d2af6e"), 1))
	choice.add_theme_stylebox_override("focus", _style(Color(0, 0, 0, 0), Color("d2af6e"), 1))
	choice.get_popup().add_theme_stylebox_override("panel", _style(Color("211e18"), Color("8b7856"), 1))
	choice.get_popup().add_theme_color_override("font_color", Color("e9dbbb"))
	return choice

func _style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(2)
	return style

func _open_creator() -> void:
	if is_instance_valid(creator): return
	creator = ColorRect.new()
	creator.name = "AppearanceCreator"
	creator.color = Color(0.035, 0.03, 0.02, 0.98)
	creator.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(creator)
	var panel = Frame.new()
	creator_panel = panel
	panel.ornate = true
	panel.add_theme_stylebox_override("panel", _style(Color("211e18"), Color("8b7856"), 2))
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	creator.add_child(panel)
	_fit_creator()
	creator.resized.connect(_fit_creator)
	var margin := MarginContainer.new()
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 20)
	panel.add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	column.add_child(_label("CHARACTER APPEARANCE", 18, Color("e9dbbb")))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(row)
	var ready := Models.is_ready(race_input.get_item_text(race_input.selected), gender_input.get_item_text(gender_input.selected))
	preview = AppearancePreview.new() if ready else TextureRect.new()
	if ready: preview.model_scene = Models.scene(race_input.get_item_text(race_input.selected), gender_input.get_item_text(gender_input.selected))
	preview.name = "CharacterPreview"
	preview.custom_minimum_size = Vector2(360, 360)
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.size_flags_stretch_ratio = 1.35
	row.add_child(preview)
	if not ready:
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.texture = Models.concept(race_input.get_item_text(race_input.selected), gender_input.get_item_text(gender_input.selected))
		var pending := VBoxContainer.new()
		pending.custom_minimum_size.x = 280
		row.add_child(pending)
		pending.add_child(_label(race_input.get_item_text(race_input.selected).to_upper() + " / " + gender_input.get_item_text(gender_input.selected).to_upper(), 14, Color("d2af6e")))
		var note := _label("REFERENCE\n3D model and animation rig in preparation.\nOne fixed build per race.", 12, Color("b2a894"))
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pending.add_child(note)
		var close := _button("BACK")
		close.name = "CancelAppearance"
		close.pressed.connect(_close_creator)
		column.add_child(close)
		close.focus_next = NodePath(".")
		close.focus_previous = NodePath(".")
		close.grab_focus()
		return
	preview_character = preview.character
	var options := VBoxContainer.new()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.custom_minimum_size.x = 280
	options.add_theme_constant_override("separation", 8)
	row.add_child(options)
	options.add_child(_label(race_input.get_item_text(race_input.selected).to_upper() + " / " + gender_input.get_item_text(gender_input.selected).to_upper(), 12, Color("d2af6e")))
	var fixed_build := _label("One fixed build while the five races are refined.", 11, Color("b2a894"))
	fixed_build.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	options.add_child(fixed_build)
	preview_character.body_size = 2
	preview_character.muscularity = 3
	options.add_child(_label("ROTATE", 12, Color("d2af6e")))
	rotation_input = HSlider.new()
	rotation_input.name = "Rotation"
	rotation_input.min_value = -180; rotation_input.max_value = 180
	rotation_input.value_changed.connect(preview.set_yaw_degrees)
	preview.rotation_changed.connect(func(value): rotation_input.set_value_no_signal(value))
	options.add_child(rotation_input)
	var views := HBoxContainer.new()
	options.add_child(views)
	var full_body := _button("FULL BODY"); full_body.name = "FullBody"
	full_body.tooltip_text = "Fit the whole character in the preview."
	full_body.pressed.connect(func(): preview.set_portrait(false)); views.add_child(full_body)
	var face := _button("FACE"); face.name = "FaceView"
	face.tooltip_text = "Inspect the face at close range."
	face.pressed.connect(func(): preview.set_portrait(true)); views.add_child(face)
	var reset := _button("RESET"); reset.name = "ResetView"
	reset.tooltip_text = "Reset rotation, zoom and framing."
	reset.pressed.connect(preview.reset_view); views.add_child(reset)
	options.add_child(_label("POSE", 12, Color("d2af6e")))
	pose_input = _choice(); pose_input.name = "PreviewPose"
	for text in ["Rest pose", "Idle", "Walk", "Run"]: pose_input.add_item(text)
	pose_input.item_selected.connect(preview.set_pose)
	options.add_child(pose_input)
	outfit_input = CheckButton.new(); outfit_input.name = "OutfitPreview"
	outfit_input.text = "Show outfit"
	var preview_mesh: MeshInstance3D = preview_character.get_node("Skeleton3D/HumanFighter")
	outfit_input.disabled = not bool(preview_mesh.mesh.get_meta("outfit_coverage", false))
	outfit_input.tooltip_text = "Preview the current starter outfit. This does not change your saved body."
	outfit_input.toggled.connect(preview.set_outfit_visible)
	options.add_child(outfit_input)
	var hint := _label("Drag to rotate · Scroll to zoom", 11, Color("b2a894"))
	options.add_child(hint)
	var note := _label("Body choices change appearance only. Your stats stay the same.", 11, Color("b2a894"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	options.add_child(note)
	var buttons := HBoxContainer.new(); column.add_child(buttons)
	var cancel := _button("BACK"); cancel.name = "CancelAppearance"
	cancel.pressed.connect(_close_creator); buttons.add_child(cancel)
	var accept := _button("USE APPEARANCE"); accept.name = "UseAppearance"
	accept.pressed.connect(_accept_appearance); buttons.add_child(accept)
	# Keep keyboard traversal inside the modal, including when reverse-tabbing.
	var controls: Array[Control] = [rotation_input, full_body, face, reset, pose_input, outfit_input, cancel, accept]
	for index in range(controls.size()):
		controls[index].focus_next = controls[index].get_path_to(controls[(index + 1) % controls.size()])
		controls[index].focus_previous = controls[index].get_path_to(controls[(index - 1 + controls.size()) % controls.size()])
	rotation_input.grab_focus()

func _fit_creator() -> void:
	if not is_instance_valid(creator_panel): return
	var available := get_viewport().get_visible_rect().size - Vector2(48, 48)
	var dimensions := Vector2(minf(960, available.x), minf(760, available.y))
	creator_panel.offset_left = -dimensions.x * .5
	creator_panel.offset_right = dimensions.x * .5
	creator_panel.offset_top = -dimensions.y * .5
	creator_panel.offset_bottom = dimensions.y * .5

func _accept_appearance() -> void:
	if not is_instance_valid(preview_character): return
	appearance = {"revision": 1, "body_size": 2, "muscularity": 3}
	_close_creator()

func _close_creator() -> void:
	if not is_instance_valid(creator): return
	creator.queue_free()
	creator = null
	preview_character = null
	preview = null
	creator_panel = null
	var customize := find_child("CustomizeAppearance", true, false) as Button
	if customize != null: customize.grab_focus()

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(creator) and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_close_creator()
		get_viewport().set_input_as_handled()
