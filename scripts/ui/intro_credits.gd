extends Control
## Short thank-you card for the open asset projects, then the studio title card.

var _done := false

func _ready() -> void:
	UIKit.fullscreen(self)
	var bg := ColorRect.new(); bg.color = Color.BLACK; UIKit.fullscreen(bg); add_child(bg)
	var geo := SacredGeometry.new()
	geo.radius = 380; geo.intensity = 0.25; geo.speed = 0.6; geo.tint = UIKit.TEAL
	UIKit.fullscreen(geo); add_child(geo)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	UIKit.fullscreen(box)
	add_child(box)
	box.add_child(UIKit.label("THIS GAME EXISTS THANKS TO THE GENEROSITY OF", 26, Color(1, 1, 1, 0.65), "Light"))
	box.add_child(UIKit.label("UNVANQUISHED  ·  DUELYST  ·  0 A.D.", 56, UIKit.TEAL))
	box.add_child(UIKit.label(
		"Their artists, sound designers and developers released their work under free licenses.\n" +
		"Every model, texture, sound and piece of music here is theirs. Full credits are in the main menu.", 24, UIKit.WHITE, "Regular"))
	Overlay.set_black(1.0)
	Overlay.fade_to(0.0, 1.0)
	get_tree().create_timer(6.5).timeout.connect(_next)

func _input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_next()

func _next() -> void:
	if _done:
		return
	_done = true
	await Overlay.fade_to(1.0, 0.8)
	Flow.goto("title")
