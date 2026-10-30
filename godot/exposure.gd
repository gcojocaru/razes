extends RefCounted
## Game-tuned thermals, not a medical model. Human freezes rates per game minute
## and clips at state boundaries, so render frame size cannot change the outcome.
var wetness := 0.0
var core := 37.0
var health := 100.0
const EPS := 0.00000001

func copy_state() -> RefCounted:
	var copy = get_script().new()
	copy.wetness = wetness
	copy.core = core
	copy.health = health
	return copy

func extra_energy(basal: float) -> float:
	return basal * clampf((36.5 - core) * 0.6, 0.0, 2.0)

func comfortable() -> bool:
	return core >= 36.0 and core <= 38.0

func recovered() -> bool:
	return wetness <= 0.1 + EPS and core >= 36.5 - EPS and core <= 37.5 + EPS

func warning() -> String:
	if core < 35.0: return "Hypothermia: return to warmth"
	if core > 39.0: return "Overheating: rest in shade, turn heating off"
	if core < 36.0: return "Cold: seek shelter and warmth"
	if core > 38.0: return "Hot: stop heavy work and cool down"
	return "Wet: dry at camp" if wetness > 0.5 else "Comfortable"

func rates(climate: Dictionary, effort: float, mass: float, basal: float, sheltered: bool, fire: bool) -> Dictionary:
	var air: float = climate.temperature
	var wind: float = climate.wind
	var solar: float = climate.sunlight
	var wetting: float = 0.0 if sheltered else {"Rain":0.45, "Storm":0.8, "Snow":0.15}.get(climate.condition, 0.0)
	wetting += maxf(0.0, air - 22.0) * maxf(0.0, effort - 2.0) * 0.006
	var drying := 0.12 + maxf(0.0, air) * 0.006 + wind * 0.025 + (1.3 if fire else 0.0)
	var cold := maxf(0.0, 12.0 - air) * 0.16 * (1.0 + minf(wind, 10.0) * 0.06) * (0.65 if sheltered else 1.0)
	if fire: cold *= 0.08
	var work_warmth := minf(1.4, maxf(0.0, effort - 1.4) * 0.25) * minf(cold, 1.0)
	var shiver_warmth := extra_energy(basal) / maxf(basal, 1.0) * 0.35 * minf(cold, 1.0)
	var hot := maxf(0.0, air - 26.0) * (0.04 if sheltered else 0.12)
	hot += (0.0 if sheltered else solar * 0.6) + maxf(0.0, air - 20.0) * maxf(0.0, effort - 1.4) * 0.025
	var wet_cooling := wetness * (maxf(0.0, 12.0 - air) * 0.07 + maxf(0.0, air - 22.0) * 0.025)
	var target := 37.0 - cold + work_warmth + shiver_warmth + hot - wet_cooling
	# Litres of sweat an hour: effort above idle, and far more in heat (Sawka et al. 2007).
	var sweat := 0.08 * maxf(0.0, effort - 1.4) + maxf(0.0, air - 18.0) * 0.015 * (0.5 + maxf(0.0, effort - 1.4))
	return {"wet":wetting * (1.0 - wetness) - drying * wetness, "temperature":(target - core) / clampf(1.2 * mass / 65.0, 0.8, 1.8), "sweat":sweat * (0.6 if sheltered else 1.0)}

func _health_delta(hours: float, temperature_rate: float, resting: bool) -> float:
	var end := core + temperature_rate * hours
	var cold := (maxf(0.0, 35.0 - core) + maxf(0.0, 35.0 - end)) * 0.5
	var hot := (maxf(0.0, core - 39.0) + maxf(0.0, end - 39.0)) * 0.5
	if cold + hot > 0.0: return -4.0 * (cold + hot) * hours
	return 2.0 * hours if resting and minf(core, end) >= 36.0 - EPS and maxf(core, end) <= 38.0 + EPS else 0.0

## Returns only the time survived, including a fractional final minute.
func advance(hours: float, rate: Dictionary, resting: bool) -> float:
	var used := hours
	for boundary in [35.0, 36.0, 36.5, 37.5, 38.0, 39.0]:
		if absf(rate.temperature) > EPS:
			var crossing: float = (boundary - core) / rate.temperature
			if crossing > EPS: used = minf(used, crossing)
	for boundary in [0.0, 0.1, 1.0]:
		if absf(rate.wet) > EPS:
			var crossing: float = (boundary - wetness) / rate.wet
			if crossing > EPS: used = minf(used, crossing)
	if health + _health_delta(used, rate.temperature, resting) <= 0.0:
		var low := 0.0
		var high := used
		for iteration in 40:
			var middle := (low + high) * 0.5
			if health + _health_delta(middle, rate.temperature, resting) > 0.0: low = middle
			else: high = middle
		used = high
	var change := _health_delta(used, rate.temperature, resting)
	core += rate.temperature * used
	wetness = clampf(wetness + rate.wet * used, 0.0, 1.0)
	health = clampf(health + change, 0.0, 100.0)
	if health < EPS: health = 0.0
	return used
