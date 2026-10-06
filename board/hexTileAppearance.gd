class_name HexTileAppearance
extends Object
## Static rules for how a tile's base output is shown.


## Dominant resource as (type, value). value = 0 when the tile has no output.
## Ties resolve by the biome's tie priority.
static func get_dominant(data: HexMapData, axial: Vector2i) -> Vector2i:
	var best_type: int = 0
	var best_value: int = 0
	var best_rank: int = 0
	for type: int in HexResource.COUNT:
		var value: int = data.get_base_output(axial, type)
		if value == 0:
			continue
		var rank: int = _get_rank(data.biome, type)
		if value > best_value or (value == best_value and rank < best_rank):
			best_type = type
			best_value = value
			best_rank = rank
	return Vector2i(best_type, best_value)


# Lower = higher priority. Unlisted types rank after listed ones, in enum order.
static func _get_rank(biome: HexBiome, type: int) -> int:
	if biome:
		var index: int = biome.tie_priority.find(type)
		if index >= 0:
			return index
	return HexResource.COUNT + type
