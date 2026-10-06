class_name HexBiomePalette
extends Resource
## Terrain colors for one biome.

## Tile face color with no output.
@export var base_color := Color(0.55, 0.56, 0.42)
## Keep low in saturation.
@export var cliff_color := Color(0.42, 0.4, 0.37)

@export_group("Resources")
## Keep green in every biome.
@export var food_color := Color(0.24, 0.55, 0.2)
@export var trade_color := Color(0.85, 0.68, 0.17)
@export var industry_color := Color(0.62, 0.27, 0.19)
## Keep more vibrant than the other resources.
@export var phenomena_color := Color(0.76, 0.15, 0.95)
