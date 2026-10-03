class_name HexTerrainSettings
extends Resource
## Tunable terrain shape and chunking values.
## Shared by HexTerrainHeight, HexChunkMeshBuilder, and HexBoard.

## World height of one elevation level.
@export_range(0.05, 2.0, 0.01) var elevation_step: float = 0.3
## Fraction of a tile's inner radius that blends into its neighbors.
@export_range(0.05, 0.95, 0.01) var blend_band: float = 0.4
## Lattice cells per hex spoke. Higher = smoother, steeper cliffs, more vertices.
@export_range(2, 16) var subdivisions: int = 6
## Tiles per chunk along each axial axis.
@export_range(2, 32) var chunk_size: int = 8
