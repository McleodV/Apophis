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

@export_group("Cliffs")
## Cliff shading from smooth (0) to flat per face (1). Higher = crisper facets.
@export_range(0.0, 1.0, 0.01) var cliff_faceting: float = 1.0
## How far tile color reaches down a cliff face from its rim, in world units.
@export_range(0.0, 0.5, 0.005) var rim_blend_down: float = 0.18
## How far cliff rock reaches onto the tile from a cliff's rim, in world units.
@export_range(0.0, 0.5, 0.005) var rim_blend_in: float = 0.08
## How far tile color reaches up a cliff face from its foot, in world units.
@export_range(0.0, 0.5, 0.005) var foot_blend_up: float = 0.1
## How far cliff rock reaches onto the tile from a cliff's foot, in world units.
@export_range(0.0, 0.5, 0.005) var foot_blend_out: float = 0.08
## How unevenly the rim and foot blends reach, in world units. 0 = straight along the cliff.
@export_range(0.0, 0.3, 0.005) var cliff_blend_noise: float = 0.08
## How often the rim and foot blends change reach along a cliff. Higher = more wiggles.
@export_range(0.5, 20.0, 0.1) var cliff_blend_frequency: float = 8.0
## Where tile color covers a cliff face, how far its shading turns from flat facets to smooth like the tile.
@export_range(0.0, 1.0, 0.01) var cliff_blend_smoothing: float = 1.0
## 0 = rim and foot blends fade smoothly, 1 = they break into patches of tile color and rock.
@export_range(0.0, 1.0, 0.01) var cliff_blend_patchiness: float = 0.0
## Size of those patches. Higher = smaller patches.
@export_range(1.0, 60.0, 0.5) var cliff_patch_frequency: float = 18.0

@export_group("Grid")
@export var grid_color := Color(0.05, 0.05, 0.05, 0.45)
@export_range(0.5, 8.0, 0.25) var grid_width_pixels: float = 1.5
## Height of grid lines above the terrain, in world units.
@export_range(0.0, 0.2, 0.005) var grid_lift: float = 0.02
