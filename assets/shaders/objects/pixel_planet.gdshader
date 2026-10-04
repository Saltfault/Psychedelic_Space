// Francisco Cidade  |  https://fcidade.com  |  https://fcidade.itch.io
shader_type canvas_item;
// Pixel Planet: a spinning pixel art planet, drawn without any textures.
// Godot 4.x, CanvasItem. Put it on a square ColorRect. CC0: use it, change it, sell it with your game.
// Note: the node's modulate is not applied (the shader outputs the final color).

// Kind of planet. Terran has oceans, Desert is dry, Ice is frozen, Lava glows, Gas giant is all bands, Moon is cratered rock with no air.
uniform int planet_type : hint_enum("Terran", "Desert", "Ice", "Lava", "Gas giant", "Moon") = 0;
// Planet resolution in big pixels (the planet is this many pixels wide).
uniform int pixels : hint_range(16, 256, 1) = 64;
// Seed: any number gives a different world.
uniform float seed : hint_range(0.0, 100.0, 0.1) = 3.0;
// Rotation speed, in turns per second.
uniform float spin : hint_range(-1.0, 1.0, 0.01) = 0.05;
// Size of the continents (higher = more, smaller landmasses).
uniform float scale : hint_range(0.5, 8.0, 0.1) = 2.0;
// Fraction of the surface that is water.
uniform float sea_level : hint_range(0.0, 1.0, 0.01) = 0.5;
// Where the light comes from, as a direction on screen (x right, y up) plus depth (z toward the viewer).
uniform vec3 light_dir = vec3(-0.6, 0.5, 0.6);
// Number of shade steps between light and shadow.
uniform int shade_steps : hint_range(2, 6, 1) = 3;
// Axis tilt in radians: how far the north pole leans toward the viewer.
uniform float tilt : hint_range(-1.0, 1.0, 0.01) = 0.35;
// Draw rings around the planet (the planet shrinks to leave room for them).
uniform bool rings = false;
// How open the rings look: 1 = seen from above, near 0 = edge-on.
uniform float ring_open : hint_range(0.05, 1.0, 0.01) = 0.3;
// Rotation of the rings on screen, in radians.
uniform float ring_angle : hint_range(-1.57, 1.57, 0.01) = -0.3;
// Size of the polar ice caps (0 = none). Used by Terran, Desert and Ice.
uniform float ice_caps : hint_range(0.0, 1.0, 0.01) = 0.25;
// How much of the sky is covered by clouds (0 = none).
uniform float cloud_cover : hint_range(0.0, 1.0, 0.01) = 0.5;
// Strength of the atmosphere glow (its color depends on the planet type).
uniform float atmosphere_strength : hint_range(0.0, 1.0, 0.01) = 0.55;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + vec3(0.1, 0.2, 0.3));
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

// 3D value noise: sampling the sphere surface in 3D means no seam and no pole pinch.
float noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y),
		f.z);
}

float fbm(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p = p * 2.03 + 11.7;
		a *= 0.5;
	}
	return v;
}

// Cloud density at a point of the visible sphere (n = unrotated surface normal).
// Lean the planet so its north pole points toward the viewer by `tilt`.
vec3 tilted(vec3 p) {
	float c = cos(tilt);
	float s = sin(tilt);
	return vec3(p.x, p.y * c + p.z * s, -p.y * s + p.z * c);
}

// Clouds turn exactly twice as fast as the ground, so a full turn of the ground loops cleanly.
float clouds(vec3 n, float angle) {
	vec3 pc = vec3(n.x * cos(angle) + n.z * sin(angle), n.y, -n.x * sin(angle) + n.z * cos(angle));
	pc = tilted(pc);
	// squash vertically: streaks that follow the latitude lines read as weather bands
	return fbm(pc * vec3(1.0, 1.7, 1.0) * scale * 1.5 + seed * 3.7 + 40.0);
}

// Ground color for a height t (already minus sea_level), per planet type.
// For the lava type, the returned alpha-like flag says "this glows" (no shading).
vec3 ground(int type, float t, out float glow) {
	glow = 0.0;
	if (type == 1) { // desert: no water, from rust canyons to pale dunes
		if (t < -0.12) return vec3(0.45, 0.20, 0.14);
		if (t < 0.0) return vec3(0.65, 0.34, 0.18);
		if (t < 0.10) return vec3(0.82, 0.55, 0.28);
		if (t < 0.22) return vec3(0.90, 0.72, 0.42);
		return vec3(0.95, 0.85, 0.62);
	}
	if (type == 2) { // ice: dark blue ice, then frost
		t += 0.10;
		if (t < -0.12) return vec3(0.30, 0.40, 0.62);
		if (t < 0.0) return vec3(0.50, 0.65, 0.85);
		if (t < 0.10) return vec3(0.75, 0.88, 0.97);
		if (t < 0.22) return vec3(0.90, 0.96, 1.00);
		return vec3(1.0);
	}
	if (type == 3) { // lava: cooled rock with glowing rivers
		if (t < -0.18) { glow = 1.0; return vec3(1.00, 0.78, 0.22); }
		if (t < -0.08) { glow = 1.0; return vec3(1.00, 0.42, 0.10); }
		if (t < 0.10) return vec3(0.20, 0.15, 0.16);
		if (t < 0.22) return vec3(0.30, 0.24, 0.24);
		return vec3(0.40, 0.34, 0.32);
	}
	// terran
	if (t < -0.12) return vec3(0.08, 0.16, 0.42);
	if (t < 0.0) return vec3(0.12, 0.32, 0.62);
	if (t < 0.03) return vec3(0.82, 0.74, 0.46);
	if (t < 0.14) return vec3(0.36, 0.62, 0.26);
	if (t < 0.24) return vec3(0.20, 0.42, 0.22);
	return vec3(0.52, 0.50, 0.46);
}

// Craters: distance to the nearest crater center, in crater radii (below 1 = inside the bowl).
float crater(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	float best = 9.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			for (int z = -1; z <= 1; z++) {
				vec3 g = vec3(float(x), float(y), float(z));
				vec3 o = vec3(hash(i + g), hash(i + g + 7.1), hash(i + g + 13.7));
				float rad = 0.30 + 0.30 * hash(i + g + 3.3);
				best = min(best, length(g + o - f) / rad);
			}
		}
	}
	return best;
}

vec3 moon(vec3 p) {
	float h = fbm(p * scale + seed * 7.31);
	vec3 col = h < 0.45 ? vec3(0.46, 0.45, 0.47) : (h < 0.58 ? vec3(0.62, 0.61, 0.62) : vec3(0.76, 0.74, 0.72));
	float k = crater(p * scale * 1.5 + seed);
	if (k < 0.8) col *= 0.60;        // dark floor of the bowl
	else if (k < 1.0) col *= 1.28;   // raised rim catches light
	return col;
}

// Gas giant: stripes by latitude, bent by noise so the edges swirl.
vec3 gas(vec3 p) {
	float v = p.y * 7.0 + (fbm(p * vec3(1.2, 3.0, 1.2) * scale + seed) - 0.5) * 2.2;
	float k = floor(v);
	float r = hash(vec3(k, seed, 1.7));
	if (r < 0.25) return vec3(0.58, 0.40, 0.30);
	if (r < 0.55) return vec3(0.72, 0.52, 0.36);
	if (r < 0.80) return vec3(0.85, 0.70, 0.50);
	return vec3(0.93, 0.84, 0.66);
}

void fragment() {
	// atmosphere glow color and cloud amount depend on the planet type
	vec3 atm = vec3(0.45, 0.70, 1.0);
	float cover = cloud_cover;
	if (planet_type == 1) { atm = vec3(0.95, 0.65, 0.40); cover *= 0.35; }
	else if (planet_type == 2) { atm = vec3(0.70, 0.90, 1.00); cover *= 0.5; }
	else if (planet_type == 3) { atm = vec3(1.00, 0.40, 0.20); cover = 0.0; }
	else if (planet_type == 4) { atm = vec3(0.90, 0.75, 0.55); cover = 0.0; }
	else if (planet_type == 5) { cover = 0.0; }
	float atm_k = planet_type == 5 ? 0.0 : atmosphere_strength;

	// snap to the big-pixel grid, then center on the pixel
	vec2 uv = (floor(UV * float(pixels)) + 0.5) / float(pixels);
	vec2 qs = uv * 2.0 - 1.0;
	// with rings the planet takes about half of the canvas, the rings the rest
	vec2 q = rings ? qs / 0.55 : qs;
	float d = dot(q, q);
	vec2 ls = normalize(vec2(light_dir.x, -light_dir.y)); // light direction on screen

	// rings: concentric stripes on a flattened circle, with gaps between them
	vec4 ring = vec4(0.0);
	bool ring_front = false;
	if (rings) {
		vec2 lq = vec2(qs.x * cos(ring_angle) + qs.y * sin(ring_angle), -qs.x * sin(ring_angle) + qs.y * cos(ring_angle));
		float rr = length(vec2(lq.x, lq.y / ring_open));
		if (rr > 0.68 && rr < 0.98) {
			float r = hash(vec3(floor((rr - 0.68) * 30.0), seed, 5.0));
			if (r > 0.22) {
				ring = vec4(mix(vec3(0.55, 0.42, 0.32), vec3(0.93, 0.84, 0.66), r), 1.0);
				ring_front = lq.y > 0.0;
				// the planet throws its shadow on the ring, on the side away from the light
				if (!ring_front && dot(qs, ls) < 0.0 && abs(qs.x * ls.y - qs.y * ls.x) < 0.55) ring.rgb *= 0.45;
			}
		}
	}
	if (d > 1.0) {
		// one-pixel halo around the planet, only on the lit side
		float halo = 1.0 + 2.0 / float(pixels);
		float side = clamp(dot(normalize(vec3(q.x, -q.y, 0.0)), normalize(light_dir)) + 0.3, 0.0, 1.0);
		COLOR = atm_k > 0.0 && d < halo * halo && side > 0.4 ? vec4(atm, atm_k) : vec4(0.0);
		if (ring.a > 0.0) COLOR = ring;
	} else {
		// point on the front of the sphere
		vec3 n = vec3(q.x, -q.y, sqrt(1.0 - d));
		// rotate around the vertical axis
		float a = TIME * spin * 6.2831853;
		vec3 p = tilted(vec3(n.x * cos(a) + n.z * sin(a), n.y, -n.x * sin(a) + n.z * cos(a)));
		vec3 col;
		float glow = 0.0;
		if (planet_type == 4) {
			col = gas(p);
		} else if (planet_type == 5) {
			col = moon(p);
		} else {
			float h = fbm(p * scale + seed * 7.31);
			col = ground(planet_type, h - sea_level, glow);
			// polar caps: ice above a latitude line that wobbles with noise, so the edge is ragged
			if (planet_type < 3) {
				// the south cap is smaller, so the strip of it that peeks over the bottom edge stays thin
				float polar = (p.y > 0.0 ? p.y : -p.y * 0.85) + (fbm(p * 4.0 + seed) - 0.5) * 0.3;
				if (polar > 1.0 - ice_caps * 0.5) col = planet_type == 1 ? vec3(0.96, 0.90, 0.82) : vec3(0.92, 0.96, 1.0);
			}
		}
		// light from the unrotated surface normal, cut into flat bands
		float lit = clamp(dot(n, normalize(light_dir)), 0.0, 1.0);
		float step_f = float(shade_steps);
		float band = floor(lit * step_f + 0.35) / step_f;
		// glowing lava keeps its color in the dark; everything else shades
		vec3 shaded = col * mix(0.48, 1.08, band);
		// shadow side leans cool, lit side leans warm
		shaded = mix(shaded, shaded * vec3(0.7, 0.8, 1.2), 1.0 - band);
		col = mix(shaded, col, glow * (1.0 - band * 0.5));
		// clouds: own noise layer, two tones, plus a shadow thrown on the ground
		if (cover > 0.0) {
			float thr = 0.78 - cover * 0.4;
			float c = clouds(n, a * 2.0);
			// the shadow is the same clouds sampled a bit toward the light
			float sh = clouds(normalize(n - normalize(light_dir) * 0.07), a * 2.0);
			if (c > thr) {
				vec3 cloud = vec3(0.90, 0.94, 1.0);
				if (c < thr + 0.07) cloud = vec3(0.70, 0.78, 0.92); // thin edge, cooler
				col = cloud * mix(0.58, 1.0, band);
			} else if (sh > thr) {
				col *= 0.72; // ground under a cloud
			}
		}
		// atmosphere: a band of glow just inside the edge, strongest where the light hits
		float edge = 1.0 - n.z;
		if (atm_k > 0.0 && edge > 0.82 && band > 0.0) col = mix(col, atm, atm_k);
		COLOR = vec4(col, 1.0);
		if (ring_front && ring.a > 0.0) COLOR = ring;
	}
}
