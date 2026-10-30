extends SceneTree

const Terrain := preload("res://terrain.gd")
const Exposure := preload("res://exposure.gd")

var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func _initialize() -> void:
	call_deferred("run")

## A farmer at the camp of a seeded Hills field.
func field_farmer(farm: Farm) -> Human:
	farm.terrain = Terrain.new(7, Terrain.PRESETS.Hills)
	farm.heating_enabled = false
	var person := Human.new()
	person.terrain = farm.terrain
	person.home = farm.terrain.camp / person.terrain_scale
	person.position = person.home
	return person

## Advances until no water work is left; returns the hours it took.
func until_done(person: Human, farm: Farm, limit := 48.0) -> float:
	var hours := 0.0
	while hours < limit and (not person.queue.is_empty() or not person.job.is_empty() or person.carried > 0):
		person.advance(farm, 40, fposmod(6.0 + hours, 24.0), 0.25)
		hours += 0.25
	return hours

func run() -> void:
	# With no water at all, a resting farmer keeps full health for a day, then dies of thirst in about three.
	var farm := Farm.new()
	farm.water = 0
	var person := Human.new()
	person.skin = 0
	var hours := 0
	var hurt := -1
	while person.activity != "Dead" and hours < 200:
		person.advance(farm, 0, fposmod(hours, 24.0), 1.0)
		hours += 1
		if hurt < 0 and person.health < 100.0: hurt = hours
	check(hurt >= 24 and hurt <= 30 and hours >= 60 and hours <= 70, "Thirst harms from 4%% of body mass after a day and kills at 10%% in under three days (%d h, %d h)" % [hurt, hours])
	check(person.message.contains("Dehydration") and is_equal_approx(person.dehydration, Human.DEATH_DRY * person.mass()), "Death comes exactly at the limit and names dehydration")

	# At home the farmer drinks from the store and keeps the skin full.
	farm = Farm.new()
	person = Human.new()
	person.skin = 500
	person.advance(farm, 0, 6.0, 24.0)
	check(person.dehydration < 0.003 and person.skin == Human.SKIN and absi(20000 - 1500 - farm.water - 2400) <= 2, "A day at home drinks about 2.4 L from the store and refills the skin (%d ml left)" % farm.water)

	# Away from camp the farmer sips from the skin once a quarter litre is missing.
	farm = Farm.new()
	person = Human.new()
	person.position = person.home + Vector2(30, 0)
	person.advance(farm, 0, 6.0, 5.0)
	check(person.skin < Human.SKIN and person.dehydration < Human.SIP + 0.01 and farm.water == 20000, "Away from camp the farmer sips from the skin, not the store")

	# Sweat rises with heat and effort.
	var exposure := Exposure.new()
	var hot: Dictionary = exposure.rates({"temperature": 30.0, "wind": 1.0, "sunlight": 0.5, "condition": "Clear"}, Human.EFFORT.Plow, 65.0, 65.0, false, false)
	var cold: Dictionary = exposure.rates({"temperature": 0.0, "wind": 1.0, "sunlight": 0.0, "condition": "Clear"}, Human.EFFORT.Idle, 65.0, 65.0, false, false)
	check(hot.sweat > 0.8 and hot.sweat < 1.5 and cold.sweat == 0.0, "Hard work in summer heat sweats about a litre an hour; idling in the cold sweats nothing")

	# The camp's nearest pond bank is reachable and the store fills trip by trip.
	farm = Farm.new()
	farm.water = 0
	person = field_farmer(farm)
	check(farm.terrain.bank != Vector2.INF and not farm.terrain.path(farm.terrain.camp, farm.terrain.bank).is_empty(), "The camp has a reachable bank beside a pond")
	var plowed := person.order(farm, [Vector2i(8, 8), Vector2i(9, 8)], 40, "Plow")
	person.dehydration = 1.0
	check(person.fetch_water(farm) == 3 and person.queue[0].action == "Fetch water" and (plowed == 0 or person.queue[-1].action == "Plow"), "Water trips fill the 40 L store and go before queued field work")
	person.advance(farm, 40, 6.0, 0.01)
	person.queue = person.queue.filter(func(job: Dictionary) -> bool: return job.action != "Plow")
	var first := until_done(person, farm)
	check(farm.water > Farm.WATER_JARS - 500 and farm.water <= Farm.WATER_JARS and person.carried == 0, "Three 15 L trips fill the jars without overflowing them (%d ml)" % farm.water)
	farm.water = Farm.WATER_JARS
	check(person.fetch_water(farm) == 0 and person.message.contains("full"), "A full store refuses more trips")

	# A frozen pond adds the time to break the ice.
	farm.water = Farm.WATER_JARS - Human.BAG_CAPACITY
	person.fetch_water(farm)
	var thawed := until_done(person, farm)
	farm.water = Farm.WATER_JARS - Human.BAG_CAPACITY
	farm.pond_frozen = true
	person.fetch_water(farm)
	var frozen := until_done(person, farm)
	check(first > thawed and is_equal_approx(frozen - thawed, 0.5), "Breaking the ice adds half an hour a trip (%.2f h vs %.2f h)" % [frozen, thawed])

	# Lying snow melts into water over the heating fire, and not without it.
	farm = Farm.new()
	farm.water = 30000
	person = Human.new()
	check(person.melt_snow(farm) == 0 and person.message.contains("snow"), "Without lying snow there is nothing to melt")
	farm.snow_cover = 1.0
	check(person.melt_snow(farm) == 1, "Melting fills the store in 10 L batches")
	var wood := farm.wood
	person.advance(farm, 300, 10.0, 2.1)
	check(farm.water > 39000 and person.queue.is_empty() and person.job.is_empty() and farm.wood < wood, "Two hours by the fire melt 10 L, burning heating wood (%d ml)" % farm.water)
	farm.heating_enabled = false
	farm.water = 0
	person.melt_snow(farm)
	person.advance(farm, 300, 12.0, 1.0)
	check(person.queue.is_empty() and person.job.is_empty() and person.message.contains("fire"), "Without the fire, melting snow stops and explains why")

	# The hut's roof fills a rain barrel; frost freezes the pond until a thaw.
	farm = Farm.new()
	farm.water = 0
	farm.grow({"condition": "Rain", "temperature": 10}, 50)
	check(farm.water == 0, "An open camp collects no rain")
	farm.shelter = true
	for rainy in 4:
		farm.grow({"condition": "Storm", "temperature": 15}, 51 + rainy)
	check(farm.water == Farm.WATER_JARS + Farm.RAIN_BARREL, "Storms fill the barrel and jars up to 140 L")
	farm.grow({"condition": "Clear", "temperature": -4}, 60)
	farm.grow({"condition": "Clear", "temperature": 0}, 61)
	check(farm.pond_frozen, "A hard frost freezes the pond and it stays frozen near zero")
	farm.grow({"condition": "Clear", "temperature": 3}, 62)
	check(not farm.pond_frozen, "A thaw opens the pond")

	# Forecasts drink like the real day does.
	farm = Farm.new()
	farm.water = 0
	person = Human.new()
	person.skin = 0
	person.dehydration = 2.4
	var forecast := person.sleep_prediction(10.0, farm, 0, 22.0)
	person.sleep(10.0)
	person.advance(farm, 0, 22.0, 2.0)
	person.advance(farm, 1, 0.0, 8.0)
	check(not forecast.is_empty() and forecast.health < 100.0 and is_equal_approx(forecast.health, person.health), "Sleep forecasts include thirst damage when the store is dry (%.2f vs %.2f)" % [forecast.get("health", -1.0), person.health])

	# Porridge needs the camp's water and hydrates the farmer.
	farm = Farm.new()
	farm.water = 1000
	person = Human.new()
	person.dehydration = 1.0
	check(not person.eat(farm, "Barley", 300) and person.message.contains("water"), "Porridge cannot cook without 1.2 L of water")
	farm.water = 1200
	check(person.eat(farm, "Barley", 300) and farm.water == 0, "Cooking reserves the porridge's water")
	person.cancel_meal(farm)
	check(farm.water == 1200 and person.meal_water == 0, "Cancelling a meal returns its water")
	person.eat(farm, "Barley", 300)
	person.advance(farm, 0, 8.0, 1.0)
	check(not person.eating_requested and person.dehydration < 0.1, "Eating porridge quenches thirst")

	if failures.is_empty():
		print("PASS: water loss, thirst damage and death, drinking at home and from the skin, sweat in heat, pond banks, fetch trips before field work, full store, pond ice, melting snow by the fire, rain barrel, freezing and forecasts")
	quit(0 if failures.is_empty() else 1)
