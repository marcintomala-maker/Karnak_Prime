class_name Alien
extends Node3D
## Mobile alien AI (Unvanquished player-class models): Mantis, Marauder, Dragoon,
## Granger, Tyrant, Dretch (blind, harmless egg-seeker). Perception -> 1.5 s alert grace -> hunt. Unaware = 2x damage.

const LOOPED := ["stand", "walk", "run", "run_left", "run_right", "walk_left", "walk_right", "stand1", "idle"]

var game: Game
var type := "mantis"
var cfg: Dictionary
var hp := 100.0
var dead := false
var aware := false
var alerted := false
var swarm := false
var alert_t := 0.0
var lose_t := 0.0
var last_known := Vector3.ZERO
var target: Node3D
var model: Node3D
var anim: AnimationPlayer
var area: Area3D
var state := "roam"
var state_t := 0.0
var vel := Vector3.ZERO
var path := PackedVector3Array()
var path_i := 0
var repath_t := 0.0
var roam_target := Vector3.ZERO
var wall_normal := Vector3.ZERO
var perch_height := 0.0
var leap_from := Vector3.ZERO
var leap_to := Vector3.ZERO
var leap_time := 0.5
var leap_damage := 0.0
var leap_hit := false
var charge_dir := Vector3.ZERO
var charge_locked := false
var attack_cd := 0.0
var lob_cd := 4.0
var taunt_t := 3.0
var pain_t := 0.0
var _perceive_t := 0.0
var _height := 1.5
var _anim_cur := ""
var _dead_t := 0.0
var _rng := RandomNumberGenerator.new()

func setup(g: Game, t: String, pos: Vector3, is_swarm := false) -> void:
	game = g
	type = t
	cfg = Defs.ALIENS[t]
	hp = cfg.hp
	swarm = is_swarm
	position = pos
	_rng.randomize()

func _ready() -> void:
	add_to_group("alien")
	model = load("res://assets/models/%s.glb" % cfg.model).instantiate()
	add_child(model)
	var aabb := Game.model_aabb(model)
	var s: float = cfg.size / maxf(aabb.size.x, aabb.size.z)
	if type == "granger" or type == "dretch":
		s = cfg.size / maxf(aabb.size.y, maxf(aabb.size.x, aabb.size.z))
	model.scale = Vector3.ONE * s
	model.position = Vector3(-aabb.get_center().x * s, -aabb.position.y * s, -aabb.get_center().z * s)
	_height = aabb.size.y * s
	Game.prepare_materials(model)
	anim = model.find_child("AnimationPlayer", true, false)
	if anim:
		for a in LOOPED:
			if anim.has_animation(a):
				anim.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	area = Area3D.new()
	area.collision_layer = 4
	area.collision_mask = 0
	area.monitoring = false
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(aabb.size.x * s * 0.75, _height * 0.9, aabb.size.z * s * 0.75)
	cs.shape = bs
	cs.position.y = _height * 0.5
	area.add_child(cs)
	area.set_meta("damage_target", self)
	add_child(area)
	if type == "dretch":
		# blind, harmless, glows lime so it is easy to spot (and to follow to eggs)
		var l := OmniLight3D.new()
		l.light_color = Color(0.6, 1.0, 0.3)
		l.omni_range = 5.0
		l.light_energy = 1.1
		l.shadow_enabled = false
		l.light_specular = 0.0
		l.position.y = _height * 0.7
		add_child(l)
		state = "dretch"
		_dretch_next_egg()
	elif swarm:
		aware = true
		state = "chase"
	else:
		_pick_roam()
	taunt_t = _rng.randf_range(2.0, 7.0)
	_play("stand")

func aim_point() -> Vector3:
	return global_position + Vector3.UP * _height * 0.55

func _play(a: String, speed := 1.0) -> void:
	if anim == null:
		return
	if not anim.has_animation(a):
		var found := false
		for alt in [a + "1", a.split("_")[0], "stand", "idle"]:
			if anim.has_animation(alt):
				a = alt
				found = true
				break
		if not found:
			return
	if _anim_cur != a or not anim.is_playing():
		anim.play(a, 0.15)
		_anim_cur = a
	anim.speed_scale = speed

func _sound(s: String, vol := 0.0, dist := 60.0) -> void:
	Sfx.play_3d("alien/%s_%s" % [type, s], global_position, vol, dist, _rng.randf_range(0.9, 1.1))

# ---------------------------------------------------------------- perception
func hear(p: Vector3, radius: float) -> void:
	if dead or type == "dretch":
		return
	if global_position.distance_to(p) <= radius:
		last_known = game.player.global_position if game.player else p
		alert()

func alert() -> void:
	if dead or aware or alerted or type == "dretch":
		return
	alerted = true
	alert_t = Defs.ALERT_GRACE
	if state in ["perch", "climb"]:
		state = "drop"
		state_t = 0.0

func is_unaware() -> bool:
	return not aware      # includes the 1.5 s grace

func _perceive() -> void:
	if type == "dretch":
		return
	var p := game.player
	if p == null or not p.alive:
		return
	var eye := global_position + Vector3.UP * _height * 0.8
	var head := p.cam.global_position
	var dist := eye.distance_to(head)
	if aware:
		if dist < 12.0 or (dist < 80.0 and game.los(eye, head)):
			lose_t = 0.0
			last_known = p.global_position
		return
	if alerted or type == "mantis":
		return      # mantises are blind
	var view := 14.0
	if p.lantern.on and not p.lantern.suppressed:
		view = 42.0
	elif game.is_lit_by_flare(p.global_position):
		view = 32.0
	if dist > view:
		return
	var fwd := -global_transform.basis.z
	var to := (head - eye).normalized()
	if fwd.dot(to) < -0.2 and dist > 6.0:
		return
	if game.los(eye, head):
		last_known = p.global_position
		alert()

# ---------------------------------------------------------------- damage
func take_damage(amount: float, from_player := false, hit_pos := Vector3.ZERO, normal := Vector3.UP) -> void:
	if dead:
		return
	if type == "dretch":
		if hit_pos != Vector3.ZERO:
			game.fx.alien_hit(hit_pos, normal)
		die()
		return
	var mult := Defs.UNAWARE_MULT if is_unaware() else 1.0
	if from_player and mult > 1.0:
		game.hud.stealth_attack()
	hp -= amount * mult
	if hit_pos != Vector3.ZERO:
		game.fx.alien_hit(hit_pos, normal)
	game.director.ally_hurt(global_position)
	if game.player:
		last_known = game.player.global_position
	alert()
	if pain_t <= 0.0:
		pain_t = 1.5
		_sound("pain", -2.0)
	if hp <= 0.0:
		die()

func die() -> void:
	if dead:
		return
	dead = true
	state = "dead"
	area.collision_layer = 0
	_play("die")
	if anim and anim.has_animation(_anim_cur):
		anim.get_animation(_anim_cur).loop_mode = Animation.LOOP_NONE
	_sound("death", 0.0, 70.0)
	game.fx.alien_hit(aim_point(), Vector3.UP)
	if type == "dretch":
		game.fx.splat(aim_point())
		for c in get_children():
			if c is OmniLight3D:
				c.queue_free()
	Flow.stats.kills += 1
	game.director.on_alien_died(self)

# ---------------------------------------------------------------- movement helpers
func _pick_roam() -> void:
	state = "roam"
	state_t = 0.0
	if type == "mantis" and not game.eggs.is_empty():
		# tend eggs: wander from egg to egg nearby
		var best: Vector3 = global_position
		for i in 6:
			var e: Node3D = game.eggs[_rng.randi() % game.eggs.size()]
			if is_instance_valid(e) and e.global_position.distance_to(global_position) < 70.0:
				best = e.global_position
				break
		roam_target = best
	else:
		var dir := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
		roam_target = global_position + dir * _rng.randf_range(15.0, 45.0)
	path = game.data.find_path(global_position, roam_target)
	path_i = 0

func _follow(target_pos: Vector3, speed: float, delta: float, repath_every := 0.7) -> bool:
	repath_t -= delta
	if repath_t <= 0.0 or path.is_empty():
		repath_t = repath_every * _rng.randf_range(0.8, 1.2)
		path = game.data.find_path(global_position, target_pos)
		path_i = 0
	var goal := target_pos
	while path_i < path.size():
		var wp := path[path_i]
		if Vector2(wp.x - global_position.x, wp.z - global_position.z).length() < 1.6:
			path_i += 1
		else:
			goal = wp
			break
	var to := goal - global_position
	to.y = 0
	var arrived := to.length() < 1.0 and path_i >= path.size()
	var desired := to.normalized() * speed if to.length() > 0.05 else Vector3.ZERO
	desired += _separation() * speed * 0.6
	vel = vel.lerp(desired, clampf(delta * 8.0, 0.0, 1.0))
	_move(delta)
	return arrived

func _separation() -> Vector3:
	var push := Vector3.ZERO
	for o in game.director.aliens:
		if o == self or not is_instance_valid(o) or o.dead:
			continue
		var d: Vector3 = global_position - o.global_position
		d.y = 0
		var l := d.length()
		var r: float = 1.2 if type != "tyrant" else 3.0
		if l < r and l > 0.001:
			push += d / l * (r - l) / r
	return push

func _move(delta: float) -> void:
	var nxt := global_position + vel * delta
	nxt.y = global_position.y
	if not game.data.is_walkable(nxt) and game.data.is_walkable(global_position):
		# slide along blocked cells
		var nx := Vector3(nxt.x, nxt.y, global_position.z)
		var nz := Vector3(global_position.x, nxt.y, nxt.z)
		if game.data.is_walkable(nx):
			nxt = nx
		elif game.data.is_walkable(nz):
			nxt = nz
		else:
			nxt = global_position
			vel = Vector3.ZERO
	var gy := game.data.nav_height_at(nxt.x, nxt.z)
	nxt.y = lerpf(global_position.y, gy, clampf(delta * 12.0, 0.0, 1.0))
	global_position = nxt
	var flat := Vector2(vel.x, vel.z)
	if flat.length() > 0.3:
		var yaw := atan2(-vel.x, -vel.z)
		rotation.y = lerp_angle(rotation.y, yaw, clampf(delta * 10.0, 0.0, 1.0))
	model.rotation = model.rotation.lerp(Vector3.ZERO, clampf(delta * 6.0, 0.0, 1.0))

func _face(p: Vector3, delta: float) -> void:
	var to := p - global_position
	if Vector2(to.x, to.z).length() > 0.1:
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), clampf(delta * 10.0, 0.0, 1.0))

func _locomotion_anim(speed: float) -> void:
	var v := Vector2(vel.x, vel.z).length()
	if v < 0.4:
		_play("stand")
	elif v < cfg.speed * 0.5:
		_play("walk", clampf(v / 2.5, 0.6, 2.5))
	else:
		_play("run", clampf(v / (cfg.speed * 0.7), 0.8, 2.2))

# ---------------------------------------------------------------- main loop
func _physics_process(delta: float) -> void:
	if dead:
		_dead_t += delta
		if _dead_t > 8.0:
			queue_free()
		return
	state_t += delta
	attack_cd -= delta
	lob_cd -= delta
	pain_t -= delta
	_perceive_t -= delta
	if _perceive_t <= 0.0:
		_perceive_t = 0.25 + _rng.randf() * 0.1
		_perceive()
	if alerted and not aware:
		alert_t -= delta
		if alert_t <= 0.0:
			aware = true
			alerted = false
			lose_t = 0.0
			if state not in ["drop", "leap"]:
				state = "chase"
			if _rng.randf() < 0.6:
				_sound("taunt", -2.0, 70.0)
	if aware and not swarm:
		lose_t += delta
		if lose_t > 20.0:
			aware = false
			_pick_roam()
	# creepy dragoon calls
	if type == "dragoon":
		taunt_t -= delta
		if taunt_t <= 0.0:
			taunt_t = _rng.randf_range(3.0, 7.0)
			if game.player and global_position.distance_to(game.player.global_position) < 90.0:
				_sound("taunt", 0.0, 90.0)
	match state:
		"dretch": _dretch(delta)
		"roam": _roam(delta)
		"idle": _idle(delta)
		"climb": _climb(delta)
		"perch": _perch(delta)
		"drop": _drop(delta)
		"chase": _chase(delta)
		"windup": _windup(delta)
		"leap": _leap(delta)
		"charge": _charge(delta)
		"recover": _recover(delta)
		"stalk": _stalk(delta)

# ---- dretch: walks to the nearest egg, then on to a random egg within 300 m
var _egg_target: Node3D = null

func _dretch_next_egg() -> void:
	var near: Array = []
	var best: Node3D = null
	var best_d := INF
	for e in game.eggs:
		if not is_instance_valid(e) or e == _egg_target:
			continue
		var d: float = e.global_position.distance_to(global_position)
		if d < best_d:
			best_d = d; best = e
		if d < 300.0:
			near.append(e)
	if _egg_target == null:
		_egg_target = best                     # first: the nearest egg
	elif not near.is_empty():
		_egg_target = near[_rng.randi() % near.size()]
	else:
		_egg_target = best
	path = PackedVector3Array()
	repath_t = 0.0

func _dretch(delta: float) -> void:
	var p := game.player
	if p and p.alive:
		var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
		if d < 0.95 and absf(p.global_position.y - global_position.y) < 1.4:
			die()          # stepped on: splat
			return
	if _egg_target == null or not is_instance_valid(_egg_target):
		_dretch_next_egg()
		if _egg_target == null:
			vel = vel.lerp(Vector3.ZERO, delta * 4.0)
			_move(delta)
			_play("stand")
			return
	var arrived := _follow(_egg_target.global_position, cfg.speed, delta, 2.0)
	_locomotion_anim(cfg.speed)
	if arrived or global_position.distance_to(_egg_target.global_position) < 2.0:
		_dretch_next_egg()

func _roam(delta: float) -> void:
	if alerted:
		vel = vel.lerp(Vector3.ZERO, delta * 6.0)
		_move(delta)
		if game.player:
			_face(game.player.global_position, delta)
		_play("stand")
		return
	var speed: float = cfg.speed * (0.32 if type != "mantis" else 0.55)
	var arrived := _follow(roam_target, speed, delta, 2.5)
	_locomotion_anim(speed)
	if arrived or state_t > 25.0:
		var r := _rng.randf()
		if type in ["marauder", "dragoon", "trapper"] and r < 0.45 and _try_climb():
			return
		state = "idle"
		state_t = 0.0

func _idle(delta: float) -> void:
	vel = vel.lerp(Vector3.ZERO, delta * 6.0)
	_move(delta)
	_play("stand")
	if alerted and game.player:
		_face(game.player.global_position, delta)
		return
	if state_t > _rng.randf_range(2.0, 6.0):
		_pick_roam()

# ---- wall climbing (visual: the body turns to the wall and crawls up its face)
func _try_climb() -> bool:
	var base := global_position + Vector3.UP * 1.0
	for i in 6:
		var a := _rng.randf() * TAU
		var dir := Vector3(cos(a), 0, sin(a))
		var hit := game.ray(base, base + dir * 5.0, 1)
		if hit and absf(hit.normal.y) < 0.3:
			wall_normal = hit.normal
			global_position = Vector3(hit.position.x, global_position.y, hit.position.z) + wall_normal * (_height * 0.35)
			perch_height = _rng.randf_range(4.0, 13.0)
			state = "climb"
			state_t = 0.0
			return true
	return false

func _wall_basis() -> Basis:
	# body "up" = wall normal, body "forward" = world up
	var up := wall_normal
	var fwd := Vector3.UP
	var right := fwd.cross(up).normalized()
	return Basis(right, up, -fwd).orthonormalized()

func _climb(delta: float) -> void:
	var ground := game.data.nav_height_at(global_position.x, global_position.z)
	var step: float = cfg.speed * 0.45 * delta
	var probe: Vector3 = global_position + Vector3.UP * (step + 0.6)
	var still_wall := game.ray(probe, probe - wall_normal * (_height * 0.35 + 1.2), 1)
	if not still_wall or global_position.y - ground >= perch_height:
		state = "perch"
		state_t = 0.0
		return
	global_position.y += step
	model.global_basis = _wall_basis().scaled(model.scale)
	_play("run", 1.2)

func _perch(delta: float) -> void:
	model.global_basis = _wall_basis().scaled(model.scale)
	_play("stand")
	# occasional sideways crawl
	if fmod(state_t, 5.0) < 1.0:
		var tangent := wall_normal.cross(Vector3.UP).normalized()
		var p := global_position + tangent * sin(state_t) * delta * 2.0
		if game.ray(p, p - wall_normal * (_height * 0.35 + 1.0), 1):
			global_position = p
	if alerted or aware:
		state = "drop"; state_t = 0.0
	elif state_t > _rng.randf_range(6.0, 16.0):
		state = "drop"; state_t = 0.0

func _drop(_delta: float) -> void:
	# leap off the wall: toward the player if we noticed them, else straight down/out
	var to := global_position + wall_normal * 3.0
	if (alerted or aware) and game.player:
		to = game.player.global_position.lerp(global_position, 0.3)
	to.y = game.data.nav_height_at(to.x, to.z)
	var cell := game.data.nearest_walkable(to, 4)
	if cell.x >= 0:
		to = game.data.cell_center(cell.x, cell.y)
	_start_leap(to, 0.0, 0.8)

# ---- hunting
func _chase(delta: float) -> void:
	var p := game.player
	var tgt_pos := last_known
	target = p
	# sometimes go for a structure that is closer than the player
	var b: Node3D = game.director.building_target_for(self)
	if b:
		target = b
		tgt_pos = b.global_position
	elif p and p.alive:
		tgt_pos = p.global_position if lose_t < 1.0 else last_known
	var dist := global_position.distance_to(tgt_pos)
	match type:
		"dragoon":
			if dist > 6.0 and dist < 25.0 and attack_cd <= 0.0 and game.los(aim_point(), tgt_pos + Vector3.UP):
				if dist < 20.0 and _rng.randf() < 0.3:
					_start_leap(tgt_pos, cfg.pounce, 0.85, 3.0)
					_sound("pounce", 0.0, 80.0)
				else:
					state = "charge"; state_t = 0.0; charge_locked = false
					charge_dir = (tgt_pos - global_position).normalized()
					_sound("attack", 0.0, 80.0)
				return
			if dist > 30.0 and _rng.randf() < 0.004:
				state = "stalk"; state_t = 0.0
				roam_target = tgt_pos + Vector3(_rng.randf_range(-30, 30), 0, _rng.randf_range(-30, 30))
				return
		"tyrant":
			if lob_cd <= 0.0 and dist > 8.0 and dist < 35.0:
				lob_cd = _rng.randf_range(6.0, 9.0)
				_lob(tgt_pos, 4.0)
	var reach := _attack_reach()
	if dist < reach and attack_cd <= 0.0:
		_begin_attack(tgt_pos, dist)
		return
	_follow(tgt_pos, cfg.speed, delta, 0.5)
	_locomotion_anim(cfg.speed)

func _attack_reach() -> float:
	match type:
		"mantis": return 5.0
		"marauder": return 5.0
		"granger": return 1.8
		"tyrant": return 3.6
		"dragoon": return 2.4
	return 2.0

func _begin_attack(tgt_pos: Vector3, _dist: float) -> void:
	match type:
		"mantis":
			_start_leap(tgt_pos, cfg.attack, 0.42, 0.8)
			_sound("attack", -2.0)
		"marauder":
			_start_leap(tgt_pos, cfg.attack, 0.45, 1.6)
			_sound("jump", -2.0)
		_:
			state = "windup"; state_t = 0.0
			_play("attack")
			if type == "tyrant":
				_sound("prepare", 0.0, 70.0)

func _windup(delta: float) -> void:
	vel = Vector3.ZERO
	var tp: Vector3 = target.global_position if is_instance_valid(target) else last_known
	_face(tp, delta)
	var wind: float = {"granger": 0.35, "tyrant": 0.3, "dragoon": 0.35}.get(type, 0.3)
	if state_t < wind:
		return
	# strike
	var fwd := -global_transform.basis.z
	if type == "granger":
		var mouth := global_position + Vector3.UP * _height * 0.5 + fwd * 0.4
		game.fx.spit(mouth, fwd)
		_sound("attack", -4.0)
	else:
		_sound("attack", 0.0, 70.0)
	var range_: float = {"granger": 2.0, "tyrant": 4.2, "dragoon": 2.8}.get(type, 2.0)
	if target == game.player:
		var p := game.player
		var to := p.global_position - global_position
		if p.alive and to.length() < range_ and fwd.dot(to.normalized()) > 0.35:
			p.take_damage(cfg.attack, cfg.toxic, global_position)
	elif is_instance_valid(target) and target.global_position.distance_to(global_position) < range_ + 1.5:
		target.take_damage(cfg.attack * 0.5)
	attack_cd = float({"granger": 0.8, "tyrant": 1.3, "dragoon": 1.2}.get(type, 1.0))
	state = "recover"; state_t = 0.0

func _recover(delta: float) -> void:
	vel = vel.lerp(Vector3.ZERO, delta * 4.0)
	_move(delta)
	_play("stand")
	if state_t > (0.5 if type == "granger" else 0.9):
		state = "chase"

# ---- leaps & pounces (ballistic, no steering once launched)
func _start_leap(to: Vector3, damage: float, t: float, arc := 1.2) -> void:
	leap_from = global_position
	leap_to = to
	leap_time = t
	leap_damage = damage
	leap_hit = false
	set_meta("arc", arc)
	state = "leap"
	state_t = 0.0
	_play("jump")
	model.rotation = Vector3.ZERO
	_face(to, 1.0)

func _leap(_delta: float) -> void:
	var k := clampf(state_t / leap_time, 0.0, 1.0)
	var p := leap_from.lerp(leap_to, k)
	p.y += sin(k * PI) * float(get_meta("arc", 1.2))
	global_position = p
	if leap_damage > 0.0 and not leap_hit and game.player and game.player.alive:
		if global_position.distance_to(game.player.global_position + Vector3.UP * 0.6) < maxf(1.4, _height * 0.6):
			leap_hit = true
			game.player.take_damage(leap_damage, cfg.toxic, global_position)
	if k >= 1.0:
		var g := game.data.nav_height_at(global_position.x, global_position.z)
		global_position.y = g
		_play("land")
		attack_cd = 1.0 if type != "dragoon" else 2.0
		state = "recover" if aware or alerted else "roam"
		state_t = 0.0
		if state == "roam":
			_pick_roam()

func _charge(delta: float) -> void:
	var p := game.player
	if p == null:
		state = "chase"; return
	var to := p.global_position - global_position
	to.y = 0
	if not charge_locked:
		if to.length() < 2.0:
			charge_locked = true     # committed: the player can still sidestep
		else:
			charge_dir = charge_dir.lerp(to.normalized(), clampf(delta * 3.0, 0.0, 1.0)).normalized()
	vel = charge_dir * 15.5
	var before := global_position
	_move(delta)
	_play("run", 2.0)
	if global_position.distance_to(before) < 0.01 and state_t > 0.2:
		state = "recover"; state_t = 0.0; attack_cd = 2.5
		return
	if p.alive and to.length() < 1.6 and not leap_hit:
		leap_hit = true
		p.take_damage(cfg.attack, 0.0, global_position)
	if (charge_locked and state_t > 0.6 and to.dot(charge_dir) < -4.0) or state_t > 4.0:
		leap_hit = false
		state = "recover"; state_t = 0.0; attack_cd = 2.5

func _stalk(delta: float) -> void:
	var arrived := _follow(roam_target, cfg.speed, delta, 1.5)
	_locomotion_anim(cfg.speed)
	if arrived or state_t > 8.0:
		if _rng.randf() < 0.5 and _try_climb():
			perch_height = _rng.randf_range(4.0, 9.0)
			return
		state = "chase"

func _trapper_ai(delta: float, tgt_pos: Vector3, dist: float) -> void:
	# keep 9-18 m away, skitter chaotically, lob poison blobs
	if state_t > 1.2 or path.is_empty():
		state_t = 0.0
		var away := (global_position - tgt_pos).normalized()
		var side := away.cross(Vector3.UP) * (1.0 if _rng.randf() < 0.5 else -1.0)
		var want := 13.0
		roam_target = tgt_pos + (away * want + side * _rng.randf_range(4.0, 10.0))
		if _rng.randf() < 0.12 and _try_climb():
			perch_height = _rng.randf_range(3.0, 7.0)
			return
	_follow(roam_target, cfg.speed, delta, 0.6)
	_locomotion_anim(cfg.speed)
	if lob_cd <= 0.0 and dist < 26.0 and game.los(aim_point(), tgt_pos + Vector3.UP):
		lob_cd = _rng.randf_range(2.5, 4.0)
		_lob(tgt_pos, 1.5)

func _lob(to: Vector3, cloud: float) -> void:
	var pr := AlienProjectile.new()
	game.add_child(pr)
	pr.lob(game, aim_point() + Vector3.UP * 0.4, to + Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)), cloud)
	_sound("attack", -2.0)
	_play("attack")
