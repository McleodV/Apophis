class_name HexChunkMeshBuilder
extends RefCounted
## Builds one chunk's terrain mesh on the hex-aligned lattice.
## Usage: var mesh := HexChunkMeshBuilder.build(data, settings, tiles)
## Vertices are derived only from lattice points and map data, so chunk borders match exactly.
## Coloring is done by the terrain shader.

## Faces with normal.y below this are cliffs. Shared with the terrain shader.
const CLIFF_NORMAL_Y: float = 0.6

var _data: HexMapData
var _settings: HexTerrainSettings
var _cached_positions: Dictionary = {} # Lattice point -> world position
var _vertex_ids: Dictionary = {} # Lattice point -> vertex index
var _positions := PackedVector3Array()
var _normals := PackedVector3Array()
var _indices := PackedInt32Array()


static func build(data: HexMapData, settings: HexTerrainSettings, tiles: Array[Vector2i]) -> ArrayMesh:
	var builder := HexChunkMeshBuilder.new(data, settings)
	return builder._build(tiles)


func _init(data: HexMapData, settings: HexTerrainSettings) -> void:
	_data = data
	_settings = settings


func _build(tiles: Array[Vector2i]) -> ArrayMesh:
	var subdivisions: int = _settings.subdivisions
	for axial: Vector2i in tiles:
		var center: Vector2i = HexLattice.hex_center(axial, subdivisions)
		for corner: int in 6:
			# Sector between the previous corner and this one, split into lattice triangles.
			var u: Vector2i = HexLattice.CORNERS[posmod(corner - 1, 6)]
			var w: Vector2i = HexLattice.CORNERS[corner]
			for a: int in subdivisions:
				for b: int in subdivisions - a:
					var p: Vector2i = center + u * a + w * b
					_add_triangle(p, p + w, p + u)
					if a + b < subdivisions - 1:
						_add_triangle(p + u, p + w, p + u + w)
	return _create_mesh()


func _add_triangle(a: Vector2i, b: Vector2i, c: Vector2i) -> void:
	_indices.append(_get_vertex(a))
	_indices.append(_get_vertex(b))
	_indices.append(_get_vertex(c))


func _get_vertex(point: Vector2i) -> int:
	if _vertex_ids.has(point):
		return _vertex_ids[point]
	var vertex: Vector3 = _get_position(point)
	var index: int = _positions.size()
	_positions.append(vertex)
	_add_normal(point, vertex)
	_vertex_ids[point] = index
	return index


# Appends the normal for a vertex.
# Cliff and ground faces are averaged separately, then blended at a fixed ratio,
# so cliff edges shade the same regardless of how many faces of each kind touch the point.
# Uses neighbors outside the chunk too, so results match across chunk borders.
func _add_normal(point: Vector2i, vertex: Vector3) -> void:
	var ground_sum := Vector3.ZERO
	var cliff_sum := Vector3.ZERO
	var previous: Vector3 = _get_position(point + HexLattice.NEIGHBORS[5]) - vertex
	for neighbor: Vector2i in HexLattice.NEIGHBORS:
		var current: Vector3 = _get_position(point + neighbor) - vertex
		var face: Vector3 = current.cross(previous)
		if face.normalized().y < CLIFF_NORMAL_Y:
			cliff_sum += face
		else:
			ground_sum += face
		previous = current
	if cliff_sum == Vector3.ZERO:
		_normals.append(ground_sum.normalized())
		return
	var normal: Vector3 = cliff_sum.normalized()
	if ground_sum != Vector3.ZERO:
		normal = normal.slerp(ground_sum.normalized(), _settings.cliff_edge_softness)
	_normals.append(normal)


func _get_position(point: Vector2i) -> Vector3:
	if _cached_positions.has(point):
		return _cached_positions[point]
	var vertex: Vector3 = HexLattice.to_world(point, _settings.subdivisions)
	vertex.y = HexTerrainHeight.get_height(_data, _settings, vertex)
	_cached_positions[point] = vertex
	return vertex


func _create_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if _positions.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _positions
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_INDEX] = _indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
