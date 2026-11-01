extends GutTest

func before_each() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)

func after_each() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)

func island(seed_text := "48271") -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.expanded_adventure = true
	setup.packs = ["pack-2"]
	setup.seed_text = seed_text
	setup.player_name = "Wayfarer"
	var record := setup.resolve({"pack-2": "1"})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	RefugeCampaign.travel(player)
	return player

func road_component(world: ShandalarWorld) -> Dictionary:
	var start := world.start_tile()
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	var at := 0
	while at < queue.size():
		var tile := queue[at]
		at += 1
		for d in range(1, 9):
			if world.road_bits(tile.x, tile.y) & (1 << (d - 1)) == 0:
				continue
			var next := tile + Vector2i(ShandalarWorld.DX[d], ShandalarWorld.DY[d])
			if not seen.has(next):
				seen[next] = true
				queue.append(next)
	return seen

func test_roads_connect_every_settlement_without_crossing_water_or_cutting_coasts() -> void:
	var shapes := {}
	for seed_value in [1, 23, 345, 12345, 48271, 8675309]:
		var world := RefugeWorld.generate(seed_value, 1, 1)
		var roads := road_component(world)
		var diagonal := false
		for tile in roads:
			assert_true(world.is_land(tile.x, tile.y))
			for d in range(1, 9):
				if world.road_bits(tile.x, tile.y) & (1 << (d - 1)) == 0: continue
				var next: Vector2i = tile + Vector2i(ShandalarWorld.DX[d], ShandalarWorld.DY[d])
				assert_true(world.is_land(next.x, next.y), "no road into water")
				var reverse := (d + 3) % 8 + 1
				assert_ne(world.road_bits(next.x, next.y) & (1 << (reverse - 1)), 0, "road joins in both directions")
				if d % 2 == 0:
					diagonal = true
					assert_true(world.is_land(next.x, tile.y) and world.is_land(tile.x, next.y), "no corner across the sea")
		for site in world.sites:
			if int(site["type"]) > 0:
				assert_true(roads.has(Vector2i(site["x"], site["y"])), "every settlement has a road")
		var castle: Array = world.expansion["castle"]
		assert_true(roads.has(Vector2i(castle[0], castle[1])))
		assert_true(diagonal, "lanes can follow terrain in all eight directions")
		shapes[world.fingerprint()] = true
	assert_eq(shapes.size(), 6)

func test_road_prefers_a_pass_around_a_mountain_mass() -> void:
	var world := ShandalarWorld.new()
	world.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	for y in range(2, 17):
		for x in range(2, 17):
			world.page[y * 320 + x] = 6
	for y in range(5, 12):
		for x in range(6, 11):
			world.page[y * 320 + x] = 5
	world.start = Vector2i(3, 8) * 32 + Vector2i(16, 16)
	RefugeRoads.join(world, Vector2i(3, 8), Vector2i(14, 8), {})
	assert_true(road_component(world).has(Vector2i(14, 8)))
	for y in range(5, 12):
		for x in range(6, 11):
			assert_eq(world.road_bits(x, y), 0, "a lowland route is preferable to climbing the range")

func test_settlements_offer_the_mainland_service_types_and_all_trade_categories() -> void:
	var player := island()
	var counts := {1: 0, 2: 0, 3: 0}
	var trades := {}
	var positions := {}
	for slot in player.world.sites.size():
		var site: Dictionary = player.world.sites[slot]
		var kind := int(site["type"])
		if kind <= 0: continue
		assert_lt(kind, ShandalarWorld.CASTLE)
		counts[kind] += 1
		var tile := Vector2i(site["x"], site["y"])
		assert_false(positions.has(tile))
		positions[tile] = true
		CardTrade.arrive(player, slot)
		var place := VisitPane.describe(player, tile)
		assert_eq(place["kind"], ["", "village", "town", "city"][kind])
		assert_gt(CardShop.offers(player, slot).size(), 0)
		if kind >= ShandalarWorld.TOWN: trades[int(site["trade"])] = true
	assert_between(counts[1], 6, 9)
	assert_eq(counts[2], 9)
	assert_eq(counts[3], 2)
	assert_eq(trades.size(), 11)
	for goods in [1, 2, 4, 8, 16, 32, 0x100, 0x200, 0x300, 0x400, 0x500]:
		assert_true(trades.has(goods))
	var sellers := {}
	for slot in player.world.world_magic_sites:
		if slot > 0:
			assert_false(sellers.has(slot), "one World Magic per seller")
			sellers[slot] = true
	assert_eq(sellers.size(), 3, "a compact island is not all eleven World Magic sellers")

func test_dungeon_opens_a_real_board_and_survives_save_and_region_changes() -> void:
	var player := island()
	var dungeon: Dictionary = player.world.encounters[5]
	var tile := Vector2i(dungeon["x"], dungeon["y"])
	assert_eq(DungeonDoors.at(player.world, tile), 5)
	assert_eq(WorldClues.known(player.world), [5])
	assert_eq(WorldClues.title(5, player.world), "Vaults of the First Crossing")
	assert_gt(WorldClues.treasures(player.world, 5).size(), 0)
	assert_eq(VisitPane.describe(player, tile)["name"], "Vaults of the First Crossing")
	var board := DungeonBoard.enter(player, DungeonDoors.enter(player, 5), 777)
	assert_not_null(board)
	assert_false(board.castle)
	assert_eq(board.title(), "Vaults of the First Crossing")
	assert_eq(board.monsters.size(), 5)
	assert_gt(board.cells.size(), 0)
	assert_string_contains(player.journal.back()["text"], "Vaults of the First Crossing")
	var before := dungeon.duplicate(true)
	assert_true(RefugeCampaign.travel(player))
	var loaded := AdventurePlayer.from_dict(player.to_dict())
	assert_not_null(loaded)
	assert_true(RefugeCampaign.travel(loaded))
	assert_eq(loaded.world.encounters[5], before)
	for attempt in 8:
		DungeonDoors.leave(loaded, 5, {})
		var moved: Dictionary = loaded.world.encounters[5]
		var next := Vector2i(moved["x"], moved["y"])
		assert_eq(RefugeCampaign.marker(loaded.world, next), "")
		assert_eq(VisitPane.site_slot(loaded.world, next), -1)
		assert_eq(loaded.world.road_bits(next.x, next.y), 0)
		assert_eq(DungeonDoors.at(loaded.world, next), 5)
	assert_eq(loaded.defeated_wizards, [] as Array[String])
	assert_eq(loaded.refuge["quests"], [])
	assert_false(loaded.refuge["liberated"])

func test_island_hints_never_reveal_empty_mainland_castles() -> void:
	var player := island()
	var words := CreatureMeeting.secrets(player, {"color": 1})
	assert_string_contains(" ".join(words), "Vaults of the First Crossing")
	for index in 5:
		assert_eq(player.world.encounters[index].get("clues", 0), 0)
	assert_eq(WorldClues.known(player.world), [5])

func test_mainland_random_lair_event_types_are_available_on_the_island() -> void:
	var player := island()
	var events := {}
	for seed_value in range(1, 300):
		player.dice = seed_value * 7919
		player.monster_timer = 0
		var event := LairEvent.begin(player, {"slot": 0, "color": 3})
		events[int(event["event"])] = true
	for kind in range(5, 19):
		assert_true(events.has(kind), LairEvent.NAMES[kind])
