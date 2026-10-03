class_name HexBoard
extends Node3D
## Renders a HexMapData as chunked terrain.
## Rebuilds only chunks affected by elevation changes, once per frame.

## Leave empty to use defaults.
@export var settings: HexTerrainSettings
## Leave empty to use a vertex-colored debug material.
@export var material: Material

var map_data: HexMapData

var _chunks: Dictionary = {} # Chunk key -> HexChunk
var _dirty_chunks: Dictionary = {} # Chunk key -> true
var _rebuild_queued: bool = false


func set_map_data(data: HexMapData) -> void:
	if map_data and map_data.elevation_changed.is_connected(_on_elevation_changed):
		map_data.elevation_changed.disconnect(_on_elevation_changed)
	map_data = data
	map_data.elevation_changed.connect(_on_elevation_changed)
	rebuild_all()


## Recreates every chunk. Use after changing settings.
func rebuild_all() -> void:
	_ensure_defaults()
	for chunk: HexChunk in _chunks.values():
		chunk.queue_free()
	_chunks.clear()
	_dirty_chunks.clear()
	if map_data == null:
		return
	for axial: Vector2i in map_data.get_all_tiles():
		_get_or_create_chunk(_get_chunk_key(axial)).tiles.append(axial)
	for chunk: HexChunk in _chunks.values():
		chunk.rebuild(map_data, settings)


func _ensure_defaults() -> void:
	if settings == null:
		settings = HexTerrainSettings.new()
	if material == null:
		var debug_material := StandardMaterial3D.new()
		debug_material.vertex_color_use_as_albedo = true
		debug_material.vertex_color_is_srgb = true
		debug_material.roughness = 1.0
		material = debug_material

func _get_or_create_chunk(key: Vector2i) -> HexChunk:
	if _chunks.has(key):
		return _chunks[key]
	var chunk := HexChunk.new()
	chunk.name = "Chunk_%d_%d" % [key.x, key.y]
	chunk.material_override = material
	add_child(chunk)
	_chunks[key] = chunk
	return chunk


func _get_chunk_key(axial: Vector2i) -> Vector2i:
	# Offset by radius so keys start at 0.
	@warning_ignore("integer_division")
	return Vector2i(
		(axial.x + map_data.radius) / settings.chunk_size,
		(axial.y + map_data.radius) / settings.chunk_size,
	)


func _on_elevation_changed(axial: Vector2i) -> void:
	# Heights reach 1 tile out; normals reach 1 more.
	for nearby: Vector2i in HexMath.get_in_range(axial, 2):
		if map_data.has_tile(nearby):
			_dirty_chunks[_get_chunk_key(nearby)] = true
	if not _rebuild_queued:
		_rebuild_queued = true
		_rebuild_dirty_chunks.call_deferred()


func _rebuild_dirty_chunks() -> void:
	for key: Vector2i in _dirty_chunks:
		_chunks[key].rebuild(map_data, settings)
	_dirty_chunks.clear()
	_rebuild_queued = false
