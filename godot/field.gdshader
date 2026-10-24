shader_type spatial;

uniform float grid_size = 16.0;
uniform vec2 hovered = vec2(-1.0);
uniform float snow = 0.0;
uniform float wet = 0.0;
// One texel per cell: R is (Farm.STAGES index + 8 × crop number) / 255, G the
// growth, B 1 when selected, A the soil fertility.
uniform sampler2D crops : filter_nearest;
uniform sampler2D grass_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// One furrow tile per plot; its ridges run along x.
uniform sampler2D furrow_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D furrow_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

varying vec2 grid;

void vertex() {
	// UV spans the whole plane, so scaling it gives cell coordinates.
	grid = UV * grid_size;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// Smooth value noise, for patchy rather than blocky shapes.
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0)), f.x), f.y);
}

void fragment() {
	vec2 cell = floor(grid);
	vec2 edge = min(fract(grid), 1.0 - fract(grid)) / fwidth(grid);
	float line = 1.0 - clamp(min(edge.x, edge.y) - 0.5, 0.0, 1.0);

	// Two scales of the grass texture hide its repeat.
	vec3 color = mix(texture(grass_color, grid * 0.5).rgb, texture(grass_color, grid * 0.13 + 0.37).rgb, 0.35);
	color *= 0.9 + 0.2 * hash(cell);
	vec3 normal = texture(grass_normal, grid * 0.5).rgb;
	vec4 crop = texelFetch(crops, ivec2(cell), 0);
	int stage = int(round(crop.r * 255.0)) % 8;
	float roughness = 1.0;
	color *= 1.0 - 0.3 * wet;
	if (stage > 0) {
		vec3 soil = texture(furrow_color, grid).rgb;
		float hollow = 1.0 - smoothstep(0.16, 0.3, dot(soil, vec3(0.333)));
		// Worn soil is paler and greyer.
		soil = mix(vec3(dot(soil, vec3(0.333))) * 1.35, soil, 0.35 + 0.65 * crop.a);
		soil *= 1.0 - 0.3 * wet;
		vec3 soil_normal = texture(furrow_normal, grid).rgb;
		// Rain pools in furrow hollows: smooth, flat and sky-tinted, more so at
		// grazing angles; gone when it dries.
		float puddle = wet * hollow * smoothstep(0.42, 0.58, noise(grid * 3.0 + 11.0));
		float sheen = 0.35 + 0.65 * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
		soil = mix(soil, mix(soil * 0.3, vec3(0.42, 0.47, 0.52), sheen), puddle);
		soil_normal = mix(soil_normal, vec3(0.5, 0.5, 1.0), puddle);
		// Grass creeps back over stubble and dead crops as their growth rises.
		float weeds = stage >= 4 ? 1.0 - smoothstep(crop.g - 0.06, crop.g + 0.06, noise(grid * 6.0)) : 0.0;
		color = mix(soil, color, weeds);
		normal = mix(soil_normal, normal, weeds);
		roughness = mix(1.0, 0.15, puddle * (1.0 - weeds));
	}
	color = mix(color, vec3(0.86, 0.89, 0.93), snow * (0.75 + 0.25 * hash(cell + 7.0)));
	if (cell == hovered) color = mix(color, vec3(0.95, 0.88, 0.55), 0.3);
	if (crop.b > 0.5) color = mix(color, vec3(0.95, 0.7, 0.25), 0.45);

	ALBEDO = mix(color, color * 0.5, line * 0.6);
	NORMAL_MAP = normal;
	ROUGHNESS = roughness;
}
