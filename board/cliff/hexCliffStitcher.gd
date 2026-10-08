class_name HexCliffStitcher
extends Object
## Static triangulation of cliff faces whose edges carry band vertices.
## Corners and creases are joined into a few large triangles first. Other band vertices lie on
## straight lines between creases, so they are filled in without bending those triangles.
## Where two chains are joined, the join order is chosen to avoid faces that look down (overhangs).

# Ladder costs against rung height differences: a face looking down, per unit of downward normal,
# and a thin face, per radian its smallest angle falls short of _SLIVER_ANGLE.
# A face turned away from outside, where that's known, or with no area, rules its step out.
const _FOLD_COST: float = 1e9
# Smallest angle, in radians, below which a face counts as having no area.
const _FLAT_ANGLE: float = 0.002
const _OVERHANG_WEIGHT: float = 1000.0
const _SLIVER_WEIGHT: float = 2.0
const _SLIVER_ANGLE: float = 0.35


## chains[i]: local vertex indices along edge i, from corner i to corner (i + 1) % 3, ends included.
## rest: undisplaced positions by local index. All lie on the triangle's plane.
## positions: final positions by local index.
## is_crease: 1 for corners and creases, by local index.
## Returns index triples wound like corners 0, 1, 2.
static func stitch(chains: Array[PackedInt32Array], rest: PackedVector3Array, positions: PackedVector3Array, is_crease: PackedByteArray) -> PackedInt32Array:
	var result: PackedInt32Array = _stitch_creases(chains, rest, positions, is_crease)
	var overhang: float = _get_overhang(result, positions)
	if overhang > 0.0:
		# No large faces avoid looking down here. Every band as a corner gives more ways to join.
		var every := PackedByteArray()
		every.resize(is_crease.size())
		every.fill(1)
		var fine: PackedInt32Array = _stitch_creases(chains, rest, positions, every)
		if _get_overhang(fine, positions) < overhang:
			result = fine
	return result


## Faces of a cliff strip, joined pair by pair: lefts[c] to rights[c], each a chain of local indices
## from rim to base, with lefts before rights along the strip. between: points on the straight line
## between two facet corners, keyed Vector2i(corner, next corner). positions: final positions by
## local index. outward: horizontal direction the face looks.
## Returns front-facing index triples.
static func stitch_columns(lefts: Array[PackedInt32Array], rights: Array[PackedInt32Array], between: Dictionary, rest: PackedVector3Array, positions: PackedVector3Array, outward: Vector3) -> PackedInt32Array:
	# Every triangle turns the same way in (along strip, height). Decide once, on a large steep
	# triangle, whether that way is front-facing: its upward face must point out of the cliff.
	var first: PackedInt32Array = lefts[0]
	var first_top: Vector3 = rest[first[0]]
	var first_bottom: Vector3 = rest[first[first.size() - 1]]
	var last_top: Vector3 = rest[rights[rights.size() - 1][0]]
	var flip: bool = (last_top - first_top).cross(first_bottom - first_top).dot(outward) < 0.0
	var face_sign: float = -1.0 if flip else 1.0
	var result := PackedInt32Array()
	for c: int in lefts.size():
		_fill(_zip_columns(lefts[c], rights[c], positions, face_sign, outward), between, rest, positions, outward * face_sign, result)
	if flip:
		for i: int in range(0, result.size(), 3):
			var swap: int = result[i + 1]
			result[i + 1] = result[i + 2]
			result[i + 2] = swap
	return result


# Joins corners and creases into large triangles, then fills in the other bands.
static func _stitch_creases(chains: Array[PackedInt32Array], rest: PackedVector3Array, positions: PackedVector3Array, is_crease: PackedByteArray) -> PackedInt32Array:
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
	var result := PackedInt32Array()
	_fill(_stitch_chains(crease_chains, rest, positions), between, rest, positions, Vector3.ZERO, result)
	return result


# Downward area of front-facing triangles: sum of area times how far each normal points down.
static func _get_overhang(triangles: PackedInt32Array, positions: PackedVector3Array) -> float:
	var total: float = 0.0
	for i: int in range(0, triangles.size(), 3):
		var origin: Vector3 = positions[triangles[i]]
		var normal: Vector3 = (positions[triangles[i + 2]] - origin).cross(positions[triangles[i + 1]] - origin)
		total += maxf(0.0, -normal.y)
	return total


# Splits large triangles around the points lying on their sides, keeping each one flat.
# facing: direction listed triangles' (c - a).cross(b - a) should share, or zero for any.
static func _fill(large: PackedInt32Array, between: Dictionary, rest: PackedVector3Array, positions: PackedVector3Array, facing: Vector3, result: PackedInt32Array) -> void:
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
		_clip_ears(polygon, sides, rest, positions, facing, result)


# Large triangles between two columns, each a chain from top to bottom.
# The columns may share their top or their bottom vertex. With left before right along the strip,
# every triangle turns counterclockwise in (along strip, height).
# face_sign: 1 if that way is front-facing, -1 if not. outward: horizontal direction the face looks.
static func _zip_columns(left: PackedInt32Array, right: PackedInt32Array, positions: PackedVector3Array, face_sign: float, outward: Vector3) -> PackedInt32Array:
	var result := PackedInt32Array()
	var shared_top: bool = left[0] == right[0]
	var shared_bottom: bool = left[left.size() - 1] == right[right.size() - 1]
	if shared_top and shared_bottom and (left.size() == 2 or right.size() == 2):
		return _fan_edge(left, right, positions, face_sign, outward)
	var trim: int = 2 if shared_bottom else 1
	var last_left: int = left.size() - trim
	var last_right: int = right.size() - trim
	var start: int = 0
	if shared_top:
		_add(result, left[0], left[1], right[1])
		start = 1
	result.append_array(_ladder(left, right, start, last_left, last_right, positions, face_sign, outward))
	if shared_bottom:
		_add(result, left[last_left], left[left.size() - 1], right[last_right])
	return result


# Columns sharing both ends, one of them a single edge: the other is fanned from whichever end of
# that edge sees it best. Triangles are listed like _ladder()'s.
static func _fan_edge(left: PackedInt32Array, right: PackedInt32Array, positions: PackedVector3Array, face_sign: float, outward: Vector3) -> PackedInt32Array:
	var best := PackedInt32Array()
	var best_cost: float = INF
	for end: int in 2:
		var fan := PackedInt32Array()
		var cost: float = 0.0
		if left.size() == 2:
			var apex: int = left[end]
			for j: int in right.size() - 1:
				if right[j] != apex and right[j + 1] != apex:
					_add(fan, apex, right[j + 1], right[j])
					cost += _get_step_cost(apex, right[j + 1], right[j], apex, apex, positions, face_sign, outward)
		else:
			var apex: int = right[end]
			for i: int in left.size() - 1:
				if left[i] != apex and left[i + 1] != apex:
					_add(fan, left[i], left[i + 1], apex)
					cost += _get_step_cost(left[i], left[i + 1], apex, apex, apex, positions, face_sign, outward)
		if cost < best_cost:
			best = fan
			best_cost = cost
	return best


# Triangles joining two chains, from rung (first[start], second[start]) to rung
# (first[last_first], second[last_second]). Each step moves one end of the rung along its chain,
# adding (first[i], first[i + 1], second[j]) or (first[i], second[j + 1], second[j]).
# Chains straight in rest make every order of steps a valid triangulation. Chains that bend, like a
# strip's columns, can turn a face away from outside; outward rules those steps out.
# Picks the order with the least overhang, then the most level rungs.
# face_sign: 1 if those triangles are front-facing as listed, -1 if not.
# outward: horizontal direction the faces look, or zero if they may look any way.
static func _ladder(first: PackedInt32Array, second: PackedInt32Array, start: int, last_first: int, last_second: int, positions: PackedVector3Array, face_sign: float, outward: Vector3) -> PackedInt32Array:
	var width: int = last_second + 1
	var size: int = (last_first + 1) * width
	var cost := PackedFloat32Array() # Least cost to reach rung (i, j), at i * width + j
	var from_first := PackedByteArray() # 1 if that rung was reached by a step along first
	cost.resize(size)
	cost.fill(INF)
	from_first.resize(size)
	cost[start * width + start] = 0.0
	for i: int in range(start, last_first + 1):
		for j: int in range(start, last_second + 1):
			var here: float = cost[i * width + j]
			if here == INF:
				continue
			if i < last_first:
				var along_first: float = here + _get_step_cost(first[i], first[i + 1], second[j], first[i + 1], second[j], positions, face_sign, outward)
				if along_first < cost[(i + 1) * width + j]:
					cost[(i + 1) * width + j] = along_first
					from_first[(i + 1) * width + j] = 1
			if j < last_second:
				var along_second: float = here + _get_step_cost(first[i], second[j + 1], second[j], first[i], second[j + 1], positions, face_sign, outward)
				if along_second < cost[i * width + j + 1]:
					cost[i * width + j + 1] = along_second
					from_first[i * width + j + 1] = 0
	# Walk back from the last rung, listing each triangle backward so one reverse fixes both orders.
	var steps := PackedInt32Array()
	var i: int = last_first
	var j: int = last_second
	while i > start or j > start:
		if from_first[i * width + j]:
			i -= 1
			steps.append_array([second[j], first[i + 1], first[i]])
		else:
			j -= 1
			steps.append_array([second[j], second[j + 1], first[i]])
	steps.reverse()
	return steps


# Cost of adding triangle a, b, c and moving the rung to (rung_first, rung_second).
static func _get_step_cost(a: int, b: int, c: int, rung_first: int, rung_second: int, positions: PackedVector3Array, face_sign: float, outward: Vector3) -> float:
	var origin: Vector3 = positions[a]
	var normal: Vector3 = (positions[c] - origin).cross(positions[b] - origin) * face_sign
	if normal.dot(outward) < 0.0:
		return _FOLD_COST
	var smallest: float = _get_smallest_angle(positions[a], positions[b], positions[c])
	if smallest < _FLAT_ANGLE:
		return _FOLD_COST
	var length: float = normal.length()
	var overhang: float = maxf(0.0, -normal.y / length) if length > 1e-9 else 0.0
	var thinness: float = maxf(0.0, _SLIVER_ANGLE - smallest)
	return overhang * _OVERHANG_WEIGHT + thinness * _SLIVER_WEIGHT + absf(positions[rung_first].y - positions[rung_second].y)


static func _get_smallest_angle(a: Vector3, b: Vector3, c: Vector3) -> float:
	return minf((b - a).angle_to(c - a), minf((c - b).angle_to(a - b), (a - c).angle_to(b - c)))


# Large triangles between chains of corners and creases, wound like corners 0, 1, 2.
static func _stitch_chains(chains: Array[PackedInt32Array], rest: PackedVector3Array, positions: PackedVector3Array) -> PackedInt32Array:
	var split: Array[int] = []
	for i: int in 3:
		if chains[i].size() > 2:
			split.append(i)
	var result := PackedInt32Array()
	var corner: Vector3 = rest[chains[0][0]]
	var front: Vector3 = (rest[chains[1][0]] - corner).cross(rest[chains[2][0]] - corner)
	match split.size():
		0:
			_add(result, chains[0][0], chains[1][0], chains[2][0])
		1:
			result = _fan(chains[(split[0] + 2) % 3][0], chains[split[0]])
		2:
			# Apex: the corner opposite the unsplit edge.
			var unsplit: int = 3 - split[0] - split[1]
			var apex: int = (unsplit + 2) % 3
			result = _zip(_get_chain(chains, apex, (apex + 1) % 3), _get_chain(chains, apex, (apex + 2) % 3), rest, positions, front)
		3:
			var order: Array[int] = [0, 1, 2]
			order.sort_custom(func(a: int, b: int) -> bool: return rest[chains[a][0]].y > rest[chains[b][0]].y)
			var top: int = order[0]
			var middle: int = order[1]
			var bottom: int = order[2]
			var long_chain: PackedInt32Array = _get_chain(chains, top, bottom)
			var bent_chain: PackedInt32Array = _get_chain(chains, top, middle)
			bent_chain.append_array(_get_chain(chains, middle, bottom).slice(1))
			result = _zip(long_chain, bent_chain, rest, positions, front)
	return _orient(result, rest, front)


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


# Triangulates between two chains that start at the same vertex.
# If they also end at the same vertex, the last triangle closes on it.
# front: normal that front-facing triangles share in rest.
static func _zip(first: PackedInt32Array, second: PackedInt32Array, rest: PackedVector3Array, positions: PackedVector3Array, front: Vector3) -> PackedInt32Array:
	var result := PackedInt32Array()
	var shared_end: bool = first[first.size() - 1] == second[second.size() - 1]
	var trim: int = 2 if shared_end else 1
	_add(result, first[0], first[1], second[1])
	# All triangles between the chains turn the same way as the first.
	var origin: Vector3 = rest[first[0]]
	var turn: float = (rest[first[1]] - origin).cross(rest[second[1]] - origin).dot(front)
	result.append_array(_ladder(first, second, 1, first.size() - trim, second.size() - trim, positions, 1.0 if turn > 0.0 else -1.0, Vector3.ZERO))
	if shared_end:
		_add(result, first[first.size() - 2], second[second.size() - 2], first[first.size() - 1])
	return result


# Triangulates a large triangle with extra points on its sides, keeping its winding.
# sides: per polygon vertex, bits of the sides it lies on. Points sharing a side are collinear in rest.
# A side that is a cliff edge bends once displaced, so with facing set, ears facing along it go first.
static func _clip_ears(polygon: PackedInt32Array, sides: PackedInt32Array, rest: PackedVector3Array, positions: PackedVector3Array, facing: Vector3, result: PackedInt32Array) -> void:
	var remaining := PackedInt32Array() # Positions in polygon
	for i: int in polygon.size():
		remaining.append(i)
	while remaining.size() >= 3:
		var count: int = remaining.size()
		var ear: int = -1
		for i: int in count:
			var previous: int = remaining[(i + count - 1) % count]
			var current: int = remaining[i]
			var next: int = remaining[(i + 1) % count]
			if not _is_ear(remaining, previous, current, next, polygon, sides, rest):
				continue
			var a: Vector3 = positions[polygon[previous]]
			if (positions[polygon[next]] - a).cross(positions[polygon[current]] - a).dot(facing) >= 0.0:
				ear = i
				break
			if ear < 0:
				ear = i
		if ear < 0:
			return # Only one side's points left; they are collinear.
		_add(result, polygon[remaining[(ear + count - 1) % count]], polygon[remaining[ear]], polygon[remaining[(ear + 1) % count]])
		remaining.remove_at(ear)


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


# Flips triangles wound against front. Works because all rest points are coplanar.
static func _orient(triangles: PackedInt32Array, rest: PackedVector3Array, front: Vector3) -> PackedInt32Array:
	for i: int in range(0, triangles.size(), 3):
		var p: Vector3 = rest[triangles[i]]
		var face: Vector3 = (rest[triangles[i + 1]] - p).cross(rest[triangles[i + 2]] - p)
		if face.dot(front) < 0.0:
			var swap: int = triangles[i + 1]
			triangles[i + 1] = triangles[i + 2]
			triangles[i + 2] = swap
	return triangles


static func _add(target: PackedInt32Array, a: int, b: int, c: int) -> void:
	target.append(a)
	target.append(b)
	target.append(c)
