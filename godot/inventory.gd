extends "res://hud_window.gd"
## Left-side inventory, toggled with I: the store as a grid of slots, each holding
## one bag of a crop's grain (Farm.bags), and the total. The Stats button adds each
## crop's kg, bags, the plots it seeds and what this year has sown and harvested.

const COLUMNS := 7
## A slot is a square for its bag over a strip for its kg.
const SLOT := 60
const LABEL := 16
const GAP := 4

## Whether the per-crop stats show under the bags.
var stats := false
var _slot_box := TimeHud.box(Color(0, 0, 0, 0.35), Color(TimeHud.GOLD, 0.25), 4, 1, Vector2.ZERO)
var _hover_box := TimeHud.box(Color(TimeHud.GOLD, 0.12), TimeHud.GOLD, 4, 1, Vector2.ZERO)
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
		for kg in farm.bags(crop):
			grid.add_child(_slot(crop, kg, grid.get_child_count()))
	var bags := grid.get_child_count()
	# Empty slots fill out the last row, and at least two rows show.
	for i in maxi(2 * COLUMNS, ceili(bags / float(COLUMNS)) * COLUMNS) - bags:
		grid.add_child(_slot("", 0, 0))
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
				year.append("−%d sown" % result.seed)
			if result.gathered:
				year.append("+%d harvested" % result.gathered)
			_row([kind.color, crop, "%d kg" % amount, farm.bags(crop).size(), "%d plot%s" % [plots, "" if plots == 1 else "s"], "  ·  ".join(year) if year else "—"], widths, body.get_child_count() % 2 == 1, TimeHud.PARCHMENT, "A bag holds %d kg of %s; %d kg sows one plot" % [kind.bag, crop.to_lower(), kind.seed])
	_row(["", "Total", "%d kg" % farm.stored(), "%d bag%s" % [bags, "" if bags == 1 else "s"], "", ""], widths, false, MUTED)
	_fit()

## One slot holding a bag of `kg` of `crop`, the `number`th bag shown, or an empty
## slot when `crop` is "". The bag is a 3D render from bag_icons.gd.
func _slot(crop: String, kg: int, number: int) -> Control:
	var slot := Control.new()
	slot.custom_minimum_size = Vector2(SLOT, SLOT + LABEL)
	slot.mouse_filter = Control.MOUSE_FILTER_PASS
	slot.draw.connect(_draw_slot.bind(slot, crop, kg))
	slot.mouse_entered.connect(slot.queue_redraw)
	slot.mouse_exited.connect(slot.queue_redraw)
	if crop == "":
		return slot
	var kind: Dictionary = Farm.CROPS[crop]
	slot.tooltip_text = "%s: %d kg%s" % [crop, kg, " (full bag)" if kg == kind.bag else " of %d" % kind.bag]
	var bag := TextureRect.new()
	bag.texture = _icons.icon(crop, float(kg) / kind.bag, number)
	bag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bag.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	bag.material = _premultiplied
	bag.size = Vector2(SLOT, SLOT)
	bag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(bag)
	return slot

## The slot's frame, lit on hover, and the bag's kg: gold when part-filled.
func _draw_slot(slot: Control, crop: String, kg: int) -> void:
	var rect := Rect2(Vector2.ZERO, slot.size)
	slot.draw_style_box(_hover_box if rect.has_point(slot.get_local_mouse_position()) else _slot_box, rect)
	if crop:
		slot.draw_string(_serif, Vector2(0, slot.size.y - 4), "%d kg" % kg, HORIZONTAL_ALIGNMENT_CENTER, slot.size.x, 13, TimeHud.PARCHMENT if kg == Farm.CROPS[crop].bag else TimeHud.GOLD)
