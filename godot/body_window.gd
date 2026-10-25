extends "res://hud_window.gd"
## Left-side body window, toggled with B or the Farmer panel's Body button: the
## farmer's build and its change since the start, energy stores, tiredness and
## what each activity costs, updated live. Human derives all of it from height and
## fat and lean mass.

const BAR := 110.0
const WIDTHS := [120.0, 190.0, BAR]
## Activities the effort table lists, by the name it shows.
const EFFORTS := {"Sleeping": "Sleeping", "Idle": "Idle", "Cooking": "Cooking", "Walking": "Walking", "Sow": "Sowing, harvesting", "Plow": "Hoeing"}

## Per row title: its value label and its third cell, a bar or a second label.
var _values := {}

func _init() -> void:
	super("Body", "B", 460, 560)
	offset_left = 14
	offset_top = 110
	_heading("Build")
	for title in ["Height", "Weight", "Body fat", "Lean mass", "BMI"]:
		_line(title)
	_line("Health", Color(0.55, 0.75, 0.35), "Full down to a BMI of 18.5, gone at 12.5")
	_heading("Energy")
	_line("Basal", Color.TRANSPARENT, "Metabolism at rest, set by lean mass")
	_line("Ready energy", TimeHud.GOLD, "Glycogen. Digested food refills it; once it is empty the body burns fat and muscle")
	_line("Stomach", Color(0.75, 0.6, 0.4), "Porridge waiting to be digested")
	_line("Digestion", Color.TRANSPARENT, "The gut absorbs at most 2.5 times basal metabolism")
	_line("Burning now")
	_heading("Rest")
	_line("Fatigue", Color(0.6, 0.65, 0.85), "Work and walking slow to 80% from 70% fatigue and to 60% from 90%")
	_heading("Effort", "kcal an hour", "fatigue an hour")
	for action in EFFORTS:
		_line(EFFORTS[action])

## Shows `person`'s body now.
func show_body(person: Human) -> void:
	_show("Height", "%.2f m" % Human.HEIGHT)
	_show("Weight", "%.1f kg" % person.mass(), "%+.2f kg since start" % (person.mass() - Human.START_FAT - Human.START_LEAN))
	_show("Body fat", "%.1f kg · %d%%" % [person.fat, roundi(person.fat / person.mass() * 100.0)], "%+.2f kg" % (person.fat - Human.START_FAT))
	_show("Lean mass", "%.1f kg" % person.lean, "%+.2f kg" % (person.lean - Human.START_LEAN))
	_show("BMI", "%.1f" % person.bmi(), "healthy from 18.5")
	_show("Health", "%d%%" % roundi(person.health), person.health / 100.0)
	_show("Basal", "%d kcal a day" % roundi(person.basal() * 24.0))
	var capacity: float = person.lean * Human.GLYCOGEN_PER_LEAN
	_show("Ready energy", "%d / %d kcal" % [roundi(person.glycogen), roundi(capacity)], person.glycogen / capacity)
	_show("Stomach", "%d / %d g · %d kcal" % [roundi(person.stomach), Human.STOMACH_GRAMS, roundi(person.stomach_kcal)], person.stomach / Human.STOMACH_GRAMS)
	_show("Digestion", "up to %d kcal an hour" % roundi(person.digestion()))
	var action: String = person.job.get("action", "Idle") if person.activity == "Working" else person.activity
	_show("Burning now", "%s · %d kcal an hour" % [person.activity, roundi(person.burn(action))] if action in Human.EFFORT else person.activity)
	_show("Fatigue", "%d%% · pace %d%%" % [roundi(person.fatigue), roundi(person.pace() * 100.0)], person.fatigue / 100.0)
	for effort in EFFORTS:
		_show(EFFORTS[effort], "%d" % roundi(person.burn(effort)), "%+.1f" % person.tiring(effort))
	_fit()

func _heading(title: String, value := "", extra := "") -> void:
	_row([title, value, extra], WIDTHS, false, TimeHud.GOLD)

## A row whose value show_body fills in, then a bar in `bar` or a second value.
func _line(title: String, bar := Color.TRANSPARENT, tooltip := "") -> void:
	var cells := [_label(""), _bar(0.0, bar, BAR) if bar.a > 0.0 else _label("", MUTED)]
	_values[title] = cells
	_row([title, cells[0], cells[1]], WIDTHS, body.get_child_count() % 2 == 1, TimeHud.PARCHMENT, tooltip)

## Sets a row's value and its bar's share (a float) or second value (a String).
func _show(title: String, text: String, extra: Variant = "") -> void:
	var cells: Array = _values[title]
	cells[0].text = text
	if extra is float:
		cells[1].get_child(0).size.x = BAR * clampf(extra, 0.0, 1.0)
	else:
		cells[1].text = extra
