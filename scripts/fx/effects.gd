class_name Effects
extends Node3D
## Pooled one-shot particle effects and short flash lights (hard caps keep it cheap).

const MAX_FLASH_LIGHTS := 8
var _pools := {}
var _pool_idx := {}
var _lights: Array[OmniLight3D] = []
var _light_t: Array[float] = []
var _light_e: Array[float] = []
var _light_idx := 0

func _ready() -> void:
	_make_pool("blood", 14, _blood_particles)
	_make_pool("sparks", 12, _spark_particles)
	_make_pool("spit", 8, _spit_particles)
	_make_pool("explosion", 6, _explosion_particles)
	_make_pool("smoke", 6, _smoke_particles)
	_make_pool("poof", 8, _poof_particles)
	for i in MAX_FLASH_LIGHTS:
		var l := OmniLight3D.new()
		l.shadow_enabled = false
		l.light_specular = 0.0
		l.visible = false
		add_child(l)
		_lights.append(l); _light_t.append(0.0); _light_e.append(0.0)

func _mat(tex_path: String, additive := false, color := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(tex_path)
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.disable_receive_shadows = true
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _base(p: CPUParticles3D, tex: String, additive: bool, size: float, color: Color) -> void:
	var q := QuadMesh.new(); q.size = Vector2(size, size)
	q.material = _mat(tex, additive, color)
	p.mesh = q
	p.one_shot = true
	p.emitting = false
	p.explosiveness = 0.95
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _blood_particles() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	_base(p, "res://assets/fx/green_acid.png", false, 0.32, Color(0.75, 1.0, 0.45))
	p.amount = 22; p.lifetime = 0.7
	p.direction = Vector3(0, 0, -1); p.spread = 55.0
	p.initial_velocity_min = 2.0; p.initial_velocity_max = 7.0
	p.gravity = Vector3(0, -12, 0)
	p.scale_amount_min = 0.5; p.scale_amount_max = 1.6
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 1)); g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	return p

func _spark_particles() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	_base(p, "res://assets/fx/spark.png", true, 0.09, Color(1.0, 0.85, 0.6))
	p.amount = 12; p.lifetime = 0.35
	p.direction = Vector3(0, 0, -1); p.spread = 60.0
	p.initial_velocity_min = 3.0; p.initial_velocity_max = 9.0
	p.gravity = Vector3(0, -9, 0)
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 1)); g.set_color(1, Color(1, 0.6, 0.3, 0))
	p.color_ramp = g
	return p

func _spit_particles() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	_base(p, "res://assets/fx/green_acid.png", true, 0.22, Color(0.6, 1.0, 0.3))
	p.amount = 26; p.lifetime = 0.35; p.explosiveness = 0.6
	p.direction = Vector3(0, 0, -1); p.spread = 7.0
	p.initial_velocity_min = 2.5; p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -2, 0)
	return p

func _explosion_particles() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	_base(p, "res://assets/fx/lc_fire.png", true, 2.2, Color(1.0, 0.75, 0.5))
	p.amount = 26; p.lifetime = 0.9
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; p.emission_sphere_radius = 1.0
	p.direction = Vector3.UP; p.spread = 180.0
	p.initial_velocity_min = 2.0; p.initial_velocity_max = 8.0
	p.gravity = Vector3(0, 2, 0)
	p.scale_amount_min = 0.6; p.scale_amount_max = 1.8
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 1)); g.set_color(1, Color(1, 0.4, 0.1, 0))
	p.color_ramp = g
	return p

func _smoke_particles() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	_base(p, "res://assets/fx/puff.png", false, 3.0, Color(0.08, 0.08, 0.08, 0.8))
	p.amount = 14; p.lifetime = 2.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; p.emission_sphere_radius = 1.5
	p.direction = Vector3.UP; p.spread = 70.0
	p.initial_velocity_min = 0.5; p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, 0.6, 0)
	p.scale_amount_min = 0.8; p.scale_amount_max = 2.0
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 0.8)); g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	return p

func _poof_particles() -> CPUParticles3D:
	var p := CPUParticles3D.new()
	_base(p, "res://assets/fx/flare.png", true, 0.8, Color(0.7, 1.0, 0.4))
	p.amount = 10; p.lifetime = 0.5
	p.direction = Vector3.UP; p.spread = 180.0
	p.initial_velocity_min = 0.5; p.initial_velocity_max = 2.5
	p.gravity = Vector3.ZERO
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 1)); g.set_color(1, Color(1, 1, 1, 0))
	p.color_ramp = g
	return p

func _make_pool(n: String, count: int, maker: Callable) -> void:
	var arr: Array = []
	for i in count:
		var p: CPUParticles3D = maker.call()
		add_child(p)
		arr.append(p)
	_pools[n] = arr
	_pool_idx[n] = 0

func _emit(n: String, pos: Vector3, dir := Vector3.UP, scale_mul := 1.0) -> void:
	var arr: Array = _pools[n]
	var i: int = _pool_idx[n]
	_pool_idx[n] = (i + 1) % arr.size()
	var p: CPUParticles3D = arr[i]
	p.restart()
	p.global_position = pos
	if dir.length_squared() > 0.001:
		var up := Vector3.UP if absf(dir.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
		p.global_transform = Transform3D(Basis.looking_at(dir, up), pos)
	p.scale = Vector3.ONE * scale_mul
	p.emitting = true

func flash(pos: Vector3, color: Color, energy: float, rng: float, time := 0.08) -> void:
	var li := _light_idx
	var l := _lights[li]
	_light_idx = (_light_idx + 1) % MAX_FLASH_LIGHTS
	l.global_position = pos
	l.light_color = color
	l.light_energy = energy
	l.omni_range = rng
	l.visible = true
	_light_t[li] = time
	_light_e[li] = energy

func _process(delta: float) -> void:
	for i in _lights.size():
		if _light_t[i] > 0.0:
			_light_t[i] -= delta
			_lights[i].light_energy = _light_e[i] * clampf(_light_t[i] / 0.08, 0.0, 1.0)
			if _light_t[i] <= 0.0:
				_lights[i].visible = false

# ---------------------------------------------------------------- public effects
func alien_hit(pos: Vector3, normal: Vector3) -> void:
	_emit("blood", pos, normal)
	flash(pos + normal * 0.3, Color(1.0, 0.7, 0.4), 0.9, 3.5, 0.06)

func world_hit(pos: Vector3, normal: Vector3) -> void:
	_emit("sparks", pos, normal)
	if randf() < 0.25:
		Sfx.play_3d("weapon/ricochet%d" % randi_range(1, 3), pos, -10.0, 30.0)

func overmind_hit(pos: Vector3, normal: Vector3) -> void:
	_emit("sparks", pos, normal)
	flash(pos + normal * 0.3, Color(0.6, 1.0, 0.3), 1.6, 4.0, 0.07)

func spit(pos: Vector3, dir: Vector3) -> void:
	_emit("spit", pos, dir)
	flash(pos, Color(0.6, 1.0, 0.3), 1.2, 3.0, 0.1)

func lime_burst(pos: Vector3, big := false) -> void:
	_emit("poof", pos, Vector3.UP, 4.0 if big else 1.0)
	flash(pos + Vector3.UP, Color(0.6, 1.0, 0.3), 6.0 if big else 2.0, 25.0 if big else 6.0, 0.4 if big else 0.12)

func explosion(pos: Vector3, radius: float) -> void:
	var s := clampf(radius / 4.0, 0.6, 3.0)
	_emit("explosion", pos, Vector3.UP, s)
	_emit("smoke", pos, Vector3.UP, s)
	flash(pos + Vector3.UP, Color(1.0, 0.6, 0.3), 3.0 * s, radius * 2.5, 0.25)
