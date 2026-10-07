class_name HexTerrainStyle
extends Resource
## Biome-independent terrain visuals. Biome colors live in HexBiomePalette.

@export_group("Base Output")
## Tint toward the dominant resource color, per dominant value. Index 0 = value 1.
## 0 = base color, 1 = resource color.
@export var output_strength := PackedFloat32Array([0.35, 0.55, 0.75, 1.0])

@export_group("Type Borders")
## Crossfade width between tiles of different dominant types (no output counts as a type).
## Fraction of the distance between tile centers.
@export_range(0.01, 0.3, 0.01) var border_blend: float = 0.08
## How far noise bends borders between different types, in world units. 0 = straight borders.
@export_range(0.0, 0.25, 0.01) var border_warp: float = 0.15
## Noise frequency of the border bend. Higher = more wiggles per edge.
@export_range(0.1, 5.0, 0.05) var border_warp_frequency: float = 1.5

@export_group("Grid")
@export var grid_color := Color(0.05, 0.05, 0.05, 0.45)
@export_range(0.5, 8.0, 0.25) var grid_width_pixels: float = 1.5
