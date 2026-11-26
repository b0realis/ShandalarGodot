extends GutTest
## A CARD QUEST'S CARD IS THE HERO'S TO CHOOSE (a player's report, 2026-11-26:
## "upon entering it immediately says 'the people thank you for your
## Regrowth' and it's removed from inventory"; the owner: a picker) — the
## model's side ([Quests]): which cards are offered and in what order
## ([method Quests.cards_for_quest]), the one named given ([method
## Quests.complete_at] with a name), none given keeps the quest, the last
## copy leaves its decks, and the offer says a card will go.

var player: AdventurePlayer
var destination := -1
## Cards of the quest's colour (red) and class, cheapest first, and one
## that does not fit.
var fits: Array[String] = []
var other := ""
const SAVES := "user://adventure_tests_c1127_quest_choice"


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	var record := setup.resolve({})
	player = AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	for slot in player.world.sites.size():
		if int(player.world.sites[slot]["type"]) == ShandalarWorld.TOWN and not TownStatus.linked(player.world, slot):
			destination = slot
			break
	player.quest = {"type": Quests.CARD, "destination": destination, "giver": 0, "color": 4, "data": -1,
		"deadline": player.quest_timer + 79}
	var wanted := Quests.card_class(destination)
	var priced: Array = []
	fits.clear()
	other = ""
	for card_name in CardRegistry.all_names():
		if not CardTrade.in_adventure(String(card_name)):
			continue
		var f := CardValue.facts(CardRegistry.get_card(card_name))
		if int(f.get("color", 0)) & 16 != 0 and int(f.get("type", 0)) & wanted != 0:
			priced.append([CardValue.price_of(f), String(card_name)])
		elif other == "" and int(f.get("color", 0)) & 16 == 0 and int(f.get("type", 0)) & CardValue.LAND == 0:
			other = String(card_name)
	priced.sort()
	for entry: Array in priced:
		fits.append(String(entry[1]))


func after_each() -> void:
	WiseMan.forget()
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _names(rows: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for row in rows:
		out.append(String(row["name"]))
	return out


func test_the_cards_offered_the_ones_to_spare_first_then_the_cheapest() -> void:
	assert_gt(fits.size(), 3, "the pool has cards of the kind")
	var cheap := fits[0]
	var dear := fits[fits.size() - 1]
	var middle := fits[fits.size() / 2]
	player.cards = [{"card": cheap, "decks": [0, 1]}, {"card": other, "decks": []},
		{"card": dear, "decks": [0]}, {"card": dear, "decks": []}, {"card": middle, "decks": []},
		{"card": "No Such Card Anywhere", "decks": []}]
	var rows := Quests.cards_for_quest(player)
	assert_eq(_names(rows), [middle, dear, cheap] as Array[String],
		"a spare copy before a deck's, the cheaper spare first; what does not fit left out")
	assert_eq(int(rows[1]["copies"]), 2)
	assert_eq(int(rows[1]["at"]), 3, "the spare copy would go, not the deck's")
	assert_eq(rows[1]["decks"], [], "and no deck loses it")
	assert_false(bool(rows[1]["last"]))
	assert_true(bool(rows[2]["last"]), "the only copy")
	assert_eq(rows[2]["decks"], [0, 1], "the decks that would lose it")
	assert_eq(int(rows[2]["price"]), CardValue.base_price(CardRegistry.get_card(cheap)))
	assert_eq(int(rows[2]["rarity"]), CardValue.rarity(cheap))
	assert_true(Quests.card_wanted_at(player, destination))
	assert_false(Quests.card_wanted_at(player, destination + 1), "only at the quest's town")


func test_the_card_named_is_the_card_given() -> void:
	var cheap := fits[0]
	var dear := fits[fits.size() - 1]
	player.cards = [{"card": cheap, "decks": []}, {"card": other, "decks": []}, {"card": dear, "decks": [0]}]
	var red := int(player.amulets["red"])
	var done := Quests.complete_at(player, destination, dear)
	assert_eq(done["lines"][0], "The people are pleased to receive the %s spell." % dear)
	assert_eq(player.cards, [{"card": cheap, "decks": []}, {"card": other, "decks": []}],
		"the card named went, the one a silent quest would have taken stays")
	assert_eq(int(player.amulets["red"]), red + 1)
	assert_true(TownStatus.linked(player.world, destination))
	assert_false(Quests.has_quest(player), "the quest is done")


func test_a_named_card_with_copies_gives_the_one_in_the_fewest_decks() -> void:
	var cheap := fits[0]
	player.cards = [{"card": cheap, "decks": [0, 1]}, {"card": cheap, "decks": [2]}]
	assert_eq(Quests.card_for_quest(player, cheap), 1)
	assert_eq(int(Quests.cards_for_quest(player)[0]["at"]), 1)
	assert_eq(Quests.cards_for_quest(player)[0]["decks"], [2])
	Quests.complete_at(player, destination, cheap)
	assert_eq(player.cards, [{"card": cheap, "decks": [0, 1]}])


func test_a_card_that_does_not_fit_or_is_not_held_is_not_given() -> void:
	player.cards = [{"card": fits[0], "decks": []}, {"card": other, "decks": []}]
	var before := player.cards.duplicate(true)
	var quest := player.quest.duplicate(true)
	assert_eq(Quests.complete_at(player, destination, other), {}, "not of the quest's kind")
	assert_eq(Quests.complete_at(player, destination, fits[1]), {}, "not the hero's")
	assert_eq(player.cards, before, "nothing taken")
	assert_eq(player.quest, quest, "the quest still under way")


func test_no_card_of_the_kind_offers_none() -> void:
	player.cards = [{"card": other, "decks": [0]}]
	assert_eq(Quests.cards_for_quest(player).size(), 0)
	assert_eq(Quests.card_for_quest(player), -1)
	player.quest = {}
	player.cards = [{"card": fits[0], "decks": []}]
	assert_eq(Quests.cards_for_quest(player).size(), 0, "no quest, nothing asked")
	assert_false(Quests.card_wanted_at(player, destination))


func test_the_last_copy_given_leaves_its_deck_and_an_emptied_deck_is_rescued() -> void:
	var cheap := fits[0]
	player.current_deck = 0
	player.cards = [{"card": cheap, "decks": [0]}, {"card": other, "decks": []}]
	assert_false(DeckRescue.needed(player))
	assert_false(Quests.complete_at(player, destination, cheap).is_empty())
	for entry: Dictionary in player.cards:
		assert_ne(String(entry["card"]), cheap, "no copy left, in a deck or out")
	assert_true(DeckRescue.needed(player), "deck 1 holds no spell now")
	assert_ne(DeckRescue.rescue(player), "", "and is filled from the hero's cards")
	assert_true(DeckRescue.playable(player, player.current_deck))


func test_the_offer_says_a_card_of_the_hero_s_goes() -> void:
	var village := -1
	for slot in player.world.sites.size():
		if int(player.world.sites[slot]["type"]) == ShandalarWorld.VILLAGE:
			village = slot
			break
	player.quest = {}
	player.quest_offer = {"type": Quests.CARD, "destination": destination, "color": 4, "at": village}
	var words := Quests.offer_words(player)
	assert_eq(words.size(), 3)
	assert_string_contains(words[0], "Take a %s" % Quests.spell_name(4, destination))
	assert_eq(words[2], Quests.CHOOSE_WORDS)
	player.quest_offer = {"type": Quests.LETTER_AMULET, "destination": destination, "color": 4, "at": village}
	assert_eq(Quests.offer_words(player).size(), 2, "a letter's offer as it was")
	# The wise man's reminder with such a card held.
	player.quest = {"type": Quests.CARD, "destination": destination, "giver": village, "color": 4, "data": -1,
		"deadline": player.quest_timer + 79}
	player.cards = [{"card": fits[0], "decks": []}]
	assert_string_contains(WiseMan.reminder(player), "There you choose a %s of yours to give." % Quests.spell_name(4, destination))
	player.cards = []
	assert_string_contains(WiseMan.reminder(player), "have asked for a %s." % Quests.spell_name(4, destination))
