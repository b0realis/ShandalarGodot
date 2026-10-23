class_name WorldMinimap
extends Control
## THE SMALL MAP IN THE CORNER (the owner, 2026-10-23: *"implement all
## items you suggest"* — "a small corner map that follows the hero, as well
## as the full map on M") [QoL]. The 1997 frame had no small map: its map
## was a screen of its own (`ShowWorldMapScreen`), which M still opens.
## This one is the land round the hero as the world screen sees it, small:
## the same diamonds, two across for one down ([method WorldView.project]),
## only the land seen, the roads, the towns and castles, the places a quest
## or a siege calls the hero to, and the hero in the middle. A click on it
## walks there, a drag moves it ([WorldHud]); N hides or shows it.

## Pixels a tile's diamond is high (twice that across).
const TILE := 6.0
const SIZE := Vector2(232, 148)
const GOLD := Color8(232, 190, 110)
const ROAD := Color8(123, 63, 7)
const TOWN := Color8(236, 222, 196)
const HERO := Color(1, 1, 1)
const SIEGE := Color8(232, 60, 40)

var world: ShandalarWorld
## The hero, in world units (32 to a tile).
var hero := Vector2.ZERO
## The places called out ([method WorldStatus.targets]): `{tile, kind,
## name}`, the kind `quest` or `siege`.
var marks: Array[Dictionary] = []
var _land: Control
var _time := 0.0


func _ready() -> void:
	custom_minimum_size = SIZE
	size = SIZE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The land is masked by the rounded glass under it, so it keeps the
	# panel's round corners; the rim is drawn over both.
	var glass := Panel.new()
	glass.name = "Glass"
	glass.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ground := StyleBoxFlat.new()
	ground.bg_color = Color(0.035, 0.026, 0.024, 0.94)
	ground.set_corner_radius_all(8)
	glass.add_theme_stylebox_override("panel", ground)
	glass.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	glass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glass)
	_land = Control.new()
	_land.name = "Land"
	_land.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_land.mouse_filter = Control.MOUSE_FILTER_STOP
	_land.draw.connect(_draw_land)
	glass.add_child(_land)
	var rim := Panel.new()
	rim.name = "Rim"
	rim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var edge := StyleBoxFlat.new()
	edge.draw_center = false
	edge.border_color = Color(GOLD, 0.35)
	edge.set_border_width_all(1)
	edge.set_corner_radius_all(8)
	rim.add_theme_stylebox_override("panel", edge)
	rim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rim)


## The part of it that takes the pointer (for the HUD's tips).
func land() -> Control:
	return _land


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	_land.queue_redraw()


## Where world point [param point] falls on it.
func project(point: Vector2) -> Vector2:
	var d := (point - hero) * (TILE / 32.0)
	return size * 0.5 + Vector2(2.0 * (d.x + d.y), d.y - d.x)


## The tile under [param at] on it.
func tile_at(at: Vector2) -> Vector2i:
	var p := (at - size * 0.5) / (TILE / 32.0)
	var point := hero + Vector2(p.x / 4.0 - p.y / 2.0, p.x / 4.0 + p.y / 2.0)
	return Vector2i(floori(point.x / 32.0), floori(point.y / 32.0))


func _draw_land() -> void:
	if world == null:
		return
	var here := Vector2i(floori(hero.x / 32.0), floori(hero.y / 32.0))
	# Wide enough for the corners: a tile is 2 · TILE across per step of
	# x + y, TILE down per step of y − x.
	var reach := int(ceil(size.x / (2.0 * TILE) + size.y / TILE)) / 2 + 2
	var box := Rect2(Vector2(-TILE * 2.0, -TILE), size + Vector2(TILE * 4.0, TILE * 2.0))
	for y in range(here.y - reach, here.y + reach + 1):
		for x in range(here.x - reach, here.x + reach + 1):
			if not world.is_explored(x, y) or not world.is_land(x, y):
				continue
			var left := project(Vector2(x * 32, y * 32))
			if not box.has_point(left):
				continue
			_land.draw_colored_polygon(PackedVector2Array([left, left + Vector2(TILE * 2.0, -TILE),
				left + Vector2(TILE * 4.0, 0), left + Vector2(TILE * 2.0, TILE)]),
				WorldView.PLAIN.get(world.terrain(x, y), WorldView.PLAIN[0]))
	for y in range(here.y - reach, here.y + reach + 1):
		for x in range(here.x - reach, here.x + reach + 1):
			var roads := world.road_bits(x, y)
			if roads == 0 or not world.is_explored(x, y):
				continue
			var middle := project(Vector2(x * 32 + 16, y * 32 + 16))
			if not box.has_point(middle):
				continue
			for d in range(1, 9):
				if roads & (1 << (d - 1)) != 0:
					var to := project(Vector2((x + ShandalarWorld.DX[d]) * 32 + 16, (y + ShandalarWorld.DY[d]) * 32 + 16))
					_land.draw_line(middle, middle.lerp(to, 0.5), ROAD, 1.0)
	for site in world.sites:
		var x := int(site["x"])
		var y := int(site["y"])
		var kind := int(site["type"])
		if kind <= 0 or not world.is_explored(x, y):
			continue
		var middle := project(Vector2(x * 32 + 16, y * 32 + 16))
		if not box.has_point(middle):
			continue
		var radius: float = [0.0, 1.6, 2.2, 2.8, 3.2, 3.2][clampi(kind, 0, 5)]
		_land.draw_circle(middle, radius + 1.0, Color(0, 0, 0, 0.85))
		_land.draw_circle(middle, radius, TOWN if kind < ShandalarWorld.CASTLE else GOLD)
	var pulse := 0.5 + 0.5 * sin(_time * 5.0)
	for mark in marks:
		var tile: Vector2i = mark["tile"]
		var at := project(Vector2(tile.x * 32 + 16, tile.y * 32 + 16))
		var ink := SIEGE if String(mark["kind"]) == "siege" else GOLD
		at = at.clamp(Vector2(6, 6), size - Vector2(6, 6))
		_land.draw_arc(at, 5.0 + pulse * 2.0, 0.0, TAU, 20, Color(ink, 0.9), 1.5, true)
	var feet := project(hero)
	_land.draw_circle(feet, 3.6, Color(0, 0, 0, 0.9))
	_land.draw_circle(feet, 2.6, HERO.lerp(GOLD, pulse * 0.5))
