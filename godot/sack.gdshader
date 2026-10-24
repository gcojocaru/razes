shader_type spatial;
render_mode cull_disabled;

// Burlap for the inventory's grain sacks: coarse threads passing over and under
// each other, uneven and fuzzy, with holes where they cross and blotches of wear.
// UV.x runs once around the sack and UV.y up it in bag units; COLOR.r is the
// shade that creases and the floor give the cloth. The inside shows darker.

uniform vec3 cloth : source_color = vec3(0.52, 0.42, 0.3);
// Threads around the sack, and per unit of its height.
uniform vec2 threads = vec2(84.0, 36.0);
uniform float seed = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 p = UV * threads + seed * 17.0;
	vec2 cell = floor(p);
	vec2 f = fract(p) - 0.5;
	// Which way the thread on top runs here, and where on it: rounded across, dipping at its ends.
	bool warp = mod(cell.x + cell.y, 2.0) < 1.0;
	float across = warp ? f.x : f.y;
	float along = warp ? f.y : f.x;
	float lift = 1.0 - 4.0 * across * across - 4.8 * pow(abs(along), 3.0);
	float hole = smoothstep(0.32, 0.5, abs(f.x)) * smoothstep(0.32, 0.5, abs(f.y));
	float fibres = 0.25 * (noise(p * vec2(4.0, 0.6)) - 0.5) + 0.2 * (noise(p * vec2(0.6, 4.0)) - 0.5);
	float shade = (0.8 + 0.2 * lift) * (0.85 + 0.3 * hash(warp ? vec2(cell.x, 7.0) : vec2(3.0, cell.y))) + fibres;
	shade = mix(shade, 0.35, hole * 0.7) * (0.82 + 0.36 * noise(p * 0.12));
	ALBEDO = cloth * shade * COLOR.r * (FRONT_FACING ? 1.0 : 0.5);
	vec2 slope = vec2(-8.0 * across, -14.4 * along * abs(along));
	vec3 bump = normalize(vec3(-(warp ? slope : slope.yx) * 0.08, 1.0));
	NORMAL_MAP = bump * 0.5 + 0.5;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
	// Loose fibres catch the light along the outline.
	EMISSION = cloth * 0.12 * pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 3.0);
}
