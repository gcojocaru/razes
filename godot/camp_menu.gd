extends "res://action_wheel.gd"
## Camp actions share field wheel hit targets, keyboard navigation and rendering.
signal eat_selected
signal sleep_selected
signal move_selected
signal build_selected
signal heat_selected
signal recover_selected
var _camp_farm: Farm
var _person: Human

func _init() -> void:
	super()
	name = "CampMenu"
	z_index = 30
	_title = "Camp"
	_detail = "Choose an action"
	entries = [{"action":"Eat", "crop":""}, {"action":"Sleep", "crop":""}, {"action":"Move", "crop":""}]

func show_camp(farm: Farm, person: Human) -> void:
	_camp_farm = farm
	_person = person
	var next: Array[Dictionary] = [{"action":"Eat", "crop":""}, {"action":"Sleep", "crop":""}, {"action":"Move", "crop":""}, {"action":"Heat", "crop":""}, {"action":"Recover", "crop":""}]
	if not farm.shelter: next.append({"action":"Build", "crop":""})
	if entries != next:
		entries = next
		if visible: _build_buttons()
	_title = "Timber shelter" if farm.shelter else "Camp"
	_detail = "%s kg wood · %s h fuel" % [Farm.kg(farm.wood), String.num(farm.fuel_hours(), 1)]
	if visible:
		_place_labels()
		for index in mini(_buttons.size(), entries.size()):
			_buttons[index].text = _label(entries[index]) + ": " + _effect(entries[index])
			_buttons[index].tooltip_text = _tooltip(entries[index])
		_show_hub()
		queue_redraw()

func _show_hub() -> void:
	super._show_hub()
	if _camp_farm != null:
		hub_detail.text = "%s kg wood\n%s h fuel" % [Farm.kg(_camp_farm.wood), String.num(_camp_farm.fuel_hours(), 1)]
		hub_detail.tooltip_text = _detail + "\n" + ("Heating enabled" if _camp_farm.heating_enabled else "Heating off")

func open_at(at: Vector2) -> void:
	_focused = 0
	super.open_at(at)

func _label(entry: Dictionary) -> String:
	if entry.action == "Heat": return "Heat on" if _camp_farm != null and _camp_farm.heating_enabled else "Heat off"
	if entry.action == "Build": return "Building" if _person != null and _person.build_reserved > 0 else "Build shelter"
	if entry.action == "Move" and _camp_farm != null and _camp_farm.shelter: return "Fixed home"
	return "Recover" if entry.action == "Recover" else entry.action

func _effect(entry: Dictionary) -> String:
	match entry.action:
		"Eat": return "Choose grain\nand a quantity"
		"Sleep": return "Choose hours\nPreview recovery"
		"Build": return "300 kg wood · 8 h\nRoof and better sleep"
		"Heat": return "0.5 kg/h at camp\nToggle heating"
		"Recover": return "Return to camp\nDry, warm or cool down"
	return "Shelter cannot move" if _camp_farm != null and _camp_farm.shelter else "Pick a new place\non the field"

func _tooltip(entry: Dictionary) -> String:
	return _label(entry) + "\n" + _effect(entry)

func _summary(entry: Dictionary) -> String:
	match entry.action:
		"Eat": return "Prepare porridge"
		"Sleep": return "Choose hours"
		"Build": return "300 kg · 8 h"
		"Heat": return "0.5 kg/h at home"
		"Recover": return "Dry and rest"
	return "Fixed in place" if _camp_farm != null and _camp_farm.shelter else "Move camp"

func _activate(index: int) -> void:
	if entries[index].action == "Move" and _camp_farm != null and _camp_farm.shelter:
		hub_detail.text = "The completed shelter is permanent"
		return
	if entries[index].action == "Build" and _camp_farm != null and (_camp_farm.wood < Farm.SHELTER_WOOD or _person.build_reserved > 0):
		hub_detail.text = "Construction already ordered" if _person.build_reserved > 0 else "Needs 300 kg deposited wood"
		return
	hide()
	match entries[index].action:
		"Eat": eat_selected.emit()
		"Sleep": sleep_selected.emit()
		"Move": move_selected.emit()
		"Build": build_selected.emit()
		"Heat": heat_selected.emit()
		"Recover": recover_selected.emit()
