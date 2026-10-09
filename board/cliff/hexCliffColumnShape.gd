class_name HexCliffColumnShape
extends Object
## Static facet corner placement for a strip's own columns.
## Corners lie on the column's slab planes, so slabs stay flat. Each column draws its own corner
## heights, crowding toward the rim, and its corners shift sideways within its room, so slab edges
## and the seams between them wander. A break gets corners of its own: two close together at a
## ledge, so the small face between them looks up, or one at a kink.
## Up each column, no corner sits further out than the one below.

# Hash seed offsets.
const _HEIGHT_SEED: int = 5591
const _SHIFT_SEED: int = 8087
# Corners stay this share of the local gap clear of the rim and base.
const _END_GAP: float = 0.3
# Share of the column's height at each end over which sideways shift fades in.
# Near its ends a column converges on its rim and base points.
const _SHIFT_FADE: float = 0.3
# Sideways shift: weights of per-corner randomness and of smooth noise. Seam edges use smooth
# noise alone, sampled at the seam's middle, so both edges of a seam bend alike.
const _SHIFT_RANDOM: float = 0.6
const _SHIFT_SMOOTH: float = 0.8
const _SEAM_SMOOTH: float = 1.4
# Corner gap scale at facet_height_taper 1: at the base, and at the rim.
const _TAPER_BASE: float = 1.5
const _TAPER_RIM: float = 0.4
## Half the height of a ledge's face, in world units. Its corners sit this far above and below the break.
const LEDGE_RISE: float = 0.012

# How far other corners keep from a break.
const _BREAK_CLEAR: float = 0.03


## Corner positions of a column, bottom to top.
## key: unique per column; seeds its randomness. Seam edges use their seam's key instead.
## top, bottom: final positions of its ends.
## ends_push: how far bottom and top already sit out from rest.
## scale: 1 = full shape. Lower values calm sideways shift and roughness; slabs keep their planes.
static func build(column: HexCliffColumn, key: Vector3i, top: Vector3, bottom: Vector3, ends_push: Vector2, frame: HexCliffFrame, settings: HexCliffSettings, noise: HexCliffNoise, scale: float) -> PackedVector3Array:
	var height: float = top.y - bottom.y
	var seam: bool = not is_nan(column.seam_center)
	var anchor: Vector3 = (top + bottom) * 0.5
	if seam:
		key = Vector3i(key.x, key.y, roundi(column.seam_center * 1000.0))
		anchor = frame.to_world(column.seam_center, 0.0, anchor.y)
	var heights: PackedFloat32Array = _get_heights(key, height, anchor, settings, noise)
	_add_breaks(heights, column, height)
	var alongs := PackedFloat32Array()
	for i: int in heights.size():
		var t: float = heights[i] / height
		var fade: float = clampf(minf(t, 1.0 - t) / _SHIFT_FADE, 0.0, 1.0)
		var shift: float
		if seam:
			shift = _SEAM_SMOOTH * noise.get_wander(frame.to_world(column.seam_center, 0.0, bottom.y + heights[i]))
		else:
			var random: float = 2.0 * HexCliffNoise.hash01(key.x, key.y, key.z * 256 + i, settings.noise_seed + _SHIFT_SEED) - 1.0
			shift = _SHIFT_RANDOM * random + _SHIFT_SMOOTH * noise.get_wander(frame.to_world(column.along, 0.0, bottom.y + heights[i]))
		alongs.append(column.along + clampf(shift, -1.0, 1.0) * fade * column.room * settings.slab_edge_wander * scale)
	_converge(alongs, heights, frame.get_along(bottom), frame.get_along(top), height, frame.get_step())
	var bottom_out: float = frame.get_out(bottom)
	var top_out: float = frame.get_out(top)
	var lines := PackedVector3Array()
	var pushes := PackedFloat32Array()
	for i: int in heights.size():
		var t: float = heights[i] / height
		var line: Vector3 = frame.to_world(alongs[i], lerpf(bottom_out, top_out, t), bottom.y + heights[i])
		lines.append(line)
		# Forced columns have no plane: their corners stay on the straight line between their ends.
		if column.lower == null:
			pushes.append(0.0)
			continue
		var push: float = column.get_push(alongs[i], t) + noise.get_relief(line) * settings.slab_roughness * scale
		# The line between the ends already carries their pushes.
		pushes.append(push - lerpf(ends_push.x, ends_push.y, t))
	var direction := Vector2(frame.outward.x, frame.outward.z)
	HexCliffDisplacement.remove_overhangs(lines, pushes, direction, PackedVector2Array([direction]), bottom, top, 0.0, 0.0)
	var corners := PackedVector3Array()
	for i: int in lines.size():
		corners.append(lines[i] + frame.outward * pushes[i])
	return corners


# Replaces corners near each of the column's breaks with the break's own: two around a ledge, one at a kink.
static func _add_breaks(heights: PackedFloat32Array, column: HexCliffColumn, height: float) -> void:
	for entry: Vector3 in column.breaks:
		var at: float = entry.x * height
		var rise: float = LEDGE_RISE * entry.y
		for i: int in range(heights.size() - 1, -1, -1):
			if absf(heights[i] - at) < rise + _BREAK_CLEAR:
				heights.remove_at(i)
	for entry: Vector3 in column.breaks:
		var at: float = entry.x * height
		var rise: float = LEDGE_RISE * entry.y
		var added := PackedFloat32Array([at - rise, at + rise]) if entry.y > 0.0 else PackedFloat32Array([at])
		for value: float in added:
			heights.insert(heights.bsearch(value), value)


# Pulls corners within a lattice step of height from an end toward that end's along position,
# in proportion, so a column never runs further sideways than up near its ends.
# The pull depends on height alone, so both edges of a seam keep their order and never meet early.
static func _converge(alongs: PackedFloat32Array, heights: PackedFloat32Array, bottom: float, top: float, height: float, step: float) -> void:
	for i: int in alongs.size():
		alongs[i] = lerpf(bottom, alongs[i], minf(heights[i] / step, 1.0))
		alongs[i] = lerpf(top, alongs[i], minf((height - heights[i]) / step, 1.0))


# Corner heights above the bottom end, ascending, at jittered gaps that shrink toward the rim. At least one.
static func _get_heights(key: Vector3i, height: float, anchor: Vector3, settings: HexCliffSettings, noise: HexCliffNoise) -> PackedFloat32Array:
	var gap: float = settings.facet_height / maxf(HexCliffBands.get_density(anchor, settings, noise), 0.05)
	var base_scale: float = lerpf(1.0, _TAPER_BASE, settings.facet_height_taper)
	var rim_scale: float = lerpf(1.0, _TAPER_RIM, settings.facet_height_taper)
	var seed_value: int = settings.noise_seed + _HEIGHT_SEED
	var heights := PackedFloat32Array()
	var position: float = lerpf(_END_GAP, 1.0, HexCliffNoise.hash01(key.x, key.y, key.z * 256, seed_value)) * gap * base_scale
	var end_gap: float = _END_GAP * gap * rim_scale
	var n: int = 0
	while position < height - end_gap:
		heights.append(position)
		n += 1
		var spread: float = 2.0 * HexCliffNoise.hash01(key.x, key.y, key.z * 256 + n, seed_value) - 1.0
		var local_gap: float = gap * lerpf(base_scale, rim_scale, position / height)
		position += local_gap * (1.0 + settings.facet_height_jitter * spread)
	if heights.is_empty():
		heights.append(height * lerpf(0.35, 0.65, HexCliffNoise.hash01(key.x, key.y, key.z * 256 + 1, seed_value + 1)))
	return heights
