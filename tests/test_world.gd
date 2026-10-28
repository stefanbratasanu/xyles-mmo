extends SceneTree

## Verifies the Map I world contract: five zones with distinct level bands,
## finite rolling terrain, the sealed waygate inside the hardest zone, a branched
## road network, the day/night cycle, the full-screen map, MMO chat channels, the
## runtime log, carved wading ponds and committed enemy attacks.
##
## Run:
##   .\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tests/test_world.gd

var game: Node
var world: Node3D

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1600, 900)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.test_mode = true
	await process_frame
	world = game.world
	assert(world != null, "world builder did not run")

	_test_zones()
	_test_terrain()
	_test_water()
	_test_waygate()
	_test_roads()
	_test_day_night()
	_test_map()
	_test_chat()
	_test_log()
	_test_enemy_ai()

	game.queue_free()
	await process_frame
	print("PASS: 5 zones, finite terrain, sanctum waygate, branched roads, day/night, map, chat, runtime log, enemy AI")
	quit()


func _test_zones() -> void:
	assert(world.zones.size() == 5, "expected 5 zones, got %d" % world.zones.size())
	var bands: Array[Vector2i] = []
	var names := {}
	for zone: Dictionary in world.zones:
		names[str(zone["name"])] = true
		assert(float(zone["radius"]) > 20.0, "%s is too small" % zone["name"])
		bands.append(Vector2i(int(zone["level_min"]), int(zone["level_max"])))
	# Every zone has a different level band; the starting zone is the lowest.
	bands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x)
	var expected: Array[Vector2i] = [Vector2i(1, 3), Vector2i(4, 6), Vector2i(7, 9), Vector2i(10, 12), Vector2i(13, 15)]
	assert(bands == expected, "level bands drifted: %s" % [bands])
	var start_zone: Dictionary = world.zone_at(Vector3(0.0, 0.0, 8.0))
	assert(str(start_zone["name"]) == "EMBERFALL VALE", "the central zone must be the starting zone")
	assert(int(start_zone["level_min"]) == 1)
	assert(names.size() == 5)
	# Zone blobs are uneven: at least two centres are closer than the sum of their
	# radii, and the boundaries are not circles.
	var boundary: PackedVector2Array = world.zone_boundary(world.zones[0], 64)
	assert(boundary.size() == 64, "zone boundary must be a closed blob")
	var min_distance: float = INF
	var max_distance: float = 0.0
	var center: Vector2 = world.zones[0]["center"]
	for point: Vector2 in boundary:
		var distance: float = point.distance_to(center)
		min_distance = minf(min_distance, distance)
		max_distance = maxf(max_distance, distance)
	assert(max_distance - min_distance > 1.5, "zone boundary is a perfect circle")


func _test_terrain() -> void:
	# The same height function drives visuals, collision and props, so it must be
	# finite everywhere including past the playable rim.
	for z_step in range(-96, 97, 8):
		for x_step in range(-96, 97, 8):
			var h: float = world.height_at(float(x_step), float(z_step))
			assert(is_finite(h), "height is not finite at (%d, %d)" % [x_step, z_step])
			assert(h > -40.0 and h < 60.0, "height %.1f out of range at (%d, %d)" % [h, x_step, z_step])
	# Rolling, not flat: the central 40 m must contain real elevation changes.
	var lowest: float = INF
	var highest: float = -INF
	for z_step in range(-40, 41, 4):
		for x_step in range(-40, 41, 4):
			var h: float = world.height_at(float(x_step), float(z_step))
			lowest = minf(lowest, h)
			highest = maxf(highest, h)
	# Gentle rolling forest: the first pass was deliberately flattened so it stops
	# reading as desert dunes, but the floor must still have real relief.
	assert(highest - lowest > 2.0, "terrain is too flat (range %.2f)" % (highest - lowest))
	assert(highest - lowest < 24.0, "terrain is too drastic for a forest (range %.2f)" % (highest - lowest))
	# The mountain rim is part of the same height field, not a ring of props.
	var rim_height: float = world.height_at(195.0, 0.0)
	assert(rim_height > 15.0, "the mountain rim did not rise (%.1f)" % rim_height)
	assert(world.height_at(0.0, 0.0) < rim_height, "the playable bowl must sit below the rim")
	# The world is at least twice the old 148 m width.
	assert(world.BOUNDS >= 140.0, "world bounds did not grow")
	# The painted map texture is generated from that same terrain grid.
	var texture: ImageTexture = world.map_texture(128)
	assert(texture != null, "the world map has no painted terrain texture")
	assert(texture.get_width() == 128, "map texture ignored the requested size")
	# The old separate cone mountains and silhouette pines must be gone.
	var crag_names: Array[String] = ["DistantCrag", "DistantSnow", "FarPine"]
	for child: Node in world.get_children():
		assert(not crag_names.has(str(child.name)), "mountain props must be part of the terrain")
	# Terrain collision exists so the player does not fall through.
	var has_collision: bool = false
	for child: Node in world.get_children():
		if child is StaticBody3D:
			has_collision = true
			break
	assert(has_collision, "world has no static collision body")
	assert(world.normal_spawns.size() >= 5, "expected at least one spawn per zone")
	for spawn: Vector3 in world.normal_spawns:
		var zone: Dictionary = world.zone_at(spawn)
		assert(not zone.is_empty(), "spawn outside every zone: %s" % spawn)
		assert(world.height_at(spawn.x, spawn.z) > -20.0)


func _test_water() -> void:
	# Ponds are carved bowls, not discs dropped on the terrain: the centre must be
	# deeper than the wading limit, the analytic shore must sit above the surface,
	# and the water mesh must carry that depth for the shader.
	var ponds: Array[Dictionary] = world.ponds()
	assert(ponds.size() == 3, "expected three fen ponds, got %d" % ponds.size())
	var water_meshes: int = 0
	for child: Node in world.get_children():
		if not (child is MeshInstance3D) or not str(child.name).begins_with("FenPool"):
			continue
		water_meshes += 1
		var arrays: Array = (child as MeshInstance3D).mesh.surface_get_arrays(0)
		assert(arrays[Mesh.ARRAY_COLOR] != null, "water mesh has no baked depth colours")
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var deepest: float = 0.0
		for colour: Color in colors:
			deepest = maxf(deepest, colour.r * 2.0)
		assert(deepest > 1.0, "water mesh depth colour never reaches the bowl bottom (%.2f)" % deepest)
	assert(water_meshes == ponds.size(), "one water mesh per pond expected (%d vs %d)" % [water_meshes, ponds.size()])
	for pond: Dictionary in ponds:
		var center: Vector2 = pond["center"]
		var level: float = float(pond["level"])
		var depth: float = float(pond["depth"])
		assert(depth > 0.8, "pond is too shallow to read as water")
		assert(absf(world.water_depth_at(center.x, center.y) - depth) < 0.12,
			"water_depth_at disagrees with the carved bowl")
		assert(world.water_depth_at(center.x, center.y) > game.player.WADE_MAX_DEPTH,
			"the middle of the pond must be deeper than the wading limit")
		# The shoreline is wavy, not a circle.
		var lowest: float = INF
		var highest: float = 0.0
		for index: int in range(24):
			var angle: float = TAU * float(index) / 24.0
			var shore: float = world._pond_shore_radius(pond, angle)
			lowest = minf(lowest, shore)
			highest = maxf(highest, shore)
		assert(highest - lowest > float(pond["radius"]) * 0.35, "pond shoreline is too circular")
		# The analytic bank is above the waterline all the way round, so the water
		# plane never pokes through the ground.
		for index: int in range(24):
			var angle: float = TAU * float(index) / 24.0
			var shore_point: Vector2 = center + Vector2(cos(angle), sin(angle)) * world._pond_shore_radius(pond, angle)
			assert(world.height_at(shore_point.x, shore_point.y) > level + 0.05,
				"pond bank dips below the waterline")
			assert(world.water_depth_at(shore_point.x, shore_point.y) < 0.05,
				"water leaks past the shoreline")
		# Check the *rendered* terrain mesh, not just the analytic field. A coarse
		# grid can interpolate a low triangle under the water rim even when the
		# formula says the bank is high, which is exactly what "water clips the
		# terrain" looked like.
		var surface: float = level + 0.02
		for index: int in range(24):
			var angle: float = TAU * float(index) / 24.0
			var shot: float = world._pond_shore_radius(pond, angle)
			for t: float in [0.75, 0.85]:
				var wet_point: Vector2 = center + Vector2(cos(angle), sin(angle)) * shot * t
				assert(_rendered_height(wet_point.x, wet_point.y) < surface,
					"terrain pokes through the pond at t=%.2f" % t)
			for t: float in [1.20, 1.30, 1.35]:
				var bank_point: Vector2 = center + Vector2(cos(angle), sin(angle)) * shot * t
				assert(_rendered_height(bank_point.x, bank_point.y) > surface + 0.004,
					"water rim is exposed at t=%.2f" % t)
		# There is a real wading shelf: the waist-deep line sits inside the shore by
		# at least a quarter of a metre, so stepping in is possible but shallow.
		var angle_zero: float = 0.0
		var shore_zero: float = world._pond_shore_radius(pond, angle_zero)
		var shoulder: Vector2 = center + Vector2(1.0, 0.0) * shore_zero * 0.60
		assert(world.water_depth_at(shoulder.x, shoulder.y) > game.player.WADE_MAX_DEPTH,
			"the inner wading shelf never reaches the waist limit")
	assert(game.player.WADE_MAX_DEPTH > 0.3 and game.player.WADE_MAX_DEPTH < 0.9,
		"wading limit should be waist height")


func _rendered_height(x: float, z: float) -> float:
	# Same bilinear split as `_create_terrain`: a(q00,q10,q01) and b(q10,q11,q01).
	var count: int = world._terrain_grid_size
	var step: float = (world.TERRAIN_EXTENT * 2.0) / float(world.TERRAIN_SEGMENTS)
	var fx: float = (x + world.TERRAIN_EXTENT) / step
	var fz: float = (z + world.TERRAIN_EXTENT) / step
	var ix: int = clampi(int(floor(fx)), 0, count - 2)
	var iz: int = clampi(int(floor(fz)), 0, count - 2)
	var u: float = clampf(fx - float(ix), 0.0, 1.0)
	var v: float = clampf(fz - float(iz), 0.0, 1.0)
	var h00: float = world._terrain_heights[iz * count + ix]
	var h10: float = world._terrain_heights[iz * count + ix + 1]
	var h01: float = world._terrain_heights[(iz + 1) * count + ix]
	var h11: float = world._terrain_heights[(iz + 1) * count + ix + 1]
	if u + v <= 1.0:
		return h00 + u * (h10 - h00) + v * (h01 - h00)
	return h10 * (1.0 - v) + h11 * (u + v - 1.0) + h01 * (1.0 - u)


func _test_waygate() -> void:
	var gate_zone: Dictionary = world.zone_at(world.waygate_position)
	assert(str(gate_zone["name"]) == "CROWNLESS SANCTUM", "waygate must sit in the hardest zone")
	assert(int(gate_zone["level_max"]) == 15)
	# The waygate is a small safe zone inside the sanctum, not a separate map.
	var distance: float = Vector2(world.waygate_position.x, world.waygate_position.z).distance_to(gate_zone["center"])
	assert(distance < float(gate_zone["radius"]), "waygate outside the sanctum blob")
	assert(world.waygate_radius >= 6.0 and world.waygate_radius <= 12.0)
	# Map II must not exist in the project.
	assert(not ResourceLoader.exists("res://scenes/map_2.tscn"), "Map II must not exist yet")
	assert(not ResourceLoader.exists("res://scenes/map2.tscn"), "Map II must not exist yet")


func _test_roads() -> void:
	assert(world.roads.size() >= 20, "expected a branched road network, got %d roads" % world.roads.size())
	var junctions: Dictionary = {}
	for road: PackedVector2Array in world.roads:
		assert(road.size() >= 2, "road with fewer than two points")
		for point: Vector2 in road:
			var key := "%.1f,%.1f" % [point.x, point.y]
			junctions[key] = int(junctions.get(key, 0)) + 1
	# A branch is a point shared by three or more road segments.
	var branches: int = 0
	for key: String in junctions.keys():
		if int(junctions[key]) >= 3:
			branches += 1
	assert(branches >= 3, "road network does not branch (junctions: %d)" % branches)
	# Roads must cover all five zones.
	for zone: Dictionary in world.zones:
		var center: Vector2 = zone["center"]
		var near: bool = false
		for road: PackedVector2Array in world.roads:
			for point: Vector2 in road:
				if point.distance_to(center) < float(zone["radius"]):
					near = true
					break
			if near:
				break
		assert(near, "%s has no road" % zone["name"])
	# Ponds exist only in the fen.
	assert(world.ponds().size() >= 2, "the fen needs water")
	for pond: Dictionary in world.ponds():
		var zone: Dictionary = world.zone_at_xz(pond["center"])
		assert(str(zone["name"]) == "ASHEN FEN", "pond outside the fen")


func _test_day_night() -> void:
	world.set_time_of_day(12.0)
	assert(world.phase_text() == "Day", "noon must be day")
	world.set_time_of_day(18.8)
	assert(world.phase_text() == "Dusk", "18:48 must be dusk")
	world.set_time_of_day(23.0)
	assert(world.phase_text() == "Night", "23:00 must be night")
	world.set_time_of_day(4.0)
	assert(world.phase_text() == "Night", "04:00 must be night")
	world.set_time_of_day(6.0)
	assert(world.phase_text() == "Dawn", "06:00 must be dawn")
	world.set_time_of_day(8.5)
	assert(world.phase_text() == "Day")
	assert(world.clock_text() == "08:30", "clock text drifted: %s" % world.clock_text())
	var before: float = float(world.time_of_day)
	world.advance_time(60.0)
	assert(float(world.time_of_day) > before, "advance_time did not move the clock")
	assert(world.DAY_SECONDS > 0.0)
	assert(world.day_number >= 1)
	# The sun must exist and cast soft shadows.
	var sun: DirectionalLight3D = null
	for child: Node in world.get_children():
		if child is DirectionalLight3D:
			sun = child
			break
	assert(sun != null, "world has no sun")
	assert(sun.shadow_enabled, "sunlight shadows must be enabled")
	assert(sun.light_angular_distance >= 1.0, "sunlight must be diffuse, not a hard point")
	world.set_time_of_day(8.25)


func _test_map() -> void:
	var hud: Node = game.hud
	assert(hud.world_map != null, "full-screen map missing")
	assert(not hud.world_map.visible, "map must start closed")
	assert(not hud.has_method("_build_navigation"), "the old minimap builder must be gone")
	hud.toggle_map()
	assert(hud.world_map.visible, "M did not open the map")
	assert(hud.is_panel_open(), "the open map must block gameplay input")
	hud.toggle_map()
	assert(not hud.world_map.visible, "M did not close the map")
	assert(not hud.is_panel_open())
	# The map must derive its bounds from the same zone data.
	for zone: Dictionary in world.zones:
		assert(world.zone_boundary(zone, 32).size() == 32)
	assert(not hud.hotbar.is_empty(), "the bare skill bar must still exist")
	assert(hud.hotbar.size() == 10)
	# Shift-click style guard: the hotbar is deliberately not a floating window.
	assert(not hud.floating_windows.has("shortcuts"), "the skill bar must not have a panel frame")


func _test_chat() -> void:
	var hud: Node = game.hud
	assert(hud.chat_messages.size() == 4, "chat needs World, Local, Party and Guild")
	for channel: String in ["World", "Local", "Party", "Guild"]:
		assert(hud.chat_messages.has(channel))
	hud._select_channel("Party")
	assert(hud.chat_channel == "Party")
	hud._append_chat_line("Party", "Tester", "regroup at the waygate")
	assert(hud.chat_messages["Party"].size() >= 1)
	assert(hud.chat_messages["Party"].back()["text"] == "regroup at the waygate")
	hud._select_channel("World")
	assert(hud.chat_channel == "World")
	# Chat input must block movement while typing.
	hud._on_chat_focus(true)
	assert(game.ui_text_input, "typing must block movement")
	hud._on_chat_focus(false)
	assert(not game.ui_text_input)


func _test_log() -> void:
	assert(game.game_log != null, "runtime log missing")
	var latest := "res://logs/LATEST.txt"
	assert(FileAccess.file_exists(latest), "logs/LATEST.txt was not written")
	var session := FileAccess.get_file_as_string(latest).get_slice("\n", 0).strip_edges()
	assert(session.begins_with("res://logs/session_"), "LATEST.txt does not point at a session")
	assert(FileAccess.file_exists(session), "the session file does not exist")
	var text := FileAccess.get_file_as_string(session)
	assert(text.contains("[BOOT]"), "session has no boot entry")
	assert(text.contains("[WORLD] world_ready"), "session has no world build entry")
	assert(text.contains("[COMBAT] enemy_spawned"), "session has no enemy spawn entry")


func _test_enemy_ai() -> void:
	# The old AI dealt damage on the cooldown frame and let mobs walk through
	# each other. Verify the two rules that are easy to regress: a mob in reach
	# commits to a windup and then lands the hit, and a distant boss never starts
	# its slam (which used to fire every seven seconds from anywhere on the map).
	var wolf = null
	var boss = null
	for candidate in game.enemies:
		if candidate.kind == "normal" and wolf == null:
			wolf = candidate
		elif candidate.kind == "boss" and boss == null:
			boss = candidate
	assert(wolf != null, "no normal enemy to test")
	assert(boss != null, "no boss to test")
	game.player.set_physics_process(false)
	# --- Wolf in reach: windup, then damage. ---
	wolf.global_position = game.player.global_position + Vector3(1.0, 0.0, 0.0)
	wolf.home = wolf.global_position
	wolf.aggro = true
	wolf.attack_timer = 0.0
	var hp_before: float = game.state.hp
	wolf._physics_process(0.02)
	assert(wolf.winding_up, "an in-reach wolf did not start its windup")
	assert(is_equal_approx(game.state.hp, hp_before), "wolf damaged on the windup frame")
	for step: int in range(60):
		wolf._physics_process(0.02)
	assert(game.state.hp < hp_before, "the committed wolf strike never landed")
	assert(not wolf.winding_up, "wolf never finished its windup")
	# --- Distant boss: no slam. ---
	boss.global_position = Vector3(-140.0, 0.0, -140.0)
	boss.home = boss.global_position
	boss.aggro = false
	boss.boss_timer = -1.0
	boss._physics_process(0.02)
	assert(not boss.slam_active, "a distant boss started a slam")
	assert(boss.telegraph == null, "a distant boss left a telegraph")
	# --- Engaged boss: slam. ---
	boss.global_position = game.player.global_position + Vector3(4.0, 0.0, 0.0)
	boss.home = boss.global_position
	boss.aggro = true
	boss.boss_timer = -1.0
	boss._physics_process(0.02)
	assert(boss.slam_active, "an engaged boss did not start its slam")
	assert(boss.telegraph != null, "the slam has no red telegraph")
