extends Control
## Emotional Support Pet: Duelyst's "neutral_nip" walking along the bottom screen edge.
## Animations: breathing (calm), idle, run, attack (on click, with its Duelyst sound).

var sprite: AnimatedSprite2D
var _state := "breathing"
var _timer := 2.0
var _target_x := 0.0
var _attacking := false
const BASE_SCALE := 2.0      # Duelyst draws unit sprites at ~1.6x on a 1080p battlefield

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = _build_frames()
	sprite.centered = true
	add_child(sprite)
	sprite.animation_finished.connect(_on_anim_finished)
	Settings.changed.connect(_apply)
	_apply()
	sprite.position = Vector2(get_viewport_rect().size.x * 0.8, 0)
	_play("breathing")

func _build_frames() -> SpriteFrames:
	var sf := SpriteFrames.new()
	var tex: Texture2D = load("res://assets/pet/neutral_nip.png")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/pet/neutral_nip.json"))
	var keys := data.keys()
	keys.sort()
	if sf.has_animation("default"):
		sf.remove_animation("default")
	for anim in ["breathing", "idle", "run", "attack"]:
		sf.add_animation(anim)
		sf.set_animation_speed(anim, 14.0 if anim != "attack" else 24.0)
		sf.set_animation_loop(anim, anim != "attack")
		for k in keys:
			if String(k).begins_with("neutral_nip_%s_" % anim):
				var f: Dictionary = data[k]
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(f.x, f.y, f.w, f.h)
				sf.add_frame(anim, at)
	return sf

func _apply() -> void:
	visible = Settings.pet_enabled
	set_process(visible)
	set_process_input(visible)
	sprite.scale = Vector2.ONE * BASE_SCALE * Settings.pet_size

func _play(a: String) -> void:
	_state = a
	sprite.play(a)

func _on_anim_finished() -> void:
	if _state == "attack":
		_attacking = false
		_play("breathing")
		_timer = randf_range(1.0, 3.0)

func _process(delta: float) -> void:
	var vp := get_viewport_rect().size
	var h := 100.0 * sprite.scale.y
	sprite.position.y = vp.y - h * 0.38
	if _attacking:
		return
	if _state == "run":
		var dir := signf(_target_x - sprite.position.x)
		sprite.flip_h = dir < 0
		sprite.position.x += dir * 140.0 * Settings.pet_size * delta
		if absf(_target_x - sprite.position.x) < 6.0:
			_play("idle" if randf() < 0.5 else "breathing")
			_timer = randf_range(2.0, 7.0)
		return
	_timer -= delta
	if _timer <= 0.0:
		var r := randf()
		if r < 0.55:
			_target_x = randf_range(80.0, vp.x - 80.0)
			_play("run")
		elif r < 0.8:
			_play("idle"); _timer = randf_range(2.0, 6.0)
		else:
			_play("breathing"); _timer = randf_range(3.0, 8.0)

func _input(event: InputEvent) -> void:
	if not visible or _attacking:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			return
		var p: Vector2 = event.position
		var half := Vector2(36, 36) * sprite.scale
		if Rect2(sprite.position - half, half * 2).has_point(p):
			_attacking = true
			_play("attack")
			Sfx.play_ui("ui/nip_attack")
			get_viewport().set_input_as_handled()
