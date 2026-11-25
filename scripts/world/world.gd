class_name World
extends Node3D
## Builds the island, toxic water, city (0 A.D. buildings clad in Unvanquished textures),
## ziggurat, bridges, environment lights and the knee-high ground fog from WorldData.

const CHUNK := 64
const BUILDING_MATS := ["wall_a", "wall_b", "wall_c"]

var data: WorldData
var env: Environment
var moon: DirectionalLight3D
var light_pool: LightPool
var noise_tex: NoiseTexture2D
var building_bodies: Array[StaticBody3D] = []
var building_info: Array = []      # [{name, pos, rot, scale, aabb_world}]
var _mesh_cache := {}
var _shape_cache := {}
var _mats := {}

func build(world_data: WorldData, progress: Callable) -> void:
	data = world_data
	noise_tex = NoiseTexture2D.new()
	var fn := FastNoiseLite.new(); fn.frequency = 0.02; fn.fractal_octaves = 3
	noise_tex.noise = fn; noise_tex.seamless = true; noise_tex.width = 256; noise_tex.height = 256
	noise_tex.generate_mipmaps = true
	_setup_environment()
	progress.call(0.05)
	await _build_terrain(progress)
	_build_water()
	progress.call(0.45)
	await _build_buildings(progress)
	_build_ziggurat()
	_build_bridges()
	_build_lights()
	progress.call(1.0)

# ------------------------------------------------------------------ environment
func _setup_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var pm := PanoramaSkyMaterial.new()
	pm.panorama = load("res://assets/sky/night_pano.png")
	pm.energy_multiplier = 0.9
	sky.sky_material = pm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.BLACK
	env.ambient_light_energy = 0.0
	env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = Settings.brightness
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.0, 0.0, 0.0)
	env.fog_density = 0.0035
	env.fog_sky_affect = 0.0
	env.fog_aerial_perspective = 0.0
	we.environment = env
	add_child(we)
	Settings.changed.connect(func(): env.tonemap_exposure = Settings.brightness)
	moon = DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 1.0)
	moon.light_energy = 0.035
	moon.light_specular = 0.0
	moon.shadow_enabled = false
	moon.rotation_degrees = Vector3(-38, 30, 0)
	add_child(moon)

func _tex(n: String) -> Texture2D:
	return load("res://assets/tex/%s.png" % n)

# ------------------------------------------------------------------ terrain
func _build_terrain(progress: Callable) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	mat.set_shader_parameter("mask_tex", load("res://assets/world/mask.png"))
	mat.set_shader_parameter("dirt_tex", _tex("dirt"))
	mat.set_shader_parameter("sand_tex", _tex("sand"))
	mat.set_shader_parameter("street_tex", _tex("street"))
	mat.set_shader_parameter("plaza_tex", _tex("plaza"))
	mat.set_shader_parameter("creep_tex", load("res://assets/fx/creep_d.png"))
	mat.set_shader_parameter("world_half", data.half)
	var fog_mat := ShaderMaterial.new()
	fog_mat.shader = load("res://shaders/groundfog.gdshader")
	fog_mat.set_shader_parameter("noise_tex", noise_tex)
	fog_mat.render_priority = 1
	var N := data.N
	var nchunks := N / CHUNK
	var cx: float = data.meta.city.x; var cz: float = data.meta.city.z; var cr: float = data.meta.city.r
	for cj in nchunks:
		for ci in nchunks:
			var mesh := _chunk_mesh(ci * CHUNK, cj * CHUNK)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.material_override = mat
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			# ground fog only over the city
			var ccx := -data.half + (ci + 0.5) * CHUNK * data.cell
			var ccz := -data.half + (cj + 0.5) * CHUNK * data.cell
			if Vector2(ccx - cx, ccz - cz).length() < cr + 100:
				var fog := MeshInstance3D.new()
				fog.mesh = mesh
				fog.material_override = fog_mat
				fog.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				fog.visibility_range_end = 140.0
				fog.visibility_range_end_margin = 20.0
				fog.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
				add_child(fog)
		progress.call(0.05 + 0.35 * float(cj + 1) / nchunks)
		await get_tree().process_frame
	# collision: one heightmap for the whole island
	var hs := HeightMapShape3D.new()
	hs.map_width = N
	hs.map_depth = N
	hs.map_data = data.height
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = hs
	cs.scale = Vector3(data.cell, 1.0, data.cell)
	body.add_child(cs)
	add_child(body)

func _chunk_mesh(i0: int, j0: int) -> ArrayMesh:
	var N := data.N
	var w := mini(CHUNK, N - 1 - i0) + 1
	var h := mini(CHUNK, N - 1 - j0) + 1
	var verts := PackedVector3Array(); verts.resize(w * h)
	var norms := PackedVector3Array(); norms.resize(w * h)
	var hgt := data.height
	for j in h:
		for i in w:
			var gi := i0 + i; var gj := j0 + j
			var y := hgt[gj * N + gi]
			verts[j * w + i] = Vector3(-data.half + (gi + 0.5) * data.cell, y, -data.half + (gj + 0.5) * data.cell)
			var l := hgt[gj * N + maxi(gi - 1, 0)]; var r := hgt[gj * N + mini(gi + 1, N - 1)]
			var d := hgt[maxi(gj - 1, 0) * N + gi]; var u := hgt[mini(gj + 1, N - 1) * N + gi]
			norms[j * w + i] = Vector3(l - r, 2.0 * data.cell, d - u).normalized()
	var idx := PackedInt32Array(); idx.resize((w - 1) * (h - 1) * 6)
	var k := 0
	for j in h - 1:
		for i in w - 1:
			var a := j * w + i
			idx[k] = a; idx[k + 1] = a + 1; idx[k + 2] = a + w
			idx[k + 3] = a + 1; idx[k + 4] = a + w + 1; idx[k + 5] = a + w
			k += 6
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = norms
	arr[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return m

# ------------------------------------------------------------------ water
func water_material() -> ShaderMaterial:
	if _mats.has("water"):
		return _mats["water"]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/water.gdshader")
	m.set_shader_parameter("noise_tex", noise_tex)
	_mats["water"] = m
	return m

func _build_water() -> void:
	# lake: one huge plane at y = 0
	var lake := MeshInstance3D.new()
	var pm := PlaneMesh.new(); pm.size = Vector2(6000, 6000); pm.subdivide_width = 8; pm.subdivide_depth = 8
	lake.mesh = pm
	lake.material_override = water_material()
	lake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(lake)
	# ponds & canals: quads on every water cell (expanded by one cell)
	var N := data.N
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for j in range(1, N - 1):
		for i in range(1, N - 1):
			var wl := -1000.0
			for dj in range(-1, 2):
				for di in range(-1, 2):
					wl = maxf(wl, data.water[(j + dj) * N + i + di])
			if wl < 0.5:
				continue
			var x0 := -data.half + i * data.cell; var z0 := -data.half + j * data.cell
			var x1 := x0 + data.cell; var z1 := z0 + data.cell
			st.set_normal(Vector3.UP)
			st.add_vertex(Vector3(x0, wl, z0)); st.add_vertex(Vector3(x1, wl, z0)); st.add_vertex(Vector3(x0, wl, z1))
			st.add_vertex(Vector3(x1, wl, z0)); st.add_vertex(Vector3(x1, wl, z1)); st.add_vertex(Vector3(x0, wl, z1))
			count += 1
	if count > 0:
		var mi := MeshInstance3D.new()
		mi.mesh = st.commit()
		mi.material_override = water_material()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

# ------------------------------------------------------------------ buildings
func building_material(variant: int, base_y: float) -> ShaderMaterial:
	var key := "b%d_%d" % [variant, int(base_y)]
	if _mats.has(key):
		return _mats[key]
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/building.gdshader")
	m.set_shader_parameter("wall_tex", _tex(BUILDING_MATS[variant % BUILDING_MATS.size()]))
	m.set_shader_parameter("roof_tex", _tex("roof"))
	m.set_shader_parameter("trim_tex", _tex("trim"))
	m.set_shader_parameter("base_y", base_y)
	m.set_shader_parameter("tint", [Vector3(0.5, 0.53, 0.58), Vector3(0.6, 0.58, 0.56), Vector3(0.48, 0.5, 0.5)][variant % 3])
	_mats[key] = m
	return m

func _building_mesh(bname: String) -> Mesh:
	if _mesh_cache.has(bname):
		return _mesh_cache[bname]
	var scene: PackedScene = load("res://assets/models/buildings/%s.glb" % bname)
	var inst := scene.instantiate()
	var mi: MeshInstance3D = inst.find_children("*", "MeshInstance3D", true, false)[0]
	var mesh := mi.mesh
	inst.free()
	_mesh_cache[bname] = mesh
	return mesh

func _building_shape(bname: String, scl: float) -> ConcavePolygonShape3D:
	var key := "%s@%.3f" % [bname, scl]
	if _shape_cache.has(key):
		return _shape_cache[key]
	var mesh := _building_mesh(bname)
	var faces := mesh.get_faces()
	for k in faces.size():
		faces[k] *= scl
	var sh := ConcavePolygonShape3D.new()
	sh.set_faces(faces)
	sh.backface_collision = true
	_shape_cache[key] = sh
	return sh

func _build_buildings(progress: Callable) -> void:
	var list: Array = data.meta.buildings
	var rng := RandomNumberGenerator.new(); rng.seed = 4242
	var k := 0
	for b in list:
		var bname: String = b.name
		var scl: float = b.scale
		var pos := Vector3(b.x, b.y, b.z)
		var rot: float = b.rot
		var mesh := _building_mesh(bname)
		var xf := Transform3D(Basis(Vector3.UP, rot).scaled(Vector3.ONE * scl), pos)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.transform = xf
		mi.material_override = building_material(rng.randi() % 3, b.y)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 420.0
		mi.visibility_range_end_margin = 40.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mi)
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.transform = Transform3D(Basis(Vector3.UP, rot), pos)
		var cs := CollisionShape3D.new()
		cs.shape = _building_shape(bname, scl)
		body.add_child(cs)
		body.set_meta("building", true)
		add_child(body)
		building_bodies.append(body)
		# occluder: inner core of the bounding box
		var aabb := mesh.get_aabb()
		var core := Vector3(aabb.size.x * 0.5, maxf(aabb.end.y, 1.0) * 0.7, aabb.size.z * 0.5) * scl
		if core.x > 4 and core.z > 4 and core.y > 4:
			var occ := OccluderInstance3D.new()
			var box := BoxOccluder3D.new()
			box.size = core
			occ.occluder = box
			occ.transform = Transform3D(Basis(Vector3.UP, rot), pos + Basis(Vector3.UP, rot) * (Vector3(aabb.get_center().x, 0, aabb.get_center().z) * scl) + Vector3(0, core.y * 0.5, 0))
			add_child(occ)
		building_info.append({"name": bname, "pos": pos, "rot": rot, "scale": scl, "aabb": xf * aabb})
		k += 1
		if k % 12 == 0:
			progress.call(0.45 + 0.4 * float(k) / list.size())
			await get_tree().process_frame

# ------------------------------------------------------------------ ziggurat
func _box(size: Vector3, xf: Transform3D, mat: Material, collide := true) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.transform = xf
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = 1; body.collision_mask = 0
		body.transform = xf
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new(); sh.size = size
		cs.shape = sh
		body.add_child(cs)
		add_child(body)

func _build_ziggurat() -> void:
	var z: Dictionary = data.meta.ziggurat
	var c := Vector3(z.x, 0, z.z)
	var ang: float = z.stair_angle
	# Godot rotation about Y by -ang aligns local +X with the stair direction (cos a, sin a) in XZ
	var basis := Basis(Vector3.UP, -ang)
	var mat := building_material(1, z.y)
	for t in z.tiers:
		var hsz: float = t.half
		var y0: float = t.y0; var y1: float = t.y1
		var depth := y1 - y0 + 12.0          # sink into the ground
		var size := Vector3(hsz * 2.0, depth, hsz * 2.0)
		_box(size, Transform3D(basis, c + Vector3(0, y1 - depth * 0.5, 0)), mat)
		var occ := OccluderInstance3D.new()
		var bo := BoxOccluder3D.new(); bo.size = size * 0.9
		occ.occluder = bo
		occ.transform = Transform3D(basis, c + Vector3(0, y1 - depth * 0.5, 0))
		add_child(occ)
	var st: Dictionary = z.stair
	var run: float = st.out - st.inn
	var rise: float = z.top_y - z.y
	var length := sqrt(run * run + rise * rise)
	var slope := atan2(rise, run)
	var mid := Vector3((st.out + st.inn) * 0.5, (z.y + z.top_y) * 0.5 - 0.3, 0)
	var ramp_basis := basis * Basis(Vector3.BACK, -slope)
	var ramp_xf := Transform3D(ramp_basis, c + basis * mid)
	_box(Vector3(length, 0.6, st.width), ramp_xf, building_material(2, z.y))
	# side walls along the stair
	for s in [-1.0, 1.0]:
		var wall_xf := Transform3D(ramp_basis, c + basis * (mid + Vector3(0, 0.6, s * (st.width * 0.5 + 0.4))))
		_box(Vector3(length, 1.6, 0.8), wall_xf, mat)

# ------------------------------------------------------------------ bridges
func _build_bridges() -> void:
	var mat := building_material(2, 0.0)
	for b in data.meta.bridges:
		var xf := Transform3D(Basis(Vector3.UP, -float(b.rot)), Vector3(b.x, float(b.y) - 0.3, b.z))
		_box(Vector3(b.length, 0.6, b.width), xf, mat)
		for s in [-1.0, 1.0]:
			var rail := xf * Transform3D(Basis(), Vector3(0, 0.8, s * (float(b.width) * 0.5 - 0.15)))
			_box(Vector3(b.length, 1.0, 0.3), rail, mat)

# ------------------------------------------------------------------ cold-blue enviro lights
func _build_lights() -> void:
	light_pool = LightPool.new()
	add_child(light_pool)
	var lamp_tex := load("res://assets/ui/rune_glow.png")
	for l in data.meta.lights:
		var p := Vector3(l.x, l.y, l.z)
		var spr := Sprite3D.new()
		spr.texture = lamp_tex
		spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spr.pixel_size = 0.006
		spr.modulate = Color(0.45, 0.7, 1.0, 0.9)
		spr.shaded = false
		spr.position = p
		spr.visibility_range_end = 200.0
		spr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(spr)
		light_pool.add_static(p, Color(0.45, 0.62, 1.0), 16.0, 1.4)
