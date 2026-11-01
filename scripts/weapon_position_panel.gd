extends RefCounted
var hud: CanvasLayer
var fields: Array[SpinBox] = []
var status: Label
var freeze_button: Button
var align_button: Button
var aligning := false
var rotating := false
var _ctrl_click := false
var _weapon: Node3D
var _key := ""
var _start := Transform3D.IDENTITY
var _hand_start := Vector3.ZERO
var _right_rotating := false
var _alt_down := false
var hand_label: Label
var _mouse_mode := Input.MOUSE_MODE_VISIBLE
var _consume_release := MOUSE_BUTTON_NONE
const MOVE_PER_PIXEL := .001
const MOVE_PER_NOTCH := .01
const ROTATE_PER_PIXEL := .25
const ROTATE_PER_NOTCH := 2.0

func _init(owner_hud: CanvasLayer) -> void:
	hud = owner_hud

func render() -> void:
	hud.overlay_title.text = "Weapon position [F7]"
	hud.overlay_subtitle.text = "Adjust the weapon in the animated hand. Changes appear immediately."
	fields.clear()
	var player = hud.game.player
	if not is_instance_valid(player.weapon_visual):
		hud.overlay_content.add_child(hud._label("Equip a weapon to adjust its grip.", 12, hud.TEXT))
		return
	var identity: String = player.character_model_id.replace("_", " ").capitalize() + " / " + player.weapon_style.capitalize()
	if not player.weapon_visual_variant.is_empty(): identity += " / " + player.weapon_visual_variant.replace("_", " ").capitalize()
	hud.overlay_content.add_child(hud._label(identity, 12, hud.GOLD))
	for kind in ["Position (metres)", "Rotation (degrees)"]:
		hud.overlay_content.add_child(hud._label(kind, 12, hud.TEXT))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		hud.overlay_content.add_child(row)
		var value: Vector3 = player.weapon_visual.position if fields.is_empty() else player.weapon_visual.rotation_degrees
		for axis in range(3):
			row.add_child(hud._label(["X", "Y", "Z"][axis], 12, hud.GOLD))
			var field := SpinBox.new()
			field.min_value = -2 if kind.begins_with("Position") else -360
			field.max_value = 2 if kind.begins_with("Position") else 360
			field.step = MOVE_PER_PIXEL if kind.begins_with("Position") else ROTATE_PER_PIXEL
			field.custom_minimum_size.x = 110
			field.value = value[axis]
			field.value_changed.connect(func(_v: float): _apply())
			fields.append(field)
			row.add_child(field)
	var buttons := HBoxContainer.new()
	hud.overlay_content.add_child(buttons)
	var save: Button = hud._button("SAVE GRIP", 12, true)
	save.pressed.connect(_save)
	buttons.add_child(save)
	var reset: Button = hud._button("RESET TO MODEL", 12)
	reset.pressed.connect(func():
		finish_alignment(false)
		player.reset_weapon_grip()
		render_again())
	buttons.add_child(reset)
	freeze_button = hud._button("RESUME ANIMATION" if player.animation_frozen else "FREEZE ANIMATION", 12)
	freeze_button.pressed.connect(_toggle_freeze)
	buttons.add_child(freeze_button)
	var align_row := HBoxContainer.new()
	hud.overlay_content.add_child(align_row)
	align_button = hud._button("FAST ALIGN", 12)
	align_button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed: _ctrl_click = event.ctrl_pressed
		elif event is InputEventKey and event.pressed: _ctrl_click = event.ctrl_pressed)
	align_button.pressed.connect(func():
		start_alignment(_ctrl_click or Input.is_key_pressed(KEY_CTRL))
		_ctrl_click = false)
	align_row.add_child(align_button)
	var help: Label = hud._label("Mouse: move · hold right button: rotate weapon\nHold Alt: rotate hand · wheel: Z", 11, hud.MUTED)
	align_row.add_child(help)
	hand_label = hud._label("", 11, hud.MUTED)
	hud.overlay_content.add_child(hand_label)
	status = hud._label("Save keeps this race / model / weapon grip after restarting.", 11, hud.MUTED)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hud.overlay_content.add_child(status)
	_sync_fields()
	if aligning: _alignment_status()

func _toggle_freeze() -> void:
	var player = hud.game.player
	player.set_animation_frozen(not player.animation_frozen)
	hud.game.game_log.ui("animation_freeze", {"frozen": player.animation_frozen, "clip": str(player.animation_player.current_animation)})
	freeze_button.text = "RESUME ANIMATION" if player.animation_frozen else "FREEZE ANIMATION"
	status.text = "Pose frozen. Resume here when ready." if player.animation_frozen else "Animation resumed."

func start_alignment(rotation: bool) -> void:
	if aligning: finish_alignment(false)
	if not is_instance_valid(hud.game.player.weapon_visual): return
	_weapon = hud.game.player.weapon_visual
	_key = hud.game.player.weapon_grip_key()
	_start = _weapon.transform
	_hand_start = hud.game.player.hand_rotation_degrees
	_right_rotating = false
	_alt_down = Input.is_key_pressed(KEY_ALT)
	rotating = rotation
	aligning = true
	_mouse_mode = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_alignment_status()

func _alignment_status() -> void:
	var mode := "ROTATE HAND" if _alt_down else ("ROTATE WEAPON" if rotating or _right_rotating else "MOVE WEAPON")
	if is_instance_valid(status): status.text = mode + " · right-drag: weapon rotation · Alt: hand rotation · click/Enter: keep · Esc: cancel"

func update_context() -> void:
	if not aligning: return
	if hud.current_panel != "weapon_position" or not is_instance_valid(_weapon) or _weapon != hud.game.player.weapon_visual or _key != hud.game.player.weapon_grip_key():
		finish_alignment(false)

func finish_alignment(cancel: bool) -> void:
	if not aligning: return
	var same_weapon: bool = is_instance_valid(_weapon) and is_instance_valid(hud.game) and is_instance_valid(hud.game.player) and _weapon == hud.game.player.weapon_visual and _key == hud.game.player.weapon_grip_key()
	if cancel and same_weapon:
		_weapon.transform = _start
		hud.game.player.hand_rotation_degrees = _hand_start
	aligning = false
	_right_rotating = false
	_alt_down = false
	Input.mouse_mode = _mouse_mode
	if same_weapon: _sync_fields()
	if is_instance_valid(status): status.text = "Alignment cancelled." if cancel else "Adjustment kept · press SAVE GRIP to keep it after restarting."
	_weapon = null

func handle_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton and not event.pressed and event.button_index == _consume_release:
		_consume_release = MOUSE_BUTTON_NONE
		return true
	update_context()
	if not aligning: return false
	if event is InputEventKey:
		if event.physical_keycode == KEY_ALT or event.keycode == KEY_ALT:
			_alt_down = event.pressed
			_alignment_status()
		if event.pressed and not event.echo:
			if event.physical_keycode == KEY_ESCAPE: finish_alignment(true)
			elif event.physical_keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_F7]: finish_alignment(false)
		return true
	if event is InputEventMouseMotion:
		var movement: Vector2 = event.screen_relative
		if movement.is_zero_approx(): movement = event.relative
		if _alt_down or event.alt_pressed:
			_alt_down = true
			var hand: Vector3 = hud.game.player.hand_rotation_degrees
			hud.game.player.hand_rotation_degrees = _wrap_angles(hand + Vector3(-movement.y, movement.x, 0) * ROTATE_PER_PIXEL)
		elif rotating or _right_rotating:
			_weapon.rotation_degrees += Vector3(-movement.y, movement.x, 0) * ROTATE_PER_PIXEL
			_wrap_rotation()
		else:
			_weapon.position = (_weapon.position + Vector3(movement.x, -movement.y, 0) * MOVE_PER_PIXEL).clamp(Vector3.ONE * -2, Vector3.ONE * 2)
		_sync_fields()
		_alignment_status()
		return true
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_right_rotating = event.pressed
			_alignment_status()
			return true
		if event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_consume_release = MOUSE_BUTTON_LEFT
				finish_alignment(false)
			elif event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
				var amount := (1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0) * maxf(event.factor, 1)
				if _alt_down or event.alt_pressed:
					var hand: Vector3 = hud.game.player.hand_rotation_degrees
					hud.game.player.hand_rotation_degrees = _wrap_angles(hand + Vector3(0, 0, amount * ROTATE_PER_NOTCH))
				elif rotating or _right_rotating:
					_weapon.rotation_degrees += Vector3(0, 0, amount * ROTATE_PER_NOTCH)
					_wrap_rotation()
				else: _weapon.position.z = clampf(_weapon.position.z + amount * MOVE_PER_NOTCH, -2, 2)
				_sync_fields()
		return true
	return false

func _wrap_rotation() -> void:
	_weapon.rotation_degrees = _wrap_angles(_weapon.rotation_degrees)

func _wrap_angles(value: Vector3) -> Vector3:
	return Vector3(wrapf(value.x,-180,180), wrapf(value.y,-180,180), wrapf(value.z,-180,180))

func _sync_fields() -> void:
	if fields.size() != 6 or not is_instance_valid(hud.game.player.weapon_visual): return
	var weapon: Node3D = hud.game.player.weapon_visual
	for axis in range(3):
		fields[axis].set_value_no_signal(weapon.position[axis])
		fields[axis+3].set_value_no_signal(weapon.rotation_degrees[axis])
	if is_instance_valid(hand_label):
		var hand: Vector3 = hud.game.player.hand_rotation_degrees
		hand_label.text = "Hand rotation: X %.2f°   Y %.2f°   Z %.2f°" % [hand.x, hand.y, hand.z]

func render_again() -> void:
	hud._render_overlay()

func _apply() -> void:
	if fields.size() != 6 or not is_instance_valid(hud.game.player.weapon_visual): return
	var weapon: Node3D = hud.game.player.weapon_visual
	weapon.position = Vector3(fields[0].value, fields[1].value, fields[2].value)
	weapon.rotation_degrees = Vector3(fields[3].value, fields[4].value, fields[5].value)
	status.text = "Live adjustment · press SAVE GRIP to keep it."

func _save() -> void:
	finish_alignment(false)
	var player = hud.game.player
	if not is_instance_valid(player.weapon_visual): return
	var error: Error = player.weapon_grips.save_grip(player.weapon_grip_key(), player.weapon_visual, player.hand_rotation_degrees)
	status.text = "Grip saved." if error == OK else "Could not save grip: " + error_string(error)
	if error == OK:
		hud.game.game_log.ui("weapon_grip_saved", {"key": player.weapon_grip_key(), "position": str(player.weapon_visual.position), "rotation": str(player.weapon_visual.rotation_degrees), "hand_rotation": str(player.hand_rotation_degrees)})
