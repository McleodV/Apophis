extends Node
## Debug: fills a HexBoard with noise elevations and generated base output.
## Space = new seed. B = next biome, same seed.

@export var board: HexBoard
## Biomes to cycle through. Leave empty for palette and weight defaults.
@export var biome_set: HexBiomeSet
@export var biome_index: int = 0
## Leave empty to use defaults.
@export var output_settings: HexOutputSettings
@export_range(1, 64) var map_radius: int = 12
@export_range(1, 256) var elevation_levels: int = 10
@export var noise_seed: int = 0
@export_range(0.005, 0.5, 0.005) var noise_frequency: float = 0.05


func _ready() -> void:
	if output_settings == null:
		output_settings = HexOutputSettings.new()
	_generate()


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.keycode == KEY_SPACE:
		noise_seed += 1
		_generate()
	elif key_event.keycode == KEY_B:
		biome_index += 1
		_generate()


func _generate() -> void:
	var data := HexMapData.new(map_radius, elevation_levels)
	data.biome = _get_biome()
	HexMapDebugFill.fill_noise(data, noise_seed, noise_frequency)
	HexOutputGenerator.generate(data, output_settings, noise_seed)
	board.set_map_data(data)
	print("Seed: %d  Biome: %s" % [noise_seed, data.biome.display_name if data.biome else "none"])


func _get_biome() -> HexBiome:
	if biome_set == null or biome_set.biomes.is_empty():
		return null
	return biome_set.biomes[posmod(biome_index, biome_set.biomes.size())]
