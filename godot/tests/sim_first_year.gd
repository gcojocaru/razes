extends SceneTree
## Plays the first year headlessly with the real Farm, Human and Weather rules and a
## scripted player, to see whether year one can be survived. Not a pass/fail suite:
## it prints one line per weather seed and policy.
## [STOCK=1] [TARGET=0] [YEARS=1] [WORK=8] godot --headless --path . -s tests/sim_first_year.gd [-- seeds policies...]
## STOCK multiplies Farm.STARTING_STOCK; TARGET caps each crop's plots a year (0: no cap);
## YEARS plays more years than the first; WORK is the hours of jobs queued each morning.
##
## Each morning the player queues up to WORK hours of jobs: harvests, then sowing
## every plot its seed allows (up to TARGET) as each window opens. It eats at
## 06:00, 12:00 and 18:00 enough to refill ready energy, and sleeps 22:00–06:00. Policies differ only in which grain they eat:
##   keep    eats nothing kept for sowing until health falls below half
##   winter  also eats the wheat and rye seed, giving up autumn sowing
##   any     eats whatever is left after each window's sowing
##   plan    keeps seed for TARGET plots of each crop, this year and next, and eats
##           the rest, or anything once BMI nears 18.5, where health starts to fall
## "seed ok" means the store at year end holds next spring's seed for TARGET plots.

const MEALS := [6.0, 12.0, 18.0]
const Terrain := preload("res://terrain.gd")
const SPRING := ["Barley", "Oats", "Millet"]

var stock_scale := float(OS.get_environment("STOCK")) if OS.has_environment("STOCK") else 1.0
var target := int(OS.get_environment("TARGET")) if OS.has_environment("TARGET") else 0
var years := int(OS.get_environment("YEARS")) if OS.has_environment("YEARS") else 1
var work_hours := float(OS.get_environment("WORK")) if OS.has_environment("WORK") else 8.0

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var seeds := range(10)
	var policies := ["keep", "winter", "any"]
	if not args.is_empty():
		seeds = range(int(args[0]))
	if args.size() > 1:
		policies = args.slice(1)
	print("starting stock x%.1f, at most %s plots a crop, %d year(s)" % [stock_scale, target if target else "any", years])
	print("policy  seed  result         min BMI  end BMI  plots sown  kg harvested  kg in store at year end")
	for policy in policies:
		var survived := 0
		for seed in seeds:
			var result := play(seed, policy)
			survived += int(result.alive)
			print("%-7s %4d  %-13s  %6.1f  %7.1f  %10d  %12.1f  %s%s" % [policy, seed, "alive" if result.alive else "dead day %d" % result.day, result.min_bmi, result.bmi, result.sown, result.harvested / 1000.0, result.store, "  seed ok" if result.seed_ok else ""])
		print("%s: %d of %d seeds survive %d year(s)\n" % [policy, survived, seeds.size(), years])
	quit()

func play(seed: int, policy: String) -> Dictionary:
	var weather := Weather.new(seed)
	var farm := Farm.new()
	for crop in farm.stock:
		farm.stock[crop] = roundi(Farm.STARTING_STOCK[crop] * stock_scale)
	farm.terrain = Terrain.new(seed, Terrain.PRESETS.get(OS.get_environment("LAND"), {"hills":Terrain.MAX_HILLS,"ponds":4} if OS.get_environment("LAND")=="Custom" else Terrain.PRESETS.Hills))
	farm.generate_woodland(seed)
	var person := Human.new()
	person.terrain = farm.terrain
	person.weather = weather
	person.home = farm.terrain.camp / person.terrain_scale
	person.position = person.home
	var shelter_day := -1
	var min_core := 37.0
	var cells: Array = []
	for x in 16:
		for y in 16:
			cells.append(Vector2i(x, y))
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return Human.plot_centre(a).distance_to(person.home) < Human.plot_centre(b).distance_to(person.home))
	var min_bmi := person.bmi()
	var day := 0
	var hour := 6.0
	farm.grow(weather.on(day), day)
	while day < Calendar.DAYS_PER_YEAR * years:
		survival(farm, person, cells, weather, day, hour)
		if farm.shelter and shelter_day < 0: shelter_day = day
		if hour == MEALS[0]:
			plan(farm, person, cells, day)
		if hour in MEALS:
			eat(farm, person, policy, day)
		if hour == 22.0:
			person.sleep(8.0)
		var until := 24.0
		for stop in MEALS + [22.0]:
			if stop > hour:
				until = minf(until, stop)
		person.advance(farm, day, hour, until - hour)
		min_bmi = minf(min_bmi, person.bmi())
		min_core = minf(min_core, person.exposure.core)
		if person.activity == "Dead":
			break
		hour = until
		if hour >= 24.0:
			hour = 0.0
			day += 1
			farm.grow(weather.on(day), day)
		if hour == 0.0 and OS.has_environment("TRACE") and day % 7 == 0:
			var stages := {}
			for cell in farm.plots:
				var key: String = farm.stage(cell) + " " + farm.crop(cell)
				stages[key] = "%d" % (int(stages.get(key, "0")) + 1) + " g%.2f" % farm.growth(cell)
			print("day %3d bmi %.1f gly %4d fat %.1f queue %d job %s stock %s %s" % [day, person.bmi(), person.glycogen, person.fat, person.queue.size(), person.job.get("action", "-"), farm.stock, stages])
		if hour == 0.0:
			# Sleep carries the farmer to 06:00.
			person.advance(farm, day, 0.0, 6.0)
			hour = 6.0
	var sown := 0
	var gathered := 0
	for crops in farm.years.values():
		for record in crops.values():
			sown += record.sown
			gathered += record.gathered
	var store := []
	for crop in farm.stock:
		store.append("%s %.1f" % [crop.left(2), farm.stock[crop] / 1000.0])
	var seed_ok := person.activity != "Dead"
	for crop in SPRING:
		seed_ok = seed_ok and farm.stock[crop] >= Farm.CROPS[crop].seed * maxi(target, 1)
	return {"seed_ok": seed_ok, "alive": person.activity != "Dead", "day": day, "min_bmi": min_bmi, "bmi": person.bmi(), "sown": sown, "harvested": gathered, "store": ", ".join(store) + " | shelter day %d; wood %s kg; min %.1f°C" % [shelter_day, Farm.kg(farm.wood), min_core]}

## Queues harvests, then plowing and sowing for as many plots as the open crops'
## seed covers, until a day's work is queued.
func plan(farm: Farm, person: Human, cells: Array, day: int) -> void:
	if not farm.shelter or person.recovering: return
	var busy := {}
	if not person.job.is_empty():
		busy[person.job.cell] = true
	for waiting in person.queue:
		busy[waiting.cell] = true
	var full := func() -> bool:
		var hours: float = person.job.get("remaining", 0.0)
		for waiting in person.queue:
			hours += waiting.remaining
		return hours >= work_hours
	for cell in cells:
		if not full.call() and farm.stage(cell) == "Ripe" and not busy.has(cell):
			person.order(farm, [cell], day, "Harvest")
	var unsown := 0
	for crop in Farm.sowable(day):
		var plots: int = farm.stock[crop] / Farm.CROPS[crop].seed
		if target:
			plots = mini(plots, target - farm.record(day, crop).sown - person.queue.filter(func(waiting: Dictionary) -> bool: return waiting.action == "Sow" and waiting.crop == crop).size() - int(person.job.get("action", "") == "Sow" and person.job.crop == crop))
		for cell in cells:
			if plots > 0 and not full.call() and farm.stage(cell) == "Plowed" and not busy.has(cell) and person.order(farm, [cell], day, "Sow", crop):
				plots -= 1
				busy[cell] = true
		unsown += plots
	# Plow for the seed left over; a later call sows it once plowed.
	unsown -= person.queue.filter(func(waiting: Dictionary) -> bool: return waiting.action == "Plow").size() + int(person.job.get("action", "") == "Plow")
	for cell in cells:
		if unsown <= 0 or full.call():
			break
		if farm.stage(cell) in ["Grass", "Stubble", "Withered"] and not busy.has(cell) and person.order(farm, [cell], day, "Plow"):
			unsown -= 1

## Eats enough to refill ready energy, from grain the policy allows.
func eat(farm: Farm, person: Human, policy: String, day: int) -> void:
	if person.eating_requested or person.sleep_remaining > 0.0:
		return
	var wanted := person.lean * Human.GLYCOGEN_PER_LEAN - person.glycogen - person.stomach_kcal
	for crop in ["Wheat", "Rye", "Millet", "Oats", "Barley"]:
		var free: int = farm.stock[crop] - kept(farm, person, policy, crop, day)
		var grams := mini(mini(free, person.room()), ceili(wanted * 100.0 / Farm.CROPS[crop].kcal_per_100g))
		if grams > 0 and person.eat(farm, crop, grams):
			return

## Grams of `crop` the policy keeps as seed rather than food.
func kept(farm: Farm, person: Human, policy: String, crop: String, day: int) -> int:
	if person.health < 50.0 or (policy == "plan" and person.bmi() < Human.HEALTHY_BMI + 0.5):
		return 0
	var month: int = day % Calendar.DAYS_PER_YEAR / Calendar.DAYS_PER_MONTH
	var window: Array = Farm.CROPS[crop].sow
	var before_window: bool = month <= window.back()
	match policy:
		"keep":
			return farm.stock[crop] if before_window else 0
		"winter":
			return farm.stock[crop] if before_window and crop in SPRING else 0
		"plan":
			var plots: int = target - (farm.record(day, crop).sown if before_window else 0)
			return mini(farm.stock[crop], Farm.CROPS[crop].seed * maxi(plots, 0))
	return 0

## Explicit scripted-player decisions, never automatic behavior in the game.
func survival(farm: Farm, person: Human, cells: Array, weather: Weather, day: int, hour: float) -> void:
	var climate := weather.at(day, hour)
	farm.heating_enabled = climate.temperature < 15.0 or person.exposure.core < 36.5
	var watering: bool = person.queue.any(func(job: Dictionary) -> bool: return job.action in ["Fetch water", "Melt snow"]) or person.job.get("action", "") in ["Fetch water", "Melt snow"]
	if farm.water < 20000 and not watering:
		if farm.snow_cover >= Farm.MELTABLE_SNOW and farm.heating_enabled and farm.wood > 5000: person.melt_snow(farm)
		else: person.fetch_water(farm)
	if not farm.shelter and person.build_reserved == 0 and farm.wood >= Farm.SHELTER_WOOD:
		person.build_shelter(farm)
	if not person.eating_requested and person.sleep_remaining == 0:
		if farm.shelter and (person.exposure.core < 36.2 or person.exposure.core > 38.0 or person.exposure.wetness > 0.7): person.recover()
	var needed := 60000 if farm.shelter else Farm.SHELTER_WOOD + 20000
	var coming := person.carried if person.carried_crop == "Wood" else 0
	if not person.job.is_empty():
		if person.job.action == "Chop": coming += Farm.WOOD_YIELD
		elif person.job.action == "Haul wood": coming += int(farm.wood_piles.get(person.job.cell,0))
	for job in person.queue:
		if job.action == "Chop": coming += Farm.WOOD_YIELD
		elif job.action == "Haul wood": coming += int(farm.wood_piles.get(job.cell,0))
	for cell in cells:
		if farm.wood + coming >= needed: break
		if farm.wood_piles.has(cell) and person.order(farm,[cell],day,"Haul wood"):
			coming += farm.wood_piles[cell]
		elif farm.woodland.has(cell) and person.order(farm,[cell],day,"Chop"):
			coming += Farm.WOOD_YIELD
