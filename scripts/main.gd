extends Node3D
## Local vertical slice. State, world art, actors and presentation are independent.

const StateScript = preload("res://scripts/game_state.gd")
const WorldScript = preload("res://scripts/world_builder.gd")
const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const HUDScript = preload("res://scripts/game_hud.gd")
const VisualScript = preload("res://scripts/actor_visual.gd")
const AudioScript = preload("res://scripts/audio_director.gd")
const SKILL_IDS := ["melee", "cast", "block", "move", "support"]
const BASE_COSTS := [4.0, 15.0, 12.0, 9.0, 24.0]
const SAVE_PATH := "res://saves/journey.json"
const SETTINGS_PATH := "res://saves/settings.cfg"

var state: Node
var world: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var camera: Camera3D
var camera_pivot: Node3D
var camera_arm: SpringArm3D
var audio: Node
var combat_effects: Node3D
var target: CharacterBody3D
var enemies: Array[CharacterBody3D] = []
var cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var max_cooldowns: Array[float] = [0.8, 3.0, 7.0, 4.0, 11.0]
var support_time: float = 0.0
var block_time: float = 0.0
var is_dead: bool = false
var camera_yaw: float = 0.25
var camera_pitch: float = 0.68
var camera_distance: float = 20.0
var camera_sensitivity: float = 0.0055
var camera_reverse_vertical: bool = true
var master_volume: float = 1.0
var camera_focus := Vector3.ZERO
var region_name: String = "EMBERFALL CAMP"
var context_hint: String = ""
var smith_position := Vector3(-17, 0, 14)
var gather_nodes: Array[Dictionary] = []
var ground_loot: Array[Dictionary] = []
var respawns: Array[Dictionary] = []
var boss_respawn: float = 0.0
var quest_spawned: bool = false
var hud_tick: float = 0.0
var autosave_tick: float = 0.0
var pending_skill: int = -1
var elapsed: float = 0.0
var arrow: Node3D
var last_failed_notice: float = -10.0
var test_mode: bool = false

func _ready() -> void:
	DisplayServer.window_set_title("XYLES  |  Ashen Frontier")
	state = get_node_or_null("GameState")
	if not is_instance_valid(state):
		state = StateScript.new()
		state.name = "GameState"
		add_child(state)
	test_mode = OS.get_cmdline_user_args().has("--test-mode")
	if not test_mode:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://saves"))
	_load_settings()
	if not test_mode and not OS.get_cmdline_user_args().has("--fresh"):
		state.load_game(SAVE_PATH)
	world = get_node_or_null("World") as Node3D
	if not is_instance_valid(world):
		world = WorldScript.new()
		world.name = "World"
		add_child(world)
		world.build()
	_load_scene_locations()
	player = get_node_or_null("Player") as CharacterBody3D
	if not is_instance_valid(player):
		player = PlayerScript.new()
		player.name = "Player"
		add_child(player)
	player.game = self
	player.position = world.player_spawn + Vector3(2, 0.1, 1.5)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	camera_pivot = get_node_or_null("CameraOrbit") as Node3D
	if not is_instance_valid(camera_pivot):
		camera_pivot = Node3D.new()
		camera_pivot.name = "CameraOrbit"
		add_child(camera_pivot)
	camera_arm = camera_pivot.get_node_or_null("CameraWallCollision") as SpringArm3D
	if not is_instance_valid(camera_arm):
		camera_arm = SpringArm3D.new()
		camera_arm.name = "CameraWallCollision"
		camera_arm.spring_length = camera_distance
		camera_arm.margin = 0.18
		camera_arm.collision_mask = 1
		var camera_shape := SphereShape3D.new()
		camera_shape.radius = 0.28
		camera_arm.shape = camera_shape
		camera_pivot.add_child(camera_arm)
	camera = camera_arm.get_node_or_null("Camera3D") as Camera3D
	if not is_instance_valid(camera):
		camera = Camera3D.new()
		camera.name = "Camera3D"
		camera.fov = 48.0
		camera.far = 220.0
		camera_arm.add_child(camera)
	camera.current = true
	camera_focus = player.position + Vector3.UP
	_update_camera(1.0)
	combat_effects = get_node_or_null("CombatEffects") as Node3D
	if not is_instance_valid(combat_effects):
		combat_effects = preload("res://scripts/combat_effects.gd").new()
		combat_effects.name = "CombatEffects"
		add_child(combat_effects)
	combat_effects.prepare(player.position)
	_build_smith()
	_build_resources()
	for spawn: Vector3 in world.normal_spawns:
		_spawn_enemy("normal", spawn)
	_spawn_enemy("boss", world.boss_spawn)
	hud = get_node_or_null("HUD") as CanvasLayer
	if not is_instance_valid(hud):
		hud = HUDScript.new()
		hud.name = "HUD"
		add_child(hud)
	hud.setup(self)
	state.notice.connect(_on_notice)
	state.changed.connect(_on_state_changed)
	audio = get_node_or_null("Audio")
	if not is_instance_valid(audio):
		audio = AudioScript.new()
		audio.name = "Audio"
		add_child(audio)
	audio.set_master_volume(master_volume)
	_on_state_changed()
	if bool(state.quests[0]["active"]):
		_on_notice("Welcome back, Wayfarer. Your journey has been restored.")
	else:
		_on_notice("Emberfall Camp · Speak with the blacksmith [E] to begin your journey.")
	get_tree().auto_accept_quit = false
	if OS.get_cmdline_user_args().has("--skills"):
		hud.toggle_panel("skills")

func _load_scene_locations() -> void:
	var spawn_root: Node3D = get_node_or_null("SpawnPoints") as Node3D
	if not is_instance_valid(spawn_root):
		return
	var player_marker: Marker3D = spawn_root.get_node_or_null("PlayerSpawn") as Marker3D
	if is_instance_valid(player_marker):
		world.player_spawn = player_marker.global_position
	var camp_marker: Marker3D = spawn_root.get_node_or_null("CampCenter") as Marker3D
	if is_instance_valid(camp_marker):
		world.camp_position = camp_marker.global_position
	var normal_markers: Node3D = spawn_root.get_node_or_null("NormalSpawns") as Node3D
	if is_instance_valid(normal_markers):
		world.normal_spawns.clear()
		for marker: Node in normal_markers.get_children():
			if marker is Node3D:
				world.normal_spawns.append((marker as Node3D).global_position)
	var quest_marker: Marker3D = spawn_root.get_node_or_null("QuestSpawn") as Marker3D
	if is_instance_valid(quest_marker):
		world.quest_spawn = quest_marker.global_position
	var boss_marker: Marker3D = spawn_root.get_node_or_null("BossSpawn") as Marker3D
	if is_instance_valid(boss_marker):
		world.boss_spawn = boss_marker.global_position
	var blacksmith: Node3D = get_node_or_null("Characters/Blacksmith") as Node3D
	if is_instance_valid(blacksmith):
		smith_position = blacksmith.global_position

func _process(delta: float) -> void:
	elapsed += delta
	if hud != null and hud.is_panel_open() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for index in range(5):
		cooldowns[index] = maxf(0.0, cooldowns[index] - delta)
	block_time = maxf(0, block_time - delta)
	support_time = maxf(0, support_time - delta)
	if not is_dead:
		var mods: Dictionary = state.get_equipment_modifiers()
		var at_camp: bool = player.global_position.distance_to(world.camp_position) < 7.0
		var in_combat: bool = _in_combat()
		state.mana = minf(state.max_mana + float(mods["max_mana"]), state.mana + delta * (3.0 if not in_combat else 1.5) * float(mods["mana_regen"]) * (2.3 if at_camp else 1.0))
		if not in_combat:
			state.hp = minf(state.max_hp + float(mods["max_hp"]), state.hp + delta * (8.0 if at_camp else 1.0))
		if support_time > 0:
			state.mana = minf(state.max_mana + float(mods["max_mana"]), state.mana + delta * 1.6)
		_process_pending_skill()
	_update_camera(delta)
	_process_respawns(delta)
	for gather: Dictionary in gather_nodes:
		gather["timer"] = maxf(0, float(gather["timer"]) - delta)
		gather["node"].visible = float(gather["timer"]) <= 0.0
	hud_tick += delta
	autosave_tick += delta
	if hud_tick >= 0.12:
		hud_tick = 0.0
		_update_region_and_context()
		hud.refresh()
	if autosave_tick >= 30.0 and not is_dead:
		autosave_tick = 0.0
		_save_journey()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed and not hud.is_panel_open() else Input.MOUSE_MODE_VISIBLE
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP and not hud.is_panel_open():
			camera_distance = maxf(4.0, camera_distance - 1.5)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and not hud.is_panel_open():
			camera_distance = minf(32.0, camera_distance + 1.5)
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not hud.is_panel_open() and not is_dead:
			_world_click(event.position)
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_yaw = wrapf(camera_yaw - event.screen_relative.x * camera_sensitivity, -PI, PI)
		var vertical_delta: float = event.screen_relative.y
		if not camera_reverse_vertical:
			vertical_delta = -vertical_delta
		camera_pitch = clampf(camera_pitch + vertical_delta * camera_sensitivity, -0.16, 1.28)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_5:
			if not hud.is_panel_open():
				use_skill(int(event.physical_keycode - KEY_1))
		elif event.physical_keycode == KEY_E and not hud.is_panel_open():
			interact()
		elif event.physical_keycode == KEY_TAB and not hud.is_panel_open():
			_cycle_target()
		elif event.physical_keycode == KEY_F5:
			_on_notice("Journey saved." if _save_journey() else "Could not save the journey.")
		elif event.physical_keycode == KEY_M:
			audio.toggle_mute()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(state):
			_save_journey()
		save_settings()
		get_tree().quit()

func _save_journey() -> bool:
	return true if test_mode else state.save_game(SAVE_PATH)

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	camera_reverse_vertical = bool(config.get_value("camera", "reverse_vertical", true))
	camera_sensitivity = clampf(float(config.get_value("camera", "sensitivity", camera_sensitivity)), 0.001, 0.015)
	master_volume = clampf(float(config.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("camera", "reverse_vertical", camera_reverse_vertical)
	config.set_value("camera", "sensitivity", camera_sensitivity)
	config.set_value("audio", "master_volume", master_volume)
	config.save(SETTINGS_PATH)

func reset_settings() -> void:
	camera_reverse_vertical = true
	camera_sensitivity = 0.0055
	master_volume = 1.0
	if is_instance_valid(audio):
		audio.set_master_volume(master_volume)
	save_settings()

func _update_camera(delta: float) -> void:
	camera_focus = camera_focus.lerp(player.global_position + Vector3.UP * 1.0, minf(delta * 7.0, 1.0))
	camera_pivot.global_position = camera_focus
	# The arm extends along local +Z; this keeps WASD aligned with the orbit heading.
	camera_pivot.rotation.y = camera_yaw
	camera_arm.rotation.x = -camera_pitch
	camera_arm.spring_length = camera_distance

func _world_click(screen_position: Vector2) -> void:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 200.0, 5)
	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return
	var collider: Object = result["collider"]
	if collider.has_method("take_damage") and not collider.dead:
		target = collider as CharacterBody3D
		pending_skill = -1
	else:
		player.destination = result["position"]
		player.moving_to_click = true
		pending_skill = -1
		_mark_destination(result["position"])

func _nearest_enemy(max_range: float = 22.0) -> CharacterBody3D:
	var nearest: CharacterBody3D = null
	var best := max_range
	for enemy in enemies:
		if not is_instance_valid(enemy) or enemy.dead:
			continue
		var distance := player.global_position.distance_to(enemy.global_position)
		if distance < best:
			nearest = enemy
			best = distance
	return nearest

func _cycle_target() -> void:
	var nearby: Array[CharacterBody3D] = []
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead and player.global_position.distance_to(enemy.global_position) < 24:
			nearby.append(enemy)
	nearby.sort_custom(func(a: CharacterBody3D, b: CharacterBody3D) -> bool: return player.position.distance_squared_to(a.position) < player.position.distance_squared_to(b.position))
	if nearby.is_empty():
		target = null
		return
	var index := nearby.find(target)
	target = nearby[(index + 1) % nearby.size()]
	hud.refresh()

func use_skill(index: int) -> void:
	if index < 0 or index > 4 or is_dead or cooldowns[index] > 0:
		return
	var effects: Dictionary = state.get_skill_effects(SKILL_IDS[index])
	var mods: Dictionary = state.get_equipment_modifiers()
	if index <= 1:
		if not is_instance_valid(target) or target.dead:
			target = _nearest_enemy(22.0)
		if not is_instance_valid(target):
			_fail_notice("No target nearby. Explore the old road east of camp.")
			return
		var reach: float = (3.1 if index == 0 else 22.0) * float(effects["range"])
		if target.kind == "boss" and index == 0:
			reach += 1.5
		if player.global_position.distance_to(target.global_position) > reach:
			pending_skill = index
			player.destination = target.global_position
			player.moving_to_click = true
			return
	var cost: float = BASE_COSTS[index] * float(effects["mana_cost"])
	if not state.spend_mana(cost):
		_fail_notice("Not enough mana. Rest at camp or let your mana recover.")
		return
	pending_skill = -1
	cooldowns[index] = max_cooldowns[index] * float(effects["cooldown"])
	var power: float = float(effects["power"])
	var equipment_power: float = state.get_equipment_power()
	var buff: float = 1.12 if support_time > 0 else 1.0
	match index:
		0:
			player.face_point(target.global_position)
			player.attack_animation()
			var damage: float = (16.0 + equipment_power * 0.35) * power * buff * float(mods["attack_multiplier"]) * float(mods["melee_multiplier"])
			burst(player.global_position + Vector3.UP * 0.15, Color("e4be78"), 2.2, 0.23)
			var struck := target
			struck.take_damage(damage)
			if int(state.skills["melee"]["ranks"][0]) > 0:
				for enemy in enemies:
					if is_instance_valid(enemy) and not enemy.dead and enemy != struck and player.global_position.distance_to(enemy.global_position) < 3.3:
						enemy.take_damage(damage * 0.45)
			audio.cue("melee")
		1:
			player.face_point(target.global_position)
			player.cast_animation()
			var damage: float = (28.0 + equipment_power * 0.5) * power * buff * float(mods["cast_multiplier"])
			_projectile(target, damage)
			audio.cue("cast")
		2:
			player.block_animation()
			block_time = 4.0 + (power - 1.0) * 3.0
			burst(player.global_position, Color("83b7bf"), 1.2, 0.5)
			floating_text(player.global_position + Vector3.UP * 2.0, "GUARD", Color("91c8cb"))
			audio.cue("block")
		3:
			player.dash()
			burst(player.global_position, Color("afd4c9"), 0.8, 0.3)
			audio.cue("move")
		4:
			player.support_animation()
			var healing: float = 38.0 * power * float(mods["support_multiplier"])
			state.hp = minf(state.max_hp + float(mods["max_hp"]), state.hp + healing)
			support_time = 10.0
			burst(player.global_position, Color("90c6a4"), 2.0, 0.8)
			floating_text(player.global_position + Vector3.UP * 2.0, "+%d" % int(healing), Color("b7dda0"))
			audio.cue("support")
	hud.refresh()

func _process_pending_skill() -> void:
	if pending_skill < 0:
		return
	if not is_instance_valid(target) or target.dead or hud.is_panel_open():
		pending_skill = -1
		return
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_D):
		pending_skill = -1
		return
	player.destination = target.global_position
	player.moving_to_click = true
	var reach: float = (3.0 if pending_skill == 0 else 21.0) * float(state.get_skill_effects(SKILL_IDS[pending_skill])["range"])
	if target.kind == "boss" and pending_skill == 0:
		reach += 1.5
	if player.global_position.distance_to(target.global_position) <= reach:
		player.moving_to_click = false
		var next := pending_skill
		pending_skill = -1
		use_skill(next)

func _projectile(enemy: CharacterBody3D, damage: float) -> void:
	var orb: MeshInstance3D = combat_effects.take_orb()
	orb.position = player.position + Vector3.UP * 1.2
	var hit_point := enemy.position + Vector3.UP * (1.0 if enemy.kind != "boss" else 2.3)
	var flame := orb.get_node_or_null("EmberTrail") as EffekseerEmitter3D
	if flame != null:
		var direction := (hit_point - orb.position).normalized()
		flame.rotation.y = atan2(direction.z, -direction.x)
		flame.play()
	var duration: float = clampf(orb.position.distance_to(hit_point) / 24.0, 0.15, 0.8)
	var tween := create_tween()
	tween.tween_property(orb, "position", hit_point, duration)
	tween.tween_callback(func():
		burst(orb.position - Vector3.UP * 0.5, Color("e3a76b"), 1.1, 0.35)
		if is_instance_valid(enemy) and not enemy.dead:
			enemy.take_damage(damage)
		combat_effects.release_orb(orb)
	)

func damage_player(amount: float, source: Node3D = null) -> void:
	if is_dead or player.invulnerable_time > 0:
		return
	var mods: Dictionary = state.get_equipment_modifiers()
	var mitigation: float = clampf(float(mods["armor"]), 0.0, 0.55)
	if block_time > 0:
		mitigation = minf(0.9, mitigation + 0.60 * float(mods["block_strength"]) * state.get_skill_bonus("block"))
	var taken: float = amount * (1.0 - mitigation)
	state.hp = maxf(0, state.hp - taken)
	floating_text(player.global_position + Vector3.UP * 1.8, "-%d" % roundi(taken), Color("e38e80"))
	if not is_instance_valid(target) and is_instance_valid(source):
		target = source as CharacterBody3D
	if state.hp <= 0:
		_player_died()

func _player_died() -> void:
	is_dead = true
	block_time = 0
	support_time = 0
	pending_skill = -1
	player.moving_to_click = false
	var result: Dictionary = state.apply_death()
	if not result["dropped"].is_empty():
		_drop_satchel(player.global_position, result["dropped"])
	player.death_animation()
	_on_notice("You have fallen. Equipment durability lost. Returning to Emberfall in 4 seconds.")
	audio.cue("death")
	await get_tree().create_timer(4.0).timeout
	player.position = world.player_spawn + Vector3(2, 0.2, 1)
	player.revive_animation()
	state.restore()
	player.invulnerable_time = 3.0
	is_dead = false
	target = null
	_on_notice("Reawakened at Emberfall. Repair at the forge [I]. Dropped gear remains where you fell.")
	_save_journey()

func _spawn_enemy(kind: String, at: Vector3) -> CharacterBody3D:
	var enemy := EnemyScript.new()
	enemy.game = self
	enemy.kind = kind
	enemy.display_name = "Briarwolf" if kind == "normal" else ("Oathbound Guardian" if kind == "quest" else "The Hollow Regent")
	enemy.home = at
	add_child(enemy)
	enemy.position = at + Vector3.UP * 0.15
	enemies.append(enemy)
	return enemy

func enemy_defeated(enemy: CharacterBody3D) -> void:
	state.register_kill(enemy.kind, enemy.display_name)
	audio.cue("reward")
	burst(enemy.global_position, Color("d3b87b"), 1.5)
	if target == enemy:
		target = null
	enemies.erase(enemy)
	if enemy.kind == "normal":
		respawns.append({"kind": "normal", "position": enemy.home, "timer": 28.0})
	elif enemy.kind == "boss":
		boss_respawn = 180.0
		respawns.append({"kind": "boss", "position": enemy.home, "timer": 180.0})
	_save_journey()

func _process_respawns(delta: float) -> void:
	boss_respawn = maxf(0, boss_respawn - delta)
	for index in range(respawns.size() - 1, -1, -1):
		respawns[index]["timer"] = float(respawns[index]["timer"]) - delta
		if float(respawns[index]["timer"]) <= 0:
			_spawn_enemy(str(respawns[index]["kind"]), respawns[index]["position"])
			respawns.remove_at(index)

func _on_state_changed() -> void:
	if is_instance_valid(player):
		player.update_equipment(state.equipment)
	if not quest_spawned and bool(state.quests[0]["active"]) and int(state.quests[0]["stage"]) == 2:
		quest_spawned = true
		_spawn_enemy("quest", world.quest_spawn)
		_on_notice("The broken arch stirs. The Oathbound Guardian has appeared to the northeast.")
	if is_instance_valid(hud):
		hud.refresh()

func _on_notice(message: String) -> void:
	if is_instance_valid(hud):
		hud.show_notice(message)

func _fail_notice(message: String) -> void:
	if elapsed - last_failed_notice > 2.5:
		last_failed_notice = elapsed
		_on_notice(message)

func _in_combat() -> bool:
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.aggro:
			return true
	return false

func _build_smith() -> void:
	var placed_smith: Node3D = get_node_or_null("Characters/Blacksmith") as Node3D
	if is_instance_valid(placed_smith):
		smith_position = placed_smith.global_position
		return
	var actor := VisualScript.new()
	actor.name = "Blacksmith"
	add_child(actor)
	actor.position = smith_position
	actor.rotation.y = -0.4
	actor.build_knight(Color("805c38"))
	_label_at("TORVEN  /  BLACKSMITH", smith_position + Vector3.UP * 2.5, Color("d6ba81"), 23)
	_label_at("[ E ]  TALK & FORGE", smith_position + Vector3.UP * 2.2, Color("b4bdad"), 17)

func _build_resources() -> void:
	var placed_deposits: Node3D = get_node_or_null("ResourceDeposits") as Node3D
	if is_instance_valid(placed_deposits) and not placed_deposits.get_children().is_empty():
		for deposit: Node in placed_deposits.get_children():
			if deposit is Node3D:
				gather_nodes.append({"type": str(deposit.get_meta("resource_type", "wood")), "node": deposit, "timer": 0.0})
		return
	for resource: Dictionary in [
		{"type": "wood", "position": Vector3(-8, 0, 10)},
		{"type": "iron", "position": Vector3(-3, 0, 16)},
		{"type": "wood", "position": Vector3(11, 0, 10)},
		{"type": "iron", "position": Vector3(21, 0, -4)},
		{"type": "wood", "position": Vector3(2, 0, -14)},
	]:
		var node := Node3D.new()
		add_child(node)
		node.position = resource["position"]
		var mesh := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.bottom_radius = 0.55
		cylinder.top_radius = 0.43 if resource["type"] == "wood" else 0.2
		cylinder.height = 0.8
		cylinder.radial_segments = 7
		mesh.mesh = cylinder
		mesh.position.y = 0.4
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color("76583b") if resource["type"] == "wood" else Color("6e8586")
		mat.metallic = 0.1 if resource["type"] == "wood" else 0.7
		mesh.material_override = mat
		node.add_child(mesh)
		var label := _label_at("FALLEN TIMBER" if resource["type"] == "wood" else "IRON DEPOSIT", Vector3.UP * 1.2, Color("adbca3"), 16, node)
		label.modulate.a = 0.85
		gather_nodes.append({"type": resource["type"], "node": node, "timer": 0.0})

func _drop_satchel(at: Vector3, items: Array) -> void:
	var node := Node3D.new()
	add_child(node)
	node.position = at
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.7, 0.45, 0.6)
	mesh.mesh = box
	mesh.position.y = 0.25
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("bc8e59")
	mat.emission_enabled = true
	mat.emission = Color("665023")
	mesh.material_override = mat
	node.add_child(mesh)
	_label_at("DROPPED EQUIPMENT [E]", Vector3.UP * 1.0, Color("e3c489"), 20, node)
	ground_loot.append({"node": node, "items": items})

func interact() -> void:
	if is_dead:
		return
	for index in range(ground_loot.size() - 1, -1, -1):
		var loot: Dictionary = ground_loot[index]
		if player.position.distance_to(loot["node"].position) < 3.0:
			for item: Dictionary in loot["items"]:
				state.inventory.append(item)
			loot["node"].queue_free()
			ground_loot.remove_at(index)
			state._notify("Dropped equipment recovered. Re-equip from your inventory [I].")
			state.changed.emit()
			return
	if player.position.distance_to(smith_position) < 5.5:
		if not bool(state.quests[0]["active"]):
			state.start_quest()
			state.restore()
		else:
			state.start_quest()
			hud.toggle_panel("forge")
		return
	for resource: Dictionary in gather_nodes:
		if float(resource["timer"]) <= 0 and player.position.distance_to(resource["node"].position) < 3.0:
			resource["timer"] = 60.0
			if resource["type"] == "wood":
				state.wood += 35
			else:
				state.iron += 35
			state._notify("Gathered 35 %s. This deposit replenishes in 60 seconds." % resource["type"])
			state.changed.emit()
			audio.cue("reward")
			return
	_fail_notice("Move closer to the blacksmith, a resource deposit, or dropped equipment.")

func _update_region_and_context() -> void:
	if player.position.distance_to(world.camp_position) < 10:
		region_name = "EMBERFALL CAMP"
	elif player.position.z < -15:
		region_name = "THE CROWNLESS SANCTUM"
	elif player.position.x > 10 and player.position.z < 0:
		region_name = "THE BROKEN ARCH"
	else:
		region_name = "THE OLD KING'S ROAD"
	context_hint = ""
	if player.position.distance_to(smith_position) < 5.5:
		context_hint = "[ E ]  Speak to Torven, the blacksmith"
	for resource: Dictionary in gather_nodes:
		if float(resource["timer"]) <= 0 and player.position.distance_to(resource["node"].position) < 3:
			context_hint = "[ E ]  Gather %s  +35" % resource["type"]
	for loot: Dictionary in ground_loot:
		if player.position.distance_to(loot["node"].position) < 3:
			context_hint = "[ E ]  Recover dropped equipment"
	if is_dead:
		context_hint = "YOU HAVE FALLEN  /  Returning to Emberfall..."
	hud.set_context(context_hint)

func _label_at(text_value: String, at: Vector3, color: Color, font_size: int = 22, parent: Node3D = self) -> Label3D:
	var label := Label3D.new()
	label.text = text_value
	label.font_size = font_size
	label.pixel_size = 0.008
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	label.outline_size = 4
	label.position = at
	parent.add_child(label)
	return label

func floating_text(at: Vector3, text_value: String, color: Color) -> void:
	combat_effects.floating_text(at, text_value, color)

func burst(at: Vector3, color: Color, radius: float = 1.0, duration: float = 0.55) -> void:
	combat_effects.burst(at, color, radius, duration)

func _mark_destination(at: Vector3) -> void:
	burst(at, Color("d6c18c"), 0.65, 0.7)



