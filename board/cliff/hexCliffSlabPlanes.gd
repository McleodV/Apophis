class_name HexCliffSlabPlanes
extends Object
## Static choice of the tiers and breaks of a run of slabs along a cliff strip.
## Each slab is stacked from flat tiers, about slab_height tall, between break lines that often
## slant. Tiers alternate between near upright and leaning back, and turn left or right, so each
## catches light differently. At a fold, neighboring tiers meet along the break; at a ledge the
## lower one stands out and a small face looking up joins them.
## Neighboring slabs differ in depth, so the narrow faces of the seam between them look sideways.
## Both edges of a seam share one end point (see HexCliffColumnLayout); the seam closes exactly
## there and opens toward its other end. A slab next to a spoke meets it the same way, across a
## narrow corner face: anchored where its edge shares the spoke's end, a step away where the face opens.
## All tiers of a slab are fitted at once (HexCliffSolver): anchors and breaks as constraints,
## open seam ends as targets, and each tier's lean and turn as preferences.
## Pushes stay between 0 and depth at the rim and base where they can, since rim and base points
## take them. Tiers lean back less than the wall's own run per height, so no face leans out going up.

# Hash seed offsets.
const _SEED: int = 3313
# Fit weights: anchors and breaks a slab must keep, targets it should, and its tiers' preferred
# lean and turn.
const _ANCHOR_WEIGHT: float = 10000.0
const _TARGET_WEIGHT: float = 1.0
const _PREFERENCE_WEIGHT: float = 0.01
# Share of the wall's run per height a tier may lean out by. Keeps faces from looking down.
const _MAX_LEAN: float = 0.8
# Upright tiers prefer leaning out by this share of the most allowed.
const _UPRIGHT_LOW: float = 0.4
const _UPRIGHT_HIGH: float = 0.9
const _MAX_TIERS: int = 6
# Spread of tier count and of break heights, as shares of a tier.
const _COUNT_JITTER: float = 0.3
const _BREAK_JITTER: float = 0.35
# Breaks stay within these heights, and this far apart in world units.
const _BREAK_LOW: float = 0.1
const _BREAK_HIGH: float = 0.9
const _MIN_TIER: float = 0.08
# Least slant of a slab's breaks, as a share of break_slant, and their spread about it, as a share
# of their slant. Breaks in a slab run near parallel, so they rarely have to flatten to keep apart.
const _LEAST_SLANT: float = 0.45
const _SLANT_JITTER: float = 0.2
# Deepest ledge, as a share of depth.
const _LEDGE_DEPTH: float = 0.8
# Steps at a seam's open end and at a split: least share of depth.
const _MIN_STEP: float = 0.25
# Sideways run from base to rim, in lattice steps, from which a seam's step goes its lean's way.
const _LEANING_SEAM: float = 0.25
# A split seam keeps this far from its slab's edges, in lattice steps. Leaves room for the inner
# columns beside both seams (see HexCliffColumnLayout).
const _SPLIT_MARGIN: float = 1.0
# Rim and base pushes out of range, and tiers leaning out too far, are pulled back to their limit
# with this weight and fitted again, up to this many times.
const _LIMIT_WEIGHT: float = 10000.0
const _LIMIT_PASSES: int = 4


## Gives each slab its breaks and tiers, left to right.
## key: unique per run; seeds its randomness. depth: most a slab stands out at the rim or base.
## run: the wall's horizontal run from base to rim, in world units. gap: seam width, in lattice steps.
## wall_height: in world units. spacing: lattice step, in world units.
## left_spoke, right_spoke: the spoke bounding the run on that side as [rim, base], each
## Vector2(along, push), or empty if a forced column bounds it.
static func assign(slabs: Array[HexCliffSlab], key: Vector3i, settings: HexCliffSettings, depth: float, run: float, gap: float, wall_height: float, spacing: float, left_spoke: PackedVector2Array, right_spoke: PackedVector2Array) -> void:
	for k: int in slabs.size():
		_set_breaks(slabs[k], _get_key(key, k), settings, depth, wall_height, spacing)
	for k: int in slabs.size():
		var slab: HexCliffSlab = slabs[k]
		var anchors := PackedVector3Array() # (along, height, push)
		var targets := PackedVector3Array()
		_add_constraints(slabs, k, key, settings, depth, left_spoke, right_spoke, anchors, targets)
		_fit(slab, anchors, targets, _get_key(key, k), settings, depth, run)
		_add_split(slab, _get_key(key, k), settings, depth, run, gap, anchors)


static func _get_key(key: Vector3i, k: int) -> Vector3i:
	return Vector3i(key.x, key.y, key.z * 64 + k)


# Constraints of slab k: where it meets the slab or spoke before it, and the spoke after it.
static func _add_constraints(slabs: Array[HexCliffSlab], k: int, key: Vector3i, settings: HexCliffSettings, depth: float, left_spoke: PackedVector2Array, right_spoke: PackedVector2Array, anchors: PackedVector3Array, targets: PackedVector3Array) -> void:
	var slab: HexCliffSlab = slabs[k]
	var slab_key: Vector3i = _get_key(key, k)
	if k > 0:
		_add_seam(anchors, targets, slabs[k - 1], slab, slab_key, settings, depth)
	elif not left_spoke.is_empty():
		_add_corner(anchors, targets, left_spoke, slab.left_shared, slab.left_ends, slab_key, settings, depth)
	else:
		var seed_value: int = settings.noise_seed + _SEED
		targets.append(Vector3(slab.left_ends.x, 1.0, depth * HexCliffNoise.hash01(key.x, key.y, key.z * 64, seed_value)))
		targets.append(Vector3(slab.left_ends.y, 0.0, depth * HexCliffNoise.hash01(key.x, key.y, key.z * 64, seed_value + 1)))
	if k == slabs.size() - 1 and not right_spoke.is_empty():
		_add_corner(anchors, targets, right_spoke, slab.right_shared, slab.right_ends, slab_key + Vector3i(0, 0, 32), settings, depth)


# Constraints from the seam to the previous slab: an anchor where the seam's edges share an end,
# and a target a step away from the previous slab where it opens.
# Up a leaning seam, the wall crosses from the slab it leans over to the other one, so that one
# shouldn't stand out further: a seam leaning right going up steps out to the right, or not at all.
static func _add_seam(anchors: PackedVector3Array, targets: PackedVector3Array, previous: HexCliffSlab, slab: HexCliffSlab, key: Vector3i, settings: HexCliffSettings, depth: float) -> void:
	var seed_value: int = settings.noise_seed + _SEED + 2
	var lean: float = slab.left_top - slab.left_bottom
	var leaning: bool = absf(lean) >= _LEANING_SEAM
	for rim: bool in [true, false]:
		var height: float = 1.0 if rim else 0.0
		if slab.left_shared == int(rim):
			var along: float = slab.left_shared_along
			anchors.append(Vector3(along, height, previous.get_plane_at(along, height).get_push(along, height)))
			continue
		var from: float = previous.right_ends.x if rim else previous.right_ends.y
		var value: float = previous.get_plane_at(from, height).get_push(from, height)
		var sign: float = signf(lean) if leaning else (1.0 if HexCliffNoise.hash01(key.x, key.y, key.z, seed_value) < 0.5 else -1.0)
		var size: float = HexCliffNoise.hash01(key.x, key.y, key.z, seed_value + 1 + int(rim))
		targets.append(Vector3(slab.left_ends.x if rim else slab.left_ends.y, height, value + _get_step(value, sign, size, settings, depth, not leaning)))


# Constraints from a corner face to a spoke, as [rim, base] of Vector2(along, push): an anchor at
# the spoke's end the slab's edge shares (shared: 1 = rim, 0 = base), and a target a step away
# from the spoke's other end, at the edge's end there. ends: the edge's (rim along, base along).
static func _add_corner(anchors: PackedVector3Array, targets: PackedVector3Array, spoke: PackedVector2Array, shared: int, ends: Vector2, key: Vector3i, settings: HexCliffSettings, depth: float) -> void:
	var seed_value: int = settings.noise_seed + _SEED + 4
	for rim: bool in [true, false]:
		var height: float = 1.0 if rim else 0.0
		var end: Vector2 = spoke[0] if rim else spoke[1]
		if shared == int(rim):
			anchors.append(Vector3(end.x, height, end.y))
			continue
		var sign: float = 1.0 if HexCliffNoise.hash01(key.x, key.y, key.z, seed_value) < 0.5 else -1.0
		var size: float = HexCliffNoise.hash01(key.x, key.y, key.z, seed_value + 1)
		targets.append(Vector3(ends.x if rim else ends.y, height, end.y + _get_step(end.y, sign, size, settings, depth, true)))


# Change of one push across a seam, sign's way. If turn, turns back at the limits; if neither way
# fits, the roomier wins. Otherwise it stops at the limit.
static func _get_step(value: float, sign: float, size: float, settings: HexCliffSettings, depth: float, turn: bool) -> float:
	var amount: float = depth * lerpf(maxf(settings.slab_step, _MIN_STEP), 1.0, size)
	var forward: float = value + sign * amount
	var backward: float = value - sign * amount
	if turn and (forward < 0.0 or forward > depth):
		var fits: bool = backward >= 0.0 and backward <= depth
		if fits or absf(clampf(backward, 0.0, depth) - value) > absf(clampf(forward, 0.0, depth) - value):
			forward = backward
	return clampf(forward, 0.0, depth) - value


# Break lines between the slab's tiers, bottom to top, about slab_height apart. They slant about
# alike, between _LEAST_SLANT and all of break_slant, so the tiers are slanted bands. A break that
# would cross the one below or leave the wall moves up or down; if that's not enough it slants half
# as much, then runs level, or is dropped.
static func _set_breaks(slab: HexCliffSlab, key: Vector3i, settings: HexCliffSettings, depth: float, wall_height: float, spacing: float) -> void:
	var seed_value: int = settings.noise_seed + _SEED + 6
	var spread: float = 2.0 * HexCliffNoise.hash01(key.x, key.y, key.z, seed_value) - 1.0
	var count: int = clampi(roundi(wall_height / maxf(settings.slab_height, 0.01) * (1.0 + _COUNT_JITTER * spread)), 1, _MAX_TIERS)
	# Slope the slab's breaks share, give or take _SLANT_JITTER of it.
	var shared_slope: float = settings.break_slant * spacing / maxf(wall_height, 0.01) * lerpf(_LEAST_SLANT, 1.0, HexCliffNoise.hash01(key.x, key.y, key.z, seed_value + 8))
	if HexCliffNoise.hash01(key.x, key.y, key.z, seed_value + 9) < 0.5:
		shared_slope = -shared_slope
	var least_gap: float = _MIN_TIER / maxf(wall_height, 0.01)
	var span: Vector2 = slab.get_span()
	var origin: float = slab.get_origin()
	var center: float = 0.5 * (span.x + span.y)
	var below := Vector2(_BREAK_LOW - least_gap, _BREAK_LOW - least_gap) # Previous break at the span's ends
	var breaks := PackedVector4Array()
	for j: int in range(1, count):
		var n: int = j * 8
		# Height at the span's center.
		var height: float = (j + _BREAK_JITTER * (2.0 * HexCliffNoise.hash01(key.x, key.y, key.z * 64 + n, seed_value) - 1.0)) / count
		var slope: float = shared_slope * (1.0 + _SLANT_JITTER * (2.0 * HexCliffNoise.hash01(key.x, key.y, key.z * 64 + n, seed_value + 1) - 1.0))
		var fits: bool = false
		for attempt: int in 3:
			# Heights at the span's center that keep both ends clear of the break below and the rim.
			var offsets := Vector2(slope * (span.x - center), slope * (span.y - center))
			var lowest: float = maxf(below.x - offsets.x, below.y - offsets.y) + least_gap
			var highest: float = _BREAK_HIGH - maxf(offsets.x, offsets.y)
			fits = lowest <= highest
			if fits:
				height = clampf(height, lowest, highest)
				break
			slope = 0.5 * slope if attempt == 0 else 0.0
		if not fits:
			continue
		below = Vector2(height + slope * (span.x - center), height + slope * (span.y - center))
		var left: float = 0.0
		var right: float = 0.0
		if HexCliffNoise.hash01(key.x, key.y, key.z * 64 + n, seed_value + 2) < settings.ledge_chance:
			var deep: float = depth * _LEDGE_DEPTH * lerpf(0.5, 1.0, HexCliffNoise.hash01(key.x, key.y, key.z * 64 + n, seed_value + 3))
			var shallow: float = depth * _LEDGE_DEPTH * HexCliffNoise.hash01(key.x, key.y, key.z * 64 + n, seed_value + 4)
			var deep_left: bool = HexCliffNoise.hash01(key.x, key.y, key.z * 64 + n, seed_value + 5) < 0.5
			left = deep if deep_left else shallow
			right = shallow if deep_left else deep
		breaks.append(Vector4(height + slope * (origin - center), slope, left, right))
	slab.breaks = breaks


# Fits all tiers of the slab at once.
static func _fit(slab: HexCliffSlab, anchors: PackedVector3Array, targets: PackedVector3Array, key: Vector3i, settings: HexCliffSettings, depth: float, run: float) -> void:
	var count: int = slab.breaks.size() + 1
	var seed_value: int = settings.noise_seed + _SEED + 7
	var most_lean: float = _MAX_LEAN * run
	var reach: float = settings.slab_turn * depth / maxf(slab.get_width(), 1.0)
	var upright: bool = HexCliffNoise.hash01(key.x, key.y, key.z, seed_value) < 0.5
	var leans := PackedFloat64Array()
	var turns := PackedFloat64Array()
	for i: int in count:
		var u: float = HexCliffNoise.hash01(key.x, key.y, key.z * 16 + i, seed_value + 1)
		var lean: float = most_lean * lerpf(_UPRIGHT_LOW, _UPRIGHT_HIGH, u)
		if upright != (i % 2 == 0):
			lean = -settings.slab_tilt * run * lerpf(0.5, 1.5, u)
		leans.append(lean)
		turns.append(reach * (2.0 * HexCliffNoise.hash01(key.x, key.y, key.z * 16 + i, seed_value + 2) - 1.0))
	slab.split_upper = null
	slab.split_at = INF
	var origin: float = slab.get_origin()
	var limit_points := PackedVector3Array() # Rim and base ends held at a limit: (along, height, push)
	var limit_leans := PackedVector2Array() # Tiers held at a lean: (tier, lean)
	for attempt: int in _LIMIT_PASSES:
		var solver := HexCliffSolver.new(3 * count)
		for point: Vector3 in anchors:
			_add_point(solver, count - 1 if point.y > 0.5 else 0, point, origin, _ANCHOR_WEIGHT)
		for point: Vector3 in targets:
			_add_point(solver, count - 1 if point.y > 0.5 else 0, point, origin, _TARGET_WEIGHT)
		_add_breaks(solver, slab, origin)
		for i: int in count:
			solver.add_row(PackedInt32Array([3 * i + 1]), PackedFloat64Array([1.0]), leans[i], _PREFERENCE_WEIGHT)
			solver.add_row(PackedInt32Array([3 * i + 2]), PackedFloat64Array([1.0]), turns[i], _PREFERENCE_WEIGHT)
		for point: Vector3 in limit_points:
			_add_point(solver, count - 1 if point.y > 0.5 else 0, point, origin, _LIMIT_WEIGHT)
		for held: Vector2 in limit_leans:
			solver.add_row(PackedInt32Array([3 * int(held.x) + 1]), PackedFloat64Array([1.0]), held.y, _LIMIT_WEIGHT)
		var x: PackedFloat64Array = solver.solve()
		slab.tiers.clear()
		for i: int in count:
			slab.tiers.append(HexCliffPlane.new(x[3 * i], x[3 * i + 1], x[3 * i + 2], origin))
		var held_more: bool = false
		for end: Vector2 in _get_ends(slab):
			var push: float = slab.get_plane_at(end.x, end.y).get_push(end.x, end.y)
			if push < -0.0001 or push > depth + 0.0001:
				limit_points.append(Vector3(end.x, end.y, clampf(push, 0.0, depth)))
				held_more = true
		for i: int in count:
			if slab.tiers[i].lean > most_lean:
				limit_leans.append(Vector2(i, most_lean))
				held_more = true
		if not held_more:
			break


static func _add_point(solver: HexCliffSolver, tier: int, point: Vector3, origin: float, weight: float) -> void:
	solver.add_row(PackedInt32Array([3 * tier, 3 * tier + 1, 3 * tier + 2]), PackedFloat64Array([1.0, point.y, point.x - origin]), point.z, weight)


# Each break: the tier below minus the one above equals its ledge depth along the break line,
# at two points.
static func _add_breaks(solver: HexCliffSolver, slab: HexCliffSlab, origin: float) -> void:
	var width: float = slab.get_width()
	for j: int in slab.breaks.size():
		for along: float in [origin + 0.15 * width, origin + 0.85 * width]:
			var height: float = slab.get_break(j, along)
			var columns := PackedInt32Array([3 * j, 3 * j + 1, 3 * j + 2, 3 * j + 3, 3 * j + 4, 3 * j + 5])
			var span: float = along - origin
			solver.add_row(columns, PackedFloat64Array([1.0, height, span, -1.0, -height, -span]), slab.get_ledge(j, along), _ANCHOR_WEIGHT)


# Where a slab's pushes land: its edge columns' rim and base points, as (along, height). Ends it
# shares with a seam's other edge or a spoke are anchored there instead.
static func _get_ends(slab: HexCliffSlab) -> PackedVector2Array:
	var ends := PackedVector2Array()
	if slab.left_shared != 1:
		ends.append(Vector2(slab.left_ends.x, 1.0))
	if slab.right_shared != 1:
		ends.append(Vector2(slab.right_ends.x, 1.0))
	if slab.left_shared != 0:
		ends.append(Vector2(slab.left_ends.y, 0.0))
	if slab.right_shared != 0:
		ends.append(Vector2(slab.right_ends.y, 0.0))
	return ends


# How far the slab's pushes at its ends fall outside 0 to depth, summed.
static func _get_excess(slab: HexCliffSlab, depth: float) -> float:
	var excess: float = 0.0
	for end: Vector2 in _get_ends(slab):
		var push: float = slab.get_plane_at(end.x, end.y).get_push(end.x, end.y)
		excess += maxf(0.0, -push) + maxf(0.0, push - depth)
	return excess


# Maybe splits the top tier along a seam on a base point, turning one side about the top break so
# the seam opens from nothing at the break toward the rim. The turned side holds no rim anchor.
static func _add_split(slab: HexCliffSlab, key: Vector3i, settings: HexCliffSettings, depth: float, run: float, gap: float, anchors: PackedVector3Array) -> void:
	slab.split_upper = null
	slab.split_at = INF
	if slab.breaks.is_empty():
		return
	var seed_value: int = settings.noise_seed + _SEED + 9
	if HexCliffNoise.hash01(key.x, key.y, key.z, seed_value) >= settings.split_chance:
		return
	var margin: float = _SPLIT_MARGIN + 0.5 * gap
	var low: int = ceili(maxf(slab.left_bottom, slab.left_top) + margin - 0.5)
	var high: int = floori(minf(slab.right_bottom, slab.right_top) - margin - 0.5)
	if high < low:
		return
	var split_at: float = low + mini(floori(HexCliffNoise.hash01(key.x, key.y, key.z, seed_value + 1) * (high - low + 1)), high - low) + 0.5
	var turns_left: bool = HexCliffNoise.hash01(key.x, key.y, key.z, seed_value + 4) < 0.5
	for point: Vector3 in anchors:
		if point.y > 0.5 and (point.x < split_at) == turns_left:
			return
	var top: int = slab.breaks.size() - 1
	var plane: HexCliffPlane = slab.tiers[top + 1]
	var rise: float = 1.0 - slab.get_break(top, split_at)
	var size: float = depth * lerpf(maxf(settings.slab_step, _MIN_STEP), 1.0, HexCliffNoise.hash01(key.x, key.y, key.z, seed_value + 2)) / rise
	# Rim pushes on the turned side stay between 0 and depth, and the tier leans out no more than allowed.
	var lowest: float = -INF
	var highest: float = _MAX_LEAN * run - plane.lean
	var near: float = split_at + (-0.5 if turns_left else 0.5) * gap
	var far: float = slab.left_ends.x if turns_left else slab.right_ends.x
	for along: float in [roundf(near), roundf(far)]:
		var height_left: float = 1.0 - slab.get_break(top, along)
		var rim: float = plane.get_push(along, 1.0)
		lowest = maxf(lowest, -rim / height_left)
		highest = minf(highest, (depth - rim) / height_left)
	var change: float = size if HexCliffNoise.hash01(key.x, key.y, key.z, seed_value + 3) < 0.5 else -size
	if change < lowest or change > highest:
		change = -change
	change = clampf(change, lowest, maxf(lowest, highest))
	# Top tier + change * (height - top break(along)).
	var line: Vector4 = slab.breaks[top]
	slab.split_upper = HexCliffPlane.new(plane.base - change * line.x, plane.lean + change, plane.turn - change * line.y, plane.origin)
	slab.split_at = split_at
	slab.split_turns_left = turns_left
