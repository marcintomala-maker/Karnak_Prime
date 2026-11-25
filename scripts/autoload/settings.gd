extends Node
## Persistent player settings (user://settings.cfg) and their application.

signal changed

const PATH := "user://settings.cfg"
const RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1600, 900), Vector2i(1920, 1080),
	Vector2i(2560, 1080), Vector2i(2560, 1440), Vector2i(3440, 1440), Vector2i(3840, 2160)]
const WINDOW_MODES := ["Windowed", "Fullscreen", "Borderless Fullscreen"]
## Quake-style yaw/pitch per raw mouse count (degrees). Middle slider = exactly this, no curves.
const DEG_PER_COUNT := 0.022

var sfx_volume := 0.8
var music_volume := 0.6
var brightness := 1.0          # 0.5 .. 2.0, 1.0 neutral
var sensitivity := 0.5         # slider 0..1, 0.5 == raw 1:1
var resolution := Vector2i(1920, 1080)
var window_mode := 2
var pet_enabled := false
var pet_size := 1.0            # 0.5 .. 2.0

func _ready() -> void:
	_ensure_buses()
	load_settings()
	apply()

func _ensure_buses() -> void:
	for bus in ["Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master")

## Multiplier applied to raw mouse counts. Exactly 1.0 at the slider's middle (0.5),
## 0.25x at the far left, 4x at the far right (log scale, no acceleration, no smoothing).
func sensitivity_multiplier() -> float:
	if is_equal_approx(sensitivity, 0.5):
		return 1.0
	return pow(4.0, (sensitivity - 0.5) * 2.0)

func radians_per_count() -> float:
	return deg_to_rad(DEG_PER_COUNT) * sensitivity_multiplier()

func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		resolution = DisplayServer.screen_get_size()
		return
	sfx_volume = cf.get_value("audio", "sfx", sfx_volume)
	music_volume = cf.get_value("audio", "music", music_volume)
	brightness = cf.get_value("video", "brightness", brightness)
	resolution = cf.get_value("video", "resolution", resolution)
	window_mode = cf.get_value("video", "window_mode", window_mode)
	sensitivity = cf.get_value("input", "sensitivity", sensitivity)
	pet_enabled = cf.get_value("extra", "pet", pet_enabled)
	pet_size = cf.get_value("extra", "pet_size", pet_size)

func save_settings() -> void:
	var cf := ConfigFile.new()
	cf.set_value("audio", "sfx", sfx_volume)
	cf.set_value("audio", "music", music_volume)
	cf.set_value("video", "brightness", brightness)
	cf.set_value("video", "resolution", resolution)
	cf.set_value("video", "window_mode", window_mode)
	cf.set_value("input", "sensitivity", sensitivity)
	cf.set_value("extra", "pet", pet_enabled)
	cf.set_value("extra", "pet_size", pet_size)
	cf.save(PATH)

func _db(v: float) -> float:
	return -80.0 if v <= 0.001 else linear_to_db(v)

func apply_audio() -> void:
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), _db(sfx_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("UI"), _db(sfx_volume))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), _db(music_volume))

func apply_video() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var win := get_window()
	match window_mode:
		0:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, false)
			var scr := DisplayServer.screen_get_size()
			var sz := Vector2i(mini(resolution.x, scr.x), mini(resolution.y, scr.y))
			DisplayServer.window_set_size(sz)
			DisplayServer.window_set_position(DisplayServer.screen_get_position() + (scr - sz) / 2)
			win.scaling_3d_scale = 1.0
		1:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
			_apply_render_scale(win)
		2:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
			_apply_render_scale(win)

## In the fullscreen modes the chosen resolution becomes the 3D render resolution.
func _apply_render_scale(win: Window) -> void:
	var scr := DisplayServer.screen_get_size()
	if scr.x <= 0:
		return
	win.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	win.scaling_3d_scale = clampf(float(resolution.x) / float(scr.x), 0.25, 2.0)

func apply() -> void:
	apply_audio()
	apply_video()
	changed.emit()

func resolution_index() -> int:
	var i := RESOLUTIONS.find(resolution)
	return i if i >= 0 else 3
