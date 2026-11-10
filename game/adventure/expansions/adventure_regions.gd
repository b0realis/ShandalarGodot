class_name AdventureRegions
extends RefCounted
## Shared travel and persistence. Only the active region is a live world;
## inactive regions are value snapshots. Hero effects and lifetime totals travel.

const MAINLAND := "mainland"
const RECORD := ["quest", "quest_offer", "last_town", "town_quests", "wise_man", "links_taken"]
const CLOCKS := ["monster_timer", "quest_timer", "siege_timer", "siege_active"]
## The places every world is made with (the 1997 site table's 128 slots).
const SITE_SLOTS := 128

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
	_voyaged(player)
	# The campaign's seed text travels with every region (h1-3).
	var text: Variant = saved.get("seed_text", "")
	if text is String and text != "":
		player.world_seed_text = text
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
		fresh.world_seed_text = player.world_seed_text  # the campaign's (h1-3)
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

## The regions of a save (`regions`; none in a save of the vanilla
## adventure). The owner, 2026-11-10: *"You can break old extended
## adventure! It was never shipped"* — the built-in Last Refuge's own shapes
## of 0.60.5–0.60.18 are not read: a save that carried its island inside
## them is refused when it stands there, and loses it otherwise.
static func saved_regions(data: Dictionary) -> Variant:
	return data.get("regions", {})

## The lands' progress of a save (`expansions`). A land whose plugin is
## missing keeps its progress as it is ([method ExpansionContract.opaque_progress]).
static func saved_progress(data: Dictionary) -> Variant:
	return data.get("expansions", {})

static func read(player: AdventurePlayer, data: Dictionary) -> void:
	# Whole numbers made whole again, as every other part of the save is read
	# (RV2-6): a save read and written again is the same text.
	player.regions = AdventurePlayer._whole(saved_regions(data))
	player.expansions = AdventurePlayer._whole(saved_progress(data))
	# The lands the installed versions cannot read, held for this session.
	player.held_lands = {}
	for key: String in saved_state(data)["changed"]:
		player.held_lands[key] = true
	var totals: Dictionary = data.get("journey", {}) if data.get("journey", {}) is Dictionary else {}
	# A save from before the journey's clock (version 4 and older): its one
	# world's clock.
	player.journey_time = AdventurePlayer._count(totals.get("time", player.quest_timer))
	# Old journal lines read "Day N: …" as they always did, with no region —
	# the owner's ruling of 2026-11-03 ("Region only with an island"); the
	# "Region day" mark 0.60.6–0.60.12 gave them is dropped (0.60.13 bug
	# campaign, h2-Q2/h3-Q1).
	for entry in player.journal: entry.erase("regional_day")
	if player.world_seed_text == "":
		player.world_seed_text = seed_text(data)

## THE CAMPAIGN'S WORLD SEED as the player typed it, from save [param data]
## (the load list's reading too): the world's, else the seed's number; ""
## when the save holds none.
static func seed_text(data: Dictionary) -> String:
	var world: Variant = data.get("world")
	if not world is Dictionary: return ""
	var text: Variant = world.get("seed_text")
	if text is String and text != "": return text
	var number: Variant = world.get("seed")
	return str(int(number)) if AdventurePlayer._is_number(number) else ""

## A region other than the mainland is never a new adventure: at clock 0 a
## save made on landing loaded as one, replaying the new adventure's reveal
## ([WorldScreen]; 0.60.13 bug campaign, h1-5). The voyage takes the
## region's first tick; the clock stays its own, so the creatures of a
## fresh island still wait as on a fresh world.
static func _voyaged(player: AdventurePlayer) -> void:
	if not mainland(player) and player.monster_timer == 0:
		player.monster_timer = 1

## Whether [param data]'s regions and lands' progress may be read at all
## ([method saved_state]).
static func valid_saved(data: Dictionary) -> bool:
	return bool(saved_state(data)["ok"])


## A SAVE'S LANDS AGAINST WHAT IS INSTALLED NOW (adventure plugins,
## 2026-11-10; the lead's rule on the guide writer's finding): `{ok, changed}`
## — ok false for damage, which refuses the save as ever; `changed` the lands
## whose saved map or progress the installed version cannot read (a town
## moved, a quest taken out), held as a missing plugin's land is held
## ([method AdventureExpansions.held]) — never a reason to refuse the save.
static func saved_state(data: Dictionary) -> Dictionary:
	var changed: Array[String] = []
	var out := {"ok": false, "changed": changed}
	var regions: Variant = saved_regions(data)
	var progress: Variant = saved_progress(data)
	if not regions is Dictionary or not progress is Dictionary: return out
	var active := String(data["world"].get("expansion", {}).get("region", MAINLAND)) if data["world"].get("expansion", {}) is Dictionary else ""
	var fit := world_state(data["world"], active)
	if fit == ExpansionContract.BROKEN: return out
	if fit == ExpansionContract.CHANGED: changed.append(active)
	for key: Variant in regions:
		if not key is String or key == active or not regions[key] is Dictionary: return out
		fit = snapshot_state(regions[key], key)
		if fit == ExpansionContract.BROKEN: return out
		if fit == ExpansionContract.CHANGED and not key in changed: changed.append(key)
	for key: Variant in progress:
		if not key is String: return out
		fit = ExpansionContract.progress_state(AdventureExpansions.definition(key), progress[key])
		if fit == ExpansionContract.BROKEN: return out
		if fit == ExpansionContract.CHANGED and not key in changed: changed.append(key)
	out["ok"] = active == MAINLAND or regions.has(MAINLAND)
	return out


static func valid_snapshot(region: Dictionary, key: String) -> bool:
	return snapshot_state(region, key) == ExpansionContract.FINE


## [method world_state] of a region's snapshot, its four parts records.
static func snapshot_state(region: Dictionary, key: String) -> int:
	for part in ["world", "where", "clocks", "record"]:
		if not region.get(part) is Dictionary: return ExpansionContract.BROKEN
	return world_state(region["world"], key)


static func valid_world(saved: Dictionary, key: String) -> bool:
	return world_state(saved, key) == ExpansionContract.FINE


## A saved world of region [param key] against the installed version:
## [constant ExpansionContract.FINE]; BROKEN — its grid, names, objectives,
## banners, markers, entries or list of 128 places damaged, or a land
## without its port (the way home); CHANGED — whole, but without a marker or a town the installed
## version's descriptor asks for (`required_markers`, `required_sites`).
static func world_state(saved: Dictionary, key: String) -> int:
	var broken := ExpansionContract.BROKEN
	if key == "" or not AdventurePlayer._grid_whole(saved.get("grid")): return broken
	var extra: Variant = saved.get("expansion", {})
	if not extra is Dictionary or extra.get("region", MAINLAND) != key: return broken
	if not WorldTerrainPalette.valid_appearance(extra.get("appearance", {})): return broken
	for field in ["town_names", "dungeon_names"]:
		if not extra.get(field, {}) is Dictionary: return broken
		for name in extra.get(field, {}).values():
			if not name is String: return broken
	var objectives: Variant = extra.get("objectives", {})
	if not objectives is Dictionary: return broken
	for slot in objectives.values():
		if not AdventurePlayer._is_number(slot) or int(slot) != slot or slot < -1 or slot >= 128: return broken
	var banners: Variant = extra.get("banners", [])
	if not banners is Array or banners.size() > 256: return broken
	for banner in banners:
		if not banner is Dictionary or not valid_point(banner.get("point")) or not banner.get("color") is String: return broken
		for field in ["anchor", "size"]:
			if not banner.has(field): continue
			if not banner[field] is Array or banner[field].size() != 2: return broken
			for value in banner[field]:
				if not AdventurePlayer._is_number(value) or value < (-256 if field == "anchor" else 1) or value > 256: return broken
	var used := {}
	var fit := ExpansionContract.FINE
	# Every land keeps its port, the hero's way home; a marker more the
	# installed version asks for is its version's word (§0.5).
	var info := AdventureExpansions.definition(key)
	var required: Array = info.get("required_markers", ["port", "castle"]) if not info.is_empty() else ["port"]
	for mark in ["port", "castle"]:
		if not extra.has(mark):
			if key != MAINLAND and mark == "port": return broken
			if key != MAINLAND and mark in required: fit = ExpansionContract.CHANGED
			continue
		if not valid_point(extra[mark]): return broken
		var point: Array = extra[mark]
		var tile := Vector2i(int(point[0]), int(point[1]))
		if used.has(tile) or String(saved["grid"][tile.y]).hex_decode()[tile.x] & 15 == 0: return broken
		used[tile] = true
	if not extra.get("entries", {}) is Dictionary: return broken
	for point in extra.get("entries", {}).values():
		if not valid_point(point): return broken
	var sites: Variant = saved.get("sites", [])
	if not sites is Array: return fit if key == MAINLAND else broken
	# A land's map has its 128 places, as every world is made (any version's).
	if key != MAINLAND and ((sites as Array).size() != SITE_SLOTS
			or not (sites as Array).all(func(site: Variant) -> bool: return site is Dictionary)):
		return broken
	for index: Variant in info.get("required_sites", []):
		if not AdventurePlayer._is_number(index) or int(index) < 0 or int(index) >= sites.size() or not sites[int(index)] is Dictionary:
			fit = ExpansionContract.CHANGED
			continue
		var site: Dictionary = sites[int(index)]
		if not AdventurePlayer._is_number(site.get("type")) or int(site["type"]) not in [ShandalarWorld.TOWN, ShandalarWorld.CITY] \
				or not valid_point([site.get("x"), site.get("y")]):
			fit = ExpansionContract.CHANGED
			continue
		var tile := Vector2i(int(site["x"]), int(site["y"]))
		if used.has(tile) or String(saved["grid"][tile.y]).hex_decode()[tile.x] & 15 == 0:
			fit = ExpansionContract.CHANGED
			continue
		used[tile] = true
	return fit

static func valid_point(value: Variant) -> bool:
	if not value is Array or value.size() != 2: return false
	for n in value:
		if not AdventurePlayer._is_number(n) or int(n) != n or n < 0 or n >= 64: return false
	return true
