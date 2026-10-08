class_name HexChunkMeshBuilder
extends RefCounted
## Builds one chunk's terrain mesh on the hex-aligned lattice.
## Usage: var mesh := HexChunkMeshBuilder.build(data, settings, tiles)
## Geometry comes from HexTerrainSurface, so chunk borders match exactly.
## Vertex color red = 1 on cliff faces. UV = undisplaced xz. Coloring is done by the terrain shader.

var _settings: HexTerrainSettings
var _surface: HexTerrainSurface
var _ground_ids: Dictionary = {} # Vertex key -> mesh index
var _cliff_ids: Dictionary = {} # Vertex key -> mesh index. Separate so cliff color stops at the face edge.
var _normal_cache: Dictionary = {} # Vertex key -> normal
var _positions := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _uvs := PackedVector2Array()
var _indices := PackedInt32Array()


static func build(data: HexMapData, settings: HexTerrainSettings, tiles: Array[Vector2i]) -> ArrayMesh:
	var builder := HexChunkMeshBuilder.new(data, settings)
	return builder._build(tiles)


func _init(data: HexMapData, settings: HexTerrainSettings) -> void:
	_settings = settings
	_surface = HexTerrainSurface.new(data, settings)


func _build(tiles: Array[Vector2i]) -> ArrayMesh:
	var subdivisions: int = _settings.subdivisions
	for axial: Vector2i in tiles:
		var center: Vector2i = HexLattice.hex_center(axial, subdivisions)
		for corner: int in 6:
			# Sector between the previous corner and this one, split into lattice triangles.
			var u: Vector2i = HexLattice.CORNERS[posmod(corner - 1, 6)]
			var w: Vector2i = HexLattice.CORNERS[corner]
			# A cliff along this side replaces the outermost row of lattice triangles.
			var strip: HexCliffStrip = _surface.get_strip(axial, corner)
			if strip:
				_add_faces(strip.get_triangle(_surface))
			for a: int in subdivisions:
				for b: int in subdivisions - a:
					var p: Vector2i = center + u * a + w * b
					if strip == null or a + b != subdivisions - 1:
						_add_triangle(p, p + w, p + u)
					if a + b < subdivisions - 1 and (strip == null or a + b != subdivisions - 2):
						_add_triangle(p + u, p + w, p + u + w)
	return _create_mesh()


func _add_triangle(a: Vector2i, b: Vector2i, c: Vector2i) -> void:
	var flags: int = _surface.get_flags(a, b, c)
	if not flags & HexTerrainSurface.FLAG_SPLIT:
		var is_steep: bool = flags & HexTerrainSurface.FLAG_STEEP != 0
		_indices.append(_get_vertex(HexTerrainSurface.get_lattice_key(a), is_steep))
		_indices.append(_get_vertex(HexTerrainSurface.get_lattice_key(b), is_steep))
		_indices.append(_get_vertex(HexTerrainSurface.get_lattice_key(c), is_steep))
		return
	_add_faces(_surface.get_triangle(a, b, c))


func _add_faces(triangle: HexTerrainSurface.Triangle) -> void:
	for key: Vector4i in triangle.keys:
		_indices.append(_get_vertex(key, triangle.is_cliff))


func _get_vertex(key: Vector4i, is_cliff: bool) -> int:
	var ids: Dictionary = _cliff_ids if is_cliff else _ground_ids
	var index: int = ids.get(key, -1)
	if index >= 0:
		return index
	var rest: Vector3 = _surface.get_rest_position(key)
	index = _positions.size()
	_positions.append(_surface.get_position(key))
	_normals.append(_get_normal(key))
	_colors.append(Color.RED if is_cliff else Color.BLACK)
	_uvs.append(Vector2(rest.x, rest.z))
	ids[key] = index
	return index


func _get_normal(key: Vector4i) -> Vector3:
	var normal: Variant = _normal_cache.get(key)
	if normal == null:
		normal = HexTerrainNormals.get_normal(_surface, key, _settings.cliff_edge_softness)
		_normal_cache[key] = normal
	return normal


func _create_mesh() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if _positions.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _positions
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_TEX_UV] = _uvs
	arrays[Mesh.ARRAY_INDEX] = _indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
