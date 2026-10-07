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
## How far the rim recedes into the high side. The face slopes back to it from the highest band.
@export_range(0.0, 0.3, 0.005) var lip_depth: float = 0.05
## How far the base flares out over the low side.
@export_range(0.0, 0.3, 0.005) var foot_depth: float = 0.05

@export_group("Crests")
## How far crests stick out and gullies sink in.
@export_range(0.0, 0.5, 0.005) var relief_amplitude: float = 0.15
## Average distance between crests along the wall. Faces between crests are flat.
@export_range(0.1, 3.0, 0.01) var crest_spacing: float = 0.35
## How far crest lines lean sideways per unit of height. 0 = vertical crests.
@export_range(0.0, 2.0, 0.01) var crest_slant: float = 0.3
## Average vertical gap between creases on one column of the face.
## At band_height or less, every band follows the crests exactly.
## Higher = fewer, longer facets that follow the crests only roughly.
@export_range(0.02, 3.0, 0.01) var crease_spacing: float = 0.1
@export var noise_seed: int = 0

@export_group("Rim and Base")
## Fraction of relief_amplitude applied at the rim and base.
@export_range(0.0, 1.0, 0.01) var edge_relief_scale: float = 0.5
## Max push of rim and base vertices. Keeps tile borders readable.
@export_range(0.0, 0.3, 0.005) var edge_max_push: float = 0.08
