class_name Briefing
extends CanvasLayer
## Mission briefing typed letter by letter in red on black (plays while the world builds).

signal done

const LINES := [
	"KARNAK PRIME",
	"POPULATION = ANNIHILATED",
	"CAUSE = ALIEN HIVE",
	"LANDING = IMMINENT",
	"SACRED VIOLENCE DOCTRINE = ACTIVATED",
	"OBJECTIVE = LEAVE NOTHING ALIVE",
]

var _labels: Array[Label] = []
var _bg: ColorRect
var progress := 0.0
var _bar: ColorRect
var typed := false

func _ready() -> void:
	layer = 50
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bg = ColorRect.new(); _bg.color = Color.BLACK; UIKit.fullscreen(_bg); add_child(_bg)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 22)
	UIKit.fullscreen(v)
	add_child(v)
	for l in LINES:
		var lab := UIKit.label("", 54 if l == LINES[0] else 40, Color(1.0, 0.12, 0.08), "Black")
		lab.add_theme_color_override("font_shadow_color", Color(1, 0, 0, 0.5))
		lab.add_theme_constant_override("shadow_outline_size", 10)
		v.add_child(lab)
		_labels.append(lab)
	_bar = ColorRect.new()
	_bar.color = Color(1.0, 0.12, 0.08, 0.5)
	_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_bar.position = Vector2(0, -6); _bar.size = Vector2(0, 3)
	add_child(_bar)
	Overlay.set_black(0.0)
	_type()

func _type() -> void:
	await get_tree().create_timer(0.8).timeout
	for i in LINES.size():
		var line: String = LINES[i]
		for c in line.length():
			_labels[i].text = line.substr(0, c + 1)
			if line[c] != " ":
				Sfx.play_ui("ui/letter", -10.0, randf_range(1.3, 1.6))
			await get_tree().create_timer(0.045).timeout
		await get_tree().create_timer(0.45).timeout
	await get_tree().create_timer(0.8).timeout
	typed = true
	done.emit()

func _process(_d: float) -> void:
	_bar.size.x = get_viewport().get_visible_rect().size.x * progress

func finish() -> void:
	var tw := create_tween()
	for l in _labels:
		tw.parallel().tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_property(_bg, "color:a", 0.0, 1.4)
	tw.tween_callback(queue_free)
