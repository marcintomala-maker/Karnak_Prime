class_name WorldData
extends RefCounted
## Loads the pre-generated world (heightfield, nav heights, water levels, walkability,
## layout JSON) and answers spatial queries. Also owns the A* grid.

var N := 512
var cell := 2.0
var half := 512.0
var height := PackedFloat32Array()
var nav_height := PackedFloat32Array()
var water := PackedFloat32Array()
var walk := PackedByteArray()
var meta: Dictionary
var astar := AStarGrid2D.new()
var city_cells := PackedInt32Array()     # walkable reachable cells inside the city
var spawn_cells := PackedInt32Array()    # subset with clearance, for alien spawns

func load_all() -> void:
	meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/world/world.json"))
	N = int(meta.N); cell = float(meta.cell); half = float(meta.half)
	height = FileAccess.get_file_as_bytes("res://assets/world/height.f32").to_float32_array()
	nav_height = FileAccess.get_file_as_bytes("res://assets/world/navheight.f32").to_float32_array()
	water = FileAccess.get_file_as_bytes("res://assets/world/water.f32").to_float32_array()
	var img: Image = load("res://assets/world/walk.png").get_image()
	img.convert(Image.FORMAT_L8)
	walk = img.get_data()
	astar.region = Rect2i(0, 0, N, N)
	astar.cell_size = Vector2(1, 1)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.update()
	astar.fill_solid_region(Rect2i(0, 0, N, N), false)
	var cx: float = meta.city.x; var cz: float = meta.city.z; var cr: float = meta.city.r
	for j in N:
		for i in N:
			var idx := j * N + i
			if walk[idx] < 128:
				astar.set_point_solid(Vector2i(i, j), true)
			else:
				var p := cell_center(i, j)
				if Vector2(p.x - cx, p.z - cz).length() < cr:
					city_cells.append(idx)
	for idx in city_cells:
		var i := idx % N; var j := idx / N
		if i > 2 and j > 2 and i < N - 3 and j < N - 3:
			if walk[idx - 1] > 128 and walk[idx + 1] > 128 and walk[idx - N] > 128 and walk[idx + N] > 128:
				spawn_cells.append(idx)

func cell_of(p: Vector3) -> Vector2i:
	return Vector2i(clampi(int((p.x + half) / cell), 0, N - 1), clampi(int((p.z + half) / cell), 0, N - 1))

func cell_center(i: int, j: int) -> Vector3:
	var x := -half + (i + 0.5) * cell
	var z := -half + (j + 0.5) * cell
	return Vector3(x, nav_height[j * N + i], z)

func _bilinear(arr: PackedFloat32Array, x: float, z: float) -> float:
	var fi := clampf((x + half) / cell - 0.5, 0.0, N - 1.001)
	var fj := clampf((z + half) / cell - 0.5, 0.0, N - 1.001)
	var i0 := int(fi); var j0 := int(fj)
	var tx := fi - i0; var tz := fj - j0
	var a := arr[j0 * N + i0]; var b := arr[j0 * N + i0 + 1]
	var c := arr[(j0 + 1) * N + i0]; var d := arr[(j0 + 1) * N + i0 + 1]
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz)

func ground_at(x: float, z: float) -> float:
	return _bilinear(height, x, z)

func nav_height_at(x: float, z: float) -> float:
	return _bilinear(nav_height, x, z)

## Water surface height at a point (lake = 0.0 everywhere off-terrain; ponds/canals from data).
func water_at(x: float, z: float) -> float:
	var c := cell_of(Vector3(x, 0, z))
	var w := water[c.y * N + c.x]
	return maxf(w, 0.0)

func is_walkable(p: Vector3) -> bool:
	var c := cell_of(p)
	return walk[c.y * N + c.x] > 128

func nearest_walkable(p: Vector3, radius := 6) -> Vector2i:
	var c := cell_of(p)
	if walk[c.y * N + c.x] > 128:
		return c
	for r in range(1, radius + 1):
		for dj in range(-r, r + 1):
			for di in range(-r, r + 1):
				if absi(di) != r and absi(dj) != r:
					continue
				var q := c + Vector2i(di, dj)
				if q.x >= 0 and q.y >= 0 and q.x < N and q.y < N and walk[q.y * N + q.x] > 128:
					return q
	return Vector2i(-1, -1)

## World-space path (cell centres at nav height). Empty if unreachable.
func find_path(from: Vector3, to: Vector3, partial := true) -> PackedVector3Array:
	var out := PackedVector3Array()
	var a := nearest_walkable(from)
	var b := nearest_walkable(to)
	if a.x < 0 or b.x < 0:
		return out
	var ids := astar.get_id_path(a, b, partial)
	# simple string-pulling: skip intermediate cells on straight runs
	var last_dir := Vector2i.ZERO
	for k in ids.size():
		var id: Vector2i = ids[k]
		if k > 0 and k < ids.size() - 1:
			var d: Vector2i = ids[k + 1] - id
			if d == last_dir:
				continue
			last_dir = d
		out.append(cell_center(id.x, id.y))
	return out

func set_blocked(p: Vector3, radius_m: float, blocked: bool) -> void:
	var c := cell_of(p)
	var r := int(ceil(radius_m / cell))
	for dj in range(-r, r + 1):
		for di in range(-r, r + 1):
			var q := c + Vector2i(di, dj)
			if q.x < 0 or q.y < 0 or q.x >= N or q.y >= N:
				continue
			if Vector2(di, dj).length() * cell > radius_m:
				continue
			if walk[q.y * N + q.x] > 128:
				astar.set_point_solid(q, blocked)

func random_city_point(rng: RandomNumberGenerator) -> Vector3:
	var idx := city_cells[rng.randi() % city_cells.size()]
	return cell_center(idx % N, idx / N)

func random_spawn_point(rng: RandomNumberGenerator) -> Vector3:
	var idx := spawn_cells[rng.randi() % spawn_cells.size()]
	return cell_center(idx % N, idx / N)
