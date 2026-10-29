extends RefCounted
## Map I spawn slots are lightweight while their cells are inactive. Times are
## session seconds, not wall time, so closing the game pauses every deadline.

const ACTIVE_RADIUS := 1
const NORMAL_RESPAWN := 28.0
const BOSS_RESPAWN := 180.0
const WORLD_LAYOUT_VERSION := 2
var game: Node
var slots: Array[Dictionary] = []
var active: Dictionary = {}
var now: float = 0.0
var last_clock: float = 0.0
var last_center := Vector2i(2147483647, 2147483647)

func setup(owner: Node, saved: Dictionary) -> void:
	game = owner
	now = maxf(0.0, float(saved.get("elapsed", 0.0)))
	last_clock = _world_clock()
	var previous: Variant = saved.get("slots", [])
	# Older saves had ten normal slots followed by the boss and guardian. Keep
	# those identities when new normal spawns are inserted before the unique mobs.
	var previous_normal_count := clampi(int(saved.get("normal_count", 10)), 0, game.world.normal_spawns.size())
	for index in range(game.world.normal_spawns.size() + 2):
		var kind := "normal" if index < game.world.normal_spawns.size() else ("boss" if index == game.world.normal_spawns.size() else "quest")
		var slot := {"kind": kind, "ready_at": 0.0, "species": "", "hp": -1.0, "position": [], "phase_epoch": -1, "window_pending": false}
		var old_index := index if kind == "normal" and index < previous_normal_count else (-1 if kind == "normal" else previous_normal_count + (1 if kind == "quest" else 0))
		if previous is Array and old_index >= 0 and old_index < previous.size() and previous[old_index] is Dictionary:
			var old: Dictionary = previous[old_index]
			slot["ready_at"] = maxf(0.0, float(old.get("ready_at", 0.0)))
			var species := str(old.get("species", ""))
			if species in ["wolf", "boar", "guardian"]:
				slot["species"] = species
			slot["hp"] = float(old.get("hp", -1.0))
			slot["phase_epoch"] = int(old.get("phase_epoch", -1))
			slot["window_pending"] = bool(old.get("window_pending", false))
			if int(saved.get("layout_version", 1)) == WORLD_LAYOUT_VERSION and old.get("position", []) is Array and old.get("position", []).size() == 3:
				slot["position"] = old["position"].duplicate()
		slots.append(slot)

func _home(index: int) -> Vector3:
	if index < game.world.normal_spawns.size():
		return game.world.normal_spawns[index]
	return game.world.boss_spawn if index == game.world.normal_spawns.size() else game.world.quest_spawn

func _species() -> String:
	# Dawn and dusk belong to the species whose period begins at the transition.
	return "boar" if game.world.time_of_day >= 5.0 and game.world.time_of_day < 17.5 else "wolf"

func _phase_epoch() -> int:
	var day: int = game.world.day_number
	var hour: float = game.world.time_of_day
	if hour < 5.0:
		return (day - 1) * 2 + 1
	return day * 2 + (1 if hour >= 17.5 else 0)

func _world_clock() -> float:
	return (game.world.day_number - 1) * game.world.DAY_SECONDS + game.world.time_of_day * game.world.DAY_SECONDS / 24.0

## Whether a recurring window intersects an elapsed interval. Constant work even
## across many days, and the end is exclusive to match the species schedules.
func window_occurred(from_clock: float, to_clock: float, start_hour: float, end_hour: float) -> bool:
	var period: float = game.world.DAY_SECONDS
	var start := fposmod(start_hour, 24.0) * period / 24.0
	var width := fposmod(end_hour - start_hour, 24.0) * period / 24.0
	if is_zero_approx(width):
		return false
	if to_clock < from_clock:
		from_clock = to_clock # Debug clock jumps backwards do not simulate time.
	var latest_start: float = floor((to_clock - start) / period) * period + start
	return latest_start <= to_clock and latest_start + width > from_clock

func advance(delta: float) -> void:
	var previous_now := now
	now += maxf(0.0, delta)
	var clock := _world_clock()
	var center: Vector2i = game.world.stream_cell(game.player.global_position)
	var current_species := _species()
	var phase_epoch := _phase_epoch()
	for index in range(slots.size()):
		var slot: Dictionary = slots[index]
		var species: String = current_species if slot["kind"] == "normal" else "guardian"
		var enemy: Node = active.get(index)
		# The boss slot is retained for save compatibility and the future boss
		# rework, but stays dormant while world.boss_spawn_enabled is false.
		if slot["kind"] == "boss" and not bool(game.world.boss_spawn_enabled):
			if is_instance_valid(enemy):
				_remove(index, false)
			continue
		if slot["kind"] == "quest" and (not bool(game.state.quests[0]["active"]) or int(game.state.quests[0]["stage"]) != 2):
			if is_instance_valid(enemy):
				_remove(index, false)
			continue
		var changed_window: bool = slot["kind"] == "normal" and int(slot["phase_epoch"]) != phase_epoch
		if is_instance_valid(enemy) and (str(slot["species"]) != species or changed_window):
			_remove(index, false)
			enemy = null
		# Time-window changes replace the old species even in unloaded cells.
		if str(slot["species"]) != species or changed_window:
			slot["species"] = species
			slot["hp"] = -1.0
			slot["position"] = []
			slot["phase_epoch"] = phase_epoch
		var cell: Vector2i = game.world.stream_cell(_home(index))
		var near := absi(cell.x - center.x) <= ACTIVE_RADIUS and absi(cell.y - center.y) <= ACTIVE_RADIUS
		if is_instance_valid(enemy) and not near and not enemy.aggro:
			_remove(index, true)
			enemy = null
		var allowed := now >= float(slot["ready_at"])
		var window: Array = game.world.boss_spawn_window
		if slot["kind"] == "boss" and window.size() == 2 and float(slot["hp"]) <= 0.0:
			if allowed:
				var eligible_clock := last_clock
				if now > previous_now and float(slot["ready_at"]) > previous_now and clock >= last_clock:
					eligible_clock = lerpf(last_clock, clock, (float(slot["ready_at"]) - previous_now) / (now - previous_now))
				if window_occurred(eligible_clock, clock, float(window[0]), float(window[1])):
					slot["window_pending"] = true
			allowed = allowed and bool(slot["window_pending"])
		if near and not is_instance_valid(enemy) and allowed:
			var at: Vector3 = _home(index)
			var position: Array = slot["position"]
			if position.size() == 3:
				at = Vector3(float(position[0]), float(position[1]), float(position[2]))
			enemy = game._spawn_enemy(str(slot["kind"]), _home(index), 0, species)
			enemy.set_meta("world_spawn_slot", index)
			enemy.global_position = at if position.size() == 3 else _home(index) + Vector3.UP * 0.15
			if float(slot["hp"]) > 0.0:
				enemy.hp = clampf(float(slot["hp"]), 0.01, enemy.max_hp)
			active[index] = enemy
			slot["window_pending"] = false
	if center != last_center:
		last_center = center
		game.game_log.world("chunk_stream", {"cell_x": center.x, "cell_z": center.y, "active_spawns": active.size()})
	last_clock = clock

func defeated(enemy: Node) -> void:
	var index: int = int(enemy.get_meta("world_spawn_slot"))
	if index < 0 or index >= slots.size():
		return
	active.erase(index)
	var slot: Dictionary = slots[index]
	slot["ready_at"] = now + (NORMAL_RESPAWN if slot["kind"] == "normal" else BOSS_RESPAWN)
	slot["hp"] = -1.0
	slot["position"] = []
	slot["window_pending"] = false

func _capture(index: int, enemy: Node) -> void:
	var slot: Dictionary = slots[index]
	var pos: Vector3 = enemy.global_position
	slot["hp"] = float(enemy.hp)
	slot["position"] = [pos.x, pos.y, pos.z]

func _remove(index: int, capture: bool) -> void:
	var enemy: Node = active.get(index)
	active.erase(index)
	if not is_instance_valid(enemy):
		return
	if capture:
		_capture(index, enemy)
	if game.target == enemy:
		game.target = null
	enemy._clear_telegraph()
	game.enemies.erase(enemy)
	enemy.queue_free()

func snapshot() -> Dictionary:
	for index in active:
		var enemy: Node = active[index]
		if is_instance_valid(enemy) and not enemy.dead:
			_capture(index, enemy)
	return {"elapsed": now, "slots": slots.duplicate(true), "normal_count": game.world.normal_spawns.size(), "layout_version": WORLD_LAYOUT_VERSION, "day": game.world.day_number, "hour": game.world.time_of_day}
