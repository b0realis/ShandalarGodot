extends GutTest
## THE DUELS' RECORD IN THE SAVE (part B, 2026-10-23): [AdventurePlayer]'s
## victory log as `{color, kind, creature}` with its counts, what each
## colour's creatures have learned of the hero's deck, the sieges counted,
## the next duel's lives in 1997's two fields, the deck in use and a card
## won — each saved, read back by its kind, and read from a save made
## before them.

var player: AdventurePlayer
var base: Dictionary


func before_all() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Record Keeper"
	setup.color = "blue"
	setup.difficulty = 1
	setup.walker = "female"
	setup.seed_text = "5150"
	var record := setup.resolve({})
	player = AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	player.adventure_id = "records"
	base = JSON.parse_string(JSON.stringify(player.to_dict()))


## The base save with [param change] made to a copy, read back.
func _read(change: Callable) -> AdventurePlayer:
	var data: Dictionary = base.duplicate(true)
	change.call(data)
	return AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(data)))


func _fresh() -> AdventurePlayer:
	return _read(func(_d: Dictionary) -> void: pass)


func test_a_new_hero_has_an_empty_record() -> void:
	assert_eq(player.duel_victories, [])
	assert_eq(player.creature_deck_colors, [0, 0, 0, 0, 0] as Array[int], "no colour has learned")
	assert_eq(player.siege_count, 0)
	assert_eq(player.next_duel_life_carried, 0)
	assert_eq([player.total_wins(), player.wins_against(CreatureBook.FEMALE_WIZARD, 1)], [0, 0])


# ------------------------------------------------------- the victory log --

func test_wins_are_logged_with_their_kind() -> void:
	var hero := _fresh()
	assert_true(hero.log_victory(1, 1), "a Witch on black land")
	hero.log_victory(39, 1)
	hero.log_victory(39, 3)
	hero.log_victory(33, 4)
	assert_eq(hero.duel_victories[0], {"color": 1, "kind": CreatureBook.FEMALE_WIZARD, "creature": "Witch"})
	assert_eq(hero.total_wins(), 4)
	assert_eq(hero.wins_against(CreatureBook.FEMALE_WIZARD, 1), 1)
	assert_eq(hero.wins_against(CreatureBook.DRAGON, 1), 1,
		"a Centaur Shaman on black land counts against black Mandurangs (both kind 8)")
	assert_eq(hero.wins_against(CreatureBook.DRAGON, 3), 1)
	assert_eq(hero.wins_against(CreatureBook.FEMALE_WIZARD, 4), 0)
	assert_eq(hero.wins_over_color(1), 2, "a castle wizard counts every win against its colour")


func test_the_log_holds_a_thousand() -> void:
	var hero := _fresh()
	for i in AdventurePlayer.VICTORIES_MOST:
		hero.log_victory(1, 1)
	assert_false(hero.log_victory(2, 1), "full")
	assert_eq(hero.total_wins(), 1000)


func test_the_log_round_trips() -> void:
	var hero := _fresh()
	hero.log_victory(29, 4)
	hero.log_victory(46, 1)
	var back := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(hero.to_dict())))
	assert_eq(back.duel_victories, hero.duel_victories)
	assert_eq(back.duel_victories[1], {"color": 1, "kind": CreatureBook.DJINN, "creature": "Aga Galneer"})
	assert_true(back.duel_victories[0]["color"] is int and back.duel_victories[0]["kind"] is int,
		"numbers read back as numbers")


## A save from before part B kept `{color, creature}`: the kind is the named
## creature's; a colour as a word its number.
func test_an_old_saves_victories_are_given_their_kind() -> void:
	var back := _read(func(d: Dictionary) -> void:
		d["duels"]["victories"] = [{"color": 2, "creature": "Witch"}, {"color": "red", "creature": "Hydra"},
			{"color": 1, "creature": 31}, {"color": 3}, {"color": 9, "kind": 4, "creature": "Someone"},
			{"color": "purple", "creature": "Nobody"}, {"creature": "Witch"}, {"color": [1]}, "x"])
	assert_eq(back.duel_victories, [
		{"color": 2, "kind": CreatureBook.FEMALE_WIZARD, "creature": "Witch"},
		{"color": 4, "kind": CreatureBook.WYRM, "creature": "Hydra"},
		{"color": 1, "kind": CreatureBook.TROLL, "creature": "Troll Shaman"},
		{"color": 3, "kind": -1, "creature": ""},
		{"color": 0, "kind": 4, "creature": "Someone"},
		{"color": 0, "kind": -1, "creature": "Nobody"},
	], "each by its kind; the ones with no colour dropped")
	assert_eq(back.wins_against(CreatureBook.WYRM, 4), 1)


# ------------------------------------------------------ what colours learn --

func test_a_colour_learns_the_heros_colours() -> void:
	var hero := _fresh()
	hero.learn_deck_colors(4, 0x3F)
	assert_eq(hero.learned_deck_colors(4), 0x3E, "never .vNone's 0x01")
	hero.learn_deck_colors(1, 0x24)
	assert_eq(hero.creature_deck_colors, [0x24, 0, 0, 0x3E, 0] as Array[int])
	hero.learn_deck_colors(0, 0x02)
	hero.learn_deck_colors(6, 0x02)
	assert_eq(hero.creature_deck_colors, [0x24, 0, 0, 0x3E, 0] as Array[int], "no colour, no change")
	assert_eq([hero.learned_deck_colors(0), hero.learned_deck_colors(6)], [0, 0])
	var back := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(hero.to_dict())))
	assert_eq(back.creature_deck_colors, hero.creature_deck_colors, "saved")
	assert_eq(hero.to_dict()["duels"]["creature_deck_colors"],
		{"black": 0x24, "blue": 0, "green": 0, "red": 0x3E, "white": 0}, "by the colours' words")


func test_the_learned_colours_are_read_by_kind() -> void:
	var back := _read(func(d: Dictionary) -> void:
		d["duels"]["creature_deck_colors"] = {"black": "x", "blue": 0x05, "red": 2.0, "white": [1], "grey": 8})
	assert_eq(back.creature_deck_colors, [0, 0x04, 0, 0x02, 0] as Array[int], "numbers only, the colour bits only")
	back = _read(func(d: Dictionary) -> void: d["duels"]["creature_deck_colors"] = [2, 4])
	assert_eq(back.creature_deck_colors, [0, 0, 0, 0, 0] as Array[int], "a list is no record")


# ------------------------------------------------- sieges and the next duel --

func test_the_siege_count_is_saved() -> void:
	var hero := _fresh()
	hero.siege_count = 7
	var back := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(hero.to_dict())))
	assert_eq(back.siege_count, 7, "[ours] 1997 never saved it")
	assert_eq(_read(func(d: Dictionary) -> void: d["clocks"]["siege_count"] = "many").siege_count, 0)
	assert_eq(_read(func(d: Dictionary) -> void: d["clocks"]["siege_count"] = -4).siege_count, 0)


func test_the_next_duels_lives_in_two_fields() -> void:
	var hero := _fresh()
	hero.next_duel_life = 3
	hero.next_duel_life_carried = -5
	assert_eq(hero.next_duel_lives(), -2, "the gift and the lives carried add up")
	assert_true(hero.duel_gift_waiting(), "the gift waits")
	var back := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(hero.to_dict())))
	assert_eq([back.next_duel_life, back.next_duel_life_carried], [3, -5], "both saved, a loss carried as one")
	hero.next_duel_life = 0
	assert_false(hero.duel_gift_waiting(), "the lives carried are no gift")
	hero.next_duel_card = "King Suleiman"
	hero.next_duel_first_move = true
	hero.clear_duel_gifts()
	assert_eq([hero.next_duel_life, hero.next_duel_life_carried, hero.next_duel_card, hero.next_duel_first_move],
		[0, 0, "", false], "every bonus spent after a duel")
	assert_eq(_read(func(d: Dictionary) -> void: d["duels"]["next_duel_life_carried"] = "x").next_duel_life_carried, 0)


## A save from before part B: every new field reads its default.
func test_a_save_from_before_part_b_loads() -> void:
	var back := _read(func(d: Dictionary) -> void:
		d["duels"].erase("next_duel_life_carried")
		d["duels"].erase("creature_deck_colors")
		d["clocks"].erase("siege_count"))
	assert_not_null(back)
	assert_eq([back.next_duel_life_carried, back.siege_count], [0, 0])
	assert_eq(back.creature_deck_colors, [0, 0, 0, 0, 0] as Array[int])
	back = _read(func(d: Dictionary) -> void: d.erase("duels"))
	assert_not_null(back, "even with no duels part")
	assert_eq(back.duel_victories, [])


# ------------------------------------------------------------- the cards --

func test_the_deck_in_use() -> void:
	var hero := _fresh()
	assert_eq(hero.deck_cards().size(), 40, "a Magician's first deck, in deck 1")
	var dealt: Array[String] = []
	dealt.assign(hero.cards.map(func(c: Dictionary) -> String: return c["card"]))
	assert_eq(hero.deck_cards(), dealt, "every card dealt")
	hero.current_deck = 1
	assert_eq(hero.deck_cards(), [] as Array[String], "deck 2 is empty")


func test_a_card_won_joins_the_bag() -> void:
	CardRegistry.ensure_loaded()
	var hero := _fresh()
	var lines := hero.journal.size()
	assert_true(hero.add_card("Llanowar Elves"))
	assert_eq(hero.cards[-1], {"card": "Llanowar Elves", "decks": []}, "in no deck")
	assert_eq(hero.journal.size(), lines, "a common writes nothing")
	assert_true(hero.add_card("Shivan Dragon"))
	assert_eq(hero.journal.size(), lines + 1, "a rare is written")
	assert_eq(String(hero.journal[-1]["text"]), "Acquired spell: Shivan Dragon", "@LOGSTRINGS 11")
	assert_eq(String(hero.journal[-1]["event"]), "card")
	assert_false(hero.add_card(""), "no card")


func test_the_bag_holds_five_hundred() -> void:
	CardRegistry.ensure_loaded()
	var hero := _fresh()
	while hero.cards.size() < AdventurePlayer.BAG_MOST:
		hero.cards.append({"card": "Island", "decks": []})
	var lines := hero.journal.size()
	assert_false(hero.add_card("Shivan Dragon"), "the bag is full: the card is lost")
	assert_eq(hero.cards.size(), 500)
	assert_eq(hero.journal.size(), lines, "[ours] no line for a card lost")
	assert_eq(AdventurePlayer.BAG_WARN, 450)
