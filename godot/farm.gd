class_name Farm
extends RefCounted
## Crop rules and plot state, kept apart from rendering. Each crop is sown in its
## own months from its own seed in the store, grows with warmth above its base
## temperature and with rain as much as it likes, dies at its frost limit and is
## harvested back into its store. Harvests leave stubble and wear out the soil,
## which recovers while land rests; stubble and dead crops go back to grass.
## Crops and numbers are tuning choices, not verified history for 1495 Moldavia.

const PLOT_AREA_M2 := 100

## Grams of each crop in store at the start, left from last year's harvest: seed
## for 25 plots each (30 of millet), and food until the first barley ripens about
## day 110. Five times less starves a careful player by day 90 in every weather
## (tests/sim_first_year.gd). Sowing a crop uses its own grain as seed.
const STARTING_STOCK := {"Barley": 50000, "Oats": 40000, "Millet": 9000, "Wheat": 37500, "Rye": 40000}
## sow: months of the year it may be sown (0 is the first month of spring, 11 the
## last of winter). base, best: °C where growth starts and where it is fastest.
## water: how much rain helps and sun dries it (1 average). ripe: days of full
## growth to ripen. frost: °C at or below which it dies. winter: must live
## through a winter before it can ripen. seed, grain: grams sown and harvested on
## a 100 m² plot, fully fertile, in a season of cloudy days. Seed
## follows medieval manor rates of 2–4 bushels an acre (130–215 kg/ha); a season's
## weather averages about 0.9 of grain, giving the 3–5-fold returns of medieval
## and 18th-century records, and millet, sown thin, over tenfold. soil: how much the
## harvest depends on fertility. wear: the fertility a harvest takes. bag: grams in a
## sack of about 70 litres, so heavier grain fills it to more. color, height: how
## the ripe crop looks (the crop shader holds one entry per crop, so adding a crop
## means resizing its arrays). kcal_per_100g: dry edible grain energy, USDA SR28;
## see docs/historical-research.md for records and processing assumptions.
const CROPS := {
	"Barley": {"kcal_per_100g": 354, "sow": [0, 1], "base": 4, "best": 18, "water": 1.0, "ripe": 60.0, "frost": -3, "winter": false, "seed": 2000, "grain": 7000, "soil": 0.8, "wear": 0.3, "bag": 45000, "color": Color(0.93, 0.8, 0.47), "height": 0.65},
	"Oats": {"kcal_per_100g": 389, "sow": [0, 1], "base": 4, "best": 18, "water": 1.5, "ripe": 75.0, "frost": -4, "winter": false, "seed": 1600, "grain": 5600, "soil": 0.5, "wear": 0.25, "bag": 32000, "color": Color(0.86, 0.83, 0.6), "height": 0.8},
	"Millet": {"kcal_per_100g": 378, "sow": [2, 3], "base": 10, "best": 26, "water": 0.4, "ripe": 50.0, "frost": 1, "winter": false, "seed": 300, "grain": 4000, "soil": 0.7, "wear": 0.3, "bag": 50000, "color": Color(0.92, 0.6, 0.18), "height": 0.6},
	"Wheat": {"kcal_per_100g": 327, "sow": [6, 7], "base": 3, "best": 20, "water": 1.0, "ripe": 110.0, "frost": -8, "winter": true, "seed": 1500, "grain": 7500, "soil": 1.0, "wear": 0.35, "bag": 55000, "color": Color(0.88, 0.67, 0.27), "height": 0.9},
	"Rye": {"kcal_per_100g": 338, "sow": [6, 7, 8], "base": 2, "best": 18, "water": 0.8, "ripe": 95.0, "frost": -16, "winter": true, "seed": 1600, "grain": 6400, "soil": 0.4, "wear": 0.25, "bag": 50000, "color": Color(0.72, 0.65, 0.47), "height": 1.1},
}
## How far a season's average watering (1 is all cloudy days) moves the harvest:
## long seasons average out their spells, so the difference is scaled up to the
## year-to-year swing of about a third seen in 18th-century harvest records.
const SEASON_SWING := 5.0
## How far a winter crop can grow before it has lived through a winter.
const BEFORE_WINTER := 0.3
## Growth multiplier per weather condition for a crop of average water need.
const WATER := {"Clear": 0.7, "Cloudy": 0.9, "Rain": 1.2, "Storm": 1.0, "Snow": 0.0}
## Days at 20°C or warmer for grass to retake stubble or dead crops. Cold days
## count less and winter not at all. Plowed land stays plowed.
const WILD_AT := 40.0
## Fertility a whole year of rest gives back, and the floor harvests wear down to.
const YEARLY_REST := 0.25
const MIN_FERTILITY := 0.1
## Index order is what the field shaders draw; a cell missing from plots is untouched grass.
const STAGES := ["Grass", "Plowed", "Sown", "Ripe", "Stubble", "Withered"]
const ACTIONS := ["Plow", "Sow", "Harvest", "Chop", "Haul wood"]
const PLOW_HOURS := 3.0
const CHOP_HOURS := 6.0
const WOOD_YIELD := 240000
const REGROW_DAYS := 2 * Calendar.DAYS_PER_YEAR

## Wood is usable dry mass, separate from grain. Values are initial game tuning.
const SHELTER_WOOD := 300000
const FUEL_PER_HOUR := 500.0
var wood := 48000
var shelter := false
var heating_enabled := true
var fire_lit := false
## Fractional grams accrued since the last whole gram was burned.
var fuel_remainder := 0.0
## Camp water in ml (grams): jars hold 40 litres; the hut adds a 100-litre rain barrel
## filled from its roof (about 10 m², so 1 mm of rain gives 10 litres).
const WATER_JARS := 40000
const RAIN_BARREL := 100000
const ROOF_CATCH := {"Rain": 40000, "Storm": 80000}
const MELTABLE_SNOW := 0.3
var water := 20000
## Ponds freeze after a hard frost and thaw above freezing; snow lies 0–1 deep.
var pond_frozen := false
var snow_cover := 0.0

## Cell -> chopping hours left, ground grams, and day cleared/last cultivated.
var woodland := {}
var wood_piles := {}
var regrowth := {}
## Cell -> plowing hours left; clearing a farmer's orders keeps the worked land.
var plowing := {}

## Crop name -> grams in store. All mass in the model is integer grams.
var stock: Dictionary = STARTING_STOCK.duplicate()
## Vector2i cell -> {"stage": one of STAGES, "crop": a CROPS name or "",
## "fertility": 0.1–1, "growth": 0–1 towards ripe for crops, or towards grass for
## stubble and dead crops, "wintered": a winter crop has lived through a winter,
## "moisture", "days": watering summed over the days the crop grew, and those days}.
var plots := {}
## Year number -> crop name -> {"sown", "frost", "harvested": plots, "seed", "gathered": grams}.
var years := {}
## Optional shared playable terrain; standalone crop simulations stay flat.
var terrain: RefCounted

func water_capacity() -> int:
	return WATER_JARS + (RAIN_BARREL if shelter else 0)

func fuel_hours() -> float:
	return maxf(0.0, wood - fuel_remainder) / FUEL_PER_HOUR

func generate_woodland(seed_value: int) -> void:
	var usable: Array[Vector2i] = []
	for x in 16:
		for y in 16:
			var cell := Vector2i(x, y)
			if terrain == null or terrain.cell_reason(cell) == "":
				usable.append(cell)
	var count := mini(floori(usable.size() * 0.25), maxi(0, usable.size() - 16))
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.24
	usable.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return noise.get_noise_2d(a.x, a.y) > noise.get_noise_2d(b.x, b.y))
	for index in count:
		woodland[usable[index]] = CHOP_HOURS

func ground_wood() -> int:
	var total := 0
	for grams: int in wood_piles.values(): total += grams
	return total

func can_camp(cell: Vector2i) -> bool:
	return not woodland.has(cell) and not wood_piles.has(cell)

## Every mutable resource and plot collection: forecast copies own them and saves store them.
const SAVED := ["stock", "plots", "years", "wood", "shelter", "heating_enabled", "fire_lit", "fuel_remainder", "woodland", "wood_piles", "regrowth", "plowing", "water", "pond_frozen", "snow_cover"]

func copy_state() -> Farm:
	var copy := Farm.new()
	copy.terrain = terrain
	for property in SAVED:
		var value: Variant = get(property)
		copy.set(property, value.duplicate(true) if value is Dictionary else value)
	return copy

## Display kilograms without losing gram precision or adding trailing zeroes.
static func kg(grams: int) -> String:
	return String.num(grams / 1000.0, 3).trim_suffix(".0")

func stage(cell: Vector2i) -> String:
	return plots[cell].stage if plots.has(cell) else "Grass"

func crop(cell: Vector2i) -> String:
	return plots[cell].crop if plots.has(cell) else ""

func growth(cell: Vector2i) -> float:
	return plots[cell].growth if plots.has(cell) else 0.0

func fertility(cell: Vector2i) -> float:
	return plots[cell].fertility if plots.has(cell) else 1.0

## Grams the plot's crop gives, or is on course to: its full yield, less on worn
## soil, and more or less as its growing days so far were wet or dry.
func harvest_yield(cell: Vector2i) -> int:
	var kind: Dictionary = CROPS[crop(cell)]
	var plot: Dictionary = plots[cell]
	var season: float = 1.0 + SEASON_SWING * (plot.moisture / plot.days - 1.0) if plot.days else 1.0
	# Real weather stays within about 0.45–1.35; a season of nothing but rain is capped.
	return maxi(1, roundi(kind.grain * lerpf(1.0, fertility(cell), kind.soil) * minf(season, 1.5)))

## A crop's store as the grams in each bag: full bags, then any part-filled one.
func bags(name: String) -> Array:
	var full: int = CROPS[name].bag
	var filled := []
	filled.resize(stock[name] / full)
	filled.fill(full)
	if stock[name] % full:
		filled.append(stock[name] % full)
	return filled

## Crops that may be sown on this day, in CROPS order.
static func sowable(day: int) -> Array:
	var month: int = day % Calendar.DAYS_PER_YEAR / Calendar.DAYS_PER_MONTH
	return CROPS.keys().filter(func(name: String) -> bool: return month in CROPS[name].sow)

## A crop's sowing months, e.g. "Spring months 1–2" or "Spring month 3 – Summer month 1".
static func sowing_window(name: String) -> String:
	var months: Array = CROPS[name].sow
	var first: int = months[0]
	var last: int = months[-1]
	if first / 3 == last / 3:
		return "%s month%s %s" % [Calendar.SEASONS[first / 3], "s" if last > first else "", str(first % 3 + 1) if last == first else "%d–%d" % [first % 3 + 1, last % 3 + 1]]
	return "%s month %d – %s month %d" % [Calendar.SEASONS[first / 3], first % 3 + 1, Calendar.SEASONS[last / 3], last % 3 + 1]

## When sowing next opens after this month and what for, e.g. "Autumn month 1 (Wheat, Rye)".
static func next_sowing(day: int) -> String:
	for ahead in range(1, 12):
		var start: int = (day / Calendar.DAYS_PER_MONTH + ahead) * Calendar.DAYS_PER_MONTH
		var crops := sowable(start)
		if not crops.is_empty():
			var date := Calendar.date(start)
			return "%s month %d (%s)" % [Calendar.SEASONS[date.season], date.month, ", ".join(crops)]
	return ""

## The one action a plot offers on this day as {"name", "reason"}; a non-empty
## reason says why it cannot be done now. Sowing uses `seed_crop`. `act` uses the
## same check.
func action(cell: Vector2i, day: int, seed_crop := "") -> Dictionary:
	if terrain != null:
		var reason: String = terrain.cell_reason(cell)
		if reason != "":
			return {"name": "Plow", "reason": reason}
	if wood_piles.has(cell):
		return {"name": "Haul wood", "reason": ""}
	if woodland.has(cell):
		return {"name": "Chop", "reason": ""}
	var season: int = Calendar.date(day).season
	match stage(cell):
		"Plowed":
			if sowable(day).is_empty():
				return {"name": "Sow", "reason": "Next sowing: " + next_sowing(day)}
			if seed_crop not in sowable(day):
				return {"name": "Sow", "reason": "%s is sown in %s" % [seed_crop, sowing_window(seed_crop)] if CROPS.has(seed_crop) else "Choose a crop to sow"}
			return {"name": "Sow", "reason": "" if stock[seed_crop] >= CROPS[seed_crop].seed else "Needs %s kg %s seed" % [kg(CROPS[seed_crop].seed), seed_crop.to_lower()]}
		"Sown":
			return {"name": "Harvest", "reason": "Not ripe yet"}
		"Ripe":
			return {"name": "Harvest", "reason": ""}
	# Grass, stubble and dead crops are plowed under.
	return {"name": "Plow", "reason": "The ground is frozen in winter" if season == 3 else ""}

## Does the plot's action; returns false and changes nothing when it is unavailable.
func act(cell: Vector2i, day: int, seed_crop := "") -> bool:
	var next := action(cell, day, seed_crop)
	if next.reason != "":
		return false
	if next.name == "Chop":
		woodland.erase(cell)
		wood_piles[cell] = WOOD_YIELD
		regrowth[cell] = day
		return true
	if next.name == "Haul wood":
		wood += wood_piles[cell]
		wood_piles.erase(cell)
		return true
	var plot: Dictionary = plots.get(cell, {"fertility": 1.0, "crop": ""})
	match next.name:
		"Plow":
			plot.stage = "Plowed"
			plot.crop = ""
			plowing.erase(cell)
		"Sow":
			var kind: Dictionary = CROPS[seed_crop]
			stock[seed_crop] -= kind.seed
			record(day, seed_crop).sown += 1
			record(day, seed_crop).seed += kind.seed
			plot.stage = "Sown"
			plot.crop = seed_crop
			plot.wintered = false
			plot.moisture = 0.0
			plot.days = 0
		"Harvest":
			var gathered := harvest_yield(cell)
			stock[plot.crop] += gathered
			record(day, plot.crop).harvested += 1
			record(day, plot.crop).gathered += gathered
			plot.stage = "Stubble"
			plot.fertility = maxf(plot.fertility - CROPS[plot.crop].wear, MIN_FERTILITY)
	plot.growth = 0.0
	plots[cell] = plot
	return true

## Does `name` (any action when empty) on every given plot that allows it now,
## in order, so sowing stops when that crop's seed runs out. Returns the plots worked.
func work(cells: Array, day: int, name := "", seed_crop := "") -> int:
	var done := 0
	for cell in cells:
		if name in ["", action(cell, day, seed_crop).name] and act(cell, day, seed_crop):
			done += 1
	return done

## What `work` would do, without doing it: {"plots": worked, "grain": change in grams stored}.
func preview(cells: Array, day: int, name := "", seed_crop := "") -> Dictionary:
	var trial := copy_state()
	var done := 0
	var to_haul := 0
	var counted := {}
	for cell in cells:
		var next := trial.action(cell, day, seed_crop)
		if name not in ["", next.name] or next.reason != "": continue
		var grams: int = WOOD_YIELD if next.name == "Chop" else trial.wood_piles.get(cell, 0) if next.name == "Haul wood" else 0
		if trial.act(cell, day, seed_crop):
			done += 1
			if not counted.has(cell): to_haul += grams
			if grams > 0: counted[cell] = true
	return {"plots": done, "grain": trial.stored() - stored(), "wood": to_haul}

## All grain in store, in grams.
func stored() -> int:
	return stock.values().reduce(func(sum: int, amount: int) -> int: return sum + amount, 0)

## How well a day's weather waters a crop, by how much it needs water.
static func watering(name: String, condition: String) -> float:
	return maxf(1.0 + (WATER[condition] - 1.0) * CROPS[name].water, 0.0)

## How much one day of this weather grows a crop, as a share of its ripening.
static func daily_growth(name: String, weather: Dictionary) -> float:
	var kind: Dictionary = CROPS[name]
	var warmth := clampf(float(weather.temperature - kind.base) / (kind.best - kind.base), 0.0, 1.0)
	return warmth * watering(name, weather.condition) / kind.ripe

## One day of weather: frost kills crops at their limit, warmth and rain grow
## them, growing days count towards the harvest's size, warmth lets grass back
## onto stubble and dead crops, and land without a crop regains fertility.
func grow(weather: Dictionary, day: int) -> void:
	if weather.condition == "Snow":
		snow_cover = 1.0
	elif weather.temperature > 2:
		snow_cover = maxf(snow_cover - 0.02 * weather.temperature, 0.0)
	if weather.temperature <= -3:
		pond_frozen = true
	elif weather.temperature >= 2:
		pond_frozen = false
	if shelter:
		water = mini(water + ROOF_CATCH.get(weather.condition, 0), water_capacity())
	for cell in regrowth.keys():
		if stage(cell) != "Grass" or (terrain != null and terrain.cell_reason(cell) == "Camp") or wood_piles.has(cell):
			regrowth[cell] = day
		elif day - regrowth[cell] >= REGROW_DAYS:
			woodland[cell] = CHOP_HOURS
			plowing.erase(cell)
			regrowth.erase(cell)
	var winter: bool = Calendar.date(day).season == 3
	var warmth: float = clampf((weather.temperature - 5) / 15.0, 0.0, 1.0)
	for plot in plots.values():
		match plot.stage:
			"Sown", "Ripe":
				var kind: Dictionary = CROPS[plot.crop]
				if weather.temperature <= kind.frost:
					plot.stage = "Withered"
					plot.growth = 0.0
					record(day, plot.crop).frost += 1
				elif plot.stage == "Sown":
					plot.wintered = plot.get("wintered", false) or winter
					var limit: float = BEFORE_WINTER if kind.winter and not plot.wintered else 1.0
					var step := daily_growth(plot.crop, weather)
					if step > 0.0 and plot.growth < limit:
						# A cloudy day counts as average; wet days fill the grain, dry ones shrink it.
						plot.moisture += watering(plot.crop, weather.condition) / watering(plot.crop, "Cloudy")
						plot.days += 1
					plot.growth = minf(plot.growth + step, maxf(limit, plot.growth))
					if plot.growth == 1.0:
						plot.stage = "Ripe"
			"Stubble", "Withered":
				plot.growth += warmth / WILD_AT
				if plot.growth >= 1.0:
					plot.stage = "Grass"
					plot.growth = 0.0
		if plot.stage not in ["Sown", "Ripe"]:
			plot.fertility = minf(plot.fertility + YEARLY_REST / Calendar.DAYS_PER_YEAR, 1.0)

## The record of one crop for the year containing `day`, started on first use.
func record(day: int, name: String) -> Dictionary:
	var year: Dictionary = years.get_or_add(Calendar.date(day).year, {})
	return year.get_or_add(name, {"sown": 0, "frost": 0, "harvested": 0, "seed": 0, "gathered": 0})

## A year's results summed over crops.
func totals(year: int) -> Dictionary:
	var sum := {"sown": 0, "frost": 0, "harvested": 0, "seed": 0, "gathered": 0}
	for result in years.get(year, {}).values():
		for key in sum:
			sum[key] += result[key]
	return sum
