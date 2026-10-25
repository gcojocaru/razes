extends Button
## Shared grain-bag slot; inventory leaves it unfocused, food selection enables it.

const TimeHud := preload("res://time_hud.gd")
const SIZE := 60
const LABEL := 16

var crop: String
var grams: int
var _font := TimeHud.serif_font()

func _init(crop_name: String, mass: int, number: int, icons: Node, bag_material: CanvasItemMaterial) -> void:
	crop = crop_name
	grams = mass
	custom_minimum_size = Vector2(SIZE, SIZE + LABEL)
	focus_mode = Control.FOCUS_NONE
	disabled = crop == ""
	var normal := TimeHud.box(Color(0, 0, 0, 0.35), Color(TimeHud.GOLD, 0.25), 4, 1, Vector2.ZERO)
	var highlighted := TimeHud.box(Color(TimeHud.GOLD, 0.12), TimeHud.GOLD, 4, 1, Vector2.ZERO)
	for style in ["normal", "disabled"]:
		add_theme_stylebox_override(style, normal)
	for style in ["hover", "pressed", "hover_pressed", "focus"]:
		add_theme_stylebox_override(style, highlighted)
	if crop == "":
		return
	var full: int = Farm.CROPS[crop].bag
	tooltip_text = "%s: %s kg%s" % [crop, Farm.kg(grams), " (full bag)" if grams == full else " of %s" % Farm.kg(full)]
	tooltip_text += "\n%d kcal / 100 g dry grain" % Farm.CROPS[crop].kcal_per_100g
	accessibility_name = tooltip_text
	var bag := TextureRect.new()
	bag.texture = icons.icon(crop, float(grams) / full, number)
	bag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bag.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	bag.material = bag_material
	bag.size = Vector2(SIZE, SIZE)
	bag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bag)

func _draw() -> void:
	if crop != "":
		draw_string(_font, Vector2(0, size.y - 4), "%s kg" % Farm.kg(grams), HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, TimeHud.PARCHMENT if grams == Farm.CROPS[crop].bag else TimeHud.GOLD)
