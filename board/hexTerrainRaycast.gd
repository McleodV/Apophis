class_name HexTerrainRaycast
extends Object
## Static ray tests against HexBoard terrain.

const _STEP: float = 0.2 # March step in world units
const _REFINE_ITERATIONS: int = 10


## First point where the ray meets the terrain, or null if it misses.
## Rays pointing level or upward never hit.
static func cast(board: HexBoard, origin: Vector3, direction: Vector3) -> Variant:
	var dir: Vector3 = direction.normalized()
	if dir.y >= 0.0:
		return null
	if origin.y <= board.get_height(origin):
		return origin
	# Only march through the height band the terrain can occupy (0 to max height).
	var t_start: float = maxf(0.0, (origin.y - board.get_max_height()) / -dir.y)
	var t_end: float = origin.y / -dir.y
	var previous_t: float = t_start
	var t: float = t_start
	while t < t_end:
		var point: Vector3 = origin + dir * t
		if point.y <= board.get_height(point):
			return _refine(board, origin, dir, previous_t, t)
		previous_t = t
		t += _STEP
	return _refine(board, origin, dir, previous_t, t_end)


# Bisects between a t above the terrain and a t at or below it.
static func _refine(board: HexBoard, origin: Vector3, dir: Vector3, above_t: float, below_t: float) -> Vector3:
	for i: int in _REFINE_ITERATIONS:
		var mid_t: float = (above_t + below_t) * 0.5
		var point: Vector3 = origin + dir * mid_t
		if point.y <= board.get_height(point):
			below_t = mid_t
		else:
			above_t = mid_t
	return origin + dir * below_t
