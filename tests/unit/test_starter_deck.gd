extends GutTest
## THE HERO'S FIRST CARDS (2026-10-23): [StarterDeck] deals the 1997 game's
## first deck (`AddRandomStarterDeckCards`, 1.3) by its rules — the shares
## by difficulty, the basic lands, the uncommon-common turns, unique
## creatures, the one rare — on the base cards. EXACTLY 1997 (the owner,
## 2026-10-27, I-2 and I-3): a share without a rare ends on its last
## creature again, and the coloured spells are enchantments only.


func _deck(color: String, difficulty: int, seed_value := 4242) -> Array[String]:
	return StarterDeck.deal(color, difficulty, MsvcRandom.new(seed_value))


func test_the_shares_make_the_1997_counts() -> void:
	# Apprentice: 13 lands, 12 spells, 10 creatures and a rare; then 40, 46
	# and 46 (the owner's ruling of 2026-10-27, I-2: 1997's extra creature
	# copy), in every colour — the few common creatures of blue and white
	# without a landwalk run out, and a second copy comes as in 1997.
	for color in AdventurePlayer.COLORS:
		for seed_value in [4242, 145729]:
			assert_eq([_deck(color, 0, seed_value).size(), _deck(color, 1, seed_value).size(),
				_deck(color, 2, seed_value).size(), _deck(color, 3, seed_value).size()],
				[36, 40, 46, 46], color)


func test_a_share_without_a_rare_ends_on_its_last_creature_again() -> void:
	# 1.3 and retail alike: the call's last add stands outside its rare
	# block (0x4be3f8 jumps to it), so a share with no rare adds the last
	# card it picked — its last creature — once more, no copy count asked.
	# Magician: the own share 11+4+12+1 = 28 (0–27), the second 4+3+4
	# (28–38) and its extra copy at 39; Sorcerer 22, 23–33 + 34, 35–44 +
	# 45; Wizard 15, 15–44 + 45.
	for color in AdventurePlayer.COLORS:
		for seed_value in [4242, 145729, 77]:
			var where := "%s, seed %d" % [color, seed_value]
			var magician := _deck(color, 1, seed_value)
			assert_eq(magician[39], magician[38], "the Magician's second share: " + where)
			assert_true(CardRegistry.get_card(magician[39]).is_creature(), where)
			var sorcerer := _deck(color, 2, seed_value)
			assert_eq(sorcerer[34], sorcerer[33], "the Sorcerer's second share: " + where)
			assert_eq(sorcerer[45], sorcerer[44], "the Sorcerer's third share: " + where)
			assert_true(CardRegistry.get_card(sorcerer[34]).is_creature(), where)
			assert_true(CardRegistry.get_card(sorcerer[45]).is_creature(), where)
			var wizard := _deck(color, 3, seed_value)
			assert_eq(wizard[45], wizard[44], "the Wizard's any-colour share: " + where)
			assert_true(CardRegistry.get_card(wizard[45]).is_creature(), where)
			# The own share's last card is its rare, never a creature's copy.
			var apprentice := _deck(color, 0, seed_value)
			assert_eq(CardRegistry.rarity_of(apprentice[35]).to_lower(), "rare", where)


func test_the_coloured_spells_are_enchantments_only() -> void:
	# 1997's spell slot is, on the coin, an artifact (0x40) or an
	# enchantment (0x04) of the colour — never an instant or a sorcery
	# (1.3's code at 0x4be1b1–0x4be1ba, the retail game's alike; the
	# owner's ruling I-3). The rare keeps its creature, enchantment or
	# sorcery. So every card dealt is a land, a creature, an artifact, an
	# enchantment, or the own share's rare.
	for difficulty in 4:
		for color in AdventurePlayer.COLORS:
			for seed_value in [4242, 145729, 9]:
				var dealt := _deck(color, difficulty, seed_value)
				var rare_at: int = [35, 27, 21, 14][difficulty]
				for i in dealt.size():
					var data := CardRegistry.get_card(dealt[i])
					if i == rare_at or data.is_land() or data.is_creature() \
							or data.is_type(Mtg.CardType.ARTIFACT):
						continue
					assert_true(data.is_type(Mtg.CardType.ENCHANTMENT), "%s, %s level %d seed %d: %s" % [
						dealt[i], color, difficulty, seed_value, "an enchantment"])


func test_every_apprentice_gets_the_one_quota_the_game_reached() -> void:
	# 1.3's second Apprentice quota, 13/7/15, stands behind `(mask < 1) &
	# 0x20`, never true (the machine code always jumps on to 13/12/10):
	# whatever the dead test meant — white (`mask & 0x20`) or red (`(mask
	# << 1) & 0x20`) — a white and a red Apprentice get 13 basic lands and
	# 36 cards like every other.
	for color in ["white", "red"]:
		var dealt := _deck(color, 0)
		assert_eq(dealt.count(StarterDeck.BASICS[color]), 13, color)
		assert_eq(dealt.size(), 36, color)


func test_under_the_classic_rules_the_extra_copy_keeps_their_allowance() -> void:
	# [Ours] With the rules allowing one of each card, the share's last
	# creature is not added again.
	var dealt: Array[String] = []
	StarterDeck._keeps = func(card: Dictionary) -> bool: return not String(card["name"]) in dealt
	StarterDeck._share(dealt, "green", 0, 0, 3, false, 1, MsvcRandom.new(31))
	StarterDeck._keeps = Callable()
	assert_eq(dealt.size(), 3, "three creatures, no copy")
	assert_ne(dealt[2], dealt[1])
	var again: Array[String] = []
	StarterDeck._share(again, "green", 0, 0, 3, false, 1, MsvcRandom.new(31))
	assert_eq(again.size(), 4, "the 1997 rules: the copy comes")
	assert_eq(again[3], again[2])


func test_under_the_classic_rules_an_apprentice_still_gets_36_cards() -> void:
	# The one common artifact of the base sets (Amulet of Kroog) is dealt
	# on every artifact toss of a commons-only spell: a fifth time the
	# Classic allowance refuses it, and the toss's other side is dealt.
	for color in StarterDeck.MASKS:
		for seed in 60:
			var dealt := StarterDeck.deal(color, 0, MsvcRandom.new(seed), true)
			assert_eq(dealt.size(), 36, "%s, dice %d" % [color, seed])
			for card_name in dealt:
				if not card_name in StarterDeck.BASICS.values():
					assert_lte(dealt.count(card_name), 4, card_name)


func test_the_new_game_screen_counts_the_deck_dealt() -> void:
	# The Embark screen's "A 40-card first deck…" is read from the setup's
	# table ([method AdventureSetup.starting_resources]): it says what is
	# dealt.
	for difficulty in 4:
		assert_eq(int(AdventureSetup.starting_resources(difficulty)["deck_cards"]),
			_deck("green", difficulty).size(), AdventureSetup.DIFFICULTIES[difficulty])


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
