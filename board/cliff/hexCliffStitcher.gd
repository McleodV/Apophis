class_name HexCliffStitcher
extends Object
## Static triangulation of a lattice triangle whose edges carry band vertices.


## chains[i]: local vertex indices along edge i, from corner i to corner (i + 1) % 3, ends included.
## rest: undisplaced positions by local index. All lie on the triangle's plane.
## Returns index triples wound like corners 0, 1, 2.
static func stitch(chains: Array[PackedInt32Array], rest: PackedVector3Array) -> PackedInt32Array:
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
