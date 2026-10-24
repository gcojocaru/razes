shader_type spatial;

uniform float grid_size = 16.0;
uniform vec2 hovered = vec2(-1.0);
uniform vec2 selected = vec2(-1.0);

varying vec2 grid;

void vertex() {
	// UV spans the whole plane, so scaling it gives cell coordinates.
	grid = UV * grid_size;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 cell = floor(grid);
	vec2 edge = min(fract(grid), 1.0 - fract(grid)) / fwidth(grid);
	float line = 1.0 - clamp(min(edge.x, edge.y) - 0.5, 0.0, 1.0);

	vec3 grass = mix(vec3(0.33, 0.45, 0.2), vec3(0.4, 0.52, 0.24), hash(cell));
	if (cell == hovered) grass = mix(grass, vec3(0.9, 0.85, 0.55), 0.35);
	if (cell == selected) grass = mix(grass, vec3(0.85, 0.65, 0.2), 0.6);

	ALBEDO = mix(grass, vec3(0.2, 0.26, 0.12), line * 0.8);
	ROUGHNESS = 1.0;
}
