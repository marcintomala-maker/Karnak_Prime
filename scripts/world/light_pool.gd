class_name LightPool
extends Node3D
## Keeps only the nearest N environment lights alive (no shadows, no specular).

const MAX_ACTIVE := 14
var _points: Array = []     # [{pos, color, range, energy}]
var _lights: Array[OmniLight3D] = []
var _t := 0.0

func _ready() -> void:
	for i in MAX_ACTIVE:
		var l := OmniLight3D.new()
		l.shadow_enabled = false
		l.light_specular = 0.0
		l.distance_fade_enabled = true
		l.distance_fade_begin = 60.0
		l.distance_fade_length = 25.0
		l.visible = false
		add_child(l)
		_lights.append(l)

func add_static(p: Vector3, c: Color, r: float, e: float) -> void:
	_points.append({"pos": p, "color": c, "range": r, "energy": e})

func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.35
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var cp := cam.global_position
	var near: Array = []
	for p in _points:
		var d: float = cp.distance_squared_to(p.pos)
		if d < 95.0 * 95.0:
			near.append([d, p])
	near.sort_custom(func(a, b): return a[0] < b[0])
	for i in MAX_ACTIVE:
		var l := _lights[i]
		if i < near.size():
			var p: Dictionary = near[i][1]
			l.global_position = p.pos
			l.light_color = p.color
			l.omni_range = p.range
			l.light_energy = p.energy
			l.visible = true
		else:
			l.visible = false
