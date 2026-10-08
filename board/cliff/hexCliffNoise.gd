class_name HexCliffNoise
extends RefCounted
## Noise and hash sources for cliff shaping, built from HexCliffSettings.
## Crests: a piecewise-linear profile along the wall (crest, gully, crest, ...), so faces between
## crest lines stay flat. Crest lines lean slightly with height.

const _WAVE_SEED_OFFSET: int = 7919
const _SLANT_SEED_OFFSET: int = 104729
## Noise frequency of the crest lean along the wall.
const _SLANT_FREQUENCY: float = 0.4
# Hash salts.
const _CREST_POSITION: int = 1
const _CREST_HEIGHT: int = 2
const _GULLY_POSITION: int = 3
const _GULLY_DEPTH: int = 4

var _wave := FastNoiseLite.new()
var _slant := FastNoiseLite.new()
var _crest_spacing: float = 1.0
var _crest_slant: float = 0.0
var _seed: int = 0


func _init(settings: HexCliffSettings) -> void:
	_seed = settings.noise_seed
	_crest_spacing = settings.crest_spacing
	_crest_slant = settings.crest_slant
	_wave.seed = settings.noise_seed + _WAVE_SEED_OFFSET
	_wave.frequency = settings.band_wave_frequency
	_wave.fractal_type = FastNoiseLite.FRACTAL_NONE
	_slant.seed = settings.noise_seed + _SLANT_SEED_OFFSET
	_slant.frequency = _SLANT_FREQUENCY
	_slant.fractal_type = FastNoiseLite.FRACTAL_NONE


## Deterministic value in [0, 1) from four ints.
static func hash01(a: int, b: int, c: int, d: int) -> float:
	var x: int = ((a * 73856093) ^ (b * 19349663) ^ (c * 83492791) ^ (d * 2654435761)) & 0xFFFFFFFF
	x = (((x >> 16) ^ x) * 0x45d9f3b) & 0xFFFFFFFF
	x = (((x >> 16) ^ x) * 0x45d9f3b) & 0xFFFFFFFF
	x = (x >> 16) ^ x
	return float(x & 0xFFFFFF) / 16777216.0


## Crest profile in [-1, 1] at a point on a wall facing direction. Crests are positive, gullies negative.
func get_crests(position: Vector3, direction: Vector2) -> float:
	# Distance along the wall, sheared so crest lines lean with height.
	var along: float = Vector2(position.x, position.z).dot(Vector2(-direction.y, direction.x))
	along += _slant.get_noise_1d(along) * _crest_slant * position.y
	var cell: int = floori(along / _crest_spacing)
	var first: int = cell - 1
	var start: float = _get_crest_position(cell - 1)
	var end: float = _get_crest_position(cell)
	if along >= end:
		first = cell
		start = end
		end = _get_crest_position(cell + 1)
	# One gully between each pair of crests.
	var gully: float = lerpf(start, end, 0.3 + 0.4 * _hash(first, _GULLY_POSITION))
	var depth: float = -0.4 - 0.6 * _hash(first, _GULLY_DEPTH)
	if along < gully:
		return lerpf(_get_crest_height(first), depth, (along - start) / (gully - start))
	return lerpf(depth, _get_crest_height(first + 1), (along - gully) / (end - gully))


## Smooth noise in about [-1, 1] for band height waves.
func get_wave(position: Vector3) -> float:
	return _wave.get_noise_3d(position.x, position.y, position.z)


# One crest per cell, somewhere in its middle 60%.
func _get_crest_position(cell: int) -> float:
	return (cell + 0.2 + 0.6 * _hash(cell, _CREST_POSITION)) * _crest_spacing


func _get_crest_height(cell: int) -> float:
	return 0.4 + 0.6 * _hash(cell, _CREST_HEIGHT)


func _hash(cell: int, salt: int) -> float:
	return hash01(cell, salt, _seed, 0)
