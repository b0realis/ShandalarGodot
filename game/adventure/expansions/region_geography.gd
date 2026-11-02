class_name RegionGeography
extends RefCounted
## Shared connected-land and safe coastal-entry placement. Never changes terrain
## or consumes the mainland random stream. Existing places keep their coordinates.

static func component(world: ShandalarWorld, start: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not world.is_land(start.x, start.y):
		return out
	var seen := {start: true}
	out.append(start)
	var i := 0
	while i < out.size():
		var at := out[i]
		i += 1
		for d in [1, 3, 5, 7]:
			var next := at + Vector2i(ShandalarWorld.DX[d], ShandalarWorld.DY[d])
			if not seen.has(next) and world.is_land(next.x, next.y):
				seen[next] = true
				out.append(next)
	return out

static func coast(world: ShandalarWorld, tile: Vector2i) -> bool:
	for d in [1, 3, 5, 7]:
		if not world.is_land(tile.x + ShandalarWorld.DX[d], tile.y + ShandalarWorld.DY[d]):
			return true
	return false

static func port_for(world: ShandalarWorld, from: Vector2i, excluded: Array = []) -> Vector2i:
	var best := Vector2i(-1, -1)
	var score := INF
	for tile in component(world, from):
		if not coast(world, tile) or world.tile_flags(tile.x, tile.y) & (ShandalarWorld.SITE | ShandalarWorld.DUNGEON):
			continue
		var clear := true
		for site in world.sites:
			if int(site["type"]) > 0 and tile.distance_to(Vector2i(site["x"], site["y"])) < 3.0:
				clear = false
		for encounter in world.encounters:
			if tile.distance_to(Vector2i(encounter.get("x", 0), encounter.get("y", 0))) < 3.0:
				clear = false
		for point in excluded:
			if tile.distance_to(Vector2i(int(point[0]), int(point[1]))) < 4.0: clear = false
		var distance := tile.distance_squared_to(from)
		if clear and distance < score:
			best = tile
			score = distance
	return best


## When coast space runs out, ships share a safe existing anchorage. This keeps
## every destination available without moving towns or changing the mainland.
static func entry_for(world: ShandalarWorld, from: Vector2i, excluded: Array) -> Vector2i:
	var tile := port_for(world, from, excluded)
	if tile.x < 0 and not excluded.is_empty(): tile = Vector2i(int(excluded[0][0]), int(excluded[0][1]))
	return tile
