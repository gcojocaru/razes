extends Node
## Long, offset rain beds and softly changing wind; all timing is real time.
const TRACKS := ["wind.wav", "winter-wind.wav", "rain-soft.ogg", "rain-heavy.ogg", "rain-drops.ogg"]
const MIX := {
	"Clear": [0.16, 0.0, 0.0, 0.0, 0.0],
	"Cloudy": [0.25, 0.0, 0.0, 0.0, 0.0],
	"Rain": [0.22, 0.0, 0.55, 0.12, 0.18],
	"Storm": [0.48, 0.0, 0.28, 0.65, 0.28],
	"Snow": [0.08, 0.28, 0.0, 0.0, 0.0],
}
var condition := "Clear"
var layers: Array[AudioStreamPlayer] = []
var thunder := AudioStreamPlayer.new()
var pending_thunder := -1.0
var wind_strength := 0.2
var wind_direction := Vector2(1, 0.3).normalized()
var _time := 0.0
var _phase := randf() * TAU
var _mix: Array = MIX.Clear.duplicate()

func _ready() -> void:
	for track in TRACKS:
		var player := AudioStreamPlayer.new()
		var stream: AudioStream = load("res://assets/audio/weather/" + track).duplicate()
		if stream is AudioStreamOggVorbis:
			stream.loop = true
		elif stream is AudioStreamWAV:
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
		player.stream = stream
		player.bus = "Weather"
		player.volume_db = -80
		add_child(player)
		player.play(randf() * stream.get_length())
		layers.append(player)
	thunder.stream = preload("res://assets/audio/weather/thunder.ogg")
	thunder.bus = "Weather"
	thunder.max_polyphony = 2
	add_child(thunder)

func show_weather(value: String, instant := false) -> void:
	if not MIX.has(value):
		return
	condition = value
	if instant:
		_mix = MIX[value].duplicate()
	if value != "Storm":
		pending_thunder = -1.0
		thunder.stop()

func lightning() -> void:
	if condition == "Storm" and pending_thunder < 0:
		pending_thunder = randf_range(0.8, 2.3)

func _process(delta: float) -> void:
	_time += delta
	var gust := 0.5 + 0.3 * sin(_time * 0.31 + _phase) + 0.2 * sin(_time * 0.73 + _phase * 2)
	var target_wind := (0.15 + gust * 0.25) * (2.0 if condition == "Storm" else 1.0)
	wind_strength = lerpf(wind_strength, target_wind, 1.0 - exp(-delta))
	wind_direction = Vector2.from_angle(0.3 + sin(_time * 0.07 + _phase) * 0.6)
	for i in layers.size():
		_mix[i] = lerpf(_mix[i], MIX[condition][i], 1.0 - exp(-delta / 1.2))
		var variation := 0.8 + 0.2 * sin(_time * (0.17 + i * 0.037) + _phase + i)
		if i < 2:
			variation *= 0.65 + gust * 0.6
		layers[i].volume_db = linear_to_db(maxf(_mix[i] * variation * 0.6, 0.0001))
	if pending_thunder >= 0:
		pending_thunder -= delta
		if pending_thunder < 0 and condition == "Storm":
			thunder.pitch_scale = randf_range(0.8, 1.1)
			thunder.volume_db = randf_range(-16, -10)
			thunder.play()

func _exit_tree() -> void:
	for player in layers:
		player.stop()
	thunder.stop()
