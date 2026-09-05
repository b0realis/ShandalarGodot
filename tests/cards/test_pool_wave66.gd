extends GameTest
## Wave-66 tests: the DRAW-REPLACEMENT cluster — Island Sanctuary, Chains of
## Mephistopheles, Aladdin's Lamp — plus Sylvan Library (a draw-step TRIGGER
## that wanted the "drawn this turn" record, not a replacement) and Fasting
## (a replacement of the draw STEP). The engine tests for the subsystem live
## in tests/unit/test_draw_replacement.gd.


## Says yes to everything (takes the offered skip / the extra cards).
class Eager extends DecisionAgent:
	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String,
			_hint: bool) -> bool:
		return true


## Says no to everything.
class Reluctant extends DecisionAgent:
	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String,
			_hint: bool) -> bool:
		return false


## Takes Sylvan Library's two extra cards but refuses to pay for them.
class Frugal extends DecisionAgent:
	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String,
			_hint: bool) -> bool:
		return not prompt.begins_with("Pay 4 life")


## Says yes, and picks a CARD by name where it can.
class EagerPicker extends DecisionAgent:
	var wanted := ""

	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String,
			_hint: bool) -> bool:
		return true

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		for inst in candidates:
			if inst.data.card_name == wanted:
				return inst
		return null if candidates.is_empty() else candidates[0]


func test_registry_loaded_wave66() -> void:
	for name in ["Island Sanctuary", "Chains of Mephistopheles",
			"Aladdin's Lamp", "Sylvan Library", "Fasting"]:
		assert_not_null(CardRegistry.get_card(name), name)


# ----------------------------------------------------- Island Sanctuary --

func test_sanctuary_skips_the_draw_when_the_seat_accepts() -> void:
	g.set_agent(0, Eager.new())
	advance_to_step(Mtg.Step.MAIN1)   # past turn 1's own draw step
	put_battlefield(0, "Island Sanctuary")
	var before := g.players[0].hand.size()
	advance_to_next_turn()
	advance_to_next_turn()   # back to p0, through their draw step
	assert_eq(g.players[0].hand.size(), before, "the draw was replaced away")


func test_sanctuary_lets_the_draw_happen_when_declined() -> void:
	g.set_agent(0, Reluctant.new())
	advance_to_step(Mtg.Step.MAIN1)   # past turn 1's own draw step
	put_battlefield(0, "Island Sanctuary")
	var before := g.players[0].hand.size()
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(g.players[0].hand.size(), before + 1)


func test_sanctuary_grounds_the_opponents_army_after_the_skip() -> void:
	g.set_agent(0, Eager.new())
	advance_to_step(Mtg.Step.MAIN1)   # past turn 1's own draw step
	put_battlefield(0, "Island Sanctuary")
	var ground := put_battlefield(1, "Grizzly Bears")
	var flier := put_battlefield(1, "Serra Angel")
	advance_to_next_turn()
	advance_to_next_turn()   # p0's draw step: the gates close
	assert_true(ground.cur_cant_attack, "ground creatures are shut out")
	assert_false(flier.cur_cant_attack, "flying still gets in")


func test_sanctuary_only_holds_until_your_next_turn() -> void:
	g.set_agent(0, Eager.new())
	advance_to_step(Mtg.Step.MAIN1)   # past turn 1's own draw step
	put_battlefield(0, "Island Sanctuary")
	var ground := put_battlefield(1, "Grizzly Bears")
	advance_to_next_turn()
	advance_to_next_turn()   # p0's turn: closed
	assert_true(ground.cur_cant_attack)
	advance_to_next_turn()   # p1's turn: still closed
	assert_true(ground.cur_cant_attack)
	advance_to_next_turn()   # p0's NEXT turn — the draw step re-asks, but
	                         # the memory of the previous close has lapsed
	assert_true(ground.cur_cant_attack, "it closed again this turn")


func test_sanctuary_does_nothing_to_a_draw_outside_your_draw_step() -> void:
	g.set_agent(0, Eager.new())
	advance_to_step(Mtg.Step.MAIN1)   # past turn 1's own draw step
	put_battlefield(0, "Island Sanctuary")
	g.draw_cards(0, 1)
	assert_eq(g.players[0].hand.size(), 1, "only the draw STEP is replaced")


# --------------------------------------------- Chains of Mephistopheles --

func test_chains_leaves_the_first_draw_step_draw_alone() -> void:
	put_battlefield(0, "Chains of Mephistopheles")
	give_hand(0, "Forest")
	advance_to_next_turn()
	advance_to_next_turn()   # p0's draw step
	assert_eq(g.players[0].graveyard.size(), 0, "the first draw is exempt")
	assert_eq(g.players[0].hand.size(), 2, "Forest plus the drawn card")


func test_chains_turns_a_later_draw_into_a_rummage() -> void:
	put_battlefield(0, "Chains of Mephistopheles")
	give_hand(0, "Forest")
	give_hand(0, "Forest")
	g.draw_cards(0, 1)
	assert_eq(g.players[0].graveyard.size(), 1, "one discarded")
	assert_eq(g.players[0].hand.size(), 2, "and one drawn to replace it")


func test_chains_mills_a_player_with_no_hand() -> void:
	put_battlefield(0, "Chains of Mephistopheles")
	var lib := g.players[1].library.size()
	g.draw_cards(1, 1)
	assert_eq(g.players[1].hand.size(), 0, "nothing drawn")
	assert_eq(g.players[1].library.size(), lib - 1, "milled instead")
	assert_eq(g.players[1].graveyard.size(), 1)


func test_chains_binds_both_players() -> void:
	put_battlefield(0, "Chains of Mephistopheles")
	give_hand(1, "Forest")
	g.draw_cards(1, 1)
	assert_eq(g.players[1].graveyard.size(), 1,
		"'if a PLAYER would draw' — not just its controller")


# ------------------------------------------------------- Aladdin's Lamp --

func test_lamp_digs_for_the_card_you_choose() -> void:
	var lamp := put_battlefield(0, "Aladdin's Lamp")
	# Stack a known top-of-library: last element is the top.
	var wanted := give_hand(0, "Serra Angel")
	g.players[0].hand.erase(wanted)
	wanted.zone = Mtg.Zone.LIBRARY
	g.players[0].library.insert(g.players[0].library.size() - 2, wanted)
	var agent := EagerPicker.new()
	agent.wanted = "Serra Angel"
	g.set_agent(0, agent)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, lamp, 0, [], 3))
	resolve_stack()
	g.draw_cards(0, 1)
	assert_eq(g.players[0].hand.size(), 1)
	assert_eq(g.players[0].hand[0], wanted, "the chosen card was drawn")


func test_lamp_refuses_x_of_zero() -> void:
	var lamp := put_battlefield(0, "Aladdin's Lamp")
	assert_refused(g.activate_ability(0, lamp, 0, [], 0), "X can't be less than 1")


func test_lamp_replacement_is_spent_on_one_draw_only() -> void:
	var lamp := put_battlefield(0, "Aladdin's Lamp")
	g.set_agent(0, Eager.new())
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, lamp, 0, [], 2))
	resolve_stack()
	g.draw_cards(0, 2)
	# One card from the rummage's own draw, one from the ordinary second.
	assert_eq(g.players[0].hand.size(), 2)


# ------------------------------------------------------- Sylvan Library --

func test_sylvan_library_draws_two_more_and_puts_two_back() -> void:
	g.set_agent(0, Frugal.new())      # take the cards, refuse the 4 life
	advance_to_step(Mtg.Step.MAIN1)   # past turn 1's own draw step
	put_battlefield(0, "Sylvan Library")
	var lib := g.players[0].library.size()
	advance_to_next_turn()
	advance_to_next_turn()
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 1,
		"drew 1 + 2, put 2 back on the library")
	assert_eq(g.players[0].library.size(), lib - 1, "three out, two back")
	assert_eq(g.players[0].life, 20, "no life was paid")


func test_sylvan_library_keeps_the_cards_when_the_life_is_paid() -> void:
	g.set_agent(0, Eager.new())
	advance_to_step(Mtg.Step.MAIN1)   # past turn 1's own draw step
	put_battlefield(0, "Sylvan Library")
	advance_to_next_turn()
	advance_to_next_turn()
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 3, "all three kept")
	assert_eq(g.players[0].life, 12, "4 life each for two of them")


func test_sylvan_library_is_declinable() -> void:
	g.set_agent(0, Reluctant.new())
	advance_to_step(Mtg.Step.MAIN1)   # past turn 1's own draw step
	put_battlefield(0, "Sylvan Library")
	advance_to_next_turn()
	advance_to_next_turn()
	resolve_stack()
	# Reluctant said no to the two extra cards, so only the normal draw-step
	# card is in hand and nothing was put back or paid for.
	assert_eq(g.players[0].hand.size(), 1)
	assert_eq(g.players[0].life, 20)


# ------------------------------------------------------------- Fasting --

func test_fasting_skips_the_draw_step_and_gains_two_life() -> void:
	advance_to_step(Mtg.Step.MAIN1)   # past turn 1's own draw step
	put_battlefield(0, "Fasting")
	var before := g.players[0].hand.size()
	advance_to_next_turn()
	advance_to_next_turn()
	assert_eq(g.players[0].hand.size(), before, "no draw step happened")
	assert_eq(g.players[0].life, 22)


func test_fasting_starves_after_five_upkeeps() -> void:
	advance_to_step(Mtg.Step.MAIN1)   # past turn 1's own draw step
	var fasting := put_battlefield(0, "Fasting")
	for _i in 5:
		advance_to_next_turn()
		advance_to_next_turn()
		if fasting.zone != Mtg.Zone.BATTLEFIELD:
			break
	assert_eq(fasting.zone, Mtg.Zone.GRAVEYARD, "five hunger counters")
	assert_eq(g.players[0].life, 28, "2 life for each of four fasts before it starved")


func test_fasting_breaks_the_moment_you_draw() -> void:
	advance_to_step(Mtg.Step.MAIN1)   # past turn 1's own draw step
	var fasting := put_battlefield(0, "Fasting")
	g.draw_cards(0, 1)
	resolve_stack()
	assert_eq(fasting.zone, Mtg.Zone.GRAVEYARD)


func test_fasting_ignores_the_opponents_draws() -> void:
	advance_to_step(Mtg.Step.MAIN1)   # past turn 1's own draw step
	var fasting := put_battlefield(0, "Fasting")
	g.draw_cards(1, 1)
	resolve_stack()
	assert_eq(fasting.zone, Mtg.Zone.BATTLEFIELD)
