extends GutTest
## PART C, W3 — ARZAKON'S PORTAL NEAR THE MIDDLE OF THE MAP (the owner,
## 2026-10-27: *"I would not put the portal at the fifth castle ruins but
## somewhere in the middle of the map approximately … the arrow, log,
## journals also point you towards this."*): [method FinalBattle.portal_tile]
## the same tile for the same world, free land the hero can walk to from
## the castles, nearest the middle; kept free of moved dungeons, lairs and
## creatures; pointed at by the guide arrows and the quest pane, open and
## petrified; a journal line as it opens and as the hero roams after the
## win; and a portal standing in an older save never moved.

const SEEDS: Array[String] = ["2468", "Marko", "143507"]
const WHITE := 6
const OCEAN := 0


## The world of seed [param seed_text] and a hero in it.
func _adventure(seed_text: String) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.player_name = "Portal Seeker"
	setup.seed_text = seed_text
	var record := setup.resolve({})
	return AdventurePlayer.begin(record, AdventureSetup.make_world(record))


## A plain world of [param terrain], with the five castles (encounter slots
## 0–4) on row 40 and three towns on row 20 — none of them flagged on the
## map unless [param flagged].
func _plain(terrain := WHITE, flagged := false) -> AdventurePlayer:
	var world := ShandalarWorld.new()
	world.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			world.page[y * ShandalarWorld.PAGE_WIDTH + x] = terrain
	for i in 3:
		world.sites.append({"x": 20 + i * 3, "y": 20, "type": ShandalarWorld.TOWN, "trade": 0, "status": 0})
	for i in 5:
		world.encounters.append({"x": 10 + i * 8, "y": 40, "color": i + 1, "clues": 0, "cards": []})
	if flagged:
		for site in world.sites:
			_flag(world, Vector2i(int(site["x"]), int(site["y"])), ShandalarWorld.SITE)
	world.lair_respawn = [-1000000, -1000000, -1000000, -1000000, -1000000, -1000000, -1000000] as Array[int]
	var player := AdventurePlayer.new()
	player.world = world
	player.adventure_id = "Portal-0000beef"
	player.position = Vector2i(10 * 32 + 16, 40 * 32 + 16)
	player.dice = 99
	for hue in ["black", "blue", "red", "white", "green"]:
		player.defeated_wizards.append(hue)
	return player


func _flag(world: ShandalarWorld, tile: Vector2i, bit: int) -> void:
	world.page[tile.y * ShandalarWorld.PAGE_WIDTH + tile.x] |= bit


func _land(world: ShandalarWorld, tile: Vector2i, terrain := WHITE) -> void:
	world.page[tile.y * ShandalarWorld.PAGE_WIDTH + tile.x] = terrain


func _middle(tile: Vector2i) -> float:
	return Vector2(tile).distance_to(Vector2(31.5, 31.5))


# ------------------------------------------------------------- the place --

func test_the_same_world_gives_the_same_free_tile_the_hero_can_walk_to() -> void:
	for seed_text in SEEDS:
		var player := _adventure(seed_text)
		var world := player.world
		var tile := FinalBattle.portal_tile(world)
		assert_eq(FinalBattle.portal_tile(_adventure(seed_text).world), tile, "%s: no dice" % seed_text)
		assert_true(world.is_land(tile.x, tile.y), "%s: land" % seed_text)
		assert_eq(world.tile_flags(tile.x, tile.y) & (ShandalarWorld.SITE | ShandalarWorld.ROAD
			| ShandalarWorld.DUNGEON), 0, "%s: no site, castle, road or dungeon" % seed_text)
		assert_lt(_middle(tile), 16.0, "%s: about the middle (%s)" % [seed_text, tile])
		for castle in 5:
			var slot: Dictionary = world.encounters[castle]
			player.position = Vector2i(int(slot["x"]) * 32 + 16, int(slot["y"]) * 32 + 16)
			var way := HeroWalk.new(player).plan(tile)
			assert_eq(way.back() if not way.is_empty() else Vector2i(-1, -1), tile,
				"%s: the hero walks there from castle %d" % [seed_text, castle])
		# Nothing free and reachable stands nearer the middle.
		var reach := FinalBattle.reachable(world)
		for y in ShandalarWorld.TILES:
			for x in ShandalarWorld.TILES:
				var other := Vector2i(x, y)
				if _middle(other) < _middle(tile) - 0.001 and FinalBattle.portal_may_stand(world, other):
					assert_eq(reach[y * ShandalarWorld.TILES + x], 0, "%s: %s is nearer and free" % [seed_text, other])


func test_it_keeps_off_sites_roads_and_dungeons() -> void:
	var player := _plain()
	assert_eq(FinalBattle.portal_tile(player.world), Vector2i(31, 31), "the middle, the upper left of four")
	_flag(player.world, Vector2i(31, 31), ShandalarWorld.SITE)
	_flag(player.world, Vector2i(32, 31), ShandalarWorld.ROAD)
	_flag(player.world, Vector2i(31, 32), ShandalarWorld.DUNGEON)
	assert_eq(FinalBattle.portal_tile(player.world), Vector2i(32, 32))


func test_an_island_in_the_middle_is_passed_by_for_land_the_hero_reaches() -> void:
	var player := _plain(OCEAN)
	for y in ShandalarWorld.TILES:
		for x in 21:
			_land(player.world, Vector2i(x, y))
	for i in 5:
		player.world.encounters[i]["x"] = 5
	_land(player.world, Vector2i(31, 31))
	_land(player.world, Vector2i(32, 32))
	assert_eq(FinalBattle.portal_tile(player.world), Vector2i(20, 31), "the island cut off; the coast nearest")
	for y in ShandalarWorld.TILES:
		for x in range(6, 21):
			_land(player.world, Vector2i(x, y), OCEAN)
	assert_eq(FinalBattle.portal_tile(player.world), Vector2i(5, 31), "far out, still the land the hero reaches")
	for y in ShandalarWorld.TILES:
		for x in 6:
			_flag(player.world, Vector2i(x, y), ShandalarWorld.ROAD)
	assert_eq(FinalBattle.portal_tile(player.world), Vector2i(31, 31), "none reachable: the nearest free land")


func test_with_no_free_land_it_stands_on_the_ruins() -> void:
	var player := _plain(OCEAN)
	for i in 5:
		var castle := Vector2i(10 + i * 8, 40)
		_land(player.world, castle)
		_flag(player.world, castle, ShandalarWorld.SITE)
	assert_eq(FinalBattle.portal_tile(player.world), Vector2i(-1, -1))
	FinalBattle.open_portal(player)
	assert_eq(FinalBattle.portal_tile_of(player), Vector2i(10 + 2 * 8, 40), "green's, the last beaten")


# ------------------------------------------------------- kept free --

func test_no_dungeon_moves_onto_it() -> void:
	var player := _plain(OCEAN)
	var portal := Vector2i(31, 31)
	var home := Vector2i(12, 12)
	_land(player.world, portal)
	_land(player.world, home)
	player.world.encounters.append({"x": home.x, "y": home.y, "color": 1, "clues": 7, "cards": [3]})
	_flag(player.world, home, ShandalarWorld.DUNGEON)
	player.portal = {"x": portal.x, "y": portal.y, "state": FinalBattle.PORTAL_PETRIFIED}
	assert_false(DungeonDoors.takes_dungeon(player.world, portal, Vector2i(0, 0), portal))
	assert_true(DungeonDoors.takes_dungeon(player.world, portal, Vector2i(0, 0)), "only the portal keeps it")
	for dice in [1, 2, 3, 4, 5]:
		player.dice = dice
		assert_eq(DungeonDoors.move(player, 5), home, "the one free tile left is its own (dice %d)" % dice)


func test_no_lair_or_creature_is_made_on_it() -> void:
	var player := _plain(OCEAN)
	player.ended = AdventurePlayer.ENDED_WON
	player.position = Vector2i(20 * 32 + 16, 20 * 32 + 16)
	var ring := Vector2i(24, 20)
	_land(player.world, ring)
	player.monster_timer = 100000
	var made := 0
	for dice in range(1, 40):
		player.monsters.clear()
		player.dice = dice
		WorldLairs.fill(player, 1, MsvcRandom.new(dice))
		made += player.monsters.size()
	assert_gt(made, 0, "the ring's one land tile takes lairs and creatures")
	player.portal = {"x": ring.x, "y": ring.y, "state": FinalBattle.PORTAL_PETRIFIED}
	for dice in range(1, 40):
		player.monsters.clear()
		WorldLairs.fill(player, 1, MsvcRandom.new(dice))
		assert_eq(player.monsters, [], "never on the portal's tile (dice %d)" % dice)


func test_at_peace_the_beaten_colours_fill_the_world_again() -> void:
	var player := _plain()
	player.position = Vector2i(20 * 32 + 16, 26 * 32 + 16)
	player.monster_timer = 100000
	var before := 0
	for dice in range(1, 30):
		player.monsters.clear()
		WorldLairs.fill(player, 1, MsvcRandom.new(dice))
		before += player.monsters.size()
	assert_eq(before, 0, "all five beaten, before the win: nothing (1997's rule)")
	player.ended = AdventurePlayer.ENDED_WON
	var after := 0
	for dice in range(1, 30):
		player.monsters.clear()
		WorldLairs.fill(player, 1, MsvcRandom.new(dice))
		after += player.monsters.size()
	assert_gt(after, 0, "at peace: they come back")
	assert_eq(player.defeated_wizards.size(), 5, "the wizards stay beaten")


# ------------------------------------------------------------ the pointers --

func test_the_arrows_and_the_quest_pane_point_to_it() -> void:
	var player := _plain(WHITE, true)
	assert_eq(FinalBattle.portal_target(player), {}, "no portal, no arrow")
	assert_eq(FinalBattle.portal_line(player), "")
	FinalBattle.open_portal(player)
	var town := WorldNames.site_name(player.world, 2)
	var open := {"tile": Vector2i(31, 31), "kind": "portal", "name": "Arzakon's Portal"}
	assert_true(WorldStatus.targets(player).has(open), "the arrow, while it is open")
	assert_eq(FinalBattle.portal_line(player), "Arzakon's Portal: east of %s" % town)
	assert_true(WorldStatus.lines(player).has("Arzakon's Portal: east of %s" % town), "the quest pane")
	FinalBattle.settle(player, null, true)
	assert_eq(FinalBattle.portal_target(player), {"tile": Vector2i(31, 31), "kind": "portal",
		"name": "Arzakon's Portal"}, "a lost battle under Reload allowed: still open")
	var won := DuelReport.new()
	won.finished = true
	won.result = DuelReport.WIN
	won.lives_start = [10, 100] as Array[int]
	FinalBattle.settle(player, won)
	var monument := {"tile": Vector2i(31, 31), "kind": "monument", "name": "Arzakon's Petrified Portal"}
	assert_true(WorldStatus.targets(player).has(monument), "the arrow, after the win")
	assert_true(WorldStatus.lines(player).has("Petrified Portal: east of %s" % town))
	player.ended = AdventurePlayer.ENDED_FAILED
	assert_eq(FinalBattle.portal_target(player), {}, "a failed adventure: none")
	assert_eq(WorldGuides.ink_for("portal"), WorldGuides.GOLD)
	assert_eq(WorldGuides.ink_for("monument"), WorldGuides.GOLD)
	assert_eq(WorldGuides.ink_for("siege"), WorldGuides.SIEGE)


func test_the_journal_says_where_as_it_opens_and_as_the_hero_roams() -> void:
	var player := _plain(WHITE, true)
	var town := WorldNames.site_name(player.world, 2)
	FinalBattle.open_portal(player)
	var opened: Dictionary = player.journal.back()
	assert_eq([opened["event"], opened["text"]],
		["portal", "Arzakon's Portal opened in the middle of Shandalar, east of %s" % town])
	assert_eq([opened["x"], opened["y"]], [31 * 32 + 16, 31 * 32 + 16], "pinned to the portal on the map")
	var lines := player.journal.size()
	FinalBattle.open_portal(player)
	assert_eq(player.journal.size(), lines, "a portal standing opens no more")
	assert_eq(FinalBattle.roam(player), "", "no roaming before the win")
	var won := DuelReport.new()
	won.finished = true
	won.result = DuelReport.WIN
	FinalBattle.settle(player, won)
	var said := FinalBattle.roam(player)
	assert_eq(said, "Arzakon's Portal turned to stone in the middle of Shandalar, east of %s" % town)
	assert_eq([player.journal.back()["text"], player.journal.back()["x"]], [said, 31 * 32 + 16])
	assert_true(bool(player.final["roamed"]))
	assert_eq(FinalBattle.roam(player), "", "once")
	assert_true(bool(AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict()))).final["roamed"]))


func test_far_from_the_middle_it_names_only_the_town() -> void:
	var player := _plain(WHITE, true)
	player.portal = {"x": 2, "y": 60, "state": FinalBattle.PORTAL_OPEN}
	assert_eq(FinalBattle.portal_where(player), "south of %s" % WorldNames.site_name(player.world, 0))
	player.world.sites.clear()
	assert_eq(FinalBattle.portal_where(player), "in Shandalar", "no town at all")
	player.portal = {"x": 31, "y": 31, "state": FinalBattle.PORTAL_OPEN}
	assert_eq(FinalBattle.portal_where(player), "in the middle of Shandalar")
	assert_eq(FinalBattle.portal_line(player), "Arzakon's Portal: in the middle of Shandalar")


# ------------------------------------------------------------ the old save --

func test_a_portal_on_the_ruins_in_an_older_save_stays_there() -> void:
	var data := _plain().to_dict()
	data["end"] = {"ended": "", "portal": {"x": 26, "y": 40, "state": "open", "castle": 2}}
	var older := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(data)))
	assert_eq(older.portal, {"x": 26, "y": 40, "state": FinalBattle.PORTAL_OPEN}, "read where it stood")
	var lines := older.journal.size()
	FinalBattle.door(older)
	FinalBattle.open_portal(older)
	assert_eq(FinalBattle.portal_tile_of(older), Vector2i(26, 40), "never moved")
	assert_eq(older.journal.size(), lines, "and no new line says it opened")
	var won := DuelReport.new()
	won.finished = true
	won.result = DuelReport.WIN
	FinalBattle.settle(older, won)
	assert_eq(older.portal, {"x": 26, "y": 40, "state": FinalBattle.PORTAL_PETRIFIED}, "petrified there")
