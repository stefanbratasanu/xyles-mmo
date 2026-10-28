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
var health_bar_root: Node3D
var health_bg: MeshInstance3D
var health_fill: MeshInstance3D
var health_bar_width: float = 1.0
var health_display_ratio: float = 1.0
var name_label: Label3D
var dead: bool = false
var attack_timer: float = 1.5
var age: float = 0.0
var aggro: bool = false
var boss_timer: float = 5.0
var winding_up: bool = false
var attack_windup: float = 0.0
var slam_active: bool = false
var sidestep_time: float = 0.0
var sidestep_dir := Vector3.ZERO
var stuck_timer: float = 0.0
var last_position := Vector3.ZERO
var telegraph: MeshInstance3D
var wander_offset: float = 0.0
var level_min: int = 1
var level_max: int = 3
var level: int = 2
var power: float = 1.0
var damage_scale: float = 1.0


## Called by main.gd before the enemy enters the tree. The zone band decides how
## much health and damage the same species has in each region, so a Briarwolf in
## the sanctum is not the tutorial wolf from the vale.
func configure_zone(zone: Dictionary) -> void:
	level_min = int(zone.get("level_min", 1))
	level_max = int(zone.get("level_max", 3))
	level = int(round((float(level_min) + float(level_max)) * 0.5))
	var ramp: float = maxf(0.0, float(level) - 2.0) * 0.18
	power = 1.0 + ramp * (0.42 if kind == "boss" else 1.0)
	damage_scale = 0.7 + power * 0.35


func _ready() -> void:
	collision_layer = 4
	# 1 = terrain, 2 = player, 4 = other enemies. Without this the old mask (world
	# only) let wolves walk straight through the player and through each other,
	# which is what looked like clipping during a fight.
	collision_mask = 1 | 2 | 4
	# The terrain is a triangle mesh with real slopes. Floor snapping and a
	# forgiving floor angle keep the mob on the ground instead of losing the
	# surface on a crest and jittering in place.
	floor_snap_length = 0.8
	floor_max_angle = deg_to_rad(60.0)
	floor_stop_on_slope = true
	safe_margin = 0.04
	max_hp = (64.0 if kind == "normal" else (200.0 if kind == "quest" else 850.0)) * power
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
	name_label.text = "%s  ·  Lv %d" % [display_name, level]
	name_label.position.y = 1.9 * scale_value + 0.3
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.font_size = 29 if kind == "boss" else 24
	name_label.pixel_size = 0.008
	name_label.modulate = Color("e1c99a") if kind != "boss" else Color("d7b1dd")
	name_label.outline_size = 5
	add_child(name_label)
	health_bar_width = 1.1 * scale_value
	health_bar_root = Node3D.new()
	health_bar_root.name = "HealthBar"
	health_bar_root.position.y = name_label.position.y - 0.20
	add_child(health_bar_root)
	var background_quad := QuadMesh.new()
	background_quad.size = Vector2(health_bar_width + 0.07, 0.09)
	health_bg = MeshInstance3D.new()
	health_bg.mesh = background_quad
	health_bg.material_override = _health_bar_material(Color("241c18"))
	health_bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	health_bar_root.add_child(health_bg)
	var fill_quad := QuadMesh.new()
	fill_quad.size = Vector2(health_bar_width, 0.06)
	health_fill = MeshInstance3D.new()
	health_fill.mesh = fill_quad
	# Sit just in front of the frame so the fill never z-fights with it.
	health_fill.position.z = 0.01
	health_fill.material_override = _health_bar_material(Color("a85a45"))
	health_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	health_bar_root.add_child(health_fill)
	_apply_health_ratio(1.0)
	health_bar_root.visible = false
	wander_offset = randf() * TAU
	last_position = global_position
	if kind == "boss":
		var light := OmniLight3D.new()
		light.light_color = Color("a68ac4")
		light.light_energy = 1.3
		light.omni_range = 6.0
		light.position.y = 3.5
		add_child(light)

func _health_bar_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

## The fill is anchored at the left edge of the frame: scaling around the mesh
## center alone would make both ends move inward and look like a floating bar.
func _apply_health_ratio(ratio: float) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	health_fill.scale.x = maxf(0.001, ratio)
	health_fill.position.x = -health_bar_width * (1.0 - ratio) * 0.5
	var material := health_fill.material_override as StandardMaterial3D
	if material != null:
		material.albedo_color = Color("7fae66") if ratio > 0.5 else (Color("c49a4f") if ratio > 0.25 else Color("b4553f"))

func _update_health_bar(delta: float) -> void:
	health_display_ratio = lerpf(health_display_ratio, hp / max_hp, minf(delta * 9.0, 1.0))
	_apply_health_ratio(health_display_ratio)
	# Face the whole bar at the camera so the fill can stay anchored to the
	# frame's left edge instead of shrinking from the centre.
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		health_bar_root.global_rotation = camera.global_rotation
	# Keep drawing until a heal animation reaches full, then fade out.
	health_bar_root.visible = hp < max_hp or game.target == self or health_display_ratio < 0.995

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
	_update_health_bar(delta)
	selected_ring.visible = game.target == self
	name_label.visible = game.target == self or kind != "normal" or aggro
	var to_player: Vector3 = game.player.global_position - global_position
	to_player.y = 0.0
	var distance: float = to_player.length()
	var detection: float = 7.0 if kind == "normal" else (8.0 if kind == "quest" else 12.0)
	var leash: float = 13.0 if kind != "boss" else 18.0
	var reach: float = _reach()
	var speed_value: float = 2.3 if kind == "normal" else (2.1 if kind == "quest" else 1.65)
	if game.is_dead:
		aggro = false
	elif distance < detection:
		aggro = true
	elif distance > leash:
		aggro = false
	if aggro and global_position.distance_to(home) > leash:
		aggro = false
	# The attack cooldown always ticks, so stepping into reach with an expired
	# timer attacks on the same frame instead of waiting for another branch.
	var attack_rate: float = 1.0
	if game.skill_runtime != null:
		attack_rate = maxf(0.1, 1.0 - game.skill_runtime.enemy_stat(self, "attack_speed"))
	attack_timer -= delta * attack_rate
	if aggro and not winding_up and not slam_active and attack_timer <= 0.0 and distance <= reach + 0.30:
		_begin_attack()
	if winding_up:
		attack_windup -= delta
		if attack_windup <= 0.0:
			_finish_attack()
	var direction := Vector3.ZERO
	var wants_move := false
	if aggro:
		if not winding_up and not slam_active and distance > reach:
			direction = to_player.normalized()
			wants_move = true
	elif global_position.distance_to(home) > 1.6:
		direction = (home - global_position).normalized()
		speed_value = 1.5
		wants_move = true
	else:
		direction = Vector3(sin(age * 0.27 + wander_offset), 0, cos(age * 0.31 + wander_offset)) * 0.25
		speed_value = 0.7
		if hp < max_hp:
			hp = minf(max_hp, hp + delta * 4.0)
	if wants_move:
		direction = _avoid_crowd(direction)
	# A mob wedged on a boulder or pinned by the player used to keep pushing into
	# the obstacle forever. After half a second without progress, sidestep.
	var moved: float = Vector2(global_position.x - last_position.x, global_position.z - last_position.z).length()
	if wants_move and moved < 0.02 and not winding_up:
		stuck_timer += delta
	else:
		stuck_timer = 0.0
	last_position = global_position
	if stuck_timer > 0.5 and sidestep_time <= 0.0 and direction.length_squared() > 0.01:
		stuck_timer = 0.0
		sidestep_time = 0.7
		var side := Vector3(-direction.z, 0.0, direction.x)
		sidestep_dir = side.normalized() if randf() < 0.5 else -side.normalized()
	if sidestep_time > 0.0:
		sidestep_time -= delta
		direction = (direction + sidestep_dir * 1.4).normalized()
		wants_move = true
	if kind == "boss":
		boss_timer -= delta
		# Only a boss that has actually engaged may slam. Without the aggro gate
		# the Regent announces and detonates its circle every seven seconds from
		# wherever it is spawned, even with the player across the map.
		if boss_timer <= 0.0 and aggro and not winding_up and not slam_active:
			_begin_slam()
	if game.skill_runtime != null:
		speed_value *= 1.0 - game.skill_runtime.enemy_stat(self, "movement_speed")
	if not wants_move:
		speed_value = 0.0
	velocity.x = direction.x * speed_value
	velocity.z = direction.z * speed_value
	if is_on_floor():
		velocity.y = -0.6
	else:
		velocity.y -= 26.0 * delta
	move_and_slide()
	if direction.length() > 0.05:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), delta * 7)
	elif aggro and to_player.length() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-to_player.x, -to_player.z), delta * 7)
	visual.animate(delta, Vector2(velocity.x, velocity.z).length())


func _reach() -> float:
	return 1.8 if kind == "normal" else (2.5 if kind == "quest" else 4.0)


## Mobs used to converge on the exact same point and stand inside each other.
func _avoid_crowd(direction: Vector3) -> Vector3:
	var push := Vector3.ZERO
	for other: CharacterBody3D in game.enemies:
		if other == self or not is_instance_valid(other) or other.dead:
			continue
		var offset: Vector3 = global_position - other.global_position
		offset.y = 0.0
		var gap: float = offset.length()
		if gap > 0.001 and gap < 1.5:
			push += offset.normalized() * (1.5 - gap)
	if push.length_squared() > 0.0001:
		direction = (direction + push * 1.2).normalized()
	return direction


## Every mob now commits to a short windup before the damage lands, so the player
## can read the swing and back out. The old code dealt damage on the frame the
## cooldown expired, which felt like a missing attack when the timer was already
## negative and the mob had drifted out of range.
func _begin_attack() -> void:
	winding_up = true
	attack_windup = 0.55 if kind == "normal" else (0.45 if kind == "quest" else 0.35)
	attack_timer = 1.7 if kind == "normal" else (2.0 if kind == "quest" else 2.3)
	visual.strike = 1.0


func _finish_attack() -> void:
	winding_up = false
	visual.strike = 1.0
	var to_player: Vector3 = game.player.global_position - global_position
	to_player.y = 0.0
	if to_player.length() <= _reach() + 0.55:
		game.damage_player((7.0 if kind == "normal" else (12.0 if kind == "quest" else 18.0)) * damage_scale, self)


func _begin_slam() -> void:
	slam_active = true
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
				game.damage_player(36.0 * damage_scale, self, "area")
		slam_active = false
		if is_instance_valid(telegraph):
			telegraph.queue_free()
	)

func take_damage(amount: float) -> void:
	if dead:
		return
	aggro = true
	hp = maxf(0, hp - amount)
	health_bar_root.visible = true
	game.floating_text(global_position + Vector3.UP * 1.6, str(roundi(amount)), Color("f1d7a2"))
	var tween := create_tween()
	tween.tween_property(visual, "scale", visual.scale * 1.05, 0.06)
	tween.tween_property(visual, "scale", Vector3.ONE * (1.0 if kind == "normal" else (1.35 if kind == "quest" else 2.45)), 0.12)
	if hp <= 0:
		dead = true
		collision_layer = 0
		game.enemy_defeated(self)
		name_label.hide()
		health_bar_root.hide()
		selected_ring.hide()
		if is_instance_valid(telegraph):
			telegraph.queue_free()
		var death_tween := create_tween()
		death_tween.tween_property(visual, "rotation:z", PI * 0.45, 0.3)
		death_tween.tween_property(self, "position:y", -2.0, 1.2).set_delay(1.0)
		death_tween.tween_callback(queue_free)
