extends AnimatableBody3D
enum Difficulty { EASY, MEDIUM, HARD }
@export var difficulty := Difficulty.EASY

const EASY = preload("res://Scripts/Easy_Holes.gd")
const MEDIUM = preload("res://Scripts/Meduim_Holes.gd")
const HARD = preload("res://Scripts/Hard_Holes.gd")

var levels: Array
@export var speed := 2.0
@export var wall_width := 20.0
@export var wall_height := 4.0
@export var thickness := 0.5
@export var meters_per_px := 0.02   # 400x200 image = 8 m x 4 m
@export var simplify := 1.5         # outline smoothing in px
@export var slice := 0.05           # collision slice width in m
@export var hole_x := 0.0
@export var start_z := -9.0
@export var end_z := 11.0
@export var start_level := 0
@export var wall_color := Color(0.85, 0.45, 0.2)
@export var isActive := true
@export var player : CharacterBody3D
var player_start: Vector3
var has_passed := false
@export var start_delay := 3.0
var started := false

var level_index := 0
var built: Array[Node] = []

func _ready():
	_pick_levels()
	if isActive :
		position = Vector3(0, 0, start_z)
		level_index = start_level
		if player:
			player_start = player.global_position
		await get_tree().create_timer(start_delay).timeout
		_build(levels[level_index])
	started = true
func _physics_process(delta):
	if not started :
		return
	position.z += speed * delta
	if (position.z > end_z) and (isActive):
		position.z = start_z
		level_index = (level_index + 1) % levels.size()
		_build(levels[level_index])
	if player and isActive:
		var passed := global_position.z > player.global_position.z
		if passed and not has_passed:
			has_passed = true
			player.global_position = player_start
			player.velocity = Vector3.ZERO
		elif not passed:
			has_passed = false

func _build(level: Dictionary):
	for n in built:
		n.queue_free()
	built.clear()
	var polys := _load_polys(level["file"])
	_build_visual(polys)
	_build_collision(polys)

# black pixels = hole, white = wall. Image bottom = floor, centered on x.
func _load_polys(path: String) -> Array:
	var tex := load(path) as Texture2D
	if tex == null:
		push_error("Hole image not found: " + path)
		return []
	var img := tex.get_image()
	var w := img.get_width()
	var h := img.get_height()
	var bm := BitMap.new()
	bm.create(Vector2i(w, h))
	for y in h:
		for x in w:
			bm.set_bit(x, y, img.get_pixel(x, y).get_luminance() < 0.5)
	var polys := []
	for p in bm.opaque_to_polygons(Rect2i(0, 0, w, h), simplify):
		var out := PackedVector2Array()
		for v in p:
			out.append(Vector2((v.x - w / 2.0) * meters_per_px + hole_x, (h - v.y) * meters_per_px))
		if out.size() >= 3:
			polys.append(out)
	return polys

func _build_visual(polys: Array):
	var mat := StandardMaterial3D.new()
	mat.albedo_color = wall_color
	var comb := CSGCombiner3D.new()
	var box := CSGBox3D.new()
	box.size = Vector3(wall_width, wall_height, thickness)
	box.position = Vector3(0, wall_height / 2.0, 0)
	box.material = mat
	comb.add_child(box)
	for p in polys:
		var cut := CSGPolygon3D.new()
		cut.operation = CSGShape3D.OPERATION_SUBTRACTION
		cut.polygon = p
		cut.mode = CSGPolygon3D.MODE_DEPTH
		cut.depth = thickness * 3.0
		cut.position = Vector3(0, 0, thickness * 1.5)
		cut.material = mat
		comb.add_child(cut)
	add_child(comb)
	built.append(comb)

func _build_collision(polys: Array):
	var half := wall_width / 2.0
	if polys.is_empty():
		_add_box(-half, half, 0.0, wall_height)
		return
	var min_x := INF
	var max_x := -INF
	for p in polys:
		for v in p:
			min_x = minf(min_x, v.x)
			max_x = maxf(max_x, v.x)
	min_x = floorf(min_x / slice) * slice
	max_x = ceilf(max_x / slice) * slice
	_add_box(-half, min_x, 0.0, wall_height)
	_add_box(max_x, half, 0.0, wall_height)

	var cols := roundi((max_x - min_x) / slice)
	var open := {}
	for i in cols + 1:
		var runs := {}
		if i < cols:
			var xc := min_x + (i + 0.5) * slice
			for iv in _solid_intervals(polys, xc):
				runs["%d:%d" % [roundi(iv.x * 100), roundi(iv.y * 100)]] = iv
		var x_now := min_x + i * slice
		for key in open.keys():
			if not runs.has(key):
				_add_box(open[key]["x"], x_now, open[key]["iv"].x, open[key]["iv"].y)
				open.erase(key)
		for key in runs:
			if not open.has(key):
				open[key] = {"x": x_now, "iv": runs[key]}

# solid y-ranges of the wall along a vertical line at x
func _solid_intervals(polys: Array, xc: float) -> Array:
	var line := PackedVector2Array([Vector2(xc, -1.0), Vector2(xc, wall_height + 1.0)])
	var holes := []
	for p in polys:
		for seg in Geometry2D.intersect_polyline_with_polygon(line, p):
			var a := clampf(minf(seg[0].y, seg[-1].y), 0.0, wall_height)
			var b := clampf(maxf(seg[0].y, seg[-1].y), 0.0, wall_height)
			if b - a > 0.001:
				holes.append(Vector2(a, b))
	holes.sort_custom(func(m, n): return m.x < n.x)
	var out := []
	var cursor := 0.0
	for h in holes:
		if h.x > cursor + 0.005:
			out.append(Vector2(cursor, h.x))
		cursor = maxf(cursor, h.y)
	if cursor < wall_height - 0.005:
		out.append(Vector2(cursor, wall_height))
	return out

func _add_box(x0: float, x1: float, y0: float, y1: float):
	if x1 - x0 < 0.001 or y1 - y0 < 0.001:
		return
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(x1 - x0, y1 - y0, thickness)
	col.shape = shape
	col.position = Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, 0)
	add_child(col)
	built.append(col)
func _pick_levels():
	match GameState.difficulty:
		0: levels = EASY.LEVEL
		1: levels = MEDIUM.LEVEL
		2: levels = HARD.LEVEL
		
