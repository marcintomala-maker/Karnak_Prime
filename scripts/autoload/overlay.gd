extends CanvasLayer
## Always-on-top layer: screen fades and the Emotional Support Pet.

var fade_rect: ColorRect
var pet: Control
var _fade_tween: Tween

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade_rect)
	pet = preload("res://scripts/ui/pet.gd").new()
	add_child(pet)

func fade_to(alpha: float, time: float, color := Color.BLACK) -> Signal:
	if _fade_tween:
		_fade_tween.kill()
	fade_rect.color = Color(color.r, color.g, color.b, fade_rect.color.a)
	_fade_tween = create_tween()
	_fade_tween.tween_property(fade_rect, "color:a", alpha, maxf(time, 0.01))
	return _fade_tween.finished

func set_black(alpha: float) -> void:
	if _fade_tween:
		_fade_tween.kill()
	fade_rect.color = Color(0, 0, 0, alpha)
