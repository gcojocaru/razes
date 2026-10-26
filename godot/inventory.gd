extends "res://hud_window.gd"
## Left-side inventory, toggled with I: the store as a grid of slots, each holding
## one bag of a crop's grain (Farm.bags), and the total. The Stats button adds each
## crop's kg, bags, the plots it seeds and what this year has sown and harvested.

const COLUMNS := 7
const GrainSlot := preload("res://grain_slot.gd")
## A slot is a square for its bag over a strip for its kg.
const SLOT := GrainSlot.SIZE
const GAP := 4

## Whether the per-crop stats show under the bags.
var stats := false
var _icons := preload("res://bag_icons.gd").new()
var _premultiplied := CanvasItemMaterial.new()
## What the inventory last showed, so toggling stats can redraw it.
var _farm: Farm
var _day := 0

func _init() -> void:
	super("Inventory", "I", COLUMNS * (SLOT + GAP) - GAP, 460)
	offset_left = 14
	offset_top = 110
	add_child(_icons)
	_premultiplied.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	var button := Button.new()
	button.text = "Stats"
	button.tooltip_text = "Each crop's kg, bags, seed and this year"
	button.toggle_mode = true
	button.toggled.connect(func(on: bool) -> void:
		stats = on
		show_inventory(_farm, _day))
	_header_button(button)

## Rebuilds the bags and rows from the farm's store on this day.
func show_inventory(farm: Farm, day: int) -> void:
	_farm = farm
	_day = day
	_clear()
	var grid := GridContainer.new()
	grid.columns = COLUMNS
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	body.add_child(grid)
	for crop in Farm.CROPS:
		for grams in farm.bags(crop):
			grid.add_child(_slot(crop, grams, grid.get_child_count()))
	var bags := grid.get_child_count()
	# Empty slots fill out the last row, and at least two rows show.
	for i in maxi(2 * COLUMNS, ceili(bags / float(COLUMNS)) * COLUMNS) - bags:
		grid.add_child(_slot("", 0, 0))
	body.add_child(_label("Wood: %s kg deposited · %s kg on the ground" % [Farm.kg(farm.wood), Farm.kg(farm.ground_wood())], TimeHud.GOLD))
	var gap := Control.new()
	gap.custom_minimum_size.y = 10
	body.add_child(gap)

	var widths := [12, 52, 58, 44, 56, 150]
	if stats:
		_row(["", "Crop", "Store", "Bags", "Seeds", "This year, kg"], widths, false, TimeHud.GOLD)
		for crop in Farm.CROPS:
			var kind: Dictionary = Farm.CROPS[crop]
			var amount: int = farm.stock[crop]
			var result: Dictionary = farm.years.get(Calendar.date(day).year, {}).get(crop, {"seed": 0, "gathered": 0})
			var plots: int = amount / kind.seed
			var year := PackedStringArray()
			if result.seed:
				year.append("−%s sown" % Farm.kg(result.seed))
			if result.gathered:
				year.append("+%s harvested" % Farm.kg(result.gathered))
			_row([kind.color, crop, "%s kg" % Farm.kg(amount), farm.bags(crop).size(), "%d plot%s" % [plots, "" if plots == 1 else "s"], "  ·  ".join(year) if year else "—"], widths, body.get_child_count() % 2 == 1, TimeHud.PARCHMENT, "A bag holds %s kg of %s; %s kg sows one %d m² plot" % [Farm.kg(kind.bag), crop.to_lower(), Farm.kg(kind.seed), Farm.PLOT_AREA_M2])
	_row(["", "Total", "%s kg" % Farm.kg(farm.stored()), "%d bag%s" % [bags, "" if bags == 1 else "s"], "", ""], widths, false, MUTED)
	_fit()

## One slot holding a bag of `grams` of `crop`, the `number`th bag shown, or an empty
## slot when `crop` is "". The bag is a 3D render from bag_icons.gd.
func _slot(crop: String, grams: int, number: int) -> Control:
	return GrainSlot.new(crop, grams, number, _icons, _premultiplied)
