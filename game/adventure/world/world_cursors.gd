class_name WorldCursors
extends RefCounted
## THE WORLD SCREEN'S POINTERS (the owner, 2026-10-22: *"for walking
## normally a cursor of the mouse displays a small walking man. For
## entering town it changes to an open door when hovering over a town"*).
## The 1997 world screen kept Windows' own arrow (its window class loads
## `IDC_ARROW`), so these are drawn [QoL], in the Embark screen's gold on
## a dark outline: drawn large, edges smoothed, then made cursor-sized.

const SIZE := 32
const DRAWN := 128
const GOLD := Color8(236, 196, 116)
const INK := Color8(38, 16, 10)
const WOOD := Color8(128, 72, 32)
const WOOD_DARK := Color8(84, 44, 18)
const LIGHT := Color8(255, 226, 150)

## What a pointer shows: walking on, or a door to a site.
enum Kind { WALK, DOOR }

static var _made := {}


## The pointer picture for [param kind], made once.
static func image(kind: Kind) -> Image:
	if not _made.has(kind):
		_made[kind] = _walker() if kind == Kind.WALK else _door()
	return _made[kind]


## Where the pointer points: the walker's feet, the door's middle.
static func hotspot(kind: Kind) -> Vector2:
	return Vector2(15, 30) if kind == Kind.WALK else Vector2(16, 16)


## Wear [param kind]'s pointer.
static func wear(kind: Kind) -> void:
	Input.set_custom_mouse_cursor(image(kind), Input.CURSOR_ARROW, hotspot(kind))


## Back to the game's own pointer.
static func take_off() -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)


# ------------------------------------------------------------ the shapes --

## A small walking man in mid-stride, facing right.
static func _walker() -> Image:
	var limbs: Array = [
		[Vector2(64, 40), Vector2(58, 76), 10.0],     # the body
		[Vector2(58, 76), Vector2(46, 98), 8.0],      # the back thigh
		[Vector2(46, 98), Vector2(36, 118), 7.0],     # the back shin
		[Vector2(58, 76), Vector2(74, 96), 8.0],      # the front thigh
		[Vector2(74, 96), Vector2(88, 114), 7.0],     # the front shin
		[Vector2(64, 46), Vector2(48, 64), 6.0],      # the back arm
		[Vector2(64, 46), Vector2(82, 60), 6.0],      # the front arm
	]
	var head := Vector2(70, 24)
	var shape := func(at: Vector2) -> float:
		var d := at.distance_to(head) - 13.0
		for limb in limbs:
			d = minf(d, _capsule(at, limb[0], limb[1]) - float(limb[2]))
		return d
	return _paint(shape, GOLD, 6.0)


## An open door, warm light in the doorway.
static func _door() -> Image:
	var image := Image.create_empty(DRAWN, DRAWN, false, Image.FORMAT_RGBA8)
	for y in DRAWN:
		for x in DRAWN:
			var at := Vector2(x + 0.5, y + 0.5)
			var color := Color(0, 0, 0, 0)
			var frame := Rect2(30, 8, 76, 116)
			var doorway := Rect2(40, 18, 56, 106)
			var panel := PackedVector2Array([Vector2(40, 18), Vector2(14, 30), Vector2(14, 112), Vector2(40, 124)])
			if frame.grow(5).has_point(at):
				color = INK
			if frame.has_point(at):
				color = GOLD
			if doorway.has_point(at):
				color = LIGHT.lerp(GOLD, clampf((at.y - 18.0) / 140.0, 0.0, 0.6))
			if Geometry2D.is_point_in_polygon(at, panel):
				color = WOOD if fmod(at.x, 9.0) > 1.5 else WOOD_DARK
			elif _near_polygon(at, panel, 5.0):
				color = INK
			if at.distance_to(Vector2(20, 72)) < 5.0:
				color = GOLD
			image.set_pixelv(Vector2i(x, y), color)
	image.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	return image


## A shape given by a distance (inside below 0), filled with [param fill]
## and outlined [param outline] wide in ink.
static func _paint(distance: Callable, fill: Color, outline: float) -> Image:
	var image := Image.create_empty(DRAWN, DRAWN, false, Image.FORMAT_RGBA8)
	for y in DRAWN:
		for x in DRAWN:
			var d: float = distance.call(Vector2(x + 0.5, y + 0.5))
			var color := Color(0, 0, 0, 0)
			if d < outline:
				color = INK
			if d < 0.0:
				color = fill
			image.set_pixel(x, y, color)
	image.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	return image


static func _capsule(at: Vector2, a: Vector2, b: Vector2) -> float:
	return at.distance_to(Geometry2D.get_closest_point_to_segment(at, a, b))


static func _near_polygon(at: Vector2, polygon: PackedVector2Array, reach: float) -> bool:
	for i in polygon.size():
		if _capsule(at, polygon[i], polygon[(i + 1) % polygon.size()]) < reach:
			return true
	return false
