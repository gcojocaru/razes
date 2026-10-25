extends "res://action_wheel.gd"
## Camp actions share the field wheel's rendering, hit targets and input.

signal eat_selected
signal sleep_selected
signal move_selected

func _init() -> void:
	super()
	name = "CampMenu"
	z_index = 30
	_title = "Camp"
	_detail = "Choose an action"
	entries = [{"action": "Eat", "crop": ""}, {"action": "Sleep", "crop": ""}, {"action": "Move", "crop": ""}]

func open_at(at: Vector2) -> void:
	_focused = 0
	super.open_at(at)

func _effect(entry: Dictionary) -> String:
	match entry.action:
		"Eat": return "Choose grain\nand a quantity"
		"Sleep": return "Choose hours\nPreview recovery"
	return "Pick a new place\non the field"

func _tooltip(entry: Dictionary) -> String:
	return entry.action + "\n" + _effect(entry)

func _summary(entry: Dictionary) -> String:
	match entry.action:
		"Eat": return "Prepare porridge"
		"Sleep": return "Choose hours"
	return "Move camp"

func _activate(index: int) -> void:
	hide()
	match entries[index].action:
		"Eat": eat_selected.emit()
		"Sleep": sleep_selected.emit()
		"Move": move_selected.emit()
