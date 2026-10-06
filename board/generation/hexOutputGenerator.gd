class_name HexOutputGenerator
extends Object
## Static base output generation.
## Splits the map into regions that each favor one resource type (warped Voronoi).
## Region types and point rolls are weighted by the map's biome.

const _CANDIDATES: int = 8 # Random tiles tried per region center; best one is kept
const _WARP_OFFSET: float = 1000.0 # Separates the x and z warp samples


## Overwrites base output on every tile. Set data.biome first.
static func generate(data: HexMapData, settings: HexOutputSettings, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var weights: PackedFloat32Array = _get_type_weights(data.biome)
	var biased: Array[PackedFloat32Array] = _get_biased_weights(weights, settings.region_bias)
	var tiles: Array[Vector2i] = data.get_all_tiles()
	var centers: PackedVector2Array = _place_centers(tiles, settings.tiles_per_region, rng)
	var region_types := PackedInt32Array()
	for i: int in centers.size():
		region_types.append(rng.rand_weighted(weights))
	var warp := FastNoiseLite.new()
	warp.seed = seed_value
	warp.frequency = settings.border_frequency
	for axial: Vector2i in tiles:
		var region: int = _get_region(axial, centers, warp, settings.border_warp)
		_roll_output(data, axial, biased[region_types[region]], rng)


# Biome weights, or HexBiome defaults without a biome or with no positive weight.
static func _get_type_weights(biome: HexBiome) -> PackedFloat32Array:
	if biome:
		var weights: PackedFloat32Array = biome.get_type_weights()
		var total: float = 0.0
		for weight: float in weights:
			total += maxf(weight, 0.0)
		if total > 0.0:
			return weights
		push_warning("Biome %s has no positive type weight. Using defaults." % biome.display_name)
	return HexBiome.new().get_type_weights()


# Point weights inside a region of each type. Index = region type.
static func _get_biased_weights(weights: PackedFloat32Array, bias: float) -> Array[PackedFloat32Array]:
	var result: Array[PackedFloat32Array] = []
	for type: int in HexResource.COUNT:
		var biased: PackedFloat32Array = weights.duplicate()
		biased[type] *= bias
		result.append(biased)
	return result


# Best-candidate sampling: each center is the candidate farthest from existing centers.
static func _place_centers(tiles: Array[Vector2i], tiles_per_region: int, rng: RandomNumberGenerator) -> PackedVector2Array:
	var count: int = maxi(1, roundi(float(tiles.size()) / tiles_per_region))
	var centers := PackedVector2Array()
	for i: int in count:
		var best := Vector2.ZERO
		var best_distance: float = -1.0
		for c: int in _CANDIDATES:
			var candidate: Vector2 = _to_flat(tiles[rng.randi_range(0, tiles.size() - 1)])
			var distance: float = _get_nearest(candidate, centers).y
			if distance > best_distance:
				best_distance = distance
				best = candidate
		centers.append(best)
	return centers


# Index of the center nearest the tile's warped position.
static func _get_region(axial: Vector2i, centers: PackedVector2Array, warp: FastNoiseLite, warp_distance: float) -> int:
	var point: Vector2 = _to_flat(axial)
	var offset := Vector2(warp.get_noise_2d(point.x, point.y), warp.get_noise_2d(point.x + _WARP_OFFSET, point.y))
	return int(_get_nearest(point + offset * warp_distance, centers).x)


# (index, squared distance) of the nearest center. (-1, INF) if there are none.
static func _get_nearest(point: Vector2, centers: PackedVector2Array) -> Vector2:
	var best_index: int = -1
	var best_distance: float = INF
	for i: int in centers.size():
		var distance: float = point.distance_squared_to(centers[i])
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return Vector2(best_index, best_distance)


# Rolls a total of 0 to MAX_TILE_TOTAL points, each type picked by weight.
static func _roll_output(data: HexMapData, axial: Vector2i, weights: PackedFloat32Array, rng: RandomNumberGenerator) -> void:
	var counts := PackedInt32Array()
	counts.resize(HexResource.COUNT)
	for i: int in rng.randi_range(0, HexResource.MAX_TILE_TOTAL):
		counts[rng.rand_weighted(weights)] += 1
	# Clear first so the per-tile cap doesn't clamp new values against old ones.
	for type: int in HexResource.COUNT:
		data.set_base_output(axial, type, 0)
	for type: int in HexResource.COUNT:
		data.set_base_output(axial, type, counts[type])


static func _to_flat(axial: Vector2i) -> Vector2:
	var world: Vector3 = HexMath.axial_to_world(axial)
	return Vector2(world.x, world.z)
