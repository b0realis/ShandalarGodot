extends GutTest
## Island story progression, shared errands, rewards and regional isolation.

var pack_was_enabled := false

var _launch_before: bool

func before_each() -> void:
	_launch_before = AdventureExpansions.launch_enabled
	AdventureExpansions.read_launch(PackedStringArray([AdventureExpansions.LAUNCH_FLAG]))
	pack_was_enabled = CardPacks.is_enabled(FallenEmpiresPack.ID)
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)

func after_each() -> void:
	AdventureExpansions.read_launch(PackedStringArray([AdventureExpansions.LAUNCH_FLAG]) if _launch_before else PackedStringArray())
	CardPacks.set_enabled(FallenEmpiresPack.ID, pack_was_enabled)

func hero() -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.expanded_adventure = true
	setup.packs = ["pack-2"]
	setup.seed_text = "48271"
	var record := setup.resolve({"pack-2": "1"})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	assert_true(RefugeCampaign.travel(player))
	return player

func qualify(player: AdventurePlayer) -> void:
	for index in 5: RefugeCampaign.finish_quest(player, index)
	player.cards.clear()
	for i in 20:
		player.cards.append({"card": "Thallid", "decks": [0]})
		player.cards.append({"card": "Forest", "decks": [0]})

func names(rows: Array) -> Array:
	return rows.map(func(row: Dictionary) -> String: return row["name"])

func test_community_battles_keep_adventure_padding_gifts_and_no_ante() -> void:
	var player := hero()
	player.cards = [{"card": "Grizzly Bears", "decks": [0]}]
	var bag := player.cards.duplicate(true)
	player.next_duel_life = 2
	player.next_duel_life_carried = -1
	player.next_duel_card = "Samite Healer"
	player.next_duel_first_move = true
	for difficulty in 4:
		player.difficulty = difficulty
		for quest in 5:
			var config := RefugeCampaign.duel_config(player, quest)
			assert_eq(config.decks[0].size(), CreatureMeeting.DECK_LEAST[difficulty])
			assert_eq(config.decks[0].count("Grizzly Bears"), 1)
			assert_eq(player.cards, bag, "temporary padding never enters the collection")
			assert_eq(config.lives[0], CreatureMeeting.hero_life(player))
			assert_eq(config.start_in_play[0], ["Samite Healer"])
			assert_eq(config.first_player, 0)
			assert_eq(config.ante, 0)
			assert_false(config.plays_named_ante())
			assert_eq(config.decks[1].size(), 40)
			player.refuge["stages"] = {"0": 2, "1": 2, "3": 1}
			player.position = RefugeQuests.destination(player, quest)["tile"] * 32 + Vector2i(16, 16)
			assert_true(RefugeJourney.quest_place(player, quest)["actions"][0][2], "pledges accept non-Fallen-Empires decks")
	assert_eq(RefugeCampaign.duel_config(player, 1).decks[1].count("Deep Spawn"), 2)
	assert_eq(RefugeCampaign.duel_config(player, 1).decks[1].count("Island"), 18)

func test_unavailable_cards_disable_pledge_duels_with_an_explanation() -> void:
	var player := hero()
	player.cards = [{"card": "Missing expansion card", "decks": [0]}]
	player.refuge["stages"] = {"0": 2}
	assert_false(RefugeJourney.quest_place(player, 0)["actions"][0][2])
	assert_string_contains(" ".join(RefugeJourney.quest_place(player, 0)["lines"]), "unavailable cards")
	player.cards.clear()
	assert_string_contains(RefugeCampaign.deck_problem(player), "Choose a deck")
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	assert_string_contains(RefugeCampaign.deck_problem(player), "Enable Pack 2")

func test_wise_men_and_roamers_speak_of_this_island_before_and_after_freedom() -> void:
	var player := hero()
	for color in range(1, 6):
		var meeting := {"color": color, "kind": 1, "row": 1, "relation": CreatureMeeting.STRONGHOLD, "wins": 0}
		var words := " ".join(CreatureMeeting.words(player, meeting))
		assert_string_contains(words, "Last Refuge")
		for wizard in WorldNames.WIZARDS: assert_false(words.contains(wizard))
		assert_eq(CreatureMeeting.relation_of(player, 1, color, 7, Vector2i.ZERO), CreatureMeeting.NONE)
	var found_news := false
	for seed_value in range(1, 30):
		var words := WiseMan._news(player, MsvcRandom.new(seed_value))
		for wizard in WorldNames.WIZARDS: assert_false(words.contains(wizard))
		found_news = found_news or words.contains("Ebon Crown")
	assert_true(found_news)
	for tale in RefugeStories.TALES.size():
		player.wise_man["tale"] = tale
		assert_eq(WiseMan._tale(player).size(), 1)
		assert_string_contains(WiseMan._tale(player)[0], RefugeStories.TALES[tale][0])
	qualify(player)
	assert_true(RefugeCampaign.liberate(player))
	var point: Array = player.world.expansion["castle"]
	var castle := RefugeJourney.describe(player, Vector2i(point[0], point[1]))
	assert_false(castle["actions"].any(func(action: Array) -> bool: return action[0] == "refuge_boss"))
	assert_false(" ".join(castle["lines"]).contains("Required:"))
	assert_string_contains(RefugeStories.news(player), "has fallen")
	assert_string_contains(RefugeStories.applause(player), "freeing")
	assert_string_contains(" ".join(RefugeStories.roaming_words(player, 0)), "broken")

func test_all_pledges_out_of_order_and_pending_rewards_survive_region_round_trip() -> void:
	var player := hero()
	while player.bag_room() > 0: player.cards.append({"card": "Forest", "decks": []})
	var gold := player.gold
	var food := player.food
	for quest in [4, 1, 3, 0, 2]:
		assert_true(RefugeCampaign.finish_quest(player, quest))
		assert_false(RefugeCampaign.finish_quest(player, quest))
	assert_eq(player.gold, gold + 200)
	assert_eq(player.food, food + 40)
	assert_eq(player.refuge["reward_choices"].size(), 5)
	for color in 5: assert_true(RefugeQuests.choose_reward(player, color))
	assert_eq(player.refuge["pending"].size(), 30)
	assert_true(RefugeCampaign.travel(player))
	player = AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	assert_not_null(player)
	if player == null: return
	assert_true(RefugeCampaign.travel(player))
	for i in 30: player.cards.pop_back()
	assert_eq(RefugeCampaign.claim(player), 30)
	assert_eq(RefugeCampaign.claim(player), 0)
	assert_eq(player.refuge["quests"].size(), 5)

func test_lair_rewards_follow_the_regional_unlock_without_polluting_other_campaigns() -> void:
	var player := hero()
	assert_has(names(LairEvent.reward_pool(player)), "Thallid")
	assert_false(names(LairEvent.reward_pool(null)).has("Thallid"))
	var found := false
	for seed_value in range(1, 160):
		var card := LairEvent._treasure(MsvcRandom.new(seed_value * 7919), 3, {}, player)
		found = found or card in FallenEmpiresPack.names()
	assert_true(found, "ordinary island treasure can actually draw a pack card")
	assert_true(RefugeCampaign.travel(player))
	assert_false(names(LairEvent.reward_pool(player)).has("Thallid"))
	assert_true(RefugeCampaign.travel(player))
	qualify(player)
	assert_true(RefugeCampaign.liberate(player))
	assert_true(RefugeCampaign.travel(player))
	assert_has(names(LairEvent.reward_pool(player)), "Thallid")
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	assert_false(names(LairEvent.reward_pool(player)).has("Thallid"))

func test_damaged_region_identity_or_missing_communities_is_rejected() -> void:
	var player := hero()
	var saved := player.to_dict()
	var broken := saved.duplicate(true)
	broken["regions"]["mainland"]["world"]["expansion"]["region"] = "refuge"
	assert_null(AdventurePlayer.from_dict(broken))
	broken = saved.duplicate(true)
	broken["world"]["sites"] = []
	assert_null(AdventurePlayer.from_dict(broken))
	broken = saved.duplicate(true)
	broken["world"]["expansion"]["port"] = [0, 0]
	assert_null(AdventurePlayer.from_dict(broken), "the return ship cannot be saved in open water")
	broken = saved.duplicate(true)
	broken["expansions"]["refuge"]["liberated"] = true
	assert_null(AdventurePlayer.from_dict(broken), "freedom requires all five pledges")
	var links := player.mana_links()
	saved["regions"]["mainland"]["links"] = ["damaged counter"]
	var loaded := AdventurePlayer.from_dict(saved)
	assert_not_null(loaded)
	assert_eq(loaded.mana_links(), links, "real settlement status supplies the links")

func test_local_deliveries_finish_at_communities_and_empty_site_slots_are_not_quests() -> void:
	var player := hero()
	for kind in [Quests.LETTER_LINK, Quests.LETTER_AMULET, Quests.CARD]:
		player.quest = {"type": kind, "destination": 1, "giver": 8, "color": 5, "deadline": 100}
		if kind == Quests.CARD: player.add_card("Icatian Infantry")
		var reward := Quests.complete_at(player, 1)
		assert_false(reward.is_empty())
		assert_true(player.quest.is_empty())
		assert_eq(player.refuge["quests"], [], "ordinary errands grant no pledge")
	player.quest = {"type": Quests.LETTER_AMULET, "destination": 127}
	assert_false(Quests.has_quest(player))
	assert_eq(WiseMan.reminder(player), "")
	assert_eq(Quests.complete_at(player, 127), {})
