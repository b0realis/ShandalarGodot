extends GutTest
## 0.70.11 campaign, bugs3 #1: the deck in use is never left without a card
## to stake while the hero owns one ([DeckRescue]) — at a meeting, at a
## ruled town, in a dungeon room, before the Final Battle and as a save is
## read; a hero with no card to stake at all still meets 1997's end.


func _hero(decks_of_spells: Array, current: int) -> AdventurePlayer:
	var hero := AdventurePlayer.new()
	hero.difficulty = 1
	for card_name in ["Grizzly Bears", "Grizzly Bears", "Giant Growth", "Llanowar Elves"]:
		hero.cards.append({"card": card_name, "decks": decks_of_spells.duplicate()})
	for n in 6:
		hero.cards.append({"card": "Forest", "decks": [0]})
	hero.current_deck = current
	return hero


func before_all() -> void:
	CardRegistry.ensure_loaded()


func test_a_playable_deck_is_left_alone() -> void:
	var hero := _hero([0], 0)
	assert_false(DeckRescue.needed(hero))
	assert_eq(DeckRescue.rescue(hero), "")
	assert_eq(hero.current_deck, 0)
	assert_eq(hero.deck_note, "")


func test_an_empty_deck_in_use_falls_back_to_the_deck_that_has_spells() -> void:
	var hero := _hero([0], 1)
	assert_true(CreatureMeeting.usable_cards(hero).is_empty(), "the trap: nothing to stake")
	assert_true(DeckRescue.needed(hero))
	var said := DeckRescue.rescue(hero)
	assert_eq(hero.current_deck, 0, "deck 1 is the deck in use")
	assert_eq(said, DeckRescue.SWITCHED % [2, 1])
	assert_eq(hero.deck_note, said, "kept for the world to say")
	assert_eq(CreatureMeeting.usable_cards(hero).size(), 4)


func test_a_deck_of_basic_lands_alone_falls_back_too() -> void:
	var hero := _hero([2], 0)
	DeckRescue.rescue(hero)
	assert_eq(hero.current_deck, 2)


func test_no_deck_with_a_spell_is_filled_from_the_bag() -> void:
	var hero := _hero([], 1)
	for n in 4:
		hero.cards.append({"card": "Lightning Bolt", "decks": []})
	var said := DeckRescue.rescue(hero)
	assert_eq(said, DeckRescue.FILLED % 2)
	assert_eq(hero.current_deck, 1, "the deck in use stays")
	var deck := hero.deck_cards()
	assert_eq(deck.count("Lightning Bolt"), DeckRescue.COPIES, "1997's three copies")
	assert_eq(deck.count("Grizzly Bears"), 2)
	assert_eq(deck.count("Forest"), 6, "every basic land")
	assert_false(CreatureMeeting.usable_cards(hero).is_empty())
	assert_eq((hero.cards[4] as Dictionary)["decks"], [0, 1], "deck 1 keeps its lands")


func test_a_hero_with_no_spell_at_all_still_meets_the_end() -> void:
	var hero := AdventurePlayer.new()
	for n in 5:
		hero.cards.append({"card": "Forest", "decks": [0]})
	hero.cards.append({"card": "No Such Card Of Any Pack", "decks": [0]})
	assert_false(DeckRescue.needed(hero))
	assert_eq(DeckRescue.rescue(hero), "")
	var meeting := CreatureMeeting.meet(hero, 1, 1)
	assert_true(bool(meeting["no_ante"]), "1997's end stands")


func test_a_meeting_never_ends_the_adventure_for_an_empty_slot() -> void:
	var hero := _hero([0], 2)
	var meeting := CreatureMeeting.meet(hero, 1, 1)
	assert_false(bool(meeting["no_ante"]), "no end")
	assert_eq(hero.current_deck, 0)
	assert_eq((meeting["hero_ante"] as Array).size(), 1, "a stake drawn from the deck now in use")


func test_a_dungeon_room_and_the_final_battle_take_the_playable_deck() -> void:
	var hero := _hero([0], 1)
	var duel := {}
	DungeonDuels.draw_stake(hero, duel)
	assert_false(bool(duel["no_ante"]))
	assert_eq(hero.current_deck, 0)
	hero.current_deck = 2
	var config := FinalBattle.duel_config(hero)
	assert_eq(hero.current_deck, 0)
	assert_true((config.decks[0] as Array).has("Grizzly Bears"), "no forty lands against Arzakon")


func test_a_save_in_the_trap_is_rescued_as_it_is_read() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Rescue"
	setup.color = "red"
	setup.difficulty = 1
	setup.seed_text = "12345"
	var record := setup.resolve({})
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	assert_false(CreatureMeeting.usable_cards(hero).is_empty(), "the starter deck plays")
	hero.current_deck = 1
	var saved := hero.to_dict()
	assert_eq(int((saved["carried"] as Dictionary)["current_deck"]), 1, "the save holds the trap")
	var read := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(saved)))
	assert_not_null(read)
	assert_eq(read.current_deck, 0, "rescued on load")
	assert_eq(read.deck_note, DeckRescue.SWITCHED % [2, 1])
	assert_false(bool(CreatureMeeting.meet(read, 1, 1)["no_ante"]))
