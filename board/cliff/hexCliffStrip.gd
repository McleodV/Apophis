class_name HexCliffStrip
extends RefCounted
## The cliff face along one hex side, rebuilt as many flat facets.
## A strip is the row of lattice triangles between a low tile's edge and the next lattice row in.
## Only its rim points (on the hex edge), base points (one row in), and the spoke edges at its two
## corners are shared with other terrain, so its inside can be triangulated freely.
## Crossing edge k joins the rim to the base, numbered along the side; 0 and the last are the spokes.
## Facet columns run from rim to base (see HexCliffColumnLayout). Neighboring columns are joined into
## triangles, and rim and base points between column ends sit on the straight line between them,
## so facets stay flush. Columns other than spokes hold the strip's own corners (HexCliffColumnShape).
## Faces are assembled by HexCliffStripFaces. No face leans out going up at any spot along the wall.

## Returned by find_for_triangle() for a triangle outside every strip.
const NONE := Vector3i(0, 0, -1)
## Returned by find_for_point() for a point inside no strip's rim or base.
const NO_POINT := Vector4i(0, 0, -1, 0)
## Vertex key z of a strip's own corners, plus its side: Vector4i(tile.x, tile.y, CORNER_Z + side, index).
const CORNER_Z: int = 8

# get_triangle(): shape scales tried in turn (see HexCliffStripFaces.build()). A face that can't be
# kept upright calms the shape; at 0 columns run straight from rim to base, which never leans out.
const _SCALES: Array[float] = [1.0, 0.5, 0.0]

## (tile.x, tile.y, side). The strip lies in tile, facing its higher neighbor across side.
var id: Vector3i
## Lattice points on the hex edge, from corner side - 1 to corner side.
var rim: Array[Vector2i] = []
## Lattice points one row in, in the same order.
var base: Array[Vector2i] = []
## Facet columns, ordered along the side. The first and last are the spokes.
var columns: Array[HexCliffColumn] = []

## Horizontal direction the face looks.
var outward := Vector3.ZERO

var _max_push: float = 0.0 # Limit of rim and base pushes
var _settings: HexCliffSettings
var _noise: HexCliffNoise
var _triangle: HexTerrainSurface.Triangle
var _corner_positions := PackedVector3Array() # By corner index
var _corner_rests := PackedVector3Array()


func _init(tile: Vector2i, side: int, subdivisions: int, settings: HexCliffSettings, noise: HexCliffNoise, max_push: float, surface: HexTerrainSurface) -> void:
	id = Vector3i(tile.x, tile.y, side)
	_max_push = max_push
	_settings = settings
	_noise = noise
	var center: Vector2i = HexLattice.hex_center(tile, subdivisions)
	var u: Vector2i = HexLattice.CORNERS[posmod(side - 1, 6)]
	var w: Vector2i = HexLattice.CORNERS[side]
	for b: int in subdivisions + 1:
		rim.append(center + u * (subdivisions - b) + w * b)
	for b: int in subdivisions:
		base.append(center + u * (subdivisions - 1 - b) + w * b)
	# A rim or base segment that is itself a cliff edge carries shared bands, so it can't lie inside
	# a facet's straight side. Columns at both of its ends make it a side of its own.
	var forced: Dictionary = {} # Crossing edge -> true
	for b: int in subdivisions:
		if surface.has_bands(rim[b], rim[b + 1]):
			forced[2 * b] = true
			forced[2 * b + 1] = true
	for b: int in subdivisions - 1:
		if surface.has_bands(base[b], base[b + 1]):
			forced[2 * b + 1] = true
			forced[2 * b + 2] = true
	var sorted: Array = forced.keys()
	sorted.sort()
	columns = HexCliffColumnLayout.pick(tile, side, subdivisions, settings, PackedInt32Array(sorted))
	outward = HexMath.axial_to_world(tile) - HexMath.axial_to_world(HexMath.neighbor(tile, side))
	outward = outward.normalized()


## Key of the strip's own corner index.
static func get_corner_key(strip_id: Vector3i, index: int) -> Vector4i:
	return Vector4i(strip_id.x, strip_id.y, CORNER_Z + strip_id.z, index)


static func is_corner_key(key: Vector4i) -> bool:
	return key.z >= CORNER_Z


## Strip id of a corner key.
static func get_corner_strip(key: Vector4i) -> Vector3i:
	return Vector3i(key.x, key.y, key.z - CORNER_Z)


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
	for column: HexCliffColumn in columns:
		# A merging column's bottom is its neighbor's.
		if is_base and column.merge_side != 0:
			continue
		var end: int = column.bottom if is_base else column.top
		if end == index:
			depth += column.depth
			ends += 1
		elif end < index:
			left = end
		elif right < 0:
			right = end
	if ends > 0:
		var push: float = clampf(depth / ends, 0.0, _max_push)
		return surface.get_rest_position(HexTerrainSurface.get_lattice_key(row[index])) + outward * push
	var start: Vector3 = surface.get_position(HexTerrainSurface.get_lattice_key(row[left]))
	var finish: Vector3 = surface.get_position(HexTerrainSurface.get_lattice_key(row[right]))
	return start.lerp(finish, float(index - left) / (right - left))


## The strip's faces. Built once.
func get_triangle(surface: HexTerrainSurface) -> HexTerrainSurface.Triangle:
	if _triangle:
		return _triangle
	for scale: float in _SCALES:
		_triangle = HexCliffStripFaces.build(self, surface, _settings, _noise, scale, _corner_positions, _corner_rests)
		if _triangle:
			break
	return _triangle


## Final position of the strip's own corner index.
func get_corner_position(index: int, surface: HexTerrainSurface) -> Vector3:
	get_triangle(surface)
	return _corner_positions[index]


## Position of the strip's own corner index before displacement: on its column's rest line.
func get_corner_rest(index: int, surface: HexTerrainSurface) -> Vector3:
	get_triangle(surface)
	return _corner_rests[index]


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
