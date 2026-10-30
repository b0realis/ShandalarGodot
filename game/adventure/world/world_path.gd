class_name WorldPath
extends Control
## THE PATH ARROWS (0.50.66; the owner, 2026-10-29: *"for mouse and click
## and pathfinding lets implement a visual pathfinding arrows as in the
## supplied reference photo from HOMM 3 (range coloured) - with visual
## pathfinding on/off setting!"*; the look picked from the mock-ups: *"Homm
## arrows, just a bit smaller and orange"*, the hungry steps red) [ours:
## 1997 drew no way — a click walked one of eight ways from the hero]. A
## click's way ([member HeroWalk.path]) is drawn on the land: an arrow on
## every tile still to walk to, pointing to the next — BENT on a tile where
## the way turns, its shaft coming in the old way and its head pointing the
## new — and an X on the last. Orange the tiles the hero reaches with food
## left, red those walked hungry, and slower ([method HeroWalk.forecast]:
## the walk's own ticks run ahead). Each mark is bevelled — a light edge up
## and left, a darker one below — on a dark outline over a grey shadow, so
## it reads on every land.
##
## THE HOVER PREVIEW: the hero standing, the pointer resting [constant
## REST_MS] ms on a tile shows the way there at half strength ([constant
## PREVIEW]); a click still walks at once, as 1997's did.
##
## HIDDEN IN THE DARK (the owner's ruling of 2026-10-29, "Hide in the
## dark"): a mark — the arrows and the X alike — is drawn only on land the
## hero has explored; the way through the dark is walked but not drawn, and
## each of its tiles takes its mark as the walk lights it ([method drawn]).
## Nothing shows while no tile of the way is lit.
##
## Only a click's walk: the keys' walk ([member HeroWalk.by_keys]) finds no
## way, and nothing is drawn for it. Nothing either while the world waits —
## a pane, the map, a news flash, a castle's or a dungeon's board, a town
## stepped aside ([method WorldScreen._world_waits]) — nor with the
## options' Path arrows off ([constant WorldHud.PATHS_SETTING]).
##
## KEPT CHEAP: the marks are one picture ([member _marks]) laid round a world
## point ([member _anchor]) in the view's pixels at zoom one, moved and
## scaled with the view each frame ([method frame]) as the view's own
## pictures are; drawn again only when the way, the tile the hero stands on
## or the food foreseen changes. Each mark's shape is made once for its
## pair of ways — the 8 × 8 of them, and the X — and kept ([method shape]).
## The dark tiles of the way are looked at again only as the clock ticks, the
## hero enters another tile or the world waited ([method _light]).

## Fill, light edge, dark edge: where the food covers the step, and where
## the hero walks it hungry.
const FED: Array[Color] = [Color("#e8892a"), Color("#ffc47e"), Color("#8c4a0f")]
const HUNGRY: Array[Color] = [Color("#c0392b"), Color("#f0998a"), Color("#5c1510")]
const INK := Color(0.06, 0.045, 0.035, 0.85)
const SHADOW := Color(0.08, 0.08, 0.09, 0.4)
## The shadow's offset, down and to the left (the view's pixels at zoom one).
const SHADOW_AT := Vector2(-3.8, 4.7)
## The marks' size against the first mock-ups' (the owner: "a bit smaller").
const SIZE := 0.75
## The hover preview's strength, and how long the pointer rests first.
const PREVIEW := 0.5
const REST_MS := 150

var view: WorldView
## The hero's walk ([member WorldScreen.walk]).
var walk: HeroWalk
## The options' switch ([method WorldHud.path_arrows_wanted]).
var wanted := true
## How many times the marks were drawn anew ([method _redraw]).
var redraws := 0

var _marks: Node2D
## The hover preview's marks are drawn through it, as one, at [constant
## PREVIEW]; a click's are not.
var _group: CanvasGroup
## The way drawn — its tiles, the next first — and the food foreseen for
## each (1 fed, 0 hungry); the first tile drawn (not the one the hero stands
## on); whether it is the hover preview.
var _way: Array[Vector2i] = []
var _fed := PackedByteArray()
var _from := 0
var _preview := false
## The world point the marks are laid round.
var _anchor := Vector2i.ZERO
## What the way was read with: the walk's way count ([member
## HeroWalk.plans]), the hero's tile, food, Quickening and World Magics.
var _plans := -1
var _tile := Vector2i(-1, -1)
var _food := -1
var _quickening := 0
var _magics := -1
## Which tiles of the way are lit (explored: 1), and the clock's tick they
## were looked at in; whether the world waited since (a pane may have shown
## land: a quest's place, a creature's lair).
var _lit := PackedByteArray()
var _lit_tick := -1
var _waited := false
## The tile under the pointer ((-1, -1): none) and since when (ms); the
## tile last looked at for a preview, and from where.
var _hover := Vector2i(-1, -1)
var _hover_since := 0
var _previewed := Vector2i(-1, -1)
var _previewed_from := Vector2i(-1, -1)

## Every mark's layers by its pair of ways ([method shape]).
static var _shapes: Array = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_group = CanvasGroup.new()
	_group.name = "Preview"
	_group.self_modulate = Color(1, 1, 1, PREVIEW)
	_group.visible = false
	add_child(_group)
	_marks = Node2D.new()
	_marks.name = "Marks"
	_marks.visible = false
	_marks.draw.connect(_paint)
	add_child(_marks)


## THE FRAME (the world screen's, after the view's glide and its looking
## round): the marks follow the walk or the pointer, moved and scaled with
## the view. [param held]: the world waits — nothing shows.
func frame(held: bool) -> void:
	if held or not wanted or walk == null or walk.player == null or view == null or not view.visible:
		if held:
			# A pane closed over a still pointer: it rests anew first.
			_hover_since = Time.get_ticks_msec()
			_waited = true
		_show(false)
		return
	var player := walk.player
	if walk.is_walking():
		if walk.by_keys:
			_show(false)
			return
		_follow_walk(player)
	else:
		_follow_hover(player)
	if _from >= _way.size() or not _any_lit():
		_show(false)
		return
	_show(true)
	var at := view.drawn_at(Vector2(_anchor))
	if _marks.position != at:
		_marks.position = at
	if _marks.scale.x != view.zoom:
		_marks.scale = Vector2(view.zoom, view.zoom)


## The pointer over world tile [param tile] — (-1, -1) off the world, or
## while a drag looks round: the hover preview's rest begins again.
func hover(tile: Vector2i) -> void:
	if tile == _hover:
		return
	_hover = tile
	_hover_since = Time.get_ticks_msec()


## Whether marks show now, and whether they are the hover preview.
func shown() -> bool:
	return _marks.visible


func previewing() -> bool:
	return _marks.visible and _preview


## The tiles marked now, the next first, and the food foreseen for each
## (true: fed) — the way still to walk, its dark tiles too ([method drawn]
## says which are drawn).
func marked() -> Array[Vector2i]:
	return _way.slice(_from) if _marks.visible else [] as Array[Vector2i]


## The tiles whose mark is drawn now: [method marked]'s on explored land.
func drawn() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if _marks.visible:
		for i in range(_from, _way.size()):
			if i < _lit.size() and _lit[i] == 1:
				out.append(_way[i])
	return out


func fed() -> Array[bool]:
	var out: Array[bool] = []
	if _marks.visible:
		for i in range(_from, _fed.size()):
			out.append(_fed[i] == 1)
	return out


## A click's walk: taken anew when the way is new, its reached tiles dropped
## from the front as the hero reaches them.
func _follow_walk(player: AdventurePlayer) -> void:
	if _preview or walk.plans != _plans:
		_take(walk.path, false)
		return
	var reached := _way.size() - walk.path.size()
	if reached > 0:
		# The middles reached leave the way; what is drawn stays as it was
		# (they were the tiles stood on, unmarked).
		_way = _way.slice(reached)
		_fed = _fed.slice(reached)
		_lit = _lit.slice(reached)
		_from = maxi(_from - reached, 0)
	_refresh(player)


## The hero standing: the way to the tile the pointer rests on, once it has
## rested [constant REST_MS] ms.
func _follow_hover(player: AdventurePlayer) -> void:
	var tile := player.tile()
	if not _preview and not _way.is_empty():
		# A click's way its walk left behind (0.50.66 bug campaign, h2-3): a
		# walk stopped on its first tile — Space, an arrow into the sea, a
		# meeting there — left its arrows at full strength, the pointer
		# still on the tile previewed. Given up; the preview looked for anew.
		_clear()
		_previewed = Vector2i(-1, -1)
	if _hover.x < 0 or _hover == tile:
		_clear()
		return
	if _hover != _previewed or tile != _previewed_from:
		if Time.get_ticks_msec() - _hover_since < REST_MS:
			_clear()
			return
		_previewed = _hover
		_previewed_from = tile
		var tiles := walk.plan(_hover)
		if tiles.size() < 2:
			_clear()
			return
		_take(tiles, true)
		return
	if _preview:
		_refresh(player)


## THE WAY TAKEN UP: [param tiles] (the next first), the food foreseen for
## each, drawn plain ([param preview] false) or as the hover preview.
func _take(tiles: Array[Vector2i], preview: bool) -> void:
	var player := walk.player
	_way = tiles.duplicate()
	_preview = preview
	_plans = walk.plans
	_food = player.food
	_quickening = player.quickening
	_magics = player.world_magics.size()
	_fed = walk.forecast(_way)
	_tile = player.tile()
	_from = 1 if not _way.is_empty() and _way[0] == _tile else 0
	_light(true)
	if not _way.is_empty():
		_anchor = _way[0] * 32 + Vector2i(16, 16)
	var parent: Node = _group if preview else self
	if _marks.get_parent() != parent:
		_marks.reparent(parent, false)
	_redraw()


## Foreseen again when the food changed (a meal, food bought), Quickening
## was cast or a World Magic came; drawn again when also the hero entered
## another tile (the one stood on is not marked).
func _refresh(player: AdventurePlayer) -> void:
	var foresee := player.food != _food or player.quickening > _quickening \
		or player.world_magics.size() != _magics
	_quickening = player.quickening
	if foresee:
		_food = player.food
		_magics = player.world_magics.size()
		_fed = walk.forecast(_way)
	var tile := player.tile()
	var lit := _light(tile != _tile)
	if foresee or tile != _tile or lit:
		_tile = tile
		_from = 1 if not _way.is_empty() and _way[0] == tile else 0
		_redraw()


## THE WAY'S TILES LIT (explored) looked at — at once when [param now], else
## only when the clock has ticked since or the world waited (land is only
## explored by a tick's step or under a pane) — and true when a tile came
## out of the dark. With the view's dark off every tile is lit.
func _light(now: bool) -> bool:
	var player := walk.player if walk != null else null
	var tick := player.monster_timer if player != null else -1
	if not now and not _waited and tick == _lit_tick and _lit.size() == _way.size():
		return false
	_lit_tick = tick
	_waited = false
	var world := view.world if view != null else null
	var dark := view != null and view.fog and world != null
	var before := _lit
	_lit = PackedByteArray()
	_lit.resize(_way.size())
	for i in _way.size():
		_lit[i] = 1 if not dark or world.is_explored(_way[i].x, _way[i].y) else 0
	return _lit != before


## Whether any tile still to walk to is lit.
func _any_lit() -> bool:
	for i in range(_from, mini(_way.size(), _lit.size())):
		if _lit[i] == 1:
			return true
	return false


func _clear() -> void:
	if not _way.is_empty():
		_way.clear()
		_fed.clear()
		_lit.clear()
	_from = 0
	_preview = false
	_plans = -1
	_show(false)


func _show(on: bool) -> void:
	if _marks.visible != on:
		_marks.visible = on
	var group := on and _preview
	if _group.visible != group:
		_group.visible = group


func _redraw() -> void:
	redraws += 1
	_marks.queue_redraw()


## THE MARKS, in the view's pixels at zoom one round [member _anchor]:
## each lit tile's shadow, outline, dark edge, light edge and fill — none on
## a tile still dark ([member _lit]).
func _paint() -> void:
	var last := _way.size() - 1
	for i in range(_from, _way.size()):
		if i >= _lit.size() or _lit[i] == 0:
			continue
		var layers: Array
		if i == last:
			layers = shape(0, 0)
		else:
			var into := 0
			if i > 0:
				into = HeroWalk.way(_way[i - 1], _way[i])
			elif walk != null and walk.player != null:
				into = HeroWalk.way(walk.player.position, _way[0] * 32 + Vector2i(16, 16))
			layers = shape(into, HeroWalk.way(_way[i], _way[i + 1]))
		var inks: Array[Color] = FED if i < _fed.size() and _fed[i] == 1 else HUNGRY
		var off := Vector2(_way[i] * 32 + Vector2i(16, 16) - _anchor)
		var at := Vector2(2.0 * (off.x + off.y), off.y - off.x)
		_marks.draw_set_transform(at + SHADOW_AT)
		_marks.draw_colored_polygon(layers[0], SHADOW)
		_marks.draw_set_transform(at)
		_marks.draw_colored_polygon(layers[0], INK)
		_marks.draw_polyline(layers[1], INK, 1.0, true)
		_marks.draw_colored_polygon(layers[2], inks[2])
		_marks.draw_colored_polygon(layers[3], inks[1])
		_marks.draw_colored_polygon(layers[4], inks[0])
	_marks.draw_set_transform(Vector2.ZERO)


# ------------------------------------------------------------ the shapes --

## THE MARK for a tile come into the way [param into] and left the way
## [param out] (1–8, 1997's ways; [param out] 0: the X on the last tile),
## made once and kept: [outline, its closed ring, base, light edge, fill],
## in the view's pixels at zoom one round the tile's middle. Every pair is
## drawn by one rule ([method _arrow]): the same way, a straight arrow; a
## turn, the arrow bent — 45° in the world (26.6° or 63.4° on the screen),
## or 90° between two diagonals; a way found never turns sharper, a single
## step reaching the same tile for less, but the rule draws those too, and
## a way back as a straight arrow.
static func shape(into: int, out: int) -> Array:
	if _shapes.is_empty():
		_shapes.resize(81)
	var index := 0 if out == 0 else clampi(into, 0, 8) * 9 + out
	if _shapes[index] == null:
		var poly: PackedVector2Array
		if out == 0:
			poly = _x()
		else:
			poly = _arrow(_on_screen(into if into != 0 else out), _on_screen(out))
		var scaled := PackedVector2Array()
		for p in poly:
			scaled.append(p * SIZE)
		_shapes[index] = _layers(scaled)
	return _shapes[index]


## World way [param d] as a direction on the screen (a unit is 2 pixels
## across and 1 down, [method WorldView.drawn_at]).
static func _on_screen(d: int) -> Vector2:
	return Vector2(2.0 * (ShandalarWorld.DX[d] + ShandalarWorld.DY[d]),
		ShandalarWorld.DY[d] - ShandalarWorld.DX[d]).normalized()


## THE ARROW from [param u_in] to [param u_out] (screen directions): a shaft
## 13 pixels thick along a curve from 20 back the old way, through the
## tile's middle (the curve's control point, so it leaves tangent to both
## ways), to 5 along the new — straight when the two agree — and a head 32
## wide and 18 long the new way.
static func _arrow(u_in: Vector2, u_out: Vector2) -> PackedVector2Array:
	var line := PackedVector2Array()
	var base: Vector2
	var tip: Vector2
	if u_in.dot(u_out) > 0.995 or u_in.dot(u_out) < -0.995:
		line.append(-u_out * 21.0)
		line.append(u_out * 4.0)
		base = u_out * 3.0
		tip = u_out * 22.0
	else:
		var p0 := -u_in * 20.0
		var p2 := u_out * 5.0
		for k in 17:
			var t := k / 16.0
			line.append(p0 * (1.0 - t) * (1.0 - t) + p2 * t * t)
		line.append(p2 + u_out)
		base = p2
		tip = p2 + u_out * 18.0
	var shaft := _biggest(Geometry2D.offset_polyline(line, 6.5, Geometry2D.JOIN_ROUND, Geometry2D.END_BUTT))
	var n := u_out.orthogonal()
	var head := PackedVector2Array([base + n * 16.0, tip, base - n * 16.0])
	return _biggest(Geometry2D.merge_polygons(shaft, head))


## THE X on the way's last tile: two bars 12 thick crossing at its middle.
static func _x() -> PackedVector2Array:
	var a := _biggest(Geometry2D.offset_polyline(PackedVector2Array([Vector2(-15, -15), Vector2(15, 15)]),
		6.0, Geometry2D.JOIN_SQUARE, Geometry2D.END_BUTT))
	var b := _biggest(Geometry2D.offset_polyline(PackedVector2Array([Vector2(15, -15), Vector2(-15, 15)]),
		6.0, Geometry2D.JOIN_SQUARE, Geometry2D.END_BUTT))
	return _biggest(Geometry2D.merge_polygons(a, b))


## The bevelled layers of [param poly]: the outline round it, its ring, the
## base (the dark edge shows below), the light edge up and left, the fill.
static func _layers(poly: PackedVector2Array) -> Array:
	var grown := _biggest(Geometry2D.offset_polygon(poly, 1.2, Geometry2D.JOIN_ROUND))
	var ring := grown.duplicate()
	ring.append(grown[0])
	var inner := _biggest(Geometry2D.offset_polygon(poly, -1.6, Geometry2D.JOIN_MITER))
	return [grown, ring, poly, _shifted(inner, Vector2(-1.0, -1.1)), _shifted(inner, Vector2(0.4, 0.5))]


static func _shifted(poly: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(p + by)
	return out


## The largest of [param polys] (a merge or an offset may give holes or
## slivers beside the outline).
static func _biggest(polys: Array) -> PackedVector2Array:
	var best := PackedVector2Array()
	var best_area := 0.0
	for poly in polys:
		var area := _area(poly)
		if area > best_area:
			best = poly
			best_area = area
	return best


static func _area(poly: PackedVector2Array) -> float:
	var sum := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		sum += a.x * b.y - b.x * a.y
	return absf(sum) * 0.5
