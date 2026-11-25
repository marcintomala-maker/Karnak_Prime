extends Control
## Scrollable credits listing every asset author (data: res://CREDITS.txt).

func _ready() -> void:
	UIKit.fullscreen(self)
	var bg := ColorRect.new(); bg.color = Color(0, 0.01, 0.02); UIKit.fullscreen(bg); add_child(bg)
	var geo := SacredGeometry.new(); geo.radius = 500; geo.intensity = 0.18; geo.speed = 0.3
	UIKit.fullscreen(geo); add_child(geo)
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.offset_left = 260; sc.offset_right = -260; sc.offset_top = 60; sc.offset_bottom = -130
	add_child(sc)
	var rt := RichTextLabel.new()
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.custom_minimum_size = Vector2(1300, 0)
	rt.add_theme_font_override("normal_font", UIKit.font("Regular"))
	rt.add_theme_font_override("bold_font", UIKit.font("Black"))
	rt.add_theme_font_size_override("normal_font_size", 22)
	rt.add_theme_font_size_override("bold_font_size", 30)
	rt.add_theme_color_override("default_color", UIKit.WHITE)
	var txt := FileAccess.get_file_as_string("res://CREDITS.txt")
	var out := ""
	for line in txt.split("\n"):
		if line.begins_with("# "):
			out += "\n[center][b][color=#5cf2f2]%s[/color][/b][/center]\n" % line.substr(2)
		elif line.begins_with("## "):
			out += "[center][b][color=#cfe8ff]%s[/color][/b][/center]\n" % line.substr(3)
		else:
			out += "[center]%s[/center]\n" % line
	rt.text = out
	sc.add_child(rt)
	var back := UIKit.button("BACK")
	back.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	back.position = Vector2(-190, -100)
	back.pressed.connect(_back)
	add_child(back)
	Overlay.fade_to(0.0, 0.5)

func _back() -> void:
	await Overlay.fade_to(1.0, 0.4)
	Flow.goto("menu")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_back()
