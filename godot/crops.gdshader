shader_type spatial;
render_mode cull_disabled;

// Crop stalks: one MultiMesh instance per stalk on every plot. Each stalk reads
// its plot from the crop texture and takes that stage's height and colour.
uniform float grid_size = 16.0;
uniform float cell_size = 2.0;
uniform vec2 hovered = vec2(-1.0);
uniform float snow = 0.0;
// Same per-cell texture as the field shader: R (stage index + 8 × crop number) / 255, G growth, B selected.
uniform sampler2D crops : filter_nearest;

// Per crop number (0 none, then Farm.CROPS order): ripe height in world units and
// ripe colour, set from Farm.CROPS by the game. One entry per crop plus none.
uniform float tall[6];
uniform vec3 ripe[6];

varying vec3 tint;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec2 cell = floor(origin.xz / cell_size + grid_size / 2.0);
	vec4 crop = texelFetch(crops, ivec2(cell), 0);
	int packed = int(round(crop.r * 255.0));
	int stage = packed % 8;
	int kind = min(packed / 8, 5);
	float r = fract(sin(dot(origin.xz, vec2(12.9898, 78.233))) * 43758.5453);

	// Grass and plowed land keep height 0, which collapses the stalk away.
	float height = 0.0;
	tint = vec3(0.0);
	if (stage == 2) { // sown: green, yellowing as it nears ripe
		height = mix(0.08, tall[kind], crop.g);
		tint = mix(vec3(0.3, 0.58, 0.15), mix(vec3(0.5, 0.6, 0.2), ripe[kind], 0.35), crop.g * crop.g);
	} else if (stage == 3) { // ripe
		height = tall[kind];
		tint = ripe[kind];
	} else if (stage == 4) { // stubble
		height = 0.1;
		tint = mix(ripe[kind], vec3(0.8, 0.7, 0.46), 0.5);
	} else if (stage == 5) { // withered
		height = 0.45 * tall[kind];
		tint = vec3(0.56, 0.52, 0.44);
	}
	height *= 0.8 + 0.4 * r;
	// Short crops spread less, so sprouts and stubble stay upright.
	float spread = step(0.001, height) * min(1.0, 0.3 + height);
	VERTEX *= vec3(spread, height, spread);
	// Withered crops slump; the rest sway together in the wind.
	float lean = stage == 5 ? 0.35 : 0.07 * sin(TIME * 1.6 + origin.x * 0.6 + origin.z * 0.4);
	VERTEX += transpose(mat3(MODEL_MATRIX)) * vec3(lean * UV.y * height, 0.0, 0.0);

	tint *= 0.8 + 0.4 * r;
	if (crop.b > 0.5) tint = mix(tint, vec3(0.98, 0.72, 0.25), 0.5);
	if (cell == hovered) tint = mix(tint, vec3(1.0, 0.92, 0.6), 0.35);
	tint = mix(tint, vec3(0.9, 0.93, 0.97), snow * UV.y);
}

void fragment() {
	// Darker at the base, where stalks shade each other.
	ALBEDO = tint * mix(0.45, 1.0, UV.y);
	ROUGHNESS = 0.85;
}
