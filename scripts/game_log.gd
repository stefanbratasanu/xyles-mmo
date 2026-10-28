extends Node
class_name XylesGameLog

## Always-on diagnostics for the local vertical slice.
##
## One file is written per run under res://logs/ (gitignored). It records
## gameplay, combat, UI, world and state events plus explicit [MARKER] blocks
## that a developer can create in-game with F10 when something looks wrong.
##
## The log is deliberately cheap: lines are buffered and flushed at most a few
## times per second, and slow-frame warnings are throttled.

const LOG_DIR := "res://logs"
const MAX_SESSION_BYTES := 8 * 1024 * 1024
const MAX_SESSION_FILES := 24
const LATEST_POINTER := "res://logs/LATEST.txt"

var enabled: bool = true
var log_path: String = ""
var session_id: String = ""
var started_unix: int = 0
var started_ticks: int = 0
var game: Node

var _file: FileAccess
var _lines_since_flush: int = 0
var _counts: Dictionary = {
	"combat": 0, "gameplay": 0, "ui": 0, "world": 0, "state": 0,
	"error": 0, "marker": 0, "perf": 0,
}
var _last_slow_log: float = -10.0
var _last_flush: float = 0.0
var _closed: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	started_unix = int(Time.get_unix_time_from_system())
	started_ticks = Time.get_ticks_msec()
	session_id = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(LOG_DIR))
	log_path = "%s/session_%s.log" % [LOG_DIR, session_id]
	_file = FileAccess.open(log_path, FileAccess.WRITE)
	if _file == null:
		enabled = false
		push_warning("Game log disabled: could not open %s" % log_path)
		return
	_write_pointer()
	_prune_old_sessions()
	_event("BOOT", "session_started", {
		"engine": Engine.get_version_info().get("string", "?"),
		"os": OS.get_name(),
		"project": ProjectSettings.get_setting("application/config/name", "XYLES"),
		"scene": str(get_tree().current_scene.scene_file_path if get_tree().current_scene != null else ""),
	})
	print("[GameLog] runtime log: ", ProjectSettings.globalize_path(log_path))


func _process(delta: float) -> void:
	if not enabled:
		return
	var now := float(Time.get_ticks_msec()) * 0.001
	if now - _last_flush >= 0.5:
		_flush()
	if delta > 0.050 and now - _last_slow_log >= 4.0:
		_last_slow_log = now
		perf("slow_frame", {
			"delta_ms": snappedf(delta * 1000.0, 0.1),
			"fps": Engine.get_frames_per_second(),
		})


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		flush()


func boot_ready(snapshot: Dictionary = {}) -> void:
	_event("BOOT", "main_ready", snapshot)


func combat(message: String, data: Dictionary = {}) -> void:
	_event("COMBAT", message, data)


func gameplay(message: String, data: Dictionary = {}) -> void:
	_event("GAMEPLAY", message, data)


func ui(message: String, data: Dictionary = {}) -> void:
	_event("UI", message, data)


func world(message: String, data: Dictionary = {}) -> void:
	_event("WORLD", message, data)


func state(message: String, data: Dictionary = {}) -> void:
	_event("STATE", message, data)


func perf(message: String, data: Dictionary = {}) -> void:
	_event("PERF", message, data)


func error(message: String, data: Dictionary = {}) -> void:
	_event("ERROR", message, data, true)


## A marker is a pinned point in the log that a tester can create while playing.
## It always includes a snapshot so a later reader knows exactly where and when
## the glitch happened without needing the tester's memory.
func marker(label: String, snapshot: Dictionary = {}) -> void:
	_counts["marker"] = int(_counts["marker"]) + 1
	_flush()
	_store("")
	_store("===== [MARKER] %s =====" % label)
	_store("time=%s  elapsed=%.1fs" % [_wall_clock(), _elapsed_seconds()])
	for key: String in snapshot.keys():
		_store("  %s = %s" % [key, str(snapshot[key])])
	_store("===== end marker =====")
	_store("")
	print("[GameLog] marker: ", label)


func snapshot_of(game_ref: Node) -> Dictionary:
	if not is_instance_valid(game_ref):
		return {}
	var data: Dictionary = {
		"fps": Engine.get_frames_per_second(),
		"engine_time_s": snappedf(Time.get_ticks_msec() * 0.001, 0.1),
	}
	var player: Variant = game_ref.get("player")
	if player is Node3D:
		var body := player as Node3D
		data["player_pos"] = _vec(body.global_position)
		var world: Variant = game_ref.get("world")
		if is_instance_valid(world) and world.has_method("zone_at"):
			var zone: Dictionary = world.zone_at(body.global_position)
			data["zone"] = zone.get("name", "?")
			data["zone_levels"] = "Lv %s-%s" % [zone.get("level_min", "?"), zone.get("level_max", "?")]
			if world.get("time_of_day") != null:
				data["time"] = _clock_text(float(world.get("time_of_day")), int(world.get("day_number")))
		var state: Variant = game_ref.get("state")
		if is_instance_valid(state):
			data["hp"] = "%.1f/%.1f" % [float(state.get("hp")), float(state.get("max_hp"))]
			data["mana"] = "%.1f/%.1f" % [float(state.get("mana")), float(state.get("max_mana"))]
			data["level"] = int(state.get("level"))
		var region: Variant = game_ref.get("region_name")
		if region is String:
			data["region_label"] = region
		var target: Variant = game_ref.get("target")
		if target is Node3D:
			data["target"] = str(target.get("display_name"))
	var enemies: Variant = game_ref.get("enemies")
	if enemies is Array:
		data["enemies_alive"] = (enemies as Array).size()
	return data


func close_session(reason: String = "quit") -> void:
	if _closed:
		return
	_closed = true
	_counts["state"] = int(_counts["state"])
	_event("BOOT", "session_ended", {
		"reason": reason,
		"duration_s": _elapsed_seconds(),
		"combat_events": int(_counts["combat"]),
		"gameplay_events": int(_counts["gameplay"]),
		"ui_events": int(_counts["ui"]),
		"world_events": int(_counts["world"]),
		"state_events": int(_counts["state"]),
		"errors": int(_counts["error"]),
		"markers": int(_counts["marker"]),
	})
	_flush()
	if _file != null:
		_file.close()
		_file = null
	if enabled:
		print("[GameLog] session written to ", ProjectSettings.globalize_path(log_path))


func flush() -> void:
	_flush()


func open_log_folder() -> void:
	var absolute := ProjectSettings.globalize_path(LOG_DIR)
	DirAccess.make_dir_recursive_absolute(absolute)
	OS.shell_open(absolute)


func log_folder() -> String:
	return ProjectSettings.globalize_path(LOG_DIR)


func _event(category: String, message: String, data: Dictionary = {}, echo: bool = false) -> void:
	if not enabled:
		return
	_counts[category.to_lower()] = int(_counts.get(category.to_lower(), 0)) + 1
	var line := "%s  [%s] %s" % [_wall_clock(), category, message]
	if not data.is_empty():
		line += "  " + JSON.stringify(data)
	_store(line)
	if echo:
		printerr("[%s] %s" % [category, message])
	if category == "ERROR":
		_flush()


func _store(line: String) -> void:
	if _file == null:
		return
	if _file.get_length() > MAX_SESSION_BYTES:
		_store("... session log truncated at %d bytes" % MAX_SESSION_BYTES)
		enabled = false
		return
	_file.store_line(line)
	_lines_since_flush += 1
	if _lines_since_flush >= 24:
		_flush()


func _flush() -> void:
	if _file == null:
		return
	_file.flush()
	_lines_since_flush = 0
	_last_flush = float(Time.get_ticks_msec()) * 0.001


func _wall_clock() -> String:
	return Time.get_datetime_string_from_system(false, true)


func _elapsed_seconds() -> float:
	return float(Time.get_ticks_msec() - started_ticks) * 0.001


func _clock_text(hours: float, day: int) -> String:
	var total := int(floor(hours * 60.0)) % (24 * 60)
	return "day %02d %02d:%02d" % [day, total / 60, total % 60]


func _vec(value: Vector3) -> String:
	return "(%.2f, %.2f, %.2f)" % [value.x, value.y, value.z]


func _write_pointer() -> void:
	var pointer := FileAccess.open(LATEST_POINTER, FileAccess.WRITE)
	if pointer != null:
		pointer.store_line(log_path)
		pointer.store_line("Started: %s" % _wall_clock())
		pointer.close()


func _prune_old_sessions() -> void:
	var dir := DirAccess.open(LOG_DIR)
	if dir == null:
		return
	var names: Array[String] = []
	for name in dir.get_files():
		if name.begins_with("session_") and name.ends_with(".log"):
			names.append(name)
	names.sort()
	while names.size() > MAX_SESSION_FILES:
		var oldest: String = names.pop_front()
		dir.remove(oldest)
