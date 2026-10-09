class_name HexCliffStripFaces
extends Object
## Static assembly of a cliff strip's faces from its columns.
## Spoke columns keep their shared bands, which lie on a straight line. Other columns get the strip's
## own corners. Neighboring columns are joined pair by pair (HexCliffStitcher.stitch_columns()), cut
## at the breaks they share so slabs stay flat on both sides of a break; rim and base points between
## column ends lie on the faces' straight sides. Then HexCliffSlope keeps every face upright.


## The faces of strip, or null if a face with a free corner can't be kept upright.
## scale: 1 = full corner shape, lower calms it (see HexCliffColumnShape.build()), 0 = no corners:
## columns run straight from rim to base.
## On success, the strip's own corners are written to corner_positions and corner_rests by index.
static func build(strip: HexCliffStrip, surface: HexTerrainSurface, settings: HexCliffSettings, noise: HexCliffNoise, scale: float, corner_positions: PackedVector3Array, corner_rests: PackedVector3Array) -> HexTerrainSurface.Triangle:
	var rim: Array[Vector2i] = strip.rim
	var base: Array[Vector2i] = strip.base
	var subdivisions: int = rim.size() - 1
	var frame := HexCliffFrame.new(
		surface.get_rest_position(HexTerrainSurface.get_lattice_key(rim[0])),
		surface.get_rest_position(HexTerrainSurface.get_lattice_key(rim[subdivisions])),
		strip.outward,
		HexLattice.get_spacing(subdivisions),
	)
	var vertices := _Vertices.new()
	var chains: Array[PackedInt32Array] = []
	var between: Dictionary = {} # Vector2i(facet corner, next facet corner) -> points between them
	var corners := PackedInt32Array() # Local index by corner index
	var used: Array[HexCliffColumn] = []
	var break_corners: Array[Dictionary] = [] # Per used column: break id -> Vector2i(upper, lower) local indices
	for c: int in strip.columns.size():
		var column: HexCliffColumn = strip.columns[c]
		var previous: HexCliffColumn = null if used.is_empty() else used[used.size() - 1]
		# Without corners, columns with both ends shared would enclose nothing.
		if scale == 0.0 and previous and previous.top == column.top and previous.bottom == column.bottom:
			continue
		used.append(column)
		break_corners.append({})
		var top_key: Vector4i = HexTerrainSurface.get_lattice_key(rim[column.top])
		var bottom_key: Vector4i = HexTerrainSurface.get_lattice_key(base[column.bottom])
		if column.is_spoke:
			chains.append(_add_spoke(top_key, bottom_key, surface, vertices))
			continue
		var chain := PackedInt32Array([vertices.add(top_key, surface)])
		var end: int = vertices.add(bottom_key, surface)
		if scale > 0.0:
			var top: Vector3 = vertices.positions[chain[0]]
			var bottom: Vector3 = vertices.positions[end]
			var top_rest: Vector3 = vertices.rest[chain[0]]
			var bottom_rest: Vector3 = vertices.rest[end]
			var ends_push := Vector2(frame.get_out(bottom) - frame.get_out(bottom_rest), frame.get_out(top) - frame.get_out(top_rest))
			var shape: PackedVector3Array = HexCliffColumnShape.build(column, Vector3i(strip.id.x, strip.id.y, strip.id.z * 64 + c), top, bottom, ends_push, frame, settings, noise, scale)
			for i: int in range(shape.size() - 1, -1, -1):
				var t: float = (shape[i].y - bottom.y) / (top.y - bottom.y)
				var index: int = vertices.add_free(HexCliffStrip.get_corner_key(strip.id, corners.size()), bottom_rest.lerp(top_rest, t), shape[i])
				corners.append(index)
				chain.append(index)
			_find_breaks(column, chain, bottom.y, top.y - bottom.y, vertices, break_corners[break_corners.size() - 1])
		chain.append(end)
		chains.append(chain)
	var lefts: Array[PackedInt32Array] = []
	var rights: Array[PackedInt32Array] = []
	for u: int in used.size() - 1:
		var pair: Array[PackedInt32Array] = [chains[u], chains[u + 1]]
		_add_rim_side(rim, pair, used[u].top, used[u + 1].top, surface, vertices, between)
		_add_base_side(base, pair, used[u].bottom, used[u + 1].bottom, surface, vertices, between)
		_split_at_breaks(pair, break_corners[u], break_corners[u + 1], lefts, rights)
	var faces: PackedInt32Array = HexCliffStitcher.stitch_columns(lefts, rights, between, vertices.rest, vertices.positions, strip.outward)
	if not corners.is_empty() and not HexCliffSlope.enforce(faces, vertices.positions, vertices.free, strip.outward):
		return null
	corner_positions.clear()
	corner_rests.clear()
	for index: int in corners:
		corner_positions.append(vertices.positions[index])
		corner_rests.append(vertices.rest[index])
	var triangle := HexTerrainSurface.Triangle.new()
	triangle.is_cliff = true
	for index: int in faces:
		triangle.keys.append(vertices.keys[index])
	return triangle


# Local indices of the corners of each of column's breaks in chain, by break id: Vector2i(upper, lower).
# A kink's one corner is both.
static func _find_breaks(column: HexCliffColumn, chain: PackedInt32Array, bottom: float, height: float, vertices: _Vertices, found: Dictionary) -> void:
	for entry: Vector3 in column.breaks:
		var at: float = bottom + entry.x * height
		var rise: float = HexCliffColumnShape.LEDGE_RISE * entry.y
		var upper: int = _find_height(chain, at + rise, vertices)
		var lower: int = _find_height(chain, at - rise, vertices)
		if upper >= 0 and lower >= 0:
			found[int(entry.z)] = Vector2i(upper, lower)


static func _find_height(chain: PackedInt32Array, height: float, vertices: _Vertices) -> int:
	for index: int in chain:
		if absf(vertices.positions[index].y - height) < 1e-5:
			return index
	return -1


# Adds the pair as faces to join, cut at the breaks both columns share, so no face reaches from one
# side of a break to the other. A ledge gets a face pair of its own between its corners.
static func _split_at_breaks(pair: Array[PackedInt32Array], left_breaks: Dictionary, right_breaks: Dictionary, lefts: Array[PackedInt32Array], rights: Array[PackedInt32Array]) -> void:
	var left: PackedInt32Array = pair[0]
	var right: PackedInt32Array = pair[1]
	var cuts: Array[Vector4i] = [] # Chain positions: left upper, left lower, right upper, right lower
	for id: int in left_breaks:
		if not right_breaks.has(id):
			continue
		var l: Vector2i = left_breaks[id]
		var r: Vector2i = right_breaks[id]
		cuts.append(Vector4i(left.find(l.x), left.find(l.y), right.find(r.x), right.find(r.y)))
	cuts.sort_custom(func(a: Vector4i, b: Vector4i) -> bool: return a.x < b.x)
	var left_start: int = 0
	var right_start: int = 0
	for cut: Vector4i in cuts:
		# Skip cuts out of order on either side; the next pass still joins everything.
		if cut.x <= left_start or cut.z <= right_start or cut.y < cut.x or cut.w < cut.z:
			continue
		lefts.append(left.slice(left_start, cut.x + 1))
		rights.append(right.slice(right_start, cut.z + 1))
		if cut.y > cut.x or cut.w > cut.z:
			lefts.append(left.slice(cut.x, cut.y + 1))
			rights.append(right.slice(cut.z, cut.w + 1))
		left_start = cut.y
		right_start = cut.w
	lefts.append(left.slice(left_start))
	rights.append(right.slice(right_start))


# Spokes are shared, so they keep every band. They are straight, and every band joins the
# neighboring column level by level, so no long thin fans reach across the slab.
static func _add_spoke(top_key: Vector4i, bottom_key: Vector4i, surface: HexTerrainSurface, vertices: _Vertices) -> PackedInt32Array:
	var chain := PackedInt32Array()
	for vertex: Vector4i in surface.get_chain(Vector2i(top_key.x, top_key.y), Vector2i(bottom_key.x, bottom_key.y)):
		chain.append(vertices.add(vertex, surface))
	return chain


# Rim side of the face between a pair of columns, [left chain, right chain], from rim index from to to.
# A rim segment that is a cliff edge bends once displaced, so it joins the chain that reaches down
# from its high end: the pair then shares that end, and the stitcher joins its bands like corners.
# Other points between the column tops lie on a straight side.
static func _add_rim_side(rim: Array[Vector2i], pair: Array[PackedInt32Array], from: int, to: int, surface: HexTerrainSurface, vertices: _Vertices, between: Dictionary) -> void:
	var bend: PackedInt32Array = _get_bend(rim, from, to, surface, vertices)
	if bend.is_empty():
		_add_between(rim, from, to, surface, vertices, between)
	elif vertices.positions[bend[0]].y > vertices.positions[bend[bend.size() - 1]].y:
		pair[1] = bend + pair[1].slice(1)
	else:
		bend.reverse()
		pair[0] = bend + pair[0].slice(1)


# Base side of the face between a pair of columns. A bent base segment joins the chain whose bottom
# is its high end, reaching down to its low end.
static func _add_base_side(base: Array[Vector2i], pair: Array[PackedInt32Array], from: int, to: int, surface: HexTerrainSurface, vertices: _Vertices, between: Dictionary) -> void:
	var bend: PackedInt32Array = _get_bend(base, from, to, surface, vertices)
	if bend.is_empty():
		_add_between(base, from, to, surface, vertices, between)
		return
	var left: PackedInt32Array = pair[0]
	var right: PackedInt32Array = pair[1]
	if vertices.positions[bend[0]].y < vertices.positions[bend[bend.size() - 1]].y:
		bend.reverse()
		pair[1] = right.slice(0, right.size() - 1) + bend
	else:
		pair[0] = left.slice(0, left.size() - 1) + bend


# Chain of a rim or base segment that is a cliff edge, from index from to to. Empty for any other span.
static func _get_bend(row: Array[Vector2i], from: int, to: int, surface: HexTerrainSurface, vertices: _Vertices) -> PackedInt32Array:
	var bend := PackedInt32Array()
	if to - from != 1 or not surface.has_bands(row[from], row[to]):
		return bend
	for key: Vector4i in surface.get_chain(row[from], row[to]):
		bend.append(vertices.add(key, surface))
	return bend


# Points strictly between two column ends along the rim or base, listed under the pair of ends.
static func _add_between(row: Array[Vector2i], from: int, to: int, surface: HexTerrainSurface, vertices: _Vertices, between: Dictionary) -> void:
	var points := PackedInt32Array()
	for i: int in range(from + 1, to):
		points.append(vertices.add(HexTerrainSurface.get_lattice_key(row[i]), surface))
	if points.is_empty():
		return
	var start: int = vertices.add(HexTerrainSurface.get_lattice_key(row[from]), surface)
	var end: int = vertices.add(HexTerrainSurface.get_lattice_key(row[to]), surface)
	between[Vector2i(start, end)] = points


# Vertices of the strip's faces under local indices, for the stitcher.
class _Vertices:
	var keys: Array[Vector4i] = []
	var rest := PackedVector3Array()
	var positions := PackedVector3Array()
	var free := PackedByteArray() # 1 for the strip's own corners
	var _local: Dictionary = {} # Vertex key -> local index

	## Local index of a shared vertex, added on first use.
	func add(key: Vector4i, surface: HexTerrainSurface) -> int:
		var index: Variant = _local.get(key)
		if index != null:
			return index
		_local[key] = keys.size()
		keys.append(key)
		rest.append(surface.get_rest_position(key))
		positions.append(surface.get_position(key))
		free.append(0)
		return keys.size() - 1

	## Local index of a new corner of the strip's own.
	func add_free(key: Vector4i, rest_position: Vector3, position: Vector3) -> int:
		_local[key] = keys.size()
		keys.append(key)
		rest.append(rest_position)
		positions.append(position)
		free.append(1)
		return keys.size() - 1
