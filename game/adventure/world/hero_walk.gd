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
##    gives two back in a forest) and the quest and siege clocks move on;
##  - a step into the sea near a tile's middle is taken back.
##
## THE WAY IS OURS [QoL]: the original walked where a key or a click
## pointed, one of eight ways from the hero, and stopped at water. Here a
## click is a destination and the way there is found around the water,
## costed by the same pace (Godot's [AStarGrid2D]); the hero walks it tile
## middle to tile middle, which are always one of the eight ways apart.
##
## NOT YET: the original draws dice each step for the footstep's sound and
## moves the roaming creatures and sieges on the same ticks; neither is
## made, so the adventure's dice stand still while the hero walks.

## Seconds a tick (the 1.3 loop waits `clock() - last_tick < 0x3c`).
const TICK := 0.06
## The divisor on slow land, and how long a step takes against plain land
## for the way-finder.
const SLOW := 3
const SLOW_COST := 1.5
const ROAD_COST := 2.0 / 3.0
## A step into the sea this near a tile's middle is taken back.
const SHORE := 12

var player: AdventurePlayer
## The tiles still to walk to, the next first.
var path: Array[Vector2i] = []
## The way walked this tick, 0–8 (`g_world_move_dir_index`).
var heading := 0
## Where the walk goes: the last tile of its way, (-1, -1) for none.
var destination := Vector2i(-1, -1)


func _init(walker: AdventurePlayer = null) -> void:
	player = walker


func is_walking() -> bool:
	return not path.is_empty()


func stop() -> void:
	path.clear()
	heading = 0
	if player != null:
		player.step = 0


## Walk to [param target]: true when there is a way (to it, or to the land
## nearest it when it is sea or out of reach).
func walk_to(target: Vector2i) -> bool:
	var way := plan(target)
	if way.is_empty():
		return false
	path = way
	destination = way[way.size() - 1]
	return true


## THE WAY from the hero's tile to [param target], the hero's tile first;
## [] when the hero cannot move at all. Sea and the map's edge are walls;
## slow land costs [constant SLOW_COST], a road [constant ROAD_COST].
func plan(target: Vector2i) -> Array[Vector2i]:
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
	var from := player.tile()
	if not grid.is_in_boundsv(from):
		return []
	var goal := target.clamp(Vector2i.ZERO, Vector2i(ShandalarWorld.TILES - 1, ShandalarWorld.TILES - 1))
	if grid.is_point_solid(goal):
		goal = _nearest_land(goal)
	var was_solid := grid.is_point_solid(from)
	grid.set_point_solid(from, false)
	var way := grid.get_id_path(from, goal, true)
	grid.set_point_solid(from, was_solid)
	var tiles: Array[Vector2i] = []
	for point in way:
		tiles.append(Vector2i(point))
	return tiles


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


## ONE TICK of the world: the clock goes on and the hero takes their step.
## True when the step brought the hero onto another tile.
func tick() -> bool:
	var world := player.world
	_arrive()
	var target := Vector2i(-1, -1)
	if not path.is_empty():
		target = path[0] * 32 + Vector2i(16, 16)
		heading = way(player.position, target)
	else:
		heading = 0
	var entered := false
	var d := heading
	var ahead := player.position + Vector2i(ShandalarWorld.DX[d], ShandalarWorld.DY[d])
	var kind := world.terrain(ahead.x / 32, ahead.y / 32)
	var divisor := SLOW if _slow(kind) else 1
	var here := player.tile()
	var roads := world.road_bits(here.x, here.y)
	if d != 0 and (roads & (1 << (d - 1)) != 0 or roads & (1 << (back(d) - 1)) != 0):
		divisor = 1
	if player.food == 0:
		divisor = clampi(divisor + 2, 0, 4)
	if player.monster_timer % divisor == 0:
		var before := player.position
		var stride := 2 if divisor == SLOW else 1
		player.position += Vector2i(ShandalarWorld.DX[d], ShandalarWorld.DY[d]) * stride
		player.step += 1
		if player.step > 4:
			player.step = 1
		if d == 0:
			player.step = 0
		else:
			player.facing = d
		if d != 0 and (player.quickening > 0
				or player.monster_timer & 1 != 0 and roads & (1 << (back(d) - 1)) != 0):
			player.position += Vector2i(ShandalarWorld.DX[d], ShandalarWorld.DY[d])
		# Ours: never past the tile middle being walked to, on either axis.
		if d != 0:
			player.position = Vector2i(_not_past(before.x, player.position.x, target.x),
				_not_past(before.y, player.position.y, target.y))
		var now := player.tile()
		var middle := now * 32 + Vector2i(16, 16)
		if world.terrain(now.x, now.y) == ShandalarWorld.OCEAN and (
				absi(player.position.x - middle.x) < SHORE or absi(player.position.y - middle.y) < SHORE):
			player.position = before
			stop()
		if player.monster_timer & 0x1F == 0 and d != 0:
			if player.food != 0:
				player.food -= 1
			if player.owns("Fruit of Sustenance") and world.terrain(now.x, now.y) == 2:
				player.food += 2
			player.siege_timer += 1
			player.quest_timer += 1
		entered = player.tile() != here
	player.monster_timer += 1
	# `TickWorldMagicSlotTimers`, once a pass of the 1.3 loop.
	if player.quickening > 0:
		player.quickening -= 1
	_arrive()
	return entered


## [param now] on one axis, held at [param target] if the step from
## [param before] went past it.
static func _not_past(before: int, now: int, target: int) -> int:
	if before < target and now > target or before > target and now < target:
		return target
	return now


## The tile middle walked to is reached: on to the next.
func _arrive() -> void:
	while not path.is_empty() and player.position == path[0] * 32 + Vector2i(16, 16):
		path.remove_at(0)
	if path.is_empty() and heading != 0:
		heading = 0
		player.step = 0
