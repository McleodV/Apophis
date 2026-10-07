// Hex helpers for pointy-top hexes in axial coordinates (q, r). Mirrors HexMath.
// World positions are xz only (y ignored).
#ifndef HEX_MATH_INCLUDED
#define HEX_MATH_INCLUDED

const float HEX_SQRT3 = 1.7320508075688772;
// Neighbor offsets. Matches HexMath.DIRECTIONS.
const ivec2 HEX_DIRECTIONS[6] = {
	ivec2(1, 0), ivec2(1, -1), ivec2(0, -1),
	ivec2(-1, 0), ivec2(-1, 1), ivec2(0, 1)
};
// Unit xz vectors toward each neighbor, matching HEX_DIRECTIONS.
const vec2 HEX_NEIGHBOR_DIRS[6] = {
	vec2(1.0, 0.0), vec2(0.5, -0.8660254), vec2(-0.5, -0.8660254),
	vec2(-1.0, 0.0), vec2(-0.5, 0.8660254), vec2(0.5, 0.8660254)
};
// Unit xz vectors toward each corner, matching HexMath.corner_offset().
const vec2 HEX_CORNER_DIRS[6] = {
	vec2(0.8660254, -0.5), vec2(0.0, -1.0), vec2(-0.8660254, -0.5),
	vec2(-0.8660254, 0.5), vec2(0.0, 1.0), vec2(0.8660254, 0.5)
};


// Hex center in world xz.
vec2 hex_axial_to_world(ivec2 axial, float outer_radius) {
	return outer_radius * vec2(HEX_SQRT3 * (float(axial.x) + 0.5 * float(axial.y)), 1.5 * float(axial.y));
}


// Rounds fractional axial coordinates to the nearest hex.
ivec2 hex_axial_round(vec2 fractional) {
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


// Hex containing a world xz position.
ivec2 hex_world_to_axial(vec2 point, float outer_radius) {
	float q = (HEX_SQRT3 / 3.0 * point.x - point.y / 3.0) / outer_radius;
	float r = (2.0 / 3.0 * point.y) / outer_radius;
	return hex_axial_round(vec2(q, r));
}


// Step distance between two hexes.
int hex_distance(ivec2 a, ivec2 b) {
	ivec2 d = a - b;
	return (abs(d.x) + abs(d.y) + abs(d.x + d.y)) / 2;
}

#endif
