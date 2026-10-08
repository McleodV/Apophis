class_name HexCliffStrip
extends RefCounted
## The cliff face along one hex side, rebuilt as a few large flat facets.
## A strip is the row of lattice triangles between a low tile's edge and the next lattice row in.
## Only its rim points (on the hex edge), base points (one row in), and the spoke edges at its two
## corners are shared with other terrain, so its inside can be triangulated freely.
## Crossing edge k joins the rim to the base, numbered along the side; 0 and the last are the spokes.
## Some crossing edges are facet columns. Neighboring columns are joined into large triangles, and
## rim and base points between column ends sit on the straight line between them, so facets stay flush.
## Inner columns alternate between ridges, pushed out, and grooves, pushed in, so the facets between
## them alternate facing left and right. Ridges also push their rim and base points out.

## Returned by find_for_triangle() for a triangle outside every strip.
const NONE := Vector3i(0, 0, -1)
## Returned by find_for_point() for a point inside no strip's rim or base.
const NO_POINT := Vector4i(0, 0, -1, 0)

# Hash seed offset for column picks.
const _COLUMN_SEED: int = 7177
# _has_overhang(): downward normal.y below this counts. Ignores float noise on upright faces.
const _OVERHANG_TOLERANCE: float = 0.003

## (tile.x, tile.y, side). The strip lies in tile, facing its higher neighbor across side.
var id: Vector3i
## Lattice points on the hex edge, from corner side - 1 to corner side.
var rim: Array[Vector2i] = []
## Lattice points one row in, in the same order.
var base: Array[Vector2i] = []
## Crossing edges that are facet columns, ascending. Always includes both spokes.
var columns := PackedInt32Array()
## Per column: signed depth. Positive = ridge, negative = groove, 0 = spoke or forced column.
var depths := PackedFloat32Array()

var _subdivisions: int = 0
var _max_push: float = 0.0 # Limit of rim and base pushes
var _outward := Vector3.ZERO # Horizontal direction the face looks
var _triangle: HexTerrainSurface.Triangle


func _init(tile: Vector2i, side: int, subdivisions: int, settings: HexCliffSettings, max_push: float, surface: HexTerrainSurface) -> void:
	id = Vector3i(tile.x, tile.y, side)
	_subdivisions = subdivisions
	_max_push = max_push
	var center: Vector2i = HexLattice.hex_center(tile, subdivisions)
	var u: Vector2i = HexLattice.CORNERS[posmod(side - 1, 6)]
	var w: Vector2i = HexLattice.CORNERS[side]
	for b: int in subdivisions + 1:
		rim.append(center + u * (subdivisions - b) + w * b)
	for b: int in subdivisions:
		base.append(center + u * (subdivisions - 1 - b) + w * b)
	var last: int = 2 * subdivisions - 1
	var picks: Dictionary = {0: 0.0, last: 0.0} # Crossing edge -> signed depth
	# A rim or base segment that is itself a cliff edge carries shared bands, so it can't lie inside
	# a facet's straight side. Columns at both of its ends make it a side of its own.
	for b: int in subdivisions:
		if surface.has_bands(rim[b], rim[b + 1]):
			picks[2 * b] = 0.0
			picks[2 * b + 1] = 0.0
	for b: int in subdivisions - 1:
		if surface.has_bands(base[b], base[b + 1]):
			picks[2 * b + 1] = 0.0
			picks[2 * b + 2] = 0.0
	# Inner columns at random gaps, alternating ridge and groove.
	# Each crossing edge is half a lattice step further along the side.
	var mean_gap: float = settings.column_width / (0.5 * HexLattice.get_spacing(subdivisions))
	var seed_value: int = settings.noise_seed + _COLUMN_SEED
	var role: float = 1.0 if HexCliffNoise.hash01(tile.x, tile.y, side, seed_value) < 0.5 else -1.0
	var k: int = 0
	var n: int = 0
	while true:
		n += 1
		var spread: float = 2.0 * HexCliffNoise.hash01(tile.x, tile.y, side * 64 + n, seed_value + 1) - 1.0
		# Gaps of 1 crossing edge make sliver facets, so columns are at least a lattice step apart.
		# That also keeps them off a spoke's neighbor: spokes are pushed along the corner's own
		# direction, so they may lean sideways and cross a column sharing their bottom.
		k += maxi(2, roundi(mean_gap * (1.0 + settings.column_width_variance * spread)))
		if k >= last - 1:
			break
		if not picks.has(k):
			picks[k] = role * settings.column_depth
		role = -role
	var sorted: Array = picks.keys()
	sorted.sort()
	for column: int in sorted:
		columns.append(column)
		depths.append(picks[column])
	_outward = HexMath.axial_to_world(tile) - HexMath.axial_to_world(HexMath.neighbor(tile, side))
	_outward = _outward.normalized()


## True if tile has a cliff face along side: the neighbor there is at least 2 levels higher.
static func is_active(data: HexMapData, tile: Vector2i, side: int) -> bool:
	var neighbor: Vector2i = HexMath.neighbor(tile, side)
	return (
		data.has_tile(tile)
		and data.has_tile(neighbor)
		and data.get_elevation(neighbor) - data.get_elevation(tile) >= 2
	)


## Strip containing lattice triangle a, b, c, as (tile.x, tile.y, side). NONE if it isn't in one.
static func find_for_triangle(data: HexMapData, subdivisions: int, a: Vector2i, b: Vector2i, c: Vector2i) -> Vector3i:
	var centroid: Vector3 = (
		HexLattice.to_world(a, subdivisions)
		+ HexLattice.to_world(b, subdivisions)
		+ HexLattice.to_world(c, subdivisions)
	) / 3.0
	var tile: Vector2i = HexMath.world_to_axial(centroid)
	for side: int in 6:
		var row_a: int = _get_row(tile, side, a, subdivisions)
		var row_b: int = _get_row(tile, side, b, subdivisions)
		var row_c: int = _get_row(tile, side, c, subdivisions)
		if row_a < 0 or row_b < 0 or row_c < 0:
			continue
		# A triangle lies in one sector. It's in the strip if its corners span the last two rows.
		if mini(row_a, mini(row_b, row_c)) == subdivisions - 1 and is_active(data, tile, side):
			return Vector3i(tile.x, tile.y, side)
		return NONE
	return NONE


## Where a lattice point sits inside a strip's rim or base, corners and spokes excluded:
## (tile.x, tile.y, side, index) on the rim, or side + 6 on the base. NO_POINT if neither.
static func find_for_point(data: HexMapData, subdivisions: int, point: Vector2i) -> Vector4i:
	var home: Vector2i = HexMath.world_to_axial(HexLattice.to_world(point, subdivisions))
	# A point on a hex edge may round to either tile, so check the neighbors too.
	for t: int in 7:
		var tile: Vector2i = home if t == 6 else HexMath.neighbor(home, t)
		for side: int in 6:
			var ab: Vector2i = _get_sector_coords(tile, side, point, subdivisions)
			if ab.x < 0 or ab.y < 0:
				continue
			var row: int = ab.x + ab.y
			if row == subdivisions and ab.y > 0 and ab.y < subdivisions and is_active(data, tile, side):
				return Vector4i(tile.x, tile.y, side, ab.y)
			if row == subdivisions - 1 and ab.y > 0 and ab.y < subdivisions - 1 and is_active(data, tile, side):
				return Vector4i(tile.x, tile.y, side + 6, ab.y)
	return NO_POINT


## Rim index of the top of crossing edge k.
static func get_top_index(k: int) -> int:
	@warning_ignore("integer_division")
	return (k + 1) / 2


## Base index of the bottom of crossing edge k.
static func get_bottom_index(k: int) -> int:
	@warning_ignore("integer_division")
	return k / 2


## Final position of a rim or base point inside the strip.
## Column ends push out by their ridge depth; grooves stay put, so rims never pull back.
## Points between column ends sit on the straight line between them, so the facet touching them stays flush.
func get_point_position(is_base: bool, index: int, surface: HexTerrainSurface) -> Vector3:
	var row: Array[Vector2i] = base if is_base else rim
	var left: int = -1
	var right: int = -1
	var depth: float = 0.0
	var ends: int = 0
	for c: int in columns.size():
		var end: int = get_bottom_index(columns[c]) if is_base else get_top_index(columns[c])
		if end == index:
			depth += depths[c]
			ends += 1
		elif end < index:
			left = end
		elif right < 0:
			right = end
	if ends > 0:
		var push: float = clampf(depth / ends, 0.0, _max_push)
		return surface.get_rest_position(HexTerrainSurface.get_lattice_key(row[index])) + _outward * push
	var start: Vector3 = surface.get_position(HexTerrainSurface.get_lattice_key(row[left]))
	var finish: Vector3 = surface.get_position(HexTerrainSurface.get_lattice_key(row[right]))
	return start.lerp(finish, float(index - left) / (right - left))


## The strip's faces. Built once.
## Column wander can rarely tip a face down; then the columns are rebuilt straight.
func get_triangle(surface: HexTerrainSurface) -> HexTerrainSurface.Triangle:
	if _triangle:
		return _triangle
	var triangle: HexTerrainSurface.Triangle = _build_triangle(surface, 1.0)
	if _has_overhang(triangle, surface):
		triangle = _build_triangle(surface, 0.0)
	_triangle = triangle
	return _triangle


# wander: scale of the inner columns' sideways wander.
func _build_triangle(surface: HexTerrainSurface, wander: float) -> HexTerrainSurface.Triangle:
	var keys: Array[Vector4i] = []
	var rest := PackedVector3Array()
	var local: Dictionary = {} # Vertex key -> local index
	var chains: Array[PackedInt32Array] = []
	var between: Dictionary = {} # Vector2i(facet corner, next facet corner) -> points between them
	var last: int = 2 * _subdivisions - 1
	for c: int in columns.size():
		var k: int = columns[c]
		var top: Vector2i = rim[get_top_index(k)]
		var bottom: Vector2i = base[get_bottom_index(k)]
		# Spokes are shared, so they keep every band. Inner columns hold only facet corners.
		var vertices: Array[Vector4i]
		if k == 0 or k == last:
			vertices = surface.get_chain(top, bottom)
		else:
			vertices = surface.get_column(top, bottom, depths[c], wander)
		var chain := PackedInt32Array()
		var pending := PackedInt32Array()
		for vertex: Vector4i in vertices:
			var index: int = _get_local(vertex, surface, keys, rest, local)
			if HexTerrainSurface.is_lattice_key(vertex) or surface.is_crease_key(vertex):
				if not pending.is_empty():
					between[Vector2i(chain[chain.size() - 1], index)] = pending
					pending = PackedInt32Array()
				chain.append(index)
			else:
				pending.append(index)
		chains.append(chain)
	for c: int in columns.size() - 1:
		_add_between(rim, get_top_index(columns[c]), get_top_index(columns[c + 1]), surface, keys, rest, local, between)
		_add_between(base, get_bottom_index(columns[c]), get_bottom_index(columns[c + 1]), surface, keys, rest, local, between)
	var positions := PackedVector3Array()
	for key: Vector4i in keys:
		positions.append(surface.get_position(key))
	var triangle := HexTerrainSurface.Triangle.new()
	triangle.is_cliff = true
	for index: int in HexCliffStitcher.stitch_columns(chains, between, rest, positions, _outward):
		triangle.keys.append(keys[index])
	return triangle


# True if any face looks down.
static func _has_overhang(triangle: HexTerrainSurface.Triangle, surface: HexTerrainSurface) -> bool:
	for i: int in range(0, triangle.keys.size(), 3):
		var a: Vector3 = surface.get_position(triangle.keys[i])
		var normal: Vector3 = (surface.get_position(triangle.keys[i + 2]) - a).cross(surface.get_position(triangle.keys[i + 1]) - a)
		if normal.y < -_OVERHANG_TOLERANCE * normal.length():
			return true
	return false


# Row of a lattice point in a tile's sector toward side, or -1 if it's outside that sector.
static func _get_row(tile: Vector2i, side: int, point: Vector2i, subdivisions: int) -> int:
	var ab: Vector2i = _get_sector_coords(tile, side, point, subdivisions)
	return -1 if ab.x < 0 or ab.y < 0 else ab.x + ab.y


# (a, b) with point = center + CORNERS[side - 1] * a + CORNERS[side] * b.
static func _get_sector_coords(tile: Vector2i, side: int, point: Vector2i, subdivisions: int) -> Vector2i:
	var offset: Vector2i = point - HexLattice.hex_center(tile, subdivisions)
	var u: Vector2i = HexLattice.CORNERS[posmod(side - 1, 6)]
	var w: Vector2i = HexLattice.CORNERS[side]
	# Adjacent corner vectors span a lattice cell of area 1, so the determinant is 1 or -1.
	var determinant: int = u.x * w.y - u.y * w.x
	return Vector2i(
		(offset.x * w.y - offset.y * w.x) * determinant,
		(u.x * offset.y - u.y * offset.x) * determinant,
	)


# Points strictly between two column ends along the rim or base, listed under the pair of ends.
# Between neighboring points that's the bands of the segment joining them, if it has any.
static func _add_between(row: Array[Vector2i], from: int, to: int, surface: HexTerrainSurface, keys: Array[Vector4i], rest: PackedVector3Array, local: Dictionary, between: Dictionary) -> void:
	var points := PackedInt32Array()
	if to - from == 1:
		var chain: Array[Vector4i] = surface.get_chain(row[from], row[to])
		for i: int in range(1, chain.size() - 1):
			points.append(_get_local(chain[i], surface, keys, rest, local))
	else:
		for i: int in range(from + 1, to):
			points.append(_get_local(HexTerrainSurface.get_lattice_key(row[i]), surface, keys, rest, local))
	if points.is_empty():
		return
	var start: int = _get_local(HexTerrainSurface.get_lattice_key(row[from]), surface, keys, rest, local)
	var end: int = _get_local(HexTerrainSurface.get_lattice_key(row[to]), surface, keys, rest, local)
	between[Vector2i(start, end)] = points


static func _get_local(key: Vector4i, surface: HexTerrainSurface, keys: Array[Vector4i], rest: PackedVector3Array, local: Dictionary) -> int:
	var index: Variant = local.get(key)
	if index != null:
		return index
	local[key] = keys.size()
	keys.append(key)
	rest.append(surface.get_rest_position(key))
	return keys.size() - 1
