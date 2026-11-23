extends GutTest
## THE REVIEW OF 2026-11-21, the sites plugins' part (adventure plugin API 2):
##  - a dungeon a place raised keeps its "where" as it moves (1997's slots
##    forget it as ever);
##  - the tiles a land's places keep are read once for many tiles asked, the
##    answer the same;
##  - a place put on a land later never stands under the hero, under
##    Arzakon's portal or on a lair;
##  - a plugin's record of its dungeon is believed only of a slot that says
##    it is that dungeon — a 0.70.4 save's unmarked vault still found.
##
## The shipped plugins are copied into the test profile with stand-in
## pictures, as tests/unit/test_site_plugins_2026_11_21.gd does.

const BEACON := preload("res://tools/expansion_testing/beacon_region.gd")
const ROOT := "user://review_sites_tests"
const HUT := "Old_Adventurers_Hut"
const GUILD := "Conjuration_Wizard_Guild"
const VAULT := "forgotten_vault"


func before_each() -> void:
	_copy_plugin(HUT)
	_copy_plugin(GUILD)
	AdventurePlugins.folders_override = [ROOT] as Array[String]
	AdventurePlugins.scan()


func after_each() -> void:
	AdventureExpansions.clear_development()
	_remove(ROOT)
	AdventurePlugins.folders_override = [] as Array[String]
	AdventurePlugins.scan()


func _copy_plugin(folder: String) -> void:
	var from := "res://expanded_adventure".path_join(folder)
	var to := ROOT.path_join(folder)
	DirAccess.make_dir_recursive_absolute(to.path_join("art"))
	for rel in ["plugin.json", "sites.json", "text.json", "README.txt", "LICENSE.txt"]:
		var file := FileAccess.open(to.path_join(rel), FileAccess.WRITE)
		file.store_buffer(FileAccess.get_file_as_bytes(from.path_join(rel)))
		file.close()
	var sites: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(from.path_join("sites.json")))
	var pictures: Array = (sites.get("pictures", {}) as Dictionary).values()
	for site: Dictionary in (sites["sites"] as Dictionary).values():
		pictures.append(String(site["sprite"]["file"]))
	for rel: String in pictures:
		var image := Image.create(48, 40, false, Image.FORMAT_RGBA8)
		image.fill(Color(0, 0, 0, 0))
		image.fill_rect(Rect2i(8, 6, 32, 30), Color(0.5, 0.4, 0.3))
		image.save_png(to.path_join(rel))


func _remove(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for name in dir.get_files():
		dir.remove(name)
	for name in dir.get_directories():
		_remove(path.path_join(name))
	DirAccess.remove_absolute(path)


## A hero of the fixed seed, the places not yet put on the land.
func _unplaced(lands: Array[String]) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.seed_text = "48271"
	setup.adventures = lands
	var record := setup.resolve({})
	return AdventurePlayer.begin(record, AdventureSetup.make_world(record))


func hero(lands: Array[String]) -> AdventurePlayer:
	var player := _unplaced(lands)
	AdventureExpansions.initialize(player)
	return player


func _point(player: AdventurePlayer, key: String) -> Vector2i:
	var point: Array = player.world.expansion.get(AdventureSites.KEY, {}).get(key, [])
	return Vector2i(int(point[0]), int(point[1])) if point.size() == 2 else Vector2i(-1, -1)


## The hut's vault raised for a hero of the mainland: its slot.
func _raise(player: AdventurePlayer) -> int:
	player.gold = 1000
	AdventureSites.provider("old_hut").do_effects(player, "hut", "secret")
	return AdventureSites.provider("old_hut").dungeon_index(player, VAULT)


# ------------------------------------------------- a moved dungeon's where --

func test_a_raised_dungeon_keeps_its_where_as_it_moves() -> void:
	var player := hero(["old_hut"] as Array[String])
	var index := _raise(player)
	assert_eq(index, 15)
	var vault: Dictionary = player.world.encounters[index]
	var old := Vector2i(int(vault["x"]), int(vault["y"]))
	var to := DungeonDoors.move(player, index)
	assert_ne(to, old, "it moved")
	assert_eq(int(vault["clues"]), 7, "where, creatures, rules: all still known")
	assert_eq(int(vault["town"]), DataSites._nearest_town(player.world, to), "its where is said from the town nearest its new tile")
	assert_eq(player.world.tile_flags(old.x, old.y) & ShandalarWorld.DUNGEON, 0)
	assert_ne(player.world.tile_flags(to.x, to.y) & ShandalarWorld.DUNGEON, 0)
	assert_true(WorldClues.lines(player.world, index).has("Location:"), "the clue screen still says where")
	assert_eq(AdventureSites.provider("old_hut").dungeon_index(player, VAULT), index, "the hut still knows its vault")


func test_a_1997_dungeon_forgets_its_where_as_ever() -> void:
	var player := hero(["old_hut"] as Array[String])
	var slot: Dictionary = player.world.encounters[7]
	slot["clues"] = 7
	assert_false(WorldClues.raised(slot, 7))
	DungeonDoors.move(player, 7)
	assert_eq(int(slot["clues"]), 6, "1997: the where forgotten, the other two known")
	assert_false(slot.has(WorldClues.RAISED))


func test_the_move_draws_the_same_dice_with_and_without_the_set() -> void:
	# The tiles kept are read once a move now: the draw is the same as one
	# that asks each tile afresh.
	var player := hero(["old_hut", "conjuration_guild"] as Array[String])
	var start := player.dice
	var to := DungeonDoors.move(player, 9)
	var dice := MsvcRandom.new(start)
	var expected := Vector2i(-1, -1)
	# The dungeon's old flag is off again for the replay, as the move left it.
	player.world.page[to.y * ShandalarWorld.PAGE_WIDTH + to.x] &= ~ShandalarWorld.DUNGEON
	while true:
		var x := dice.below(ShandalarWorld.TILES)
		var y := dice.below(ShandalarWorld.TILES)
		if DungeonDoors.takes_dungeon(player.world, Vector2i(x, y), player.tile(), FinalBattle.portal_tile_of(player)):
			expected = Vector2i(x, y)
			break
	assert_eq(to, expected)
	assert_eq(player.dice, dice.state)


# ----------------------------------------------- the kept tiles, read once --

func _same_answers(player: AdventurePlayer, why: String) -> void:
	var world := player.world
	var kept := DungeonDoors.kept_points(world)
	var wrong := 0
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			var tile := Vector2i(x, y)
			if DungeonDoors.expansion_place(world, tile) != DungeonDoors.expansion_place(world, tile, kept) \
					or DungeonDoors.takes_dungeon(world, tile, player.tile()) != DungeonDoors.takes_dungeon(world, tile, player.tile(), Vector2i(-1, -1), kept):
				wrong += 1
	assert_eq(wrong, 0, why)


func test_the_kept_tiles_read_once_answer_as_each_tile_asked() -> void:
	assert_true(AdventureExpansions.register_development(BEACON.ID, BEACON.descriptor()))
	var plain := _unplaced([])
	assert_eq(DungeonDoors.kept_points(plain.world), {}, "a 1997 world keeps none")
	_same_answers(plain, "a 1997 world")
	var player := hero([BEACON.ID, "old_hut", "conjuration_guild"] as Array[String])
	var hut := _point(player, "old_hut:hut")
	var kept := DungeonDoors.kept_points(player.world)
	assert_true(kept.has(hut) and kept.has(_point(player, "conjuration_guild:tower")), "the places")
	for point: Variant in (player.world.expansion.get("entries", {}) as Dictionary).values():
		assert_true(kept.has(Vector2i(int(point[0]), int(point[1]))), "the anchorage")
	_same_answers(player, "the mainland with its places and anchorage")
	# A place more, a place gone, damage: a set read afterwards answers anew.
	var more: Dictionary = player.world.expansion[AdventureSites.KEY]
	more["old_hut:other"] = [hut.x + 1, hut.y]
	more["broken"] = "no point"
	assert_true(DungeonDoors.kept_points(player.world).has(hut + Vector2i(1, 0)))
	_same_answers(player, "one place more")
	more.erase("old_hut:hut")
	assert_false(DungeonDoors.kept_points(player.world).has(hut))
	_same_answers(player, "one place gone")
	_raise(player)
	_same_answers(player, "a dungeon raised")
	assert_true(AdventureExpansions.voyage(player, BEACON.ID))
	AdventureExpansions.entered(player)
	_same_answers(player, "an island: its port, its castle, its tower")


func test_a_raised_dungeon_stands_where_it_stood_before_the_review() -> void:
	# The tile [method DataSites._dungeon_tile] draws is the one each tile
	# asked afresh gives: the same land's tiles in the same order.
	var player := hero(["old_hut"] as Array[String])
	var sites := AdventureSites.provider("old_hut")
	var hut := _point(player, "old_hut:hut")
	var info := sites.dungeon(VAULT)
	var least := float(info["distance"]["min"])
	var most := float(info["distance"]["max"])
	var inside: Array[Vector2i] = []
	# Since 0.70.9 of those tiles only the ones with a dungeon's air (1997's
	# gap of 4 from towns, cities and slots; beside no other landmark:
	# test_c1123_hut_chain.gd) — the same tiles in the same order still.
	var air := sites._dungeon_air(player, DungeonDoors.kept_points(player.world))
	for tile in RegionGeography.component(player.world, hut):
		if not DungeonDoors.takes_dungeon(player.world, tile, player.tile()):
			continue
		var far := tile.distance_to(hut)
		if far >= least and far <= most and DataSites._airy(tile, air):
			inside.append(tile)
	assert_false(inside.is_empty())
	var dice := AdventureSites.dice_for(player.world, int(sites.file().get("salt", 0)), "old_hut:%s:%s:0" % [DataSites.land(player), VAULT])
	assert_eq(sites._dungeon_tile(player, VAULT, "hut"), inside[dice.below(inside.size())])


# --------------------------------------------- where a later place stands --

func test_the_blocked_tiles_are_the_heros_the_portals_and_the_lairs() -> void:
	var player := _unplaced([])
	assert_eq(AdventureSites.blocked_tiles(player), [player.tile()] as Array[Vector2i])
	player.portal = {"x": 20, "y": 21, "state": FinalBattle.PORTAL_OPEN}
	player.monsters.append({"slot": 0, "kind": "lair", "x": 30 * 32 + 16, "y": 31 * 32 + 16, "color": 1})
	player.monsters.append({"slot": 1, "kind": "creature", "x": 40 * 32, "y": 41 * 32})
	player.monsters.append("damage")
	player.monsters.append({"kind": "lair", "x": "no number"})
	assert_eq(AdventureSites.blocked_tiles(player), [player.tile(), Vector2i(20, 21), Vector2i(30, 31)] as Array[Vector2i])
	assert_eq(AdventureSites.blocked_tiles(null), [] as Array[Vector2i])


func test_a_new_campaigns_places_stand_where_they_stood() -> void:
	# The hero stands on the start, which no place ever took: the draw of a
	# new campaign is the one without the blocked tiles.
	var player := hero(["old_hut", "conjuration_guild"] as Array[String])
	var bare := _unplaced(["old_hut", "conjuration_guild"] as Array[String])
	var placed: Array = []
	for id in AdventureSites.on_ids(bare):
		var info := AdventureSites.definition(id)
		for site: String in info["sites"]:
			var key := id + ":" + site
			var tile := AdventureSites.spot(bare.world, key, int(info["salt"]), int(info["sites"][site]["gap"]), placed)
			assert_eq(_point(player, key), tile, key)
			placed.append([tile.x, tile.y])
	assert_eq(placed.size(), 2)


func test_a_place_put_on_the_land_later_keeps_off_the_hero_the_portal_and_a_lair() -> void:
	var first := _point(hero(["old_hut"] as Array[String]), "old_hut:hut")
	assert_true(first.x >= 0)
	# The hero stands where the hut would rise.
	var standing := _unplaced(["old_hut"] as Array[String])
	standing.position = first * 32 + Vector2i(16, 16)
	AdventureExpansions.initialize(standing)
	var second := _point(standing, "old_hut:hut")
	assert_true(second.x >= 0 and second != first, "not under the hero")
	# The portal stands there.
	var gated := _unplaced(["old_hut"] as Array[String])
	gated.portal = {"x": first.x, "y": first.y, "state": FinalBattle.PORTAL_OPEN}
	AdventureExpansions.initialize(gated)
	assert_true(_point(gated, "old_hut:hut").x >= 0 and _point(gated, "old_hut:hut") != first, "not under the portal")
	# A lair lies there.
	var lair := _unplaced(["old_hut"] as Array[String])
	lair.monsters.append({"slot": 0, "kind": "lair", "x": first.x * 32 + 16, "y": first.y * 32 + 16, "color": 1})
	AdventureExpansions.initialize(lair)
	assert_true(_point(lair, "old_hut:hut").x >= 0 and _point(lair, "old_hut:hut") != first, "not on a lair")
	# A tile blocked that the draw never chose from changes nothing.
	var elsewhere := _unplaced(["old_hut"] as Array[String])
	elsewhere.portal = {"x": 0, "y": 0, "state": FinalBattle.PORTAL_OPEN}
	AdventureExpansions.initialize(elsewhere)
	assert_eq(_point(elsewhere, "old_hut:hut"), first)


# ------------------------------------------------- the slot says whose it is --

func test_a_raised_slot_says_whose_it_is_and_the_save_keeps_it() -> void:
	var player := hero(["old_hut"] as Array[String])
	var index := _raise(player)
	assert_eq(index, 15)
	assert_eq(String(player.world.encounters[index][WorldClues.RAISED]), "old_hut:" + VAULT)
	var read := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	assert_eq(String(read.world.encounters[index][WorldClues.RAISED]), "old_hut:" + VAULT)
	assert_eq(AdventureSites.provider("old_hut").dungeon_index(read, VAULT), index)
	assert_eq(AdventureSites.provider("old_hut").dungeon_state(read, VAULT), "open")


func test_a_damaged_record_pointing_at_a_castle_or_a_1997_dungeon_is_not_believed() -> void:
	var sites := AdventureSites.provider("old_hut")
	for slot: int in [0, 3, 5, 14]:
		var player := hero(["old_hut"] as Array[String])
		var hut := _point(player, "old_hut:hut")
		var saved: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
		saved["sites"] = {"old_hut": {"uses": {}, "flags": [], "dungeons": {"mainland:" + VAULT: slot}}}
		var read := AdventurePlayer.from_dict(saved)
		assert_not_null(read, "the save opens")
		AdventureExpansions.initialize(read)
		if slot < 5:
			assert_false(read.sites["old_hut"]["dungeons"].has("mainland:" + VAULT), "a castle's slot is dropped as the save is read")
		assert_eq(sites.dungeon_index(read, VAULT), -1, "slot %d is no vault" % slot)
		assert_eq(sites.dungeon_state(read, VAULT), "none")
		assert_false(read.world.encounters[slot].has(WorldClues.RAISED), "and is not marked one")
		# The hut sells its secret and the vault is raised: the price buys it.
		read.gold = 1000
		sites.do_effects(read, "hut", "secret")
		assert_eq(read.gold, 0)
		assert_eq(read.world.encounters.size(), 16, "a slot of its own")
		assert_eq(sites.dungeon_index(read, VAULT), 15)
		assert_eq(_point(read, "old_hut:hut"), hut)


func test_a_slot_marked_another_dungeons_is_not_believed() -> void:
	var player := hero(["old_hut"] as Array[String])
	var index := _raise(player)
	var sites := AdventureSites.provider("old_hut")
	player.world.encounters[index][WorldClues.RAISED] = "conjuration_guild:cellar"
	assert_eq(sites.dungeon_index(player, VAULT), -1)
	player.world.encounters[index][WorldClues.RAISED] = 7
	assert_eq(sites.dungeon_index(player, VAULT), index, "damage for a mark reads as none: a slot past the fifteen")
	assert_eq(String(player.world.encounters[index][WorldClues.RAISED]), "old_hut:" + VAULT)
	player.sites["old_hut"]["dungeons"]["mainland:" + VAULT] = "damage"
	assert_eq(sites.dungeon_index(player, VAULT), -1)
	player.sites["old_hut"]["dungeons"]["mainland:" + VAULT] = 47
	assert_eq(sites.dungeon_index(player, VAULT), -1, "no such slot")


func test_a_0_70_4_saves_unmarked_vault_is_found_and_marked() -> void:
	var player := hero(["old_hut"] as Array[String])
	var index := _raise(player)
	var saved: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	(saved["world"]["encounters"][index] as Dictionary).erase(WorldClues.RAISED)
	var read := AdventurePlayer.from_dict(saved)
	assert_false(read.world.encounters[index].has(WorldClues.RAISED), "as 0.70.4 wrote it")
	var sites := AdventureSites.provider("old_hut")
	assert_eq(sites.dungeon_state(read, VAULT), "open", "its vault is found")
	assert_eq(String(read.world.encounters[index][WorldClues.RAISED]), "old_hut:" + VAULT, "and marked from now on")
	# Unmarked, it keeps its where as it moves all the same (past the fifteen).
	(read.world.encounters[index] as Dictionary).erase(WorldClues.RAISED)
	DungeonDoors.move(read, index)
	assert_eq(int(read.world.encounters[index]["clues"]), 7)


func test_on_an_island_an_unmarked_slot_is_the_vault_only_under_its_name() -> void:
	assert_true(AdventureExpansions.register_development(BEACON.ID, BEACON.descriptor()))
	var player := hero([BEACON.ID, "old_hut"] as Array[String])
	assert_true(AdventureExpansions.voyage(player, BEACON.ID))
	AdventureExpansions.entered(player)
	var sites := AdventureSites.provider("old_hut")
	# The fixture island has no dungeon of its own: the castles' five slots
	# are made empty, and the vault takes the sixth.
	var index := sites.spawn(player, VAULT)
	if index < 0:
		pending("the fixture island has no tile for a raised dungeon")
		return
	assert_eq(index, 5)
	var key := BEACON.ID + ":" + VAULT
	assert_eq(sites.dungeon_index(player, VAULT), index)
	# 0.70.4's: no mark. Found under the name the raising gave it.
	(player.world.encounters[index] as Dictionary).erase(WorldClues.RAISED)
	assert_eq(sites.dungeon_index(player, VAULT), index)
	assert_eq(String(player.world.encounters[index][WorldClues.RAISED]), "old_hut:" + VAULT)
	# A land's own cave — unnamed, or under the land's name for it: a damaged
	# record pointing at it is not believed.
	var cave := player.world.encounters.size()
	player.world.encounters.append({"x": 1, "y": 1, "cards": [3], "clues": 7})
	player.sites["old_hut"]["dungeons"][key] = cave
	assert_eq(sites.dungeon_index(player, VAULT), -1, "unnamed")
	player.world.expansion["dungeon_names"][str(cave)] = "The Island's Cave"
	assert_eq(sites.dungeon_index(player, VAULT), -1, "another name")
	assert_false(player.world.encounters[cave].has(WorldClues.RAISED))
	# A marked slot under the fifteen keeps its where as it moves; the cave forgets.
	player.sites["old_hut"]["dungeons"][key] = index
	DungeonDoors.move(player, index)
	assert_eq(int(player.world.encounters[index]["clues"]) & WorldClues.LOCATION, WorldClues.LOCATION)
	DungeonDoors.move(player, cave)
	assert_eq(int(player.world.encounters[cave]["clues"]), 6)
