class_name Human
extends RefCounted
## One farmer; positions are metres and all carried/reserved mass is integer grams.

const WALK_SPEED := 4500.0
const WORK_HOURS := {"Plow": 3.0, "Sow": 0.5, "Harvest": 2.0}
const BAG_CAPACITY := 15000
const MEAL_GRAMS := 300
const MEAL_HOURS := 0.5
const MAX_SLEEP_HOURS := 24.0
const SLEEP_BURN := 60.0
const SLEEP_RECOVERY := 20.0
const EPSILON := 0.00000001

var home := Vector2(-85, 0)
var position := home
var facing := Vector2.DOWN
var activity := "Idle"
var job: Dictionary = {}
var queue: Array[Dictionary] = []
var carried_crop := ""
var carried := 0
var calories := 2000.0
var fatigue := 0.0
var health := 100.0
var message := "Ready for work"
var sleep_remaining := 0.0
var eating_requested := false
var meal_crop := ""
var meal_grams := 0
var advanced_hours := 0.0

var _carrying_seed := false
var _returning_home := false
var _cooking_remaining := 0.0
var _farm_changed := false

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
		var seed: int = Farm.CROPS[crop].seed if next.name == "Sow" else 0
		if seed:
			farm.stock[crop] -= seed
		queue.append({"action": next.name, "cell": cell, "crop": crop if next.name == "Sow" else farm.crop(cell), "remaining": WORK_HOURS[next.name], "seed": seed})
		added += 1
	if added:
		message = "%d job%s queued" % [added, "" if added == 1 else "s"]
	return added

func reserved_seed() -> int:
	var total: int = job.get("seed", 0)
	for waiting in queue:
		total += waiting.seed
	return total

func cancel(farm: Farm) -> void:
	if activity == "Dead":
		return
	for waiting in queue:
		if waiting.seed:
			farm.stock[waiting.crop] += waiting.seed
	if not job.is_empty() and job.seed:
		farm.stock[job.crop] += job.seed - (carried if _carrying_seed else 0)
	queue.clear()
	job = {}
	_returning_home = true
	message = "Jobs cleared; returning home"

func sleep(hours: Variant) -> bool:
	if activity == "Dead" or health <= 0.0 or sleep_remaining > 0.0 or eating_requested:
		return false
	if typeof(hours) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(hours) or hours <= 0.0 or hours > MAX_SLEEP_HOURS:
		message = "Choose sleep hours above zero and up to 24"
		return false
	sleep_remaining = hours
	message = "Returning home to sleep"
	return true

func wake_up() -> void:
	if activity != "Dead" and health > 0.0 and sleep_remaining > 0.0:
		sleep_remaining = 0.0
		if activity == "Sleeping":
			activity = "Idle"
		message = "Awake; resuming work"

func sleep_prediction(hours: Variant) -> Dictionary:
	var forecast := Human.new()
	forecast.position = position
	forecast.home = home
	forecast.calories = calories
	forecast.fatigue = fatigue
	forecast.health = health
	if not forecast.sleep(hours):
		return {}
	forecast.advance(Farm.new(), 0, 0, position.distance_to(home) / WALK_SPEED + float(hours))
	return {"fatigue": forecast.fatigue, "calories": forecast.calories, "health": forecast.health, "hours": forecast.advanced_hours}

static func porridge(crop: String, grams: int) -> Dictionary:
	# shortcut: water, fuel, milling losses and weather exposure are abstracted; model them before expanding survival.
	if crop not in Farm.CROPS or grams <= 0:
		return {}
	return {"hours": MEAL_HOURS * grams / MEAL_GRAMS, "calories": grams * Farm.CROPS[crop].kcal_per_100g / 100.0}

func eat(farm: Farm, crop: String, grams: Variant) -> bool:
	if activity == "Dead" or health <= 0.0 or eating_requested or sleep_remaining > 0.0:
		return false
	if crop not in Farm.CROPS or typeof(grams) != TYPE_INT or grams <= 0:
		message = "Choose grain and a positive whole-gram quantity"
		return false
	if farm.stock[crop] < grams:
		message = "Not enough unreserved %s" % crop.to_lower()
		return false
	farm.stock[crop] -= grams
	meal_crop = crop
	meal_grams = grams
	_cooking_remaining = porridge(crop, grams).hours
	eating_requested = true
	message = "Returning home for a meal"
	return true

## The caller owns the calendar and splits at midnight; events also split each minute.
func advance(farm: Farm, day: int, hour: float, hours: float) -> bool:
	advanced_hours = 0.0
	if activity == "Dead" or hours <= 0.0:
		return false
	_farm_changed = false
	while hours - advanced_hours > EPSILON:
		var now := fposmod(hour + advanced_hours, 24.0)
		var step := minf(hours - advanced_hours, 1.0 / 60.0)
		for boundary in [6.0, 22.0, 24.0]:
			if boundary - now > EPSILON:
				step = minf(step, boundary - now)
		var used := _step(farm, day, now, step)
		advanced_hours += used
		if activity == "Dead":
			break
	return _farm_changed

func _step(farm: Farm, day: int, _hour: float, hours: float) -> float:
	if health <= 0.0:
		_die()
		return 0.0
	if position.distance_to(home) < EPSILON:
		position = home
		_deposit(farm)
		_returning_home = false
	var return_home := eating_requested or sleep_remaining > 0.0 or _returning_home or (carried > 0 and (not _carrying_seed or job.is_empty()))
	if return_home and position != home:
		return _walk(farm, home, hours)
	if eating_requested:
		activity = "Cooking"
		var used := _spend(minf(hours, _cooking_remaining), 220.0, 8.0)
		_cooking_remaining = maxf(0.0, _cooking_remaining - used)
		if _cooking_remaining <= EPSILON and activity != "Dead":
			calories += porridge(meal_crop, meal_grams).calories
			eating_requested = false
			meal_crop = ""
			meal_grams = 0
			message = "Meal eaten"
		return used
	if sleep_remaining > 0.0:
		activity = "Sleeping"
		var used := _spend(minf(hours, sleep_remaining), SLEEP_BURN, -SLEEP_RECOVERY)
		sleep_remaining = maxf(0.0, sleep_remaining - used)
		if sleep_remaining <= EPSILON and activity != "Dead":
			sleep_remaining = 0.0
			activity = "Idle"
			message = "Awake; resuming work"
		return used
	if job.is_empty() and not queue.is_empty():
		job = queue.pop_front()
	if job.is_empty():
		activity = "Idle"
		return _spend(hours, 90.0, 1.0)
	if job.seed and not _carrying_seed:
		if position != home:
			return _walk(farm, home, hours)
		carried_crop = job.crop
		carried = job.seed
		_carrying_seed = true
	var destination := Vector2((job.cell.x - 7.5) * 10.0, (job.cell.y - 7.5) * 10.0)
	if position.distance_to(destination) > EPSILON:
		return _walk(farm, destination, hours)
	position = destination
	activity = "Working"
	var used := _spend(minf(hours, job.remaining), 220.0, 8.0)
	job.remaining = maxf(0.0, job.remaining - used)
	if job.remaining <= EPSILON and activity != "Dead":
		_finish_job(farm, day)
	return used

func _walk(farm: Farm, destination: Vector2, hours: float) -> float:
	activity = "Walking"
	var distance := position.distance_to(destination)
	facing = position.direction_to(destination)
	var used := _spend(minf(hours, distance / WALK_SPEED), 160.0, 4.0)
	position = position.move_toward(destination, used * WALK_SPEED)
	if position.distance_to(destination) < EPSILON:
		position = destination
		if position == home and activity != "Dead":
			_deposit(farm)
	return used

## Split at need thresholds as well as job/travel boundaries, independent of frame size.
func _spend(hours: float, burn: float, tired: float) -> float:
	var used := hours
	if calories > EPSILON:
		used = minf(used, calories / burn)
	else:
		used = minf(used, health / 2.0)
	if tired > 0.0 and fatigue < 100.0 - EPSILON:
		used = minf(used, (100.0 - fatigue) / tired)
	if calories <= EPSILON:
		health = maxf(0.0, health - used * 2.0)
	calories -= used * burn
	fatigue = clampf(fatigue + used * tired, 0.0, 100.0)
	if health <= EPSILON:
		_die()
	return used

func _finish_job(farm: Farm, day: int) -> void:
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
		farm.stock[carried_crop] += carried
		_farm_changed = true
	carried = 0
	carried_crop = ""
	_carrying_seed = false

func _die() -> void:
	health = 0.0
	activity = "Dead"
	message = "Game Over. Health reached zero."
