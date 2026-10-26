extends "res://hud_window.gd"
## Explicit sleep duration with a forecast from the actual needs simulation.

signal sleep_requested(hours: float)

var hours := SpinBox.new()
var start := Button.new()
var _preview := Label.new()
var _reason := Label.new()
var _person: Human
var _farm: Farm
var _day := 0
var _hour := 0.0
## What the shown forecast was made from; the 24-hour forecast is too slow to redo every frame.
var _forecast_key := []

func _init() -> void:
	super("Sleep at camp", "Escape", 420, 300)
	name = "SleepPreparation"
	z_index = 25
	offset_left = 14
	offset_top = 110
	body.add_theme_constant_override("separation", 12)
	body.minimum_size_changed.connect(_fit)
	var explanation := _label("Sleep clears fatigue. Meals restore energy.")
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(explanation)
	var duration := HBoxContainer.new()
	duration.add_child(_label("Sleep hours"))
	hours.min_value = 0.25
	hours.max_value = Human.MAX_SLEEP_HOURS
	hours.step = 0.25
	hours.allow_greater = true
	hours.allow_lesser = true
	hours.update_on_text_changed = true
	hours.value = 8
	hours.custom_minimum_size.x = 160
	hours.tooltip_text = "Hours asleep after arriving at camp; up to 24 hours"
	hours.value_changed.connect(func(_value: float): _refresh_prediction())
	duration.add_child(hours)
	body.add_child(duration)
	for label in [_preview, _reason]:
		label.add_theme_font_override("font", _serif)
		label.add_theme_font_size_override("font_size", 14)
		label.add_theme_color_override("font_color", TimeHud.PARCHMENT)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(label)
	_reason.add_theme_color_override("font_color", TimeHud.GOLD)
	start.text = "Sleep"
	TimeHud.style_button(start, _serif)
	start.pressed.connect(_start)
	header.get_parent().add_child(start)

func show_sleep(person: Human, farm: Farm = null, day := 0, hour := 0.0) -> void:
	_person = person
	_farm = farm
	_day = day
	_hour = hour
	var key := [hours.value, person.position, snappedf(person.fatigue, 0.1), roundi(person.glycogen), person.sleep_remaining, person.eating_requested, person.activity, day, floori(hour * 60), snappedf(person.exposure.core, 0.01), snappedf(person.exposure.wetness, 0.01), roundi(person.exposure.health), farm.shelter if farm != null else false, floori(farm.fuel_hours() * 60) if farm != null else 0, farm.heating_enabled if farm != null else false]
	if key != _forecast_key:
		_forecast_key = key
		_refresh_prediction()

func _refresh_prediction() -> void:
	if _person == null:
		return
	_reason.text = ""
	_preview.text = ""
	if _person.activity == "Dead" or _person.health <= 0:
		_reason.text = "Game Over"
	elif _person.sleep_remaining > 0:
		_reason.text = "Sleep is already planned. Choose Wake up to end it early."
	elif _person.eating_requested:
		_reason.text = "Finish preparing your meal before sleeping."
	var prediction: Dictionary = {} if _reason.text != "" else _person.sleep_prediction(hours.value, _farm, _day, _hour)
	if prediction.is_empty() and _reason.text == "":
		_reason.text = "Choose hours above zero and up to 24."
	start.disabled = prediction.is_empty()
	if not prediction.is_empty():
		_preview.text = "Restedness: %d%% → %d%%\nEnergy: %d → %d kcal\nWeight: %.1f → %.1f kg\nHealth: %d%% → %d%%\nTime including walk to camp: %s h" % [roundi(100 - _person.fatigue), roundi(100 - prediction.fatigue), roundi(_person.glycogen), roundi(prediction.glycogen), _person.mass(), prediction.mass, roundi(_person.health), roundi(prediction.health), String.num(prediction.hours, 2).trim_suffix("0").trim_suffix(".")]
		_preview.text += "\nTemperature: %.1f → %.1f°C · Wet: %d → %d%%\nWood after sleep: %s kg" % [_person.exposure.core, prediction.core, roundi(_person.exposure.wetness * 100), roundi(prediction.wetness * 100), Farm.kg(prediction.wood)]
		if prediction.health <= 0:
			_reason.text = "You will not survive this sleep. Check food, shelter and heating."
		elif prediction.core < 36 or prediction.core > 38:
			_reason.text = "Unsafe temperature is predicted. Check shelter, heating and fuel."
		elif prediction.glycogen <= 0:
			_reason.text = "Ready energy will run out; the body will burn fat and muscle."
	_reason.visible = _reason.text != ""
	_fit()

func _start() -> void:
	hours.apply()
	_refresh_prediction()
	if not start.disabled:
		sleep_requested.emit(hours.value)

func _input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		hide()
