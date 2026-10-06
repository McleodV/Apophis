class_name HexBiome
extends Resource
## One biome per board, fixed for the whole run.
## Visuals live in palette. Generation weights are below.

@export var display_name: String = ""
## Breaks ties for a tile's dominant resource, highest priority first.
## Types not listed rank after listed ones, in HexResource.Type order.
@export var tie_priority: Array[HexResource.Type] = [
	HexResource.Type.FOOD,
	HexResource.Type.TRADE,
	HexResource.Type.INDUSTRY,
	HexResource.Type.PHENOMENA,
]
@export var palette: HexBiomePalette

@export_group("Generation")
## Relative chance of Food regions, and of Food points in other regions.
@export_range(0.0, 10.0, 0.05) var food_weight: float = 1.0
## Relative chance of Trade regions, and of Trade points in other regions.
@export_range(0.0, 10.0, 0.05) var trade_weight: float = 1.0
## Relative chance of Industry regions, and of Industry points in other regions.
@export_range(0.0, 10.0, 0.05) var industry_weight: float = 1.0
## Relative chance of Phenomena regions, and of Phenomena points in other regions.
## Keep lower than the others; Phenomena is rarer.
@export_range(0.0, 10.0, 0.05) var phenomena_weight: float = 0.35


## Weights indexed by HexResource.Type.
func get_type_weights() -> PackedFloat32Array:
	return PackedFloat32Array([food_weight, trade_weight, industry_weight, phenomena_weight])
