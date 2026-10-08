class_name HexTerrainNormals
extends Object
## Static vertex normals from a HexTerrainSurface.
## Cliff and ground faces are averaged separately, then blended at a fixed ratio,
## so cliff edges shade the same regardless of how many faces of each kind touch the point.
## Uses triangles outside the chunk too, so results match across chunk borders.

const _N: Array[Vector2i] = HexLattice.NEIGHBORS


static func get_normal(surface: HexTerrainSurface, key: Vector4i, cliff_edge_softness: float) -> Vector3:
	var sums: Array[Vector3] = _get_ring_sums(surface, key)
	if sums.is_empty():
		sums = _get_split_sums(surface, key)
	var ground_sum: Vector3 = sums[0]
	var cliff_sum: Vector3 = sums[1]
	if cliff_sum == Vector3.ZERO:
		return ground_sum.normalized()
	var normal: Vector3 = cliff_sum.normalized()
	if ground_sum != Vector3.ZERO:
		normal = normal.slerp(ground_sum.normalized(), cliff_edge_softness)
	return normal


# Fast path: lattice point with no split triangle around it. Empty if it doesn't apply.
# Returns [ground_sum, cliff_sum].
static func _get_ring_sums(surface: HexTerrainSurface, key: Vector4i) -> Array[Vector3]:
	if not HexTerrainSurface.is_lattice_key(key):
		return []
	var point := Vector2i(key.x, key.y)
	var steep_mask: int = surface.get_ring_steep_mask(point)
	if steep_mask < 0:
		return []
	var vertex: Vector3 = surface.get_position(key)
	var ground_sum := Vector3.ZERO
	var cliff_sum := Vector3.ZERO
	var previous: Vector3 = surface.get_position(HexTerrainSurface.get_lattice_key(point + _N[5])) - vertex
	for k: int in 6:
		var current: Vector3 = surface.get_position(HexTerrainSurface.get_lattice_key(point + _N[k])) - vertex
		# Area-weighted, pointing up out of the surface.
		var face: Vector3 = current.cross(previous)
		# Triangle (point, N[k - 1], N[k]) is mask bit k - 1.
		if steep_mask & (1 << ((k + 5) % 6)):
			cliff_sum += face
		else:
			ground_sum += face
		previous = current
	return [ground_sum, cliff_sum]


# Any vertex, from the stitched triangles around it. Returns [ground_sum, cliff_sum].
static func _get_split_sums(surface: HexTerrainSurface, key: Vector4i) -> Array[Vector3]:
	var ground_sum := Vector3.ZERO
	var cliff_sum := Vector3.ZERO
	for triangle: HexTerrainSurface.Triangle in surface.get_triangles_around(key):
		if triangle.is_cliff:
			cliff_sum += triangle.get_normal_sum(key, surface)
		else:
			ground_sum += triangle.get_normal_sum(key, surface)
	return [ground_sum, cliff_sum]
