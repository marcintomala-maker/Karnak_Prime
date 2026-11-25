extends Node
## Dev smoke test: start a mission, exercise systems, save screenshots.
var shots := 0
func _ready() -> void:
	await get_tree().process_frame
	get_tree().current_scene = null
	Flow.goto("game")
	await get_tree().create_timer(1.0).timeout
	var g: Game = Game.I
	while not g._ready_to_play:
		await get_tree().process_frame
	print("GAME READY  eggs=", g.eggs.size(), " overminds=", g.overminds.size(), " statics=", g.statics.size(), " buildings=", g.world.building_info.size())
	await _shot("spawn")
	var p := g.player
	p.god_mode = "--mortal" not in OS.get_cmdline_user_args()
	# walk into the city near an overmind
	var om: Node3D = g.overminds[1]
	var cell := g.data.nearest_walkable(om.global_position + Vector3(12, 0, 0), 6)
	p.global_position = g.data.cell_center(cell.x, cell.y) + Vector3.UP * 0.3
	var to := om.global_position - p.global_position
	p.set_look(atan2(-to.x, -to.z), -0.05)
	await get_tree().create_timer(0.5).timeout
	await _shot("city_overmind")
	# spawn a few aliens in front
	var fwd := -p.global_transform.basis.z
	for t in ["mantis", "marauder", "dragoon", "granger", "trapper", "tyrant"]:
		var c := g.data.nearest_walkable(p.global_position + fwd * 22.0 + p.global_transform.basis.x * randf_range(-5, 5), 4)
		if c.x >= 0:
			g.director.spawn(t, g.data.cell_center(c.x, c.y), false)
	await get_tree().create_timer(0.4).timeout
	await _shot("aliens")
	# shoot for 1.5 s
	Input.action_press("fire")
	await get_tree().create_timer(1.5).timeout
	Input.action_release("fire")
	await _shot("after_fire")
	# flare
	p.weapons._fire_flare()
	await get_tree().create_timer(1.5).timeout
	await _shot("flare")
	# build: switch to ckit and place reactor + turret
	p.weapons.select(0)
	await get_tree().create_timer(0.5).timeout
	g.place_building("reactor", p.global_position + fwd * 3.0, 0.0)
	await get_tree().create_timer(0.2).timeout
	for b in g.player_buildings: b.build_progress = 0.99
	await get_tree().create_timer(0.3).timeout
	g.place_building("mgturret", p.global_position + fwd * 3.0 + p.global_transform.basis.x * 3.0, p.rotation.y)
	await get_tree().create_timer(0.3).timeout
	await _shot("buildings")
	g.hud.open_build_menu()
	await get_tree().create_timer(0.3).timeout
	await _shot("build_menu")
	g.hud.build_menu.close_menu()
	print("aliens alive ", g.director.aliens.size(), " player hp ", p.health, " tox ", p.toxic)
	# let the AI run for a while
	await get_tree().create_timer(4.0).timeout
	print("after AI: aliens ", g.director.aliens.size(), " hp ", p.health, " fps ", Engine.get_frames_per_second())
	await _shot("ai_run")
	if not p.alive:
		print("player died during AI run (expected with 6 aliens at 9 m)")
		await get_tree().create_timer(3.0).timeout
		get_tree().quit()
		return
	# force the ending
	g.overminds_destroyed = 6
	g.eggs_destroyed = g.egg_total - 1
	g.eggs[0].take_damage(100.0, true)
	await get_tree().create_timer(3.0).timeout
	await _shot("victory_flare")
	await get_tree().create_timer(6.0).timeout
	await _shot("victory_sky")
	await get_tree().create_timer(3.0).timeout
	await _shot("sunrise")
	await get_tree().create_timer(9.0).timeout
	await _shot("complete")
	get_tree().quit()

func _shot(n: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/g_%02d_%s.png" % [shots, n])
	shots += 1
	print("shot ", n)
