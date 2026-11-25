extends Control
## Photosensitivity warning shown before anything else.

var _done := false

func _ready() -> void:
	UIKit.fullscreen(self)
	var bg := ColorRect.new(); bg.color = Color.BLACK; UIKit.fullscreen(bg); add_child(bg)
	var box := VBoxContainer.new()
	UIKit.fullscreen(box)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 26)
	add_child(box)
	var t := UIKit.label("PHOTOSENSITIVITY WARNING", 52, UIKit.RED)
	box.add_child(t)
	var body := UIKit.label(
		"This game contains flashing lights, muzzle flashes, explosions and sudden\n" +
		"changes between light and darkness that may trigger seizures in people with\n" +
		"photosensitive epilepsy. If you or anyone in your family has an epileptic\n" +
		"condition, consult a doctor before playing. Stop playing immediately if you\n" +
		"experience dizziness, altered vision, twitching or disorientation.", 28, UIKit.WHITE, "Regular")
	box.add_child(body)
	var cont := UIKit.label("press any key", 22, Color(1, 1, 1, 0.5), "Light")
	box.add_child(cont)
	Overlay.set_black(1.0)
	Overlay.fade_to(0.0, 0.8)
	get_tree().create_timer(9.0).timeout.connect(_next)

func _input(event: InputEvent) -> void:
	if (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_next()

func _next() -> void:
	if _done:
		return
	_done = true
	await Overlay.fade_to(1.0, 0.6)
	Flow.goto("intro")
