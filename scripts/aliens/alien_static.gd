class_name AlienStatic
extends Node3D
## Stationary alien structures: egg, overmind, acid_tube, barricade, booster.

var game: Game
var kind := "egg"
var hp := 10.0
var dead := false
var model: Node3D
var anim: AnimationPlayer
var hit_area: CollisionObject3D
var width := 6.0          # barricade span
var _cd := 0.0
var _rng := RandomNumberGenerator.new()
var _blocked_cells: Array = []
var cluster_id := -1

static var _egg_mesh: Mesh = null
static var _egg_mats: Array = []

func setup(g: Game, k: String) -> void:
	game = g
	kind = k
	hp = Defs.STATIC_HP.get(k, 100.0)
	_rng.randomize()

func _ready() -> void:
	add_to_group("alien_static")
	match kind:
		"egg": _make_egg()
		"overmind": _make_animated("overmind", 5.5)
		"acid_tube": _make_animated("acid_tube", 1.7)
		"booster": _make_animated("booster", 1.3)
		"barricade": _make_barricade()
	if kind == "overmind":
		add_to_group("overmind")
		Sfx.play_3d("alien/overmind_idle", global_position, -6.0, 50.0)

func _area(shape: Shape3D, offset: Vector3, static_body := false) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = offset
	if static_body:
		var b := StaticBody3D.new()
		b.collision_layer = 1 | 16
		b.collision_mask = 0
		b.add_child(cs)
		hit_area = b
	else:
		var a := Area3D.new()
		a.collision_layer = 16
		a.collision_mask = 0
		a.monitoring = false
		a.add_child(cs)
		hit_area = a
	hit_area.set_meta("damage_target", self)
	add_child(hit_area)

func _make_animated(name_: String, size: float) -> void:
	model = load("res://assets/models/buildables/%s.glb" % name_).instantiate()
	add_child(model)
	var aabb := Game.model_aabb(model)
	var s := size / maxf(aabb.size.x, aabb.size.z)
	model.scale = Vector3.ONE * s
	model.position = Vector3(-aabb.get_center().x * s, -aabb.position.y * s, -aabb.get_center().z * s)
	Game.prepare_materials(model)
	anim = model.find_child("AnimationPlayer", true, false)
	if anim and anim.has_animation("idle"):
		anim.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
		anim.play("idle")
		anim.seek(_rng.randf() * anim.current_animation_length, true)
	var bs := BoxShape3D.new()
	bs.size = Vector3(aabb.size.x * s * 0.8, aabb.size.y * s * 0.9, aabb.size.z * s * 0.8)
	_area(bs, Vector3(0, aabb.size.y * s * 0.45, 0))
	if kind == "overmind":
		var l := OmniLight3D.new()
		l.light_color = Color(0.55, 1.0, 0.35)
		l.omni_range = 12.0
		l.light_energy = 1.2
		l.shadow_enabled = false
		l.light_specular = 0.0
		l.position.y = aabb.size.y * s * 0.6
		add_child(l)

## Eggs are static (bind-pose) copies of the Unvanquished eggpod with a pulsing lime shader.
func _make_egg() -> void:
	if _egg_mesh == null:
		var src: Node3D = load("res://assets/models/buildables/eggpod.glb").instantiate()
		var mi: MeshInstance3D = src.find_children("*", "MeshInstance3D", true, false)[0]
		var aabb := Game.model_aabb(src)
		var base_xf: Transform3D = mi.global_transform if mi.is_inside_tree() else _accum_xf(mi)
		var am := ArrayMesh.new()
		var m: Mesh = mi.mesh
		var s := 1.1 / maxf(aabb.size.x, aabb.size.z)
		for si in m.get_surface_count():
			var arr := m.surface_get_arrays(si)
			arr[Mesh.ARRAY_BONES] = null
			arr[Mesh.ARRAY_WEIGHTS] = null
			var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			for i in verts.size():
				var v := base_xf * verts[i]
				verts[i] = Vector3((v.x - aabb.get_center().x) * s, (v.y - aabb.position.y) * s, (v.z - aabb.get_center().z) * s)
				if i < norms.size():
					norms[i] = (base_xf.basis * norms[i]).normalized()
			arr[Mesh.ARRAY_VERTEX] = verts
			arr[Mesh.ARRAY_NORMAL] = norms
			arr[Mesh.ARRAY_TANGENT] = null
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			var sm := ShaderMaterial.new()
			sm.shader = load("res://shaders/egg.gdshader")
			var mat := m.surface_get_material(si)
			if mat is BaseMaterial3D:
				sm.set_shader_parameter("albedo_tex", (mat as BaseMaterial3D).albedo_texture)
			_egg_mats.append(sm)
		_egg_mesh = am
		src.free()
	var inst := MeshInstance3D.new()
	inst.mesh = _egg_mesh
	for si in _egg_mats.size():
		inst.set_surface_override_material(si, _egg_mats[si])
	inst.set_instance_shader_parameter("phase", _rng.randf() * TAU)
	inst.visibility_range_end = 90.0
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model = inst
	add_child(inst)
	var sp := SphereShape3D.new()
	sp.radius = 0.55
	_area(sp, Vector3(0, 0.5, 0))

static func _accum_xf(n: Node) -> Transform3D:
	var xf := Transform3D.IDENTITY
	var cur := n
	while cur != null and cur is Node3D:
		xf = (cur as Node3D).transform * xf
		cur = cur.get_parent()
	return xf

func _make_barricade() -> void:
	model = load("res://assets/models/buildables/barricade.glb").instantiate()
	add_child(model)
	var aabb := Game.model_aabb(model)
	var sx := width / aabb.size.x
	var sh := 3.6 / aabb.size.y
	model.scale = Vector3(sx, sh, minf(sx, 1.4 / aabb.size.z * 2.0))
	model.position = Vector3(-aabb.get_center().x * sx, -aabb.position.y * sh, -aabb.get_center().z * model.scale.z)
	Game.prepare_materials(model)
	anim = model.find_child("AnimationPlayer", true, false)
	if anim and anim.has_animation("idle"):
		anim.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
		anim.play("idle")
	var bs := BoxShape3D.new()
	bs.size = Vector3(width, 3.4, 1.6)
	_area(bs, Vector3(0, 1.7, 0), true)
	# block alien/objective navigation through the street
	var dir := global_transform.basis.x
	var n := int(width / 1.5)
	for i in range(-n / 2, n / 2 + 1):
		var p := global_position + dir * i * 1.5
		game.data.set_blocked(p, 1.2, true)
		_blocked_cells.append(p)

func take_damage(amount: float, from_player := false, hit_pos := Vector3.ZERO, normal := Vector3.UP) -> void:
	if dead:
		return
	if kind == "overmind":
		# bullet- and bomb-proof
		if hit_pos != Vector3.ZERO:
			game.fx.overmind_hit(hit_pos, normal)
		if randf() < 0.2:
			Sfx.play_3d("alien/overmind_pain", global_position, -4.0, 60.0)
		return
	hp -= amount
	if hit_pos != Vector3.ZERO:
		game.fx.alien_hit(hit_pos, normal)
	if from_player:
		game.director.ally_hurt(global_position)
	if kind == "barricade" and randf() < 0.3:
		Sfx.play_3d("alien/barricade_pain", global_position, -4.0, 50.0)
		if anim and anim.has_animation("pain"):
			anim.play("pain"); anim.queue("idle")
	if hp <= 0.0:
		die()

func die() -> void:
	if dead:
		return
	dead = true
	if hit_area:
		hit_area.queue_free()
	match kind:
		"egg":
			Sfx.play_3d("alien/egg_pain", global_position, -2.0, 50.0)
			game.fx.alien_hit(global_position + Vector3.UP * 0.5, Vector3.UP)
			game.fx.lime_burst(global_position + Vector3.UP * 0.4)
			game.on_egg_destroyed(self)
			queue_free()
		"booster":
			Sfx.play_3d("alien/booster_pain", global_position, 0.0, 50.0)
			ToxicCloud.spawn(game, global_position, 4.0)
			queue_free()
		"barricade":
			for p in _blocked_cells:
				game.data.set_blocked(p, 1.2, false)
			Sfx.play_3d("alien/structure_destroyed", global_position, 0.0, 70.0)
			game.fx.alien_hit(global_position + Vector3.UP * 1.5, Vector3.UP)
			game.fx.lime_burst(global_position + Vector3.UP)
			if anim and anim.has_animation("destroy"):
				anim.play("destroy")
			get_tree().create_timer(2.0).timeout.connect(queue_free)
		"acid_tube":
			Sfx.play_3d("alien/structure_destroyed", global_position, -2.0, 60.0)
			game.fx.alien_hit(global_position + Vector3.UP * 0.8, Vector3.UP)
			if anim and anim.has_animation("destroy"):
				anim.play("destroy")
			get_tree().create_timer(1.5).timeout.connect(queue_free)
	Flow.stats.kills += 1 if kind != "egg" else 0

func destroy_overmind() -> void:
	dead = true
	game.fx.lime_burst(global_position + Vector3.UP * 2.0, true)
	ToxicCloud.spawn(game, global_position, 5.0)
	Sfx.play_3d("alien/structure_explode", global_position, 4.0, 150.0)
	if anim and anim.has_animation("destroy"):
		anim.play("destroy")
	get_tree().create_timer(1.2).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
	if dead or game == null or game.player == null:
		return
	var p := game.player
	match kind:
		"booster":
			if p.alive and p.global_position.distance_to(global_position) < 1.15:
				die()
		"acid_tube":
			_cd -= delta
			if _cd <= 0.0:
				_cd = _rng.randf_range(1.8, 2.6)
				var from := global_position + Vector3.UP * 1.4
				var head := p.cam.global_position
				if p.alive and from.distance_to(head) < 30.0 and game.los(from, head):
					var pr := AlienProjectile.new()
					game.add_child(pr)
					pr.shoot(game, from, head + Vector3(_rng.randf_range(-0.5, 0.5), -0.3, _rng.randf_range(-0.5, 0.5)), 20.0, 450.0)
					Sfx.play_3d("alien/acid_attack", from, -2.0, 50.0)
					if anim and anim.has_animation("attack"):
						anim.play("attack"); anim.queue("idle")
