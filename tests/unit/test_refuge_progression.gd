extends GutTest
## Travel objectives, chosen rewards, fixed opposition and journal persistence.

func before_each() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)

func after_each() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)

func hero() -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.adventures = ["refuge"]
	setup.packs = ["pack-2"]
	setup.seed_text = "48271"
	var record := setup.resolve({"pack-2": "1"})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	assert_true(_refuge().travel(player))
	return player

func test_petitions_survive_travel_and_cannot_skip_their_delivery() -> void:
	var player := hero()
	for quest in [0, 1]:
		assert_true(_refuge().start(player, quest))
		assert_false(_refuge().start(player, quest))
		player.position = Quests.site_tile(player.world, quest + 1) * 32 + Vector2i(16, 16)
		assert_false(_refuge().deliver(player, quest))
		assert_false(_refuge().ready(player, quest))
	assert_true(_refuge().start(player, 3))
	assert_true(_refuge().ready(player, 3))
	assert_eq(_refuge().destination(player, 3)["tile"], Quests.site_tile(player.world, _refuge().destination_slot(player, 3)))
	assert_true(_refuge().travel(player))
	player = AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	assert_not_null(player)
	if player == null: return
	assert_true(_refuge().travel(player))
	for quest in [0, 1]:
		player.position = _refuge().destination(player, quest)["tile"] * 32 + Vector2i(16, 16)
		assert_true(_refuge().deliver(player, quest))
		assert_false(_refuge().deliver(player, quest), "cannot repeat a delivery")
		assert_true(_refuge().ready(player, quest))
		assert_eq(_refuge().destination(player, quest)["tile"], Quests.site_tile(player.world, quest + 1))

func test_reward_color_choice_and_legacy_cards_are_never_lost_or_farmed() -> void:
	var player := hero()
	var before := player.mana_links()
	assert_true(_refuge().finish_quest(player, 0))
	assert_eq(player.mana_links(), before, "pledges never grant mainland progression")
	assert_false(_refuge().finish_quest(player, 0))
	while player.bag_room() > 0: player.cards.append({"card": "Forest", "decks": []})
	# Preserve twelve cards earned by the older reward system.
	player.expansions["refuge"]["pending"] = ["Thallid", "Thallid", "Thorn Thallid", "Thorn Thallid", "Elvish Farmer", "Elvish Farmer", "Spore Flower", "Spore Flower", "Feral Thallid", "Feral Thallid", "Elvish Hunter", "Elvish Hunter"]
	assert_true(_refuge().choose_reward(player, 4), "white pledge may teach green")
	assert_eq(player.expansions["refuge"]["pending"].size(), 18)
	assert_false(_refuge().choose_reward(player, 4), "one choice per pledge")
	player = AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	assert_not_null(player)
	if player == null: return
	assert_eq(player.expansions["refuge"]["pending"].size(), 18)
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	assert_eq(_refuge().claim(player), 0)
	assert_eq(player.expansions["refuge"]["pending"].size(), 18)
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)
	for i in 18: player.cards.pop_back()
	assert_eq(_refuge().claim(player), 18)
	assert_true(player.expansions["refuge"]["pending"].is_empty())

func test_classic_reward_options_respect_owned_and_waiting_copies() -> void:
	var player := hero()
	player.card_rule = AdventurePlayer.RULE_CLASSIC
	player.cards = [{"card": "Order of the Ebon Hand", "decks": []}, {"card": "Order of the Ebon Hand", "decks": []}]
	player.expansions["refuge"]["pending"] = ["Order of the Ebon Hand", "Order of the Ebon Hand"]
	var cards := _refuge().reward_options(player, 2)
	assert_false(cards.has("Order of the Ebon Hand"))
	assert_eq(cards.size(), 6)

func test_enemy_decks_have_goblin_fuel_and_do_not_scale_to_hero() -> void:
	var player := hero()
	var first := _refuge().duel_config(player, 3)
	assert_eq(first.decks[1].count("Goblin Grenade"), 4)
	var goblins := 0
	for name in first.decks[1]:
		if name in ["Goblin Chirurgeon", "Goblin Balloon Brigade", "Goblins of the Flarg"]: goblins += 1
	assert_eq(goblins, 12)
	player.next_duel_life = 80
	player.cards.clear()
	for i in 40: player.cards.append({"card": "Black Lotus", "decks": [0]})
	var later := _refuge().duel_config(player, 3)
	assert_eq(later.decks[1], first.decks[1])
	assert_eq(later.lives[1], first.lives[1])
	for quest in range(-1, 5):
		var config := _refuge().duel_config(player, quest)
		assert_gt(config.lives[1], 20)
		assert_eq(config.decks[1].size(), 40)
		for card in config.decks[1]: assert_true(CardRegistry.has_card(card), card)
	assert_eq(_refuge().roaming_tier(null, 4), 12)
	assert_eq(_refuge().roaming_tier(null, 0), 0)
	assert_eq(_refuge().roaming_tier(null, 18), 18)

func test_journal_keeps_cumulative_days_regions_and_short_deduplicated_clues() -> void:
	var player := hero()
	player.journey_time = 48
	player.log_clue("Seek the Vaults north of Havenwood.")
	player.log_clue("Seek the Vaults north of Havenwood.")
	var entry: Dictionary = player.journal.back()
	assert_eq(entry["day"], 3)
	assert_eq(entry["region"], "refuge")
	assert_true(entry["highlight"])
	assert_string_contains(HeroStats.journal_line(entry), "Day 3 · The Last Refuge: Clue:")
	var size := player.journal.size()
	player.log_clue("Seek the Vaults north of Havenwood.")
	assert_eq(player.journal.size(), size)
	assert_true(_refuge().travel(player))
	player.log_clue("Deliver the letter to the eastern town.", "quest_clue")
	# A campaign that chose the island names every line's region (the
	# owner's ruling of 2026-11-03).
	assert_string_contains(HeroStats.journal_line(player.journal.back(), player), "Day 3 · Shandalar: Quest:")
	var loaded := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	assert_not_null(loaded)
	if loaded != null: assert_eq(loaded.journal, player.journal)

func test_old_five_town_island_keeps_reachable_objectives_without_regeneration() -> void:
	var player := hero()
	for slot in range(6, player.world.sites.size()):
		var tile := Quests.site_tile(player.world, slot)
		player.world.page[tile.y * ShandalarWorld.PAGE_WIDTH + tile.x] &= ~ShandalarWorld.SITE
		player.world.sites[slot]["type"] = 0
	player.world.expansion.erase("objectives")
	var before := player.world.fingerprint()
	assert_true(_refuge().start(player, 1))
	var point: Array = player.world.expansion["port"]
	var port := Vector2i(point[0], point[1])
	assert_eq(_refuge().destination(player, 1)["tile"], port)
	var harbor := _refuge().describe(player, port)
	assert_true(harbor["actions"].any(func(action: Array) -> bool: return action[0] == "refuge_deliver_1"))
	player.position = port * 32 + Vector2i(16, 16)
	assert_true(_refuge().deliver(player, 1))
	assert_true(_refuge().start(player, 3))
	var home := Quests.site_tile(player.world, 4)
	assert_eq(_refuge().destination(player, 3)["tile"], home)
	var town := VisitPane.describe(player, home)
	assert_true(town["actions"].any(func(action: Array) -> bool: return action[0] == "refuge_petition_3"))
	assert_false(town["actions"].any(func(action: Array) -> bool: return action[0] == "wiseman"))
	assert_true(town["lines"].any(func(line: String) -> bool: return line.contains("raider")))
	assert_eq(player.world.fingerprint(), before)

## The prototype plugin's interpreter ([DataRegion]).
func _refuge() -> DataRegion:
	return AdventureExpansions.provider("refuge") as DataRegion
