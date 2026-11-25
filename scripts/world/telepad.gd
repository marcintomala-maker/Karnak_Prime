class_name Telepad
extends Node3D
## Static (unanimated) Unvanquished telenode pad. Walk onto it: hologram vanishes, PLING,
## coloured screen flash, +20 max Health (red) or Toxic (yellow) and +100 healed over 5 s.

var game: Game
var stat := "health"
var used := false
var _holo: Sprite3D
var _light: OmniLight3D
var _t := 0.0
var _radius := 1.3

func setup(g: Game, s: String) -> void:
	game = g
	stat = s

func color() -> Color:
	return Color(1.0, 0.18, 0.15) if stat == "health" else Color(1.0, 0.85, 0.15)

func _ready() -> void:
	var m := Buildable.make_model("telenode", 2.6)
	add_child(m)
	var ap := m.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if ap:
		ap.stop()
	var ab: AABB = m.get_meta("aabb")
	_radius = maxf(ab.size.x, ab.size.z) * 0.5
	# low walkable collision: the pad is easy to step onto
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = _radius * 0.9
	cyl.height = minf(ab.size.y, 0.3)
	cs.shape = cyl
	cs.position.y = cyl.height * 0.5
	body.add_child(cs)
	add_child(body)
	_holo = Sprite3D.new()
	_holo.texture = load("res://assets/icons/%s.png" % ("health" if stat == "health" else "toxic"))
	_holo.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_holo.shaded = false
	_holo.pixel_size = 1.2 / maxf(_holo.texture.get_width(), 1.0)
	_holo.modulate = Color(color(), 0.85)
	_holo.position.y = ab.size.y + 1.0
	_holo.visibility_range_end = 120.0
	add_child(_holo)
	_light = OmniLight3D.new()
	_light.light_color = color()
	_light.omni_range = 5.0
	_light.light_energy = 0.9
	_light.shadow_enabled = false
	_light.light_specular = 0.0
	_light.distance_fade_enabled = true
	_light.distance_fade_begin = 50.0
	_light.distance_fade_length = 15.0
	_light.position.y = ab.size.y + 0.8
	add_child(_light)

func _process(delta: float) -> void:
	if used:
		return
	_t += delta
	_holo.position.y = _light.position.y + 0.2 + sin(_t * 2.0) * 0.12
	_holo.modulate.a = 0.65 + 0.25 * sin(_t * 5.0)
	var p := game.player
	if p == null or not p.alive:
		return
	var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
	if d < _radius and absf(p.global_position.y - global_position.y) < 1.2:
		used = true
		_holo.visible = false
		_light.visible = false
		p.telepad_bonus(stat)
		Sfx.play_ui("ui/pling", 0.0)
		game.hud.flash_screen(color())
