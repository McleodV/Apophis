class_name HexGridMaterial
extends Object
## Static setup for the grid line ShaderMaterial.

const _SHADER: Shader = preload("res://board/shaders/hexGrid.gdshader")


static func create() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = _SHADER
	return material


static func apply_style(material: ShaderMaterial, style: HexTerrainStyle) -> void:
	material.set_shader_parameter("grid_color", style.grid_color)
	material.set_shader_parameter("width_pixels", style.grid_width_pixels)
	material.set_shader_parameter("lift", style.grid_lift)
