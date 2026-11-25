class_name UIKit
extends RefCounted
## Shared UI helpers: fonts, colours, Duelyst-styled buttons and labels.

const TEAL := Color(0.35, 0.95, 0.95)
const LIME := Color(0.72, 1.0, 0.35)
const RED := Color(1.0, 0.18, 0.15)
const GOLD := Color(1.0, 0.82, 0.45)
const WHITE := Color(0.92, 0.96, 1.0)

static var _fonts := {}
static var _tex := {}

static func font(weight := "Black") -> FontFile:
	if not _fonts.has(weight):
		_fonts[weight] = load("res://assets/fonts/Lato-%s.ttf" % weight)
	return _fonts[weight]

static func tex(path: String) -> Texture2D:
	if not _tex.has(path):
		_tex[path] = load(path)
	return _tex[path]

static func ui(name: String) -> Texture2D:
	return tex("res://assets/ui/%s.png" % name)

static func label(text: String, size := 32, color := WHITE, weight := "Black") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(weight))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

static func _box(color: Color, border: Color, bw := 2) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(2)
	sb.skew = Vector2(0.18, 0)
	sb.content_margin_left = 24; sb.content_margin_right = 24
	sb.content_margin_top = 8; sb.content_margin_bottom = 8
	sb.shadow_color = Color(border.r, border.g, border.b, 0.35)
	sb.shadow_size = 0
	return sb

## Sci-fi menu button (code-drawn skewed panel, Lato font) with Duelyst UI sounds.
static func button(text: String, size := 30, accent := TEAL) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font("Black"))
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", accent.lerp(Color.WHITE, 0.4))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", accent)
	b.add_theme_color_override("font_focus_color", Color.WHITE)
	b.add_theme_stylebox_override("normal", _box(Color(0.02, 0.05, 0.08, 0.75), Color(accent, 0.55)))
	var hov := _box(Color(0.04, 0.16, 0.2, 0.9), accent, 2)
	hov.shadow_size = 10
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", _box(Color(0.1, 0.3, 0.35, 0.95), Color.WHITE))
	b.add_theme_stylebox_override("focus", hov)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(380, 62)
	b.mouse_entered.connect(func(): Sfx.play_ui("ui/hover", -8.0))
	b.pressed.connect(func(): Sfx.play_ui("ui/select", -4.0))
	return b

static func panel(alpha := 0.82) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.01, 0.025, 0.04, alpha)
	sb.border_color = Color(TEAL, 0.5)
	sb.set_border_width_all(2)
	sb.set_content_margin_all(28)
	p.add_theme_stylebox_override("panel", sb)
	return p

static func slider_style(s: HSlider) -> void:
	var g := StyleBoxFlat.new(); g.bg_color = Color(TEAL, 0.25); g.content_margin_top = 3; g.content_margin_bottom = 3
	var f := StyleBoxFlat.new(); f.bg_color = Color(TEAL, 0.9); f.content_margin_top = 3; f.content_margin_bottom = 3
	s.add_theme_stylebox_override("slider", g)
	s.add_theme_stylebox_override("grabber_area", f)
	s.add_theme_stylebox_override("grabber_area_highlight", f)

static func fullscreen(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.offset_left = 0; c.offset_top = 0; c.offset_right = 0; c.offset_bottom = 0
