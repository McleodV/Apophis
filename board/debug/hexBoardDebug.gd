extends Node
## Debug: fills a HexBoard with noise elevations. Space = new seed.

@export var board: HexBoard
@export_range(1, 64) var map_radius: int = 12
@export_range(1, 256) var elevation_levels: int = 10
@export var noise_seed: int = 0
@export_range(0.005, 0.5, 0.005) var noise_frequency: float = 0.05


func _ready() -> void:
	_generate()


func _unhandled_input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event and key_event.pressed and not key_event.echo and key_event.keycode == KEY_SPACE:
		noise_seed += 1
		_generate()


func _generate() -> void:
	var data := HexMapData.new(map_radius, elevation_levels)
	HexMapDebugFill.fill_noise(data, noise_seed, noise_frequency)
	board.set_map_data(data)
	print("Seed: %d" % noise_seed)
