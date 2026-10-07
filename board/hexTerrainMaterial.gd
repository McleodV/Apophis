class_name HexTerrainMaterial
extends Object
## Static setup for the terrain ShaderMaterial.

const _SHADER: Shader = preload("res://board/shaders/hexTerrain.gdshader")


static func create() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _SHADER
	return material


## Shape values shared with HexMath, mesh building, and height sampling.
static func apply_settings(material: ShaderMaterial, settings: HexTerrainSettings) -> void:
	material.set_shader_parameter("outer_radius", HexMath.OUTER_RADIUS)
	material.set_shader_parameter("blend_band", settings.blend_band)


static func apply_style(material: ShaderMaterial, style: HexTerrainStyle) -> void:
	material.set_shader_parameter("output_strength", _to_value_array(style.output_strength))
	material.set_shader_parameter("border_blend", style.border_blend)
	material.set_shader_parameter("border_warp", style.border_warp)
	material.set_shader_parameter("border_warp_frequency", style.border_warp_frequency)
	material.set_shader_parameter("cliff_faceting", style.cliff_faceting)
	material.set_shader_parameter("grid_color", style.grid_color)
	material.set_shader_parameter("grid_width_pixels", style.grid_width_pixels)


## Tile texture, map size, and biome palette. A missing biome or palette uses palette defaults.
static func apply_map(material: ShaderMaterial, data: HexMapData, tile_texture: Texture2D) -> void:
	material.set_shader_parameter("tile_data", tile_texture)
	material.set_shader_parameter("map_radius", data.radius)
	var palette: HexBiomePalette = data.biome.palette if data.biome and data.biome.palette else HexBiomePalette.new()
	material.set_shader_parameter("base_color", palette.base_color)
	material.set_shader_parameter("cliff_color", palette.cliff_color)
	material.set_shader_parameter("food_color", palette.food_color)
	material.set_shader_parameter("trade_color", palette.trade_color)
	material.set_shader_parameter("industry_color", palette.industry_color)
	material.set_shader_parameter("phenomena_color", palette.phenomena_color)


static func set_grid_visible(material: ShaderMaterial, visible: bool) -> void:
	material.set_shader_parameter("grid_visible", visible)


# One entry per dominant value (1 to MAX_TILE_TOTAL). Missing entries become 0.
static func _to_value_array(source: PackedFloat32Array) -> PackedFloat32Array:
	if source.size() != HexResource.MAX_TILE_TOTAL:
		push_warning("HexTerrainStyle.output_strength needs %d entries." % HexResource.MAX_TILE_TOTAL)
	var result: PackedFloat32Array = source.duplicate()
	result.resize(HexResource.MAX_TILE_TOTAL)
	return result
