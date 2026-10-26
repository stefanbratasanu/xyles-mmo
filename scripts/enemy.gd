extends CharacterBody3D

const Visual = preload("res://scripts/actor_visual.gd")
var game: Node
var display_name: String = "Briarwolf"
var kind: String = "normal"
var hp: float = 64.0
var max_hp: float = 64.0
var home := Vector3.ZERO
var visual: Node3D
var selected_ring: MeshInstance3D
var health_mesh: MeshInstance3D
var name_label: Label3D
var dead: bool = false
var attack_timer: float = 1.5
var age: float = 0.0
var aggro: bool = false
var boss_timer: float = 5.0
var winding_up: bool = false
var telegraph: MeshInstance3D
var wander_offset: float = 0.0

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	max_hp = 64.0 if kind == "normal" else (200.0 if kind == "quest" else 850.0)
	hp = max_hp
	var scale_value: float = 1.0 if kind == "normal" else (1.35 if kind == "quest" else 2.45)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.55 * scale_value
	capsule.height = 1.5 * scale_value
	shape.shape = capsule
	shape.position.y = 0.8 * scale_value
	add_child(shape)
	visual = Visual.new()
	add_child(visual)
	if kind == "normal":
		visual.build_wolf()
	else:
		visual.build_knight(Color("6b5041") if kind == "quest" else Color("453651"), kind == "boss")
		visual.scale = Vector3.ONE * scale_value
	selected_ring = _ring(0.8 * scale_value, Color("d8ab63"))
	selected_ring.visible = false
	add_child(selected_ring)
	name_label = Label3D.new()
	name_label.text = display_name
	name_label.position.y = 1.9 * scale_value + 0.3
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.font_size = 29 if kind == "boss" else 24
	name_label.pixel_size = 0.008
	name_label.modulate = Color("e1c99a") if kind != "boss" else Color("d7b1dd")
	name_label.outline_size = 5
	add_child(name_label)
	health_mesh = MeshInstance3D.new()
	var health_bar := QuadMesh.new()
	health_bar.size = Vector2(1.1 * scale_value, 0.055)
	health_mesh.mesh = health_bar
	health_mesh.position.y = name_label.position.y - 0.20
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("b3614a")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	health_mesh.material_override = material
	add_child(health_mesh)
	wander_offset = randf() * TAU
	if kind == "boss":
		var light := OmniLight3D.new()
		light.light_color = Color("a68ac4")
		light.light_energy = 1.3
		light.omni_range = 6.0
		light.position.y = 3.5
		add_child(light)

func _ring(radius: float, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius
	mesh.outer_radius = radius + 0.065
	mesh.rings = 48
	mesh.ring_segments = 8
	instance.mesh = mesh
	instance.position.y = 0.09
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	instance.material_override = material
	return instance

func _physics_process(delta: float) -> void:
	if dead or not is_instance_valid(game) or not is_instance_valid(game.player):
		return
	age += delta
	attack_timer -= delta
	selected_ring.visible = game.target == self
	health_mesh.visible = hp < max_hp or game.target == self
	name_label.visible = game.target == self or kind != "normal" or aggro
	var to_player: Vector3 = game.player.global_position - global_position
	to_player.y = 0
	var distance: float = to_player.length()
	var detection: float = 7.0 if kind == "normal" else (8.0 if kind == "quest" else 12.0)
	var leash: float = 13.0 if kind != "boss" else 18.0
	if distance < detection and not game.is_dead:
		aggro = true
	if global_position.distance_to(home) > leash or game.is_dead:
		aggro = false
	var direction := Vector3.ZERO
	var reach: float = 1.8 if kind == "normal" else (2.5 if kind == "quest" else 4.0)
	var speed_value: float = 2.3 if kind == "normal" else (2.1 if kind == "quest" else 1.65)
	if aggro:
		if distance > reach and not winding_up:
			direction = to_player.normalized()
		elif attack_timer <= 0 and not winding_up:
			attack_timer = 1.7 if kind != "boss" else 2.3
			visual.strike = 1.0
			game.damage_player(7.0 if kind == "normal" else (12.0 if kind == "quest" else 18.0), self)
		if kind == "boss":
			boss_timer -= delta
			if boss_timer <= 0 and not winding_up:
				_begin_slam()
	else:
		if global_position.distance_to(home) > 1.6:
			direction = (home - global_position).normalized()
			speed_value = 1.5
		else:
			direction = Vector3(sin(age * 0.27 + wander_offset), 0, cos(age * 0.31 + wander_offset)) * 0.25
			speed_value = 0.7
		if hp < max_hp:
			hp = minf(max_hp, hp + delta * 4.0)
	velocity.x = direction.x * speed_value
	velocity.z = direction.z * speed_value
	velocity.y -= delta * 20.0
	if is_on_floor():
		velocity.y = -0.3
	move_and_slide()
	if direction.length() > 0.05:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), delta * 7)
	elif aggro and to_player.length() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-to_player.x, -to_player.z), delta * 7)
	visual.animate(delta, Vector2(velocity.x, velocity.z).length())

func _begin_slam() -> void:
	winding_up = true
	boss_timer = 7.0
	telegraph = _ring(5.5, Color("d46b64"))
	add_child(telegraph)
	game.state.notice.emit("Hollow Regent is gathering power. Leave the red circle!")
	var tween := create_tween()
	tween.tween_property(telegraph, "scale", Vector3(1, 2, 1), 1.7)
	tween.tween_callback(func():
		if not dead:
			game.burst(global_position + Vector3.UP * 0.1, Color("ba7dc4"), 5.5)
			if game.player.global_position.distance_to(global_position) < 5.8:
				game.damage_player(36.0, self)
		winding_up = false
		if is_instance_valid(telegraph):
			telegraph.queue_free()
	)

func take_damage(amount: float) -> void:
	if dead:
		return
	aggro = true
	hp = maxf(0, hp - amount)
	health_mesh.scale.x = maxf(0.01, hp / max_hp)
	game.floating_text(global_position + Vector3.UP * 1.6, str(roundi(amount)), Color("f1d7a2"))
	var tween := create_tween()
	tween.tween_property(visual, "scale", visual.scale * 1.05, 0.06)
	tween.tween_property(visual, "scale", Vector3.ONE * (1.0 if kind == "normal" else (1.35 if kind == "quest" else 2.45)), 0.12)
	if hp <= 0:
		dead = true
		collision_layer = 0
		game.enemy_defeated(self)
		name_label.hide()
		health_mesh.hide()
		selected_ring.hide()
		if is_instance_valid(telegraph):
			telegraph.queue_free()
		var death_tween := create_tween()
		death_tween.tween_property(visual, "rotation:z", PI * 0.45, 0.3)
		death_tween.tween_property(self, "position:y", -2.0, 1.2).set_delay(1.0)
		death_tween.tween_callback(queue_free)
