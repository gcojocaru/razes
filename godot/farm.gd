class_name Farm
extends RefCounted
## Crop rules and plot state, kept apart from rendering. Each crop is sown in its
## own months from its own seed in the store, grows with warmth above its base
## temperature and with rain as much as it likes, dies at its frost limit and is
## harvested back into its store. Harvests leave stubble and wear out the soil,
## which recovers while land rests; stubble and dead crops go back to grass.
## Crops and numbers are tuning choices, not verified history for 1495 Moldavia.

## Grain of each crop in store at the start; sowing a crop uses its own grain as seed.
const STARTING_STOCK := {"Barley": 10, "Oats": 10, "Millet": 6, "Wheat": 10, "Rye": 10}
## sow: months of the year it may be sown (0 is the first month of spring, 11 the
## last of winter). base, best: °C where growth starts and where it is fastest.
## water: how much rain helps and sun dries it (1 average). ripe: days of full
## growth to ripen. frost: °C at or below which it dies. winter: must live
## through a winter before it can ripen. seed, grain: sown and harvested on fully
## fertile soil. soil: how much the harvest depends on fertility. wear: the
## fertility a harvest takes. color, height: how the ripe crop looks (the crop
## shader holds one entry per crop, so adding a crop means resizing its arrays).
const CROPS := {
	"Barley": {"sow": [0, 1], "base": 4, "best": 18, "water": 1.0, "ripe": 60.0, "frost": -3, "winter": false, "seed": 2, "grain": 7, "soil": 0.8, "wear": 0.3, "color": Color(0.93, 0.8, 0.47), "height": 0.65},
	"Oats": {"sow": [0, 1], "base": 4, "best": 18, "water": 1.5, "ripe": 75.0, "frost": -4, "winter": false, "seed": 2, "grain": 7, "soil": 0.5, "wear": 0.25, "color": Color(0.86, 0.83, 0.6), "height": 0.8},
	"Millet": {"sow": [2, 3], "base": 10, "best": 26, "water": 0.4, "ripe": 50.0, "frost": 1, "winter": false, "seed": 1, "grain": 6, "soil": 0.7, "wear": 0.3, "color": Color(0.92, 0.6, 0.18), "height": 0.6},
	"Wheat": {"sow": [6, 7], "base": 3, "best": 20, "water": 1.0, "ripe": 110.0, "frost": -8, "winter": true, "seed": 2, "grain": 11, "soil": 1.0, "wear": 0.35, "color": Color(0.88, 0.67, 0.27), "height": 0.9},
	"Rye": {"sow": [6, 7, 8], "base": 2, "best": 18, "water": 0.8, "ripe": 95.0, "frost": -16, "winter": true, "seed": 2, "grain": 8, "soil": 0.4, "wear": 0.25, "color": Color(0.72, 0.65, 0.47), "height": 1.1},
}
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
const ACTIONS := ["Plow", "Sow", "Harvest"]

## Crop name -> grain in store.
var stock: Dictionary = STARTING_STOCK.duplicate()
## Vector2i cell -> {"stage": one of STAGES, "crop": a CROPS name or "",
## "fertility": 0.1–1, "growth": 0–1 towards ripe for crops, or towards grass for
## stubble and dead crops, "wintered": a winter crop has lived through a winter}.
var plots := {}
## Year number -> crop name -> {"sown", "frost", "harvested": plots, "seed", "gathered": grain}.
var years := {}

func stage(cell: Vector2i) -> String:
	return plots[cell].stage if plots.has(cell) else "Grass"

func crop(cell: Vector2i) -> String:
	return plots[cell].crop if plots.has(cell) else ""

func growth(cell: Vector2i) -> float:
	return plots[cell].growth if plots.has(cell) else 0.0

func fertility(cell: Vector2i) -> float:
	return plots[cell].fertility if plots.has(cell) else 1.0

func harvest_yield(cell: Vector2i) -> int:
	var kind: Dictionary = CROPS[crop(cell)]
	return maxi(1, roundi(kind.grain * lerpf(1.0, fertility(cell), kind.soil)))

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
	var season: int = Calendar.date(day).season
	match stage(cell):
		"Plowed":
			if sowable(day).is_empty():
				return {"name": "Sow", "reason": "Next sowing: " + next_sowing(day)}
			if seed_crop not in sowable(day):
				return {"name": "Sow", "reason": "%s is sown in %s" % [seed_crop, sowing_window(seed_crop)] if CROPS.has(seed_crop) else "Choose a crop to sow"}
			return {"name": "Sow", "reason": "" if stock[seed_crop] >= CROPS[seed_crop].seed else "Needs %d %s seed" % [CROPS[seed_crop].seed, seed_crop.to_lower()]}
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
	var plot: Dictionary = plots.get(cell, {"fertility": 1.0, "crop": ""})
	match next.name:
		"Plow":
			plot.stage = "Plowed"
			plot.crop = ""
		"Sow":
			var kind: Dictionary = CROPS[seed_crop]
			stock[seed_crop] -= kind.seed
			record(day, seed_crop).sown += 1
			record(day, seed_crop).seed += kind.seed
			plot.stage = "Sown"
			plot.crop = seed_crop
			plot.wintered = false
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

## What `work` would do, without doing it: {"plots": worked, "grain": change in grain stored}.
func preview(cells: Array, day: int, name := "", seed_crop := "") -> Dictionary:
	var trial := Farm.new()
	trial.stock = stock.duplicate()
	trial.plots = plots.duplicate(true)
	var done := trial.work(cells, day, name, seed_crop)
	return {"plots": done, "grain": trial.stored() - stored()}

## All grain in store.
func stored() -> int:
	return stock.values().reduce(func(sum: int, amount: int) -> int: return sum + amount, 0)

## How much one day of this weather grows a crop, as a share of its ripening.
static func daily_growth(name: String, weather: Dictionary) -> float:
	var kind: Dictionary = CROPS[name]
	var warmth := clampf(float(weather.temperature - kind.base) / (kind.best - kind.base), 0.0, 1.0)
	return warmth * maxf(1.0 + (WATER[weather.condition] - 1.0) * kind.water, 0.0) / kind.ripe

## One day of weather: frost kills crops at their limit, warmth and rain grow
## them, warmth lets grass back onto stubble and dead crops, and land without a
## crop regains fertility.
func grow(weather: Dictionary, day: int) -> void:
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
					plot.growth = minf(plot.growth + daily_growth(plot.crop, weather), maxf(limit, plot.growth))
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
