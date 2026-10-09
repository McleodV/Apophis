class_name HexCliffSlabPlanes
extends Object
## Static choice of the flat planes of a run of slabs along a cliff strip.
## Neighboring slabs differ in depth, so the narrow faces of the seam between them look sideways.
## Both edges of a seam share one end point (see HexCliffColumnLayout); the seam closes exactly
## there and opens toward its other end. A slab next to a spoke passes through the spoke, so the
## wall stays flat up to the hex corner.
## Pushes stay between 0 and depth at the rim and base where they can, since rim and base points
## take them. Each plane leans back less than the wall's own run per height, so no face leans out going up.

# Hash seed offsets.
const _SEED: int = 3313
# Fit weights: anchors a plane must pass through, targets it should, and its preferred turn.
const _ANCHOR_WEIGHT: float = 10000.0
const _TARGET_WEIGHT: float = 1.0
const _TURN_WEIGHT: float = 0.01
# Share of the wall's run per height a plane may lean back by. Keeps faces from looking down.
const _MAX_LEAN: float = 0.8
# Break heights, as shares of the wall, and how far a break may slant across a slab.
const _BREAK_LOW: float = 0.35
const _BREAK_HIGH: float = 0.7
const _BREAK_SLANT: float = 0.15
# Deepest ledge, as a share of depth.
const _LEDGE_DEPTH: float = 0.7
# A split seam keeps this far from its slab's edges, in lattice steps. Leaves room for the inner
# columns beside both seams (see HexCliffColumnLayout).
const _SPLIT_MARGIN: float = 1.0
# A spoke must run at least this far along the wall per height to hinge a ledge on.
const _MIN_HINGE: float = 0.05
# Turns tried for the slab before the right spoke's, and the cost per unit of turn away from the preferred one.
const _TURN_SAMPLES: int = 9
const _PREFERENCE: float = 0.001


## Gives each slab its planes, left to right.
## key: unique per run; seeds its randomness. depth: most a slab stands out at the rim or base.
## run: the wall's horizontal run from base to rim, in world units. gap: split seam width, in lattice steps.
## left_spoke, right_spoke: the spoke bounding the run on that side as [rim, base], each
## Vector2(along, push), or empty if a forced column bounds it.
## The slab on the right spoke has no freedom left, so the slab before it turns to keep it in range.
static func assign(slabs: Array[HexCliffSlab], key: Vector3i, settings: HexCliffSettings, depth: float, run: float, gap: float, left_spoke: PackedVector2Array, right_spoke: PackedVector2Array) -> void:
	var seed_value: int = settings.noise_seed + _SEED
	var last: int = slabs.size() - 1
	for k: int in slabs.size():
		var slab: HexCliffSlab = slabs[k]
		var slab_key := Vector3i(key.x, key.y, key.z * 64 + k)
		var anchors := PackedVector3Array() # (along, height, push)
		var targets := PackedVector3Array()
		var hinge := PackedVector2Array()
		if k == 0 and not left_spoke.is_empty():
			_add_line(anchors, left_spoke)
			hinge = left_spoke
		elif k == 0:
			targets.append(Vector3(slab.left, 1.0, depth * HexCliffNoise.hash01(key.x, key.y, key.z * 64, seed_value)))
			targets.append(Vector3(slab.left, 0.0, depth * HexCliffNoise.hash01(key.x, key.y, key.z * 64, seed_value + 1)))
		else:
			_add_seam(anchors, targets, slabs[k - 1], slab, slab_key, settings, depth)
		if k == last and not right_spoke.is_empty():
			_add_line(anchors, right_spoke)
			if hinge.is_empty():
				hinge = right_spoke
		var turns: Vector3 = _get_turns(slab, anchors + targets, slab_key, settings, depth)
		var turn: float = turns.z
		if k == last - 1 and not right_spoke.is_empty():
			turn = _get_turn_for_next(slab, slabs[last], anchors, targets, turns, Vector3i(key.x, key.y, key.z * 64 + last), slab_key, settings, depth, run, gap, hinge, right_spoke)
		_plan(slab, anchors, targets, turn, slab_key, settings, depth, run, gap, hinge)


# Sets the slab's planes and break from scratch.
static func _plan(slab: HexCliffSlab, anchors: PackedVector3Array, targets: PackedVector3Array, turn: float, key: Vector3i, settings: HexCliffSettings, depth: float, run: float, gap: float, hinge: PackedVector2Array) -> void:
	slab.upper = _fit(slab, anchors, targets, turn)
	slab.lower = slab.upper
	slab.split_upper = null
	slab.split_at = INF
	slab.split_turns_left = false
	slab.break_height = 2.0
	slab.break_slope = 0.0
	slab.has_ledge = false
	_add_break(slab, key, settings, depth, run, gap, hinge)


# Turn for slab that keeps both it and next, the slab on the right spoke, nearest the push range.
# Ties go to the turn nearest the preferred one.
static func _get_turn_for_next(slab: HexCliffSlab, next: HexCliffSlab, anchors: PackedVector3Array, targets: PackedVector3Array, turns: Vector3, next_key: Vector3i, key: Vector3i, settings: HexCliffSettings, depth: float, run: float, gap: float, hinge: PackedVector2Array, right_spoke: PackedVector2Array) -> float:
	var best: float = turns.z
	var best_cost: float = INF
	for i: int in _TURN_SAMPLES + 1:
		var turn: float = turns.z if i == _TURN_SAMPLES else lerpf(turns.x, turns.y, float(i) / (_TURN_SAMPLES - 1))
		_plan(slab, anchors, targets, turn, key, settings, depth, run, gap, hinge)
		var next_anchors := PackedVector3Array()
		var next_targets := PackedVector3Array()
		_add_seam(next_anchors, next_targets, slab, next, next_key, settings, depth)
		_add_line(next_anchors, right_spoke)
		var plane: HexCliffPlane = _fit(next, next_anchors, next_targets, 0.0)
		var cost: float = _get_excess(slab.upper, slab, depth) + _get_excess(slab.lower, slab, depth) + _get_excess(plane, next, depth)
		cost += _PREFERENCE * absf(turn - turns.z)
		if cost < best_cost:
			best_cost = cost
			best = turn
	return best


static func _add_line(anchors: PackedVector3Array, line: PackedVector2Array) -> void:
	anchors.append(Vector3(line[0].x, 1.0, line[0].y))
	anchors.append(Vector3(line[1].x, 0.0, line[1].y))


# Constraints from the seam to the previous slab: an anchor where the seam's edges share an end,
# and a target a step away from the previous slab where it opens.
static func _add_seam(anchors: PackedVector3Array, targets: PackedVector3Array, previous: HexCliffSlab, slab: HexCliffSlab, key: Vector3i, settings: HexCliffSettings, depth: float) -> void:
	var seed_value: int = settings.noise_seed + _SEED + 2
	for end: int in 2:
		var height: float = 1.0 - end # Rim, then base
		var offset: float = 0.5 * end # Base points sit half a step along
		var shared: bool = roundi(previous.right - offset) == roundi(slab.left - offset)
		if shared:
			var along: float = roundi(slab.left - offset) + offset
			anchors.append(Vector3(along, height, _get_previous(previous, along, height)))
			continue
		var value: float = _get_previous(previous, previous.right, height)
		var sign: float = 1.0 if HexCliffNoise.hash01(key.x, key.y, key.z, seed_value) < 0.5 else -1.0
		var size: float = HexCliffNoise.hash01(key.x, key.y, key.z, seed_value + 1 + end)
		targets.append(Vector3(slab.left, height, value + _get_step(value, sign, size, settings, depth)))


static func _get_previous(previous: HexCliffSlab, along: float, height: float) -> float:
	var plane: HexCliffPlane = previous.get_upper(along) if height > 0.5 else previous.lower
	return plane.get_push(along, height)


# Change of one push across a seam. Turns back at the limits; if neither way fits, the roomier wins.
static func _get_step(value: float, sign: float, size: float, settings: HexCliffSettings, depth: float) -> float:
	var amount: float = depth * lerpf(settings.slab_step, 1.0, size)
	var forward: float = value + sign * amount
	var backward: float = value - sign * amount
	if forward < 0.0 or forward > depth:
		var fits: bool = backward >= 0.0 and backward <= depth
		if fits or absf(clampf(backward, 0.0, depth) - value) > absf(clampf(forward, 0.0, depth) - value):
			forward = backward
	return clampf(forward, 0.0, depth) - value


# Turns that keep pushes carried from each point to the slab's ends, at the same height, between
# 0 and depth: (lowest, highest, preferred). The preferred one is random within them.
static func _get_turns(slab: HexCliffSlab, points: PackedVector3Array, key: Vector3i, settings: HexCliffSettings, depth: float) -> Vector3:
	var width: float = maxf(slab.right - slab.left, 0.001)
	var low: float = -settings.slab_turn * depth / maxf(width, 1.0)
	var high: float = -low
	for point: Vector3 in points:
		if point.z < 0.0 or point.z > depth:
			continue
		for end: Vector2 in _get_ends(slab):
			var span: float = end.x - point.x
			if end.y != point.y or absf(span) < 0.001:
				continue
			var lowest: float = -point.z / span if span > 0.0 else (depth - point.z) / span
			var highest: float = (depth - point.z) / span if span > 0.0 else -point.z / span
			low = maxf(low, lowest)
			high = minf(high, highest)
	if low > high:
		var middle: float = 0.5 * (low + high)
		low = middle
		high = middle
	var preferred: float = lerpf(low, high, HexCliffNoise.hash01(key.x, key.y, key.z, settings.noise_seed + _SEED + 5))
	return Vector3(low, high, preferred)


# Where a slab's pushes land: its edge columns' rim and base points, as (along, height).
static func _get_ends(slab: HexCliffSlab) -> PackedVector2Array:
	var ends := PackedVector2Array()
	for along: float in [slab.left, slab.right]:
		ends.append(Vector2(roundf(along), 1.0))
		ends.append(Vector2(roundf(along - 0.5) + 0.5, 0.0))
	return ends


# How far plane's pushes at the slab's ends fall outside 0 to depth, summed.
static func _get_excess(plane: HexCliffPlane, slab: HexCliffSlab, depth: float) -> float:
	var excess: float = 0.0
	for end: Vector2 in _get_ends(slab):
		var push: float = plane.get_push(end.x, end.y)
		excess += maxf(0.0, -push) + maxf(0.0, push - depth)
	return excess


# Plane through anchors, as near targets as they allow, turned as near turn as both allow.
# Weighted least squares on push = base + lean * height + turn * (along - left).
static func _fit(slab: HexCliffSlab, anchors: PackedVector3Array, targets: PackedVector3Array, turn: float) -> HexCliffPlane:
	var m := PackedFloat64Array()
	m.resize(9)
	var b := PackedFloat64Array([0.0, 0.0, 0.0])
	var rows: Array[Vector4] = [] # (1, height, along - left, push)
	var weights := PackedFloat64Array()
	for point: Vector3 in anchors:
		rows.append(Vector4(1.0, point.y, point.x - slab.left, point.z))
		weights.append(_ANCHOR_WEIGHT)
	for point: Vector3 in targets:
		rows.append(Vector4(1.0, point.y, point.x - slab.left, point.z))
		weights.append(_TARGET_WEIGHT)
	rows.append(Vector4(0.0, 0.0, 1.0, turn))
	weights.append(_TURN_WEIGHT)
	for r: int in rows.size():
		var row: Vector4 = rows[r]
		var v: Array[float] = [row.x, row.y, row.z]
		for i: int in 3:
			b[i] += weights[r] * v[i] * row.w
			for j: int in 3:
				m[i * 3 + j] += weights[r] * v[i] * v[j]
	var x: PackedFloat64Array = _solve(m, b)
	return HexCliffPlane.new(x[0], x[1], x[2], slab.left)


# Solves the 3x3 system m x = b by Cramer's rule.
static func _solve(m: PackedFloat64Array, b: PackedFloat64Array) -> PackedFloat64Array:
	var det: float = _det(m)
	var x := PackedFloat64Array([0.0, 0.0, 0.0])
	if absf(det) < 1e-12:
		return x
	for c: int in 3:
		var replaced: PackedFloat64Array = m.duplicate()
		for r: int in 3:
			replaced[r * 3 + c] = b[r]
		x[c] = _det(replaced) / det
	return x


static func _det(m: PackedFloat64Array) -> float:
	return (
		m[0] * (m[4] * m[8] - m[5] * m[7])
		- m[1] * (m[3] * m[8] - m[5] * m[6])
		+ m[2] * (m[3] * m[7] - m[4] * m[6])
	)


# Maybe breaks the slab at a height: a ledge where its lower part stands out, a split of its upper part, or both.
# hinge: spoke the slab passes through, or empty. Changes keep to the far side of it.
static func _add_break(slab: HexCliffSlab, key: Vector3i, settings: HexCliffSettings, depth: float, run: float, gap: float, hinge: PackedVector2Array) -> void:
	var seed_value: int = settings.noise_seed + _SEED + 6
	var width: float = slab.right - slab.left
	var ledge: bool = HexCliffNoise.hash01(key.x, key.y, key.z, seed_value) < settings.ledge_chance
	var split_at: float = _get_split(slab, key, seed_value + 1, gap)
	var split: bool = split_at < INF and HexCliffNoise.hash01(key.x, key.y, key.z, seed_value + 2) < settings.split_chance
	if not ledge and not split:
		return
	slab.break_height = lerpf(_BREAK_LOW, _BREAK_HIGH, HexCliffNoise.hash01(key.x, key.y, key.z, seed_value + 3))
	slab.break_slope = _BREAK_SLANT * (2.0 * HexCliffNoise.hash01(key.x, key.y, key.z, seed_value + 4) - 1.0) / maxf(width, 1.0)
	var most_lean: float = _MAX_LEAN * run
	if ledge:
		_add_ledge(slab, key, seed_value + 5, depth, most_lean, hinge)
	if split:
		slab.split_at = split_at
		slab.split_turns_left = not hinge.is_empty() and hinge[1].x > slab.right
		_add_split(slab, key, seed_value + 9, settings, depth, most_lean, gap)


# Split seam center: on a base point, so the seam's edges share it, at least a margin in from the
# slab's edges. INF if none fits.
static func _get_split(slab: HexCliffSlab, key: Vector3i, seed_value: int, gap: float) -> float:
	var margin: float = _SPLIT_MARGIN + 0.5 * gap
	var low: int = ceili(slab.left + margin - 0.5)
	var high: int = floori(slab.right - margin - 0.5)
	if high < low:
		return INF
	return low + mini(floori(HexCliffNoise.hash01(key.x, key.y, key.z, seed_value) * (high - low + 1)), high - low) + 0.5


# Lower plane standing out from the upper one at the break, by a depth that changes along the slab.
# Without a hinge it sometimes falls to nothing at one end. With one, the lower plane still passes
# through the spoke's lower part, so the ledge closes at the spoke and opens away from it.
static func _add_ledge(slab: HexCliffSlab, key: Vector3i, seed_value: int, depth: float, most_lean: float, hinge: PackedVector2Array) -> void:
	var plane: HexCliffPlane = slab.upper
	var width: float = maxf(slab.right - slab.left, 0.001)
	var deep: float = depth * _LEDGE_DEPTH * lerpf(0.5, 1.0, HexCliffNoise.hash01(key.x, key.y, key.z, seed_value))
	var shallow: float = depth * _LEDGE_DEPTH * HexCliffNoise.hash01(key.x, key.y, key.z, seed_value + 1)
	# Lower plane = plane + lean_change * height + turn_change * (along - pivot).
	# Its depth over the upper plane at the break is lean_change * break + turn_change * (along - pivot).
	var lean_change: float
	var turn_change: float
	var pivot: float = slab.left
	if hinge.is_empty():
		var deep_left: bool = HexCliffNoise.hash01(key.x, key.y, key.z, seed_value + 2) < 0.5
		var left_depth: float = deep if deep_left else shallow
		var right_depth: float = shallow if deep_left else deep
		lean_change = minf(left_depth / slab.get_break(slab.left), most_lean - plane.lean)
		turn_change = (right_depth - lean_change * slab.get_break(slab.right)) / width
		turn_change = maxf(turn_change, -lean_change * slab.get_break(slab.right) / width)
	else:
		# Zero along the spoke: turn_change = -lean_change / (spoke's along change from base to rim).
		var reach: float = hinge[0].x - hinge[1].x
		if absf(reach) < _MIN_HINGE:
			return
		pivot = hinge[1].x
		var far: float = slab.right if hinge[1].x < slab.left else slab.left
		var per_lean: float = slab.get_break(far) - (far - pivot) / reach
		if per_lean <= 0.0:
			return
		lean_change = minf(deep / per_lean, most_lean - plane.lean)
		turn_change = -lean_change / reach
	# Base pushes at the slab's ends stay between 0 and depth.
	for end: Vector2 in _get_ends(slab):
		if end.y > 0.5:
			continue
		var base: float = plane.get_push(end.x, 0.0)
		var change: float = turn_change * (end.x - pivot)
		if base + change < 0.0 or base + change > depth:
			var scale: float = clampf(base + change, 0.0, depth) - base
			var factor: float = scale / change if absf(change) > 1e-9 else 0.0
			lean_change *= factor
			turn_change *= factor
	if lean_change <= 0.0:
		return
	slab.lower = HexCliffPlane.new(plane.base + turn_change * (slab.left - pivot), plane.lean + lean_change, plane.turn + turn_change, slab.left)
	slab.has_ledge = true


# Upper part on one side of a seam turned about the break line, so the seam opens from nothing at
# the break toward the rim.
static func _add_split(slab: HexCliffSlab, key: Vector3i, seed_value: int, settings: HexCliffSettings, depth: float, most_lean: float, gap: float) -> void:
	var plane: HexCliffPlane = slab.upper
	var rise: float = 1.0 - slab.get_break(slab.split_at)
	var size: float = depth * lerpf(settings.slab_step, 1.0, HexCliffNoise.hash01(key.x, key.y, key.z, seed_value)) / rise
	# Rim pushes on the turned side stay between 0 and depth, and the plane leans back no more than allowed.
	var low: float = -INF
	var high: float = most_lean - plane.lean
	var far: float = slab.left if slab.split_turns_left else slab.right
	var near: float = slab.split_at + (-0.5 if slab.split_turns_left else 0.5) * gap
	for along: float in [roundf(near), roundf(far)]:
		var height_left: float = 1.0 - slab.get_break(along)
		var rim: float = plane.get_push(along, 1.0)
		low = maxf(low, -rim / height_left)
		high = minf(high, (depth - rim) / height_left)
	var change: float = size if HexCliffNoise.hash01(key.x, key.y, key.z, seed_value + 1) < 0.5 else -size
	if change < low or change > high:
		change = -change
	change = clampf(change, low, maxf(low, high))
	# Plane + change * (height - break(along)).
	slab.split_upper = HexCliffPlane.new(
		plane.base - change * slab.break_height,
		plane.lean + change,
		plane.turn - change * slab.break_slope,
		slab.left,
	)
