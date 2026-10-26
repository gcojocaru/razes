class_name Weather
extends RefCounted
## Daily weather from the time of year plus smooth seeded noise, so warm, cold,
## wet and dry spells last several days. The same seed and day always give the
## same weather. Tuned to modern Moldovan (Chișinău) climate normals: daily
## mean near -1.5°C in January and 22.5°C in July, summer thunderstorms, a
## cloudy winter with snow and thaws. Not a reconstruction of medieval weather.

const CONDITIONS := ["Clear", "Cloudy", "Rain", "Storm", "Snow"]
const MEAN_TEMPERATURE := 10.5
const SEASONAL_SWING := 12.0
## Day-to-day spread per season; winter cold snaps and thaws swing furthest.
const RANDOM_SWING := [8.0, 6.0, 8.0, 11.0]
## Per season: wetness above WET_THRESHOLD brings rain or snow (higher is drier);
## within CLOUD_MARGIN below it the day is cloudy. Summer has the most rain,
## winter the most overcast days.
const WET_THRESHOLD := [0.2, 0.15, 0.25, 0.15]
const CLOUD_MARGIN := [0.3, 0.2, 0.35, 0.4]
const STORM_MARGIN := 0.12

var _noise := FastNoiseLite.new()

func _init(seed: int) -> void:
	_noise.seed = seed
	_noise.frequency = 0.2

## Returns {"temperature": int °C, "condition": one of CONDITIONS}.
func on(day: int) -> Dictionary:
	var season: int = Calendar.date(day).season
	# Coldest in mid-winter, warmest in mid-summer.
	var phase := TAU * (day - Calendar.DAYS_PER_SEASON / 2.0) / Calendar.DAYS_PER_YEAR
	var temperature: float = MEAN_TEMPERATURE + SEASONAL_SWING * sin(phase) + RANDOM_SWING[season] * _noise.get_noise_2d(day, 0)
	var wetness := _noise.get_noise_2d(day, 500)
	var wet: float = WET_THRESHOLD[season]
	var condition := "Clear"
	if wetness > wet:
		if temperature <= 1.0:
			condition = "Snow"
		elif temperature >= 16.0 and wetness > wet + STORM_MARGIN:
			condition = "Storm"
		else:
			condition = "Rain"
	elif wetness > wet - CLOUD_MARGIN[season]:
		condition = "Cloudy"
	return {"temperature": roundi(temperature), "condition": condition}

## Hourly exposure weather; daily crop means remain the on(day) contract.
func at(day: int, hour: float) -> Dictionary:
	var sample_day := day + floori(hour / 24.0)
	var clock := fposmod(hour, 24.0)
	var daily := on(sample_day)
	var winds := {"Clear":2.0, "Cloudy":3.0, "Rain":4.0, "Storm":8.0, "Snow":4.0}
	var sunlight: float = maxf(0.0, Calendar.sun(sample_day, clock).y) * {"Clear":1.0, "Cloudy":0.35, "Rain":0.15, "Storm":0.1, "Snow":0.2}[daily.condition]
	return {"temperature":daily.temperature + 4.0 * sin(TAU * (clock - 9.0) / 24.0), "condition":daily.condition, "wind":winds[daily.condition], "sunlight":sunlight}
