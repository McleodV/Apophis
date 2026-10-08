class_name HexCliffStripFaces
extends Object
## Static assembly of a cliff strip's faces from its columns.
## Spoke columns keep their shared bands. Other columns get the strip's own corners; a merging
## column ends on a corner of its neighbor. Neighboring columns are joined pair by pair
## (HexCliffStitcher.stitch_columns()); rim and base points between column ends lie on the faces'
## straight sides. Then HexCliffSlope keeps every face upright.


## The faces of strip, or null if a face with a free corner can't be kept upright.
## scale: 1 = full corner shape, lower calms it (see HexCliffColumnShape.build()), 0 = no corners:
## columns run straight from rim to base. A merging column then runs to its neighbor's base point.
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
	var used: Array[HexCliffColumn] = []
	var order := PackedInt32Array() # Index in strip.columns, by used index
	var merging := PackedInt32Array() # Merge side by used index: 0 when there are no corners to merge into
	for c: int in strip.columns.size():
		var column: HexCliffColumn = strip.columns[c]
		var previous: HexCliffColumn = null if used.is_empty() else used[used.size() - 1]
		# Without corners, columns with both ends shared would enclose nothing.
		if scale == 0.0 and previous and previous.top == column.top and previous.bottom == column.bottom:
			continue
		used.append(column)
		order.append(c)
		merging.append(column.merge_side if scale > 0.0 else 0)
	var vertices := _Vertices.new()
	var between: Dictionary = {} # Vector2i(facet corner, next facet corner) -> points between them
	var corners := PackedInt32Array() # Local index by corner index
	var chains: Array[PackedInt32Array] = []
	chains.resize(used.size())
	var merges := PackedInt32Array() # Per used column: index of its merge corner in the neighbor's chain, or -1
	merges.resize(used.size())
	merges.fill(-1)
	# Columns running to the base first, so merging ones can end on their corners.
	for second: bool in [false, true]:
		for u: int in used.size():
			var column: HexCliffColumn = used[u]
			if (merging[u] != 0) != second:
				continue
			var top_key: Vector4i = HexTerrainSurface.get_lattice_key(rim[column.top])
			var bottom_key: Vector4i = HexTerrainSurface.get_lattice_key(base[column.bottom])
			if column.is_spoke:
				chains[u] = _add_spoke(top_key, bottom_key, surface, vertices, between)
				continue
			var chain := PackedInt32Array([vertices.add(top_key, surface)])
			var top: Vector3 = surface.get_position(top_key)
			var wall := Vector2(surface.get_position(bottom_key).y, top.y)
			var end: int = vertices.add(bottom_key, surface)
			if second:
				var target: PackedInt32Array = chains[u + merging[u]]
				merges[u] = _get_merge_corner(target, lerpf(wall.x, wall.y, column.merge_height), vertices)
				end = target[merges[u]]
			if scale > 0.0:
				var bottom: Vector3 = vertices.positions[end]
				var top_rest: Vector3 = surface.get_rest_position(top_key)
				var bottom_rest: Vector3 = vertices.rest[end]
				var shape: PackedVector3Array = HexCliffColumnShape.build(column, Vector3i(strip.id.x, strip.id.y, strip.id.z * 64 + order[u]), top, bottom, wall, frame, settings, noise, scale)
				for i: int in range(shape.size() - 1, -1, -1):
					var t: float = (shape[i].y - bottom.y) / (top.y - bottom.y)
					var index: int = vertices.add_free(HexCliffStrip.get_corner_key(strip.id, corners.size()), bottom_rest.lerp(top_rest, t), shape[i])
					corners.append(index)
					chain.append(index)
			chain.append(end)
			chains[u] = chain
	var lefts: Array[PackedInt32Array] = []
	var rights: Array[PackedInt32Array] = []
	for u: int in used.size() - 1:
		var pair: Array[PackedInt32Array]
		# A merging column and its neighbor share the merge corner, so their face has no base side.
		if merging[u + 1] < 0:
			pair = [chains[u].slice(0, merges[u + 1] + 1), chains[u + 1]]
		elif merging[u] > 0:
			pair = [chains[u], chains[u + 1].slice(0, merges[u] + 1)]
		else:
			pair = [_get_side(chains, merges, merging, u, 1), _get_side(chains, merges, merging, u + 1, -1)]
			_add_base_side(base, pair, used[u].bottom, used[u + 1].bottom, surface, vertices, between)
		_add_rim_side(rim, pair, used[u].top, used[u + 1].top, surface, vertices, between)
		lefts.append(pair[0])
		rights.append(pair[1])
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


# Chain bounding the face beside used column u, rim to base. toward: 1 for the face after u, -1 for
# the face before it. Seen from the side away from the neighbor it merges into, a merging column
# continues down that neighbor.
static func _get_side(chains: Array[PackedInt32Array], merges: PackedInt32Array, merging: PackedInt32Array, u: int, toward: int) -> PackedInt32Array:
	var side: int = merging[u]
	if side == 0 or side == toward:
		return chains[u]
	var target: PackedInt32Array = chains[u + side]
	return chains[u] + target.slice(merges[u] + 1)


# Index in chain of the corner nearest height, not counting its ends.
static func _get_merge_corner(chain: PackedInt32Array, height: float, vertices: _Vertices) -> int:
	var best: int = 1
	for i: int in range(2, chain.size() - 1):
		if absf(vertices.positions[chain[i]].y - height) < absf(vertices.positions[chain[best]].y - height):
			best = i
	return best


# Spokes are shared, so they keep every band. Bands that aren't facet corners lie between corners.
static func _add_spoke(top_key: Vector4i, bottom_key: Vector4i, surface: HexTerrainSurface, vertices: _Vertices, between: Dictionary) -> PackedInt32Array:
	var chain := PackedInt32Array()
	var pending := PackedInt32Array()
	for vertex: Vector4i in surface.get_chain(Vector2i(top_key.x, top_key.y), Vector2i(bottom_key.x, bottom_key.y)):
		var index: int = vertices.add(vertex, surface)
		if HexTerrainSurface.is_lattice_key(vertex) or surface.is_crease_key(vertex):
			if not pending.is_empty():
				between[Vector2i(chain[chain.size() - 1], index)] = pending
				pending = PackedInt32Array()
			chain.append(index)
		else:
			pending.append(index)
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
