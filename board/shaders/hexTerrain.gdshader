shader_type spatial;
// Terrain coloring from per-tile data. Parameters are set by HexTerrainMaterial.
// Same-type blending mirrors HexTerrainHeight.

#include "res://board/shaders/hexMath.gdshaderinc"
#include "res://shaders/noise.gdshaderinc"

// Separates the x and y border warp samples.
const vec2 WARP_OFFSET = vec2(57.3, 113.9);
// How far outside a cliff's height span a face may reach and still count as part of it, in world units.
const float CLIFF_SPAN_TOLERANCE = 0.02;

// R = dominant type, G = dominant value (0 = none), B = elevation. Pixel = axial + map_radius.
uniform sampler2D tile_data : filter_nearest, repeat_disable;
uniform int map_radius = 0;
uniform float outer_radius = 1.0;
uniform float blend_band = 0.4;
// World height of one elevation level, and the gap between lattice rows: how far a cliff's
// foot lies out from its tile edge.
uniform float elevation_step = 0.3;
uniform float lattice_row = 0.144;

uniform vec4 base_color : source_color = vec4(0.55, 0.56, 0.42, 1.0);
uniform vec4 cliff_color : source_color = vec4(0.42, 0.4, 0.37, 1.0);
uniform vec4 food_color : source_color = vec4(0.24, 0.55, 0.2, 1.0);
uniform vec4 trade_color : source_color = vec4(0.85, 0.68, 0.17, 1.0);
uniform vec4 industry_color : source_color = vec4(0.62, 0.27, 0.19, 1.0);
uniform vec4 phenomena_color : source_color = vec4(0.76, 0.15, 0.95, 1.0);

// Tint toward the resource color. Index 0 = dominant value 1.
uniform float output_strength[4];

// Borders between different dominant types.
uniform float border_blend = 0.08;
uniform float border_warp = 0.15;
uniform float border_warp_frequency = 1.5;

// Cliff shading from smooth (0) to flat per face (1).
uniform float cliff_faceting = 1.0;

// Where a cliff meets a tile, at its rim and foot, tile color reaches onto the face and rock onto
// the tile, by these world distances, give or take cliff_blend_noise.
uniform float rim_blend_down = 0.18;
uniform float rim_blend_in = 0.08;
uniform float foot_blend_up = 0.1;
uniform float foot_blend_out = 0.08;
uniform float cliff_blend_noise = 0.08;
uniform float cliff_blend_frequency = 8.0;
// How far tile-colored parts of a face shade smooth instead of faceted.
uniform float cliff_blend_smoothing = 1.0;
// 0 = rim and foot blends fade smoothly, 1 = they break into patches of tile color and rock.
uniform float cliff_blend_patchiness = 0.0;
uniform float cliff_patch_frequency = 18.0;

// Undisplaced xz from the mesh UV. Cliff displacement doesn't move tile colors.
varying vec2 v_rest;
// 1 on cliff faces, from vertex color red. Constant per face.
varying float v_cliff;
// World height.
varying float v_height;


bool has_tile(ivec2 axial) {
	return hex_distance(axial, ivec2(0)) <= map_radius;
}


ivec4 read_tile(ivec2 axial) {
	return ivec4(round(texelFetch(tile_data, axial + ivec2(map_radius), 0) * 255.0));
}


vec3 get_resource_color(int type) {
	if (type == 0) {
		return food_color.rgb;
	}
	if (type == 1) {
		return trade_color.rgb;
	}
	if (type == 2) {
		return industry_color.rgb;
	}
	return phenomena_color.rgb;
}


// Base color tinted toward the dominant resource color by its value.
vec3 get_tile_color(ivec4 tile) {
	if (tile.g <= 0) {
		return base_color.rgb;
	}
	int index = min(tile.g, 4) - 1;
	return mix(base_color.rgb, get_resource_color(tile.r), output_strength[index]);
}


// Same dominant type, or both without output.
bool is_same_type(ivec4 a, ivec4 b) {
	if (a.g <= 0 || b.g <= 0) {
		return a.g <= 0 && b.g <= 0;
	}
	return a.r == b.r;
}


// True if a tile shares an edge with a tile at elevation: on the map and not across a cliff.
bool shares_edge(ivec4 tile, bool on_map, int elevation) {
	return on_map && abs(tile.b - elevation) <= 1;
}


// Neighbor color used for blending, as seen from the viewer tile.
// Off the map or across a cliff: the viewer's color, so the tile stays solid up to the edge.
// Different type: base color, so the viewer blends toward base instead of the neighbor's color.
vec3 get_blend_color(ivec4 tile, bool on_map, ivec4 viewer, vec3 viewer_color) {
	if (!shares_edge(tile, on_map, viewer.b)) {
		return viewer_color;
	}
	if (!is_same_type(tile, viewer)) {
		return base_color.rgb;
	}
	return get_tile_color(tile);
}


// Piecewise-linear blend of 3 tiles with flat tile tops. Mirrors HexTerrainHeight._blend().
// Order-independent. With identity colors, returns the blend weights.
vec3 blend(vec3 w, vec3 c0, vec3 c1, vec3 c2, float band) {
	float corner_min = (1.0 - band) / 3.0;
	// Flat tile top.
	if (w.x - w.y >= band && w.x - w.z >= band) {
		return c0;
	}
	if (w.y - w.z >= band && w.y - w.x >= band) {
		return c1;
	}
	if (w.z - w.x >= band && w.z - w.y >= band) {
		return c2;
	}
	// Slope between two tiles, away from the third.
	if (w.x < corner_min) {
		return mix(c1, c2, clamp((w.z - w.y + band) / (2.0 * band), 0.0, 1.0));
	}
	if (w.y < corner_min) {
		return mix(c2, c0, clamp((w.x - w.z + band) / (2.0 * band), 0.0, 1.0));
	}
	if (w.z < corner_min) {
		return mix(c0, c1, clamp((w.y - w.x + band) / (2.0 * band), 0.0, 1.0));
	}
	// Corner where all 3 tiles meet.
	return ((w.x - corner_min) * c0 + (w.y - corner_min) * c1 + (w.z - corner_min) * c2) / band;
}


// Barycentric weights of a tile and its neighbors in adjacent directions a and b.
// offset: from the tile's center. Valid outside the triangle too.
vec3 get_weights(vec2 offset, int a, int b, float inner_radius) {
	float t_a = dot(offset, HEX_NEIGHBOR_DIRS[a]) / inner_radius;
	float t_b = dot(offset, HEX_NEIGHBOR_DIRS[b]) / inner_radius;
	float weight_a = (2.0 * t_a - t_b) / 3.0;
	float weight_b = (2.0 * t_b - t_a) / 3.0;
	return vec3(1.0 - weight_a - weight_b, weight_a, weight_b);
}


// Color at this point as seen from t0, blending toward t1 and t2. w: weights in the same order.
vec3 get_view_color(vec3 w, ivec4 t0, ivec4 t1, bool on_1, ivec4 t2, bool on_2) {
	vec3 c0 = get_tile_color(t0);
	vec3 c1 = get_blend_color(t1, on_1, t0, c0);
	vec3 c2 = get_blend_color(t2, on_2, t0, c0);
	return blend(w, c0, c1, c2, blend_band);
}


// Two octaves of value noise in [-1, 1].
float border_noise(vec2 p) {
	return noise_value(p) * 0.65 + noise_value(p * 2.0 + WARP_OFFSET.yx) * 0.35;
}


// World-space offset that bends borders between different types.
vec2 get_border_warp(vec2 point) {
	vec2 p = point * border_warp_frequency;
	return vec2(border_noise(p), border_noise(p + WARP_OFFSET)) * border_warp;
}


// How much rock shows where a cliff meets a tile: 1 on the face, 0 on the tile.
// across: signed distance from the junction, in world units: above 0 onto the tile, below 0 onto the
// face. face, tile: how far the blend reaches each way. The junction wanders with noise at point,
// and patches follow noise at point and height, so both sides of it agree.
float get_rock(float across, float face, float tile, vec2 point, float height) {
	float shift = border_noise(point * cliff_blend_frequency + WARP_OFFSET) * cliff_blend_noise;
	float rock = 1.0 - smoothstep(-face, tile + 0.0001, across + shift);
	// Patches: noise pushes each spot toward rock or tile, most midway, and a narrower fade sharpens them.
	vec2 patch_point = (point + vec2(height * 1.7, -height)) * cliff_patch_frequency;
	float patch_noise = noise_value(patch_point) * 0.65 + noise_value(patch_point * 2.3 + WARP_OFFSET) * 0.35;
	rock += patch_noise * cliff_blend_patchiness * 2.0 * rock * (1.0 - rock);
	float fade = mix(0.55, 0.06, cliff_blend_patchiness);
	return smoothstep(0.5 - fade, 0.5 + fade, rock);
}


void vertex() {
	v_rest = UV;
	v_cliff = COLOR.r;
	v_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}


void fragment() {
	// Derivatives first; they need uniform control flow.
	// Flat face normal in view space, turned toward the camera.
	vec3 face_normal = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(face_normal, VERTEX) > 0.0) {
		face_normal = -face_normal;
	}
	bool is_cliff = v_cliff > 0.5;

	vec2 point = v_rest;
	ivec2 owner = hex_world_to_axial(point, outer_radius);
	vec2 offset = point - hex_axial_to_world(owner, outer_radius);
	float inner_radius = outer_radius * HEX_SQRT3 * 0.5;
	bool on_owner = has_tile(owner);
	ivec4 own = on_owner ? read_tile(owner) : ivec4(0);

	// Nearest corner, for blending.
	int corner = 0;
	float corner_dot = -1e9;
	for (int i = 0; i < 6; i++) {
		float c = dot(offset, HEX_CORNER_DIRS[i]);
		if (c > corner_dot) {
			corner_dot = c;
			corner = i;
		}
	}

	// The two neighbors nearest this point.
	int next = (corner + 1) % 6;
	ivec2 axial_a = owner + HEX_DIRECTIONS[corner];
	ivec2 axial_b = owner + HEX_DIRECTIONS[next];
	bool on_a = has_tile(axial_a);
	bool on_b = has_tile(axial_b);
	ivec4 tile_a = on_a ? read_tile(axial_a) : ivec4(0);
	ivec4 tile_b = on_b ? read_tile(axial_b) : ivec4(0);
	bool shares_a = shares_edge(tile_a, on_a, own.b);
	bool shares_b = shares_edge(tile_b, on_b, own.b);

	// Each tile's color here, as seen from that tile.
	// Same-type neighbors blend with each other; different-type neighbors blend toward base color.
	// Tiles across a cliff or off the map act as the owner.
	vec3 weights = get_weights(offset, corner, next, inner_radius);
	vec3 color_owner = get_view_color(weights, own, tile_a, on_a, tile_b, on_b);
	vec3 color_a = shares_a ? get_view_color(weights.yxz, tile_a, own, on_owner, tile_b, on_b) : color_owner;
	vec3 color_b = shares_b ? get_view_color(weights.zxy, tile_b, own, on_owner, tile_a, on_a) : color_owner;

	// Split the 3 colors along noise-bent borders, with a narrow crossfade.
	// Same-type colors match near their shared edge, so only different-type borders change.
	vec3 split = get_weights(offset + get_border_warp(point), corner, next, inner_radius);
	split = blend(split, vec3(1.0, 0.0, 0.0), vec3(0.0, 1.0, 0.0), vec3(0.0, 0.0, 1.0), border_blend);
	vec3 color = split.x * color_owner + split.y * color_a + split.z * color_b;

	// Distances to the three tile borders meeting at the nearest corner: the owner's two sides, and
	// the border between its two neighbors there, which starts at the corner.
	vec3 border_distance = vec3(
		inner_radius - dot(offset, HEX_NEIGHBOR_DIRS[corner]),
		inner_radius - dot(offset, HEX_NEIGHBOR_DIRS[next]),
		length(offset - HEX_CORNER_DIRS[corner] * outer_radius)
	);

	if (is_cliff) {
		// The cliff this face belongs to: the nearest of those borders that is a cliff and whose
		// height span holds this point. Its rim takes the upper tile's color, its foot the lower's.
		vec3 face = cliff_color.rgb;
		float tile_cover = 0.0;
		float nearest = 1e9;
		for (int i = 0; i < 3; i++) {
			ivec4 first = i == 2 ? tile_a : own;
			ivec4 second = i == 0 ? tile_a : tile_b;
			bool on_both = (i == 2 ? on_a : on_owner) && (i == 0 ? on_a : on_b);
			if (!on_both || abs(first.b - second.b) < 2 || border_distance[i] >= nearest) {
				continue;
			}
			bool first_high = first.b > second.b;
			float rim = float(max(first.b, second.b)) * elevation_step;
			float foot = float(min(first.b, second.b)) * elevation_step;
			if (v_height < foot - CLIFF_SPAN_TOLERANCE || v_height > rim + CLIFF_SPAN_TOLERANCE) {
				continue;
			}
			nearest = border_distance[i];
			// The owner's own color here where it is one of the two, so the face matches its tile.
			vec3 high_color = i < 2 && first_high ? color : get_tile_color(first_high ? first : second);
			vec3 low_color = i < 2 && !first_high ? color : get_tile_color(first_high ? second : first);
			float top = 1.0 - get_rock(v_height - rim, rim_blend_down, rim_blend_in, point, v_height);
			float bottom = 1.0 - get_rock(foot - v_height, foot_blend_up, foot_blend_out, point, v_height);
			face = mix(mix(cliff_color.rgb, high_color, top), low_color, bottom);
			tile_cover = max(top, bottom);
		}
		color = face;
		NORMAL = normalize(mix(NORMAL, face_normal, cliff_faceting * (1.0 - tile_cover * cliff_blend_smoothing)));
	} else {
		// Rock onto the tile from the rim above a cliff, or from the foot below one, on either nearest
		// side. The foot lies a lattice row out from the edge.
		float rock = 0.0;
		for (int i = 0; i < 2; i++) {
			bool on = i == 0 ? on_a : on_b;
			ivec4 tile = i == 0 ? tile_a : tile_b;
			if (!on || abs(tile.b - own.b) < 2) {
				continue;
			}
			rock = max(rock, own.b > tile.b
				? get_rock(border_distance[i], rim_blend_down, rim_blend_in, point, v_height)
				: get_rock(border_distance[i] - lattice_row, foot_blend_up, foot_blend_out, point, v_height));
		}
		color = mix(color, cliff_color.rgb, rock);
	}

	ALBEDO = color;
	ROUGHNESS = 1.0;
}
