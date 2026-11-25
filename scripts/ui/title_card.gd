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
	Overlay.set_black(1.0)
	Overlay.fade_to(0.0, 1.0)
	Sfx.play_ui("ui/reveal", -4.0)
	get_tree().create_timer(3.6).timeout.connect(_next)

func _input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_next()

func _next() -> void:
	if _done:
		return
	_done = true
	await Overlay.fade_to(1.0, 0.9)
	Flow.goto("menu")
