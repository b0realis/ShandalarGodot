class_name Hourglass
extends Control
## AN HOURGLASS, running while the world is made (the owner, 2026-10-22:
## *"some beautiful mtg hourglass animation … so player sees something is
## calculating"*). The 1997 files hold none, so it is drawn [QoL], in the
## Embark screen's garnet and gold: two glass bulbs between gilded caps on
## turned posts, the five colours' gems set in each cap, the sand running
## from the top bulb into the bottom one, then the glass turned over to run
## again.

## Seconds for the sand to run through, and to turn the glass over.
const RUN := 2.6
const TURN := 0.6

const GOLD := Color8(228, 176, 92)
const GOLD_DARK := Color8(122, 82, 34)
const GARNET := Color8(126, 20, 16)
const GLASS := Color(0.86, 0.9, 1.0, 0.14)
const GLASS_EDGE := Color(0.93, 0.95, 1.0, 0.6)
const SAND := Color8(238, 200, 124)
const SAND_DEEP := Color8(190, 140, 66)
const GLOW := Color(0.9, 0.7, 0.36, 0.022)
## The five colours' gems, white, blue, black, red and green, as on a card's
## colour pie.
const GEMS: Array[Color] = [Color8(246, 238, 210), Color8(64, 128, 222), Color8(84, 70, 84),
	Color8(216, 54, 38), Color8(54, 152, 72)]

## Seconds the glass has run.
var time := 0.0
## How tall the glass is drawn against its box: above 1 it reaches past
## the box, above and below, without taking more room in the layout.
var reach := 1.0


func _init() -> void:
	custom_minimum_size = Vector2(64, 96)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	time += delta
	queue_redraw()


## Where the glass stands at [param seconds]: x the share of the sand run
## through (0 all above, 1 all below), y the turn (0 upright, 1 over).
static func phase(seconds: float) -> Vector2:
	var at := fmod(maxf(seconds, 0.0), RUN + TURN)
	if at < RUN:
		return Vector2(at / RUN, 0.0)
	return Vector2(1.0, (at - RUN) / TURN)


func _draw() -> void:
	var now := phase(time)
	var height := minf(size.y, size.x * 1.5) * reach
	var width := height * 0.62
	var middle := size * 0.5
	for ring in 10:
		draw_circle(middle, height * (0.22 + ring * 0.036), GLOW)
	# Turned over with an easing, about the middle; the glass is the same
	# either way up, so the next run starts upright again.
	var turn := 0.5 - 0.5 * cos(PI * now.y)
	draw_set_transform(middle, PI * turn, Vector2.ONE)
	var cap := height * 0.09
	var glass := height * 0.5 - cap
	_draw_posts(width, height, cap)
	_draw_glass(width, glass, now.x, now.y > 0.0)
	_draw_cap(-height * 0.5, width, cap)
	_draw_cap(height * 0.5 - cap, width, cap)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The glass's half-width at [param y], from -[param half] at the top to
## [param half] at the bottom: a narrow neck at 0, the bulbs widest a little
## past half way out.
func _profile(y: float, half: float, width: float) -> float:
	var u := clampf(absf(y) / half, 0.0, 1.0)
	var neck := width * 0.05
	var widest := width * 0.4
	if u <= 0.62:
		return neck + (widest - neck) * sin(u / 0.62 * PI * 0.5)
	return widest - width * 0.06 * pow((u - 0.62) / 0.38, 2.0)


func _side(from: float, to: float, half: float, width: float, sign_x: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := 14
	for i in steps + 1:
		var y := lerpf(from, to, float(i) / steps)
		points.append(Vector2(sign_x * _profile(y, half, width), y))
	return points


func _draw_glass(width: float, half: float, run: float, turning: bool) -> void:
	var outline := _side(-half, half, half, width, 1.0)
	var back := _side(half, -half, half, width, -1.0)
	outline.append_array(back)
	draw_colored_polygon(outline, GLASS)
	# The sand above: settled against the neck, its top sinking as it runs,
	# a little hollow where it drains.
	var left := 1.0 - run
	if left > 0.001:
		var top := -half * 0.86 * pow(left, 0.6)
		var neck := -half * 0.04
		var sand := _side(top, neck, half, width, 1.0)
		sand.append_array(_side(neck, top, half, width, -1.0))
		var across := _profile(top, half, width)
		var hollow := half * 0.05 * left * (0.0 if run <= 0.001 else 1.0)
		var surface := PackedVector2Array()
		for i in range(1, 8):
			var x := lerpf(-across, across, i / 8.0)
			surface.append(Vector2(x, top + hollow * (1.0 - pow(x / across, 2.0))))
		sand.append_array(surface)
		draw_colored_polygon(sand, SAND)
		draw_polyline(surface, SAND_DEEP, 1.0, true)
	# The sand below: a heap rising from the bottom; the same sand, so the
	# glass turned over shows it unchanged.
	if run > 0.001:
		var level := half - half * 0.8 * pow(run, 0.6)
		var heap := half * 0.12 * minf(run * 4.0, 1.0)
		var pile := _side(level, half, half, width, 1.0)
		pile.append_array(_side(half, level, half, width, -1.0))
		pile.append(Vector2(0.0, level - heap))
		draw_colored_polygon(pile, SAND)
		draw_polyline(PackedVector2Array([Vector2(-_profile(level, half, width), level),
			Vector2(0.0, level - heap), Vector2(_profile(level, half, width), level)]), SAND_DEEP, 1.0, true)
		# The stream, and grains falling in it, while there is sand above.
		if left > 0.001 and not turning:
			draw_line(Vector2(0.0, -half * 0.04), Vector2(0.0, level - heap), SAND, 1.6, true)
			for grain in 3:
				var fall := fposmod(time * 1.9 + grain / 3.0, 1.0)
				var at := Vector2(sin((time + grain) * 9.0) * 0.8, lerpf(0.0, level - heap, fall))
				draw_circle(at, 1.3, SAND)
	draw_polyline(_side(-half, half, half, width, 1.0), GLASS_EDGE, 1.5, true)
	draw_polyline(_side(-half, half, half, width, -1.0), GLASS_EDGE, 1.5, true)
	# A glint down the left bulbs.
	var glint := PackedVector2Array()
	for y in [-half * 0.78, -half * 0.5, -half * 0.25]:
		glint.append(Vector2(-_profile(y, half, width) * 0.62, y))
	draw_polyline(glint, Color(1, 1, 1, 0.35), 1.2, true)
	glint = PackedVector2Array()
	for y in [half * 0.3, half * 0.55, half * 0.8]:
		glint.append(Vector2(-_profile(y, half, width) * 0.62, y))
	draw_polyline(glint, Color(1, 1, 1, 0.25), 1.2, true)


func _draw_posts(width: float, height: float, cap: float) -> void:
	for side in [-1.0, 1.0]:
		var x: float = side * width * 0.42
		var post := Rect2(x - 2.0, -height * 0.5 + cap * 0.5, 4.0, height - cap)
		draw_rect(post, GOLD_DARK)
		draw_line(Vector2(x - 0.5, post.position.y), Vector2(x - 0.5, post.end.y), GOLD, 1.0)
		# A turned knob half way.
		draw_circle(Vector2(x, 0.0), 3.2, GOLD_DARK)
		draw_arc(Vector2(x, 0.0), 3.2, 0.0, TAU, 12, GOLD, 1.0, true)


func _draw_cap(top: float, width: float, thickness: float) -> void:
	var plate := Rect2(-width * 0.5, top, width, thickness)
	draw_rect(plate, GOLD_DARK)
	draw_rect(plate.grow(-1.5), GARNET)
	draw_rect(plate, GOLD, false, 1.5)
	var gem := thickness * 0.24
	for i in GEMS.size():
		var at := Vector2(-width * 0.32 + width * 0.16 * i, top + thickness * 0.5)
		draw_circle(at, gem, GEMS[i])
		draw_arc(at, gem, 0.0, TAU, 10, GOLD, 1.0, true)
