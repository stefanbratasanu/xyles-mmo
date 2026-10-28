extends Node3D
## Local vertical slice. State, world art, actors and presentation are independent.

const StateScript = preload("res://scripts/game_state.gd")
const WorldScript = preload("res://scripts/world_builder.gd")
const PlayerScript = preload("res://scripts/player.gd")
const EnemyScript = preload("res://scripts/enemy.gd")
const HUDScript = preload("res://scripts/game_hud.gd")
const VisualScript = preload("res://scripts/actor_visual.gd")
const AudioScript = preload("res://scripts/audio_director.gd")
const GameLogScript = preload("res://scripts/game_log.gd")
const SAVE_PATH := "res://saves/journey.json"
const SETTINGS_PATH := "res://saves/settings.cfg"

var state: Node
var world: Node3D
var player: CharacterBody3D
var hud: CanvasLayer
var game_log: Node
var camera: Camera3D
var camera_pivot: Node3D
var camera_arm: SpringArm3D
var audio: Node
var combat_effects: Node3D
var target: CharacterBody3D
var enemies: Array[CharacterBody3D] = []
## Alternate wolves and boars along the normal spawn list so Map I always has
## both species without relying on random rolls.
var normal_spawn_index: int = 0
var cooldowns: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
var support_time: float = 0.0
var block_time: float = 0.0
var is_dead: bool = false
var debug_invulnerable: bool = false
var debug_time_paused: bool = false
var debug_keys: Dictionary = {"invulnerable": KEY_F2, "heal": KEY_F3, "spawn": KEY_F4}
var camera_yaw: float = 0.25
var camera_pitch: float = 0.68
var camera_distance: float = 20.0
var camera_sensitivity: float = 0.0055
var camera_reverse_vertical: bool = true
var master_volume: float = 1.0
## Graphics toggles from Settings. Persisted under [graphics] and applied to the
## WorldEnvironment live so the player sees the change before closing the menu.
var glow_enabled: bool = true
var ssao_enabled: bool = true
var camera_focus := Vector3.ZERO
var region_name: String = "EMBERFALL VALE"
var context_hint: String = ""
var smith_position := Vector3(-17, 0, 14)
var ui_text_input: bool = false
var last_zone_id: String = ""
var last_day_phase: String = ""
var in_safe_zone: bool = false
var gather_nodes: Array[Dictionary] = []
var ground_loot: Array[Dictionary] = []
var respawns: Array[Dictionary] = []
var boss_respawn: float = 0.0
var quest_spawned: bool = false
var hud_tick: float = 0.0
var autosave_tick: float = 0.0
var pending_skill: int = -1
var skill_runtime: Node
var elapsed: float = 0.0
var arrow: Node3D
var last_failed_notice: float = -10.0
var test_mode: bool = false
var screenshot_mode: bool = false

func _ready() -> void:
	DisplayServer.window_set_title("XYLES  |  Ashen Frontier")
	game_log = get_node_or_null("GameLog")
	if not is_instance_valid(game_log):
		game_log = GameLogScript.new()
		game_log.name = "GameLog"
		add_child(game_log)
	game_log.game = self
	state = get_node_or_null("GameState")
	if not is_instance_valid(state):
		state = StateScript.new()
		state.name = "GameState"
		add_child(state)
	test_mode = OS.get_cmdline_user_args().has("--test-mode")
	screenshot_mode = OS.get_cmdline_user_args().has("--screenshot")
	if not test_mode:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://saves"))
	_load_settings()
	if not test_mode and not OS.get_cmdline_user_args().has("--fresh"):
		state.load_game(SAVE_PATH)
	game_log.boot_ready({"test_mode": test_mode, "level": int(state.level), "save_loaded": not test_mode})
	var world_started := Time.get_ticks_msec()
	world = get_node_or_null("World") as Node3D
	if not is_instance_valid(world):
		world = WorldScript.new()
		world.name = "World"
		add_child(world)
	if world.get_child_count() == 0:
		world.build()
	if world.has_method("apply_graphics_settings"):
		world.apply_graphics_settings(glow_enabled, ssao_enabled)
	game_log.world("world_ready", {
		"build_ms": Time.get_ticks_msec() - world_started,
		"children": world.get_child_count(),
		"zones": world.zones.size() if world.get("zones") != null else -1,
	})
	smith_position = world.smith_position
	player = get_node_or_null("Player") as CharacterBody3D
	if not is_instance_valid(player):
		player = PlayerScript.new()
		player.name = "Player"
		add_child(player)
	player.game = self
	var spawn_at: Vector3 = world.player_spawn + Vector3(0.4, 0.0, 0.6)
	player.position = Vector3(spawn_at.x, world.height_at(spawn_at.x, spawn_at.z) + 0.15, spawn_at.z)
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
		camera.far = 420.0
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
	skill_runtime = preload("res://scripts/skills/skill_runtime.gd").new()
	add_child(skill_runtime)
	skill_runtime.setup(self)
	cooldowns.resize(10)
	cooldowns.fill(0.0)
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
	game_log.ui("hud_ready", {"panels": ["status", "quest", "menu", "chat", "map", "hotbar"]})
	state.notice.connect(_on_notice)
	state.changed.connect(_on_state_changed)
	audio = get_node_or_null("Audio")
	if not is_instance_valid(audio):
		audio = AudioScript.new()
		audio.name = "Audio"
		add_child(audio)
	audio.set_master_volume(master_volume)
	_on_state_changed()
	# Toasts and zone banners would cover the subject in the scripted visual tour.
	if not screenshot_mode:
		if bool(state.quests[0]["active"]):
			_on_notice("Welcome back, Wayfarer. Your journey has been restored.")
		else:
			_on_notice("Emberfall Camp · Speak with the blacksmith [E] to begin your journey.")
	get_tree().auto_accept_quit = false
	if OS.get_cmdline_user_args().has("--skills"):
		hud.toggle_panel("skills")
	if screenshot_mode:
		_run_screenshot_tour.call_deferred()


## A scripted visual pass for development: it teleports to every landmark, waits
## for the frame to settle, writes a PNG into res://screenshots and quits.
## Run windowed with:  .\Godot_v4.7.2-stable_win64.exe --path . -- --screenshot
func _run_screenshot_tour() -> void:
	await get_tree().create_timer(1.8).timeout
	var shots: Array[Dictionary] = [
		{"name": "01_camp", "at": Vector3(-36.0, 0.0, 34.0), "yaw": 0.0, "pitch": 0.44, "distance": 10.0},
		{"name": "02_vale_road", "at": Vector3(0.0, 0.0, 12.0), "yaw": 0.9, "pitch": 0.68, "distance": 36.0},
		{"name": "03_thornwood", "at": Vector3(-76.9, 0.0, 19.1), "yaw": 0.97, "pitch": 0.30, "distance": 16.0},
		{"name": "04_ashen_fen", "at": Vector3(88.0, 0.0, 16.0), "yaw": 1.6, "pitch": 0.34, "distance": 22.0},
		{"name": "11_pond", "at": Vector3(60.9, 0.0, 15.5), "yaw": 2.88, "pitch": 0.65, "distance": 16.0},
		{"name": "05_broken_arch", "at": Vector3(72.0, 0.0, -68.0), "yaw": 0.12, "pitch": 0.36, "distance": 20.0},
		{"name": "06_sanctum", "at": Vector3(-52.0, 0.0, -84.0), "yaw": 0.08, "pitch": 0.40, "distance": 16.0},
		{"name": "07_waygate", "at": Vector3(-104.0, 0.0, -114.0), "yaw": 0.45, "pitch": 0.36, "distance": 24.0},
		{"name": "10_frontier", "at": Vector3(0.0, 0.0, 62.0), "yaw": PI, "pitch": 0.60, "distance": 78.0},
	]
	for shot: Dictionary in shots:
		var at: Vector3 = shot["at"]
		player.position = Vector3(at.x, world.height_at(at.x, at.z) + 0.4, at.z)
		player.velocity = Vector3.ZERO
		camera_yaw = float(shot["yaw"])
		camera_pitch = float(shot["pitch"])
		camera_distance = float(shot["distance"])
		camera_focus = player.global_position + Vector3.UP
		_update_camera(1.0)
		await get_tree().create_timer(0.9).timeout
		await _capture_frame(str(shot["name"]))
	# The full-screen map is generated from the same zone, road and landmark data
	# as the terrain, so this shot doubles as a data-consistency check.
	hud.toggle_map()
	await get_tree().create_timer(0.9).timeout
	await _capture_frame("09_world_map")
	hud.toggle_map()
	await get_tree().create_timer(0.4).timeout
	world.set_time_of_day(22.0)
	player.position = Vector3(-36.0, world.height_at(-36.0, 34.0) + 0.4, 34.0)
	camera_focus = player.global_position + Vector3.UP
	camera_yaw = 0.0
	camera_pitch = 0.44
	camera_distance = 10.0
	_update_camera(1.0)
	await get_tree().create_timer(1.2).timeout
	await _capture_frame("08_camp_night")
	game_log.close_session("screenshot_tour")
	get_tree().quit()


func _capture_frame(label: String) -> void:
	var directory := ProjectSettings.globalize_path("res://screenshots")
	DirAccess.make_dir_recursive_absolute(directory)
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path := "res://screenshots/%s.png" % label
	var result: int = image.save_png(path)
	game_log.gameplay("screenshot", {"path": path, "ok": result == OK})
	print("[Screenshot] ", ProjectSettings.globalize_path(path))

func _process(delta: float) -> void:
	elapsed += delta
	if is_instance_valid(world) and not debug_time_paused:
		world.advance_time(delta)
	if hud != null and hud.blocks_gameplay() and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for index in range(10):
		cooldowns[index] = float(skill_runtime.skill_cooldowns.get(state.loadout[index], 0))
	block_time = maxf(0, block_time - delta)
	support_time = maxf(0, support_time - delta)
	if not is_dead:
		var mods: Dictionary = state.get_equipment_modifiers()
		in_safe_zone = player.global_position.distance_to(world.camp_position) < 9.0 or player.global_position.distance_to(world.waygate_position) < 9.5
		var in_combat: bool = _in_combat()
		state.mana = minf(state.max_mana + float(mods["max_mana"]), state.mana + delta * (3.0 if not in_combat else 1.5) * float(mods["mana_regen"]) * (2.3 if in_safe_zone else 1.0))
		if not in_combat:
			state.hp = minf(state.max_hp + float(mods["max_hp"]), state.hp + delta * (8.0 if in_safe_zone else 1.0))
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
	if event is InputEventKey and not event.pressed and skill_runtime != null and skill_runtime.channel_slot >= 0:
		var released_slot: int = 9 if event.physical_keycode == KEY_0 else int(event.physical_keycode - KEY_1)
		if released_slot == skill_runtime.channel_slot: skill_runtime.stop_channel()
	if ui_text_input:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if event.pressed and not hud.blocks_gameplay() else Input.MOUSE_MODE_VISIBLE
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP and not hud.blocks_gameplay():
			camera_distance = maxf(4.0, camera_distance - 1.5)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN and not hud.blocks_gameplay():
			camera_distance = minf(32.0, camera_distance + 1.5)
		elif event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not hud.blocks_gameplay() and not is_dead:
			_world_click(event.position)
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		camera_yaw = wrapf(camera_yaw - event.screen_relative.x * camera_sensitivity, -PI, PI)
		var vertical_delta: float = event.screen_relative.y
		if not camera_reverse_vertical:
			vertical_delta = -vertical_delta
		camera_pitch = clampf(camera_pitch + vertical_delta * camera_sensitivity, -0.16, 1.28)
	elif event is InputEventKey and event.pressed and not event.echo:
		if not hud.blocks_gameplay() and not event.ctrl_pressed and not event.alt_pressed and not event.shift_pressed and not event.meta_pressed and _handle_debug_shortcut(event.physical_keycode):
			get_viewport().set_input_as_handled()
			return
		if event.physical_keycode == KEY_X and not hud.blocks_gameplay() and not is_dead:
			skill_runtime.stop_channel()
			player.toggle_sit()
		elif event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9:
			if not hud.blocks_gameplay():
				use_skill(int(event.physical_keycode - KEY_1))
		elif event.physical_keycode == KEY_0 and not hud.blocks_gameplay():
			use_skill(9)
		elif event.physical_keycode == KEY_E and not hud.blocks_gameplay():
			interact()
		elif event.physical_keycode == KEY_TAB and not hud.blocks_gameplay():
			_cycle_target()
		elif event.physical_keycode == KEY_F5:
			_on_notice("Journey saved." if _save_journey() else "Could not save the journey.")
			game_log.state("manual_save", {"ok": not test_mode})
		elif event.physical_keycode == KEY_F9:
			game_log.open_log_folder()
			_on_notice("Opened the runtime log folder.")
		elif event.physical_keycode == KEY_F10:
			game_log.marker("tester_marker", game_log.snapshot_of(self))
			_on_notice("Bug marker written to the runtime log.")
		elif event.physical_keycode == KEY_F12:
			_capture_frame("manual_%s" % Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_"))
			_on_notice("Screenshot saved to the screenshots folder.")
		elif event.physical_keycode == KEY_F8:
			audio.toggle_mute()
			game_log.ui("audio_mute", {"muted": bool(audio.get("muted"))})

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if is_instance_valid(state):
			_save_journey()
		save_settings()
		if is_instance_valid(game_log):
			game_log.close_session("window_close")
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
	glow_enabled = bool(config.get_value("graphics", "glow", glow_enabled))
	ssao_enabled = bool(config.get_value("graphics", "ambient_occlusion", ssao_enabled))
	_load_debug_keys(config)

func _load_debug_keys(config: ConfigFile) -> void:
	var saved_keys: Dictionary = debug_keys.duplicate()
	for action: String in saved_keys:
		saved_keys[action] = int(config.get_value("debug_keys", action, saved_keys[action]))
	var used: Array = []
	for action: String in saved_keys:
		var key: int = saved_keys[action]
		if not _debug_key_available(key) or used.has(key):
			return
		used.append(key)
	debug_keys = saved_keys

func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("camera", "reverse_vertical", camera_reverse_vertical)
	config.set_value("camera", "sensitivity", camera_sensitivity)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("graphics", "glow", glow_enabled)
	config.set_value("graphics", "ambient_occlusion", ssao_enabled)
	for action: String in debug_keys:
		config.set_value("debug_keys", action, debug_keys[action])
	config.save(SETTINGS_PATH)

func _debug_key_available(key: int) -> bool:
	if key == KEY_NONE or (key >= KEY_0 and key <= KEY_9): return false
	return key not in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_X, KEY_E, KEY_TAB, KEY_K, KEY_B, KEY_I, KEY_C, KEY_H, KEY_O, KEY_M, KEY_F5, KEY_F6, KEY_F8, KEY_F9, KEY_F10, KEY_F12, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE, KEY_SPACE, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]

func set_debug_key(action: String, key: int) -> bool:
	if not debug_keys.has(action) or not _debug_key_available(key): return false
	for other: String in debug_keys:
		if other != action and int(debug_keys[other]) == key: return false
	debug_keys[action] = key
	if not test_mode: save_settings()
	game_log.ui("debug_shortcut_changed", {"action": action, "key": OS.get_keycode_string(key)})
	return true

func _handle_debug_shortcut(key: int) -> bool:
	if key == int(debug_keys["invulnerable"]):
		debug_set_invulnerable(not debug_invulnerable)
		hud.show_notice("Invulnerability %s." % ("enabled" if debug_invulnerable else "disabled"))
		hud.refresh()
	elif key == int(debug_keys["heal"]):
		debug_restore_vitals()
		hud.show_notice("Health and mana restored." if not is_dead else "Cannot restore vitals while dead.")
	elif key == int(debug_keys["spawn"]):
		hud._spawn_minions()
	else:
		return false
	return true

func reset_settings() -> void:
	camera_reverse_vertical = true
	camera_sensitivity = 0.0055
	master_volume = 1.0
	glow_enabled = true
	ssao_enabled = true
	if is_instance_valid(audio):
		audio.set_master_volume(master_volume)
	_apply_graphics_settings()
	save_settings()


func _apply_graphics_settings() -> void:
	if is_instance_valid(world) and world.has_method("apply_graphics_settings"):
		world.apply_graphics_settings(glow_enabled, ssao_enabled)


func set_glow_enabled(enabled: bool) -> void:
	glow_enabled = enabled
	_apply_graphics_settings()
	save_settings()
	game_log.ui("graphics_option", {"option": "glow", "enabled": enabled})


func set_ssao_enabled(enabled: bool) -> void:
	ssao_enabled = enabled
	_apply_graphics_settings()
	save_settings()
	game_log.ui("graphics_option", {"option": "ambient_occlusion", "enabled": enabled})


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
	if skill_runtime != null:
		if skill_runtime.cast_slot(index):
			game_log.combat("skill_used", {"skill": str(state.loadout[index]), "mana_after": snappedf(float(state.mana), 0.1), "player_hp": snappedf(float(state.hp), 0.1)})
		hud.refresh()

func _process_pending_skill() -> void:
	pass


func damage_player(amount: float, source: Node3D = null, delivery: String = "melee") -> void:
	if is_dead: return
	if debug_invulnerable: return
	if player.invulnerable_time > 0:
		skill_runtime.incoming(0, source, delivery, false, true)
		return
	if is_instance_valid(source): amount *= 1.0 - skill_runtime.enemy_stat(source, "outgoing_damage")
	var mods: Dictionary = state.get_equipment_modifiers()
	var mitigation: float = clampf(float(mods["armor"]), 0.0, 0.55)
	if block_time > 0:
		mitigation = minf(0.9, mitigation + 0.60 * float(mods["block_strength"]) * state.get_skill_bonus("block"))
	var taken: float = skill_runtime.incoming(amount * (1.0 - mitigation), source, delivery, block_time > 0)
	state.hp = maxf(0, state.hp - taken)
	game_log.combat("player_damaged", {
		"source": str(source.display_name) if is_instance_valid(source) and source.get("display_name") != null else "world",
		"raw": snappedf(amount, 0.1), "taken": snappedf(taken, 0.1),
		"mitigation": snappedf(mitigation, 0.01), "hp": snappedf(float(state.hp), 0.1),
	})
	if state.hp > 0: skill_runtime.after_incoming(amount * (1.0 - mitigation), source, delivery, block_time > 0)
	floating_text(player.global_position + Vector3.UP * 1.8, "-%d" % roundi(taken), Color("e38e80"))
	if not is_instance_valid(target) and is_instance_valid(source):
		target = source as CharacterBody3D
	if state.hp <= 0:
		_player_died()

func debug_restore_vitals() -> void:
	if is_dead:
		return
	var mods: Dictionary = state.get_equipment_modifiers()
	state.hp = state.max_hp + float(mods.get("max_hp", 0.0))
	state.mana = state.max_mana + float(mods.get("max_mana", 0.0))
	state.changed.emit()
	game_log.gameplay("debug_restore_vitals", {})

func debug_clear_cooldowns() -> void:
	if not skill_runtime.channel_id.is_empty():
		skill_runtime.stop_channel()
	skill_runtime.skill_cooldowns.clear()
	cooldowns.fill(0.0)
	game_log.gameplay("debug_clear_cooldowns", {})

func debug_set_invulnerable(enabled: bool) -> void:
	debug_invulnerable = enabled
	game_log.gameplay("debug_invulnerability", {"enabled": enabled})

func debug_set_time_paused(enabled: bool) -> void:
	debug_time_paused = enabled
	game_log.world("debug_time_paused", {"enabled": enabled})

func debug_set_time(hours: float) -> void:
	world.set_time_of_day(hours)
	game_log.world("debug_set_time", {"clock": world.clock_text()})

func _player_died() -> void:
	is_dead = true
	skill_runtime._react("ON_DEATH", null)
	skill_runtime.clear_combat()
	block_time = 0
	support_time = 0
	pending_skill = -1
	player.moving_to_click = false
	var result: Dictionary = state.apply_death()
	game_log.combat("player_died", {"position": game_log.snapshot_of(self).get("player_pos", "?"), "dropped": result["dropped"].size()})
	if not result["dropped"].is_empty():
		_drop_satchel(player.global_position, result["dropped"])
	player.death_animation()
	_on_notice("You have fallen. Equipment durability lost. Returning to Emberfall in 4 seconds.")
	audio.cue("death")
	await get_tree().create_timer(4.0).timeout
	player.position = world.player_spawn + Vector3(0.4, 0.2, 0.6)
	player.revive_animation()
	state.restore()
	player.invulnerable_time = 3.0
	is_dead = false
	target = null
	_on_notice("Reawakened at Emberfall. Repair at the forge [I]. Dropped gear remains where you fell.")
	_save_journey()

func _spawn_enemy(kind: String, at: Vector3, training_level: int = 0, species: String = "") -> CharacterBody3D:
	var enemy := EnemyScript.new()
	enemy.game = self
	enemy.kind = kind
	if kind == "normal":
		if species.is_empty():
			species = "boar" if normal_spawn_index % 2 == 1 else "wolf"
			normal_spawn_index += 1
		enemy.species = species
		enemy.display_name = "Ridge Boar" if species == "boar" else "Briarwolf"
	else:
		enemy.species = "guardian"
		enemy.display_name = "Oathbound Guardian" if kind == "quest" else "The Hollow Regent"
	enemy.home = at
	var zone: Dictionary = world.zone_at(at)
	var scaling_zone := zone.duplicate()
	if training_level > 0:
		scaling_zone["level_min"] = training_level
		scaling_zone["level_max"] = training_level
		enemy.set_meta("training_minion", true)
		enemy.display_name = "Training Briarwolf"
		enemy.species = "wolf"
	enemy.configure_zone(scaling_zone)
	add_child(enemy)
	enemy.position = at + Vector3.UP * 0.15
	enemies.append(enemy)
	game_log.combat("enemy_spawned", {
		"kind": kind, "name": enemy.display_name, "level": enemy.level,
		"zone": zone.get("name", "?"), "at": "(%.1f, %.1f, %.1f)" % [at.x, at.y, at.z],
	})
	return enemy

func training_minion_count() -> int:
	var count := 0
	for enemy in enemies:
		if is_instance_valid(enemy) and not enemy.dead and enemy.has_meta("training_minion"):
			count += 1
	return count

func spawn_training_minions(count: int, level: int) -> int:
	var amount := mini(clampi(count, 1, 30), maxi(0, 50 - training_minion_count()))
	for i in range(amount):
		var angle := TAU * float(i) / float(amount)
		var radius := 6.0 + 1.5 * float(floori(float(i) / 12.0))
		var at: Vector3 = player.global_position + Vector3(cos(angle), 0, sin(angle)) * radius
		at.x = clampf(at.x, -world.BOUNDS + 1.0, world.BOUNDS - 1.0)
		at.z = clampf(at.z, -world.BOUNDS + 1.0, world.BOUNDS - 1.0)
		at.y = world.height_at(at.x, at.z)
		_spawn_enemy("normal", at, clampi(level, 1, 100), "wolf")
	game_log.gameplay("training_minions_spawned", {"count": amount, "level": clampi(level, 1, 100)})
	return amount

func clear_training_minions() -> void:
	var removed := 0
	for enemy in enemies.duplicate():
		if is_instance_valid(enemy) and enemy.has_meta("training_minion"):
			if target == enemy:
				target = null
			enemies.erase(enemy)
			enemy.queue_free()
			removed += 1
	game_log.gameplay("training_minions_cleared", {"count": removed})

func enemy_defeated(enemy: CharacterBody3D) -> void:
	if enemy.has_meta("training_minion"):
		game_log.combat("training_minion_defeated", {"level": enemy.level})
		if target == enemy:
			target = null
		enemies.erase(enemy)
		return
	state.register_kill(enemy.kind, enemy.display_name)
	game_log.combat("enemy_defeated", {"kind": enemy.kind, "name": enemy.display_name, "player_level": int(state.level)})
	audio.cue("reward")
	burst(enemy.global_position, Color("d3b87b"), 1.5)
	if target == enemy:
		target = null
	enemies.erase(enemy)
	if enemy.kind == "normal":
		respawns.append({"kind": "normal", "position": enemy.home, "timer": 28.0, "species": enemy.species})
	elif enemy.kind == "boss":
		boss_respawn = 180.0
		respawns.append({"kind": "boss", "position": enemy.home, "timer": 180.0})
	_save_journey()

func _process_respawns(delta: float) -> void:
	boss_respawn = maxf(0, boss_respawn - delta)
	for index in range(respawns.size() - 1, -1, -1):
		respawns[index]["timer"] = float(respawns[index]["timer"]) - delta
		if float(respawns[index]["timer"]) <= 0:
			_spawn_enemy(str(respawns[index]["kind"]), respawns[index]["position"], 0, str(respawns[index].get("species", "")))
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
	if is_instance_valid(game_log):
		game_log.gameplay("notice", {"message": message})

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
		{"type": "wood", "position": Vector3(-16, 0, 20)},
		{"type": "iron", "position": Vector3(-6, 0, 32)},
		{"type": "wood", "position": Vector3(22, 0, 20)},
		{"type": "iron", "position": Vector3(42, 0, -8)},
		{"type": "wood", "position": Vector3(4, 0, -28)},
		{"type": "wood", "position": Vector3(-76, 0, 8)},
		{"type": "iron", "position": Vector3(-100, 0, -32)},
		{"type": "wood", "position": Vector3(80, 0, 32)},
		{"type": "iron", "position": Vector3(60, 0, -60)},
		{"type": "iron", "position": Vector3(-72, 0, -80)},
	]:
		var node := Node3D.new()
		add_child(node)
		var at: Vector3 = resource["position"]
		node.position = Vector3(at.x, world.height_at(at.x, at.z) + 0.05, at.z)
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
	if player.position.distance_to(world.waygate_position) < 10.0:
		game_log.gameplay("waygate_examined", {"sealed": true, "target": "map_ii"})
		_on_notice("The waygate is sealed. Beyond it lies Map II, which has not been built yet.")
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
			game_log.gameplay("loot_recovered", {"items": loot["items"].size()})
			return
	if player.position.distance_to(smith_position) < 5.5:
		game_log.gameplay("blacksmith_interacted", {"quest_active": bool(state.quests[0]["active"]), "stage": int(state.quests[0]["stage"])})
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
			game_log.gameplay("resource_gathered", {"type": resource["type"], "amount": 35, "wood": state.wood, "iron": state.iron})
			return
	_fail_notice("Move closer to the blacksmith, a resource deposit, or dropped equipment.")

func _update_region_and_context() -> void:
	var zone: Dictionary = world.zone_at(player.global_position)
	var zone_id: String = str(zone.get("id", ""))
	if zone_id != last_zone_id:
		last_zone_id = zone_id
		game_log.world("zone_entered", {
			"zone": zone.get("name", "?"), "levels": world.zone_level_text(zone),
			"position": game_log.snapshot_of(self).get("player_pos", "?"),
		})
		if elapsed > 3.0 and not screenshot_mode:
			_on_notice("%s   ·   %s" % [zone.get("name", ""), world.zone_level_text(zone)])
	var phase: String = world.phase_text()
	if phase != last_day_phase:
		last_day_phase = phase
		game_log.world("day_phase", {"phase": phase, "clock": world.clock_text(), "day": world.day_number})
	var near_camp: bool = player.global_position.distance_to(world.camp_position) < 9.5
	region_name = "EMBERFALL CAMP" if near_camp else str(zone.get("name", "ASHEN FRONTIER"))
	context_hint = ""
	if player.position.distance_to(world.waygate_position) < 10.0:
		context_hint = "[ E ]  Examine the sealed waygate  ·  safe ground"
	elif player.position.distance_to(smith_position) < 5.5:
		context_hint = "[ E ]  Speak to Torven, the blacksmith"
	else:
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



