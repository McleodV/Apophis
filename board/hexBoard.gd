class_name HexBoard
extends Node3D
## Renders a HexMapData as chunked terrain with grid lines.
## Rebuilds only chunks affected by elevation changes, once per frame.

## Leave empty to use defaults.
@export var settings: HexTerrainSettings
## Leave empty to use defaults.
@export var style: HexTerrainStyle
@export var grid_visible: bool = true:
	set(value):
		grid_visible = value
		for chunk: HexChunk in _chunks.values():
			chunk.grid.visible = value

var map_data: HexMapData

var _material: ShaderMaterial
var _grid_material: ShaderMaterial
var _tile_texture: HexTileTexture
var _chunks: Dictionary = {} # Chunk key -> HexChunk
var _dirty_chunks: Dictionary = {} # Chunk key -> true
var _rebuild_queued: bool = false


func set_map_data(data: HexMapData) -> void:
	if map_data and map_data.elevation_changed.is_connected(_on_elevation_changed):
		map_data.elevation_changed.disconnect(_on_elevation_changed)
	map_data = data
	map_data.elevation_changed.connect(_on_elevation_changed)
	_tile_texture = HexTileTexture.new(map_data)
	rebuild_all()


## Terrain height at a world position. 0 if no map is set.
func get_height(world_position: Vector3) -> float:
	if map_data == null:
		return 0.0
	return HexTerrainHeight.get_height(map_data, settings, world_position)


## Highest possible terrain height. 0 if no map is set.
func get_max_height() -> float:
	if map_data == null:
		return 0.0
	return map_data.get_max_elevation() * settings.elevation_step


## Distance from the board center to the farthest tile center. 0 if no map is set.
func get_world_radius() -> float:
	if map_data == null:
		return 0.0
	return map_data.radius * HexMath.SQRT3 * HexMath.OUTER_RADIUS


## Recreates every chunk and reapplies the material. Use after changing settings or style.
func rebuild_all() -> void:
	_ensure_defaults()
	_apply_material()
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
	if style == null:
		style = HexTerrainStyle.new()
	if _material == null:
		_material = HexTerrainMaterial.create()
	if _grid_material == null:
		_grid_material = HexGridMaterial.create()


func _apply_material() -> void:
	HexTerrainMaterial.apply_settings(_material, settings)
	HexTerrainMaterial.apply_style(_material, style)
	HexGridMaterial.apply_style(_grid_material, style)
	if map_data:
		HexTerrainMaterial.apply_map(_material, map_data, _tile_texture.texture)


func _get_or_create_chunk(key: Vector2i) -> HexChunk:
	if _chunks.has(key):
		return _chunks[key]
	var chunk := HexChunk.new()
	chunk.name = "Chunk_%d_%d" % [key.x, key.y]
	chunk.material_override = _material
	chunk.grid.material_override = _grid_material
	chunk.grid.visible = grid_visible
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
	_tile_texture.write_tile(axial)
	# Heights reach 1 tile out; normals reach 1 more.
	for nearby: Vector2i in HexMath.get_in_range(axial, 2):
		if map_data.has_tile(nearby):
			_dirty_chunks[_get_chunk_key(nearby)] = true
	if not _rebuild_queued:
		_rebuild_queued = true
		_rebuild_dirty_chunks.call_deferred()


func _rebuild_dirty_chunks() -> void:
	_tile_texture.flush()
	for key: Vector2i in _dirty_chunks:
		_chunks[key].rebuild(map_data, settings)
	_dirty_chunks.clear()
	_rebuild_queued = false
