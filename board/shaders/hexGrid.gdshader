shader_type spatial;
// Straight grid lines, raised above the terrain and drawn at a fixed pixel width.
// Parameters are set by HexGridMaterial. Mesh layout from HexGridMeshBuilder:
// each quad corner has VERTEX = its end of the segment, CUSTOM0.xyz = the other end, CUSTOM0.w = side (-1 or 1).
// Both ends measure sides from the same direction, so a side means the same thing at both.
render_mode unshaded, cull_disabled, shadows_disabled, depth_draw_never;

uniform vec4 grid_color : source_color = vec4(0.05, 0.05, 0.05, 0.45);
uniform float width_pixels = 1.5;
// World units above the terrain.
uniform float lift = 0.02;
// Pulls lines toward the camera by this fraction of their distance so they win depth ties with the terrain.
// The pull is along the view ray, so lines don't shift on screen.
uniform float depth_pull = 0.002;

// Signed distance from the line center, in pixels.
varying float v_across;


vec4 to_clip(vec3 local, mat4 modelview, mat4 projection) {
	vec3 view = (modelview * vec4(local + vec3(0.0, lift, 0.0), 1.0)).xyz;
	return projection * vec4(view * (1.0 - depth_pull), 1.0);
}


void vertex() {
	vec4 here = to_clip(VERTEX, MODELVIEW_MATRIX, PROJECTION_MATRIX);
	vec4 there = to_clip(CUSTOM0.xyz, MODELVIEW_MATRIX, PROJECTION_MATRIX);
	vec2 half_viewport = VIEWPORT_SIZE * 0.5;
	vec2 along = there.xy / there.w * half_viewport - here.xy / here.w * half_viewport;
	// Point along from the end with the smaller x (then z), so both ends agree on direction.
	if (VERTEX.x > CUSTOM0.x || (VERTEX.x == CUSTOM0.x && VERTEX.z > CUSTOM0.z)) {
		along = -along;
	}
	vec2 across = length(along) > 0.0001 ? normalize(vec2(-along.y, along.x)) : vec2(0.0);
	// One extra pixel on each side for antialiasing.
	v_across = CUSTOM0.w * (width_pixels * 0.5 + 1.0);
	here.xy += across * v_across / half_viewport * here.w;
	POSITION = here;
}


void fragment() {
	// Fraction of this pixel covered by a line width_pixels wide.
	float coverage = clamp(width_pixels * 0.5 + 0.5 - abs(v_across), 0.0, 1.0);
	ALBEDO = grid_color.rgb;
	ALPHA = grid_color.a * coverage;
}
