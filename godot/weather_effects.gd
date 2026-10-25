extends Node3D
## Weather and daylight you can see: rain and snow particles, storm lightning, fog,
## and sky, sunlight and wet-ground changes that blend in when the weather turns.
## The sun crosses the sky, dawn and dusk tint it, and the moon and the camp fire
## light the night.

signal lightning

const BLEND_SECONDS := 2.0
## Per condition: sky, sun energy, sun colour, fog density, ambient energy, field wetness.
const LOOKS := {
	"Clear": [Color(0.55, 0.68, 0.78), 1.0, Color(1, 0.96, 0.88), 0.0, 0.6, 0.0],
	"Cloudy": [Color(0.6, 0.64, 0.68), 0.55, Color(0.9, 0.92, 0.95), 0.006, 0.7, 0.0],
	"Rain": [Color(0.45, 0.5, 0.55), 0.35, Color(0.8, 0.85, 0.9), 0.014, 0.6, 1.0],
	"Storm": [Color(0.27, 0.3, 0.35), 0.2, Color(0.7, 0.75, 0.85), 0.022, 0.45, 1.0],
	"Snow": [Color(0.78, 0.8, 0.84), 0.45, Color(0.9, 0.95, 1), 0.018, 0.8, 0.0],
}
const DAY_AMBIENT := Color(0.75, 0.78, 0.8)
const NIGHT_AMBIENT := Color(0.36, 0.44, 0.68)
const LOW_SUN := Color(1.0, 0.62, 0.36)
## The moon stands opposite the sun, as when full, with a fraction of its light.
const MOON := Color(0.66, 0.74, 0.95)
const MOON_ENERGY := 0.3
const FLASH_SKY := Color(0.75, 0.78, 0.9)
const RAIN_COLOR := Color(0.78, 0.86, 1, 0.45)
const SNOW_COLOR := Color(1, 1, 1, 0.9)

var condition := ""
## 0–1 darkening of the field after rain.
var wet := 0.0:
	set(value):
		wet = value
		_field.set_shader_parameter("wet", value)
var rain := GPUParticles3D.new()
var snow := GPUParticles3D.new()

## The weather's sky, sunlight and ambient light, before the time of day tints them.
var _sky := Color.BLACK
var _sun_energy := 0.0
var _sun_color := Color.WHITE
var _ambient := 0.0
## 0–1 brightness of a lightning strike.
var _flash := 0.0
var _day := 0
var _hour := 0.0
## Sky colour multiplier as the sun rises from 15° below the horizon to 12° above:
## night, blue hour, twilight, sunrise, morning, day.
var _dusk := Gradient.new()
var _sun: DirectionalLight3D
var _environment: Environment
var _field: ShaderMaterial
var _fire: OmniLight3D
var _tween: Tween
var _next_flash := 0.0

func _init(sun: DirectionalLight3D, environment: Environment, field: ShaderMaterial, fire: OmniLight3D) -> void:
	name = "WeatherEffects"
	_sun = sun
	_environment = environment
	_field = field
	_fire = fire
	_environment.fog_enabled = true
	_dusk.offsets = PackedFloat32Array([0.0, 0.26, 0.44, 0.59, 0.78, 1.0])
	_dusk.colors = PackedColorArray([Color(0.08, 0.1, 0.2), Color(0.25, 0.27, 0.55), Color(0.75, 0.55, 0.8), Color(1.7, 0.95, 0.55), Color(1.5, 1.08, 0.72), Color.WHITE])

	var rain_motion := ParticleProcessMaterial.new()
	rain_motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rain_motion.emission_box_extents = Vector3(24, 1, 24)
	rain_motion.direction = Vector3(0.12, -1, 0.05)
	rain_motion.spread = 2.0
	rain_motion.initial_velocity_min = 26.0
	rain_motion.initial_velocity_max = 32.0
	rain_motion.particle_flag_align_y = true
	# Emitters sit below the default camera height so drops never sweep across the lens.
	_setup(rain, "Rain", rain_motion, Vector2(0.035, 0.9), RAIN_COLOR, 6000, 0.6, 13)
	rain.draw_pass_1.surface_get_material(0).billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y

	var snow_motion := ParticleProcessMaterial.new()
	snow_motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	snow_motion.emission_box_extents = Vector3(24, 1, 24)
	snow_motion.direction = Vector3(0.2, -1, 0)
	snow_motion.spread = 25.0
	snow_motion.initial_velocity_min = 1.5
	snow_motion.initial_velocity_max = 2.5
	snow_motion.gravity = Vector3(0, -0.4, 0)
	snow_motion.turbulence_enabled = true
	snow_motion.turbulence_noise_strength = 0.6
	snow_motion.scale_min = 0.6
	snow_motion.scale_max = 1.4
	_setup(snow, "Snow", snow_motion, Vector2(0.13, 0.13), SNOW_COLOR, 3000, 8.0, 12)
	# Small spheres read as round flakes from every angle.
	var flake := SphereMesh.new()
	flake.radius = 0.06
	flake.height = 0.12
	flake.radial_segments = 6
	flake.rings = 3
	flake.material = snow.draw_pass_1.material
	snow.draw_pass_1 = flake

func _setup(particles: GPUParticles3D, label: String, motion: ParticleProcessMaterial, size: Vector2, color: Color, amount: int, lifetime: float, height: float) -> void:
	particles.name = label
	particles.process_material = motion
	particles.amount = amount
	particles.lifetime = lifetime
	# Fill the sky at once instead of waiting for the first particles to fall.
	particles.preprocess = lifetime
	particles.position.y = height
	particles.visibility_aabb = AABB(Vector3(-30, -height - 2, -30), Vector3(60, height + 6, 60))
	particles.emitting = false
	var mesh := QuadMesh.new()
	mesh.size = size
	var look := StandardMaterial3D.new()
	look.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	look.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	look.albedo_color = color
	mesh.material = look
	particles.draw_pass_1 = mesh
	add_child(particles)

## Switches particles on or off and blends the sky and light toward the new weather.
func show_weather(new_condition: String, instant := false) -> void:
	if new_condition == condition:
		return
	condition = new_condition
	_set_emitting(rain, condition in ["Rain", "Storm"])
	rain.amount_ratio = 1.0 if condition == "Storm" else 0.45
	_set_emitting(snow, condition == "Snow")
	# First strike after the blend, so it never cuts the blend short; wet ground blends twice as long.
	_next_flash = randf_range(BLEND_SECONDS * 2 + 1.0, BLEND_SECONDS * 2 + 4.0)

	var look: Array = LOOKS[condition]
	if _tween:
		_tween.kill()
	_flash = 0.0
	var seconds := 0.0 if instant else BLEND_SECONDS
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "_sky", look[0], seconds)
	_tween.tween_property(self, "_sun_energy", look[1], seconds)
	_tween.tween_property(self, "_sun_color", look[2], seconds)
	_tween.tween_property(_environment, "fog_density", look[3], seconds)
	_tween.tween_property(self, "_ambient", look[4], seconds)
	_tween.tween_property(self, "wet", look[5], seconds * 2)

## Moves the sun and moon to `hour` of `day` and relights the scene.
func show_time(day: int, hour: float) -> void:
	_day = day
	_hour = hour
	_light()

## Lights the scene for the weather and the time of day.
func _light() -> void:
	var to_sun := Calendar.sun(_day, _hour)
	var elevation := rad_to_deg(asin(to_sun.y))
	# 0 in daylight and early twilight, 1 once the sun is 14° down.
	var dark := 1.0 - smoothstep(-14.0, 0.0, elevation)
	var sky := _sky * _dusk.sample(inverse_lerp(-15.0, 12.0, elevation))
	_environment.background_color = sky.lerp(FLASH_SKY, _flash)
	_environment.fog_light_color = _environment.background_color
	_environment.ambient_light_color = DAY_AMBIENT.lerp(NIGHT_AMBIENT, dark)
	_environment.ambient_light_energy = lerpf(_ambient * (1.0 - 0.5 * dark), 1.6, _flash)
	# One light serves as sun and moon, kept 11° up so shadows stay on the field.
	var light := to_sun if elevation >= 0.0 else -to_sun
	_sun.basis = Basis.looking_at(-Vector3(light.x, maxf(light.y, 0.2), light.z))
	var color := _sun_color.lerp(LOW_SUN, 1.0 - smoothstep(2.0, 20.0, elevation)) if elevation >= 0.0 else MOON
	_sun.light_color = color.lerp(Color.WHITE, _flash)
	var energy := _sun_energy * (smoothstep(-1.0, 10.0, elevation) + MOON_ENERGY * smoothstep(-1.0, 10.0, -elevation))
	_sun.light_energy = lerpf(energy, 4.0, _flash)
	var t := Time.get_ticks_msec() / 1000.0
	_fire.light_energy = lerpf(0.3, 2.5, dark) * (1.0 + 0.1 * sin(t * 8.0) + 0.07 * sin(t * 19.0 + 1.7))
	# Unshaded rain and snow would glow in the dark; lightning shows them again.
	var dim := 0.7 * dark * (1.0 - _flash)
	rain.draw_pass_1.material.albedo_color = RAIN_COLOR.darkened(dim)
	snow.draw_pass_1.material.albedo_color = SNOW_COLOR.darkened(dim * 0.8)

func _set_emitting(particles: GPUParticles3D, on: bool) -> void:
	if on and not particles.emitting:
		particles.restart()
	particles.emitting = on

func _process(delta: float) -> void:
	_light()
	if condition != "Storm":
		return
	_next_flash -= delta
	if _next_flash <= 0.0:
		_next_flash = randf_range(2.5, 8.0)
		flash()

## A lightning strike: two quick bright pulses on the sun and sky.
func flash() -> void:
	lightning.emit()
	if _tween:
		_tween.kill()
	_tween = create_tween()
	for pulse in [[1.0, 0.06], [0.0, 0.08], [0.6, 0.05], [0.0, 0.4]]:
		_tween.tween_property(self, "_flash", pulse[0], pulse[1])

## Shared wind drives precipitation and the crop shader.
func set_wind(direction: Vector2, strength: float) -> void:
	var drift := direction * strength
	rain.process_material.direction = Vector3(drift.x * 0.5, -1, drift.y * 0.5)
	snow.process_material.direction = Vector3(drift.x, -1, drift.y)
	snow.process_material.gravity = Vector3(drift.x * 0.8, -0.4, drift.y * 0.8)
