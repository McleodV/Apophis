class_name HexCliffDisplacement
extends Object
## Static push amounts and directions for cliff vertices.
## Push is horizontal along the cliff's outward direction: positive = toward the low side.

# get_fade(): least alignment with a face where pushes start fading, and over how much they fade out.
const _FADE_START: float = 0.25
const _FADE_RANGE: float = 0.25
# A push barely moving a corner along a face's direction can't fix that face.
const _MIN_RATE: float = 0.01
# remove_overhangs(): least horizontal lean back per unit of height.
const _MIN_LEAN: float = 0.05


## Horizontal part of a front-facing triangle's unit normal. Points downhill.
static func get_downhill(a: Vector3, b: Vector3, c: Vector3) -> Vector2:
	var normal: Vector3 = (c - a).cross(b - a).normalized()
	return Vector2(normal.x, normal.z)


## 0 at the cliff threshold, 1 half a level above it. Fades geometry where cliffs end.
static func get_strength(height_difference: float, elevation_step: float) -> float:
	var levels: float = absf(height_difference) / elevation_step
	return smoothstep(HexCliffBands.CLIFF_LEVELS, HexCliffBands.CLIFF_LEVELS + 0.5, levels)


## Push of a facet corner.
static func get_crease_push(position: Vector3, strength: float, settings: HexCliffSettings, noise: HexCliffNoise) -> float:
	return noise.get_relief(position) * settings.relief_amplitude * strength


## Push of a rim or base lattice point, clamped to max_push.
## Rims only recede and bases only flare, so a rim never hangs over its base.
static func get_edge_push(position: Vector3, is_rim: bool, is_base: bool, strength: float, max_push: float, settings: HexCliffSettings, noise: HexCliffNoise) -> float:
	var push: float = noise.get_relief(position) * settings.relief_amplitude * settings.edge_relief_scale
	if is_rim:
		push -= settings.lip_depth
	if is_base:
		push += settings.foot_depth
	var low: float = -max_push if is_rim else 0.0
	var high: float = max_push if is_base else 0.0
	return clampf(push * strength, low, high)


## Appends the unit downhill direction of front-facing triangle a, b, c, unless it's flat.
static func append_downhill(faces: PackedVector2Array, a: Vector3, b: Vector3, c: Vector3) -> void:
	var downhill: Vector2 = get_downhill(a, b, c)
	if downhill.length() > 0.0001:
		faces.append(downhill.normalized())


## Push direction for a vertex beside faces: the average of their downhill directions.
static func get_average_direction(faces: PackedVector2Array) -> Vector2:
	var sum := Vector2.ZERO
	for face: Vector2 in faces:
		sum += face
	return sum.normalized() if sum.length() > 0.0001 else Vector2.ZERO


## How much of a push a vertex keeps when the faces around it look different ways.
## A rim pushed in must recede from every face; that fails once a face looks against the push.
static func get_fade(direction: Vector2, faces: PackedVector2Array) -> float:
	var alignment: float = 1.0
	for face: Vector2 in faces:
		alignment = minf(alignment, direction.dot(face))
	return clampf((alignment - _FADE_START) / _FADE_RANGE, 0.0, 1.0)


## Adjusts facet corner pushes so no corner sits further out than the one below it,
## or further in than the rim above it, in the downhill direction of any face beside the edge.
## Each step up must also lean back by at least _MIN_LEAN, so faces never stand exactly upright.
## Removes overhangs and undercuts.
## lines: each corner's position before its push, ordered bottom to top. pushes: along direction.
## faces: unit downhill directions of the faces beside the edge.
## base, rim: final positions of the edge's bottom and top points.
static func remove_overhangs(lines: PackedVector3Array, pushes: PackedFloat32Array, direction: Vector2, faces: PackedVector2Array, base: Vector3, rim: Vector3) -> void:
	var limits := PackedFloat32Array() # Per face: how far out the next corner up may sit
	var height: float = base.y
	for face: Vector2 in faces:
		limits.append(_get_out(base, face))
	for i: int in pushes.size():
		var lean: float = (lines[i].y - height) * _MIN_LEAN
		for f: int in faces.size():
			var rate: float = direction.dot(faces[f])
			var excess: float = _get_out(lines[i], faces[f]) + pushes[i] * rate - (limits[f] - lean)
			if rate > _MIN_RATE and excess > 0.0:
				pushes[i] -= excess / rate
		for f: int in faces.size():
			limits[f] = _get_out(lines[i], faces[f]) + pushes[i] * direction.dot(faces[f])
		height = lines[i].y
	height = rim.y
	for f: int in faces.size():
		limits[f] = _get_out(rim, faces[f])
	for i: int in range(pushes.size() - 1, -1, -1):
		var lean: float = (height - lines[i].y) * _MIN_LEAN
		for f: int in faces.size():
			var rate: float = direction.dot(faces[f])
			var shortfall: float = limits[f] + lean - _get_out(lines[i], faces[f]) - pushes[i] * rate
			if rate > _MIN_RATE and shortfall > 0.0:
				pushes[i] += shortfall / rate
		for f: int in faces.size():
			limits[f] = _get_out(lines[i], faces[f]) + pushes[i] * direction.dot(faces[f])
		height = lines[i].y


## Final band positions, bottom to top. Creases are pushed from their line position along direction;
## every other band sits on the straight line between the creases or end points around it.
static func place_bands(lines: PackedVector3Array, crease_bands: PackedInt32Array, pushes: PackedFloat32Array, direction: Vector2, lower: Vector3, upper: Vector3) -> PackedVector3Array:
	var finals := PackedVector3Array()
	finals.resize(lines.size())
	var offset := Vector3(direction.x, 0.0, direction.y)
	var previous_point: Vector3 = lower
	var previous_band: int = -1
	for c: int in crease_bands.size() + 1:
		var is_end: bool = c == crease_bands.size()
		var next_band: int = lines.size() if is_end else crease_bands[c]
		var next_point: Vector3 = upper if is_end else lines[next_band] + offset * pushes[c]
		for i: int in range(previous_band + 1, next_band):
			var t: float = (lines[i].y - previous_point.y) / (next_point.y - previous_point.y)
			finals[i] = previous_point.lerp(next_point, t)
		if not is_end:
			finals[next_band] = next_point
		previous_point = next_point
		previous_band = next_band
	return finals


static func _get_out(position: Vector3, face: Vector2) -> float:
	return position.x * face.x + position.z * face.y
