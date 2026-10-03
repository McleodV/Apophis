class_name HexLattice
extends Object
## Static helpers for the triangular vertex lattice aligned to hex edges.
## Lattice point (i, j) sits at x = spacing * sqrt(3) / 2 * i, z = spacing * (i / 2 + j).
## Every hex center and corner is a lattice point, so hex edges follow lattice lines.

## Unit offsets from a hex center to its corners, matching HexMath.corner_offset().
## Multiply by subdivisions for the full offset.
const CORNERS: Array[Vector2i] = [
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
	Vector2i(1, 0),
]
## The 6 adjacent lattice points, in rotational order.
const NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 1),
	Vector2i(-1, 0),
	Vector2i(0, -1),
	Vector2i(1, -1),
]


## Distance between adjacent lattice points.
static func get_spacing(subdivisions: int) -> float:
	return HexMath.OUTER_RADIUS / subdivisions


## Lattice point at a hex center.
static func hex_center(axial: Vector2i, subdivisions: int) -> Vector2i:
	return Vector2i(2 * axial.x + axial.y, axial.y - axial.x) * subdivisions


## World position of a lattice point (y = 0).
static func to_world(point: Vector2i, subdivisions: int) -> Vector3:
	var spacing: float = get_spacing(subdivisions)
	return Vector3(spacing * HexMath.SQRT3 * 0.5 * point.x, 0.0, spacing * (0.5 * point.x + point.y))
