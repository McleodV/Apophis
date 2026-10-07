class_name HexCliffSettings
extends Resource
## Tunable cliff face shape. Used by HexTerrainSurface.
## Distances are world units. Push is horizontal: positive = out toward the low side.

@export_group("Bands")
## Average vertical gap between rows of vertices on cliff faces.
@export_range(0.02, 1.0, 0.005) var band_height: float = 0.1
## Random height shift per band, as a fraction of band_height.
@export_range(0.0, 0.45, 0.01) var band_jitter: float = 0.25
## Height shift that varies along the wall, as a fraction of band_height.
@export_range(0.0, 0.45, 0.01) var band_wave: float = 0.3
## Noise frequency of the band wave. Higher = more undulation per wall.
@export_range(0.05, 10.0, 0.05) var band_wave_frequency: float = 1.5

@export_group("Profile")
## How far the rim recedes into the high side.
@export_range(0.0, 0.3, 0.005) var lip_depth: float = 0.05
## Height below the rim over which the lip curves back into the face.
@export_range(0.01, 1.0, 0.01) var lip_height: float = 0.2
## How far the base flares out over the low side.
@export_range(0.0, 0.3, 0.005) var foot_depth: float = 0.05
## Height above the base over which the foot flares out.
@export_range(0.01, 1.0, 0.01) var foot_height: float = 0.2

@export_group("Relief")
## Max push from ridged noise. Ridges push out, gullies push in.
@export_range(0.0, 0.5, 0.005) var relief_amplitude: float = 0.15
## Higher = narrower ridges.
@export_range(0.1, 20.0, 0.1) var relief_frequency: float = 3.0
## Vertical noise scale. Below 1 stretches ridges vertically.
@export_range(0.05, 1.0, 0.01) var relief_vertical_scale: float = 0.25
@export_range(1, 6) var relief_octaves: int = 3
@export var noise_seed: int = 0

@export_group("Rim and Base")
## Fraction of relief_amplitude applied at the rim and base.
@export_range(0.0, 1.0, 0.01) var edge_relief_scale: float = 0.5
## Max push of rim and base vertices. Keeps tile borders readable.
@export_range(0.0, 0.3, 0.005) var edge_max_push: float = 0.08
