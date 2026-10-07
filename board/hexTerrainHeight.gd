class_name HexTerrainHeight
extends Object
## Static terrain height sampling from HexMapData.
## Tile centers are flat. Neighbors within 1 level blend into slopes;
## larger differences produce cliffs (a sharp step at the shared edge).

const _EDGE_EPSILON: float = 0.001

# Unit xz vectors toward each neighbor, matching HexMath.DIRECTIONS.
const _NEIGHBOR_DIRS: Array[Vector2] = [
	Vector2(1.0, 0.0),
	Vector2(0.5, -0.8660254),
	Vector2(-0.5, -0.8660254),
	Vector2(-1.0, 0.0),
	Vector2(-0.5, 0.8660254),
	Vector2(0.5, 0.8660254),
]
# Unit xz vectors toward each corner, matching HexMath.corner_offset().
const _CORNER_DIRS: Array[Vector2] = [
	Vector2(0.8660254, -0.5),
	Vector2(0.0, -1.0),
	Vector2(-0.8660254, -0.5),
	Vector2(-0.8660254, 0.5),
	Vector2(0.0, 1.0),
	Vector2(0.8660254, 0.5),
]


## World height at a position. On tile borders, the highest bordering tile wins.
static func get_height(data: HexMapData, settings: HexTerrainSettings, world_position: Vector3) -> float:
	var axial: Vector2i = HexMath.world_to_axial(world_position)
	var offset: Vector2 = _get_offset(axial, world_position)
	var best: float = -INF
	if data.has_tile(axial):
		best = _get_owner_level(data, settings, axial, offset)
	for direction: int in 6:
		# Only neighbors whose shared edge this point lies on.
		if offset.dot(_NEIGHBOR_DIRS[direction]) / HexMath.INNER_RADIUS < 1.0 - _EDGE_EPSILON:
			continue
		var neighbor: Vector2i = HexMath.neighbor(axial, direction)
		if not data.has_tile(neighbor):
			continue
		best = maxf(best, _get_owner_level(data, settings, neighbor, _get_offset(neighbor, world_position)))
	if best == -INF:
		# Off the map: continue the nearest edge tile flat. Keeps edge normals correct.
		best = data.get_elevation(_clamp_to_map(data, axial))
	return best * settings.elevation_step


## World height at a point on the edge shared by tiles a and b, seen only from those two.
## Matches get_height() except at the edge's corners, where a third tile is ignored. b may be off the map.
static func get_edge_height(data: HexMapData, settings: HexTerrainSettings, a: Vector2i, b: Vector2i, world_position: Vector3) -> float:
	var level: float = _get_owner_level(data, settings, a, _get_offset(a, world_position))
	if data.has_tile(b):
		level = maxf(level, _get_owner_level(data, settings, b, _get_offset(b, world_position)))
	return level * settings.elevation_step


# Height in elevation levels, as seen from one tile.
static func _get_owner_level(data: HexMapData, settings: HexTerrainSettings, owner: Vector2i, offset: Vector2) -> float:
	# Blend within the triangle formed by the owner and the two neighbors nearest this point.
	var corner: int = _get_nearest_corner(offset)
	var next: int = (corner + 1) % 6
	var t_a: float = offset.dot(_NEIGHBOR_DIRS[corner]) / HexMath.INNER_RADIUS
	var t_b: float = offset.dot(_NEIGHBOR_DIRS[next]) / HexMath.INNER_RADIUS
	var weight_a: float = (2.0 * t_a - t_b) / 3.0
	var weight_b: float = (2.0 * t_b - t_a) / 3.0
	var weights := Vector3(1.0 - weight_a - weight_b, weight_a, weight_b)
	var own_level: int = data.get_elevation(owner)
	var levels := Vector3(
		own_level,
		_get_blend_level(data, HexMath.neighbor(owner, corner), own_level),
		_get_blend_level(data, HexMath.neighbor(owner, next), own_level),
	)
	return _blend(weights, levels, settings.blend_band)


# Neighbors across a cliff or off the map don't blend; they act as the owner's level.
static func _get_blend_level(data: HexMapData, axial: Vector2i, own_level: int) -> float:
	if not data.has_tile(axial):
		return own_level
	var level: int = data.get_elevation(axial)
	if absi(level - own_level) > 1:
		return own_level
	return level


# Piecewise-linear blend of 3 tile levels with flat tile tops.
# weights: barycentric weights of the 3 tile centers. band: blend_band setting.
static func _blend(weights: Vector3, levels: Vector3, band: float) -> float:
	var corner_min: float = (1.0 - band) / 3.0
	# Flat tile top.
	for i: int in 3:
		var j: int = (i + 1) % 3
		var k: int = (i + 2) % 3
		if weights[i] - weights[j] >= band and weights[i] - weights[k] >= band:
			return levels[i]
	# Slope between two tiles, away from the third.
	for i: int in 3:
		if weights[i] < corner_min:
			var j: int = (i + 1) % 3
			var k: int = (i + 2) % 3
			var t: float = clampf((weights[k] - weights[j] + band) / (2.0 * band), 0.0, 1.0)
			return lerpf(levels[j], levels[k], t)
	# Corner where all 3 tiles meet.
	return (
		(weights.x - corner_min) * levels.x
		+ (weights.y - corner_min) * levels.y
		+ (weights.z - corner_min) * levels.z
	) / band


static func _clamp_to_map(data: HexMapData, axial: Vector2i) -> Vector2i:
	var steps: int = HexMath.distance(axial, Vector2i.ZERO)
	if steps <= data.radius:
		return axial
	return HexMath.axial_round(Vector2(axial) * (float(data.radius) / steps))


static func _get_offset(axial: Vector2i, world_position: Vector3) -> Vector2:
	var center: Vector3 = HexMath.axial_to_world(axial)
	return Vector2(world_position.x - center.x, world_position.z - center.z)


static func _get_nearest_corner(offset: Vector2) -> int:
	var best_corner: int = 0
	var best_dot: float = -INF
	for corner: int in 6:
		var corner_dot: float = offset.dot(_CORNER_DIRS[corner])
		if corner_dot > best_dot:
			best_dot = corner_dot
			best_corner = corner
	return best_corner
