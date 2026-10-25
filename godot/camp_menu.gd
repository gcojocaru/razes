extends "res://action_wheel.gd"
## Camp actions share the field wheel's rendering, hit targets and input.

signal eat_selected
signal sleep_selected

func _init() -> void:
	super()
	name = "CampMenu"
	z_index = 30
	_title = "Camp"
	_detail = "Choose an action"
	entries = [{"action": "Eat", "crop": ""}, {"action": "Sleep", "crop": ""}]

func open_at(at: Vector2) -> void:
	_focused = 0
	super.open_at(at)

func _effect(entry: Dictionary) -> String:
	return "Choose grain\nand a quantity" if entry.action == "Eat" else "Choose hours\nPreview recovery"

func _tooltip(entry: Dictionary) -> String:
	return entry.action + "\n" + _effect(entry)

func _summary(entry: Dictionary) -> String:
	return "Prepare porridge" if entry.action == "Eat" else "Choose hours"

func _activate(index: int) -> void:
	hide()
	if entries[index].action == "Eat":
		eat_selected.emit()
	else:
		sleep_selected.emit()
