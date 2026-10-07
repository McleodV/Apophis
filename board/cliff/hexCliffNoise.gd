class_name HexCliffNoise
extends RefCounted
## Noise sources for cliff shaping, built from HexCliffSettings.

const _WAVE_SEED_OFFSET: int = 7919

var _relief := FastNoiseLite.new()
var _wave := FastNoiseLite.new()
var _vertical_scale: float = 1.0


func _init(settings: HexCliffSettings) -> void:
	_relief.seed = settings.noise_seed
	_relief.frequency = settings.relief_frequency
	_relief.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	_relief.fractal_octaves = settings.relief_octaves
	_vertical_scale = settings.relief_vertical_scale
	_wave.seed = settings.noise_seed + _WAVE_SEED_OFFSET
	_wave.frequency = settings.band_wave_frequency
	_wave.fractal_type = FastNoiseLite.FRACTAL_NONE


## Ridged noise in about [-1, 1]. Ridges are positive.
func get_relief(position: Vector3) -> float:
	return _relief.get_noise_3d(position.x, position.y * _vertical_scale, position.z)


## Smooth noise in about [-1, 1] for band height waves.
func get_wave(position: Vector3) -> float:
	return _wave.get_noise_3d(position.x, position.y, position.z)
