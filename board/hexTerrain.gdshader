shader_type spatial;
// Terrain coloring from per-tile data. Parameters are set by HexTerrainMaterial.
// Hex math mirrors HexMath; same-type blending mirrors HexTerrainHeight.

const float SQRT3 = 1.7320508075688772;
// Matches HexMath.DIRECTIONS.
const ivec2 DIRECTIONS[6] = {
	ivec2(1, 0), ivec2(1, -1), ivec2(0, -1),
	ivec2(-1, 0), ivec2(-1, 1), ivec2(0, 1)
};
// Unit xz vectors toward each neighbor, matching DIRECTIONS.
const vec2 NEIGHBOR_DIRS[6] = {
	vec2(1.0, 0.0), vec2(0.5, -0.8660254), vec2(-0.5, -0.8660254),
	vec2(-1.0, 0.0), vec2(-0.5, 0.8660254), vec2(0.5, 0.8660254)
};
// Unit xz vectors toward each corner, matching HexMath.corner_offset().
const vec2 CORNER_DIRS[6] = {
	vec2(0.8660254, -0.5), vec2(0.0, -1.0), vec2(-0.8660254, -0.5),
	vec2(-0.8660254, 0.5), vec2(0.0, 1.0), vec2(0.8660254, 0.5)
};
// R = dominant type, G = dominant value (0 = none), B = elevation. Pixel = axial + map_radius.
uniform sampler2D tile_data : filter_nearest, repeat_disable;
uniform int map_radius = 0;
uniform float outer_radius = 1.0;
uniform float blend_band = 0.4;
uniform float cliff_normal_y = 0.6;

uniform vec4 base_color : source_color = vec4(0.55, 0.56, 0.42, 1.0);
uniform vec4 cliff_color : source_color = vec4(0.42, 0.4, 0.37, 1.0);
uniform vec4 food_color : source_color = vec4(0.24, 0.55, 0.2, 1.0);
uniform vec4 trade_color : source_color = vec4(0.85, 0.68, 0.17, 1.0);
uniform vec4 industry_color : source_color = vec4(0.62, 0.27, 0.19, 1.0);
uniform vec4 phenomena_color : source_color = vec4(0.76, 0.15, 0.95, 1.0);

// Tint toward the resource color. Index 0 = dominant value 1.
uniform float output_strength[4];

uniform bool grid_visible = true;
uniform vec4 grid_color : source_color = vec4(0.05, 0.05, 0.05, 0.45);
uniform float grid_width_pixels = 1.5;

varying vec3 v_position;


vec2 axial_to_world(ivec2 axial) {
	return outer_radius * vec2(SQRT3 * (float(axial.x) + 0.5 * float(axial.y)), 1.5 * float(axial.y));
}


ivec2 axial_round(vec2 fractional) {
	float q = fractional.x;
	float r = fractional.y;
	float s = -q - r;
	float rq = round(q);
	float rr = round(r);
	float rs = round(s);
	float dq = abs(rq - q);
	float dr = abs(rr - r);
	float ds = abs(rs - s);
	if (dq > dr && dq > ds) {
		rq = -rr - rs;
	} else if (dr > ds) {
		rr = -rq - rs;
	}
	return ivec2(int(rq), int(rr));
}


ivec2 world_to_axial(vec2 point) {
	float q = (SQRT3 / 3.0 * point.x - point.y / 3.0) / outer_radius;
	float r = (2.0 / 3.0 * point.y) / outer_radius;
	return axial_round(vec2(q, r));
}


bool has_tile(ivec2 axial) {
	return (abs(axial.x) + abs(axial.y) + abs(axial.x + axial.y)) / 2 <= map_radius;
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


// True if the tile across an edge shares it: on the map and not across a cliff.
bool shares_edge(ivec2 axial, int own_elevation) {
	return has_tile(axial) && abs(read_tile(axial).b - own_elevation) <= 1;
}


// Neighbor color used for blending, as seen from the owner.
// Off the map or across a cliff: the owner's color, so the tile stays solid up to the edge.
// Different type: base color, so the owner blends toward base instead of the neighbor's color.
vec3 get_blend_color(ivec2 axial, ivec4 own, vec3 own_color) {
	if (!has_tile(axial)) {
		return own_color;
	}
	ivec4 tile = read_tile(axial);
	if (abs(tile.b - own.b) > 1) {
		return own_color;
	}
	if (!is_same_type(tile, own)) {
		return base_color.rgb;
	}
	return get_tile_color(tile);
}


// Piecewise-linear blend of 3 tile colors with flat tile tops. Mirrors HexTerrainHeight._blend().
vec3 blend_colors(vec3 w, vec3 c0, vec3 c1, vec3 c2) {
	float band = blend_band;
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


void vertex() {
	v_position = VERTEX;
}


void fragment() {
	// Derivatives first; they need uniform control flow.
	vec3 face = cross(dFdx(v_position), dFdy(v_position));
	vec2 dpdx = dFdx(v_position.xz);
	vec2 dpdy = dFdy(v_position.xz);
	bool is_cliff = abs(normalize(face).y) < cliff_normal_y;

	vec2 point = v_position.xz;
	ivec2 owner = world_to_axial(point);
	vec2 offset = point - axial_to_world(owner);
	float inner_radius = outer_radius * SQRT3 * 0.5;
	ivec4 own = has_tile(owner) ? read_tile(owner) : ivec4(0);

	// Nearest corner (for blending) and nearest edge (for the grid).
	int corner = 0;
	int edge = 0;
	float corner_dot = -1e9;
	float edge_dot = -1e9;
	for (int i = 0; i < 6; i++) {
		float c = dot(offset, CORNER_DIRS[i]);
		if (c > corner_dot) {
			corner_dot = c;
			corner = i;
		}
		float e = dot(offset, NEIGHBOR_DIRS[i]);
		if (e > edge_dot) {
			edge_dot = e;
			edge = i;
		}
	}
	float edge_distance = inner_radius - edge_dot;

	// Barycentric weights of the owner and the two neighbors nearest this point.
	int next = (corner + 1) % 6;
	float t_a = dot(offset, NEIGHBOR_DIRS[corner]) / inner_radius;
	float t_b = dot(offset, NEIGHBOR_DIRS[next]) / inner_radius;
	float weight_a = (2.0 * t_a - t_b) / 3.0;
	float weight_b = (2.0 * t_b - t_a) / 3.0;
	vec3 weights = vec3(1.0 - weight_a - weight_b, weight_a, weight_b);

	// Same-type neighbors blend with each other; different-type neighbors blend toward base color.
	vec3 own_color = get_tile_color(own);
	vec3 color_a = get_blend_color(owner + DIRECTIONS[corner], own, own_color);
	vec3 color_b = get_blend_color(owner + DIRECTIONS[next], own, own_color);
	vec3 color = blend_colors(weights, own_color, color_a, color_b);

	if (is_cliff) {
		color = cliff_color.rgb;
	} else if (grid_visible) {
		// Edge distance in screen pixels, measured across the edge.
		vec2 edge_normal = NEIGHBOR_DIRS[edge];
		float pixel_size = max(length(vec2(dot(dpdx, edge_normal), dot(dpdy, edge_normal))), 1e-6);
		float pixels = edge_distance / pixel_size;
		// Shared edges are split between both tiles. Cliff and map edges draw the full width here.
		float half_width = grid_width_pixels * 0.5;
		if (!shares_edge(owner + DIRECTIONS[edge], own.b)) {
			half_width = grid_width_pixels;
		}
		float line = clamp(half_width - pixels + 0.5, 0.0, 1.0);
		color = mix(color, grid_color.rgb, grid_color.a * line);
	}

	ALBEDO = color;
	ROUGHNESS = 1.0;
}
