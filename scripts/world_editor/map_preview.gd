extends Node3D
## Read-only foundation for the separate world editor. This deliberately does
## not offer Save or Apply until the authored world and gameplay agree.

var world: Node3D
var camera: Camera3D
var speed := 24.0
var looking := false
var status: Label

func _ready() -> void:
	DisplayServer.window_set_title("Xyles World Editor - Read-only Preview")
	world = load("res://scripts/world_builder.gd").new()
	world.name = "World"
	add_child(world)
	world.build()
	world.visual_time_preview = "day"
	world._apply_time_of_day()
	camera = Camera3D.new()
	camera.name = "EditorCamera"
	camera.position = Vector3(-23.0, 35.0, 54.0)
	add_child(camera)
	camera.look_at(Vector3(-36.0, 0.0, 32.0), Vector3.UP)
	camera.current = true
	camera.far = 1000.0
	_build_interface()

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -300.0
	panel.offset_right = -12.0
	panel.offset_top = 12.0
	panel.offset_bottom = 390.0
	layer.add_child(panel)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("241b17e8")
	style.border_color = Color("8f7044")
	style.set_border_width_all(2)
	style.set_content_margin_all(14.0)
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	var title := Label.new()
	title.text = "XYLES WORLD EDITOR"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("e6d6a8"))
	column.add_child(title)
	var map_label := Label.new()
	map_label.text = "MAP I  ·  THE ASHEN FRONTIER"
	map_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(map_label)
	var info := Label.new()
	info.text = "Read-only preview\n\nHold right mouse: look\nW / A / S / D: fly\nQ / E: down / up\nMouse wheel: change speed\nEscape: release mouse"
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(info)
	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	var footer := Label.new()
	footer.text = "Editing, drafts and Apply to Game are not yet available."
	footer.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer.add_theme_color_override("font_color", Color("d6bf88"))
	column.add_child(footer)

func _process(delta: float) -> void:
	if camera == null:
		return
	if looking:
		var direction := Vector3.ZERO
		if Input.is_physical_key_pressed(KEY_W): direction -= camera.global_basis.z
		if Input.is_physical_key_pressed(KEY_S): direction += camera.global_basis.z
		if Input.is_physical_key_pressed(KEY_A): direction -= camera.global_basis.x
		if Input.is_physical_key_pressed(KEY_D): direction += camera.global_basis.x
		if Input.is_physical_key_pressed(KEY_E): direction += Vector3.UP
		if Input.is_physical_key_pressed(KEY_Q): direction -= Vector3.UP
		if direction.length_squared() > 0.0:
			camera.position += direction.normalized() * speed * delta
	world.update_streamed_visuals(camera.global_position)
	world.update_terrain_chunks(camera.global_position)
	world.update_static_chunks(camera.global_position)
	if status != null:
		status.text = "Camera speed: %.0f m/s" % speed

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			looking = event.pressed
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if looking else Input.MOUSE_MODE_VISIBLE
			get_viewport().set_input_as_handled()
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			speed = clampf(speed * (1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2), 2.0, 250.0)
	elif event is InputEventMouseMotion and looking:
		camera.rotation.y -= event.relative.x * 0.002
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.002, -1.55, 1.55)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		looking = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
