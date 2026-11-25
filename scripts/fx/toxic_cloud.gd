class_name ToxicCloud
extends Node3D
## Poison fog cloud. Lifetime = 2 s per metre of diameter. Damages Toxic while inside.

var diameter := 1.5
var life := 3.0
var _age := 0.0
var _parts: CPUParticles3D

static func spawn(parent: Node, pos: Vector3, size_m: float) -> ToxicCloud:
	var c := ToxicCloud.new()
	c.diameter = size_m
	c.life = 2.0 * size_m
	parent.add_child(c)
	c.global_position = pos
	return c

func _ready() -> void:
	add_to_group("toxic_cloud")
	_parts = CPUParticles3D.new()
	var q := QuadMesh.new(); q.size = Vector2(1.6, 1.6) * clampf(diameter / 2.0, 0.8, 2.5)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/fx/spore.png")
	m.albedo_color = Color(0.35, 0.55, 0.2, 0.75)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.emission_enabled = true
	m.emission = Color(0.05, 0.12, 0.02)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	q.material = m
	_parts.mesh = q
	_parts.amount = int(clampf(diameter * 10.0, 14, 60))
	_parts.lifetime = 1.6
	_parts.preprocess = 0.8
	_parts.local_coords = true
	_parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_parts.emission_sphere_radius = diameter * 0.4
	_parts.direction = Vector3.UP; _parts.spread = 180.0
	_parts.initial_velocity_min = 0.1; _parts.initial_velocity_max = 0.5
	_parts.gravity = Vector3(0, 0.15, 0)
	_parts.scale_amount_min = 0.7; _parts.scale_amount_max = 1.4
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 0)); g.add_point(0.3, Color(1, 1, 1, 0.9)); g.set_color(1, Color(1, 1, 1, 0))
	_parts.color_ramp = g
	_parts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_parts)
	_parts.position.y = diameter * 0.3

func contains(p: Vector3) -> bool:
	if _age > life:
		return false
	var c := global_position + Vector3(0, diameter * 0.3, 0)
	return c.distance_to(p) < diameter * 0.5 + 0.35

func _process(delta: float) -> void:
	_age += delta
	if _age > life - 1.6:
		_parts.emitting = false
	if _age > life + 1.6:
		queue_free()
