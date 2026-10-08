class_name HexCliffDisplacement
extends Object
## Static push amounts and directions for cliff vertices.
## Push is horizontal along the cliff's outward direction: positive = toward the low side.

# get_fade(): least alignment with a face where pushes start fading, and over how much they fade out.
const _FADE_START: float = 0.25
const _FADE_RANGE: float = 0.25
# A push barely moving a corner along a face's direction can't fix that face.
const _MIN_RATE: float = 0.01
# remove_overhangs(): horizontal lean back per unit of height, when there is room for it.
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


## Push of a rim or base lattice point outside a strip's column ends, from 0 to max_push.
## Both only push out: rims never pull back behind the grid line, and bases spread into a foot.
static func get_edge_push(position: Vector3, strength: float, max_push: float, settings: HexCliffSettings, noise: HexCliffNoise) -> float:
	var amount: float = 0.5 + 0.5 * noise.get_relief(position)
	return clampf(amount * settings.edge_relief_scale * max_push, 0.0, max_push) * strength


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
## A rim pushed out must move out from every face; that fails once a face looks against the push.
static func get_fade(direction: Vector2, faces: PackedVector2Array) -> float:
	var alignment: float = 1.0
	for face: Vector2 in faces:
		alignment = minf(alignment, direction.dot(face))
	return clampf((alignment - _FADE_START) / _FADE_RANGE, 0.0, 1.0)


## Adjusts facet corner pushes so no corner sits further out than the one below it,
## or further in than the rim above it, in the downhill direction of any face beside the edge.
## Each step up also leans back, so faces never stand exactly upright.
## Where there is room, corners also stay lip out from the rim and foot in from the base.
## Removes overhangs and undercuts.
## lines: each corner's position before its push, ordered bottom to top. pushes: along direction.
## faces: unit downhill directions of the faces beside the edge.
## base, rim: final positions of the edge's bottom and top points.
static func remove_overhangs(lines: PackedVector3Array, pushes: PackedFloat32Array, direction: Vector2, faces: PackedVector2Array, base: Vector3, rim: Vector3, lip: float, foot: float) -> void:
	# Lean only as much as the gap between rim and base allows.
	var room: float = INF
	for face: Vector2 in faces:
		room = minf(room, _get_out(base, face) - _get_out(rim, face))
	var lean: float = clampf(0.5 * room / maxf(rim.y - base.y, 0.0001), 0.0, _MIN_LEAN)
	# Lip and foot first, then the hard limits, which win where both can't fit.
	_cap_from_base(lines, pushes, direction, faces, base, foot, lean)
	_floor_from_rim(lines, pushes, direction, faces, rim, lip, lean)
	_cap_from_base(lines, pushes, direction, faces, base, 0.0, lean)
	_floor_from_rim(lines, pushes, direction, faces, rim, 0.0, lean)


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


# Bottom up: each corner no further out than the one below it, or than the base less margin.
static func _cap_from_base(lines: PackedVector3Array, pushes: PackedFloat32Array, direction: Vector2, faces: PackedVector2Array, base: Vector3, margin: float, lean: float) -> void:
	var limits := PackedFloat32Array() # Per face: how far out the next corner up may sit
	for face: Vector2 in faces:
		limits.append(_get_out(base, face) - margin)
	var height: float = base.y
	for i: int in pushes.size():
		var step: float = (lines[i].y - height) * lean
		for f: int in faces.size():
			var rate: float = direction.dot(faces[f])
			var excess: float = _get_out(lines[i], faces[f]) + pushes[i] * rate - (limits[f] - step)
			if rate > _MIN_RATE and excess > 0.0:
				pushes[i] -= excess / rate
		for f: int in faces.size():
			limits[f] = _get_out(lines[i], faces[f]) + pushes[i] * direction.dot(faces[f])
		height = lines[i].y


# Top down: each corner no further in than the one above it, or than the rim plus margin.
static func _floor_from_rim(lines: PackedVector3Array, pushes: PackedFloat32Array, direction: Vector2, faces: PackedVector2Array, rim: Vector3, margin: float, lean: float) -> void:
	var limits := PackedFloat32Array() # Per face: how far in the next corner down may sit
	for face: Vector2 in faces:
		limits.append(_get_out(rim, face) + margin)
	var height: float = rim.y
	for i: int in range(pushes.size() - 1, -1, -1):
		var step: float = (height - lines[i].y) * lean
		for f: int in faces.size():
			var rate: float = direction.dot(faces[f])
			var shortfall: float = limits[f] + step - _get_out(lines[i], faces[f]) - pushes[i] * rate
			if rate > _MIN_RATE and shortfall > 0.0:
				pushes[i] += shortfall / rate
		for f: int in faces.size():
			limits[f] = _get_out(lines[i], faces[f]) + pushes[i] * direction.dot(faces[f])
		height = lines[i].y


static func _get_out(position: Vector3, face: Vector2) -> float:
	return position.x * face.x + position.z * face.y
