extends Node3D
## Weather you can see: rain and snow particles, storm lightning, fog, and
## sky, sunlight and wet-ground changes that blend in when the weather turns.

const BLEND_SECONDS := 2.0
## Per condition: sky, sun energy, sun colour, fog density, ambient energy, field wetness.
const LOOKS := {
	"Clear": [Color(0.55, 0.68, 0.78), 1.0, Color(1, 0.96, 0.88), 0.0, 0.6, 0.0],
	"Cloudy": [Color(0.6, 0.64, 0.68), 0.55, Color(0.9, 0.92, 0.95), 0.006, 0.7, 0.0],
	"Rain": [Color(0.45, 0.5, 0.55), 0.35, Color(0.8, 0.85, 0.9), 0.014, 0.6, 1.0],
	"Storm": [Color(0.27, 0.3, 0.35), 0.2, Color(0.7, 0.75, 0.85), 0.022, 0.45, 1.0],
	"Snow": [Color(0.78, 0.8, 0.84), 0.45, Color(0.9, 0.95, 1), 0.018, 0.8, 0.0],
}

var condition := ""
## 0–1 darkening of the field after rain.
var wet := 0.0:
	set(value):
		wet = value
		_field.set_shader_parameter("wet", value)
var rain := GPUParticles3D.new()
var snow := GPUParticles3D.new()

var _sun: DirectionalLight3D
var _environment: Environment
var _field: ShaderMaterial
var _tween: Tween
var _next_flash := 0.0

func _init(sun: DirectionalLight3D, environment: Environment, field: ShaderMaterial) -> void:
	name = "WeatherEffects"
	_sun = sun
	_environment = environment
	_field = field
	_environment.fog_enabled = true

	var rain_motion := ParticleProcessMaterial.new()
	rain_motion.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rain_motion.emission_box_extents = Vector3(24, 1, 24)
	rain_motion.direction = Vector3(0.12, -1, 0.05)
	rain_motion.spread = 2.0
	rain_motion.initial_velocity_min = 26.0
	rain_motion.initial_velocity_max = 32.0
	rain_motion.particle_flag_align_y = true
	# Emitters sit below the default camera height so drops never sweep across the lens.
	_setup(rain, "Rain", rain_motion, Vector2(0.035, 0.9), Color(0.78, 0.86, 1, 0.45), 6000, 0.6, 13)
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
	_setup(snow, "Snow", snow_motion, Vector2(0.13, 0.13), Color(1, 1, 1, 0.9), 3000, 8.0, 12)
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
	var seconds := 0.0 if instant else BLEND_SECONDS
	_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE)
	_tween.tween_property(_environment, "background_color", look[0], seconds)
	_tween.tween_property(_environment, "fog_light_color", look[0], seconds)
	_tween.tween_property(_sun, "light_energy", look[1], seconds)
	_tween.tween_property(_sun, "light_color", look[2], seconds)
	_tween.tween_property(_environment, "fog_density", look[3], seconds)
	_tween.tween_property(_environment, "ambient_light_energy", look[4], seconds)
	_tween.tween_property(self, "wet", look[5], seconds * 2)

func _set_emitting(particles: GPUParticles3D, on: bool) -> void:
	if on and not particles.emitting:
		particles.restart()
	particles.emitting = on

func _process(delta: float) -> void:
	if condition != "Storm":
		return
	_next_flash -= delta
	if _next_flash <= 0.0:
		_next_flash = randf_range(2.5, 8.0)
		flash()

## A lightning strike: two quick bright pulses on the sun and sky.
func flash() -> void:
	var look: Array = LOOKS[condition]
	if _tween:
		_tween.kill()
	_tween = create_tween()
	for pulse in [[4.0, 0.06], [look[1], 0.08], [2.5, 0.05], [look[1], 0.4]]:
		var sky: Color = Color(0.75, 0.78, 0.9) if pulse[0] > 1.0 else look[0]
		_tween.tween_property(_sun, "light_energy", pulse[0], pulse[1])
		_tween.parallel().tween_property(_environment, "background_color", sky, pulse[1])
		_tween.parallel().tween_property(_environment, "ambient_light_energy", 1.6 if pulse[0] > 1.0 else look[4], pulse[1])
