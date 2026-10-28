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
## a town a wizard rules, a dungeon's skull, a lair's cave mouth,
## Arzakon's horned portal round its violet void and, after the win, the
## same arch in grey stone, sealed (part C [ours]: no 1997 picture of it
## was ever made); elsewhere
## the walking man; over the panel and the panes a gold arrow (the owner:
## *"over panes the cursor is normal gold mouse"*), and the hand over what
## is clicked and the four arrows over a pane to drag in the same gold
## (*"system hand and move pointers have to also be in this style"*). The
## 1997 world screen kept Windows' own arrow (its window class loads
## `IDC_ARROW`), so these are drawn [QoL], in the Embark screen's gold on a
## dark outline: drawn large, edges smoothed, then made cursor-sized.
##
## HOW THEY ARE PAINTED. Each pointer is a few shapes ([method shapes]),
## laid at four times the size and outlined together in ink: a pixel takes
## the colour of the last shape it lies in, else ink within the outline's
## width of any shape, else nothing. The first painter asked that of every
## pixel and every shape one by one (16,384 pixels a pointer: 20 to 70 ms
## each, half a second for the twelve, all on the first pointer worn); now
## each shape is painted a row at a time ([method _paint_rows]) — the run
## of a row it covers worked out from the shape and its two ends checked
## pixel by pixel against the same distances — so the pictures are the
## same to the pixel at a fraction of the cost.

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
## Arzakon's portal (part C): its dark slate, its violet void and the void's
## pale heart — the colours of `game/art/world_portal_open.png`.
const SLATE := Color8(64, 56, 82)
const VOID := Color8(124, 64, 200)
const VOID_HEART := Color8(220, 196, 255)

## What a pointer shows: walking on, or the place under it.
enum Kind { WALK, VILLAGE, TOWN, CITY, CASTLE, FALLEN, RULED, DUNGEON, LAIR, ARROW, HAND, MOVE, PORTAL,
	MONUMENT }
## The pointer for each kind of place [method VisitPane.describe] gives —
## and Arzakon's portal, open or petrified ([method AdventureFinale.place_at]).
const FOR_PLACE := {"village": Kind.VILLAGE, "town": Kind.TOWN, "city": Kind.CITY,
	"castle": Kind.CASTLE, "fallen": Kind.FALLEN, "ruled": Kind.RULED,
	"dungeon": Kind.DUNGEON, "lair": Kind.LAIR, "portal": Kind.PORTAL, "monument": Kind.MONUMENT}

static var _made := {}
## Whether the hand and the four arrows are worn for their shapes.
static var _shapes_on := false


## The pointer picture for [param kind], made once: its drawing made
## pointer-sized, edges smoothed.
static func image(kind: Kind) -> Image:
	if not _made.has(kind):
		var picture := drawing(kind)
		picture.resize(SIZE, SIZE, Image.INTERPOLATE_LANCZOS)
		_made[kind] = picture
	return _made[kind]


## [param kind]'s pointer drawn large ([constant DRAWN] pixels across),
## before it is made pointer-sized.
static func drawing(kind: Kind) -> Image:
	return _layers(shapes(kind), outline(kind))


## THE SHAPES of [param kind]'s pointer, the later over the earlier —
## `[kind, what, colour]`, the kind `rect` (a Rect2), `circle` (`[centre,
## radius]`), `capsule` (`[from, to, radius]`: a stroke with round ends)
## or `poly` (its points) — on the 128-pixel drawing.
static func shapes(kind: Kind) -> Array:
	match kind:
		Kind.WALK:
			return _walker()
		Kind.VILLAGE:
			return _house(Vector2(64, 70), 1.0, THATCH)
		Kind.TOWN:
			return _house(Vector2(44, 66), 0.75, ROOF) + _house(Vector2(78, 76), 0.9, THATCH)
		Kind.CITY:
			return _city()
		Kind.CASTLE:
			return _castle(false)
		Kind.FALLEN:
			return _castle(true)
		Kind.RULED:
			return _dome()
		Kind.DUNGEON:
			return _skull()
		Kind.LAIR:
			return _cave()
		Kind.PORTAL:
			return _portal(false)
		Kind.MONUMENT:
			return _portal(true)
		Kind.HAND:
			return _hand()
		Kind.MOVE:
			return _move()
		Kind.ARROW:
			return [["poly", PackedVector2Array([Vector2(10, 6), Vector2(10, 104),
				Vector2(36, 80), Vector2(54, 120), Vector2(72, 112), Vector2(54, 74),
				Vector2(88, 74)]), GOLD]]
	return []


## How wide the ink round [param kind]'s shapes is, in drawing pixels: the
## walker's a little wider, his limbs being thin.
static func outline(kind: Kind) -> float:
	return 6.0 if kind == Kind.WALK else 5.0


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

## A small walking man in mid-stride, facing right: a head and seven
## strokes of their widths.
static func _walker() -> Array:
	var limbs: Array = [
		[Vector2(64, 40), Vector2(58, 76), 10.0],     # the body
		[Vector2(58, 76), Vector2(46, 98), 8.0],      # the back thigh
		[Vector2(46, 98), Vector2(36, 118), 7.0],     # the back shin
		[Vector2(58, 76), Vector2(74, 96), 8.0],      # the front thigh
		[Vector2(74, 96), Vector2(88, 114), 7.0],     # the front shin
		[Vector2(64, 46), Vector2(48, 64), 6.0],      # the back arm
		[Vector2(64, 46), Vector2(82, 60), 6.0],      # the front arm
	]
	var parts: Array = [["circle", [Vector2(70, 24), 13.0], GOLD]]
	for limb in limbs:
		parts.append(["capsule", limb, GOLD])
	return parts


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


## Arzakon's portal [ours]: a horned arch on a plinth round a violet void
## with a pale heart — or, [param stone], the monument it became after the
## win: the arch in grey stone, the right horn broken, the void sealed by a
## carved plug.
static func _portal(stone: bool) -> Array:
	var body := STONE if stone else SLATE
	var right_tip := Vector2(100, 22) if stone else Vector2(112, 6)
	return [
		["rect", Rect2(18, 108, 92, 16), STONE_DARK],
		["rect", Rect2(32, 52, 64, 58), body],
		["circle", [Vector2(64, 52), 32.0], body],
		["poly", PackedVector2Array([Vector2(40, 34), Vector2(16, 6), Vector2(52, 26)]), body],
		["poly", PackedVector2Array([Vector2(88, 34), right_tip, Vector2(76, 26)]), body],
		["rect", Rect2(46, 56, 36, 52), STONE_DARK if stone else VOID],
		["circle", [Vector2(64, 56), 18.0], STONE_DARK if stone else VOID],
		["circle", [Vector2(64, 76), 9.0], STONE if stone else VOID_HEART],
		["circle", [Vector2(64, 76), 4.0], STONE_DARK if stone else Color.WHITE],
	]


## Shapes laid one over another — the later over the earlier, all
## outlined together in ink [param ink_width] wide. Ink goes first on every
## pixel near any shape, then each shape's own colour over it in turn: the
## same picture as asking each pixel which shape it lies in last, else
## whether it lies near one.
static func _layers(parts: Array, ink_width: float) -> Image:
	var image := Image.create_empty(DRAWN, DRAWN, false, Image.FORMAT_RGBA8)
	for part in parts:
		_paint_rows(image, part, ink_width, INK)
	for part in parts:
		_paint_rows(image, part, 0.0, part[2])
	return image


## Paint [param color] on every pixel whose middle lies less than [param
## within] from [param part] (inside it when 0). An outline's ink is its
## inside and a stroke along each of its sides, each painted on its own —
## together the pixels near the outline, each piece quick to ask.
static func _paint_rows(image: Image, part: Array, within: float, color: Color) -> void:
	_paint_runs(image, part, 0.0 if String(part[0]) == "poly" else within, color)
	if String(part[0]) == "poly" and within > 0.0:
		var points: PackedVector2Array = part[1]
		for i in points.size():
			_paint_runs(image, ["capsule", [points[i], points[(i + 1) % points.size()], 0.0]], within, color)


## Paint one shape's rows: the runs its geometry gives for each row
## ([method _row_runs]) with their two ends settled pixel by pixel
## ([method _settled]) by [method _distance] — the one rule the picture is
## held to.
static func _paint_runs(image: Image, part: Array, within: float, color: Color) -> void:
	var rows := _row_range(part, within)
	for y in range(maxi(rows.x, 0), mini(rows.y, DRAWN - 1) + 1):
		var runs := _row_runs(part, y + 0.5, within)
		for i in range(0, runs.size(), 2):
			var run := _settled(part, y, within, runs[i], runs[i + 1])
			if run.x <= run.y:
				image.fill_rect(Rect2i(run.x, y, run.y - run.x + 1, 1), color)


## Whether pixel ([param x], [param y])'s middle lies less than [param
## within] from [param part] (inside it when 0) — for an outline's inside,
## the point-in-polygon test alone, as [method _distance] begins.
static func _covers(part: Array, x: int, y: int, within: float) -> bool:
	var at := Vector2(x + 0.5, y + 0.5)
	if within <= 0.0 and String(part[0]) == "poly":
		return Geometry2D.is_point_in_polygon(at, part[1])
	return _distance(part, at) < within


## The first and last pixel of a row's run, from the run the geometry gives
## (between [param from] and [param to], pixel middles strictly inside):
## each end moved a pixel at a time until [method _covers] agrees, so a
## rounding in the geometry never changes a pixel. Empty when x > y.
static func _settled(part: Array, y: int, within: float, from: float, to: float) -> Vector2i:
	var first := clampi(ceili(from - 0.5), 0, DRAWN - 1)
	var last := clampi(ceili(to - 0.5) - 1, 0, DRAWN - 1)
	if first > last:
		# A row the shape barely touches: its one pixel, if any.
		first = clampi(floori((from + to) * 0.5), 0, DRAWN - 1)
		last = first
	if _covers(part, first, y, within):
		while first > 0 and _covers(part, first - 1, y, within):
			first -= 1
	else:
		while first <= last and not _covers(part, first, y, within):
			first += 1
		if first > last:
			return Vector2i(1, 0)
	if _covers(part, last, y, within):
		while last < DRAWN - 1 and _covers(part, last + 1, y, within):
			last += 1
	else:
		while last > first and not _covers(part, last, y, within):
			last -= 1
	return Vector2i(first, last)


## The rows [param part] can reach within [param within], first and last
## (unclamped).
static func _row_range(part: Array, within: float) -> Vector2i:
	var top := 0.0
	var bottom := 0.0
	match String(part[0]):
		"rect":
			var box: Rect2 = part[1]
			top = box.position.y
			bottom = box.end.y
		"circle":
			top = part[1][0].y - part[1][1]
			bottom = part[1][0].y + part[1][1]
		"capsule":
			top = minf(part[1][0].y, part[1][1].y) - part[1][2]
			bottom = maxf(part[1][0].y, part[1][1].y) + part[1][2]
		_:
			var points: PackedVector2Array = part[1]
			top = INF
			bottom = -INF
			for point in points:
				top = minf(top, point.y)
				bottom = maxf(bottom, point.y)
	return Vector2i(floori(top - within) - 1, ceili(bottom + within) + 1)


## The runs of the row whose middles stand at height [param middle] that lie
## less than [param within] from [param part] (inside it when 0; an
## outline's inside only), by the shape's geometry: from, to, from, to …
## (each run whole).
static func _row_runs(part: Array, middle: float, within: float) -> PackedFloat64Array:
	match String(part[0]):
		"rect":
			var box: Rect2 = part[1]
			if within <= 0.0:
				if middle < box.position.y or middle >= box.end.y:
					return PackedFloat64Array()
				return PackedFloat64Array([box.position.x, box.end.x])
			var gap := maxf(maxf(box.position.y - middle, middle - box.end.y), 0.0)
			return _widened(box.position.x, box.end.x, gap, within)
		"circle":
			var centre: Vector2 = part[1][0]
			return _widened(centre.x, centre.x, absf(middle - centre.y), float(part[1][1]) + within)
		"capsule":
			return _stroke(part[1][0], part[1][1], middle, float(part[1][2]) + within)
		_:
			# An outline's inside ([method _paint_rows] strokes its sides).
			return _crossings(part[1], middle)


## The run [param left] … [param right] widened by what of [param reach] is
## left at [param gap] above or below it (none when the gap is as wide).
static func _widened(left: float, right: float, gap: float, reach: float) -> PackedFloat64Array:
	if gap >= reach:
		return PackedFloat64Array()
	var side := sqrt(reach * reach - gap * gap)
	return PackedFloat64Array([left - side, right + side])


## The run of a row (at [param middle]) within [param reach] of the stroke
## from [param a] to [param b]: its two round ends and the band between, one
## run as the stroke is convex.
static func _stroke(a: Vector2, b: Vector2, middle: float, reach: float) -> PackedFloat64Array:
	var runs := _widened(a.x, a.x, absf(middle - a.y), reach)
	runs.append_array(_widened(b.x, b.x, absf(middle - b.y), reach))
	var along := b - a
	var length := along.length()
	if length > 0.0:
		# The band beside the stroke: a point p of the row with
		# 0 ≤ (p − a)·u ≤ length and |(p − a)·n| < reach — each a limit on
		# x − a.x, the row's height already in the offset.
		var u := along / length
		var n := Vector2(-u.y, u.x)
		var band := Vector2(-INF, INF)
		band = _limit(band, u.x, (middle - a.y) * u.y, 0.0, length)
		band = _limit(band, n.x, (middle - a.y) * n.y, -reach, reach)
		if band.x < band.y:
			runs.append_array(PackedFloat64Array([a.x + band.x, a.x + band.y]))
	if runs.is_empty():
		return runs
	var from := INF
	var to := -INF
	for i in range(0, runs.size(), 2):
		from = minf(from, runs[i])
		to = maxf(to, runs[i + 1])
	return PackedFloat64Array([from, to])


## [param band] (a run of x) narrowed to where [param low] ≤ [param
## slope] · x + [param offset] ≤ [param high]; empty (from past to) when
## nowhere.
static func _limit(band: Vector2, slope: float, offset: float, low: float, high: float) -> Vector2:
	if absf(slope) < 1e-9:
		return band if offset >= low and offset <= high else Vector2(INF, -INF)
	var one := (low - offset) / slope
	var two := (high - offset) / slope
	return Vector2(maxf(band.x, minf(one, two)), minf(band.y, maxf(one, two)))


## Where the row at [param middle] crosses the outline of [param points],
## paired into the runs inside (even and odd).
static func _crossings(points: PackedVector2Array, middle: float) -> PackedFloat64Array:
	var xs := PackedFloat64Array()
	for i in points.size():
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		if (a.y <= middle) != (b.y <= middle):
			xs.append(a.x + (middle - a.y) * (b.x - a.x) / (b.y - a.y))
	xs.sort()
	if xs.size() % 2 != 0:
		xs.resize(xs.size() - 1)
	return xs


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
		"capsule":
			return _capsule(at, part[1][0], part[1][1]) - float(part[1][2])
		_:
			var points: PackedVector2Array = part[1]
			if Geometry2D.is_point_in_polygon(at, points):
				return -1.0
			var near := INF
			for i in points.size():
				near = minf(near, _capsule(at, points[i], points[(i + 1) % points.size()]))
			return near


static func _capsule(at: Vector2, a: Vector2, b: Vector2) -> float:
	return at.distance_to(Geometry2D.get_closest_point_to_segment(at, a, b))
