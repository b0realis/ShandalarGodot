extends GutTest
## THE COPY LIMIT ON WHAT THE HERO IS GIVEN ([member
## AdventurePlayer.copy_limit]; the owner, 2026-10-24: an Embark choice).
## On, as 1997 meant it: the shops, the duels' rewards and the trader's
## dimmed names count the deck in use's copies (`GetRemainingAllowedCardCopies`).
## Off, as 1997 shipped it: that count matched no owned card, so none is
## counted — only the rule's own cases stay.

var player: AdventurePlayer


func before_each() -> void:
	CardRegistry.ensure_loaded()
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	var record := setup.resolve({})
	player = AdventurePlayer.begin(record, AdventureSetup.make_world(record))


func after_each() -> void:
	CardValue.forget()
	CardShop.forget()


func test_on_the_deck_s_copies_are_counted_off_none() -> void:
	assert_true(player.copy_limit, "on by default")
	var counted := CardShop.counted_copies(player)
	assert_eq(counted, CardShop.deck_counts(player), "on: the deck in use's copies")
	assert_false(counted.is_empty())
	player.copy_limit = false
	assert_eq(CardShop.counted_copies(player), {}, "off: none counted, as 1997 shipped")


func test_the_choice_is_saved_and_an_old_save_keeps_the_limit() -> void:
	player.copy_limit = false
	var data := JSON.parse_string(JSON.stringify(player.to_dict())) as Dictionary
	assert_false(AdventurePlayer.from_dict(data).copy_limit, "saved and read back")
	(data["hero"] as Dictionary).erase("copy_limit")
	(data["hero"] as Dictionary).erase("card_rule")
	assert_true(AdventurePlayer.from_dict(data).copy_limit,
		"a save from before the choice: the limit on, as those adventures played")
	var record := {"seed": 1, "color": "red", "difficulty": 1}
	assert_true(AdventurePlayer.begin(record, AdventureSetup.make_world(record)).copy_limit,
		"a record without the choice: on")


func test_a_reward_may_be_a_card_the_deck_is_full_of_only_with_the_limit_off() -> void:
	# The deck in use under 40 cards: one copy allowed with the limit on. A
	# Magician's first deck is 40 since 1997's extra creature copy (the quick
	# world package, I-2): one card goes out of the deck in use.
	for entry in player.cards:
		if String((entry as Dictionary)["card"]) != "Mountain":
			(entry as Dictionary)["decks"] = []
			break
	assert_eq(CardShop.copies_allowed(player), 1, "control: under 40 cards")
	var held := CardShop.deck_counts(player)
	var meeting := {"row": 22, "color": 4, "strength": 40, "creature_ante": []}
	var repeats := 0
	for seed_value in range(1, 41):
		player.copy_limit = true
		for card_name in DuelSpoils.reward_cards(player, meeting, MsvcRandom.new(seed_value)):
			if not card_name in CreatureDeck.BASICS:
				assert_false(held.has(card_name), "on: no card the deck already holds (%s)" % card_name)
		player.copy_limit = false
		var again := DuelSpoils.reward_cards(player, meeting, MsvcRandom.new(seed_value))
		repeats += again.filter(func(c: String) -> bool: return held.has(c) and not c in CreatureDeck.BASICS).size()
	assert_gt(repeats, 0, "off: cards the deck already holds may come again")
