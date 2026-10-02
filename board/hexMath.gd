class_name HexMath
extends Object
## Static helpers for pointy-top hexes in axial coordinates (q, r).
## Never instantiate; call functions directly, e.g. HexMath.distance(a, b).

## Center to corner.
const OUTER_RADIUS: float = 1.0
## Center to edge midpoint.
const INNER_RADIUS: float = OUTER_RADIUS * 0.8660254037844386
const SQRT3: float = 1.7320508075688772

## Neighbor offsets. Index 0 = east, then counterclockwise when viewed from above.
const DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
]


## Hex center in world space (y = 0).
static func axial_to_world(axial: Vector2i) -> Vector3:
	var x: float = OUTER_RADIUS * (SQRT3 * axial.x + SQRT3 * 0.5 * axial.y)
	var z: float = OUTER_RADIUS * 1.5 * axial.y
	return Vector3(x, 0.0, z)


## Hex containing a world position (y ignored).
static func world_to_axial(world_position: Vector3) -> Vector2i:
	var q: float = (SQRT3 / 3.0 * world_position.x - world_position.z / 3.0) / OUTER_RADIUS
	var r: float = (2.0 / 3.0 * world_position.z) / OUTER_RADIUS
	return axial_round(Vector2(q, r))


## Rounds fractional axial coordinates to the nearest hex.
static func axial_round(fractional: Vector2) -> Vector2i:
	var q: float = fractional.x
	var r: float = fractional.y
	var s: float = -q - r
	var rq: float = roundf(q)
	var rr: float = roundf(r)
	var rs: float = roundf(s)
	var dq: float = absf(rq - q)
	var dr: float = absf(rr - r)
	var ds: float = absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return Vector2i(int(rq), int(rr))


## Step distance between two hexes.
static func distance(a: Vector2i, b: Vector2i) -> int:
	var d: Vector2i = a - b
	@warning_ignore("integer_division")
	return (absi(d.x) + absi(d.y) + absi(d.x + d.y)) / 2


## Adjacent hex in a direction (0-5, wraps).
static func neighbor(axial: Vector2i, direction: int) -> Vector2i:
	return axial + DIRECTIONS[posmod(direction, 6)]


## Corner offset from hex center, between DIRECTIONS[index] and DIRECTIONS[index + 1].
## The edge shared with neighbor i runs from corner i - 1 to corner i.
static func corner_offset(index: int) -> Vector3:
	var angle: float = deg_to_rad(-30.0 - 60.0 * posmod(index, 6))
	return Vector3(cos(angle), 0.0, sin(angle)) * OUTER_RADIUS


## All hexes within radius steps of center, including center.
static func get_in_range(center: Vector2i, radius: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for q: int in range(-radius, radius + 1):
		for r: int in range(maxi(-radius, -q - radius), mini(radius, -q + radius) + 1):
			result.append(center + Vector2i(q, r))
	return result
