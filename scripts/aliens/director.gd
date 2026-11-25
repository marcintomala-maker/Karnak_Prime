class_name Director
extends Node
## Alien population: ambient roaming groups (spawned out of sight, despawned when far & calm),
## Left-4-Dead style small hordes with an audio cue, and Overmind SWARM waves.

var game: Game
var aliens: Array = []
var _rng := RandomNumberGenerator.new()
var _tick := 0.0
var horde_t := 90.0
var swarm_t := 0.0
var _swarm_alive: Array = []

const GROUPS := {
	"mantis": [3, 6],
	"marauder": [2, 6],
	"granger": [5, 20],
	"dretch": [2, 4],
	"dragoon": [1, 1],
}

func setup(g: Game) -> void:
	game = g
	_rng.randomize()
	horde_t = _rng.randf_range(80.0, 140.0)

func noise(p: Vector3, radius: float) -> void:
	for a in aliens:
		if is_instance_valid(a) and not a.dead:
			a.hear(p, radius)
	for t in game.trappers:
		if is_instance_valid(t) and not t.dead and t.global_position.distance_to(p) <= radius:
			t.aggro()

func ally_hurt(p: Vector3) -> void:
	for a in aliens:
		if is_instance_valid(a) and not a.dead and a.global_position.distance_to(p) < Defs.ALLY_ALERT_RADIUS:
			a.alert()
	for t in game.trappers:
		if is_instance_valid(t) and not t.dead and t.global_position.distance_to(p) < Defs.ALLY_ALERT_RADIUS:
			t.aggro()

func on_alien_died(a: Alien) -> void:
	aliens.erase(a)
	_swarm_alive.erase(a)

## Chance-based: if a player structure is meaningfully closer than the player, go for it.
func building_target_for(a: Alien) -> Node3D:
	if game.player_buildings.is_empty() or game.player == null:
		return null
	if a.has_meta("bt"):
		var t = a.get_meta("bt")
		if t != null and is_instance_valid(t):
			return t
		a.remove_meta("bt")
		return null
	if a.has_meta("bt_checked"):
		return null
	a.set_meta("bt_checked", true)
	var pd := a.global_position.distance_to(game.player.global_position)
	for b in game.player_buildings:
		if is_instance_valid(b) and a.global_position.distance_to(b.global_position) < pd * 0.6 and _rng.randf() < 0.45:
			a.set_meta("bt", b)
			return b
	return null

func count_type(dretch: bool) -> int:
	var n := 0
	for a in aliens:
		if is_instance_valid(a) and not a.dead and (a.type == "dretch") == dretch:
			n += 1
	return n

func spawn(type: String, pos: Vector3, aware := false) -> Alien:
	if type == "dretch":
		if count_type(true) >= Defs.DRETCH_MAX:
			return null
	elif count_type(false) >= Defs.MAX_MOBILE and not aware:
		return null
	var a := Alien.new()
	a.setup(game, type, pos, aware)
	game.add_child(a)
	a.rotation.y = _rng.randf() * TAU
	aliens.append(a)
	return a

func spawn_group(type: String, center: Vector3, aware := false, count := -1) -> Array:
	var out: Array = []
	var r: Array = GROUPS.get(type, [1, 1])
	var n := count if count > 0 else _rng.randi_range(r[0], r[1])
	for i in n:
		var off := Vector3(_rng.randf_range(-4, 4), 0, _rng.randf_range(-4, 4))
		var c := game.data.nearest_walkable(center + off, 3)
		if c.x < 0:
			continue
		var a := spawn(type, game.data.cell_center(c.x, c.y), aware)
		if a:
			out.append(a)
			if aware and game.player:
				a.last_known = game.player.global_position
	return out

func _hidden_spawn_point(around: Vector3, rmin: float, rmax: float) -> Vector3:
	var p := game.player
	for attempt in 30:
		var pt := game.data.random_spawn_point(_rng)
		var d := pt.distance_to(around)
		if d < rmin or d > rmax:
			continue
		if p and pt.distance_to(p.global_position) < 28.0:
			continue
		if p and game.los(p.cam.global_position, pt + Vector3.UP * 1.2):
			continue
		return pt
	return Vector3.INF

func _pick_type(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights: total += weights[k]
	var r := _rng.randf() * total
	for k in weights:
		r -= weights[k]
		if r <= 0.0:
			return k
	return weights.keys()[0]

func _process(delta: float) -> void:
	if game == null or game.player == null or not game.player.alive or game.ending:
		return
	_tick -= delta
	if _tick <= 0.0:
		_tick = 1.0
		_maintain()
	# small hordes (suspended while an Overmind swarm runs)
	if not game.swarm_active and game.player_in_city():
		horde_t -= delta
		if horde_t <= 0.0:
			horde_t = _rng.randf_range(70.0, 140.0)
			_horde()
	if game.swarm_active:
		swarm_t -= delta
		if swarm_t <= 0.0:
			swarm_t = _rng.randf_range(4.0, 6.0)
			_swarm_wave()

func _maintain() -> void:
	var pp := game.player.global_position
	var near := 0
	var near_dretch := 0
	for a in aliens.duplicate():
		if not is_instance_valid(a):
			aliens.erase(a)
			continue
		var d: float = a.global_position.distance_to(pp)
		if not a.aware and not a.alerted and d > Defs.DESPAWN_DIST:
			aliens.erase(a)
			a.queue_free()
			continue
		if d < 120.0:
			if a.type == "dretch":
				near_dretch += 1
			else:
				near += 1
	if not game.player_in_city(60.0):
		return
	if near < Defs.AMBIENT_TARGET and count_type(false) < Defs.MAX_MOBILE:
		var pt := _hidden_spawn_point(pp, Defs.SPAWN_MIN, Defs.SPAWN_MAX)
		if pt != Vector3.INF:
			var t := _pick_type({"mantis": 3.0, "marauder": 2.5, "granger": 1.2, "dragoon": 1.2})
			spawn_group(t, pt, false)
	# dretches are common: they lead the way to eggs
	if near_dretch < Defs.DRETCH_TARGET:
		var pt2 := _hidden_spawn_point(pp, 30.0, 95.0)
		if pt2 != Vector3.INF:
			spawn_group("dretch", pt2, false)

func _horde() -> void:
	var t := _pick_type({"granger": 3.0, "marauder": 2.5, "dragoon": 1.0, "mantis": 2.0})
	var pp := game.player.global_position
	var back := game.player.global_transform.basis.z
	var pt := Vector3.INF
	for i in 12:
		var c := pp + back.rotated(Vector3.UP, _rng.randf_range(-1.2, 1.2)) * _rng.randf_range(30.0, 55.0)
		var cell := game.data.nearest_walkable(c, 5)
		if cell.x < 0:
			continue
		var cand := game.data.cell_center(cell.x, cell.y)
		if not game.los(game.player.cam.global_position, cand + Vector3.UP * 1.2):
			pt = cand
			break
	if pt == Vector3.INF:
		pt = _hidden_spawn_point(pp, 30.0, 70.0)
	if pt == Vector3.INF:
		return
	var n := -1
	if t == "granger": n = _rng.randi_range(5, 12)
	spawn_group(t, pt, true, n)
	_cue(t)

func _cue(t: String) -> void:
	# a distinct, unmistakable call so the player knows what is coming
	Sfx.play_ui("alien/%s_taunt" % t, 2.0, 0.85)

func _swarm_wave() -> void:
	for a in _swarm_alive.duplicate():
		if not is_instance_valid(a) or a.dead:
			_swarm_alive.erase(a)
	if _swarm_alive.size() >= 26:
		return
	var center: Vector3 = game.swarm_center
	var pt := _hidden_spawn_point(center, 30.0, 60.0)
	if pt == Vector3.INF:
		var cell := game.data.nearest_walkable(center + Vector3(_rng.randf_range(-45, 45), 0, _rng.randf_range(-45, 45)), 6)
		if cell.x < 0:
			return
		pt = game.data.cell_center(cell.x, cell.y)
	var t := _pick_type({"granger": 3.0, "marauder": 2.5, "mantis": 2.5, "dragoon": 0.6})
	var n := -1
	if t == "granger": n = _rng.randi_range(4, 8)
	elif t == "marauder": n = _rng.randi_range(2, 4)
	elif t == "mantis": n = _rng.randi_range(3, 5)
	var g := spawn_group(t, pt, true, n)
	_swarm_alive.append_array(g)

func spawn_tyrant(near: Vector3) -> void:
	var pt := _hidden_spawn_point(near, 25.0, 55.0)
	if pt == Vector3.INF:
		pt = near + Vector3(20, 0, 20)
	var g := spawn_group("tyrant", pt, true, 1)
	_cue("tyrant")
	_swarm_alive.append_array(g)
