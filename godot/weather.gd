class_name Weather
extends RefCounted
## Daily weather from the time of year plus smooth seeded noise, so warm, cold,
## wet and dry spells last several days. The same seed and day always give the
## same weather. Tuned to feel like a continental climate, not historical data.

const CONDITIONS := ["Clear", "Cloudy", "Rain", "Storm", "Snow"]
const MEAN_TEMPERATURE := 9.0
const SEASONAL_SWING := 13.0
const RANDOM_SWING := 10.0
## Wetness above this brings rain or snow, per season; higher is drier.
const WET_THRESHOLD := [0.15, 0.25, 0.2, 0.15]
const CLOUD_MARGIN := 0.25
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
	var temperature := MEAN_TEMPERATURE + SEASONAL_SWING * sin(phase) + RANDOM_SWING * _noise.get_noise_2d(day, 0)
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
	elif wetness > wet - CLOUD_MARGIN:
		condition = "Cloudy"
	return {"temperature": roundi(temperature), "condition": condition}
