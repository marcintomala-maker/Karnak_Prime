class_name Flare
extends Node3D
## Cold teal flare: fast lobbed projectile that sticks where it lands, flickers and
## lights ~20 m for 10 s, then fades over 5 s. Constant sparks while burning.

var vel := Vector3.ZERO
var stuck := false
var age := 0.0
var _light: OmniLight3D
var _sparks: CPUParticles3D
var _core: Sprite3D
var _noise := FastNoiseLite.new()

func launch(pos: Vector3, v: Vector3) -> void:
	global_position = pos
	vel = v

func _ready() -> void:
	add_to_group("flare")
	_noise.frequency = 6.0
	_noise.seed = randi()
	_light = OmniLight3D.new()
	_light.light_color = Color(0.35, 1.0, 0.92)
	_light.omni_range = Defs.FLARE_RANGE
	_light.omni_attenuation = 1.1
	_light.light_energy = 2.2
	_light.shadow_enabled = false
	_light.light_specular = 0.0
	add_child(_light)
	_core = Sprite3D.new()
	_core.texture = load("res://assets/fx/flare.png")
	_core.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_core.shaded = false
	_core.pixel_size = 0.004
	_core.modulate = Color(0.5, 1.0, 0.95)
	add_child(_core)
	_sparks = CPUParticles3D.new()
	var q := QuadMesh.new(); q.size = Vector2(0.06, 0.06)
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/fx/spark.png")
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_color = Color(0.6, 1.0, 0.95)
	m.vertex_color_use_as_albedo = true
	q.material = m
	_sparks.mesh = q
	_sparks.amount = 24
	_sparks.lifetime = 0.6
	_sparks.local_coords = false
	_sparks.direction = Vector3.UP
	_sparks.spread = 70.0
	_sparks.initial_velocity_min = 1.0
	_sparks.initial_velocity_max = 3.5
	_sparks.gravity = Vector3(0, -6, 0)
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 1)); g.set_color(1, Color(0.4, 1, 0.9, 0))
	_sparks.color_ramp = g
	_sparks.emitting = false
	add_child(_sparks)

func _physics_process(delta: float) -> void:
	age += delta
	if not stuck:
		vel.y -= Defs.GRAVITY * 0.7 * delta
		var from := global_position
		var to := from + vel * delta
		var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 8 | 16)
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if hit:
			global_position = hit.position + hit.normal * 0.05
			stuck = true
			_sparks.emitting = true
			Sfx.play_3d("weapon/flare_bounce", global_position, -4.0, 40.0)
			Sfx.play_3d("weapon/spark", global_position, -8.0, 30.0)
		else:
			global_position = to
	var life := Defs.FLARE_LIFE + Defs.FLARE_FADE
	var fade := 1.0 - clampf((age - Defs.FLARE_LIFE) / Defs.FLARE_FADE, 0.0, 1.0)
	var flick := 0.8 + 0.2 * _noise.get_noise_1d(age * 8.0) + 0.08 * sin(age * 31.0)
	_light.light_energy = 2.2 * fade * flick
	_core.modulate.a = fade
	if age > Defs.FLARE_LIFE + Defs.FLARE_FADE * 0.5:
		_sparks.emitting = false
	if age > life:
		queue_free()

## Used by AI: is a point lit by this flare?
func lights(p: Vector3) -> bool:
	return age < Defs.FLARE_LIFE + Defs.FLARE_FADE * 0.5 and global_position.distance_to(p) < Defs.FLARE_RANGE * 0.8
