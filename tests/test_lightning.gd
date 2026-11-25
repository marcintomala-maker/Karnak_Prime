extends Node
## Dev: trigger a lightning strike and screenshot before / during / after.
func _ready() -> void:
	await get_tree().process_frame
	get_tree().current_scene = null
	Flow.goto("game")
	await get_tree().create_timer(1.0).timeout
	var g: Game = Game.I
	while not g._ready_to_play:
		await get_tree().process_frame
	g.player.god_mode = true
	var p := g.player
	var c := g.data.nearest_walkable(g.zig_center + Vector3(120, 0, 40), 8)
	p.global_position = g.data.cell_center(c.x, c.y) + Vector3.UP * 0.3
	var to := g.zig_center - p.global_position
	p.set_look(atan2(-to.x, -to.z), 0.1)
	p.lantern.on = false
	await get_tree().create_timer(2.5).timeout
	await _shot("before")
	g._strike()
	await get_tree().create_timer(0.25).timeout
	await _shot("flash")
	await get_tree().create_timer(2.0).timeout
	await _shot("after")
	print("lightning visible after: ", g._lightning.visible, " next in ", g._lightning_t)
	get_tree().quit()
func _shot(n: String) -> void:
	for i in 2:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/l_%s.png" % n)
