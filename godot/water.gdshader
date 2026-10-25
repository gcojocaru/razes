shader_type spatial;

uniform float grid_size = 16.0;
uniform float cell_size = 2.0;
uniform vec2 hovered = vec2(-1.0);
uniform sampler2D crops : filter_nearest;

varying vec2 surface;

void vertex() {
	surface = VERTEX.xz;
}

void fragment() {
	float ripple = sin(surface.x * 1.8 + surface.y * 0.7 + TIME * 0.6);
	float cross_ripple = sin(surface.y * 1.6 - surface.x * 0.5 + TIME * 0.5);
	NORMAL_MAP = vec3(0.5 + ripple * 0.018, 0.5 + cross_ripple * 0.012, 1.0);
	float sheen = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 color = mix(vec3(0.055, 0.19, 0.20), vec3(0.30, 0.45, 0.48), sheen) + ripple * cross_ripple * 0.005;
	vec2 cell = floor(surface / cell_size + grid_size * 0.5);
	if (all(greaterThanEqual(cell, vec2(0.0))) && all(lessThan(cell, vec2(grid_size)))) {
		if (cell == hovered) color = mix(color, vec3(0.95, 0.88, 0.55), 0.3);
		if (texelFetch(crops, ivec2(cell), 0).b > 0.5) color = mix(color, vec3(0.95, 0.7, 0.25), 0.45);
	}
	ALBEDO = color;
	ROUGHNESS = 0.45;
	SPECULAR = 0.3;
}
