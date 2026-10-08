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


## Push of a crease vertex on a wall facing direction.
static func get_crease_push(position: Vector3, direction: Vector2, strength: float, settings: HexCliffSettings, noise: HexCliffNoise) -> float:
	return noise.get_crests(position, direction) * settings.relief_amplitude * strength


## Push of a rim or base lattice point on a wall facing direction, clamped.
## Rims only recede and bases only flare, so a rim never hangs over its base.
static func get_edge_push(position: Vector3, direction: Vector2, is_rim: bool, is_base: bool, strength: float, settings: HexCliffSettings, noise: HexCliffNoise) -> float:
	var push: float = noise.get_crests(position, direction) * settings.relief_amplitude * settings.edge_relief_scale
	if is_rim:
		push -= settings.lip_depth
	if is_base:
		push += settings.foot_depth
	var low: float = -settings.edge_max_push if is_rim else 0.0
	var high: float = settings.edge_max_push if is_base else 0.0
	return clampf(push * strength, low, high)


## Adjusts crease pushes so no crease sits further out than the one below it,
## or further in than the rim above it. Removes overhangs and undercuts.
## outward: each crease's rest distance along the push direction, ordered bottom to top.
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
