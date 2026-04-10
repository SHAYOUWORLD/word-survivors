extends Node2D
## Vampire-Survivors-ish scrolling grid background. Drawn around the camera.

const CELL := 64
const LINE_COLOR := Color(0.14, 0.14, 0.18, 1.0)
const MAJOR_COLOR := Color(0.2, 0.22, 0.3, 1.0)
const DOT_COLOR := Color(0.25, 0.28, 0.38, 1.0)

var _cam: Camera2D = null

func _ready() -> void:
	z_index = -10

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if _cam == null:
		_cam = get_viewport().get_camera_2d()
	var center := Vector2.ZERO
	if _cam:
		center = _cam.global_position
	var vp := get_viewport_rect().size
	var half := vp * 0.75
	var x0 := int((center.x - half.x) / CELL) * CELL
	var x1 := int((center.x + half.x) / CELL) * CELL + CELL
	var y0 := int((center.y - half.y) / CELL) * CELL
	var y1 := int((center.y + half.y) / CELL) * CELL + CELL

	# Minor + major grid lines.
	for x in range(x0, x1 + 1, CELL):
		var col: Color = MAJOR_COLOR if (x % (CELL * 4)) == 0 else LINE_COLOR
		draw_line(Vector2(x, y0), Vector2(x, y1), col, 1.0)
	for y in range(y0, y1 + 1, CELL):
		var col: Color = MAJOR_COLOR if (y % (CELL * 4)) == 0 else LINE_COLOR
		draw_line(Vector2(x0, y), Vector2(x1, y), col, 1.0)

	# Dots at major intersections.
	for x in range(x0, x1 + 1, CELL * 4):
		for y in range(y0, y1 + 1, CELL * 4):
			draw_circle(Vector2(x, y), 2.0, DOT_COLOR)
