class_name HexCliffColumnShape
extends Object
## Static facet corner placement for a strip's own columns.
## Each column draws its own corner heights, so corners on neighboring columns don't line up
## into level rows. Corners crowd toward the rim and on faces that stand out, so facets there are shorter.
## Corners then shift sideways within the column's room, and in or out by the column's depth
## and relief noise, measured from the wall at rest so pushed ends don't add to it.
## Up each column, no corner sits further out than the one below.

# Hash seed offsets.
const _HEIGHT_SEED: int = 5591
const _SHIFT_SEED: int = 8087
const _DEPTH_SEED: int = 4813
# Corners stay this share of the local gap clear of the rim and base.
const _END_GAP: float = 0.3
# Share of the column's height at each end over which sideways shift fades in.
# Near its ends a column converges on its rim and base points.
const _SHIFT_FADE: float = 0.3
# Sideways shift: weights of per-corner randomness and of smooth noise.
const _SHIFT_RANDOM: float = 0.6
const _SHIFT_SMOOTH: float = 0.8
# _limit_lean(): most sideways run per unit of rise, and passes over the column.
const _MAX_LEAN: float = 1.0
const _LEAN_SWEEPS: int = 3
# Corner gap scale at facet_height_taper 1: at the base, and at the rim.
const _TAPER_BASE: float = 1.5
const _TAPER_RIM: float = 0.4
# Corner gap scale on a face at full column_depth, at ridge_detail 1.
const _RIDGE_GAP: float = 0.5


## Corner positions of a column, bottom to top.
## key: unique per column; seeds its randomness. top, bottom: final positions of its ends; a merging
## column's bottom is the corner it merges into. ends_push: how far bottom and top already sit out
## from rest. wall: heights of the wall's base and rim there.
## scale: 1 = full shape. Lower values calm sideways shift and pushes.
static func build(column: HexCliffColumn, key: Vector3i, top: Vector3, bottom: Vector3, ends_push: Vector2, wall: Vector2, frame: HexCliffFrame, settings: HexCliffSettings, noise: HexCliffNoise, scale: float) -> PackedVector3Array:
	var height: float = top.y - bottom.y
	var heights: PackedFloat32Array = _get_heights(column, key, bottom.y, height, wall, (top + bottom) * 0.5, settings, noise)
	var bottom_out: float = frame.get_out(bottom)
	var top_out: float = frame.get_out(top)
	var alongs := PackedFloat32Array()
	for i: int in heights.size():
		var t: float = heights[i] / height
		var fade: float = clampf(minf(t, 1.0 - t) / _SHIFT_FADE, 0.0, 1.0)
		var random: float = 2.0 * HexCliffNoise.hash01(key.x, key.y, key.z * 256 + i, settings.noise_seed + _SHIFT_SEED) - 1.0
		var smooth: float = noise.get_wander(frame.to_world(column.along, 0.0, bottom.y + heights[i]))
		var shift: float = clampf(_SHIFT_RANDOM * random + _SHIFT_SMOOTH * smooth, -1.0, 1.0)
		alongs.append(column.along + shift * fade * column.room * settings.column_wander * scale)
	_limit_lean(alongs, heights, Vector2(frame.get_along(bottom), 0.0), Vector2(frame.get_along(top), height), frame.get_step())
	var lines := PackedVector3Array()
	var pushes := PackedFloat32Array()
	for i: int in heights.size():
		var line: Vector3 = frame.to_world(alongs[i], lerpf(bottom_out, top_out, heights[i] / height), bottom.y + heights[i])
		var jitter: float = settings.column_depth_jitter * HexCliffNoise.hash01(key.x, key.y, key.z * 256 + i, settings.noise_seed + _DEPTH_SEED)
		var push: float = column.depth * (1.0 - jitter) + noise.get_relief(line) * settings.relief_amplitude
		# The line between the ends already carries their pushes.
		var carried: float = lerpf(ends_push.x, ends_push.y, heights[i] / height)
		lines.append(line)
		pushes.append(push * scale - carried)
	var direction := Vector2(frame.outward.x, frame.outward.z)
	# A merge point is inside the wall, so there's no foot to set back from.
	var foot: float = settings.foot_depth if column.merge_side == 0 else 0.0
	HexCliffDisplacement.remove_overhangs(lines, pushes, direction, PackedVector2Array([direction]), bottom, top, settings.lip_depth, foot)
	var corners := PackedVector3Array()
	for i: int in lines.size():
		corners.append(lines[i] + frame.outward * pushes[i])
	return corners


# Keeps each step between neighboring corners, and to the column's ends, from running further
# sideways than up. Near-level steps would turn faces edge-on. Ends are (along, height).
static func _limit_lean(alongs: PackedFloat32Array, heights: PackedFloat32Array, bottom: Vector2, top: Vector2, step: float) -> void:
	for sweep: int in _LEAN_SWEEPS:
		var previous: Vector2 = bottom
		for i: int in alongs.size():
			var run: float = _MAX_LEAN * (heights[i] - previous.y) / step
			alongs[i] = clampf(alongs[i], previous.x - run, previous.x + run)
			previous = Vector2(alongs[i], heights[i])
		var next: Vector2 = top
		for i: int in range(alongs.size() - 1, -1, -1):
			var run: float = _MAX_LEAN * (next.y - heights[i]) / step
			alongs[i] = clampf(alongs[i], next.x - run, next.x + run)
			next = Vector2(alongs[i], heights[i])


# Corner heights above the bottom end, ascending, at jittered gaps. At least one.
# Gaps shrink toward the rim and on faces that stand out.
static func _get_heights(column: HexCliffColumn, key: Vector3i, bottom: float, height: float, wall: Vector2, anchor: Vector3, settings: HexCliffSettings, noise: HexCliffNoise) -> PackedFloat32Array:
	var gap: float = settings.facet_height / maxf(HexCliffBands.get_density(anchor, settings, noise), 0.05)
	var ridge: float = clampf(column.depth / maxf(settings.column_depth, 0.001), 0.0, 1.0)
	gap *= lerpf(1.0, _RIDGE_GAP, settings.ridge_detail * ridge)
	var wall_height: float = maxf(wall.y - wall.x, 0.001)
	var base_scale: float = lerpf(1.0, _TAPER_BASE, settings.facet_height_taper)
	var rim_scale: float = lerpf(1.0, _TAPER_RIM, settings.facet_height_taper)
	var seed_value: int = settings.noise_seed + _HEIGHT_SEED
	var heights := PackedFloat32Array()
	var start_gap: float = gap * lerpf(base_scale, rim_scale, clampf((bottom - wall.x) / wall_height, 0.0, 1.0))
	var end_gap: float = _END_GAP * gap * lerpf(base_scale, rim_scale, clampf((bottom + height - wall.x) / wall_height, 0.0, 1.0))
	var position: float = lerpf(_END_GAP * start_gap, start_gap, HexCliffNoise.hash01(key.x, key.y, key.z * 256, seed_value))
	var n: int = 0
	while position < height - end_gap:
		heights.append(position)
		n += 1
		var spread: float = 2.0 * HexCliffNoise.hash01(key.x, key.y, key.z * 256 + n, seed_value) - 1.0
		var local_gap: float = gap * lerpf(base_scale, rim_scale, clampf((bottom + position - wall.x) / wall_height, 0.0, 1.0))
		position += local_gap * (1.0 + settings.facet_height_jitter * spread)
	if heights.is_empty():
		heights.append(height * lerpf(0.35, 0.65, HexCliffNoise.hash01(key.x, key.y, key.z * 256 + 1, seed_value + 1)))
	return heights
