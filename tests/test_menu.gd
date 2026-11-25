extends Node
## Dev: screenshots of menus and screens.
var n := 0
func _ready() -> void:
	await get_tree().process_frame
	get_tree().current_scene = null
	Settings.pet_enabled = true
	Settings.changed.emit()
	for s in ["seizure", "intro", "title", "menu", "credits", "failed", "complete"]:
		Flow.goto(s)
		await get_tree().create_timer(2.2).timeout
		Overlay.set_black(0.0)
		await _shot(s)
		if s == "menu":
			var m = get_tree().current_scene
			m._settings()
			await get_tree().create_timer(0.5).timeout
			await _shot("settings")
	get_tree().quit()
func _shot(nm: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/m_%02d_%s.png" % [n, nm])
	n += 1
