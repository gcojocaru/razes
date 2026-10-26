class_name Human
extends RefCounted
const Exposure := preload("res://exposure.gd")
## One farmer; positions are metres and all carried/reserved mass is integer grams.
## Needs follow from a simulated body: lean mass sets basal metabolism, each activity
## burns a multiple of it, meals digest into glycogen, and fat and lean tissue store
## any surplus and pay any deficit. Health follows body mass; tiredness slows work.

const WALK_SPEED := 4500.0
const WORK_HOURS := {"Plow": 3.0, "Sow": 0.5, "Harvest": 2.0, "Chop": 6.0, "Haul wood": 0.01}
const BAG_CAPACITY := 15000
const MEAL_GRAMS := 300
const MEAL_HOURS := 0.5
const BUILD_HOURS := 8.0
const MAX_SLEEP_HOURS := 24.0
const EPSILON := 0.00000001

## The default peasant: a lean adult, 1.718 m like the 3D farmer's mesh, of 65 kg with
## 15% body fat (BMI 22). The creation screen can choose another body; see create().
const HEIGHT := 1.718
const START_FAT := 9.75
const START_LEAN := 55.25
## Energy use as multiples of basal metabolism: FAO 2004 physical activity ratios,
## and about 5 METs for hoeing (Compendium of Physical Activities).
const EFFORT := {"Sleeping": 1.0, "Idle": 1.4, "Cooking": 2.1, "Walking": 3.2, "Sow": 4.1, "Harvest": 4.1, "Plow": 5.0, "Chop": 5.5, "Haul wood": 2.1, "Build": 4.1, "Recovering": 1.4}
## kcal in a kilogram of fat and of lean tissue, which is mostly water. By Forbes' rule
## each kilogram of fat lost takes FORBES / fat kilograms of lean with it (Hall 2008).
const FAT_KCAL := 9400.0
const LEAN_KCAL := 1800.0
const FORBES := 10.4
## Storing a surplus wastes a third of it, and two thirds of the gain is fat, so
## 84,000 kcal of overeating adds about 8 kg, as in Bouchard et al. 1990.
const STORE_EFFICIENCY := 2.0 / 3.0
const GAIN_FAT_SHARE := 2.0 / 3.0
## Glycogen, the ready energy: about 9 g per kilogram of lean mass at 4 kcal a gram.
const GLYCOGEN_PER_LEAN := 36.0
## The stomach holds about 1.5 litres: 375 g of grain cooked as porridge at 4 ml a gram.
const STOMACH_GRAMS := 375
## The gut absorbs at most about 2.5 times basal metabolism, the alimentary limit of
## Thurber et al. 2019; harder work than that runs down the body's stores.
const ALIMENTARY_LIMIT := 2.5
## Health is full down to a BMI of 18.5 and gone at 12.5, which total starvation
## reaches in about two months, as in the 1981 hunger strike (60–66 days).
const HEALTHY_BMI := 18.5
const DEATH_BMI := 12.5
## Eight hours' sleep a day clears a day's fatigue: 16 idle hours awake build 70 and
## nine hours' hoeing 30 more. From 70 and from 90 work and walking slow down.
const SLEEP_HOURS := 8.0
const AWAKE_TIRING := 70.0 / 16.0
const EFFORT_TIRING := 30.0 / (9.0 * 3.6)
const TIRED_PACE := {70.0: 0.8, 90.0: 0.6}

## The peasant made on the creation screen, if any. Each new game's farmer is made
## from them, so Restart keeps them.
static var peasant := {}

var name := "Ion"
var height := HEIGHT
## Fat and lean mass at the start, for the Body window's change since then.
var start_fat := START_FAT
var start_lean := START_LEAN
var home := Vector2(-85, 0)
var position := home
var facing := Vector2.DOWN
var activity := "Idle"
var job: Dictionary = {}
var queue: Array[Dictionary] = []
var carried_crop := ""
var carried := 0
var fat := START_FAT
var lean := START_LEAN
## kcal of glycogen, full at the start.
var glycogen := START_LEAN * GLYCOGEN_PER_LEAN
## Porridge not yet digested: grams of dry grain and the kcal they still hold.
var stomach := 0.0
var stomach_kcal := 0.0
var fatigue := 0.0
## 100 down to 0 as the body falls from a BMI of 18.5 to 12.5.
var health: float:
	get:
		return 0.0 if activity == "Dead" else minf(exposure.health, clampf(inverse_lerp(DEATH_BMI, HEALTHY_BMI, bmi()), 0.0, 1.0) * 100.0)
var message := "Ready for work"
var sleep_remaining := 0.0
var eating_requested := false
var meal_crop := ""
var meal_grams := 0
var advanced_hours := 0.0
var build_remaining := 0.0
var build_reserved := 0
var meal_fuel := 0
var _farm: Farm
var weather: Weather
var exposure = Exposure.new()
var recovering := false
var _absolute_hour := 0.0
var _thermal_key := []
var _thermal_rate := {"wet":0.0, "temperature":0.0}
## Navigation is in world units; the needs simulation keeps metres.
var terrain: RefCounted
var terrain_scale := 0.2

var _carrying_seed := false
var _returning_home := false
var _cooking_remaining := 0.0
var _farm_changed := false
var _route := PackedVector2Array()
var _route_destination := Vector2(INF, INF)

## Gives the farmer the creation screen's name and a body of `chosen.weight` kg, a
## `chosen.body_fat` share of it fat, with full glycogen.
func create(chosen: Dictionary) -> void:
	name = chosen.name
	height = chosen.height
	start_fat = chosen.weight * chosen.body_fat
	start_lean = chosen.weight - start_fat
	fat = start_fat
	lean = start_lean
	glycogen = lean * GLYCOGEN_PER_LEAN

func order(farm: Farm, cells: Array, day: int, action := "", crop := "") -> int:
	if activity == "Dead" or (action != "" and action not in Farm.ACTIONS):
		return 0
	var added := 0
	for cell in cells:
		if typeof(cell) != TYPE_VECTOR2I or not Rect2i(0, 0, 16, 16).has_point(cell):
			continue
		if queue.size() + int(not job.is_empty()) >= 256:
			break
		if (not job.is_empty() and job.cell == cell) or queue.any(func(waiting: Dictionary) -> bool: return waiting.cell == cell):
			continue
		var next := farm.action(cell, day, crop)
		if next.reason != "" or (action != "" and action != next.name):
			continue
		var destination := plot_centre(cell)
		if not _reachable(home, destination) or not _reachable(position, home):
			message = "No dry route to this plot and camp"
			continue
		var seed: int = Farm.CROPS[crop].seed if next.name == "Sow" else 0
		if seed:
			farm.stock[crop] -= seed
		queue.append({"action": next.name, "cell": cell, "crop": crop if next.name == "Sow" else farm.crop(cell), "remaining": farm.woodland[cell] if next.name == "Chop" else WORK_HOURS[next.name], "seed": seed})
		added += 1
	if added:
		message = "%d job%s queued" % [added, "" if added == 1 else "s"]
	return added

## Where the farmer stands to work a plot, in metres.
static func plot_centre(cell: Vector2i) -> Vector2:
	return (Vector2(cell) - Vector2.ONE * 7.5) * 10.0

func reserved_seed() -> int:
	var total: int = job.get("seed", 0)
	for waiting in queue:
		total += waiting.seed
	return total

func mass() -> float:
	return fat + lean

func bmi() -> float:
	return mass() / (height * height)

## Basal metabolic rate in kcal an hour, from lean mass (Katch–McArdle).
func basal() -> float:
	return (370.0 + 21.6 * lean) / 24.0

## kcal an hour `action` burns. Moving adds about 1 kcal per kilogram moved for each
## step of effort above basal (one MET), so weight and loads make it dearer.
func burn(action: String) -> float:
	var effort: float = EFFORT[action]
	var cost := basal() * effort
	if action == "Walking" or action in WORK_HOURS or action == "Build":
		cost = basal() + (effort - 1.0) * (mass() + carried / 1000.0)
	return cost + (exposure.extra_energy(basal()) if weather != null else 0.0)

## Fatigue points an hour `action` adds, or clears when negative.
func tiring(action: String) -> float:
	if action == "Sleeping":
		return -100.0 / (6.0 if _farm != null and _farm.shelter and position == home else SLEEP_HOURS) * (1.0 if exposure.comfortable() else 0.6)
	return AWAKE_TIRING + EFFORT_TIRING * (EFFORT[action] - EFFORT.Idle)

## kcal an hour the gut absorbs while there is food in it.
func digestion() -> float:
	return ALIMENTARY_LIMIT * basal()

## Share of normal working and walking pace that tiredness leaves.
func pace() -> float:
	var result := 1.0
	for tired in TIRED_PACE:
		if fatigue >= tired - EPSILON:
			result = TIRED_PACE[tired]
	if exposure.core < 35.0 or exposure.core > 39.0: result *= 0.6
	elif not exposure.comfortable(): result *= 0.8
	return result

## Grams of dry grain the stomach has room for.
func room() -> int:
	return floori(STOMACH_GRAMS - stomach + EPSILON)

func cancel(farm: Farm) -> void:
	if activity == "Dead":
		return
	for waiting in queue:
		if waiting.seed:
			farm.stock[waiting.crop] += waiting.seed
	if not job.is_empty() and job.seed:
		farm.stock[job.crop] += job.seed - (carried if _carrying_seed else 0)
	if build_reserved > 0:
		farm.wood += build_reserved
	build_reserved = 0
	build_remaining = 0.0
	recovering = false
	queue.clear()
	job = {}
	_returning_home = true
	message = "Jobs cleared; returning home"

func build_shelter(farm: Farm) -> bool:
	if activity == "Dead" or health <= 0 or farm.shelter or build_reserved > 0:
		return false
	if eating_requested or sleep_remaining > 0:
		message = "Finish the meal or wake before starting construction"
		return false
	if farm.wood < Farm.SHELTER_WOOD:
		message = "Shelter needs 300 kg deposited wood"
		return false
	if not _reachable(position, home):
		message = "No dry route to camp"
		return false
	_farm = farm
	farm.wood -= Farm.SHELTER_WOOD
	build_reserved = Farm.SHELTER_WOOD
	build_remaining = BUILD_HOURS
	message = "Returning home to build the shelter"
	return true

func cancel_meal(farm: Farm) -> void:
	if not eating_requested: return
	farm.stock[meal_crop] += meal_grams
	farm.wood += meal_fuel
	meal_fuel = 0
	meal_crop = ""
	meal_grams = 0
	_cooking_remaining = 0.0
	eating_requested = false
	_farm_changed = true

func sleep(hours: Variant) -> bool:
	if activity == "Dead" or health <= 0.0 or sleep_remaining > 0.0 or eating_requested:
		return false
	if typeof(hours) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(hours) or hours <= 0.0 or hours > MAX_SLEEP_HOURS:
		message = "Choose sleep hours above zero and up to 24"
		return false
	if not _reachable(position, home):
		message = "No dry route to camp"
		return false
	sleep_remaining = hours
	message = "Returning home to sleep"
	return true

func recover() -> bool:
	if activity == "Dead" or health <= 0 or eating_requested or sleep_remaining > 0:
		message = "Finish the meal or wake before recovering"
		return false
	if not _reachable(position, home):
		message = "No dry route to camp"
		return false
	recovering = true
	message = "Returning to camp to recover; field work preserved"
	return true

func wake_up() -> void:
	if recovering:
		recovering = false
		activity = "Idle"
		message = "Recovery ended; resuming work"
	if activity != "Dead" and health > 0.0 and sleep_remaining > 0.0:
		sleep_remaining = 0.0
		if activity == "Sleeping":
			activity = "Idle"
		message = "Awake; resuming work"

func sleep_prediction(hours: Variant, context: Farm = null, day := 0, hour := 0.0) -> Dictionary:
	var forecast := Human.new()
	for property in ["position", "home", "carried", "carried_crop", "height", "fat", "lean", "glycogen", "stomach", "stomach_kcal", "fatigue", "terrain", "terrain_scale", "weather", "activity", "eating_requested", "sleep_remaining", "build_remaining", "build_reserved", "recovering", "_carrying_seed", "_returning_home", "_absolute_hour"]:
		forecast.set(property, get(property))
	forecast.exposure = exposure.copy_state()
	forecast.job = job.duplicate(true)
	forecast.queue = queue.duplicate(true)
	forecast._route = _route.duplicate()
	forecast._route_destination = _route_destination
	forecast._thermal_key = _thermal_key.duplicate()
	forecast._thermal_rate = _thermal_rate.duplicate()
	var source: Farm = context if context != null else _farm
	var farm := source.copy_state() if source != null else Farm.new()
	forecast._farm = farm
	if not forecast.sleep(hours): return {}
	var elapsed := 0.0
	while forecast.position != forecast.home and forecast.activity != "Dead":
		forecast.advance(farm, day, hour + elapsed, forecast.position.distance_to(forecast.home) / (WALK_SPEED * forecast.pace()))
		elapsed += forecast.advanced_hours
		if forecast.sleep_remaining == 0.0 and forecast.activity != "Dead": return {}
	forecast.advance(farm, day, hour + elapsed, float(hours))
	return {"fatigue":forecast.fatigue, "glycogen":forecast.glycogen, "mass":forecast.mass(), "health":forecast.health, "hours":elapsed + forecast.advanced_hours, "core":forecast.exposure.core, "wetness":forecast.exposure.wetness, "exposure_health":forecast.exposure.health, "wood":farm.wood}

static func porridge(crop: String, grams: int) -> Dictionary:
	# shortcut: water and milling losses are abstracted; model them before adding thirst or processing.
	if crop not in Farm.CROPS or grams <= 0:
		return {}
	return {"hours": MEAL_HOURS * grams / MEAL_GRAMS, "calories": grams * Farm.CROPS[crop].kcal_per_100g / 100.0}

func eat(farm: Farm, crop: String, grams: Variant) -> bool:
	_farm = farm
	if activity == "Dead" or health <= 0.0 or eating_requested or sleep_remaining > 0.0:
		return false
	if crop not in Farm.CROPS or typeof(grams) != TYPE_INT or grams <= 0:
		message = "Choose grain and a positive whole-gram quantity"
		return false
	if grams > room():
		message = "Too full: room for %d g" % room()
		return false
	if farm.stock[crop] < grams:
		message = "Not enough unreserved %s" % crop.to_lower()
		return false
	if not _reachable(position, home):
		message = "No dry route to camp"
		return false
	var fuel := ceili(porridge(crop, grams).hours * Farm.FUEL_PER_HOUR + farm.fuel_remainder - EPSILON)
	if farm.wood < fuel:
		message = "Not enough wood for cooking: needs %s kg" % Farm.kg(fuel)
		return false
	farm.stock[crop] -= grams
	farm.wood -= fuel
	meal_fuel = fuel
	meal_crop = crop
	meal_grams = grams
	_cooking_remaining = porridge(crop, grams).hours
	eating_requested = true
	message = "Returning home for a meal"
	return true

## The caller owns the calendar and splits at midnight; events also split each minute.
func advance(farm: Farm, day: int, hour: float, hours: float) -> bool:
	advanced_hours = 0.0
	_farm = farm
	if activity == "Dead" or hours <= 0.0:
		return false
	_farm_changed = false
	while hours - advanced_hours > EPSILON:
		_absolute_hour = day * 24.0 + hour + advanced_hours
		var now := fposmod(_absolute_hour, 24.0)
		var minute_end := (floorf((_absolute_hour + EPSILON) * 60.0) + 1.0) / 60.0
		var step := minf(hours - advanced_hours, maxf(EPSILON * 2.0, minute_end - _absolute_hour))
		for boundary in [6.0, 22.0, 24.0]:
			if boundary - now > EPSILON:
				step = minf(step, boundary - now)
		var used := _step(farm, day, now, step)
		advanced_hours += used
		if activity == "Dead":
			break
	farm.fire_lit = activity != "Dead" and position == home and (eating_requested or farm.heating_enabled) and (meal_fuel if eating_requested else farm.wood) > farm.fuel_remainder + EPSILON
	return _farm_changed

func _step(farm: Farm, day: int, _hour: float, hours: float) -> float:
	if health <= 0.0:
		_die()
		return 0.0
	if position.distance_to(home) < EPSILON:
		position = home
		_deposit(farm)
		_returning_home = false
	var return_home := eating_requested or sleep_remaining > 0.0 or build_remaining > 0.0 or recovering or _returning_home or (carried > 0 and (not _carrying_seed or job.is_empty()))
	if return_home and position != home:
		return _walk(farm, home, hours)
	if eating_requested:
		activity = "Cooking"
		var used := _spend(minf(hours, _cooking_remaining), "Cooking")
		_cooking_remaining = maxf(0.0, _cooking_remaining - used)
		if _cooking_remaining <= EPSILON and activity != "Dead":
			stomach += meal_grams
			stomach_kcal += porridge(meal_crop, meal_grams).calories
			farm.wood += meal_fuel
			meal_fuel = 0
			eating_requested = false
			meal_crop = ""
			meal_grams = 0
			message = "Meal eaten"
		return used
	if sleep_remaining > 0.0:
		activity = "Sleeping"
		var used := _spend(minf(hours, sleep_remaining), "Sleeping")
		sleep_remaining = maxf(0.0, sleep_remaining - used)
		if sleep_remaining <= EPSILON and activity != "Dead":
			sleep_remaining = 0.0
			activity = "Idle"
			message = "Awake; resuming work"
		return used
	if recovering:
		if exposure.recovered():
			recovering = false
			message = "Recovered; resuming work"
		else:
			activity = "Recovering"
			message = "Recovering at camp; queued work preserved"
			if exposure.core < 36.5 and (not farm.heating_enabled or farm.wood <= 0): message = "Too cold: enable heating and supply wood"
			elif exposure.core > 38 and farm.heating_enabled: message = "Too hot: turn heating off while recovering"
			elif exposure.wetness > 0.1 and not farm.shelter: message = "Open camp may stay wet in rain; build a shelter"
			return _spend(hours, "Recovering")
	if build_remaining > 0.0:
		activity = "Building"
		var rate := pace()
		var used := _spend(minf(hours, build_remaining / rate), "Build")
		build_remaining = maxf(0.0, build_remaining - used * rate)
		_farm_changed = true
		if build_remaining <= EPSILON and activity != "Dead":
			build_remaining = 0.0
			build_reserved = 0
			farm.shelter = true
			message = "Shelter complete"
		return used
	if job.is_empty() and not queue.is_empty():
		job = queue.pop_front()
	if job.is_empty():
		activity = "Idle"
		return _spend(hours, "Idle")
	if job.seed and not _carrying_seed:
		if position != home:
			return _walk(farm, home, hours)
		carried_crop = job.crop
		carried = job.seed
		_carrying_seed = true
	var destination := plot_centre(job.cell)
	if position.distance_to(destination) > EPSILON:
		return _walk(farm, destination, hours)
	position = destination
	activity = "Working"
	var rate := pace()
	var used := _spend(minf(hours, job.remaining / rate), job.action)
	job.remaining = maxf(0.0, job.remaining - used * rate)
	if job.action == "Chop" and farm.woodland.has(job.cell):
		farm.woodland[job.cell] = job.remaining
	if job.remaining <= EPSILON and activity != "Dead":
		_finish_job(farm, day)
	return used

func _walk(farm: Farm, destination: Vector2, hours: float) -> float:
	if terrain != null:
		if _route_destination != destination:
			_route = terrain.path(position * terrain_scale, destination * terrain_scale)
			for index in _route.size():
				_route[index] /= terrain_scale
			if not _route.is_empty():
				_route[0] = position
				_route[-1] = destination
			_route_destination = destination
		while not _route.is_empty() and position.distance_to(_route[0]) < EPSILON:
			_route.remove_at(0)
		if _route.is_empty():
			if not job.is_empty():
				if job.seed:
					farm.stock[job.crop] += job.seed - (carried if _carrying_seed else 0)
					_farm_changed = true
				job = {}
			cancel_meal(farm)
			if build_reserved:
				farm.wood += build_reserved
				build_reserved = 0
				build_remaining = 0.0
				_farm_changed = true
			sleep_remaining = 0.0
			recovering = false
			_returning_home = false
			activity = "Idle"
			message = "No dry route; work cancelled and unused grain returned"
			return _spend(hours, "Idle")
		destination = _route[0]
	activity = "Walking"
	var distance := position.distance_to(destination)
	facing = position.direction_to(destination)
	var speed := WALK_SPEED * pace()
	var used := _spend(minf(hours, distance / speed), "Walking")
	position = position.move_toward(destination, used * speed)
	if position.distance_to(destination) < EPSILON:
		position = destination
		if position == home and activity != "Dead":
			_deposit(farm)
	return used

func _reachable(from: Vector2, to: Vector2) -> bool:
	return terrain == null or not terrain.path(from * terrain_scale, to * terrain_scale).is_empty()

## Spends up to `hours` on `action` and returns the hours used. Stops where pace,
## digestion or survival change, so frame size never changes the outcome.
func _spend(hours: float, action: String) -> float:
	var cost := burn(action)
	var tired_rate := tiring(action)
	var digesting := digestion() if stomach_kcal > EPSILON else 0.0
	var used := hours
	var fire := _farm != null and position == home and (_farm.heating_enabled or eating_requested)
	var fuel: int = (meal_fuel if eating_requested else _farm.wood) if _farm != null else 0
	fire = fire and fuel > _farm.fuel_remainder + EPSILON
	if _farm != null: _farm.fire_lit = fire
	if fire:
		used = minf(used, (fuel - _farm.fuel_remainder) / Farm.FUEL_PER_HOUR)
	if digesting > 0.0:
		used = minf(used, stomach_kcal / digesting)
	for tired in TIRED_PACE.keys() + [100.0]:
		if tired_rate > 0.0 and fatigue < tired - EPSILON:
			used = minf(used, (tired - fatigue) / tired_rate)
			break
	var starved := INF
	if cost > digesting:
		starved = (glycogen + _reserve()) / (cost - digesting)
		used = minf(used, starved)
	if weather != null:
		var key := [floori((_absolute_hour + EPSILON) * 60.0), action, position == home, _farm.shelter, fire]
		if key != _thermal_key:
			_thermal_key = key
			var absolute_minute: float = key[0] / 60.0
			var climate := weather.at(floori(absolute_minute / 24.0), fposmod(absolute_minute, 24.0))
			_thermal_rate = exposure.rates(climate, EFFORT[action], mass(), basal(), position == home and _farm.shelter, fire)
		used = exposure.advance(used, _thermal_rate, position == home and action in ["Idle", "Sleeping", "Recovering"])
	var absorbed := digesting * used
	if absorbed > 0.0:
		stomach -= stomach * absorbed / stomach_kcal
		stomach_kcal -= absorbed
		if stomach_kcal <= EPSILON:
			stomach = 0.0
			stomach_kcal = 0.0
	fatigue = clampf(fatigue + used * tired_rate, 0.0, 100.0)
	_store(absorbed - cost * used)
	if fire:
		var burn_grams := _farm.fuel_remainder + used * Farm.FUEL_PER_HOUR
		var whole := mini(fuel, floori(burn_grams + EPSILON))
		_farm.fuel_remainder = maxf(0.0, burn_grams - whole)
		if eating_requested: meal_fuel -= whole
		else: _farm.wood -= whole
		if whole > 0: _farm_changed = true
	if used >= starved - EPSILON or exposure.health <= 0.0:
		_die()
	return used

## Adds kcal to the body, or takes them when negative: glycogen first, then fat and
## lean tissue, gained mostly as fat and lost by Forbes' rule.
func _store(kcal: float) -> void:
	glycogen += kcal
	var change := maxf(0.0, glycogen - lean * GLYCOGEN_PER_LEAN) + minf(0.0, glycogen)
	glycogen -= change
	if change > 0.0:
		var kg := change * STORE_EFFICIENCY / (GAIN_FAT_SHARE * FAT_KCAL + (1.0 - GAIN_FAT_SHARE) * LEAN_KCAL)
		fat += kg * GAIN_FAT_SHARE
		lean += kg * (1.0 - GAIN_FAT_SHARE)
		return
	var lean_per_fat := FORBES / maxf(fat, 0.001)
	var fat_change := change / (FAT_KCAL + LEAN_KCAL * lean_per_fat)
	fat += fat_change
	lean += fat_change * lean_per_fat

## kcal of tissue the body can still lose before starving to death, at today's fat.
func _reserve() -> float:
	var lean_per_fat := FORBES / maxf(fat, 0.001)
	return maxf(0.0, mass() - DEATH_BMI * height * height) / (1.0 + lean_per_fat) * (FAT_KCAL + LEAN_KCAL * lean_per_fat)

func _finish_job(farm: Farm, day: int) -> void:
	if job.action == "Haul wood":
		var grams: int = mini(farm.wood_piles.get(job.cell, 0), BAG_CAPACITY)
		if grams > 0:
			carried = grams
			carried_crop = "Wood"
			farm.wood_piles[job.cell] -= grams
			_farm_changed = true
			job.remaining = WORK_HOURS["Haul wood"]
			if farm.wood_piles[job.cell] == 0:
				farm.wood_piles.erase(job.cell)
				job = {}
			message = "Hauling wood home"
		else:
			job = {}
		return
	# Temporarily restore held seed so Farm validates and consumes the same reserved grams.
	if job.seed:
		farm.stock[job.crop] += job.seed
	var next := farm.action(job.cell, day, job.crop)
	var valid: bool = next.name == job.action and next.reason == ""
	if job.action == "Harvest":
		valid = valid and farm.crop(job.cell) == job.crop
		# shortcut: every current cereal yield fits one 15 kg bag; add haul trips before larger crops.
		if valid:
			valid = farm.harvest_yield(job.cell) <= BAG_CAPACITY
	var before: int = farm.stock.get(job.crop, 0)
	if valid and farm.act(job.cell, day, job.crop):
		_farm_changed = true
		if job.action == "Chop":
			job.action = "Haul wood"
			job.remaining = WORK_HOURS["Haul wood"]
			message = "Wood cut; hauling it to camp"
			return
		if job.action == "Sow":
			carried = 0
			carried_crop = ""
			_carrying_seed = false
		elif job.action == "Harvest":
			carried_crop = job.crop
			carried = farm.stock[job.crop] - before
			farm.stock[job.crop] -= carried
		message = job.action + " complete"
	else:
		if job.seed:
			farm.stock[job.crop] -= job.seed
		message = "Job no longer available; returning unused seed"
	job = {}

func _deposit(farm: Farm) -> void:
	if carried <= 0:
		return
	if not _carrying_seed or job.is_empty():
		if carried_crop == "Wood":
			farm.wood += carried
		else:
			farm.stock[carried_crop] += carried
		_farm_changed = true
	carried = 0
	carried_crop = ""
	_carrying_seed = false

func _die() -> void:
	activity = "Dead"
	message = "Game Over. " + ("Exposure health reached zero." if exposure.health <= 0 else "Starvation health reached zero.")
