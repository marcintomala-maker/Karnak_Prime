class_name SettingsPanel
extends PanelContainer
## Settings tab used by both the main menu and the pause menu.

signal closed

var _pet_size_row: Control

func _ready() -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.01, 0.025, 0.04, 0.92)
	sb.border_color = Color(UIKit.TEAL, 0.6)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(34)
	add_theme_stylebox_override("panel", sb)
	custom_minimum_size = Vector2(820, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	add_child(v)
	v.add_child(UIKit.label("SETTINGS", 44, UIKit.TEAL))
	_slider(v, "SFX VOLUME", 0.0, 1.0, Settings.sfx_volume, func(x): Settings.sfx_volume = x; Settings.apply_audio(); Sfx.play_ui("ui/hover"))
	_slider(v, "MUSIC VOLUME", 0.0, 1.0, Settings.music_volume, func(x): Settings.music_volume = x; Settings.apply_audio())
	_slider(v, "BRIGHTNESS", 0.5, 2.0, Settings.brightness, func(x): Settings.brightness = x; Settings.changed.emit())
	var sens := _slider(v, "MOUSE SENSITIVITY", 0.0, 1.0, Settings.sensitivity, func(x):
		if absf(x - 0.5) < 0.02: x = 0.5
		Settings.sensitivity = x; Settings.changed.emit())
	sens.tooltip_text = "Middle = raw mouse input (1:1)"
	var res := _option(v, "RESOLUTION", Settings.RESOLUTIONS.map(func(r): return "%d x %d" % [r.x, r.y]), Settings.resolution_index(),
		func(i): Settings.resolution = Settings.RESOLUTIONS[i]; Settings.apply_video())
	_option(v, "DISPLAY MODE", Settings.WINDOW_MODES, Settings.window_mode, func(i): Settings.window_mode = i; Settings.apply_video())
	var pet_row := HBoxContainer.new()
	var pl := UIKit.label("EMOTIONAL SUPPORT PET", 24, UIKit.WHITE, "Bold")
	pl.custom_minimum_size.x = 340; pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	pet_row.add_child(pl)
	var cb := CheckBox.new()
	cb.button_pressed = Settings.pet_enabled
	cb.scale = Vector2(1.5, 1.5)
	cb.toggled.connect(func(on): Settings.pet_enabled = on; _pet_size_row.visible = on; Settings.changed.emit())
	pet_row.add_child(cb)
	v.add_child(pet_row)
	_pet_size_row = _slider(v, "PET SIZE", 0.5, 2.0, Settings.pet_size, func(x): Settings.pet_size = x; Settings.changed.emit()).get_parent()
	_pet_size_row.visible = Settings.pet_enabled
	var back := UIKit.button("BACK", 28)
	back.pressed.connect(_close)
	v.add_child(back)
	res.get_parent().visible = true

func _row(v: VBoxContainer, title: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 20)
	var l := UIKit.label(title, 24, UIKit.WHITE, "Bold")
	l.custom_minimum_size.x = 340
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	h.add_child(l)
	v.add_child(h)
	return h

func _slider(v: VBoxContainer, title: String, mn: float, mx: float, val: float, cb: Callable) -> HSlider:
	var h := _row(v, title)
	var s := HSlider.new()
	s.min_value = mn; s.max_value = mx; s.step = 0.01; s.value = val
	s.custom_minimum_size = Vector2(380, 32)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UIKit.slider_style(s)
	s.value_changed.connect(cb)
	h.add_child(s)
	return s

func _option(v: VBoxContainer, title: String, items: Array, sel: int, cb: Callable) -> OptionButton:
	var h := _row(v, title)
	var o := OptionButton.new()
	for it in items:
		o.add_item(str(it))
	o.select(sel)
	o.custom_minimum_size = Vector2(380, 44)
	o.add_theme_font_override("font", UIKit.font("Bold"))
	o.add_theme_font_size_override("font_size", 22)
	o.item_selected.connect(cb)
	h.add_child(o)
	return o

func _close() -> void:
	Settings.save_settings()
	closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_close()
