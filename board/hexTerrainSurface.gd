class_name HexTerrainSurface
extends RefCounted
## Terrain geometry before meshing: lattice points, cliff band vertices, and triangulated lattice triangles.
## Results depend only on map data and settings, so chunks built separately match at their borders.
## Vertex keys:
## Vector4i(x, y, -1, 0) = lattice point (x, y).
## Vector4i(x, y, d, i) = band i (counted up from the bottom) on the edge from lattice point (x, y)
## toward HexLattice.NEIGHBORS[d], d in 0-2.

## get_flags(): an edge carries band vertices.
const FLAG_SPLIT: int = 1
## get_flags(): steep enough to draw as cliff.
const FLAG_STEEP: int = 2
## Faces with normal.y below this are cliffs, even without bands.
const CLIFF_NORMAL_Y: float = 0.6

const _LATTICE: int = -1
const _N: Array[Vector2i] = HexLattice.NEIGHBORS
# Edge direction by offset, indexed (dx + 1) * 3 + dy + 1. 0-2 = NEIGHBORS[d], 3-5 = reversed, -1 = not adjacent.
const _EDGE_CODES: Array[int] = [-1, 3, 2, 4, -1, 1, 5, 0, -1]

var _data: HexMapData
var _settings: HexTerrainSettings
var _cliff: HexCliffSettings
var _noise: HexCliffNoise
var _subdivisions: int = 0
var _cliff_threshold: float = 0.0 # Min height step of a cliff edge
var _steep_limit: float = 0.0 # See get_flags()
var _heights: Dictionary = {} # Lattice point -> undisplaced height
var _rest: Dictionary = {} # Band key -> undisplaced position
var _positions: Dictionary = {} # Vertex key -> final position
var _creases: Dictionary = {} # Band key -> true, for bands with their own push
var _cliff_edges: Dictionary = {} # Edge key -> bool
var _chains: Dictionary = {} # Edge key -> Array[Vector4i], origin to end
var _triangles: Dictionary = {} # Triangle key -> Triangle


func _init(data: HexMapData, settings: HexTerrainSettings) -> void:
	_data = data
	_settings = settings
	_cliff = settings.cliff if settings.cliff else HexCliffSettings.new()
	_noise = HexCliffNoise.new(_cliff)
	_subdivisions = settings.subdivisions
	_cliff_threshold = HexCliffBands.CLIFF_LEVELS * settings.elevation_step
	var spacing: float = HexLattice.get_spacing(_subdivisions)
	_steep_limit = (1.0 / (CLIFF_NORMAL_Y * CLIFF_NORMAL_Y) - 1.0) * 0.75 * spacing * spacing


static func get_lattice_key(point: Vector2i) -> Vector4i:
	return Vector4i(point.x, point.y, _LATTICE, 0)


static func is_lattice_key(key: Vector4i) -> bool:
	return key.z == _LATTICE


## Final vertex position.
func get_position(key: Vector4i) -> Vector3:
	var position: Variant = _positions.get(key)
	if position == null:
		# Band positions are stored when their edge is built, so only lattice points land here.
		position = _get_point_position(Vector2i(key.x, key.y))
		_positions[key] = position
	return position


## Vertex position before cliff displacement.
func get_rest_position(key: Vector4i) -> Vector3:
	if key.z == _LATTICE:
		return _get_lattice_rest(Vector2i(key.x, key.y))
	return _rest[key]


## FLAG_SPLIT and FLAG_STEEP for lattice triangle a, b, c.
func get_flags(a: Vector2i, b: Vector2i, c: Vector2i) -> int:
	var height_a: float = _get_height(a)
	var ab: float = _get_height(b) - height_a
	var ac: float = _get_height(c) - height_a
	var flags: int = FLAG_STEEP if _is_steep(ab, ac) else 0
	# Height checks first; most triangles have no steep edge.
	if (
		(absf(ab) > _cliff_threshold and _is_cliff_edge(_get_edge_key(a, b)))
		or (absf(ac - ab) > _cliff_threshold and _is_cliff_edge(_get_edge_key(b, c)))
		or (absf(ac) > _cliff_threshold and _is_cliff_edge(_get_edge_key(c, a)))
	):
		flags |= FLAG_SPLIT
	return flags


## Steep triangles around a lattice point: bit k = triangle (point, NEIGHBORS[k], NEIGHBORS[k + 1]).
## -1 if any of them might be split; use get_triangles_around() then.
func get_ring_steep_mask(point: Vector2i) -> int:
	var center: float = _get_height(point)
	var first: float = _get_height(point + _N[0]) - center
	var current: float = first
	var mask: int = 0
	for k: int in 6:
		var next: float = first if k == 5 else _get_height(point + _N[k + 1]) - center
		if absf(current) > _cliff_threshold or absf(next - current) > _cliff_threshold:
			return -1
		if _is_steep(current, next):
			mask |= 1 << k
		current = next
	return mask


## Lattice triangle a, b, c (any order), split around its band vertices. Front-facing.
## Allocates; for unsplit triangles prefer get_flags() and lattice keys.
func get_triangle(a: Vector2i, b: Vector2i, c: Vector2i) -> Triangle:
	var key: Vector3i = _get_triangle_key(a, b, c)
	var triangle: Triangle = _triangles.get(key)
	if triangle == null:
		triangle = _build_triangle(key)
		_triangles[key] = triangle
	return triangle


## Lattice triangles that contain a vertex.
func get_triangles_around(key: Vector4i) -> Array[Triangle]:
	var point := Vector2i(key.x, key.y)
	var result: Array[Triangle] = []
	if key.z == _LATTICE:
		for k: int in 6:
			result.append(get_triangle(point, point + _N[k], point + _N[(k + 1) % 6]))
		return result
	var end: Vector2i = point + _N[key.z]
	result.append(get_triangle(point, point + _N[(key.z + 5) % 6], end))
	result.append(get_triangle(point, end, point + _N[key.z + 1]))
	return result


# Canonical key. Vector3i(x, y, 0) = (p, p + N0, p + N1). Vector3i(x, y, 1) = (p, p + N1, p + N2).
# Type 0 has one corner with the lowest x + y; type 1 has two.
static func _get_triangle_key(a: Vector2i, b: Vector2i, c: Vector2i) -> Vector3i:
	var sum_a: int = a.x + a.y
	var sum_b: int = b.x + b.y
	var sum_c: int = c.x + c.y
	if sum_a < sum_b and sum_a < sum_c:
		return Vector3i(a.x, a.y, 0)
	if sum_b < sum_a and sum_b < sum_c:
		return Vector3i(b.x, b.y, 0)
	if sum_c < sum_a and sum_c < sum_b:
		return Vector3i(c.x, c.y, 0)
	# Type 1: of the two lowest corners, the one with larger x.
	var p: Vector2i
	if sum_a == sum_b:
		p = a if a.x > b.x else b
	elif sum_a == sum_c:
		p = a if a.x > c.x else c
	else:
		p = b if b.x > c.x else c
	return Vector3i(p.x, p.y, 1)


# Canonical key: the edge from origin toward NEIGHBORS[d], d in 0-2.
static func _get_edge_key(a: Vector2i, b: Vector2i) -> Vector3i:
	var offset: Vector2i = b - a
	var code: int = -1
	if absi(offset.x) <= 1 and absi(offset.y) <= 1:
		code = _EDGE_CODES[(offset.x + 1) * 3 + offset.y + 1]
	if code < 0:
		push_error("Lattice points %s and %s are not adjacent." % [a, b])
		return Vector3i.ZERO
	if code < 3:
		return Vector3i(a.x, a.y, code)
	return Vector3i(b.x, b.y, code - 3)


# Exact steepness of a lattice triangle from the height changes along two of its edges.
# |gradient|^2 = (ab^2 - ab * ac + ac^2) / (0.75 * spacing^2).
func _is_steep(ab: float, ac: float) -> bool:
	return ab * ab - ab * ac + ac * ac > _steep_limit


func _build_triangle(key: Vector3i) -> Triangle:
	var origin := Vector2i(key.x, key.y)
	var corners: Array[Vector2i] = [origin, origin + _N[key.z], origin + _N[key.z + 1]]
	var triangle := Triangle.new()
	var flags: int = get_flags(corners[0], corners[1], corners[2])
	if not flags & FLAG_SPLIT:
		for corner: Vector2i in corners:
			triangle.keys.append(get_lattice_key(corner))
		triangle.is_cliff = flags & FLAG_STEEP != 0
		return triangle
	# Local indices for the stitcher.
	var keys: Array[Vector4i] = []
	var rest := PackedVector3Array()
	var is_crease := PackedByteArray() # Corners count as creases.
	var local: Dictionary = {} # Vertex key -> local index
	var chains: Array[PackedInt32Array] = []
	for i: int in 3:
		var indices := PackedInt32Array()
		for vertex: Vector4i in _get_chain(corners[i], corners[(i + 1) % 3]):
			if not local.has(vertex):
				local[vertex] = keys.size()
				keys.append(vertex)
				rest.append(get_rest_position(vertex))
				is_crease.append(1 if vertex.z == _LATTICE or _creases.has(vertex) else 0)
			indices.append(local[vertex])
		chains.append(indices)
	for index: int in HexCliffStitcher.stitch(chains, rest, is_crease):
		triangle.keys.append(keys[index])
	triangle.is_cliff = true
	return triangle


# Vertex keys along an edge, from one end to the other.
func _get_chain(from: Vector2i, to: Vector2i) -> Array[Vector4i]:
	var edge: Vector3i = _get_edge_key(from, to)
	if not _chains.has(edge):
		_chains[edge] = _build_chain(edge)
	var chain: Array[Vector4i] = _chains[edge]
	if Vector2i(edge.x, edge.y) == from:
		return chain
	var reversed: Array[Vector4i] = chain.duplicate()
	reversed.reverse()
	return reversed


func _build_chain(edge: Vector3i) -> Array[Vector4i]:
	var origin := Vector2i(edge.x, edge.y)
	var end: Vector2i = origin + _N[edge.z]
	var chain: Array[Vector4i] = [get_lattice_key(origin)]
	if _is_cliff_edge(edge):
		var start: Vector3 = _get_lattice_rest(origin)
		var finish: Vector3 = _get_lattice_rest(end)
		var bottom: float = minf(start.y, finish.y)
		var top: float = maxf(start.y, finish.y)
		var heights: PackedFloat32Array = HexCliffBands.get_heights(bottom, top, (start + finish) * 0.5, _cliff, _noise)
		var direction: Vector2 = _get_edge_direction(edge)
		var strength: float = HexCliffDisplacement.get_strength(top - bottom, _settings.elevation_step)
		var count: int = heights.size()
		var rests := PackedVector3Array()
		var crease_bands := PackedInt32Array()
		var pushes := PackedFloat32Array()
		var outward := PackedFloat32Array()
		# Bottom to top. Only creases get their own push.
		for i: int in count:
			var rest: Vector3 = start.lerp(finish, (heights[i] - start.y) / (finish.y - start.y))
			rests.append(rest)
			if HexCliffBands.is_crease(edge, i, _cliff):
				crease_bands.append(i)
				pushes.append(HexCliffDisplacement.get_crease_push(rest, direction, strength, _cliff, _noise))
				outward.append(Vector2(rest.x, rest.z).dot(direction))
		var lower: Vector3 = get_position(get_lattice_key(origin if start.y < finish.y else end))
		var upper: Vector3 = get_position(get_lattice_key(end if start.y < finish.y else origin))
		HexCliffDisplacement.remove_overhangs(
			outward,
			pushes,
			Vector2(lower.x, lower.z).dot(direction),
			Vector2(upper.x, upper.z).dot(direction),
		)
		var finals: PackedVector3Array = _place_bands(rests, crease_bands, pushes, direction, lower, upper)
		for n: int in count:
			# Keys count up from the bottom; the chain runs origin to end.
			var index: int = n if start.y < finish.y else count - 1 - n
			var key := Vector4i(origin.x, origin.y, edge.z, index)
			_rest[key] = rests[index]
			_positions[key] = finals[index]
			chain.append(key)
		for index: int in crease_bands:
			_creases[Vector4i(origin.x, origin.y, edge.z, index)] = true
	chain.append(get_lattice_key(end))
	return chain


# Final band positions, bottom to top. Creases are pushed along direction;
# every other band sits on the straight line between the creases or end points around it.
static func _place_bands(rests: PackedVector3Array, crease_bands: PackedInt32Array, pushes: PackedFloat32Array, direction: Vector2, lower: Vector3, upper: Vector3) -> PackedVector3Array:
	var finals := PackedVector3Array()
	finals.resize(rests.size())
	var offset := Vector3(direction.x, 0.0, direction.y)
	var previous_point: Vector3 = lower
	var previous_band: int = -1
	for c: int in crease_bands.size() + 1:
		var is_end: bool = c == crease_bands.size()
		var next_band: int = rests.size() if is_end else crease_bands[c]
		var next_point: Vector3 = upper if is_end else rests[next_band] + offset * pushes[c]
		for i: int in range(previous_band + 1, next_band):
			var t: float = (rests[i].y - previous_point.y) / (next_point.y - previous_point.y)
			finals[i] = previous_point.lerp(next_point, t)
		if not is_end:
			finals[next_band] = next_point
		previous_point = next_point
		previous_band = next_band
	return finals


# Steep edges of on-map triangles. Off-map terrain gets no cliffs.
func _is_cliff_edge(edge: Vector3i) -> bool:
	var cached: Variant = _cliff_edges.get(edge)
	if cached != null:
		return cached
	var origin := Vector2i(edge.x, edge.y)
	var end: Vector2i = origin + _N[edge.z]
	var result: bool = absf(_get_height(end) - _get_height(origin)) > _cliff_threshold
	if result:
		result = (
			_is_on_map(origin, origin + _N[(edge.z + 5) % 6], end)
			or _is_on_map(origin, end, origin + _N[edge.z + 1])
		)
	_cliff_edges[edge] = result
	return result


func _has_cliff_edge(a: Vector2i, b: Vector2i, c: Vector2i) -> bool:
	return (
		_is_cliff_edge(_get_edge_key(a, b))
		or _is_cliff_edge(_get_edge_key(b, c))
		or _is_cliff_edge(_get_edge_key(c, a))
	)


# Each lattice triangle lies inside one hex, so its centroid picks the tile.
func _is_on_map(a: Vector2i, b: Vector2i, c: Vector2i) -> bool:
	var centroid: Vector3 = (
		HexLattice.to_world(a, _subdivisions)
		+ HexLattice.to_world(b, _subdivisions)
		+ HexLattice.to_world(c, _subdivisions)
	) / 3.0
	return _data.has_tile(HexMath.world_to_axial(centroid))


# Outward direction of a cliff edge: average of its on-map triangles.
func _get_edge_direction(edge: Vector3i) -> Vector2:
	var origin := Vector2i(edge.x, edge.y)
	var end: Vector2i = origin + _N[edge.z]
	var origin_rest: Vector3 = _get_lattice_rest(origin)
	var end_rest: Vector3 = _get_lattice_rest(end)
	var sum := Vector2.ZERO
	var before: Vector2i = origin + _N[(edge.z + 5) % 6]
	if _is_on_map(origin, before, end):
		sum += HexCliffDisplacement.get_downhill(origin_rest, _get_lattice_rest(before), end_rest)
	var after: Vector2i = origin + _N[edge.z + 1]
	if _is_on_map(origin, end, after):
		sum += HexCliffDisplacement.get_downhill(origin_rest, end_rest, _get_lattice_rest(after))
	return sum.normalized() if sum.length() > 0.0001 else Vector2.ZERO


# Lattice points on a cliff's rim or base are pushed; all others stay at rest.
func _get_point_position(point: Vector2i) -> Vector3:
	var rest: Vector3 = _get_lattice_rest(point)
	var is_rim: bool = false
	var is_base: bool = false
	var strength: float = 0.0
	for k: int in 6:
		var neighbor: Vector2i = point + _N[k]
		var difference: float = rest.y - _get_height(neighbor)
		if absf(difference) <= _cliff_threshold or not _is_cliff_edge(_get_edge_key(point, neighbor)):
			continue
		if difference > 0.0:
			is_rim = true
		else:
			is_base = true
		strength = maxf(strength, HexCliffDisplacement.get_strength(difference, _settings.elevation_step))
	if not is_rim and not is_base:
		return rest
	var direction := Vector2.ZERO
	for k: int in 6:
		var b: Vector2i = point + _N[k]
		var c: Vector2i = point + _N[(k + 1) % 6]
		if _has_cliff_edge(point, b, c) and _is_on_map(point, b, c):
			direction += HexCliffDisplacement.get_downhill(rest, _get_lattice_rest(b), _get_lattice_rest(c))
	if direction.length() < 0.0001:
		return rest
	direction = direction.normalized()
	var push: float = HexCliffDisplacement.get_edge_push(rest, direction, is_rim, is_base, strength, _cliff, _noise)
	return rest + Vector3(direction.x, 0.0, direction.y) * push


func _get_lattice_rest(point: Vector2i) -> Vector3:
	var position: Vector3 = HexLattice.to_world(point, _subdivisions)
	position.y = _get_height(point)
	return position


func _get_height(point: Vector2i) -> float:
	var height: Variant = _heights.get(point)
	if height == null:
		height = HexTerrainHeight.get_height(_data, _settings, HexLattice.to_world(point, _subdivisions))
		_heights[point] = height
	return height


## One lattice triangle after cliff stitching.
class Triangle:
	## Vertex keys, 3 per triangle, front-facing.
	var keys: Array[Vector4i] = []
	## Drawn with cliff color and shaded as cliff.
	var is_cliff: bool = false
