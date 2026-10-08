class_name HexCliffColumnLayout
extends Object
## Static placement of a cliff strip's facet columns along the wall.
## Spokes and forced columns are fixed. Between them the wall is split into flat slabs (see
## HexCliffSlabPlanes). Each slab is bounded by two free columns on its planes. Neighboring slabs
## meet at a seam: their edge columns stand close together, so the faces between them are narrow.
## A slab whose upper part splits gets a seam pair inside it too.
## Free columns end at the nearest rim and base points. Seams sit on a rim point or a base point,
## so their two edges share exactly that end: the seam tapers to a point there and opens toward the other.

# Hash seed offsets.
const _GAP_SEED: int = 7177
# Least gap between a free column and a fixed one. Spokes are pushed along the hex corner's
# own direction, so they may lean sideways.
const _FIXED_GAP: float = 0.75
# Narrowest slab, in lattice steps.
const _MIN_SLAB: float = 0.6
# Spread of seam width, as a share of seam_width.
const _SEAM_JITTER: float = 0.3
# Sideways room kept clear toward a free neighbor's shifted corners, and toward a fixed column's ends.
const _FREE_CLEARANCE: float = 0.05
const _FIXED_CLEARANCE: float = 0.3
# Most a seam may bend sideways, in lattice steps. Its columns shift alike, but not exactly.
const _SEAM_ROOM: float = 0.5
# Inner columns stand this far into a slab from a seam, if the slab is at least two of these plus
# _MIN_INNER wide.
const _INNER: float = 0.3
const _MIN_INNER: float = 0.4
# Least gap between columns, in lattice steps.
const _MIN_COLUMN_GAP: float = 0.12


## Columns of a strip, ordered along the wall. forced: crossing edges that must be columns.
## max_push: limit of rim and base pushes. spokes: the strip's two spokes as [rim, base], each
## Vector2(along, push); slabs next to them pass through them.
static func pick(tile: Vector2i, side: int, subdivisions: int, settings: HexCliffSettings, forced: PackedInt32Array, max_push: float, spokes: Array[PackedVector2Array]) -> Array[HexCliffColumn]:
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
	for f: int in fixed.size():
		columns.append(fixed[f])
		if f == fixed.size() - 1:
			break
		var key := Vector3i(tile.x, tile.y, side * 64 + f)
		var slabs: Array[HexCliffSlab] = _place_slabs(fixed[f].along, fixed[f + 1].along, key, settings, spacing, gap)
		var left_spoke: PackedVector2Array = spokes[0] if f == 0 else PackedVector2Array()
		var right_spoke: PackedVector2Array = spokes[1] if f + 1 == fixed.size() - 1 else PackedVector2Array()
		HexCliffSlabPlanes.assign(slabs, key, settings, depth, spacing * sqrt(0.75), gap, left_spoke, right_spoke)
		columns.append_array(_place_columns(slabs, gap, f * 64))
	_set_room(columns)
	return columns


# Slabs between two fixed columns, edge to edge with a seam between neighbors.
static func _place_slabs(from: float, to: float, key: Vector3i, settings: HexCliffSettings, spacing: float, gap: float) -> Array[HexCliffSlab]:
	var slabs: Array[HexCliffSlab] = []
	var start: float = from + _FIXED_GAP
	var end: float = to - _FIXED_GAP
	if end < start:
		return slabs
	var width: float = settings.slab_width / spacing
	var seed_value: int = settings.noise_seed + _GAP_SEED
	var left: float = start
	var position: float = from # Last seam center, or the fixed column
	var n: int = 0
	while true:
		n += 1
		var spread: float = 2.0 * HexCliffNoise.hash01(key.x, key.y, key.z * 256 + n, seed_value) - 1.0
		var seam_gap: float = gap * (1.0 + _SEAM_JITTER * (2.0 * HexCliffNoise.hash01(key.x, key.y, key.z * 256 + n, seed_value + 1) - 1.0))
		var seam: float = maxf(position + width * (1.0 + settings.slab_width_variance * spread), left + _MIN_SLAB + 0.5 * seam_gap)
		# On a rim point the seam starts at the rim and opens toward the base; on a base point, the reverse.
		if HexCliffNoise.hash01(key.x, key.y, key.z * 256 + n, seed_value + 2) < settings.seam_from_rim_chance:
			seam = ceilf(seam)
		else:
			seam = ceilf(seam - 0.5) + 0.5
		if seam + 0.5 * seam_gap + _MIN_SLAB > end:
			break
		slabs.append(HexCliffSlab.new(left, seam - 0.5 * seam_gap))
		left = seam + 0.5 * seam_gap
		position = seam
	slabs.append(HexCliffSlab.new(left, end))
	return slabs


# Edge columns of each slab, and the seam pair of a split. first_id: break id of the first slab.
# Beside each seam, an inner column on each slab moves with the seam, so repairs near a seam bend
# only the thin strip next to it, not faces across the whole slab.
static func _place_columns(slabs: Array[HexCliffSlab], gap: float, first_id: int) -> Array[HexCliffColumn]:
	var columns: Array[HexCliffColumn] = []
	var last: int = slabs.size() - 1
	for s: int in slabs.size():
		var slab: HexCliffSlab = slabs[s]
		var width: float = slab.right - slab.left
		var left_seam: float = 0.5 * (slabs[s - 1].right + slab.left) if s > 0 else NAN
		var right_seam: float = 0.5 * (slab.right + slabs[s + 1].left) if s < last else NAN
		var inner: bool = width >= 2.0 * _INNER + _MIN_INNER
		var places: Array[Vector2] = [Vector2(slab.left, left_seam)] # (along, seam center)
		if inner and s > 0:
			places.append(Vector2(slab.left + _INNER, left_seam))
		if slab.split_at < INF:
			for offset: float in [-0.5 * gap - _INNER, -0.5 * gap, 0.5 * gap, 0.5 * gap + _INNER]:
				places.append(Vector2(slab.split_at + offset, slab.split_at))
		if inner and s < last:
			places.append(Vector2(slab.right - _INNER, right_seam))
		if width >= _MIN_SLAB:
			places.append(Vector2(slab.right, right_seam))
		places.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
		var previous: float = -INF
		for place: Vector2 in places:
			# Columns this close would make slivers; the first of them stays.
			if place.x - previous < _MIN_COLUMN_GAP:
				continue
			previous = place.x
			var column: HexCliffColumn = HexCliffColumn.from_position(place.x)
			column.lower = slab.lower
			column.upper = slab.get_upper(place.x)
			column.break_height = slab.get_break(place.x)
			column.has_ledge = slab.has_ledge
			column.seam_center = place.y
			if column.break_height <= 1.0:
				column.breaks.append(Vector3(column.break_height, 1.0 if column.has_ledge else 0.0, first_id + s))
			columns.append(column)
	# Columns of one seam get each other's breaks too, so they keep the same corner heights.
	for group: Vector2i in _get_seam_groups(columns):
		var shared := PackedVector3Array()
		for c: int in range(group.x, group.y + 1):
			for entry: Vector3 in columns[c].breaks:
				if not _has_break(shared, entry.z):
					shared.append(entry)
		for c: int in range(group.x, group.y + 1):
			columns[c].breaks = shared.duplicate()
	return columns


static func _has_break(breaks: PackedVector3Array, id: float) -> bool:
	for entry: Vector3 in breaks:
		if entry.z == id:
			return true
	return false


# Runs of neighboring columns of one seam, as (first, last) index.
static func _get_seam_groups(columns: Array[HexCliffColumn]) -> Array[Vector2i]:
	var groups: Array[Vector2i] = []
	var c: int = 0
	while c < columns.size():
		var center: float = columns[c].seam_center
		var end: int = c
		while not is_nan(center) and end + 1 < columns.size() and columns[end + 1].seam_center == center:
			end += 1
		if end > c:
			groups.append(Vector2i(c, end))
		c = end + 1
	return groups


# Sideways room of free columns. Fixed columns keep 0, so free neighbors may take the space beside them.
# Columns of one seam shift alike, so their room is toward the columns outside the seam.
static func _set_room(columns: Array[HexCliffColumn]) -> void:
	for c: int in range(1, columns.size() - 1):
		if not columns[c].is_fixed and is_nan(columns[c].seam_center):
			columns[c].room = maxf(0.0, minf(_get_room(columns[c], columns[c - 1]), _get_room(columns[c], columns[c + 1])))
	for group: Vector2i in _get_seam_groups(columns):
		var room: float = minf(_get_room(columns[group.x], columns[group.x - 1]), _get_room(columns[group.y], columns[group.y + 1]))
		for c: int in range(group.x, group.y + 1):
			columns[c].room = clampf(room, 0.0, _SEAM_ROOM)


# How far column's corners may shift toward neighbor, in lattice steps.
# Free neighbors split the gap; fixed ones keep their ends' span plus clearance.
static func _get_room(column: HexCliffColumn, neighbor: HexCliffColumn) -> float:
	if not neighbor.is_fixed:
		return 0.5 * absf(column.along - neighbor.along) - _FREE_CLEARANCE
	var span: Vector2 = neighbor.get_end_span()
	var gap: float = column.along - span.y if neighbor.along < column.along else span.x - column.along
	return gap - _FIXED_CLEARANCE
