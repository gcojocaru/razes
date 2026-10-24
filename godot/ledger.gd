extends "res://hud_window.gd"
## Right-side farm ledger, toggled with L, in three tabs: Fields (what stands on the
## land now and the kg it is on course for), Years (each year's results, newest
## first) and Crops (what each needs).

const TABS := ["Fields", "Years", "Crops"]

var tab := "Fields"
## What the ledger last showed, so switching tabs can redraw it.
var _farm: Farm
var _day := 0

func _init() -> void:
	super("Ledger", "L", 580, 320)
	anchor_left = 1.0
	anchor_right = 1.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_right = -14
	offset_top = 110
	var group := ButtonGroup.new()
	for name in TABS:
		var button := Button.new()
		button.text = name
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = name == tab
		button.pressed.connect(func() -> void:
			tab = name
			show_ledger(_farm, _day))
		_header_button(button)

## Rebuilds the open tab from the farm on this day.
func show_ledger(farm: Farm, day: int) -> void:
	_farm = farm
	_day = day
	_clear()
	match tab:
		"Fields": _show_fields(farm)
		"Years": _show_years(farm, day)
		"Crops": _show_crops()
	_fit()

func _show_fields(farm: Farm) -> void:
	var by_crop := {}
	var land := {}
	var soil := 0.0
	for cell in farm.plots:
		var stage := farm.stage(cell)
		if stage in ["Sown", "Ripe"]:
			by_crop.get_or_add(farm.crop(cell), []).append(cell)
		elif stage != "Grass":
			land[stage] = land.get(stage, 0) + 1
		if stage != "Grass":
			soil += farm.fertility(cell)
	var widths := [12, 64, 150, 90, 50, 70]
	_row(["", "Crop", "Plots", "Growth", "Soil", "Harvest"], widths, false, TimeHud.GOLD)
	if by_crop.is_empty():
		_row(["", "Nothing growing", "", "", "", ""], widths, true, MUTED)
	for name in Farm.CROPS:
		if not by_crop.has(name):
			continue
		var cells: Array = by_crop[name]
		var ripe := cells.filter(func(cell: Vector2i) -> bool: return farm.stage(cell) == "Ripe").size()
		var growth := 0.0
		var crop_soil := 0.0
		var harvest := 0
		for cell in cells:
			growth += farm.growth(cell)
			crop_soil += farm.fertility(cell)
			harvest += farm.harvest_yield(cell)
		var count := "%d growing" % (cells.size() - ripe) + ("  ·  %d ripe" % ripe if ripe else "")
		_row([Farm.CROPS[name].color, name, count, _bar(growth / cells.size(), Farm.CROPS[name].color, 90), "%d%%" % roundi(crop_soil / cells.size() * 100), "%d kg" % harvest], widths, body.get_child_count() % 2 == 1, TimeHud.PARCHMENT, "Harvest: what the plots give if harvested when ripe, from their soil and the weather so far")
	var worked: int = farm.plots.values().filter(func(plot: Dictionary) -> bool: return plot.stage != "Grass").size()
	var summary := PackedStringArray()
	for stage in ["Plowed", "Stubble", "Withered"]:
		if land.has(stage):
			summary.append("%s %d" % ["Dead" if stage == "Withered" else stage, land[stage]])
	_row(["", "Land", "  ·  ".join(summary) if summary else "No idle fields", "", "%d%%" % roundi(soil / worked * 100) if worked else "", ""], widths, false, MUTED)

func _show_years(farm: Farm, day: int) -> void:
	var current: int = Calendar.date(day).year
	var nets := []
	for year in range(1, current + 1):
		var sum := farm.totals(year)
		nets.append(sum.gathered - sum.seed)
	var largest: float = maxf(1.0, nets.map(func(net: int) -> int: return absi(net)).max())
	var widths := [62, 44, 40, 70, 84, 56, 70]
	_row(["Year", "Sown", "Lost", "Harvested", "Gathered kg", "Net kg", ""], widths, false, TimeHud.GOLD)
	for year in range(current, 0, -1):
		var sum := farm.totals(year)
		var net: int = nets[year - 1]
		var detail := PackedStringArray()
		for name in farm.years.get(year, {}):
			var result: Dictionary = farm.years[year][name]
			detail.append("%s: %d sown, %d lost, %d harvested, %d kg" % [name, result.sown, result.frost, result.harvested, result.gathered])
		var bar := _bar(absf(net) / largest, Color(0.55, 0.75, 0.35) if net >= 0 else Color(0.85, 0.35, 0.25), 70)
		_row(["%d%s" % [year, " now" if year == current else ""], sum.sown, sum.frost, sum.harvested, sum.gathered, "%+d" % net, bar], widths, (current - year) % 2 == 1, TimeHud.PARCHMENT, "\n".join(detail) if detail else "Nothing sown or harvested")

func _show_crops() -> void:
	var widths := [12, 54, 210, 120, 46, 84]
	_row(["", "Crop", "Sow", "Grows", "Frost", "Kg a plot"], widths, false, TimeHud.GOLD)
	for name in Farm.CROPS:
		var kind: Dictionary = Farm.CROPS[name]
		var water := "likes rain" if kind.water > 1.2 else ("hardy in drought" if kind.water < 0.6 else "")
		var tooltip := "Grows above %d°C, best at %d°C%s. Harvest takes %d%% of the soil's fertility; poor soil costs it %s. Kg sown and harvested on a fertile plot in an average season; a bag holds %d kg." % [kind.base, kind.best, (", " + water) if water else "", roundi(kind.wear * 100), "little" if kind.soil < 0.6 else "much", kind.bag]
		_row([kind.color, name, Farm.sowing_window(name), "%d days%s" % [kind.ripe, " + winter" if kind.winter else ""], "%d°C" % kind.frost, "%d → %d" % [kind.seed, kind.grain]], widths, body.get_child_count() % 2 == 0, TimeHud.PARCHMENT, tooltip)
