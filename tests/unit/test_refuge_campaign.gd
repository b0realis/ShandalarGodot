extends GutTest

var _launch_before: bool

func before_each() -> void:
	_launch_before = AdventureExpansions.launch_enabled
	AdventureExpansions.read_launch(PackedStringArray([AdventureExpansions.LAUNCH_FLAG]))
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)

func after_each() -> void:
	AdventureExpansions.read_launch(PackedStringArray([AdventureExpansions.LAUNCH_FLAG]) if _launch_before else PackedStringArray())
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)

func hero(seed_text := "12345") -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.expanded_adventure = true
	setup.packs = ["pack-2"]
	setup.player_name = "Wayfarer"
	setup.seed_text = seed_text
	var record := setup.resolve({"pack-2": "1"})
	return AdventurePlayer.begin(record, AdventureSetup.make_world(record))

func test_port_preserves_mainland_and_is_reachable_from_start() -> void:
	for seed_text in ["12345", "111", "2026", "87654"]:
		var player := hero(seed_text)
		var before := player.world.page.duplicate()
		var sites := player.world.sites.duplicate(true)
		var dice := player.dice
		RefugeCampaign.initialize(player)
		assert_eq(player.world.page, before)
		assert_eq(player.world.sites, sites)
		assert_eq(player.dice, dice)
		assert_true(player.world.expansion.has("port"))
		var p: Array = player.world.expansion.get("port", [-1, -1])
		var port := Vector2i(p[0], p[1])
		assert_true(port in RefugeWorld.component(player.world, player.world.start_tile()))
		assert_true(RefugeWorld.coast(player.world, port))
		assert_eq(VisitPane.site_slot(player.world, port), -1)

func test_island_is_compact_deterministic_and_all_places_connected() -> void:
	for seed_value in [1, 23, 345, 12345]:
		var world := RefugeWorld.generate(seed_value, 1, 1)
		assert_eq(world.fingerprint(), RefugeWorld.generate(seed_value, 1, 1).fingerprint())
		var land := RefugeWorld.component(world, world.start_tile())
		assert_eq(land.size(), world.land_count())
		assert_gt(land.size(), 100)
		for tile in land:
			assert_true(tile.x >= 16 and tile.x < 48 and tile.y >= 16 and tile.y < 48)
		for slot in range(1, 6):
			var site: Dictionary = world.sites[slot]
			assert_true(Vector2i(site["x"], site["y"]) in land)
		assert_eq(world.encounters.size(), 6, "one dungeon follows the reserved wizard slots")
		for index in 5:
			assert_false(WorldClues.holds_cards(world.encounters[index]), "mainland wizard castles are not duplicated")

func test_save_round_trip_and_return_preserve_each_region_and_shared_bag() -> void:
	var player := hero()
	RefugeCampaign.initialize(player)
	player.quest = {"type": Quests.LETTER_LINK, "destination": 12, "giver": 3, "color": 4, "data": 1, "deadline": 400}
	player.quest_timer = 321
	player.siege_timer = 99
	var before := RefugeCampaign.snapshot(player)
	var links := player.mana_links()
	var cards := player.cards.size()
	assert_true(RefugeCampaign.travel(player))
	assert_true(RefugeCampaign.on_island(player))
	assert_true(player.world_intact(), "the island recipe excludes exploration marks")
	assert_eq(player.quest, {})
	assert_eq(player.mana_links(), links)
	player.add_card("Thallid")
	player.food += 4
	player.quest_timer = 12
	var island := player.world.fingerprint()
	var loaded := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	assert_not_null(loaded)
	if loaded == null: return
	assert_true(RefugeCampaign.travel(loaded))
	assert_false(RefugeCampaign.on_island(loaded))
	assert_eq(loaded.quest, player.regions["mainland"]["record"]["quest"])
	assert_eq(loaded.quest_timer, 321)
	assert_eq(loaded.siege_timer, 99)
	assert_eq(loaded.cards.size(), cards + 1)
	assert_eq(loaded.world.page, AdventurePlayer._world_from(before["world"], Vector2i.ZERO).page)
	assert_true(RefugeCampaign.travel(loaded))
	assert_eq(loaded.world.fingerprint(), island)
	assert_eq(loaded.quest_timer, 12)

func test_missing_pack_never_strands_a_returning_player() -> void:
	var player := hero()
	assert_true(RefugeCampaign.travel(player))
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	assert_true(RefugeCampaign.travel(player))
	assert_false(RefugeCampaign.travel(player))

func test_disabled_pack_adds_nothing_to_a_fresh_mainland() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	var player := hero()
	var terrain := player.world.page.duplicate()
	var sites := player.world.sites.duplicate(true)
	var dice := player.dice
	RefugeCampaign.initialize(player)
	assert_true(player.world.expansion.is_empty())
	assert_true(player.refuge.is_empty())
	assert_eq(player.world.page, terrain)
	assert_eq(player.world.sites, sites)
	assert_eq(player.dice, dice)

func test_disabled_pack_hides_saved_harbor_without_erasing_progress() -> void:
	var player := hero()
	RefugeCampaign.initialize(player)
	var point: Array = player.world.expansion["port"].duplicate()
	var port := Vector2i(point[0], point[1])
	assert_eq(RefugeCampaign.marker(player.world, port), "port")
	assert_true(RefugeCampaign.travel(player))
	assert_true(RefugeCampaign.finish_quest(player, 0))
	assert_true(RefugeCampaign.travel(player))
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	assert_eq(RefugeCampaign.marker(player.world, port), "")
	assert_true(VisitPane.describe(player, port).is_empty())
	player = AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	assert_not_null(player)
	if player == null: return
	assert_eq(player.world.expansion["port"], point)
	assert_eq(RefugeCampaign.marker(player.world, port), "")
	assert_true(RefugeCampaign.completed(player, 0))
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	RefugeCampaign.initialize(player)
	assert_eq(player.world.expansion["port"], point)
	assert_eq(RefugeCampaign.marker(player.world, port), "port")
	assert_true(RefugeCampaign.travel(player))
	assert_true(RefugeCampaign.completed(player, 0))

func test_corrupt_inactive_map_is_rejected_and_old_saves_still_load() -> void:
	var player := hero()
	var old := player.to_dict()
	old.erase("expansions")
	old.erase("regions")
	old.erase("journey")
	old["world"].erase("expansion")
	old["version"] = 3
	assert_not_null(AdventurePlayer.from_dict(old))
	assert_true(RefugeCampaign.travel(player))
	var broken := player.to_dict().duplicate(true)
	broken["regions"]["mainland"]["world"]["grid"] = []
	assert_null(AdventurePlayer.from_dict(broken))
	broken = player.to_dict().duplicate(true)
	broken["regions"].erase("mainland")
	assert_null(AdventurePlayer.from_dict(broken))
	for value in ["not a list", [0, 0], [6], ["white"]]:
		broken = player.to_dict().duplicate(true)
		broken["expansions"]["refuge"]["quests"] = value
		assert_null(AdventurePlayer.from_dict(broken))
	broken = player.to_dict().duplicate(true)
	broken["world"]["expansion"]["port"] = ["bad", 1]
	assert_null(AdventurePlayer.from_dict(broken))

func test_unclaimed_rewards_survive_a_full_bag_and_can_be_collected_later() -> void:
	var player := hero()
	assert_true(RefugeCampaign.travel(player))
	while player.bag_room() > 0:
		player.cards.append({"card": "Forest", "decks": []})
	assert_true(RefugeCampaign.finish_quest(player, 0))
	assert_true(RefugeQuests.choose_reward(player, 0))
	assert_eq(player.refuge["pending"].size(), 6)
	player = AdventurePlayer.from_dict(player.to_dict())
	assert_not_null(player)
	for i in 3: player.cards.pop_back()
	assert_eq(RefugeCampaign.claim(player), 3)
	assert_eq(player.refuge["pending"].size(), 3)
	assert_eq(RefugeCampaign.claim(player), 0)

func test_island_steps_shops_and_guidance_keep_mainland_threats_separate() -> void:
	var player := hero()
	player.portal = {"x": 32, "y": 32, "state": FinalBattle.PORTAL_OPEN}
	assert_true(RefugeCampaign.travel(player))
	assert_eq(FinalBattle.portal_target(player), {})
	assert_false(FinalBattle.portal_at(player, Vector2i(32, 32)))
	assert_eq(WorldStatus.targets(player)[0]["name"], RefugeWorld.TOWNS[0])
	assert_string_contains(" ".join(WorldStatus.lines(player)), "0 / 5 pledges")
	for slot in range(1, 6):
		assert_eq(CardShop.town_colors(player.world, slot), [0x20, 0x04, 0x02, 0x10, 0x08][slot - 1], "settlement's trade color")
		CardTrade.arrive(player, slot)
		assert_gt(CardShop.offers(player, slot).size(), 0)
	for tick in 500:
		WorldCreatures.tick(player)
		player.monster_timer += 1
	assert_true(Sieges.calm(player))
	assert_true(RefugeCampaign.finish_quest(player, 0))
	assert_eq(WorldStatus.targets(player)[0]["name"], RefugeWorld.TOWNS[1])
	assert_string_contains(" ".join(WorldStatus.lines(player)), "1 / 5 pledges")

func test_quests_rewards_gate_and_unlock_are_persistent_and_not_repeatable() -> void:
	var player := hero()
	var original_stock := CardShop.stock().size()
	assert_eq(AdventurePacks.add_stock(player, CardShop.stock()).size(), original_stock)
	assert_true(RefugeCampaign.travel(player))
	assert_gt(AdventurePacks.add_stock(player, CardShop.stock()).size(), original_stock)
	for index in 5:
		var config := RefugeCampaign.duel_config(player, index)
		assert_eq(config.decks[1].size(), 40)
		for card in config.decks[1]:
			assert_true(CardRegistry.has_card(card), card)
		assert_true(RefugeCampaign.finish_quest(player, index))
		var gold := player.gold
		assert_false(RefugeCampaign.finish_quest(player, index))
		assert_eq(player.gold, gold)
	player.cards.clear()
	for i in 10:
		player.cards.append({"card": "Thallid", "decks": [0]})
		player.cards.append({"card": "Grizzly Bears", "decks": [0]})
	for i in 20:
		player.cards.append({"card": "Forest", "decks": [0]})
	assert_true(RefugeCampaign.can_challenge(player))
	player.cards.append({"card": "Grizzly Bears", "decks": [0]})
	assert_false(RefugeCampaign.can_challenge(player), "10/21 nonlands is below one half")
	player.cards.pop_back()
	assert_true(RefugeCampaign.liberate(player))
	assert_false(RefugeCampaign.liberate(player))
	assert_true(RefugeCampaign.travel(player))
	assert_gt(AdventurePacks.add_stock(player, CardShop.stock()).size(), original_stock)
	assert_eq(player.defeated_wizards, [] as Array[String])
	assert_true(AdventurePlayer.from_dict(player.to_dict()).refuge["liberated"])

func test_deck_gate_counts_only_main_deck_nonlands_and_requires_at_least_one() -> void:
	var player := hero()
	player.cards.clear()
	assert_false(RefugeCampaign.deck_gate(player)["ready"], "an empty deck cannot qualify")
	for card in ["Forest", "Ruins of Trokair", "Ebon Stronghold", "Mishra's Factory"]:
		assert_true(CardRegistry.get_card(card).is_land(), card)
		player.cards.append({"card": card, "decks": [0]})
	assert_eq(RefugeCampaign.deck_gate(player), {"count": 0, "total": 0, "ready": false})
	player.cards.append({"card": "Thallid", "decks": [0]})
	player.cards.append({"card": "Thallid", "decks": [0]})
	player.cards.append({"card": "Grizzly Bears", "decks": [0]})
	player.cards.append({"card": "Grizzly Bears", "decks": [0]})
	player.cards.append({"card": "Thallid", "decks": []})
	player.cards.append({"card": "Grizzly Bears", "decks": [1]})
	assert_eq(RefugeCampaign.deck_gate(player), {"count": 2, "total": 4, "ready": true},
		"copies count, lands and cards outside the selected deck do not")
	player.cards.append({"card": "Forest", "decks": [0]})
	assert_eq(RefugeCampaign.deck_gate(player), {"count": 2, "total": 4, "ready": true})
	player.cards.append({"card": "Grizzly Bears", "decks": [0]})
	assert_eq(RefugeCampaign.deck_gate(player), {"count": 2, "total": 5, "ready": false})
	player.cards.pop_back()
	player.cards.append({"card": "Missing card", "decks": [0]})
	assert_false(RefugeCampaign.deck_gate(player)["ready"], "unavailable card types cannot qualify")
