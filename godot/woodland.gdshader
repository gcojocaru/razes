shader_type spatial;
render_mode cull_disabled;
uniform sampler2D bark : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D leaves : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D crops : filter_nearest;
uniform bool foliage = false;
uniform vec2 wind = vec2(0.1, 0.0);
uniform vec3 person = vec3(1000.0);
uniform vec3 camera_position = vec3(1000.0);
uniform vec3 autumn = vec3(0.9, 0.49, 0.12);
uniform float autumn_mix = 0.0;
uniform float leaf_cover = 1.0;
uniform float snow = 0.0;
varying vec3 world;
varying float up;
void vertex() {
	float sway = sin(TIME * 1.3 + VERTEX.y * 0.7 + MODEL_MATRIX[3].x) * VERTEX.y * (foliage ? 0.035 : 0.009);
	VERTEX.xz += sway * wind;
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	up = NORMAL.y;
}
void fragment() {
	vec4 tex = foliage ? texture(leaves, UV) : texture(bark, UV);
	ALBEDO = tex.rgb;
	ROUGHNESS = 0.95;
	if (foliage) {
		float lightness = dot(tex.rgb, vec3(0.3, 0.59, 0.11));
		ALBEDO = mix(tex.rgb, autumn * (0.45 + lightness), autumn_mix);
		vec3 ray = camera_position - person;
		float t = clamp(dot(world - person, ray) / max(dot(ray, ray), 0.001), 0.0, 1.0);
		float occlusion = 1.0 - smoothstep(0.45, 0.9, distance(world, person + t * ray));
		vec2 field_uv = (world.xz + vec2(16.0)) / 32.0;
		float selected = texture(crops, clamp(field_uv, vec2(0.0), vec2(1.0))).b;
		float cover = leaf_cover * mix(1.0, 0.08, max(occlusion, selected));
		float dither = fract(sin(dot(floor(FRAGCOORD.xy), vec2(12.9898, 78.233))) * 43758.5453);
		ALPHA = tex.a * step(dither, cover);
		ALPHA_SCISSOR_THRESHOLD = 0.5;
	}
	ALBEDO = mix(ALBEDO, vec3(0.9, 0.93, 0.94), snow * max(up, 0.0) * 0.75);
}
