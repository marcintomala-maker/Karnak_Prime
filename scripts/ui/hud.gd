class_name HUD
extends CanvasLayer
## Iron-Man style helmet HUD: sci-fi frame, sacred geometry that reddens with damage,
## Health/Toxic arcs, half-radial motion scanner, lantern + flare radial bars,
## Duelyst rune status "sentences", objective toasts, swarm warning, overmind markers.

var game: Game
var root: Control
var draw_layer: Control
var geo: Array[SacredGeometry] = []
var vignette: TextureRect
var under_rect: ColorRect
var toxic_rect: ColorRect
var toast: Label
var stealth: Label
var swarm_box: VBoxContainer
var swarm_timer: Label
var runes := {}
var build_menu: BuildMenu
var pause_menu: PauseMenu
var _damage_pulse := 0.0
var _toast_t := 0.0
var _stealth_t := 0.0
var _scan_t := 0.0
var _scan_dots: Array = []
var _sweep := 0.0
var _t := 0.0
var _markers: Array = []
var underwater := false

func setup(g: Game) -> void:
	game = g

func _ready() -> void:
	layer = 10
	root = Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.fullscreen(root)
	add_child(root)
	under_rect = ColorRect.new(); under_rect.color = Color(0.0, 0.03, 0.02, 0.92); UIKit.fullscreen(under_rect)
	under_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE; under_rect.visible = false; root.add_child(under_rect)
	toxic_rect = ColorRect.new(); toxic_rect.color = Color(0.25, 0.5, 0.05, 0.0); UIKit.fullscreen(toxic_rect)
	toxic_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(toxic_rect)
	vignette = TextureRect.new()
	vignette.texture = UIKit.ui("vignette")
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	vignette.modulate = Color(1, 0.1, 0.05, 0.0)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.fullscreen(vignette)
	root.add_child(vignette)
	# sacred geometry in the four corners of the visor
	for c in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var sg := SacredGeometry.new()
		sg.style = 1
		sg.radius = 210
		sg.intensity = 0.28
		sg.speed = 0.7 if c.x == 0 else -0.6
		sg.particles = 10
		UIKit.fullscreen(sg)
		sg.set_meta("corner", c)
		root.add_child(sg)
		geo.append(sg)
	draw_layer = Control.new()
	draw_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIKit.fullscreen(draw_layer)
	draw_layer.draw.connect(_draw_hud)
	root.add_child(draw_layer)
	toast = UIKit.label("", 64, UIKit.LIME)
	toast.add_theme_color_override("font_shadow_color", Color(0.2, 0.6, 0.1, 0.8))
	toast.add_theme_constant_override("shadow_outline_size", 16)
	toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast.position = Vector2(-700, 70); toast.size = Vector2(1400, 90)
	toast.modulate.a = 0.0
	root.add_child(toast)
	stealth = UIKit.label("STEALTH ATTACK  2X", 22, UIKit.LIME, "Bold")
	stealth.set_anchors_preset(Control.PRESET_CENTER)
	stealth.position = Vector2(-200, 60); stealth.size = Vector2(400, 30)
	stealth.modulate.a = 0.0
	root.add_child(stealth)
	swarm_box = VBoxContainer.new()
	swarm_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	swarm_box.position = Vector2(-500, 170); swarm_box.size = Vector2(1000, 160)
	swarm_box.alignment = BoxContainer.ALIGNMENT_CENTER
	swarm_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swarm_box.visible = false
	root.add_child(swarm_box)
	var sl := UIKit.label("SWARM INCOMING", 58, UIKit.RED)
	sl.add_theme_color_override("font_shadow_color", Color(1, 0, 0, 0.6))
	sl.add_theme_constant_override("shadow_outline_size", 14)
	swarm_box.add_child(sl)
	var hb := HBoxContainer.new(); hb.alignment = BoxContainer.ALIGNMENT_CENTER
	hb.add_theme_constant_override("separation", 40)
	for i in 3:
		var r := RuneText.new(); r.glyph_height = 24; r.color = UIKit.RED
		r.set_sentence("swarm %d" % i, 6, 4)
		hb.add_child(r)
	swarm_box.add_child(hb)
	swarm_timer = UIKit.label("60", 44, UIKit.RED)
	swarm_box.add_child(swarm_timer)
	# status rune sentences
	_add_rune("health", Vector2(70, -250), UIKit.RED, 2)
	_add_rune("toxic", Vector2(70, -290), UIKit.LIME, 5)
	_add_rune("ammo", Vector2(-420, -250), Color(1.0, 0.45, 0.3), 1)
	_add_rune("zone", Vector2(-260, 140), UIKit.TEAL, 3)
	_add_rune("lantern", Vector2(-420, -290), Color(0.5, 0.6, 1.0), 6)
	build_menu = BuildMenu.new()
	build_menu.game = game
	build_menu.visible = false
	root.add_child(build_menu)
	pause_menu = PauseMenu.new()
	pause_menu.game = game
	pause_menu.visible = false
	root.add_child(pause_menu)

func _add_rune(key: String, pos: Vector2, col: Color, faction: int) -> void:
	var r := RuneText.new()
	r.glyph_height = 26
	r.color = col
	r.set_sentence(key, 7, faction)
	var anchor := Control.PRESET_BOTTOM_LEFT if pos.x > 0 else Control.PRESET_BOTTOM_RIGHT
	if key == "zone":
		anchor = Control.PRESET_CENTER
	r.set_anchors_preset(anchor)
	r.position = pos
	r.visible = false
	root.add_child(r)
	runes[key] = r

# ---------------------------------------------------------------- events
func on_damage(amount: float, _from: Vector3) -> void:
	_damage_pulse = clampf(_damage_pulse + 0.25 + amount / 600.0, 0.0, 1.0)

func stealth_attack() -> void:
	_stealth_t = 2.0

func show_toast(text: String, color := UIKit.LIME, t := 3.0) -> void:
	toast.text = text
	toast.add_theme_color_override("font_color", color)
	_toast_t = t
	Sfx.play_ui("ui/objective", -4.0)

func set_underwater(v: bool) -> void:
	underwater = v

func open_build_menu() -> void:
	build_menu.open()

# ---------------------------------------------------------------- per frame
func _process(delta: float) -> void:
	if game == null or game.player == null:
		return
	_t += delta
	var p := game.player
	_damage_pulse = maxf(_damage_pulse - delta * 0.8, 0.0)
	var hf := p.health / Defs.MAX_HEALTH
	var hurt := clampf((1.0 - hf) * 0.8 + _damage_pulse, 0.0, 1.0)
	var tint := UIKit.TEAL.lerp(UIKit.RED, hurt)
	var vp := root.get_viewport_rect().size
	for sg in geo:
		var c: Vector2 = sg.get_meta("corner")
		sg.center_override = Vector2(c.x * vp.x, c.y * vp.y)
		sg.tint = tint
		sg.intensity = 0.22 + 0.3 * _damage_pulse
		sg.visible = p.alive
	vignette.modulate.a = clampf(_damage_pulse * 0.8 + (0.35 if hf < 0.25 else 0.0) * (0.6 + 0.4 * sin(_t * 4.0)), 0.0, 0.9)
	toxic_rect.color.a = p.toxicity() * 0.18 * (0.8 + 0.2 * sin(_t * 1.3))
	under_rect.visible = underwater
	_toast_t -= delta
	toast.modulate.a = clampf(_toast_t * 2.0, 0.0, 1.0)
	_stealth_t -= delta
	stealth.modulate.a = clampf(_stealth_t * 2.0, 0.0, 1.0) * (0.75 + 0.25 * sin(_t * 12.0))
	swarm_box.visible = game.swarm_active
	if game.swarm_active:
		swarm_timer.text = str(int(ceil(game.swarm_time_left)))
		var inside := game.player_in_swarm_zone()
		swarm_timer.add_theme_color_override("font_color", Color(0.4, 0.7, 1.0) if inside else UIKit.RED)
		swarm_box.modulate.a = 0.75 + 0.25 * sin(_t * 6.0)
	runes.health.visible = hf < 0.3
	runes.toxic.visible = p.toxicity() > 0.5
	runes.ammo.visible = p.weapons.is_low_ammo()
	runes.zone.visible = game.player_in_med or game.player_in_swarm_zone()
	runes.lantern.visible = p.lantern.fraction() < 0.33
	# scanner: refresh once per second, dots fade over the second
	_scan_t -= delta
	_sweep = 1.0 - clampf(_scan_t, 0.0, 1.0)
	if _scan_t <= 0.0:
		_scan_t = 1.0
		_scan_dots.clear()
		var yaw := p.rotation.y
		for a in game.director.aliens:
			if not is_instance_valid(a) or a.dead:
				continue
			var d: Vector3 = a.global_position - p.global_position
			var dist := Vector2(d.x, d.z).length()
			if dist > 100.0:
				continue
			var local := Vector2(d.x, d.z).rotated(yaw)
			_scan_dots.append(local / 100.0)
		Sfx.play_ui("ui/hover", -26.0, 0.6)
	_update_markers()
	draw_layer.queue_redraw()

func _update_markers() -> void:
	_markers.clear()
	var cam := game.player.cam
	for o in game.overminds:
		if not is_instance_valid(o) or o.dead:
			continue
		var top: Vector3 = o.global_position + Vector3.UP * 4.0
		if cam.is_position_behind(top):
			continue
		if cam.global_position.distance_to(top) > 220.0:
			continue
		if not game.los(cam.global_position, top):
			continue
		_markers.append(cam.unproject_position(top))

func _draw_hud() -> void:
	var p := game.player
	if p == null or not p.alive:
		return
	var vp := draw_layer.get_viewport_rect().size
	var hf := p.health / Defs.MAX_HEALTH
	var tint := UIKit.TEAL.lerp(UIKit.RED, clampf((1.0 - hf) * 0.8 + _damage_pulse, 0.0, 1.0))
	_draw_frame(vp, tint)
	# --- health + toxic arcs (bottom-left)
	var c := Vector2(150, vp.y - 150)
	_arc_bar(c, 104, hf, UIKit.RED.lerp(Color(1, 0.6, 0.5), 0.3), 10)
	_arc_bar(c, 84, p.toxic / Defs.MAX_TOXIC, UIKit.LIME, 8)
	var hi := UIKit.tex("res://assets/icons/health.png")
	draw_layer.draw_texture_rect(hi, Rect2(c - Vector2(26, 26), Vector2(52, 52)), false, Color(1, 0.45, 0.4, 0.85))
	# --- lantern + flare radials (bottom-right)
	var lc := Vector2(vp.x - 150, vp.y - 150)
	var lcol := Color(0.9, 0.95, 1.0) if not p.lantern.regenerating else Color(0.4, 1.0, 0.7)
	if not p.lantern.on and not p.lantern.regenerating:
		lcol = Color(0.5, 0.6, 0.8)
	_arc_bar(lc, 104, p.lantern.fraction(), lcol, 10)
	_arc_bar(lc, 84, p.weapons.flare_fraction(), Color(0.35, 1.0, 0.9) if p.weapons.flare_fraction() >= 1.0 else Color(0.2, 0.6, 0.55), 8)
	var glow := UIKit.ui("rune_glow")
	draw_layer.draw_texture_rect(glow, Rect2(lc - Vector2(36, 36), Vector2(72, 72)), false, Color(lcol, 0.9 if p.lantern.on else 0.35))
	var fl := UIKit.tex("res://assets/fx/flare.png")
	draw_layer.draw_texture_rect(fl, Rect2(lc + Vector2(40, 40), Vector2(36, 36)), false, Color(0.35, 1.0, 0.9, 0.9 if p.weapons.flare_fraction() >= 1.0 else 0.3))
	# --- scanner (bottom centre, half radial)
	var sc := Vector2(vp.x * 0.5, vp.y - 26)
	var R := 150.0
	draw_layer.draw_arc(sc, R, PI, TAU, 64, Color(tint, 0.55), 2.0, true)
	draw_layer.draw_arc(sc, R * 0.66, PI, TAU, 48, Color(tint, 0.25), 1.0, true)
	draw_layer.draw_arc(sc, R * 0.33, PI, TAU, 32, Color(tint, 0.2), 1.0, true)
	draw_layer.draw_line(sc - Vector2(R, 0), sc + Vector2(R, 0), Color(tint, 0.5), 2.0)
	var sw := PI + _sweep * PI
	draw_layer.draw_line(sc, sc + Vector2(cos(sw), sin(sw)) * R, Color(tint, 0.35), 2.0)
	var fade := 1.0 - _sweep
	for d in _scan_dots:
		var v: Vector2 = d
		if v.y > 0.02:
			continue      # behind: the scanner is a forward half-circle
		var pos := sc + v * R
		draw_layer.draw_circle(pos, 5.0, Color(1.0, 0.1, 0.08, 0.95 * fade))
		draw_layer.draw_circle(pos, 9.0, Color(1.0, 0.1, 0.08, 0.25 * fade))
	draw_layer.draw_circle(sc, 4.0, Color(tint, 0.9))
	# --- objective markers (Overmind)
	var dia := UIKit.ui("symbol_main_menu_diamond")
	for m in _markers:
		var pos2: Vector2 = m
		var s := 46.0 + 6.0 * sin(_t * 4.0)
		draw_layer.draw_texture_rect(dia, Rect2(pos2 - Vector2(s, s) * 0.5, Vector2(s, s)), false, Color(UIKit.LIME, 0.9))
		draw_layer.draw_arc(pos2, s * 0.62, 0, TAU, 24, Color(UIKit.LIME, 0.6), 2.0, true)

func _arc_bar(c: Vector2, r: float, frac: float, col: Color, w: float) -> void:
	var a0 := PI * 0.75
	var span := PI * 1.5
	draw_layer.draw_arc(c, r, a0, a0 + span, 48, Color(col, 0.15), w, true)
	if frac > 0.001:
		draw_layer.draw_arc(c, r, a0, a0 + span * clampf(frac, 0.0, 1.0), 48, Color(col, 0.9), w, true)

func _draw_frame(vp: Vector2, tint: Color) -> void:
	var col := Color(tint, 0.55)
	var m := 28.0
	var L := 120.0
	for corner in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
		var o := Vector2(m if corner.x == 0 else vp.x - m, m if corner.y == 0 else vp.y - m)
		var sx := 1.0 if corner.x == 0 else -1.0
		var sy := 1.0 if corner.y == 0 else -1.0
		draw_layer.draw_polyline(PackedVector2Array([o + Vector2(0, sy * L), o, o + Vector2(sx * L, 0)]), col, 3.0, true)
		draw_layer.draw_polyline(PackedVector2Array([o + Vector2(sx * 10, sy * (L * 0.55)), o + Vector2(sx * 10, sy * 10), o + Vector2(sx * L * 0.55, sy * 10)]), Color(col, 0.35), 1.5, true)
	# top bar with ticks
	var y := m + 4
	draw_layer.draw_line(Vector2(vp.x * 0.35, y), Vector2(vp.x * 0.65, y), Color(col, 0.4), 1.5)
	for i in 13:
		var x := vp.x * 0.35 + vp.x * 0.3 * i / 12.0
		draw_layer.draw_line(Vector2(x, y), Vector2(x, y + (10 if i % 3 == 0 else 5)), Color(col, 0.5), 1.5)
	# heading marker
	var yaw := fposmod(rad_to_deg(-game.player.rotation.y), 360.0)
	var hx := vp.x * 0.5
	draw_layer.draw_colored_polygon(PackedVector2Array([Vector2(hx - 6, y + 14), Vector2(hx + 6, y + 14), Vector2(hx, y + 6)]), Color(col, 0.8))
	draw_layer.draw_string(UIKit.font("Bold"), Vector2(hx - 20, y + 36), "%03d" % int(yaw), HORIZONTAL_ALIGNMENT_CENTER, 40, 16, Color(col, 0.7))
