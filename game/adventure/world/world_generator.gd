class_name WorldGenerator
extends RefCounted
## THE 1997 WORLD GENERATOR, step for step — `GenerateAdventureWorldMap`
## (004f6d90) and everything it calls, then `InitializeCastleDungeonSlots`
## (005081fa) and the hero's starting tile, as version 1.3 of the original
## runs them (the matching decompilation, `rlerrr/shandalar-decomp`,
## `world_generation.c`; `docs/world-builder-adventure-notes.md` walks
## through it). Our own code, written from that reading: no line of the
## decompilation is in this project.
##
## EXACT, NOT ALIKE. Given the seed its dice stood at when the original
## began a world, and the slot its site placement began with, this makes
## the original's world: the same terrain, sites, World Magics, trade,
## roads, castles, dungeons and start, drawn in the same order from the
## same `rand()` ([MsvcRandom]) — and the original's quirks with them,
## each marked QUIRK below. A scratch harness built from the decompiled C
## holds it to that, world for world (`docs/world-builder-adventure-notes.md`,
## "Exactness").
##
## NEVER STUCK [QoL]. A few seeds lead the original into a loop it never
## leaves: it hangs on "Shandalar Materializing...". Each place it can,
## marked GUARD below, this sees it and makes the world again from the
## dice as they stand. Every world the original finishes is unchanged.
##
## ON THE ORIGINAL'S WORK PAGE. The original keeps the world on a 320 × 200
## picture and works on it with pixel reads and writes, using regions beside
## the 64 × 64 grid as scratch ([ShandalarWorld]). This works on the same
## page the same way, so reads that wander off the grid wander where the
## original's did.

const W := ShandalarWorld.PAGE_WIDTH
const H := ShandalarWorld.PAGE_HEIGHT
const DX := ShandalarWorld.DX
const DY := ShandalarWorld.DY

## Fewer land tiles than this and the world is made again (0x6d6).
const MIN_LAND := 1750
## The castles' colours as the placement marks them: bits 1–5 (0x3e).
const ALL_CASTLES := 0x3E
## At least this many towns and cities, or the sites are placed again.
const MIN_MAJOR_SITES := 30
## The six trade goods go to six different towns and cities.
const TRADE_GOODS := 6
## A GUARD: after this many draws in vain, a placement looks over the
## whole map once for any place it could take; if there is none, the
## original would draw forever.
const LOOK_EVERYWHERE_AFTER := 65536

## `g_dungeon_card_effect_by_color[4]` (0058c5ec) and, straight after it in
## memory, `g_dungeon_card_effect_by_monster_flags[9]` (0058c5fc). QUIRK:
## the colour table is indexed by colour 1–5, so red and green read on into
## the second table; one array keeps that true.
const EFFECTS_BY_COLOR_THEN_FLAGS: Array[int] = [0, 8, 867, 939,
	178, 51, 159, 287, 63, 114, 229, 5, -1]
const FLAGS_TABLE_START := 4
## `g_mana_castle_card_effect_by_difficulty[5][4]` (0058c620).
const MANA_CASTLE_EFFECTS: Array[Array] = [[246, 100, 208, 661], [52, 494, 935, 340],
	[288, 15, 262, 803], [123, 439, 192, 155], [128, 134, 28, 620]]

var _rng := MsvcRandom.new()
var _page := PackedByteArray()
## The 18 × 18 random lattice and its 17 × 17 wrapped copy, row by row,
## 19 to a row.
var _lattice := PackedInt32Array()
var _grid := PackedInt32Array()
## The page as it stood before the road being laid, to take it back from.
var _before_road := PackedByteArray()
var _site_type := PackedInt32Array()
var _site_x := PackedInt32Array()
var _site_y := PackedInt32Array()
var _site_trade := PackedInt32Array()
var _site_status := PackedInt32Array()
var _magic := PackedInt32Array()
var _owned_magic := 0
var _slot_start := 0
## A GUARD found that the original would never finish this world.
var _doomed := false


## MAKE A WORLD. [param seed_value] is the dice's state when the generator
## starts (`srand`); [param slot_start] is the site slot it starts filling
## at, 0–127 (the original's `clock() % 128`, which no dice draw);
## [param color] the hero's colour, 1 black, 2 blue, 3 green, 4 red,
## 5 white, whose own World Magic it is given and is offered nowhere;
## [param difficulty] 0–3, for the wizards' castles.
static func generate(seed_value: int, slot_start: int, color: int, difficulty: int) -> ShandalarWorld:
	var maker := WorldGenerator.new()
	return maker._make(seed_value, slot_start, clampi(color, 1, 5), clampi(difficulty, 0, 3))


func _make(seed_value: int, slot_start: int, color: int, difficulty: int) -> ShandalarWorld:
	_rng.reseed(seed_value)
	_slot_start = posmod(slot_start, 128)
	_owned_magic = 1 << (color * 2)
	_page.resize(W * H)
	var encounters: Array[Dictionary] = []
	var start := Vector2i(-1, -1)
	while true:
		_generate_map()
		encounters = _place_castles_and_dungeons(difficulty)
		if encounters.is_empty():
			continue
		start = _starting_point(color)
		if start.x < 0:
			continue
		break
	var world := ShandalarWorld.new()
	world.seed = seed_value & 0xFFFFFFFF
	world.slot_start = _slot_start
	world.color = color
	world.difficulty = difficulty
	for i in 7:
		world.lair_respawn.append((4 - difficulty) * i * -100)
	world.encounters = encounters
	world.start = start
	world.page = _page
	for i in 128:
		world.sites.append({"x": _site_x[i], "y": _site_y[i], "type": _site_type[i],
			"trade": _site_trade[i], "status": _site_status[i]})
	for i in 12:
		world.world_magic_sites.append(_magic[i])
	world.rand_state = _rng.state
	return world


# ------------------------------------------------------------- the page --

func _put(x: int, y: int, value: int) -> void:
	if x < 0 or y < 0 or x >= W or y >= H:
		return
	_page[y * W + x] = value & 0xFF


## A raw read, as the original's: off the left edge it is the row above's
## last pixel.
func _read(x: int, y: int) -> int:
	var at := y * W + x
	if at < 0 or at >= W * H:
		return 0
	return _page[at]


## `GetWorldTileType`: off the grid reads row or column 0.
func _tile(x: int, y: int) -> int:
	if x >= 64 or x < 0:
		x = 0
	if y >= 64 or y < 0:
		y = 0
	return _page[y * W + x] & 0xF


func _flags(x: int, y: int) -> int:
	if x >= 64 or x < 0 or y >= 64 or y < 0:
		return 0
	return _page[y * W + x]


func _set_flags(mask: int, x: int, y: int) -> void:
	if x >= 64 or x < 0 or y >= 64 or y < 0:
		return
	_page[y * W + x] = _page[y * W + x] | mask


func _clear_flags(mask: int, x: int, y: int) -> void:
	if x >= 64 or x < 0 or y >= 64 or y < 0:
		return
	_page[y * W + x] = _page[y * W + x] & ~mask & 0xFF


## `ApproximateDistance`: twice the longer leg plus the shorter.
static func distance(dx: int, dy: int) -> int:
	dx = absi(dx)
	dy = absi(dy)
	return dx * 2 + dy if dy < dx else dy * 2 + dx


# --------------------------------------------------------------- terrain --

func _generate_map() -> void:
	while true:
		_init_lattice()
		_page.fill(0)
		if _lay_terrain() < MIN_LAND:
			continue
		_fill_ponds()
		_keep_one_landmass()
		if not _place_sites():
			continue
		_lay_roads()
		return


## 18 × 18 random values 0–15, row by row, wrapped at the edges; the
## original then sums a smoothing it never uses and copies the values as
## they are into a 17 × 17 grid that wraps again (`InitializeAnimatedNoiseGrid`).
func _init_lattice() -> void:
	_lattice.resize(19 * 19)
	_lattice.fill(0)
	for y in 18:
		for x in 18:
			_lattice[y * 19 + x] = _rng.below(16)
		_lattice[y * 19 + 18] = _lattice[y * 19]
	for x in 18:
		_lattice[18 * 19 + x] = _lattice[x]
	_grid.resize(19 * 19)
	_grid.fill(0)
	for y in 17:
		for x in 17:
			_grid[y * 19 + x] = _lattice[y * 19 + x]
	for y in 17:
		_grid[y * 19 + 16] = _grid[y * 19]
	for x in 17:
		_grid[16 * 19 + x] = _grid[x]


## Bilinear value noise at a fixed-point position (`SampleAnimatedNoiseGridBilinear`).
func _sample(xf: int, yf: int) -> int:
	xf -= 0x80
	yf -= 0x80
	var e := (xf >> 8) & 0xF
	var lx := (xf & 0xFF) / 8
	var i := (yf >> 8) & 0xF
	var ly := (yf & 0xFF) / 8
	var w := _grid[e * 19 + i] * (32 - ly) * (32 - lx)
	w += _grid[(e + 1) * 19 + i] * (32 - ly) * lx
	w += _grid[e * 19 + i + 1] * (32 - lx) * ly
	w += _grid[(e + 1) * 19 + i + 1] * ly * lx
	return _cdiv(w, 32)


## A tile's height, 0–100 (`CalculateWorldTerrainValue`): three samples of
## the noise less a falloff from the centre along the x = y diagonal.
func _height(x: int, y: int) -> int:
	var falloff := absi(x - 32) + absi(y - 32)
	falloff = falloff * falloff / 512 + absi(x - y) / 16
	x = x << 5
	y = y << 5
	var value := _sample(x, y) << 2
	value += _sample(x << 3, y << 3) * 2
	value += _sample(x << 4, y << 4)
	value -= clampi(falloff, 0, 12) * 0x200
	return clampi(_cdiv(_cdiv(7 * value, 64), 4), 0, 100)


## Height to terrain, by the original's bands. The 56–63 band's first
## choice is overwritten in the original, so only 15 and 5 land. Heights
## over 91 cannot happen, so the original's "keep the last code" for 96
## and over never does either.
static func terrain_for(height: int, last: int) -> int:
	match height / 8:
		0, 1: return 0
		2: return 8 if height >= 22 else 1
		3: return 3
		4: return 13 if height < 34 else 6
		5: return 10 if height <= 42 else 2
		6: return 2
		7: return 5 if height >= 60 else 15
		8, 9, 10, 11: return 5
	return last


## The terrain, x outer and y inner as the original walks it; ocean on the
## outer two tiles and outside the overview's isometric frame. Returns the
## land count.
func _lay_terrain() -> int:
	var land := 0
	var code := 0
	for x in 64:
		for y in 64:
			if x < 2 or y < 2 or x >= 62 or y >= 62:
				_page[y * W + x] = 0
				continue
			var sx := (x + y) * 3 - 32
			var sy := (y - x) * 3 + 100
			if sx < 4 or sy < 4 or sx >= 316 or sy >= 196:
				_page[y * W + x] = 0
				continue
			code = terrain_for(_height(x, y), code)
			_page[y * W + x] = code
			if code != 0:
				land += 1
	return land


## A one-tile pond with land on all four sides becomes white land, in
## place, x outer and y inner.
func _fill_ponds() -> void:
	for x in range(1, 63):
		for y in range(1, 63):
			if _tile(x, y) != 0:
				continue
			var open := false
			for d in [1, 3, 5, 7]:
				if _tile(x + DX[d], y + DY[d]) == 0:
					open = true
					break
			if not open:
				_page[y * W + x] = 6


## ONE LANDMASS (`PropagatePathConnectivity`): a flood of up to seven
## steps from tile (40, 24); every fourth tile it reaches on the 4-tile
## lattice floods again, until nothing new is reached. Land never reached
## becomes ocean.
func _keep_one_landmass() -> void:
	_put(0xA8, 0x58, 0xFF)
	var changed := true
	while changed:
		changed = false
		for x in range(4, 64, 4):
			for y in range(4, 64, 4):
				if _page[(y + 64) * W + x + 128] == 0:
					continue
				for sy in 64:
					for sx in 64:
						_page[sy * W + sx + 64] = 0
				_flood(x, y, 8)
				_page[(y + 64) * W + x + 128] = 0
				for sx in 64:
					for sy in 64:
						if _page[sy * W + sx + 64] != 0 and _page[sy * W + sx + 128] == 0:
							changed = true
							_page[sy * W + sx + 128] = 0xFF
							_page[(sy + 64) * W + sx + 128] = 0xFF
	for x in 64:
		for y in 64:
			if _page[y * W + x + 128] == 0:
				_page[y * W + x] = 0


## `FloodFillPathConnectivity`: the depth goes into the x + 64 layer; a
## neighbour is entered while its depth there is lower and its tile is
## not ocean.
func _flood(x: int, y: int, depth: int) -> void:
	_put(x + 64, y, depth)
	if depth <= 1:
		return
	for d in [1, 3, 5, 7]:
		var nx: int = DX[d] + x
		var ny: int = DY[d] + y
		if _read(nx + 64, ny) < depth and _read(nx, ny) != 0:
			_flood(nx, ny, depth - 1)


# ----------------------------------------------------------------- sites --

## THE 128 SITES, the World Magics and the trade (`GenerateWorldTownSlots`).
## Up to four tries; false makes the whole world again.
func _place_sites() -> bool:
	_site_type.resize(128)
	_site_x.resize(128)
	_site_y.resize(128)
	_site_trade.resize(128)
	_site_status.resize(128)
	_magic.resize(12)
	_doomed = false
	for attempt in 4:
		if _try_sites():
			return true
		if _doomed:
			return false
	return false


func _try_sites() -> bool:
	var magic_towns := 0
	var major := 0
	var castles := 0
	_magic.fill(0)
	var slot := _slot_start
	_site_type.fill(-1)
	_site_x.fill(-1)
	_site_y.fill(-1)
	_site_trade.fill(-1)
	_site_status.fill(-1)
	# Room left for towns and cities, to see a doomed world early (the GUARD
	# below). A town is placed only more than 10 from every site and a city
	# more than 32 from every city, so a 4 × 4 block of tiles (9 at most
	# across) can take a town only while it has no site, and an 11 × 11
	# block (30 at most) a city only while it has no city.
	var town_room := {}
	var city_room := {}
	for y in 64:
		for x in 64:
			if _page[y * W + x] & 0xF != 0:
				town_room[Vector2i(x / 4, y / 4)] = true
				city_room[Vector2i(x / 11, y / 11)] = true
	var trading := 0
	for counter in 128:
		# GUARD: the tidy-up keeps only the land joined to tile (40, 24); when
		# that tile is cut off by sea, little or no land is left. With none,
		# the original draws for a site's place forever; with room for fewer
		# towns and cities than trade goods, it places all 128 sites (each,
		# on a crowded islet, after hundreds of draws) and then picks a town
		# for the last trade good forever. Either way the world is made again
		# as soon as that is certain.
		if trading + town_room.size() + city_room.size() < TRADE_GOODS:
			_take_back_sites()
			_doomed = true
			return false
		var tries := 0
		var placed := false
		while not placed:
			var cx := _rng.below(64)
			var cy := _rng.below(64)
			var tile := _tile(cx, cy)
			if tile == 0:
				continue
			var nearest := 0x7FFF
			var nearest_city := 0x7FFF
			for other in 128:
				if _site_x[other] == -1:
					continue
				var d := distance(cx - _site_x[other], cy - _site_y[other])
				if d < nearest:
					nearest = d
				if d < nearest_city and _site_type[other] == ShandalarWorld.CITY:
					nearest_city = d
			tries += 1
			if 7 - tries / 100 > nearest:
				continue
			placed = true
			_site_x[slot] = cx
			_site_y[slot] = cy
			if nearest_city > 32:
				_site_type[slot] = ShandalarWorld.CITY
			elif nearest > 10:
				_site_type[slot] = ShandalarWorld.TOWN
			else:
				_site_type[slot] = ShandalarWorld.VILLAGE
			_site_trade[slot] = 0
			_site_status[slot] = 0
			var castle_color := 0
			match tile:
				3: castle_color = 1
				1: castle_color = 2
				2: castle_color = 3
				5: castle_color = 4
				6: castle_color = 5
			if nearest_city > 16 and castle_color != 0 and castles & (1 << castle_color) == 0:
				_site_type[slot] = ShandalarWorld.CASTLE
				castles |= 1 << castle_color
			var colors := ShandalarWorld.magic_mask(tile)
			if slot != 0 and (_site_type[slot] == ShandalarWorld.CITY or _site_type[slot] == ShandalarWorld.TOWN):
				var draws := 0
				while draws < 99:
					var wanted := _rng.below(10) + 2
					if _magic[wanted] == 0 and colors & (1 << (wanted / 2)) != 0:
						_magic[wanted] = slot
						break
					draws += 1
				if draws >= 99:
					_magic[_rng.below(2)] = slot
				if magic_towns < 10:
					_site_status[slot] |= 1
					magic_towns += 1
			_set_flags(ShandalarWorld.SITE, cx, cy)
			town_room.erase(Vector2i(cx / 4, cy / 4))
			if _site_type[slot] == ShandalarWorld.CITY:
				city_room.erase(Vector2i(cx / 11, cy / 11))
			if _site_type[slot] == ShandalarWorld.CITY or _site_type[slot] == ShandalarWorld.TOWN:
				trading += 1
			slot = (slot * 5 + 1) % 128
		# QUIRK: the original counts the site in the slot numbered like this
		# turn of the loop, not the one just placed.
		if _site_type[counter] > 1:
			major += 1
	var valid := castles == ALL_CASTLES and major >= MIN_MAJOR_SITES
	# GUARD: fewer towns and cities than trade goods, and the original picks
	# a town for the last one forever; the world is made again.
	if trading < TRADE_GOODS:
		_take_back_sites()
		_doomed = true
		return false
	for trade_color in TRADE_GOODS:
		var pick := 0
		while true:
			pick = _rng.below(128)
			while _site_type[pick] <= 1:
				pick = _rng.below(128)
			if _site_type[pick] != ShandalarWorld.CASTLE and _site_trade[pick] == 0:
				break
		_site_trade[pick] = 1 << trade_color
	# QUIRK: every town and city is given a trade again, overwriting the six.
	var turn := _rng.below(12)
	for i in 128:
		if _site_type[i] > 1 and _site_type[i] < ShandalarWorld.CASTLE:
			if turn & 1 != 0:
				_site_trade[i] = 1 << ((turn % 12) / 2)
			else:
				_site_trade[i] = ((turn % 10) / 2 + 1) * 0x100
			turn += 1
	for i in 12:
		if _magic[i] == 0:
			valid = false
		if _owned_magic & (1 << i) != 0:
			_magic[i] = 0
	if valid:
		return true
	_take_back_sites()
	return false


func _take_back_sites() -> void:
	for i in 128:
		_clear_flags(ShandalarWorld.SITE, _site_x[i], _site_y[i])
	_magic.fill(0)


# ----------------------------------------------------------------- roads --

## `GenerateTownConnections`: as many roads from each site as its type
## number, each to a near site among 42 drawn, three tries each.
func _lay_roads() -> void:
	# QUIRK: the road goes to the SECOND-best of the samples (the best
	# before the last improvement), and the two are carried from one road
	# to the next; the original never set them first, so ours start at 0.
	var best := 0
	var chosen := 0
	for site in 128:
		for road in _site_type[site]:
			var attempts := 0
			while true:
				var nearest := 0x7FFF
				for sample in 42:
					var candidate := _rng.below(128)
					var d := distance(_site_x[site] - _site_x[candidate], _site_y[site] - _site_y[candidate])
					if d < nearest:
						nearest = d
						chosen = best
						best = candidate
				if _lay_road(_site_x[site], _site_y[site], _site_x[chosen], _site_y[chosen]):
					break
				attempts += 1
				if attempts >= 3:
					break


## `CreateTownConnectionPath`: greedy steps that always get closer, cheaper
## on roads already laid and dearer on green and red; a road that meets a
## road ends there. A road that cannot get closer is taken back whole.
func _lay_road(sx: int, sy: int, tx: int, ty: int) -> bool:
	var cx := sx
	var cy := sy
	var steps := 0
	# The original copies the grid and the road layer aside on its page
	# (x + 64) and copies them back on a failure; nothing reads that copy
	# afterwards, so it is held here instead.
	_before_road = _page.duplicate()
	_set_flags(ShandalarWorld.ROAD, cx, cy)
	while true:
		var target := distance(tx - cx, ty - cy)
		var best_direction := -1
		var best_score := 0x7FFF
		for d in range(1, 9):
			var nx: int = DX[d] + cx
			var ny: int = DY[d] + cy
			var tile := _tile(nx, ny)
			if tile == 0:
				continue
			var score := distance(tx - nx, ty - ny)
			if target <= score:
				continue
			if tile == 2 or tile == 11:
				score += 1
			if tile == 4 or tile == 5:
				score += 4
			if _flags(nx, ny) & ShandalarWorld.ROAD != 0 and steps >= 1:
				score -= 4
			if best_score > score:
				best_score = score
				best_direction = d
		if best_direction == -1:
			for yy in 128:
				for xx in 64:
					_page[yy * W + xx] = _before_road[yy * W + xx]
			return false
		var nx: int = DX[best_direction] + cx
		var ny: int = DY[best_direction] + cy
		var joined := _flags(nx, ny) & ShandalarWorld.ROAD
		_mark_road(cx, cy, best_direction)
		if joined != 0 and steps >= 1:
			return true
		cx = nx
		cy = ny
		steps += 1
		if cx == tx and cy == ty:
			return true
	return true


## `MarkPathConnection`: the direction bit on both ends, and both tiles
## flagged as road.
func _mark_road(x: int, y: int, direction: int) -> void:
	if x >= 64 or x < 0 or y >= 64 or y < 0:
		return
	_put(x, y + 64, _read(x, y + 64) | (1 << (direction - 1)))
	_set_flags(ShandalarWorld.ROAD, x, y)
	x += DX[direction]
	y += DY[direction]
	direction = ((direction + 3) & 7) + 1
	_put(x, y + 64, _read(x, y + 64) | (1 << (direction - 1)))
	_set_flags(ShandalarWorld.ROAD, x, y)


# ------------------------------------------------- castles and dungeons --

## `InitializeCastleDungeonSlots`: the 28 dungeon cards into the ten
## dungeons, then fifteen places — five draws for the wizards' castles,
## which then stand on their castle sites, and ten dungeons at least 4 from
## every town, city and earlier slot, each with its colour, monsters and
## rules. Empty when no place is left for one (a GUARD).
func _place_castles_and_dungeons(difficulty: int) -> Array[Dictionary]:
	# Three places a slot, slot by slot.
	var cards := PackedInt32Array()
	cards.resize(15 * 3)
	cards.fill(-1)
	for k in ShandalarWorld.DUNGEON_CARDS.size():
		var e := 0
		while true:
			e = _rng.below(10) + 5
			if cards[e * 3 + 2] == -1:
				break
		for place in 3:
			if cards[e * 3 + place] == -1:
				cards[e * 3 + place] = k
				break
	var out: Array[Dictionary] = []
	var nearest_town := 0
	var castle_town := 0
	for e in 15:
		var cx := 0
		var cy := 0
		var nearest := 0
		var misses := 0
		while true:
			cx = _rng.below(64)
			cy = _rng.below(64)
			if _free_for_dungeon(cx, cy):
				nearest = 0xFF
				for s in 128:
					if e < 5 and _site_type[s] == ShandalarWorld.CASTLE:
						if ShandalarWorld.magic_mask(_tile(_site_x[s], _site_y[s])) == 1 << (e + 1):
							castle_town = s
					if _site_type[s] <= 1 or _site_type[s] == ShandalarWorld.CASTLE:
						continue
					var d := distance(_site_x[s] - cx, _site_y[s] - cy)
					if nearest > d:
						nearest = d
						nearest_town = s
				nearest = mini(nearest, _nearest_earlier(cx, cy, out))
				if nearest >= 4:
					break
			# GUARD: no free tile anywhere far enough from the towns, cities
			# and earlier slots, and the original draws forever.
			misses += 1
			if misses == LOOK_EVERYWHERE_AFTER and not _dungeon_place_left(out):
				return []
		# QUIRK: the dungeon flag goes on the drawn tile even for a castle,
		# which then moves to its castle site.
		_set_flags(ShandalarWorld.DUNGEON, cx, cy)
		var slot := {"x": cx, "y": cy, "town": nearest_town,
			"color": _rng.below(5) + 1, "monster_flags": 2}
		if e < 5:
			slot["color"] = e + 1
			slot["monster_flags"] = 0x81
			slot["x"] = _site_x[castle_town]
			slot["y"] = _site_y[castle_town]
		var flags: int = slot["monster_flags"]
		var weight := 0
		if flags <= _rng.below(2) + 1:
			weight = 0x1C if flags > 1 else 0x10
			flags |= 0x80
		else:
			for s in flags:
				weight += s * 2 + 4
		if cards[e * 3 + 1] == -1:
			weight = weight * 3 / 2
		if cards[e * 3 + 2] != -1:
			weight = weight * 2 / 3
		var effect := EFFECTS_BY_COLOR_THEN_FLAGS[FLAGS_TABLE_START
			+ (4 if flags & 0xC0 != 0 else 0) + (flags & 0x7F) + _rng.below(2)]
		var rules := 1
		var by_color: int = EFFECTS_BY_COLOR_THEN_FLAGS[int(slot["color"])]
		match weight / 4:
			0, 1, 2, 3:
				if weight / 4 < 3:
					flags = (flags + 1) & 0xFF
				effect = by_color
				rules |= 1 << (_rng.below(5) + 4)
			4:
				effect = by_color
			5:
				rules |= 1 << (_rng.below(5) + 4)
				effect = -1
			6:
				effect = -1
		if rules & 0x100 != 0 or (flags & 0x3F < 2 and rules & 0x20 != 0):
			effect = by_color
			rules &= 0xFFFFFEDF
		if flags & 0x7F == 1:
			rules &= 0xFFFFFFFE
		if e < 5:
			rules |= 3
			effect = MANA_CASTLE_EFFECTS[e][difficulty]
		slot["monster_flags"] = flags
		slot["rules"] = rules
		slot["card_in_effect"] = effect
		var held: Array[int] = []
		for place in 3:
			if cards[e * 3 + place] != -1:
				held.append(cards[e * 3 + place])
		slot["cards"] = held
		out.append(slot)
	return out


func _free_for_dungeon(x: int, y: int) -> bool:
	return _tile(x, y) != 0 and _flags(x, y) & (ShandalarWorld.SITE | ShandalarWorld.ROAD) == 0


func _nearest_earlier(x: int, y: int, earlier: Array[Dictionary]) -> int:
	var nearest := 0xFF
	for slot in earlier:
		nearest = mini(nearest, distance(int(slot["x"]) - x, int(slot["y"]) - y))
	return nearest


## Whether any tile could still take the next slot, as its draws test one.
func _dungeon_place_left(earlier: Array[Dictionary]) -> bool:
	for y in 64:
		for x in 64:
			if not _free_for_dungeon(x, y):
				continue
			var nearest := _nearest_earlier(x, y, earlier)
			for s in 128:
				if _site_type[s] == ShandalarWorld.TOWN or _site_type[s] == ShandalarWorld.CITY:
					nearest = mini(nearest, distance(_site_x[s] - x, _site_y[s] - y))
			if nearest >= 4:
				return true
	return false


## WHERE THE HERO STARTS (`RunAdventureSession`): a random tile of the
## hero's own colour (two-colour terrain counts) with no site on it, in
## world units, 32 to a tile, at the tile's middle. (−1, −1) when there is
## no such tile (a GUARD).
func _starting_point(color: int) -> Vector2i:
	var wanted := 1 << color
	var misses := 0
	while true:
		var px := _rng.below(64) * 32 + 16
		var py := _rng.below(64) * 32 + 16
		if _start_fits(wanted, px / 32, py / 32):
			return Vector2i(px, py)
		# GUARD: no free tile of the hero's colour, and the original draws
		# forever.
		misses += 1
		if misses == LOOK_EVERYWHERE_AFTER and not _start_left(wanted):
			return Vector2i(-1, -1)
	return Vector2i(-1, -1)


func _start_fits(wanted: int, x: int, y: int) -> bool:
	return wanted & ShandalarWorld.magic_mask(_tile(x, y)) != 0 \
		and _flags(x, y) & ShandalarWorld.SITE == 0


func _start_left(wanted: int) -> bool:
	for y in 64:
		for x in 64:
			if _start_fits(wanted, x, y):
				return true
	return false


## C's integer division, which truncates toward zero.
static func _cdiv(a: int, b: int) -> int:
	var q := absi(a) / absi(b)
	return q if (a < 0) == (b < 0) else -q
