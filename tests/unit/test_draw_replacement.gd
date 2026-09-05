extends GameTest
## Engine tests for the DRAW-REPLACEMENT subsystem (CR 614), independent of
## the cards that motivated it: MtgGame._replace_draw and its two kinds of
## replacement (a static one on a permanent via CardData.draw_replacement,
## a one-shot one via MtgGame.replace_next_draw), the CR 614.5 re-entry
## guard, the draw-STEP replacement (CardData.draw_step_replacement), and
## the bookkeeping the cards read — MtgPlayer.drawn_this_turn and
## draws_this_step. The card tests live in tests/cards/test_pool_wave66.gd.


func _hand_size(pid: int) -> int:
	return g.players[pid].hand.size()


# ------------------------------------------------- one-shot replacements --

func test_replace_next_draw_eats_exactly_one_draw() -> void:
	var seen := []
	g.replace_next_draw(0, func(_game: MtgGame, pid: int, _ctx: Dictionary) -> void:
		seen.append(pid))
	g.draw_cards(0, 2)
	assert_eq(seen, [0], "the replacement fired once")
	assert_eq(_hand_size(0), 1, "the first draw was replaced, the second happened")


func test_a_replaced_draw_moves_no_card_and_fires_no_event() -> void:
	var drawn := []
	g.event_occurred.connect(func(e: GameEvent) -> void:
		if e.type == Mtg.EventType.CARD_DRAWN:
			drawn.append(e))
	g.replace_next_draw(0, func(_g: MtgGame, _pid: int, _c: Dictionary) -> void: pass)
	g.draw_cards(0, 1)
	assert_eq(_hand_size(0), 0)
	assert_eq(drawn.size(), 0, "no CARD_DRAWN for a draw that never happened")


func test_a_replaced_draw_cannot_kill_an_empty_library() -> void:
	g.players[0].library.clear()
	g.replace_next_draw(0, func(_g: MtgGame, _pid: int, _c: Dictionary) -> void: pass)
	g.draw_cards(0, 1)
	assert_false(g.game_over, "no draw happened, so nobody drew from an empty deck")


func test_a_one_shot_only_catches_its_own_player() -> void:
	g.replace_next_draw(1, func(_g: MtgGame, _pid: int, _c: Dictionary) -> void: pass)
	g.draw_cards(0, 1)
	assert_eq(_hand_size(0), 1, "p0's draw is not p1's replacement")
	g.draw_cards(1, 1)
	assert_eq(_hand_size(1), 0)


func test_one_shot_replacements_expire_at_cleanup() -> void:
	g.replace_next_draw(0, func(_g: MtgGame, _pid: int, _c: Dictionary) -> void: pass)
	advance_to_next_turn()
	var before := _hand_size(0)
	g.draw_cards(0, 1)
	assert_eq(_hand_size(0), before + 1, "'this turn' expired unspent")


# --------------------------------------------------- static replacements --

func test_a_static_replacement_sees_the_draw_context() -> void:
	# Island Sanctuary is the pool's user; the context it reads is
	# in_draw_step + draw_number.
	var sanctuary := put_battlefield(0, "Island Sanctuary")
	assert_true(sanctuary.data.draw_replacement.is_valid())
	# Outside the draw step it declines, so a plain draw goes through.
	g.draw_cards(0, 1)
	assert_eq(_hand_size(0), 1)


func test_draws_this_step_counts_would_be_draws() -> void:
	assert_eq(g.players[0].draws_this_step, 0)
	g.draw_cards(0, 3)
	assert_eq(g.players[0].draws_this_step, 3)
	g.replace_next_draw(0, func(_g: MtgGame, _pid: int, _c: Dictionary) -> void: pass)
	g.draw_cards(0, 1)
	assert_eq(g.players[0].draws_this_step, 4,
		"a replaced draw is still a would-be draw")


func test_draws_this_step_resets_on_every_step_boundary() -> void:
	g.draw_cards(0, 2)
	assert_eq(g.players[0].draws_this_step, 2)
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	assert_eq(g.players[0].draws_this_step, 0)


# ---------------------------------------------------- drawn_this_turn --

func test_drawn_this_turn_keeps_the_cards_not_a_count() -> void:
	g.draw_cards(0, 2)
	assert_eq(g.players[0].drawn_this_turn.size(), 2)
	for inst in g.players[0].drawn_this_turn:
		assert_eq(inst.zone, Mtg.Zone.HAND)


func test_drawn_this_turn_is_cleared_at_cleanup() -> void:
	g.draw_cards(0, 2)
	advance_to_next_turn()
	assert_eq(g.players[0].drawn_this_turn.size(), 0)


# -------------------------------------------- the CR 614.5 re-entry guard --

func test_a_replacement_cannot_catch_its_own_replacement_draw() -> void:
	# Chains of Mephistopheles is the pool's user: its "then they draw a
	# card" must not fall into its own jaws, or the card never terminates.
	put_battlefield(0, "Chains of Mephistopheles")
	give_hand(0, "Forest")
	g.draw_cards(0, 1)
	# Discarded the Forest, then drew one card that Chains did NOT re-eat.
	assert_eq(_hand_size(0), 1)
	assert_eq(g.players[0].graveyard.size(), 1)


# ------------------------------------------------ draw-STEP replacement --

func test_a_skipped_draw_step_draws_nothing_and_fires_no_draw_step_event() -> void:
	# Fasting is the pool's user.
	put_battlefield(0, "Fasting")
	var steps := []
	g.event_occurred.connect(func(e: GameEvent) -> void:
		if e.type == Mtg.EventType.DRAW_STEP:
			steps.append(int(e.data["player"])))
	var before := _hand_size(0)
	advance_to_next_turn()   # p1's turn: p1 draws normally
	assert_true(steps.has(1), "the other seat's draw step is untouched")
	advance_to_next_turn()   # p0's turn: Fasting skips it
	assert_eq(_hand_size(0), before, "p0 drew nothing")
	assert_false(steps.has(0), "the whole step was skipped")


func test_put_from_hand_on_top_of_library_is_not_a_draw_in_reverse() -> void:
	var card := give_hand(0, "Forest")
	var lib := g.players[0].library.size()
	g.put_from_hand_on_top_of_library(card)
	assert_eq(card.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[0].library.size(), lib + 1)
	assert_eq(g.players[0].library.back(), card, "on TOP")
	assert_eq(_hand_size(0), 0)


func test_put_on_bottom_of_library_goes_under_everything() -> void:
	var card := give_hand(0, "Forest")
	g.put_on_bottom_of_library(card)
	assert_eq(card.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[0].library[0], card, "at the BOTTOM")
