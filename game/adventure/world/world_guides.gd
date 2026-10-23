class_name WorldGuides
extends Control
## THE GUIDE ARROWS (the owner, 2026-10-23: *"implement all items you
## suggest"* — "an arrow at the screen edge pointing to the quest target or
## the town under siege") [QoL]. A place that calls the hero
## ([method WorldStatus.targets]) is ringed where it stands on the screen,
## its name under it, as 1.3 lettered the quest's destination on the world
## (`DrawWorldTileRange`); off the screen an arrow at the edge points the
## way, named. Gold for the quest, red for a siege. The options switch
## them off.

const GOLD := Color8(232, 190, 110)
const SIEGE := Color8(232, 60, 40)
const EDGE := Color8(20, 10, 8)
## How far in from the screen's edge an arrow stands, and how far from the
## side the panel holds.
const INSET := 34.0
const PANEL_ROOM := 70.0

var view: WorldView
var targets: Array[Dictionary] = []
## Where an arrow must not stand: the small map and the quest pane, on the
## screen.
var avoid: Array[Rect2] = []
## The panel's side: the arrows keep clear of it.
var bar_at_bottom := false
var _time := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if targets.is_empty() or not is_visible_in_tree():
		return
	_time += delta
	queue_redraw()


## Where tile [param tile]'s middle is on the screen.
func on_screen(tile: Vector2i) -> Vector2:
	return view.feet() + view.project(Vector2(tile.x * 32 + 16, tile.y * 32 + 16)) * view.zoom


## The rectangle the arrows stand on: the screen, in from its edges and
## clear of the panel.
func room() -> Rect2:
	var top := INSET + (0.0 if bar_at_bottom else PANEL_ROOM)
	var bottom := INSET + (PANEL_ROOM if bar_at_bottom else 0.0)
	return Rect2(INSET, top, maxf(size.x - INSET * 2.0, 1.0), maxf(size.y - top - bottom, 1.0))


## Where the arrow for [param tile] stands and the way it points, or the
## place itself (`{at, arrow: false}`) when it is on the screen.
func guide_for(tile: Vector2i) -> Dictionary:
	var at := on_screen(tile)
	var box := room()
	if box.has_point(at):
		return {"at": at, "arrow": false}
	var middle := box.get_center()
	var way := (at - middle).normalized()
	if way == Vector2.ZERO:
		way = Vector2.UP
	# Out along the way from the middle to the edge of the room.
	var reach_x := (box.size.x * 0.5) / absf(way.x) if way.x != 0.0 else INF
	var reach_y := (box.size.y * 0.5) / absf(way.y) if way.y != 0.0 else INF
	var edge := minf(reach_x, reach_y)
	# Back toward the middle, out from under a pane.
	var spot := middle + way * edge
	var step := 0
	while step < 80 and _hidden(spot):
		edge -= 6.0
		spot = middle + way * edge
		step += 1
	return {"at": spot, "arrow": true, "way": way}


func _hidden(at: Vector2) -> bool:
	for rect in avoid:
		if rect.grow(18.0).has_point(at):
			return true
	return false


func _draw() -> void:
	if view == null:
		return
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	var font := GameSkin.font("font_title")
	if font == null:
		font = get_theme_default_font()
	for target in targets:
		var ink := SIEGE if String(target["kind"]) == "siege" else GOLD
		var guide := guide_for(target["tile"])
		var at: Vector2 = guide["at"]
		var called := String(target.get("name", ""))
		var label_at := at + Vector2(0, 30)
		if guide["arrow"]:
			var way: Vector2 = guide["way"]
			var side := way.orthogonal()
			var tip := at + way * 14.0
			var points := PackedVector2Array([tip, at - way * 10.0 + side * 11.0,
				at - way * 4.0, at - way * 10.0 - side * 11.0])
			draw_colored_polygon(points, Color(ink, 0.75 + 0.25 * pulse))
			points.append(tip)
			draw_polyline(points, EDGE, 2.0, true)
			label_at = at - way * 30.0 + Vector2(0, 5)
		else:
			var radius := 26.0 * view.zoom * 0.5 + pulse * 4.0
			draw_arc(at, radius + 1.5, 0.0, TAU, 40, Color(EDGE, 0.7), 4.0, true)
			draw_arc(at, radius, 0.0, TAU, 40, ink, 2.0, true)
			label_at = at + Vector2(0, radius + 16.0)
		if called != "" and font != null:
			var width := font.get_string_size(called, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x
			var x := clampf(label_at.x - width * 0.5, 4.0, maxf(4.0, size.x - width - 4.0))
			draw_string_outline(font, Vector2(x, label_at.y), called, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, 4, EDGE)
			draw_string(font, Vector2(x, label_at.y), called, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ink)
