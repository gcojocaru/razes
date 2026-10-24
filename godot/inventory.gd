extends "res://hud_window.gd"
## Left-side inventory, toggled with I: each crop's grain in store, how many plots
## that seeds, and what this year has sown and harvested of it.

func _init() -> void:
	super("Inventory", "I", 440, 300)
	offset_left = 14
	offset_top = 110

## Rebuilds the rows from the farm's store on this day.
func show_inventory(farm: Farm, day: int) -> void:
	_clear()
	var widths := [12, 64, 70, 84, 140]
	_row(["", "Crop", "In store", "Seeds", "This year"], widths, false, TimeHud.GOLD)
	var largest: float = maxf(1.0, farm.stock.values().max())
	for crop in Farm.CROPS:
		var kind: Dictionary = Farm.CROPS[crop]
		var amount: int = farm.stock[crop]
		var result: Dictionary = farm.years.get(Calendar.date(day).year, {}).get(crop, {"seed": 0, "gathered": 0})
		var store := HBoxContainer.new()
		store.add_child(_label(str(amount)))
		store.add_child(_bar(amount / largest, kind.color, 36))
		var seeds := "%d plot%s" % [amount / kind.seed, "" if amount / kind.seed == 1 else "s"]
		var year := PackedStringArray()
		if result.seed:
			year.append("−%d sown" % result.seed)
		if result.gathered:
			year.append("+%d harvested" % result.gathered)
		_row([kind.color, crop, store, seeds, "  ·  ".join(year) if year else "—"], widths, body.get_child_count() % 2 == 0, TimeHud.PARCHMENT, "%d grain sows one plot; up to %d come back" % [kind.seed, kind.grain])
	_row(["", "Total", str(farm.stored()), "", ""], widths, false, MUTED)
	_fit()
