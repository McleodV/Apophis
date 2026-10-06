class_name HexTerrainStyle
extends Resource
## Biome-independent terrain visuals. Biome colors live in HexBiomePalette.

@export_group("Base Output")
## Tint toward the dominant resource color, per dominant value. Index 0 = value 1.
## 0 = base color, 1 = resource color.
@export var output_strength := PackedFloat32Array([0.35, 0.55, 0.75, 1.0])

@export_group("Grid")
@export var grid_color := Color(0.05, 0.05, 0.05, 0.45)
@export_range(0.5, 8.0, 0.25) var grid_width_pixels: float = 1.5
