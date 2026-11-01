class_name RegionObjectives
extends RefCounted
## Geography queries shared by generators and quests. Stable selection, no dice
## consumed and no existing terrain or settlements moved to repair old maps.

static func matches(world: ShandalarWorld, tile: Vector2i, rule: Dictionary) -> bool:
	if not world.is_land(tile.x, tile.y): return false
	if rule.get("coastal", false) and not RegionGeography.coast(world, tile): return false
	if rule.get("road", false) and world.tile_flags(tile.x, tile.y) & ShandalarWorld.ROAD == 0: return false
	if rule.has("near_terrain"):
		var found := false
		var radius := int(rule.get("radius", 2))
		for y in range(tile.y - radius, tile.y + radius + 1):
			for x in range(tile.x - radius, tile.x + radius + 1):
				if world.terrain(x, y) == int(rule["near_terrain"]): found = true
		if not found: return false
	return true

static func site(world: ShandalarWorld, rule: Dictionary, preferred := -1) -> int:
	var candidates: Array[int] = []
	for slot in world.sites.size():
		if slot in rule.get("exclude", []): continue
		var place: Dictionary = world.sites[slot]
		if int(place.get("type", 0)) not in rule.get("types", [ShandalarWorld.VILLAGE, ShandalarWorld.TOWN, ShandalarWorld.CITY]): continue
		if matches(world, Vector2i(place["x"], place["y"]), rule): candidates.append(slot)
	if preferred in candidates: return preferred
	return candidates[0] if not candidates.is_empty() else -1

static func tile(data: Dictionary, slot: int) -> Vector2i:
	var sites: Array = data.get("sites", [])
	if slot < 0 or slot >= sites.size(): return Vector2i(-1, -1)
	return Vector2i(int(sites[slot].get("x", -1)), int(sites[slot].get("y", -1)))

static func site_name(data: Dictionary, slot: int) -> String:
	var sites: Array = data.get("sites", [])
	if slot < 0 or slot >= sites.size(): return ""
	var named: String = data.get("expansion", {}).get("town_names", {}).get(str(slot), "")
	if named != "": return named
	var first: String = WorldNames.FIRST_HALVES[clampi((slot / 8) % 16, 0, 15)]
	return first + " Village" if int(sites[slot].get("type", 0)) == ShandalarWorld.VILLAGE else first + " " + WorldNames.SECOND_HALVES[clampi(slot % 16, 0, 15)]
