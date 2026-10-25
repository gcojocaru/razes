extends SceneTree
## Deterministic farmer behavior: real Farm state, mass conservation and elapsed game time.

const DAY := 35
const CELL := Vector2i(0, 7)
const NEIGHBOUR := Vector2i(1, 7)
var failures: Array[String] = []
var Model: GDScript

func check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)
		push_error(description)

func _initialize() -> void:
	call_deferred("run")

func plowed(cells: Array = [CELL]) -> Farm:
	var farm := Farm.new()
	farm.work(cells, DAY, "Plow")
	return farm

func ripe() -> Farm:
	var farm := plowed()
	farm.act(CELL, DAY, "Barley")
	farm.plots[CELL].stage = "Ripe"
	return farm

## Leaves `person` `kcal` of body tissue above starving to death, with no glycogen.
func starving(person, kcal: float) -> void:
	person.glycogen = 0.0
	person.fat = 2.0
	# Forbes' rule at 2 kg of fat: the kcal each kilogram of body mass still holds.
	var per_kg: float = (Human.FAT_KCAL + Human.LEAN_KCAL * Human.FORBES / 2.0) / (1.0 + Human.FORBES / 2.0)
	person.lean = Human.DEATH_BMI * person.height * person.height - 2.0 + kcal / per_kg

func run() -> void:
	if not ResourceLoader.exists("res://human.gd"):
		check(false, "The timed farmer model exists before any field job can execute")
		quit(1)
		return
	Model = load("res://human.gd")
	if not Model.can_instantiate():
		check(false, "The timed farmer model can be instantiated")
		quit(1)
		return
	if not Model.new().has_method("sleep"):
		check(false, "The farmer accepts a chosen sleep duration")
		quit(1)
		return
	test_body()
	test_created_body()
	test_starvation()
	test_tired_pace()
	test_orders_and_work()
	test_seed_reservations()
	test_cancellation()
	test_stale_jobs()
	test_harvest_hauling()
	test_timed_sleep()
	test_sleep_prediction()
	test_sleep_validation()
	test_porridge()
	test_grain_meal_calories()
	test_selected_meal()
	test_meal_boundaries()
	test_invalid_meals()
	test_meal_seed_and_cancellation()
	test_unfinished_meal_death()
	test_food_and_death()
	test_subdivision()
	test_meal_subdivision()
	if failures.is_empty():
		print("PASS: body-derived metabolism, created bodies, digestion, fat and lean stores, starvation and tired pace; human walking and timed jobs; seed and selected-meal reservations; proportional porridge; invalid meal requests; cancellation and death; hauling; timed sleep and forecasts; deterministic subdivision")
	quit(0 if failures.is_empty() else 1)

func test_body() -> void:
	var person = Model.new()
	check(is_equal_approx(person.mass(), 65.0) and absf(person.bmi() - 22.02) < 0.01 and person.health == 100.0, "The farmer starts as a lean 65 kg adult of 1.718 m, BMI 22, in full health")
	check(is_equal_approx(person.basal() * 24.0, 1563.4) and is_equal_approx(person.glycogen, 1989.0) and person.room() == 375, "Lean mass sets basal metabolism of 1563.4 kcal a day and 1989 kcal of glycogen; the stomach is empty")
	person.advance(Farm.new(), DAY, 6.0, 1.0)
	check(is_equal_approx(person.glycogen, 1989.0 - 1.4 * 1563.4 / 24.0) and is_equal_approx(person.fatigue, 4.375), "An idle hour burns 1.4 times basal metabolism and builds the fatigue of being awake")
	var loaded = Model.new()
	var empty = Model.new()
	loaded.carried = 15000
	loaded.carried_crop = "Barley"
	for walker in [loaded, empty]:
		walker.position = walker.home + Vector2(4500, 0)
		walker.cancel(Farm.new())
		walker.advance(Farm.new(), DAY, 6.0, 1.0)
	check(loaded.position == loaded.home and is_equal_approx(empty.glycogen - loaded.glycogen, 2.2 * 15.0), "A 15 kg sack adds 2.2 kcal an hour per kilogram to walking: one MET per kilogram moved")
	var farm := Farm.new()
	var eater = Model.new()
	eater.glycogen = 1000.0
	check(not eater.eat(farm, "Oats", 376) and eater.message.contains("375") and farm.stock.Oats == 8000, "A meal bigger than the 375 g stomach is refused without spending grain")
	eater.eat(farm, "Oats", 375)
	eater.advance(farm, DAY, 6.0, 0.625)
	check(eater.stomach == 375.0 and is_equal_approx(eater.stomach_kcal, 1458.75) and eater.room() == 0, "Cooked porridge fills the stomach with its grain and energy")
	check(not eater.eat(farm, "Oats", 1), "A full stomach refuses even a gram more")
	var before: float = eater.glycogen
	eater.advance(farm, DAY, 6.625, 1.0)
	check(is_equal_approx(eater.digestion(), 2.5 * 1563.4 / 24.0) and is_equal_approx(eater.stomach_kcal, 1458.75 - eater.digestion()) and is_equal_approx(eater.glycogen, before + eater.digestion() - 1.4 * eater.basal()) and eater.room() == 41, "The gut passes 2.5 times basal metabolism into glycogen and frees stomach room")
	var feast = Model.new()
	feast.stomach = 375.0
	feast.stomach_kcal = 1458.75
	feast.advance(Farm.new(), DAY, 6.0, 1458.75 / feast.digestion())
	check(feast.stomach == 0.0 and absf(feast.glycogen - feast.lean * Human.GLYCOGEN_PER_LEAN) < 1.0 and feast.fat > Human.START_FAT and is_equal_approx(feast.fat - Human.START_FAT, 2.0 * (feast.lean - Human.START_LEAN)), "Energy beyond full glycogen is stored, two thirds of the gain as fat")
	var glutton = Model.new()
	farm = Farm.new()
	farm.stock.Oats = 100000
	for minute in 24 * 60:
		if not glutton.eating_requested and glutton.room() >= 50:
			glutton.eat(farm, "Oats", glutton.room())
		glutton.advance(farm, DAY, minute / 60.0, 1.0 / 60.0)
	var gained: float = glutton.mass() - 65.0
	check(gained > 0.1 and gained < 0.2, "Eating at every chance for a resting day adds under 0.2 kg: the gut caps what overeating can store")

func test_created_body() -> void:
	var person = Model.new()
	person.create({"name": "Toader", "height": 1.85, "weight": 72.0, "body_fat": 0.25})
	check(person.name == "Toader" and is_equal_approx(person.mass(), 72.0) and is_equal_approx(person.fat, 18.0) and is_equal_approx(person.start_lean, 54.0) and is_equal_approx(person.glycogen, 54.0 * Human.GLYCOGEN_PER_LEAN) and absf(person.bmi() - 21.04) < 0.01, "A created peasant starts with the chosen name and body, full glycogen and a BMI from their own height")
	check(is_equal_approx(person.basal() * 24.0, 370.0 + 21.6 * 54.0), "Their lean mass sets their basal metabolism")
	person.fatigue = 80
	starving(person, 30.0)
	var preview: Dictionary = person.sleep_prediction(8)
	person.sleep(8)
	person.advance(Farm.new(), DAY, 22, 8)
	check(person.activity == "Dead" and is_equal_approx(person.bmi(), Human.DEATH_BMI) and person.mass() > 42.0 and is_equal_approx(person.advanced_hours, preview.hours), "A taller body starves at a BMI of 12.5 for its own height, when its sleep forecast says")

func test_starvation() -> void:
	var person = Model.new()
	var farm := Farm.new()
	var hurt := -1
	var days := 0
	while person.activity != "Dead" and days < 120:
		person.advance(farm, DAY, 6.0, 24.0)
		days += 1
		if hurt < 0 and person.health < 100.0:
			hurt = days
	check(hurt > 20 and days >= 45 and days <= 75 and person.lean < Human.START_LEAN * 0.75, "With no food an idle farmer keeps full health for weeks, then starves after about two months, losing muscle once fat runs low")
	check(is_equal_approx(person.bmi(), Human.DEATH_BMI) and person.health == 0.0, "Starvation kills exactly at the limit of survival")
	var thin = Model.new()
	thin.fat = 3.0
	thin.lean = 40.0
	thin.glycogen = 40.0 * Human.GLYCOGEN_PER_LEAN
	var health: float = thin.health
	thin.stomach = 375.0
	thin.stomach_kcal = 1458.75
	thin.advance(Farm.new(), DAY, 6.0, 1458.75 / 300.0)
	check(thin.health > health and thin.mass() > 43.0, "Eating after starvation rebuilds weight and health")
	var dying = Model.new()
	starving(dying, 10.0)
	dying.advance(Farm.new(), DAY, 6.0, 1.0)
	check(dying.activity == "Dead" and dying.advanced_hours < 0.2 and is_equal_approx(dying.bmi(), Human.DEATH_BMI), "Time advancement stops at the exact instant the body reaches the limit of survival")

func test_tired_pace() -> void:
	var farm := Farm.new()
	var person = Model.new()
	person.fatigue = 95.0
	person.position = Vector2((CELL.x - 7.5) * 10.0, (CELL.y - 7.5) * 10.0)
	person.order(farm, [CELL], DAY, "Plow")
	person.advance(farm, DAY, 6.0, 4.99)
	check(farm.stage(CELL) == "Grass" and person.activity == "Working", "An exhausted farmer still hoes, at 60% pace")
	person.advance(farm, DAY, 10.99, 0.02)
	check(farm.stage(CELL) == "Plowed", "Three hours of hoeing take five when exhausted")
	var walker = Model.new()
	walker.fatigue = 75.0
	walker.position = walker.home + Vector2(4500, 0)
	walker.cancel(Farm.new())
	walker.advance(Farm.new(), DAY, 6.0, 0.5)
	check(walker.position.is_equal_approx(walker.home + Vector2(2700, 0)), "Past 70% fatigue the farmer walks at 80% pace")
	var sleeper = Model.new()
	sleeper.fatigue = 100.0
	sleeper.sleep(8.0)
	sleeper.advance(Farm.new(), DAY, 22.0, 8.0)
	check(is_zero_approx(sleeper.fatigue) and is_equal_approx(sleeper.glycogen, 1989.0 - 8.0 * sleeper.basal()), "Eight hours' sleep clears full fatigue and burns basal metabolism")
	var awake = Model.new()
	awake.advance(Farm.new(), DAY, 6.0, 16.0)
	check(is_equal_approx(awake.fatigue, 70.0), "Sixteen idle hours awake build 70% fatigue")

func test_orders_and_work() -> void:
	var farm := Farm.new()
	var person = Model.new()
	check(person.order(farm, [CELL, CELL, Vector2i(-1, 0), Vector2i(16, 0), "bad", Vector2(1, 1)], DAY, "Plow") == 1, "Only an eligible in-bounds integer cell queues once")
	check(farm.stage(CELL) == "Grass" and person.queue.size() == 1, "Ordering work does not instantly change the plot")
	check(person.order(farm, [CELL], DAY, "Plow") == 0, "A plot already waiting cannot queue another job")
	person.advance(farm, DAY, 6.0, 0.1)
	check(farm.stage(CELL) == "Grass" and person.activity == "Working" and person.job.remaining > 2.8, "Walking and a fraction of three-hour plowing leave the land unchanged")
	check(person.order(farm, [CELL], DAY, "Plow") == 0, "A plot being worked cannot queue again")
	check(person.advance(farm, DAY, 6.1, 3.0) and farm.stage(CELL) == "Plowed", "Completing three hours of actual field work plows through Farm")
	check(person.order(farm, [NEIGHBOUR], DAY, "Dance") == 0 and person.order(farm, [NEIGHBOUR], Calendar.DAYS_PER_SEASON * 3, "Plow") == 0, "Unknown actions and winter plowing have no side effects")
	var walker = Model.new()
	walker.home = Vector2(-4575, -5)
	walker.position = walker.home
	walker.order(Farm.new(), [CELL], DAY, "Plow")
	walker.advance(farm, DAY, 6.0, 0.5)
	check(walker.position.is_equal_approx(Vector2(-2325, -5)) and walker.activity == "Walking", "A half-hour walk covers exactly 2250 metres")
	var all_cells: Array = []
	for x in 16:
		for y in 16:
			all_cells.append(Vector2i(x, y))
	person = Model.new()
	farm = Farm.new()
	check(person.order(farm, all_cells + all_cells, DAY, "Plow") == 256 and person.queue.size() == 256, "The queue contains at most the 256 distinct field plots")

func test_seed_reservations() -> void:
	var cells: Array = [CELL, NEIGHBOUR, Vector2i(2, 7), Vector2i(3, 7), Vector2i(4, 7), Vector2i(5, 7)]
	var farm := plowed(cells)
	var person = Model.new()
	check(person.order(farm, cells, DAY, "Sow", "Barley") == 5 and farm.stock.Barley == 0 and person.reserved_seed() == 10000, "Five sowings reserve every gram of barley immediately; a sixth cannot overspend")
	person.advance(farm, DAY, 6.0, 0.001)
	check(person.carried == 2000 and person.carried_crop == "Barley" and person.reserved_seed() == 10000, "Only the active job's seed leaves camp in the person's bag")
	person.advance(farm, DAY, 6.001, 0.51)
	check(farm.stage(CELL) == "Sown" and farm.record(DAY, "Barley").seed == 2000 and person.reserved_seed() == 8000, "Carried seed commits exactly once even when no unreserved seed remains")
	check(farm.stock.Barley == 0, "Starting the next reserved sowing never exposes reserved grain as free stock")

func test_cancellation() -> void:
	var farm := plowed([CELL, NEIGHBOUR])
	var person = Model.new()
	person.order(farm, [CELL, NEIGHBOUR], DAY, "Sow", "Barley")
	person.cancel(farm)
	check(farm.stock.Barley == 10000 and person.reserved_seed() == 0 and person.queue.is_empty(), "Cancelling waiting jobs immediately refunds all reserved seed")
	person.order(farm, [CELL, NEIGHBOUR], DAY, "Sow", "Barley")
	person.advance(farm, DAY, 6.0, 0.1)
	var away: Vector2 = person.position
	person.cancel(farm)
	check(farm.stock.Barley == 8000 and person.carried == 2000 and person.queue.is_empty() and person.job.is_empty(), "Cancelling refunds waiting seed immediately while carried seed remains physically away")
	check(person.position == away and person.reserved_seed() == 0, "Cancelling clears the work without teleporting the person or reserving abandoned seed")
	person.advance(farm, DAY, 6.1, 0.1)
	check(person.position == person.home and farm.stock.Barley == 10000 and person.carried == 0, "Cancelled carried seed returns exactly once upon arrival home")
	person.cancel(farm)
	check(farm.stock.Barley == 10000, "Repeated cancellation cannot duplicate refunded stock")

func test_stale_jobs() -> void:
	var farm := plowed()
	var person = Model.new()
	person.order(farm, [CELL], DAY, "Sow", "Barley")
	person.advance(farm, Calendar.DAYS_PER_MONTH * 2, 6.0, 1.0)
	check(farm.stage(CELL) == "Plowed" and farm.stock.Barley == 10000 and person.carried == 0, "A sowing window closed before completion refunds carried seed at home")
	farm = plowed()
	person = Model.new()
	person.order(farm, [CELL], DAY, "Sow", "Barley")
	farm.act(CELL, DAY, "Oats")
	person.advance(farm, DAY, 6.0, 1.0)
	check(farm.crop(CELL) == "Oats" and farm.stock.Barley == 10000, "A stale sowing job cannot replace another crop or lose its seed")
	farm = ripe()
	person = Model.new()
	person.order(farm, [CELL], DAY, "Harvest")
	farm.grow({"temperature": -3, "condition": "Snow"}, DAY)
	person.advance(farm, DAY, 6.0, 2.5)
	check(farm.stage(CELL) == "Withered" and farm.stock.Barley == 8000 and person.carried == 0, "Frost before harvest completion invalidates the job without plowing or gathering")
	farm = Farm.new()
	person = Model.new()
	person.order(farm, [CELL], DAY, "Plow")
	person.advance(farm, Calendar.DAYS_PER_SEASON * 3, 6.0, 3.5)
	check(farm.stage(CELL) == "Grass", "Work that finishes on frozen winter ground cannot commit")

func test_harvest_hauling() -> void:
	var farm := ripe()
	var person = Model.new()
	person.home = Vector2(-4575, -5)
	person.position = Vector2(-75, -5)
	person.order(farm, [CELL], DAY, "Harvest")
	person.advance(farm, DAY, 6.0, 2.0)
	check(farm.stage(CELL) == "Stubble" and farm.stock.Barley == 8000 and person.carried == 7000 and person.carried_crop == "Barley", "A completed harvest enters the bag, not camp stock")
	person.advance(farm, DAY, 8.0, 0.5)
	check(farm.stock.Barley == 8000 and person.carried == 7000, "Grain in transit remains unavailable to orders and meals")
	check(person.advance(farm, DAY, 8.5, 0.6) and farm.stock.Barley == 15000 and person.carried == 0, "Harvest enters camp stock once on arrival")

func test_timed_sleep() -> void:
	var farm := Farm.new()
	var person = Model.new()
	person.order(farm, [CELL], DAY, "Plow")
	person.advance(farm, DAY, 21.0, 3.1)
	check(farm.stage(CELL) == "Plowed" and person.activity != "Sleeping", "Night does not automatically interrupt work")
	farm = plowed()
	person = Model.new()
	person.order(farm, [CELL], DAY, "Sow", "Barley")
	person.advance(farm, DAY, 6.0, 0.1)
	var remaining: float = person.job.remaining
	person.fatigue = 60.0
	check(person.sleep(8.0), "The player may choose eight hours of daytime sleep")
	person.advance(farm, DAY, 6.1, 1.0)
	check(person.activity == "Sleeping" and person.position == person.home and person.carried == 0 and person.reserved_seed() == 2000 and farm.stock.Barley == 8000 and is_equal_approx(person.job.remaining, remaining), "Sleep returns carried seed to its camp reservation and preserves work")
	person.advance(farm, DAY, 7.1, 6.0)
	check(person.fatigue == 0.0 and person.sleep_remaining > 0.9 and farm.stage(CELL) == "Plowed", "Full recovery does not shorten the player's chosen sleep")
	person.advance(farm, DAY, 13.1, 2.0)
	check(person.sleep_remaining == 0.0 and farm.stage(CELL) == "Sown" and farm.stock.Barley == 8000 and person.reserved_seed() == 0, "At the sleep deadline work resumes and recollects seed exactly once")
	person = Model.new()
	person.fatigue = 100
	person.sleep(8)
	person.advance(Farm.new(), DAY, 6, 0.5)
	person.wake_up()
	check(person.sleep_remaining == 0 and is_equal_approx(person.fatigue, 93.75), "Waking early keeps only the recovery actually earned")
	person.advance(Farm.new(), DAY, 6.5, 1)
	check(person.activity == "Idle" and is_equal_approx(person.fatigue, 98.125), "Waking resumes awake needs without further sleep recovery")
	var a = Model.new()
	var b = Model.new()
	for sleeper in [a, b]:
		sleeper.fatigue = 80
		sleeper.glycogen = 30
		sleeper.sleep(1.37)
	a.advance(Farm.new(), DAY, 23.5, 2)
	for i in 240:
		b.advance(Farm.new(), DAY, 23.5 + i / 120.0, 1.0 / 120)
	check(a.sleep_remaining == 0 and b.sleep_remaining == 0 and is_equal_approx(a.fatigue, b.fatigue) and is_equal_approx(a.glycogen, b.glycogen) and is_equal_approx(a.mass(), b.mass()) and is_equal_approx(a.health, b.health), "Non-frame-aligned sleep and waking across midnight are subdivision independent")

func test_sleep_prediction() -> void:
	var person = Model.new()
	person.fatigue = 80
	var preview: Dictionary = person.sleep_prediction(2)
	check(is_equal_approx(preview.fatigue, 55) and is_equal_approx(preview.glycogen, 1989.0 - 2.0 * person.basal()) and preview.health == 100 and is_equal_approx(preview.hours, 2), "Two hours of sleep recovers 25 fatigue points and burns two hours of basal metabolism")
	check(person.fatigue == 80 and person.glycogen == 1989.0 and person.sleep_remaining == 0 and person.activity == "Idle", "Previewing never changes the actual person")
	person.position = person.home + Vector2(4500, 0)
	preview = person.sleep_prediction(2)
	check(is_equal_approx(preview.fatigue, 80.0 + 1.25 * (70.0 / 16.0 + 30.0 / 32.4 * 1.8) - 25.0) and is_equal_approx(preview.hours, 3.25), "At 80% fatigue the walk home takes 1.25 hours before the full sleep")
	person.sleep(2)
	person.advance(Farm.new(), DAY, 12, 3.25)
	check(is_equal_approx(person.fatigue, preview.fatigue) and is_equal_approx(person.glycogen, preview.glycogen) and is_equal_approx(person.mass(), preview.mass) and is_equal_approx(person.health, preview.health) and person.sleep_remaining == 0, "The actual walk and sleep match the preview")
	person = Model.new()
	person.fatigue = 80
	starving(person, 30.0)
	preview = person.sleep_prediction(8)
	check(preview.health == 0 and preview.hours < 1.0 and preview.fatigue > 70.0, "Preview stops recovery at starvation death rather than promising eight hours")
	person.sleep(8)
	person.advance(Farm.new(), DAY, 22, 8)
	check(person.activity == "Dead" and is_equal_approx(person.advanced_hours, preview.hours), "Actual sleep stops at the predicted death time")

func test_sleep_validation() -> void:
	for hours in [0, -1, 25, NAN, INF, "8", true, null, [], {}]:
		var person = Model.new()
		check(not person.sleep(hours) and person.sleep_remaining == 0 and person.sleep_prediction(hours).is_empty(), "Sleep refuses malformed or out-of-range hours: %s" % str(hours))
	var person = Model.new()
	person.sleep(0.25)
	check(not person.sleep(8) and person.sleep_remaining == 0.25, "A duplicate sleep order cannot replace the pending duration")
	var farm := Farm.new()
	var before := farm.stock.duplicate()
	check(not person.eat(farm, "Oats", 300) and farm.stock == before, "Wake up before a meal can spend grain")
	person.wake_up()
	person.eat(farm, "Oats", 300)
	check(not person.sleep(8) and person.sleep_remaining == 0 and person.eating_requested, "A pending meal must finish before sleep can start")
	person = Model.new()
	person.lean = 20.0
	check(not person.sleep(8) and person.sleep_prediction(8).is_empty(), "A starved body refuses sleep before the next advancement")

func test_porridge() -> void:
	for recipe in [["Barley", 100, 0.166666666666667, 354.0], ["Oats", 100, 0.166666666666667, 389.0], ["Millet", 100, 0.166666666666667, 378.0], ["Wheat", 100, 0.166666666666667, 327.0], ["Rye", 100, 0.166666666666667, 338.0], ["Oats", 1, 0.001666666666667, 3.89], ["Oats", 375, 0.625, 1458.75], ["Millet", 1800, 3.0, 6804.0]]:
		var result: Dictionary = Model.porridge(recipe[0], recipe[1])
		check(is_equal_approx(result.hours, recipe[2]) and is_equal_approx(result.calories, recipe[3]), "Porridge uses %s's dry-grain energy for %d grams" % [recipe[0], recipe[1]])
	check(Model.porridge("Unknown", 300).is_empty() and Model.porridge("Barley", 0).is_empty(), "Unknown grain and empty portions cannot generate a recipe")

func test_grain_meal_calories() -> void:
	for meal in [["Barley", 1062.0], ["Oats", 1167.0], ["Millet", 1134.0], ["Wheat", 981.0], ["Rye", 1014.0]]:
		var farm := Farm.new()
		var person = Model.new()
		var before: int = farm.stock[meal[0]]
		person.eat(farm, meal[0], 300)
		person.advance(farm, DAY, 6, 0.25)
		check(person.stomach_kcal == 0.0 and person.glycogen < 1989.0, "Each grain waits for cooking completion before reaching the stomach")
		person.advance(farm, DAY, 6.25, 0.25)
		check(is_equal_approx(person.stomach_kcal, meal[1]) and person.stomach == 300.0 and farm.stock[meal[0]] == before - 300 and not person.eating_requested, "%s puts its own dry-grain calories in the stomach exactly once" % meal[0])

func test_selected_meal() -> void:
	var farm := plowed()
	farm.stock.Oats = 1875
	var person = Model.new()
	person.position = person.home + Vector2(4500, 0)
	var before := farm.stock.duplicate()
	check(person.eat(farm, "Oats", 375), "The chosen 0.375 kg of oats is accepted while away from camp")
	check(farm.stock.Oats == 1500 and farm.stock.Barley == before.Barley and farm.stock.Millet == before.Millet, "Confirmation reserves precisely the selected oats before walking, without spending the first grain")
	check(person.meal_crop == "Oats" and person.meal_grams == 375 and person.eating_requested, "The pending meal exposes its reserved crop and integer grams")
	check(not person.eat(farm, "Millet", 100) and farm.stock.Millet == before.Millet, "A second meal cannot spend another crop while the first awaits camp")
	check(person.order(farm, [CELL], DAY, "Sow", "Oats") == 0, "Grain reserved for a meal is unavailable to new field orders")
	person.advance(farm, DAY, 6.0, 1.0)
	check(person.position == person.home and person.meal_grams == 375 and is_equal_approx(person.glycogen, 1989.0 - person.basal() - 2.2 * 65.0) and person.stomach == 0.0, "Returning to camp spends walking energy and does not prepare or eat grain early")
	person.advance(farm, DAY, 7.0, 0.624)
	check(person.activity == "Cooking" and person.meal_grams == 375 and person.stomach_kcal == 0.0, "A 375 gram meal remains pending until all 0.625 preparation hours finish")
	check(not person.eat(farm, "Oats", 1) and farm.stock.Oats == 1500, "Repeated confirmation during cooking cannot reserve another gram")
	person.advance(farm, DAY, 7.624, 0.001)
	check(is_equal_approx(person.stomach_kcal, 1458.75) and farm.stock.Oats == 1500, "Completing chosen porridge puts its 1458.75 kcal in the stomach once without spending stock again")
	check(not person.eating_requested and person.meal_crop == "" and person.meal_grams == 0, "Eating clears the pending meal so another choice becomes possible")
	person.advance(farm, DAY, 7.625, 0.5)
	check(is_equal_approx(person.stomach_kcal, 1458.75 - 0.5 * person.digestion()) and farm.stock.Oats == 1500, "Further time digests the meal without repeating its energy or stock cost")

func test_meal_boundaries() -> void:
	for recipe in [[1, 0.001666666666667, 3.78], [375, 0.625, 1417.5]]:
		var farm := Farm.new()
		farm.stock.Millet = recipe[0]
		var person = Model.new()
		check(person.eat(farm, "Millet", recipe[0]) and farm.stock.Millet == 0 and farm.stock.Barley == 10000, "A selected millet meal may reserve every available gram, including a one-gram portion")
		person.advance(farm, DAY, 6.0, recipe[1] / 2.0)
		check(person.stomach_kcal == 0.0 and person.meal_grams == recipe[0], "A partially prepared %d gram portion yields no early energy" % recipe[0])
		person.advance(farm, DAY, 6.0 + recipe[1] / 2.0, recipe[1] / 2.0)
		check(is_equal_approx(person.stomach_kcal, recipe[2]) and person.meal_grams == 0 and farm.stock.Millet == 0, "All-stock millet preparation preserves gram precision and proportional energy for %d grams" % recipe[0])

func test_invalid_meals() -> void:
	var farm := Farm.new()
	var person = Model.new()
	var before := farm.stock.duplicate()
	for crop in ["", "oats", "Oats ", "Flour", "Unknown"]:
		check(not person.eat(farm, crop, 300), "Unknown or inexact ingredient names are rejected: '%s'" % crop)
	for grams in [0, -1, 1.0, 300.0, NAN, INF, -INF, "300", null, true, false, [], {}, Vector2.ONE]:
		check(not person.eat(farm, "Oats", grams), "Meal quantities must be positive integer grams: %s" % str(grams))
	check(farm.stock == before and not person.eating_requested and person.meal_grams == 0, "Malformed meal requests create no reservation and spend no grain")
	farm.stock.Oats = 299
	check(not person.eat(farm, "Oats", 300) and farm.stock.Oats == 299 and not person.eating_requested, "Confirmation rechecks chosen stock after it becomes insufficient")
	farm.stock.Oats = 0
	person.carried_crop = "Oats"
	person.carried = 300
	check(not person.eat(farm, "Oats", 1) and person.carried == 300, "Grain in transit cannot fund a meal before entering camp stock")
	person.lean = 20.0
	check(not person.eat(farm, "Millet", 1) and farm.stock.Millet == before.Millet, "A starved body refuses new meal reservations before the next advance")

func test_meal_seed_and_cancellation() -> void:
	var farm := plowed()
	farm.stock.Oats = 1900
	var person = Model.new()
	person.order(farm, [CELL], DAY, "Sow", "Oats")
	person.advance(farm, DAY, 6.0, 0.1)
	check(person.carried == 1600 and farm.stock.Oats == 300, "A field reservation leaves only its unreserved grain available for food")
	check(not person.eat(farm, "Oats", 301) and person.eat(farm, "Oats", 300), "Food cannot spend reserved seed even when the person carries it")
	check(farm.stock.Oats == 0 and person.reserved_seed() == 1600, "Pending food and carried seed reserve distinct grams")
	person.cancel(farm)
	check(person.eating_requested and person.meal_grams == 300 and person.carried == 1600 and farm.stock.Oats == 0, "Clear jobs preserves the pending meal and returns carried seed physically")
	person.advance(farm, DAY, 6.1, 0.7)
	check(person.meal_grams == 0 and farm.stock.Oats == 1600 and person.carried == 0 and farm.stage(CELL) == "Plowed", "Returning seed and finishing a meal cannot refund its consumed ingredient or sow cancelled work")
	check(person.eat(farm, "Oats", 1), "After completing porridge another explicit portion can be chosen")

func test_unfinished_meal_death() -> void:
	for away in [false, true]:
		var farm := Farm.new()
		var person = Model.new()
		starving(person, 10.0)
		if away:
			person.position = person.home + Vector2(4500, 0)
		check(person.eat(farm, "Millet", 300), "A living person can reserve food before starvation ends preparation or travel")
		person.advance(farm, DAY, 6.0, 2.0)
		check(person.activity == "Dead" and person.advanced_hours < 0.5 and is_equal_approx(person.bmi(), Human.DEATH_BMI), "Death stops a pending meal at the limit of survival, while walking or cooking")
		check(person.meal_crop == "Millet" and person.meal_grams == 300 and farm.stock.Millet + person.meal_grams == 1800 and person.stomach == 0.0, "Unfinished meal grain remains accounted for after death and grants no output")
		var before := farm.stock.duplicate()
		var energy: float = person.glycogen
		person.cancel(farm)
		person.wake_up()
		check(not person.eat(farm, "Oats", 1) and not person.advance(farm, DAY, 8.0, 12.0), "Death rejects every further meal request and time advance")
		check(farm.stock == before and person.meal_grams == 300 and person.glycogen == energy, "Game Over cannot spend, refund or complete a pending meal")

func test_food_and_death() -> void:
	var farm := Farm.new()
	var person = Model.new()
	person.glycogen = 700.0
	var grain := farm.stored()
	person.advance(farm, DAY, 6.0, 1.0)
	check(person.activity == "Idle" and is_equal_approx(person.glycogen, 700.0 - 1.4 * person.basal()) and farm.stored() == grain, "Low energy never grants a meal or consumes grain automatically")
	person.glycogen = 700.0
	check(person.eat(farm, "Barley", 300) and farm.stock.Barley == 9700, "Confirming a meal reserves its grain before the first advance")
	person.advance(farm, DAY, 7.0, 0.25)
	check(person.activity == "Cooking" and farm.stock.Barley == 9700 and person.glycogen < 700.0, "Cooking consumes 300 g of existing grain, with no starting flour")
	check(not person.eat(farm, "Barley", 300), "Repeated Eat commands cannot queue duplicate meals")
	person.advance(farm, DAY, 7.25, 0.25)
	check(is_equal_approx(person.stomach_kcal, 1062.0) and is_equal_approx(person.glycogen, 700.0 - 0.5 * 2.1 * person.basal()) and farm.stock.Barley == 9700, "A half-hour meal fills the stomach and consumes grain exactly once")
	farm = plowed()
	for name in Farm.CROPS:
		farm.stock[name] = 0
	farm.stock.Barley = 2000
	farm.stock.Oats = 300
	person = Model.new()
	person.order(farm, [CELL], DAY, "Sow", "Barley")
	person.eat(farm, "Oats", 300)
	person.advance(farm, DAY, 6.0, 0.5)
	check(farm.stock.Barley == 0 and farm.stock.Oats == 0 and person.reserved_seed() == 2000 and is_equal_approx(person.stomach_kcal, 1167.0), "Manual meals use free cereal and never reserved sowing seed")
	farm = Farm.new()
	for name in Farm.CROPS:
		farm.stock[name] = 0
	person = Model.new()
	person.glycogen = 45.0
	check(not person.eat(farm, "Oats", 300), "A requested meal without grain is refused without creating food")
	person.advance(farm, DAY, 6.0, 1.0)
	check(person.glycogen == 0.0 and person.mass() < 65.0 and person.mass() > 64.99 and person.health == 100.0, "Once glycogen is spent, fat and muscle pay the rest of the hour without harming health yet")
	starving(person, 20.0)
	person.advance(farm, DAY, 7.0, 1.0)
	check(person.activity == "Dead" and person.health == 0.0 and person.advanced_hours < 0.5, "A body at the limit of survival dies within the hour and stops the person")
	var before := farm.stock.duplicate()
	var energy: float = person.glycogen
	check(person.order(farm, [CELL], DAY, "Plow") == 0 and not person.advance(farm, DAY, 8.0, 12.0), "A dead person refuses orders and cannot advance")
	person.cancel(farm)
	person.wake_up()
	check(not person.eat(farm, "Oats", 300) and farm.stock == before and person.glycogen == energy and person.activity == "Dead", "Eating, rest and cancellation after death create or spend no resources")

func test_subdivision() -> void:
	var a := plowed([CELL, NEIGHBOUR])
	var b := plowed([CELL, NEIGHBOUR])
	var one = Model.new()
	var frames = Model.new()
	one.glycogen = 900.0
	frames.glycogen = 900.0
	one.order(a, [CELL, NEIGHBOUR], DAY, "Sow", "Barley")
	frames.order(b, [CELL, NEIGHBOUR], DAY, "Sow", "Barley")
	one.advance(a, DAY, 6.0, 8.0)
	for i in 8 * 120:
		frames.advance(b, DAY, 6.0 + i / 120.0, 1.0 / 120.0)
	check(a.plots == b.plots and a.stock == b.stock and one.carried == frames.carried, "A long skip and half-minute frames produce the same crops and mass accounting")
	check(one.position.is_equal_approx(frames.position) and is_equal_approx(one.glycogen, frames.glycogen) and is_equal_approx(one.mass(), frames.mass()) and is_equal_approx(one.fatigue, frames.fatigue) and is_equal_approx(one.health, frames.health), "Internal minute subdivision preserves travel, food and needs across frame sizes")
	var unchanged: Vector2 = one.position
	var energy: float = one.glycogen
	check(not one.advance(a, DAY, 14.0, 0.0) and one.position == unchanged and one.glycogen == energy, "Zero elapsed time advances neither people nor farm state")

func test_meal_subdivision() -> void:
	var a := plowed([CELL, NEIGHBOUR])
	var b := plowed([CELL, NEIGHBOUR])
	var one = Model.new()
	var frames = Model.new()
	for person in [one, frames]:
		person.position = person.home + Vector2(4500, 0)
		person.glycogen = 200.0
		person.fatigue = 95.0
	one.order(a, [CELL, NEIGHBOUR], DAY, "Sow", "Barley")
	frames.order(b, [CELL, NEIGHBOUR], DAY, "Sow", "Barley")
	one.eat(a, "Oats", 359)
	frames.eat(b, "Oats", 359)
	one.advance(a, DAY, 6.0, 8.0)
	for i in 8 * 120:
		frames.advance(b, DAY, 6.0 + i / 120.0, 1.0 / 120.0)
	check(a.stock == b.stock and a.plots == b.plots and a.stock.Oats == 7641 and one.meal_grams == 0 and frames.meal_grams == 0, "Frame size cannot change a non-frame-aligned meal's reserved grams or resumed field work")
	check(one.position.is_equal_approx(frames.position) and is_equal_approx(one.glycogen, frames.glycogen) and is_equal_approx(one.mass(), frames.mass()) and is_equal_approx(one.fatigue, frames.fatigue) and is_equal_approx(one.health, frames.health), "Cooking across depleted energy and full fatigue preserves needs across frame subdivisions")
