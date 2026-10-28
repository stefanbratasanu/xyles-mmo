extends CanvasLayer
## Local character selection; no world state is active until a save is selected.
signal character_selected(path: String)
const Store = preload("res://scripts/character_store.gd")
const State = preload("res://scripts/game_state.gd")
const Frame = preload("res://scripts/classic_frame.gd")
var store: RefCounted
var roster: Array[Dictionary] = []
var list: ItemList
var name_input: LineEdit
var race_input: OptionButton
var class_input: OptionButton
var status: Label
var enter_button: Button
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
	race_input = OptionButton.new()
	race_input.name = "CharacterRace"
	for race: String in State.CHARACTER_RACES: race_input.add_item(race)
	creation.add_child(race_input)
	creation.add_child(_label("CLASS", 10, Color("b2a894")))
	class_input = OptionButton.new()
	class_input.name = "CharacterClass"
	for character_class: String in State.CHARACTER_CLASSES: class_input.add_item(character_class)
	creation.add_child(class_input)
	var note := _label("Race and class are identity choices for now. All characters currently share the same model, abilities and starting stats.", 11, Color("b2a894"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	creation.add_child(note)
	var create := _button("CREATE & ENTER")
	create.name = "CreateCharacter"
	create.pressed.connect(_create_character)
	creation.add_child(create)
	status = _label("", 11, Color("e1a899"))
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	outer.add_child(status)
	_refresh_roster()

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
	selected_details.text = "" if selected.is_empty() else "%s  /  %s" % [roster[selected[0]].race, roster[selected[0]]["class"]]

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
	var result: Dictionary = store.create_character(name_input.text, race_input.get_item_text(race_input.selected), class_input.get_item_text(class_input.selected))
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
	return button

func _style(fill: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(2)
	return style
