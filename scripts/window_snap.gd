extends RefCounted
## Geometry shared by movable HUD windows. Dragging only attracts nearby edges;
## release chooses the closest free placement, without moving other windows.
const DEFAULT_GAP := 8.0
const DEFAULT_THRESHOLD := 14.0
const EPSILON := 0.01

static func clamp_position(rect: Rect2, bounds: Rect2) -> Vector2:
	var maximum := (bounds.end - rect.size).max(bounds.position)
	return rect.position.clamp(bounds.position, maximum)

static func overlaps(rect: Rect2, obstacles: Array, gap: float = DEFAULT_GAP) -> bool:
	for other: Rect2 in obstacles:
		if rect.intersects(other.grow(maxf(0.0, gap) - EPSILON)):
			return true
	return false

static func snap(rect: Rect2, bounds: Rect2, obstacles: Array, gap: float = DEFAULT_GAP, threshold: float = DEFAULT_THRESHOLD) -> Vector2:
	var position := clamp_position(rect, bounds)
	rect.position = position
	var xs: Array[float] = [bounds.position.x, bounds.end.x - rect.size.x]
	var ys: Array[float] = [bounds.position.y, bounds.end.y - rect.size.y]
	for other: Rect2 in obstacles:
		if _interval_near(rect.position.y, rect.end.y, other.position.y, other.end.y, gap + threshold):
			xs.append(other.position.x - rect.size.x - gap)
			xs.append(other.end.x + gap)
		if _interval_near(rect.position.x, rect.end.x, other.position.x, other.end.x, gap + threshold):
			ys.append(other.position.y - rect.size.y - gap)
			ys.append(other.end.y + gap)
		# Align the edges of windows already docked on the perpendicular axis.
		if rect.end.y <= other.position.y - gap + threshold or rect.position.y >= other.end.y + gap - threshold:
			xs.append(other.position.x)
			xs.append(other.end.x - rect.size.x)
		if rect.end.x <= other.position.x - gap + threshold or rect.position.x >= other.end.x + gap - threshold:
			ys.append(other.position.y)
			ys.append(other.end.y - rect.size.y)
	position.x = _nearest(position.x, xs, threshold, bounds.position.x, maxf(bounds.position.x, bounds.end.x - rect.size.x))
	position.y = _nearest(position.y, ys, threshold, bounds.position.y, maxf(bounds.position.y, bounds.end.y - rect.size.y))
	return clamp_position(Rect2(position, rect.size), bounds)

static func settle(rect: Rect2, bounds: Rect2, obstacles: Array, gap: float = DEFAULT_GAP, threshold: float = DEFAULT_THRESHOLD) -> Vector2:
	var desired := clamp_position(rect, bounds)
	var snapped := snap(Rect2(desired, rect.size), bounds, obstacles, gap, threshold)
	if not overlaps(Rect2(snapped, rect.size), obstacles, gap):
		return snapped
	# A closest free placement is formed by an original coordinate, a viewport
	# boundary, or an obstacle boundary. Their Cartesian product covers all such
	# candidates, including narrow spaces that a fixed sampling grid would miss.
	var xs: Array[float] = [desired.x, snapped.x, bounds.position.x, bounds.end.x - rect.size.x]
	var ys: Array[float] = [desired.y, snapped.y, bounds.position.y, bounds.end.y - rect.size.y]
	for other: Rect2 in obstacles:
		xs.append(other.position.x - rect.size.x - gap)
		xs.append(other.end.x + gap)
		ys.append(other.position.y - rect.size.y - gap)
		ys.append(other.end.y + gap)
	var best := desired
	var distance := INF
	for x: float in xs:
		for y: float in ys:
			var candidate := Rect2(Vector2(x, y), rect.size)
			if not _inside(candidate, bounds) or overlaps(candidate, obstacles, gap):
				continue
			var score := desired.distance_squared_to(candidate.position)
			if score < distance - EPSILON or (is_equal_approx(score, distance) and _before(candidate.position, best)):
				best = candidate.position
				distance = score
	# If the viewport cannot contain a clear placement, preserve the requested
	# position instead of teleporting between equally impossible arrangements.
	return best

static func for_control(control: Control, extent: Vector2, peers: Array, release: bool = false, gap: float = DEFAULT_GAP, threshold: float = DEFAULT_THRESHOLD) -> Vector2:
	var obstacles: Array[Rect2] = []
	for peer: Variant in peers:
		if not is_instance_valid(peer) or not peer is Control or peer == control:
			continue
		if not peer.is_visible_in_tree() or peer.is_queued_for_deletion():
			continue
		if peer.is_ancestor_of(control) or control.is_ancestor_of(peer):
			continue
		obstacles.append(peer.get_global_rect())
	var bounds := Rect2(Vector2(4.0, 12.0), (extent - Vector2(8.0, 16.0)).max(Vector2.ZERO))
	var rect := control.get_global_rect()
	return settle(rect, bounds, obstacles, gap, threshold) if release else snap(rect, bounds, obstacles, gap, threshold)

static func _nearest(value: float, values: Array[float], threshold: float, minimum: float, maximum: float) -> float:
	var best := value
	var distance := maxf(0.0, threshold) + EPSILON
	for candidate: float in values:
		if candidate < minimum or candidate > maximum:
			continue
		var delta := absf(candidate - value)
		if delta < distance - EPSILON or (is_equal_approx(delta, distance) and candidate < best):
			best = candidate
			distance = delta
	return best

static func _interval_near(a0: float, a1: float, b0: float, b1: float, tolerance: float) -> bool:
	return a0 <= b1 + tolerance and a1 >= b0 - tolerance

static func _inside(rect: Rect2, bounds: Rect2) -> bool:
	return rect.position.x >= bounds.position.x - EPSILON and rect.position.y >= bounds.position.y - EPSILON and rect.end.x <= bounds.end.x + EPSILON and rect.end.y <= bounds.end.y + EPSILON

static func _before(a: Vector2, b: Vector2) -> bool:
	return a.y < b.y if not is_equal_approx(a.y, b.y) else a.x < b.x
