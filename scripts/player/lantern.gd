class_name Lantern
extends Node3D
## Flame-like white lantern (TAB). 2 min at full brightness, then fades over 1 min,
## turning bluer and darker the longer it burns. Regenerates 5x faster while off.

var on := true
var charge := Defs.LANTERN_MAX
var suppressed := false
var regenerating := false
var _near: OmniLight3D
var _mid: OmniLight3D
var _far: OmniLight3D
var _t := 0.0
var _noise := FastNoiseLite.new()

func _ready() -> void:
	_near = _make(3.4, 2.0, 1.0)
	_mid = _make(12.0, 1.7, 1.1)
	_far = _make(32.0, 0.35, 0.7)
	_noise.frequency = 3.5
	_noise.seed = 17

func _make(r: float, e: float, att: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.omni_range = r
	l.light_energy = e
	l.omni_attenuation = att
	l.shadow_enabled = false
	l.light_specular = 0.0
	l.set_meta("base", e)
	add_child(l)
	return l

func toggle() -> void:
	if not on and charge < 1.0:
		Sfx.play_ui("weapon/click", -6.0)
		return
	on = not on
	Sfx.play_ui("weapon/click", -8.0, 0.8 if on else 0.6)

func fraction() -> float:
	return charge / Defs.LANTERN_MAX

func _process(delta: float) -> void:
	_t += delta
	if on and not suppressed:
		charge = maxf(charge - delta, 0.0)
		regenerating = false
		if charge <= 0.0:
			on = false
	elif not on:
		charge = minf(charge + delta * Defs.LANTERN_REGEN, Defs.LANTERN_MAX)
		regenerating = charge < Defs.LANTERN_MAX
	var lit := on and not suppressed
	# brightness: full for the first 2 minutes, fades during the last minute
	var bright := clampf(charge / Defs.LANTERN_FADE, 0.0, 1.0)
	var burned := 1.0 - charge / Defs.LANTERN_MAX
	var col := Color(1.0, 0.97, 0.92).lerp(Color(0.32, 0.45, 1.0), clampf(burned * 1.15, 0.0, 1.0))
	var flick := 0.9 + 0.1 * _noise.get_noise_1d(_t * 10.0) + 0.04 * sin(_t * 23.0)
	for l in [_near, _mid, _far]:
		l.visible = lit
		l.light_color = col
		l.light_energy = float(l.get_meta("base")) * bright * flick * lerpf(1.0, 0.7, burned)
	position.x = -0.28 + _noise.get_noise_2d(_t * 3.0, 3.0) * 0.006
	position.y = -0.12 + _noise.get_noise_2d(_t * 3.0, 9.0) * 0.006
