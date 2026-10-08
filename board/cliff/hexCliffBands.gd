class_name HexCliffBands
extends Object
## Static rules for which lattice edges are cliffs, where their band vertices sit, and which are facet corners.
## Results depend only on the edge, so both triangles sharing it agree.

## Height steps above this many elevation levels are cliffs.
## Slopes stay within 1 level per lattice edge; cliffs are about 1.4 levels or more.
const CLIFF_LEVELS: float = 1.25
## Bands closer than this fraction of band_height to an edge's ends are dropped.
const _MIN_END_GAP: float = 0.35
## Combined band shift limit, as a fraction of band_height. Keeps bands in order.
const _MAX_SHIFT: float = 0.45
## Random spread of gaps between facet corners, as a fraction of the average gap.
const _GAP_JITTER: float = 0.4


## Band heights strictly between low and high, ascending.
## anchor: undisplaced edge midpoint. Band waves are sampled there.
static func get_heights(low: float, high: float, anchor: Vector3, settings: HexCliffSettings, noise: HexCliffNoise) -> PackedFloat32Array:
	var heights := PackedFloat32Array()
	var band: float = settings.band_height
	var end_gap: float = _MIN_END_GAP * band
	for i: int in range(floori(low / band), ceili(high / band) + 1):
		var nominal: float = i * band
		var shift: float = (HexCliffNoise.hash01(i, settings.noise_seed, 0, 0) * 2.0 - 1.0) * settings.band_jitter
		shift += noise.get_wave(Vector3(anchor.x, nominal, anchor.z)) * settings.band_wave
		var height: float = nominal + clampf(shift, -_MAX_SHIFT, _MAX_SHIFT) * band
		if height > low + end_gap and height < high - end_gap:
			heights.append(height)
	return heights


## Which of an edge's count bands are facet corners with their own push: 1 per corner.
## Other bands lie on the straight line between the corners around them.
## Corners are spread at jittered gaps, so columns rarely get long runs without one.
## density: from get_density(); scales how often bands are corners.
static func get_creases(edge: Vector3i, count: int, density: float, settings: HexCliffSettings) -> PackedByteArray:
	var creases := PackedByteArray()
	creases.resize(count)
	var mean_gap: float = maxf(settings.facet_height / (settings.band_height * maxf(density, 0.05)), 1.0)
	# Start part way into the first gap, so corners don't line up across columns.
	var position: float = mean_gap * HexCliffNoise.hash01(edge.x, edge.y, edge.z, settings.noise_seed)
	var n: int = 0
	while roundi(position) < count:
		creases[maxi(roundi(position), 0)] = 1
		n += 1
		var spread: float = 2.0 * HexCliffNoise.hash01(edge.x, edge.y, edge.z * 1024 + n, settings.noise_seed) - 1.0
		position += maxf(mean_gap * (1.0 + _GAP_JITTER * spread), 1.0)
	return creases


## Facet corner density near anchor, an edge's undisplaced midpoint.
## Varies slowly along walls, so facet sizes change from place to place while neighboring
## columns keep similar corner counts and join without fans of thin triangles.
static func get_density(anchor: Vector3, settings: HexCliffSettings, noise: HexCliffNoise) -> float:
	return 1.0 + settings.facet_height_variance * noise.get_density(anchor)
