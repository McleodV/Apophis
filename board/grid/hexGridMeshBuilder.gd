class_name HexGridMeshBuilder
extends Object
## Static builder for straight grid lines along every hex edge of a group of tiles.
## Lines follow the terrain height at the lattice points on each edge, before cliff displacement,
## as seen from the edge's two tiles. A third tile at a corner is ignored, so lines never climb a cliff.
## Mesh layout for hexGrid.gdshader: each segment is a quad whose corners have
## VERTEX = their end of the segment, CUSTOM0.xyz = the other end, CUSTOM0.w = side (-1 or 1).

const _CUSTOM0_FORMAT: int = Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT


static func build(data: HexMapData, settings: HexTerrainSettings, tiles: Array[Vector2i]) -> ArrayMesh:
	var subdivisions: int = settings.subdivisions
	var positions := PackedVector3Array()
	var others := PackedFloat32Array()
	var indices := PackedInt32Array()
	for axial: Vector2i in tiles:
		var center: Vector2i = HexLattice.hex_center(axial, subdivisions)
		for direction: int in 6:
			var neighbor: Vector2i = HexMath.neighbor(axial, direction)
			# Shared edges are drawn once, by the tile on their 0-2 side. Map edges by the tile on the map.
			if direction >= 3 and data.has_tile(neighbor):
				continue
			# The edge shared with neighbor i runs from corner i - 1 to corner i.
			var start_corner: Vector2i = HexLattice.CORNERS[posmod(direction - 1, 6)]
			var start: Vector2i = center + start_corner * subdivisions
			var step: Vector2i = HexLattice.CORNERS[direction] - start_corner
			var previous: Vector3 = _get_point(start, axial, neighbor, data, settings)
			for i: int in range(1, subdivisions + 1):
				var current: Vector3 = _get_point(start + step * i, axial, neighbor, data, settings)
				_add_segment(previous, current, positions, others, indices)
				previous = current
	var mesh := ArrayMesh.new()
	if positions.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = positions
	arrays[Mesh.ARRAY_CUSTOM0] = others
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, _CUSTOM0_FORMAT)
	return mesh


static func _get_point(point: Vector2i, tile: Vector2i, neighbor: Vector2i, data: HexMapData, settings: HexTerrainSettings) -> Vector3:
	var position: Vector3 = HexLattice.to_world(point, settings.subdivisions)
	position.y = HexTerrainHeight.get_edge_height(data, settings, tile, neighbor, position)
	return position


# Quad corners in order: a+, a-, b+, b-. The shader measures sides from one shared direction,
# so a+ and b+ lie on the same side of the line.
static func _add_segment(a: Vector3, b: Vector3, positions: PackedVector3Array, others: PackedFloat32Array, indices: PackedInt32Array) -> void:
	var first: int = positions.size()
	_add_corner(a, b, 1.0, positions, others)
	_add_corner(a, b, -1.0, positions, others)
	_add_corner(b, a, 1.0, positions, others)
	_add_corner(b, a, -1.0, positions, others)
	indices.append(first)
	indices.append(first + 2)
	indices.append(first + 3)
	indices.append(first)
	indices.append(first + 3)
	indices.append(first + 1)


static func _add_corner(here: Vector3, there: Vector3, side: float, positions: PackedVector3Array, others: PackedFloat32Array) -> void:
	positions.append(here)
	others.append(there.x)
	others.append(there.y)
	others.append(there.z)
	others.append(side)
