class_name HexCliffStitcher
extends Object
## Static triangulation of a lattice triangle whose edges carry band vertices.
## Corners and creases are joined into a few large triangles first. Other band vertices lie on
## straight lines between creases, so they are filled in without bending those triangles.


## chains[i]: local vertex indices along edge i, from corner i to corner (i + 1) % 3, ends included.
## rest: undisplaced positions by local index. All lie on the triangle's plane.
## is_crease: 1 for corners and creases, by local index.
## Returns index triples wound like corners 0, 1, 2.
static func stitch(chains: Array[PackedInt32Array], rest: PackedVector3Array, is_crease: PackedByteArray) -> PackedInt32Array:
	var crease_chains: Array[PackedInt32Array] = []
	var between: Dictionary = {} # Vector2i(crease, next crease) -> vertices between them
	for chain: PackedInt32Array in chains:
		var creases := PackedInt32Array([chain[0]])
		var last: int = 0
		for i: int in range(1, chain.size()):
			if not is_crease[chain[i]]:
				continue
			if i - last > 1:
				between[Vector2i(chain[last], chain[i])] = chain.slice(last + 1, i)
			creases.append(chain[i])
			last = i
		crease_chains.append(creases)
	var large: PackedInt32Array = _stitch_chains(crease_chains, rest)
	var result := PackedInt32Array()
	for t: int in range(0, large.size(), 3):
		# Each vertex records which sides of the large triangle it lies on, as bits.
		# Corner k is on sides k and k - 1; points between corners k and k + 1 are on side k.
		var polygon := PackedInt32Array()
		var sides := PackedInt32Array()
		for k: int in 3:
			var a: int = large[t + k]
			var b: int = large[t + (k + 1) % 3]
			polygon.append(a)
			sides.append((1 << k) | (1 << ((k + 2) % 3)))
			for v: int in _get_between(between, a, b):
				polygon.append(v)
				sides.append(1 << k)
		_clip_ears(polygon, sides, rest, result)
	return result


# Large triangles between chains of corners and creases, wound like corners 0, 1, 2.
static func _stitch_chains(chains: Array[PackedInt32Array], rest: PackedVector3Array) -> PackedInt32Array:
	var split: Array[int] = []
	for i: int in 3:
		if chains[i].size() > 2:
			split.append(i)
	var result := PackedInt32Array()
	match split.size():
		0:
			_add(result, chains[0][0], chains[1][0], chains[2][0])
		1:
			result = _fan(chains[(split[0] + 2) % 3][0], chains[split[0]])
		2:
			# Apex: the corner opposite the unsplit edge.
			var unsplit: int = 3 - split[0] - split[1]
			var apex: int = (unsplit + 2) % 3
			result = _zip(_get_chain(chains, apex, (apex + 1) % 3), _get_chain(chains, apex, (apex + 2) % 3), rest)
		3:
			var order: Array[int] = [0, 1, 2]
			order.sort_custom(func(a: int, b: int) -> bool: return rest[chains[a][0]].y > rest[chains[b][0]].y)
			var top: int = order[0]
			var middle: int = order[1]
			var bottom: int = order[2]
			var long_chain: PackedInt32Array = _get_chain(chains, top, bottom)
			var bent_chain: PackedInt32Array = _get_chain(chains, top, middle)
			bent_chain.append_array(_get_chain(chains, middle, bottom).slice(1))
			result = _zip(long_chain, bent_chain, rest)
	return _orient(result, rest, chains[0][0], chains[1][0], chains[2][0])


# Chain from one corner to another, reversing the stored edge if needed.
static func _get_chain(chains: Array[PackedInt32Array], from: int, to: int) -> PackedInt32Array:
	if to == (from + 1) % 3:
		return chains[from].duplicate()
	var reversed: PackedInt32Array = chains[to].duplicate()
	reversed.reverse()
	return reversed


# Vertices strictly between a and b on a chain, ordered from a. Empty if a-b isn't a chain segment.
static func _get_between(between: Dictionary, a: int, b: int) -> PackedInt32Array:
	var forward: Variant = between.get(Vector2i(a, b))
	if forward != null:
		return forward
	var backward: Variant = between.get(Vector2i(b, a))
	if backward == null:
		return PackedInt32Array()
	var reversed: PackedInt32Array = (backward as PackedInt32Array).duplicate()
	reversed.reverse()
	return reversed


static func _fan(apex: int, chain: PackedInt32Array) -> PackedInt32Array:
	var result := PackedInt32Array()
	for i: int in chain.size() - 1:
		_add(result, apex, chain[i], chain[i + 1])
	return result


# Triangulates between two chains that start at the same vertex, pairing vertices by height.
# If they also end at the same vertex, the last triangle closes on it.
static func _zip(first: PackedInt32Array, second: PackedInt32Array, rest: PackedVector3Array) -> PackedInt32Array:
	var result := PackedInt32Array()
	var shared_end: bool = first[first.size() - 1] == second[second.size() - 1]
	var trim: int = 2 if shared_end else 1
	var last_first: int = first.size() - trim
	var last_second: int = second.size() - trim
	var start_y: float = rest[first[0]].y
	_add(result, first[0], first[1], second[1])
	var i: int = 1
	var j: int = 1
	while i < last_first or j < last_second:
		var advance_first: bool
		if i == last_first:
			advance_first = false
		elif j == last_second:
			advance_first = true
		else:
			advance_first = absf(rest[first[i + 1]].y - start_y) <= absf(rest[second[j + 1]].y - start_y)
		if advance_first:
			_add(result, first[i], first[i + 1], second[j])
			i += 1
		else:
			_add(result, first[i], second[j + 1], second[j])
			j += 1
	if shared_end:
		_add(result, first[last_first], second[last_second], first[first.size() - 1])
	return result


# Triangulates a large triangle with extra points on its sides, keeping its winding.
# sides: per polygon vertex, bits of the sides it lies on. Points sharing a side are collinear.
static func _clip_ears(polygon: PackedInt32Array, sides: PackedInt32Array, rest: PackedVector3Array, result: PackedInt32Array) -> void:
	var remaining := PackedInt32Array() # Positions in polygon
	for i: int in polygon.size():
		remaining.append(i)
	while remaining.size() >= 3:
		var count: int = remaining.size()
		var clipped: bool = false
		for i: int in count:
			var previous: int = remaining[(i + count - 1) % count]
			var current: int = remaining[i]
			var next: int = remaining[(i + 1) % count]
			if _is_ear(remaining, previous, current, next, polygon, sides, rest):
				_add(result, polygon[previous], polygon[current], polygon[next])
				remaining.remove_at(i)
				clipped = true
				break
		if not clipped:
			return # Only one side's points left; they are collinear.


# Not all on one side, and the new edge a-c passes through no other remaining vertex.
static func _is_ear(remaining: PackedInt32Array, a: int, b: int, c: int, polygon: PackedInt32Array, sides: PackedInt32Array, rest: PackedVector3Array) -> bool:
	if sides[a] & sides[b] & sides[c]:
		return false
	var shared: int = sides[a] & sides[c]
	if not shared:
		return true
	# a and c lie on one side, so the new edge runs along it. No vertex may sit between them.
	var start: Vector3 = rest[polygon[a]]
	var along: Vector3 = rest[polygon[c]] - start
	for v: int in remaining:
		if v == a or v == b or v == c or not sides[v] & shared:
			continue
		var t: float = (rest[polygon[v]] - start).dot(along) / along.length_squared()
		if t > 0.0 and t < 1.0:
			return false
	return true


# Flips triangles wound against the corners. Works because all rest points are coplanar.
static func _orient(triangles: PackedInt32Array, rest: PackedVector3Array, a: int, b: int, c: int) -> PackedInt32Array:
	var reference: Vector3 = (rest[b] - rest[a]).cross(rest[c] - rest[a])
	for i: int in range(0, triangles.size(), 3):
		var p: Vector3 = rest[triangles[i]]
		var face: Vector3 = (rest[triangles[i + 1]] - p).cross(rest[triangles[i + 2]] - p)
		if face.dot(reference) < 0.0:
			var swap: int = triangles[i + 1]
			triangles[i + 1] = triangles[i + 2]
			triangles[i + 2] = swap
	return triangles


static func _add(target: PackedInt32Array, a: int, b: int, c: int) -> void:
	target.append(a)
	target.append(b)
	target.append(c)
