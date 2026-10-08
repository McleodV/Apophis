class_name HexCliffColumnShape
extends Object
## Static facet corner placement for a strip's own columns.
## Each column draws its own corner heights, so corners on neighboring columns don't line up
## into level rows. Corners then shift sideways within the column's room, and in or out by the
## column's depth and relief noise. Up each column, no corner sits further out than the one below.

# Hash seed offsets.
const _HEIGHT_SEED: int = 5591
const _SHIFT_SEED: int = 8087
const _DEPTH_SEED: int = 4813
# Corners stay this share of the average gap clear of the rim and base.
const _END_GAP: float = 0.3
# Share of the column's height at each end over which sideways shift fades in.
# Near its ends a column converges on its rim and base points.
const _SHIFT_FADE: float = 0.3
# Sideways shift: weights of per-corner randomness and of smooth noise.
const _SHIFT_RANDOM: float = 0.6
const _SHIFT_SMOOTH: float = 0.8


## Corner positions of a column, bottom to top.
## key: unique per column; seeds its randomness. top, bottom: final positions of its ends.
## scale: 1 = full shape. Lower values calm sideways shift and pushes.
static func build(column: HexCliffColumn, key: Vector3i, top: Vector3, bottom: Vector3, frame: HexCliffFrame, settings: HexCliffSettings, noise: HexCliffNoise, scale: float) -> PackedVector3Array:
	var height: float = top.y - bottom.y
	var heights: PackedFloat32Array = _get_heights(key, height, (top + bottom) * 0.5, settings, noise)
	var bottom_out: float = frame.get_out(bottom)
	var top_out: float = frame.get_out(top)
	var lines := PackedVector3Array()
	var pushes := PackedFloat32Array()
	for i: int in heights.size():
		var t: float = heights[i] / height
		var line: Vector3 = frame.to_world(column.along, lerpf(bottom_out, top_out, t), bottom.y + heights[i])
		var fade: float = clampf(minf(t, 1.0 - t) / _SHIFT_FADE, 0.0, 1.0)
		var random: float = 2.0 * HexCliffNoise.hash01(key.x, key.y, key.z * 256 + i, settings.noise_seed + _SHIFT_SEED) - 1.0
		var shift: float = clampf(_SHIFT_RANDOM * random + _SHIFT_SMOOTH * noise.get_wander(line), -1.0, 1.0)
		line += frame.along * (shift * fade * column.room * settings.column_wander * scale * frame.get_step())
		var jitter: float = settings.column_depth_jitter * HexCliffNoise.hash01(key.x, key.y, key.z * 256 + i, settings.noise_seed + _DEPTH_SEED)
		var push: float = column.depth * (1.0 - jitter) + noise.get_relief(line) * settings.relief_amplitude
		lines.append(line)
		pushes.append(push * scale)
	var direction := Vector2(frame.outward.x, frame.outward.z)
	HexCliffDisplacement.remove_overhangs(lines, pushes, direction, PackedVector2Array([direction]), bottom, top, settings.lip_depth, settings.foot_depth)
	var corners := PackedVector3Array()
	for i: int in lines.size():
		corners.append(lines[i] + frame.outward * pushes[i])
	return corners


# Corner heights above the bottom end, ascending, at jittered gaps. At least one.
static func _get_heights(key: Vector3i, height: float, anchor: Vector3, settings: HexCliffSettings, noise: HexCliffNoise) -> PackedFloat32Array:
	var gap: float = settings.facet_height / maxf(HexCliffBands.get_density(anchor, settings, noise), 0.05)
	var end_gap: float = _END_GAP * gap
	var seed_value: int = settings.noise_seed + _HEIGHT_SEED
	var heights := PackedFloat32Array()
	var position: float = lerpf(end_gap, gap, HexCliffNoise.hash01(key.x, key.y, key.z * 256, seed_value))
	var n: int = 0
	while position < height - end_gap:
		heights.append(position)
		n += 1
		var spread: float = 2.0 * HexCliffNoise.hash01(key.x, key.y, key.z * 256 + n, seed_value) - 1.0
		position += gap * (1.0 + settings.facet_height_jitter * spread)
	if heights.is_empty():
		heights.append(height * lerpf(0.35, 0.65, HexCliffNoise.hash01(key.x, key.y, key.z * 256 + 1, seed_value + 1)))
	return heights
