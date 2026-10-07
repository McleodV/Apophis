class_name HexChunk
extends MeshInstance3D
## Renders the terrain and grid lines for one group of tiles. Rebuilt by HexBoard.

var tiles: Array[Vector2i] = []
## Grid lines for the same tiles. Material and visibility are set by HexBoard.
var grid := MeshInstance3D.new()


func _init() -> void:
	grid.name = "Grid"
	grid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(grid)


func rebuild(data: HexMapData, settings: HexTerrainSettings) -> void:
	mesh = HexChunkMeshBuilder.build(data, settings, tiles)
	grid.mesh = HexGridMeshBuilder.build(data, settings, tiles)
