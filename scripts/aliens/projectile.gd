class_name AlienProjectile
extends Node3D
## Lobbed poison blob (Trapper/Tyrant -> toxic cloud) or straight acid shot (Acid Tube).

var game: Game
var vel := Vector3.ZERO
var cloud := 0.0
var straight := false
var health_dmg := 0.0
var toxic_dmg := 0.0
var age := 0.0
var _sprite: Sprite3D

func lob(g: Game, from: Vector3, to: Vector3, cloud_size: float) -> void:
	game = g
	global_position = from
	cloud = cloud_size
	var flat := Vector2(to.x - from.x, to.z - from.z)
	var t := clampf(flat.length() / 16.0, 0.5, 1.6)
	var grav := Defs.GRAVITY * 0.8
	vel = Vector3(flat.x / t, 0, flat.y / t)
	vel.y = (to.y - from.y + 0.5 * grav * t * t) / t

func shoot(g: Game, from: Vector3, to: Vector3, hp: float, tox: float) -> void:
	game = g
	global_position = from
	straight = true
	health_dmg = hp
	toxic_dmg = tox
	vel = (to - from).normalized() * 19.0

func _ready() -> void:
	_sprite = Sprite3D.new()
	_sprite.texture = load("res://assets/fx/green_acid.png")
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sprite.shaded = false
	_sprite.modulate = Color(0.6, 1.0, 0.3)
	_sprite.pixel_size = 0.006 if not straight else 0.004
	add_child(_sprite)
	var l := OmniLight3D.new()
	l.light_color = Color(0.5, 1.0, 0.3)
	l.omni_range = 4.0
	l.light_energy = 0.8
	l.shadow_enabled = false
	l.light_specular = 0.0
	add_child(l)

func _physics_process(delta: float) -> void:
	age += delta
	if not straight:
		vel.y -= Defs.GRAVITY * 0.8 * delta
	var from := global_position
	var to := from + vel * delta
	var p := game.player
	if straight and p and p.alive and Geometry3D.get_closest_point_to_segment(p.global_position + Vector3.UP * 1.0, from, to).distance_to(p.global_position + Vector3.UP * 1.0) < 0.7:
		p.take_damage(health_dmg, toxic_dmg, from)
		game.fx.spit(to, -vel.normalized())
		Sfx.play_3d("alien/blob_impact", to, -4.0, 30.0)
		queue_free()
		return
	var hit := game.ray(from, to, 1 | 8)
	if hit or age > 5.0:
		var at: Vector3 = hit.position if hit else to
		Sfx.play_3d("alien/blob_impact", at, 0.0, 50.0)
		game.fx.spit(at, Vector3.UP)
		if cloud > 0.0:
			ToxicCloud.spawn(game, at, cloud)
		queue_free()
		return
	global_position = to
