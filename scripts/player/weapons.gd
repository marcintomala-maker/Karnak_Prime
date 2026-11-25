class_name Weapons
extends Node3D
## View weapons: Construction kit (1), Chaingun (2), Lasgun (3). Hitscan fire, regenerating
## ammo shown as world-space holograms, projected teal crosshair + laser sight, flares,
## repair beam, build-menu placement.

const CKIT := 0
const CHAINGUN := 1
const LASGUN := 2
const MODEL := ["ckit", "chaingun", "lasgun"]
const LENGTH := [0.30, 0.34, 0.36]

var player: Player
var current := CHAINGUN
var ammo := [Defs.BUILD_POINTS, float(Defs.CHAINGUN.ammo), float(Defs.LASGUN.ammo)]
var _since_fire := [0.0, 10.0, 10.0]
var _fire_cd := 0.0
var _flare_cd := 0.0
var _models: Array[Node3D] = []
var _anim: Array = [null, null, null]
var _muzzle: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO]
var _holo: Array[Label3D] = []
var _holder: Node3D
var _flash_sprite: Sprite3D
var _flash_light: OmniLight3D
var _flash_t := 0.0
var _switch_t := 0.0
var _recoil := 0.0
var _sway := Vector2.ZERO
var _lights_suppressed := false
var bob_phase := 0.0
var bob_amount := 0.0
var sprinting := false
var crosshair: Decal
var _laser: MeshInstance3D
var _laser_mesh: ImmediateMesh
var _beam: MeshInstance3D
var _beam_mesh: ImmediateMesh
var _repair_t := 0.0
var aim_hit := {}
var aim_on_enemy := false
var placing := ""
var _ghost: Node3D
var _ghost_ok := false
var _shot_count := 0

func _ready() -> void:
	_holder = Node3D.new()
	add_child(_holder)
	for i in 3:
		var m: Node3D = load("res://assets/models/weapons/%s.glb" % MODEL[i]).instantiate()
		_holder.add_child(m)
		_fit_model(m, i)
		Game.prepare_materials(m)
		m.visible = i == current
		_models.append(m)
		_anim[i] = m.find_child("AnimationPlayer", true, false)
		var h := Label3D.new()
		h.font = UIKit.font("Black")
		h.font_size = 64
		h.pixel_size = 0.00045
		h.modulate = Color(0.45, 1.0, 1.0, 0.95)
		h.outline_modulate = Color(0.0, 0.4, 0.5, 0.6)
		h.outline_size = 10
		h.shaded = false
		h.no_depth_test = true
		h.render_priority = 10
		h.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		h.double_sided = true
		m.add_child(h)
		h.position = m.get_meta("holo_pos")
		_holo.append(h)
	_flash_sprite = Sprite3D.new()
	_flash_sprite.texture = load("res://assets/fx/rifle_flash.png")
	_flash_sprite.pixel_size = 0.00035
	_flash_sprite.shaded = false
	_flash_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_flash_sprite.modulate = Color(1.0, 0.85, 0.6)
	_flash_sprite.visible = false
	_holder.add_child(_flash_sprite)
	_flash_light = OmniLight3D.new()
	_flash_light.omni_range = 7.0
	_flash_light.light_energy = 0.0
	_flash_light.shadow_enabled = false
	_flash_light.light_specular = 0.0
	_flash_light.light_color = Color(1.0, 0.78, 0.5)
	_flash_light.visible = false
	add_child(_flash_light)
	_flash_light.position = Vector3(0.1, 0.0, -0.9)
	# projected crosshair (Duelyst ring + dot), teal; turns lime over enemies
	crosshair = Decal.new()
	crosshair.texture_albedo = load("res://assets/ui/crosshair.png")
	crosshair.size = Vector3(0.4, 0.6, 0.4)
	crosshair.modulate = UIKit.TEAL
	crosshair.albedo_mix = 1.0
	crosshair.emission_energy = 2.0
	crosshair.texture_emission = crosshair.texture_albedo
	crosshair.upper_fade = 0.0
	crosshair.lower_fade = 0.0
	crosshair.cull_mask = 1
	player.game.add_child.call_deferred(crosshair)
	_laser_mesh = ImmediateMesh.new()
	_laser = MeshInstance3D.new()
	_laser.mesh = _laser_mesh
	_laser.material_override = _unshaded(Color(0.35, 0.95, 0.95, 0.35))
	_laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player.game.add_child.call_deferred(_laser)
	_beam_mesh = ImmediateMesh.new()
	_beam = MeshInstance3D.new()
	_beam.mesh = _beam_mesh
	_beam.material_override = _unshaded(Color(0.9, 0.95, 1.0, 0.95))
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player.game.add_child.call_deferred(_beam)

func _unshaded(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.no_depth_test = false
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

## Scale and place a Quake view-model so it sits in the lower right of the view.
func _fit_model(m: Node3D, i: int) -> void:
	var aabb := Game.model_aabb(m)
	var s: float = LENGTH[i] / maxf(aabb.size.z, 0.001)
	m.scale = Vector3.ONE * s
	var target := Vector3(0.19, -0.19, -0.2 - LENGTH[i] * 0.5)
	m.position = target - aabb.get_center() * s
	# muzzle in holder space: front-centre of the box
	_muzzle[i] = m.position + Vector3(aabb.get_center().x, aabb.get_center().y + aabb.size.y * 0.15, aabb.position.z) * s
	m.set_meta("holo_pos", Vector3(aabb.get_center().x, aabb.end.y + 0.12 / s, aabb.get_center().z) )
	m.set_meta("base_pos", m.position)

func set_lights_suppressed(v: bool) -> void:
	_lights_suppressed = v

func muzzle_global() -> Vector3:
	return _holder.global_transform * _muzzle[current]

func select(i: int) -> void:
	if i == current or _switch_t > 0.0:
		return
	if placing != "":
		cancel_placement()
	_switch_t = 0.32
	Sfx.play_ui("weapon/change", -6.0)
	await get_tree().create_timer(0.16).timeout
	for k in 3:
		_models[k].visible = k == i
	current = i
	if _anim[i]:
		_play_anim(i, "raise")

func _play_anim(i: int, a: String) -> void:
	var ap: AnimationPlayer = _anim[i]
	if ap and ap.has_animation(a):
		ap.play(a)

func _unhandled_input(event: InputEvent) -> void:
	if player == null or not player.alive or not player.controls_enabled or player.in_menu:
		return
	if event.is_action_pressed("weapon_1"): select(CKIT)
	elif event.is_action_pressed("weapon_2"): select(CHAINGUN)
	elif event.is_action_pressed("weapon_3"): select(LASGUN)
	elif event.is_action_pressed("weapon_next"): select((current + 1) % 3)
	elif event.is_action_pressed("weapon_prev"): select((current + 2) % 3)
	elif event.is_action_pressed("build_menu") and current == CKIT and placing == "":
		player.game.hud.open_build_menu()
	elif event.is_action_pressed("flare") and placing != "":
		cancel_placement()
	elif event.is_action_pressed("flare") and _flare_cd <= 0.0:
		_fire_flare()
	elif event.is_action_pressed("fire") and placing != "":
		_confirm_placement()

func flare_fraction() -> float:
	return 1.0 - clampf(_flare_cd / Defs.FLARE_COOLDOWN, 0.0, 1.0)

func _process(delta: float) -> void:
	if player == null:
		return
	_fire_cd -= delta
	_flare_cd = maxf(_flare_cd - delta, 0.0)
	_switch_t = maxf(_switch_t - delta, 0.0)
	# ammo regeneration
	ammo[CKIT] = minf(ammo[CKIT] + Defs.BUILD_REGEN * delta, Defs.BUILD_POINTS)
	for k in [CHAINGUN, LASGUN]:
		_since_fire[k] += delta
		var d: Dictionary = Defs.CHAINGUN if k == CHAINGUN else Defs.LASGUN
		if _since_fire[k] > d.regen_delay:
			ammo[k] = minf(ammo[k] + d.ammo / d.regen_time * delta, d.ammo)
	_update_holo()
	_update_aim()
	var firing: bool = player.alive and player.controls_enabled and not player.in_menu and placing == "" \
		and Input.is_action_pressed("fire") and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	_beam.visible = false
	if firing and _switch_t <= 0.0:
		if current == CKIT:
			_repair(delta)
		elif _fire_cd <= 0.0:
			_shoot()
	if placing != "":
		_update_ghost()
	_animate(delta)
	# muzzle flash decay
	_flash_t -= delta
	_flash_sprite.visible = _flash_t > 0.0 and not _lights_suppressed
	_flash_light.visible = _flash_t > 0.0 and not _lights_suppressed
	if _flash_t > 0.0:
		_flash_light.light_energy = _flash_light.get_meta("e", 0.5) * clampf(_flash_t / 0.05, 0.0, 1.0)

func _update_holo() -> void:
	for k in 3:
		var h := _holo[k]
		if not _models[k].visible:
			continue
		if k == CKIT:
			h.text = "[F]\n%d" % int(ammo[k])
		else:
			h.text = str(int(ammo[k]))
		var d: Dictionary = Defs.CHAINGUN if k == CHAINGUN else Defs.LASGUN
		var low: bool = k != CKIT and ammo[k] < d.ammo * 0.2
		h.modulate = Color(1.0, 0.35, 0.3, 0.95) if low else Color(0.45, 1.0, 1.0, 0.95)

func is_low_ammo() -> bool:
	if current == CKIT:
		return false
	var d: Dictionary = Defs.CHAINGUN if current == CHAINGUN else Defs.LASGUN
	return ammo[current] < d.ammo * 0.2

func _ray(from: Vector3, to: Vector3, mask := 1 | 4 | 8 | 16) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	q.collide_with_areas = true
	q.collide_with_bodies = true
	q.exclude = [player.get_rid()]
	return get_world_3d().direct_space_state.intersect_ray(q)

func _update_aim() -> void:
	var cam := player.cam
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	aim_hit = _ray(from, from + dir * 250.0)
	aim_on_enemy = false
	if aim_hit and aim_hit.collider:
		var tgt = Game.damage_target(aim_hit.collider)
		aim_on_enemy = tgt != null and tgt.is_in_group("alien")
	var show := player.alive and not aim_hit.is_empty() and current != CKIT and placing == ""
	crosshair.visible = show
	_laser.visible = show and not _lights_suppressed
	if not show:
		return
	var p: Vector3 = aim_hit.position
	var n: Vector3 = aim_hit.normal
	var dist := from.distance_to(p)
	var sz := clampf(dist * 0.035, 0.12, 4.0)
	crosshair.size = Vector3(sz, maxf(sz, 0.8), sz)
	var up := n if n.length() > 0.5 else Vector3.UP
	var side := up.cross(dir).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	crosshair.global_transform = Transform3D(Basis(side, up, side.cross(up)).orthonormalized(), p)
	var col := UIKit.LIME if aim_on_enemy else UIKit.TEAL
	crosshair.modulate = col
	_laser.material_override.albedo_color = Color(col, 0.28)
	_laser_mesh.clear_surfaces()
	var m := muzzle_global()
	var side_v := (p - m).cross(p - from).normalized()
	if side_v.length() < 0.5:
		side_v = (p - m).cross(Vector3.UP).normalized()
	var w0 := side_v * 0.0025
	var w1 := side_v * maxf(dist * 0.0011, 0.0025)
	_laser_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for v in [m - w0, m + w0, p + w1, m - w0, p + w1, p - w1]:
		_laser_mesh.surface_add_vertex(v)
	_laser_mesh.surface_end()

func _shoot() -> void:
	var d: Dictionary = Defs.CHAINGUN if current == CHAINGUN else Defs.LASGUN
	if ammo[current] < 1.0:
		_fire_cd = 0.25
		Sfx.play_ui("weapon/click", -8.0)
		return
	ammo[current] -= 1.0
	_since_fire[current] = 0.0
	_fire_cd = 1.0 / d.rate
	_shot_count += 1
	var cam := player.cam
	var spread := deg_to_rad(d.spread) * (1.6 if sprinting else 1.0)
	var dir := (-cam.global_transform.basis.z).rotated(cam.global_transform.basis.x, randf_range(-spread, spread)).rotated(cam.global_transform.basis.y, randf_range(-spread, spread))
	var from := cam.global_position
	var hit := _ray(from, from + dir * 300.0)
	if hit:
		Game.apply_hit(hit, d.damage, true)
	# feedback
	_recoil = minf(_recoil + (0.6 if current == LASGUN else 0.35), 1.0)
	_flash_t = 0.05
	var e := (0.55 if _shot_count % 2 == 0 else 0.35) if current == CHAINGUN else 0.6
	_flash_light.set_meta("e", e)
	_flash_light.light_color = Color(1.0, 0.78, 0.5) if current == CHAINGUN else Color(0.6, 0.85, 1.0)
	_flash_sprite.position = _muzzle[current]
	_flash_sprite.texture = load("res://assets/fx/rifle_flash.png" if current == CHAINGUN else "res://assets/fx/prifle_flash.png")
	if current == CHAINGUN:
		Sfx.play_3d("weapon/chaingun%d" % randi_range(1, 4), player.global_position, -3.0, 80.0)
	else:
		Sfx.play_3d("weapon/lasgun", player.global_position, -2.0, 80.0)
	_play_anim(current, "fire")
	player.game.noise(player.global_position, Defs.NOISE_SHOT)

func _repair(delta: float) -> void:
	var cam := player.cam
	var m := muzzle_global()
	var best: Buildable = null
	var best_d := Defs.REPAIR_RANGE + 2.0
	for b in player.game.player_buildings:
		if not is_instance_valid(b):
			continue
		var c: Vector3 = b.global_position + Vector3(0, 0.8, 0)
		var to := c - cam.global_position
		var dd: float = to.length() - b.radius()
		if dd < best_d and to.normalized().dot(-cam.global_transform.basis.z) > 0.55:
			best = b; best_d = dd
	if best == null or best_d > Defs.REPAIR_RANGE:
		return
	_beam.visible = true
	var target := best.global_position + Vector3(0, 0.8, 0)
	_beam_mesh.clear_surfaces()
	_beam_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var segs := 9
	var prev := m
	for s in range(1, segs + 1):
		var t := float(s) / segs
		var p := m.lerp(target, t)
		if s < segs:
			p += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * 0.07
		_beam_mesh.surface_add_vertex(prev); _beam_mesh.surface_add_vertex(p)
		prev = p
	_beam_mesh.surface_end()
	_repair_t -= delta
	if _repair_t <= 0.0:
		_repair_t = Defs.REPAIR_TICK
		best.repair(Defs.REPAIR_AMOUNT)
		if randf() < 0.15:
			Sfx.play_3d("weapon/repair", target, -10.0, 20.0)

func _fire_flare() -> void:
	_flare_cd = Defs.FLARE_COOLDOWN
	var f := Flare.new()
	player.game.add_child(f)
	var cam := player.cam
	var dir := (-cam.global_transform.basis.z + Vector3.UP * 0.08).normalized()
	f.launch(muzzle_global() + dir * 0.2, dir * 30.0 + player.velocity * 0.5)
	Sfx.play_3d("weapon/flare_fire", player.global_position, 0.0, 40.0, 0.8)
	_recoil = 1.0

func _animate(delta: float) -> void:
	_recoil = move_toward(_recoil, 0.0, delta * 6.0)
	var md := player.mouse_delta
	player.mouse_delta = Vector2.ZERO
	_sway = _sway.lerp(Vector2(clampf(-md.x * 0.0009, -0.05, 0.05), clampf(md.y * 0.0009, -0.05, 0.05)), clampf(delta * 8.0, 0.0, 1.0))
	# heavy gun bob: figure-eight, bigger when sprinting
	var amp := 0.018 + (0.035 if sprinting else 0.0)
	var bx := cos(bob_phase) * amp * bob_amount
	var by := -absf(sin(bob_phase)) * amp * 1.3 * bob_amount
	var sw := _switch_t / 0.32
	var dip := sin(sw * PI) * -0.22
	_holder.position = Vector3(bx + _sway.x, by + _sway.y + dip, _recoil * 0.05)
	_holder.rotation = Vector3(_recoil * 0.06 + (0.12 if sprinting else 0.0) * bob_amount, _sway.x * 2.0, (0.25 if sprinting else 0.0) * bob_amount)

# ---------------------------------------------------------------- placement
func begin_placement(kind: String) -> void:
	placing = kind
	var def: Dictionary = Defs.BUILDABLES[kind]
	_ghost = Buildable.make_model(def.model, def.size)
	Game.ghostify(_ghost)
	player.game.add_child(_ghost)

func cancel_placement() -> void:
	placing = ""
	if _ghost:
		_ghost.queue_free()
		_ghost = null

func _update_ghost() -> void:
	var cam := player.cam
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var hit := _ray(from, from + dir * 8.0, 1)
	var pos: Vector3
	if hit:
		pos = hit.position
	else:
		pos = from + dir * 8.0
	var down := _ray(pos + Vector3.UP * 1.5, pos + Vector3.DOWN * 6.0, 1)
	_ghost_ok = false
	if down:
		pos = down.position
		_ghost_ok = down.normal.y > 0.8 and from.distance_to(pos) > 1.2
	_ghost.global_position = pos
	_ghost.rotation.y = player.rotation.y + PI
	var reason := player.game.can_place(placing, pos)
	if reason != "":
		_ghost_ok = false
	Game.tint_ghost(_ghost, _ghost_ok)

func _confirm_placement() -> void:
	if not _ghost_ok:
		Sfx.play_ui("ui/error", -4.0)
		return
	var def: Dictionary = Defs.BUILDABLES[placing]
	if ammo[CKIT] < def.cost:
		Sfx.play_ui("ui/error", -4.0)
		return
	ammo[CKIT] -= def.cost
	player.game.place_building(placing, _ghost.global_position, _ghost.rotation.y)
	cancel_placement()
