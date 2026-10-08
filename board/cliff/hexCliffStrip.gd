class_name HexCliffStrip
extends RefCounted
## The cliff face along one hex side, rebuilt as a few large flat facets.
## A strip is the row of lattice triangles between a low tile's edge and the next lattice row in.
## Only its rim points (on the hex edge), base points (one row in), and the spoke edges at its two
## corners are shared with other terrain, so its inside can be triangulated freely.
## Crossing edge k joins the rim to the base, numbered along the side; 0 and the last are the spokes.
## Some crossing edges are facet columns. Neighboring columns are joined into large triangles, and
## rim and base points between column ends sit on the straight line between them, so facets stay flush.

## Returned by find_for_triangle() for a triangle outside every strip.
const NONE := Vector3i(0, 0, -1)
## Returned by find_for_point() for a point inside no strip's rim or base.
const NO_POINT := Vector4i(0, 0, -1, 0)

## (tile.x, tile.y, side). The strip lies in tile, facing its higher neighbor across side.
var id: Vector3i
## Lattice points on the hex edge, from corner side - 1 to corner side.
var rim: Array[Vector2i] = []
## Lattice points one row in, in the same order.
var base: Array[Vector2i] = []
## Crossing edges that are facet columns, ascending. Always includes both spokes.
var columns := PackedInt32Array()

var _subdivisions: int = 0
var _outward := Vector3.ZERO # Horizontal direction the face looks
var _triangle: HexTerrainSurface.Triangle


func _init(tile: Vector2i, side: int, subdivisions: int, settings: HexCliffSettings, surface: HexTerrainSurface) -> void:
	id = Vector3i(tile.x, tile.y, side)
	_subdivisions = subdivisions
	var center: Vector2i = HexLattice.hex_center(tile, subdivisions)
	var u: Vector2i = HexLattice.CORNERS[posmod(side - 1, 6)]
	var w: Vector2i = HexLattice.CORNERS[side]
	for b: int in subdivisions + 1:
		rim.append(center + u * (subdivisions - b) + w * b)
	for b: int in subdivisions:
		base.append(center + u * (subdivisions - 1 - b) + w * b)
	var last: int = 2 * subdivisions - 1
	var forced: Dictionary = {0: true, last: true} # Crossing edge -> true
	# A rim or base segment that is itself a cliff edge carries shared bands, so it can't lie inside
	# a facet's straight side. Columns at both of its ends make it a side of its own.
	for b: int in subdivisions:
		if surface.has_bands(rim[b], rim[b + 1]):
			forced[2 * b] = true
			forced[2 * b + 1] = true
	for b: int in subdivisions - 1:
		if surface.has_bands(base[b], base[b + 1]):
			forced[2 * b + 1] = true
			forced[2 * b + 2] = true
	# Each crossing edge is half a lattice step further along the side.
	var chance: float = clampf(0.5 * HexLattice.get_spacing(subdivisions) / settings.facet_width, 0.0, 1.0)
	for k: int in last + 1:
		if forced.has(k):
			columns.append(k)
		# Spokes are pushed along the corner's own direction, so they may lean sideways. A column
		# sharing a spoke's bottom could cross it there.
		elif k != 1 and k != last - 1 and HexCliffNoise.hash01(tile.x, tile.y, side * 64 + k, settings.noise_seed + 1) < chance:
			columns.append(k)
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


## Final position of a rim or base point between two column ends: on the straight line between them,
## so the facet touching it stays flush. Null for a column end, which keeps its own position.
func get_between_position(is_base: bool, index: int, surface: HexTerrainSurface) -> Variant:
	var left: int = -1
	var right: int = -1
	for k: int in columns:
		var end: int = get_bottom_index(k) if is_base else get_top_index(k)
		if end == index:
			return null
		if end < index:
			left = end
		elif right < 0:
			right = end
	var row: Array[Vector2i] = base if is_base else rim
	var start: Vector3 = surface.get_position(HexTerrainSurface.get_lattice_key(row[left]))
	var finish: Vector3 = surface.get_position(HexTerrainSurface.get_lattice_key(row[right]))
	return start.lerp(finish, float(index - left) / (right - left))


## The strip's faces. Built once.
func get_triangle(surface: HexTerrainSurface) -> HexTerrainSurface.Triangle:
	if _triangle:
		return _triangle
	var keys: Array[Vector4i] = []
	var rest := PackedVector3Array()
	var local: Dictionary = {} # Vertex key -> local index
	var chains: Array[PackedInt32Array] = []
	var between: Dictionary = {} # Vector2i(facet corner, next facet corner) -> points between them
	var last: int = 2 * _subdivisions - 1
	for k: int in columns:
		var top: Vector2i = rim[get_top_index(k)]
		var bottom: Vector2i = base[get_bottom_index(k)]
		# Spokes are shared, so they keep every band. Inner columns hold only facet corners.
		var vertices: Array[Vector4i] = surface.get_chain(top, bottom) if k == 0 or k == last else surface.get_column(top, bottom)
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
	_triangle = triangle
	return _triangle


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
