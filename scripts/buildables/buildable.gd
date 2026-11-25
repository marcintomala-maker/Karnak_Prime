class_name Buildable
extends Node3D
## Player structures (Unvanquished human buildables): Reactor, Med Station, MG Turret,
## Rocket Turret, Bomb (drill model), Overmind Destroyer (telenode model).

const ICONS := {"reactor": "energy", "medstation": "health", "mgturret": "ammo", "rocket": "ammo", "bomb": "attack", "destroyer": "timer"}

var game: Game
var kind := ""
var def: Dictionary
var hp := 1.0
var max_hp := 1.0
var built := false
var build_progress := 0.0
var powered := true
var reactor: Buildable = null        # reactor this structure draws energy from
var energy_used := 0                 # reactors only
var dependents: Array = []
var model: Node3D
var anim: AnimationPlayer
var body: StaticBody3D
var holo_icon: Sprite3D
var holo_label: Label3D
var _dead := false
var _t := 0.0
# kind specific
var pool := Defs.MED_POOL
var shots := Defs.MG_SHOTS
var rockets := Defs.ROCKETS
var _target: Node3D = null
var _scan_t := 0.0
var _fire_t := 0.0
var _salvo_t := 0.0
var _heal_snd_t := 0.0
var bomb_ready := false
var _bomb_light: OmniLight3D
var cone: MeshInstance3D
var _aabb := AABB()

## Instantiate an Unvanquished buildable model, normalised to `size` metres wide, base at y=0.
static func make_model(model_name: String, size: float) -> Node3D:
	var root := Node3D.new()
	var m: Node3D = load("res://assets/models/buildables/%s.glb" % model_name).instantiate()
	root.add_child(m)
	var aabb := Game.model_aabb(m)
	var s := size / maxf(aabb.size.x, aabb.size.z)
	m.scale = Vector3.ONE * s
	m.position = Vector3(-aabb.get_center().x * s, -aabb.position.y * s, -aabb.get_center().z * s)
	Game.prepare_materials(m)
	root.set_meta("aabb", AABB(Vector3(-aabb.size.x * s * 0.5, 0, -aabb.size.z * s * 0.5), aabb.size * s))
	return root

func setup(g: Game, k: String) -> void:
	game = g
	kind = k
	def = Defs.BUILDABLES[k]
	max_hp = def.hp
	hp = max_hp * 0.2

func _ready() -> void:
	add_to_group("player_building")
	model = make_model(def.model, def.size)
	add_child(model)
	_aabb = model.get_meta("aabb")
	anim = model.find_child("AnimationPlayer", true, false)
	body = StaticBody3D.new()
	body.collision_layer = 8
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(_aabb.size.x * 0.8, maxf(_aabb.size.y, 0.8), _aabb.size.z * 0.8)
	cs.shape = bs
	cs.position.y = bs.size.y * 0.5
	body.add_child(cs)
	body.set_meta("damage_target", self)
	add_child(body)
	holo_icon = Sprite3D.new()
	holo_icon.texture = load("res://assets/icons/%s.png" % ICONS[kind])
	holo_icon.pixel_size = 0.0016
	holo_icon.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	holo_icon.shaded = false
	holo_icon.modulate = Color(0.45, 1.0, 1.0, 0.85)
	holo_icon.position = Vector3(-0.22, _aabb.size.y + 0.55, 0)
	holo_icon.no_depth_test = true
	add_child(holo_icon)
	holo_label = Label3D.new()
	holo_label.font = UIKit.font("Black")
	holo_label.font_size = 72
	holo_label.pixel_size = 0.004
	holo_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	holo_label.modulate = Color(0.45, 1.0, 1.0, 0.9)
	holo_label.outline_size = 8
	holo_label.outline_modulate = Color(0, 0.3, 0.4, 0.5)
	holo_label.shaded = false
	holo_label.no_depth_test = true
	holo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	holo_label.position = Vector3(0.05, _aabb.size.y + 0.55, 0)
	add_child(holo_label)
	if kind == "mgturret":
		cone = _make_cone(Defs.MG_RANGE, Defs.MG_CONE)
		add_child(cone)
	if kind == "bomb":
		_bomb_light = OmniLight3D.new()
		_bomb_light.light_color = Color(1.0, 0.1, 0.05)
		_bomb_light.omni_range = 9.0
		_bomb_light.light_energy = 0.0
		_bomb_light.shadow_enabled = false
		_bomb_light.light_specular = 0.0
		_bomb_light.position.y = _aabb.size.y + 0.2
		add_child(_bomb_light)
	_play("construct", def.time)
	Sfx.play_3d("human/construct", global_position, -2.0, 40.0)

func radius() -> float:
	return maxf(_aabb.size.x, _aabb.size.z) * 0.5

func _play(a: String, fit_time := 0.0) -> void:
	if anim == null:
		return
	for cand in [a, a + "_loop"]:
		if anim.has_animation(cand):
			anim.play(cand)
			if fit_time > 0.0:
				var l := anim.get_animation(cand).length
				anim.speed_scale = clampf(l / fit_time, 0.05, 4.0)
			else:
				anim.speed_scale = 1.0
			return

## A holographic fan on the ground showing the turret's field of fire.
func _make_cone(r: float, deg: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 24
	var half := deg_to_rad(deg) * 0.5
	for i in n:
		var a0 := -half + (2.0 * half) * i / n
		var a1 := -half + (2.0 * half) * (i + 1) / n
		st.set_uv(Vector2(0, 0)); st.add_vertex(Vector3(0, 0.08, 0))
		st.set_uv(Vector2(1, float(i) / n)); st.add_vertex(Vector3(sin(a0) * r, 0.08, -cos(a0) * r))
		st.set_uv(Vector2(1, float(i + 1) / n)); st.add_vertex(Vector3(sin(a1) * r, 0.08, -cos(a1) * r))
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/holo_fan.gdshader")
	mi.material_override = sm
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

func repair(amount: float) -> void:
	if _dead:
		return
	hp = minf(hp + amount, max_hp)

func take_damage(amount: float, _from_player := false, _p := Vector3.ZERO, _n := Vector3.UP) -> void:
	if _dead:
		return
	if kind == "bomb":
		if _from_player:
			if bomb_ready:
				detonate()
			return
	if _from_player:
		return
	hp -= amount
	if randf() < 0.3:
		Sfx.play_3d("human/damage%d" % randi_range(1, 2), global_position, -6.0, 40.0)
	if hp <= 0.0:
		destroy()

func destroy(silent := false) -> void:
	if _dead:
		return
	_dead = true
	if not silent:
		game.fx.explosion(global_position + Vector3.UP * 0.8, 2.5)
		Sfx.play_3d("human/destroyed", global_position, 0.0, 60.0)
	for d in dependents:
		if is_instance_valid(d):
			d.set_powered(false)
	if reactor and is_instance_valid(reactor):
		reactor.energy_used = maxi(reactor.energy_used - 1, 0)
		reactor.dependents.erase(self)
	game.on_building_destroyed(self)
	queue_free()

func set_powered(p: bool) -> void:
	if powered == p:
		return
	powered = p
	if not p:
		_play("powerdown")
		Sfx.play_3d("human/powerdown", global_position, -4.0, 40.0)

func free_energy() -> int:
	return Defs.REACTOR_ENERGY - energy_used

func _process(delta: float) -> void:
	if _dead:
		return
	_t += delta
	if not built:
		build_progress += delta / def.time
		hp = minf(hp + max_hp * 0.8 * delta / def.time, max_hp)
		holo_label.text = "%d%%" % int(build_progress * 100.0)
		if build_progress >= 1.0:
			built = true
			_play("idle")
			Sfx.play_3d("weapon/repaired", global_position, -4.0, 40.0)
			game.on_building_complete(self)
		return
	match kind:
		"reactor": _reactor(delta)
		"medstation": _med(delta)
		"mgturret": _turret(delta)
		"rocket": _rocket(delta)
		"bomb": _bomb(delta)
		"destroyer": _destroyer(delta)

func _reactor(_d: float) -> void:
	holo_label.text = str(free_energy())

func _med(delta: float) -> void:
	holo_label.text = str(int(pool))
	if not powered or pool <= 0.0:
		return
	var p := game.player
	if p == null or not p.alive:
		return
	var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
	if d < 1.8 and absf(p.global_position.y - global_position.y) < 1.6:
		game.player_in_med = true
		var want_h := minf(p.max_health - p.health, Defs.MED_RATE * delta)
		var want_t := minf(p.max_toxic - p.toxic, Defs.MED_RATE * delta)
		var total := minf(want_h + want_t, pool)
		if total > 0.0:
			var k := total / maxf(want_h + want_t, 0.0001)
			p.heal(want_h * k, want_t * k)
			pool -= total
			_heal_snd_t -= delta
			if _heal_snd_t <= 0.0:
				_heal_snd_t = 1.2
				Sfx.play_3d("human/medistat_heal", global_position, -6.0, 25.0)
		if pool <= 0.0:
			set_powered(false)
			get_tree().create_timer(1.5).timeout.connect(destroy.bind(true))

func _acquire(range_m: float, cone_deg: float) -> Node3D:
	var best: Node3D = null
	var best_d := range_m
	var fwd := -global_transform.basis.z
	for a in game.director.aliens:
		if not is_instance_valid(a) or a.dead:
			continue
		var to: Vector3 = a.aim_point() - (global_position + Vector3.UP * 1.2)
		var dist := to.length()
		if dist > best_d:
			continue
		if cone_deg < 360.0:
			var f2 := Vector2(fwd.x, fwd.z).normalized()
			var t2 := Vector2(to.x, to.z).normalized()
			if rad_to_deg(acos(clampf(f2.dot(t2), -1.0, 1.0))) > cone_deg * 0.5:
				continue
		if not game.los(global_position + Vector3.UP * 1.2, a.aim_point()):
			continue
		best = a; best_d = dist
	return best

func _turret(delta: float) -> void:
	holo_label.text = str(shots)
	if not powered or shots <= 0:
		return
	_scan_t -= delta
	if _scan_t <= 0.0:
		_scan_t = 0.25
		_target = _acquire(Defs.MG_RANGE, Defs.MG_CONE)
	if _target == null or not is_instance_valid(_target) or _target.dead:
		return
	var to: Vector3 = _target.aim_point() - global_position
	var yaw := atan2(-to.x, -to.z) - rotation.y
	model.rotation.y = lerp_angle(model.rotation.y, yaw, clampf(delta * 8.0, 0.0, 1.0))
	_fire_t -= delta
	if _fire_t <= 0.0:
		_fire_t = 0.1
		shots -= 1
		var from := global_position + Vector3.UP * (_aabb.size.y * 0.7)
		var tp: Vector3 = _target.aim_point() + Vector3(randf_range(-0.2, 0.2), randf_range(-0.2, 0.2), randf_range(-0.2, 0.2))
		var hit := game.ray(from, from + (tp - from).normalized() * (Defs.MG_RANGE + 2.0), 1 | 4 | 16)
		if hit:
			Game.apply_hit(hit, Defs.CHAINGUN.damage, false)
		game.fx.flash(from + (tp - from).normalized() * 0.8, Color(1.0, 0.8, 0.5), 0.4, 6.0, 0.04)
		if shots % 2 == 0:
			Sfx.play_3d("human/mgturret_fire", from, -6.0, 60.0)
		if shots <= 0:
			set_powered(false)
			get_tree().create_timer(1.5).timeout.connect(destroy.bind(true))

func _rocket(delta: float) -> void:
	holo_label.text = str(rockets)
	if not powered or rockets <= 0:
		return
	_scan_t -= delta
	if _scan_t <= 0.0 and (_target == null or not is_instance_valid(_target) or _target.dead):
		_scan_t = 0.4
		_target = _acquire(Defs.ROCKET_RANGE, 360.0)
		if _target:
			Sfx.play_3d("human/rocket_lockon", global_position, -2.0, 50.0)
			_play("open")
	if _target == null or not is_instance_valid(_target) or _target.dead:
		return
	_salvo_t -= delta
	if _salvo_t <= 0.0:
		_salvo_t = 0.12
		rockets -= 1
		var r := Rocket.new()
		game.add_child(r)
		var from := global_position + Vector3.UP * (_aabb.size.y * 0.9)
		var spread := Vector3(randf_range(-1, 1), randf_range(0.6, 1.4), randf_range(-1, 1)).normalized()
		r.launch(game, from, spread * 14.0, _target.aim_point() + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5)))
		Sfx.play_3d("human/rocket_flash", from, -6.0, 60.0)
		if rockets <= 0:
			set_powered(false)
			get_tree().create_timer(2.5).timeout.connect(destroy.bind(true))

func _bomb(_d: float) -> void:
	var t := _t
	holo_label.text = ""
	if not bomb_ready:
		_bomb_light.light_energy = 2.0 if fmod(t, 0.3) < 0.15 else 0.0
		if build_progress >= 1.0:
			if not has_meta("arm_t"):
				set_meta("arm_t", _t)
			if _t - float(get_meta("arm_t")) >= 2.0:
				bomb_ready = true
				Sfx.play_3d("human/bomb_ready", global_position, 0.0, 60.0)
	else:
		_bomb_light.light_energy = 2.2

func detonate() -> void:
	if _dead:
		return
	_dead = true
	var p := global_position + Vector3.UP * 0.5
	game.fx.explosion(p, Defs.BOMB_RADIUS)
	game.fx.explosion(p + Vector3.UP * 2.0, Defs.BOMB_RADIUS * 0.6)
	Sfx.play_3d("human/big_explosion", p, 6.0, 200.0)
	game.explode(p, Defs.BOMB_RADIUS, 20000.0, true, self)
	if game.player and game.player.alive and game.player.global_position.distance_to(p) < Defs.BOMB_RADIUS:
		game.player.take_damage(Defs.BOMB_PLAYER_DAMAGE, 0.0, p)
	game.on_building_destroyed(self)
	queue_free()

func _destroyer(_d: float) -> void:
	holo_label.text = str(int(ceil(game.swarm_time_left))) if game.swarm_active else ""
