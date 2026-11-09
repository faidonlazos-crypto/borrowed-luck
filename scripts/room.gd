class_name Room extends Node2D

const PLAY_MIN: Vector2 = Vector2(40.0, 40.0)
const PLAY_SIZE: Vector2 = Vector2(1200.0, 640.0)

var _spawn_markers: Array[Marker2D] = []
var _rock_rects: Array[Rect2] = []
var _grid: AStarGrid2D
const CELL: float = 20.0
const AGENT_RADIUS: float = 16.0


func _ready() -> void:
	_build_floor()
	_build_walls()
	_build_rocks()
	_build_spawn_points()
	_build_grid()


## Path for a walker of AGENT_RADIUS from `from` to `to`, avoiding rocks.
## Returns world-space points (may be empty if no path).
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if _grid == null:
		return PackedVector2Array()
	var a := _to_cell(from)
	var b := _to_cell(to)
	if _grid.is_point_solid(b):
		b = _nearest_free(b)
	if _grid.is_point_solid(a):
		a = _nearest_free(a)
	var cells := _grid.get_id_path(a, b, true)
	var pts := PackedVector2Array()
	for c in cells:
		pts.append(PLAY_MIN + (Vector2(c) + Vector2(0.5, 0.5)) * CELL)
	return pts


func _build_grid() -> void:
	_grid = AStarGrid2D.new()
	_grid.region = Rect2i(0, 0, int(ceil(PLAY_SIZE.x / CELL)), int(ceil(PLAY_SIZE.y / CELL)))
	_grid.cell_size = Vector2(CELL, CELL)
	_grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_grid.update()
	for x in range(_grid.region.size.x):
		for y in range(_grid.region.size.y):
			var center := PLAY_MIN + (Vector2(x, y) + Vector2(0.5, 0.5)) * CELL
			var solid := false
			# keep away from outer walls
			if center.x < PLAY_MIN.x + AGENT_RADIUS or center.y < PLAY_MIN.y + AGENT_RADIUS \
					or center.x > PLAY_MIN.x + PLAY_SIZE.x - AGENT_RADIUS or center.y > PLAY_MIN.y + PLAY_SIZE.y - AGENT_RADIUS:
				solid = true
			for r in _rock_rects:
				if r.grow(AGENT_RADIUS + 2.0).has_point(center):
					solid = true
					break
			_grid.set_point_solid(Vector2i(x, y), solid)


func _to_cell(p: Vector2) -> Vector2i:
	var c := Vector2i(((p - PLAY_MIN) / CELL).floor())
	c.x = clampi(c.x, 0, _grid.region.size.x - 1)
	c.y = clampi(c.y, 0, _grid.region.size.y - 1)
	return c


func _nearest_free(c: Vector2i) -> Vector2i:
	for radius in range(1, 8):
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				var n := c + Vector2i(dx, dy)
				if _grid.is_in_boundsv(n) and not _grid.is_point_solid(n):
					return n
	return c


func get_spawn_points() -> Array[Vector2]:
	var points: Array[Vector2] = []
	for marker in _spawn_markers:
		if is_instance_valid(marker):
			points.append(marker.global_position)
	return points


func get_play_rect() -> Rect2:
	return Rect2(PLAY_MIN, PLAY_SIZE)


func _build_floor() -> void:
	var floor_rect := ColorRect.new()
	floor_rect.name = "Floor"
	floor_rect.position = PLAY_MIN
	floor_rect.size = PLAY_SIZE
	floor_rect.color = Color(0.09, 0.10, 0.14, 1.0)
	add_child(floor_rect)


func _build_walls() -> void:
	# Walls sit just outside the 1200x640 floor, leaving a visible border.
	_add_wall(Vector2(640.0, 28.0), Vector2(1248.0, 24.0))
	_add_wall(Vector2(640.0, 692.0), Vector2(1248.0, 24.0))
	_add_wall(Vector2(28.0, 360.0), Vector2(24.0, 688.0))
	_add_wall(Vector2(1252.0, 360.0), Vector2(24.0, 688.0))


func _build_rocks() -> void:
	_add_rock(Vector2(300.0, 180.0), Vector2(56.0, 56.0))
	_add_rock(Vector2(980.0, 180.0), Vector2(56.0, 56.0))
	_add_rock(Vector2(300.0, 540.0), Vector2(56.0, 56.0))
	_add_rock(Vector2(980.0, 540.0), Vector2(56.0, 56.0))


func _build_spawn_points() -> void:
	var positions: Array[Vector2] = [
		Vector2(150.0, 130.0),
		Vector2(1130.0, 130.0),
		Vector2(150.0, 590.0),
		Vector2(1130.0, 590.0),
		Vector2(640.0, 120.0),
		Vector2(640.0, 600.0),
		Vector2(170.0, 360.0),
		Vector2(1110.0, 360.0),
	]
	for pos in positions:
		var marker := Marker2D.new()
		marker.position = pos
		add_child(marker)
		_spawn_markers.append(marker)


func _add_wall(center: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = center

	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape_node.shape = rect
	body.add_child(shape_node)

	var visual := Polygon2D.new()
	visual.color = Color(0.35, 0.32, 0.42, 1.0)
	visual.polygon = _rect_points(size)
	body.add_child(visual)

	add_child(body)


func _add_rock(center: Vector2, size: Vector2) -> void:
	_rock_rects.append(Rect2(center - size * 0.5, size))
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = center

	var shape_node := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape_node.shape = rect
	body.add_child(shape_node)

	var visual := Polygon2D.new()
	visual.color = Color(0.45, 0.38, 0.30, 1.0)
	visual.polygon = _rect_points(size)
	body.add_child(visual)

	var highlight := Polygon2D.new()
	highlight.color = Color(0.60, 0.52, 0.42, 1.0)
	highlight.polygon = _rect_points(size * 0.55)
	body.add_child(highlight)

	add_child(body)


func _rect_points(size: Vector2) -> PackedVector2Array:
	var half := size * 0.5
	return PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])
