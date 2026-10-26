extends CharacterBody3D

const Visual = preload("res://scripts/actor_visual.gd")
var game: Node
var visual: Node3D
var destination := Vector3.ZERO
var moving_to_click: bool = false
var move_direction := Vector3.FORWARD
var dash_time: float = 0.0
var invulnerable_time: float = 0.0

func _ready() -> void:
	name = "Wayfarer"
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
		visual = Visual.new()
		visual.name = "Visual"
		add_child(visual)
		visual.build_knight()
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
	invulnerable_time = maxf(0, invulnerable_time - delta)
	dash_time = maxf(0, dash_time - delta)
	var input_dir := Vector2.ZERO
	if not game.hud.is_panel_open() and not game.is_dead:
		input_dir = Vector2(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	var direction := Vector3.ZERO
	if input_dir.length() > 0.0:
		moving_to_click = false
		direction = Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, game.camera_yaw).normalized()
	elif moving_to_click and not game.hud.is_panel_open() and not game.is_dead:
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
	if dash_time > 0:
		speed_value = 22.0
	velocity.x = direction.x * speed_value
	velocity.z = direction.z * speed_value
	velocity.y -= 20.0 * delta
	if is_on_floor():
		velocity.y = -0.2
	move_and_slide()
	position.x = clampf(position.x, -34.0, 34.0)
	position.z = clampf(position.z, -34.0, 34.0)
	if position.y < -4.0:
		position = game.world.player_spawn
	if direction.length_squared() > 0.01:
		move_direction = direction
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), delta * 14.0)
	visual.animate(delta, Vector2(velocity.x, velocity.z).length())

func face_point(point: Vector3) -> void:
	var offset := point - global_position
	if Vector2(offset.x, offset.z).length() > 0.01:
		visual.rotation.y = atan2(-offset.x, -offset.z)

func attack_animation() -> void:
	visual.strike = 1.0

func dash() -> void:
	dash_time = 0.28
	invulnerable_time = 0.38
	moving_to_click = false
