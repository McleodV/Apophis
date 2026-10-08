class_name HexCliffSlope
extends Object
## Static check and repair of the no-overhang rule on a strip's faces: at every spot along the
## wall, the face never sits further out higher up. Holds across facets, not only up each column.
## For a front-facing triangle with normal n, out per unit height at a fixed spot is
## -n.y / n.dot(outward), so the rule is n.y >= 0.
## Repairs move free vertices straight in or out. That leaves n.dot(outward) unchanged, so faces
## can't fold. Each step moves the least needed to level one face (cyclic projection).

# Repairs aim this far past level, as out per unit height, so float noise can't tip a face over.
const _TARGET: float = 0.004
const _MAX_SWEEPS: int = 200
# Faces seen this nearly edge-on from outside count as folded.
const _MIN_FACING: float = 0.001


## Moves free vertices in or out until no face with a free vertex leans out going up.
## triangles: front-facing index triples. free: 1 per vertex that may move.
## Returns false if such a face is folded or can't be repaired; positions may be changed then.
static func enforce(triangles: PackedInt32Array, positions: PackedVector3Array, free: PackedByteArray, outward: Vector3) -> bool:
	var movable := PackedInt32Array() # Triangle starts with a free vertex
	for i: int in range(0, triangles.size(), 3):
		if not (free[triangles[i]] or free[triangles[i + 1]] or free[triangles[i + 2]]):
			continue
		var normal: Vector3 = _get_normal(positions, triangles, i)
		if normal.dot(outward) <= _MIN_FACING * normal.length():
			return false
		movable.append(i)
	for sweep: int in _MAX_SWEEPS:
		var changed: bool = false
		for i: int in movable:
			var normal: Vector3 = _get_normal(positions, triangles, i)
			if normal.y >= 0.0:
				continue
			changed = true
			_level(triangles, i, positions, free, outward, _TARGET * normal.dot(outward) - normal.y)
		if not changed:
			return true
	return false


# Raises triangle i's normal.y by rise, moving its free vertices along outward.
# Moving a by d along u changes the normal by d * u.cross(c - b); likewise b by u.cross(a - c),
# c by u.cross(b - a).
static func _level(triangles: PackedInt32Array, i: int, positions: PackedVector3Array, free: PackedByteArray, outward: Vector3, rise: float) -> void:
	var rates := PackedFloat32Array([0.0, 0.0, 0.0])
	var total: float = 0.0
	for k: int in 3:
		if not free[triangles[i + k]]:
			continue
		var before: Vector3 = positions[triangles[i + (k + 1) % 3]]
		var after: Vector3 = positions[triangles[i + (k + 2) % 3]]
		rates[k] = outward.cross(after - before).y
		total += rates[k] * rates[k]
	if total < 1e-12:
		return
	for k: int in 3:
		if rates[k] != 0.0:
			positions[triangles[i + k]] += outward * (rise * rates[k] / total)


static func _get_normal(positions: PackedVector3Array, triangles: PackedInt32Array, i: int) -> Vector3:
	var a: Vector3 = positions[triangles[i]]
	return (positions[triangles[i + 2]] - a).cross(positions[triangles[i + 1]] - a)
