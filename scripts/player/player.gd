class_name Player
extends CharacterBody3D
## First-person player: raw mouse look, walk/sprint/dash/jump, head + gun bob,
## Health/Toxic, toxic water, lantern + neck light, footstep noise, death ragdoll.

signal died

var game: Game
var head: Node3D
var cam: Camera3D
var weapons: Weapons
var lantern: Lantern
var neck_light: OmniLight3D

var health := Defs.MAX_HEALTH
var toxic := Defs.MAX_TOXIC        # mental/neurological integrity; poison drains it
var alive := true
var controls_enabled := true
var in_menu := false
var god_mode := false     # dev/testing only

var _yaw := 0.0
var _pitch := 0.0
var _dash_t := 0.0
var _dash_cd := 0.0
var _dash_dir := Vector3.ZERO
var _step_dist := 0.0
var _bob_t := 0.0
var _bob_amount := 0.0
var _sprinting := false
var _was_on_floor := true
var _pain_cd := 0.0
var _breath_cd := 0.0
var _underwater := false
var _last_damage_t := -10.0
var mouse_delta := Vector2.ZERO
var noise_level := 0.0

func _init() -> void:
	collision_layer = 2
	collision_mask = 1 | 8     # world + player buildings
	floor_max_angle = deg_to_rad(48)
	floor_snap_length = 0.6
	safe_margin = 0.02

func _ready() -> void:
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new(); cap.radius = 0.4; cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	head = Node3D.new()
	head.position.y = 1.62
	add_child(head)
	cam = Camera3D.new()
	cam.fov = 80.0
	cam.near = 0.03
	cam.far = 1200.0
	head.add_child(cam)
	cam.make_current()
	neck_light = OmniLight3D.new()
	neck_light.light_color = Color(0.85, 1.0, 0.82)
	neck_light.light_energy = 0.55
	neck_light.omni_range = 5.0
	neck_light.omni_attenuation = 1.4
	neck_light.shadow_enabled = false
	neck_light.light_specular = 0.0
	neck_light.position = Vector3(0, 1.35, -0.15)
	add_child(neck_light)
	lantern = Lantern.new()
	cam.add_child(lantern)
	lantern.position = Vector3(-0.28, -0.12, -0.15)
	weapons = Weapons.new()
	weapons.player = self
	cam.add_child(weapons)
	Input.use_accumulated_input = false

func set_look(yaw: float, pitch := 0.0) -> void:
	_yaw = yaw; _pitch = pitch
	rotation.y = _yaw
	head.rotation.x = _pitch

func _unhandled_input(event: InputEvent) -> void:
	if not alive or not controls_enabled or in_menu:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var rel: Vector2 = event.relative
		var k := Settings.radians_per_count()
		_yaw -= rel.x * k
		_pitch = clampf(_pitch - rel.y * k, deg_to_rad(-88), deg_to_rad(88))
		rotation.y = _yaw
		head.rotation.x = _pitch
		mouse_delta += rel
	elif event.is_action_pressed("lantern"):
		lantern.toggle()

func toxicity() -> float:
	return clampf(1.0 - toxic / Defs.MAX_TOXIC, 0.0, 1.0)

func _physics_process(delta: float) -> void:
	if not alive:
		return
	var tox := toxicity()
	var input := Vector2.ZERO
	var can_move := controls_enabled and not in_menu
	if can_move:
		input = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	_sprinting = can_move and Input.is_action_pressed("sprint") and input.y < 0.1 and input.length() > 0.1
	var speed := (Defs.SPRINT_SPEED if _sprinting else Defs.WALK_SPEED) * (1.0 - 0.2 * tox)
	var wish := (transform.basis * Vector3(input.x, 0, input.y))
	wish.y = 0
	wish = wish.normalized() * minf(input.length(), 1.0)
	var on_floor := is_on_floor()
	_dash_cd -= delta
	# --- dash / jump: Space dashes sideways/back; with a forward component it jumps instead
	if can_move and Input.is_action_just_pressed("dash"):
		if input.y < -0.3:
			if on_floor:
				velocity.y = Defs.JUMP_VELOCITY * (1.0 - 0.5 * tox)
				Sfx.play_3d("player/jump", global_position, -8.0, 20.0)
		elif _dash_cd <= 0.0 and _dash_t <= 0.0:
			var local := Vector3(input.x, 0, maxf(input.y, 0.0))
			if local.length() < 0.2:
				local = Vector3(0, 0, 1)
			_dash_dir = (transform.basis * local.normalized())
			_dash_dir.y = 0
			_dash_dir = _dash_dir.normalized()
			_dash_t = Defs.DASH_TIME
			game.noise(global_position, Defs.NOISE_DASH)
			Sfx.play_3d("player/land", global_position, -6.0, 20.0, 1.3)
	if _dash_t > 0.0:
		_dash_t -= delta
		var f := Defs.DASH_SPEED * (0.4 + 0.6 * (_dash_t / Defs.DASH_TIME))
		velocity.x = _dash_dir.x * f
		velocity.z = _dash_dir.z * f
		if _dash_t <= 0.0:
			_dash_cd = Defs.DASH_COOLDOWN
	else:
		var accel := 45.0 if on_floor else 9.0
		var target := wish * speed
		velocity.x = move_toward(velocity.x, target.x, accel * delta)
		velocity.z = move_toward(velocity.z, target.z, accel * delta)
	if not on_floor:
		velocity.y -= Defs.GRAVITY * delta
	move_and_slide()
	if on_floor and not _was_on_floor and velocity.y < -6.0:
		Sfx.play_3d("player/land", global_position, -6.0, 20.0)
	_was_on_floor = is_on_floor()
	# --- footsteps & noise rings
	var hspeed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and hspeed > 0.6 and _dash_t <= 0.0:
		_step_dist += hspeed * delta
		var stride := 2.9 if _sprinting else 2.2
		if _step_dist > stride:
			_step_dist = 0.0
			var wet := game.data.water_at(global_position.x, global_position.z) > global_position.y + 0.02
			Sfx.play_3d(("player/splash%d" % randi_range(1, 2)) if wet else ("player/step%d" % randi_range(1, 4)),
				global_position, -6.0 if _sprinting else -14.0, 30.0)
			game.noise(global_position, Defs.NOISE_SPRINT if _sprinting else Defs.NOISE_WALK)
	_update_bob(delta, hspeed)
	_update_water(delta)
	_update_breathing(delta, tox)
	if global_position.y < -30.0:
		take_damage(99999.0, 0.0, global_position)

func _update_bob(delta: float, hspeed: float) -> void:
	var moving := is_on_floor() and hspeed > 0.5 and _dash_t <= 0.0
	var target := 0.0
	if moving:
		target = 1.0 if _sprinting else 0.35
	_bob_amount = move_toward(_bob_amount, target, delta * 3.0)
	_bob_t += delta * (hspeed * (1.45 if _sprinting else 1.6))
	var by := sin(_bob_t * 2.0) * 0.022 * _bob_amount + (sin(_bob_t * 2.0) * 0.03 * _bob_amount if _sprinting else 0.0)
	var bx := cos(_bob_t) * 0.018 * _bob_amount
	head.position = Vector3(bx, 1.62 + by, 0)
	cam.rotation.z = (cos(_bob_t) * deg_to_rad(1.4) * _bob_amount) if _sprinting else 0.0
	weapons.bob_phase = _bob_t
	weapons.bob_amount = _bob_amount
	weapons.sprinting = _sprinting

func _update_water(delta: float) -> void:
	var p := global_position
	var wl := game.data.water_at(p.x, p.z)
	var depth := wl - p.y
	if depth > Defs.KNEE_DEPTH:
		damage_toxic(Defs.WATER_TOXIC_PER_SEC * delta)
	var under := cam.global_position.y < wl
	if under != _underwater:
		_underwater = under
		lantern.suppressed = under
		neck_light.visible = not under
		weapons.set_lights_suppressed(under)
		if under:
			Sfx.play_3d("player/water_under", p, -4.0)
		else:
			Sfx.play_3d("player/water_in", p, -6.0)
	game.hud.set_underwater(under)

func _update_breathing(delta: float, tox: float) -> void:
	_breath_cd -= delta
	if tox > 0.5 and _breath_cd <= 0.0:
		# no human-made breathing sample exists in the packs: Unvanquished heartbeat instead
		Sfx.play_ui("player/heartbeat" if tox < 0.8 else "player/heartbeat_fast", lerpf(-14.0, 0.0, (tox - 0.5) * 2.0))
		_breath_cd = lerpf(1.6, 0.8, (tox - 0.5) * 2.0)

func damage_toxic(amount: float) -> void:
	if not alive or god_mode:
		return
	toxic = maxf(toxic - amount, 0.0)
	if toxic <= 0.0:
		_die(true)

func heal(hp: float, tx: float) -> void:
	health = minf(health + hp, Defs.MAX_HEALTH)
	toxic = minf(toxic + tx, Defs.MAX_TOXIC)

func take_damage(hp: float, tx: float, from: Vector3) -> void:
	if not alive or god_mode:
		return
	health -= hp
	if tx > 0.0:
		toxic = maxf(toxic - tx, 0.0)
	_last_damage_t = Time.get_ticks_msec() / 1000.0
	if hp > 0.0:
		game.hud.on_damage(hp, from)
		_pain_cd -= 1.0
		if _pain_cd <= 0.0:
			_pain_cd = 3.0
			Sfx.play_3d("player/pain%d" % randi_range(1, 3), global_position, -2.0, 30.0)
	if health <= 0.0:
		health = 0.0
		_die(false)
	elif toxic <= 0.0:
		_die(true)

func _process(delta: float) -> void:
	_pain_cd = maxf(_pain_cd - delta, -1.0)

func _die(from_toxic: bool) -> void:
	if not alive:
		return
	alive = false
	controls_enabled = false
	weapons.visible = false
	lantern.suppressed = true
	Sfx.play_3d("player/death", global_position, 0.0, 40.0)
	var body := RigidBody3D.new()
	body.collision_layer = 0
	body.collision_mask = 1
	body.mass = 4.0
	body.angular_damp = 1.5
	body.linear_damp = 0.4
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new(); sp.radius = 0.22
	cs.shape = sp
	body.add_child(cs)
	body.set_script(preload("res://scripts/player/death_cam.gd"))
	game.add_child(body)
	body.global_transform = cam.global_transform
	var keep := cam.global_transform
	cam.get_parent().remove_child(cam)
	body.add_child(cam)
	cam.global_transform = keep
	cam.make_current()
	if from_toxic:
		body.linear_velocity = Vector3(randf_range(-0.5, 0.5), -1.0, randf_range(-0.5, 0.5))
		body.angular_velocity = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	else:
		var side := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		body.linear_velocity = side * randf_range(2.0, 4.5) + Vector3.UP * randf_range(2.5, 4.5)
		body.angular_velocity = Vector3(randf_range(-6, 6), randf_range(-4, 4), randf_range(-6, 6))
	visible = false
	collision_layer = 0
	died.emit()
