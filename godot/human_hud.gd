extends PanelContainer
## One person's current work, needs and supplies; field orders still use the farm panel.

signal focus_requested
signal body_requested
signal wake_requested
signal cancel_requested

const TimeHud := preload("res://time_hud.gd")

var title := Label.new()
var _activity := Label.new()
var _needs := Label.new()
var _supplies := Label.new()
var _carried := Label.new()
var _message := Label.new()
var _buttons := HBoxContainer.new()
var _wake_button: Button

func _init() -> void:
	name = "HumanHud"
	offset_left = 14
	offset_top = 110
	add_theme_stylebox_override("panel", TimeHud.box(TimeHud.INK, TimeHud.GOLD, 8, 1, Vector2(14, 10)))
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 250
	column.add_theme_constant_override("separation", 6)
	add_child(column)
	title.add_theme_font_override("font", preload("res://assets/fonts/CormorantUnicase-Bold.ttf"))
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", TimeHud.GOLD)
	column.add_child(title)
	for label in [_activity, _needs, _supplies, _carried, _message]:
		label.add_theme_font_override("font", TimeHud.serif_font())
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", TimeHud.PARCHMENT)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 250
		column.add_child(label)
	column.add_child(_buttons)
	for choice in [["Focus", "Find the farmer (H)", focus_requested], ["Body", "Weight, energy stores and effort (B)", body_requested], ["Wake up", "End the chosen sleep early (R)", wake_requested], ["Clear jobs", "Cancel work and return carried grain (Backspace)", cancel_requested]]:
		var button := _button(choice[0], choice[1])
		var requested: Signal = choice[2]
		button.pressed.connect(requested.emit)
		_buttons.add_child(button)
		if choice[0] == "Wake up":
			_wake_button = button

func _button(text: String, tooltip: String) -> Button:
	var button := Button.new()
	button.text = text
	button.tooltip_text = tooltip
	button.focus_mode = Control.FOCUS_NONE
	TimeHud.style_button(button, TimeHud.serif_font())
	return button

func show_person(person) -> void:
	var waiting: int = person.queue.size() + int(not person.job.is_empty())
	title.text = person.name
	_activity.text = person.activity
	if person.eating_requested:
		_activity.text += " · %s porridge (%s kg)" % [person.meal_crop, Farm.kg(person.meal_grams)]
	elif person.build_remaining > 0 and person.activity == "Building":
		_activity.text += " · %s h left" % String.num(person.build_remaining, 1)
	elif person.sleep_remaining > 0:
		_activity.text += " · Sleep: %s h left" % String.num(person.sleep_remaining, 2)
	elif not person.job.is_empty():
		_activity.text += " · " + person.job.action
		if person.job.crop != "":
			_activity.text += " " + person.job.crop
		_activity.text += " · %s h left" % String.num(person.job.remaining, 1).trim_suffix(".0")
	_activity.text += "\n%d job%s queued" % [waiting, "" if waiting == 1 else "s"]
	_needs.text = "Energy: %d kcal  ·  Stomach: %d%%\nWeight: %.1f kg  ·  BMI %.1f\nFatigue: %d%%  ·  Health: %d%%" % [roundi(person.glycogen), roundi(person.stomach / Human.STOMACH_GRAMS * 100.0), person.mass(), person.bmi(), roundi(person.fatigue), roundi(person.health)]
	_needs.tooltip_text = "Camp offers food, sleep, recovery, heating and shelter construction. Cold/wet and hot work can cause exposure injury. Meals fill the stomach and digest into ready energy. Without it the body burns fat and muscle: weight falls, and health drops below a BMI of 18.5 and is gone at 12.5. Sleep clears fatigue, which slows work and walking from 70%."
	_supplies.text = "Seed reserved: %s kg\nShelter reserved: %s kg" % [Farm.kg(person.reserved_seed()), Farm.kg(person.build_reserved)]
	_needs.text += "\nCore: %.1f°C · Wet: %d%%\n%s" % [person.exposure.core, roundi(person.exposure.wetness * 100), person.exposure.warning()]
	_wake_button.text = "Stop recovery" if person.recovering else "Wake up"
	_wake_button.tooltip_text = "End recovery and resume work (R)" if person.recovering else "End the chosen sleep early (R)"
	_wake_button.visible = person.sleep_remaining > 0 or person.recovering
	_carried.text = "Carrying: %s kg %s" % [Farm.kg(person.carried), person.carried_crop.to_lower()] if person.carried else "Bag empty"
	_message.text = "Last: " + person.message
	_message.visible = person.message != ""
	_buttons.visible = person.activity != "Dead"
