extends SceneTree

## Verifies the Map I world contract: five zones with distinct level bands,
## finite rolling terrain, the sealed waygate inside the hardest zone, a branched
## road network, the day/night cycle, the full-screen map, MMO chat channels, the
## runtime log, carved wading ponds, forest families and committed enemy attacks.
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
	_test_forest_families()
	_test_tree_spacing()
	_test_terrain()
	_test_water()
	_test_waygate()
	_test_roads()
	_test_day_night()
	_test_map()
	_test_chat()
	_test_log()
	_test_enemy_ai()
	_test_creatures()
	_test_road_lamps()
	_test_frontier_landmarks()
	_test_ground_cover()
	_test_camp()
	_test_sky()

	game.queue_free()
	await process_frame
	print("PASS: 5 zones, forest families, finite terrain, sanctum waygate, branched roads, day/night, map, chat, runtime log, committed enemy attacks, modelled creatures, road lamps, ground cover, camp, moving sky, glow and ambient occlusion")
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
	for i in range(world.zones.size()):
		for j in range(i + 1, world.zones.size()):
			assert((world.zones[i]["center"] as Vector2).distance_to(world.zones[j]["center"]) >= 100.0,
				"difficulty zones should be spread across the larger map")
	assert(str(world.zone_at(world.quest_spawn)["id"]) == "arch", "the quest guardian must be in the Broken Arch")
	assert(str(world.zone_at(world.boss_spawn)["id"]) == "sanctum", "the boss must be in the Crownless Sanctum")
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


## Conifer regions must not grow broadleaf trees and the two woods must not grow
## pines. This is a design rule, not a random roll: it is baked into the zone
## tables and inherited by the outskirt forest.
func _test_forest_families() -> void:
	var by_id: Dictionary = {}
	for zone: Dictionary in world.zones:
		by_id[str(zone["id"])] = zone["trees"]
	for id: String in ["vale", "thornwood"]:
		var mix: Dictionary = by_id[id]
		assert(mix.has("oak") and mix.has("birch"), "%s needs oak and birch" % id)
		assert(not mix.has("pine") and not mix.has("dead"), "%s must not mix conifers or dead trees" % id)
	for id: String in ["arch", "sanctum"]:
		var mix: Dictionary = by_id[id]
		assert(mix.size() == 1 and mix.has("pine"), "%s must be pine only, got %s" % [id, mix])
	var fen: Dictionary = by_id["fen"]
	assert(fen.has("dead") and fen.has("pine") and fen.size() == 2,
		"the fen must be dead trees plus pines, got %s" % fen)
	# Outskirts pick their family from the nearest region, so a pine ridge does
	# not gain an oak at its foot just because the point is outside the blob.
	for step: int in range(48):
		var angle: float = TAU * float(step) / 48.0
		var point: Vector2 = Vector2(cos(angle), sin(angle)) * (float(world.BOUNDS) - 6.0)
		var nearest: Dictionary = world.zone_at_xz(point)
		var kind: String = str(world.call("_outskirt_tree", point))
		var mix: Dictionary = nearest["trees"]
		if float(mix.get("pine", 0.0)) >= 0.5 and not mix.has("dead"):
			assert(kind == "pine", "outskirt near %s grew a %s" % [nearest["name"], kind])
		elif mix.has("dead"):
			assert(kind == "dead" or kind == "pine", "fen outskirt grew a %s" % kind)
		else:
			assert(kind == "oak" or kind == "birch", "wood outskirt grew a %s" % kind)


func _test_tree_spacing() -> void:
	# Check every reserved trunk, including the foothill belt, independently of
	# the placement helper. Nearby canopies may overlap; trunks must not.
	var points: Array[Vector2] = []
	for cell: Variant in world._tree_spacing_cells:
		for point: Vector2 in world._tree_spacing_cells[cell]:
			points.append(point)
	assert(points.size() > 1000, "forest lost too many trees")
	var minimum: float = float(world.TREE_TRUNK_CLEARANCE)
	var checked: Dictionary = {}
	for point: Vector2 in points:
		var cell := Vector2i(floori(point.x / minimum), floori(point.y / minimum))
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				for prior: Vector2 in checked.get(cell + Vector2i(dx, dz), []):
					assert(point.distance_squared_to(prior) >= minimum * minimum - 0.0001,
						"tree trunks are too close: %s / %s" % [point, prior])
		if not checked.has(cell):
			checked[cell] = []
		checked[cell].append(point)


func _test_terrain() -> void:
	# The same height function drives visuals, collision and props, so it must be
	# finite everywhere including past the playable rim.
	for z_step in range(-96, 97, 8):
		for x_step in range(-96, 97, 8):
			var h: float = world.height_at(float(x_step), float(z_step))
			assert(is_finite(h), "height is not finite at (%d, %d)" % [x_step, z_step])
			assert(h > -40.0 and h < 60.0, "height %.1f out of range at (%d, %d)" % [h, x_step, z_step])
			var sample_x := float(x_step) + 0.37
			var sample_z := float(z_step) + 0.63
			assert(absf(world.surface_height_at(sample_x, sample_z) - _rendered_height(sample_x, sample_z)) < 0.001, "ground overlay height must match the terrain mesh")
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
	var rim_height: float = world.height_at(float(world.RIM_END) - 5.0, 0.0)
	assert(rim_height > 15.0, "the mountain rim did not rise (%.1f)" % rim_height)
	assert(world.height_at(0.0, 0.0) < rim_height, "the playable bowl must sit below the rim")
	# The world is at least twice the old 148 m width.
	assert(absf(pow(float(world.BOUNDS) / 148.0, 2.0) - 3.0) < 0.001, "playable area should be three times the previous map")
	assert(world.normal_spawns.size() >= 25, "the expanded outer areas need creatures")
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
	assert(world.waygate_position.x < -world.BOUNDS * 0.8 and world.waygate_position.z < -world.BOUNDS * 0.8,
		"the sealed waygate should be in the northwest corner")
	var road_ends := 0
	var gate_xz := Vector2(world.waygate_position.x, world.waygate_position.z)
	for road: PackedVector2Array in world.roads:
		if road[0].distance_to(gate_xz) < 0.1 or road[road.size() - 1].distance_to(gate_xz) < 0.1:
			road_ends += 1
	assert(road_ends == 1, "the waygate must sit at the end of one road")
	# The waygate is a small safe zone inside the sanctum, not a separate map.
	var distance: float = Vector2(world.waygate_position.x, world.waygate_position.z).distance_to(gate_zone["center"])
	assert(distance < float(gate_zone["radius"]), "waygate outside the sanctum blob")
	assert(world.waygate_radius >= 6.0 and world.waygate_radius <= 12.0)
	# Map II must not exist in the project.
	assert(not ResourceLoader.exists("res://scenes/map_2.tscn"), "Map II must not exist yet")
	assert(not ResourceLoader.exists("res://scenes/map2.tscn"), "Map II must not exist yet")


func _test_roads() -> void:
	assert(world.roads.size() >= 55, "expanded regions need connected new roads, got %d roads" % world.roads.size())
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
	var wolf = game._spawn_enemy("normal", world.normal_spawns[0], 0, "wolf")
	var boss = game._spawn_enemy("boss", world.boss_spawn)
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
	# --- Committed bite: stepping off the locked point dodges the wolf. ---
	game.player.global_position = Vector3(0.0, 2.0, 16.0)
	wolf.global_position = game.player.global_position + Vector3(1.0, 0.0, 0.0)
	wolf.home = wolf.global_position
	wolf.aggro = true
	wolf.attack_timer = 0.0
	wolf.species = "wolf"
	wolf._physics_process(0.02)
	assert(wolf.winding_up and wolf.attack_type == "bite", "wolf did not commit to a bite")
	var wolf_point: Vector3 = wolf.locked_point
	game.player.global_position = wolf_point + Vector3(0.0, 0.0, 3.0)
	var hp_after_wolf_dodge: float = game.state.hp
	for step: int in range(60):
		wolf._physics_process(0.02)
	assert(not wolf.winding_up, "wolf never finished its committed bite")
	assert(is_equal_approx(game.state.hp, hp_after_wolf_dodge),
		"the wolf hit a player who had left the locked point")
	# --- Boar charge: the lane is committed, so a sidestep is a clean dodge. ---
	var boar = game._spawn_enemy("normal", world.normal_spawns[0], 0, "boar")
	game.player.global_position = Vector3(0.0, 2.0, 16.0)
	boar.global_position = game.player.global_position + Vector3(4.0, 0.0, 0.0)
	boar.home = boar.global_position
	boar.aggro = true
	boar.attack_timer = 0.0
	boar.charge_active = false
	boar._physics_process(0.02)
	assert(boar.winding_up and boar.attack_type == "charge", "boar did not commit to a charge")
	var charge_point: Vector3 = boar.locked_point
	game.player.global_position = charge_point + Vector3(0.0, 0.0, 5.0)
	var hp_after_charge_dodge: float = game.state.hp
	for step: int in range(80):
		boar._physics_process(0.02)
	assert(not boar.charge_active, "the boar never ended its charge")
	assert(is_equal_approx(game.state.hp, hp_after_charge_dodge),
		"the boar charge hit a player who sidestepped the lane")
	# --- Every normal in Map I is a wolf or a boar. ---
	for candidate in game.enemies:
		if candidate.kind != "normal":
			continue
		assert(candidate.species == "wolf" or candidate.species == "boar",
			"normal spawn has unknown species '%s'" % candidate.species)


func _test_creatures() -> void:
	# The wolf and boar are modelled in Blender, not built from primitives. A
	# bare GLB would still load, so assert the detail that makes them read as
	# animals: real geometry, emissive eyes and the runtime alpha-cut fur cards
	# (the GLB itself exports blended transparency, which the runtime replaces).
	for entry: Array in [["wolf.glb", "build_wolf", 9000], ["boar.glb", "build_boar", 8000]]:
		var visual: Node3D = load("res://scripts/actor_visual.gd").new()
		root.add_child(visual)
		visual.call(str(entry[1]))
		var triangles: int = 0
		var cards: int = 0
		var eyes: int = 0
		for node: Node in visual.find_children("*", "MeshInstance3D", true, false):
			var instance := node as MeshInstance3D
			if instance.mesh == null:
				continue
			triangles += instance.mesh.get_faces().size() / 3
			for surface: int in range(instance.mesh.get_surface_count()):
				var material: Material = instance.get_surface_override_material(surface)
				if material == null:
					material = instance.mesh.surface_get_material(surface)
				if material is BaseMaterial3D:
					var base := material as BaseMaterial3D
					if base.resource_name == "FurCard":
						cards += 1
					if base.emission_enabled:
						eyes += 1
		assert(triangles >= int(entry[2]),
			"%s is still the primitive fallback (%d triangles)" % [entry[0], triangles])
		assert(cards > 0, "%s has no runtime fur-card material" % entry[0])
		assert(eyes > 0, "%s has no emissive eye material" % entry[0])
		assert(visual.creature_rig != null, "%s has no creature skeleton" % entry[0])
		for bone: String in ["front_left", "front_right", "hind_left", "hind_right", "head"]:
			assert(visual.creature_rig.find_bone(bone) >= 0, "%s is missing bone %s" % [entry[0], bone])
		var leg: int = visual.creature_rig.find_bone("front_left")
		var before: Quaternion = visual.creature_rig.get_bone_pose_rotation(leg)
		visual.animate(0.13, 2.3)
		assert(absf(before.dot(visual.creature_rig.get_bone_pose_rotation(leg))) < 0.9999,
			"%s legs do not animate while moving" % entry[0])
		visual.queue_free()


func _test_road_lamps() -> void:
	var lamps: Array[Vector3] = world.road_lamps
	assert(not lamps.is_empty(), "no road lamps were placed")
	assert(lamps.size() <= 13, "too many road lamps: %d" % lamps.size())
	var verge_min: float = world.ROAD_WIDTH * 0.5 + 0.4
	for index: int in range(lamps.size()):
		var lamp: Vector3 = lamps[index]
		var distance: float = world._road_distance(Vector2(lamp.x, lamp.z))
		assert(distance > verge_min, "a road lamp stands on the road ribbon")
		assert(distance < verge_min + 4.5, "a road lamp is adrift in the field")
		for other: int in range(index + 1, lamps.size()):
			assert(lamp.distance_to(lamps[other]) >= 44.0,
				"road lamps are packed closer than 44 m")
	# Lamps must actually light the night; a mesh with no omni light is scenery.
	for lamp: Vector3 in lamps:
		_load_static_at(lamp)
		var found := false
		for light: OmniLight3D in world._night_lights:
			if light.global_position.distance_to(lamp) < 3.5:
				found = true
				break
		assert(found, "a streamed road lamp has no light source")
	_load_static_at(lamps[0])
	var sampled_light: OmniLight3D
	for light: OmniLight3D in world._night_lights:
		if light.global_position.distance_to(lamps[0]) < 3.5:
			sampled_light = light
			break
	assert(sampled_light != null, "could not sample a streamed lamp")
	world.set_time_of_day(12.0)
	var day_energy: float = sampled_light.light_energy
	world.set_time_of_day(23.0)
	assert(sampled_light.light_energy > day_energy, "streamed lamps must respond to day and night")
	world.set_time_of_day(8.25)
	_load_static_at(world.player_spawn)

func _test_frontier_landmarks() -> void:
	assert(world.frontier_landmarks.size() >= 5, "expanded areas need places to explore")
	for landmark: Dictionary in world.frontier_landmarks:
		var at: Vector2 = landmark["at"]
		_load_static_at(Vector3(at.x, 0.0, at.y))
		var found := false
		for label: Label3D in world.find_children("*", "Label3D", true, false):
			if label.text == str(landmark["name"]):
				found = true
				break
		assert(found, "an exploration landmark failed to load")
	_load_static_at(world.player_spawn)

func _load_static_at(at: Vector3) -> void:
	world.update_static_chunks(at)
	var cell: Vector2i = world.stream_cell(at)
	for attempt in range(180):
		if world._static_active.has(cell) or not world._static_paths.has(cell):
			return
		world._pump_streaming()
	assert(false, "the requested scenery cell did not load")


func _test_ground_cover() -> void:
	var grass := world.find_child("MeadowGrass_*", false, false) as MultiMeshInstance3D
	assert(grass != null and grass.multimesh != null, "meadow grass was not built")
	assert(world.grass_points.size() > 2000, "the meadow grass is too sparse")
	var grass_material: Material = grass.multimesh.mesh.surface_get_material(0)
	assert(grass_material is ShaderMaterial, "grass is not using the blade shader")
	var shader := (grass_material as ShaderMaterial).shader
	assert(shader != null and shader.code.contains("alpha_to_coverage"),
		"grass shader lost its anti-aliased coverage path")
	# No blade on the road ribbon: sample the whole field rather than trusting
	# the placement loop that wrote it.
	var recorded_grass: int = int(world._vegetation_counts.get("MeadowGrass", 0))
	assert(world.grass_points.size() == recorded_grass,
		"the grass audit trail does not match the drawn tufts")
	var step: int = maxi(1, world.grass_points.size() / 500)
	for index: int in range(0, world.grass_points.size(), step):
		var point: Vector2 = world.grass_points[index]
		assert(not world._on_road(point, 0.05),
			"grass grows on the road at (%.1f, %.1f)" % [point.x, point.y])
	var brush := world.find_child("Underbrush_*", false, false) as MultiMeshInstance3D
	assert(brush != null and brush.multimesh != null, "the underbrush was not built")
	var recorded_brush: int = int(world._vegetation_counts.get("Underbrush", 0))
	assert(recorded_brush > 400, "the underbrush is too sparse")
	assert(brush.multimesh.mesh.get_surface_count() >= 2,
		"bushes have no separate foliage surface")
	var leaves: Material = brush.multimesh.mesh.surface_get_material(1)
	assert(leaves is StandardMaterial3D and (leaves as StandardMaterial3D).albedo_texture != null,
		"bush foliage has no alpha-card texture")


func _test_camp() -> void:
	var camp: Node3D = world.find_child("SurvivorCamp", true, false)
	assert(camp != null, "the starting camp was not built")
	# Godot gives repeated sibling names opaque "@Node3D@12" names, so match
	# structures (a tent canopy, a log seat) instead of node names.
	var tents: Array[Node] = []
	var logs: int = 0
	var beds: int = 0
	for child: Node in camp.get_children():
		if child is MeshInstance3D:
			continue
		if child.get_node_or_null("TentCanopy") != null:
			tents.append(child)
		elif child.get_node_or_null("LogSeat") != null:
			logs += 1
	assert(tents.size() == 4, "expected four walk-in tents, found %d" % tents.size())
	for tent: Node in tents:
		var tent_beds := tent.find_children("GroundBed*", "Node3D", true, false)
		assert(tent_beds.size() == 1, "a walk-in tent has no ground bed")
		beds += tent_beds.size()
	assert(beds == 4, "the camp does not have four beds")
	assert(logs == 2, "expected two log seats by the fire, found %d" % logs)
	assert(camp.find_children("Flame", "Node3D", true, false).size() > 0,
		"the campfire has no flame")
	var body := camp.get_node_or_null("CampFenceBody") as StaticBody3D
	assert(body != null, "the camp fence has no collision body")
	# A gate is only a gate if the fence leaves a hole where the road enters.
	var centre := Vector2(world.camp_position.x, world.camp_position.z)
	var gates: Array[float] = []
	for polyline: PackedVector2Array in world.roads:
		if polyline.size() < 2:
			continue
		var start: Vector2 = polyline[0]
		var direction: Vector2 = polyline[1] - polyline[0]
		if start.distance_to(centre) > 2.0:
			start = polyline[polyline.size() - 1]
			direction = polyline[polyline.size() - 2] - start
			if start.distance_to(centre) > 2.0:
				continue
		if direction.length() < 0.01:
			continue
		gates.append(atan2(direction.y, direction.x))
	assert(gates.size() >= 3, "the camp does not open onto at least three roads")
	var segments: int = 0
	for child: Node in body.get_children():
		var collision := child as CollisionShape3D
		if collision == null:
			continue
		segments += 1
		var offset := Vector2(collision.position.x, collision.position.z)
		if offset.length() < 4.0:
			continue
		var angle := atan2(offset.y, offset.x)
		for gate: float in gates:
			assert(absf(angle_difference(angle, gate)) > 0.12,
				"a fence segment blocks a camp gate")
	assert(segments >= gates.size() * 2,
		"the fence has too few segments to enclose the camp")


func _test_sky() -> void:
	assert(world._environment != null, "the environment was not built")
	var environment := world._environment as Environment
	var sky := environment.sky as Sky
	assert(sky != null, "the environment has no sky")
	assert(sky.process_mode == Sky.PROCESS_MODE_REALTIME,
		"the moving cloud deck needs a realtime sky")
	var material := world._sky_material as ShaderMaterial
	assert(material != null and material.shader != null,
		"the frontier sky shader is missing")
	assert(material.shader.code.contains("cloud"),
		"the sky shader has no cloud layer")
	# Glow is what makes the fire, lanterns, runes and eyes read at night, and
	# SSAO grounds props and actors. Both must default on and be live-togglable.
	assert(environment.glow_enabled, "glow should be enabled by default")
	assert(environment.ssao_enabled, "ambient occlusion should be enabled by default")
	assert(game.glow_enabled and game.ssao_enabled,
		"the graphics settings should default to on")
	assert(environment.glow_blend_mode == Environment.GLOW_BLEND_MODE_SCREEN,
		"glow should screen-blend so it only adds light")
	assert(environment.glow_hdr_threshold >= 1.0,
		"glow should only catch light sources above the HDR threshold")
	for level: int in [2, 3, 4]:
		assert(environment.get_glow_level(level) > 0.0,
			"glow level %d should contribute to the halo" % level)
	world.apply_graphics_settings(false, false)
	assert(not environment.glow_enabled, "disabling glow did not reach the environment")
	assert(not environment.ssao_enabled, "disabling occlusion did not reach the environment")
	world.apply_graphics_settings(true, true)
	assert(environment.glow_enabled and environment.ssao_enabled,
		"re-enabling graphics effects did not reach the environment")
	for strength in range(1, 4):
		game.set_ssao_strength(strength)
		assert(is_equal_approx(environment.ssao_intensity, 1.5 * strength), "AO strength must update immediately")
	game.set_ssao_enabled(false)
	game.set_ssao_strength(3)
	game.set_ssao_enabled(true)
	assert(is_equal_approx(environment.ssao_intensity, 4.5), "AO strength must survive toggling")
	var settings := ConfigFile.new()
	game._load_graphics_settings(settings)
	assert(game.ssao_strength == 1, "old settings should retain the original strength")
	settings.set_value("graphics", "ambient_occlusion_strength", 2)
	game._load_graphics_settings(settings)
	assert(game.ssao_strength == 2, "saved AO strength should load")
	var saved_settings := ConfigFile.new()
	game._store_graphics_settings(saved_settings)
	assert(saved_settings.get_value("graphics", "ambient_occlusion_strength") == 2, "AO strength should be stored")
	settings.set_value("graphics", "ambient_occlusion_strength", 99)
	game._load_graphics_settings(settings)
	assert(game.ssao_strength == 3, "AO strength should be bounded")
	game.set_ssao_strength(1)

