extends GameTest
## AI SIDEBOARDING — [AiMatchMemory] and [AiSideboard], M4 phase 2.x.
##
## Two things are under test and they are deliberately separate: WHAT THE
## AI SAW (the memory, which is the only thing it may sideboard on — the
## opponent's decklist is off limits) and WHAT IT DOES WITH IT (the swap,
## which must never change the deck's size, never break the copy limit
## counted across both piles, and never leave a format the match required).
##
## The three invariants have a test each, named for the invariant, because
## they are the promises the design makes and the ones a future tuning pass
## must not quietly break.


func _memory_seeing(names: Array, pid := 0) -> AiMatchMemory:
	# The memory as it would stand after one duel in which the opponent
	# showed exactly [param names]. Built through the real recorder — a
	# hand-filled dictionary would test the scorer against a fiction.
	var memory := AiMatchMemory.new(pid)
	memory.watch(g)
	for card_name in names:
		var inst := put_battlefield(1 - pid, String(card_name))
		g.dispatch_event(Mtg.EventType.SPELL_CAST,
			{"instance": inst, "controller": 1 - pid})
	memory.end_duel()
	return memory


func _rng(seed_value := 7) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _pile(counts: Dictionary) -> Array:
	var pile: Array = []
	var names: Array = counts.keys()
	names.sort()
	for card_name in names:
		for _n in int(counts[card_name]):
			pile.append(String(card_name))
	return pile


# ------------------------------------------------- what the memory sees --

func test_the_memory_records_what_the_opponent_cast() -> void:
	var memory := _memory_seeing(["Shatter", "Shatter", "Ornithopter"])
	assert_eq(memory.copies_seen("Shatter"), 2)
	assert_eq(memory.copies_seen("Ornithopter"), 1)
	assert_eq(memory.duels, 1)


func test_the_memory_ignores_our_own_cards() -> void:
	var memory := AiMatchMemory.new(0)
	memory.watch(g)
	var mine := put_battlefield(0, "Shatter")
	g.dispatch_event(Mtg.EventType.SPELL_CAST,
		{"instance": mine, "controller": 0})
	memory.end_duel()
	assert_eq(memory.copies_seen("Shatter"), 0,
		"a seat sideboards against its OPPONENT, not against itself")


func test_the_memory_never_sums_copies_across_duels() -> void:
	# Four Bolts seen in each of three duels is four Bolts in the deck, not
	# twelve — the estimate a human makes at the table.
	var memory := AiMatchMemory.new(0)
	for _duel in 3:
		memory.watch(g)
		for _copy in 4:
			var inst := put_battlefield(1, "Lightning Bolt")
			g.dispatch_event(Mtg.EventType.SPELL_CAST,
				{"instance": inst, "controller": 1})
		memory.end_duel()
	assert_eq(memory.copies_seen("Lightning Bolt"), 4)
	assert_eq(memory.duels, 3)


func test_one_instance_seen_twice_is_still_one_card() -> void:
	# Cast, then reanimated: two events, one card in the opponent's deck.
	var memory := AiMatchMemory.new(0)
	memory.watch(g)
	var ogre := put_battlefield(1, "Gray Ogre")
	g.dispatch_event(Mtg.EventType.SPELL_CAST,
		{"instance": ogre, "controller": 1})
	g.dispatch_event(Mtg.EventType.ENTERS_BATTLEFIELD,
		{"instance": ogre, "controller": 1})
	memory.end_duel()
	assert_eq(memory.copies_seen("Gray Ogre"), 1)


func test_a_token_is_not_remembered() -> void:
	var memory := AiMatchMemory.new(0)
	# Made a token BEFORE the memory starts watching: `put_battlefield`
	# dispatches its own ENTERS_BATTLEFIELD, and this test is about the
	# token flag, not about that event.
	var inst := put_battlefield(1, "Grizzly Bears")
	inst.is_token = true
	memory.watch(g)
	g.dispatch_event(Mtg.EventType.ENTERS_BATTLEFIELD,
		{"instance": inst, "controller": 1})
	memory.end_duel()
	assert_eq(memory.copies_seen("Grizzly Bears"), 0,
		"a token is in nobody's deck")


func test_the_memory_records_damage_by_colour() -> void:
	var memory := AiMatchMemory.new(0)
	memory.watch(g)
	var bolt := put_battlefield(1, "Lightning Bolt")
	g.deal_damage(bolt, TargetRef.player(0), 3)
	memory.end_duel()
	assert_eq(memory.damage_from(Mtg.ManaColor.R), 3)
	assert_eq(memory.damage_from(Mtg.ManaColor.W), 0)


# ------------------------------------------------ reading a card's answer --

func test_terror_is_not_read_as_artifact_hate() -> void:
	# "Destroy target nonartifact, nonblack creature" — the negations are
	# stripped before anything is matched, or Terror would look like the
	# answer to an artifact deck.
	var keys := AiSideboard.answers(CardRegistry.get_card("Terror"))
	assert_true(keys.has(AiSideboard.S_CREATURE), "Terror answers creatures")
	assert_false(keys.has(AiSideboard.S_ARTIFACT),
		"nonartifact is not artifact hate")
	assert_false(keys.has("color:black"), "nonblack is not black hate")


func test_earthquake_is_not_read_as_flying_hate() -> void:
	# "each creature without flying" — the opposite of Hurricane, which is
	# the card that IS flying hate.
	var quake := AiSideboard.answers(CardRegistry.get_card("Earthquake"))
	assert_false(quake.has(AiSideboard.S_FLYING))
	var hurricane := AiSideboard.answers(CardRegistry.get_card("Hurricane"))
	assert_true(hurricane.has(AiSideboard.S_FLYING))


func test_a_plain_creature_answers_nothing() -> void:
	assert_eq(AiSideboard.answers(CardRegistry.get_card("Serra Angel")).size(), 0,
		"'Flying, vigilance' names a keyword; it does not answer one")


func test_shatter_answers_artifacts_and_tranquility_enchantments() -> void:
	assert_true(AiSideboard.answers(CardRegistry.get_card("Shatter"))
		.has(AiSideboard.S_ARTIFACT))
	assert_true(AiSideboard.answers(CardRegistry.get_card("Tranquility"))
		.has(AiSideboard.S_ENCHANTMENT))


# --------------------------------------------------------- the three swaps --

## A red deck with a real mana base, a filler spell worth cutting, and a
## sideboard of artifact hate.
func _red_deck() -> Array:
	return _pile({"Mountain": 17, "Gray Ogre": 4, "Hurloon Minotaur": 4})


func test_it_boards_in_the_answer_to_what_it_saw() -> void:
	var deck := _red_deck()
	var board := _pile({"Shatter": 4})
	var memory := _memory_seeing(["Ornithopter", "Ornithopter",
		"Ornithopter", "Ornithopter"])
	var plan := AiSideboard.sideboard(memory, deck, board,
		AiProfile.wizard(), _rng())
	assert_gt(plan["in"].size(), 0, "four artifacts seen, Shatter in hand")
	assert_true(deck.has("Shatter"))
	assert_eq(String(plan["in"][0]), "Shatter")


func test_it_leaves_a_dead_answer_in_the_board() -> void:
	var deck := _red_deck()
	var board := _pile({"Shatter": 4})
	# A duel in which the opponent showed nothing but creatures.
	var memory := _memory_seeing(["Grizzly Bears", "Grizzly Bears"])
	var plan := AiSideboard.sideboard(memory, deck, board,
		AiProfile.wizard(), _rng())
	assert_eq(plan["in"].size(), 0, "no artifacts seen, so Shatter is dead")
	assert_false(deck.has("Shatter"))


func test_a_dead_narrow_answer_is_the_first_card_cut() -> void:
	# Blue Elemental Blast in the MAINDECK against a deck with no red card
	# in it: the cheapest possible improvement is to cut it.
	var deck := _pile({"Mountain": 17, "Gray Ogre": 4,
		"Blue Elemental Blast": 2, "Island": 4})
	var board := _pile({"Shatter": 4})
	var memory := _memory_seeing(["Ornithopter", "Ornithopter",
		"Ornithopter", "Ornithopter"])
	var plan := AiSideboard.sideboard(memory, deck, board,
		AiProfile.wizard(), _rng())
	assert_gt(plan["out"].size(), 0)
	assert_eq(String(plan["out"][0]), "Blue Elemental Blast")


func test_it_never_cuts_a_land() -> void:
	var deck := _pile({"Mountain": 30})
	var board := _pile({"Shatter": 4})
	var memory := _memory_seeing(["Ornithopter", "Ornithopter",
		"Ornithopter", "Ornithopter"])
	var plan := AiSideboard.sideboard(memory, deck, board,
		AiProfile.wizard(), _rng())
	assert_eq(plan["in"].size(), 0,
		"there was nothing to cut but mana, so nothing moved")
	assert_eq(deck.count("Mountain"), 30)


func test_it_will_not_board_in_a_card_the_deck_cannot_cast() -> void:
	# A mono-red deck cannot cast Circle of Protection: Red, however much
	# it would like to.
	var deck := _red_deck()
	var board := _pile({"Circle of Protection: Red": 4})
	var memory := _memory_seeing(["Lightning Bolt", "Lightning Bolt",
		"Lightning Bolt", "Lightning Bolt"])
	var plan := AiSideboard.sideboard(memory, deck, board,
		AiProfile.wizard(), _rng())
	assert_eq(plan["in"].size(), 0)
	assert_eq(board.count("Circle of Protection: Red"), 4)


func test_the_apprentice_does_not_sideboard_at_all() -> void:
	var deck := _red_deck()
	var board := _pile({"Shatter": 4})
	var memory := _memory_seeing(["Ornithopter", "Ornithopter",
		"Ornithopter", "Ornithopter"])
	var plan := AiSideboard.sideboard(memory, deck, board,
		AiProfile.apprentice(), _rng())
	assert_eq(plan["in"].size(), 0)
	assert_eq(deck.count("Shatter"), 0)
	assert_eq(board.count("Shatter"), 4)


func test_nothing_moves_before_the_first_duel_has_been_seen() -> void:
	var deck := _red_deck()
	var board := _pile({"Shatter": 4})
	var plan := AiSideboard.sideboard(AiMatchMemory.new(0), deck, board,
		AiProfile.wizard(), _rng())
	assert_eq(plan["in"].size(), 0, "duel 1 has no evidence to board on")


func test_a_profile_never_swaps_more_than_its_allowance() -> void:
	var deck := _pile({"Mountain": 17, "Gray Ogre": 8})
	var board := _pile({"Shatter": 8})
	var memory := _memory_seeing(["Ornithopter", "Ornithopter", "Ornithopter",
		"Ornithopter", "Ornithopter", "Ornithopter", "Ornithopter",
		"Ornithopter"])
	var wizard := AiProfile.wizard()
	var plan := AiSideboard.sideboard(memory, deck, board, wizard, _rng())
	assert_eq(plan["in"].size(), wizard.sideboard_swaps)
	assert_eq(plan["out"].size(), wizard.sideboard_swaps)


# ---------------------------------------------------- THE THREE INVARIANTS --

func test_invariant_the_deck_size_never_moves() -> void:
	var deck := _red_deck()
	var board := _pile({"Shatter": 4})
	var before_deck := deck.size()
	var before_board := board.size()
	var memory := _memory_seeing(["Ornithopter", "Ornithopter",
		"Ornithopter", "Ornithopter"])
	var plan := AiSideboard.sideboard(memory, deck, board,
		AiProfile.wizard(), _rng())
	assert_gt(plan["in"].size(), 0, "the test is worthless if nothing moved")
	assert_eq(deck.size(), before_deck)
	assert_eq(board.size(), before_board)


func test_invariant_the_copy_limit_is_counted_across_both_piles() -> void:
	# Four Shatter split two and two. Whatever moves, four is the number of
	# Shatter in the match, and DeckFormat counts both piles.
	var deck := _pile({"Mountain": 17, "Gray Ogre": 4, "Shatter": 2})
	var board := _pile({"Shatter": 2, "Dust to Dust": 2})
	var memory := _memory_seeing(["Ornithopter", "Ornithopter",
		"Ornithopter", "Ornithopter"])
	AiSideboard.sideboard(memory, deck, board, AiProfile.wizard(), _rng(),
		DeckFormat.RESTRICTED_T1)
	assert_eq(deck.count("Shatter") + board.count("Shatter"), 4)
	assert_eq(DeckFormat.legal(deck, DeckFormat.RESTRICTED_T1, board), "",
		"the copy limit counts across both piles and must still hold")


func test_invariant_a_format_the_match_required_is_still_legal() -> void:
	var deck := _pile({"Mountain": 17, "Gray Ogre": 4,
		"Blue Elemental Blast": 2, "Island": 4})
	var board := _pile({"Shatter": 4, "Dust to Dust": 2})
	assert_eq(DeckFormat.legal(deck, DeckFormat.TOURNAMENT_T15, board), "",
		"the fixture must start legal or it proves nothing")
	var memory := _memory_seeing(["Ornithopter", "Ornithopter",
		"Ornithopter", "Ornithopter"])
	var plan := AiSideboard.sideboard(memory, deck, board,
		AiProfile.wizard(), _rng(), DeckFormat.TOURNAMENT_T15)
	assert_gt(plan["in"].size(), 0)
	assert_eq(DeckFormat.legal(deck, DeckFormat.TOURNAMENT_T15, board), "")


# ------------------------------------------------------------ determinism --

func test_the_same_seed_makes_the_same_swap() -> void:
	var memory := _memory_seeing(["Ornithopter", "Ornithopter",
		"Ornithopter", "Ornithopter", "Grizzly Bears"])
	var plans: Array = []
	for _run in 2:
		var deck := _red_deck()
		var board := _pile({"Shatter": 4, "Dust to Dust": 2,
			"Red Elemental Blast": 2})
		plans.append(AiSideboard.sideboard(memory, deck, board,
			AiProfile.magician(), _rng(99)))
	assert_eq(plans[0]["in"], plans[1]["in"])
	assert_eq(plans[0]["out"], plans[1]["out"])


func test_a_fumbling_profile_makes_fewer_swaps() -> void:
	# Difficulty is mistake injection and nothing else: a profile that is
	# allowed four swaps and fumbles most of them makes fewer than four.
	var memory := _memory_seeing(["Ornithopter", "Ornithopter", "Ornithopter",
		"Ornithopter", "Ornithopter", "Ornithopter", "Ornithopter",
		"Ornithopter"])
	var butterfingers := AiProfile.new("Butterfingers", 0.95, 0.5, 5, true,
		5.0, 4)
	var deck := _pile({"Mountain": 17, "Gray Ogre": 8})
	var board := _pile({"Shatter": 8})
	var plan := AiSideboard.sideboard(memory, deck, board, butterfingers,
		_rng(3))
	assert_lt(plan["in"].size(), 4,
		"a 95%-mistake profile cannot land all four swaps")
	assert_eq(deck.size(), 25, "a fumbled swap still leaves the deck whole")
