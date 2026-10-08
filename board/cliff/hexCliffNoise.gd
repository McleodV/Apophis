class_name HexCliffNoise
extends RefCounted
## Noise and hash sources for cliff shaping, built from HexCliffSettings.

const _WAVE_SEED_OFFSET: int = 7919
## Below 1, pushes vary less with height than along the wall.
const _VERTICAL_SCALE: float = 0.5

var _relief := FastNoiseLite.new()
var _wave := FastNoiseLite.new()


func _init(settings: HexCliffSettings) -> void:
	_relief.seed = settings.noise_seed
	_relief.frequency = settings.relief_frequency
	_relief.fractal_type = FastNoiseLite.FRACTAL_FBM
	_relief.fractal_octaves = 2
	_wave.seed = settings.noise_seed + _WAVE_SEED_OFFSET
	_wave.frequency = settings.band_wave_frequency
	_wave.fractal_type = FastNoiseLite.FRACTAL_NONE


## Deterministic value in [0, 1) from four ints.
static func hash01(a: int, b: int, c: int, d: int) -> float:
	var x: int = ((a * 73856093) ^ (b * 19349663) ^ (c * 83492791) ^ (d * 2654435761)) & 0xFFFFFFFF
	x = (((x >> 16) ^ x) * 0x45d9f3b) & 0xFFFFFFFF
	x = (((x >> 16) ^ x) * 0x45d9f3b) & 0xFFFFFFFF
	x = (x >> 16) ^ x
	return float(x & 0xFFFFFF) / 16777216.0


## Smooth noise in about [-1, 1] for facet corner pushes.
func get_relief(position: Vector3) -> float:
	return _relief.get_noise_3d(position.x, position.y * _VERTICAL_SCALE, position.z)


## Smooth noise in about [-1, 1] for band height waves.
func get_wave(position: Vector3) -> float:
	return _wave.get_noise_3d(position.x, position.y, position.z)
