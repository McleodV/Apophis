class_name HexTileTexture
extends RefCounted
## Per-tile data texture read by the terrain shader.
## Pixel (q + radius, r + radius). R = dominant type, G = dominant value (0 = none), B = elevation.

const _CHANNELS: int = 4

var texture: ImageTexture

var _data: HexMapData
var _size: int = 0
var _bytes := PackedByteArray()
var _image: Image
var _dirty: bool = false


func _init(data: HexMapData) -> void:
	_data = data
	_size = data.radius * 2 + 1
	_bytes.resize(_size * _size * _CHANNELS)
	for axial: Vector2i in data.get_all_tiles():
		_write(axial)
	_image = Image.create_from_data(_size, _size, false, Image.FORMAT_RGBA8, _bytes)
	texture = ImageTexture.create_from_image(_image)


## Rewrites one tile. Call flush() to upload.
func write_tile(axial: Vector2i) -> void:
	if not _data.has_tile(axial):
		return
	_write(axial)
	_dirty = true


## Uploads pending writes to the GPU.
func flush() -> void:
	if not _dirty:
		return
	_image.set_data(_size, _size, false, Image.FORMAT_RGBA8, _bytes)
	texture.update(_image)
	_dirty = false


func _write(axial: Vector2i) -> void:
	var dominant: Vector2i = HexTileAppearance.get_dominant(_data, axial)
	var index: int = ((axial.y + _data.radius) * _size + (axial.x + _data.radius)) * _CHANNELS
	_bytes[index] = dominant.x
	_bytes[index + 1] = dominant.y
	_bytes[index + 2] = _data.get_elevation(axial)
	_bytes[index + 3] = 255
