class_name RuneText
extends Control
## Pseudo-Akkadian status "sentences" assembled from Duelyst faction rune glyphs.
## The same seed always gives the same sentence, so each status reads like a fixed word.

static var _atlases := {}

@export var glyph_height := 26.0
@export var color := UIKit.TEAL
@export var pulse_speed := 2.0
var glyphs: Array = []      # [ [Texture2D, Rect2], ... ]
var _t := 0.0
var active := true

static func _atlas(faction: int) -> Dictionary:
	if not _atlases.has(faction):
		var tex: Texture2D = load("res://assets/runes/f%d_runes.png" % faction)
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/runes/f%d_runes.json" % faction))
		var rects: Array = []
		for k in data.keys():
			var f: Dictionary = data[k]
			rects.append(Rect2(f.x, f.y, f.w, f.h))
		_atlases[faction] = {"tex": tex, "rects": rects}
	return _atlases[faction]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_sentence(seed_text: String, length := 7, faction := 3) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(seed_text)
	glyphs.clear()
	var at := _atlas(faction)
	for i in length:
		if i > 0 and rng.randf() < 0.18:
			glyphs.append(null)     # word gap
			continue
		var r: Rect2 = at.rects[rng.randi() % at.rects.size()]
		glyphs.append([at.tex, r])
	var w := 0.0
	for g in glyphs:
		w += glyph_height * (0.5 if g == null else 0.62)
	custom_minimum_size = Vector2(w, glyph_height)
	size = custom_minimum_size
	queue_redraw()

func _process(delta: float) -> void:
	if visible:
		_t += delta
		queue_redraw()

func _draw() -> void:
	var x := 0.0
	var a := 0.55 + 0.45 * sin(_t * pulse_speed)
	for i in glyphs.size():
		var g = glyphs[i]
		if g == null:
			x += glyph_height * 0.5
			continue
		var r: Rect2 = g[1]
		var w := glyph_height * r.size.x / r.size.y
		var flick := 0.85 + 0.15 * sin(_t * 9.0 + i * 1.7)
		draw_texture_rect_region(g[0], Rect2(x, 0, w, glyph_height), r, Color(color, a * flick))
		x += w * 0.62 / (r.size.x / r.size.y) * (r.size.x / r.size.y)
