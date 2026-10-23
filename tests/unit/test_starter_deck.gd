extends GutTest
## THE HERO'S FIRST CARDS (2026-10-23): [StarterDeck] deals the 1997 game's
## first deck (`AddRandomStarterDeckCards`, 1.3) by its rules — the shares
## by difficulty, the basic lands, the uncommon-common turns, unique
## creatures, the one rare — on the base cards.


func _deck(color: String, difficulty: int, seed_value := 4242) -> Array[String]:
	return StarterDeck.deal(color, difficulty, MsvcRandom.new(seed_value))


func test_the_shares_make_the_1997_counts() -> void:
	# Apprentice: 13 lands, 12 spells, 10 creatures and a rare; then 39,
	# 44 and 45, in every colour — the few common creatures of blue and
	# white without a landwalk run out, and a second copy comes as in 1997.
	for color in AdventurePlayer.COLORS:
		for seed_value in [4242, 145729]:
			assert_eq([_deck(color, 0, seed_value).size(), _deck(color, 1, seed_value).size(),
				_deck(color, 2, seed_value).size(), _deck(color, 3, seed_value).size()],
				[36, 39, 44, 45], color)


func test_an_apprentice_s_deck_is_of_their_colour() -> void:
	var dealt := _deck("green", 0)
	assert_eq(dealt.count("Forest"), 13, "the colour's basic lands")
	var rare := 0
	var creatures: Array[String] = []
	for card_name in dealt:
		if card_name == "Forest":
			continue
		assert_false(card_name in DeckFormat.BANNED, card_name + ": never an ante card")
		var data := CardRegistry.get_card(card_name)
		var mask := data.color_mask()
		assert_true(mask == 0 or mask == Mtg.ManaColor.G, card_name + ": green or colourless")
		if data.is_creature() and not card_name in creatures:
			creatures.append(card_name)
			assert_false(data.landwalk.has("swamp") or data.landwalk.has("island"), "no swampwalk or islandwalk")
		if CardRegistry.rarity_of(card_name).to_lower() == "rare":
			rare += 1
	assert_gte(rare, 1, "the rare")
	assert_gte(creatures.size(), 9, "ten creatures (a second copy counted once), the rare maybe one more")


func test_more_colours_as_the_difficulty_rises() -> void:
	var dealt := _deck("white", 2)
	var lands := {}
	for card_name in dealt:
		if card_name in StarterDeck.BASICS.values():
			lands[card_name] = int(lands.get(card_name, 0)) + 1
	assert_eq(lands.size(), 3, "a Sorcerer's three colours")
	assert_eq(int(lands["Plains"]), 9, "nine of their own")


func test_the_same_dice_deal_the_same_deck() -> void:
	assert_eq(_deck("blue", 1, 77), _deck("blue", 1, 77))
	assert_ne(_deck("blue", 1, 77), _deck("blue", 1, 78), "other dice, another deck")


func test_a_new_hero_carries_it_in_deck_1() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "black"
	setup.difficulty = 0
	setup.seed_text = "12345"
	var record := setup.resolve({})
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	assert_eq(player.cards.size(), 36)
	for card in player.cards:
		assert_eq(card["decks"], [0], "every card in Deck 1")
	var again := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	var names := func(hero: AdventurePlayer) -> Array:
		return hero.cards.map(func(card: Dictionary) -> String: return card["card"])
	assert_eq(names.call(again), names.call(player), "one seed, one deck")
