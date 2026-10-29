class_name WorldMinimap
extends Control
## THE SMALL MAP IN THE CORNER (the owner, 2026-10-23: *"implement all
## items you suggest"* — "a small corner map that follows the hero, as well
## as the full map on M") [QoL]. The 1997 frame had no small map: its map
## was a screen of its own (`ShowWorldMapScreen`), which M still opens.
## This one is the land round the hero as the world screen sees it, small:
## the same diamonds, two across for one down ([method WorldView.project]),
## only the land seen, the roads, the towns and castles, the dungeons the
## hero knows of (the owner's ruling A-2 of 2026-10-27: a dark mouth ringed
## in gold, on land not yet seen too — [method WorldClues.on_world]), the
## places a quest or a siege calls the hero to, and the hero in the middle.
## A click on it walks there, a drag moves it ([WorldHud]); N hides or
## shows it.
##
## TWO LAYERS, so a frame costs next to nothing: the land, its roads and
## towns ([member _ground]) are drawn round the middle of the hero's tile
## and only drawn again when the hero steps onto another tile, sees new
## land, or the world changes — between, the picture is only moved under
## the hero; the marks and the hero's dot ([member _marks]) pulse, and are
## all that is drawn each frame. (It was all drawn every frame: 1.3 to
## 2.5 ms a frame standing still, under a town's pane too.)

## Pixels a tile's diamond is high (twice that across).
const TILE := 6.0
const SIZE := Vector2(232, 148)
const GOLD := Color8(232, 190, 110)
const ROAD := Color8(123, 63, 7)
const TOWN := Color8(236, 222, 196)
const HERO := Color(1, 1, 1)
const SIEGE := Color8(232, 60, 40)
## A dungeon's mark: a dark mouth of this radius, ringed in [constant GOLD].
const DUNGEON := 2.4
const DUNGEON_MOUTH := Color8(14, 10, 12)

var world: ShandalarWorld:
	set(value):
		world = value
		if not _held:
			_follow()
## The hero, in world units (32 to a tile).
var hero := Vector2.ZERO:
	set(value):
		hero = value
		if not _held:
			_follow()
## The places called out ([method WorldStatus.targets]): `{tile, kind,
## name}`, the kind `quest` or `siege`.
var marks: Array[Dictionary] = []
## The dungeons the hero knows of ([method WorldClues.on_world]): `{index,
## x, y}`, x and y their tile; drawn with the land.
var dungeons: Array[Dictionary] = []:
	set(value):
		dungeons = value
		if not _held:
			_follow()
## What takes the pointer: the whole map, drawing nothing itself.
var _land: Control
## The land, roads and towns, drawn round [member _anchor] and moved under
## the hero.
var _ground: Node2D
## The marks and the hero's dot, drawn each frame.
var _marks: Node2D
## The world point [member _ground] was drawn round (the middle of the
## hero's tile then), and what it showed: the world, the tile, the land
## seen and the towns, the map's size.
var _anchor := Vector2.ZERO
var _drawn: Array = []
var _time := 0.0
## While [method show_hero] sets what it shows, one look for all of it.
var _held := false
## How many times it looked whether to draw the land again ([method
## _follow]; the tests).
var looks := 0


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
	glass.add_child(_land)
	_ground = Node2D.new()
	_ground.name = "Ground"
	_ground.draw.connect(_draw_ground)
	_land.add_child(_ground)
	_marks = Node2D.new()
	_marks.name = "Marks"
	_marks.draw.connect(_draw_marks)
	_land.add_child(_marks)
	resized.connect(_follow)
	_follow()
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


## THE HERO SHOWN in one go — [param shown_world], where they stand
## ([param at], world units), the places calling ([param calling]) and the
## dungeons known ([param known]) — and looked at once ([method _follow])
## rather than once for each (the smoothness pass, 0.50.66: every tick
## hashed the world's page and sites three times over).
func show_hero(shown_world: ShandalarWorld, at: Vector2, calling: Array[Dictionary],
		known: Array[Dictionary]) -> void:
	_held = true
	world = shown_world
	hero = at
	dungeons = known
	_held = false
	marks = calling
	_follow()


## The part of it that takes the pointer (for the HUD's tips).
func land() -> Control:
	return _land


## The pulse: only the marks and the hero's dot are drawn again.
func _process(delta: float) -> void:
	if not is_visible_in_tree() or _marks == null:
		return
	_time += delta
	_marks.queue_redraw()


## The land moved under the hero, and drawn again when what it shows
## changed: another tile, new land seen (the page's explored marks), a
## town taken or a castle beaten, a dungeon learned of or moved, another
## world or size.
func _follow() -> void:
	if _ground == null:
		return
	looks += 1
	var tile := Vector2i(floori(hero.x / 32.0), floori(hero.y / 32.0))
	var shown: Array = [null, tile, size]
	if world != null:
		shown = [world.get_instance_id(), tile, size, hash(world.page), world.sites.hash(), dungeons.hash()]
	if shown != _drawn:
		_drawn = shown
		_anchor = Vector2(tile * 32 + Vector2i(16, 16))
		_ground.queue_redraw()
	_ground.position = project(_anchor) - size * 0.5


## The tile the land was last drawn round.
func drawn_tile() -> Vector2i:
	return Vector2i(floori(_anchor.x / 32.0), floori(_anchor.y / 32.0))


## Where world point [param point] falls on it.
func project(point: Vector2) -> Vector2:
	var d := (point - hero) * (TILE / 32.0)
	return size * 0.5 + Vector2(2.0 * (d.x + d.y), d.y - d.x)


## The tile under [param at] on it.
func tile_at(at: Vector2) -> Vector2i:
	var p := (at - size * 0.5) / (TILE / 32.0)
	var point := hero + Vector2(p.x / 4.0 - p.y / 2.0, p.x / 4.0 + p.y / 2.0)
	return Vector2i(floori(point.x / 32.0), floori(point.y / 32.0))


## Where world point [param point] falls on the land's own picture (as
## [method project], round [member _anchor] rather than the hero).
func _on_ground(point: Vector2) -> Vector2:
	var d := (point - _anchor) * (TILE / 32.0)
	return size * 0.5 + Vector2(2.0 * (d.x + d.y), d.y - d.x)


## The land seen, its roads and its towns round [member _anchor] — wider
## than the map by what the picture slides under the hero (up to half a
## tile each way: 2 · TILE across, TILE down) and a diamond's own reach
## from its left point (4 · TILE across, TILE up and down). The bug pass
## after the campaign (r4-1) found the left margin a slide short: a black
## sawtooth along the map's left edge while walking west or north.
## [method ground_box] is the room a tile's left point may stand in.
func ground_box() -> Rect2:
	return Rect2(Vector2(-TILE * 6.0, -TILE * 2.0), size + Vector2(TILE * 10.0, TILE * 4.0))


## The land's own picture, drawn once round [member _anchor].
func _draw_ground() -> void:
	if world == null:
		return
	var here := Vector2i(floori(_anchor.x / 32.0), floori(_anchor.y / 32.0))
	# Wide enough for the corners: a tile is 2 · TILE across per step of
	# x + y, TILE down per step of y − x.
	var reach := int(ceil(size.x / (2.0 * TILE) + size.y / TILE)) / 2 + 3
	var box := ground_box()
	for y in range(here.y - reach, here.y + reach + 1):
		for x in range(here.x - reach, here.x + reach + 1):
			if not world.is_explored(x, y) or not world.is_land(x, y):
				continue
			var left := _on_ground(Vector2(x * 32, y * 32))
			if not box.has_point(left):
				continue
			_ground.draw_colored_polygon(PackedVector2Array([left, left + Vector2(TILE * 2.0, -TILE),
				left + Vector2(TILE * 4.0, 0), left + Vector2(TILE * 2.0, TILE)]),
				WorldView.PLAIN.get(world.terrain(x, y), WorldView.PLAIN[0]))
	for y in range(here.y - reach, here.y + reach + 1):
		for x in range(here.x - reach, here.x + reach + 1):
			var roads := world.road_bits(x, y)
			if roads == 0 or not world.is_explored(x, y):
				continue
			var middle := _on_ground(Vector2(x * 32 + 16, y * 32 + 16))
			if not box.has_point(middle):
				continue
			for d in range(1, 9):
				if roads & (1 << (d - 1)) != 0:
					var to := _on_ground(Vector2((x + ShandalarWorld.DX[d]) * 32 + 16, (y + ShandalarWorld.DY[d]) * 32 + 16))
					_ground.draw_line(middle, middle.lerp(to, 0.5), ROAD, 1.0)
	for site in world.sites:
		var x := int(site["x"])
		var y := int(site["y"])
		var kind := int(site["type"])
		if kind <= 0 or not world.is_explored(x, y):
			continue
		var middle := _on_ground(Vector2(x * 32 + 16, y * 32 + 16))
		if not box.has_point(middle):
			continue
		var radius: float = [0.0, 1.6, 2.2, 2.8, 3.2, 3.2][clampi(kind, 0, 5)]
		_ground.draw_circle(middle, radius + 1.0, Color(0, 0, 0, 0.85))
		_ground.draw_circle(middle, radius, TOWN if kind < ShandalarWorld.CASTLE else GOLD)
	for dungeon in dungeons:
		var mouth := _on_ground(Vector2(int(dungeon["x"]) * 32 + 16, int(dungeon["y"]) * 32 + 16))
		if box.has_point(mouth):
			_ground.draw_circle(mouth, DUNGEON + 1.2, GOLD)
			_ground.draw_circle(mouth, DUNGEON, DUNGEON_MOUTH)


## The places called out and the hero's dot, pulsing.
func _draw_marks() -> void:
	if world == null:
		return
	var pulse := 0.5 + 0.5 * sin(_time * 5.0)
	for mark in marks:
		var tile: Vector2i = mark["tile"]
		var at := project(Vector2(tile.x * 32 + 16, tile.y * 32 + 16))
		var ink := SIEGE if String(mark["kind"]) == "siege" else GOLD
		at = at.clamp(Vector2(6, 6), size - Vector2(6, 6))
		_marks.draw_arc(at, 5.0 + pulse * 2.0, 0.0, TAU, 20, Color(ink, 0.9), 1.5, true)
	var feet := project(hero)
	_marks.draw_circle(feet, 3.6, Color(0, 0, 0, 0.9))
	_marks.draw_circle(feet, 2.6, HERO.lerp(GOLD, pulse * 0.5))
