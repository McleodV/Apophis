class_name HexCliffBands
extends Object
## Static rules for which lattice edges are cliffs and where their band vertices sit.
## Results depend only on the edge, so both triangles sharing it agree.

## Height steps above this many elevation levels are cliffs.
## Slopes stay within 1 level per lattice edge; cliffs are about 1.4 levels or more.
const CLIFF_LEVELS: float = 1.25
## Bands closer than this fraction of band_height to an edge's ends are dropped.
const _MIN_END_GAP: float = 0.35
## Combined band shift limit, as a fraction of band_height. Keeps bands in order.
const _MAX_SHIFT: float = 0.45


## Band heights strictly between low and high, ascending.
## anchor: undisplaced edge midpoint. Band waves are sampled there.
static func get_heights(low: float, high: float, anchor: Vector3, settings: HexCliffSettings, noise: HexCliffNoise) -> PackedFloat32Array:
	var heights := PackedFloat32Array()
	var band: float = settings.band_height
	var end_gap: float = _MIN_END_GAP * band
	for i: int in range(floori(low / band), ceili(high / band) + 1):
		var nominal: float = i * band
		var shift: float = _get_jitter(i, settings.noise_seed) * settings.band_jitter
		shift += noise.get_wave(Vector3(anchor.x, nominal, anchor.z)) * settings.band_wave
		var height: float = nominal + clampf(shift, -_MAX_SHIFT, _MAX_SHIFT) * band
		if height > low + end_gap and height < high - end_gap:
			heights.append(height)
	return heights


# Deterministic value in [-1, 1] per band index.
static func _get_jitter(index: int, seed_value: int) -> float:
	var x: int = (index * 374761393 + seed_value * 668265263) & 0xFFFFFFFF
	x = ((x ^ (x >> 13)) * 1274126177) & 0xFFFFFFFF
	x ^= x >> 16
	return float(x & 0xFFFF) / 32767.5 - 1.0
