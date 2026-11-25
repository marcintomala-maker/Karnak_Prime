class_name PauseMenu
extends Control
## Esc: PAUSED, Resume, Settings, Main Menu, and the state of both objectives.

var game: Game
var _box: VBoxContainer
var _eggs: Label
var _oms: Label

func _ready() -> void:
	UIKit.fullscreen(self)
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new(); dim.color = Color(0, 0.01, 0.02, 0.8); UIKit.fullscreen(dim); add_child(dim)
	var g := SacredGeometry.new(); g.radius = 380; g.intensity = 0.25; g.speed = 0.4
	UIKit.fullscreen(g); add_child(g)
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 18)
	UIKit.fullscreen(_box)
	add_child(_box)
	_box.add_child(UIKit.label("PAUSED", 84, UIKit.WHITE))
	_eggs = UIKit.label("", 30, UIKit.LIME, "Bold")
	_oms = UIKit.label("", 30, UIKit.LIME, "Bold")
	_box.add_child(_eggs)
	_box.add_child(_oms)
	var sp := Control.new(); sp.custom_minimum_size.y = 20; _box.add_child(sp)
	for b in [["RESUME", resume], ["SETTINGS", _settings], ["MAIN MENU", _menu]]:
		var btn := UIKit.button(b[0])
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.pressed.connect(b[1])
		_box.add_child(btn)

func open() -> void:
	visible = true
	_box.visible = true
	_eggs.text = "EGGS DESTROYED: %d/%d" % [game.eggs_destroyed, game.egg_total]
	_oms.text = "OVERMINDS DESTROYED: %d/%d" % [game.overminds_destroyed, Defs.OVERMIND_TOTAL]
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func resume() -> void:
	visible = false
	get_tree().paused = false
	if not game.player.in_menu:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _settings() -> void:
	_box.visible = false
	var cc := CenterContainer.new()
	UIKit.fullscreen(cc)
	add_child(cc)
	var p := SettingsPanel.new()
	cc.process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	cc.add_child(p)
	p.closed.connect(func(): _box.visible = true; cc.queue_free())

func _menu() -> void:
	get_tree().paused = false
	Sfx.stop_music(0.5)
	await Overlay.fade_to(1.0, 0.5)
	Flow.goto("menu")

func _unhandled_input(event: InputEvent) -> void:
	if visible and _box.visible and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		resume()
