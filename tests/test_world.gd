extends Node3D
## Dev test: build the world and save screenshots from several viewpoints.
func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var wd := WorldData.new()
	wd.load_all()
	print("data loaded ms ", Time.get_ticks_msec() - t0)
	var w := World.new()
	add_child(w)
	await w.build(wd, func(p): pass)
	print("world built ms ", Time.get_ticks_msec() - t0)
	var cam := Camera3D.new(); cam.far = 1500; add_child(cam); cam.make_current()
	var lit := "--lit" in OS.get_cmdline_user_args()
	if lit:
		w.env.ambient_light_color = Color(0.6, 0.6, 0.7); w.env.ambient_light_energy = 1.0
		w.moon.light_energy = 1.2
		w.env.fog_density = 0.0005
	var z: Dictionary = wd.meta.ziggurat
	var sp: Dictionary = wd.meta.spawn
	var views := [
		[Vector3(-300, 260, 420), Vector3(10, 30, 15)],
		[Vector3(z.x + 140, z.top_y + 30, z.z + 120), Vector3(z.x, z.y + 20, z.z)],
		[Vector3(sp.x, sp.y + 1.7, sp.z), Vector3(z.x, 40, z.z)],
	]
	# a street-level view in the city
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var p := wd.random_city_point(rng)
	views.append([p + Vector3(0, 1.7, 0), p + Vector3(30, 8, 10)])
	var k := 0
	for v in views:
		cam.global_position = v[0]
		cam.look_at(v[1])
		for i in 6:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("/tmp/shot_%d.png" % k)
		print("shot ", k, " fps ", Engine.get_frames_per_second())
		k += 1
	print("render info draw calls ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), " prims ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	get_tree().quit()
