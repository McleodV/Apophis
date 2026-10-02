class_name HexMapData
extends Resource
## Tile data for a hexagon-shaped map centered on axial (0, 0).
## Data only: no rendering, no generation logic.

signal elevation_changed(axial: Vector2i)

## Tiles from center to edge. Read-only; use setup() to change.
var radius: int = 0
## Number of discrete elevations. Valid elevations are 0 to elevation_levels - 1.
var elevation_levels: int = 10

var _size: int = 0 # Side length of the backing square grid
var _elevations: PackedByteArray = PackedByteArray()


func _init(map_radius: int = 0, levels: int = 10) -> void:
	setup(map_radius, levels)


## Allocates storage. Clears all existing tile data.
func setup(map_radius: int, levels: int) -> void:
	radius = maxi(map_radius, 0)
	elevation_levels = clampi(levels, 1, 256)
	_size = radius * 2 + 1
	_elevations = PackedByteArray()
	_elevations.resize(_size * _size)


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


# Maps axial coordinates into the backing square grid.
# Corners of the square are unused (~25% of slots); kept for simple indexing.
func _to_index(axial: Vector2i) -> int:
	return (axial.y + radius) * _size + (axial.x + radius)
