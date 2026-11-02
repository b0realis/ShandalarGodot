class_name AdventureRegions
extends RefCounted
## Shared travel and persistence. Only the active region is a live world;
## inactive regions are value snapshots. Hero effects and lifetime totals travel.

const MAINLAND := "mainland"
const RECORD := ["quest", "quest_offer", "last_town", "town_quests", "wise_man", "links_taken"]
const CLOCKS := ["monster_timer", "quest_timer", "siege_timer", "siege_active"]

static func id(world: ShandalarWorld) -> String:
	return String(world.expansion.get("region", MAINLAND)) if world != null else MAINLAND

static func mainland(player: AdventurePlayer) -> bool:
	return player != null and id(player.world) == MAINLAND

static func snapshot(player: AdventurePlayer) -> Dictionary:
	var saved := player.to_dict(false)
	var record := {}
	var clocks := {}
	for key in RECORD: record[key] = saved["record"][key]
	for key in CLOCKS: clocks[key] = saved["clocks"][key]
	return {"world": saved["world"], "where": saved["where"], "clocks": clocks, "record": record}.duplicate(true)

static func restore(player: AdventurePlayer, region: Dictionary) -> void:
	var saved: Dictionary = region["world"]
	player.world = AdventurePlayer._world_from(saved, Vector2i.ZERO)
	AdventurePlayer._read_where(player, region["where"])
	var current := player.to_dict(false)
	for key in CLOCKS: current["clocks"][key] = region["clocks"].get(key, 0 if key != "siege_active" else false)
	AdventurePlayer._read_clocks(player, current["clocks"])
	for key in RECORD: current["record"][key] = region["record"].get(key, current["record"][key])
	AdventurePlayer._read_record(player, current["record"])
	player.world_seed_text = str(saved.get("seed_text", player.world.seed))
	player.made_fingerprint = str(saved.get("made_fingerprint", ""))
	player.dice = int(saved.get("dice", player.world.rand_state))
	player.monsters = AdventurePlayer._cleaned_monsters(saved.get("monsters"), player.world)
	player.shops = AdventurePlayer._cleaned_shops(saved.get("shops"), player.world)
	player.step = 0
	# New regions and restored regions obey the same campaign rules as Embark.
	player.treasures_by_the_ban_list()
	AdventureExpansions.sync_choices(player)

static func travel(player: AdventurePlayer, destination: String, make_world := Callable()) -> bool:
	if player == null or player.world == null: return false
	var leaving := id(player.world)
	if leaving == destination: return false
	player.journey_time = player.journey_steps()
	var arriving: Dictionary = player.regions.get(destination, {})
	if arriving.is_empty():
		if destination == MAINLAND or not make_world.is_valid(): return false
		var made: ShandalarWorld = make_world.call()
		if made == null or id(made) != destination: return false
		var fresh := AdventurePlayer.new()
		fresh.world = made
		fresh.position = made.start
		fresh.dice = made.rand_state
		fresh.made_fingerprint = made.fingerprint()
		arriving = snapshot(fresh)
	if not valid_snapshot(arriving, destination): return false
	player.regions[leaving] = snapshot(player)
	restore(player, arriving)
	player.regions.erase(destination)
	player.entered_tile = player.tile()
	AdventureExpansions.entered(player)
	return true

static func extra_links(player: AdventurePlayer) -> int:
	var count := 0
	for key in player.regions:
		if key != MAINLAND and not bool(AdventureExpansions.definition(key).get("mana_links", false)): continue
		var region: Dictionary = player.regions[key]
		for site in region.get("world", {}).get("sites", []):
			if site is Dictionary and int(site.get("type", 0)) in [ShandalarWorld.TOWN, ShandalarWorld.CITY] and int(site.get("status", 0)) & TownStatus.LINKED != 0 and int(site.get("status", 0)) & TownStatus.RULER_MASK == 0:
				count += 1
	return count

static func saved_regions(data: Dictionary) -> Variant:
	return data.get("regions", data.get("refuge", {}).get("regions", {}) if data.get("refuge", {}) is Dictionary else null)

static func saved_progress(data: Dictionary) -> Variant:
	if data.has("expansions"): return data["expansions"]
	var old: Variant = data.get("refuge", {})
	if not old is Dictionary: return null
	if old.is_empty(): return {}
	var state: Dictionary = old.duplicate(true)
	state.erase("regions")
	return {"refuge": state}

static func read(player: AdventurePlayer, data: Dictionary) -> void:
	player.regions = saved_regions(data).duplicate(true)
	player.expansions = AdventurePlayer._whole(saved_progress(data))
	var totals: Dictionary = data.get("journey", {}) if data.get("journey", {}) is Dictionary else {}
	# Old saves kept these counters per region. Sum them once on migration.
	var days := player.quest_timer
	var lairs := player.lairs_explored
	var sieges := player.siege_count
	if int(data.get("version", 1)) < 5:
		for region in player.regions.values():
			days += AdventurePlayer._count(region.get("clocks", {}).get("quest_timer"))
			lairs += AdventurePlayer._count(region.get("record", {}).get("lairs_explored"))
			sieges += AdventurePlayer._count(region.get("clocks", {}).get("siege_count"))
	player.journey_time = AdventurePlayer._count(totals.get("time", days))
	player.lairs_explored = lairs
	player.siege_count = sieges
	# New journal entries use the lifetime clock; old ones explicitly say region day.
	if int(data.get("version", 1)) < 5:
		for entry in player.journal: entry["regional_day"] = true

static func valid_saved(data: Dictionary) -> bool:
	var regions: Variant = saved_regions(data)
	var progress: Variant = saved_progress(data)
	if not regions is Dictionary or not progress is Dictionary: return false
	var active := String(data["world"].get("expansion", {}).get("region", MAINLAND)) if data["world"].get("expansion", {}) is Dictionary else ""
	if not valid_world(data["world"], active): return false
	for key in regions:
		if not key is String or key == active or not regions[key] is Dictionary or not valid_snapshot(regions[key], key): return false
	for key in progress:
		if not key is String or not progress[key] is Dictionary or not AdventureExpansions.valid_progress(key, progress[key]): return false
	return active == MAINLAND or regions.has(MAINLAND)

static func valid_snapshot(region: Dictionary, key: String) -> bool:
	for part in ["world", "where", "clocks", "record"]:
		if not region.get(part) is Dictionary: return false
	return valid_world(region["world"], key)

static func valid_world(saved: Dictionary, key: String) -> bool:
	if key == "" or not AdventurePlayer._grid_whole(saved.get("grid")): return false
	var extra: Variant = saved.get("expansion", {})
	if not extra is Dictionary or extra.get("region", MAINLAND) != key: return false
	if not WorldTerrainPalette.valid_appearance(extra.get("appearance", {})): return false
	for field in ["town_names", "dungeon_names"]:
		if not extra.get(field, {}) is Dictionary: return false
		for name in extra.get(field, {}).values():
			if not name is String: return false
	var objectives: Variant = extra.get("objectives", {})
	if not objectives is Dictionary: return false
	for slot in objectives.values():
		if not AdventurePlayer._is_number(slot) or int(slot) != slot or slot < -1 or slot >= 128: return false
	var banners: Variant = extra.get("banners", [])
	if not banners is Array or banners.size() > 256: return false
	for banner in banners:
		if not banner is Dictionary or not valid_point(banner.get("point")) or not banner.get("color") is String: return false
		for field in ["anchor", "size"]:
			if not banner.has(field): continue
			if not banner[field] is Array or banner[field].size() != 2: return false
			for value in banner[field]:
				if not AdventurePlayer._is_number(value) or value < (-256 if field == "anchor" else 1) or value > 256: return false
	var used := {}
	for mark in ["port", "castle"]:
		if not extra.has(mark):
			if key != MAINLAND and mark in AdventureExpansions.definition(key).get("required_markers", ["port", "castle"]): return false
			continue
		if not valid_point(extra[mark]): return false
		var point: Array = extra[mark]
		var tile := Vector2i(int(point[0]), int(point[1]))
		if used.has(tile) or String(saved["grid"][tile.y]).hex_decode()[tile.x] & 15 == 0: return false
		used[tile] = true
	if not extra.get("entries", {}) is Dictionary: return false
	for point in extra.get("entries", {}).values():
		if not valid_point(point): return false
	var sites: Variant = saved.get("sites", [])
	if not sites is Array: return key == MAINLAND
	for index in AdventureExpansions.definition(key).get("required_sites", []):
		if index >= sites.size() or not sites[index] is Dictionary: return false
		var site: Dictionary = sites[index]
		if not AdventurePlayer._is_number(site.get("type")) or int(site["type"]) not in [ShandalarWorld.TOWN, ShandalarWorld.CITY]: return false
		if not valid_point([site.get("x"), site.get("y")]): return false
		var tile := Vector2i(int(site["x"]), int(site["y"]))
		if used.has(tile) or String(saved["grid"][tile.y]).hex_decode()[tile.x] & 15 == 0: return false
		used[tile] = true
	return true

static func valid_point(value: Variant) -> bool:
	if not value is Array or value.size() != 2: return false
	for n in value:
		if not AdventurePlayer._is_number(n) or int(n) != n or n < 0 or n >= 64: return false
	return true
