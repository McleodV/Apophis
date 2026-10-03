class_name HexMapDebugFill
extends Object
## Debug-only elevation fillers for evaluating terrain visuals.

## Fills all tiles from smooth noise, stretched to use the full elevation range.
static func fill_noise(data: HexMapData, seed_value: int, frequency: float) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = frequency
	var tiles: Array[Vector2i] = data.get_all_tiles()
	var samples := PackedFloat32Array()
	samples.resize(tiles.size())
	var low: float = INF
	var high: float = -INF
	for i: int in tiles.size():
		var center: Vector3 = HexMath.axial_to_world(tiles[i])
		samples[i] = noise.get_noise_2d(center.x, center.z)
		low = minf(low, samples[i])
		high = maxf(high, samples[i])
	var range_size: float = maxf(high - low, 0.0001)
	for i: int in tiles.size():
		var normalized: float = (samples[i] - low) / range_size
		data.set_elevation(tiles[i], roundi(normalized * data.get_max_elevation()))
