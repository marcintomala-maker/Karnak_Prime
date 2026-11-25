class_name SacredGeometry
extends Control
## Rotating, pulsing "sacred geometry" built from Duelyst ring/glyph sprites plus
## code-drawn polygons (hexagram, triangles, circles). Used by menus and the HUD.

@export var tint := UIKit.TEAL
@export var radius := 300.0
@export var intensity := 1.0
@export var speed := 1.0
@export var particles := 28
@export var style := 0          # 0 = menu mandala, 1 = HUD corner, 2 = death/victory burst
var center_override := Vector2(-1, -1)
var _t := 0.0
var _layers: Array = []
var _dots: Array = []

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var L := [
		["symbol_main_menu_ring_outer", 1.0, 0.05, 0.9],
		["symbol_main_menu_ring_inner", 0.78, -0.09, 0.8],
		["rift_level_ring", 0.62, 0.0, 0.7],
		["replace_outer_ring_shine", 1.15, 0.13, 0.55],
		["dialogue_border", 0.45, -0.2, 0.6],
		["ring_segment", 0.9, 0.31, 0.7],
		["readiness", 0.34, -0.45, 0.8],
		["lines_towards_ring", 1.35, 0.03, 0.5],
	]
	if style == 1:
		L = [["symbol_main_menu_ring_outer", 1.0, 0.04, 0.7], ["ring_segment", 0.8, -0.25, 0.6],
			["rift_level_ring", 0.55, 0.0, 0.5], ["readiness", 0.4, 0.4, 0.6]]
	for l in L:
		_layers.append({"tex": UIKit.ui(l[0] + "_g"), "scale": l[1], "spin": l[2], "alpha": l[3]})
	var rng := RandomNumberGenerator.new()
	for i in particles:
		_dots.append({"a": rng.randf() * TAU, "r": rng.randf_range(0.2, 1.4), "s": rng.randf_range(0.05, 0.25),
			"size": rng.randf_range(4, 14), "ph": rng.randf() * TAU})

func _process(delta: float) -> void:
	_t += delta * speed
	queue_redraw()

func _center() -> Vector2:
	return center_override if center_override.x >= 0 else size * 0.5

func _draw() -> void:
	var c := _center()
	var pulse := 0.85 + 0.15 * sin(_t * 1.7)
	for i in _layers.size():
		var l: Dictionary = _layers[i]
		var t: Texture2D = l.tex
		var s: float = radius * 2.0 * l.scale * (1.0 + 0.03 * sin(_t * 1.3 + i))
		var col := Color(tint, l.alpha * intensity * pulse)
		draw_set_transform(c, _t * l.spin, Vector2.ONE)
		draw_texture_rect(t, Rect2(-s * 0.5, -s * 0.5, s, s), false, col)
	draw_set_transform(c, 0.0, Vector2.ONE)
	# code-drawn geometry: hexagram, rotating triangles, flower-of-life circles
	var a := Color(tint, 0.55 * intensity * pulse)
	var r := radius * 0.72
	for k in 2:
		var pts := PackedVector2Array()
		for j in 4:
			var ang := _t * (0.07 if k == 0 else -0.07) + k * PI / 3.0 + j * TAU / 3.0 - PI / 2
			pts.append(Vector2(cos(ang), sin(ang)) * r)
		draw_polyline(pts, a, 2.0, true)
	if style != 1:
		for j in 6:
			var ang := -_t * 0.05 + j * TAU / 6.0
			draw_arc(Vector2(cos(ang), sin(ang)) * radius * 0.36, radius * 0.36, 0, TAU, 64, Color(tint, 0.22 * intensity), 1.5, true)
		var sq := PackedVector2Array()
		for j in 5:
			var ang := _t * 0.11 + j * TAU / 4.0
			sq.append(Vector2(cos(ang), sin(ang)) * radius * 0.5)
		draw_polyline(sq, Color(tint, 0.35 * intensity), 1.5, true)
	# drifting glow dots (Duelyst dot orb sprite)
	var dot := UIKit.ui("dotorb_g")
	for d in _dots:
		var ang: float = d.a + _t * d.s
		var rr: float = radius * d.r * (1.0 + 0.05 * sin(_t + d.ph))
		var p := Vector2(cos(ang), sin(ang)) * rr
		var sz: float = d.size * (0.7 + 0.3 * sin(_t * 2.0 + d.ph))
		draw_texture_rect(dot, Rect2(p - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), false, Color(tint.lerp(Color.WHITE, 0.4), 0.8 * intensity))
