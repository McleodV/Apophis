class_name HexOutputSettings
extends Resource
## Tunable values for HexOutputGenerator.

## Average tiles per region. Higher = fewer, larger regions.
@export_range(3, 200, 1) var tiles_per_region: int = 20
## How much more likely a region's type is when rolling points inside it.
@export_range(1.0, 20.0, 0.5) var region_bias: float = 6.0
## Max distance noise pushes region borders, in world units. 0 = straight borders.
@export_range(0.0, 5.0, 0.05) var border_warp: float = 1.5
## Noise frequency of the border warp. Higher = more jagged borders.
@export_range(0.01, 1.0, 0.01) var border_frequency: float = 0.15
