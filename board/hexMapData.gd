class_name HexMapData
extends Resource
## Tile data for a hexagon-shaped map centered on axial (0, 0).
## Data only: no rendering, no generation logic.

signal elevation_changed(axial: Vector2i)

## Tiles from center to edge. Read-only; use setup() to change.
var radius: int = 0
## Number of discrete elevations. Valid elevations are 0 to elevation_levels - 1.
var elevation_levels: int = 10
## Set once during generation. Fixed for the whole run.
var biome: HexBiome

var _size: int = 0 # Side length of the backing square grid
var _elevations: PackedByteArray = PackedByteArray()
var _base_output: PackedByteArray = PackedByteArray() # HexResource.COUNT bytes per grid slot


func _init(map_radius: int = 0, levels: int = 10) -> void:
	setup(map_radius, levels)


## Allocates storage. Clears all existing tile data.
func setup(map_radius: int, levels: int) -> void:
	radius = maxi(map_radius, 0)
	elevation_levels = clampi(levels, 1, 256)
	_size = radius * 2 + 1
	_elevations = PackedByteArray()
	_elevations.resize(_size * _size)
	_base_output = PackedByteArray()
	_base_output.resize(_size * _size * HexResource.COUNT)


func has_tile(axial: Vector2i) -> bool:
	return HexMath.distance(axial, Vector2i.ZERO) <= radius


func get_tile_count() -> int:
	return 3 * radius * (radius + 1) + 1


func get_all_tiles() -> Array[Vector2i]:
	return HexMath.get_in_range(Vector2i.ZERO, radius)


func get_max_elevation() -> int:
	return elevation_levels - 1


## Returns 0 for tiles outside the map.
func get_elevation(axial: Vector2i) -> int:
	if not has_tile(axial):
		return 0
	return _elevations[_to_index(axial)]


## Clamps to the valid range. Emits elevation_changed only if the value changed.
func set_elevation(axial: Vector2i, value: int) -> void:
	if not has_tile(axial):
		return
	var clamped: int = clampi(value, 0, get_max_elevation())
	var index: int = _to_index(axial)
	if _elevations[index] == clamped:
		return
	_elevations[index] = clamped
	elevation_changed.emit(axial)


## Starting output of one HexResource.Type. Returns 0 for tiles outside the map.
func get_base_output(axial: Vector2i, type: int) -> int:
	if not has_tile(axial):
		return 0
	return _base_output[_to_index(axial) * HexResource.COUNT + type]


## Combined starting output of all types. Returns 0 for tiles outside the map.
func get_base_output_total(axial: Vector2i) -> int:
	if not has_tile(axial):
		return 0
	var start: int = _to_index(axial) * HexResource.COUNT
	var total: int = 0
	for i: int in HexResource.COUNT:
		total += _base_output[start + i]
	return total


## Generation only. Tile colors read base output when HexBoard.set_map_data() is called.
## Clamps so the tile total stays within HexResource.MAX_TILE_TOTAL.
func set_base_output(axial: Vector2i, type: int, value: int) -> void:
	if not has_tile(axial):
		return
	var index: int = _to_index(axial) * HexResource.COUNT + type
	var others: int = get_base_output_total(axial) - _base_output[index]
	_base_output[index] = clampi(value, 0, HexResource.MAX_TILE_TOTAL - others)


# Maps axial coordinates into the backing square grid.
# Corners of the square are unused (~25% of slots); kept for simple indexing.
func _to_index(axial: Vector2i) -> int:
	return (axial.y + radius) * _size + (axial.x + radius)
