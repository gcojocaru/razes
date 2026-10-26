extends SceneTree
class ControlledWeather extends Weather:
	var temperature := 15.0
	var condition := "Clear"
	var wind := 2.0
	var sunlight := 0.0
	var midnight_cold := false
	func _init(t := 15.0, c := "Clear", w := 2.0, sun := 0.0) -> void:
		super(1)
		temperature = t; condition = c; wind = w; sunlight = sun
	func at(day: int, _hour: float) -> Dictionary:
		return {"temperature": -10.0 if midnight_cold and day > 0 else temperature, "condition":condition, "wind":wind, "sunlight":sunlight}
var failures: Array[String] = []
func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
func person_at(home: bool, climate: Weather) -> Human:
	var person := Human.new()
	person.home = Vector2.ZERO
	person.position = Vector2.ZERO if home else Vector2(20,0)
	person.weather = climate
	return person
func _initialize() -> void:
	if not Weather.new(1).has_method("at"):
		check(false, "Exposure has deterministic hourly weather independent of audio")
		quit(1)
		return
	var weather := Weather.new(42)
	var noon: Dictionary = weather.at(0,15)
	check(noon == Weather.new(42).at(0,15) and noon.temperature > weather.at(0,3).temperature and weather.on(0).temperature != noon.temperature, "Hourly seeded weather follows time without changing daily crop means")
	var farm := Farm.new()
	var person := person_at(false, ControlledWeather.new())
	person.advance(farm,0,6,8)
	check(absf(person.exposure.core - 37) < 0.1 and person.exposure.health == 100, "Mild dry weather is safe")
	person = person_at(false, ControlledWeather.new(3,"Storm",6))
	person.advance(Farm.new(),0,6,6)
	check(person.exposure.wetness > 0.5 and person.exposure.core < 35 and person.exposure.health < 100, "Prolonged wet cold soaks, cools and harms the farmer")
	check(person.burn("Idle") > person.basal() * 1.4, "Shivering burns extra body energy")
	farm = Farm.new(); farm.shelter = true
	person = person_at(true, ControlledWeather.new(-10,"Snow",6))
	person.exposure.core = 35.2; person.exposure.wetness = 1.0; person.fatigue = 100
	person.sleep(8)
	person.advance(farm,0,22,8)
	check(person.exposure.health == 100 and person.exposure.core > 36.5 and person.exposure.wetness < 0.1 and farm.wood == 44000, "Heated winter shelter dries and warms a sleeper with exact fuel")
	farm = Farm.new(); farm.heating_enabled = false
	person = person_at(false, ControlledWeather.new(-10,"Snow",6))
	person.advance(farm,0,22,8)
	check(person.health < 100, "Winter outdoors without heat causes exposure damage")
	farm = Farm.new()
	var cell := Vector2i(8,8)
	farm.woodland[cell] = 6.0
	person = person_at(false, ControlledWeather.new(35,"Clear",2,1))
	person.position = Human.plot_centre(cell)
	person.order(farm,[cell],0,"Chop")
	person.advance(farm,0,11,4)
	check(person.exposure.core > 39 and person.exposure.health < 100, "Sustained hot heavy work causes overheating")
	farm.shelter = true; farm.heating_enabled = false
	person.recover()
	for i in 400:
		person.advance(farm,0,15+i*0.025,0.025)
		if not person.recovering: break
	check(not person.recovering and person.exposure.core < 37.5 and not person.job.is_empty(), "Shaded recovery returns home and resumes preserved work")
	var climate := ControlledWeather.new(15,"Rain",3)
	climate.midnight_cold = true
	farm = Farm.new(); farm.shelter = true; farm.wood = 1000
	person = person_at(true,climate)
	person.fatigue = 80; person.exposure.wetness = 0.4
	var preview: Dictionary = person.sleep_prediction(8,farm,0,22)
	check(farm.wood == 1000 and person.exposure.wetness == 0.4 and person.sleep_remaining == 0, "Sleep forecast mutates neither fuel nor exposure nor orders")
	person.sleep(8);person.advance(farm,0,22,8)
	check(absf(person.exposure.core-preview.core)<0.001 and absf(person.exposure.health-preview.exposure_health)<0.001 and farm.wood==preview.wood and absf(person.fatigue-preview.fatigue)<0.001, "Sleep forecast follows midnight weather and fuel exhaustion exactly")
	var one := person_at(false,ControlledWeather.new(3,"Storm",6))
	var frames := person_at(false,ControlledWeather.new(3,"Storm",6))
	one.advance(Farm.new(),0,6,4)
	var frame_farm := Farm.new()
	for i in 173: frames.advance(frame_farm,0,6+i*4.0/173,4.0/173)
	check(absf(one.exposure.core-frames.exposure.core)<0.001 and absf(one.exposure.health-frames.exposure.health)<0.001 and absf(one.exposure.wetness-frames.exposure.wetness)<0.001, "Thermal state is independent of irregular rendering frame subdivisions")
	person = person_at(false,ControlledWeather.new(-15,"Snow",8))
	person.exposure.core = 32; person.exposure.health = 0.1
	person.advance(Farm.new(),0,6,10)
	check(person.activity=="Dead" and person.advanced_hours<1, "Exposure death stops a long skip at the fatal instant")
	person = person_at(true, ControlledWeather.new(-15,"Snow",8))
	person.exposure.core=32;person.exposure.health=0.1
	farm=Farm.new();farm.heating_enabled=false
	person.advance(farm,0,6,1)
	var wood_before: int=farm.wood
	farm.heating_enabled=true
	person.advance(farm,0,7,4)
	check(not farm.fire_lit and farm.wood==wood_before, "Dead farmers cannot relight or consume camp fuel")
	if failures.is_empty(): print("PASS: hourly weather, wet/cold/heat, shelter, fuel, recovery, forecasts, subdivision and exposure death")
	quit(0 if failures.is_empty() else 1)
