class_name HexChunk
extends MeshInstance3D
## Renders the terrain for one group of tiles. Rebuilt by HexBoard.

var tiles: Array[Vector2i] = []


func rebuild(data: HexMapData, settings: HexTerrainSettings) -> void:
	mesh = HexChunkMeshBuilder.build(data, settings, tiles)
