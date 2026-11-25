extends Control
## MISSION COMPLETE card with mission statistics.

var _can_leave := false

func _ready() -> void:
	UIKit.fullscreen(self)
	var bg := ColorRect.new(); bg.color = Color.BLACK; UIKit.fullscreen(bg); add_child(bg)
	var g := SacredGeometry.new(); g.radius = 480; g.tint = UIKit.GOLD; g.speed = 0.4; g.intensity = 0.35
	UIKit.fullscreen(g); add_child(g)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	UIKit.fullscreen(v); add_child(v)
	var title := UIKit.label("MISSION COMPLETE", 92, Color(1.0, 0.95, 0.8))
	title.add_theme_color_override("font_shadow_color", Color(1.0, 0.75, 0.3, 0.6))
	title.add_theme_constant_override("shadow_outline_size", 20)
	v.add_child(title)
	var s := Flow.stats
	var t := int(s.time)
	v.add_child(UIKit.label("ALIENS KILLED   %d" % s.kills, 36, UIKit.WHITE, "Bold"))
	v.add_child(UIKit.label("STRUCTURES BUILT   %d" % s.built, 36, UIKit.WHITE, "Bold"))
	v.add_child(UIKit.label("TIME   %02d:%02d:%02d" % [t / 3600, (t / 60) % 60, t % 60], 36, UIKit.WHITE, "Bold"))
	var spacer := Control.new(); spacer.custom_minimum_size.y = 40; v.add_child(spacer)
	v.add_child(UIKit.label("THANK YOU FOR PLAYING :)", 44, UIKit.TEAL))
	Overlay.fade_to(0.0, 1.5)
	Sfx.play_ui("ui/victory_vo")
	Sfx.play_music("music_codex", 1.0)
	await get_tree().create_timer(4.0).timeout
	_can_leave = true
	var hint := UIKit.label("press any key", 20, Color(1, 1, 1, 0.4), "Light")
	v.add_child(hint)

func _input(event: InputEvent) -> void:
	if _can_leave and (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed():
		_can_leave = false
		Sfx.stop_music(1.5)
		await Overlay.fade_to(1.0, 1.0)
		Flow.goto("menu")
