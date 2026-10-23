class_name WorldView
extends Control
## THE WORLD, DRAWN AS 1.3 DREW IT — `DrawWorldTileRange` (0054d619) and
## `RenderAdventureWorldScene` (0054ac08), read 2026-10-22 and written here
## as our own; only the window is new: the original looked at the world
## through a 512 × 280 hole in its frame (`Advinter.pic`), and this draws
## it on the whole screen, with a zoom.
##
## THE PROJECTION. A world unit (32 to a tile) is 2 pixels across and 1
## down: a tile is a 128 × 64 diamond, and the tile's corner (32 tx, 32 ty)
## is the diamond's left vertex. The camera is a world point drawn at
## [member feet] — the hero's feet, as in the original, which kept them a
## little below the window's middle.
##
## WHAT IS DRAWN, in the original's order: the screen rows of tiles top to
## bottom and each row left to right — the ground, the black terrain's and
## the coast's edge pieces (each quarter of a diamond reading three
## neighbours), the roads, the ground halves of the trees and rocks and of
## the sites; then the hero's shadow; then every upright sprite sorted by
## the height of its foot, the later of two at one height behind. The two
## trees or rocks a tile carries, and where they stand, follow from the
## tile's place alone, so a world looks the same every time it is drawn.
## Dungeons show only once the hero holds a clue to them (none at the
## start), as in the original.
##
## Without the 1997 sheets ([WorldArt]) the same world is drawn plain: a
## diamond of its colour per tile, the roads, a mark per site.

## The world drawn, and the world point at the screen's [member feet].
var world: ShandalarWorld
var camera := Vector2(0, 0)
## The hero, in world units, and how they look: `male` or `female`, and
## facing (0–7, the original's directions; 0 at the start).
var hero := Vector2(0, 0)
var hero_walker := "male"
var hero_facing := 0
## The walking figure's step, 0 standing, 1–4 walking (`g_world_player_
## animation_frame`): the frame is the facing's fifth plus the step.
var hero_step := 0
## The figure's sheet dressed in the hero's colours ([HeroColors]), or null
## for the 1997 one.
var hero_sheet: Texture2D
## The lairs the hero sees ([method WorldLairs.seen]): `{x, y, color}`, in
## world units.
var lairs: Array[Dictionary] = []
## Twice the 1997 pixels by default (the owner's choice, 2026-10-22): crisp,
## and about the original window's view scaled up; the wheel zooms.
var zoom := DEFAULT_ZOOM
const DEFAULT_ZOOM := 2.0
## LAND THE HERO HAS NOT SEEN is drawn dark and nothing standing on it is
## shown (the owner's choice, 2026-10-22): the 1997 window showed only
## what it marked explored, and the whole screen would show far more.
var fog := true
const FOG := Color(0.035, 0.026, 0.024, 0.97)
const FOG_EDGE := Color(0.035, 0.026, 0.024, 0.72)

const ZOOM_MIN := 0.5
const ZOOM_MAX := 3.0

## The original's tile, in its screen pixels.
const TILE_W := 128
const TILE_H := 64

## Ground frame by terrain (LANDTILE): 1 water for ocean and marsh, 2 sand
## for blue, 4 grey rock for black, 0 grass for the rest.
## Tree and rock column by terrain (LAND, then LAND2 from 5).
const OBJECT_COLUMN := {3: 0, 1: 1, 2: 2, 5: 3, 6: 4, 8: 5, 13: 6, 10: 7, 15: 8}
## `g_location_marker_sprite_lookup_by_town` (adventureWorldUi.c): pairs of
## (upright, ground half) by look — sixteen looks for towns and cities by
## slot, two for villages by column — as indices into the six location
## sheets read one after another, each counting its end marker.
const TOWN_LOOKS: Array[int] = [1, 7, 5, 11, 28, 32, 25, 29, 0, 6, 35, 36, 13, 19, 33, 34,
	2, 8, 12, 18, 14, 20, 26, 30, 27, 31, 38, 44, 39, 45, 52, 58, 3, 9, 4, 10]
## Where each location sheet starts in that count (24 + 1, 12 + 1, …).
const LOCATION_SHEETS: Array[Array] = [[0, "world_locatn01"], [25, "world_locatn02"],
	[38, "world_locatn03"], [63, "world_locatn04"], [76, "world_locatn05"], [101, "world_locatn06"]]
## `g_castle_sprite_lookup_by_tile_class`: by colour (black, blue, green,
## red, white), a living wizard's castle and its ground half, then a
## beaten wizard's — indices into CASTLES1 (0–11) and CASTLES2 (12–).
const CASTLE_FRAMES: Array[Array] = [[8, 9, 10, 11], [2, 6, 3, 7], [12, 16, 13, 17],
	[14, 18, 15, 19], [0, 4, 1, 5]]
## A town a wizard holds wears his dome (black, blue, green, red, white),
## its ground half always LOCATN04 frame 6.
const DOMES: Array[Array] = [["world_locatn04", 10], ["world_locatn04", 2],
	["world_locatn04", 8], ["world_locatn06", 0], ["world_locatn04", 3]]

## `g_lair_sprite_index_by_color`: a lair's LOCATN07 frame by its colour
## (colourless, black … white), its ground half six frames on; drawn 64
## left of and 96 above its point, at that point's height.
const LAIR_FRAMES: Array[int] = [0, 4, 0, 3, 2, 1]

## Plain colours by terrain (the overview map's tiles, averaged).
const PLAIN := {0: Color("#387faf"), 1: Color("#3aa19c"), 2: Color("#798d58"),
	3: Color("#7c7574"), 4: Color("#ca7c72"), 5: Color("#c4705d"), 6: Color("#c4b289"),
	7: Color("#6c91c6"), 8: Color("#3b878f"), 9: Color("#7b527d"), 10: Color("#81a565"),
	11: Color("#186342"), 12: Color("#992c32"), 13: Color("#a8947f"), 14: Color("#1d7b89"),
	15: Color("#858d4f")}

var art := WorldArt.new()
## Every tile, in the order the original draws them: by screen row (ty − tx)
## and then across it (tx + ty) — and a margin round the map, which the
## original reads as ocean (`GetWorldTileType` turns a place off the map
## into row or column 0) and so draws as water.
static var _order: Array[Vector2i] = []
const MARGIN := 12


func _init() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_PASS


## The screen point the camera is drawn at: the middle across, a little
## below the middle down (the original kept the feet at 160 of a 280-high
## window).
func feet() -> Vector2:
	return Vector2(size.x * 0.5, size.y * 0.57)


## A world point on screen, before the zoom: 2 pixels across and 1 down per
## world unit, relative to the camera.
func project(point: Vector2) -> Vector2:
	var d := point - camera
	return Vector2(2.0 * (d.x + d.y), d.y - d.x)


## A screen point (after the zoom) back to the world.
func unproject(screen: Vector2) -> Vector2:
	var p := (screen - feet()) / zoom
	return camera + Vector2(p.x / 4.0 - p.y / 2.0, p.x / 4.0 + p.y / 2.0)


static func draw_order() -> Array[Vector2i]:
	if _order.is_empty():
		for ty in range(-MARGIN, ShandalarWorld.TILES + MARGIN):
			for tx in range(-MARGIN, ShandalarWorld.TILES + MARGIN):
				_order.append(Vector2i(tx, ty))
		_order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
			var ra := a.y - a.x
			var rb := b.y - b.x
			if ra != rb:
				return ra < rb
			return a.x + a.y < b.x + b.y)
	return _order


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PLAIN[0])
	if world == null:
		return
	draw_set_transform(feet(), 0.0, Vector2(zoom, zoom))
	var view := Rect2(-feet() / zoom, size / zoom)
	var visible: Array[Vector2i] = []
	for tile in draw_order():
		var left := project(Vector2(tile.x * 32, tile.y * 32))
		# The tile's box, grown upward and outward for what stands on it.
		if Rect2(left.x - 96, left.y - 32 - 200, TILE_W + 192, TILE_H + 240).intersects(view):
			visible.append(tile)
	if art.ready():
		_draw_1997(visible)
	else:
		_draw_plain(visible)
	draw_set_transform(Vector2.ZERO)


# ------------------------------------------------------------ the 1997 --

func _draw_1997(visible: Array[Vector2i]) -> void:
	for tile in visible:
		_draw_ground(tile)
	if fog:
		_draw_fog(visible)
	var queue: Array[Array] = []
	for tile in visible:
		if not fog or world.is_explored(tile.x, tile.y):
			_draw_ground_halves(tile, queue)
	for lair in lairs:
		var point := project(Vector2(int(lair["x"]), int(lair["y"])))
		var frame := LAIR_FRAMES[clampi(int(lair.get("color", 0)), 0, 5)]
		_sprite("world_locatn07", frame + 6, point - Vector2(64, 96))
		queue.append([point.y, queue.size(), "world_locatn07", frame, point - Vector2(64, 96)])
	var at := project(hero)
	var frame := ((hero_facing + 2) & 7) * 5 + clampi(hero_step, 0, 4)
	_sprite("world_sego_f", frame, at - Vector2(77, 61))
	queue.append([at.y, queue.size(), HERO, frame, at - Vector2(77, 61)])
	# Up by the foot's height; the later of two at one height behind.
	queue.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] < b[0]
		return a[1] > b[1])
	for entry in queue:
		_sprite(entry[2], entry[3], entry[4])


## The dark over unseen land, lighter where it meets the seen.
func _draw_fog(visible: Array[Vector2i]) -> void:
	for tile in visible:
		if world.is_explored(tile.x, tile.y):
			continue
		var edge := false
		for d in range(1, 9):
			if world.is_explored(tile.x + ShandalarWorld.DX[d], tile.y + ShandalarWorld.DY[d]):
				edge = true
				break
		var left := project(Vector2(tile.x * 32, tile.y * 32))
		draw_colored_polygon(PackedVector2Array([left, left + Vector2(64, -32),
			left + Vector2(128, 0), left + Vector2(64, 32)]), FOG_EDGE if edge else FOG)


## The hero's place in the draw queue: their sheet, dressed or 1997.
const HERO := "hero"


func _sprite(key: String, frame: int, at: Vector2) -> void:
	var sheet: Texture2D
	if key == HERO:
		key = "world_ego_f" if hero_walker == "female" else "world_ego_m"
		sheet = hero_sheet
	if sheet == null:
		sheet = art.texture(key)
	if sheet == null:
		return
	var rect := art.frame_rect(key, frame)
	draw_texture_rect_region(sheet, Rect2(at, rect.size), rect)


func _draw_ground(tile: Vector2i) -> void:
	var left := project(Vector2(tile.x * 32, tile.y * 32))
	var box := Vector2(left.x, left.y - 32)
	var code := world.terrain(tile.x, tile.y)
	var colors := ShandalarWorld.magic_mask(code)
	if code == 0 or code == 8:
		_sprite("world_landtile", 1, box)
	else:
		if code == 1:
			_sprite("world_landtile", 2, box)
		else:
			_sprite("world_landtile", 4 if colors == 2 else 0, box)
		var coast := 0
		var black := 0
		for d in range(1, 9):
			coast >>= 1
			black >>= 1
			var next := world.terrain(tile.x + ShandalarWorld.DX[d], tile.y + ShandalarWorld.DY[d])
			var next_colors := ShandalarWorld.magic_mask(next)
			if next == 0 or next == 8 or (next != code and (colors | next_colors) & 4 != 0):
				coast |= 0x80
			if colors != 2 and next_colors == 2:
				black |= 0x80
		_draw_edges(black, 4, box)
		_draw_edges(coast, 0, box)
	var roads := world.road_bits(tile.x, tile.y)
	for i in 8:
		if roads & (1 << i) != 0:
			_sprite("world_roads", ((i - 2) & 7) + 1, box)


## The four quarters of a diamond, each reading its two edge neighbours
## and the corner between (bits of the eight directions, wrapped): top
## N NE E, bottom S SW W, left W NW N, right E SE S.
func _draw_edges(bits: int, first_row: int, box: Vector2) -> void:
	if bits == 0:
		return
	bits |= bits << 8
	for i in 4:
		var three := 0
		match i:
			0: three = bits & 7
			1: three = (bits >> 4) & 7
			2: three = (bits >> 6) & 7
			3: three = (bits >> 2) & 7
		if three == 0:
			continue
		var at := box + (Vector2(32, (i & 1) * 32) if i < 2 else Vector2((i & 1) * 64, 16))
		_sprite("world_cstline1", (first_row + i) * 7 + three - 1, at)


func _draw_ground_halves(tile: Vector2i, queue: Array[Array]) -> void:
	var left := project(Vector2(tile.x * 32, tile.y * 32))
	var base := left.y
	var flags := world.tile_flags(tile.x, tile.y)
	var code := world.terrain(tile.x, tile.y)
	if flags & ShandalarWorld.SITE == 0 and OBJECT_COLUMN.has(code):
		var pattern := absi(tile.y) * 3 + absi(tile.x) * 7
		var ox := TILE_W / ((pattern % 5) * 2 + 4)
		var oy := (pattern % 4) * 2 + 5
		if code == 1:
			ox = 0
			oy = 0
		var column: int = OBJECT_COLUMN[code]
		var row := pattern % 11
		if column >= 5:
			column %= 5
			row += 11
		_object(row, column, Vector2(left.x + ox, base - oy), base - oy, queue)
		row = (pattern + tile.x) % 11 + (11 if row >= 11 else 0)
		_object(row, column, Vector2(left.x - ox, base + oy), base + oy, queue)
	if flags & ShandalarWorld.SITE != 0:
		_site(tile, left, base, queue)


## One tree or rock: its ground half now, the upright into the queue,
## both standing at [param foot] less the frame's anchor.
func _object(row: int, column: int, foot: Vector2, depth: float, queue: Array[Array]) -> void:
	var upright := "world_land2" if row >= 11 else "world_land"
	var ground := "world_sland2" if row >= 11 else "world_sland"
	var frame := (row % 11) * 5 + column
	var at := foot - Vector2(0, art.top(upright, frame))
	_sprite(ground, frame, at)
	queue.append([depth, queue.size(), upright, frame, at])


func _site(tile: Vector2i, left: Vector2, base: float, queue: Array[Array]) -> void:
	var index := _site_index(tile)
	if index < 0:
		return
	var site: Dictionary = world.sites[index]
	var kind: int = site["type"]
	if kind == ShandalarWorld.CASTLE or kind == 5:
		var color := _color_index(world.terrain(tile.x, tile.y))
		var frames: Array = CASTLE_FRAMES[color]
		var pick := 0 if kind == ShandalarWorld.CASTLE else 2
		var at := Vector2(left.x, base - 160)
		_castle_sprite(frames[pick + 1], at)
		queue.append([base, queue.size()] + _castle_ref(frames[pick]) + [at])
		return
	if int(site["status"]) & 0xFF00 != 0:
		var dome: Array = DOMES[clampi((int(site["status"]) >> 8) - 1, 0, 4)]
		var at := Vector2(left.x, base - 166)
		_sprite("world_locatn04", 6, at)
		queue.append([base, queue.size(), dome[0], dome[1], at])
		return
	var look := ((tile.x & 1) + 16) * 2 if kind == ShandalarWorld.VILLAGE else (index % 16) * 2
	var upright := _location(TOWN_LOOKS[look])
	var ground := _location(TOWN_LOOKS[look + 1])
	var height := art.frame_size(upright[0]).y
	var at := Vector2(left.x, 24 + base - height)
	_sprite(ground[0], ground[1], at)
	queue.append([base, queue.size(), upright[0], upright[1], at])


## `FindTownAtWorldCoordinates`: the first slot standing on the tile.
func _site_index(tile: Vector2i) -> int:
	for i in world.sites.size():
		if int(world.sites[i]["x"]) == tile.x and int(world.sites[i]["y"]) == tile.y:
			return i
	return -1


## A terrain's one colour, 0 black … 4 white.
static func _color_index(code: int) -> int:
	match ShandalarWorld.magic_mask(code):
		0x02: return 0
		0x04: return 1
		0x08: return 2
		0x10: return 3
	return 4


## An index into the six location sheets read as one: [sheet, frame].
static func _location(index: int) -> Array:
	for i in range(LOCATION_SHEETS.size() - 1, -1, -1):
		if index >= int(LOCATION_SHEETS[i][0]):
			return [LOCATION_SHEETS[i][1], index - int(LOCATION_SHEETS[i][0])]
	return [LOCATION_SHEETS[0][1], index]


static func _castle_ref(index: int) -> Array:
	return ["world_castles1", index] if index < 12 else ["world_castles2", index - 12]


func _castle_sprite(index: int, at: Vector2) -> void:
	var ref := _castle_ref(index)
	_sprite(ref[0], ref[1], at)


# ----------------------------------------------------------- the plain --

func _draw_plain(visible: Array[Vector2i]) -> void:
	for tile in visible:
		var left := project(Vector2(tile.x * 32, tile.y * 32))
		var points := PackedVector2Array([left, left + Vector2(64, -32),
			left + Vector2(128, 0), left + Vector2(64, 32)])
		draw_colored_polygon(points, PLAIN.get(world.terrain(tile.x, tile.y), PLAIN[0]))
	if fog:
		_draw_fog(visible)
	for tile in visible:
		if fog and not world.is_explored(tile.x, tile.y):
			continue
		var middle := project(Vector2(tile.x * 32 + 16, tile.y * 32 + 16))
		var roads := world.road_bits(tile.x, tile.y)
		for d in range(1, 9):
			if roads & (1 << (d - 1)) != 0:
				var to := project(Vector2((tile.x + ShandalarWorld.DX[d]) * 32 + 16,
					(tile.y + ShandalarWorld.DY[d]) * 32 + 16))
				draw_line(middle, middle.lerp(to, 0.5), Color8(123, 63, 7), 3.0)
	for tile in visible:
		if world.tile_flags(tile.x, tile.y) & ShandalarWorld.SITE == 0:
			continue
		if fog and not world.is_explored(tile.x, tile.y):
			continue
		var index := _site_index(tile)
		if index < 0:
			continue
		var kind: int = world.sites[index]["type"]
		var middle := project(Vector2(tile.x * 32 + 16, tile.y * 32 + 16))
		var radius: float = [0, 7, 11, 14, 18, 18][clampi(kind, 0, 5)]
		draw_circle(middle, radius + 2, Color(0, 0, 0, 0.6))
		draw_circle(middle, radius, Color8(236, 222, 196) if kind < 4 else Color8(232, 190, 110))
	for lair in lairs:
		var mouth := project(Vector2(int(lair["x"]), int(lair["y"])))
		draw_circle(mouth, 12, Color(0, 0, 0, 0.6))
		draw_circle(mouth, 9, Color8(40, 26, 20))
		draw_arc(mouth, 10, 0, TAU, 20, Color8(232, 190, 110), 2.0)
	var at := project(hero)
	draw_circle(at + Vector2(0, -14), 9, Color8(150, 22, 18))
	draw_rect(Rect2(at + Vector2(-5, -8), Vector2(10, 8)), Color8(150, 22, 18))
