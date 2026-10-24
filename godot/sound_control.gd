extends Control
## Same sound panel in menu and field, with native keyboard slider support.
const TimeHud := preload("res://time_hud.gd")
var button := Button.new()
var panel := PanelContainer.new()
var mute := CheckButton.new()
var sliders := {}

func _ready() -> void:
	name = "SoundControl"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.text = "Sound"
	button.tooltip_text = "Sound volume and mute (F10)"
	TimeHud.style_button(button, TimeHud.serif_font())
	button.add_theme_stylebox_override("normal", TimeHud.box(TimeHud.INK, TimeHud.GOLD, 6, 1, Vector2(6, 4)))
	add_child(button)
	button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	button.offset_left = -118
	button.offset_right = -18
	button.offset_top = 18
	button.offset_bottom = 58
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -370
	panel.offset_right = -18
	panel.offset_top = 68
	panel.add_theme_stylebox_override("panel", TimeHud.box(TimeHud.INK, TimeHud.GOLD, 10, 2, Vector2(18, 14)))
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	mute.text = "Mute all sound"
	mute.button_pressed = Audio.muted
	mute.toggled.connect(func(value: bool) -> void:
		Audio.set_muted(value)
		Audio.save_settings())
	column.add_child(mute)
	for bus in Audio.levels:
		var label := Label.new()
		label.text = "%s  %d%%" % [bus, roundi(Audio.levels[bus] * 100)]
		label.add_theme_color_override("font_color", TimeHud.PARCHMENT)
		column.add_child(label)
		var slider := HSlider.new()
		slider.custom_minimum_size = Vector2(290, 24)
		slider.max_value = 100
		slider.value = Audio.levels[bus] * 100
		slider.tooltip_text = bus + " volume (arrow keys adjust)"
		slider.value_changed.connect(func(value: float) -> void:
			Audio.set_level(bus, value / 100)
			label.text = "%s  %d%%" % [bus, roundi(value)])
		slider.drag_ended.connect(func(_changed: bool) -> void: Audio.save_settings())
		slider.focus_exited.connect(func() -> void: Audio.save_settings())
		column.add_child(slider)
		sliders[bus] = slider
	var credit := Label.new()
	credit.text = "Wind: Flixberry Entertainment · CC BY 4.0\nRain: Ylmir · Thunder: rubberduck · CC0"
	credit.tooltip_text = "Wind: Strong Wind Blowing by Flixberry Entertainment\nhttps://opengameart.org/content/strong-wind-blowing\nhttps://creativecommons.org/licenses/by/4.0/\nModified: filtered, resampled and loop-edited.\nRain: https://opengameart.org/content/rain-loopable\nThunder: https://opengameart.org/content/100-cc0-sfx-2\nCC0: https://creativecommons.org/publicdomain/zero/1.0/"
	credit.mouse_filter = Control.MOUSE_FILTER_PASS
	credit.add_theme_font_size_override("font_size", 12)
	credit.add_theme_color_override("font_color", TimeHud.PARCHMENT)
	column.add_child(credit)
	var close := Button.new()
	close.text = "Close"
	TimeHud.style_button(close, TimeHud.serif_font())
	column.add_child(close)
	close.pressed.connect(_close)
	panel.hide()
	button.pressed.connect(_toggle)

func _toggle() -> void:
	if panel.visible:
		_close()
	else:
		panel.show()
		mute.grab_focus()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F10:
		_toggle()
		get_viewport().set_input_as_handled()
	if panel.visible and event.is_action_pressed("ui_cancel"):
		_close()
		get_viewport().set_input_as_handled()

func _close() -> void:
	Audio.save_settings()
	panel.hide()
	button.grab_focus()

func _exit_tree() -> void:
	Audio.save_settings()
