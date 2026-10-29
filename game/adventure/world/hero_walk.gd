class_name HeroWalk
extends RefCounted
## WALKING THE WORLD (the owner, 2026-10-22: *"place a walking figure on the
## map. We will guide that figure with pathfinding by clicking on a map"*).
##
## THE PACE IS THE 1997 GAME'S, tick for tick (`UpdateAdventureWorldInput
## AndMovement`, 0055e808 in 1.3, run once a tick of 60 ms):
##  - a step is one world unit (32 to a tile) in one of eight ways, the
##    same for a diagonal: a diagonal tile takes no longer than a straight;
##  - forest, and swamp without Amulet of Swampwalk, and mountains without
##    Dwarven Pick, are slow: two units every third tick;
##  - a road leaving the hero's tile the way they walk (or coming in from
##    behind) is never slow, and every other tick adds a unit more — every
##    tick while Quickening runs ([WorldMagic]), whose ticks count down;
##  - with no food every pace is slower (the divisor two more, at most 4);
##  - every 32nd tick a walking hero eats one food (Fruit of Sustenance
##    gives two back in a forest; [ours] an ascetic hero, chosen at the
##    Embark, eats on every other such tick, [member
##    AdventurePlayer.ascetic]) and the quest and siege clocks move on —
##    the siege clock's step begins or resolves a wizard's siege when it
##    says ([method Sieges.on_step], as 1997 did right there), whose news
##    waits in [member news] for the world screen to show — [ours] under
##    the sieges' pace "Rare" the siege clock on every 64th tick only
##    ([method Sieges.clock_steps]);
##  - a step into the sea near a tile's middle is taken back — [ours] only
##    a step from land: a step out of the sea stands ([method _shore]).
##
## THE WAY IS OURS [QoL]: the original walked where a key or a click
## pointed, one of eight ways from the hero, and stopped at water. Here a
## click is a destination and the way there is found around the water,
## costed by the same pace (Godot's [AStarGrid2D]); the hero walks it tile
## middle to tile middle, which are always one of the eight ways apart.
##
## THE KEYS WALK AS 1997'S DID (the owner's ruling of 2026-10-29: *"The
## arrow keys (and the keypad's 8 directions, two arrows for a diagonal)
## would walk the hero step by step while held, no pathfinding"*): a key
## set 1997's heading, one of the eight ways (`g_world_move_dir_index`,
## adventure_input.c 328–353), and the step above walked it. Here the keys
## held ([member keyed], [method WorldScreen._keyed_way]) walk the hero a
## tile at a time that way, no way found ([method key_toward], [method
## _key_on]), through the same step — the pace, the food and the clocks.
## [ours, the owner's ruling: 1997 queued a key's press, never its release
## (shandalar.c 1019–1021), so its heading stayed after the key was let go,
## until Space, the shore or a town (adventure_input.c 352–353, 612, 846);
## here the walk is the keys' while they are held, and let go the hero
## stops on the middle of the tile under way, as a click's walk ends.]
##
## THE SEA'S CORNERS [ours]. A diagonal step north-east or south-west
## between two land tiles stands for one tick on the corner of a third:
## from (x, y) to (x + 1, y − 1) the hero passes (32 (x + 1), 32 y), which
## is tile (x + 1, y) — often the sea, the way-finder cutting across the
## coast's corners, and 16 units from that tile's middle, so the shore
## rule lets it stand. A way planned on that tick (a click, or a game
## taken up again from a save made then) once started on the sea tile and
## its first step was taken back, every click again: the hero stood stuck
## for good (found 2026-10-23). Now a way starts on the land the hero
## stands by ([method _standing_tile]), only a step from land into the sea
## is taken back, and a walker made for a hero off the land sets them back
## on it ([method settle]) — which heals a save written before.
##
## THE FOOD FORESEEN [ours] (the path arrows, 0.50.66, [WorldPath]): a
## click's way is walked ahead on copies, tick by tick, through the step's
## own pace, stride and meal ([method forecast]) — which tiles the hero
## reaches with food left, which hungry.
##
## A TICK IN 1997'S ORDER (shandalar.c 625–655): the hero's step ([method
## step]), then the roaming creatures ([WorldCreatures], which read the clock
## as it stands), then [method end_tick] — Quickening's tick spent, the
## clock on by one. [method tick] runs the hero's part of a whole tick, for
## a walk without the creatures. The footsteps' sounds draw their own dice
## ([WorldSoundscape]): a walk moves the adventure's dice only through the
## creatures' refills and jumps, and the sieges begun ([Sieges]).

## Seconds a tick (the 1.3 loop waits `clock() - last_tick < 0x3c`).
const TICK := 0.06
## The divisor on slow land, and how long a step takes against plain land
## for the way-finder.
const SLOW := 3
const SLOW_COST := 1.5
const ROAD_COST := 2.0 / 3.0
## A step into the sea this near a tile's middle is taken back.
const SHORE := 12
## How near a tile's middle (world units, on each axis) the hero still
## stands on it for a key pressed ([method key_toward]): a second arrow
## pressed a tick after the first turns the walk from that middle, so two
## arrows walk the diagonal from the first step. Two units at most: from
## further a diagonal would cut a sea tile's corner within [constant
## SHORE] of its middle.
const TURN_SLACK := 2

var player: AdventurePlayer
## The tiles still to walk to, the next first.
var path: Array[Vector2i] = []
## The way walked this tick, 0–8 (`g_world_move_dir_index`).
var heading := 0
## Whether the last tick ran the move block (the pace's divisor allowed a
## step this tick, walking or standing) — when 1997 played a footstep and
## drew its colours' calls ([WorldSoundscape]).
var stepped := false
## Where the walk goes: the last tile of its way, (-1, -1) for none.
var destination := Vector2i(-1, -1)
## THE KEYS' WAY (1–8; 0 for none): the way the walking keys held point,
## set by the world screen before each tick ([method
## WorldScreen._keyed_way]). While the walk is the keys' ([member by_keys])
## each tile middle reached walks on to the next tile that way ([method
## _key_on]).
var keyed := 0
## Whether the walk is the keys' — a tile at a time, no way found ([method
## key_toward]) — rather than a click's ([method walk_to]).
var by_keys := false
## Whether this tick's step ended on the middle of a tile the walk went to
## ([method step]): the keys' walk arrives at every place it steps onto, as
## 1997's did ([method WorldScreen.advance]).
var at_middle := false
## THE SIEGES' NEWS the walk's steps brought ([method Sieges.on_step]), the
## oldest first, until the world screen takes it ([method take_news]).
var news: Array[Dictionary] = []
## THE WAY'S COUNT: one more each time the way is set anew — a click's walk,
## the keys', a stop — and not as its tiles are reached: how the path arrows
## ([WorldPath]) tell a new way from a step along the old one.
var plans := 0
## THE WAY-FINDER'S GRID of the world's land and its costs, kept between
## clicks (building it reads all 4,096 tiles: about 3 ms on a desk, 10 on
## a handheld) and built again when what shapes it changes — the world,
## Amulet of Swampwalk, Dwarven Pick ([method _grid_for]). A world's land
## never changes once made, so the world itself is the key to it.
var _grid: AStarGrid2D
var _grid_key: Array = []


## A walker for [param walker], set back on land if a save left them on
## the sea ([method settle]).
func _init(walker: AdventurePlayer = null) -> void:
	player = walker
	settle()


## A HERO OFF THE LAND is set on the middle of the land tile nearest them
## ([method _standing_tile]); true when they were moved. A save made while
## the hero crossed a sea tile's corner, or one written while a hero stood
## stuck on the sea (before the fix of 2026-10-23), is taken up again on
## land. [ours]
func settle() -> bool:
	if player == null or player.world == null:
		return false
	var here := player.tile()
	if player.world.is_land(here.x, here.y):
		return false
	player.position = _standing_tile() * 32 + Vector2i(16, 16)
	return true


func is_walking() -> bool:
	return not path.is_empty()


## The walk stopped where the hero stands — the keys' too: a key still held
## walks again only once pressed again ([method key_toward]).
func stop() -> void:
	path.clear()
	plans += 1
	heading = 0
	by_keys = false
	if player != null:
		player.step = 0


## Walk to [param target]: true when there is a way (to it, or to the land
## nearest it when it is sea or out of reach). The keys' walk is given up.
func walk_to(target: Vector2i) -> bool:
	var way := plan(target)
	if way.is_empty():
		return false
	path = way
	plans += 1
	destination = way[way.size() - 1]
	by_keys = false
	return true


## THE WALKING KEYS PRESSED toward [param d] (1–8 — 1997's ways, which the
## screen's keys point: [constant WorldScreen.WALK_KEYS]; 0, two keys
## against each other): the walk becomes the keys' — a click's way given up
## (the owner's ruling of 2026-10-29) — and goes a tile at a time that way,
## from a tile's middle: the one the hero stands on or has hardly left
## ([constant TURN_SLACK]), else the one the step under way reaches, else
## the middle of the tile they stand on (a walk stopped half way). A tap
## walks one tile. The tile that way is not walked onto when it is the sea
## [ours: 1997 walked on to the shore's very edge and took the step into
## the sea back there, the heading dropped (adventure_input.c 607–614);
## here the hero stands on the middle of the last land tile, as a click's
## walk ends]. Held, the walk goes on ([method _key_on]).
func key_toward(d: int) -> void:
	keyed = d
	var at := player.position
	var near := Vector2i(roundi((at.x - 16) / 32.0), roundi((at.y - 16) / 32.0))
	var start := _standing_tile()
	if absi(at.x - _middle(near).x) <= TURN_SLACK and absi(at.y - _middle(near).y) <= TURN_SLACK \
			and player.world.is_land(near.x, near.y):
		start = near
	elif not path.is_empty():
		start = path[0]
	path.clear()
	plans += 1
	if at != _middle(start):
		path.append(start)
	if d != 0:
		var next := start + Vector2i(ShandalarWorld.DX[d], ShandalarWorld.DY[d])
		if player.world.is_land(next.x, next.y):
			path.append(next)
	by_keys = true
	destination = path[path.size() - 1] if not path.is_empty() else Vector2i(-1, -1)
	if path.is_empty():
		heading = 0
		player.step = 0


## THE KEYS' NEXT TILE, the walk's middle reached with a key still held:
## the tile beside it the keys' way ([member keyed]) — 1997's heading
## walked on, step after step (adventure_input.c 516–606) — unless it is
## the sea or off the map ([method key_toward]); the hero stands then.
func _key_on() -> void:
	if not by_keys or keyed == 0:
		return
	var next := player.tile() + Vector2i(ShandalarWorld.DX[keyed], ShandalarWorld.DY[keyed])
	if player.world.is_land(next.x, next.y):
		path.append(next)
		plans += 1
		destination = next


## The middle of [param tile], in world units.
static func _middle(tile: Vector2i) -> Vector2i:
	return tile * 32 + Vector2i(16, 16)


## THE WAY from the hero's tile to [param target], the hero's tile first;
## [] when the hero cannot move at all. Sea and the map's edge are walls;
## slow land costs [constant SLOW_COST], a road [constant ROAD_COST]. A
## hero on a sea tile's corner starts from the land beside them
## ([method _standing_tile]).
func plan(target: Vector2i) -> Array[Vector2i]:
	var grid := _grid_for()
	var from := _standing_tile()
	if not grid.is_in_boundsv(from):
		return []
	var goal := target.clamp(Vector2i.ZERO, Vector2i(ShandalarWorld.TILES - 1, ShandalarWorld.TILES - 1))
	if grid.is_point_solid(goal):
		goal = _nearest_land(goal)
	# Only a world without land leaves the start in the sea; the grid is
	# kept, so it is given back as it was.
	var was_solid := grid.is_point_solid(from)
	grid.set_point_solid(from, false)
	var way := grid.get_id_path(from, goal, true)
	grid.set_point_solid(from, was_solid)
	var tiles: Array[Vector2i] = []
	for point in way:
		tiles.append(Vector2i(point))
	return tiles


## The tile a way starts from: the hero's own, or — when it is the sea (a
## diagonal step crossing its corner, or a hero once stuck there) — the
## land tile beside them whose middle is nearest, the one they walk to
## first on a tie; the nearest land of the map when none is beside them.
func _standing_tile() -> Vector2i:
	var world := player.world
	var here := player.tile()
	if world.is_land(here.x, here.y):
		return here
	var beside: Array[Vector2i] = []
	if not path.is_empty():
		beside.append(path[0])
	for d in range(1, 9):
		beside.append(here + Vector2i(ShandalarWorld.DX[d], ShandalarWorld.DY[d]))
	var best := Vector2i(-1, -1)
	var best_distance := INF
	for tile in beside:
		if maxi(absi(tile.x - here.x), absi(tile.y - here.y)) > 1 or not world.is_land(tile.x, tile.y):
			continue
		var distance := Vector2(player.position).distance_squared_to(Vector2(tile * 32 + Vector2i(16, 16)))
		if distance < best_distance:
			best = tile
			best_distance = distance
	return best if best.x >= 0 else _nearest_land(here)


## The way-finder's grid for the hero as they are now: the kept one, or a
## new one when the world or what is slow for the hero changed.
func _grid_for() -> AStarGrid2D:
	var key := [player.world.get_instance_id(), _slow(3), _slow(4)]
	if _grid == null or key != _grid_key:
		_grid = _build_grid()
		_grid_key = key
	return _grid


## The world's land as a grid: the sea solid, a road cheap, slow land dear.
func _build_grid() -> AStarGrid2D:
	var world := player.world
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(0, 0, ShandalarWorld.TILES, ShandalarWorld.TILES)
	grid.cell_size = Vector2.ONE
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ALWAYS
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_CHEBYSHEV
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_CHEBYSHEV
	grid.update()
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			var at := Vector2i(x, y)
			if not world.is_land(x, y):
				grid.set_point_solid(at, true)
			elif world.tile_flags(x, y) & ShandalarWorld.ROAD != 0:
				grid.set_point_weight_scale(at, ROAD_COST)
			elif _slow(world.terrain(x, y)):
				grid.set_point_weight_scale(at, SLOW_COST)
	return grid


func _nearest_land(target: Vector2i) -> Vector2i:
	var world := player.world
	var best := player.tile()
	var best_distance := 1 << 30
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			if world.is_land(x, y):
				var d := (x - target.x) * (x - target.x) + (y - target.y) * (y - target.y)
				if d < best_distance:
					best_distance = d
					best = Vector2i(x, y)
	return best


func _slow(code: int) -> bool:
	return code == 2 \
		or (code == 3 and not player.owns("Amulet of Swampwalk")) \
		or ((code == 4 or code == 5) and not player.owns("Dwarven Pick"))


## The way (1–8) from [param from] toward [param to], 0 when they meet.
static func way(from: Vector2i, to: Vector2i) -> int:
	var sx := signi(to.x - from.x)
	var sy := signi(to.y - from.y)
	for d in range(1, 9):
		if ShandalarWorld.DX[d] == sx and ShandalarWorld.DY[d] == sy:
			return d
	return 0


## The way back from [param d]: 1.3's `(d + 3 & 7) + 1`.
static func back(d: int) -> int:
	return ((d + 3) & 7) + 1


## ONE TICK of the world without the creatures: the hero's step, then the
## clock on ([method step], [method end_tick]). True when the step brought
## the hero onto another tile.
func tick() -> bool:
	var entered := step()
	end_tick()
	return entered


## THE HERO'S STEP this tick (`UpdateAdventureWorldInputAndMovement`), the
## clock read as it stands — the creatures move after it, before [method
## end_tick]. True when the step brought the hero onto another tile. The
## pace, the stride and the meal are [method pace], [method stride] and
## [method meal], which the food forecast runs too ([method forecast]).
func step() -> bool:
	_arrive()
	at_middle = false
	var target := Vector2i(-1, -1)
	if not path.is_empty():
		target = path[0] * 32 + Vector2i(16, 16)
		heading = way(player.position, target)
	else:
		heading = 0
	var entered := false
	var d := heading
	var here := player.tile()
	var divisor := pace(player.position, d, player.food == 0)
	stepped = player.monster_timer % divisor == 0
	if stepped:
		var before := player.position
		player.position = stride(before, d, divisor, player.monster_timer, player.quickening, target)
		player.step += 1
		if player.step > 4:
			player.step = 1
		if d == 0:
			player.step = 0
		else:
			player.facing = d
		var now := player.tile()
		if _shore(before):
			player.position = before
			stop()
		if player.monster_timer & 0x1F == 0 and d != 0:
			player.food = meal(player.food, now)
			player.quest_timer += 1
			# Half as often under the sieges' pace "Rare" [ours, the owner's
			# ruling of 2026-10-28] ([method Sieges.clock_steps]).
			if Sieges.clock_steps(player):
				player.siege_timer += 1
				news.append_array(Sieges.on_step(player))
		entered = player.tile() != here
	_arrive()
	return entered


## THE PACE of a step from [param at] (world units) the way [param d]: its
## divisor — the step is taken on the ticks the clock divides by it ([method
## step]). Slow land ([method _slow]) three, else one; one on a road leaving
## the tile that way or coming in from behind; [param hungry], two more, at
## most four. ONE PACE for the walk and for the food it foresees ([method
## forecast]; the path arrows, 0.50.66), so the two never drift.
func pace(at: Vector2i, d: int, hungry: bool) -> int:
	var world := player.world
	var ahead := at + Vector2i(ShandalarWorld.DX[d], ShandalarWorld.DY[d])
	var divisor := SLOW if _slow(world.terrain(ahead.x / 32, ahead.y / 32)) else 1
	var roads := world.road_bits(at.x / 32, at.y / 32)
	if d != 0 and (roads & (1 << (d - 1)) != 0 or roads & (1 << (back(d) - 1)) != 0):
		divisor = 1
	if hungry:
		divisor = clampi(divisor + 2, 0, 4)
	return divisor


## THE STRIDE of a step taken ([method pace]'s [param divisor] allowing it)
## from [param at] the way [param d] toward the tile middle [param target],
## on clock tick [param timer] with [param quickening] ticks of Quickening
## left: where it takes the hero. Two units on slow land, else one; a unit
## more on every tick of Quickening, and on every other tick on a road
## coming in from behind; [ours] never past the middle, on either axis.
func stride(at: Vector2i, d: int, divisor: int, timer: int, quickening: int, target: Vector2i) -> Vector2i:
	var dv := Vector2i(ShandalarWorld.DX[d], ShandalarWorld.DY[d])
	var now := at + dv * (2 if divisor == SLOW else 1)
	var roads := player.world.road_bits(at.x / 32, at.y / 32)
	if d != 0 and (quickening > 0 or timer & 1 != 0 and roads & (1 << (back(d) - 1)) != 0):
		now += dv
	if d != 0:
		now = Vector2i(_not_past(at.x, now.x, target.x), _not_past(at.y, now.y, target.y))
	return now


## THE MEAL of a walking hero's 32nd tick, on tile [param tile]: [param
## food] less the one eaten — every other step for an ascetic hero [ours,
## the owner's ruling of 2026-10-29] ([method
## AdventurePlayer.eats_this_step]) — and two given back by Fruit of
## Sustenance in a forest.
func meal(food: int, tile: Vector2i) -> int:
	if food != 0 and player.eats_this_step():
		food -= 1
	if player.owns("Fruit of Sustenance") and player.world.terrain(tile.x, tile.y) == 2:
		food += 2
	return food


## THE FOOD FORESEEN along [param tiles] — a way's tiles still to walk to,
## the next first — for the path arrows ([WorldPath]; the owner's ruling of
## 2026-10-29: the steps the food covers in one colour, the hungry ones in
## another) [ours]: for each tile, 1 when the hero reaches its middle with
## food left, else 0. The walk's own ticks are run from where the hero
## stands, on copies of their place, food, the clock and Quickening's ticks
## ([method pace], [method stride], [method meal]; an ascetic's half-meal
## put back after) — tick for tick what the walk will do, unless a creature
## met or a siege's news stops it first. The shore rule never takes a step
## of a way found on land back, so it is not run.
func forecast(tiles: Array[Vector2i]) -> PackedByteArray:
	var fed := PackedByteArray()
	fed.resize(tiles.size())
	if player == null or player.world == null:
		return fed
	var at := player.position
	var food := player.food
	var timer := player.monster_timer
	var quickening := player.quickening
	var half := player.meal_half
	var i := 0
	# The slowest tile is 128 ticks (hungry on slow land: a unit every fourth).
	var most := tiles.size() * 160 + 160
	var ticks := 0
	while i < tiles.size() and ticks < most:
		var middle := tiles[i] * 32 + Vector2i(16, 16)
		if at == middle:
			fed[i] = 1 if food > 0 else 0
			i += 1
			continue
		var d := way(at, middle)
		var divisor := pace(at, d, food == 0)
		if timer % divisor == 0:
			at = stride(at, d, divisor, timer, quickening, middle)
			if timer & 0x1F == 0:
				food = meal(food, Vector2i(at.x / 32, at.y / 32))
		# The tick's end ([method end_tick]).
		if quickening > 0:
			quickening -= 1
		timer += 1
		ticks += 1
	player.meal_half = half
	return fed


## The sieges' news brought so far ([member news]), taken: none is left.
func take_news() -> Array[Dictionary]:
	var taken := news
	news = [] as Array[Dictionary]
	return taken


## THE TICK'S END, after the creatures: Quickening's tick spent
## (`TickWorldMagicSlotTimers`, once a pass of the 1.3 loop), then the
## world's clock on by one (`g_monster_timer += 1`).
func end_tick() -> void:
	if player.quickening > 0:
		player.quickening -= 1
	player.monster_timer += 1


## THE SHORE: whether the step from [param before] to where the hero now
## stands goes into the sea near a tile's middle — 1.3 takes such a step
## back. [ours] Only a step from land: a hero on the sea (a tile's corner)
## walks back onto land rather than being held there.
func _shore(before: Vector2i) -> bool:
	var world := player.world
	var now := player.tile()
	var was := Vector2i(before.x / 32, before.y / 32)
	if world.terrain(now.x, now.y) != ShandalarWorld.OCEAN or not world.is_land(was.x, was.y):
		return false
	var middle := now * 32 + Vector2i(16, 16)
	return absi(player.position.x - middle.x) < SHORE or absi(player.position.y - middle.y) < SHORE


## [param now] on one axis, held at [param target] if the step from
## [param before] went past it.
static func _not_past(before: int, now: int, target: int) -> int:
	if before < target and now > target or before > target and now < target:
		return target
	return now


## The tile middle walked to is reached: on to the next — with a walking
## key held, the next tile its way ([method _key_on]), the hero never
## standing between the two.
func _arrive() -> void:
	while not path.is_empty() and player.position == path[0] * 32 + Vector2i(16, 16):
		path.remove_at(0)
		at_middle = true
	if path.is_empty():
		_key_on()
	if path.is_empty() and heading != 0:
		heading = 0
		player.step = 0
