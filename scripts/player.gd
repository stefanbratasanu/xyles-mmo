extends CharacterBody3D

const CHARACTER_SCENE = preload("res://assets/animations/player_runtime/character.tscn")
const PROTOF_ANIMATIONS = preload("res://assets/animations/player_runtime/protof_animations.tres")
const SWORD_MODEL = preload("res://assets/animations/player_runtime/sword.tscn")
const GREATSWORD_MODEL = preload("res://assets/animations/player_runtime/greatsword.tscn")
const AUTHORED_SPEEDS_PATH := "res://assets/animations/player_runtime/authored_speeds.json"
var game: Node
var visual: Node3D
var animation_player: AnimationPlayer
var upper_body_player: AnimationPlayer
var upper_body_library := AnimationLibrary.new()
var authored_animation_speeds: Dictionary = {}
var weapon_attachment: BoneAttachment3D
var weapon_visual: Node3D
var weapon_style := "unarmed"
var action_active := false
var is_dying := false
var destination := Vector3.ZERO
var moving_to_click: bool = false
var move_direction := Vector3.FORWARD
var dash_time: float = 0.0
var invulnerable_time: float = 0.0
var jump_key_held := false
var was_airborne := false
var jump_started := false
var roll_elapsed := 0.0
var rolling := false
var sitting := false
const SIT_ANIMATIONS = preload("res://assets/animations/player_runtime/sit_animations.tres")
const WALK_SPEED_FACTOR := 0.55
const BACKWARD_SPEED_FACTOR := 0.60
const CROUCH_SPEED_FACTOR := 0.40
const JUMP_SPEED := 7.2
const SPRINT_SPEED_FACTOR := 1.50
const BASE_MOVEMENT_SPEED := 5.3
const MAX_WALK_ANIMATION_RATE := 1.4
const DODGE_DURATION := 0.55

func _ready() -> void:
	var speed_file := FileAccess.open(AUTHORED_SPEEDS_PATH, FileAccess.READ)
	if speed_file != null:
		var parsed: Variant = JSON.parse_string(speed_file.get_as_text())
		if parsed is Dictionary:
			authored_animation_speeds = parsed
	collision_layer = 2
	collision_mask = 1
	var shape: CollisionShape3D = get_node_or_null("CollisionShape3D") as CollisionShape3D
	if not is_instance_valid(shape):
		shape = CollisionShape3D.new()
		shape.name = "CollisionShape3D"
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.34
		capsule.height = 1.75
		shape.shape = capsule
		shape.position.y = 0.9
		add_child(shape)
	visual = get_node_or_null("Visual") as Node3D
	if not is_instance_valid(visual):
		visual = Node3D.new()
		visual.name = "Visual"
		add_child(visual)
	var character := visual.get_node_or_null("Character") as Node3D
	if not is_instance_valid(character):
		character = CHARACTER_SCENE.instantiate() as Node3D
		character.name = "Character"
		character.rotation.y = PI
		visual.add_child(character)
	animation_player = character.get_node_or_null("AnimationPlayer") as AnimationPlayer
	if animation_player != null:
		animation_player.add_animation_library(&"protof", PROTOF_ANIMATIONS)
		animation_player.add_animation_library(&"sit", SIT_ANIMATIONS)
		animation_player.animation_finished.connect(_on_animation_finished)
		_play_locomotion("protof/unarmed_idle")
		upper_body_player = AnimationPlayer.new()
		upper_body_player.name = "UpperBodyActions"
		upper_body_player.root_node = NodePath("..")
		upper_body_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		character.add_child(upper_body_player)
		upper_body_player.add_animation_library(&"upper", upper_body_library)
		process_priority = 100
	var skeleton := character.find_child("Skeleton3D", true, false) as Skeleton3D
	if skeleton != null:
		weapon_attachment = BoneAttachment3D.new()
		weapon_attachment.name = "EquippedWeapon"
		skeleton.add_child(weapon_attachment)
		weapon_attachment.bone_name = "humanoid_ R Hand"
	var ring: MeshInstance3D = get_node_or_null("SelectionRing") as MeshInstance3D
	if not is_instance_valid(ring):
		ring = MeshInstance3D.new()
		ring.name = "SelectionRing"
		var torus := TorusMesh.new()
		torus.inner_radius = 0.49
		torus.outer_radius = 0.53
		torus.rings = 24
		torus.ring_segments = 8
		ring.mesh = torus
		ring.position.y = 0.045
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("a5c8c0")
		mat.emission_enabled = true
		mat.emission = Color("5c9184")
		ring.material_override = mat
		add_child(ring)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(game):
		return
	if rolling:
		roll_elapsed = minf(roll_elapsed + delta, DODGE_DURATION)
		var roll_angle := -TAU * roll_elapsed / DODGE_DURATION
		visual.rotation.x = roll_angle
		visual.position = Vector3(0.0, 0.7 * (1.0 - cos(roll_angle)), 0.7 * sin(roll_angle)).rotated(Vector3.UP, visual.rotation.y)
		if roll_elapsed >= DODGE_DURATION:
			rolling = false
			visual.rotation.x = 0.0
			visual.position = Vector3.ZERO
			action_active = false
			animation_player.stop()
	invulnerable_time = maxf(0, invulnerable_time - delta)
	dash_time = maxf(0, dash_time - delta)
	var input_dir := Vector2.ZERO
	var controls_enabled: bool = not game.hud.is_panel_open() and not game.is_dead and not bool(game.get("ui_text_input"))
	if controls_enabled:
		input_dir = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	if sitting:
		if controls_enabled and (input_dir.length_squared() > 0 or Input.is_physical_key_pressed(KEY_SPACE) or moving_to_click):
			stand_up()
		input_dir = Vector2.ZERO
		controls_enabled = false
	var walking: bool = controls_enabled and Input.is_key_pressed(KEY_ALT)
	var crouching: bool = controls_enabled and Input.is_key_pressed(KEY_CTRL)
	var sprinting: bool = controls_enabled and Input.is_key_pressed(KEY_SHIFT) and input_dir.y < 0.0 and not walking and not crouching
	var jump_pressed: bool = controls_enabled and Input.is_physical_key_pressed(KEY_SPACE)
	var on_ground := is_on_floor()
	if jump_pressed and not jump_key_held and on_ground and not crouching and dash_time <= 0.0:
		velocity.y = JUMP_SPEED
		jump_started = true
		_play_action("protof/greatsword_JumpToApex2HandMelee" if weapon_style == "greatsword" else "protof/jump")
	jump_key_held = jump_pressed
	var direction := Vector3.ZERO
	if input_dir.length() > 0.0:
		moving_to_click = false
		direction = Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, game.camera_yaw).normalized()
	elif moving_to_click and not sitting and not game.hud.is_panel_open() and not game.is_dead and not bool(game.get("ui_text_input")):
		var offset := destination - global_position
		offset.y = 0
		if offset.length() > 0.3:
			direction = offset.normalized()
		else:
			moving_to_click = false
	if game.is_dead:
		direction = Vector3.ZERO
	if dash_time > 0:
		direction = move_direction
	var speed_value: float = 5.3 + game.state.get_skill_bonus("move") * 0.12
	var speed_factor := 1.0
	if sprinting:
		speed_factor = SPRINT_SPEED_FACTOR
	if input_dir.y > 0.0:
		speed_factor = BACKWARD_SPEED_FACTOR
	if walking:
		speed_factor = minf(speed_factor, WALK_SPEED_FACTOR)
	if crouching:
		speed_factor = minf(speed_factor, CROUCH_SPEED_FACTOR)
	speed_value *= speed_factor
	if direction.length_squared() > 0.0 and dash_time <= 0.0 and (walking or crouching or input_dir.y > 0.0):
		var walk_input := input_dir if input_dir.length_squared() > 0.0 else Vector2.UP
		var walk_clip := _movement_animation(walk_input, walking, crouching, true, false).trim_prefix("protof/")
		var clip_speed := float(authored_animation_speeds.get(walk_clip, 0.0))
		if clip_speed > 0.05:
			speed_value = minf(speed_value, clip_speed * MAX_WALK_ANIMATION_RATE)
	if dash_time > 0:
		speed_value = 11.2
	velocity.x = direction.x * speed_value
	velocity.z = direction.z * speed_value
	velocity.y -= 20.0 * delta
	if on_ground and not jump_started:
		velocity.y = -0.2
	move_and_slide()
	if jump_started:
		jump_started = false
		was_airborne = true
	elif not is_on_floor() and velocity.y < -0.5:
		was_airborne = true
	elif is_on_floor() and was_airborne:
		was_airborne = false
		_play_action("protof/greatsword_LandingLight2HandMelee" if weapon_style == "greatsword" else "protof/land")
	var world_limit: float = float(game.world.BOUNDS) - 1.0
	position.x = clampf(position.x, -world_limit, world_limit)
	position.z = clampf(position.z, -world_limit, world_limit)
	if position.y < -6.0:
		game.game_log.gameplay("fell_out_of_world", {"from": "(%.1f, %.1f, %.1f)" % [position.x, position.y, position.z]})
		position = game.world.player_spawn + Vector3.UP * 0.4
		velocity = Vector3.ZERO
	if direction.length_squared() > 0.01:
		move_direction = direction
		var facing_yaw: float = game.camera_yaw if input_dir.length_squared() > 0.0 and dash_time <= 0.0 else atan2(-direction.x, -direction.z)
		visual.rotation.y = lerp_angle(visual.rotation.y, facing_yaw, minf(delta * 14.0, 1.0))
		if animation_player != null and animation_player.current_animation in ["protof/land", "protof/greatsword_LandingLight2HandMelee"]:
			action_active = false
	if not action_active and not is_dying:
		var speed := Vector2(velocity.x, velocity.z).length()
		var moving := speed > 0.15
		if was_airborne:
			_play_locomotion("protof/greatsword_Falling2HandMelee" if weapon_style == "greatsword" else "protof/fall")
		else:
			var animation_input := input_dir if input_dir.length_squared() > 0.0 else (Vector2.UP if moving else Vector2.ZERO)
			var clip := _movement_animation(animation_input, walking, crouching, moving, sprinting)
			var reference_factor := CROUCH_SPEED_FACTOR if crouching else (BACKWARD_SPEED_FACTOR if animation_input.y > 0.0 and not walking else (WALK_SPEED_FACTOR if walking else (SPRINT_SPEED_FACTOR if sprinting and animation_input.y < 0.0 else 1.0)))
			var fallback_speed := BASE_MOVEMENT_SPEED * reference_factor
			var authored_speed := float(authored_animation_speeds.get(clip.trim_prefix("protof/"), fallback_speed))
			var rate := clampf(speed / maxf(authored_speed, 0.05), 0.25, 6.0) if moving else 1.0
			_play_locomotion(clip, rate)

func _process(delta: float) -> void:
	# The main AnimationPlayer updates first; the manual overlay then writes only
	# upper-body tracks, leaving the current leg movement intact.
	if upper_body_player != null and upper_body_player.is_playing():
		upper_body_player.advance(delta)

func _movement_animation(input_dir: Vector2, walking: bool, crouching: bool, moving: bool, sprinting: bool = false) -> String:
	if not moving:
		if crouching:
			return "protof/greatsword_IdleCrouchBreathe2HandMelee" if weapon_style == "greatsword" else "protof/crouch_idle"
		return "protof/" + weapon_style + "_idle"
	var horizontal := signi(int(input_dir.x))
	var vertical := signi(int(input_dir.y))
	var direction := "forward" if vertical < 0 else ("back" if vertical > 0 else "")
	if horizontal != 0:
		var side := "left" if horizontal < 0 else "right"
		direction = side if direction.is_empty() else direction + "_" + side
	if direction.is_empty():
		direction = "forward"
	if crouching:
		if weapon_style == "greatsword":
			var crouch_names := {"forward": "Forward", "back": "Backwards", "left": "Left", "right": "Right", "forward_left": "ForwardLeft", "forward_right": "ForwardRight", "back_left": "BackwardsLeft", "back_right": "BackwardsRight"}
			return "protof/greatsword_Crouch" + str(crouch_names[direction]) + "2HandMelee"
		return "protof/crouch_" + direction
	if sprinting and vertical < 0:
		return "protof/" + weapon_style + "_sprint"
	var gait := "walk" if walking or vertical > 0 else "run"
	if gait == "run" and direction == "forward":
		return "protof/" + weapon_style + "_run"
	return "protof/%s_%s_%s" % [weapon_style, gait, direction]

func face_point(point: Vector3) -> void:
	var offset := point - global_position
	if Vector2(offset.x, offset.z).length() > 0.01:
		visual.rotation.y = atan2(-offset.x, -offset.z)

func attack_animation() -> void:
	_play_upper_body_action("protof/greatsword_attack" if weapon_style == "greatsword" else ("protof/sword_attack" if weapon_style == "sword" else "protof/unarmed_attack"))

## Play any imported two-handed clip using the part of its FBX filename after
## "Humanoid@". Looping full-body clips remain active until explicitly stopped.
func play_greatsword_animation(clip_name: String, upper_body_only: bool = false) -> bool:
	var full_name := "protof/greatsword_" + clip_name.trim_prefix("Humanoid@").trim_suffix(".fbx")
	if animation_player == null or not animation_player.has_animation(full_name):
		return false
	if upper_body_only:
		return _play_upper_body_action(full_name)
	_play_action(full_name)
	return true

func stop_greatsword_animation() -> void:
	if upper_body_player != null:
		upper_body_player.stop()
	if animation_player != null and animation_player.is_playing():
		animation_player.stop()
	action_active = false

func cast_animation() -> void:
	_play_upper_body_action("protof/wizard_cast", 2.0)

func block_animation() -> void:
	_play_action("protof/greatsword_block" if weapon_style == "greatsword" else ("protof/sword_block" if weapon_style == "sword" else "protof/unarmed_block"))

func support_animation() -> void:
	_play_upper_body_action("protof/wizard_support", 2.8)

func update_equipment(equipment: Array) -> void:
	var next_style := "unarmed"
	for item: Dictionary in equipment:
		if str(item.get("slot", "")) == "weapon":
			var item_name := str(item.get("name", "")).to_lower()
			next_style = "greatsword" if "greatblade" in item_name or "greatsword" in item_name else "sword"
			break
	if next_style == weapon_style:
		return
	weapon_style = next_style
	if is_instance_valid(weapon_visual):
		weapon_visual.queue_free()
		weapon_visual = null
	if weapon_attachment != null and weapon_style != "unarmed":
		weapon_visual = (GREATSWORD_MODEL if weapon_style == "greatsword" else SWORD_MODEL).instantiate() as Node3D
		weapon_attachment.add_child(weapon_visual)
		# FBX prop pivots and the hand bone use different axes. Align the blade
		# along the grip and move the handle into the fingers.
		var blade_direction := (Vector3(0.07, 0.0, 1.0) if weapon_style == "greatsword" else Vector3(0.25, -0.06, 0.96)).normalized()
		var handle_offset := 0.04 if weapon_style == "greatsword" else 0.06
		weapon_visual.quaternion = Quaternion(Vector3.UP, blade_direction)
		weapon_visual.position = Vector3(0.095, -0.008, 0.039) + blade_direction * handle_offset
		weapon_visual.visible = not sitting

func toggle_sit() -> void:
	if sitting:
		stand_up()
	elif is_on_floor() and not action_active and not is_dying:
		sitting = true
		moving_to_click = false
		dash_time = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		if is_instance_valid(weapon_visual):
			weapon_visual.hide()
		_play_action("sit/enter")

func stand_up() -> void:
	if sitting and animation_player.current_animation == "sit/idle":
		_play_action("sit/exit")

func death_animation() -> void:
	sitting = false
	if is_instance_valid(weapon_visual):
		weapon_visual.show()
	rolling = false
	visual.rotation.x = 0.0
	visual.position = Vector3.ZERO
	is_dying = true
	_play_action("protof/greatsword_DeathFront2HandMelee" if weapon_style == "greatsword" else "protof/death")

func revive_animation() -> void:
	is_dying = false
	action_active = false
	_play_locomotion("protof/unarmed_idle")

func _play_locomotion(animation_name: String, playback_rate: float = 1.0) -> void:
	if animation_player == null or not animation_player.has_animation(animation_name):
		return
	animation_player.speed_scale = playback_rate
	if animation_player.current_animation != animation_name or not animation_player.is_playing():
		animation_player.play(animation_name, 0.15)

func _play_upper_body_action(animation_name: String, playback_speed: float = 1.0) -> bool:
	if animation_player == null or upper_body_player == null or not animation_player.has_animation(animation_name):
		return false
	var clip_key := animation_name.trim_prefix("protof/")
	if not upper_body_library.has_animation(clip_key):
		var source: Animation = animation_player.get_animation(animation_name)
		var upper_clip: Animation = source.duplicate(true)
		upper_clip.loop_mode = Animation.LOOP_NONE
		for track in range(upper_clip.get_track_count() - 1, -1, -1):
			var path: NodePath = upper_clip.track_get_path(track)
			var bone := String(path.get_subname(0)) if path.get_subname_count() > 0 else ""
			if not ("Spine" in bone or "Clavicle" in bone or "UpperArm" in bone or "Forearm" in bone or "Hand" in bone or "Finger" in bone or "Neck" in bone or "Head" in bone):
				upper_clip.remove_track(track)
		upper_body_library.add_animation(clip_key, upper_clip)
	upper_body_player.play("upper/" + clip_key, -1, playback_speed)
	return true

func _play_action(animation_name: String) -> void:
	if animation_player == null or not animation_player.has_animation(animation_name):
		return
	if upper_body_player != null:
		upper_body_player.stop()
	action_active = true
	animation_player.speed_scale = 1.6 if animation_name.begins_with("sit/") and animation_name != "sit/idle" else 1.0
	animation_player.play(animation_name, 0.1)

func _on_animation_finished(animation_name: StringName) -> void:
	if sitting:
		match str(animation_name):
			"sit/enter": _play_action("sit/down")
			"sit/down": _play_action("sit/idle")
			"sit/exit": _play_action("sit/stand")
			"sit/stand":
				sitting = false
				action_active = false
				if is_instance_valid(weapon_visual):
					weapon_visual.show()
		return
	action_active = false

func dash() -> void:
	dash_time = DODGE_DURATION
	rolling = true
	roll_elapsed = 0.0
	invulnerable_time = 0.38
	moving_to_click = false
	_play_action("protof/greatsword_IdleCrouchBreathe2HandMelee" if weapon_style == "greatsword" else "protof/crouch_idle")
