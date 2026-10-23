class_name WorldCursors
extends RefCounted
## THE WORLD SCREEN'S POINTERS (the owner, 2026-10-22: *"for walking
## normally a cursor of the mouse displays a small walking man"*; and
## 2026-10-23: *"for each unique place that can be visited design a mouse
## cursor that changes to that place when player mouses over that location
## … for the town … a little house cursor, for dungeon a skull"*). Over a
## place the hero can see and visit ([VisitPane]) the pointer is the place
## — a village's little house, a town's two houses, a city's towered gate,
## a wizard's castle, a beaten wizard's broken tower, a wizard's dome over
## a town a wizard rules, a dungeon's skull, a lair's cave mouth; elsewhere the
## walking man; over the panel and the panes a gold arrow (the owner:
## *"over panes the cursor is normal gold mouse"*), and the hand over what
## is clicked and the four arrows over a pane to drag in the same gold
## (*"system hand and move pointers have to also be in this style"*). The
## 1997 world screen
## kept Windows' own arrow (its window
## class loads `IDC_ARROW`), so these are drawn [QoL], in the Embark
## screen's gold on a dark outline: drawn large, edges smoothed, then made
## cursor-sized.

const SIZE := 32
const DRAWN := 128
const GOLD := Color8(236, 196, 116)
const INK := Color8(38, 16, 10)
const WOOD := Color8(128, 72, 32)
const WOOD_DARK := Color8(84, 44, 18)
const LIGHT := Color8(255, 226, 150)
const THATCH := Color8(196, 150, 70)
const ROOF := Color8(170, 52, 34)
const STONE := Color8(176, 170, 160)
const STONE_DARK := Color8(112, 106, 100)
const BONE := Color8(236, 226, 200)
const DOME := Color8(92, 52, 128)
const DARK := Color8(30, 18, 14)

## What a pointer shows: walking on, or the place under it.
enum Kind { WALK, VILLAGE, TOWN, CITY, CASTLE, FALLEN, RULED, DUNGEON, LAIR, ARROW, HAND, MOVE }
## The pointer for each kind of place [method VisitPane.describe] gives.
const FOR_PLACE := {"village": Kind.VILLAGE, "town": Kind.TOWN, "city": Kind.CITY,
	"castle": Kind.CASTLE, "fallen": Kind.FALLEN, "ruled": Kind.RULED,
	"dungeon": Kind.DUNGEON, "lair": Kind.LAIR}

static var _made := {}
## Whether the hand and the four arrows are worn for their shapes.
static var _shapes_on := false


## The pointer picture for [param kind], made once.
static func image(kind: Kind) -> Image:
	if not _made.has(kind):
		match kind:
			Kind.WALK:
				_made[kind] = _walker()
			Kind.VILLAGE:
				_made[kind] = _layers(_house(Vector2(64, 70), 1.0, THATCH))
			Kind.TOWN:
				_made[kind] = _layers(_house(Vector2(44, 66), 0.75, ROOF) + _house(Vector2(78, 76), 0.9, THATCH))
			Kind.CITY:
				_made[kind] = _layers(_city())
			Kind.CASTLE:
				_made[kind] = _layers(_castle(false))
			Kind.FALLEN:
				_made[kind] = _layers(_castle(true))
			Kind.RULED:
				_made[kind] = _layers(_dome())
			Kind.DUNGEON:
				_made[kind] = _layers(_skull())
			Kind.LAIR:
				_made[kind] = _layers(_cave())
			Kind.HAND:
				_made[kind] = _layers(_hand())
			Kind.MOVE:
				_made[kind] = _layers(_move())
			Kind.ARROW:
				_made[kind] = _layers([["poly", PackedVector2Array([Vector2(10, 6), Vector2(10, 104),
					Vector2(36, 80), Vector2(54, 120), Vector2(72, 112), Vector2(54, 74),
					Vector2(88, 74)]), GOLD]])
	return _made[kind]


## Where the pointer points: the walker's feet, the arrow's tip, a place's
## middle.
static func hotspot(kind: Kind) -> Vector2:
	match kind:
		Kind.WALK:
			return Vector2(15, 30)
		Kind.ARROW:
			return Vector2(2, 1)
		Kind.HAND:
			return Vector2(11, 1)
	return Vector2(16, 16)


## Wear [param kind]'s pointer — and the gold hand and four arrows for
## what is clicked and what is dragged, while the world is on show.
static func wear(kind: Kind) -> void:
	Input.set_custom_mouse_cursor(image(kind), Input.CURSOR_ARROW, hotspot(kind))
	if not _shapes_on:
		_shapes_on = true
		Input.set_custom_mouse_cursor(image(Kind.HAND), Input.CURSOR_POINTING_HAND, hotspot(Kind.HAND))
		Input.set_custom_mouse_cursor(image(Kind.MOVE), Input.CURSOR_MOVE, hotspot(Kind.MOVE))


## Back to the game's own pointer.
static func take_off() -> void:
	Input.set_custom_mouse_cursor(null, Input.CURSOR_ARROW)
	if _shapes_on:
		_shapes_on = false
		Input.set_custom_mouse_cursor(null, Input.CURSOR_POINTING_HAND)
		Input.set_custom_mouse_cursor(null, Input.CURSOR_MOVE)


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


## A house: walls, a door, a window and a roof of [param roof], [param
## scale] times the village's, its walls' foot at [param foot].
static func _house(foot: Vector2, scale: float, roof: Color) -> Array:
	var w := 64.0 * scale
	var h := 40.0 * scale
	var left := foot.x - w * 0.5
	var top := foot.y - h
	return [
		["rect", Rect2(left, top, w, h), WOOD],
		["poly", PackedVector2Array([Vector2(left - 10 * scale, top + 2), Vector2(foot.x, top - 38 * scale),
			Vector2(left + w + 10 * scale, top + 2)]), roof],
		["rect", Rect2(foot.x - 8 * scale, foot.y - 24 * scale, 16 * scale, 24 * scale), WOOD_DARK],
		["rect", Rect2(left + 8 * scale, top + 10 * scale, 12 * scale, 10 * scale), LIGHT],
	]


## A city's towered gate and its spire.
static func _city() -> Array:
	return [
		["rect", Rect2(10, 70, 108, 50), STONE],
		["rect", Rect2(10, 60, 14, 12), STONE], ["rect", Rect2(36, 60, 14, 12), STONE],
		["rect", Rect2(78, 60, 14, 12), STONE], ["rect", Rect2(104, 60, 14, 12), STONE],
		["rect", Rect2(48, 34, 32, 86), STONE],
		["poly", PackedVector2Array([Vector2(42, 38), Vector2(64, 2), Vector2(86, 38)]), GOLD],
		["poly", PackedVector2Array([Vector2(52, 120), Vector2(52, 96), Vector2(64, 86),
			Vector2(76, 96), Vector2(76, 120)]), DARK],
	]


## A wizard's castle — or, [param fallen], a beaten one's broken tower.
static func _castle(fallen: bool) -> Array:
	if fallen:
		return [
			["poly", PackedVector2Array([Vector2(30, 122), Vector2(30, 44), Vector2(44, 52), Vector2(54, 34),
				Vector2(66, 50), Vector2(80, 40), Vector2(98, 60), Vector2(98, 122)]), STONE_DARK],
			["poly", PackedVector2Array([Vector2(54, 122), Vector2(54, 98), Vector2(64, 88),
				Vector2(74, 98), Vector2(74, 122)]), DARK],
			["circle", [Vector2(16, 116), 8.0], STONE_DARK], ["circle", [Vector2(112, 114), 10.0], STONE_DARK],
		]
	return [
		["rect", Rect2(28, 48, 72, 74), STONE],
		["rect", Rect2(28, 34, 14, 16), STONE], ["rect", Rect2(57, 34, 14, 16), STONE],
		["rect", Rect2(86, 34, 14, 16), STONE],
		["rect", Rect2(62, 6, 4, 30), INK],
		["poly", PackedVector2Array([Vector2(66, 6), Vector2(92, 13), Vector2(66, 20)]), ROOF],
		["poly", PackedVector2Array([Vector2(52, 122), Vector2(52, 96), Vector2(64, 84),
			Vector2(76, 96), Vector2(76, 122)]), DARK],
		["rect", Rect2(38, 62, 10, 14), DARK], ["rect", Rect2(80, 62, 10, 14), DARK],
	]


## A wizard's dome over a town a wizard rules.
static func _dome() -> Array:
	return [
		["rect", Rect2(22, 84, 84, 38), STONE_DARK],
		["circle", [Vector2(64, 86), 40.0], DOME],
		["rect", Rect2(22, 86, 84, 36), STONE_DARK],
		["poly", PackedVector2Array([Vector2(58, 48), Vector2(64, 10), Vector2(70, 48)]), GOLD],
		["circle", [Vector2(64, 70), 9.0], GOLD],
		["circle", [Vector2(64, 70), 4.0], DARK],
	]


## A dungeon's skull.
static func _skull() -> Array:
	return [
		["circle", [Vector2(64, 54), 42.0], BONE],
		["rect", Rect2(40, 74, 48, 40), BONE],
		["circle", [Vector2(47, 58), 11.0], DARK], ["circle", [Vector2(81, 58), 11.0], DARK],
		["poly", PackedVector2Array([Vector2(64, 70), Vector2(57, 86), Vector2(71, 86)]), DARK],
		["rect", Rect2(48, 98, 4, 16), DARK], ["rect", Rect2(58, 98, 4, 16), DARK],
		["rect", Rect2(68, 98, 4, 16), DARK], ["rect", Rect2(78, 98, 4, 16), DARK],
	]


## A hand, its forefinger pointing up at the left, the thumb beside it
## and three fingers folded at the right.
static func _hand() -> Array:
	return [
		["rect", Rect2(36, 12, 18, 62), GOLD], ["circle", [Vector2(45, 12), 9.0], GOLD],
		["rect", Rect2(34, 58, 68, 46), GOLD], ["circle", [Vector2(68, 102), 30.0], GOLD],
		["circle", [Vector2(62, 60), 9.0], GOLD], ["circle", [Vector2(79, 62), 9.0], GOLD],
		["circle", [Vector2(94, 66), 8.0], GOLD],
		["poly", PackedVector2Array([Vector2(36, 72), Vector2(14, 58), Vector2(6, 68),
			Vector2(34, 102)]), GOLD],
		["rect", Rect2(70, 56, 2, 16), INK], ["rect", Rect2(87, 58, 2, 16), INK],
	]


## The four arrows of a pane to drag.
static func _move() -> Array:
	return [
		["rect", Rect2(58, 26, 12, 76), GOLD], ["rect", Rect2(26, 58, 76, 12), GOLD],
		["poly", PackedVector2Array([Vector2(64, 4), Vector2(84, 30), Vector2(44, 30)]), GOLD],
		["poly", PackedVector2Array([Vector2(64, 124), Vector2(84, 98), Vector2(44, 98)]), GOLD],
		["poly", PackedVector2Array([Vector2(4, 64), Vector2(30, 44), Vector2(30, 84)]), GOLD],
		["poly", PackedVector2Array([Vector2(124, 64), Vector2(98, 44), Vector2(98, 84)]), GOLD],
	]


## A lair's cave mouth, eyes in the dark.
static func _cave() -> Array:
	return [
		["poly", PackedVector2Array([Vector2(6, 120), Vector2(22, 60), Vector2(48, 30), Vector2(82, 24),
			Vector2(108, 48), Vector2(122, 120)]), STONE_DARK],
		["poly", PackedVector2Array([Vector2(36, 120), Vector2(40, 84), Vector2(64, 60),
			Vector2(88, 84), Vector2(92, 120)]), DARK],
		["circle", [Vector2(56, 92), 5.0], LIGHT], ["circle", [Vector2(72, 92), 5.0], LIGHT],
	]


## Shapes laid one over another — `[kind, what, colour]`, the kind
## `rect` (a Rect2), `circle` (`[centre, radius]`) or `poly` — the later
## over the earlier, all outlined together in ink.
static func _layers(parts: Array) -> Image:
	var image := Image.create_empty(DRAWN, DRAWN, false, Image.FORMAT_RGBA8)
	for y in DRAWN:
		for x in DRAWN:
			var at := Vector2(x + 0.5, y + 0.5)
			var color := Color(0, 0, 0, 0)
			var outline := false
			for part in parts:
				var d := _distance(part, at)
				if d < 0.0:
					color = part[2]
				elif d < 5.0:
					outline = true
			if color.a == 0.0 and outline:
				color = INK
			image.set_pixel(x, y, color)
	image.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
	return image


## How far [param at] lies outside [param part] (below 0 inside).
static func _distance(part: Array, at: Vector2) -> float:
	match String(part[0]):
		"rect":
			var box: Rect2 = part[1]
			if box.has_point(at):
				return -1.0
			return at.distance_to(at.clamp(box.position, box.end))
		"circle":
			return at.distance_to(part[1][0]) - float(part[1][1])
		_:
			var points: PackedVector2Array = part[1]
			if Geometry2D.is_point_in_polygon(at, points):
				return -1.0
			var near := INF
			for i in points.size():
				near = minf(near, _capsule(at, points[i], points[(i + 1) % points.size()]))
			return near


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
