class_name RefugeRoads
extends RefCounted
## Regional roads join neighboring settlements, favor easy terrain and
## existing lanes, and can turn in all eight map directions.

static func build(world: ShandalarWorld, places: Array[Vector2i], dice: MsvcRandom) -> void:
	if places.size() < 2:
		return
	# A coarse, seeded cost field gives routes broad bends rather than a
	# fresh random decision at every step. It is shared by all roads.
	var costs := {}
	for y in range(0, 64, 4):
		for x in range(0, 64, 4):
			costs[Vector2i(x / 4, y / 4)] = dice.below(14)
	var linked: Array[Vector2i] = [places[0]]
	var left := places.duplicate()
	left.remove_at(0)
	while not left.is_empty():
		var from := linked[0]
		var pick := 0
		var best := INF
		for a in linked:
			for i in left.size():
				var distance := a.distance_squared_to(left[i])
				if distance < best:
					best = distance
					from = a
					pick = i
		var to: Vector2i = left.pop_at(pick)
		join(world, from, to, costs)
		linked.append(to)
	# One additional local link offers a loop without covering the island
	# with a complete graph of roads.
	var first := dice.below(places.size())
	var second := (first + 1 + dice.below(places.size() - 1)) % places.size()
	join(world, places[first], places[second], costs)

static func step_allowed(world: ShandalarWorld, from: Vector2i, to: Vector2i) -> bool:
	if not world.is_land(to.x, to.y):
		return false
	var delta := to - from
	if absi(delta.x) == 1 and absi(delta.y) == 1:
		return world.is_land(from.x + delta.x, from.y) and world.is_land(from.x, from.y + delta.y)
	return absi(delta.x) + absi(delta.y) == 1

static func _cost(world: ShandalarWorld, tile: Vector2i, costs: Dictionary) -> int:
	if world.road_bits(tile.x, tile.y) != 0:
		return 5
	var terrain := world.terrain(tile.x, tile.y)
	var value := 12
	match terrain:
		5: value = 36  # mountains
		3, 8, 13: value = 28  # swamps and their borders
		2, 10, 15: value = 18  # woods and their borders
	return value + int(costs.get(Vector2i(tile.x / 4, tile.y / 4), 0))

static func join(world: ShandalarWorld, from: Vector2i, to: Vector2i, costs: Dictionary) -> void:
	var open: Array[Vector2i] = [from]
	var distance := {from: 0}
	var parents := {from: from}
	var closed := {}
	while not open.is_empty():
		var pick := 0
		for i in range(1, open.size()):
			if int(distance[open[i]]) < int(distance[open[pick]]):
				pick = i
		var tile: Vector2i = open.pop_at(pick)
		if tile == to:
			break
		closed[tile] = true
		for d in range(1, 9):
			var next := tile + Vector2i(ShandalarWorld.DX[d], ShandalarWorld.DY[d])
			if closed.has(next) or not step_allowed(world, tile, next):
				continue
			var weight := _cost(world, next, costs) * (14 if d % 2 == 0 else 10)
			var candidate := int(distance[tile]) + weight
			if candidate < int(distance.get(next, 0x7FFFFFFF)):
				distance[next] = candidate
				parents[next] = tile
				if not next in open:
					open.append(next)
	var tile := to
	while tile != from and parents.has(tile):
		var previous: Vector2i = parents[tile]
		for d in range(1, 9):
			if previous + Vector2i(ShandalarWorld.DX[d], ShandalarWorld.DY[d]) == tile:
				var reverse := (d + 3) % 8 + 1
				world.page[(previous.y + 64) * 320 + previous.x] |= 1 << (d - 1)
				world.page[(tile.y + 64) * 320 + tile.x] |= 1 << (reverse - 1)
				world.page[previous.y * 320 + previous.x] |= ShandalarWorld.ROAD
				world.page[tile.y * 320 + tile.x] |= ShandalarWorld.ROAD
				break
		tile = previous
