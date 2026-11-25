extends Control
## "Created by MALEVOLENT WORMHOLE" card, shown right before the main menu fades in.

var _done := false

func _ready() -> void:
	UIKit.fullscreen(self)
	var bg := ColorRect.new(); bg.color = Color.BLACK; UIKit.fullscreen(bg); add_child(bg)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)
	UIKit.fullscreen(box)
	add_child(box)
	box.add_child(UIKit.label("CREATED BY", 26, Color(1, 1, 1, 0.55), "Light"))
	var t := UIKit.label("MALEVOLENT WORMHOLE", 78, Color(0.85, 0.2, 1.0))
	box.add_child(t)
	var gap := Control.new(); gap.custom_minimum_size.y = 40; box.add_child(gap)
	var lines: Array[Label] = []
	for txt in ["NO AI GENERATED IMAGES", "NO AI GENERATED SOUNDS", "NO AI GENERATED MUSIC"]:
		var l := UIKit.label(txt, 34, Color(0.92, 0.96, 1.0))
		l.modulate.a = 0.0
		box.add_child(l)
		lines.append(l)
	_reveal(lines)
	Overlay.set_black(1.0)
	Overlay.fade_to(0.0, 1.0)
	Sfx.play_ui("ui/reveal", -4.0)
	get_tree().create_timer(7.0).timeout.connect(_next)

func _reveal(lines: Array[Label]) -> void:
	await get_tree().create_timer(1.6).timeout
	for l in lines:
		if _done:
			return
		create_tween().tween_property(l, "modulate:a", 1.0, 0.5)
		Sfx.play_ui("ui/letter", -6.0, 0.9)
		await get_tree().create_timer(1.1).timeout

func _input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_next()

func _next() -> void:
	if _done:
		return
	_done = true
	await Overlay.fade_to(1.0, 0.9)
	Flow.goto("menu")
