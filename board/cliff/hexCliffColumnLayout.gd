class_name HexCliffColumnLayout
extends Object
## Static placement of a cliff strip's facet columns along the wall.
## Spokes and forced columns are fixed. Between them the wall is split into slabs (see
## HexCliffSlabPlanes) by seams: narrow strips between two slab edges, about a slab width apart.
## Each seam's two edges share one end, a rim point or a base point: the seam tapers to a point
## there and opens toward its other end, where its edges end on neighboring points.
## The seams of a run lean alike, so the slabs between them are slanted strips. A slab next to a
## spoke has an edge of its own that shares one of the spoke's ends and leans the seams' way, so a
## narrow corner face joins it to the spoke much as a seam joins two slabs.
## Beside each seam and corner face, an inner column on the slab moves with its edge, so repairs
## there bend only the thin strip next to it, not faces across the whole slab.

# Hash seed offsets.
const _GAP_SEED: int = 7177
# Least gap between a free column and a forced one.
const _FIXED_GAP: float = 0.75
# Narrowest slab, at the rim and at the base, in lattice steps.
const _MIN_SLAB: float = 0.6
# Spread of seam width, as a share of seam_width.
const _SEAM_JITTER: float = 0.3
# Spread of seam positions, as a share of the space between seams times slab_width_variance.
const _SPREAD: float = 0.3
# Most a seam may run sideways from base to rim, in lattice steps. Each run of slabs picks one run
# its seams share, at least _LEAST_RUN of the most, give or take _RUN_JITTER of it.
const _MAX_RUN: float = 2.0
const _LEAST_RUN: float = 0.5
const _RUN_JITTER: float = 0.2
# Shares of that run tried, until the seams fit; and nudges along tried per seam, in lattice steps.
const _LEAN_SHARES: Array[float] = [1.0, 0.6, 0.3, 0.0]
const _NUDGES: Array[float] = [0.0, 0.5, -0.5]
# Sideways room kept clear toward a free neighbor's shifted corners, and toward a fixed column's ends.
const _FREE_CLEARANCE: float = 0.05
const _FIXED_CLEARANCE: float = 0.3
# Most a seam may bend sideways, in lattice steps. Its columns shift alike, but not exactly.
const _SEAM_ROOM: float = 0.5
# Inner columns stand this far into a slab from a seam or corner face, if the slab is at least one
# of these per inner column plus _MIN_INNER wide at the rim and base.
const _INNER: float = 0.3
const _MIN_INNER: float = 0.4
# Break ids per slab. Ids are unique per strip.
const _BREAK_IDS: int = 16


## Columns of a strip, ordered along the wall. forced: crossing edges that must be columns.
## max_push: limit of rim and base pushes. spokes: the strip's two spokes as [rim, base], each
## Vector2(along, push); slabs next to them meet them at a shared end. wall_height: in world units.
static func pick(tile: Vector2i, side: int, subdivisions: int, settings: HexCliffSettings, forced: PackedInt32Array, max_push: float, spokes: Array[PackedVector2Array], wall_height: float) -> Array[HexCliffColumn]:
	var last: int = 2 * subdivisions - 1
	var fixed: Array[HexCliffColumn] = [HexCliffColumn.from_edge(0, true)]
	for k: int in forced:
		if k > 0 and k < last:
			fixed.append(HexCliffColumn.from_edge(k, false))
	fixed.append(HexCliffColumn.from_edge(last, true))
	var spacing: float = HexLattice.get_spacing(subdivisions)
	var gap: float = settings.seam_width / spacing
	var depth: float = minf(settings.slab_depth, max_push)
	var columns: Array[HexCliffColumn] = []
	var next_seam: Array[int] = [0]
	for f: int in fixed.size():
		columns.append(fixed[f])
		if f == fixed.size() - 1:
			break
		var key := Vector3i(tile.x, tile.y, side * 64 + f)
		var run: float = _get_run(key, settings, spacing, wall_height)
		var left_edge: HexCliffColumn = _make_edge(fixed[f], true, run)
		var right_edge: HexCliffColumn = _make_edge(fixed[f + 1], false, run)
		if _get_mid(right_edge) - _get_mid(left_edge) < _MIN_SLAB:
			continue
		var seams: Array[_Seam] = _place_seams(left_edge, right_edge, _get_bound_ends(left_edge, fixed[f], 1), _get_bound_ends(right_edge, fixed[f + 1], -1), run, key, settings, spacing, gap)
		var slabs: Array[HexCliffSlab] = _make_slabs(left_edge, right_edge, fixed[f], fixed[f + 1], seams)
		var left_spoke: PackedVector2Array = spokes[0] if f == 0 else PackedVector2Array()
		var right_spoke: PackedVector2Array = spokes[1] if f + 1 == fixed.size() - 1 else PackedVector2Array()
		HexCliffSlabPlanes.assign(slabs, key, settings, depth, spacing * sqrt(0.75), gap, wall_height, spacing, left_spoke, right_spoke)
		columns.append_array(_place_columns(slabs, seams, left_edge, right_edge, fixed[f], fixed[f + 1], gap, f * 64 * _BREAK_IDS, next_seam))
	_keep_ends_in_order(columns)
	_set_room(columns)
	return columns


static func _get_mid(column: HexCliffColumn) -> float:
	return 0.5 * (column.along_bottom + column.along_top)


static func _get_line(column: HexCliffColumn) -> Vector2:
	return Vector2(column.along_bottom, column.along_top)


# Sideways run from base to rim the run's seams share, in lattice steps.
static func _get_run(key: Vector3i, settings: HexCliffSettings, spacing: float, wall_height: float) -> float:
	var seed_value: int = settings.noise_seed + _GAP_SEED
	var most: float = minf(settings.seam_lean * wall_height / spacing, _MAX_RUN)
	var run: float = most * lerpf(_LEAST_RUN, 1.0, HexCliffNoise.hash01(key.x, key.y, key.z, seed_value + 5))
	return -run if HexCliffNoise.hash01(key.x, key.y, key.z, seed_value + 7) < 0.5 else run


# Edge column of a run beside fixed, on its left or right. Beside a spoke it shares one of the
# spoke's ends and ends a lattice point further into the wall at the other, leaning run's way. It
# runs straight, so the corner face between them is flat.
# Beside a forced column it stands upright, clear of it.
static func _make_edge(fixed: HexCliffColumn, left: bool, run: float) -> HexCliffColumn:
	if not fixed.is_spoke:
		var along: float = _get_mid(fixed) + (_FIXED_GAP if left else -_FIXED_GAP)
		return HexCliffColumn.from_line(Vector2(along, along), roundi(along), roundi(along - 0.5))
	var step: int = 1 if left else -1
	var top: int = fixed.top
	var bottom: int = fixed.bottom
	# Leaning right going up, a left edge steps in at the rim, a right edge at the base.
	if (run > 0.0) == left:
		top += step
	else:
		bottom += step
	var column := HexCliffColumn.from_line(Vector2(bottom + 0.5, top), top, bottom)
	column.is_straight = true
	return column


# Ends, as Vector2i(top, bottom), seams' edges may share at most with the edge column beside fixed:
# its own, or beside a spoke those of its corner face's inner column (see _make_corner_inner()).
# step: 1 into the wall from a left edge, -1 from a right one.
static func _get_bound_ends(edge: HexCliffColumn, fixed: HexCliffColumn, step: int) -> Vector2i:
	if not fixed.is_spoke:
		return Vector2i(edge.top, edge.bottom)
	return Vector2i(edge.top + step, edge.bottom + step)


# Seams between the edge columns left and right, left to right, evenly about a slab width apart.
# They lean alike, by run or less where the slabs at the ends would get too narrow.
# left_ends, right_ends: bounds of their edges' ends, as Vector2i(top, bottom).
static func _place_seams(left: HexCliffColumn, right: HexCliffColumn, left_ends: Vector2i, right_ends: Vector2i, run: float, key: Vector3i, settings: HexCliffSettings, spacing: float, gap: float) -> Array[_Seam]:
	var width: float = settings.slab_width / spacing
	var length: float = _get_mid(right) - _get_mid(left)
	var left_run: float = left.along_top - left.along_bottom
	var right_run: float = right.along_top - right.along_bottom
	for share: float in _LEAN_SHARES:
		var lean: float = run * share
		# Mid-height room for slabs and seams, less what the end slabs need for leaning unlike their edges.
		var left_extra: float = 0.5 * absf(lean - left_run)
		var room: float = length - left_extra - 0.5 * absf(lean - right_run) + gap
		var count: int = maxi(roundi(room / (width + gap)), 1)
		while count > 1 and room / count - gap < _MIN_SLAB:
			count -= 1
		if count < 2:
			continue
		var seams: Array[_Seam] = _place_even(left, right, left_ends, right_ends, lean, _get_mid(left) + left_extra - 0.5 * gap, room / count, count, key, settings, gap)
		if not seams.is_empty():
			return seams
	return []


# count - 1 seams pitch apart after first. A seam that fits nowhere near its place is left out.
static func _place_even(left: HexCliffColumn, right: HexCliffColumn, left_ends: Vector2i, right_ends: Vector2i, lean: float, first: float, pitch: float, count: int, key: Vector3i, settings: HexCliffSettings, gap: float) -> Array[_Seam]:
	var seed_value: int = settings.noise_seed + _GAP_SEED
	var seams: Array[_Seam] = []
	var previous: Vector2 = _get_line(left)
	var previous_ends: Vector2i = left_ends
	for n: int in range(1, count):
		var spread: float = 2.0 * HexCliffNoise.hash01(key.x, key.y, key.z * 256 + n, seed_value) - 1.0
		var seam_gap: float = gap * (1.0 + _SEAM_JITTER * (2.0 * HexCliffNoise.hash01(key.x, key.y, key.z * 256 + n, seed_value + 1) - 1.0))
		var seam_run: float = lean * (1.0 + _RUN_JITTER * (2.0 * HexCliffNoise.hash01(key.x, key.y, key.z * 256 + n, seed_value + 3) - 1.0))
		var from_rim: bool = HexCliffNoise.hash01(key.x, key.y, key.z * 256 + n, seed_value + 2) < settings.seam_from_rim_chance
		var center: float = first + n * pitch + _SPREAD * settings.slab_width_variance * pitch * spread
		for nudge: float in _NUDGES:
			var seam := _Seam.new(center + nudge, seam_run, seam_gap, from_rim)
			if _fits(seam.left_line - previous, seam.left_ends - previous_ends) and _fits(_get_line(right) - seam.right_line, right_ends - seam.right_ends):
				seams.append(seam)
				previous = seam.right_line
				previous_ends = seam.right_ends
				break
	return seams


# True if a slab between two lines, width at its base and rim, is at least _MIN_SLAB wide, and its
# right edge's (top, bottom) indices less its left edge's don't run backward.
static func _fits(width: Vector2, ends: Vector2i) -> bool:
	return minf(width.x, width.y) >= _MIN_SLAB and ends.x >= 0 and ends.y >= 0


# Slabs between the edge columns, split by seams. Edges beside a spoke share one of its ends.
static func _make_slabs(left: HexCliffColumn, right: HexCliffColumn, left_fixed: HexCliffColumn, right_fixed: HexCliffColumn, seams: Array[_Seam]) -> Array[HexCliffSlab]:
	var slabs: Array[HexCliffSlab] = []
	var line: Vector2 = _get_line(left)
	var ends := Vector2i(left.top, left.bottom)
	for k: int in seams.size() + 1:
		var right_line: Vector2 = seams[k].left_line if k < seams.size() else _get_line(right)
		var right_ends: Vector2i = seams[k].left_ends if k < seams.size() else Vector2i(right.top, right.bottom)
		var slab := HexCliffSlab.new(line, right_line)
		slab.left_ends = Vector2(ends.x, ends.y + 0.5)
		slab.right_ends = Vector2(right_ends.x, right_ends.y + 0.5)
		if k > 0:
			slab.left_shared = 1 if seams[k - 1].from_rim else 0
			slab.left_shared_along = seams[k - 1].shared_along
		slabs.append(slab)
		if k < seams.size():
			line = seams[k].right_line
			ends = seams[k].right_ends
	if left_fixed.is_spoke:
		slabs[0].left_shared = 1 if left.top == left_fixed.top else 0
		slabs[0].left_shared_along = left.along_top if left.top == left_fixed.top else left.along_bottom
	if right_fixed.is_spoke:
		slabs[slabs.size() - 1].right_shared = 1 if right.top == right_fixed.top else 0
	return slabs


# Columns of each slab: its edges, the inner columns beside its seams and corner faces, and its
# split seam's columns.
# first_id: break id of the run's first slab. next_seam: next free seam id, advanced here.
static func _place_columns(slabs: Array[HexCliffSlab], seams: Array[_Seam], left_edge: HexCliffColumn, right_edge: HexCliffColumn, left_fixed: HexCliffColumn, right_fixed: HexCliffColumn, gap: float, first_id: int, next_seam: Array[int]) -> Array[HexCliffColumn]:
	var columns: Array[HexCliffColumn] = []
	var seam_ids := PackedInt32Array()
	for seam: _Seam in seams:
		seam_ids.append(next_seam[0])
		next_seam[0] += 1
	var last: int = slabs.size() - 1
	for k: int in slabs.size():
		var slab: HexCliffSlab = slabs[k]
		var span: float = minf(slab.right_bottom - slab.left_bottom, slab.right_top - slab.left_top)
		# Inner columns beside corner faces come first, then beside seams, while the slab keeps _MIN_INNER.
		var corners: int = int(k == 0 and slab.left_shared >= 0) + int(k == last and slab.right_shared >= 0)
		var corner_inner: bool = span >= corners * _INNER + _MIN_INNER
		# Alone between two edges, the inner columns' ends mustn't pass each other.
		if seams.is_empty():
			var reach: Vector2i = _get_bound_ends(right_edge, right_fixed, -1) - _get_bound_ends(left_edge, left_fixed, 1)
			corner_inner = corner_inner and reach.x >= 0 and reach.y >= 0
		var inner: bool = span >= (corners + int(k > 0) + int(k < last)) * _INNER + _MIN_INNER
		var first: int = columns.size()
		# Left edge and the inner column beside its seam or corner face.
		if k == 0:
			columns.append(left_edge)
			if corner_inner and slab.left_shared >= 0:
				columns.append(_make_corner_inner(left_edge, left_fixed, _INNER, next_seam))
		else:
			var seam: _Seam = seams[k - 1]
			var edge: HexCliffColumn = HexCliffColumn.from_line(seam.right_line, seam.right_ends.x, seam.right_ends.y)
			_set_seam(edge, seam, seam_ids[k - 1])
			columns.append(edge)
			if inner:
				var inside: HexCliffColumn = HexCliffColumn.from_line(seam.right_line + Vector2(_INNER, _INNER), edge.top, edge.bottom)
				_set_seam(inside, seam, seam_ids[k - 1])
				columns.append(inside)
		if slab.split_at < INF:
			columns.append_array(_place_split(slab, gap, next_seam))
		# Right edge and the inner column beside its seam.
		if k == last:
			if corner_inner and slab.right_shared >= 0:
				columns.append(_make_corner_inner(right_edge, right_fixed, -_INNER, next_seam))
			columns.append(right_edge)
		else:
			var seam: _Seam = seams[k]
			var edge: HexCliffColumn = HexCliffColumn.from_line(seam.left_line, seam.left_ends.x, seam.left_ends.y)
			_set_seam(edge, seam, seam_ids[k])
			if inner:
				var inside: HexCliffColumn = HexCliffColumn.from_line(seam.left_line - Vector2(_INNER, _INNER), edge.top, edge.bottom)
				_set_seam(inside, seam, seam_ids[k])
				columns.append(inside)
			columns.append(edge)
		for c: int in range(first, columns.size()):
			columns[c].slab = slab
			columns[c].turned = slab.is_turned(0.5 * (columns[c].along_bottom + columns[c].along_top))
	_set_breaks(columns, first_id)
	return columns


# Inner column offset from a corner face's edge beside spoke. With it the edge forms a seam, so the
# strip between them joins the flat corner face to the slab. It ends a lattice point further into
# the wall at both ends, so it never meets the edge: where the slab and the straight edge part
# ways, the strip between them stays wide enough to face out.
static func _make_corner_inner(edge: HexCliffColumn, spoke: HexCliffColumn, offset: float, next_seam: Array[int]) -> HexCliffColumn:
	var ends: Vector2i = _get_bound_ends(edge, spoke, 1 if offset > 0.0 else -1)
	var inside: HexCliffColumn = HexCliffColumn.from_line(_get_line(edge) + Vector2(offset, offset), ends.x, ends.y)
	for column: HexCliffColumn in [edge, inside]:
		column.seam = next_seam[0]
		column.seam_line = _get_line(edge)
	next_seam[0] += 1
	return inside


# Columns of a slab's split seam: an upright pair on a base point, with an inner column on each side.
static func _place_split(slab: HexCliffSlab, gap: float, next_seam: Array[int]) -> Array[HexCliffColumn]:
	var seam := _Seam.new(slab.split_at, 0.0, gap, false)
	var id: int = next_seam[0]
	next_seam[0] += 1
	var columns: Array[HexCliffColumn] = []
	for offset: float in [-_INNER, 0.0]:
		var column: HexCliffColumn = HexCliffColumn.from_line(seam.left_line + Vector2(offset, offset), seam.left_ends.x, seam.left_ends.y)
		_set_seam(column, seam, id)
		columns.append(column)
	for offset: float in [0.0, _INNER]:
		var column: HexCliffColumn = HexCliffColumn.from_line(seam.right_line + Vector2(offset, offset), seam.right_ends.x, seam.right_ends.y)
		_set_seam(column, seam, id)
		columns.append(column)
	return columns


static func _set_seam(column: HexCliffColumn, seam: _Seam, id: int) -> void:
	column.seam = id
	column.seam_line = seam.line


# Break corners of each column, and where it changes tier: where its line crosses its slab's breaks.
# Columns of one seam also take every break of the other slab beside it, where the seam's middle
# line crosses them, so they keep about the same corner heights.
static func _set_breaks(columns: Array[HexCliffColumn], first_id: int) -> void:
	var slab_ids: Dictionary = {} # HexCliffSlab -> its first break id
	for column: HexCliffColumn in columns:
		if column.slab and not slab_ids.has(column.slab):
			slab_ids[column.slab] = first_id + slab_ids.size() * _BREAK_IDS
	var seam_slabs: Dictionary = {} # Seam id -> Array of slabs beside it
	for column: HexCliffColumn in columns:
		if column.seam >= 0:
			var beside: Array = seam_slabs.get(column.seam, [])
			if not beside.has(column.slab):
				beside.append(column.slab)
			seam_slabs[column.seam] = beside
	for column: HexCliffColumn in columns:
		var beside: Array = [column.slab]
		if column.seam >= 0:
			beside = seam_slabs[column.seam]
		for slab: HexCliffSlab in beside:
			var line := Vector2(column.along_bottom, column.along_top) if slab == column.slab else column.seam_line
			for j: int in slab.breaks.size():
				var height: float = _get_crossing(slab, j, line)
				var ledge: float = 1.0 if slab.breaks[j].z > 0.0 or slab.breaks[j].w > 0.0 else 0.0
				# A straight column's corners lie on no tier, so it needs no break corners.
				if not column.is_straight:
					column.breaks.append(Vector3(height, ledge, slab_ids[slab] + j))
				if slab == column.slab:
					column.tier_breaks.append(height)


# Height where a line from the base to the rim, (along at base, along at rim), crosses break j.
static func _get_crossing(slab: HexCliffSlab, j: int, line: Vector2) -> float:
	var at_base: float = slab.get_break(j, line.x)
	var slope: float = slab.breaks[j].y
	var denominator: float = 1.0 - slope * (line.y - line.x)
	var height: float = at_base / denominator if absf(denominator) > 0.1 else slab.get_break(j, 0.5 * (line.x + line.y))
	return clampf(height, 0.05, 0.95)


# Columns' ends never run backward along the wall, so neighbors can't cross at their ends.
static func _keep_ends_in_order(columns: Array[HexCliffColumn]) -> void:
	for c: int in range(1, columns.size()):
		columns[c].top = maxi(columns[c].top, columns[c - 1].top)
		columns[c].bottom = maxi(columns[c].bottom, columns[c - 1].bottom)


# Sideways room of free columns. Fixed columns keep 0, so free neighbors may take the space beside them.
# Columns of one seam shift alike, so their room is toward the columns outside the seam.
static func _set_room(columns: Array[HexCliffColumn]) -> void:
	var c: int = 1
	while c < columns.size() - 1:
		var end: int = c
		if columns[c].seam >= 0:
			while end + 1 < columns.size() - 1 and columns[end + 1].seam == columns[c].seam:
				end += 1
		if not columns[c].is_fixed:
			var room: float = minf(_get_room(columns[c], columns[c - 1]), _get_room(columns[end], columns[end + 1]))
			for i: int in range(c, end + 1):
				columns[i].room = clampf(room, 0.0, _SEAM_ROOM if columns[c].seam >= 0 else INF)
		c = end + 1


# How far column's corners may shift toward neighbor, in lattice steps, at its narrower end.
# Free neighbors split the gap; fixed ones keep their ends' span plus clearance.
static func _get_room(column: HexCliffColumn, neighbor: HexCliffColumn) -> float:
	var near: float = minf(absf(column.along_bottom - neighbor.along_bottom), absf(column.along_top - neighbor.along_top))
	if not neighbor.is_fixed:
		return 0.5 * near - _FREE_CLEARANCE
	var span: Vector2 = neighbor.get_end_span()
	var left: bool = neighbor.along_bottom + neighbor.along_top < column.along_bottom + column.along_top
	var gap: float = minf(column.along_bottom, column.along_top) - span.y if left else span.x - maxf(column.along_bottom, column.along_top)
	return gap - _FIXED_CLEARANCE


# A seam: its middle line, its two edge lines, and where its edges end.
class _Seam:
	## Middle line: Vector2(along at base, along at rim).
	var line := Vector2.ZERO
	var left_line := Vector2.ZERO
	var right_line := Vector2.ZERO
	## Edges' end indices: Vector2i(top, bottom).
	var left_ends := Vector2i.ZERO
	var right_ends := Vector2i.ZERO
	## True if the edges share their rim point, false if their base point.
	var from_rim: bool = false
	## Along-wall position of the shared point.
	var shared_along: float = 0.0

	## center: middle at mid-height. run: sideways change from base to rim. width: edge to edge.
	## The shared end snaps onto its nearest lattice point; the whole seam moves with it.
	func _init(center: float, run: float, width: float, rim: bool) -> void:
		from_rim = rim
		var top: float = center + 0.5 * run
		var base: float = center - 0.5 * run
		# Snapping moves the whole seam, so it keeps its lean.
		var shift: float = roundf(top) - top if rim else roundf(base - 0.5) + 0.5 - base
		top += shift
		base += shift
		if rim:
			shared_along = top
			var open: int = floori(base - 0.5)
			left_ends = Vector2i(roundi(top), open)
			right_ends = Vector2i(roundi(top), open + 1)
		else:
			shared_along = base
			var open: int = floori(top)
			left_ends = Vector2i(open, roundi(base - 0.5))
			right_ends = Vector2i(open + 1, roundi(base - 0.5))
		line = Vector2(base, top)
		left_line = line - Vector2(0.5 * width, 0.5 * width)
		right_line = line + Vector2(0.5 * width, 0.5 * width)
