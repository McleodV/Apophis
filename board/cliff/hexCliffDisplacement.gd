class_name HexCliffDisplacement
extends Object
## Static push amounts and directions for cliff vertices.
## Push is horizontal along the cliff's outward direction: positive = toward the low side.


## Horizontal part of a front-facing triangle's unit normal. Points downhill.
static func get_downhill(a: Vector3, b: Vector3, c: Vector3) -> Vector2:
	var normal: Vector3 = (c - a).cross(b - a).normalized()
	return Vector2(normal.x, normal.z)


## 0 at the cliff threshold, 1 half a level above it. Fades geometry where cliffs end.
static func get_strength(height_difference: float, elevation_step: float) -> float:
	var levels: float = absf(height_difference) / elevation_step
	return smoothstep(HexCliffBands.CLIFF_LEVELS, HexCliffBands.CLIFF_LEVELS + 0.5, levels)


## Push of a band vertex on an edge spanning bottom to top.
static func get_band_push(position: Vector3, bottom: float, top: float, strength: float, settings: HexCliffSettings, noise: HexCliffNoise) -> float:
	var lip: float = 1.0 - smoothstep(0.0, settings.lip_height, top - position.y)
	var foot: float = 1.0 - smoothstep(0.0, settings.foot_height, position.y - bottom)
	# Relief eases to the rim and base amount near the ends.
	var relief_scale: float = lerpf(settings.edge_relief_scale, 1.0, minf(1.0 - lip, 1.0 - foot))
	var push: float = foot * settings.foot_depth - lip * settings.lip_depth
	push += noise.get_relief(position) * settings.relief_amplitude * relief_scale
	return push * strength


## Push of a rim or base lattice point. Matches get_band_push at the ends, then clamps.
## Rims only recede and bases only flare, so a rim never hangs over its base.
static func get_edge_push(position: Vector3, is_rim: bool, is_base: bool, strength: float, settings: HexCliffSettings, noise: HexCliffNoise) -> float:
	var push: float = noise.get_relief(position) * settings.relief_amplitude * settings.edge_relief_scale
	if is_rim:
		push -= settings.lip_depth
	if is_base:
		push += settings.foot_depth
	var low: float = -settings.edge_max_push if is_rim else 0.0
	var high: float = settings.edge_max_push if is_base else 0.0
	return clampf(push * strength, low, high)


## Adjusts band pushes so no band sits further out than the one below it,
## or further in than the rim above it. Removes overhangs and undercuts.
## outward: each band's rest distance along the push direction, ordered bottom to top.
## base_outward, rim_outward: final distances of the edge's bottom and top points.
static func remove_overhangs(outward: PackedFloat32Array, pushes: PackedFloat32Array, base_outward: float, rim_outward: float) -> void:
	var limit: float = base_outward
	for i: int in pushes.size():
		var out: float = outward[i] + pushes[i]
		if out > limit:
			pushes[i] -= out - limit
			out = limit
		limit = out
	var minimum: float = rim_outward
	for i: int in range(pushes.size() - 1, -1, -1):
		var out: float = outward[i] + pushes[i]
		if out < minimum:
			pushes[i] += minimum - out
			out = minimum
		minimum = out
