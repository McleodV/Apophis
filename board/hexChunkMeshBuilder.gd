class_name HexChunkMeshBuilder
extends RefCounted
## Builds one chunk's terrain mesh on the hex-aligned lattice.
## Usage: var mesh := HexChunkMeshBuilder.build(data, settings, tiles)
## Vertices are derived only from lattice points and map data, so chunk borders match exactly.

# Debug coloring until the terrain shader exists.
const _CLIFF_NORMAL_Y: float = 0.6 # Normals flatter than this are colored as cliff
const _CLIFF_COLOR := Color(0.42, 0.39, 0.36)
const _LOW_COLOR := Color(0.25, 0.42, 0.18)
const _HIGH_COLOR := Color(0.72, 0.68, 0.52)

var _data: HexMapData
var _settings: HexTerrainSettings
var _cached_positions: Dictionary = {} # Lattice point -> world position
var _vertex_ids: Dictionary = {} # Lattice point -> vertex index
var _positions := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
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
	var normal: Vector3 = _get_normal(point, vertex)
	var index: int = _positions.size()
	_positions.append(vertex)
	_normals.append(normal)
	_colors.append(_get_color(vertex.y, normal))
	_vertex_ids[point] = index
	return index


func _get_position(point: Vector2i) -> Vector3:
	if _cached_positions.has(point):
		return _cached_positions[point]
	var vertex: Vector3 = HexLattice.to_world(point, _settings.subdivisions)
	vertex.y = HexTerrainHeight.get_height(_data, _settings, vertex)
	_cached_positions[point] = vertex
	return vertex


# Averages the 6 surrounding lattice triangles. Uses neighbors outside the chunk too,
# so normals match across chunk borders.
func _get_normal(point: Vector2i, vertex: Vector3) -> Vector3:
	var normal := Vector3.ZERO
	var previous: Vector3 = _get_position(point + HexLattice.NEIGHBORS[5]) - vertex
	for neighbor: Vector2i in HexLattice.NEIGHBORS:
		var current: Vector3 = _get_position(point + neighbor) - vertex
		normal += current.cross(previous)
		previous = current
	return normal.normalized()


func _get_color(height: float, normal: Vector3) -> Color:
	if normal.y < _CLIFF_NORMAL_Y:
		return _CLIFF_COLOR
	var max_height: float = maxf(_data.get_max_elevation() * _settings.elevation_step, 0.001)
	return _LOW_COLOR.lerp(_HIGH_COLOR, clampf(height / max_height, 0.0, 1.0))


func _create_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if _positions.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _positions
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_INDEX] = _indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
