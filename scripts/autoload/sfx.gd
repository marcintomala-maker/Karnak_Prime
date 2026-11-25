extends Node
## Sound manager: pooled 3D voices (hard cap), UI sounds, looping music with crossfade.

const MAX_3D_VOICES := 32
const MAX_SAME_SOUND := 4
const MAX_UI_VOICES := 8

var _cache := {}
var _voices: Array[AudioStreamPlayer3D] = []
var _ui: Array[AudioStreamPlayer] = []
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_current := ""
var _tween: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in MAX_3D_VOICES:
		var p := AudioStreamPlayer3D.new()
		p.bus = "SFX"
		p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		p.unit_size = 6.0
		p.max_db = 3.0
		p.panning_strength = 1.0
		p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(p)
		_voices.append(p)
	for i in MAX_UI_VOICES:
		var u := AudioStreamPlayer.new()
		u.bus = "UI"
		add_child(u)
		_ui.append(u)
	_music_a = AudioStreamPlayer.new(); _music_a.bus = "Music"; add_child(_music_a)
	_music_b = AudioStreamPlayer.new(); _music_b.bus = "Music"; add_child(_music_b)

func stream(sound_name: String) -> AudioStream:
	if _cache.has(sound_name):
		return _cache[sound_name]
	var path := "res://assets/sfx/%s.ogg" % sound_name
	var s: AudioStream = null
	if ResourceLoader.exists(path):
		s = load(path)
	else:
		push_warning("missing sound " + sound_name)
	_cache[sound_name] = s
	return s

## Plays a positional sound. Steals the quietest/farthest voice if the pool is full.
func play_3d(sound_name: String, pos: Vector3, volume_db := 0.0, max_distance := 70.0, pitch := 1.0) -> AudioStreamPlayer3D:
	var s := stream(sound_name)
	if s == null:
		return null
	var same := 0
	var free_voice: AudioStreamPlayer3D = null
	var cam := get_viewport().get_camera_3d()
	var listener := cam.global_position if cam else Vector3.ZERO
	if listener.distance_to(pos) > max_distance:
		return null
	var worst: AudioStreamPlayer3D = null
	var worst_score := -INF
	for v in _voices:
		if v.playing:
			if v.stream == s:
				same += 1
			var score := v.global_position.distance_to(listener) + v.get_playback_position() * 4.0
			if score > worst_score:
				worst_score = score; worst = v
		elif free_voice == null:
			free_voice = v
	if same >= MAX_SAME_SOUND:
		return null
	var p := free_voice if free_voice else worst
	if p == null:
		return null
	p.stop()
	p.stream = s
	p.global_position = pos
	p.volume_db = volume_db
	p.max_distance = max_distance
	p.pitch_scale = pitch
	p.play()
	return p

func play_ui(sound_name: String, volume_db := 0.0, pitch := 1.0) -> void:
	var s := stream(sound_name)
	if s == null:
		return
	for u in _ui:
		if not u.playing:
			u.stream = s; u.volume_db = volume_db; u.pitch_scale = pitch; u.play()
			return
	_ui[0].stream = s; _ui[0].volume_db = volume_db; _ui[0].pitch_scale = pitch; _ui[0].play()

func play_music(music_name: String, fade := 1.5, loop := true, volume_db := 0.0) -> void:
	if music_name == _music_current and (_music_a.playing or _music_b.playing):
		return
	_music_current = music_name
	var s: AudioStream = null
	if music_name != "":
		s = load("res://assets/music/%s.ogg" % music_name)
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = loop
	var old := _music_a if _music_a.playing else _music_b
	var new := _music_b if old == _music_a else _music_a
	if _tween:
		_tween.kill()
	if s == null and not old.playing:
		return
	_tween = create_tween().set_parallel(true)
	if s:
		new.stream = s
		new.volume_db = -40.0
		new.play()
		_tween.tween_property(new, "volume_db", volume_db, fade)
	if old.playing:
		_tween.tween_property(old, "volume_db", -60.0, fade)
		_tween.chain().tween_callback(old.stop)

func stop_music(fade := 1.0) -> void:
	play_music("", fade)

func stop_all_3d() -> void:
	for v in _voices:
		v.stop()
