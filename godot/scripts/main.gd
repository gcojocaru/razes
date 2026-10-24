extends Node

const Rules = preload("res://scripts/village_rules.gd")
const Store = preload("res://scripts/save_store.gd")
const World = preload("res://scripts/village_world.gd")
const PAPER := Color("eadfc5")
const GOLD := Color("d6b575")
const MUTED := Color("aab09a")
const INK := Color("18221d")
const BAD := Color("e7a18b")

var state: Dictionary
var store = Store.new()
var world: Node3D
var selection: Dictionary = {}
var needs_recovery := false
var reduce_motion := false
var _panel_key := ""
var _tool := ""
var _facing := 0
var _instant := false
var _parcel := Vector2i.ZERO
var _message := ""
var _save_warning := ""
var _calendar: Label
var _resources: Label
var _needs: Label
var _task_button: Button
var _week_button: Button
var _cancel_button: Button
var _banner: Label
var _pane: PanelContainer
var _panel_title: Label
var _panel_body: VBoxContainer
var _confirm: ConfirmationDialog
var _fresh: ConfirmationDialog
var _recovery: AcceptDialog
var _ambient: AudioStreamPlayer
var _interface: Control
var _preferences := ConfigFile.new()

func _ready() -> void:
	var loaded: Dictionary = store.load_game()
	state = Rules.new_game() if loaded.state.is_empty() else loaded.state
	needs_recovery = not loaded.error.is_empty()
	_message = loaded.error
	_preferences.load("user://preferences.cfg")
	reduce_motion = _preferences.get_value("comfort", "reduce_motion", false)
	world = World.new()
	world.name = "Village"
	world.set_state(state)
	add_child(world)
	world.selection_changed.connect(select_place)
	world.placement_requested.connect(_place)
	world.parcel_selected.connect(func(parcel: Vector2i):
		_parcel = parcel
		show_panel("land"))
	world.tool_rotated.connect(func(value: int): _facing = value)
	world.set_reduce_motion(reduce_motion)
	_build_interface()
	_refresh()
	if needs_recovery:
		call_deferred("_show_recovery", loaded.recovered)
	if _preferences.get_value("comfort", "ambient", false):
		_set_ambient(true)

func perform(action: String, payload: Dictionary = {}) -> bool:
	if needs_recovery:
		_notice("Recover the saved household or start fresh before making changes.")
		return false
	var result: Dictionary = Rules.act(state, action, payload)
	if not result.error.is_empty():
		_notice(result.error)
		return false
	state = result.state
	_message = ""
	var save_error: String = store.save_game(state)
	_save_warning = "Changes are not saved: " + save_error if not save_error.is_empty() else ""
	_refresh()
	return true

func _box(fill: Color, border: Color = Color("455447"), radius: int = 8) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _label(text: String, size: int = 16, color: Color = PAPER) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _button(title: String, callback: Callable, key: String = "") -> Button:
	var button := Button.new()
	button.text = title
	button.name = key if not key.is_empty() else title.validate_node_name()
	button.accessibility_name = title
	var descriptions := {"RotateLeft": "Rotate view left", "RotateRight": "Rotate view right", "ZoomOut": "Zoom out", "ZoomIn": "Zoom in", "ClosePanel": "Close command panel", "Help": "How to play"}
	if descriptions.has(key):
		button.accessibility_name = descriptions[key]
		button.tooltip_text = descriptions[key]
	button.focus_mode = Control.FOCUS_ALL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size.y = 38
	button.pressed.connect(callback)
	return button

func _action(title: String, action: String, payload: Dictionary = {}, reason: String = "", key: String = "") -> Button:
	var button := _button(title, func(): perform(action, payload), key)
	button.disabled = needs_recovery or state.phase == "dead" or not reason.is_empty()
	button.tooltip_text = reason
	button.accessibility_description = reason
	return button

func _space() -> Control:
	var space := Control.new()
	space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return space

func _row() -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 9)
	return row

func _build_interface() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "Interface"
	add_child(canvas)
	_interface = Control.new()
	_interface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_interface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(_interface)
	var theme := Theme.new()
	theme.default_font_size = 17
	theme.set_color("font_color", "Label", PAPER)
	theme.set_color("font_color", "Button", PAPER)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", Color("828878"))
	theme.set_stylebox("normal", "Button", _box(Color("27382e")))
	theme.set_stylebox("hover", "Button", _box(Color("3d5040"), GOLD))
	theme.set_stylebox("pressed", "Button", _box(Color("4a5138"), GOLD))
	theme.set_stylebox("disabled", "Button", _box(Color("202c25"), Color("344337")))
	theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), GOLD))
	theme.set_stylebox("panel", "PanelContainer", _box(Color("1b2923f5")))
	theme.set_stylebox("panel", "AcceptDialog", _box(INK))
	_interface.theme = theme

	var top := PanelContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 18
	top.offset_right = -18
	top.offset_top = 18
	top.offset_bottom = 96
	_interface.add_child(top)
	var header := _row()
	top.add_child(header)
	var title := VBoxContainer.new()
	title.custom_minimum_size.x = 220
	header.add_child(title)
	var wordmark := _label("Răzeș", 30, GOLD)
	var serif := SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Noto Serif", "DejaVu Serif"])
	wordmark.add_theme_font_override("font", serif)
	title.add_child(wordmark)
	_calendar = _label("", 14, MUTED)
	_calendar.autowrap_mode = TextServer.AUTOWRAP_OFF
	title.add_child(_calendar)
	header.add_child(_space())
	_resources = _label("", 19)
	_resources.autowrap_mode = TextServer.AUTOWRAP_OFF
	_resources.custom_minimum_size.x = 360
	_resources.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(_resources)
	header.add_child(_space())
	header.add_child(_button("Settings", func(): show_panel("settings")))
	header.add_child(_button("?", func(): show_panel("help"), "Help"))

	var navigation := _row()
	navigation.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	navigation.offset_left = 18
	navigation.offset_right = -18
	navigation.offset_top = 108
	navigation.offset_bottom = 150
	_interface.add_child(navigation)
	for entry in [["Build", "build"], ["Materials", "materials"], ["Land", "land"], ["Ion", "work"], ["Places", "places"], ["Debug", "debug"]]:
		navigation.add_child(_button(entry[0], func(): show_panel(entry[1]), "Open" + entry[0]))
	navigation.add_child(_space())
	navigation.add_child(_button("↶", func(): world.rotate_map(-1), "RotateLeft"))
	navigation.add_child(_button("↷", func(): world.rotate_map(1), "RotateRight"))
	navigation.add_child(_button("−", func(): world.zoom_camera(1.18), "ZoomOut"))
	navigation.add_child(_button("+", func(): world.zoom_camera(1.0 / 1.18), "ZoomIn"))
	navigation.add_child(_button("Home", func(): world.reset_camera(), "ResetCamera"))

	var bottom := PanelContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 18
	bottom.offset_right = -18
	bottom.offset_top = -100
	bottom.offset_bottom = -18
	_interface.add_child(bottom)
	var dock := _row()
	bottom.add_child(dock)
	var ion := VBoxContainer.new()
	ion.custom_minimum_size.x = 345
	dock.add_child(ion)
	ion.add_child(_label("ION · SETTLER", 15, GOLD))
	_needs = _label("", 15)
	ion.add_child(_needs)
	_task_button = _button("", func(): show_panel("work"), "Assignment")
	_task_button.clip_text = true
	_task_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dock.add_child(_task_button)
	_cancel_button = _button("Cancel placement", _cancel_tool, "CancelPlacement")
	dock.add_child(_cancel_button)
	_week_button = _button("Review week", _review_week, "EndWeek")
	_week_button.custom_minimum_size = Vector2(190, 52)
	_week_button.add_theme_stylebox_override("normal", _box(Color("9b743c"), GOLD))
	dock.add_child(_week_button)

	_banner = _label("", 16, GOLD)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_banner.offset_left = 28
	_banner.offset_right = -28
	_banner.offset_top = -151
	_banner.offset_bottom = -108
	_banner.add_theme_stylebox_override("normal", _box(Color("14231de8")))
	_interface.add_child(_banner)

	_pane = PanelContainer.new()
	_pane.name = "CommandPanel"
	_pane.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	_pane.offset_left = 18
	_pane.offset_right = 390
	_pane.offset_top = 164
	_pane.offset_bottom = -164
	_pane.visible = false
	_interface.add_child(_pane)
	var contents := VBoxContainer.new()
	contents.add_theme_constant_override("separation", 14)
	_pane.add_child(contents)
	var panel_header := _row()
	contents.add_child(panel_header)
	_panel_title = _label("", 21, GOLD)
	_panel_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel_header.add_child(_panel_title)
	panel_header.add_child(_button("×", _close_panel, "ClosePanel"))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	contents.add_child(scroll)
	_panel_body = VBoxContainer.new()
	_panel_body.name = "PanelBody"
	_panel_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_panel_body.add_theme_constant_override("separation", 12)
	scroll.add_child(_panel_body)

	_confirm = ConfirmationDialog.new()
	_confirm.title = "Review this week"
	_confirm.ok_button_text = "Confirm · End week"
	_confirm.min_size = Vector2i(550, 330)
	_confirm.exclusive = true
	_confirm.theme = theme
	_confirm.confirmed.connect(func(): perform("end_week"))
	add_child(_confirm)
	_fresh = ConfirmationDialog.new()
	_fresh.title = "Begin a fresh household?"
	_fresh.dialog_text = "The current save will be preserved as a recovery file before a new household begins."
	_fresh.ok_button_text = "Start fresh"
	_fresh.min_size = Vector2i(520, 180)
	_fresh.exclusive = true
	_fresh.theme = theme
	_fresh.confirmed.connect(_start_fresh)
	_fresh.canceled.connect(_return_to_recovery)
	add_child(_fresh)

func _refresh() -> void:
	if world == null:
		return
	world.set_state(state)
	_calendar.text = "%s · Month %d · Week %d · %d%s" % [Rules.SEASONS[int(state.season)], int(state.week) / 4 + 1, int(state.week) % 4 + 1, 1495 + int(state.year), " · PREVIEW" if state.debugSeason != null else ""]
	_resources.text = "Food %d   ·   Galbeni %d\nShelter %d   ·   Seeds %d" % [state.food, state.money, state.house, state.seeds]
	_needs.text = "Health %d  ·  Energy %d  ·  Hunger %d" % [state.character.health, state.character.energy, state.character.hunger]
	_task_button.text = "Assigned · " + Rules.TASKS[state.assignments.ion].name
	_task_button.tooltip_text = _task_button.text
	_task_button.accessibility_name = "Change assignment. " + _task_button.text
	_task_button.disabled = state.phase != "work" or needs_recovery
	_week_button.text = "Recover household" if needs_recovery else ("Start fresh" if state.phase == "dead" else ("Read weekly report" if state.phase == "summary" else "Review week"))
	_week_button.disabled = false
	_cancel_button.visible = not _tool.is_empty()
	_banner.text = _save_warning if not _save_warning.is_empty() else _message
	if _banner.text.is_empty():
		_banner.text = "Place %s · R rotates · Escape cancels" % _tool.capitalize() if not _tool.is_empty() else "Drag to pan · Scroll to zoom · Select a building or Ion"
	_banner.add_theme_color_override("font_color", BAD if not _save_warning.is_empty() else GOLD)
	if not _panel_key.is_empty():
		_refresh_panel()

func _notice(message: String) -> void:
	_message = message
	if _banner != null:
		_banner.text = message
		_banner.add_theme_color_override("font_color", BAD)

func show_panel(key: String) -> void:
	_panel_key = key
	_pane.visible = true
	_refresh_panel()

func _close_panel() -> void:
	_panel_key = ""
	_pane.visible = false

func _refresh_panel() -> void:
	var focused := get_viewport().gui_get_focus_owner()
	var focus_name := str(focused.name) if focused != null and _panel_body.is_ancestor_of(focused) else ""
	for child in _panel_body.get_children():
		_panel_body.remove_child(child)
		child.queue_free()
	match _panel_key:
		"work": _work_panel()
		"build": _build_panel()
		"materials": _materials_panel()
		"land": _land_panel()
		"inspect": _inspect_panel()
		"places": _places_panel()
		"report": _report_panel()
		"settings": _settings_panel()
		"debug": _debug_panel()
		"help": _help_panel()
	if not focus_name.is_empty():
		var replacement := _panel_body.find_child(focus_name, true, false)
		if replacement is Control:
			replacement.call_deferred("grab_focus")

func _work_panel() -> void:
	_panel_title.text = "Ion’s week"
	_panel_body.add_child(_label("One assignment each week. Rest restores energy; successful work improves skills.", 16, MUTED))
	for skill in ["farming", "gathering", "building", "strength", "endurance"]:
		_panel_body.add_child(_label("%s · Level %d  · %d XP" % [skill.capitalize(), Rules.skill_level(state.character, skill), state.character[skill + "XP"]], 15))
	if state.phase != "work":
		_panel_body.add_child(_button("Read weekly report", func(): show_panel("report")))
		return
	for task in Rules.task_options(state):
		var candidate: Dictionary = Rules.act(state, "assign", {"task": task})
		var title: String = Rules.TASKS[task].name
		if state.assignments.ion == task:
			title = "✓ " + title
		var cost := Rules.energy_cost(state, task)
		if cost > 0:
			title += " · %d energy" % cost
		_panel_body.add_child(_action(title, "assign", {"task": task}, candidate.error, "Assign_" + task))

func _price(requirement: Dictionary) -> String:
	var parts: Array[String] = ["%d Galbeni" % requirement.coins]
	for material in Rules.MATERIALS:
		if requirement.materials[material] > 0:
			parts.append("%d %s" % [requirement.materials[material], material])
	return " · ".join(parts)

func _record(id: String) -> Dictionary:
	for record in state.buildings:
		if record.id == id:
			return record
	return {}

func _build_panel() -> void:
	_panel_title.text = "Build a household"
	_panel_body.add_child(_label("Place structures on owned ground. Foundations complete at season end. Costs reserve neither Ion nor his weekly job.", 16, MUTED))
	for id in Rules.DEFINITIONS:
		var definition: Dictionary = Rules.DEFINITIONS[id]
		var record := _record(id)
		if not record.is_empty():
			_panel_body.add_child(_button("%s · %s" % [definition.title, "Foundation" if record.level == 0 else "Level %d" % record.level], func(): select_place({"kind": "building", "id": id}), "Inspect_" + id))
			continue
		var requirement: Dictionary = Rules.requirements(state, id)
		_panel_body.add_child(_label(definition.title, 19, GOLD))
		_panel_body.add_child(_label(_price(requirement), 15))
		var reason := " ".join(requirement.problems)
		if not reason.is_empty():
			_panel_body.add_child(_label(reason, 14, MUTED))
		var place := _button("Place " + definition.title, func(): begin_placement(id), "Place_" + id)
		place.disabled = not requirement.isMet or state.phase == "dead" or needs_recovery
		place.tooltip_text = reason
		_panel_body.add_child(place)
	_panel_body.add_child(_label("Ground & boundaries", 20, GOLD))
	for entry in [["Dirt path", "dirtPath"], ["Stone pavement", "pavement"], ["Farmland", "farmland"], ["Rail fence", "fence"], ["Wattle fence", "wattleFence"], ["Erase ground works", "erase"]]:
		_panel_body.add_child(_button(entry[0] + (" · 1 Galbeni" if entry[1] != "erase" else ""), func(): begin_placement(entry[1])))
	_panel_body.add_child(_label("Scenery", 20, GOLD))
	for kind in Rules.SCENERY:
		_panel_body.add_child(_button("Place " + kind.capitalize(), func(): begin_placement("scenery:" + kind)))

func _materials_panel() -> void:
	_panel_title.text = "Supplies & storage"
	var total: int = int(state.materials.wood) + int(state.materials.stone) + int(state.materials.planks)
	_panel_body.add_child(_label("%d / %d shared storage · %d free Galbeni" % [total, Rules.storage_capacity(state), Rules.available_money(state)], 17, GOLD))
	var free: Dictionary = Rules.available_materials(state)
	for id in Rules.MATERIALS:
		_panel_body.add_child(_label("%s · %d stored · %d free" % [id.capitalize(), state.materials[id], free[id]], 18))
		var row := _row()
		var quantity := SpinBox.new()
		quantity.name = "Quantity_" + id
		quantity.min_value = 1
		quantity.max_value = 100000
		quantity.value = 1
		quantity.custom_minimum_size.x = 82
		quantity.accessibility_name = id.capitalize() + " quantity"
		row.add_child(quantity)
		var price := 3 if id == "planks" else 1
		row.add_child(_button("Buy · %d G each" % price, func(): perform("buy_material", {"id": id, "amount": int(quantity.value)}), "Buy_" + id))
		row.add_child(_button("Discard", func(): perform("discard_material", {"id": id, "amount": int(quantity.value)}), "Discard_" + id))
		_panel_body.add_child(row)
	_panel_body.add_child(_label("Craft planks", 20, GOLD))
	_panel_body.add_child(_label("A working Workshop crafts planks immediately. A Smithy reduces the recipe from 2 wood to 1.", 15, MUTED))
	_panel_body.add_child(_action("Craft 1 plank", "craft", {"amount": 1}))
	_panel_body.add_child(_label("Grain seeds · %d" % state.seeds, 19, GOLD))
	_panel_body.add_child(_action("Buy 4 seeds · 4 Galbeni", "buy_seeds", {"amount": 4}))
	_panel_body.add_child(_button("House storage upgrades", func(): select_place({"kind": "hotspot", "id": "house"})))

func _land_panel() -> void:
	_panel_title.text = "Room to grow"
	var owned: Array = state.layout.ownedParcels
	_panel_body.add_child(_label("%d parcels owned · %d tiles" % [owned.size(), owned.size() * 256], 19, GOLD))
	_panel_body.add_child(_label("Each parcel is 16 × 16 tiles. Buy land sharing an edge with your household for %d Galbeni. All nine parcels form a 48 × 48 map." % Rules.LAND_PRICE, 16, MUTED))
	_panel_body.add_child(_label("%d free Galbeni · weekly work stays reserved" % Rules.available_money(state), 16))
	var names := [["Northwest", "North", "Northeast"], ["West", "Home", "East"], ["Southwest", "South", "Southeast"]]
	for y in range(-1, 2):
		for x in range(-1, 2):
			var position := {"x": x, "y": y}
			var is_owned: bool = owned.has(position)
			var result: Dictionary = Rules.act(state, "buy_land", {"position": position})
			var title: String = names[y + 1][x + 1]
			if is_owned:
				title += " · Owned"
			else:
				title += " · %d Galbeni" % Rules.LAND_PRICE
			if _parcel == Vector2i(x, y):
				title = "◆ " + title
			var button := _action(title, "buy_land", {"position": position}, result.error, "Parcel_%d_%d" % [x + 1, y + 1])
			_panel_body.add_child(button)
			if not is_owned and not result.error.is_empty():
				_panel_body.add_child(_label(result.error, 14, MUTED))

func select_place(place: Dictionary) -> void:
	_cancel_tool()
	selection = place.duplicate()
	world.set_selection(selection)
	if selection.is_empty():
		_close_panel()
	else:
		show_panel("inspect")

func _inspect_panel() -> void:
	var kind: String = selection.get("kind", "")
	var id: String = selection.get("id", "")
	if kind == "worker":
		_work_panel()
		return
	if kind == "building" and Rules.DEFINITIONS.has(id):
		var definition: Dictionary = Rules.DEFINITIONS[id]
		var record := _record(id)
		_panel_title.text = definition.title
		if record.is_empty():
			_panel_body.add_child(_label("Reserved building plot. A weekly builder completes it at season end; cancel an unused plan to free this ground.", 17))
			_panel_body.add_child(_action("Cancel building plan", "remove_plan", {"id": id}, "", "CancelPlan_" + id))
		else:
			_panel_body.add_child(_label("Foundation · finishes this season" if record.level == 0 else "Level %d / 5 · Condition %d%%" % [record.level, record.condition], 19, GOLD))
			_panel_body.add_child(_label("Seasonal output · %d food · %d Galbeni" % [definition.food * maxi(1, int(record.level)), definition.coins * maxi(1, int(record.level))], 16))
			if record.level > 0:
				if record.level < 5:
					var requirement: Dictionary = Rules.requirements(state, id, int(record.level) + 1)
					_panel_body.add_child(_label("Upgrade · " + _price(requirement), 15))
					_panel_body.add_child(_action("Upgrade to level %d" % (int(record.level) + 1), "upgrade_building", {"id": id}, " ".join(requirement.problems)))
				else:
					_panel_body.add_child(_label("Fully upgraded", 16, GOLD))
				var repair: Dictionary = Rules.repair_requirements(state, id)
				_panel_body.add_child(_action("Repair · " + _price(repair), "repair_building", {"id": id}, " ".join(repair.problems)))
		_panel_body.add_child(_button("Move building", func(): begin_placement(id)))
		_panel_body.add_child(_action("Rotate building", "rotate_building", {"id": id}))
	elif kind == "hotspot" and id == "house":
		_panel_title.text = "Your household"
		_panel_body.add_child(_label("House level %d / 5 · Shelter %d" % [state.houseLevel, state.house], 20, GOLD))
		_panel_body.add_child(_label("Food, seeds, Galbeni and materials belong to the household. Keep shelter at 40 or more for winter.", 16, MUTED))
		var requirement: Dictionary = Rules.requirements(state, "house")
		_panel_body.add_child(_label("Storage upgrade · " + _price(requirement), 16))
		_panel_body.add_child(_action("Upgrade house storage", "upgrade_house", {}, " ".join(requirement.problems)))
		_panel_body.add_child(_button("Buy or craft supplies", func(): show_panel("materials")))
		_panel_body.add_child(_button("Assign house repairs", func(): show_panel("work")))
	elif kind == "hotspot" and id == "field":
		_panel_title.text = "Grain field"
		_panel_body.add_child(_label("%s · %d tiles · %d seeds" % [Rules.crop_stage(state).capitalize(), state.layout.farmland.size(), state.seeds], 20, GOLD))
		_panel_body.add_child(_label("Sow 4 seeds in spring. Tend after 4 weeks; grain ripens after 24 growing weeks. Bring in the harvest before winter.", 16, MUTED))
		_panel_body.add_child(_button("Choose Ion’s assignment", func(): show_panel("work")))
		_panel_body.add_child(_action("Buy 4 seeds · 4 Galbeni", "buy_seeds", {"amount": 4}))
		_panel_body.add_child(_button("Paint more farmland", func(): begin_placement("farmland")))
	elif kind == "scenery":
		_panel_title.text = "Scenery"
		_panel_body.add_child(_action("Rotate selected scenery", "rotate_scenery", {"id": id}))
		_panel_body.add_child(_action("Remove selected scenery", "remove_scenery", {"id": id}))
	else:
		_panel_title.text = "Shared stores"
		_panel_body.add_child(_button("Open supplies & storage", func(): show_panel("materials")))

func _places_panel() -> void:
	_panel_title.text = "Places & people"
	for entry in [["Ion", "worker", "ion"], ["House", "hotspot", "house"], ["Grain field", "hotspot", "field"], ["Shared stores", "hotspot", "stores"]]:
		_panel_body.add_child(_button(entry[0], func(): select_place({"kind": entry[1], "id": entry[2]})))
	for placement in state.layout.buildings:
		var id: String = placement.id
		var title: String = Rules.DEFINITIONS[id].title
		if _record(id).is_empty():
			title += " · Reserved plot"
		_panel_body.add_child(_button(title, func(): select_place({"kind": "building", "id": id}), "Visit_" + id))
	for scenery in state.layout.scenery:
		_panel_body.add_child(_button(scenery.kind.capitalize(), func(): select_place({"kind": "scenery", "id": scenery.id})))

func _review_week() -> void:
	if needs_recovery:
		if _recovery != null:
			_recovery.popup_centered()
	elif state.phase == "dead":
		_fresh.popup_centered()
	elif state.phase == "summary":
		show_panel("report")
	else:
		var forecast: Dictionary = Rules.forecast(state)
		var lines: Array[String] = [Rules.TASKS[state.assignments.ion].name, "", "Food: %d → %d" % [state.food, maxi(0, int(forecast.foodAfter))], "Galbeni: %d → %d" % [state.money, forecast.moneyAfter], "Shelter: %d → %d" % [state.house, forecast.houseAfter], "Energy: %d → %d" % [state.character.energy, forecast.character.after.energy], "Health: %d → %d" % [state.character.health, forecast.character.after.health]]
		for line in forecast.errors + forecast.warnings:
			lines.append("\n" + line)
		_confirm.dialog_text = "\n".join(lines)
		_confirm.get_ok_button().disabled = not forecast.errors.is_empty()
		_confirm.popup_centered()

func _report_panel() -> void:
	_panel_title.text = "The week’s work"
	if state.report == null:
		_panel_body.add_child(_label("Choose an assignment, then review the week.", 17))
		return
	var report: Dictionary = state.report
	_panel_body.add_child(_label("\n".join(report.tasks), 20, GOLD))
	for entry in [["Food", "foodBefore", "foodAfter"], ["Galbeni", "moneyBefore", "moneyAfter"], ["Shelter", "houseBefore", "houseAfter"], ["Seeds", "seedsBefore", "seedsAfter"]]:
		_panel_body.add_child(_label("%s · %d → %d" % [entry[0], report[entry[1]], report[entry[2]]], 18))
	_panel_body.add_child(_label("Health %d · Energy %d · Hunger %d" % [state.character.health, state.character.energy, state.character.hunger], 16))
	if state.phase == "dead":
		_panel_body.add_child(_label("Ion has died. His household can go no further. Begin again when you are ready.", 18, BAD))
		_panel_body.add_child(_button("Begin a fresh household", func(): _fresh.popup_centered()))
	elif state.phase == "summary":
		_panel_body.add_child(_action("Continue to next week", "continue", {}, "", "ContinueWeek"))

func _settings_panel() -> void:
	_panel_title.text = "A quieter household"
	var motion := CheckButton.new()
	motion.text = "Reduce motion"
	motion.button_pressed = reduce_motion
	motion.toggled.connect(func(enabled: bool):
		reduce_motion = enabled
		world.set_reduce_motion(enabled)
		_preferences.set_value("comfort", "reduce_motion", enabled)
		_save_preferences())
	_panel_body.add_child(motion)
	var sound := CheckButton.new()
	sound.text = "Quiet ambient sound"
	sound.button_pressed = _ambient != null and _ambient.playing
	sound.toggled.connect(func(enabled: bool):
		_set_ambient(enabled)
		_preferences.set_value("comfort", "ambient", enabled)
		_save_preferences())
	_panel_body.add_child(sound)
	_panel_body.add_child(_label("Season preview", 19, GOLD))
	_panel_body.add_child(_label("Changes the view while the actual calendar keeps its place.", 15, MUTED))
	for season in range(4):
		_panel_body.add_child(_action(Rules.SEASONS[season], "preview_season", {"season": season}))
	_panel_body.add_child(_action("Return to actual season", "preview_season", {"season": null}))
	_panel_body.add_child(_button("Start a fresh household", func(): _fresh.popup_centered()))

func _debug_panel() -> void:
	_panel_title.text = "Building workshop"
	_panel_body.add_child(_label("Developer tools bypass construction costs and unlocks. Changes are saved in this household.", 15, MUTED))
	_panel_body.add_child(_action("Add 100 food & Galbeni", "debug_resources", {}, "", "DebugResources"))
	for id in Rules.DEFINITIONS:
		var record := _record(id)
		_panel_body.add_child(_label(Rules.DEFINITIONS[id].title, 20, GOLD))
		if record.is_empty():
			var place := _button("Place completed building", func(): begin_placement(id, true), "DebugPlace_" + id)
			place.disabled = state.phase == "dead" or needs_recovery
			_panel_body.add_child(place)
		else:
			_panel_body.add_child(_label("Level %d · Condition %d%%" % [record.level, record.condition], 15))
			var levels := _row()
			for level in range(1, 6):
				levels.add_child(_action(str(level), "debug_building", {"id": id, "level": level, "condition": 100}, "", "DebugLevel_%s_%d" % [id, level]))
			_panel_body.add_child(levels)
			var condition := _row()
			condition.add_child(_action("Worn · 25%", "debug_building", {"id": id, "level": maxi(1, int(record.level)), "condition": 25}))
			condition.add_child(_action("Intact · 100%", "debug_building", {"id": id, "level": maxi(1, int(record.level)), "condition": 100}))
			_panel_body.add_child(condition)

func _help_panel() -> void:
	_panel_title.text = "A home worth keeping"
	_panel_body.add_child(_label("Northern Moldavia · 1495", 17, GOLD))
	_panel_body.add_child(_label("Keep Ion fed, rested and sheltered. Choose one job each week, review its forecast and confirm. A season has 12 weeks; a year has 48.\n\nSow 4 seeds in spring. Tend after 4 weeks and harvest ripe grain after 24 growing weeks, before winter. Rest restores energy. Wages buy provisions and materials; gathering supplies wood and stone.\n\nBuild on free, owned ground. Foundations finish at season end. Upgrades need the matching house and Building skill levels; some buildings need another building first. A Workshop crafts planks.\n\nBuy adjoining land in Land. Each new 16 × 16 parcel costs 20 Galbeni. Your existing buildings stay where they are. More farmland provides layout space; harvest yield follows Ion’s skill and buildings.\n\nDrag to pan; scroll or pinch to zoom. Home returns to the household. Use the arrow buttons to turn the view. R rotates while placing; Escape cancels or closes commands. Tab and Enter reach the command buttons. Places offers every building and Ion without map clicking.\n\nProgress saves on this computer after each accepted change. Existing native/browser saves are separate. This household starts fresh.", 16))

func begin_placement(kind: String, instant: bool = false) -> void:
	if state.phase == "dead" or needs_recovery:
		_notice("Begin a fresh household before placing structures.")
		return
	_tool = kind
	_instant = instant
	selection = {}
	world.set_selection({})
	world.set_tool(kind, _facing, instant)
	_close_panel()
	_refresh()

func _cancel_tool() -> void:
	_tool = ""
	_instant = false
	if world != null:
		world.set_tool("")
	if _cancel_button != null:
		_cancel_button.visible = false

func _place(kind: String, tile: Vector2i, facing: int) -> void:
	var payload := {"position": {"x": tile.x, "y": tile.y}, "facing": facing}
	_facing = facing
	var action := "infrastructure"
	if Rules.DEFINITIONS.has(kind):
		action = "place_building"
		payload.id = kind
		payload.instant = _instant
	elif kind.begins_with("scenery:"):
		action = "place_scenery"
		payload.kind = kind.trim_prefix("scenery:")
	else:
		payload.kind = kind
	if perform(action, payload) and action != "infrastructure":
		_cancel_tool()
		if action == "place_building":
			select_place({"kind": "building", "id": kind})
		_refresh()

func _show_recovery(can_restore: bool) -> void:
	_recovery = AcceptDialog.new()
	_recovery.title = "Recover your household"
	_recovery.dialog_text = _message
	_recovery.min_size = Vector2i(580, 230)
	_recovery.exclusive = true
	_recovery.theme = _interface.theme
	_recovery.ok_button_text = "Start fresh"
	_recovery.confirmed.connect(func(): _fresh.popup_centered())
	_recovery.add_button("Retry", false, "retry")
	if can_restore:
		_recovery.add_button("Restore previous household", false, "restore")
	_recovery.custom_action.connect(func(action: StringName):
		if action == "restore":
			var problem: String = store.restore_recovery()
			if not problem.is_empty():
				_notice(problem)
				return
		var result: Dictionary = store.load_game()
		if result.error.is_empty():
			state = result.state if result.exists else Rules.new_game()
			needs_recovery = false
			_message = ""
			_recovery.hide()
			_refresh()
		else:
			_recovery.dialog_text = result.error)
	add_child(_recovery)
	_recovery.popup_centered()

func _start_fresh() -> void:
	var next: Dictionary = Rules.new_game()
	var problem: String = store.start_fresh(next)
	if not problem.is_empty():
		_notice(problem)
		_return_to_recovery()
		return
	state = next
	needs_recovery = false
	_save_warning = ""
	_message = "A new spring. A household to make your own."
	selection = {}
	_cancel_tool()
	_close_panel()
	if _recovery != null:
		_recovery.hide()
	world.reset_camera()
	_refresh()

func _return_to_recovery() -> void:
	if needs_recovery and _recovery != null:
		_recovery.call_deferred("popup_centered")

func _save_preferences() -> void:
	if _preferences.save("user://preferences.cfg") != OK:
		_notice("The comfort preference could not be saved. It still applies for this session.")

func _set_ambient(enabled: bool) -> void:
	if _ambient == null:
		_ambient = AudioStreamPlayer.new()
		var wave := AudioStreamWAV.new()
		wave.format = AudioStreamWAV.FORMAT_16_BITS
		wave.mix_rate = 16000
		wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wave.loop_end = 64000
		var data := PackedByteArray()
		data.resize(128000)
		var rng := RandomNumberGenerator.new()
		rng.seed = 1495
		var wind := 0.0
		for i in range(64000):
			wind = wind * 0.97 + rng.randf_range(-0.03, 0.03)
			data.encode_s16(i * 2, int(wind * 1200))
		wave.data = data
		_ambient.stream = wave
		add_child(_ambient)
	if enabled:
		_ambient.play()
	else:
		_ambient.stop()

func _notification(what: int) -> void:
	if _ambient != null:
		if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
			_ambient.stream_paused = true
		elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
			_ambient.stream_paused = false

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if not _tool.is_empty():
			_cancel_tool()
		elif _pane.visible:
			_close_panel()
		_refresh()
		get_viewport().set_input_as_handled()
