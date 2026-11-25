extends Control
## Main menu: slowly turning deep-space skybox, pulsing sacred geometry, Duelyst tutorial music.

var cam: Camera3D
var env: Environment
var menu_box: VBoxContainer
var geo: SacredGeometry
var _t := 0.0
var _busy := false

func _ready() -> void:
	UIKit.fullscreen(self)
	# --- 3D backdrop
	var world := Node3D.new()
	add_child(world)
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var pm := PanoramaSkyMaterial.new()
	pm.panorama = load("res://assets/sky/menu_pano.png")
	sky.sky_material = pm
	env.sky = sky
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	we.environment = env
	world.add_child(we)
	cam = Camera3D.new()
	cam.fov = 70
	world.add_child(cam)
	cam.make_current()
	_apply_brightness()
	Settings.changed.connect(_apply_brightness)
	# --- sacred geometry
	geo = SacredGeometry.new()
	geo.radius = 420; geo.intensity = 0.75; geo.speed = 0.5; geo.tint = Color(0.45, 0.85, 1.0)
	UIKit.fullscreen(geo)
	add_child(geo)
	var title := UIKit.label("KARNAK PRIME", 110, Color(0.9, 0.97, 1.0))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(-500, 90); title.size = Vector2(1000, 140)
	title.add_theme_color_override("font_shadow_color", Color(0.2, 0.8, 1.0, 0.6))
	title.add_theme_constant_override("shadow_outline_size", 18)
	add_child(title)
	var sub := RuneText.new()
	sub.glyph_height = 34
	sub.set_sentence("karnak prime title", 13, 3)
	sub.set_anchors_preset(Control.PRESET_CENTER_TOP)
	sub.position = Vector2(-sub.size.x * 0.5, 235)
	add_child(sub)
	menu_box = VBoxContainer.new()
	menu_box.add_theme_constant_override("separation", 18)
	menu_box.set_anchors_preset(Control.PRESET_CENTER)
	menu_box.position = Vector2(-190, -60)
	add_child(menu_box)
	var start := UIKit.button("START MISSION", 32, UIKit.RED.lerp(Color.WHITE, 0.2))
	start.pressed.connect(_start)
	menu_box.add_child(start)
	var st := UIKit.button("SETTINGS")
	st.pressed.connect(_settings)
	menu_box.add_child(st)
	var cr := UIKit.button("CREDITS")
	cr.pressed.connect(func(): _go("credits"))
	menu_box.add_child(cr)
	var q := UIKit.button("QUIT")
	q.pressed.connect(func(): get_tree().quit())
	menu_box.add_child(q)
	var ver := UIKit.label("v" + str(ProjectSettings.get_setting("application/config/version")), 16, Color(1, 1, 1, 0.3), "Light")
	ver.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	ver.position = Vector2(18, -36)
	add_child(ver)
	Sfx.play_music("music_tutorial", 2.0)
	Overlay.fade_to(0.0, 1.5)

func _apply_brightness() -> void:
	env.tonemap_exposure = Settings.brightness

func _process(delta: float) -> void:
	_t += delta
	cam.rotation = Vector3(0.12 * sin(_t * 0.05), _t * 0.012, 0.04 * sin(_t * 0.07))
	geo.intensity = 0.6 + 0.2 * sin(_t * 0.9)

func _settings() -> void:
	menu_box.visible = false
	var cc := CenterContainer.new()
	UIKit.fullscreen(cc)
	add_child(cc)
	var p := SettingsPanel.new()
	cc.add_child(p)
	p.closed.connect(func(): menu_box.visible = true; cc.queue_free())

func _start() -> void:
	if _busy:
		return
	_busy = true
	Sfx.stop_music(1.2)
	Sfx.play_ui("ui/panel_open")
	await Overlay.fade_to(1.0, 1.0)
	Flow.goto("game")

func _go(s: String) -> void:
	if _busy:
		return
	_busy = true
	await Overlay.fade_to(1.0, 0.5)
	Flow.goto(s)
