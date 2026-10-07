// Procedural noise helpers. No uniforms or textures.
#ifndef NOISE_INCLUDED
#define NOISE_INCLUDED


// Pseudo-random value in [0, 1) per integer cell.
float noise_hash(vec2 p) {
	vec3 p3 = fract(p.xyx * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}


// Smooth value noise in [-1, 1]. One cell per world unit at p = position.
float noise_value(vec2 p) {
	vec2 cell = floor(p);
	vec2 u = smoothstep(0.0, 1.0, fract(p));
	float a = noise_hash(cell);
	float b = noise_hash(cell + vec2(1.0, 0.0));
	float c = noise_hash(cell + vec2(0.0, 1.0));
	float d = noise_hash(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y) * 2.0 - 1.0;
}

#endif
