extends RefCounted
## User-painted zone cells use 4 m world-space squares. They override the
## original region lookup without changing the original terrain generation.
const CELL_SIZE := 4.0

static func key_at(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL_SIZE), floori(point.y / CELL_SIZE))

static func center_of(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * CELL_SIZE

static func validate(zones: Variant, bounds: float) -> String:
	if not zones is Array or zones.size() > 100:
		return "The zone list is invalid or contains more than 100 zones."
	var ids: Dictionary = {}
	var occupied: Dictionary = {}
	for zone in zones:
		if not zone is Dictionary:
			return "A zone definition is invalid."
		var id := str(zone.get("id", ""))
		var name := str(zone.get("name", "")).strip_edges()
		var kind := str(zone.get("kind", ""))
		if not id.begins_with("zone_") or id.length() != 37 or ids.has(id) or name.is_empty() or name.length() > 60 or kind not in ["starter", "enemy", "neutral"]:
			return "A zone name, ID or type is invalid."
		for character in id.trim_prefix("zone_"):
			if not character in "0123456789abcdef":
				return "A zone ID is invalid."
		ids[id] = true
		var minimum := int(zone.get("level_min", 0))
		var maximum := int(zone.get("level_max", 0))
		if minimum < 1 or maximum < minimum or maximum > 999:
			return "A zone has an invalid level range."
		var cells: Variant = zone.get("cells")
		if not cells is Array or cells.size() > 200000:
			return "A zone has invalid painted cells."
		for item in cells:
			if not item is Array or item.size() != 2:
				return "A zone has an invalid painted cell."
			for value in item:
				if not (value is int or value is float) or not is_finite(float(value)) or floorf(float(value)) != float(value):
					return "A zone has an invalid painted cell."
			var cell := Vector2i(int(item[0]), int(item[1]))
			var point := center_of(cell)
			if absf(point.x) > bounds or absf(point.y) > bounds or occupied.has(cell):
				return "A zone cell is outside the map or belongs to more than one zone."
			occupied[cell] = true
	return ""

static func apply(world: Node3D, zones: Array) -> void:
	world.editor_zones.clear()
	world.editor_zone_cells.clear()
	for zone: Dictionary in zones:
		if zone["cells"].is_empty():
			continue
		var center := Vector2.ZERO
		for item: Array in zone["cells"]:
			center += center_of(Vector2i(int(item[0]), int(item[1])))
		center /= float(zone["cells"].size())
		# Inherit the local biome's visual identity; type does not invent a mob
		# species or spawn schedule. It only declares the authored zone's role.
		var base: Dictionary = world.zones[0]
		var best := INF
		for candidate: Dictionary in world.zones:
			var metric: float = world._zone_metric(candidate, center)
			if metric < best:
				best = metric
				base = candidate
		var definition: Dictionary = base.duplicate(true)
		definition["id"] = str(zone["id"])
		definition["name"] = str(zone["name"]).strip_edges().to_upper()
		definition["subtitle"] = str(zone["kind"]).capitalize() + " zone"
		definition["kind"] = str(zone["kind"])
		definition["level_min"] = int(zone["level_min"])
		definition["level_max"] = int(zone["level_max"])
		definition["center"] = center
		world.editor_zones[definition["id"]] = definition
		for item: Array in zone["cells"]:
			world.editor_zone_cells[Vector2i(int(item[0]), int(item[1]))] = definition["id"]
