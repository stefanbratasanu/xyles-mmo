extends Node3D

const Grid := preload("res://scripts/world_editor/terrain_grid.gd")
const Catalog := preload("res://scripts/world_editor/asset_catalog.gd")
const Runtime := preload("res://scripts/world_editor/map_runtime.gd")
const Store := preload("res://scripts/world_editor/draft_store.gd")
const Zones := preload("res://scripts/world_editor/zone_data.gd")
const UNDO_LIMIT := 20
const ZONE_COLORS := [Color("58d4ad"), Color("ef875f"), Color("a995f2"), Color("a7cb52"), Color("5fa9e5"), Color("e6a2d4"), Color("e0ba54"), Color("66cbc8"), Color("e57587")]

var store = Store.new()
var world: Node3D
var camera: Camera3D
var brush_marker: MeshInstance3D
var selection_outline: MeshInstance3D
var zone_overlay: MultiMeshInstance3D
var view_container: SubViewportContainer
var scene_root: Node3D
var grid = Grid.new()
var draft_id := ""
var clear_base := false
var terrain_changed := false
var dirty := false
var placements: Array[Dictionary] = []
var removed_trees: Array[Dictionary] = []
var static_edits: Array[Dictionary] = []
var zone_definitions: Array[Dictionary] = []
var zone_pending: Dictionary = {}
var zone_index := -1
var zone_editing := false
var zone_erasing := false
var zone_base_cells: Dictionary = {}
var undo_stack: Array[Dictionary] = []
var stroke_active := false
var stroke_recorded := false
var selected: Node3D
var selected_id := ""
var selected_tree: Dictionary = {}
var selected_static: Dictionary = {}
var selected_asset := "oak"
var mode := "select"
var brush_radius := 10.0
var brush_strength := 2.0
var camera_speed := 24.0
var asset_brush_enabled := false
var asset_brushing := false
var brush_rng := RandomNumberGenerator.new()
var looking := false
var is_brushing := false
var brush_timer := 0.0
var updating_fields := false
var pending_action: Callable
var name_edit: LineEdit
var status: Label
var draft_list: ItemList
var terrain_tools: OptionButton
var brush_size_input: SpinBox
var terrain_size_slider: HSlider
var project_dialog: ConfirmationDialog
var project_source: OptionButton
var project_source_label: Label
var load_project_dialog: ConfirmationDialog
var load_project_list: ItemList
var active_map_label: Label
var zone_list: ItemList
var zone_legend: RichTextLabel
var zone_name: LineEdit
var zone_kind: OptionButton
var zone_minimum: SpinBox
var zone_maximum: SpinBox
var tabs: TabContainer
var asset_cards: Dictionary = {}
var active_preview: Node3D
var active_preview_viewport: SubViewport
var fields: Dictionary = {}
var confirmation: ConfirmationDialog

func _ready() -> void:
	DisplayServer.window_set_title("Xyles World Editor")
	Engine.max_fps = 60
	get_tree().auto_accept_quit = false
	_build_interface()
	_reset_world()
	_create_asset_previews()
	camera = Camera3D.new()
	camera.name = "EditorCamera"
	camera.position = Vector3(-23.0, 35.0, 54.0)
	scene_root.add_child(camera)
	camera.look_at(Vector3(-36.0, 0.0, 32.0), Vector3.UP)
	camera.current = true
	camera.far = 1000.0
	camera.near = 0.05
	brush_marker = MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.97
	ring.outer_radius = 1.0
	brush_marker.mesh = ring
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = Color("f3d383")
	brush_marker.material_override = ring_material
	brush_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	brush_marker.visible = false
	scene_root.add_child(brush_marker)
	_create_zone_overlay()
	selection_outline = MeshInstance3D.new()
	selection_outline.name = "SelectionOutline"
	selection_outline.mesh = ImmediateMesh.new()
	selection_outline.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene_root.add_child(selection_outline)
	_refresh_drafts()
	_refresh_active_label()
	_message("Map I loaded. Select an asset or terrain tool to begin.")

func _reset_world() -> void:
	if is_instance_valid(world):
		scene_root.remove_child(world)
		world.queue_free()
	world = load("res://scripts/world_builder.gd").new()
	world.name = "World"
	world.editor_pick_enabled = true
	scene_root.add_child(world)
	world.build()
	world.visual_time_preview = "day"
	world._apply_time_of_day()
	grid = Grid.new()
	grid.import_baked(load("res://assets/world/baked_world.res"))
	clear_base = false
	terrain_changed = false
	placements.clear()
	removed_trees.clear()
	static_edits.clear()
	zone_definitions.clear()
	zone_pending.clear()
	zone_index = -1
	zone_editing = false
	zone_base_cells.clear()
	selected = null
	selected_id = ""
	selected_tree.clear()
	selected_static.clear()
	if is_instance_valid(selection_outline):
		(selection_outline.mesh as ImmediateMesh).clear_surfaces()

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	view_container = SubViewportContainer.new()
	view_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view_container.offset_left = 8
	view_container.offset_top = 68
	view_container.offset_right = -508
	view_container.offset_bottom = -8
	view_container.stretch = true
	view_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(view_container)
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	view_container.add_child(viewport)
	scene_root = Node3D.new()
	viewport.add_child(scene_root)
	var toolbar := PanelContainer.new()
	toolbar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	toolbar.offset_left = 8
	toolbar.offset_right = -8
	toolbar.offset_top = 8
	toolbar.offset_bottom = 60
	layer.add_child(toolbar)
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color("241b17")
	bar_style.border_color = Color("8f7044")
	bar_style.set_border_width_all(2)
	bar_style.set_content_margin_all(8)
	toolbar.add_theme_stylebox_override("panel", bar_style)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	toolbar.add_child(bar)
	var title := Label.new()
	title.text = "XYLES WORLD EDITOR"
	title.add_theme_font_size_override("font_size", 19)
	title.add_theme_color_override("font_color", Color("e6d6a8"))
	bar.add_child(title)
	var brush_toggle := CheckButton.new()
	brush_toggle.text = "Asset brush"
	brush_toggle.tooltip_text = "Paint multiple copies of the selected asset on the map."
	brush_toggle.toggled.connect(func(enabled: bool) -> void: asset_brush_enabled = enabled; _message("Asset brush %s." % ("on" if enabled else "off")))
	bar.add_child(brush_toggle)
	var size_caption := _label(bar, "Size")
	size_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	size_caption.custom_minimum_size.x = 34
	brush_size_input = SpinBox.new()
	brush_size_input.min_value = 2.0
	brush_size_input.max_value = 60.0
	brush_size_input.step = 1.0
	brush_size_input.value = brush_radius
	brush_size_input.suffix = " m"
	brush_size_input.custom_minimum_size.x = 90
	brush_size_input.value_changed.connect(_set_brush_size)
	bar.add_child(brush_size_input)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	for config: Array in [["New project", _new_requested], ["Load project", _load_project_requested], ["Save draft", _save], ["Apply to game", _apply]]:
		var action := _button(bar, config[0], config[1])
		action.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		action.custom_minimum_size.x = 110
	var sidebar := PanelContainer.new()
	sidebar.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	sidebar.offset_left = -500
	sidebar.offset_right = -8
	sidebar.offset_top = 68
	sidebar.offset_bottom = -8
	layer.add_child(sidebar)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("241b17ed")
	style.border_color = Color("8f7044")
	style.set_border_width_all(2)
	style.set_content_margin_all(12)
	sidebar.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	sidebar.add_child(column)
	var map := OptionButton.new()
	map.add_item("Map I · The Ashen Frontier")
	map.tooltip_text = "Map I is the only existing map."
	column.add_child(map)
	active_map_label = Label.new()
	active_map_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	active_map_label.add_theme_color_override("font_color", Color("d6bf88"))
	column.add_child(active_map_label)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Draft name"
	name_edit.text = "My map draft"
	name_edit.text_changed.connect(func(_text: String) -> void: dirty = true)
	column.add_child(name_edit)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(tabs)
	for group: String in ["Environment", "Buildings"]:
		var scroll := ScrollContainer.new()
		scroll.name = "Nature" if group == "Environment" else group
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		tabs.add_child(scroll)
		var cards := GridContainer.new()
		cards.columns = 2
		cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cards.add_theme_constant_override("h_separation", 8)
		cards.add_theme_constant_override("v_separation", 8)
		scroll.add_child(cards)
		for entry: Dictionary in Catalog.list_group(group):
			_create_asset_card(cards, str(entry["id"]), str(entry["name"]))
	var terrain_scroll := ScrollContainer.new()
	terrain_scroll.name = "Terrain"
	terrain_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(terrain_scroll)
	var terrain := VBoxContainer.new()
	terrain.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	terrain.add_theme_constant_override("separation", 8)
	terrain_scroll.add_child(terrain)
	_label(terrain, "Surface materials · click to paint")
	var terrain_cards := GridContainer.new()
	terrain_cards.columns = 2
	terrain_cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	terrain_cards.add_theme_constant_override("h_separation", 8)
	terrain_cards.add_theme_constant_override("v_separation", 8)
	terrain.add_child(terrain_cards)
	_create_asset_card(terrain_cards, "terrain_ground", "Forest ground")
	_create_asset_card(terrain_cards, "terrain_dirt", "Road / dirt")
	_create_asset_card(terrain_cards, "terrain_rock", "Rock ground")
	var tools := OptionButton.new()
	terrain_tools = tools
	for tool: Array in [["Select objects", "select"], ["Paint forest ground", "ground"], ["Paint road / dirt", "dirt"], ["Paint rock", "rock"], ["Raise ground", "raise"], ["Lower ground", "lower"], ["Erase ground", "erase"]]:
		tools.add_item(tool[0])
		tools.set_item_metadata(tools.item_count - 1, tool[1])
	tools.item_selected.connect(_terrain_tool_selected.bind(tools))
	terrain.add_child(tools)
	_label(terrain, "Brush radius (metres)")
	var size := HSlider.new()
	terrain_size_slider = size
	size.min_value = 2.0
	size.max_value = 60.0
	size.value = brush_radius
	size.value_changed.connect(_set_brush_size)
	terrain.add_child(size)
	_label(terrain, "Sculpt strength (metres per stroke)")
	var strength := HSlider.new()
	strength.min_value = 0.2
	strength.max_value = 8.0
	strength.value = brush_strength
	strength.value_changed.connect(func(value: float) -> void: brush_strength = value)
	terrain.add_child(strength)
	_button(terrain, "Clear entire map…", _clear_requested)
	_button(terrain, "Fill empty ground", _fill_ground)
	_label(terrain, "Clears terrain, roads, lakes and placed scenery. Paint ground back onto the empty map.")
	var object_tab := VBoxContainer.new()
	object_tab.name = "Object"
	tabs.add_child(object_tab)
	_button(object_tab, "Select objects", _select_mode)
	_label(object_tab, "Select a placed object or existing scenery to edit it.")
	for field: String in ["X", "Y", "Z", "Rotation", "Scale"]:
		var row := HBoxContainer.new()
		object_tab.add_child(row)
		var caption := _label(row, field)
		caption.custom_minimum_size.x = 90
		var input := SpinBox.new()
		input.min_value = 0.05 if field == "Scale" else -10000
		input.max_value = 20 if field == "Scale" else 10000
		input.step = 0.05 if field == "Scale" else 0.1
		input.allow_greater = false
		input.allow_lesser = false
		input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		input.value_changed.connect(_field_changed.bind(field))
		row.add_child(input)
		fields[field] = input
	_button(object_tab, "Delete selected object", _delete_selected)
	var zone_scroll := ScrollContainer.new()
	zone_scroll.name = "Zones"
	zone_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(zone_scroll)
	var zone_tab := VBoxContainer.new()
	zone_tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	zone_tab.add_theme_constant_override("separation", 7)
	zone_scroll.add_child(zone_tab)
	_label(zone_tab, "Saved custom zones")
	zone_list = ItemList.new()
	zone_list.custom_minimum_size.y = 110
	zone_list.item_selected.connect(_zone_selected)
	zone_tab.add_child(zone_list)
	zone_legend = RichTextLabel.new()
	zone_legend.bbcode_enabled = true
	zone_legend.fit_content = true
	zone_legend.scroll_active = false
	zone_tab.add_child(zone_legend)
	_button(zone_tab, "New zone", _new_zone)
	zone_name = LineEdit.new()
	zone_name.placeholder_text = "Zone name"
	zone_tab.add_child(zone_name)
	zone_kind = OptionButton.new()
	for kind: String in ["Starter", "Enemy", "Neutral"]:
		zone_kind.add_item(kind)
	zone_tab.add_child(zone_kind)
	var zone_levels := HBoxContainer.new()
	zone_tab.add_child(zone_levels)
	var levels_caption := _label(zone_levels, "Enemy levels")
	levels_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	levels_caption.custom_minimum_size.x = 95
	zone_minimum = SpinBox.new()
	zone_minimum.min_value = 1
	zone_minimum.max_value = 999
	zone_minimum.value = 1
	zone_minimum.custom_minimum_size.x = 90
	zone_levels.add_child(zone_minimum)
	var levels_separator := _label(zone_levels, "to")
	levels_separator.autowrap_mode = TextServer.AUTOWRAP_OFF
	levels_separator.custom_minimum_size.x = 24
	zone_maximum = SpinBox.new()
	zone_maximum.min_value = 1
	zone_maximum.max_value = 999
	zone_maximum.value = 3
	zone_maximum.custom_minimum_size.x = 90
	zone_levels.add_child(zone_maximum)
	_button(zone_tab, "Paint selected zone", _begin_zone)
	var erase_zone := CheckButton.new()
	erase_zone.text = "Erase from zone"
	erase_zone.toggled.connect(func(enabled: bool) -> void: zone_erasing = enabled)
	zone_tab.add_child(erase_zone)
	_button(zone_tab, "Delete selected zone…", _delete_zone_requested)
	_label(zone_tab, "Enemy levels set the range for existing spawn points. Enemies currently use the midpoint (1–3 means level 2); no enemies are created. Paint selected zone enables the zone brush automatically. The yellow ring follows the mouse and yellow cells show unfinished painting. Right-click to finish. Shift + right mouse looks around.")
	var drafts := VBoxContainer.new()
	drafts.name = "Drafts"
	tabs.add_child(drafts)
	draft_list = ItemList.new()
	draft_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drafts.add_child(draft_list)
	_button(drafts, "Open selected draft", _open_selected_requested)
	_button(drafts, "Use original map in game", _original_requested)
	var instructions := Label.new()
	instructions.text = "WASD: fly · Q/E: down/up · Right mouse: look\nWheel: zoom · Shift: faster · Ctrl+Z: undo"
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(instructions)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_color_override("font_color", Color("e4ce98"))
	column.add_child(status)
	confirmation = ConfirmationDialog.new()
	confirmation.title = "Confirm"
	confirmation.confirmed.connect(func() -> void: if pending_action.is_valid(): pending_action.call())
	add_child(confirmation)
	project_dialog = ConfirmationDialog.new()
	project_dialog.title = "New project"
	project_dialog.dialog_text = ""
	project_dialog.min_size = Vector2i(480, 240)
	var project_options := VBoxContainer.new()
	project_options.custom_minimum_size = Vector2(440, 120)
	project_dialog.add_child(project_options)
	var project_caption := _label(project_options, "Choose a map and starting point:")
	project_caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	var map_choice := OptionButton.new()
	map_choice.add_item("Map I · The Ashen Frontier")
	map_choice.tooltip_text = "Map I is currently the only available map."
	project_options.add_child(map_choice)
	project_source = OptionButton.new()
	project_source.add_item("Copy the map currently applied to the game")
	project_source.add_item("Start from scratch · empty map")
	project_options.add_child(project_source)
	project_source_label = _label(project_options, "")
	project_source_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	project_dialog.confirmed.connect(_new_project_confirmed)
	add_child(project_dialog)
	load_project_dialog = ConfirmationDialog.new()
	load_project_dialog.title = "Load project"
	load_project_dialog.dialog_text = "Choose a saved project. Opening it does not apply it to the game."
	load_project_dialog.min_size = Vector2i(500, 320)
	load_project_list = ItemList.new()
	load_project_list.custom_minimum_size = Vector2(440, 210)
	load_project_list.item_activated.connect(_load_project_activated)
	load_project_dialog.add_child(load_project_list)
	load_project_dialog.confirmed.connect(_load_project_confirmed)
	add_child(load_project_dialog)
	tabs.tab_changed.connect(func(_index: int) -> void: _refresh_zone_overlay())

func _create_asset_card(parent: Node, id: String, label_text: String) -> void:
	var button := Button.new()
	button.custom_minimum_size = Vector2(180, 154)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.tooltip_text = "Select %s, then click the map. Hover to rotate." % label_text
	if id.begins_with("terrain_"):
		button.pressed.connect(_terrain_chosen.bind(id))
	else:
		button.pressed.connect(_asset_chosen.bind(id))
	parent.add_child(button)
	var content := VBoxContainer.new()
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 5
	content.offset_top = 5
	content.offset_right = -5
	content.offset_bottom = -5
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(content)
	var image := TextureRect.new()
	image.custom_minimum_size = Vector2(160, 112)
	image.size_flags_vertical = Control.SIZE_EXPAND_FILL
	image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(image)
	var caption := Label.new()
	caption.text = label_text
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(caption)
	asset_cards[id] = {"button": button, "image": image}

func _create_asset_previews() -> void:
	for id: String in asset_cards:
		var card: Dictionary = asset_cards[id]
		var viewport := SubViewport.new()
		viewport.size = Vector2i(200, 130)
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
		viewport.msaa_3d = Viewport.MSAA_4X
		(card["button"] as Button).add_child(viewport)
		var stage := Node3D.new()
		viewport.add_child(stage)
		var env_node := WorldEnvironment.new()
		var environment := Environment.new()
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color("171e1b")
		environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.ambient_light_color = Color("f2e5c9")
		environment.ambient_light_energy = 0.8
		env_node.environment = environment
		stage.add_child(env_node)
		var light := DirectionalLight3D.new()
		light.rotation_degrees = Vector3(-48, -35, 0)
		light.light_energy = 1.7
		stage.add_child(light)
		var model: Node3D
		if id.begins_with("terrain_"):
			model = Node3D.new()
			var plane := PlaneMesh.new()
			plane.size = Vector2(4.0, 4.0)
			var surface_id := 1 if id == "terrain_ground" else (2 if id == "terrain_dirt" else 3)
			plane.material = Runtime.make_materials(world)[surface_id]
			var tile := MeshInstance3D.new()
			tile.mesh = plane
			model.add_child(tile)
		else:
			model = Catalog.create(world, id)
		if model == null:
			continue
		stage.add_child(model)
		var bounds := AABB()
		var first := true
		for candidate: Node in model.find_children("*", "MeshInstance3D", true, false):
			var visual := candidate as MeshInstance3D
			if visual.mesh == null:
				continue
			var local_transform := model.global_transform.affine_inverse() * visual.global_transform
			var part: AABB = local_transform * visual.mesh.get_aabb()
			if first:
				bounds = part
				first = false
			else:
				bounds = bounds.merge(part)
		var center := bounds.get_center() if not first else Vector3.ZERO
		var size := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z)) if not first else 1.0
		var preview_camera := Camera3D.new()
		preview_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		preview_camera.size = maxf(size * 1.3, 0.5)
		preview_camera.position = center + Vector3(1.4, 1.1, 1.8).normalized() * maxf(size * 2.5, 2.0)
		stage.add_child(preview_camera)
		preview_camera.look_at(center, Vector3.UP)
		preview_camera.current = true
		(card["image"] as TextureRect).texture = viewport.get_texture()
		card["viewport"] = viewport
		card["model"] = model
		(card["button"] as Button).mouse_entered.connect(_preview_entered.bind(viewport, model))
		(card["button"] as Button).mouse_exited.connect(_preview_exited.bind(viewport, model))

func _preview_entered(viewport: SubViewport, model: Node3D) -> void:
	active_preview = model
	active_preview_viewport = viewport
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

func _preview_exited(viewport: SubViewport, model: Node3D) -> void:
	if active_preview == model:
		active_preview = null
		active_preview_viewport = null
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func _label(parent: Node, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _message(text: String) -> void:
	if status != null:
		status.text = text
	print("[WorldEditor] ", text)

func _confirm(text: String, action: Callable) -> void:
	pending_action = action
	confirmation.dialog_text = text
	confirmation.popup_centered()

func _asset_chosen(id: String) -> void:
	if zone_editing:
		_message("Right-click the map to finish the current zone first.")
		return
	selected_asset = id
	mode = "place"
	_message("Click the map to place " + str(Catalog.ASSETS[selected_asset]["name"]) + ".")

func _terrain_chosen(id: String) -> void:
	if zone_editing:
		_message("Right-click the map to finish the current zone first.")
		return
	mode = id.trim_prefix("terrain_")
	terrain_tools.select(1 if mode == "ground" else (2 if mode == "dirt" else 3))
	_message("Click or drag on the map to paint the selected surface.")

func _terrain_tool_selected(index: int, tools: OptionButton) -> void:
	if zone_editing:
		_message("Right-click the map to finish the current zone first.")
		return
	mode = str(tools.get_item_metadata(index))
	_message("Tool: " + tools.get_item_text(index))

func _select_mode() -> void:
	if zone_editing:
		_message("Right-click the map to finish the current zone first.")
		return
	mode = "select"
	_message("Click an object in the map view to select it.")

func _new_requested() -> void:
	if dirty:
		_confirm("Discard unsaved changes and start a new project?", _show_new_project)
	else:
		_show_new_project()

func _show_new_project() -> void:
	project_source.select(0)
	project_source_label.text = active_map_label.text
	project_dialog.reset_size()
	project_dialog.popup_centered(Vector2i(500, 240))

func _new_project_confirmed() -> void:
	if project_source.selected == 1:
		_new_draft()
		_clear_all()
		undo_stack.clear()
		_message("New empty project. Paint or fill ground to begin.")
		return
	var applied: Dictionary = store.load_published()
	var payload: Dictionary = applied.get("payload", {})
	if not payload.is_empty() and not bool(payload.get("original", false)):
		var problem := Runtime.validate(payload, world, false)
		if not problem.is_empty():
			_message("Could not copy the applied map: " + problem)
			return
		_new_draft()
		problem = _load_payload(payload)
		if not problem.is_empty():
			_message("Could not copy the applied map: " + problem)
			return
		draft_id = ""
		name_edit.text = "Copy of " + str(applied.get("name", "applied map"))
		dirty = true
		_message("New project copied from the applied game snapshot. Save it as a new draft.")
	else:
		_new_draft()
		_message("New project opened from the original map currently used by the game.")

func _load_project_requested() -> void:
	if dirty:
		_confirm("Discard unsaved changes and load a saved project?", _show_load_project)
	else:
		_show_load_project()

func _show_load_project() -> void:
	load_project_list.clear()
	var active: Dictionary = store.load_published()
	var active_id := str(active.get("id", ""))
	for draft: Dictionary in store.list_drafts():
		var label := str(draft["name"])
		if str(draft["id"]) == active_id:
			label += "  ·  applied snapshot" if draft.get("payload", {}) == active.get("payload", {}) else "  ·  draft differs from applied snapshot"
		load_project_list.add_item(label)
		load_project_list.set_item_metadata(load_project_list.item_count - 1, draft["id"])
	if load_project_list.item_count == 0:
		_message("No saved projects yet. Save a draft first.")
		return
	load_project_dialog.popup_centered()

func _load_project_confirmed() -> void:
	var chosen := load_project_list.get_selected_items()
	if chosen.is_empty():
		_message("Select a saved project first.")
		return
	_open_draft(str(load_project_list.get_item_metadata(chosen[0])))

func _load_project_activated(index: int) -> void:
	load_project_dialog.hide()
	_open_draft(str(load_project_list.get_item_metadata(index)))

func _refresh_active_label() -> void:
	if active_map_label == null:
		return
	var active: Dictionary = store.load_published()
	var title := "Original Ashen Frontier"
	if not active.is_empty() and not bool(active.get("payload", {}).get("original", false)):
		title = str(active.get("name", "Unnamed project")) + " (applied snapshot)"
	active_map_label.text = "Game uses: " + title

func _set_brush_size(value: float) -> void:
	brush_radius = value
	if brush_size_input != null:
		brush_size_input.set_value_no_signal(value)
	if terrain_size_slider != null:
		terrain_size_slider.set_value_no_signal(value)

func _create_zone_overlay() -> void:
	zone_overlay = MultiMeshInstance3D.new()
	zone_overlay.name = "ZoneOverlay"
	zone_overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(Zones.CELL_SIZE, Zones.CELL_SIZE)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 1.0, 1.0, 0.32)
	material.vertex_color_use_as_albedo = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh.material = material
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	zone_overlay.multimesh = multi
	scene_root.add_child(zone_overlay)
	_refresh_zone_overlay()

func _refresh_zone_list() -> void:
	if zone_list == null:
		return
	zone_list.clear()
	for index in zone_definitions.size():
		var zone: Dictionary = zone_definitions[index]
		zone_list.add_item("%s  ·  %s  ·  %d–%d" % [zone["name"], str(zone["kind"]).capitalize(), int(zone["level_min"]), int(zone["level_max"])])
		zone_list.set_item_custom_fg_color(index, ZONE_COLORS[(index + world.zones.size()) % ZONE_COLORS.size()])
	if zone_legend != null and is_instance_valid(world):
		var legend := "[b]Original game zones[/b]  "
		for index in world.zones.size():
			legend += "[color=#%s]● %s[/color]  " % [ZONE_COLORS[index % ZONE_COLORS.size()].to_html(false), world.zones[index]["name"]]
		zone_legend.text = legend + "\nYellow: unfinished zone brush"

func _refresh_zone_overlay() -> void:
	if not is_instance_valid(zone_overlay) or not is_instance_valid(world):
		return
	var visible := zone_editing or (tabs != null and tabs.get_tab_title(tabs.current_tab) == "Zones")
	zone_overlay.visible = visible
	if not visible:
		return
	if zone_base_cells.is_empty():
		var limit := ceili(world.BOUNDS / Zones.CELL_SIZE)
		for z in range(-limit, limit):
			for x in range(-limit, limit):
				var cell := Vector2i(x, z)
				var point: Vector2 = Zones.center_of(cell)
				if absf(point.x) > world.BOUNDS or absf(point.y) > world.BOUNDS:
					continue
				var best_index := 0
				var best_metric := INF
				for index in world.zones.size():
					var metric: float = world._zone_metric(world.zones[index], point)
					if metric < best_metric:
						best_metric = metric
						best_index = index
				zone_base_cells[cell] = best_index
		_refresh_zone_list()
	var all: Dictionary = {}
	for cell: Vector2i in zone_base_cells:
		all[cell] = ZONE_COLORS[int(zone_base_cells[cell]) % ZONE_COLORS.size()]
	for index in zone_definitions.size():
		if zone_editing and index == zone_index:
			continue
		for item: Array in zone_definitions[index]["cells"]:
			all[Vector2i(int(item[0]), int(item[1]))] = ZONE_COLORS[(index + world.zones.size()) % ZONE_COLORS.size()]
	for cell: Vector2i in zone_pending:
		all[cell] = Color(1.0, 0.82, 0.30, 0.72)
	var entries: Array[Dictionary] = []
	for cell: Vector2i in all:
		var point: Vector2 = Zones.center_of(cell)
		var height: float = grid.sample_height(point)
		if is_finite(height):
			entries.append({"at": Vector3(point.x, height + 0.45, point.y), "color": all[cell]})
	var multi := zone_overlay.multimesh
	multi.instance_count = entries.size()
	for index in entries.size():
		multi.set_instance_transform(index, Transform3D(Basis.IDENTITY, entries[index]["at"]))
		multi.set_instance_color(index, entries[index]["color"])

func _new_zone() -> void:
	if zone_editing and not zone_pending.is_empty():
		_message("Right-click to finish the current zone before starting another.")
		return
	zone_editing = false
	if mode == "zone":
		mode = "select"
	zone_index = -1
	zone_list.deselect_all()
	zone_name.text = ""
	zone_kind.select(0)
	zone_minimum.value = 1
	zone_maximum.value = 3
	zone_pending.clear()
	_refresh_zone_overlay()
	_message("Name the zone, choose its type and levels, then select Paint selected zone.")

func _zone_selected(index: int) -> void:
	if zone_editing:
		_message("Right-click to finish the current zone first.")
		return
	zone_index = index
	var zone: Dictionary = zone_definitions[index]
	zone_name.text = str(zone["name"])
	zone_kind.select(["starter", "enemy", "neutral"].find(str(zone["kind"])))
	zone_minimum.value = int(zone["level_min"])
	zone_maximum.value = int(zone["level_max"])
	_message("Select Paint selected zone to change this zone.")

func _delete_zone_requested() -> void:
	if zone_editing:
		_message("Right-click to finish the current zone first.")
		return
	if zone_index < 0 or zone_index >= zone_definitions.size():
		_message("Select a zone first.")
		return
	_confirm("Delete this zone from the current draft?", _delete_zone)

func _delete_zone() -> void:
	if zone_index < 0 or zone_index >= zone_definitions.size():
		return
	_record_undo()
	zone_definitions.remove_at(zone_index)
	zone_index = -1
	zone_pending.clear()
	Zones.apply(world, zone_definitions)
	_refresh_zone_list()
	_refresh_zone_overlay()
	dirty = true
	_message("Zone removed from the draft.")

func _begin_zone() -> void:
	if zone_name.text.strip_edges().is_empty():
		_message("Enter a zone name first.")
		return
	if zone_minimum.value > zone_maximum.value:
		_message("The minimum zone level cannot exceed the maximum.")
		return
	zone_pending.clear()
	if zone_index >= 0 and zone_index < zone_definitions.size():
		for item: Array in zone_definitions[zone_index]["cells"]:
			zone_pending[Vector2i(int(item[0]), int(item[1]))] = true
	zone_editing = true
	dirty = true
	mode = "zone"
	_refresh_zone_overlay()
	_message("Paint with left mouse. Right-click to finish; Shift + right mouse looks around.")

func _paint_zone(at: Vector3) -> void:
	_record_undo()
	var point := Vector2(at.x, at.z)
	var x0 := floori((point.x - brush_radius) / Zones.CELL_SIZE)
	var x1 := floori((point.x + brush_radius) / Zones.CELL_SIZE)
	var z0 := floori((point.y - brush_radius) / Zones.CELL_SIZE)
	var z1 := floori((point.y + brush_radius) / Zones.CELL_SIZE)
	for z in range(z0, z1 + 1):
		for x in range(x0, x1 + 1):
			var cell := Vector2i(x, z)
			var center: Vector2 = Zones.center_of(cell)
			if absf(center.x) <= world.BOUNDS and absf(center.y) <= world.BOUNDS and center.distance_squared_to(point) <= brush_radius * brush_radius:
				if zone_erasing:
					zone_pending.erase(cell)
				else:
					zone_pending[cell] = true
	_refresh_zone_overlay()

func _finish_zone() -> void:
	if not zone_editing:
		return
	var name := zone_name.text.strip_edges()
	if name.is_empty() or name.length() > 60 or zone_minimum.value > zone_maximum.value:
		_message("Enter a zone name of up to 60 characters and a valid level range.")
		return
	if zone_pending.is_empty():
		_message("Paint at least one area before finishing the zone.")
		return
	_record_undo()
	var cells: Array = []
	for cell: Vector2i in zone_pending:
		cells.append([cell.x, cell.y])
	var id := str(zone_definitions[zone_index]["id"]) if zone_index >= 0 else "zone_" + store.new_draft_id()
	var zone := {"id": id, "name": name, "kind": ["starter", "enemy", "neutral"][zone_kind.selected], "level_min": int(zone_minimum.value), "level_max": int(zone_maximum.value), "cells": cells}
	# A painted cell belongs to one defined zone. The newest brush stroke wins.
	for index in zone_definitions.size():
		if index == zone_index:
			continue
		var remaining: Array = []
		for item: Array in zone_definitions[index]["cells"]:
			if not zone_pending.has(Vector2i(int(item[0]), int(item[1]))):
				remaining.append(item)
		zone_definitions[index]["cells"] = remaining
	if zone_index < 0:
		zone_definitions.append(zone)
		zone_index = zone_definitions.size() - 1
	else:
		zone_definitions[zone_index] = zone
	zone_pending.clear()
	zone_editing = false
	mode = "select"
	Zones.apply(world, zone_definitions)
	_refresh_zone_list()
	zone_list.select(zone_index)
	_refresh_zone_overlay()
	dirty = true
	_message("Zone saved in this draft: " + name + ". Save the draft to keep it.")

func _new_draft() -> void:
	_reset_world()
	undo_stack.clear()
	stroke_active = false
	stroke_recorded = false
	_refresh_zone_list()
	_refresh_zone_overlay()
	draft_id = ""
	name_edit.text = "My map draft"
	dirty = false
	mode = "select"
	_message("New draft opened from the original map.")

func _payload() -> Dictionary:
	return {"format": 1, "clear_base": clear_base, "terrain": grid.to_data() if terrain_changed else null, "placements": placements.duplicate(true), "removed_trees": removed_trees.duplicate(true), "static_edits": static_edits.duplicate(true), "zones": zone_definitions.duplicate(true)}

func _record_undo() -> void:
	if stroke_active and stroke_recorded:
		return
	var terrain: Variant = null
	if terrain_changed:
		terrain = {"segments": grid.segments, "extent": grid.extent, "heights": grid.heights.duplicate(), "colors": grid.colors.duplicate(), "surfaces": grid.surfaces.duplicate(), "cells": grid.cells.duplicate()}
	undo_stack.append({"clear_base": clear_base, "terrain": terrain, "placements": placements.duplicate(true), "removed_trees": removed_trees.duplicate(true), "static_edits": static_edits.duplicate(true), "zones": zone_definitions.duplicate(true), "zone_pending": zone_pending.duplicate(), "zone_index": zone_index, "zone_editing": zone_editing, "mode": mode})
	if undo_stack.size() > UNDO_LIMIT:
		undo_stack.pop_front()
	if stroke_active:
		stroke_recorded = true

func _undo() -> void:
	if undo_stack.is_empty():
		_message("Nothing to undo in this project.")
		return
	is_brushing = false
	asset_brushing = false
	stroke_active = false
	stroke_recorded = false
	var snapshot: Dictionary = undo_stack.pop_back()
	var terrain_data: Variant = null
	if snapshot["terrain"] != null:
		var saved: Dictionary = snapshot["terrain"]
		var saved_grid = Grid.new()
		saved_grid.initialize(saved["segments"], saved["extent"], false)
		saved_grid.heights = saved["heights"]
		saved_grid.colors = saved["colors"]
		saved_grid.surfaces = saved["surfaces"]
		saved_grid.cells = saved["cells"]
		terrain_data = saved_grid.to_data()
	var payload := {"format": 1, "clear_base": snapshot["clear_base"], "terrain": terrain_data, "placements": snapshot["placements"], "removed_trees": snapshot["removed_trees"], "static_edits": snapshot["static_edits"], "zones": snapshot["zones"]}
	_reset_world()
	var problem := Runtime.apply(world, payload, false)
	if not problem.is_empty():
		_message("Undo could not restore the previous state: " + problem)
		return
	clear_base = bool(snapshot["clear_base"])
	terrain_changed = terrain_data != null
	if terrain_changed:
		grid = world.editor_terrain
	for item: Dictionary in snapshot["placements"]: placements.append(item.duplicate(true))
	for item: Dictionary in snapshot["removed_trees"]: removed_trees.append(item.duplicate(true))
	for item: Dictionary in snapshot["static_edits"]: static_edits.append(item.duplicate(true))
	for item: Dictionary in snapshot["zones"]: zone_definitions.append(item.duplicate(true))
	zone_pending = snapshot["zone_pending"].duplicate()
	zone_index = int(snapshot["zone_index"])
	zone_editing = bool(snapshot["zone_editing"])
	mode = str(snapshot["mode"])
	var nodes: Array[Node] = []
	for child: Node in world.get_children():
		if str(child.name).begins_with("Placed_"): nodes.append(child)
	for index in mini(nodes.size(), placements.size()):
		_attach_pick(nodes[index] as Node3D, str(placements[index].get("uid", "")))
	_refresh_zone_list()
	_refresh_zone_overlay()
	dirty = true
	_message("Last action undone. Save the draft to keep this change.")

func _save() -> bool:
	if zone_editing:
		_message("Right-click the map to finish the zone before saving the draft.")
		return false
	var name := name_edit.text.strip_edges()
	if name.is_empty():
		_message("Enter a draft name first.")
		return false
	var payload := _payload()
	var problem := Runtime.validate(payload, world, false)
	if not problem.is_empty():
		_message(problem)
		return false
	if draft_id.is_empty():
		draft_id = store.new_draft_id()
	var result: Error = store.save_draft(draft_id, name, "map_i", payload)
	if result != OK:
		_message("Could not save the draft (error %d)." % result)
		return false
	dirty = false
	_refresh_drafts()
	_message("Draft saved. The game still uses its previously selected map.")
	return true

func _apply() -> void:
	var problem := Runtime.validate(_payload(), world)
	if not problem.is_empty():
		_message(problem)
		return
	if not _save():
		return
	var result: Error = store.publish_draft(draft_id)
	if result == OK:
		_refresh_active_label()
	_message("Applied. Restart the game to load this draft." if result == OK else "Could not apply draft (error %d)." % result)

func _refresh_drafts() -> void:
	if draft_list == null:
		return
	draft_list.clear()
	for draft: Dictionary in store.list_drafts():
		draft_list.add_item(str(draft["name"]))
		draft_list.set_item_metadata(draft_list.item_count - 1, draft["id"])

func _open_selected_requested() -> void:
	var selection := draft_list.get_selected_items()
	if selection.is_empty():
		_message("Select a draft first.")
		return
	var id := str(draft_list.get_item_metadata(selection[0]))
	if dirty:
		_confirm("Discard unsaved changes and open the selected draft?", _open_draft.bind(id))
	else:
		_open_draft(id)

func _open_draft(id: String) -> void:
	var draft: Dictionary = store.load_draft(id)
	if draft.is_empty() or str(draft.get("map_id", "")) != "map_i":
		_message("Could not open this map draft.")
		return
	var payload: Dictionary = draft["payload"]
	var problem := Runtime.validate(payload, world, false)
	if not problem.is_empty():
		_message(problem)
		return
	_reset_world()
	undo_stack.clear()
	stroke_active = false
	stroke_recorded = false
	problem = _load_payload(payload)
	if not problem.is_empty():
		_message(problem)
		return
	draft_id = id
	name_edit.text = str(draft["name"])
	dirty = false
	mode = "select"
	_message("Draft opened: " + name_edit.text)

func _load_payload(payload: Dictionary) -> String:
	var problem := Runtime.apply(world, payload, false)
	if not problem.is_empty():
		return problem
	clear_base = bool(payload.get("clear_base", false))
	terrain_changed = payload.get("terrain", null) != null
	if terrain_changed:
		grid = world.editor_terrain
	placements.clear()
	for item: Dictionary in payload.get("placements", []):
		placements.append(item.duplicate(true))
	removed_trees.clear()
	for item: Dictionary in payload.get("removed_trees", []):
		removed_trees.append(item.duplicate(true))
	static_edits.clear()
	for item: Dictionary in payload.get("static_edits", []):
		static_edits.append(item.duplicate(true))
	zone_definitions.clear()
	for item: Dictionary in payload.get("zones", []):
		zone_definitions.append(item.duplicate(true))
	_refresh_zone_list()
	_refresh_zone_overlay()
	var nodes: Array[Node] = []
	for child: Node in world.get_children():
		if str(child.name).begins_with("Placed_"):
			nodes.append(child)
	for index in mini(nodes.size(), placements.size()):
		_attach_pick(nodes[index] as Node3D, str(placements[index].get("uid", "")))
	return ""

func _original_requested() -> void:
	_confirm("Use the original Ashen Frontier the next time the game starts? Your drafts will be kept.", _publish_original)

func _publish_original() -> void:
	var result: Error = store.publish_original()
	if result == OK:
		_refresh_active_label()
	_message("Original map selected. Restart the game." if result == OK else "Could not select the original map (error %d)." % result)

func _clear_requested() -> void:
	_confirm("Clear ALL terrain, roads, lakes and scenery from this draft? This will not change the game until you apply it.", _clear_all)

func _clear_all() -> void:
	_record_undo()
	Runtime.clear_world(world)
	grid.clear()
	Runtime.enable_editor_terrain(world, grid, false)
	clear_base = true
	terrain_changed = true
	placements.clear()
	removed_trees.clear()
	static_edits.clear()
	zone_definitions.clear()
	zone_pending.clear()
	zone_editing = false
	zone_index = -1
	_refresh_zone_list()
	_refresh_zone_overlay()
	selected = null
	selected_id = ""
	selected_tree.clear()
	selected_static.clear()
	_clear_outline()
	dirty = true
	mode = "ground"
	terrain_tools.select(1)
	_message("Map cleared. Use Terrain → Paint forest ground to create new land.")

func _fill_ground() -> void:
	_record_undo()
	if not terrain_changed:
		Runtime.enable_editor_terrain(world, grid, false)
		terrain_changed = true
	grid.cells.fill(1)
	for child: Node in world.get_children():
		if str(child.name).begins_with("EditedTerrain_"):
			Runtime.remove_node(child)
	Runtime._build_terrain(world, grid, Runtime.make_materials(world))
	_refresh_zone_overlay()
	dirty = true
	_message("Ground filled. Use the brushes to shape and paint it.")

func _input(event: InputEvent) -> void:
	# A release over a panel is consumed by the GUI; stop painting even there.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		is_brushing = false
		asset_brushing = false
		stroke_active = false
		stroke_recorded = false
	elif event is InputEventKey and event.pressed and not event.echo and event.ctrl_pressed and event.keycode == KEY_Z:
		var focused := get_viewport().gui_get_focus_owner()
		if not (focused is LineEdit or focused is TextEdit):
			_undo()
			get_viewport().set_input_as_handled()

func _field_changed(_value: float, field: String) -> void:
	if updating_fields:
		return
	if is_instance_valid(selected) or not selected_tree.is_empty():
		_record_undo()
	if not selected_tree.is_empty():
		_convert_tree()
	if not is_instance_valid(selected):
		return
	if selected_static.is_empty():
		selected.position = Vector3(fields["X"].value, fields["Y"].value, fields["Z"].value)
		selected.rotation.y = deg_to_rad(fields["Rotation"].value)
	else:
		selected.global_position = Vector3(fields["X"].value, fields["Y"].value, fields["Z"].value)
		selected.global_rotation.y = deg_to_rad(fields["Rotation"].value)
	if field == "Scale":
		var old_scale := selected.scale.x
		if absf(old_scale) > 0.0001:
			selected.scale *= float(fields["Scale"].value) / old_scale
	if selected_static.is_empty():
		_sync_selected_entry()
	else:
		_sync_static_entry(false)
	_outline_node(selected)

func _sync_selected_entry() -> void:
	for item: Dictionary in placements:
		if str(item.get("uid", "")) == selected_id:
			item["position"] = [selected.position.x, selected.position.y, selected.position.z]
			item["rotation"] = selected.rotation.y
			item["scale"] = selected.scale.x
			Runtime.sync_lakes(world, placements)
			dirty = true
			return

func _show_selected(node: Node3D) -> void:
	selected_tree.clear()
	selected_static.clear()
	selected = node
	selected_id = str(node.get_meta("editor_id", ""))
	updating_fields = true
	fields["X"].value = node.position.x
	fields["Y"].value = node.position.y
	fields["Z"].value = node.position.z
	fields["Rotation"].value = rad_to_deg(node.rotation.y)
	fields["Scale"].value = node.scale.x
	updating_fields = false
	_outline_node(node)
	_message("Object selected. Open the Object tab to move, rotate, scale or delete it.")

func _delete_selected() -> void:
	if not selected_tree.is_empty():
		_record_undo()
		_remove_selected_tree()
		selected_tree.clear()
		_clear_outline()
		_message("Original vegetation removed from this draft.")
		return
	if not is_instance_valid(selected):
		_message("Select an object first.")
		return
	_record_undo()
	if not selected_static.is_empty():
		_sync_static_entry(true)
		Runtime.remove_node(selected)
		selected = null
		selected_static.clear()
		_clear_outline()
		world._refresh_baked_dynamic_nodes()
		_message("Original object removed from this draft.")
		return
	for index in range(placements.size() - 1, -1, -1):
		if str(placements[index].get("uid", "")) == selected_id:
			placements.remove_at(index)
			break
	Runtime.remove_node(selected)
	selected = null
	selected_id = ""
	_clear_outline()
	dirty = true
	world._refresh_baked_dynamic_nodes()
	Runtime.sync_lakes(world, placements)
	_message("Object removed from draft.")

func _select_tree(body: StaticBody3D, shape_index: int) -> void:
	if not body.has_meta("editor_cell") or not body.has_meta("editor_group"):
		return
	var owner_id := body.shape_find_owner(shape_index)
	var collision := body.shape_owner_get_owner(owner_id) as CollisionShape3D
	if collision == null or not collision.has_meta("editor_index"):
		return
	var cell: Vector2i = body.get_meta("editor_cell")
	var item := {"cell": [cell.x, cell.y], "group": str(body.get_meta("editor_group")), "index": int(collision.get_meta("editor_index"))}
	_select_vegetation(item)

func _select_vegetation(item: Dictionary) -> void:
	var info := Runtime.tree_info(world, item)
	if info.is_empty():
		return
	selected = null
	selected_id = ""
	selected_static.clear()
	selected_tree = item
	var transform: Transform3D = info["transform"]
	updating_fields = true
	fields["X"].value = transform.origin.x
	fields["Y"].value = transform.origin.y
	fields["Z"].value = transform.origin.z
	fields["Rotation"].value = rad_to_deg(transform.basis.get_euler().y)
	fields["Scale"].value = transform.basis.get_scale().x
	updating_fields = false
	var mesh: Mesh = load("res://assets/world/vegetation/" + str(Catalog.ASSETS[str(info["asset"])]["mesh"]))
	if mesh != null:
		_outline_bounds(transform * mesh.get_aabb())
	_message("Original vegetation selected. Use Object to move, rotate, scale or delete it.")

func _select_static(body: StaticBody3D) -> void:
	var target := body.get_parent() as Node3D
	if target == null or str(target.name).begins_with("SurvivorCamp"):
		return
	for cell: Vector2i in world._static_active:
		var holder: Node = world._static_active[cell]
		if not holder.is_ancestor_of(target) or target == holder:
			continue
		_select_static_target(target, cell)
		return

func _clear_outline() -> void:
	if is_instance_valid(selection_outline):
		(selection_outline.mesh as ImmediateMesh).clear_surfaces()

func _outline_node(node: Node3D) -> void:
	if not is_instance_valid(node):
		_clear_outline()
		return
	var visuals: Array[Node] = node.find_children("*", "MeshInstance3D", true, false)
	if node is MeshInstance3D:
		visuals.append(node)
	var first := true
	var bounds := AABB()
	for candidate: Node in visuals:
		var visual := candidate as MeshInstance3D
		if visual.mesh == null:
			continue
		var part := visual.global_transform * visual.mesh.get_aabb()
		if first:
			bounds = part
			first = false
		else:
			bounds = bounds.merge(part)
	if first:
		_clear_outline()
	else:
		_outline_bounds(bounds)

func _outline_bounds(bounds: AABB) -> void:
	if not is_instance_valid(selection_outline):
		return
	var box := bounds.grow(0.12)
	var p := box.position
	var s := box.size
	var points := [p, p + Vector3(s.x, 0, 0), p + Vector3(s.x, 0, s.z), p + Vector3(0, 0, s.z), p + Vector3(0, s.y, 0), p + Vector3(s.x, s.y, 0), p + s, p + Vector3(0, s.y, s.z)]
	var edges := [0, 1, 1, 2, 2, 3, 3, 0, 4, 5, 5, 6, 6, 7, 7, 4, 0, 4, 1, 5, 2, 6, 3, 7]
	var mesh := selection_outline.mesh as ImmediateMesh
	mesh.clear_surfaces()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("f4ce72")
	material.no_depth_test = true
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for index: int in edges:
		mesh.surface_add_vertex(points[index])
	mesh.surface_end()

func _select_static_target(target: Node3D, cell: Vector2i) -> void:
	var holder: Node = world._static_active.get(cell)
	if holder == null or not holder.is_ancestor_of(target):
		return
	_show_selected(target)
	selected_static = {"cell": [cell.x, cell.y], "path": str(holder.get_path_to(target))}
	updating_fields = true
	fields["X"].value = target.global_position.x
	fields["Y"].value = target.global_position.y
	fields["Z"].value = target.global_position.z
	fields["Rotation"].value = rad_to_deg(target.global_rotation.y)
	updating_fields = false
	_message("Original object selected. Use Object to move, rotate, scale or delete it.")

## Existing scenery includes non-collidable props, so test their actual mesh
## bounds on selection rather than adding hundreds of gameplay colliders.
func _find_vegetation_visual(at: Vector2, max_distance: float) -> Dictionary:
	var local := at - view_container.global_position
	var origin := camera.project_ray_origin(local)
	var direction := camera.project_ray_normal(local)
	var best := max_distance
	var result: Dictionary = {}
	for cell: Vector2i in world._streamed_visual_nodes:
		if not world._vegetation_paths.has(cell):
			continue
		var tile: Resource = load(world._vegetation_paths[cell])
		for group: Dictionary in tile.groups:
			var group_name := str(group["name"])
			if group_name not in ["MeadowGrass", "Underbrush", "Wildflowers"]:
				continue
			var mesh: Mesh = load(group["mesh_path"])
			if mesh == null:
				continue
			var bounds := mesh.get_aabb()
			var key := "%d,%d:%s" % [cell.x, cell.y, group_name]
			var removed: Dictionary = world.editor_removed_trees.get(key, {})
			var entries: Array = group["entries"]
			for index in entries.size():
				if removed.has(index):
					continue
				var transform: Transform3D = entries[index]
				var to_instance := transform.origin - origin
				var along := to_instance.dot(direction)
				var reach := bounds.size.length() * transform.basis.get_scale().length()
				if along < -reach or along > best + reach or (to_instance - direction * along).length_squared() > reach * reach:
					continue
				var inverse := transform.affine_inverse()
				var local_hit: Variant = bounds.intersects_ray(inverse * origin, inverse.basis * direction)
				if not local_hit is Vector3:
					continue
				var distance := origin.distance_to(transform * local_hit)
				if distance < best:
					best = distance
					result = {"cell": [cell.x, cell.y], "group": group_name, "index": index, "distance": distance}
	return result

func _find_static_visual(at: Vector2, max_distance: float) -> Dictionary:
	var local := at - view_container.global_position
	var origin := camera.project_ray_origin(local)
	var direction := camera.project_ray_normal(local)
	var best := max_distance
	var result: Dictionary = {}
	for cell: Vector2i in world._static_active:
		var holder: Node = world._static_active[cell]
		for candidate: Node in holder.find_children("*", "MeshInstance3D", true, false):
			var visual := candidate as MeshInstance3D
			if visual.mesh == null or not visual.is_visible_in_tree():
				continue
			# The original camp fence's rails and collider are shared across an
			# entire ring. Moving one mesh would leave invisible collision behind.
			if str(visual.name).begins_with("Fence") or str(visual.name).begins_with("GateBeam") or str(visual.name).begins_with("GateBrace") or str(visual.name).begins_with("GateFinial"):
				continue
			var inverse := visual.global_transform.affine_inverse()
			var local_hit: Variant = visual.mesh.get_aabb().intersects_ray(inverse * origin, inverse.basis * direction)
			if not local_hit is Vector3:
				continue
			var distance := origin.distance_to(visual.to_global(local_hit))
			if distance >= best:
				continue
			var target: Node3D = visual
			var parent := visual.get_parent()
			while parent != holder and parent is Node3D:
				if str(parent.name).begins_with("Tent") or str(parent.name).begins_with("SittingLog") or str(parent.name).begins_with("RoadLamp"):
					target = parent
					break
				parent = parent.get_parent()
			best = distance
			result = {"node": target, "cell": cell, "distance": distance}
	return result

func _sync_static_entry(removed: bool) -> void:
	var entry := selected_static.duplicate(true)
	entry["removed"] = removed
	if not removed:
		entry["position"] = [selected.position.x, selected.position.y, selected.position.z]
		entry["rotation"] = [selected.rotation.x, selected.rotation.y, selected.rotation.z]
		entry["scale"] = [selected.scale.x, selected.scale.y, selected.scale.z]
	for index in range(static_edits.size() - 1, -1, -1):
		if static_edits[index]["cell"] == entry["cell"] and static_edits[index]["path"] == entry["path"]:
			static_edits.remove_at(index)
	static_edits.append(entry)
	Runtime.set_static_edits(world, static_edits)
	dirty = true

func _remove_selected_tree() -> void:
	removed_trees.append(selected_tree.duplicate(true))
	Runtime.apply_tree_removals(world, removed_trees)
	dirty = true

func _convert_tree() -> void:
	var info := Runtime.tree_info(world, selected_tree)
	if info.is_empty():
		return
	var values := [fields["X"].value, fields["Y"].value, fields["Z"].value, fields["Rotation"].value, fields["Scale"].value]
	var asset := str(info["asset"])
	_remove_selected_tree()
	selected_tree.clear()
	selected_asset = asset
	_place(Vector3(values[0], values[1], values[2]))
	updating_fields = true
	fields["Rotation"].value = values[3]
	fields["Scale"].value = values[4]
	updating_fields = false
	selected.rotation.y = deg_to_rad(values[3])
	selected.scale = Vector3.ONE * values[4]
	_sync_selected_entry()

func _attach_pick(node: Node3D, uid: String) -> void:
	node.set_meta("editor_id", uid)
	var area := Area3D.new()
	area.collision_layer = 1024
	area.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(4, 3, 5) if str(node.name).begins_with("Placed_tent") else Vector3(2, 3, 2)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	collider.position.y = 1.3
	area.add_child(collider)
	node.add_child(area)

func _place(at: Vector3, announce: bool = true, angle: float = 0.0, scale_value: float = 1.0) -> void:
	if placements.size() >= 20000:
		asset_brushing = false
		_message("This draft has reached the 20,000-object limit.")
		return
	var object := Catalog.create(world, selected_asset)
	if object == null:
		_message("Could not load the selected asset.")
		return
	_record_undo()
	var uid: String = store.new_draft_id()
	if selected_asset == "lake":
		at.y += 0.4
		if not terrain_changed:
			Runtime.enable_editor_terrain(world, grid, true)
			terrain_changed = true
		var center := Vector2(at.x, at.z)
		var outer: float = grid.shape_lake(center, 8.0 * scale_value, at.y)
		Runtime.refresh_brush(world, grid, center, outer)
		_refresh_zone_overlay()
	object.position = at
	object.rotation.y = angle
	object.scale = Vector3.ONE * scale_value
	world.add_child(object)
	_attach_pick(object, uid)
	placements.append({"uid": uid, "asset": selected_asset, "position": [at.x, at.y, at.z], "rotation": angle, "scale": scale_value})
	if selected_asset == "lake":
		Runtime.sync_lakes(world, placements)
	if announce:
		world._refresh_baked_dynamic_nodes()
		world._apply_time_of_day()
		_show_selected(object)
	dirty = true

func _scatter_assets(center: Vector3) -> void:
	for unused in 3:
		var angle := brush_rng.randf_range(0.0, TAU)
		var distance := sqrt(brush_rng.randf()) * brush_radius
		var x := center.x + cos(angle) * distance
		var z := center.z + sin(angle) * distance
		if absf(x) > world.BOUNDS or absf(z) > world.BOUNDS:
			continue
		if not _can_scatter(selected_asset, Vector2(x, z)):
			continue
		var height: float = grid.sample_height(Vector2(x, z)) if terrain_changed else world.surface_height_at(x, z)
		if not is_finite(height):
			continue
		var natural := str(Catalog.ASSETS[selected_asset]["group"]) == "Environment" and selected_asset != "lake"
		var rotation := brush_rng.randf_range(0.0, TAU) if natural else 0.0
		var scale_value := brush_rng.randf_range(0.85, 1.15) if natural else 1.0
		_place(Vector3(x, height, z), false, rotation, scale_value)
	world._refresh_baked_dynamic_nodes()
	world._apply_time_of_day()

func _can_scatter(asset: String, point: Vector2) -> bool:
	if asset == "lake":
		# Separate brushed ponds need room for their banks; overlapping lake
		# discs at different heights would cut through each other's shores.
		for pond: Dictionary in world.ponds():
			if point.distance_to(pond["center"]) < float(pond["radius"]) * 1.25 + 10.0:
				return false
	var is_tree := bool(Catalog.ASSETS[asset].get("tree", false))
	if is_tree or asset in ["grass", "bush", "flowers"]:
		if world._on_road(point, 0.4) or world.water_depth_at(point.x, point.y) > 0.0:
			return false
		if terrain_changed:
			var step: float = grid.extent * 2.0 / grid.segments
			var x := clampi(floori((point.x + grid.extent) / step), 0, grid.segments)
			var z := clampi(floori((point.y + grid.extent) / step), 0, grid.segments)
			if grid.surfaces[grid._index(x, z)] == 2:
				return false
	if not is_tree:
		return true
	var family := "dead" if asset == "dead_tree" else asset
	if not world.zone_at_xz(point)["trees"].has(family):
		return false
	var cell := Vector2i(floori(point.x / world.TREE_TRUNK_CLEARANCE), floori(point.y / world.TREE_TRUNK_CLEARANCE))
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			for existing: Vector2 in world._tree_spacing_cells.get(cell + Vector2i(dx, dz), []):
				if existing.distance_squared_to(point) < world.TREE_TRUNK_CLEARANCE * world.TREE_TRUNK_CLEARANCE:
					return false
	for entry: Dictionary in placements:
		if bool(Catalog.ASSETS[str(entry["asset"])].get("tree", false)):
			var position: Array = entry["position"]
			if Vector2(float(position[0]), float(position[2])).distance_squared_to(point) < world.TREE_TRUNK_CLEARANCE * world.TREE_TRUNK_CLEARANCE:
				return false
	return true

func _ray(at: Vector2, mask: int, areas: bool = false) -> Dictionary:
	var local := at - view_container.global_position
	var origin := camera.project_ray_origin(local)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(local) * 1600.0, mask)
	query.collide_with_areas = areas
	return camera.get_world_3d().direct_space_state.intersect_ray(query)

func _ground_point(at: Vector2) -> Variant:
	var hit := _ray(at, 1)
	if not hit.is_empty():
		return hit["position"]
	var local := at - view_container.global_position
	var origin := camera.project_ray_origin(local)
	var direction := camera.project_ray_normal(local)
	if absf(direction.y) < 0.0001:
		return null
	var distance := -origin.y / direction.y
	if distance < 0.0 or distance > 1600.0:
		return null
	return origin + direction * distance

func _paint(at: Vector3) -> void:
	if mode == "zone":
		_paint_zone(at)
		return
	_record_undo()
	var point := Vector2(at.x, at.z)
	if not terrain_changed:
		Runtime.enable_editor_terrain(world, grid, true)
		terrain_changed = true
	match mode:
		"ground", "dirt", "rock":
			grid.paint_ground(point, brush_radius, true)
			grid.paint_surface(point, brush_radius, 1 if mode == "ground" else (2 if mode == "dirt" else 3))
		"erase": grid.paint_ground(point, brush_radius, false)
		"raise": grid.sculpt(point, brush_radius, brush_strength * 0.15)
		"lower": grid.sculpt(point, brush_radius, -brush_strength * 0.15)
	Runtime.refresh_brush(world, grid, point, brush_radius)
	_refresh_zone_overlay()
	dirty = true

func _process(delta: float) -> void:
	if is_instance_valid(active_preview):
		active_preview.rotate_y(delta * 0.65)
	if camera == null:
		return
	var focused := get_viewport().gui_get_focus_owner()
	var typing := focused is LineEdit or focused is TextEdit
	var over_map := view_container.get_global_rect().has_point(get_viewport().get_mouse_position())
	_move_camera(delta, over_map, typing, Input.is_key_pressed(KEY_CTRL), Input.is_key_pressed(KEY_SHIFT), Input.is_physical_key_pressed(KEY_W), Input.is_physical_key_pressed(KEY_S), Input.is_physical_key_pressed(KEY_A), Input.is_physical_key_pressed(KEY_D), Input.is_physical_key_pressed(KEY_Q), Input.is_physical_key_pressed(KEY_E))
	world.update_streamed_visuals(camera.global_position)
	world.update_terrain_chunks(camera.global_position)
	world.update_static_chunks(camera.global_position)
	var mouse := get_viewport().get_mouse_position()
	var terrain_mode := mode in ["ground", "dirt", "rock", "raise", "lower", "erase", "zone"] or (mode == "place" and asset_brush_enabled)
	brush_marker.visible = terrain_mode and not looking and view_container.get_global_rect().has_point(mouse)
	if brush_marker.visible:
		var marker_position: Variant = _ground_point(mouse)
		if marker_position is Vector3:
			brush_marker.position = marker_position + Vector3.UP * 0.08
			brush_marker.scale = Vector3(brush_radius, 1.0, brush_radius)
			(brush_marker.material_override as StandardMaterial3D).albedo_color = Color("ffe05a") if mode == "zone" else Color("f3d383")
		else:
			brush_marker.visible = false
	if is_brushing:
		brush_timer -= delta
		if brush_timer <= 0.0 and view_container.get_global_rect().has_point(mouse):
			brush_timer = 0.18
			var point: Variant = _ground_point(mouse)
			if point is Vector3:
				_paint(point)
	if asset_brushing:
		brush_timer -= delta
		if brush_timer <= 0.0 and view_container.get_global_rect().has_point(mouse):
			brush_timer = 0.18
			var point: Variant = _ground_point(mouse)
			if point is Vector3:
				_scatter_assets(point)

func _move_camera(delta: float, over_map: bool, typing: bool, ctrl: bool, fast: bool, forward: bool, backward: bool, left: bool, right: bool, down: bool, up: bool) -> void:
	if not (looking or over_map) or typing or ctrl:
		return
	var direction := Vector3.ZERO
	if forward: direction -= camera.global_basis.z
	if backward: direction += camera.global_basis.z
	if left: direction -= camera.global_basis.x
	if right: direction += camera.global_basis.x
	if up: direction += Vector3.UP
	if down: direction -= Vector3.UP
	if direction.length_squared() > 0.0:
		camera.position += direction.normalized() * camera_speed * delta * (3.0 if fast else 1.0)

func _zoom_at(at: Vector2, inward: bool) -> void:
	var target: Variant = _ground_point(at)
	var direction: Vector3 = camera.project_ray_normal(at - view_container.global_position).normalized()
	var distance := camera.global_position.distance_to(target) if target is Vector3 else 30.0
	var step := maxf(distance * 0.25, 0.2)
	if inward:
		step = minf(step, maxf(distance - 0.2, 0.0))
		camera.global_position += direction * step
	else:
		camera.global_position -= direction * step

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and not looking and not view_container.get_global_rect().has_point(event.position):
			return
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if mode == "zone" and not looking and not event.shift_pressed:
				if event.pressed:
					_finish_zone()
				return
			looking = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if looking else Input.MOUSE_MODE_VISIBLE
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if not event.pressed:
				is_brushing = false
				asset_brushing = false
			elif not looking:
				get_viewport().gui_release_focus()
				if mode == "select":
					var hit := _ray(event.position, 1024 | 8 | 1, true)
					var distance := camera.global_position.distance_to(hit["position"]) if not hit.is_empty() else 1600.0
					var visual := _find_static_visual(event.position, distance)
					var vegetation := _find_vegetation_visual(event.position, float(visual.get("distance", distance)))
					if not vegetation.is_empty():
						vegetation.erase("distance")
						_select_vegetation(vegetation)
					elif not visual.is_empty():
						_select_static_target(visual["node"], visual["cell"])
					elif not hit.is_empty() and hit["collider"] is StaticBody3D:
						if hit["collider"].has_meta("editor_cell"):
							_select_tree(hit["collider"], int(hit["shape"]))
						else:
							_select_static(hit["collider"])
					elif not hit.is_empty() and hit["collider"].get_parent() is Node3D:
						_show_selected(hit["collider"].get_parent())
				elif mode == "place":
					if asset_brush_enabled:
						stroke_active = true
						stroke_recorded = false
						asset_brushing = true
						brush_timer = 0.0
					else:
						var at: Variant = _ground_point(event.position)
						if at is Vector3:
							_place(at)
				else:
					stroke_active = true
					stroke_recorded = false
					is_brushing = true
					brush_timer = 0.0
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if event.shift_pressed:
				camera_speed = clampf(camera_speed * (1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2), 2.0, 250.0)
			else:
				_zoom_at(event.position, event.button_index == MOUSE_BUTTON_WHEEL_UP)
	elif event is InputEventMouseMotion and looking:
		camera.rotation.y -= event.relative.x * 0.002
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.002, -1.55, 1.55)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		looking = false
		is_brushing = false
		asset_brushing = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if dirty:
			_confirm("Close without saving the current draft?", func() -> void: get_tree().quit())
		else:
			get_tree().quit()
