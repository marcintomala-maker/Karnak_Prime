class_name Game
extends Node3D
## Mission root: builds the world, player, aliens and objectives; runs the SWARM event,
## victory cutscene and defeat flow. Also hosts shared helpers used by other scripts.

static var I: Game

var data: WorldData
var world: World
var player: Player
var director: Director
var fx: Effects
var hud: HUD
var briefing: Briefing

var player_buildings: Array = []
var eggs: Array = []
var overminds: Array = []
var statics: Array = []
var egg_total := Defs.EGG_TOTAL
var eggs_destroyed := 0
var overminds_destroyed := 0
var swarm_active := false
var swarm_time_left := 0.0
var swarm_center := Vector3.ZERO
var swarm_destroyer: Buildable
var swarm_overmind: AlienStatic
var _swarm_ring: MeshInstance3D
var zig_center := Vector3.ZERO
var ending := false
var _ready_to_play := false
var _rng := RandomNumberGenerator.new()
var _rings: Array = []
var _ring_i := 0
var _med_ms := -1000
var _music_t := 0.0
var _ambient: AudioStreamPlayer
var _amb_t := 10.0

var player_in_med: bool:
	get: return Time.get_ticks_msec() - _med_ms < 150
	set(v):
		if v: _med_ms = Time.get_ticks_msec()

# ================================================================ static helpers
## Replace imported materials with non-specular, fully rough versions (keeps textures).
static func prepare_materials(n: Node) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if m.mesh == null:
			continue
		for si in m.mesh.get_surface_count():
			var src := m.get_active_material(si)
			if src is BaseMaterial3D:
				var mat := (src as BaseMaterial3D).duplicate() as BaseMaterial3D
				mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
				mat.metallic = 0.0
				mat.metallic_specular = 0.0
				mat.roughness = 1.0
				m.set_surface_override_material(si, mat)

## AABB of all meshes under `n`, expressed in n's local space (works outside the tree).
static func model_aabb(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var xf := Transform3D.IDENTITY
		var cur: Node = mi
		while cur != null and cur != n:
			if cur is Node3D:
				xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		var a: AABB = xf * (mi as MeshInstance3D).get_aabb()
		if first:
			out = a; first = false
		else:
			out = out.merge(a)
	return out

static func damage_target(collider: Object) -> Node:
	var c: Node = collider as Node
	while c != null:
		if c.has_meta("damage_target"):
			return c.get_meta("damage_target")
		c = c.get_parent()
	return null

static func apply_hit(hit: Dictionary, damage: float, from_player: bool) -> void:
	var t := damage_target(hit.collider)
	var g := I
	if t != null and t.has_method("take_damage"):
		t.take_damage(damage, from_player, hit.position, hit.normal)
	elif g:
		g.fx.world_hit(hit.position, hit.normal)

static func ghostify(n: Node) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		var g := StandardMaterial3D.new()
		g.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		g.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		g.albedo_color = Color(0.3, 1.0, 0.9, 0.35)
		m.material_override = g

static func tint_ghost(n: Node, ok: bool) -> void:
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		if m.material_override:
			(m.material_override as StandardMaterial3D).albedo_color = Color(0.3, 1.0, 0.9, 0.35) if ok else Color(1.0, 0.2, 0.15, 0.4)

# ================================================================ setup
func _ready() -> void:
	I = self
	_rng.randomize()
	Flow.reset_stats()
	Overlay.set_black(0.0)
	briefing = Briefing.new()
	add_child(briefing)
	await get_tree().process_frame
	data = WorldData.new()
	data.load_all()
	briefing.progress = 0.05
	world = World.new()
	add_child(world)
	await world.build(data, func(p): briefing.progress = 0.05 + p * 0.7)
	var z: Dictionary = data.meta.ziggurat
	zig_center = Vector3(z.x, z.y, z.z)
	fx = Effects.new()
	add_child(fx)
	director = Director.new()
	director.setup(self)
	add_child(director)
	hud = HUD.new()
	hud.setup(self)
	add_child(hud)
	hud.visible = false
	_make_noise_rings()
	_spawn_player()
	_make_crash_site()
	await get_tree().physics_frame
	await get_tree().physics_frame
	briefing.progress = 0.8
	_place_objectives()
	briefing.progress = 1.0
	_ambient = AudioStreamPlayer.new()
	_ambient.stream = Sfx.stream("ambient/wind_forlorn")
	if _ambient.stream is AudioStreamOggVorbis:
		(_ambient.stream as AudioStreamOggVorbis).loop = true
	_ambient.bus = "SFX"
	_ambient.volume_db = -14.0
	add_child(_ambient)
	if not briefing.typed:
		await briefing.done
	briefing.finish()
	hud.visible = true
	_ambient.play()
	_next_music()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_ready_to_play = true

func _spawn_player() -> void:
	var sp: Dictionary = data.meta.spawn
	player = Player.new()
	player.game = self
	add_child(player)
	var face: float = sp.face
	var dir := Vector3(cos(face), 0, sin(face))
	var pos := Vector3(sp.x, 0, sp.z) + dir * 4.0
	pos.y = data.ground_at(pos.x, pos.z) + 0.2
	player.global_position = pos
	# look toward the city centre
	var to := zig_center - pos
	player.set_look(atan2(-to.x, -to.z), 0.0)
	player.died.connect(_on_player_died)

## Crashed drop capsule on the beach (procedural shell clad in Unvanquished textures).
func _make_crash_site() -> void:
	var sp: Dictionary = data.meta.spawn
	var pos := Vector3(sp.x, 0, sp.z)
	pos.y = data.ground_at(pos.x, pos.z) - 0.6
	var root := Node3D.new()
	add_child(root)
	root.global_position = pos
	root.rotation = Vector3(deg_to_rad(18), _rng.randf() * TAU, deg_to_rad(72))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = load("res://assets/tex/plate.png")
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.5, 0.5, 0.5)
	mat.albedo_color = Color(0.6, 0.62, 0.66)
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	mat.roughness = 1.0
	var hull := MeshInstance3D.new()
	var cm := CapsuleMesh.new(); cm.radius = 1.5; cm.height = 6.5
	hull.mesh = cm
	hull.material_override = mat
	root.add_child(hull)
	var band := MeshInstance3D.new()
	var cyl := CylinderMesh.new(); cyl.top_radius = 1.56; cyl.bottom_radius = 1.56; cyl.height = 0.5
	band.mesh = cyl
	var bm := StandardMaterial3D.new()
	bm.albedo_texture = load("res://assets/tex/trim.png")
	bm.emission_enabled = true
	bm.emission = Color(0.25, 0.5, 1.0)
	bm.emission_energy_multiplier = 0.6
	bm.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	band.material_override = bm
	band.position.y = 1.2
	root.add_child(band)
	var body := StaticBody3D.new()
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 1.5; cap.height = 6.5
	cs.shape = cap
	body.add_child(cs)
	root.add_child(body)
	var l := OmniLight3D.new()
	l.light_color = Color(0.4, 0.6, 1.0)
	l.omni_range = 9.0
	l.light_energy = 0.9
	l.shadow_enabled = false
	l.light_specular = 0.0
	l.position = Vector3(0, 1.0, 1.8)
	root.add_child(l)
	var smoke := CPUParticles3D.new()
	var q := QuadMesh.new(); q.size = Vector2(2.0, 2.0)
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = load("res://assets/fx/smoke.png")
	sm.albedo_color = Color(0.12, 0.12, 0.13, 0.5)
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	q.material = sm
	smoke.mesh = q
	smoke.amount = 20
	smoke.lifetime = 5.0
	smoke.local_coords = false
	smoke.direction = Vector3.UP
	smoke.spread = 15.0
	smoke.initial_velocity_min = 0.6; smoke.initial_velocity_max = 1.4
	smoke.gravity = Vector3(0.3, 0.2, 0)
	smoke.scale_amount_min = 1.0; smoke.scale_amount_max = 3.0
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 0.0)); g.add_point(0.2, Color(1, 1, 1, 0.6)); g.set_color(1, Color(1, 1, 1, 0))
	smoke.color_ramp = g
	add_child(smoke)
	smoke.global_position = pos + Vector3.UP * 1.5

func _make_noise_rings() -> void:
	for i in 10:
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new(); pm.size = Vector2(2, 2)
		mi.mesh = pm
		var m := ShaderMaterial.new()
		m.shader = load("res://shaders/noise_ring.gdshader")
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_rings.append({"mi": mi, "t": 1.0, "r": 1.0})

# ================================================================ objectives
func _clear(cell: int, r: int) -> bool:
	var i := cell % data.N; var j := cell / data.N
	for dj in range(-r, r + 1):
		for di in range(-r, r + 1):
			var ii := i + di; var jj := j + dj
			if ii < 0 or jj < 0 or ii >= data.N or jj >= data.N or data.walk[jj * data.N + ii] < 128:
				return false
	return true

func _place_objectives() -> void:
	var sp: Dictionary = data.meta.spawn
	var spawn_pos := Vector3(sp.x, sp.y, sp.z)
	# ---- Overminds: one on the ziggurat summit, five spread evenly over reachable ground
	var z: Dictionary = data.meta.ziggurat
	var chosen: Array[Vector3] = [Vector3(z.x, z.top_y, z.z)]
	var tries := 0
	while chosen.size() < Defs.OVERMIND_TOTAL and tries < 40:
		tries += 1
		var best := Vector3.INF
		var best_d := -1.0
		for k in 300:
			var idx := data.city_cells[_rng.randi() % data.city_cells.size()]
			if not _clear(idx, 2):
				continue
			var p := data.cell_center(idx % data.N, idx / data.N)
			if p.distance_to(zig_center) < 95.0:
				continue
			var md := INF
			for c in chosen:
				md = minf(md, Vector2(p.x - c.x, p.z - c.z).length())
			md *= _rng.randf_range(0.9, 1.0)
			if md > best_d:
				best_d = md; best = p
		if best == Vector3.INF:
			continue
		# explicit reachability check (A* from the landing site)
		if data.find_path(spawn_pos, best, false).is_empty():
			continue
		chosen.append(best)
	for c in chosen:
		var o := AlienStatic.new()
		o.setup(self, "overmind")
		add_child(o)
		o.global_position = c
		o.rotation.y = _rng.randf() * TAU
		overminds.append(o)
	# ---- Eggs: 621 in clusters of 3-6, on walls and streets
	var made := 0
	var centers: Array[Vector3] = []
	var guard := 0
	while made < egg_total and guard < 5000:
		guard += 1
		var idx := data.city_cells[_rng.randi() % data.city_cells.size()]
		var c := data.cell_center(idx % data.N, idx / data.N)
		if c.distance_to(spawn_pos) < 60.0:
			continue
		var ok := true
		for o in centers:
			if o.distance_to(c) < 13.0:
				ok = false; break
		if not ok:
			continue
		centers.append(c)
		var n := mini(_rng.randi_range(3, 6), egg_total - made)
		made += _egg_cluster(c, n, centers.size())
	egg_total = eggs.size()
	# ---- Acid tubes on rooftops, boosters (mines), barricades across narrow streets
	var bi: Array = world.building_info
	var tubes := 0
	for k in 400:
		if tubes >= 45: break
		var b: Dictionary = bi[_rng.randi() % bi.size()]
		var ab: AABB = b.aabb
		var px := _rng.randf_range(ab.position.x + 2.0, ab.end.x - 2.0)
		var pz := _rng.randf_range(ab.position.z + 2.0, ab.end.z - 2.0)
		var hit := ray(Vector3(px, ab.end.y + 4.0, pz), Vector3(px, b.pos.y + 5.0, pz), 1)
		if hit and hit.normal.y > 0.75:
			_static("acid_tube", hit.position, _rng.randf() * TAU)
			tubes += 1
	for k in 70:
		var p := data.random_city_point(_rng)
		if p.distance_to(spawn_pos) > 50.0:
			_static("booster", p, _rng.randf() * TAU)
	# trap ring around the ziggurat (mines on the plaza and stairs)
	for k in 40:
		var a := _rng.randf() * TAU
		var r := _rng.randf_range(50.0, 85.0)
		var cell := data.nearest_walkable(zig_center + Vector3(cos(a) * r, 0, sin(a) * r), 3)
		if cell.x >= 0:
			_static("booster", data.cell_center(cell.x, cell.y), _rng.randf() * TAU)
	var bars := 0
	for k in 600:
		if bars >= 16: break
		var p := data.random_city_point(_rng)
		if p.distance_to(spawn_pos) < 80.0:
			continue
		var origin := p + Vector3.UP * 1.5
		for d in [Vector3.RIGHT, Vector3.FORWARD, Vector3(1, 0, 1).normalized(), Vector3(1, 0, -1).normalized()]:
			var h1 := ray(origin, origin + d * 9.0, 1)
			var h2 := ray(origin, origin - d * 9.0, 1)
			if h1 and h2:
				var w: float = (h1.position as Vector3).distance_to(h2.position)
				if w > 4.0 and w < 15.0:
					var mid: Vector3 = ((h1.position as Vector3) + (h2.position as Vector3)) * 0.5
					mid.y = data.nav_height_at(mid.x, mid.z)
					var bar := AlienStatic.new()
					bar.setup(self, "barricade")
					bar.width = w + 1.0
					bar.global_transform = Transform3D(Basis(Vector3.UP, atan2(-d.z, d.x)), mid)
					add_child(bar)
					statics.append(bar)
					bars += 1
					break

func _static(kind: String, pos: Vector3, yaw: float) -> AlienStatic:
	var s := AlienStatic.new()
	s.setup(self, kind)
	add_child(s)
	s.global_position = pos
	s.rotation.y = yaw
	statics.append(s)
	return s

func _egg_cluster(c: Vector3, n: int, cid: int) -> int:
	var placed := 0
	var origin := c + Vector3.UP * 1.5
	var wall: Dictionary = {}
	if _rng.randf() < 0.6:
		for k in 8:
			var a := _rng.randf() * TAU
			var hit := ray(origin, origin + Vector3(cos(a), 0, sin(a)) * 9.0, 1)
			if hit and absf(hit.normal.y) < 0.3:
				wall = hit
				break
	var creep := Decal.new()
	creep.texture_albedo = load("res://assets/fx/creep_d.png")
	creep.modulate = Color(0.55, 0.75, 0.35, 0.9)
	creep.size = Vector3(7, 4, 7)
	creep.distance_fade_enabled = true
	creep.distance_fade_begin = 50.0
	creep.distance_fade_length = 15.0
	add_child(creep)
	for i in n:
		var xf := Transform3D.IDENTITY
		var ok := false
		if not wall.is_empty():
			var nrm: Vector3 = wall.normal
			var t := nrm.cross(Vector3.UP).normalized()
			for attempt in 4:
				var p: Vector3 = wall.position + t * _rng.randf_range(-2.5, 2.5) + Vector3.UP * _rng.randf_range(-1.2, 2.8)
				p.y = maxf(p.y, data.nav_height_at(p.x, p.z) + 0.25)
				var chk := ray(p + nrm * 1.0, p - nrm * 1.0, 1)
				if chk and absf((chk.normal as Vector3).y) < 0.4:
					var up: Vector3 = chk.normal
					var right := Vector3.UP.cross(up).normalized()
					xf = Transform3D(Basis(right, up, right.cross(up)).orthonormalized().rotated(up, _rng.randf_range(-0.6, 0.6)), (chk.position as Vector3) + up * 0.05)
					ok = true
					break
			creep.global_position = (wall.position as Vector3)
		if not ok:
			for attempt in 6:
				var p := c + Vector3(_rng.randf_range(-3, 3), 0, _rng.randf_range(-3, 3))
				if data.is_walkable(p):
					p.y = data.nav_height_at(p.x, p.z)
					xf = Transform3D(Basis(Vector3.UP, _rng.randf() * TAU), p)
					ok = true
					break
			if wall.is_empty():
				creep.global_position = c
		if not ok:
			continue
		var e := AlienStatic.new()
		e.setup(self, "egg")
		e.cluster_id = cid
		add_child(e)
		e.global_transform = xf.scaled_local(Vector3.ONE * _rng.randf_range(0.8, 1.2))
		eggs.append(e)
		placed += 1
	return placed

func on_egg_destroyed(e: AlienStatic) -> void:
	eggs.erase(e)
	eggs_destroyed += 1
	Flow.stats.eggs = eggs_destroyed
	hud.show_toast("EGGS DESTROYED: %d/%d" % [eggs_destroyed, egg_total])
	_check_victory()

# ================================================================ queries
func ray(a: Vector3, b: Vector3, mask := 1) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b, mask)
	q.collide_with_areas = (mask & (4 | 16)) != 0
	return get_world_3d().direct_space_state.intersect_ray(q)

func los(a: Vector3, b: Vector3) -> bool:
	return ray(a, b, 1).is_empty()

func is_lit_by_flare(p: Vector3) -> bool:
	for f in get_tree().get_nodes_in_group("flare"):
		if f.lights(p):
			return true
	return false

func player_in_city(margin := 0.0) -> bool:
	if player == null:
		return false
	var c: Dictionary = data.meta.city
	return Vector2(player.global_position.x - c.x, player.global_position.z - c.z).length() < float(c.r) + margin

func alien_statics_near(p: Vector3, r: float) -> Array:
	var out: Array = []
	for s in statics:
		if is_instance_valid(s) and not s.dead and s.global_position.distance_to(p) < r:
			out.append(s)
	return out

func noise(p: Vector3, radius: float) -> void:
	director.noise(p, radius)
	var r: Dictionary = _rings[_ring_i]
	_ring_i = (_ring_i + 1) % _rings.size()
	r.t = 0.0
	r.r = radius
	var mi: MeshInstance3D = r.mi
	mi.global_position = p + Vector3.UP * 0.12
	mi.scale = Vector3(radius, 1, radius)
	mi.visible = true

# ================================================================ building
func can_place(kind: String, pos: Vector3) -> String:
	var d: Dictionary = Defs.BUILDABLES[kind]
	if d.energy > 0 and _reactor_for(pos) == null:
		return "energy"
	if kind == "destroyer":
		if swarm_active:
			return "busy"
		if _overmind_near(pos) == null:
			return "overmind"
	for b in player_buildings:
		if is_instance_valid(b) and b.global_position.distance_to(pos) < b.radius() + 1.0:
			return "blocked"
	return ""

func _reactor_for(pos: Vector3) -> Buildable:
	for b in player_buildings:
		if is_instance_valid(b) and b.kind == "reactor" and b.built and b.global_position.distance_to(pos) <= Defs.REACTOR_RANGE and b.free_energy() > 0:
			return b
	return null

func _overmind_near(pos: Vector3) -> AlienStatic:
	for o in overminds:
		if is_instance_valid(o) and not o.dead and o.global_position.distance_to(pos) < Defs.DESTROYER_PLACE_RANGE:
			return o
	return null

func place_building(kind: String, pos: Vector3, yaw: float) -> void:
	var b := Buildable.new()
	b.setup(self, kind)
	add_child(b)
	b.global_position = pos
	b.rotation.y = yaw
	var d: Dictionary = Defs.BUILDABLES[kind]
	if d.energy > 0:
		var r := _reactor_for(pos)
		if r:
			r.energy_used += 1
			r.dependents.append(b)
			b.reactor = r
	player_buildings.append(b)
	Flow.stats.built += 1
	while player_buildings.size() > Defs.MAX_PLAYER_BUILDINGS:
		var old = player_buildings.pop_front()
		if is_instance_valid(old):
			old.destroy()

func on_building_complete(b: Buildable) -> void:
	if b.kind == "destroyer":
		_start_swarm(b)

func on_building_destroyed(b: Buildable) -> void:
	player_buildings.erase(b)
	if b == swarm_destroyer and swarm_active:
		_end_swarm(false)

func explode(p: Vector3, r: float, dmg: float, hits_buildings: bool, source: Node) -> void:
	for a in director.aliens.duplicate():
		if is_instance_valid(a) and not a.dead and a.global_position.distance_to(p) < r:
			a.take_damage(dmg * (1.0 - 0.5 * a.global_position.distance_to(p) / r), source != null, Vector3.ZERO, Vector3.UP)
	for s in statics.duplicate():
		if is_instance_valid(s) and not s.dead and s.global_position.distance_to(p) < r + (s.width * 0.5 if s.kind == "barricade" else 0.0):
			s.take_damage(dmg, true)
	for e in eggs.duplicate():
		if is_instance_valid(e) and not e.dead and e.global_position.distance_to(p) < r:
			e.take_damage(dmg, true)
	if hits_buildings:
		for b in player_buildings.duplicate():
			if is_instance_valid(b) and b != source and b.global_position.distance_to(p) < r:
				if b.kind == "bomb":
					b.call_deferred("detonate")
				else:
					b.destroy()

# ================================================================ swarm
func _start_swarm(d: Buildable) -> void:
	var o := _overmind_near(d.global_position)
	if o == null:
		return
	swarm_active = true
	swarm_time_left = Defs.DESTROYER_TIME
	swarm_destroyer = d
	swarm_overmind = o
	swarm_center = d.global_position
	director.swarm_t = 2.0
	Sfx.play_ui("ui/swarm", 4.0)
	Sfx.play_3d("human/repeater_use", d.global_position, 0.0, 60.0)
	_swarm_ring = MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(Defs.DESTROYER_RANGE * 2.0, Defs.DESTROYER_RANGE * 2.0)
	_swarm_ring.mesh = pm
	var sm := ShaderMaterial.new()
	sm.shader = load("res://shaders/holo_ring.gdshader")
	_swarm_ring.material_override = sm
	_swarm_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_swarm_ring)
	_swarm_ring.global_position = swarm_center + Vector3.UP * 0.3
	if overminds_destroyed >= 3:
		director.spawn_tyrant(swarm_center)

func player_in_swarm_zone() -> bool:
	return swarm_active and player != null and player.global_position.distance_to(swarm_center) < Defs.DESTROYER_RANGE

func _end_swarm(success: bool) -> void:
	swarm_active = false
	if _swarm_ring:
		_swarm_ring.queue_free()
		_swarm_ring = null
	if success:
		var o := swarm_overmind
		overminds.erase(o)
		o.destroy_overmind()
		fx.lime_burst(swarm_destroyer.global_position + Vector3.UP, true)
		swarm_destroyer.destroy(true)
		overminds_destroyed += 1
		Flow.stats.overminds = overminds_destroyed
		hud.show_toast("OVERMIND DESTROYED: %d/%d" % [overminds_destroyed, Defs.OVERMIND_TOTAL], UIKit.LIME, 4.0)
		_check_victory()
	swarm_destroyer = null
	swarm_overmind = null

func _check_victory() -> void:
	if ending:
		return
	if eggs_destroyed >= egg_total and overminds_destroyed >= Defs.OVERMIND_TOTAL:
		_victory()

# ================================================================ loop
func _process(delta: float) -> void:
	for r in _rings:
		if r.t < 1.0:
			r.t += delta / 0.7
			var mi: MeshInstance3D = r.mi
			(mi.material_override as ShaderMaterial).set_shader_parameter("progress", clampf(r.t, 0.0, 1.0))
			mi.visible = r.t < 1.0
	if not _ready_to_play or ending or player == null:
		return
	Flow.stats.time += delta
	if player.alive:
		for c in get_tree().get_nodes_in_group("toxic_cloud"):
			if c.contains(player.global_position + Vector3.UP * 0.9):
				player.damage_toxic(Defs.CLOUD_TOXIC_DPS * delta)
	if swarm_active:
		if not is_instance_valid(swarm_destroyer):
			_end_swarm(false)
		else:
			var inside := player_in_swarm_zone()
			if inside:
				swarm_time_left -= delta
			(_swarm_ring.material_override as ShaderMaterial).set_shader_parameter("color", Color(0.3, 0.6, 1.0) if inside else Color(1.0, 0.15, 0.1))
			if swarm_time_left <= 0.0:
				_end_swarm(true)
	# ambience: distant rumbles and drones around the player
	_amb_t -= delta
	if _amb_t <= 0.0:
		_amb_t = _rng.randf_range(14.0, 30.0)
		var dir := Vector3(_rng.randf_range(-1, 1), 0, _rng.randf_range(-1, 1)).normalized()
		Sfx.play_3d(["ambient/rumble", "ambient/drone", "ambient/wind2", "ambient/slowpulse"][_rng.randi() % 4], player.global_position + dir * 25.0 + Vector3.UP * 8.0, -8.0, 80.0)
	_music_t -= delta
	if _music_t <= 0.0:
		_next_music()

func _next_music() -> void:
	_music_t = _rng.randf_range(200.0, 320.0)
	var tracks := ["music_battlemap_abyssian", "music_battlemap_duskfall", "music_ageofdisjunction"]
	Sfx.play_music(tracks[_rng.randi() % tracks.size()], 6.0, true, -9.0)

## A camera spot at least `above` metres over the terrain and the ziggurat summit.
func _safe_cam_pos(p: Vector3, above: float) -> Vector3:
	var g := data.ground_at(p.x, p.z)
	return Vector3(p.x, maxf(g + above, zig_center.y + 30.0), p.z)

func _unhandled_input(event: InputEvent) -> void:
	if not _ready_to_play or ending or player == null or not player.alive:
		return
	if event.is_action_pressed("pause"):
		if hud.build_menu.visible:
			return
		if player.weapons.placing != "":
			player.weapons.cancel_placement()
			return
		hud.pause_menu.open()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if not hud.build_menu.visible and not hud.pause_menu.visible:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _ready_to_play and not ending and player and player.alive:
		if not hud.pause_menu.visible:
			hud.pause_menu.open()

# ================================================================ endings
func _on_player_died() -> void:
	ending = true
	hud.visible = false
	await get_tree().create_timer(1.0).timeout
	await Overlay.fade_to(1.0, 1.0)
	Flow.goto("failed")

func _victory() -> void:
	ending = true
	player.controls_enabled = false
	hud.visible = false
	Sfx.play_music("music_codex", 2.0)
	var start := player.global_position
	# panorama camera above and behind the player, looking over the city
	var cam := Camera3D.new()
	cam.far = 2000.0
	add_child(cam)
	var back := (start - zig_center)
	back.y = 0
	back = back.normalized()
	cam.global_position = _safe_cam_pos(start + back * 40.0, 45.0)
	cam.look_at(zig_center + Vector3.UP * 20.0)
	cam.make_current()
	await Overlay.fade_to(0.0, 0.5)
	# green flare from the player's position
	var flare := Node3D.new()
	add_child(flare)
	flare.global_position = start + Vector3.UP * 1.5
	var fl := OmniLight3D.new()
	fl.light_color = Color(0.4, 1.0, 0.3); fl.omni_range = 60.0; fl.light_energy = 4.0
	fl.shadow_enabled = false; fl.light_specular = 0.0
	flare.add_child(fl)
	var spr := Sprite3D.new()
	spr.texture = load("res://assets/fx/flare.png"); spr.modulate = Color(0.5, 1.0, 0.4)
	spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED; spr.shaded = false; spr.pixel_size = 0.02
	flare.add_child(spr)
	Sfx.play_3d("weapon/flare_fire", start, 6.0, 200.0, 0.6)
	var tw := create_tween()
	tw.tween_property(flare, "global_position", start + Vector3.UP * 140.0, 4.0).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	var look_up := cam.global_transform.looking_at(cam.global_position + Vector3(0.01, 1, 0.3), Vector3.UP)
	tw.parallel().tween_property(cam, "global_basis", look_up.basis, 5.0).set_delay(1.5).set_trans(Tween.TRANS_SINE)
	await tw.finished
	await get_tree().create_timer(1.0).timeout
	await Overlay.fade_to(1.0, 1.2)
	# sunrise over the same city
	flare.queue_free()
	var env := world.env
	var sky := Sky.new()
	var ps := ProceduralSkyMaterial.new()
	ps.sky_top_color = Color(0.32, 0.18, 0.5)
	ps.sky_horizon_color = Color(1.0, 0.55, 0.3)
	ps.ground_horizon_color = Color(0.9, 0.45, 0.3)
	ps.ground_bottom_color = Color(0.1, 0.05, 0.12)
	ps.sun_angle_max = 12.0
	ps.sun_curve = 0.06
	sky.sky_material = ps
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.6
	env.fog_light_color = Color(0.6, 0.35, 0.35)
	env.fog_density = 0.0015
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(1.0, 0.6, 0.35)
	sun.light_energy = 1.4
	sun.light_specular = 0.0
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY
	sun.light_angular_distance = 8.0
	add_child(sun)
	world.moon.visible = false
	cam.global_position = _safe_cam_pos(zig_center + back * 170.0, 30.0)
	cam.look_at(zig_center + Vector3.UP * 25.0)
	# sun hangs low, straight ahead of the camera (light travels back toward the viewer)
	var fwd := -cam.global_transform.basis.z
	sun.global_transform = Transform3D(Basis.looking_at(Vector3(-fwd.x, -0.12, -fwd.z).normalized(), Vector3.UP), Vector3.ZERO)
	await Overlay.fade_to(0.0, 2.0)
	var pan := create_tween()
	pan.tween_property(cam, "global_position", cam.global_position + Vector3.UP * 10.0 - back * 30.0, 8.0).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(7.0).timeout
	await Overlay.fade_to(1.0, 1.5)
	Flow.goto("complete")
