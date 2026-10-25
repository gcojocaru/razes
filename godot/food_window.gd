extends "res://hud_window.gd"
## Inventory-style ingredient choice and an explicit porridge preparation order.

signal prepare_requested(crop: String, grams: int)

const Inventory := preload("res://inventory.gd")
const GrainSlot := preload("res://grain_slot.gd")

var selected_crop := ""
var quantity := SpinBox.new()
var prepare := Button.new()
var grain_buttons: Array[Button] = []
var _grid := GridContainer.new()
var _selection := Label.new()
var _preview := Label.new()
var _reason := Label.new()
var _icons := preload("res://bag_icons.gd").new()
var _premultiplied := CanvasItemMaterial.new()
var _stock := {}
var _farm: Farm
var _person

func _init() -> void:
	super("Prepare food", "Escape", Inventory.COLUMNS * (GrainSlot.SIZE + Inventory.GAP) - Inventory.GAP, 260)
	name = "FoodPreparation"
	z_index = 25
	offset_left = 14
	offset_top = 110
	add_child(_icons)
	_premultiplied.blend_mode = CanvasItemMaterial.BLEND_MODE_PREMULT_ALPHA
	body.add_child(_label("Choose grain from your inventory", TimeHud.GOLD))
	_grid.columns = Inventory.COLUMNS
	_grid.add_theme_constant_override("h_separation", Inventory.GAP)
	_grid.add_theme_constant_override("v_separation", Inventory.GAP)
	body.add_child(_grid)
	var recipe := VBoxContainer.new()
	recipe.add_theme_constant_override("separation", 10)
	header.get_parent().add_child(recipe)
	recipe.add_child(_label("Porridge", TimeHud.GOLD, 20))
	for label in [_selection, _preview, _reason]:
		label.add_theme_font_override("font", TimeHud.serif_font())
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", TimeHud.PARCHMENT)
	var amount := HBoxContainer.new()
	amount.add_child(_label("Grain quantity (g)"))
	quantity.min_value = 1
	quantity.max_value = 10000
	quantity.allow_greater = true
	quantity.step = 1
	quantity.update_on_text_changed = true
	quantity.value = 300
	quantity.suffix = " g"
	quantity.custom_minimum_size.x = 160
	quantity.tooltip_text = "Whole grams of the selected grain"
	quantity.value_changed.connect(func(_value: float): _refresh_recipe())
	amount.add_child(quantity)
	recipe.add_child(_selection)
	recipe.add_child(amount)
	recipe.add_child(_preview)
	recipe.add_child(_reason)
	prepare.text = "Prepare & Eat Porridge"
	TimeHud.style_button(prepare, TimeHud.serif_font())
	prepare.pressed.connect(_prepare)
	recipe.add_child(prepare)

func show_food(farm: Farm, person) -> void:
	_farm = farm
	_person = person
	if selected_crop == "":
		for crop in Farm.CROPS:
			if farm.stock[crop] > 0:
				selected_crop = crop
				break
	if _stock != farm.stock:
		_stock = farm.stock.duplicate()
		_rebuild_bags()
	_refresh_recipe()

func _rebuild_bags() -> void:
	for child in _grid.get_children():
		child.free()
	grain_buttons.clear()
	for crop in Farm.CROPS:
		for grams in _farm.bags(crop):
			var slot := GrainSlot.new(crop, grams, _grid.get_child_count(), _icons, _premultiplied)
			slot.focus_mode = Control.FOCUS_ALL
			slot.toggle_mode = true
			slot.button_pressed = crop == selected_crop
			slot.pressed.connect(_choose_grain.bind(crop))
			_grid.add_child(slot)
			grain_buttons.append(slot)
	var count := _grid.get_child_count()
	for i in maxi(Inventory.COLUMNS * 2, ceili(count / float(Inventory.COLUMNS)) * Inventory.COLUMNS) - count:
		_grid.add_child(GrainSlot.new("", 0, 0, _icons, _premultiplied))
	_fit()

func _choose_grain(crop: String) -> void:
	selected_crop = crop
	for slot in grain_buttons:
		slot.set_pressed_no_signal(slot.crop == crop)
	_refresh_recipe()

func _refresh_recipe() -> void:
	if _farm == null:
		return
	var available: int = _farm.stock.get(selected_crop, 0)
	quantity.max_value = maxi(1, available)
	_selection.text = "%s · %s kg available" % [selected_crop if selected_crop != "" else "No grain", Farm.kg(available)]
	var valid_amount: bool = is_finite(quantity.value) and quantity.value >= 1 and quantity.value == floor(quantity.value) and quantity.value <= available
	_reason.text = ""
	if _person.activity == "Dead":
		_reason.text = "Game Over"
	elif _person.eating_requested:
		_reason.text = "A meal is already being prepared."
	elif _person.sleep_remaining > 0:
		_reason.text = "Choose Wake up before preparing a meal."
	elif _farm.stored() == 0:
		_reason.text = "Your inventory has no available grain."
	elif not valid_amount:
		_reason.text = "Choose an amount from the available grain."
	prepare.disabled = _reason.text != ""
	if valid_amount:
		var recipe: Dictionary = Human.porridge(selected_crop, int(quantity.value))
		_preview.text = "%d kcal / 100 g dry grain\nMeal: %s kcal · %s min preparation\nFood energy now: %d kcal" % [Farm.CROPS[selected_crop].kcal_per_100g, String.num(recipe.calories, 2).trim_suffix(".0"), String.num(recipe.hours * 60, 1).trim_suffix(".0"), roundi(_person.calories)]
	else:
		_preview.text = "Energy now: %d kcal" % roundi(_person.calories)
	_reason.visible = _reason.text != ""

func _prepare() -> void:
	quantity.apply()
	_refresh_recipe()
	if not prepare.disabled:
		prepare_requested.emit(selected_crop, int(quantity.value))

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		hide()
