class_name Rocket
extends Node3D
## Swirling homing missile from the Rocket Turret. Explodes on arrival / impact.

var game: Game
var vel := Vector3.ZERO
var target := Vector3.ZERO
var age := 0.0
var _trail: CPUParticles3D

func launch(g: Game, from: Vector3, v: Vector3, tgt: Vector3) -> void:
	game = g
	global_position = from
	vel = v
	target = tgt

func _ready() -> void:
	var s := Sprite3D.new()
	s.texture = load("res://assets/fx/flare.png")
	s.modulate = Color(1.0, 0.7, 0.4)
	s.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.shaded = false
	s.pixel_size = 0.0025
	add_child(s)
	_trail = CPUParticles3D.new()
	var q := QuadMesh.new(); q.size = Vector2(0.5, 0.5)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/fx/puff.png")
	m.albedo_color = Color(0.35, 0.35, 0.38, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	q.material = m
	_trail.mesh = q
	_trail.amount = 30
	_trail.lifetime = 0.8
	_trail.local_coords = false
	_trail.gravity = Vector3.ZERO
	_trail.initial_velocity_max = 0.3
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 0.7)); g.set_color(1, Color(1, 1, 1, 0))
	_trail.color_ramp = g
	add_child(_trail)

func _physics_process(delta: float) -> void:
	age += delta
	var to := target - global_position
	var desired := to.normalized() * minf(34.0, 12.0 + age * 40.0)
	var wobble := Vector3(sin(age * 13.0 + get_instance_id()), cos(age * 11.0), sin(age * 9.0)) * maxf(0.0, 1.2 - age) * 8.0
	vel = vel.lerp(desired + wobble, clampf(delta * (1.5 + age * 4.0), 0.0, 1.0))
	var from := global_position
	var nxt := from + vel * delta
	var hit := game.ray(from, nxt, 1 | 4 | 16)
	if hit or to.length() < 1.2 or age > 4.0:
		_explode(hit.position if hit else global_position)
		return
	global_position = nxt

func _explode(p: Vector3) -> void:
	game.fx.explosion(p, Defs.ROCKET_RADIUS)
	Sfx.play_3d("human/explosion", p, -2.0, 80.0)
	game.explode(p, Defs.ROCKET_RADIUS, Defs.ROCKET_DAMAGE, false, null)
	queue_free()
