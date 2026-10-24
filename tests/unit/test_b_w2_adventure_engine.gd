extends GameTest
## PART B (W2, 2026-10-23): what an adventure duel asks of the ENGINE —
## the named stakes (`MtgGame.stake_named_ante` / `stake_extra_ante`), the
## record of owner changes, 1997's adventure mulligan
## (`MtgGame.MULLIGAN_1997`), the cards in play at the start and Mind
## Control (`arrange_opening`, `create_into_play`, `mirror_opening`), and
## life 0 at the start. The 1997 truth is `play_duel`'s Shandalar branch
## (`duel.c:2205-2526`), cited at each engine site.
##
## And the one thing the engine must NOT do: settle the ante when the duel
## ends. The adventure moves its own cards (docs/duel-todo.md §7).

const SPELLS := ["Grizzly Bears", "Hill Giant", "Lightning Bolt", "Giant Growth"]


func _deck(lands := 20, spells := 20) -> Array:
	var out: Array = []
	for i in lands:
		out.append("Forest")
	for i in spells:
		out.append(SPELLS[i % SPELLS.size()])
	return out


## A fresh, set-up game in [member g] (not dealt).
func _game(deck0: Array = [], deck1: Array = [], life0 := 20, life1 := 20,
		seed_value := 424242) -> MtgGame:
	g = MtgGame.new()
	g.setup(deck0 if not deck0.is_empty() else _deck(),
		deck1 if not deck1.is_empty() else _deck(), "Hero", "Creature",
		life0, life1, seed_value)
	return g


func _names(cards: Array) -> Array[String]:
	var out: Array[String] = []
	for inst in cards:
		out.append(inst.data.card_name)
	return out


func _count(cards: Array, card_name: String) -> int:
	return _names(cards).count(card_name)


func _has_log(fragment: String) -> bool:
	for line in g.log_lines:
		if String(line).contains(fragment):
			return true
	return false


# ------------------------------------------------------- the named stakes --

func test_a_named_stake_is_lifted_out_of_the_library() -> void:
	_game(_deck(20, 20), _deck(20, 20))
	var before := _count(g.players[0].library, "Hill Giant")
	var staked := g.stake_named_ante(0, ["Hill Giant"])
	assert_eq(_names(staked), ["Hill Giant"] as Array[String])
	assert_eq(_names(g.players[0].ante), ["Hill Giant"] as Array[String])
	assert_eq(staked[0].zone, Mtg.Zone.ANTE)
	assert_eq(staked[0].owner_id, 0)
	assert_eq(_count(g.players[0].library, "Hill Giant"), before - 1,
		"one copy came out of the library")
	assert_eq(g.players[0].library.size(), 39)
	assert_true(g.ante_enabled, "the duel is played for ante")


func test_a_named_stake_is_never_dealt() -> void:
	# A deck with ONE Lightning Bolt, staked: no deal can reach it (1997
	# marked it 0x8000 in the deck, duel.c:2360-2370).
	var deck := _deck(39, 0)
	deck.append("Lightning Bolt")
	for seed_value in [1, 2, 3, 4, 5]:
		_game(deck, _deck(), 20, 20, seed_value)
		g.stake_named_ante(0, ["Lightning Bolt"])
		g.deal_opening_hands(7)
		assert_eq(_count(g.players[0].hand, "Lightning Bolt"), 0)
		assert_eq(_count(g.players[0].library, "Lightning Bolt"), 0)


func test_a_named_stake_spends_no_rng_draw() -> void:
	# The random stake spends one draw; a named one is the adventure's
	# choice and spends none — the deal after it is the seed's own.
	_game()
	var state := g.rng.state
	g.stake_named_ante(0, ["Grizzly Bears"])
	g.stake_extra_ante(1, ["Black Lotus"])
	assert_eq(g.rng.state, state)


func test_two_names_stake_two_copies() -> void:
	_game()
	g.stake_named_ante(1, ["Grizzly Bears", "Grizzly Bears"])
	assert_eq(_names(g.players[1].ante), ["Grizzly Bears", "Grizzly Bears"] as Array[String])
	assert_ne(g.players[1].ante[0], g.players[1].ante[1])


func test_a_name_the_library_lacks_is_skipped_and_said() -> void:
	_game()
	var staked := g.stake_named_ante(0, ["Shivan Dragon", "Hill Giant"])
	assert_eq(_names(staked), ["Hill Giant"] as Array[String], "the rest is still staked")
	assert_true(_has_log("Hero has no Shivan Dragon in the library to ante"))
	assert_eq(g.players[0].library.size(), 39)


func test_naming_nothing_still_plays_for_ante() -> void:
	# The adventurer at a lair stakes nothing, and the duel is for the hoard.
	_game()
	assert_eq(g.stake_named_ante(0, []).size(), 0)
	assert_true(g.ante_enabled)
	assert_eq(g.players[0].library.size(), 40, "and nothing left the deck")


func test_an_extra_stake_is_made_into_the_ante() -> void:
	# A lair's hoard: rares the creature's deck never held.
	_game()
	var deck_before := g.players[1].deck_names.duplicate()
	var staked := g.stake_extra_ante(1, ["Black Lotus", "Mox Pearl"])
	assert_eq(_names(g.players[1].ante), ["Black Lotus", "Mox Pearl"] as Array[String])
	for inst in staked:
		assert_eq(inst.owner_id, 1, "owned by the seat that stakes it")
		assert_eq(inst.zone, Mtg.Zone.ANTE)
		assert_eq(g.find_instance(inst.id), inst, "a card of this game")
	assert_eq(g.players[1].library.size(), 40, "not out of the library")
	assert_eq(g.players[1].deck_names, deck_before, "and not part of the deck")
	assert_true(g.ante_enabled)


func test_an_unknown_extra_is_skipped_and_said() -> void:
	_game()
	assert_eq(g.stake_extra_ante(0, ["No Such Card At All"]).size(), 0)
	assert_true(_has_log("No card No Such Card At All can be anted"))


# ------------------------------------------- the engine never settles it --

func test_the_engine_never_settles_the_ante() -> void:
	_game()
	g.stake_named_ante(0, ["Hill Giant"])
	g.stake_named_ante(1, ["Grizzly Bears"])
	g.stake_extra_ante(1, ["Black Lotus"])
	g.deal_opening_hands(7)
	g.start_duel(0)
	assert_ok(g.concede(1))    # the adventurer wins
	assert_true(g.game_over)
	assert_eq(g.winner, 0)
	# Nothing moved and nothing changed hands: the piles and the owners are
	# what was staked. The adventure takes them from here.
	assert_eq(_names(g.players[0].ante), ["Hill Giant"] as Array[String])
	assert_eq(_names(g.players[1].ante), ["Grizzly Bears", "Black Lotus"] as Array[String])
	for inst in g.players[1].ante:
		assert_eq(inst.owner_id, 1)
		assert_eq(inst.zone, Mtg.Zone.ANTE)
	assert_eq(g.owner_changes.size(), 0)


# ------------------------------------------------------- owner changes --

func test_every_owner_change_is_listed() -> void:
	_game()
	g.stake_named_ante(0, ["Hill Giant"])
	g.deal_opening_hands(7)
	g.start_duel(0)
	var giant: CardInstance = g.players[0].ante[0]
	g.change_owner(giant, 1)
	assert_eq(g.owner_changes.size(), 1)
	assert_eq(g.owner_changes[0], {"id": giant.id, "card": "Hill Giant", "from": 0, "to": 1})
	assert_eq(_names(g.players[1].ante), ["Hill Giant"] as Array[String],
		"the card lives in its new owner's ante")


func test_an_owner_change_a_search_explored_leaves_no_line() -> void:
	_game()
	g.deal_opening_hands(7)
	g.start_duel(0)
	g.undo_log = UndoLog.new()
	var mark := g.make_mark()
	g.change_owner(g.players[0].hand[0], 1)
	assert_eq(g.owner_changes.size(), 1)
	g.unmake_to(mark)
	assert_eq(g.owner_changes.size(), 0, "journaled: the rewind takes it back")


# -------------------------------------------------- 1997's adventure mulligan --

## Seat 0's hand set to [param lands] Forests and the rest Bears (7 cards),
## the library keeping its size; the opening is open.
func _hand(pid: int, lands: int) -> void:
	var p := g.players[pid]
	for inst in p.hand:
		inst.zone = Mtg.Zone.LIBRARY
		p.library.append(inst)
	p.hand.clear()
	var want := {"Forest": lands, "Grizzly Bears": 7 - lands}
	for card_name in want:
		for i in int(want[card_name]):
			for j in range(p.library.size() - 1, -1, -1):
				if p.library[j].data.card_name == card_name:
					var inst: CardInstance = p.library[j]
					p.library.remove_at(j)
					inst.zone = Mtg.Zone.HAND
					p.hand.append(inst)
					break


## Twenty Forests and twenty Grizzly Bears a side: any hand [method _hand]
## asks for can be made.
func _deal_1997() -> void:
	var deck: Array = []
	for i in 20:
		deck.append("Forest")
		deck.append("Grizzly Bears")
	_game(deck, deck.duplicate())
	g.mulligan_rule = MtgGame.MULLIGAN_1997
	g.deal_opening_hands(7)


func test_the_rule_is_named_and_off_by_default() -> void:
	assert_eq(MtgGame.MULLIGAN_1997, "1997")
	assert_eq(MtgGame.MULLIGAN_1997_HERO, 0)
	assert_eq(MtgGame.new().mulligan_rule, "", "every other duel keeps ours")


func test_the_adventurer_may_redraw_only_no_land_or_all_land() -> void:
	_deal_1997()
	for lands in [1, 2, 3, 4, 5, 6]:
		_hand(0, lands)
		assert_false(g.may_mulligan(0), "%d lands: no offer" % lands)
	_hand(0, 0)
	assert_true(g.may_mulligan(0), "no land")
	_hand(0, 7)
	assert_true(g.may_mulligan(0), "all land")


func test_the_1997_redraw_is_seven_for_seven_and_once() -> void:
	_deal_1997()
	_hand(0, 0)
	assert_ok(g.take_mulligan(0))
	assert_eq(g.players[0].hand.size(), 7, "free: seven back, seven out")
	assert_eq(g.mulligans_taken[0], 1)
	assert_eq(g.players[0].hand.size() + g.players[0].library.size(), 40)
	_hand(0, 0)
	assert_false(g.may_mulligan(0), "never a second one")
	assert_refused(g.take_mulligan(0), "no mulligan is available")


func test_the_creature_answers_the_adventurers_redraw() -> void:
	# duel.c:2399-2470: fewer than two lands or more than five, once the
	# adventurer has redrawn.
	_deal_1997()
	_hand(0, 0)
	for lands in [1, 6]:
		_hand(1, lands)
		assert_false(g.may_mulligan(1), "%d lands, no redraw yet: keeps" % lands)
	assert_ok(g.take_mulligan(0))
	for lands in [1, 6]:
		_hand(1, lands)
		assert_true(g.may_mulligan(1), "%d lands after the redraw: goes again" % lands)
	for lands in [2, 3, 4, 5]:
		_hand(1, lands)
		assert_false(g.may_mulligan(1), "%d lands: keeps" % lands)
	_hand(1, 0)
	assert_true(g.may_mulligan(1), "and no land always goes")


func test_the_adventurer_gets_no_courtesy() -> void:
	# The 1997 offer to the adventurer never depends on the creature's.
	_deal_1997()
	_hand(1, 0)
	assert_ok(g.take_mulligan(1))
	_hand(0, 1)
	assert_false(g.may_mulligan(0))


# ---------------------------------------------- cards in play at the start --

func test_cards_in_play_enter_before_turn_one() -> void:
	_game()
	var deck_before := g.players[1].deck_names.duplicate()
	g.arrange_opening(false, [["Llanowar Elves"], ["Timber Wolves", "Wall of Wood"]])
	g.deal_opening_hands(7)
	assert_eq(g.players[1].battlefield.size(), 0, "not before the hands are settled")
	g.start_duel(1)
	assert_eq(_names(g.players[0].battlefield), ["Llanowar Elves"] as Array[String])
	assert_eq(_names(g.players[1].battlefield), ["Timber Wolves", "Wall of Wood"] as Array[String])
	for pid in 2:
		for inst in g.players[pid].battlefield:
			assert_eq(inst.owner_id, pid)
			assert_eq(inst.controller_id, pid)
	assert_eq(g.players[1].deck_names, deck_before, "from outside the deck")
	assert_eq(g.players[0].hand.size(), 7, "the hands are untouched")
	# The creature starts: its permanents were under its control as its
	# turn began, so they are not summoning sick (CR 302.6).
	assert_false(g.players[1].battlefield[0].summoning_sick)
	assert_false(g.players[0].acted_this_turn, "no turn had begun")
	assert_false(g.players[1].acted_this_turn)


func test_a_card_in_play_runs_its_entering() -> void:
	# Venerable Monk: "When Venerable Monk enters the battlefield, you gain
	# 2 life." 1997's process_card_enters_play; ours waits, as every trigger
	# of the untap step does, for turn 1's upkeep. (Portal is a pack.)
	CardPacks.set_enabled("pack-6", true)
	_game()
	g.arrange_opening(false, [["Venerable Monk"], []])
	g.deal_opening_hands(7)
	g.start_duel(0)
	resolve_stack()
	assert_eq(g.players[0].life, 22)
	CardPacks.set_enabled("pack-6", false)


func test_a_card_in_play_enters_with_its_counters_and_statics() -> void:
	# What belongs to ARRIVING is applied as it arrives: Clockwork Beast's
	# seven +1/+0 counters, and Crusade's +1/+1 to white creatures at once.
	_game()
	g.arrange_opening(false, [["Clockwork Beast"], ["Crusade", "White Knight"]])
	g.deal_opening_hands(7)
	g.start_duel(0)
	var beast: CardInstance = g.players[0].battlefield[0]
	assert_eq(int(beast.counters.get("+1/+0", 0)), 7)
	assert_eq(beast.cur_power, 7)
	var knight: CardInstance = g.players[1].battlefield[1]
	assert_eq(knight.data.card_name, "White Knight")
	assert_eq(knight.cur_power, 3, "Crusade's static applies from the first moment")


func test_a_card_that_is_no_permanent_is_not_put_into_play() -> void:
	_game()
	assert_null(g.create_into_play(0, "Lightning Bolt"))
	assert_true(_has_log("Lightning Bolt is not a permanent and cannot start the duel in play"))
	assert_null(g.create_into_play(0, "No Such Card At All"))
	assert_eq(g.players[0].battlefield.size(), 0)


func test_the_arrangements_run_once() -> void:
	_game()
	g.arrange_opening(false, [["Wall of Wood"], []])
	g.deal_opening_hands(7)
	g.start_duel(0)
	g.start_duel(0)   # a tool that starts twice
	assert_eq(g.players[0].battlefield.size(), 1)


func test_nothing_arranged_changes_nothing() -> void:
	# Two games on one seed, one told to arrange nothing: the same deal and
	# the same stream.
	_game()
	g.deal_opening_hands(7)
	g.start_duel(0)
	var plain_hand := _names(g.players[1].hand)
	var plain_state := g.rng.state
	_game()
	g.arrange_opening(false, [[], []])
	g.deal_opening_hands(7)
	g.start_duel(0)
	assert_eq(_names(g.players[1].hand), plain_hand)
	assert_eq(g.rng.state, plain_state)


# ------------------------------------------------------------ Mind Control --

func test_mind_control_copies_the_library_and_the_final_hand() -> void:
	var hero := _deck(10, 0)
	for card_name in ["Shivan Dragon", "Serra Angel", "Lightning Bolt", "Dark Ritual"]:
		for i in 5:
			hero.append(card_name)
	_game(hero, _deck(20, 20))
	g.stake_named_ante(0, ["Serra Angel"])
	g.stake_named_ante(1, ["Hill Giant"])
	g.arrange_opening(true)
	g.deal_opening_hands(7)
	assert_ok(g.take_mulligan(0))           # the hand AFTER the mulligans
	var hero_hand := _names(g.players[0].hand)
	var hero_library := _names(g.players[0].library)
	var old_ids: Array[int] = []
	for inst in g.players[1].library + g.players[1].hand:
		old_ids.append(inst.id)
	g.start_duel(0)
	assert_eq(_names(g.players[1].hand), hero_hand, "the hand, card for card")
	var copied := _names(g.players[1].library)
	var expected := hero_library.duplicate()
	copied.sort()
	expected.sort()
	assert_eq(copied, expected, "the library, card for card")
	for inst in g.players[1].library + g.players[1].hand:
		assert_eq(inst.owner_id, 1, "the copies are the creature's own")
		assert_false(g.players[0].library.has(inst) or g.players[0].hand.has(inst))
	for id in old_ids:
		assert_null(g.find_instance(id), "its own cards are gone from the game")
	assert_eq(_names(g.players[1].ante), ["Hill Giant"] as Array[String],
		"its stake stays its own")
	assert_eq(g.players[1].deck_names, g.players[0].deck_names, "it plays the hero's list")
	assert_true(_has_log("Creature's library and hand are a copy of Hero's"))


func test_mind_control_shuffles_the_copy() -> void:
	var differs := false
	for seed_value in [11, 12, 13]:
		var hero: Array = []
		for i in 40:
			hero.append(SPELLS[i % SPELLS.size()] if i % 2 == 0 else "Forest")
		_game(hero, _deck(), 20, 20, seed_value)
		g.arrange_opening(true)
		g.deal_opening_hands(7)
		g.start_duel(0)
		if _names(g.players[1].library) != _names(g.players[0].library):
			differs = true
	assert_true(differs, "a shuffled copy, not the same order")


# ------------------------------------------------------------- life 0 --

func test_life_zero_is_a_loss_at_once() -> void:
	# duel.c:2205-2226: no floor — no links and no bonus is life 0, a loss.
	_game([], [], 0, 12)
	g.deal_opening_hands(7)
	g.start_duel(0)
	assert_true(g.game_over, "before anyone acts")
	assert_eq(g.winner, 1)
	assert_eq(g.turn_number, 1)
	assert_eq(g.players[0].battlefield.size() + g.players[1].battlefield.size(), 0)


func test_the_creature_at_life_zero_loses_at_once() -> void:
	_game([], [], 5, 0)
	g.deal_opening_hands(7)
	g.start_duel(1)
	assert_true(g.game_over)
	assert_eq(g.winner, 0)


func test_both_at_life_zero_is_a_draw() -> void:
	_game([], [], 0, 0)
	g.deal_opening_hands(7)
	g.start_duel(0)
	assert_true(g.game_over)
	assert_eq(g.winner, -1)


func test_any_life_is_dealt() -> void:
	_game([], [], 400, 1)
	g.deal_opening_hands(7)
	g.start_duel(0)
	assert_false(g.game_over)
	assert_eq(g.players[0].life, 400)
	assert_eq(g.players[1].life, 1)
