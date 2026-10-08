class_name HexCliffColumnLayout
extends Object
## Static placement of a cliff strip's facet columns along the wall, with their ridge and groove depths.
## Spokes and forced columns are fixed. Free columns fill the space between them at random gaps,
## ending at the nearest rim and base points, so several may share one point.
## Free columns run ridge, slope, groove, slope, ridge. A slope is 1 or 2 bands wide: a 2-band slope
## bends at an in-between column, which sometimes matches the ridge or groove beside it (a flat band).
## Some free columns branch: they start at the rim and merge into a neighbor partway down, so the
## upper wall has more, narrower facets than the lower wall.

# Hash seed offsets.
const _GAP_SEED: int = 7177
const _ROLE_SEED: int = 2203
const _DEPTH_SEED: int = 9341
const _BRANCH_SEED: int = 6143
# Least gap between free columns, in lattice steps. Smaller gaps make slivers.
const _MIN_GAP: float = 0.55
# Least gap between a free column and a fixed one. Spokes are pushed along the hex corner's
# own direction, so they may lean sideways.
const _FIXED_GAP: float = 0.75
# Sideways room kept clear toward a free neighbor's shifted corners, and toward a fixed column's ends.
const _FREE_CLEARANCE: float = 0.05
const _FIXED_CLEARANCE: float = 0.3
# A bent slope bends at least this far from either end, unless the band is flat.
const _BEND_MARGIN: float = 0.2
# Branches merge between these shares of the wall's height above the base.
const _MERGE_LOW: float = 0.35
const _MERGE_HIGH: float = 0.7


## Columns of a strip, ordered along the wall. forced: crossing edges that must be columns.
static func pick(tile: Vector2i, side: int, subdivisions: int, settings: HexCliffSettings, forced: PackedInt32Array) -> Array[HexCliffColumn]:
	var last: int = 2 * subdivisions - 1
	var fixed: Array[HexCliffColumn] = [HexCliffColumn.from_edge(0, true)]
	for k: int in forced:
		if k > 0 and k < last:
			fixed.append(HexCliffColumn.from_edge(k, false))
	fixed.append(HexCliffColumn.from_edge(last, true))
	var mean_gap: float = settings.column_width / HexLattice.get_spacing(subdivisions)
	var seed_value: int = settings.noise_seed + _GAP_SEED
	var columns: Array[HexCliffColumn] = []
	var n: int = 0
	for f: int in fixed.size():
		columns.append(fixed[f])
		if f == fixed.size() - 1:
			break
		var run: Array[HexCliffColumn] = []
		var position: float = fixed[f].along + _FIXED_GAP + 0.5 * mean_gap * HexCliffNoise.hash01(tile.x, tile.y, side * 64 + f, seed_value)
		var end: float = fixed[f + 1].along - _FIXED_GAP
		while position <= end:
			var column: HexCliffColumn = HexCliffColumn.from_position(position)
			# Spoke ends are shared with the next strip around the corner, so free columns keep off them.
			if column.top >= 1 and column.top <= subdivisions - 1 and column.bottom >= 1 and column.bottom <= subdivisions - 2:
				run.append(column)
			n += 1
			var spread: float = 2.0 * HexCliffNoise.hash01(tile.x, tile.y, side * 4096 + n, seed_value + 1) - 1.0
			position += maxf(_MIN_GAP, mean_gap * (1.0 + settings.column_width_variance * spread))
		_assign_depths(run, Vector3i(tile.x, tile.y, side * 64 + f), settings)
		_add_branches(run, Vector3i(tile.x, tile.y, side * 64 + f), settings)
		columns.append_array(run)
	# Fixed columns keep room 0, so free neighbors may take the space beside them.
	for c: int in range(1, columns.size() - 1):
		if not columns[c].is_fixed:
			columns[c].room = maxf(0.0, minf(_get_room(columns[c], columns[c - 1]), _get_room(columns[c], columns[c + 1])))
	return columns


# Ridges and grooves alternate over a run of free columns. Some slopes get an in-between column.
static func _assign_depths(run: Array[HexCliffColumn], key: Vector3i, settings: HexCliffSettings) -> void:
	if run.is_empty():
		return
	var seed_value: int = settings.noise_seed + _ROLE_SEED
	var extremes := PackedInt32Array()
	var i: int = 0
	while i < run.size():
		extremes.append(i)
		var split: bool = HexCliffNoise.hash01(key.x, key.y, key.z * 256 + i, seed_value) < settings.slope_split_chance
		# An in-between column needs an extreme after it.
		i += 2 if split and i + 2 < run.size() else 1
	var role: float = 1.0 if HexCliffNoise.hash01(key.x, key.y, key.z, seed_value + 1) < 0.5 else -1.0
	var depth_seed: int = settings.noise_seed + _DEPTH_SEED
	for e: int in extremes.size():
		var spread: float = settings.column_depth_variance * HexCliffNoise.hash01(key.x, key.y, key.z * 256 + e, depth_seed)
		run[extremes[e]].depth = role * settings.column_depth * (1.0 - spread)
		role = -role
	for e: int in extremes.size() - 1:
		var a: int = extremes[e]
		var b: int = extremes[e + 1]
		if b - a != 2:
			continue
		var t: float = lerpf(_BEND_MARGIN, 1.0 - _BEND_MARGIN, HexCliffNoise.hash01(key.x, key.y, key.z * 256 + a, depth_seed + 1))
		if HexCliffNoise.hash01(key.x, key.y, key.z * 256 + a, depth_seed + 2) < settings.slope_flat_chance:
			t = 0.0 if HexCliffNoise.hash01(key.x, key.y, key.z * 256 + a, depth_seed + 3) < 0.5 else 1.0
		run[a + 1].depth = lerpf(run[a].depth, run[b].depth, t)


# Turns some free columns into branches, merging into the neighbor on the ridge side.
# A merge target runs to the base, and never branches itself.
static func _add_branches(run: Array[HexCliffColumn], key: Vector3i, settings: HexCliffSettings) -> void:
	var seed_value: int = settings.noise_seed + _BRANCH_SEED
	var targets: Dictionary = {} # Run index -> true
	for i: int in run.size():
		if targets.has(i) or HexCliffNoise.hash01(key.x, key.y, key.z * 256 + i, seed_value) >= settings.column_branch_chance:
			continue
		var side: int = 0
		for step: int in [-1, 1]:
			var j: int = i + step
			if j < 0 or j >= run.size() or run[j].merge_side != 0:
				continue
			if side == 0 or run[j].depth > run[i + side].depth:
				side = step
		if side == 0:
			continue
		var target: HexCliffColumn = run[i + side]
		run[i].merge_side = side
		run[i].merge_height = lerpf(_MERGE_LOW, _MERGE_HIGH, HexCliffNoise.hash01(key.x, key.y, key.z * 256 + i, seed_value + 1))
		run[i].bottom = target.bottom
		targets[i + side] = true


# How far column's corners may shift toward neighbor, in lattice steps.
# Free neighbors split the gap; fixed ones keep their ends' span plus clearance.
static func _get_room(column: HexCliffColumn, neighbor: HexCliffColumn) -> float:
	if not neighbor.is_fixed:
		return 0.5 * absf(column.along - neighbor.along) - _FREE_CLEARANCE
	var span: Vector2 = neighbor.get_end_span()
	var gap: float = column.along - span.y if neighbor.along < column.along else span.x - column.along
	return gap - _FIXED_CLEARANCE
