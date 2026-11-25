extends Control
## Gold/white sacred geometry + MISSION FAILED, then back to the main menu after 3 s.

func _ready() -> void:
	UIKit.fullscreen(self)
	var bg := ColorRect.new(); bg.color = Color.BLACK; UIKit.fullscreen(bg); add_child(bg)
	var g1 := SacredGeometry.new(); g1.radius = 460; g1.tint = UIKit.GOLD; g1.speed = 1.2; g1.intensity = 0.9; g1.particles = 60
	UIKit.fullscreen(g1); add_child(g1)
	var g2 := SacredGeometry.new(); g2.radius = 250; g2.tint = Color.WHITE; g2.speed = -1.6; g2.intensity = 0.6; g2.particles = 20
	UIKit.fullscreen(g2); add_child(g2)
	var l := UIKit.label("MISSION FAILED", 96, Color(1.0, 0.93, 0.75))
	l.add_theme_color_override("font_shadow_color", Color(1.0, 0.7, 0.2, 0.7))
	l.add_theme_constant_override("shadow_outline_size", 22)
	UIKit.fullscreen(l); add_child(l)
	Sfx.stop_music(0.5)
	Sfx.play_ui("ui/defeat")
	Overlay.fade_to(0.0, 0.6)
	var tw := create_tween().set_loops()
	tw.tween_property(g1, "intensity", 1.2, 0.6)
	tw.tween_property(g1, "intensity", 0.7, 0.6)
	await get_tree().create_timer(3.0).timeout
	tw.kill()
	await Overlay.fade_to(1.0, 0.8)
	Flow.goto("menu")
